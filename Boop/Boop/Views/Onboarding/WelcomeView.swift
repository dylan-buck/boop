import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            // Title
            Text("Welcome to Boop")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Description
            Text("Get notified when Claude or Codex needs you")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "bell.fill",
                    color: .orange,
                    title: "Approval notifications",
                    description: "Know instantly when AI needs your permission"
                )

                FeatureRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "Completion alerts",
                    description: "Get pinged when tasks finish"
                )

                FeatureRow(
                    icon: "iphone",
                    color: .blue,
                    title: "Push to your phone",
                    description: "Walk away and stay in the loop"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
        .frame(width: 500, height: 600)
}
