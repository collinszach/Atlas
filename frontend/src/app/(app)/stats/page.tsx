import { PageHeader } from "@/components/ui/PageHeader";
import { StatsClient } from "./StatsClient";

export default function StatsPage() {
  return (
    <div className="h-full overflow-y-auto px-6 py-7 sm:px-8">
      <div className="mx-auto max-w-5xl">
        <PageHeader
          eyebrow="The Logbook"
          title="Statistics"
          description="The shape of your travels, measured. Distances, nights, and the countries that drew you back."
        />
        <StatsClient />
      </div>
    </div>
  );
}
