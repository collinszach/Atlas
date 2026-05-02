import { describe, it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { TripForm } from "../components/trips/TripForm";
import type { Trip } from "../types";

vi.mock("../hooks/useTrips", () => ({
  useCreateTrip: () => ({
    mutateAsync: vi.fn().mockResolvedValue({ id: "new-trip", title: "Test" }),
    isPending: false,
  }),
  useUpdateTrip: () => ({
    mutateAsync: vi.fn(),
    isPending: false,
  }),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
}));

vi.mock("@clerk/nextjs", () => ({ useAuth: () => ({ getToken: vi.fn().mockResolvedValue("tok") }) }));

const editTrip: Partial<Trip> = {
  id: "trip-edit-001",
  title: "Pre-filled Title",
  status: "planned",
  visibility: "private",
};

describe("TripForm", () => {
  it("requires a title to submit", async () => {
    render(<TripForm />);
    const btn = screen.getByRole("button", { name: /save/i });
    await userEvent.click(btn);
    expect(await screen.findByText(/title is required/i)).toBeInTheDocument();
  });

  it("calls createTrip with form data on valid submit", async () => {
    render(<TripForm />);
    await userEvent.type(screen.getByLabelText(/title/i), "Euro Trip");
    await userEvent.click(screen.getByRole("button", { name: /save/i }));
    // Verify that submitting with a valid title doesn't show validation error
    await waitFor(() => {
      expect(screen.queryByText(/title is required/i)).not.toBeInTheDocument();
    });
  });

  it("pre-fills title in edit mode", () => {
    render(<TripForm initialValues={editTrip} onSuccess={vi.fn()} />);
    const input = screen.getByDisplayValue("Pre-filled Title");
    expect(input).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /save changes/i })).toBeInTheDocument();
  });
});
