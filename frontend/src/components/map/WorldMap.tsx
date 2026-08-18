"use client";

import { useEffect, useRef, useCallback, useState } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { useMapStore } from "@/store/mapStore";
import { useMapArcs } from "@/hooks/useMapData";
import { ATLAS_DARK_STYLE } from "@/lib/maplibre";
import { MapControls } from "./MapControls";

export function WorldMap() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<maplibregl.Map | null>(null);
  const { projection, setProjection } = useMapStore();
  const { data: arcs = [] } = useMapArcs();
  const [mapLoaded, setMapLoaded] = useState(false);

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

    map.current.on("load", () => setMapLoaded(true));

    map.current.addControl(new maplibregl.NavigationControl({ showCompass: false }), "bottom-right");

    return () => {
      map.current?.remove();
      map.current = null;
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Flight arc layer
  useEffect(() => {
    if (!map.current || !mapLoaded || arcs.length === 0) return;

    const geojson: GeoJSON.FeatureCollection = {
      type: "FeatureCollection",
      features: arcs.map((a) => ({
        type: "Feature",
        geometry: {
          type: "LineString",
          coordinates: [
            [a.origin_lng, a.origin_lat],
            [a.dest_lng, a.dest_lat],
          ],
        },
        properties: {
          flight_number: a.flight_number,
        },
      })),
    };

    const src = map.current.getSource("flight-arcs") as maplibregl.GeoJSONSource | undefined;
    if (src) {
      src.setData(geojson);
    } else {
      map.current.addSource("flight-arcs", { type: "geojson", data: geojson });
      map.current.addLayer({
        id: "flight-arcs",
        type: "line",
        source: "flight-arcs",
        paint: {
          "line-color": "#4a90d9",
          "line-width": 1,
          "line-opacity": 0.5,
        },
      });
    }
  }, [arcs, mapLoaded]);

  const handleToggleProjection = useCallback(() => {
    const next = projection === "globe" ? "mercator" : "globe";
    setProjection(next);
    if (map.current) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (map.current as any).setProjection(next === "globe" ? "globe" : "mercator");
    }
  }, [projection, setProjection]);

  return (
    <div className="relative h-full w-full">
      <div ref={mapContainer} id="map-container" className="h-full w-full" />
      <MapControls onToggleProjection={handleToggleProjection} />
    </div>
  );
}
