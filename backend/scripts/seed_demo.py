"""Seed a few realistic flights for a given Clerk user_id so the app populates.

Usage (inside the backend container):
    python -m scripts.seed_demo <clerk_user_id> [email]

Idempotent: if the user already has flights, it does nothing.
"""

from __future__ import annotations

import sys

from sqlalchemy import select

from app.database import SyncSession
from app.models.user import User
from app.models.transport import TransportLeg


def _flight(session, user_id, oc, dc, oi, di, dist):
    session.add(TransportLeg(
        user_id=user_id,
        origin_city=oc, dest_city=dc, origin_iata=oi, dest_iata=di, distance_km=dist,
    ))


def main(user_id: str, email: str) -> None:
    with SyncSession() as session:
        if not session.get(User, user_id):
            session.add(User(id=user_id, email=email, display_name="Zach"))
            session.flush()

        existing = session.execute(
            select(TransportLeg.id).where(TransportLeg.user_id == user_id).limit(1)
        ).first()
        if existing:
            print(f"User {user_id} already has flights — nothing to seed.")
            return

        _flight(session, user_id, "London", "Tokyo", "LHR", "HND", 9560)
        _flight(session, user_id, "Tokyo", "London", "HND", "LHR", 9560)
        _flight(session, user_id, "London", "Buenos Aires", "LHR", "EZE", 11100)
        _flight(session, user_id, "London", "Reykjavík", "LHR", "KEF", 1890)

        session.commit()
        print(f"Seeded 4 flights for {user_id}.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python -m scripts.seed_demo <clerk_user_id> [email]")
        raise SystemExit(1)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "zakslax@gmail.com")
