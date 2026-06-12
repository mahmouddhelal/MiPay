import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str
    default_currency: str
    locale: str
    created_at: datetime


class UserUpdate(BaseModel):
    display_name: str | None = None
    default_currency: str | None = None
    locale: str | None = None

    @field_validator("locale")
    @classmethod
    def validate_locale(cls, v: str | None) -> str | None:
        if v is not None and v not in ("ar", "en"):
            raise ValueError("locale must be 'ar' or 'en'")
        return v
