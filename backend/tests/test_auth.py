"""
Auth integration tests — require a running Postgres DB (set DATABASE_URL in .env).
Run with: docker compose exec api pytest tests/test_auth.py -v
"""
import uuid

import pytest
from httpx import AsyncClient


def _email(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:8]}@example.com"


@pytest.mark.asyncio
async def test_register_success(client: AsyncClient) -> None:
    email = _email("alice")
    r = await client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "display_name": "Alice",
    })
    assert r.status_code == 201
    data = r.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == email
    assert "password_hash" not in data["user"]


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient) -> None:
    payload = {"email": _email("bob"), "password": "password123", "display_name": "Bob"}
    await client.post("/api/v1/auth/register", json=payload)
    r = await client.post("/api/v1/auth/register", json=payload)
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "EMAIL_TAKEN"


@pytest.mark.asyncio
async def test_register_short_password(client: AsyncClient) -> None:
    r = await client.post("/api/v1/auth/register", json={
        "email": _email("carol"),
        "password": "short",
        "display_name": "Carol",
    })
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient) -> None:
    email = _email("dave")
    await client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "display_name": "Dave",
    })
    r = await client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "password123",
    })
    assert r.status_code == 200
    assert "access_token" in r.json()


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient) -> None:
    email = _email("eve")
    await client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "display_name": "Eve",
    })
    r = await client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "wrongpassword",
    })
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "INVALID_CREDENTIALS"


@pytest.mark.asyncio
async def test_protected_route_no_token(client: AsyncClient) -> None:
    r = await client.get("/api/v1/users/me")
    assert r.status_code in (401, 403)  # HTTPBearer: 403 on older FastAPI, 401 on newer


@pytest.mark.asyncio
async def test_protected_route_with_token(client: AsyncClient) -> None:
    email = _email("frank")
    reg = await client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "display_name": "Frank",
    })
    token = reg.json()["access_token"]

    r = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert r.json()["email"] == email


@pytest.mark.asyncio
async def test_refresh_token(client: AsyncClient) -> None:
    reg = await client.post("/api/v1/auth/register", json={
        "email": _email("grace"),
        "password": "password123",
        "display_name": "Grace",
    })
    refresh_token = reg.json()["refresh_token"]

    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert r.status_code == 200
    data = r.json()
    assert "access_token" in data
    assert data["refresh_token"] != refresh_token  # rotated


@pytest.mark.asyncio
async def test_refresh_token_reuse_rejected(client: AsyncClient) -> None:
    reg = await client.post("/api/v1/auth/register", json={
        "email": _email("henry"),
        "password": "password123",
        "display_name": "Henry",
    })
    old_refresh = reg.json()["refresh_token"]

    await client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})

    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert r.status_code == 401  # token_version mismatch
