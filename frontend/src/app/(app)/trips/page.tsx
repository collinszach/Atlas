import { Suspense } from "react";
import Link from "next/link";
import { Plus } from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import { TripListClient } from "./TripListClient";

export default function TripsPage() {
  return (
    <div className="h-full overflow-y-auto px-6 py-7 sm:px-8">
      <div className="mx-auto max-w-5xl">
        <PageHeader
          eyebrow="The Archive"
          title="Trips"
          description="Every journey you've logged, from past expeditions to plans still taking shape."
          actions={
            <Link
              href="/trips/new"
              className="inline-flex h-9 items-center gap-2 rounded-md bg-atlas-accent px-4 text-sm font-semibold text-atlas-bg-deep shadow-elev-1 transition-colors hover:bg-atlas-accent-hi focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-atlas-accent focus-visible:ring-offset-2 focus-visible:ring-offset-atlas-bg"
            >
              <Plus size={15} />
              New trip
            </Link>
          }
        />
        <Suspense fallback={null}>
          <TripListClient />
        </Suspense>
      </div>
    </div>
  );
}
