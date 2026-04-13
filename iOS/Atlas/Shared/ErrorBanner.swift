import SwiftUI

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))
            Text(message)
                .font(AtlasFont.body(13))
                .foregroundStyle(Color.atlasText)
                .lineLimit(2)
            Spacer()
            if let retry {
                Button("Retry", action: retry)
                    .font(AtlasFont.body(12, weight: .medium))
                    .foregroundStyle(Color.atlasAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#1F0A0A"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}
