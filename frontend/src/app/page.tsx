import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import Link from "next/link";

export default async function LandingPage() {
  const { userId } = await auth();

  if (userId) {
    redirect("/map");
  }

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-atlas-bg">
      {/* Subtle grid background */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage:
            "linear-gradient(rgba(201,168,76,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(201,168,76,0.5) 1px, transparent 1px)",
          backgroundSize: "60px 60px",
        }}
      />

      {/* Radial glow */}
      <div className="pointer-events-none absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 h-[600px] w-[600px] rounded-full bg-atlas-accent/5 blur-3xl" />

      <div className="relative z-10 flex flex-col items-center gap-8 px-6 text-center">
        {/* Logo / Title */}
        <div className="flex flex-col items-center gap-3">
          <div className="flex items-center gap-3">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              className="h-10 w-10 text-atlas-accent"
            >
              <circle cx="12" cy="12" r="10" />
              <path d="M2 12h20" />
              <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
            </svg>
            <h1 className="font-display text-5xl font-bold tracking-tight text-atlas-text">
              Atlas
            </h1>
          </div>
          <p className="max-w-md text-lg text-atlas-muted">
            Your personal travel intelligence platform. Archive the past, track the present, plan the future.
          </p>
        </div>

        {/* Stats tease */}
        <div className="flex gap-8 text-center">
          {[
            { label: "Countries", icon: "M3.5 21L14.5 3M9.5 21L20.5 3M3 7h18M3 17h18" },
            { label: "Flights", icon: "M17.8 3.8L21 3l-.8 3.2L16 10.4l.4 5.2-2.4.8-2-4-4-2 .8-2.4 5.2.4z" },
            { label: "Photos", icon: "M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2zM12 17a5 5 0 100-10 5 5 0 000 10z" },
          ].map((item) => (
            <div key={item.label} className="flex flex-col items-center gap-1.5">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="h-5 w-5 text-atlas-accent/60"
              >
                <path d={item.icon} />
              </svg>
              <span className="text-xs font-mono uppercase tracking-widest text-atlas-muted">
                {item.label}
              </span>
            </div>
          ))}
        </div>

        {/* CTA */}
        <div className="flex flex-col items-center gap-3 pt-2">
          <Link
            href="/sign-in"
            className="rounded-lg bg-atlas-accent px-8 py-3 text-sm font-semibold text-atlas-bg transition-all hover:bg-atlas-accent/90 hover:shadow-lg hover:shadow-atlas-accent/20"
          >
            Sign In
          </Link>
          <Link
            href="/sign-up"
            className="text-sm text-atlas-muted transition-colors hover:text-atlas-text"
          >
            Create an account
          </Link>
        </div>
      </div>

      {/* Coordinate decoration */}
      <div className="absolute bottom-6 font-mono text-[10px] tracking-widest text-atlas-muted/30">
        40.7128&deg; N &middot; 74.0060&deg; W
      </div>
    </div>
  );
}
