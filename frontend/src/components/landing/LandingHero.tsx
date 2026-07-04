"use client";

import Link from "next/link";
import { motion, useReducedMotion, type Variants } from "framer-motion";

const STATS = [
  { label: "Countries", icon: "M3.5 21L14.5 3M9.5 21L20.5 3M3 7h18M3 17h18" },
  { label: "Flights", icon: "M17.8 3.8L21 3l-.8 3.2L16 10.4l.4 5.2-2.4.8-2-4-4-2 .8-2.4 5.2.4z" },
  { label: "Photos", icon: "M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2zM12 17a5 5 0 100-10 5 5 0 000 10z" },
];

const container: Variants = {
  hidden: {},
  show: {
    transition: { staggerChildren: 0.08, delayChildren: 0.1 },
  },
};

const item: Variants = {
  hidden: { opacity: 0, y: 14 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] },
  },
};

export function LandingHero() {
  const shouldReduceMotion = useReducedMotion();

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
      <motion.div
        className="pointer-events-none absolute top-1/3 left-1/2 h-[600px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-atlas-accent/5 blur-3xl"
        animate={
          shouldReduceMotion
            ? undefined
            : { opacity: [0.6, 1, 0.6], scale: [1, 1.06, 1] }
        }
        transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
      />

      <motion.div
        variants={container}
        initial="hidden"
        animate="show"
        className="relative z-10 flex flex-col items-center gap-8 px-6 text-center"
      >
        {/* Logo / Title */}
        <motion.div variants={item} className="flex flex-col items-center gap-3">
          <div className="flex items-center gap-3">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              className="h-10 w-10 text-atlas-accent"
              aria-hidden="true"
            >
              <circle cx="12" cy="12" r="10" />
              <path d="M2 12h20" />
              <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
            </svg>
            <h1 className="font-display text-5xl font-bold tracking-tight text-atlas-ink">
              Atlas
            </h1>
          </div>
          <p className="max-w-md text-lg text-atlas-ink-2">
            Your personal travel intelligence platform. Archive the past, track the present, plan the future.
          </p>
        </motion.div>

        {/* Stats tease */}
        <motion.div variants={item} className="flex gap-8 text-center">
          {STATS.map((stat) => (
            <motion.div
              key={stat.label}
              whileHover={shouldReduceMotion ? undefined : { y: -2 }}
              transition={{ duration: 0.2, ease: [0.25, 1, 0.5, 1] }}
              className="flex flex-col items-center gap-1.5"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="h-5 w-5 text-atlas-accent/60"
                aria-hidden="true"
              >
                <path d={stat.icon} />
              </svg>
              <span className="font-mono text-xs uppercase tracking-widest text-atlas-ink-2">
                {stat.label}
              </span>
            </motion.div>
          ))}
        </motion.div>

        {/* CTA */}
        <motion.div variants={item} className="flex flex-col items-center gap-3 pt-2">
          <motion.div whileTap={shouldReduceMotion ? undefined : { scale: 0.97 }}>
            <Link
              href="/sign-in"
              className="inline-block cursor-pointer rounded-lg bg-atlas-accent px-8 py-3 text-sm font-semibold text-atlas-bg transition-all duration-200 hover:bg-atlas-accent-hi hover:shadow-glow-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-atlas-accent"
            >
              Sign In
            </Link>
          </motion.div>
          <Link
            href="/sign-up"
            className="cursor-pointer text-sm text-atlas-ink-2 transition-colors duration-200 hover:text-atlas-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-atlas-accent"
          >
            Create an account
          </Link>
        </motion.div>
      </motion.div>

      {/* Coordinate decoration */}
      <div className="absolute bottom-6 font-mono text-[10px] tracking-widest text-atlas-ink-faint/60">
        40.7128&deg; N &middot; 74.0060&deg; W
      </div>
    </div>
  );
}
