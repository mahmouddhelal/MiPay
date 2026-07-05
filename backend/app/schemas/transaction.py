import uuid
from datetime import date as date_type
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

# 29 category keys (17 original + 12 Egyptian additions) — kept in sync with DB
CATEGORY_KEYS = frozenset({
    # original 17
    "groceries", "restaurants", "transport", "fuel", "shopping", "bills",
    "rent", "health", "education", "entertainment", "travel", "personal_care",
    "gifts_donations", "salary", "business", "transfer_in", "other",
    # 12 new Egyptian categories (migration 0003)
    "coffee", "internet_mobile", "subscriptions", "household", "tuition",
    "clothes", "pets", "insurance", "savings", "transfer_out",
    "freelance", "investments",
})


class TransactionCreate(BaseModel):
    transaction_type: Literal["expense", "income"]
    amount: Decimal = Field(gt=0, le=Decimal("9999999999.99"), decimal_places=2)
    currency: str = Field(min_length=3, max_length=3)
    category: str
    name: str | None = Field(default=None, max_length=200)
    date: date_type
    note: str | None = None
    source: Literal["voice", "manual"] = "manual"
    transcript: str | None = None

    @field_validator("currency")
    @classmethod
    def uppercase_currency(cls, v: str) -> str:
        return v.upper()

    @field_validator("category")
    @classmethod
    def known_category(cls, v: str) -> str:
        if v not in CATEGORY_KEYS:
            raise ValueError(f"Unknown category '{v}'")
        return v


class TransactionUpdate(BaseModel):
    transaction_type: Literal["expense", "income"] | None = None
    amount: Decimal | None = Field(default=None, gt=0, decimal_places=2)
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    category: str | None = None
    name: str | None = Field(default=None, max_length=200)
    date: date_type | None = None
    note: str | None = None

    @field_validator("currency")
    @classmethod
    def uppercase_currency(cls, v: str | None) -> str | None:
        return v.upper() if v else v

    @field_validator("category")
    @classmethod
    def known_category(cls, v: str | None) -> str | None:
        if v is not None and v not in CATEGORY_KEYS:
            raise ValueError(f"Unknown category '{v}'")
        return v


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    transaction_type: str
    amount: float
    currency: str
    category: str
    name: str | None
    date: date_type
    note: str | None
    source: str
    transcript: str | None
    created_at: datetime
    updated_at: datetime


class TransactionListOut(BaseModel):
    items: list[TransactionOut]
    page: int
    page_size: int
    total: int


# ── Voice/text extraction (§5.2 response shape + FEATURES.md §2.2) ──────────

class ExtractionItem(BaseModel):
    """One extracted transaction, with its own review status. A single utterance
    may yield several of these (e.g. "coffee 50, croissant 100, dad sent 200")."""
    status: Literal["ok", "needs_review"]
    transaction_type: str | None
    amount: float | None
    currency: str
    category: str | None
    name: str | None
    date: date_type
    confidence: str


class VoiceExtractionResult(BaseModel):
    # Top-level status: "failed" if no transactions were extracted; "needs_review"
    # if any item needs review; otherwise "ok".
    status: Literal["ok", "needs_review", "failed"]
    transcript: str
    detected_language: str | None
    extractions: list[ExtractionItem]
    timing_ms: dict[str, int]


class BatchTransactionCreate(BaseModel):
    """Body for POST /transactions/batch — saves all of one confirm screen at once."""
    items: list[TransactionCreate] = Field(min_length=1, max_length=50)


class ExtractTextRequest(BaseModel):
    text: str = Field(min_length=1, max_length=500)
    client_date: date_type
    client_locale: Literal["ar", "en"] = "en"

    @field_validator("text")
    @classmethod
    def not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("text must not be blank")
        return v.strip()
