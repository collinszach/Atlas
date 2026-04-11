"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Globe, MapPin, Calendar, Compass, BarChart2, Settings } from "lucide-react";
import { UserButton } from "@clerk/nextjs";
import { Tooltip } from "@/components/ui/Tooltip";
import { cn } from "@/lib/utils";

const NAV_ITEMS = [
  { href: "/map",      icon: Globe,     label: "Map" },
  { href: "/trips",    icon: MapPin,    label: "Trips" },
  { href: "/plan",     icon: Calendar,  label: "Plan" },
  { href: "/discover", icon: Compass,   label: "Discover" },
  { href: "/stats",    icon: BarChart2, label: "Stats" },
] as const;

function NavIcon({ href, icon: Icon, label }: (typeof NAV_ITEMS)[number]) {
  const pathname = usePathname();
  const isActive = pathname === href || pathname.startsWith(href + "/");

  return (
    <Tooltip label={label}>
      <Link
        href={href}
        title={label}
        data-active={isActive}
        className={cn(
          "flex h-9 w-9 items-center justify-center rounded-lg transition-colors",
          isActive
            ? "bg-atlas-accent/10 text-atlas-accent border border-atlas-accent/30"
            : "text-atlas-muted hover:text-atlas-text hover:bg-atlas-surface"
        )}
      >
        <Icon size={18} strokeWidth={1.5} />
      </Link>
    </Tooltip>
  );
}

export function Sidebar() {
  return (
    <aside className="flex h-full w-[52px] flex-col items-center border-r border-atlas-border bg-atlas-surface py-4 gap-2 shrink-0">
      {/* Logo mark */}
      <div className="mb-2 flex h-8 w-8 items-center justify-center">
        <span className="font-display text-sm font-bold text-atlas-accent">A</span>
      </div>

      {/* Nav items */}
      {NAV_ITEMS.map((item) => (
        <NavIcon key={item.href} {...item} />
      ))}

      {/* Spacer */}
      <div className="flex-1" />

      {/* Bottom: settings + user */}
      <Tooltip label="Settings">
        <Link
          href="/settings"
          title="Settings"
          className="flex h-9 w-9 items-center justify-center rounded-lg text-atlas-muted hover:text-atlas-text hover:bg-atlas-surface transition-colors"
        >
          <Settings size={18} strokeWidth={1.5} />
        </Link>
      </Tooltip>

      <UserButton
        appearance={{
          elements: {
            avatarBox: "h-8 w-8",
          },
        }}
      />
    </aside>
  );
}
