"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { useAddTransport } from "@/hooks/useTransport";

const schema = z.object({
  type: z.enum(["flight", "car", "train", "ferry", "bus", "walk", "other"]),
  flight_number: z.string().optional(),
  airline: z.string().optional(),
  origin_iata: z.string().length(3, "3-letter IATA code").toUpperCase().optional().or(z.literal("")),
  dest_iata: z.string().length(3, "3-letter IATA code").toUpperCase().optional().or(z.literal("")),
  origin_city: z.string().optional(),
  dest_city: z.string().optional(),
  departure_at: z.string().optional(),
  arrival_at: z.string().optional(),
  duration_min: z.coerce.number().optional().or(z.literal("")),
  distance_km: z.coerce.number().optional().or(z.literal("")),
  seat_class: z.string().optional(),
  booking_ref: z.string().optional(),
  cost: z.coerce.number().optional().or(z.literal("")),
  currency: z.string().max(3).default("USD"),
  notes: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export function TransportForm({
  tripId,
  onSuccess,
}: {
  tripId: string;
  onSuccess?: () => void;
}) {
  const { mutateAsync: addTransport, isPending } = useAddTransport(tripId);

  const {
    register,
    handleSubmit,
    formState: { errors },
    watch,
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { type: "flight", currency: "USD" } });

  const transportType = watch("type");

  const onSubmit = async (data: FormValues) => {
    const payload = {
      ...data,
      origin_iata: data.origin_iata === "" ? undefined : data.origin_iata,
      dest_iata: data.dest_iata === "" ? undefined : data.dest_iata,
      duration_min: data.duration_min === "" ? undefined : data.duration_min,
      distance_km: data.distance_km === "" ? undefined : data.distance_km,
      cost: data.cost === "" ? undefined : data.cost,
    };
    await addTransport(payload);
    onSuccess?.();
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 max-w-lg">
      <div>
        <label className="block text-xs font-semibold text-atlas-text mb-2">Transport type</label>
        <select
          {...register("type")}
          className="w-full px-3 py-2 rounded border border-atlas-border bg-atlas-surface text-atlas-text text-sm"
        >
          <option value="flight">Flight</option>
          <option value="car">Car</option>
          <option value="train">Train</option>
          <option value="ferry">Ferry</option>
          <option value="bus">Bus</option>
          <option value="walk">Walk</option>
          <option value="other">Other</option>
        </select>
      </div>

      {transportType === "flight" && (
        <>
          <div className="grid grid-cols-2 gap-4">
            <Input label="Flight number" placeholder="AA123" {...register("flight_number")} />
            <Input label="Airline" placeholder="American Airlines" {...register("airline")} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Input label="Origin IATA" placeholder="JFK" error={errors.origin_iata?.message} {...register("origin_iata")} />
            <Input label="Dest IATA" placeholder="LHR" error={errors.dest_iata?.message} {...register("dest_iata")} />
          </div>
        </>
      )}

      <div className="grid grid-cols-2 gap-4">
        <Input label="Origin city" placeholder="New York" {...register("origin_city")} />
        <Input label="Destination city" placeholder="London" {...register("dest_city")} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input label="Departure" type="datetime-local" {...register("departure_at")} />
        <Input label="Arrival" type="datetime-local" {...register("arrival_at")} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input label="Duration (min)" type="number" {...register("duration_min")} />
        <Input label="Distance (km)" type="number" step="any" {...register("distance_km")} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input label="Seat class" placeholder="Economy" {...register("seat_class")} />
        <Input label="Booking reference" placeholder="ABC123" {...register("booking_ref")} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input label="Cost" type="number" step="0.01" {...register("cost")} />
        <Input label="Currency" placeholder="USD" maxLength={3} {...register("currency")} />
      </div>

      <Input label="Notes" placeholder="Optional notes" {...register("notes")} />

      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>
          Add transport
        </Button>
        <Button type="button" variant="ghost" onClick={() => window.history.back()}>
          Cancel
        </Button>
      </div>
    </form>
  );
}
