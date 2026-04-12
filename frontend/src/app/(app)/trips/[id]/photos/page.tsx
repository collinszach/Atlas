"use client";

import { useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useTrip } from "@/hooks/useTrips";
import { usePhotos, useUploadPhotos, useDeletePhoto, useSetCoverPhoto } from "@/hooks/usePhotos";
import PhotoGrid from "@/components/photos/PhotoGrid";
import PhotoUploader from "@/components/photos/PhotoUploader";
import Lightbox from "@/components/photos/Lightbox";

export default function TripPhotosPage() {
  const { id } = useParams<{ id: string }>();
  const { data: trip } = useTrip(id);
  const { data: photoData, isLoading } = usePhotos(id);
  const uploadMutation = useUploadPhotos(id);
  const deleteMutation = useDeletePhoto(id);
  const setCoverMutation = useSetCoverPhoto(id);

  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);

  const photos = photoData?.items ?? [];

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-5xl mx-auto">
        <div className="mb-6">
          <Link href={`/trips/${id}`} className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block">
            ← {trip?.title ?? "Trip"}
          </Link>
          <h1 className="font-display text-2xl font-semibold text-atlas-text">Photos</h1>
          <p className="text-xs text-atlas-muted mt-1">
            {photos.length} photo{photos.length !== 1 ? "s" : ""}
          </p>
        </div>

        <div className="mb-6">
          <PhotoUploader uploadMutation={uploadMutation} />
        </div>

        {isLoading ? (
          <p className="text-atlas-muted text-sm">Loading photos...</p>
        ) : (
          <PhotoGrid
            photos={photos}
            onPhotoClick={(index) => setLightboxIndex(index)}
            onSetCover={(photoId) => setCoverMutation.mutate(photoId)}
            onDelete={(photoId) => deleteMutation.mutate(photoId)}
          />
        )}

        <Lightbox
          photos={photos}
          open={lightboxIndex !== null}
          index={lightboxIndex ?? 0}
          onClose={() => setLightboxIndex(null)}
        />
      </div>
    </div>
  );
}
