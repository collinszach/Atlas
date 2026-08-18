import type { StyleSpecification } from "maplibre-gl";

export const ATLAS_DARK_STYLE: StyleSpecification = {
  version: 8,
  glyphs: "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
  sprite: "https://demotiles.maplibre.org/styles/osm-bright-gl-style/sprite",
  sources: {
    protomaps: {
      type: "vector",
      url: `https://api.protomaps.com/tiles/v4.json?key=${process.env.NEXT_PUBLIC_PROTOMAPS_KEY ?? ""}`,
      attribution:
        "© <a href='https://protomaps.com'>Protomaps</a> © <a href='https://openstreetmap.org'>OpenStreetMap</a>",
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
