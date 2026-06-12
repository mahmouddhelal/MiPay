import logging

import httpx
from fastapi import APIRouter, Request
from sqlalchemy import text

from app.api.v1 import auth as auth_router
from app.api.v1 import categories as categories_router
from app.api.v1 import debug as debug_router
from app.api.v1 import transactions as transactions_router
from app.api.v1 import users as users_router
from app.core.config import settings
from app.db.session import async_session_factory

logger = logging.getLogger(__name__)

router = APIRouter()
router.include_router(auth_router.router)
router.include_router(users_router.router)
router.include_router(transactions_router.router)
router.include_router(categories_router.router)
router.include_router(debug_router.router)  # temporary — Phase 3 STT testing


@router.get("/health", tags=["system"])
async def health(request: Request) -> dict:
    db_ok = False
    try:
        async with async_session_factory() as session:
            await session.execute(text("SELECT 1"))
        db_ok = True
    except Exception as exc:
        logger.warning("DB health check failed: %s", exc)

    ollama_reachable = False
    try:
        async with httpx.AsyncClient() as client:
            r = await client.get(f"{settings.OLLAMA_URL}/api/tags", timeout=3.0)
            ollama_reachable = r.status_code == 200
    except Exception as exc:
        logger.warning("Ollama health check failed: %s", exc)

    whisper_loaded: bool = getattr(request.app.state, "whisper_model", None) is not None

    overall = "ok" if (db_ok and ollama_reachable) else "degraded"

    return {
        "status": overall,
        "db_ok": db_ok,
        "ollama_reachable": ollama_reachable,
        "whisper_loaded": whisper_loaded,
    }
