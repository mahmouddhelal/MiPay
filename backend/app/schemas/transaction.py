import uuid
from datetime import date as date_type
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

# The 17 category keys from MIPAY_SPEC.md §4.3 — kept in sync with the DB seed
CATEGORY_KEYS = frozenset({
    "groceries", "restaurants", "transport", "fuel", "shopping", "bills",
    "rent", "health", "education", "entertainment", "travel", "personal_care",
    "gifts_donations", "salary", "business", "transfer_in", "other",
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
