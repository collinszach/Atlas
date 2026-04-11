import { TripForm } from "@/components/trips/TripForm";

export default function NewTripPage() {
  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-6">New Trip</h1>
        <TripForm />
      </div>
    </div>
  );
}
