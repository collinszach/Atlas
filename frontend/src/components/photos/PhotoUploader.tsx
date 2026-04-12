"use client";

import { useCallback, useRef, useState } from "react";
import { Upload } from "lucide-react";
import type { UseMutationResult } from "@tanstack/react-query";
import type { Photo } from "@/types";

interface Props {
  uploadMutation: UseMutationResult<Photo[], Error, File[]>;
}

export default function PhotoUploader({ uploadMutation }: Props) {
  const [isDragOver, setIsDragOver] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFiles = useCallback(
    (files: FileList | null) => {
      if (!files || files.length === 0) return;
      const accepted = Array.from(files).filter((f) =>
        ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"].includes(f.type)
      );
      if (accepted.length > 0) {
        uploadMutation.mutate(accepted);
      }
    },
    [uploadMutation]
  );

  const onDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragOver(false);
      handleFiles(e.dataTransfer.files);
    },
    [handleFiles]
  );

  return (
    <div
      onDrop={onDrop}
      onDragOver={(e) => { e.preventDefault(); setIsDragOver(true); }}
      onDragLeave={() => setIsDragOver(false)}
      onClick={() => inputRef.current?.click()}
      className={`
        flex flex-col items-center justify-center gap-3 p-8 rounded-lg border-2 border-dashed cursor-pointer transition-colors
        ${isDragOver
          ? "border-atlas-accent bg-atlas-accent/5"
          : "border-atlas-border hover:border-atlas-accent/50 bg-atlas-surface"
        }
      `}
    >
      <input
        ref={inputRef}
        type="file"
        multiple
        accept="image/jpeg,image/png,image/webp,image/heic,image/heif"
        className="hidden"
        onChange={(e) => handleFiles(e.target.files)}
      />
      <Upload size={20} className="text-atlas-muted" />
      {uploadMutation.isPending ? (
        <p className="text-sm text-atlas-accent">Uploading...</p>
      ) : (
        <>
          <p className="text-sm text-atlas-text">Drag & drop photos here</p>
          <p className="text-xs text-atlas-muted">or click to select — JPEG, PNG, WEBP, HEIC</p>
        </>
      )}
      {uploadMutation.isError && (
        <p className="text-xs text-red-400">{uploadMutation.error?.message ?? "Upload failed"}</p>
      )}
    </div>
  );
}
