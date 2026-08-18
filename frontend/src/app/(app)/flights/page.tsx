import { Suspense } from "react";
import Link from "next/link";
import { Plus } from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import { FlightListClient } from "./FlightListClient";

export default function FlightsPage() {
  return (
    <div className="h-full overflow-y-auto px-6 py-7 sm:px-8">
      <div className="mx-auto max-w-5xl">
        <PageHeader
          eyebrow="The Logbook"
          title="Flights"
          description="Every flight you've flown, logged with its route, aircraft, and details."
          actions={
            <Link
              href="/flights/new"
              className="inline-flex h-9 items-center gap-2 rounded-md bg-atlas-accent px-4 text-sm font-semibold text-atlas-bg-deep shadow-elev-1 transition-colors hover:bg-atlas-accent-hi focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-atlas-accent focus-visible:ring-offset-2 focus-visible:ring-offset-atlas-bg"
            >
              <Plus size={15} />
              Log flight
            </Link>
          }
        />
        <Suspense fallback={null}>
          <FlightListClient />
        </Suspense>
      </div>
    </div>
  );
}
