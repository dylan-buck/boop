import SwiftUI

struct PhoneSetupView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    @ObservedObject var configManager = ConfigurationManager.shared
    @ObservedObject var notificationDispatcher = NotificationDispatcher.shared

    @State private var testResult: Bool?
    @State private var isTesting = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Connect Your iPhone")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Instructions
            VStack(alignment: .leading, spacing: 20) {
                InstructionStep(
                    number: 1,
                    title: "Install \"ntfy\" from the App Store",
                    action: {
                        Button("Open App Store") {
                            openAppStore()
                        }
                    }
                )

                InstructionStep(
                    number: 2,
                    title: "Scan this QR code in the ntfy app",
                    action: { EmptyView() }
                )
            }
            .padding(.horizontal, 40)

            // QR Code
            VStack(spacing: 12) {
                QRCodeView(content: configManager.settings.ntfySubscribeURL, size: 180)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)

                Text("Topic: \(configManager.settings.ntfy.topic)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            // Test button
            VStack(spacing: 8) {
                Button(action: sendTest) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Send Test Notification")
                    }
                    .frame(width: 200)
                }
                .disabled(isTesting)

                if let result = testResult {
                    HStack {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result ? .green : .red)
                        Text(result ? "Check your phone!" : "Failed to send")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Navigation buttons
            HStack {
                Button("Back") {
                    onBack()
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/ntfy/id1625396347") {
            NSWorkspace.shared.open(url)
        }
    }

    private func sendTest() {
        testResult = nil
        isTesting = true

        Task {
            let result = await notificationDispatcher.sendTestNotification()
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }
}

struct InstructionStep<Action: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                action()
            }
        }
    }
}

#Preview {
    PhoneSetupView(onContinue: {}, onBack: {})
        .frame(width: 500, height: 650)
}
