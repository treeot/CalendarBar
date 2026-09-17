import Combine
import ServiceManagement

enum LaunchAtLoginMenuPresentation {
    static func title(isEnabled: Bool, requiresApproval: Bool = false) -> String {
        if requiresApproval {
            return "Launch at Login: Needs Approval"
        }

        return "Launch at Login: \(isEnabled ? "On" : "Off")"
    }

    static func symbolName(isEnabled: Bool, requiresApproval: Bool = false) -> String {
        if requiresApproval {
            return "exclamationmark.circle"
        }

        return isEnabled ? "checkmark.circle.fill" : "circle"
    }
}

enum LaunchAtLoginRegistrationStatus {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

enum LaunchAtLoginStatePolicy {
    static func displayedEnabled(
        requestedEnabled: Bool,
        status: LaunchAtLoginRegistrationStatus
    ) -> Bool {
        switch status {
        case .enabled:
            return true
        case .requiresApproval, .notRegistered, .notFound:
            return false
        }
    }
}

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    private let preferenceKey = "launchAtLoginEnabled"

    init() {
        // Launch at Login is opt-in: never register the app as a login item
        // without the user turning it on explicitly from the menu.
        isEnabled = UserDefaults.standard.bool(forKey: preferenceKey)

        Task { @MainActor [weak self] in
            self?.refreshStatus()
        }
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: preferenceKey)
        isEnabled = enabled
        errorMessage = nil

        do {
            if enabled {
                switch SMAppService.mainApp.status {
                case .notRegistered, .notFound:
                    try SMAppService.mainApp.register()
                case .enabled, .requiresApproval:
                    break
                @unknown default:
                    break
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: preferenceKey)
            errorMessage = "Couldn’t update Launch at Login: \(error.localizedDescription)"
        }

        refreshStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func refreshStatus() {
        let status = SMAppService.mainApp.status
        requiresApproval = status == .requiresApproval
        let registrationStatus: LaunchAtLoginRegistrationStatus
        switch status {
        case .enabled:
            registrationStatus = .enabled
        case .requiresApproval:
            registrationStatus = .requiresApproval
        case .notFound:
            registrationStatus = .notFound
        case .notRegistered:
            registrationStatus = .notRegistered
        @unknown default:
            registrationStatus = .notRegistered
        }

        guard errorMessage == nil else { return }
        isEnabled = LaunchAtLoginStatePolicy.displayedEnabled(
            requestedEnabled: isEnabled,
            status: registrationStatus
        )
    }
}
