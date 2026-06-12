"""Deterministic post-processing of LLM output (§4.5). This layer is unit-tested
(tests/test_postprocess.py) and is part of the thesis evaluation: the LLM never
does date arithmetic — Python does."""
import logging
import re
from dataclasses import dataclass
from datetime import date as date_type
from datetime import datetime
from typing import Literal

import dateparser
from pydantic import BaseModel, ValidationError

logger = logging.getLogger(__name__)

# ── §4.5.2: Arabic-Indic numeral normalization ──────────────────────────────

_NUMERAL_MAP = str.maketrans("٠١٢٣٤٥٦٧٨٩٫", "0123456789.")


def normalize_numerals(text: str) -> str:
    """٠١٢٣٤٥٦٧٨٩ → 0123456789 and ٫ → . — applied to the transcript before
    the LLM sees it, and to `name` afterwards."""
    return text.translate(_NUMERAL_MAP)


# ── §4.5.1: Pydantic mirror of the extraction schema ────────────────────────

class RawExtraction(BaseModel):
    transaction_type: Literal["expense", "income"] | None
    amount: float | None
    currency: str | None
    category: str | None
    name: str | None
    date_text: str | None
    confidence: Literal["high", "medium", "low"]


# ── §4.5.3: date resolution ─────────────────────────────────────────────────

# dateparser misses some dialect forms; map them to phrases it understands.
_DIALECT_DATE_MAP = {
    "أمس": "yesterday",
    "امس": "yesterday",
    "البارح": "yesterday",
    "البارحة": "yesterday",
    "امبارح": "yesterday",
    "إمبارح": "yesterday",
    "أمبارح": "yesterday",
    "أول أمس": "2 days ago",
    "اول امس": "2 days ago",
    "أول البارح": "2 days ago",
    "اول البارح": "2 days ago",
    "أول امبارح": "2 days ago",
    "اول امبارح": "2 days ago",
    "اليوم": "today",
    "النهارده": "today",
    "النهاردة": "today",
}

# Retry transforms for phrases dateparser 1.x can't parse directly (verified):
# «يوم الجمعة» → «الجمعة», «قبل يومين» → «منذ يومين», "last friday" → "friday"
# (PREFER_DATES_FROM=past already makes bare weekday names resolve backwards).
_RETRY_TRANSFORMS = [
    (re.compile(r"^يوم\s+"), ""),
    (re.compile(r"^قبل\s+"), "منذ "),
    (re.compile(r"^last\s+"), ""),
]


def resolve_date(date_text: str | None, client_date: date_type) -> date_type:
    """Resolve a raw date phrase to an absolute date anchored at client_date.
    Null or unparseable input falls back to client_date."""
    if not date_text or not date_text.strip():
        return client_date

    phrase = normalize_numerals(date_text.strip())
    phrase = _DIALECT_DATE_MAP.get(phrase, phrase)

    anchor = datetime(client_date.year, client_date.month, client_date.day)
    settings = {"RELATIVE_BASE": anchor, "PREFER_DATES_FROM": "past"}

    resolved = dateparser.parse(phrase, languages=["ar", "en"], settings=settings)
    if resolved is None:
        retry = phrase.lower()
        for pattern, replacement in _RETRY_TRANSFORMS:
            retry = pattern.sub(replacement, retry)
        if retry != phrase.lower():
            resolved = dateparser.parse(retry, languages=["ar", "en"], settings=settings)

    if resolved is None:
        logger.info("Unparseable date_text %r — defaulting to client_date", date_text)
        return client_date
    return resolved.date()


# ── Final result ────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class FinalExtraction:
    transaction_type: str | None
    amount: float | None
    currency: str
    category: str | None
    name: str | None
    date: date_type
    confidence: str


@dataclass(frozen=True)
class PostprocessResult:
    status: Literal["ok", "needs_review", "failed"]
    extraction: FinalExtraction | None


def postprocess(
    raw: dict,
    transcript: str,
    client_date: date_type,
    default_currency: str,
) -> PostprocessResult:
    """§4.5 steps 1–6: validate, resolve date, fill defaults, decide status."""
    if not transcript.strip():
        return PostprocessResult(status="failed", extraction=None)

    try:
        parsed = RawExtraction.model_validate(raw)
    except ValidationError as exc:
        # Shouldn't happen with constrained decoding, but defend (§4.5.1)
        logger.error("LLM output failed validation: %s", exc)
        return PostprocessResult(status="failed", extraction=None)

    # §4.5.5 category guard
    category = parsed.category
    if category is None and parsed.transaction_type is not None:
        category = "other"

    extraction = FinalExtraction(
        transaction_type=parsed.transaction_type,
        amount=parsed.amount,
        # §4.5.4 currency default
        currency=parsed.currency or default_currency,
        category=category,
        name=normalize_numerals(parsed.name) if parsed.name else None,
        date=resolve_date(parsed.date_text, client_date),
        confidence=parsed.confidence,
    )

    # §4.5.6 status decision
    if (
        parsed.transaction_type is None
        or parsed.amount is None
        or parsed.confidence == "low"
    ):
        return PostprocessResult(status="needs_review", extraction=extraction)
    return PostprocessResult(status="ok", extraction=extraction)
