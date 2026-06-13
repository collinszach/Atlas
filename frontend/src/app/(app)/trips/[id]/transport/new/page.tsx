import { PageHeader } from "@/components/ui/PageHeader";
import { TransportForm } from "@/components/trips/TransportForm";

export default function NewTransportPage({ params }: { params: { id: string } }) {
  return (
    <div className="h-full overflow-y-auto px-6 py-7 sm:px-8">
      <div className="mx-auto max-w-4xl">
        <PageHeader
          eyebrow="Log a leg"
          title="Add transport"
          description="A flight, train, drive, or ferry. Origin and destination draw the line on your map."
        />
        <TransportForm tripId={params.id} />
      </div>
    </div>
  );
}
