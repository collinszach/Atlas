import { PageHeader } from "@/components/ui/PageHeader";
import { MapPin, Ruler, Eye } from "lucide-react";

const SECTIONS = [
  {
    icon: MapPin,
    title: "Home base",
    body: "Set your home country so distances, time away, and recommendations are measured from where you actually start.",
  },
  {
    icon: Ruler,
    title: "Units & format",
    body: "Kilometers or miles, date format, and currency for trip costs. Applied across stats and the map.",
  },
  {
    icon: Eye,
    title: "Privacy & sharing",
    body: "Default trip visibility and the public profile that powers shared links.",
  },
];

export default function SettingsPage() {
  return (
    <div className="h-full overflow-y-auto px-6 py-7 sm:px-8">
      <div className="mx-auto max-w-2xl">
        <PageHeader
          eyebrow="The Instruments"
          title="Settings"
          description="Calibrate how Atlas measures and presents your travels. Account and sign-in are managed from the avatar menu."
        />
        <div className="space-y-3">
          {SECTIONS.map(({ icon: Icon, title, body }) => (
            <div
              key={title}
              className="flex items-start gap-4 rounded-lg border border-atlas-border bg-atlas-surface p-5 shadow-elev-1"
            >
              <div className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-md border border-atlas-border bg-atlas-surface-2 text-atlas-ink-faint">
                <Icon size={17} strokeWidth={1.75} />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-semibold text-atlas-ink">{title}</h3>
                  <span className="rounded-full border border-atlas-border bg-atlas-surface-2 px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider text-atlas-ink-faint">
                    Soon
                  </span>
                </div>
                <p className="mt-1 text-sm text-atlas-ink-2">{body}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
