import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.atlasAccent)
            Text("Loading…")
                .font(AtlasFont.body(13))
                .foregroundStyle(Color.atlasMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.atlasBackground)
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.atlasBorder)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.atlasBorder)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.atlasBorder)
                    .frame(width: 100, height: 11)
            }
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
    }
}
