#!/usr/bin/env python3
"""
Demo seed script — creates a demo user account and populates it with
realistic transactions spanning the past two months for thesis demo purposes.

Usage
-----
    # Containers must be running (docker compose up -d):
    python scripts/seed_demo.py

    # Custom backend URL:
    BASE_URL=http://localhost:8000/api/v1 python scripts/seed_demo.py

Output
------
Prints the demo credentials and a brief summary of what was seeded.
"""

import json
import sys
from datetime import date, timedelta

try:
    import httpx
except ImportError:
    sys.exit("httpx not found. Run: pip install httpx")

BASE_URL = "http://localhost:8000/api/v1"

DEMO_EMAIL    = "demo@mipay.app"
DEMO_PASSWORD = "demo1234"
DEMO_NAME     = "Ahmed (Demo)"
DEMO_CURRENCY = "EGP"

# ── Helpers ────────────────────────────────────────────────────────────────────

def _days_ago(n: int) -> str:
    return (date.today() - timedelta(days=n)).isoformat()

def post(client: httpx.Client, path: str, **kwargs) -> dict:
    r = client.post(f"{BASE_URL}{path}", **kwargs)
    if r.status_code not in (200, 201):
        print(f"  [WARN] POST {path} → {r.status_code}: {r.text[:120]}")
    return r.json()

# ── Transaction dataset ────────────────────────────────────────────────────────
# 20 transactions: mix of expense / income, Arabic / English merchant names,
# EGP amounts, multiple categories spanning ~6 weeks so the dashboard chart
# has meaningful data for current month and the previous one.

def transactions_for(today: date) -> list[dict]:
    def ago(n): return (today - timedelta(days=n)).isoformat()

    return [
        # ── Current month (last ~10 days) ──────────────────────────────────────
        {"transaction_type": "expense", "amount": "250.00", "currency": "EGP",
         "category": "groceries",   "name": "كارفور",        "date": ago(0)},
        {"transaction_type": "expense", "amount": "85.00",  "currency": "EGP",
         "category": "restaurants", "name": "كشري أبو طارق","date": ago(1)},
        {"transaction_type": "expense", "amount": "320.00", "currency": "EGP",
         "category": "fuel",        "name": "محطة موبيل",    "date": ago(2)},
        {"transaction_type": "expense", "amount": "150.00", "currency": "EGP",
         "category": "transport",   "name": "كريم",          "date": ago(3)},
        {"transaction_type": "expense", "amount": "500.00", "currency": "EGP",
         "category": "shopping",    "name": "H&M مول العرب", "date": ago(4)},
        {"transaction_type": "income", "amount": "18500.00","currency": "EGP",
         "category": "salary",      "name": "شركة التقنية",  "date": ago(5)},
        {"transaction_type": "expense", "amount": "420.00", "currency": "EGP",
         "category": "bills",       "name": "فودافون",       "date": ago(6)},
        {"transaction_type": "expense", "amount": "200.00", "currency": "EGP",
         "category": "health",      "name": "صيدلية العزبي", "date": ago(7)},
        {"transaction_type": "expense", "amount": "75.00",  "currency": "EGP",
         "category": "entertainment","name": "Cine Scan",    "date": ago(8)},
        {"transaction_type": "expense", "amount": "190.00", "currency": "EGP",
         "category": "groceries",   "name": "سبينس",         "date": ago(9)},

        # ── Previous month (30–45 days ago) ───────────────────────────────────
        {"transaction_type": "income", "amount": "18500.00","currency": "EGP",
         "category": "salary",      "name": "شركة التقنية",  "date": ago(35)},
        {"transaction_type": "expense", "amount": "6500.00","currency": "EGP",
         "category": "rent",        "name": "إيجار شقة",     "date": ago(33)},
        {"transaction_type": "expense", "amount": "340.00", "currency": "EGP",
         "category": "groceries",   "name": "أولاد رجب",     "date": ago(31)},
        {"transaction_type": "expense", "amount": "1200.00","currency": "EGP",
         "category": "shopping",    "name": "إيكيا",         "date": ago(30)},
        {"transaction_type": "expense", "amount": "600.00", "currency": "EGP",
         "category": "bills",       "name": "وي للإنترنت",   "date": ago(29)},
        {"transaction_type": "expense", "amount": "290.00", "currency": "EGP",
         "category": "fuel",        "name": "محطة توتال",    "date": ago(28)},
        {"transaction_type": "expense", "amount": "450.00", "currency": "EGP",
         "category": "education",   "name": "Coursera",      "date": ago(27)},
        {"transaction_type": "expense", "amount": "120.00", "currency": "EGP",
         "category": "personal_care","name": "نيكست",        "date": ago(26)},
        {"transaction_type": "income", "amount": "2000.00", "currency": "EGP",
         "category": "business",    "name": "مشروع فريلانس", "date": ago(25)},
        {"transaction_type": "expense", "amount": "95.00",  "currency": "EGP",
         "category": "restaurants", "name": "مومن",          "date": ago(24)},
    ]

# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    today = date.today()

    with httpx.Client(base_url=BASE_URL, timeout=15) as client:
        # ── 1. Register (idempotent: if user exists, fall through to login) ──
        print(f"[1/4] Registering demo user ({DEMO_EMAIL})…")
        reg = post(client, "/auth/register", json={
            "email": DEMO_EMAIL,
            "password": DEMO_PASSWORD,
            "display_name": DEMO_NAME,
            "default_currency": DEMO_CURRENCY,
        })
        if "access_token" in reg:
            token = reg["access_token"]
            print("      ✓ New account created.")
        else:
            # Account already exists — log in instead
            print("      Account exists, logging in…")
            login = post(client, "/auth/login", json={
                "email": DEMO_EMAIL,
                "password": DEMO_PASSWORD,
            })
            if "access_token" not in login:
                sys.exit(f"Login failed: {json.dumps(login, ensure_ascii=False)}")
            token = login["access_token"]
            print("      ✓ Logged in.")

        auth_headers = {"Authorization": f"Bearer {token}"}

        # ── 2. Update locale to Arabic for the demo ──────────────────────────
        print("[2/4] Setting locale to ar (Arabic)…")
        r = client.patch("/users/me", json={"locale": "ar"}, headers=auth_headers)
        if r.status_code == 200:
            print("      ✓ Locale set to ar.")
        else:
            print(f"      [WARN] locale update {r.status_code}")

        # ── 3. Seed transactions ─────────────────────────────────────────────
        print("[3/4] Seeding transactions…")
        txs = transactions_for(today)
        ok = fail = 0
        for tx in txs:
            tx_payload = {**tx, "source": "manual"}
            r = client.post("/transactions", json=tx_payload, headers=auth_headers)
            if r.status_code in (200, 201):
                ok += 1
            else:
                fail += 1
                print(f"  [WARN] {tx['name']}: {r.status_code} {r.text[:80]}")
        print(f"      ✓ {ok} transactions created, {fail} failed.")

        # ── 4. Print summary ─────────────────────────────────────────────────
        print("[4/4] Verifying via /summary…")
        month = today.strftime("%Y-%m")
        r = client.get(f"/summary?month={month}", headers=auth_headers)
        if r.status_code == 200:
            s = r.json()
            income  = float(s.get("total_income",  0))
            expense = float(s.get("total_expense", 0))
            balance = float(s.get("balance",       0))
            print(f"      {month}: income={income:,.0f} EGP  "
                  f"expense={expense:,.0f} EGP  balance={balance:,.0f} EGP")

    print()
    print("=" * 52)
    print("  Demo account ready")
    print(f"  Email   : {DEMO_EMAIL}")
    print(f"  Password: {DEMO_PASSWORD}")
    print("=" * 52)

if __name__ == "__main__":
    main()
