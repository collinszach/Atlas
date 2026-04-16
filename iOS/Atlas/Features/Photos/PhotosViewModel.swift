import Foundation

@MainActor
@Observable
final class PhotosViewModel {
    var photos: [Photo] = []
    var isLoading = false
    var isUploading = false
    var uploadProgress: Double = 0
    var error: String? = nil

    func load(tripId: String, api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            photos = try await api.listPhotos(tripId: tripId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// `uploads` is pre-loaded by the view layer from PHPicker items.
    func upload(
        tripId: String,
        uploads: [(data: Data, filename: String, mimeType: String)],
        api: APIClient
    ) async {
        guard !uploads.isEmpty else { return }
        isUploading = true
        uploadProgress = 0
        defer { isUploading = false; uploadProgress = 0 }
        for (index, item) in uploads.enumerated() {
            do {
                let photo = try await api.uploadPhoto(
                    tripId: tripId,
                    data: item.data,
                    filename: item.filename,
                    mimeType: item.mimeType
                )
                photos.append(photo)
            } catch {
                self.error = "Upload failed: \(error.localizedDescription)"
            }
            uploadProgress = Double(index + 1) / Double(uploads.count)
        }
    }

    func delete(photoId: String, api: APIClient) async {
        do {
            try await api.deletePhoto(photoId: photoId)
            photos.removeAll { $0.id == photoId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setCover(photoId: String, api: APIClient) async {
        do {
            try await api.setCoverPhoto(photoId: photoId)
            photos = photos.map {
                Photo(
                    id: $0.id, tripId: $0.tripId, destinationId: $0.destinationId,
                    originalFilename: $0.originalFilename, caption: $0.caption,
                    takenAt: $0.takenAt, latitude: $0.latitude, longitude: $0.longitude,
                    width: $0.width, height: $0.height, sizeBytes: $0.sizeBytes,
                    isCover: $0.id == photoId, orderIndex: $0.orderIndex,
                    url: $0.url, thumbnailUrl: $0.thumbnailUrl
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
