# Atlas Phase 1 — Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Atlas frontend — Next.js 14 app with Clerk auth, icon sidebar shell, MapLibre GL globe with country choropleth, trip list, and trip detail pages.

**Architecture:** Next.js 14 App Router with route groups: `(auth)` for Clerk sign-in/up, `(app)` for authenticated pages. MapLibre GL runs client-side only (`dynamic(() => import(...), { ssr: false })`). TanStack Query handles all server state. The map globe is the primary view — the sidebar never overlaps it. Country data for the choropleth comes from `/api/v1/map/countries`; country polygon geometries come from Protomaps tiles.

**Tech Stack:** Next.js 14, TypeScript strict, Tailwind CSS, MapLibre GL JS, Clerk, TanStack Query v5, Zustand, Radix UI Tooltip, React Hook Form + Zod, Vitest + @testing-library/react

**Prerequisite:** Backend plan (`2026-04-11-atlas-phase1-backend.md`) must be complete and running at `http://localhost:8000`.

---

## File Map

```
Atlas/frontend/
├── package.json                         CREATE
├── next.config.ts                       CREATE
├── tailwind.config.ts                   CREATE
├── tsconfig.json                        CREATE
├── middleware.ts                        CREATE — Clerk auth route protection
├── vitest.config.ts                     CREATE
├── postcss.config.mjs                   CREATE — required for Tailwind in Next.js
├── app/
│   ├── layout.tsx                       CREATE — root layout, fonts, ClerkProvider, QueryProvider
│   ├── page.tsx                         CREATE — redirect to /map
│   ├── (auth)/
│   │   ├── sign-in/[[...sign-in]]/
│   │   │   └── page.tsx                 CREATE — Clerk SignIn component
│   │   └── sign-up/[[...sign-up]]/
│   │       └── page.tsx                 CREATE — Clerk SignUp component
│   └── (app)/
│       ├── layout.tsx                   CREATE — authenticated shell: sidebar + main area
│       ├── map/
│       │   └── page.tsx                 CREATE — WorldMap page
│       ├── trips/
│       │   ├── page.tsx                 CREATE — TripList page (shell)
│       │   ├── TripListClient.tsx       CREATE — client component for TanStack Query
│       │   ├── new/
│       │   │   └── page.tsx             CREATE — CreateTrip page
│       │   └── [id]/
│       │       ├── page.tsx             CREATE — TripDetail page
│       │       └── destinations/
│       │           └── new/
│       │               └── page.tsx     CREATE — AddDestination page
├── components/
│   ├── layout/
│   │   └── Sidebar.tsx                  CREATE — 52px icon rail
│   ├── map/
│   │   ├── WorldMap.tsx                 CREATE — MapLibre GL globe (CSR only)
│   │   ├── CountryPanel.tsx             CREATE — slide-in panel on country click
│   │   └── MapControls.tsx              CREATE — globe/flat toggle
│   ├── trips/
│   │   ├── TripCard.tsx                 CREATE — trip card for list view
│   │   ├── TripForm.tsx                 CREATE — create/edit trip form (RHF + Zod)
│   │   └── DestinationForm.tsx          CREATE — add destination form
│   └── ui/
│       ├── Button.tsx                   CREATE — primary/secondary/ghost variants
│       ├── Input.tsx                    CREATE — text input with label
│       ├── Select.tsx                   CREATE — native select wrapper
│       └── Tooltip.tsx                  CREATE — Radix tooltip wrapper
├── hooks/
│   ├── useTrips.ts                      CREATE — TanStack Query trip hooks
│   ├── useDestinations.ts               CREATE — TanStack Query destination hooks
│   └── useMapData.ts                    CREATE — TanStack Query map layer hooks
├── lib/
│   ├── api.ts                           CREATE — typed fetch client with Clerk auth header
│   ├── maplibre.ts                      CREATE — map style, layer definitions, choropleth colors
│   └── utils.ts                         CREATE — cn(), date formatting
├── providers/
│   └── QueryProvider.tsx                CREATE — TanStack QueryClientProvider
├── store/
│   └── mapStore.ts                      CREATE — Zustand: selectedCountry, projection
├── types/
│   └── index.ts                         CREATE — Trip, Destination, MapCountry, MapCity types
└── __tests__/
    ├── Sidebar.test.tsx                 CREATE
    ├── TripCard.test.tsx                CREATE
    ├── TripForm.test.tsx                CREATE
    └── api.test.ts                      CREATE
```

---

## Task 1: Project setup — package.json, config files, design tokens

**Files:**
- Create: `frontend/package.json`
- Create: `frontend/next.config.ts`
- Create: `frontend/tailwind.config.ts`
- Create: `frontend/tsconfig.json`
- Create: `frontend/vitest.config.ts`
- Create: `frontend/Dockerfile`

- [ ] **Step 1: Create package.json**

Create `Atlas/frontend/package.json`:
```json
{
  "name": "atlas-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "type-check": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "next": "14.2.18",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "@clerk/nextjs": "^5.7.5",
    "@tanstack/react-query": "^5.61.3",
    "@tanstack/react-query-devtools": "^5.61.3",
    "maplibre-gl": "^4.7.1",
    "zustand": "^5.0.2",
    "react-hook-form": "^7.54.0",
    "zod": "^3.23.8",
    "@hookform/resolvers": "^3.9.1",
    "@radix-ui/react-tooltip": "^1.1.4",
    "clsx": "^2.1.1",
    "tailwind-merge": "^2.5.5",
    "lucide-react": "^0.468.0"
  },
  "devDependencies": {
    "typescript": "^5.7.2",
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "@types/node": "^22.9.0",
    "tailwindcss": "^3.4.15",
    "postcss": "^8.4.49",
    "autoprefixer": "^10.4.20",
    "vitest": "^2.1.6",
    "@vitejs/plugin-react": "^4.3.4",
    "@testing-library/react": "^16.0.1",
    "@testing-library/jest-dom": "^6.6.3",
    "@testing-library/user-event": "^14.5.2",
    "jsdom": "^25.0.1"
  }
}
```

- [ ] **Step 2: Create next.config.ts**

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  experimental: {
    typedRoutes: true,
  },
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "img.clerk.com" },
    ],
  },
};

export default nextConfig;
```

- [ ] **Step 3: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "paths": {
      "@/*": ["./src/*"]
    },
    "plugins": [{ "name": "next" }]
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 4: Create tailwind.config.ts**

```typescript
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./providers/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        atlas: {
          bg: "#0a0e1a",
          surface: "#111827",
          border: "#1e2d45",
          accent: "#c9a84c",
          "accent-cool": "#4a90d9",
          text: "#e2e8f0",
          muted: "#64748b",
          visited: "#4a90d9",
          planned: "#c9a84c",
          bucket: "#374151",
        },
      },
      fontFamily: {
        display: ["Playfair Display", "Georgia", "serif"],
        sans: ["IBM Plex Sans", "system-ui", "sans-serif"],
        mono: ["IBM Plex Mono", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
```

- [ ] **Step 5: Create vitest.config.ts**

```typescript
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { resolve } from "path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
    globals: true,
  },
  resolve: {
    alias: {
      "@": resolve(__dirname, "./"),
    },
  },
});
```

Create `Atlas/frontend/vitest.setup.ts`:
```typescript
import "@testing-library/jest-dom";
```

- [ ] **Step 6: Create postcss.config.mjs**

```javascript
const config = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
export default config;
```

- [ ] **Step 7: Create Dockerfile**

Create `Atlas/frontend/Dockerfile`:
```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
```

- [ ] **Step 8: Install dependencies and verify type-check runs**

```bash
cd /home/zach/Atlas/frontend
npm install
npm run type-check
```
Expected: type errors (files don't exist yet) — confirm the toolchain works.

- [ ] **Step 9: Commit**

```bash
cd /home/zach/Atlas
git add frontend/
git commit -m "feat(atlas): frontend project setup — Next.js 14, Tailwind, Vitest, design tokens"
```

---

## Task 2: Types, API client, and utilities

**Files:**
- Create: `frontend/types/index.ts`
- Create: `frontend/lib/api.ts`
- Create: `frontend/lib/utils.ts`
- Create: `frontend/__tests__/api.test.ts`

- [ ] **Step 1: Write failing API client test**

Create `Atlas/frontend/__tests__/api.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";

describe("API client", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("adds Authorization header when token provided", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify([]), { status: 200 })
    );
    vi.stubGlobal("fetch", fetchMock);

    const { apiGet } = await import("../lib/api");
    await apiGet("/trips", "test-token-123");

    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining("/trips"),
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer test-token-123",
        }),
      })
    );
  });

  it("throws on non-OK response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("Not found", { status: 404 }))
    );
    const { apiGet } = await import("../lib/api");
    await expect(apiGet("/trips/bad-id", "token")).rejects.toThrow("404");
  });
});
```

Run to verify failure:
```bash
cd /home/zach/Atlas/frontend
npm run test -- __tests__/api.test.ts
```
Expected: `Cannot find module '../lib/api'`

- [ ] **Step 2: Create types/index.ts**

```typescript
export interface Trip {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  status: "past" | "active" | "planned" | "dream";
  start_date: string | null;
  end_date: string | null;
  tags: string[];
  visibility: "private" | "shared" | "public";
  created_at: string;
  updated_at: string;
}

export interface TripListResponse {
  items: Trip[];
  total: number;
  page: number;
  limit: number;
}

export interface Destination {
  id: string;
  trip_id: string;
  user_id: string;
  city: string;
  country_code: string;
  country_name: string;
  region: string | null;
  latitude: number | null;
  longitude: number | null;
  arrival_date: string | null;
  departure_date: string | null;
  nights: number | null;
  notes: string | null;
  rating: number | null;
  order_index: number;
  created_at: string;
}

export interface MapCountry {
  country_code: string;
  country_name: string;
  visit_count: number;
  first_visit: string | null;
  last_visit: string | null;
  total_nights: number;
  trip_ids: string[];
}

export interface MapCity {
  id: string;
  city: string;
  country_code: string;
  country_name: string;
  latitude: number;
  longitude: number;
  arrival_date: string | null;
  departure_date: string | null;
  trip_id: string;
}
```

- [ ] **Step 3: Create lib/api.ts**

```typescript
const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000";

async function request<T>(
  path: string,
  token: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${API_BASE}/api/v1${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...options.headers,
    },
  });
  if (!res.ok) {
    throw new Error(`${res.status}: ${await res.text()}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const apiGet = <T>(path: string, token: string) =>
  request<T>(path, token);

export const apiPost = <T>(path: string, token: string, body: unknown) =>
  request<T>(path, token, { method: "POST", body: JSON.stringify(body) });

export const apiPut = <T>(path: string, token: string, body: unknown) =>
  request<T>(path, token, { method: "PUT", body: JSON.stringify(body) });

export const apiDelete = (path: string, token: string) =>
  request<void>(path, token, { method: "DELETE" });
```

- [ ] **Step 4: Create lib/utils.ts**

```typescript
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDateRange(start: string | null, end: string | null): string {
  if (!start) return "Dates TBD";
  const s = new Date(start).toLocaleDateString("en-US", { month: "short", year: "numeric" });
  if (!end) return s;
  const e = new Date(end).toLocaleDateString("en-US", { month: "short", year: "numeric" });
  return s === e ? s : `${s} – ${e}`;
}

export function nightsLabel(nights: number | null): string {
  if (nights === null) return "";
  return nights === 1 ? "1 night" : `${nights} nights`;
}
```

- [ ] **Step 5: Run API tests**

```bash
cd /home/zach/Atlas/frontend
npm run test -- __tests__/api.test.ts
```
Expected: both tests `PASSED`.

- [ ] **Step 6: Commit**

```bash
cd /home/zach/Atlas
git add frontend/types/ frontend/lib/ frontend/__tests__/api.test.ts
git commit -m "feat(atlas): add TypeScript types, API client, and utilities"
```

---

## Task 3: Providers, Clerk setup, and root layout

**Files:**
- Create: `frontend/providers/QueryProvider.tsx`
- Create: `frontend/middleware.ts`
- Create: `frontend/app/layout.tsx`
- Create: `frontend/app/page.tsx`
- Create: `frontend/app/(auth)/sign-in/[[...sign-in]]/page.tsx`
- Create: `frontend/app/(auth)/sign-up/[[...sign-up]]/page.tsx`
- Create: `frontend/app/globals.css`

- [ ] **Step 1: Create providers/QueryProvider.tsx**

```typescript
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { useState, type ReactNode } from "react";

export function QueryProvider({ children }: { children: ReactNode }) {
  const [client] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000, // 1 minute
            retry: 1,
          },
        },
      })
  );

  return (
    <QueryClientProvider client={client}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

- [ ] **Step 2: Create middleware.ts**

```typescript
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/sign-in(.*)",
  "/sign-up(.*)",
]);

export default clerkMiddleware((auth, req) => {
  if (!isPublicRoute(req)) {
    auth().protect();
  }
});

export const config = {
  matcher: ["/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)"],
};
```

- [ ] **Step 3: Create app/globals.css**

```css
@import url("https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap");
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --atlas-bg: #0a0e1a;
    --atlas-surface: #111827;
    --atlas-border: #1e2d45;
    --atlas-accent: #c9a84c;
    --atlas-accent-cool: #4a90d9;
    --atlas-text: #e2e8f0;
    --atlas-text-muted: #64748b;
  }

  html,
  body {
    @apply bg-atlas-bg text-atlas-text font-sans;
    height: 100%;
    overflow: hidden;
  }

  /* maplibre-gl requires a non-zero size container */
  #map-container {
    width: 100%;
    height: 100%;
  }
}
```

- [ ] **Step 4: Create app/layout.tsx**

```typescript
import type { Metadata } from "next";
import { ClerkProvider } from "@clerk/nextjs";
import { QueryProvider } from "@/providers/QueryProvider";
import "./globals.css";

export const metadata: Metadata = {
  title: "Atlas — Travel Intelligence",
  description: "Your personal travel archive, journal, and planner.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body>
          <QueryProvider>{children}</QueryProvider>
        </body>
      </html>
    </ClerkProvider>
  );
}
```

- [ ] **Step 5: Create app/page.tsx (root redirect)**

```typescript
import { redirect } from "next/navigation";

export default function RootPage() {
  redirect("/map");
}
```

- [ ] **Step 6: Create Clerk auth pages**

Create `Atlas/frontend/app/(auth)/sign-in/[[...sign-in]]/page.tsx`:
```typescript
import { SignIn } from "@clerk/nextjs";

export default function SignInPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-atlas-bg">
      <div className="flex flex-col items-center gap-6">
        <h1 className="font-display text-3xl font-semibold text-atlas-accent">Atlas</h1>
        <p className="text-atlas-muted text-sm">Your travel intelligence platform</p>
        <SignIn />
      </div>
    </div>
  );
}
```

Create `Atlas/frontend/app/(auth)/sign-up/[[...sign-up]]/page.tsx`:
```typescript
import { SignUp } from "@clerk/nextjs";

export default function SignUpPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-atlas-bg">
      <div className="flex flex-col items-center gap-6">
        <h1 className="font-display text-3xl font-semibold text-atlas-accent">Atlas</h1>
        <p className="text-atlas-muted text-sm">Create your account to get started</p>
        <SignUp />
      </div>
    </div>
  );
}
```

- [ ] **Step 7: Run type-check**

```bash
cd /home/zach/Atlas/frontend
npm run type-check
```
Expected: no errors (providers and layout are clean TypeScript).

- [ ] **Step 8: Commit**

```bash
cd /home/zach/Atlas
git add frontend/providers/ frontend/middleware.ts frontend/app/layout.tsx frontend/app/page.tsx frontend/app/globals.css frontend/app/\(auth\)/
git commit -m "feat(atlas): add Clerk auth, QueryProvider, root layout, sign-in/sign-up pages"
```

---

## Task 4: App shell — authenticated layout and sidebar

**Files:**
- Create: `frontend/store/mapStore.ts`
- Create: `frontend/components/ui/Tooltip.tsx`
- Create: `frontend/components/layout/Sidebar.tsx`
- Create: `frontend/app/(app)/layout.tsx`
- Create: `frontend/__tests__/Sidebar.test.tsx`

- [ ] **Step 1: Write failing Sidebar test**

Create `Atlas/frontend/__tests__/Sidebar.test.tsx`:
```typescript
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";

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
    render(<Sidebar />);
    expect(screen.getByTitle("Map")).toBeInTheDocument();
    expect(screen.getByTitle("Trips")).toBeInTheDocument();
    expect(screen.getByTitle("Plan")).toBeInTheDocument();
    expect(screen.getByTitle("Discover")).toBeInTheDocument();
    expect(screen.getByTitle("Stats")).toBeInTheDocument();
  });

  it("marks the active route", async () => {
    const { Sidebar } = await import("../components/layout/Sidebar");
    render(<Sidebar />);
    const mapLink = screen.getByTitle("Map").closest("a");
    expect(mapLink).toHaveAttribute("data-active", "true");
  });
});
```

Run to verify failure:
```bash
npm run test -- __tests__/Sidebar.test.tsx
```
Expected: `Cannot find module '../components/layout/Sidebar'`

- [ ] **Step 2: Create store/mapStore.ts**

```typescript
import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { MapCountry } from "@/types";

interface MapState {
  projection: "globe" | "mercator";
  selectedCountry: MapCountry | null;
  setProjection: (p: "globe" | "mercator") => void;
  setSelectedCountry: (c: MapCountry | null) => void;
}

export const useMapStore = create<MapState>()(
  persist(
    (set) => ({
      projection: "globe",
      selectedCountry: null,
      setProjection: (projection) => set({ projection }),
      setSelectedCountry: (selectedCountry) => set({ selectedCountry }),
    }),
    { name: "atlas-map", partialize: (s) => ({ projection: s.projection }) }
  )
);
```

- [ ] **Step 3: Create components/ui/Tooltip.tsx**

```typescript
"use client";

import * as RadixTooltip from "@radix-ui/react-tooltip";
import type { ReactNode } from "react";

export function Tooltip({ label, children }: { label: string; children: ReactNode }) {
  return (
    <RadixTooltip.Provider delayDuration={300}>
      <RadixTooltip.Root>
        <RadixTooltip.Trigger asChild>{children}</RadixTooltip.Trigger>
        <RadixTooltip.Portal>
          <RadixTooltip.Content
            side="right"
            sideOffset={8}
            className="z-50 rounded bg-atlas-surface px-2.5 py-1.5 text-xs text-atlas-text shadow-lg border border-atlas-border"
          >
            {label}
            <RadixTooltip.Arrow className="fill-atlas-surface" />
          </RadixTooltip.Content>
        </RadixTooltip.Portal>
      </RadixTooltip.Root>
    </RadixTooltip.Provider>
  );
}
```

- [ ] **Step 4: Create components/layout/Sidebar.tsx**

```typescript
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
  const isActive = pathname.startsWith(href);

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
```

- [ ] **Step 5: Create app/(app)/layout.tsx**

```typescript
import { Sidebar } from "@/components/layout/Sidebar";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen w-screen overflow-hidden bg-atlas-bg">
      <Sidebar />
      <main className="relative flex-1 overflow-hidden">{children}</main>
    </div>
  );
}
```

- [ ] **Step 6: Run Sidebar tests**

```bash
cd /home/zach/Atlas/frontend
npm run test -- __tests__/Sidebar.test.tsx
```
Expected: both tests `PASSED`.

- [ ] **Step 7: Commit**

```bash
cd /home/zach/Atlas
git add frontend/store/ frontend/components/ui/Tooltip.tsx frontend/components/layout/Sidebar.tsx frontend/app/\(app\)/layout.tsx frontend/__tests__/Sidebar.test.tsx
git commit -m "feat(atlas): add app shell — icon sidebar rail, Zustand map store, authenticated layout"
```

---

## Task 5: TanStack Query hooks

**Files:**
- Create: `frontend/hooks/useTrips.ts`
- Create: `frontend/hooks/useDestinations.ts`
- Create: `frontend/hooks/useMapData.ts`

- [ ] **Step 1: Create hooks/useTrips.ts**

```typescript
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { Trip, TripListResponse } from "@/types";

export function useTrips(status?: string) {
  const { getToken } = useAuth();
  return useQuery<TripListResponse>({
    queryKey: ["trips", { status }],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      const params = status ? `?status=${status}` : "";
      return apiGet<TripListResponse>(`/trips${params}`, token);
    },
  });
}

export function useTrip(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<Trip>({
    queryKey: ["trips", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<Trip>(`/trips/${tripId}`, token);
    },
    enabled: !!tripId,
  });
}

export function useCreateTrip() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (data: Partial<Trip>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Trip>("/trips", token, data);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trips"] }),
  });
}

export function useUpdateTrip(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (data: Partial<Trip>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<Trip>(`/trips/${tripId}`, token, data);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trips"] });
      qc.invalidateQueries({ queryKey: ["trips", tripId] });
    },
  });
}

export function useDeleteTrip() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (tripId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/trips/${tripId}`, token);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trips"] }),
  });
}
```

- [ ] **Step 2: Create hooks/useDestinations.ts**

```typescript
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { Destination } from "@/types";

export function useDestinations(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<Destination[]>({
    queryKey: ["destinations", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<Destination[]>(`/trips/${tripId}/destinations`, token);
    },
    enabled: !!tripId,
  });
}

export function useAddDestination(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (data: Partial<Destination>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Destination>(`/trips/${tripId}/destinations`, token, data);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["destinations", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "countries"] });
      qc.invalidateQueries({ queryKey: ["map", "cities"] });
    },
  });
}

export function useDeleteDestination(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (destId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/destinations/${destId}`, token);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["destinations", tripId] });
      qc.invalidateQueries({ queryKey: ["map"] });
    },
  });
}
```

- [ ] **Step 3: Create hooks/useMapData.ts**

```typescript
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { MapCountry, MapCity } from "@/types";

export function useMapCountries() {
  const { getToken } = useAuth();
  return useQuery<MapCountry[]>({
    queryKey: ["map", "countries"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<MapCountry[]>("/map/countries", token);
    },
    staleTime: 5 * 60 * 1000, // 5 minutes — matches Redis TTL
  });
}

export function useMapCities() {
  const { getToken } = useAuth();
  return useQuery<MapCity[]>({
    queryKey: ["map", "cities"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<MapCity[]>("/map/cities", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}
```

- [ ] **Step 4: Commit**

```bash
cd /home/zach/Atlas
git add frontend/hooks/
git commit -m "feat(atlas): add TanStack Query hooks for trips, destinations, and map data"
```

---

## Task 6: MapLibre configuration and WorldMap component

**Files:**
- Create: `frontend/lib/maplibre.ts`
- Create: `frontend/components/map/MapControls.tsx`
- Create: `frontend/components/map/CountryPanel.tsx`
- Create: `frontend/components/map/WorldMap.tsx`
- Create: `frontend/app/(app)/map/page.tsx`

- [ ] **Step 1: Create lib/maplibre.ts**

```typescript
import type { StyleSpecification, LayerSpecification } from "maplibre-gl";
import type { MapCountry } from "@/types";

// Choropleth color expression using visit_count
// Data source: country_visits joined to PMTiles country features by ISO code
export function buildChoroplethExpression(visitData: MapCountry[]): maplibregl.ExpressionSpecification {
  const visitMap: Record<string, number> = {};
  for (const c of visitData) {
    visitMap[c.country_code] = c.visit_count;
  }

  // Step expression: ISO_A2 property from Protomaps tiles
  return [
    "case",
    ["==", ["get", "ISO_A2"], ""],
    "transparent",
    [
      "match",
      ["get", "ISO_A2"],
      ...Object.entries(visitMap).flatMap(([code, count]) => [
        code,
        count >= 5 ? "#4a90d9" : count >= 2 ? "#2e6aaa" : "#1e4a7a",
      ]),
      "transparent",
    ],
  ];
}

export const ATLAS_DARK_STYLE: StyleSpecification = {
  version: 8,
  glyphs: "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
  sprite: "https://demotiles.maplibre.org/styles/osm-bright-gl-style/sprite",
  sources: {
    protomaps: {
      type: "vector",
      url: `https://api.protomaps.com/tiles/v4.json?key=${process.env.NEXT_PUBLIC_PROTOMAPS_KEY ?? ""}`,
      attribution: "© <a href='https://protomaps.com'>Protomaps</a> © <a href='https://openstreetmap.org'>OpenStreetMap</a>",
    },
  },
  layers: [
    {
      id: "background",
      type: "background",
      paint: { "background-color": "#0a0e1a" },
    },
    {
      id: "water",
      type: "fill",
      source: "protomaps",
      "source-layer": "water",
      paint: { "fill-color": "#0d1829" },
    },
    {
      id: "country-fill",
      type: "fill",
      source: "protomaps",
      "source-layer": "countries",
      paint: {
        "fill-color": "transparent",
        "fill-opacity": 0.7,
      },
    },
    {
      id: "country-border",
      type: "line",
      source: "protomaps",
      "source-layer": "countries",
      paint: {
        "line-color": "#1e2d45",
        "line-width": 0.5,
      },
    },
  ],
};
```

- [ ] **Step 2: Create components/map/MapControls.tsx**

```typescript
"use client";

import { Globe2, Map } from "lucide-react";
import { useMapStore } from "@/store/mapStore";
import { cn } from "@/lib/utils";

export function MapControls({ onToggleProjection }: { onToggleProjection: () => void }) {
  const { projection } = useMapStore();

  return (
    <div className="absolute right-4 top-4 z-10 flex flex-col gap-1">
      <button
        onClick={onToggleProjection}
        className={cn(
          "flex h-8 w-8 items-center justify-center rounded border border-atlas-border bg-atlas-surface shadow-lg transition-colors hover:bg-atlas-border",
          "text-atlas-muted hover:text-atlas-text"
        )}
        title={projection === "globe" ? "Switch to flat map" : "Switch to globe"}
      >
        {projection === "globe" ? <Map size={14} /> : <Globe2 size={14} />}
      </button>
    </div>
  );
}
```

- [ ] **Step 3: Create components/map/CountryPanel.tsx**

```typescript
"use client";

import { X } from "lucide-react";
import Link from "next/link";
import { useMapStore } from "@/store/mapStore";
import { cn } from "@/lib/utils";

export function CountryPanel() {
  const { selectedCountry, setSelectedCountry } = useMapStore();

  if (!selectedCountry) return null;

  return (
    <div
      className={cn(
        "absolute right-0 top-0 h-full w-[380px] border-l border-atlas-border bg-atlas-surface z-20",
        "flex flex-col shadow-2xl"
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between border-b border-atlas-border px-5 py-4">
        <div>
          <h2 className="font-display text-xl font-semibold text-atlas-text">
            {selectedCountry.country_name}
          </h2>
          <p className="text-xs font-mono text-atlas-muted mt-0.5">
            {selectedCountry.country_code}
          </p>
        </div>
        <button
          onClick={() => setSelectedCountry(null)}
          className="text-atlas-muted hover:text-atlas-text transition-colors"
        >
          <X size={18} />
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-px border-b border-atlas-border bg-atlas-border">
        <Stat label="Visits" value={String(selectedCountry.visit_count)} />
        <Stat label="Nights" value={String(selectedCountry.total_nights || "—")} />
        <Stat
          label="First visit"
          value={
            selectedCountry.first_visit
              ? new Date(selectedCountry.first_visit).getFullYear().toString()
              : "—"
          }
        />
      </div>

      {/* Trips */}
      <div className="flex-1 overflow-y-auto p-5">
        <p className="text-xs uppercase tracking-widest text-atlas-muted mb-3">Trips here</p>
        {selectedCountry.trip_ids.length === 0 ? (
          <p className="text-atlas-muted text-sm">No trips logged yet.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {selectedCountry.trip_ids.map((id) => (
              <Link
                key={id}
                href={`/trips/${id}`}
                className="rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text hover:border-atlas-accent/50 transition-colors"
                onClick={() => setSelectedCountry(null)}
              >
                View trip →
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-atlas-surface flex flex-col items-center py-4">
      <span className="text-xl font-semibold text-atlas-text font-mono">{value}</span>
      <span className="text-xs text-atlas-muted mt-1">{label}</span>
    </div>
  );
}
```

- [ ] **Step 4: Create components/map/WorldMap.tsx**

This component is client-side only (MapLibre GL requires a DOM). It must be imported with `dynamic(..., { ssr: false })`.

```typescript
"use client";

import { useEffect, useRef, useCallback } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { useMapStore } from "@/store/mapStore";
import { useMapCountries, useMapCities } from "@/hooks/useMapData";
import { buildChoroplethExpression, ATLAS_DARK_STYLE } from "@/lib/maplibre";
import { MapControls } from "./MapControls";
import { CountryPanel } from "./CountryPanel";
import type { MapCountry } from "@/types";

export function WorldMap() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<maplibregl.Map | null>(null);
  const { projection, setProjection, setSelectedCountry } = useMapStore();
  const { data: countries = [] } = useMapCountries();
  const { data: cities = [] } = useMapCities();

  // Init map
  useEffect(() => {
    if (!mapContainer.current || map.current) return;

    map.current = new maplibregl.Map({
      container: mapContainer.current,
      style: ATLAS_DARK_STYLE,
      center: [10, 20],
      zoom: 1.5,
      projection: projection === "globe" ? "globe" : "mercator",
    } as maplibregl.MapOptions);

    map.current.addControl(new maplibregl.NavigationControl({ showCompass: false }), "bottom-right");

    map.current.on("click", "country-fill", (e) => {
      if (!e.features?.[0]) return;
      const props = e.features[0].properties as { ISO_A2?: string; NAME?: string };
      const code = props.ISO_A2;
      if (!code) return;
      const countryData = countries.find((c) => c.country_code === code);
      if (countryData) {
        setSelectedCountry(countryData);
      }
    });

    map.current.on("mouseenter", "country-fill", () => {
      if (map.current) map.current.getCanvas().style.cursor = "pointer";
    });
    map.current.on("mouseleave", "country-fill", () => {
      if (map.current) map.current.getCanvas().style.cursor = "";
    });

    return () => {
      map.current?.remove();
      map.current = null;
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Update choropleth when countries data changes
  useEffect(() => {
    if (!map.current || !map.current.isStyleLoaded() || countries.length === 0) return;
    const expr = buildChoroplethExpression(countries);
    map.current.setPaintProperty("country-fill", "fill-color", expr);
  }, [countries]);

  // Add city markers when cities data changes
  useEffect(() => {
    if (!map.current || !map.current.isStyleLoaded() || cities.length === 0) return;

    const geojson: GeoJSON.FeatureCollection = {
      type: "FeatureCollection",
      features: cities.map((c) => ({
        type: "Feature",
        geometry: { type: "Point", coordinates: [c.longitude, c.latitude] },
        properties: { city: c.city, country_name: c.country_name, trip_id: c.trip_id },
      })),
    };

    const src = map.current.getSource("city-points") as maplibregl.GeoJSONSource | undefined;
    if (src) {
      src.setData(geojson);
    } else {
      map.current.addSource("city-points", { type: "geojson", data: geojson });
      map.current.addLayer({
        id: "city-markers",
        type: "circle",
        source: "city-points",
        paint: {
          "circle-radius": 4,
          "circle-color": "#c9a84c",
          "circle-stroke-width": 1,
          "circle-stroke-color": "#0a0e1a",
        },
      });
    }
  }, [cities]);

  const handleToggleProjection = useCallback(() => {
    const next = projection === "globe" ? "mercator" : "globe";
    setProjection(next);
    if (map.current) {
      (map.current as maplibregl.Map).setProjection(next === "globe" ? "globe" : "mercator");
    }
  }, [projection, setProjection]);

  return (
    <div className="relative h-full w-full">
      <div ref={mapContainer} id="map-container" className="h-full w-full" />
      <MapControls onToggleProjection={handleToggleProjection} />
      <CountryPanel />
    </div>
  );
}
```

- [ ] **Step 5: Create app/(app)/map/page.tsx**

```typescript
import dynamic from "next/dynamic";

const WorldMap = dynamic(
  () => import("@/components/map/WorldMap").then((m) => m.WorldMap),
  {
    ssr: false,
    loading: () => (
      <div className="flex h-full items-center justify-center bg-atlas-bg">
        <p className="text-atlas-muted text-sm font-mono">Loading map...</p>
      </div>
    ),
  }
);

export default function MapPage() {
  return <WorldMap />;
}
```

- [ ] **Step 6: Run type-check**

```bash
cd /home/zach/Atlas/frontend
npm run type-check
```
Expected: no type errors.

- [ ] **Step 7: Commit**

```bash
cd /home/zach/Atlas
git add frontend/lib/maplibre.ts frontend/components/map/ frontend/app/\(app\)/map/
git commit -m "feat(atlas): add WorldMap with MapLibre GL globe, choropleth layer, country panel"
```

---

## Task 7: Trip list, TripCard, and TripForm

**Files:**
- Create: `frontend/components/ui/Button.tsx`
- Create: `frontend/components/ui/Input.tsx`
- Create: `frontend/components/ui/Select.tsx`
- Create: `frontend/components/trips/TripCard.tsx`
- Create: `frontend/components/trips/TripForm.tsx`
- Create: `frontend/app/(app)/trips/page.tsx`
- Create: `frontend/app/(app)/trips/new/page.tsx`
- Create: `frontend/__tests__/TripCard.test.tsx`
- Create: `frontend/__tests__/TripForm.test.tsx`

- [ ] **Step 1: Write failing tests**

Create `Atlas/frontend/__tests__/TripCard.test.tsx`:
```typescript
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import type { Trip } from "../types";

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
  it("renders trip title", async () => {
    const { TripCard } = await import("../components/trips/TripCard");
    render(<TripCard trip={mockTrip} />);
    expect(screen.getByText("Japan Spring 2025")).toBeInTheDocument();
  });

  it("renders status badge", async () => {
    const { TripCard } = await import("../components/trips/TripCard");
    render(<TripCard trip={mockTrip} />);
    expect(screen.getByText(/past/i)).toBeInTheDocument();
  });
});
```

Create `Atlas/frontend/__tests__/TripForm.test.tsx`:
```typescript
import { describe, it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

vi.mock("../hooks/useTrips", () => ({
  useCreateTrip: () => ({
    mutateAsync: vi.fn().mockResolvedValue({ id: "new-trip", title: "Test" }),
    isPending: false,
  }),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

describe("TripForm", () => {
  it("requires a title to submit", async () => {
    const { TripForm } = await import("../components/trips/TripForm");
    render(<TripForm />);
    const btn = screen.getByRole("button", { name: /save/i });
    await userEvent.click(btn);
    expect(await screen.findByText(/title is required/i)).toBeInTheDocument();
  });

  it("calls createTrip with form data on valid submit", async () => {
    const mockCreate = vi.fn().mockResolvedValue({ id: "t1", title: "Euro Trip" });
    vi.doMock("../hooks/useTrips", () => ({
      useCreateTrip: () => ({ mutateAsync: mockCreate, isPending: false }),
    }));
    const { TripForm } = await import("../components/trips/TripForm");
    render(<TripForm />);
    await userEvent.type(screen.getByLabelText(/title/i), "Euro Trip");
    await userEvent.click(screen.getByRole("button", { name: /save/i }));
    await waitFor(() => expect(mockCreate).toHaveBeenCalledWith(expect.objectContaining({ title: "Euro Trip" })));
  });
});
```

Run to verify failures:
```bash
npm run test -- __tests__/TripCard.test.tsx __tests__/TripForm.test.tsx
```
Expected: `Cannot find module`

- [ ] **Step 2: Create shared UI primitives**

Create `Atlas/frontend/components/ui/Button.tsx`:
```typescript
import { cn } from "@/lib/utils";
import type { ButtonHTMLAttributes } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: "sm" | "md";
  loading?: boolean;
}

const variants: Record<Variant, string> = {
  primary: "bg-atlas-accent text-atlas-bg hover:bg-atlas-accent/90",
  secondary: "bg-atlas-surface text-atlas-text border border-atlas-border hover:bg-atlas-border",
  ghost: "text-atlas-muted hover:text-atlas-text hover:bg-atlas-surface",
  danger: "bg-red-900/50 text-red-300 border border-red-800 hover:bg-red-900",
};

const sizes = {
  sm: "px-3 py-1.5 text-xs",
  md: "px-4 py-2 text-sm",
};

export function Button({ variant = "primary", size = "md", loading, className, children, ...props }: ButtonProps) {
  return (
    <button
      {...props}
      disabled={props.disabled ?? loading}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed",
        variants[variant],
        sizes[size],
        className
      )}
    >
      {loading ? <span className="h-3 w-3 animate-spin rounded-full border border-current border-t-transparent" /> : null}
      {children}
    </button>
  );
}
```

Create `Atlas/frontend/components/ui/Input.tsx`:
```typescript
import { cn } from "@/lib/utils";
import type { InputHTMLAttributes } from "react";
import { forwardRef } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, className, id, ...props }, ref) => {
    const inputId = id ?? label?.toLowerCase().replace(/\s+/g, "-");
    return (
      <div className="flex flex-col gap-1.5">
        {label && (
          <label htmlFor={inputId} className="text-xs font-medium text-atlas-muted uppercase tracking-wide">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          {...props}
          className={cn(
            "rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted",
            "focus:outline-none focus:ring-1 focus:ring-atlas-accent/50 focus:border-atlas-accent/50",
            "disabled:opacity-50",
            error && "border-red-700",
            className
          )}
        />
        {error && <p className="text-xs text-red-400">{error}</p>}
      </div>
    );
  }
);
Input.displayName = "Input";
```

Create `Atlas/frontend/components/ui/Select.tsx`:
```typescript
import { cn } from "@/lib/utils";
import type { SelectHTMLAttributes } from "react";
import { forwardRef } from "react";

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  options: { value: string; label: string }[];
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ label, error, options, className, id, ...props }, ref) => {
    const selectId = id ?? label?.toLowerCase().replace(/\s+/g, "-");
    return (
      <div className="flex flex-col gap-1.5">
        {label && (
          <label htmlFor={selectId} className="text-xs font-medium text-atlas-muted uppercase tracking-wide">
            {label}
          </label>
        )}
        <select
          ref={ref}
          id={selectId}
          {...props}
          className={cn(
            "rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text",
            "focus:outline-none focus:ring-1 focus:ring-atlas-accent/50",
            error && "border-red-700",
            className
          )}
        >
          {options.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
        {error && <p className="text-xs text-red-400">{error}</p>}
      </div>
    );
  }
);
Select.displayName = "Select";
```

- [ ] **Step 3: Create components/trips/TripCard.tsx**

```typescript
import Link from "next/link";
import { MapPin, Calendar } from "lucide-react";
import { cn, formatDateRange } from "@/lib/utils";
import type { Trip } from "@/types";

const STATUS_STYLES: Record<Trip["status"], string> = {
  past: "bg-atlas-visited/10 text-atlas-visited border border-atlas-visited/20",
  active: "bg-green-900/20 text-green-400 border border-green-800",
  planned: "bg-atlas-accent/10 text-atlas-accent border border-atlas-accent/20",
  dream: "bg-atlas-muted/10 text-atlas-muted border border-atlas-muted/20",
};

export function TripCard({ trip }: { trip: Trip }) {
  return (
    <Link
      href={`/trips/${trip.id}`}
      className={cn(
        "block rounded-lg border border-atlas-border bg-atlas-surface p-4",
        "hover:border-atlas-accent/40 transition-colors group"
      )}
    >
      <div className="flex items-start justify-between gap-3 mb-3">
        <h3 className="font-display text-base font-semibold text-atlas-text group-hover:text-atlas-accent transition-colors line-clamp-1">
          {trip.title}
        </h3>
        <span className={cn("shrink-0 rounded px-2 py-0.5 text-xs font-medium", STATUS_STYLES[trip.status])}>
          {trip.status}
        </span>
      </div>

      {trip.description && (
        <p className="text-sm text-atlas-muted line-clamp-2 mb-3">{trip.description}</p>
      )}

      <div className="flex items-center gap-4 text-xs text-atlas-muted">
        <span className="flex items-center gap-1">
          <Calendar size={12} />
          {formatDateRange(trip.start_date, trip.end_date)}
        </span>
        {trip.tags.length > 0 && (
          <span className="flex items-center gap-1">
            <MapPin size={12} />
            {trip.tags.slice(0, 2).join(", ")}
          </span>
        )}
      </div>
    </Link>
  );
}
```

- [ ] **Step 4: Create components/trips/TripForm.tsx**

```typescript
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useRouter } from "next/navigation";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import { useCreateTrip } from "@/hooks/useTrips";

const schema = z.object({
  title: z.string().min(1, "Title is required").max(120),
  description: z.string().max(500).optional(),
  status: z.enum(["past", "active", "planned", "dream"]),
  start_date: z.string().optional(),
  end_date: z.string().optional(),
  visibility: z.enum(["private", "shared", "public"]),
});

type FormValues = z.infer<typeof schema>;

const STATUS_OPTIONS = [
  { value: "past", label: "Past trip" },
  { value: "active", label: "Currently on this trip" },
  { value: "planned", label: "Planned" },
  { value: "dream", label: "Dream destination" },
];

const VISIBILITY_OPTIONS = [
  { value: "private", label: "Private" },
  { value: "shared", label: "Shared (link)" },
  { value: "public", label: "Public" },
];

export function TripForm() {
  const router = useRouter();
  const { mutateAsync: createTrip, isPending } = useCreateTrip();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { status: "past", visibility: "private" },
  });

  const onSubmit = async (data: FormValues) => {
    const trip = await createTrip(data);
    router.push(`/trips/${trip.id}`);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 max-w-lg">
      <Input
        label="Title"
        placeholder="Japan Spring 2025"
        error={errors.title?.message}
        {...register("title")}
      />
      <Input
        label="Description"
        placeholder="Optional notes about the trip"
        error={errors.description?.message}
        {...register("description")}
      />
      <div className="grid grid-cols-2 gap-4">
        <Input label="Start date" type="date" {...register("start_date")} />
        <Input label="End date" type="date" {...register("end_date")} />
      </div>
      <Select label="Status" options={STATUS_OPTIONS} {...register("status")} />
      <Select label="Visibility" options={VISIBILITY_OPTIONS} {...register("visibility")} />
      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>Save trip</Button>
        <Button type="button" variant="ghost" onClick={() => router.back()}>Cancel</Button>
      </div>
    </form>
  );
}
```

- [ ] **Step 5: Create trip pages**

Create `Atlas/frontend/app/(app)/trips/page.tsx`:
```typescript
import { Suspense } from "react";
import Link from "next/link";
import { Plus } from "lucide-react";

// Client component that uses TanStack Query
import { TripListClient } from "./TripListClient";

export default function TripsPage() {
  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <h1 className="font-display text-2xl font-semibold text-atlas-text">Trips</h1>
          <Link
            href="/trips/new"
            className="flex items-center gap-2 rounded bg-atlas-accent px-3 py-1.5 text-sm font-medium text-atlas-bg hover:bg-atlas-accent/90 transition-colors"
          >
            <Plus size={14} />
            New trip
          </Link>
        </div>
        <Suspense fallback={<div className="text-atlas-muted text-sm">Loading trips...</div>}>
          <TripListClient />
        </Suspense>
      </div>
    </div>
  );
}
```

Create `Atlas/frontend/app/(app)/trips/TripListClient.tsx`:
```typescript
"use client";

import { useTrips } from "@/hooks/useTrips";
import { TripCard } from "@/components/trips/TripCard";

export function TripListClient() {
  const { data, isLoading, error } = useTrips();

  if (isLoading) return <div className="text-atlas-muted text-sm">Loading...</div>;
  if (error) return <div className="text-red-400 text-sm">Failed to load trips.</div>;
  if (!data?.items.length) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <p className="text-atlas-muted">No trips yet.</p>
        <p className="text-atlas-muted text-sm mt-1">Add your first trip to get started.</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {data.items.map((trip) => (
        <TripCard key={trip.id} trip={trip} />
      ))}
    </div>
  );
}
```

Create `Atlas/frontend/app/(app)/trips/new/page.tsx`:
```typescript
import { TripForm } from "@/components/trips/TripForm";

export default function NewTripPage() {
  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-6">New Trip</h1>
        <TripForm />
      </div>
    </div>
  );
}
```

- [ ] **Step 6: Run trip tests**

```bash
cd /home/zach/Atlas/frontend
npm run test -- __tests__/TripCard.test.tsx __tests__/TripForm.test.tsx
```
Expected: all 4 tests `PASSED`.

- [ ] **Step 7: Commit**

```bash
cd /home/zach/Atlas
git add frontend/components/ui/ frontend/components/trips/ frontend/app/\(app\)/trips/ frontend/__tests__/TripCard.test.tsx frontend/__tests__/TripForm.test.tsx
git commit -m "feat(atlas): add TripCard, TripForm, trip list and create pages"
```

---

## Task 8: Trip detail page and DestinationForm

**Files:**
- Create: `frontend/components/trips/DestinationForm.tsx`
- Create: `frontend/app/(app)/trips/[id]/page.tsx`
- Create: `frontend/app/(app)/trips/[id]/destinations/new/page.tsx`

- [ ] **Step 1: Create components/trips/DestinationForm.tsx**

```typescript
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useRouter } from "next/navigation";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { useAddDestination } from "@/hooks/useDestinations";

const schema = z.object({
  city: z.string().min(1, "City is required"),
  country_code: z.string().length(2, "2-letter ISO code required").toUpperCase(),
  country_name: z.string().min(1, "Country name is required"),
  region: z.string().optional(),
  arrival_date: z.string().optional(),
  departure_date: z.string().optional(),
  latitude: z.coerce.number().min(-90).max(90).optional().or(z.literal("")),
  longitude: z.coerce.number().min(-180).max(180).optional().or(z.literal("")),
  notes: z.string().optional(),
  rating: z.coerce.number().min(1).max(5).optional().or(z.literal("")),
});

type FormValues = z.infer<typeof schema>;

export function DestinationForm({ tripId }: { tripId: string }) {
  const router = useRouter();
  const { mutateAsync: addDestination, isPending } = useAddDestination(tripId);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema) });

  const onSubmit = async (data: FormValues) => {
    const payload = {
      ...data,
      latitude: data.latitude === "" ? undefined : data.latitude,
      longitude: data.longitude === "" ? undefined : data.longitude,
      rating: data.rating === "" ? undefined : data.rating,
    };
    await addDestination(payload);
    router.push(`/trips/${tripId}`);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5 max-w-lg">
      <div className="grid grid-cols-2 gap-4">
        <Input label="City" placeholder="Tokyo" error={errors.city?.message} {...register("city")} />
        <Input label="Country code" placeholder="JP" error={errors.country_code?.message} {...register("country_code")} />
      </div>
      <Input label="Country name" placeholder="Japan" error={errors.country_name?.message} {...register("country_name")} />
      <div className="grid grid-cols-2 gap-4">
        <Input label="Arrival date" type="date" {...register("arrival_date")} />
        <Input label="Departure date" type="date" {...register("departure_date")} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Input label="Latitude" placeholder="35.6762" type="number" step="any" {...register("latitude")} />
        <Input label="Longitude" placeholder="139.6503" type="number" step="any" {...register("longitude")} />
      </div>
      <Input label="Notes" placeholder="Optional notes" {...register("notes")} />
      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={isPending}>Add destination</Button>
        <Button type="button" variant="ghost" onClick={() => router.back()}>Cancel</Button>
      </div>
    </form>
  );
}
```

- [ ] **Step 2: Create app/(app)/trips/[id]/page.tsx**

```typescript
"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { Plus, MapPin, Calendar } from "lucide-react";
import { useTrip } from "@/hooks/useTrips";
import { useDestinations } from "@/hooks/useDestinations";
import { formatDateRange, nightsLabel } from "@/lib/utils";

export default function TripDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data: trip, isLoading: tripLoading } = useTrip(id);
  const { data: destinations = [], isLoading: destLoading } = useDestinations(id);

  if (tripLoading) return <div className="p-6 text-atlas-muted text-sm">Loading...</div>;
  if (!trip) return <div className="p-6 text-red-400 text-sm">Trip not found.</div>;

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <Link href="/trips" className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block">
            ← All trips
          </Link>
          <h1 className="font-display text-3xl font-semibold text-atlas-text">{trip.title}</h1>
          {trip.description && (
            <p className="text-atlas-muted mt-2 text-sm">{trip.description}</p>
          )}
          <p className="text-xs font-mono text-atlas-muted mt-2">
            {formatDateRange(trip.start_date, trip.end_date)}
          </p>
        </div>

        {/* Destinations */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Destinations
            </h2>
            <Link
              href={`/trips/${id}/destinations/new`}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              Add destination
            </Link>
          </div>

          {destLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!destLoading && destinations.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No destinations yet. Add one to start building your itinerary.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {destinations.map((dest) => (
              <div
                key={dest.id}
                className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0">
                  <MapPin size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-atlas-text">{dest.city}</p>
                  <p className="text-xs text-atlas-muted">{dest.country_name}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-xs font-mono text-atlas-muted">
                    {dest.arrival_date ?? "—"}
                  </p>
                  <p className="text-xs text-atlas-muted">{nightsLabel(dest.nights)}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Create app/(app)/trips/[id]/destinations/new/page.tsx**

```typescript
import { DestinationForm } from "@/components/trips/DestinationForm";

export default function NewDestinationPage({ params }: { params: { id: string } }) {
  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-6">Add Destination</h1>
        <DestinationForm tripId={params.id} />
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run type-check**

```bash
cd /home/zach/Atlas/frontend
npm run type-check
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
cd /home/zach/Atlas
git add frontend/components/trips/DestinationForm.tsx frontend/app/\(app\)/trips/\[id\]/
git commit -m "feat(atlas): add TripDetail page, DestinationForm, and add-destination flow"
```

---

## Task 9: Placeholder pages and smoke test

**Files:**
- Create: `frontend/app/(app)/plan/page.tsx`
- Create: `frontend/app/(app)/discover/page.tsx`
- Create: `frontend/app/(app)/stats/page.tsx`
- Create: `frontend/app/(app)/settings/page.tsx`

These are Phase 4/5/6 pages — stubs now so the sidebar links don't 404.

- [ ] **Step 1: Create placeholder pages**

For each of these files, use the same pattern:

Create `Atlas/frontend/app/(app)/plan/page.tsx`:
```typescript
export default function PlanPage() {
  return (
    <div className="flex h-full items-center justify-center">
      <div className="text-center">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-2">Plan</h1>
        <p className="text-atlas-muted text-sm">Future trips & bucket list — coming in Phase 4</p>
      </div>
    </div>
  );
}
```

Create `Atlas/frontend/app/(app)/discover/page.tsx`:
```typescript
export default function DiscoverPage() {
  return (
    <div className="flex h-full items-center justify-center">
      <div className="text-center">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-2">Discover</h1>
        <p className="text-atlas-muted text-sm">AI destination recommendations — coming in Phase 5</p>
      </div>
    </div>
  );
}
```

Create `Atlas/frontend/app/(app)/stats/page.tsx`:
```typescript
export default function StatsPage() {
  return (
    <div className="flex h-full items-center justify-center">
      <div className="text-center">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-2">Stats</h1>
        <p className="text-atlas-muted text-sm">Travel analytics dashboard — coming in Phase 6</p>
      </div>
    </div>
  );
}
```

Create `Atlas/frontend/app/(app)/settings/page.tsx`:
```typescript
export default function SettingsPage() {
  return (
    <div className="flex h-full items-center justify-center">
      <div className="text-center">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-2">Settings</h1>
        <p className="text-atlas-muted text-sm">Account settings — coming soon</p>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Run full test suite**

```bash
cd /home/zach/Atlas/frontend
npm run test
npm run type-check
```
Expected: all tests pass, no type errors.

- [ ] **Step 3: Build check**

```bash
cd /home/zach/Atlas/frontend
npm run build
```
Expected: successful production build.

- [ ] **Step 4: End-to-end smoke test (manual)**

With `docker compose up` running:
1. Open `http://localhost:3000` — should redirect to `/map`
2. Should redirect to Clerk sign-in
3. Sign in — should land on `/map` with globe
4. Navigate to `/trips` — should show empty state
5. Click "New trip" — should show form
6. Create a trip — should redirect to trip detail
7. Add a destination with lat/lng — should return to trip detail
8. Navigate back to `/map` — city marker should appear

- [ ] **Step 5: Final commit**

```bash
cd /home/zach/Atlas
git add frontend/app/\(app\)/plan/ frontend/app/\(app\)/discover/ frontend/app/\(app\)/stats/ frontend/app/\(app\)/settings/
git commit -m "feat(atlas): add placeholder pages for Plan, Discover, Stats, Settings"
```

---

## Phase 1 Frontend Quality Checklist

Before marking Phase 1 frontend done:

- [ ] `npm run type-check` — zero errors
- [ ] `npm run test` — all tests pass
- [ ] `npm run build` — production build succeeds
- [ ] Sign-in/sign-up via Clerk works end-to-end
- [ ] `/map` renders globe with dark cartographic style
- [ ] Country choropleth fills correctly after adding destinations
- [ ] Clicking a country opens the slide-in panel
- [ ] Globe ↔ flat toggle persists across page reloads (localStorage)
- [ ] City markers appear for destinations with coordinates
- [ ] Trip list shows all trips; empty state shown when none
- [ ] Create trip form validates and redirects on success
- [ ] Add destination form validates and triggers map update
- [ ] Sidebar active state correct for all nav items
- [ ] All font families rendering (Playfair Display, IBM Plex Sans, IBM Plex Mono)
- [ ] Design tokens match CLAUDE.md (`--atlas-bg: #0a0e1a` etc.)
