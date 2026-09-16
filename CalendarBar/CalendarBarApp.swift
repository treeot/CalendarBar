import SwiftUI

@main
@MainActor
struct CalendarBarApp: App {
    @StateObject private var manager: CalendarManager
    @StateObject private var launchAtLogin: LaunchAtLoginManager
    @AppStorage("menuBarDisplayMode") private var displayModeRawValue = MenuBarDisplayMode.compact.rawValue

    init() {
        let manager = CalendarManager()
        _manager = StateObject(wrappedValue: manager)
        _launchAtLogin = StateObject(wrappedValue: LaunchAtLoginManager())
        manager.requestAccessAndStart()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                manager: manager,
                launchAtLogin: launchAtLogin,
                displayMode: displayModeBinding
            )
        } label: {
            if let title = manager.menuBarTitle(for: displayMode) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(title)
                        .lineLimit(1)
                }
                .fixedSize()
            } else {
                Image(systemName: "calendar")
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var displayMode: MenuBarDisplayMode {
        MenuBarDisplayMode(rawValue: displayModeRawValue) ?? .compact
    }

    private var displayModeBinding: Binding<MenuBarDisplayMode> {
        Binding(
            get: { displayMode },
            set: { displayModeRawValue = $0.rawValue }
        )
    }
}
