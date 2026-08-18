import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import type { TransportLeg } from "../types";
import { FlightCard } from "../components/flights/FlightCard";

const mockFlight: TransportLeg = {
  id: "flight-001",
  user_id: "user-001",
  flight_number: "BA178",
  airline: "British Airways",
  origin_iata: "JFK",
  dest_iata: "LHR",
  origin_city: "New York",
  dest_city: "London",
  departure_at: "2025-03-15T09:00:00Z",
  arrival_at: "2025-03-15T21:00:00Z",
  duration_min: 420,
  distance_km: 5560,
  seat_class: "economy",
  booking_ref: null,
  cost: null,
  currency: "USD",
  notes: null,
  origin_lat: null,
  origin_lng: null,
  dest_lat: null,
  dest_lng: null,
  created_at: "2025-01-01T00:00:00Z",
};

describe("FlightCard", () => {
  it("renders the route", () => {
    render(<FlightCard flight={mockFlight} />);
    expect(screen.getByText("New York → London")).toBeInTheDocument();
  });

  it("renders airline and flight number", () => {
    render(<FlightCard flight={mockFlight} />);
    expect(screen.getByText(/British Airways/)).toBeInTheDocument();
    expect(screen.getByText(/BA178/)).toBeInTheDocument();
  });
});
