import Foundation

final class DNDChecker {
    static let shared = DNDChecker()

    private init() {}

    var isDoNotDisturbEnabled: Bool {
        // Check Focus mode state via user defaults
        // This uses the NSDoNotDisturbEnabled key in com.apple.notificationcenterui
        let notificationCenterDefaults = UserDefaults(suiteName: "com.apple.notificationcenterui")
        return notificationCenterDefaults?.bool(forKey: "doNotDisturb") ?? false
    }

    func checkAndWarn() -> Bool {
        if isDoNotDisturbEnabled {
            print("Do Not Disturb is enabled - notifications may be silenced on this Mac")
            return true
        }
        return false
    }
}
