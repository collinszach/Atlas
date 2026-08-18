"use client";

import { useRouter } from "next/navigation";
import { FlightForm } from "@/components/flights/FlightForm";

export default function NewFlightPage() {
  const router = useRouter();

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-6">Log flight</h1>
        <FlightForm onSuccess={(flightId) => router.push(`/flights/${flightId}`)} />
      </div>
    </div>
  );
}
