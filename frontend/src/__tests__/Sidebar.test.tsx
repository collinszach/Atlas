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
    expect(screen.getByRole("link", { name: "Map" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Flights" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Stats" })).toBeInTheDocument();
  });

  it("marks the active route", async () => {
    const { Sidebar } = await import("../components/layout/Sidebar");
    render(<TooltipProvider><Sidebar /></TooltipProvider>);
    const mapLink = screen.getByRole("link", { name: "Map" });
    expect(mapLink).toHaveAttribute("data-active", "true");
  });
});
