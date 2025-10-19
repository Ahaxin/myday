"""FastAPI application setup for the My Day API."""
from fastapi import FastAPI

from . import config
from .database import init_db
from .routes import auth, entries, exports


def create_app() -> FastAPI:
    """Create and configure the FastAPI application instance."""
    init_db()
    application = FastAPI(title=config.APP_NAME, version=config.APP_VERSION)
    application.include_router(auth.router, prefix="/v1/auth", tags=["auth"])
    application.include_router(entries.router, prefix="/v1/entries", tags=["entries"])
    application.include_router(exports.router, prefix="/v1/exports", tags=["exports"])
    return application


app = create_app()
