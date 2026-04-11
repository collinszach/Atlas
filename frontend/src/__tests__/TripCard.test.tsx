import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import type { Trip } from "../types";
import { TripCard } from "../components/trips/TripCard";

const mockTrip: Trip = {
  id: "trip-001",
  user_id: "user-001",
  title: "Japan Spring 2025",
  description: null,
  status: "past",
  start_date: "2025-03-15",
  end_date: "2025-03-28",
  tags: ["asia", "food"],
  visibility: "private",
  created_at: "2025-01-01T00:00:00Z",
  updated_at: "2025-01-01T00:00:00Z",
};

describe("TripCard", () => {
  it("renders trip title", () => {
    render(<TripCard trip={mockTrip} />);
    expect(screen.getByText("Japan Spring 2025")).toBeInTheDocument();
  });

  it("renders status badge", () => {
    render(<TripCard trip={mockTrip} />);
    expect(screen.getByText(/past/i)).toBeInTheDocument();
  });
});
