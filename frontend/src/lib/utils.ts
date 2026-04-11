import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDateRange(start: string | null, end: string | null): string {
  if (!start) return "Dates TBD";
  const s = new Date(start).toLocaleDateString("en-US", { month: "short", year: "numeric" });
  if (!end) return s;
  const e = new Date(end).toLocaleDateString("en-US", { month: "short", year: "numeric" });
  return s === e ? s : `${s} – ${e}`;
}

export function nightsLabel(nights: number | null): string {
  if (nights === null) return "";
  return nights === 1 ? "1 night" : `${nights} nights`;
}
