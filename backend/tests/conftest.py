import pytest
import pytest_asyncio
import os

# Override env before any app imports
os.environ.setdefault("POSTGRES_DB", "atlas_test")
os.environ.setdefault("POSTGRES_USER", "atlas")
os.environ.setdefault("POSTGRES_PASSWORD", "testpass")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://atlas:testpass@localhost:5432/atlas_test")
os.environ.setdefault("DATABASE_URL_SYNC", "postgresql+psycopg2://atlas:testpass@localhost:5432/atlas_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")
os.environ.setdefault("CLERK_SECRET_KEY", "sk_test_fake")
os.environ.setdefault("CLERK_WEBHOOK_SECRET", "whsec_fake1234567890abcdef1234567890ab")
os.environ.setdefault("MINIO_ACCESS_KEY", "minioadmin")
os.environ.setdefault("MINIO_SECRET_KEY", "minioadmin")


@pytest.fixture(scope="session", autouse=True)
def override_engine_nullpool():
    """Swap the app's engine+session_factory for NullPool variants.

    asyncpg connections are bound to the event loop that created them.
    With NullPool, every session gets a fresh connection — no cross-loop
    reuse, so tests don't collide even across loop boundaries.
    """
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
    from sqlalchemy.pool import NullPool
    import app.database as db_module

    test_engine = create_async_engine(os.environ["DATABASE_URL"], poolclass=NullPool)
    test_session_factory = async_sessionmaker(test_engine, expire_on_commit=False)

    original_engine = db_module.engine
    original_session_factory = db_module.async_session_factory
    db_module.engine = test_engine
    db_module.async_session_factory = test_session_factory

    yield

    db_module.engine = original_engine
    db_module.async_session_factory = original_session_factory
    import asyncio
    asyncio.get_event_loop().run_until_complete(test_engine.dispose())


@pytest_asyncio.fixture
async def client():
    from httpx import AsyncClient, ASGITransport
    from app.main import app
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def db_session():
    """Provide a live DB session for integration test setup/teardown."""
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
    from sqlalchemy.pool import NullPool
    engine = create_async_engine(os.environ["DATABASE_URL"], poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session
    await engine.dispose()


# Test user IDs used across integration tests
_TEST_USER_ID = "user_test_atlas_001"
_OTHER_USER_ID = "user_test_other_002"

# Public aliases for import in test modules
TEST_USER_ID = _TEST_USER_ID
OTHER_USER_ID = _OTHER_USER_ID


@pytest_asyncio.fixture
async def auth_client(client, seed_test_users):
    """Client with auth dependency overridden to TEST_USER_ID."""
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest_asyncio.fixture(autouse=False, scope="function")
async def seed_test_users(db_session):
    """Insert test user rows so FK constraints pass. Cleaned up after each test."""
    from sqlalchemy import text
    for uid in (_TEST_USER_ID, _OTHER_USER_ID):
        await db_session.execute(
            text("INSERT INTO users (id, email) VALUES (:id, :email) ON CONFLICT (id) DO NOTHING"),
            {"id": uid, "email": f"{uid}@test.invalid"},
        )
    await db_session.commit()
    yield
    # Cascade deletes trips/destinations via FK ON DELETE CASCADE
    for uid in (_TEST_USER_ID, _OTHER_USER_ID):
        await db_session.execute(text("DELETE FROM users WHERE id = :id"), {"id": uid})
    await db_session.commit()
