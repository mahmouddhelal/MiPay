#!/usr/bin/env python3
"""
STT Evaluation — Word Error Rate (WER) per language.

Usage
-----
    # From the repo root (containers must be running):
    BASE_URL=http://localhost:8000/api/v1 \\
    python backend/evaluation/run_stt_eval.py

    # Or from inside the evaluation/ directory:
    cd backend/evaluation
    BASE_URL=http://localhost:8000/api/v1 python run_stt_eval.py

Prerequisites
-------------
- Docker containers running: `docker compose up -d`
- Audio files referenced by audio_path in dataset.jsonl must exist.
  (Rows with audio_path=null or missing file are skipped with a warning.)
- Python packages: httpx, jiwer  (pip install httpx jiwer)

IMPORTANT — debug endpoint
--------------------------
This script calls POST /debug/transcribe which is NOT mounted in production.
Before running STT eval, temporarily re-enable it in backend/app/api/v1/router.py:

    from app.api.v1 import debug as debug_router
    router.include_router(debug_router.router)

Remove it again after eval is complete.

Environment variables
---------------------
BASE_URL       Backend base URL (default: http://localhost:8000/api/v1)
EVAL_DATE      ISO date used as client_date  (default: 2026-06-15)
WHISPER_SIZES  Comma-separated list of model sizes to ablate, e.g. "base,small,medium"
               Requires restarting the API between runs with WHISPER_MODEL env changed.
               If unset, runs once with whatever model is currently loaded.

Output
------
Prints a table of WER / CER per language, then writes results_stt.json.
"""

import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

try:
    import httpx
except ImportError:
    sys.exit("httpx not found. Run: pip install httpx")

try:
    import jiwer
except ImportError:
    sys.exit("jiwer not found. Run: pip install jiwer")

from normalize_ar import normalize_arabic  # noqa: E402 (relative import)

# ── Configuration ─────────────────────────────────────────────────────────────

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000/api/v1")
EVAL_DATE = os.getenv("EVAL_DATE", "2026-06-15")
DATASET_PATH = Path(__file__).parent / "dataset.jsonl"
RESULTS_PATH = Path(__file__).parent / "results_stt.json"
TIMEOUT_S = 120  # seconds per transcription request

# ── Helpers ───────────────────────────────────────────────────────────────────


def load_dataset() -> list[dict]:
    return [
        json.loads(line)
        for line in DATASET_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def transcribe(audio_path: Path, client: httpx.Client) -> str:
    """Call POST /debug/transcribe (unauthenticated) and return the transcript."""
    with audio_path.open("rb") as f:
        r = client.post(
            f"{BASE_URL}/debug/transcribe",
            files={"audio": (audio_path.name, f)},
            data={"client_date": EVAL_DATE},
            timeout=TIMEOUT_S,
        )
    r.raise_for_status()
    return r.json()["transcript"]


def _normalise(text: str, lang: str) -> str:
    """Language-aware normalisation before WER scoring."""
    text = text.lower().strip()
    if lang in ("ar", "mixed"):
        text = normalize_arabic(text)
    return text


def _wer_safe(refs: list[str], hyps: list[str]) -> float:
    """jiwer.wer crashes on empty lists — guard here."""
    if not refs:
        return float("nan")
    return jiwer.wer(refs, hyps)


def _cer_safe(refs: list[str], hyps: list[str]) -> float:
    if not refs:
        return float("nan")
    return jiwer.cer(refs, hyps)


# ── Main ──────────────────────────────────────────────────────────────────────


def evaluate(entries: list[dict], label: str = "") -> dict:
    """
    Run STT eval for all entries that have a resolvable audio_path.
    Returns a dict keyed by language with per-language metrics.
    """
    by_lang: dict[str, list[tuple[str, str]]] = {}  # lang → [(ref, hyp)]
    skipped = 0
    errors = 0

    with httpx.Client() as client:
        for entry in entries:
            ap = entry.get("audio_path")
            if not ap:
                skipped += 1
                continue
            audio_file = (Path(__file__).parent / ap).resolve()
            if not audio_file.exists():
                print(
                    f"  [skip] {entry['id']}: audio not found at {audio_file}",
                    file=sys.stderr,
                )
                skipped += 1
                continue

            try:
                hyp = transcribe(audio_file, client)
            except Exception as exc:
                print(f"  [error] {entry['id']}: {exc}", file=sys.stderr)
                errors += 1
                continue

            lang = entry["lang"]
            ref = _normalise(entry["transcript_gold"], lang)
            hyp = _normalise(hyp, lang)
            by_lang.setdefault(lang, []).append((ref, hyp))

    print(f"\n{'=' * 60}")
    if label:
        print(f"  Model: {label}")
    print(f"  Total entries: {len(entries)}  |  skipped: {skipped}  |  errors: {errors}")
    print(f"{'=' * 60}")

    results: dict[str, dict] = {}
    for lang in sorted(by_lang):
        pairs = by_lang[lang]
        refs, hyps = zip(*pairs)
        wer_val = _wer_safe(list(refs), list(hyps))
        cer_val = _cer_safe(list(refs), list(hyps)) if lang in ("ar", "mixed") else None

        row: dict = {"n": len(pairs), "wer": round(wer_val, 4)}
        if cer_val is not None:
            row["cer"] = round(cer_val, 4)
        results[lang] = row

        cer_str = f"  CER: {cer_val:.1%}" if cer_val is not None else ""
        print(f"\n  [{lang.upper()}] n={len(pairs)}")
        print(f"    WER: {wer_val:.1%}{cer_str}")

    print()
    return results


def main() -> None:
    entries = load_dataset()
    audio_entries = [e for e in entries if e.get("audio_path")]
    if not audio_entries:
        print(
            "No audio_path found in dataset.jsonl.\n"
            "Record audio clips, save them under evaluation/audio/, and set\n"
            "  audio_path: \"audio/<id>.m4a\"\n"
            "in each relevant entry to run STT evaluation."
        )
        return

    whisper_sizes = os.getenv("WHISPER_SIZES", "").split(",")
    whisper_sizes = [s.strip() for s in whisper_sizes if s.strip()]

    all_results: dict[str, dict] = {}

    if whisper_sizes:
        # Ablation mode: user manually restarts API between runs
        print(
            "WHISPER_SIZES ablation mode.\n"
            "Make sure to restart the API with each WHISPER_MODEL value before continuing."
        )
        for size in whisper_sizes:
            input(f"\nSet WHISPER_MODEL={size} and restart the API, then press Enter…")
            all_results[size] = evaluate(entries, label=f"whisper-{size}")
    else:
        # Single-run mode
        all_results["current"] = evaluate(entries)

    RESULTS_PATH.write_text(
        json.dumps(all_results, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"Results written → {RESULTS_PATH}")

    # Print ablation summary table if multiple models
    if len(all_results) > 1:
        langs = sorted({lang for r in all_results.values() for lang in r})
        header = f"{'Model':<16}" + "".join(f"  {'WER-'+lg:>10}" for lg in langs)
        print("\nAblation summary:")
        print(header)
        print("-" * len(header))
        for model, res in all_results.items():
            row = f"{model:<16}" + "".join(
                f"  {res.get(lg, {}).get('wer', float('nan')):>9.1%}" for lg in langs
            )
            print(row)


if __name__ == "__main__":
    main()
