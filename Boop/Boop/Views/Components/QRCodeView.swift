import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 200

    private var qrCodeImage: NSImage? {
        generateQRCode(from: content)
    }

    var body: some View {
        if let image = qrCodeImage {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: size, height: size)
                .overlay(
                    Text("QR Code")
                        .foregroundColor(.secondary)
                )
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        // Scale up the QR code for better quality
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}

#Preview {
    VStack(spacing: 20) {
        QRCodeView(content: "https://ntfy.sh/boop-test123")

        QRCodeView(content: "https://ntfy.sh/boop-abcdefghij123456", size: 150)
    }
    .padding()
}
