"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  Plus, MapPin, Plane, Car, Train, Ship, Bus, Footprints, GripVertical,
} from "lucide-react";
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
  arrayMove,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useAuth } from "@clerk/nextjs";
import { useQueryClient } from "@tanstack/react-query";
import { useTrip } from "@/hooks/useTrips";
import { useDestinations } from "@/hooks/useDestinations";
import { useTransport } from "@/hooks/useTransport";
import { formatDateRange, nightsLabel } from "@/lib/utils";
import { apiPatch } from "@/lib/api";
import type { TransportLeg, Destination } from "@/types";

const TRANSPORT_ICONS: Record<TransportLeg["type"], React.ReactNode> = {
  flight: <Plane size={14} />,
  car: <Car size={14} />,
  train: <Train size={14} />,
  ferry: <Ship size={14} />,
  bus: <Bus size={14} />,
  walk: <Footprints size={14} />,
  other: <MapPin size={14} />,
};

function transportLabel(leg: TransportLeg): string {
  if (leg.origin_city && leg.dest_city) {
    return `${leg.origin_city} → ${leg.dest_city}`;
  }
  if (leg.origin_iata && leg.dest_iata) {
    return `${leg.origin_iata} → ${leg.dest_iata}`;
  }
  return leg.flight_number ?? leg.type;
}

function SortableDestination({ dest }: { dest: Destination }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } =
    useSortable({ id: dest.id });

  const style = {
    transform: CSS.Transform.toString(transform) ?? undefined,
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4"
    >
      <button
        {...attributes}
        {...listeners}
        className="text-atlas-muted hover:text-atlas-text cursor-grab active:cursor-grabbing shrink-0"
        aria-label="Drag to reorder"
      >
        <GripVertical size={14} />
      </button>
      <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0">
        <MapPin size={14} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-atlas-text">{dest.city}</p>
        <p className="text-xs text-atlas-muted">{dest.country_name}</p>
      </div>
      <div className="text-right shrink-0">
        <p className="text-xs font-mono text-atlas-muted">{dest.arrival_date ?? "—"}</p>
        <p className="text-xs text-atlas-muted">{nightsLabel(dest.nights)}</p>
      </div>
    </div>
  );
}

export default function TripDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { getToken } = useAuth();
  const qc = useQueryClient();
  const { data: trip, isLoading: tripLoading } = useTrip(id);
  const { data: destinations = [], isLoading: destLoading } = useDestinations(id);
  const { data: transport = [], isLoading: transportLoading } = useTransport(id);

  const [orderedDests, setOrderedDests] = useState<Destination[]>(destinations);
  const isDraggingRef = useRef(false);
  useEffect(() => {
    if (!isDraggingRef.current) setOrderedDests(destinations);
  }, [destinations]);

  const sensors = useSensors(useSensor(PointerSensor));

  function handleDragStart() {
    isDraggingRef.current = true;
  }

  async function handleDragEnd(event: DragEndEvent) {
    isDraggingRef.current = false;
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    const oldIndex = orderedDests.findIndex((d) => d.id === String(active.id));
    const newIndex = orderedDests.findIndex((d) => d.id === String(over.id));
    const reordered = arrayMove(orderedDests, oldIndex, newIndex);
    setOrderedDests(reordered);  // optimistic
    const token = await getToken();
    if (!token) return;
    try {
      await apiPatch(
        `/trips/${id}/destinations/reorder`,
        token,
        reordered.map((d, i) => ({ id: d.id, order_index: i }))
      );
      qc.invalidateQueries({ queryKey: ["destinations", id] });
    } catch {
      setOrderedDests(orderedDests);  // roll back on failure
    }
  }

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
        <div className="mb-10">
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

          <DndContext sensors={sensors} collisionDetection={closestCenter} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
            <SortableContext
              items={orderedDests.map((d) => d.id)}
              strategy={verticalListSortingStrategy}
            >
              <div className="flex flex-col gap-2">
                {orderedDests.map((dest) => (
                  <SortableDestination key={dest.id} dest={dest} />
                ))}
              </div>
            </SortableContext>
          </DndContext>
        </div>

        {/* Transport */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Transport
            </h2>
            <Link
              href={`/trips/${id}/transport/new`}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              Log transport
            </Link>
          </div>

          {transportLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!transportLoading && transport.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No transport logged yet.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {transport.map((leg) => (
              <div
                key={leg.id}
                className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent-cool/10 text-atlas-accent-cool shrink-0">
                  {TRANSPORT_ICONS[leg.type]}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-atlas-text">{transportLabel(leg)}</p>
                  <p className="text-xs text-atlas-muted capitalize">
                    {leg.type}
                    {leg.airline ? ` · ${leg.airline}` : ""}
                    {leg.flight_number ? ` ${leg.flight_number}` : ""}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  {leg.departure_at && (
                    <p className="text-xs font-mono text-atlas-muted">
                      {leg.departure_at.slice(0, 10)}
                    </p>
                  )}
                  {leg.duration_min != null && (
                    <p className="text-xs text-atlas-muted">
                      {Math.floor(leg.duration_min / 60)}h {leg.duration_min % 60}m
                    </p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
