"""faster-whisper singleton (§4.1). Loaded once at startup via the FastAPI
lifespan handler — never per request. transcribe() is CPU-bound; callers must
run it in a thread (asyncio.to_thread) to keep the event loop free."""
import logging
from dataclasses import dataclass
from pathlib import Path

from faster_whisper import WhisperModel

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class STTResult:
    transcript: str
    language: str
    language_probability: float


class STTService:
    def __init__(self) -> None:
        logger.info(
            "Loading Whisper model '%s' (compute_type=%s)…",
            settings.WHISPER_MODEL, settings.WHISPER_COMPUTE_TYPE,
        )
        self._model = WhisperModel(
            settings.WHISPER_MODEL,
            compute_type=settings.WHISPER_COMPUTE_TYPE,
        )
        logger.info("Whisper model loaded.")

    def transcribe(self, wav_path: Path) -> STTResult:
        segments, info = self._model.transcribe(
            str(wav_path),
            language=None,    # auto-detect — critical for ar/en/code-switching (§4.1)
            beam_size=5,
            vad_filter=True,  # trims silence; improves short-clip accuracy
        )
        transcript = " ".join(s.text for s in segments).strip()
        return STTResult(
            transcript=transcript,
            language=info.language,
            language_probability=info.language_probability,
        )
