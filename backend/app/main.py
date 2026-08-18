import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import users, map as map_router
from app.routers.photos import router as photos_router
from app.routers.transport import router as transport_router
from app.routers.skywatch import router as skywatch_router
from app.routers.stats import router as stats_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Atlas backend starting")
    try:
        from app.services.storage import get_storage
        storage = get_storage()
        await storage.ensure_bucket_exists()
    except Exception as exc:
        logger.warning("MinIO bucket init failed (continuing without photo storage): %s", exc)

    try:
        from app.tasks.scheduler import start_scheduler
        start_scheduler()
    except Exception as exc:
        logger.warning("Skywatch scheduler failed to start: %s", exc)

    yield

    try:
        from app.tasks.scheduler import shutdown_scheduler
        shutdown_scheduler()
    except Exception:
        logger.exception("Skywatch scheduler shutdown failed")
    logger.info("Atlas backend shutting down")


app = FastAPI(
    title="Atlas API",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router, prefix="/api/v1")
app.include_router(map_router.router, prefix="/api/v1")
app.include_router(photos_router, prefix="/api/v1")
app.include_router(transport_router, prefix="/api/v1")
app.include_router(skywatch_router, prefix="/api/v1")
app.include_router(stats_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
