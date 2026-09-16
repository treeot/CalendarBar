import XCTest
@testable import CalendarBar

final class EventTimelineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testCurrentEventIncludesEventsThatStartedAtNowAndExcludesEventsEndingAtNow() {
        let startingNow = makeEvent(
            id: "starting-now",
            title: "Starting now",
            startOffset: 0,
            endOffset: 60
        )
        let endingNow = makeEvent(
            id: "ending-now",
            title: "Ending now",
            startOffset: -60,
            endOffset: 0
        )

        XCTAssertEqual(EventTimeline.currentEvent(in: [startingNow, endingNow], at: now), startingNow)
    }

    func testCurrentEventSelectsTheActiveEventWithTheEarliestEndDate() {
        let laterEnding = makeEvent(
            id: "later-ending",
            title: "Later ending",
            startOffset: -60,
            endOffset: 120
        )
        let earlierEnding = makeEvent(
            id: "earlier-ending",
            title: "Earlier ending",
            startOffset: -30,
            endOffset: 60
        )

        XCTAssertEqual(EventTimeline.currentEvent(in: [laterEnding, earlierEnding], at: now), earlierEnding)
    }

    func testUpcomingEventsExcludeEndedAndCurrentEventsAndSortByStartDateThenTitle() {
        let later = makeEvent(id: "later", title: "Later", startOffset: 120, endOffset: 180)
        let sameStartZ = makeEvent(id: "same-start-z", title: "Zeta", startOffset: 60, endOffset: 90)
        let sameStartA = makeEvent(id: "same-start-a", title: "Alpha", startOffset: 60, endOffset: 90)
        let current = makeEvent(id: "current", title: "Current", startOffset: -30, endOffset: 30)
        let ended = makeEvent(id: "ended", title: "Ended", startOffset: -120, endOffset: -60)

        XCTAssertEqual(
            EventTimeline.upcomingEvents(in: [later, ended, current, sameStartZ, sameStartA], at: now, limit: 10),
            [sameStartA, sameStartZ, later]
        )
    }

    func testUpcomingEventsAreCappedAtFive() {
        let events = (1...6).map { index in
            makeEvent(
                id: "event-\(index)",
                title: "Event \(index)",
                startOffset: TimeInterval(index * 60),
                endOffset: TimeInterval(index * 60 + 30)
            )
        }

        XCTAssertEqual(EventTimeline.upcomingEvents(in: events, at: now, limit: 5).map(\.id), [
            "event-1", "event-2", "event-3", "event-4", "event-5"
        ])
    }

    func testRemainingEventsReturnsEveryFutureEventInOrder() {
        let events = [
            makeEvent(id: "event-7", title: "Event 7", startOffset: 420, endOffset: 450),
            makeEvent(id: "event-6", title: "Event 6", startOffset: 360, endOffset: 390),
            makeEvent(id: "event-5", title: "Event 5", startOffset: 300, endOffset: 330),
            makeEvent(id: "event-4", title: "Event 4", startOffset: 240, endOffset: 270),
            makeEvent(id: "event-3", title: "Event 3", startOffset: 180, endOffset: 210),
            makeEvent(id: "event-2", title: "Event 2", startOffset: 120, endOffset: 150),
            makeEvent(id: "event-1", title: "Event 1", startOffset: 60, endOffset: 90),
        ]

        XCTAssertEqual(EventTimeline.remainingEvents(in: events, at: now).map(\.id), [
            "event-1", "event-2", "event-3", "event-4", "event-5", "event-6", "event-7"
        ])
    }

    func testUpcomingEventsWithNonPositiveLimitReturnEmpty() {
        let event = makeEvent(id: "event", title: "Event", startOffset: 60, endOffset: 120)

        XCTAssertTrue(EventTimeline.upcomingEvents(in: [event], at: now, limit: 0).isEmpty)
        XCTAssertTrue(EventTimeline.upcomingEvents(in: [event], at: now, limit: -1).isEmpty)
    }

    func testEmptyInputReturnsNoCurrentOrUpcomingEvents() {
        XCTAssertNil(EventTimeline.currentEvent(in: [], at: now))
        XCTAssertTrue(EventTimeline.upcomingEvents(in: [], at: now, limit: 5).isEmpty)
    }

    func testCountdownMinutesRoundsUpToTheNextWholeMinute() {
        XCTAssertEqual(EventTimeline.countdownMinutes(until: now.addingTimeInterval(61), from: now), 2)
        XCTAssertEqual(EventTimeline.countdownMinutes(until: now.addingTimeInterval(60), from: now), 1)
    }

    func testCountdownMinutesNeverReturnsNegativeValues() {
        XCTAssertEqual(EventTimeline.countdownMinutes(until: now.addingTimeInterval(-1), from: now), 0)
    }

    func testTimeRemainingUsesAtMostTwoUnits() {
        let duration = TimeInterval((24 * 60 + 2 * 60 + 3) * 60)

        XCTAssertEqual(
            TimeRemainingFormatter.string(until: now.addingTimeInterval(duration), from: now),
            "1d 2h"
        )
    }

    func testTimeRemainingConvertsMinutesToHoursAndMinutes() {
        XCTAssertEqual(
            TimeRemainingFormatter.string(until: now.addingTimeInterval(546 * 60), from: now),
            "9h 6m"
        )
    }

    func testTimeRemainingSupportsMonthsAndWeeks() {
        let fortyFourDays = TimeInterval(44 * 24 * 60 * 60)

        XCTAssertEqual(
            TimeRemainingFormatter.string(until: now.addingTimeInterval(fortyFourDays), from: now),
            "1mo 2w"
        )
    }

    func testBlankEventTitlesUseUntitledEvent() {
        let blank = makeEvent(id: "blank", title: "   ", startOffset: 0, endOffset: 60)

        XCTAssertEqual(blank.title, "Untitled event")
    }

    func testLocationsAreTrimmedAndBlankLocationsAreOmitted() {
        let located = CalendarEvent(
            id: "located",
            title: "Team Huddle",
            startDate: now,
            endDate: now.addingTimeInterval(60),
            calendarTitle: "Calendar",
            location: "  Conference Room A  "
        )
        let blank = CalendarEvent(
            id: "blank-location",
            title: "Team Huddle",
            startDate: now,
            endDate: now.addingTimeInterval(60),
            calendarTitle: "Calendar",
            location: "   "
        )

        XCTAssertEqual(located.location, "Conference Room A")
        XCTAssertNil(blank.location)
    }

    func testFullMenuBarTitleIncludesEventAndRoundedCountdown() {
        let event = makeEvent(id: "next", title: "Team Huddle", startOffset: 61, endOffset: 300)

        XCTAssertEqual(
            MenuBarTitleFormatter.title(
                mode: .full,
                currentEvent: nil,
                upcomingEvents: [event],
                now: now
            ),
            "Next: Team Huddle · 2m"
        )
    }

    func testFullMenuBarTitleAdaptsEventTitleToThirtyOneCharacters() {
        let event = makeEvent(
            id: "next",
            title: "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
            startOffset: 546 * 60,
            endOffset: 547 * 60
        )

        let title = MenuBarTitleFormatter.title(
            mode: .full,
            currentEvent: nil,
            upcomingEvents: [event],
            now: now
        )

        XCTAssertEqual(title, "Next: ABCDEFGHIJKLMNOP… · 9h 6m")
        XCTAssertEqual(title?.count, 31)
    }

    func testEventCacheRequiresReloadForFirstLoadAndNewDayOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: now)!

        XCTAssertTrue(
            EventCachePolicy.requiresReload(lastLoadedAt: nil, now: now, calendar: calendar)
        )
        XCTAssertFalse(
            EventCachePolicy.requiresReload(
                lastLoadedAt: now,
                now: now.addingTimeInterval(60),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            EventCachePolicy.requiresReload(lastLoadedAt: now, now: nextDay, calendar: calendar)
        )
    }

    func testCompactMenuBarTitleContainsOnlyCountdown() {
        let event = makeEvent(id: "next", title: "Team Huddle", startOffset: 61, endOffset: 300)

        XCTAssertEqual(
            MenuBarTitleFormatter.title(
                mode: .compact,
                currentEvent: nil,
                upcomingEvents: [event],
                now: now
            ),
            "2m"
        )
    }

    func testIconOnlyMenuBarTitleIsNil() {
        let event = makeEvent(id: "next", title: "Team Huddle", startOffset: 61, endOffset: 300)

        XCTAssertNil(
            MenuBarTitleFormatter.title(
                mode: .iconOnly,
                currentEvent: nil,
                upcomingEvents: [event],
                now: now
            )
        )
    }

    func testCompactMenuBarTitleShowsNowForActiveEventWithoutUpcomingEvent() {
        let event = makeEvent(id: "current", title: "Coding", startOffset: -60, endOffset: 300)

        XCTAssertEqual(
            MenuBarTitleFormatter.title(
                mode: .compact,
                currentEvent: event,
                upcomingEvents: [],
                now: now
            ),
            "Now"
        )
    }

    func testLaunchAtLoginMenuPresentationClearlyIdentifiesEnabledState() {
        XCTAssertEqual(LaunchAtLoginMenuPresentation.title(isEnabled: true), "Launch at Login: On")
        XCTAssertEqual(LaunchAtLoginMenuPresentation.symbolName(isEnabled: true), "checkmark.circle.fill")
    }

    func testLaunchAtLoginMenuPresentationClearlyIdentifiesDisabledState() {
        XCTAssertEqual(LaunchAtLoginMenuPresentation.title(isEnabled: false), "Launch at Login: Off")
        XCTAssertEqual(LaunchAtLoginMenuPresentation.symbolName(isEnabled: false), "circle")
    }

    func testLaunchAtLoginStateStaysOnWhenRegistrationStatusHasNotSettled() {
        XCTAssertTrue(
            LaunchAtLoginStatePolicy.displayedEnabled(
                requestedEnabled: true,
                status: .notRegistered
            )
        )
    }

    func testLaunchAtLoginStateStaysOffWhenUserDisablesIt() {
        XCTAssertFalse(
            LaunchAtLoginStatePolicy.displayedEnabled(
                requestedEnabled: false,
                status: .notRegistered
            )
        )
    }

    private func makeEvent(
        id: String,
        title: String,
        startOffset: TimeInterval,
        endOffset: TimeInterval
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: now.addingTimeInterval(startOffset),
            endDate: now.addingTimeInterval(endOffset),
            calendarTitle: "Calendar"
        )
    }
}
