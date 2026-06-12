"""Audio intake: size/format validation, ffmpeg conversion to 16 kHz mono WAV,
duration check, and guaranteed temp-file cleanup (NFR-04: nothing persists)."""
import asyncio
import json
import tempfile
import uuid
from pathlib import Path

from fastapi import UploadFile

from app.core.config import settings
from app.core.exceptions import AppError

_ALLOWED_EXTENSIONS = {".m4a", ".aac", ".wav", ".mp3", ".ogg", ".opus"}

_TMP_DIR = Path(tempfile.gettempdir()) / "mipay_audio"


class ProcessedAudio:
    """Paths created for one request. Call cleanup() in a finally block."""

    def __init__(self, original: Path, wav: Path, duration_seconds: float) -> None:
        self.original = original
        self.wav = wav
        self.duration_seconds = duration_seconds

    def cleanup(self) -> None:
        for path in (self.original, self.wav):
            path.unlink(missing_ok=True)


async def _run(*cmd: str) -> tuple[int, bytes, bytes]:
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return proc.returncode or 0, stdout, stderr


async def _probe_duration(path: Path) -> float:
    code, stdout, _ = await _run(
        "ffprobe", "-v", "quiet", "-print_format", "json",
        "-show_format", str(path),
    )
    if code != 0:
        raise AppError(415, "AUDIO_UNSUPPORTED", "Could not read the audio file.")
    try:
        return float(json.loads(stdout)["format"]["duration"])
    except (KeyError, ValueError):
        raise AppError(415, "AUDIO_UNSUPPORTED", "Could not determine audio duration.")


async def save_and_convert(upload: UploadFile) -> ProcessedAudio:
    """Validate the upload and produce a 16 kHz mono WAV for Whisper.

    Raises AppError 413 (too large/long) or 415 (unsupported format).
    """
    suffix = Path(upload.filename or "audio.m4a").suffix.lower()
    if suffix not in _ALLOWED_EXTENSIONS:
        raise AppError(
            415, "AUDIO_UNSUPPORTED",
            f"Unsupported audio format '{suffix}'. Use m4a, aac, wav, or mp3.",
        )

    data = await upload.read()
    if len(data) > settings.MAX_AUDIO_BYTES:
        raise AppError(
            413, "AUDIO_TOO_LONG",
            f"Audio file exceeds {settings.MAX_AUDIO_BYTES // (1024 * 1024)} MB.",
        )
    if not data:
        raise AppError(415, "AUDIO_UNSUPPORTED", "Empty audio file.")

    _TMP_DIR.mkdir(parents=True, exist_ok=True)
    stem = uuid.uuid4().hex
    original = _TMP_DIR / f"{stem}{suffix}"
    wav = _TMP_DIR / f"{stem}_16k.wav"  # distinct name: the upload may itself be .wav
    original.write_bytes(data)

    try:
        duration = await _probe_duration(original)
        if duration > settings.MAX_AUDIO_SECONDS:
            raise AppError(
                413, "AUDIO_TOO_LONG",
                f"Audio is {duration:.0f}s; the maximum is {settings.MAX_AUDIO_SECONDS}s.",
            )

        code, _, stderr = await _run(
            "ffmpeg", "-y", "-i", str(original),
            "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le",
            str(wav),
        )
        if code != 0:
            raise AppError(
                415, "AUDIO_UNSUPPORTED",
                f"Audio conversion failed: {stderr.decode(errors='ignore')[-200:]}",
            )
    except AppError:
        original.unlink(missing_ok=True)
        wav.unlink(missing_ok=True)
        raise

    return ProcessedAudio(original=original, wav=wav, duration_seconds=duration)
