import SwiftUI

@main
struct BoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var configManager = ConfigurationManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                sessionManager: sessionManager,
                configManager: configManager
            )
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        // Onboarding window
        Window("Welcome to Boop", id: "onboarding") {
            OnboardingCoordinator()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Settings window
        Settings {
            SettingsView()
        }
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: menuBarIconName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(menuBarIconColor)
        }
    }

    private var menuBarIconName: String {
        switch sessionManager.overallState {
        case .paused:
            return "pause.circle.fill"
        case .disconnected:
            return "circle"
        default:
            return "circle.fill"
        }
    }

    private var menuBarIconColor: Color {
        switch sessionManager.overallState {
        case .idle:
            return .green
        case .working:
            return .blue
        case .attention:
            return .orange
        case .disconnected:
            return .gray
        case .paused:
            return .gray
        }
    }
}
