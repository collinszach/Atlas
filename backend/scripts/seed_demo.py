"""Seed a few realistic trips for a given Clerk user_id so the app populates.

Usage (inside the backend container):
    python -m scripts.seed_demo <clerk_user_id> [email]

Idempotent: if the user already has trips, it does nothing.
"""

from __future__ import annotations

import sys
from datetime import date

from sqlalchemy import select

from app.database import SyncSession
from app.models.user import User
from app.models.trip import Trip
from app.models.destination import Destination
from app.models.transport import TransportLeg


def _trip(session, user_id, title, status, start, end, desc, tags):
    t = Trip(
        user_id=user_id, title=title, status=status,
        start_date=start, end_date=end, description=desc, tags=tags,
    )
    session.add(t)
    session.flush()
    return t


def _dest(session, trip, user_id, city, cc, cn, arr, dep, rating=None):
    nights = (dep - arr).days if (arr and dep) else None
    session.add(Destination(
        trip_id=trip.id, user_id=user_id, city=city, country_code=cc, country_name=cn,
        arrival_date=arr, departure_date=dep, nights=nights, rating=rating,
    ))


def _flight(session, trip, user_id, oc, dc, oi, di, dist):
    session.add(TransportLeg(
        trip_id=trip.id, user_id=user_id, type="flight",
        origin_city=oc, dest_city=dc, origin_iata=oi, dest_iata=di, distance_km=dist,
    ))


def main(user_id: str, email: str) -> None:
    with SyncSession() as session:
        if not session.get(User, user_id):
            session.add(User(id=user_id, email=email, display_name="Zach"))
            session.flush()

        existing = session.execute(
            select(Trip.id).where(Trip.user_id == user_id).limit(1)
        ).first()
        if existing:
            print(f"User {user_id} already has trips — nothing to seed.")
            return

        # Past — Japan
        jp = _trip(session, user_id, "Kyoto in Autumn", "past",
                   date(2024, 11, 8), date(2024, 11, 19),
                   "Temples, momiji, and the slow trains of Kansai.", ["food", "culture"])
        _dest(session, jp, user_id, "Tokyo", "JP", "Japan", date(2024, 11, 8), date(2024, 11, 12), 5)
        _dest(session, jp, user_id, "Kyoto", "JP", "Japan", date(2024, 11, 12), date(2024, 11, 19), 5)
        _flight(session, jp, user_id, "London", "Tokyo", "LHR", "HND", 9560)
        _flight(session, jp, user_id, "Tokyo", "London", "HND", "LHR", 9560)

        # Past — Patagonia
        pat = _trip(session, user_id, "Patagonia Crossing", "past",
                    date(2024, 2, 2), date(2024, 2, 23),
                    "Three weeks tracing the Andes to Torres del Paine.", ["hiking", "wild"])
        _dest(session, pat, user_id, "Bariloche", "AR", "Argentina", date(2024, 2, 2), date(2024, 2, 10), 4)
        _dest(session, pat, user_id, "El Chaltén", "AR", "Argentina", date(2024, 2, 10), date(2024, 2, 16), 5)
        _dest(session, pat, user_id, "Puerto Natales", "CL", "Chile", date(2024, 2, 16), date(2024, 2, 23), 5)
        _flight(session, pat, user_id, "London", "Buenos Aires", "LHR", "EZE", 11100)

        # Active — Lisbon
        lis = _trip(session, user_id, "Lisbon & the Algarve", "active",
                    date(2026, 6, 1), date(2026, 6, 28),
                    "Working remotely from Alfama, weekends on the coast.", ["coast"])
        _dest(session, lis, user_id, "Lisbon", "PT", "Portugal", date(2026, 6, 1), date(2026, 6, 28))

        # Planned — Iceland
        ice = _trip(session, user_id, "Iceland Ring Road", "planned",
                    date(2026, 9, 12), date(2026, 9, 22),
                    "Ten days, one 4x4, the whole island.", ["roadtrip"])
        _dest(session, ice, user_id, "Reykjavík", "IS", "Iceland", date(2026, 9, 12), date(2026, 9, 14))

        session.commit()
        print(f"Seeded 4 trips for {user_id}.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python -m scripts.seed_demo <clerk_user_id> [email]")
        raise SystemExit(1)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "zakslax@gmail.com")
