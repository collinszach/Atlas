import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { TooltipProvider } from "../components/ui/Tooltip";

vi.mock("@clerk/nextjs", () => ({
  useUser: () => ({ user: { firstName: "Test", imageUrl: null } }),
  UserButton: () => <div data-testid="user-button" />,
}));

vi.mock("next/navigation", () => ({
  usePathname: () => "/map",
}));

describe("Sidebar", () => {
  it("renders nav icons for all top-level routes", async () => {
    const { Sidebar } = await import("../components/layout/Sidebar");
    render(<TooltipProvider><Sidebar /></TooltipProvider>);
    expect(screen.getByTitle("Map")).toBeInTheDocument();
    expect(screen.getByTitle("Trips")).toBeInTheDocument();
    expect(screen.getByTitle("Plan")).toBeInTheDocument();
    expect(screen.getByTitle("Discover")).toBeInTheDocument();
    expect(screen.getByTitle("Stats")).toBeInTheDocument();
  });

  it("marks the active route", async () => {
    const { Sidebar } = await import("../components/layout/Sidebar");
    render(<TooltipProvider><Sidebar /></TooltipProvider>);
    const mapLink = screen.getByTitle("Map").closest("a");
    expect(mapLink).toHaveAttribute("data-active", "true");
  });
});
