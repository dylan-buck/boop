import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sessionManager: SessionManager!
    private var configManager: ConfigurationManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize managers
        configManager = ConfigurationManager.shared
        sessionManager = SessionManager.shared

        // Ensure app directory exists
        do {
            try configManager.ensureDirectoryExists()
        } catch {
            print("Failed to create app directory: \(error)")
        }

        // Set up launch at login based on settings
        if configManager.settings.launchAtLogin {
            LaunchAtLoginService.shared.enable()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up socket server
        sessionManager.stopSocketServer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps should not quit when windows are closed
        return false
    }
}
