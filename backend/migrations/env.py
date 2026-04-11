import asyncio
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.database import Base
# Import all models so their metadata is registered
from app.models import User, Trip, Destination, TransportLeg, Accommodation  # noqa

config = context.config

# Read DB URL directly from env — avoids loading full app settings (which
# requires Clerk keys etc.) when running `alembic` from the command line.
# Online (async) path needs asyncpg; offline path uses sync psycopg2.
_async_url = os.environ.get("DATABASE_URL", "")
_sync_url = os.environ.get("DATABASE_URL_SYNC", "") or _async_url.replace("+asyncpg", "")
if _async_url:
    config.set_main_option("sqlalchemy.url", _async_url)
elif _sync_url:
    config.set_main_option("sqlalchemy.url", _sync_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
