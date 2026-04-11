"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useRouter } from "next/navigation";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import { useCreateTrip } from "@/hooks/useTrips";

const schema = z.object({
  title: z.string().min(1, "Title is required").max(120),
  description: z.string().max(500).optional(),
  status: z.enum(["past", "active", "planned", "dream"]),
  start_date: z.string().optional(),
  end_date: z.string().optional(),
  visibility: z.enum(["private", "shared", "public"]),
});

type FormValues = z.infer<typeof schema>;

const STATUS_OPTIONS = [
  { value: "past", label: "Past trip" },
  { value: "active", label: "Currently on this trip" },
  { value: "planned", label: "Planned" },
  { value: "dream", label: "Dream destination" },
];

const VISIBILITY_OPTIONS = [
  { value: "private", label: "Private" },
  { value: "shared", label: "Shared (link)" },
  { value: "public", label: "Public" },
];

export function TripForm() {
  const router = useRouter();
  const { mutateAsync: createTrip, isPending } = useCreateTrip();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { status: "past", visibility: "private" },
  });

  const onSubmit = async (data: FormValues) => {
    const trip = await createTrip(data);
    router.push(`/trips/${trip.id}`);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 max-w-lg">
      <Input
        label="Title"
        placeholder="Japan Spring 2025"
        error={errors.title?.message}
        {...register("title")}
      />
      <Input
        label="Description"
        placeholder="Optional notes about the trip"
        error={errors.description?.message}
        {...register("description")}
      />
      <div className="grid grid-cols-2 gap-4">
        <Input label="Start date" type="date" {...register("start_date")} />
        <Input label="End date" type="date" {...register("end_date")} />
      </div>
      <Select label="Status" options={STATUS_OPTIONS} {...register("status")} />
      <Select label="Visibility" options={VISIBILITY_OPTIONS} {...register("visibility")} />
      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>Save trip</Button>
        <Button type="button" variant="ghost" onClick={() => router.back()}>Cancel</Button>
      </div>
    </form>
  );
}
