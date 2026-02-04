import Foundation
import ServiceManagement

final class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var lastError: String?

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func enable() {
        do {
            try SMAppService.mainApp.register()
            refreshStatus()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            print("Failed to enable launch at login: \(error)")
        }
    }

    func disable() {
        do {
            try SMAppService.mainApp.unregister()
            refreshStatus()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            print("Failed to disable launch at login: \(error)")
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            enable()
        } else {
            disable()
        }
    }
}
