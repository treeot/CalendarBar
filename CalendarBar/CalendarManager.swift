import AppKit
import Combine
import EventKit
import Foundation

enum CalendarAuthorizationState: Equatable {
    case notDetermined
    case requesting
    case authorized
    case denied
    case restricted
    case failed
}

enum CalendarAuthorizationStatePolicy {
    static func state(for status: EKAuthorizationStatus) -> CalendarAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized, .fullAccess:
            return .authorized
        case .writeOnly:
            // CalendarBar only reads events, so write-only access is unusable.
            return .denied
        @unknown default:
            return .denied
        }
    }
}

@MainActor
final class CalendarManager: ObservableObject {
    @Published private(set) var authorizationState: CalendarAuthorizationState = .notDetermined
    @Published private(set) var currentEvent: CalendarEvent?
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var now = Date()

    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    private var eventStoreChangedObserver: NSObjectProtocol?
    private var cachedEvents: [CalendarEvent] = []
    private var eventsLoadedAt: Date?

    deinit {
        refreshTimer?.invalidate()
        if let eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(eventStoreChangedObserver)
        }
    }

    func requestAccessAndStart() {
        let state = CalendarAuthorizationStatePolicy.state(
            for: EKEventStore.authorizationStatus(for: .event)
        )

        switch state {
        case .notDetermined:
            guard authorizationState != .requesting else { return }

            authorizationState = .requesting
            errorMessage = nil

            Task { @MainActor [weak self] in
                guard let self else { return }

                do {
                    let granted = try await self.eventStore.requestFullAccessToEvents()
                    self.finishAuthorization(granted: granted)
                } catch {
                    self.authorizationRequestFailed()
                }
            }

        case .authorized:
            beginAuthorizedUpdates()

        case .denied:
            setAuthorizationState(.denied)

        case .restricted:
            setAuthorizationState(.restricted)

        case .requesting:
            // This is an app-level state and is not returned by EventKit.
            break

        case .failed:
            // Re-checking EventKit above makes a retry possible after a failure.
            break
        }
    }

    func refresh() {
        let state = CalendarAuthorizationStatePolicy.state(
            for: EKEventStore.authorizationStatus(for: .event)
        )

        guard state == .authorized else {
            if authorizationState != .requesting {
                setAuthorizationState(state)
            }
            return
        }

        if authorizationState != .authorized {
            beginAuthorizedUpdates()
            return
        }

        reloadEvents(at: Date())
    }

    private func reloadEvents(at currentDate: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: currentDate)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            cachedEvents = []
            eventsLoadedAt = nil
            currentEvent = nil
            upcomingEvents = []
            errorMessage = "Unable to determine the current calendar day."
            return
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: startOfNextDay,
            calendars: nil
        )

        cachedEvents = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .enumerated()
            .compactMap { index, event in
                CalendarEvent(event: event, fallbackDisambiguator: index)
            }
        eventsLoadedAt = currentDate
        errorMessage = nil
        updateTimeline(at: currentDate)
    }

    private func updateTimeline(at currentDate: Date) {
        now = currentDate
        currentEvent = EventTimeline.currentEvent(in: cachedEvents, at: currentDate)
        upcomingEvents = EventTimeline.remainingEvents(in: cachedEvents, at: currentDate)
    }

    private func handleTimerTick() {
        guard authorizationState == .authorized else { return }

        let currentDate = Date()
        if EventCachePolicy.requiresReload(lastLoadedAt: eventsLoadedAt, now: currentDate) {
            refresh()
        } else {
            updateTimeline(at: currentDate)
        }
    }

    func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func menuBarTitle(for mode: MenuBarDisplayMode) -> String? {
        guard authorizationState == .authorized, errorMessage == nil else {
            return mode == .full ? "CalendarBar" : nil
        }

        return MenuBarTitleFormatter.title(
            mode: mode,
            currentEvent: currentEvent,
            upcomingEvents: upcomingEvents,
            now: now
        )
    }

    func openInCalendar() {
        guard let calendarURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else {
            return
        }

        NSWorkspace.shared.openApplication(
            at: calendarURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func copyTitle(of event: CalendarEvent) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(event.title, forType: .string)
    }

    private func finishAuthorization(granted: Bool) {
        if granted {
            beginAuthorizedUpdates()
        } else {
            setAuthorizationState(.denied)
        }
    }

    private func authorizationRequestFailed() {
        authorizationState = .failed
        clearTimeline()
        errorMessage = "Couldn’t request Calendar access. Try again or open System Settings."
        stopLiveUpdates()
    }

    private func beginAuthorizedUpdates() {
        authorizationState = .authorized
        errorMessage = nil
        installLiveUpdatesIfNeeded()
        refresh()
    }

    private func setAuthorizationState(_ state: CalendarAuthorizationState) {
        authorizationState = state
        clearTimeline()
        if state != .authorized {
            stopLiveUpdates()
        }
    }

    private func clearTimeline() {
        cachedEvents = []
        eventsLoadedAt = nil
        currentEvent = nil
        upcomingEvents = []
    }

    private func installLiveUpdatesIfNeeded() {
        if refreshTimer == nil {
            let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleTimerTick()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }

        if eventStoreChangedObserver == nil {
            eventStoreChangedObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: eventStore,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }
    }

    private func stopLiveUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        if let eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(eventStoreChangedObserver)
            self.eventStoreChangedObserver = nil
        }
    }

}

private extension CalendarEvent {
    init?(event: EKEvent, fallbackDisambiguator: Int) {
        guard let startDate = event.startDate, let endDate = event.endDate else {
            return nil
        }

        let fallbackID = CalendarEvent.fallbackID(
            title: event.title ?? "",
            startDate: startDate,
            endDate: endDate,
            calendarTitle: event.calendar?.title ?? "Calendar",
            disambiguator: fallbackDisambiguator
        )
        let color: NSColor?
        if let calendar = event.calendar,
           let calendarColor = NSColor(cgColor: calendar.cgColor) {
            color = calendarColor.usingColorSpace(.deviceRGB)
        } else {
            color = nil
        }
        let colorHex: String
        if let color {
            colorHex = String(
                format: "#%02X%02X%02X",
                Int(round(color.redComponent * 255)),
                Int(round(color.greenComponent * 255)),
                Int(round(color.blueComponent * 255))
            )
        } else {
            colorHex = "#5E5CE6"
        }

        self.init(
            id: event.eventIdentifier ?? fallbackID,
            title: event.title ?? "",
            startDate: startDate,
            endDate: endDate,
            calendarTitle: event.calendar?.title ?? "Calendar",
            calendarColorHex: colorHex,
            location: event.location
        )
    }
}
