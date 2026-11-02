import OSLog
import ServiceManagement

/// Open at Login, through the system's login items.
@MainActor
public struct LoginItem {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.system.error("Open at Login change failed: \(error.localizedDescription, privacy: .public)")
        }
        // Turned off earlier in System Settings: only the user can approve it again, there.
        if enabled, SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
