"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useTrip } from "@/hooks/useTrips";
import { AccommodationForm } from "@/components/trips/AccommodationForm";

export default function NewAccommodationPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { data: trip } = useTrip(id);

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <Link
          href={`/trips/${id}`}
          className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block"
        >
          ← {trip?.title ?? "Trip"}
        </Link>
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-6">
          Add accommodation
        </h1>
        <AccommodationForm tripId={id} onSuccess={() => router.push(`/trips/${id}`)} />
      </div>
    </div>
  );
}
