import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var manager: CalendarManager
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @Binding var displayMode: MenuBarDisplayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            authorizationContent
            footer
        }
        .padding(16)
        .frame(width: 360)
        .background(.regularMaterial)
        .onAppear {
            manager.refresh()
            launchAtLogin.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            manager.refresh()
            launchAtLogin.refreshStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.tint)

            Text("CalendarBar")
                .font(.title3.weight(.semibold))

            Spacer()

            Menu {
                Picker("Menu Bar Display", selection: $displayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Divider()

                Button {
                    launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
                } label: {
                    Label(
                        LaunchAtLoginMenuPresentation.title(
                            isEnabled: launchAtLogin.isEnabled,
                            requiresApproval: launchAtLogin.requiresApproval
                        ),
                        systemImage: LaunchAtLoginMenuPresentation.symbolName(
                            isEnabled: launchAtLogin.isEnabled,
                            requiresApproval: launchAtLogin.requiresApproval
                        )
                    )
                }

                if launchAtLogin.requiresApproval {
                    Button("Approve in Login Items…") {
                        launchAtLogin.openLoginItemsSettings()
                    }
                }

                if let loginError = launchAtLogin.errorMessage {
                    Text(loginError)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Settings")
        }
        .padding(.bottom, 16)
        .frame(width: 328, alignment: .leading)
    }

    @ViewBuilder
    private var authorizationContent: some View {
        switch manager.authorizationState {
        case .notDetermined:
            statusAction("Grant Calendar Access", systemImage: "checkmark.shield") {
                manager.requestAccessAndStart()
            }

        case .requesting:
            statusText("Requesting Calendar Access…")

        case .authorized:
            eventSections

        case .denied:
            statusAction("Open Calendar Privacy Settings…", systemImage: "gear") {
                manager.openCalendarPrivacySettings()
            }

        case .restricted:
            statusText("Calendar access is restricted")

        case .failed:
            VStack(alignment: .leading, spacing: 8) {
                statusText(manager.errorMessage ?? "Calendar access failed")
                statusAction("Try Again", systemImage: "arrow.clockwise") {
                    manager.requestAccessAndStart()
                }
            }
        }
    }

    private var eventSections: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Now")
            if let currentEvent = manager.currentEvent {
                eventRow(currentEvent, isCurrent: true)
            } else {
                statusText("No event in progress")
            }

            sectionTitle("Upcoming events")
            if manager.upcomingEvents.isEmpty {
                statusText("No upcoming events")
            } else {
                ForEach(manager.upcomingEvents) { event in
                    eventRow(event, isCurrent: false)
                }
            }

            if let errorMessage = manager.errorMessage {
                statusText(errorMessage)
                statusAction("Try Again", systemImage: "arrow.clockwise") {
                    manager.refresh()
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 12)

            HStack(spacing: 8) {
                Button {
                    manager.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func eventRow(_ event: CalendarEvent, isCurrent: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if isCurrent {
                CurrentEventView(event: event)
            } else {
                UpcomingEventRow(event: event)
            }

            eventActionsMenu(for: event)
                .padding(.top, isCurrent ? 8 : 3)
        }
        .padding(.leading, isCurrent ? 12 : 0)
        .padding(.trailing, 12)
        .padding(.vertical, isCurrent ? 12 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
            }
        }
    }

    private func eventActionsMenu(for event: CalendarEvent) -> some View {
        Menu {
            Button {
                manager.openInCalendar()
            } label: {
                Label("Open in Calendar", systemImage: "calendar")
            }

            Button {
                manager.copyTitle(of: event)
            } label: {
                Label("Copy Event Title", systemImage: "doc.on.doc")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 24, alignment: .trailing)
        .help("Event actions")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func statusAction(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.borderless)
    }
}
