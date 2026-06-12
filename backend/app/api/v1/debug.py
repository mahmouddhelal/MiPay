"""Temporary STT debug endpoint (Phase 3 acceptance). Not part of the public
API surface (§5.2) — remove or guard before any non-dev deployment."""
import asyncio
import time

from fastapi import APIRouter, Request, UploadFile

from app.core.exceptions import AppError
from app.services.audio import save_and_convert
from app.services.stt import STTService

router = APIRouter(prefix="/debug", tags=["debug"])


@router.post("/transcribe")
async def transcribe(request: Request, audio: UploadFile) -> dict:
    stt: STTService | None = getattr(request.app.state, "whisper_model", None)
    if stt is None:
        raise AppError(503, "STT_UNAVAILABLE", "Whisper model is not loaded yet.")

    processed = await save_and_convert(audio)
    try:
        start = time.monotonic()
        result = await asyncio.to_thread(stt.transcribe, processed.wav)
        elapsed_ms = int((time.monotonic() - start) * 1000)
    finally:
        processed.cleanup()  # NFR-04: audio never persists

    return {
        "transcript": result.transcript,
        "detected_language": result.language,
        "language_probability": round(result.language_probability, 3),
        "audio_seconds": round(processed.duration_seconds, 2),
        "timing_ms": {"stt": elapsed_ms},
    }
