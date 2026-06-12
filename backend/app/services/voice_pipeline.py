"""Pipeline orchestrator. Two entry points sharing one extraction core
(FEATURES.md §2.1):

    process_audio(...)  # voice mode A: audio → STT → _extract_and_post
    process_text(...)   # text  mode B: ───────────→ _extract_and_post

Synchronous inline processing by design (§3.2). Upgrade path if ever needed:
FastAPI BackgroundTasks or Celery + a polling endpoint — do not build for MVP."""
import asyncio
import time
from dataclasses import dataclass
from datetime import date as date_type
from typing import Literal

from fastapi import UploadFile

from app.services import extraction as extraction_svc
from app.services.audio import save_and_convert
from app.services.postprocess import FinalExtraction, normalize_numerals, postprocess
from app.services.stt import STTService


@dataclass(frozen=True)
class PipelineResult:
    status: Literal["ok", "needs_review", "failed"]
    transcript: str
    detected_language: str | None
    extraction: FinalExtraction | None
    timing_ms: dict[str, int]


async def _extract_and_post(
    transcript: str,
    client_date: date_type,
    default_currency: str,
    detected_language: str | None,
    stt_ms: int | None,
    start: float,
) -> PipelineResult:
    transcript = normalize_numerals(transcript).strip()

    if not transcript:
        return PipelineResult(
            status="failed", transcript="", detected_language=detected_language,
            extraction=None,
            timing_ms=_timing(start, stt_ms, extraction_ms=None),
        )

    t0 = time.monotonic()
    raw = await extraction_svc.extract(transcript)  # raises ExtractionError → 502
    extraction_ms = int((time.monotonic() - t0) * 1000)

    result = postprocess(raw, transcript, client_date, default_currency)
    return PipelineResult(
        status=result.status,
        transcript=transcript,
        detected_language=detected_language,
        extraction=result.extraction,
        timing_ms=_timing(start, stt_ms, extraction_ms),
    )


def _timing(start: float, stt_ms: int | None, extraction_ms: int | None) -> dict[str, int]:
    timing = {}
    if stt_ms is not None:
        timing["stt"] = stt_ms
    if extraction_ms is not None:
        timing["extraction"] = extraction_ms
    timing["total"] = int((time.monotonic() - start) * 1000)
    return timing


async def process_text(
    text: str,
    client_date: date_type,
    default_currency: str,
) -> PipelineResult:
    """Mode B (FEATURES.md): typed input — no STT, no detected_language."""
    start = time.monotonic()
    return await _extract_and_post(
        text, client_date, default_currency,
        detected_language=None, stt_ms=None, start=start,
    )


async def process_audio(
    upload: UploadFile,
    client_date: date_type,
    default_currency: str,
    stt: STTService,
) -> PipelineResult:
    """Mode A: voice. Audio is deleted as soon as STT finishes (NFR-04)."""
    start = time.monotonic()

    processed = await save_and_convert(upload)
    try:
        t0 = time.monotonic()
        stt_result = await asyncio.to_thread(stt.transcribe, processed.wav)
        stt_ms = int((time.monotonic() - t0) * 1000)
    finally:
        processed.cleanup()

    return await _extract_and_post(
        stt_result.transcript, client_date, default_currency,
        detected_language=stt_result.language, stt_ms=stt_ms, start=start,
    )
