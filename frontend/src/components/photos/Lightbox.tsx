"use client";

import YARLightbox from "yet-another-react-lightbox";
import "yet-another-react-lightbox/styles.css";
import Captions from "yet-another-react-lightbox/plugins/captions";
import "yet-another-react-lightbox/plugins/captions.css";
import type { Photo } from "@/types";

interface Props {
  photos: Photo[];
  open: boolean;
  index: number;
  onClose: () => void;
}

export default function Lightbox({ photos, open, index, onClose }: Props) {
  const slides = photos.map((p) => ({
    src: p.url,
    alt: p.caption ?? p.original_filename ?? "Photo",
    description: p.caption ?? undefined,
    width: p.width ?? undefined,
    height: p.height ?? undefined,
  }));

  return (
    <YARLightbox
      open={open}
      close={onClose}
      index={index}
      slides={slides}
      plugins={[Captions]}
      styles={{
        container: { backgroundColor: "rgba(10, 14, 26, 0.97)" },
      }}
    />
  );
}
