"use client";

import { useState } from "react";
import { Plus, MapPin, Globe, Trash2, Star, Sparkles, Loader2 } from "lucide-react";
import { useTrips } from "@/hooks/useTrips";
import { useBucketList, useDeleteBucketListItem, useAddBucketListItem, useEnrichBucketListItem } from "@/hooks/useBucketList";
import type { BucketListItem } from "@/types";

const SEASON_LABELS: Record<string, string> = {
  spring: "Spring",
  summer: "Summer",
  fall: "Fall",
  winter: "Winter",
  any: "Any time",
};

const PRIORITY_COLORS: Record<number, string> = {
  5: "text-amber-400",
  4: "text-atlas-accent",
  3: "text-atlas-text",
  2: "text-atlas-muted",
  1: "text-atlas-muted",
};

function PriorityStars({ priority }: { priority: number }) {
  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((n) => (
        <Star
          key={n}
          size={10}
          className={n <= priority ? (PRIORITY_COLORS[priority] ?? "text-atlas-muted") : "text-atlas-border"}
          fill={n <= priority ? "currentColor" : "none"}
        />
      ))}
    </div>
  );
}

function BucketCard({
  item,
  onDelete,
  onEnrich,
  isEnriching,
}: {
  item: BucketListItem;
  onDelete: () => void;
  onEnrich: () => void;
  isEnriching: boolean;
}) {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-start gap-4">
      <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0 mt-0.5">
        <Globe size={14} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-atlas-text">
          {item.city ? `${item.city}, ` : ""}{item.country_name ?? item.country_code}
        </p>
        {item.reason && (
          <p className="text-xs text-atlas-muted mt-0.5 line-clamp-2">{item.reason}</p>
        )}
        {item.ai_summary && (
          <blockquote className="mt-2 border-l-2 border-atlas-accent/40 pl-3 text-xs italic text-atlas-muted leading-relaxed">
            {item.ai_summary}
          </blockquote>
        )}
        <div className="flex items-center gap-3 mt-1.5">
          <PriorityStars priority={item.priority} />
          {item.ideal_season && (
            <span className="text-xs text-atlas-muted font-mono">
              {SEASON_LABELS[item.ideal_season] ?? item.ideal_season}
            </span>
          )}
          {!item.ai_summary && (
            <button
              onClick={onEnrich}
              disabled={isEnriching}
              className="flex items-center gap-1 text-xs text-atlas-muted hover:text-atlas-accent transition-colors disabled:opacity-50"
            >
              {isEnriching ? (
                <Loader2 size={10} className="animate-spin" />
              ) : (
                <Sparkles size={10} />
              )}
              Enrich
            </button>
          )}
        </div>
      </div>
      <button
        onClick={onDelete}
        className="text-atlas-muted hover:text-red-400 transition-colors shrink-0 mt-0.5"
        aria-label="Remove from bucket list"
      >
        <Trash2 size={14} />
      </button>
    </div>
  );
}

export default function PlanPage() {
  const [showAddForm, setShowAddForm] = useState(false);
  const [addCity, setAddCity] = useState("");
  const [addCountry, setAddCountry] = useState("");
  const [addReason, setAddReason] = useState("");

  const [enrichingId, setEnrichingId] = useState<string | null>(null);

  const { data: tripsData, isLoading: tripsLoading } = useTrips();
  const trips = tripsData?.items ?? [];
  const { data: bucketList = [], isLoading: bucketLoading } = useBucketList();
  const deleteItem = useDeleteBucketListItem();
  const addItem = useAddBucketListItem();
  const enrichItem = useEnrichBucketListItem();

  async function handleEnrich(id: string) {
    setEnrichingId(id);
    try {
      await enrichItem.mutateAsync(id);
    } finally {
      setEnrichingId(null);
    }
  }

  const plannedTrips = trips.filter((t) => t.status === "planned" || t.status === "dream");

  async function handleAdd() {
    if (!addCountry.trim()) return;
    await addItem.mutateAsync({
      city: addCity.trim() || undefined,
      country_name: addCountry.trim(),
      priority: 3,
      reason: addReason.trim() || undefined,
    });
    setAddCity("");
    setAddCountry("");
    setAddReason("");
    setShowAddForm(false);
  }

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        {/* Future Trips */}
        <div className="mb-10">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Future Trips
            </h2>
            <a
              href="/trips"
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              New trip
            </a>
          </div>

          {tripsLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!tripsLoading && plannedTrips.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No planned trips yet. Create a trip with status &ldquo;planned&rdquo; or &ldquo;dream&rdquo;.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {plannedTrips.map((trip) => (
              <a
                key={trip.id}
                href={`/trips/${trip.id}`}
                className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4 hover:border-atlas-accent/40 transition-colors"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-planned/20 text-atlas-accent shrink-0">
                  <MapPin size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-atlas-text">{trip.title}</p>
                  <p className="text-xs text-atlas-muted capitalize">{trip.status}</p>
                </div>
                {trip.start_date && (
                  <p className="text-xs font-mono text-atlas-muted shrink-0">{trip.start_date}</p>
                )}
              </a>
            ))}
          </div>
        </div>

        {/* Bucket List */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Bucket List
            </h2>
            <button
              onClick={() => setShowAddForm((v) => !v)}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              Add destination
            </button>
          </div>

          {showAddForm && (
            <div className="mb-4 rounded-lg border border-atlas-border bg-atlas-surface p-4 flex flex-col gap-3">
              <input
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
                placeholder="Country (required)"
                value={addCountry}
                onChange={(e) => setAddCountry(e.target.value)}
              />
              <input
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
                placeholder="City (optional)"
                value={addCity}
                onChange={(e) => setAddCity(e.target.value)}
              />
              <input
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
                placeholder="Why do you want to go? (optional)"
                value={addReason}
                onChange={(e) => setAddReason(e.target.value)}
              />
              <div className="flex gap-2 justify-end">
                <button
                  onClick={() => setShowAddForm(false)}
                  className="px-3 py-1.5 text-xs text-atlas-muted hover:text-atlas-text transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleAdd}
                  disabled={!addCountry.trim() || addItem.isPending}
                  className="px-3 py-1.5 text-xs rounded bg-atlas-accent text-atlas-bg font-medium hover:bg-atlas-accent/80 transition-colors disabled:opacity-50"
                >
                  {addItem.isPending ? "Adding\u2026" : "Add"}
                </button>
              </div>
            </div>
          )}

          {bucketLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!bucketLoading && bucketList.length === 0 && !showAddForm && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              Your bucket list is empty. Add a destination to get started.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {bucketList.map((item) => (
              <BucketCard
                key={item.id}
                item={item}
                onDelete={() => deleteItem.mutate(item.id)}
                onEnrich={() => handleEnrich(item.id)}
                isEnriching={enrichingId === item.id}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
