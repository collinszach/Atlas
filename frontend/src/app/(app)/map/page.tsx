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
