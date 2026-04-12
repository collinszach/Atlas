"use client";

import Image from "next/image";
import { Star, Trash2 } from "lucide-react";
import type { Photo } from "@/types";

interface Props {
  photos: Photo[];
  onPhotoClick: (index: number) => void;
  onSetCover: (photoId: string) => void;
  onDelete: (photoId: string) => void;
}

export default function PhotoGrid({ photos, onPhotoClick, onSetCover, onDelete }: Props) {
  if (photos.length === 0) {
    return (
      <p className="text-atlas-muted text-sm py-8 text-center border border-dashed border-atlas-border rounded-lg">
        No photos yet. Upload some to start your visual journal.
      </p>
    );
  }

  return (
    <div className="columns-2 sm:columns-3 lg:columns-4 gap-2 space-y-2">
      {photos.map((photo, index) => (
        <div
          key={photo.id}
          className="relative group break-inside-avoid overflow-hidden rounded-lg border border-atlas-border bg-atlas-surface cursor-pointer"
          onClick={() => onPhotoClick(index)}
        >
          <Image
            src={photo.thumbnail_url ?? photo.url}
            alt={photo.caption ?? photo.original_filename ?? "Photo"}
            width={photo.width ?? 400}
            height={photo.height ?? 300}
            className="w-full h-auto object-cover transition-opacity group-hover:opacity-80"
            unoptimized
          />

          {photo.is_cover && (
            <span className="absolute top-2 left-2 bg-atlas-accent text-atlas-bg text-xs font-mono px-1.5 py-0.5 rounded">
              Cover
            </span>
          )}

          <div
            className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => onSetCover(photo.id)}
              className="p-1 rounded bg-atlas-bg/80 text-atlas-accent hover:bg-atlas-bg transition-colors"
              title="Set as cover"
            >
              <Star size={12} />
            </button>
            <button
              onClick={() => onDelete(photo.id)}
              className="p-1 rounded bg-atlas-bg/80 text-red-400 hover:bg-atlas-bg transition-colors"
              title="Delete photo"
            >
              <Trash2 size={12} />
            </button>
          </div>

          {photo.caption && (
            <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-atlas-bg/90 to-transparent px-2 py-2 opacity-0 group-hover:opacity-100 transition-opacity">
              <p className="text-xs text-atlas-text truncate">{photo.caption}</p>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
