import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import users, trips, destinations, map as map_router
from app.routers.transport import router as transport_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Atlas backend starting")
    yield
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
app.include_router(trips.router, prefix="/api/v1")
app.include_router(destinations.router, prefix="/api/v1")
app.include_router(map_router.router, prefix="/api/v1")
app.include_router(transport_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
