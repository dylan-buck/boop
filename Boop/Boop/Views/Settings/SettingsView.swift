import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var configManager = ConfigurationManager.shared
    @ObservedObject var shellService = ShellIntegrationService.shared
    @ObservedObject var launchService = LaunchAtLoginService.shared
    @ObservedObject var notificationDispatcher = NotificationDispatcher.shared

    @State private var showingQRCode = false
    @State private var testNotificationResult: Bool?
    @State private var showingResetConfirmation = false
    @State private var copiedTopic = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Boop Settings")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    phoneNotificationsSection
                    notifyWhenSection
                    monitoredToolsSection
                    shellIntegrationSection
                    generalSection
                    developerSection
                    aboutSection
                }
                .padding()
            }
        }
        .frame(width: 450, height: 600)
        .sheet(isPresented: $showingQRCode) {
            qrCodeSheet
        }
    }

    // MARK: - Notification Channel Section

    private var phoneNotificationsSection: some View {
        SettingsSection(title: "NOTIFICATION CHANNEL") {
            VStack(alignment: .leading, spacing: 12) {
                // Status
                HStack {
                    Image(systemName: notificationDispatcher.connectionHealthy ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(notificationDispatcher.connectionHealthy ? .green : .orange)
                    Text(notificationDispatcher.connectionHealthy ? "ntfy server reachable" : "Checking ntfy...")
                        .foregroundColor(.secondary)
                }

                // Topic with copy button
                HStack {
                    Text("Topic:")
                        .foregroundColor(.secondary)
                    Text(configManager.settings.ntfy.topic)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Button(action: copyTopic) {
                        Image(systemName: copiedTopic ? "checkmark" : "doc.on.doc")
                            .foregroundColor(copiedTopic ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy topic to clipboard")
                }

                // Actions
                HStack(spacing: 12) {
                    Button("Show QR Code") {
                        showingQRCode = true
                    }

                    Button("Send Test") {
                        sendTestNotification()
                    }
                    .disabled(notificationDispatcher.isTestingConnection)
                }

                // Test result
                if let result = testNotificationResult {
                    HStack {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result ? .green : .red)
                        Text(result ? "Sent! Check your phone." : "Failed to send")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 12))
                }

                Divider()

                // Explanation
                Text("Scan the QR code on any device to receive notifications. Multiple devices can subscribe to the same channel.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Reset button
                Button("Reset Channel") {
                    showingResetConfirmation = true
                }
                .foregroundColor(.red)

                Text("Generates a new topic. All devices must re-scan.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .alert("Reset Notification Channel?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                configManager.regenerateTopic()
            }
        } message: {
            Text("This will generate a new topic. All devices will need to re-scan the QR code to receive notifications.")
        }
    }

    // MARK: - Notify When Section

    private var notifyWhenSection: some View {
        SettingsSection(title: "NOTIFY WHEN") {
            VStack(spacing: 12) {
                notificationToggleRow(
                    title: "Approval needed",
                    isOn: $configManager.settings.notifications.approval.enabled,
                    priority: $configManager.settings.notifications.approval.priority
                )

                notificationToggleRow(
                    title: "Task completed",
                    isOn: $configManager.settings.notifications.completed.enabled,
                    priority: $configManager.settings.notifications.completed.priority
                )

                notificationToggleRow(
                    title: "Errors",
                    isOn: $configManager.settings.notifications.error.enabled,
                    priority: $configManager.settings.notifications.error.priority
                )
            }
        }
    }

    private func notificationToggleRow(
        title: String,
        isOn: Binding<Bool>,
        priority: Binding<NotificationPriority>
    ) -> some View {
        HStack {
            Toggle(title, isOn: isOn)

            Spacer()

            Text("Priority:")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            Picker("", selection: priority) {
                ForEach(NotificationPriority.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
    }

    // MARK: - Monitored Tools Section

    private var monitoredToolsSection: some View {
        SettingsSection(title: "MONITORED TOOLS") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Claude Code CLI", isOn: $configManager.settings.tools.claude)
                Toggle("Codex CLI", isOn: $configManager.settings.tools.codex)
            }
        }
    }

    // MARK: - Shell Integration Section

    private var shellIntegrationSection: some View {
        SettingsSection(title: "SHELL INTEGRATION") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    statusIcon(for: shellService.status)
                    Text(statusText(for: shellService.status))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Location:")
                        .foregroundColor(.secondary)
                    Text("~/.\(shellService.detectedShell.rawValue)rc")
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 12) {
                    Button("Reinstall Hook") {
                        try? shellService.installHooks()
                    }

                    Button("Uninstall Hook") {
                        try? shellService.uninstallHooks()
                    }
                }
            }
        }
    }

    private func statusIcon(for status: ShellIntegrationStatus) -> some View {
        switch status {
        case .installed:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .notInstalled:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .partial:
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
        case .missingBinary:
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case .error:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }

    private func statusText(for status: ShellIntegrationStatus) -> String {
        switch status {
        case .installed:
            return "Installed"
        case .notInstalled:
            return "Not installed"
        case .partial(let installed, _):
            return "Partially installed (\(installed.map(\.rawValue).joined(separator: ", ")))"
        case .missingBinary:
            return "Missing boop-pty binary"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        SettingsSection(title: "GENERAL") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchService.isEnabled },
                    set: { newValue in
                        launchService.setEnabled(newValue)
                        configManager.settings.launchAtLogin = newValue
                    }
                ))

                Toggle("Respect Do Not Disturb", isOn: $configManager.settings.respectDND)

                HStack {
                    Text("Quiet hours:")
                        .foregroundColor(.secondary)

                    Picker("", selection: $configManager.settings.quietHours.enabled) {
                        Text("Off").tag(false)
                        Text("On").tag(true)
                    }
                    .labelsHidden()
                    .frame(width: 80)

                    if configManager.settings.quietHours.enabled {
                        TextField("", text: $configManager.settings.quietHours.start)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)

                        Text("to")
                            .foregroundColor(.secondary)

                        TextField("", text: $configManager.settings.quietHours.end)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    // MARK: - Developer Section

    #if DEBUG
    private var developerSection: some View {
        SettingsSection(title: "DEVELOPER") {
            VStack(alignment: .leading, spacing: 8) {
                Button("Reset Onboarding") {
                    configManager.settings.onboardingComplete = false
                    NSApplication.shared.terminate(nil)
                }

                Text("App will quit. Relaunch to see onboarding.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
    #else
    private var developerSection: some View {
        EmptyView()
    }
    #endif

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Boop v1.0.0")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                Spacer()

                Link("GitHub", destination: URL(string: "https://github.com/your-repo/boop")!)
                    .font(.system(size: 12))

                Text("·")
                    .foregroundColor(.secondary)

                Link("Report Issue", destination: URL(string: "https://github.com/your-repo/boop/issues")!)
                    .font(.system(size: 12))
            }
        }
    }

    // MARK: - QR Code Sheet

    private var qrCodeSheet: some View {
        VStack(spacing: 20) {
            Text("Scan in ntfy app")
                .font(.headline)

            QRCodeView(content: configManager.settings.ntfySubscribeURL)
                .frame(width: 200, height: 200)

            Text(configManager.settings.ntfy.topic)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            Button("Done") {
                showingQRCode = false
            }
        }
        .padding(40)
    }

    // MARK: - Actions

    private func sendTestNotification() {
        testNotificationResult = nil
        Task {
            let result = await notificationDispatcher.sendTestNotification()
            await MainActor.run {
                testNotificationResult = result
            }
        }
    }

    private func copyTopic() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configManager.settings.ntfy.topic, forType: .string)
        copiedTopic = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedTopic = false
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            GroupBox {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    SettingsView()
}
