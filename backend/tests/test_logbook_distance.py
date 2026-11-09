"""Synthetic coordinates on a sphere of mean radius 6371.0088 km.

These check the shared geometry helper, not automatic distance calculation
when a logbook entry is saved (the API stores the supplied distance).
"""

import pytest

from app.services.adsb.geo import haversine_km


@pytest.mark.parametrize(
    "origin,destination,expected_km",
    [
        ((0.0, 0.0), (0.0, 0.0), 0.0),
        ((0.0, 0.0), (0.0, 1.0), 111.195080),
        ((0.0, 179.0), (0.0, -179.0), 222.390160),
        ((89.0, 0.0), (89.0, 180.0), 222.390160),
        ((0.0, 0.0), (0.0, 180.0), 20015.114442),
    ],
    ids=["coincident", "equatorial-degree", "antimeridian", "over-pole", "antipodal"],
)
def test_synthetic_great_circle_distance(origin, destination, expected_km):
    # Fixed arc-length references; one metre tolerance, independent of route direction.
    assert haversine_km(*origin, *destination) == pytest.approx(expected_km, abs=0.001, rel=0)
    assert haversine_km(*destination, *origin) == pytest.approx(expected_km, abs=0.001, rel=0)
