"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useRouter } from "next/navigation";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { useAddDestination } from "@/hooks/useDestinations";

const schema = z.object({
  city: z.string().min(1, "City is required"),
  country_code: z.string().length(2, "2-letter ISO code required").toUpperCase(),
  country_name: z.string().min(1, "Country name is required"),
  region: z.string().optional(),
  arrival_date: z.string().optional(),
  departure_date: z.string().optional(),
  latitude: z.coerce.number().min(-90).max(90).optional().or(z.literal("")),
  longitude: z.coerce.number().min(-180).max(180).optional().or(z.literal("")),
  notes: z.string().optional(),
  rating: z.coerce.number().min(1).max(5).optional().or(z.literal("")),
});

type FormValues = z.infer<typeof schema>;

export function DestinationForm({ tripId }: { tripId: string }) {
  const router = useRouter();
  const { mutateAsync: addDestination, isPending } = useAddDestination(tripId);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = async (data: FormValues) => {
    const payload = {
      ...data,
      latitude: data.latitude === "" ? undefined : data.latitude,
      longitude: data.longitude === "" ? undefined : data.longitude,
      rating: data.rating === "" ? undefined : data.rating,
    };
    await addDestination(payload);
    router.push(`/trips/${tripId}`);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 max-w-lg">
      <div className="grid grid-cols-2 gap-4">
        <Input label="City" placeholder="Tokyo" error={errors.city?.message} {...register("city")} />
        <Input label="Country code" placeholder="JP" error={errors.country_code?.message} {...register("country_code")} />
      </div>
      <Input label="Country name" placeholder="Japan" error={errors.country_name?.message} {...register("country_name")} />
      <div className="grid grid-cols-2 gap-4">
        <Input label="Arrival date" type="date" {...register("arrival_date")} />
        <Input label="Departure date" type="date" {...register("departure_date")} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Input label="Latitude" placeholder="35.6762" type="number" step="any" {...register("latitude")} />
        <Input label="Longitude" placeholder="139.6503" type="number" step="any" {...register("longitude")} />
      </div>
      <Input label="Notes" placeholder="Optional notes" {...register("notes")} />
      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>Add destination</Button>
        <Button type="button" variant="ghost" onClick={() => router.back()}>Cancel</Button>
      </div>
    </form>
  );
}
