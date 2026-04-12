"""Async client for Open-Meteo geocoding and climate APIs.

Both APIs are free with no API key required.
"""
from __future__ import annotations
import logging
from collections import defaultdict

import httpx

logger = logging.getLogger(__name__)

GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"
CLIMATE_URL = "https://climate-api.open-meteo.com/v1/climate"


async def geocode(name: str) -> tuple[float, float, str]:
    """Return (latitude, longitude, display_name) for a place name.

    Raises ValueError if the location cannot be found.
    """
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            GEOCODING_URL,
            params={"name": name, "count": 1, "language": "en", "format": "json"},
        )
        resp.raise_for_status()
        results = resp.json().get("results") or []
    if not results:
        raise ValueError(f"Location not found: {name!r}")
    r = results[0]
    display = f"{r['name']}, {r.get('country', '')}"
    return float(r["latitude"]), float(r["longitude"]), display


async def fetch_monthly_averages(lat: float, lng: float) -> list[dict]:
    """Fetch 30-year (1991-2020) monthly climate averages.

    Returns a list of 12 dicts:
        {"month": 1-12, "avg_max_temp_c": float, "avg_precipitation_mm": float}
    """
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(
            CLIMATE_URL,
            params={
                "latitude": lat,
                "longitude": lng,
                "start_date": "1991-01-01",
                "end_date": "2020-12-31",
                "monthly": "temperature_2m_max,precipitation_sum",
                "models": "EC_Earth3P_HR",
            },
        )
        resp.raise_for_status()
        data = resp.json()

    monthly = data.get("monthly", {})
    times: list[str] = monthly.get("time", [])
    temps: list[float | None] = monthly.get("temperature_2m_max", [])
    precips: list[float | None] = monthly.get("precipitation_sum", [])

    # Aggregate: group by calendar month (1-12) and average across years
    temp_by_month: dict[int, list[float]] = defaultdict(list)
    precip_by_month: dict[int, list[float]] = defaultdict(list)

    for i, t in enumerate(times):
        month = int(t.split("-")[1])  # "1991-01" → 1
        if i < len(temps) and temps[i] is not None:
            temp_by_month[month].append(temps[i])
        if i < len(precips) and precips[i] is not None:
            precip_by_month[month].append(precips[i])

    return [
        {
            "month": m,
            "avg_max_temp_c": round(sum(temp_by_month[m]) / len(temp_by_month[m]), 1)
            if temp_by_month[m] else 0.0,
            "avg_precipitation_mm": round(sum(precip_by_month[m]) / len(precip_by_month[m]), 1)
            if precip_by_month[m] else 0.0,
        }
        for m in range(1, 13)
    ]


def pick_best_months(monthly: list[dict]) -> list[int]:
    """Return month numbers (1-12) where max temp is 15-28°C and precip < 120mm."""
    return [
        entry["month"]
        for entry in monthly
        if 15.0 <= entry["avg_max_temp_c"] <= 28.0
        and entry["avg_precipitation_mm"] < 120.0
    ]
