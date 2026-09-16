import Foundation

struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarColorHex: String
    let location: String?

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String,
        calendarColorHex: String = "#5E5CE6",
        location: String? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled event"
            : title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.location = trimmedLocation?.isEmpty == true ? nil : trimmedLocation
    }
}

enum EventTimeline {
    static func currentEvent(in events: [CalendarEvent], at now: Date) -> CalendarEvent? {
        events
            .filter { $0.startDate <= now && now < $0.endDate }
            .min { lhs, rhs in
                if lhs.endDate != rhs.endDate {
                    return lhs.endDate < rhs.endDate
                }
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                if lhs.title != rhs.title {
                    return lhs.title < rhs.title
                }
                return lhs.id < rhs.id
            }
    }

    static func upcomingEvents(
        in events: [CalendarEvent],
        at now: Date,
        limit: Int
    ) -> [CalendarEvent] {
        guard limit > 0 else { return [] }

        return events
            .filter { $0.startDate > now }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                if lhs.title != rhs.title {
                    return lhs.title < rhs.title
                }
                return lhs.id < rhs.id
            }
            .prefix(limit)
            .map { $0 }
    }

    static func remainingEvents(in events: [CalendarEvent], at now: Date) -> [CalendarEvent] {
        upcomingEvents(in: events, at: now, limit: .max)
    }

    static func countdownMinutes(until date: Date, from now: Date) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
    }
}

enum EventCachePolicy {
    static func requiresReload(
        lastLoadedAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let lastLoadedAt else { return true }
        return !calendar.isDate(lastLoadedAt, inSameDayAs: now)
    }
}

enum TimeRemainingFormatter {
    private static let units: [(minutes: Int, suffix: String)] = [
        (30 * 24 * 60, "mo"),
        (7 * 24 * 60, "w"),
        (24 * 60, "d"),
        (60, "h"),
        (1, "m"),
    ]

    static func string(until date: Date, from now: Date) -> String {
        var remainingMinutes = EventTimeline.countdownMinutes(until: date, from: now)
        guard remainingMinutes > 0 else { return "0m" }

        var components: [String] = []

        for unit in units {
            let value = remainingMinutes / unit.minutes
            guard value > 0 else { continue }

            components.append("\(value)\(unit.suffix)")
            remainingMinutes %= unit.minutes

            if components.count == 2 {
                break
            }
        }

        return components.joined(separator: " ")
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case full
    case compact
    case iconOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: "Full"
        case .compact: "Compact"
        case .iconOnly: "Icon Only"
        }
    }
}

enum MenuBarTitleFormatter {
    private static let maximumFullTitleLength = 31

    static func title(
        mode: MenuBarDisplayMode,
        currentEvent: CalendarEvent?,
        upcomingEvents: [CalendarEvent],
        now: Date
    ) -> String? {
        guard mode != .iconOnly else { return nil }

        if let nextEvent = upcomingEvents.first {
            let timeRemaining = TimeRemainingFormatter.string(until: nextEvent.startDate, from: now)
            switch mode {
            case .full:
                let prefix = "Next: "
                let suffix = " · \(timeRemaining)"
                let titleBudget = maximumFullTitleLength - prefix.count - suffix.count
                return prefix + truncated(nextEvent.title, maximumLength: titleBudget) + suffix
            case .compact:
                return timeRemaining
            case .iconOnly:
                return nil
            }
        }

        if let currentEvent {
            let prefix = "Now: "
            return mode == .full
                ? prefix + truncated(
                    currentEvent.title,
                    maximumLength: maximumFullTitleLength - prefix.count
                )
                : "Now"
        }

        return mode == .full ? "No more events" : nil
    }

    private static func truncated(_ title: String, maximumLength: Int) -> String {
        guard maximumLength > 1 else { return "…" }

        let characters = Array(title)
        guard characters.count > maximumLength else { return title }
        return String(characters.prefix(maximumLength - 1)) + "…"
    }
}
