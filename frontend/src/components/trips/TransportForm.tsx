"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Loader2, Sparkles } from "lucide-react";
import { useAuth } from "@clerk/nextjs";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import { useAddTransport } from "@/hooks/useTransport";
import { apiPost } from "@/lib/api";
import type { EnrichFlightResponse } from "@/types";

const TRANSPORT_TYPES = [
  { value: "flight", label: "Flight" },
  { value: "car", label: "Car" },
  { value: "train", label: "Train" },
  { value: "ferry", label: "Ferry" },
  { value: "bus", label: "Bus" },
  { value: "walk", label: "Walk" },
  { value: "other", label: "Other" },
];

const SEAT_CLASS_OPTIONS = [
  { value: "", label: "— not set —" },
  { value: "economy", label: "Economy" },
  { value: "business", label: "Business" },
  { value: "first", label: "First" },
];

const schema = z.object({
  type: z.enum(["flight", "car", "train", "ferry", "bus", "walk", "other"]),
  flight_number: z.string().optional(),
  airline: z.string().optional(),
  origin_iata: z.string().length(3).toUpperCase().optional().or(z.literal("")),
  dest_iata: z.string().length(3).toUpperCase().optional().or(z.literal("")),
  seat_class: z.string().optional(),
  origin_city: z.string().optional(),
  dest_city: z.string().optional(),
  departure_at: z.string().optional(),
  arrival_at: z.string().optional(),
  distance_km: z.coerce.number().positive().optional().or(z.literal("")),
  cost: z.coerce.number().nonnegative().optional().or(z.literal("")),
  currency: z.string().length(3).default("USD"),
  notes: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export function TransportForm({ tripId, onSuccess }: { tripId: string; onSuccess: () => void }) {
  const { getToken } = useAuth();
  const { mutateAsync: addTransport, isPending } = useAddTransport(tripId);
  const [enriching, setEnriching] = useState(false);
  const [enrichError, setEnrichError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { type: "flight", currency: "USD" },
  });

  const type = watch("type");
  const flightNumber = watch("flight_number");
  const departureAt = watch("departure_at");
  const isFlight = type === "flight";
  const canEnrich = isFlight && !!flightNumber && !!departureAt;

  async function handleEnrich() {
    if (!canEnrich) return;
    setEnrichError(null);
    setEnriching(true);
    try {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      const date = departureAt!.slice(0, 10);
      const result = await apiPost<EnrichFlightResponse>(
        "/transport/enrich-flight",
        token,
        { flight_number: flightNumber, date }
      );
      if (result.flight_number) setValue("flight_number", result.flight_number);
      if (result.airline) setValue("airline", result.airline);
      if (result.origin_iata) setValue("origin_iata", result.origin_iata);
      if (result.dest_iata) setValue("dest_iata", result.dest_iata);
      // Populate city fields even though they're hidden in flight mode — the
      // API stores them on transport_legs and they may be visible in future views.
      if (result.origin_city) setValue("origin_city", result.origin_city);
      if (result.dest_city) setValue("dest_city", result.dest_city);
    } catch {
      setEnrichError("Enrichment failed — fill fields manually.");
    } finally {
      setEnriching(false);
    }
  }

  const onSubmit = async (data: FormValues) => {
    const payload = {
      ...data,
      distance_km: data.distance_km === "" ? undefined : data.distance_km,
      cost: data.cost === "" ? undefined : data.cost,
      seat_class: data.seat_class || undefined,
    };
    await addTransport(payload);
    onSuccess();
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 max-w-lg">
      <Select label="Type" options={TRANSPORT_TYPES} {...register("type")} />

      {isFlight && (
        <>
          <div className="grid grid-cols-2 gap-4">
            <Input label="Flight number" placeholder="AA100" {...register("flight_number")} />
            <Input label="Airline" placeholder="American Airlines" {...register("airline")} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Input label="Origin IATA" placeholder="JFK" {...register("origin_iata")} />
            <Input label="Dest IATA" placeholder="LHR" {...register("dest_iata")} />
          </div>
          <Select label="Seat class" options={SEAT_CLASS_OPTIONS} {...register("seat_class")} />

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={handleEnrich}
              disabled={!canEnrich || enriching}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors disabled:opacity-40"
            >
              {enriching ? <Loader2 size={12} className="animate-spin" /> : <Sparkles size={12} />}
              Auto-fill from flight number
            </button>
            {enrichError && <span className="text-xs text-red-400">{enrichError}</span>}
          </div>
        </>
      )}

      {!isFlight && (
        <div className="grid grid-cols-2 gap-4">
          <Input label="From" placeholder="New York" {...register("origin_city")} />
          <Input label="To" placeholder="Boston" {...register("dest_city")} />
        </div>
      )}

      <div className="grid grid-cols-2 gap-4">
        <Input label="Departure" type="datetime-local" {...register("departure_at")} />
        <Input label="Arrival" type="datetime-local" {...register("arrival_at")} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Distance (km)"
          type="number"
          step="any"
          placeholder="5560"
          error={errors.distance_km?.message}
          {...register("distance_km")}
        />
        <div className="grid grid-cols-2 gap-2">
          <Input
            label="Cost"
            type="number"
            step="any"
            placeholder="450"
            {...register("cost")}
          />
          <Input label="Currency" placeholder="USD" maxLength={3} {...register("currency")} />
        </div>
      </div>

      <Input label="Notes" placeholder="Optional notes" {...register("notes")} />

      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>Log transport</Button>
        <Button type="button" variant="ghost" onClick={onSuccess}>Cancel</Button>
      </div>
    </form>
  );
}
