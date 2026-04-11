#!/usr/bin/env python3
"""
Seed the countries table from Natural Earth 110m admin-0 data.

Usage (from inside the backend container):
    python scripts/seed_countries.py

Downloads ~1MB shapefile on first run. Safe to re-run (upserts by country code).
"""
import io
import logging
import os
import urllib.request
import zipfile

import psycopg2
from shapely.geometry import MultiPolygon, shape
import fiona

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

NE_URL = "https://naciscdn.org/naturalearth/110m/cultural/ne_110m_admin_0_countries.zip"

ISO_A2_FIELD = "ISO_A2"
NAME_FIELD = "NAME"
NAME_LONG_FIELD = "NAME_LONG"
CONTINENT_FIELD = "CONTINENT"


def download_shapefile() -> bytes:
    logger.info("Downloading Natural Earth 110m countries shapefile...")
    with urllib.request.urlopen(NE_URL) as resp:
        return resp.read()


def parse_shapefile(zip_bytes: bytes) -> list[dict]:
    records: list[dict] = []
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        zf.extractall("/tmp/ne_countries")
        shp_name = next(n for n in zf.namelist() if n.endswith(".shp"))

    with fiona.open(f"/tmp/ne_countries/{shp_name.split('/')[-1]}") as src:
        for feature in src:
            props = feature["properties"]
            iso: str = (props.get(ISO_A2_FIELD) or "").strip()
            if not iso or iso == "-99":
                continue
            geom = shape(feature["geometry"])
            if geom.geom_type == "Polygon":
                geom = MultiPolygon([geom])
            records.append({
                "code": iso,
                "name": props.get(NAME_FIELD, ""),
                "name_long": props.get(NAME_LONG_FIELD, ""),
                "continent": props.get(CONTINENT_FIELD, ""),
                "wkt": geom.wkt,
            })
    logger.info("Parsed %d country records", len(records))
    return records


def seed(records: list[dict], database_url: str) -> None:
    dsn = database_url.replace("postgresql+psycopg2://", "postgresql://")
    with psycopg2.connect(dsn) as conn:
        with conn.cursor() as cur:
            for rec in records:
                cur.execute(
                    """
                    INSERT INTO countries (code, name, name_long, continent, geometry)
                    VALUES (%s, %s, %s, %s, ST_Multi(ST_GeomFromText(%s, 4326)))
                    ON CONFLICT (code) DO UPDATE SET
                        name = EXCLUDED.name,
                        name_long = EXCLUDED.name_long,
                        continent = EXCLUDED.continent,
                        geometry = EXCLUDED.geometry
                    """,
                    (rec["code"], rec["name"], rec["name_long"], rec["continent"], rec["wkt"]),
                )
        conn.commit()
    logger.info("Upserted %d countries", len(records))


if __name__ == "__main__":
    _database_url = os.environ.get("DATABASE_URL_SYNC")
    if not _database_url:
        raise RuntimeError("DATABASE_URL_SYNC environment variable is not set")
    zip_bytes = download_shapefile()
    records = parse_shapefile(zip_bytes)
    seed(records, _database_url)
    logger.info("Country seed complete.")
