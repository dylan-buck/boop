import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var configManager: ConfigurationManager

    @State private var showingSettings = false
    @State private var hasCheckedOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Sessions list
            if sessionManager.sessions.isEmpty {
                emptyStateView
            } else {
                sessionsListView
            }

            Divider()

            // Connection status
            connectionStatusView

            Divider()

            // Footer
            footerView
        }
        .frame(width: 300)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            // Auto-open onboarding if not completed (only once per app launch)
            if !hasCheckedOnboarding && !configManager.settings.onboardingComplete {
                hasCheckedOnboarding = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    openWindow(id: "onboarding")
                }
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Boop")
                .font(.headline)

            Spacer()

            // Pause button
            Button(action: togglePause) {
                Image(systemName: configManager.settings.isPaused ? "play.fill" : "pause.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(configManager.settings.isPaused ? "Resume notifications" : "Pause notifications")

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("No active sessions")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var sessionsListView: some View {
        VStack(spacing: 0) {
            ForEach(sessionManager.sessions) { session in
                SessionRowView(session: session)

                if session.id != sessionManager.sessions.last?.id {
                    Divider()
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var connectionStatusView: some View {
        Button(action: handleConnectionTap) {
            ConnectionStatusView(
                sessionManager: sessionManager,
                configManager: configManager
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var footerView: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack {
                Text("Quit Boop")
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func togglePause() {
        configManager.settings.isPaused.toggle()
    }

    private func handleConnectionTap() {
        if !configManager.settings.onboardingComplete {
            openWindow(id: "onboarding")
        } else {
            showingSettings = true
        }
    }
}

#Preview {
    MenuBarView(
        sessionManager: SessionManager.shared,
        configManager: ConfigurationManager.shared
    )
}
