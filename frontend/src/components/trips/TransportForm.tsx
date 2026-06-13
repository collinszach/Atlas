"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useRouter } from "next/navigation";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import { useAddTransport } from "@/hooks/useTransport";

const TYPES = ["flight", "train", "car", "ferry", "bus", "walk", "other"] as const;

const num = z.coerce.number().optional().or(z.literal(""));

const schema = z.object({
  type: z.enum(TYPES),
  origin_city: z.string().min(1, "Origin is required"),
  dest_city: z.string().min(1, "Destination is required"),
  flight_number: z.string().optional(),
  airline: z.string().optional(),
  origin_iata: z.string().max(3).optional(),
  dest_iata: z.string().max(3).optional(),
  departure_at: z.string().optional(),
  arrival_at: z.string().optional(),
  distance_km: num,
  seat_class: z.string().optional(),
  booking_ref: z.string().optional(),
  cost: num,
  currency: z.string().length(3).optional().or(z.literal("")),
  notes: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export function TransportForm({ tripId }: { tripId: string }) {
  const router = useRouter();
  const { mutateAsync: addTransport, isPending } = useAddTransport(tripId);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { type: "flight", currency: "USD" },
  });

  const isFlight = watch("type") === "flight";

  const onSubmit = async (data: FormValues) => {
    const blank = (v: unknown) => (v === "" ? undefined : v);
    await addTransport({
      type: data.type,
      origin_city: data.origin_city,
      dest_city: data.dest_city,
      flight_number: blank(data.flight_number) as string | undefined,
      airline: blank(data.airline) as string | undefined,
      origin_iata: (blank(data.origin_iata) as string | undefined)?.toUpperCase(),
      dest_iata: (blank(data.dest_iata) as string | undefined)?.toUpperCase(),
      departure_at: blank(data.departure_at) as string | undefined,
      arrival_at: blank(data.arrival_at) as string | undefined,
      distance_km: blank(data.distance_km) as number | undefined,
      seat_class: blank(data.seat_class) as string | undefined,
      booking_ref: blank(data.booking_ref) as string | undefined,
      cost: blank(data.cost) as number | undefined,
      currency: (blank(data.currency) as string | undefined) ?? "USD",
      notes: blank(data.notes) as string | undefined,
    });
    router.push(`/trips/${tripId}`);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex max-w-lg flex-col gap-5">
      <Select
        label="Mode"
        options={TYPES.map((t) => ({ value: t, label: t.charAt(0).toUpperCase() + t.slice(1) }))}
        {...register("type")}
      />

      <div className="grid grid-cols-2 gap-4">
        <Input label="From" placeholder="London" error={errors.origin_city?.message} {...register("origin_city")} />
        <Input label="To" placeholder="Tokyo" error={errors.dest_city?.message} {...register("dest_city")} />
      </div>

      {isFlight && (
        <div className="grid grid-cols-2 gap-4">
          <Input label="Flight number" placeholder="JL44" {...register("flight_number")} />
          <Input label="Airline" placeholder="Japan Airlines" {...register("airline")} />
          <Input label="Origin (IATA)" placeholder="LHR" maxLength={3} {...register("origin_iata")} />
          <Input label="Destination (IATA)" placeholder="HND" maxLength={3} {...register("dest_iata")} />
        </div>
      )}

      <div className="grid grid-cols-2 gap-4">
        <Input label="Departs" type="datetime-local" {...register("departure_at")} />
        <Input label="Arrives" type="datetime-local" {...register("arrival_at")} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input label="Distance (km)" type="number" step="any" placeholder="9560" {...register("distance_km")} />
        <Input label="Seat class" placeholder="Economy" {...register("seat_class")} />
      </div>

      <div className="grid grid-cols-[1fr_1fr_90px] gap-4">
        <Input label="Booking ref" placeholder="ABC123" {...register("booking_ref")} />
        <Input label="Cost" type="number" step="any" placeholder="850" {...register("cost")} />
        <Input label="Currency" placeholder="USD" maxLength={3} {...register("currency")} />
      </div>

      <Input label="Notes" placeholder="Optional" {...register("notes")} />

      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>
          Log transport
        </Button>
        <Button type="button" variant="ghost" onClick={() => router.back()}>
          Cancel
        </Button>
      </div>
    </form>
  );
}
