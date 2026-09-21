"""Route validation must tell a departure from an arrival.

Found by tracking live flights: DAL1538 was reported as landing at LGA in 3.2
minutes while it was actually climbing out of LGA on an LGA->MIA leg, 1,612km
from where it was really going. Proximity to an endpoint short-circuited the
heading test, and adsbdb had the opposite leg recorded for that callsign.
"""
import pytest

from app.services.flightroute import RouteInfo, validate_route

# LGA and MIA, roughly. MIA is almost due south of LGA.
LGA_LAT, LGA_LON = 40.777, -73.872
MIA_LAT, MIA_LON = 25.795, -80.290


def _route(origin="MIA", dest="LGA"):
    """adsbdb's record for the callsign — here, the inbound leg."""
    if origin == "MIA":
        return RouteInfo(
            origin_iata="MIA", origin_name="Miami", dest_iata="LGA", dest_name="New York",
            origin_lat=MIA_LAT, origin_lon=MIA_LON, dest_lat=LGA_LAT, dest_lon=LGA_LON,
        )
    return RouteInfo(
        origin_iata="LGA", origin_name="New York", dest_iata="MIA", dest_name="Miami",
        origin_lat=LGA_LAT, origin_lon=LGA_LON, dest_lat=MIA_LAT, dest_lon=MIA_LON,
    )


def test_departure_near_the_recorded_destination_is_swapped():
    """The DAL1538 case: just off LGA, heading south — that is a departure."""
    result = validate_route(_route(), 40.5, -74.0, track=200.0)
    assert result is not None
    assert (result.origin_iata, result.dest_iata) == ("LGA", "MIA")


def test_arrival_near_the_recorded_destination_is_kept():
    """Same position, heading north into LGA — genuinely arriving."""
    result = validate_route(_route(), 40.5, -74.0, track=20.0)
    assert result is not None
    assert (result.origin_iata, result.dest_iata) == ("MIA", "LGA")


def test_enroute_toward_destination_is_kept():
    result = validate_route(_route(), 33.0, -78.0, track=25.0)
    assert result is not None
    assert result.dest_iata == "LGA"


def test_enroute_toward_origin_is_swapped():
    result = validate_route(_route(), 33.0, -78.0, track=200.0)
    assert result is not None
    assert result.dest_iata == "MIA"


def test_far_from_both_and_pointed_at_neither_is_rejected():
    """The HNL->LAX-over-New-Jersey case: a stale route for this airframe."""
    assert validate_route(_route(), 39.0, -100.0, track=270.0) is None


def test_near_an_endpoint_but_manoeuvring_keeps_the_scheduled_route():
    """On the ground or in a turn the heading says nothing; don't discard the route."""
    result = validate_route(_route(), 40.78, -73.87, track=90.0)
    assert result is not None
    assert {result.origin_iata, result.dest_iata} == {"MIA", "LGA"}


def test_missing_track_falls_back_to_the_scheduled_route():
    result = validate_route(_route(), 40.5, -74.0, track=None)
    assert result is not None
    assert result.dest_iata == "LGA"


def test_none_route_stays_none():
    assert validate_route(None, 40.0, -74.0, track=180.0) is None


def test_route_without_coordinates_is_trusted():
    route = RouteInfo(
        origin_iata="AAA", origin_name=None, dest_iata="BBB", dest_name=None,
        origin_lat=None, origin_lon=None, dest_lat=None, dest_lon=None,
    )
    assert validate_route(route, 40.0, -74.0, track=180.0) is route
