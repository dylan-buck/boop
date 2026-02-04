import SwiftUI

struct StatusIndicator: View {
    let isActive: Bool
    var activeColor: Color = .green
    var inactiveColor: Color = .red

    var body: some View {
        Circle()
            .fill(isActive ? activeColor : inactiveColor)
            .frame(width: 8, height: 8)
    }
}

struct StatusBadge: View {
    let text: String
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSuccess ? .green : .red)
            Text(text)
        }
        .font(.system(size: 13))
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            StatusIndicator(isActive: true)
            Text("Active")
        }

        HStack {
            StatusIndicator(isActive: false)
            Text("Inactive")
        }

        StatusBadge(text: "Connected", isSuccess: true)
        StatusBadge(text: "Disconnected", isSuccess: false)
    }
    .padding()
}
