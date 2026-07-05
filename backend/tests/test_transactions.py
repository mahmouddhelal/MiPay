"""
Transactions CRUD tests — require a running Postgres with migrations applied.
Run with: docker compose exec api pytest tests/test_transactions.py -v
"""
import uuid

import pytest
from httpx import AsyncClient


async def _register(client: AsyncClient, email: str) -> dict[str, str]:
    r = await client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "display_name": email.split("@")[0],
    })
    assert r.status_code == 201
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _unique_email(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:8]}@example.com"


_TX = {
    "transaction_type": "expense",
    "amount": 50.0,
    "currency": "SAR",
    "category": "groceries",
    "name": "كارفور",
    "date": "2026-06-11",
    "source": "manual",
}


@pytest.mark.asyncio
async def test_create_and_get(client: AsyncClient) -> None:
    headers = await _register(client, _unique_email("tx-create"))

    r = await client.post("/api/v1/transactions", json=_TX, headers=headers)
    assert r.status_code == 201
    created = r.json()
    assert created["amount"] == 50.0
    assert created["category"] == "groceries"
    assert created["name"] == "كارفور"

    r = await client.get(f"/api/v1/transactions/{created['id']}", headers=headers)
    assert r.status_code == 200
    assert r.json()["id"] == created["id"]


@pytest.mark.asyncio
async def test_create_invalid_category(client: AsyncClient) -> None:
    headers = await _register(client, _unique_email("tx-badcat"))
    r = await client.post(
        "/api/v1/transactions",
        json={**_TX, "category": "nonexistent"},
        headers=headers,
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_create_negative_amount(client: AsyncClient) -> None:
    headers = await _register(client, _unique_email("tx-neg"))
    r = await client.post(
        "/api/v1/transactions",
        json={**_TX, "amount": -5},
        headers=headers,
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_list_with_filters(client: AsyncClient) -> None:
    headers = await _register(client, _unique_email("tx-list"))

    await client.post("/api/v1/transactions", json=_TX, headers=headers)
    await client.post("/api/v1/transactions", json={
        **_TX, "transaction_type": "income", "category": "salary",
        "amount": 4500, "date": "2026-06-01", "name": "salary",
    }, headers=headers)
    await client.post("/api/v1/transactions", json={
        **_TX, "date": "2026-05-20", "amount": 30,
    }, headers=headers)

    r = await client.get("/api/v1/transactions?month=2026-06", headers=headers)
    assert r.status_code == 200
    data = r.json()
    assert data["total"] == 2
    # newest first
    assert data["items"][0]["date"] == "2026-06-11"

    r = await client.get("/api/v1/transactions?type=income", headers=headers)
    assert r.json()["total"] == 1
    assert r.json()["items"][0]["category"] == "salary"

    r = await client.get("/api/v1/transactions?category=groceries", headers=headers)
    assert r.json()["total"] == 2

    r = await client.get("/api/v1/transactions?month=2026-6", headers=headers)
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_update_and_delete(client: AsyncClient) -> None:
    headers = await _register(client, _unique_email("tx-upd"))

    created = (await client.post("/api/v1/transactions", json=_TX, headers=headers)).json()

    r = await client.patch(
        f"/api/v1/transactions/{created['id']}",
        json={"amount": 75.5, "note": "updated"},
        headers=headers,
    )
    assert r.status_code == 200
    assert r.json()["amount"] == 75.5
    assert r.json()["note"] == "updated"

    r = await client.delete(f"/api/v1/transactions/{created['id']}", headers=headers)
    assert r.status_code == 204

    r = await client.get(f"/api/v1/transactions/{created['id']}", headers=headers)
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_per_user_isolation(client: AsyncClient) -> None:
    """FR-13: users can only ever access their own data."""
    headers_a = await _register(client, _unique_email("alice-iso"))
    headers_b = await _register(client, _unique_email("bob-iso"))

    created = (await client.post("/api/v1/transactions", json=_TX, headers=headers_a)).json()

    # B cannot read, update, or delete A's transaction
    r = await client.get(f"/api/v1/transactions/{created['id']}", headers=headers_b)
    assert r.status_code == 404

    r = await client.patch(
        f"/api/v1/transactions/{created['id']}", json={"amount": 1}, headers=headers_b
    )
    assert r.status_code == 404

    r = await client.delete(f"/api/v1/transactions/{created['id']}", headers=headers_b)
    assert r.status_code == 404

    # B's list does not contain A's transaction
    r = await client.get("/api/v1/transactions", headers=headers_b)
    assert r.json()["total"] == 0

    # A still sees it untouched
    r = await client.get(f"/api/v1/transactions/{created['id']}", headers=headers_a)
    assert r.status_code == 200
    assert r.json()["amount"] == 50.0


@pytest.mark.asyncio
async def test_categories_endpoint(client: AsyncClient) -> None:
    headers = await _register(client, _unique_email("cats"))
    r = await client.get("/api/v1/categories", headers=headers)
    assert r.status_code == 200
    cats = r.json()
    assert len(cats) == 29
    keys = {c["key"] for c in cats}
    assert "groceries" in keys and "salary" in keys and "other" in keys
    grocery = next(c for c in cats if c["key"] == "groceries")
    assert grocery["label_ar"] == "بقالة وسوبرماركت"

    # requires auth
    r = await client.get("/api/v1/categories")
    assert r.status_code in (401, 403)
