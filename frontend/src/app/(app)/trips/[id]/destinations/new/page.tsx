import { DestinationForm } from "@/components/trips/DestinationForm";

export default function NewDestinationPage({ params }: { params: { id: string } }) {
  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-6">Add Destination</h1>
        <DestinationForm tripId={params.id} />
      </div>
    </div>
  );
}
