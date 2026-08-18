"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Globe, Plane, BarChart2, Settings } from "lucide-react";
import { UserButton } from "@clerk/nextjs";
import { cn } from "@/lib/utils";
import type { Route } from "next";
import type { LucideIcon } from "lucide-react";

interface NavLink {
  href: Route;
  icon: LucideIcon;
  label: string;
}

const NAV_ITEMS: NavLink[] = [
  { href: "/map", icon: Globe, label: "Map" },
  { href: "/flights", icon: Plane, label: "Flights" },
  { href: "/stats", icon: BarChart2, label: "Stats" },
];

function NavItem({ href, icon: Icon, label }: NavLink) {
  const pathname = usePathname();
  const isActive = pathname === href || pathname.startsWith(href + "/");

  return (
    <Link
      href={href}
      data-active={isActive}
      aria-current={isActive ? "page" : undefined}
      className={cn(
        "group relative flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors duration-150",
        isActive
          ? "bg-atlas-accent/10 text-atlas-accent"
          : "text-atlas-ink-2 hover:bg-atlas-surface-2 hover:text-atlas-ink"
      )}
    >
      {/* active meridian tick */}
      <span
        className={cn(
          "absolute left-0 top-1/2 h-5 w-0.5 -translate-y-1/2 rounded-full bg-atlas-accent transition-all duration-200",
          isActive ? "opacity-100" : "opacity-0"
        )}
      />
      <Icon
        size={18}
        strokeWidth={1.75}
        className={cn(isActive ? "text-atlas-accent" : "text-atlas-ink-faint group-hover:text-atlas-ink")}
      />
      <span className="font-medium">{label}</span>
    </Link>
  );
}

export function Sidebar() {
  return (
    <aside className="bg-graticule relative flex h-full w-[212px] shrink-0 flex-col border-r border-atlas-border bg-atlas-surface">
      {/* Wordmark */}
      <div className="flex items-center gap-2.5 px-4 pb-5 pt-5">
        <div className="flex h-9 w-9 items-center justify-center rounded-md border border-atlas-accent/30 bg-atlas-accent/10">
          <span className="font-display text-lg font-bold leading-none text-atlas-accent">A</span>
        </div>
        <div className="leading-tight">
          <div className="font-display text-base font-semibold text-atlas-ink">Atlas</div>
          <div className="font-mono text-[10px] uppercase tracking-[0.18em] text-atlas-ink-faint">
            Flight Radar
          </div>
        </div>
      </div>

      <div className="rule-meridian mx-3 mb-3" />

      {/* Nav */}
      <nav className="flex flex-col gap-1 px-3">
        {NAV_ITEMS.map((item) => (
          <NavItem key={item.href} {...item} />
        ))}
      </nav>

      <div className="flex-1" />

      <div className="rule-meridian mx-3 mb-3" />

      {/* Footer: settings + account */}
      <div className="flex flex-col gap-1 px-3 pb-4">
        <NavItem href={"/settings" as Route} icon={Settings} label="Settings" />
        <div className="mt-2 flex items-center gap-3 rounded-md px-3 py-2">
          <UserButton
            appearance={{ elements: { avatarBox: "h-7 w-7" } }}
          />
          <span className="text-xs text-atlas-ink-2">Account</span>
        </div>
      </div>
    </aside>
  );
}
