import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return _pwd_context.verify(plain, hashed)


def _encode(payload: dict[str, Any], expire_minutes: int) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=expire_minutes)
    return jwt.encode({**payload, "exp": exp}, settings.JWT_SECRET, algorithm="HS256")


def create_access_token(user_id: uuid.UUID) -> str:
    return _encode({"sub": str(user_id), "type": "access"}, settings.ACCESS_TOKEN_MINUTES)


def create_refresh_token(user_id: uuid.UUID, token_version: int) -> str:
    return _encode(
        {"sub": str(user_id), "ver": token_version, "type": "refresh"},
        settings.REFRESH_TOKEN_DAYS * 24 * 60,
    )


def decode_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
    except JWTError as exc:
        raise ValueError("Invalid or expired token") from exc
