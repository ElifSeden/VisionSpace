from fastapi import FastAPI

from app.api.routes import design_jobs, health, products, uploads
from app.core.config import get_settings
from app.core.logging import configure_logging

configure_logging()

app = FastAPI(title=get_settings().app_name)
app.include_router(health.router)
app.include_router(uploads.router)
app.include_router(design_jobs.router)
app.include_router(products.router)

