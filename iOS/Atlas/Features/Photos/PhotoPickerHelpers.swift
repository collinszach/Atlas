import PhotosUI
import UniformTypeIdentifiers

/// Loads PHPicker selection items as raw Data tuples for upload.
/// Defined here (not inside a view file) so TripDetailView can call it
/// without importing PhotoGridView.
func loadPickerItems(
    _ items: [PhotosPickerItem]
) async -> [(data: Data, filename: String, mimeType: String)] {
    var results: [(data: Data, filename: String, mimeType: String)] = []
    for item in items {
        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
        let contentType = item.supportedContentTypes.first ?? UTType.jpeg
        let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
        let ext = contentType.preferredFilenameExtension ?? "jpg"
        results.append((data: data, filename: "\(UUID().uuidString).\(ext)", mimeType: mimeType))
    }
    return results
}
