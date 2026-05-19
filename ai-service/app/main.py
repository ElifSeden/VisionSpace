from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import design_jobs, health, products, uploads
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.storage.local_storage import LocalImageStorage

configure_logging()

settings = get_settings()
LocalImageStorage(settings)

app = FastAPI(
    title="VisionSpace AI Service",
    description=(
        "Furniture recommendation API. Upload a room photo, receive AI-powered "
        "design proposals with product selections and placement plans. "
        "The pipeline orchestrates room analysis, design strategy creation, "
        "product retrieval via vector search, ranking, and spatial placement."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(health.router, tags=["health"])
app.include_router(uploads.router)
app.include_router(design_jobs.router)
app.include_router(products.router)
app.mount("/images", StaticFiles(directory=settings.local_image_root, check_dir=False), name="images")
