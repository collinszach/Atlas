from __future__ import annotations
import math


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometers between two lat/lon points."""
    r = 6371.0088  # mean Earth radius, km
    p1, p2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(d_lambda / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def km_to_nm(km: float) -> float:
    return km / 1.852


def nm_to_km(nm: float) -> float:
    return nm * 1.852


def project_position(
    lat: float, lon: float, bearing_deg: float, distance_km: float
) -> tuple[float, float]:
    """Great-circle destination from a point, given a bearing and distance.

    Used for dead reckoning an aircraft forward along its current track. Uses
    the spherical formula rather than a flat approximation so it stays honest
    at the 250nm radius the ADS-B sources allow.
    """
    r = 6371.0088
    delta = distance_km / r
    theta = math.radians(bearing_deg)
    phi1, lambda1 = math.radians(lat), math.radians(lon)

    sin_phi2 = math.sin(phi1) * math.cos(delta) + math.cos(phi1) * math.sin(delta) * math.cos(theta)
    phi2 = math.asin(max(-1.0, min(1.0, sin_phi2)))
    y = math.sin(theta) * math.sin(delta) * math.cos(phi1)
    x = math.cos(delta) - math.sin(phi1) * math.sin(phi2)
    lambda2 = lambda1 + math.atan2(y, x)

    # Normalize to [-180, 180] so a projection across the antimeridian stays valid.
    lon2 = (math.degrees(lambda2) + 540) % 360 - 180
    return math.degrees(phi2), lon2


def knots_to_kmh(knots: float) -> float:
    return knots * 1.852
