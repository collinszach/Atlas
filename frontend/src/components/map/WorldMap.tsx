"use client";

import { useEffect, useRef, useCallback } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { useMapStore } from "@/store/mapStore";
import { useMapCountries, useMapCities, useMapArcs } from "@/hooks/useMapData";
import { buildChoroplethExpression, ATLAS_DARK_STYLE } from "@/lib/maplibre";
import { MapControls } from "./MapControls";
import { CountryPanel } from "./CountryPanel";

export function WorldMap() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<maplibregl.Map | null>(null);
  const { projection, setProjection, setSelectedCountry } = useMapStore();
  const { data: countries = [] } = useMapCountries();
  const { data: cities = [] } = useMapCities();
  const { data: arcs = [] } = useMapArcs();
  const countriesRef = useRef(countries);

  useEffect(() => { countriesRef.current = countries; }, [countries]);

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
      const countryData = countriesRef.current.find((c) => c.country_code === code);
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

  // Flight arc layer
  useEffect(() => {
    if (!map.current || !map.current.isStyleLoaded() || arcs.length === 0) return;

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
          trip_id: a.trip_id,
        },
      })),
    };

    const src = map.current.getSource("flight-arcs") as maplibregl.GeoJSONSource | undefined;
    if (src) {
      src.setData(geojson);
    } else {
      map.current.addSource("flight-arcs", { type: "geojson", data: geojson });
      map.current.addLayer(
        {
          id: "flight-arcs",
          type: "line",
          source: "flight-arcs",
          paint: {
            "line-color": "#4a90d9",
            "line-width": 1,
            "line-opacity": 0.5,
          },
        },
        map.current.getLayer("city-markers") ? "city-markers" : undefined,
      );
    }
  }, [arcs]);

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
      <CountryPanel />
    </div>
  );
}
