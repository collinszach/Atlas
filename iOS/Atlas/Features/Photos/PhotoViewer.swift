import SwiftUI

struct PhotoViewer: View {
    let photos: [Photo]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0

    init(photos: [Photo], startIndex: Int) {
        self.photos = photos
        self.startIndex = startIndex
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZoomablePhotoPage(
                        photo: photo,
                        scale: index == currentIndex ? scale * magnifyBy : 1,
                        offset: index == currentIndex ? offset : .zero
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { value, state, _ in state = value }
                        .onEnded { value in
                            scale = min(max(scale * value, 1.0), 5.0)
                            if scale <= 1.0 { offset = .zero }
                        },
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1 else { return }
                            offset = value.translation
                        }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1 { scale = 1; offset = .zero }
                    else { scale = 2.5 }
                }
            }

            overlays
        }
        .onChange(of: currentIndex) { _, _ in
            scale = 1
            offset = .zero
        }
    }

    @ViewBuilder
    private var overlays: some View {
        VStack {
            // Top: counter + close
            HStack {
                Spacer()
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(AtlasFont.mono(13))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(
                LinearGradient(colors: [.black.opacity(0.5), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )

            Spacer()

            // Bottom: caption + date
            if let photo = photos[safe: currentIndex],
               photo.caption != nil || photo.takenAt != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let caption = photo.caption, !caption.isEmpty {
                        Text(caption)
                            .font(AtlasFont.body(14))
                            .foregroundStyle(.white)
                    }
                    if let takenAt = photo.takenAt {
                        Text(formatDate(takenAt))
                            .font(AtlasFont.mono(12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ] {
            formatter.formatOptions = options
            if let date = formatter.date(from: iso) {
                let display = DateFormatter()
                display.dateFormat = "MMM d, yyyy"
                return display.string(from: date)
            }
        }
        return String(iso.prefix(10))
    }
}

private struct ZoomablePhotoPage: View {
    let photo: Photo
    let scale: CGFloat
    let offset: CGSize

    var body: some View {
        AsyncImage(url: URL(string: photo.url)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
            case .failure:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.white.opacity(0.4))
            default:
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
