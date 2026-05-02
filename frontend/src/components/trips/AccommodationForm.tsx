"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import { useAddAccommodation } from "@/hooks/useAccommodations";

const ACCOMMODATION_TYPES = [
  { value: "", label: "— not set —" },
  { value: "hotel", label: "Hotel" },
  { value: "airbnb", label: "Airbnb" },
  { value: "hostel", label: "Hostel" },
  { value: "house", label: "House" },
  { value: "camping", label: "Camping" },
  { value: "other", label: "Other" },
];

const CURRENCIES = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "INR", "MXN"];
const CURRENCY_OPTIONS = CURRENCIES.map((c) => ({ value: c, label: c }));

const schema = z.object({
  name: z.string().min(1, "Name is required"),
  type: z.string().optional(),
  address: z.string().optional(),
  check_in: z.string().optional(),
  check_out: z.string().optional(),
  confirmation: z.string().optional(),
  cost_per_night: z.coerce.number().nonnegative().optional().or(z.literal("")),
  currency: z.string().length(3).default("USD"),
  notes: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export function AccommodationForm({
  tripId,
  onSuccess,
}: {
  tripId: string;
  onSuccess: () => void;
}) {
  const { mutateAsync: addAccommodation, isPending } = useAddAccommodation(tripId);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { currency: "USD" },
  });

  const onSubmit = async (data: FormValues) => {
    const payload = {
      ...data,
      type: data.type || undefined,
      cost_per_night: data.cost_per_night === "" ? undefined : data.cost_per_night,
      check_in: data.check_in ? new Date(data.check_in).toISOString() : undefined,
      check_out: data.check_out ? new Date(data.check_out).toISOString() : undefined,
    };
    await addAccommodation(payload);
    onSuccess();
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 max-w-lg">
      <Input
        label="Name"
        placeholder="Park Hyatt Tokyo"
        error={errors.name?.message}
        {...register("name")}
      />

      <Select label="Type" options={ACCOMMODATION_TYPES} {...register("type")} />

      <Input label="Address" placeholder="3-7-1-2 Nishi-Shinjuku, Tokyo" {...register("address")} />

      <div className="grid grid-cols-2 gap-4">
        <Input label="Check-in" type="datetime-local" {...register("check_in")} />
        <Input label="Check-out" type="datetime-local" {...register("check_out")} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Cost per night"
          type="number"
          step="any"
          placeholder="250"
          error={errors.cost_per_night?.message}
          {...register("cost_per_night")}
        />
        <Select label="Currency" options={CURRENCY_OPTIONS} {...register("currency")} />
      </div>

      <Input
        label="Confirmation number"
        placeholder="HYATT-ABC123"
        {...register("confirmation")}
      />

      <Input label="Notes" placeholder="Optional notes" {...register("notes")} />

      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>
          Save accommodation
        </Button>
        <Button type="button" variant="ghost" onClick={onSuccess}>
          Cancel
        </Button>
      </div>
    </form>
  );
}
