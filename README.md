# MiPay — Voice-First Personal Finance Tracker

A bilingual (Arabic/English) voice-first mobile app that lets users say a sentence like "دفعت ٢٥٠ جنيه على البقالة في كارفور امبارح" and automatically saves the structured transaction.

**Stack**: FastAPI · PostgreSQL · faster-whisper · Ollama/Qwen2.5 · Flutter/Riverpod

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Docker + Docker Compose | v2.20+ | All backend services run in containers |
| Flutter SDK | 3.22+ | For building/running the mobile app |
| Android SDK or iOS tools | matching Flutter | Device/emulator needed for the app |
| 10 GB free disk | — | Whisper model (~500 MB) + Qwen2.5-7B (~5 GB) |
| 8 GB RAM | 16 GB preferred | Running Whisper + Qwen2.5 simultaneously |

---

## Quick Start (fresh machine)

### 1. Clone and configure

```bash
git clone <repo-url> MiPay
cd MiPay
cp .env .env           # .env already has safe defaults — change JWT_SECRET
```

Edit `.env` and set a real `JWT_SECRET`:

```bash
JWT_SECRET=$(openssl rand -hex 32)   # paste this value into .env
```

### 2. Start all services

```bash
docker compose up -d
```

This starts:
- `postgres` — PostgreSQL 16 on port 5432
- `ollama` — Ollama LLM server on port 11434
- `api` — FastAPI backend on port 8000 (waits for postgres health check)

First startup downloads the Whisper model on first request (cached in `whisper_models` volume).

### 3. Run database migrations and pull the LLM model

```bash
bash scripts/setup.sh
```

This runs `alembic upgrade head` (creates all tables + seeds 17 categories) and pulls `qwen2.5:7b-instruct` into the Ollama container. The model pull takes 5–15 minutes depending on your connection.

### 4. Verify the backend is healthy

```bash
curl http://localhost:8000/api/v1/health
# Expected: {"status":"ok","db_ok":true,"ollama_reachable":true,...}
```

### 5. (Optional) Seed the demo account

```bash
pip install httpx          # or use your venv
python scripts/seed_demo.py
```

Creates a demo user with 20 pre-seeded transactions for the demo walkthrough:

```
Email   : demo@mipay.app
Password: demo1234
```

### 6. Run the Flutter app

```bash
cd mipay_app
flutter pub get
flutter run
```

The app is configured to connect to `192.168.1.42:8000`. To connect to a different host (emulator, device, CI), edit the `_baseUrl` constant in [mipay_app/lib/core/api/dio_client.dart](mipay_app/lib/core/api/dio_client.dart):

```dart
// Physical device → host LAN IP
const _baseUrl = 'http://192.168.1.42:8000/api/v1';

// Android emulator → host machine
const _baseUrl = 'http://10.0.2.2:8000/api/v1';

// iOS simulator → host machine
const _baseUrl = 'http://localhost:8000/api/v1';
```

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://mipay:changeme@postgres:5432/mipay` | Async SQLAlchemy DSN |
| `POSTGRES_PASSWORD` | `changeme` | Passed to the Postgres container |
| `JWT_SECRET` | *(must set)* | HS256 signing key — generate with `openssl rand -hex 32` |
| `ACCESS_TOKEN_MINUTES` | `30` | Access token lifetime |
| `REFRESH_TOKEN_DAYS` | `30` | Refresh token lifetime |
| `WHISPER_MODEL` | `small` | Faster-Whisper model size: `tiny`, `base`, `small`, `medium` |
| `WHISPER_COMPUTE_TYPE` | `int8` | Inference precision: `int8` (CPU) or `float16` (GPU) |
| `OLLAMA_URL` | `http://ollama:11434` | Ollama server URL |
| `EXTRACTION_MODEL` | `qwen2.5:7b-instruct` | Ollama model used for transaction extraction |
| `MAX_AUDIO_SECONDS` | `30` | Maximum recording length accepted by the API |
| `MAX_AUDIO_BYTES` | `5242880` | Maximum audio file size (5 MB) |

---

## Project Structure

```
MiPay/
├── docker-compose.yml
├── .env                    # secrets + config (never commit real values)
├── scripts/
│   ├── setup.sh            # run migrations + pull LLM model
│   └── seed_demo.py        # populate demo account
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── alembic/            # database migrations
│   ├── app/
│   │   ├── api/v1/         # FastAPI routers
│   │   ├── models/         # SQLAlchemy models
│   │   ├── schemas/        # Pydantic request/response models
│   │   ├── services/       # stt.py, extraction.py, postprocess.py
│   │   └── core/           # config, security, deps
│   ├── evaluation/
│   │   ├── dataset.jsonl   # 250-utterance labeled eval set
│   │   ├── run_stt_eval.py
│   │   └── run_extraction_eval.py
│   └── tests/
└── mipay_app/              # Flutter app
    └── lib/
        ├── features/       # auth, record, transactions, dashboard, settings
        ├── core/           # router, api client, auth, providers
        └── l10n/           # Arabic + English ARB localizations
```

---

## Running Tests

```bash
# Backend unit tests (no containers needed for pure tests):
docker compose exec api pytest tests/ -v

# Or locally with a running Postgres (set DATABASE_URL):
cd backend && pytest tests/ -v
```

---

## Evaluation (thesis §4.6)

Ensure containers are running and a user account exists (e.g., via `seed_demo.py`), then:

```bash
# Extraction accuracy (condition a — gold transcript → LLM):
EVAL_EMAIL=demo@mipay.app EVAL_PASSWORD=demo1234 \
python backend/evaluation/run_extraction_eval.py --condition gold

# Full pipeline (condition b — audio → Whisper → LLM):
# Audio files must be in backend/evaluation/audio/
EVAL_EMAIL=demo@mipay.app EVAL_PASSWORD=demo1234 \
python backend/evaluation/run_extraction_eval.py --condition e2e

# STT Word Error Rate:
# Note: requires temporarily re-enabling POST /debug/transcribe (see run_stt_eval.py header)
python backend/evaluation/run_stt_eval.py
```

---

## Hardware Requirements

| Component | CPU-only | With GPU (NVIDIA) |
|---|---|---|
| Whisper `small` | ~2 GB RAM, ~1× realtime | GPU: ~0.2× realtime |
| Qwen2.5-7B (int4) | ~6 GB RAM, ~5 s/request | GPU: ~1 s/request |
| PostgreSQL | ~256 MB | — |
| Flutter app | Android 6.0+ / iOS 13+ | — |

Minimum: 8 GB RAM. Recommended for comfortable development: 16 GB RAM.

To use GPU acceleration for Ollama, uncomment the `deploy.resources` block in `docker-compose.yml` and ensure the NVIDIA Container Toolkit is installed.

---

## API Reference

The FastAPI backend auto-generates interactive docs at:

- Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)
- ReDoc: [http://localhost:8000/redoc](http://localhost:8000/redoc)

Key endpoints:

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | — | Create account |
| `POST` | `/api/v1/auth/login` | — | Get access + refresh tokens |
| `POST` | `/api/v1/auth/refresh` | — | Rotate tokens |
| `GET` | `/api/v1/users/me` | 🔒 | Current user profile |
| `PATCH` | `/api/v1/users/me` | 🔒 | Update display name / currency / locale |
| `POST` | `/api/v1/transactions/voice` | 🔒 | Upload audio → extract → return structured result |
| `POST` | `/api/v1/transactions/extract-text` | 🔒 | Text → extract (no audio) |
| `GET` | `/api/v1/transactions` | 🔒 | List transactions (filter by month/category) |
| `POST` | `/api/v1/transactions` | 🔒 | Create transaction manually |
| `PATCH` | `/api/v1/transactions/{id}` | 🔒 | Edit transaction |
| `DELETE` | `/api/v1/transactions/{id}` | 🔒 | Delete transaction |
| `GET` | `/api/v1/categories` | 🔒 | List all 17 categories with bilingual labels |
| `GET` | `/api/v1/summary` | 🔒 | Monthly income/expense/balance + per-category breakdown |
| `GET` | `/api/v1/health` | — | Service health (DB + Ollama + Whisper status) |

---

## Troubleshooting

**Ollama model not responding**
```bash
docker compose logs ollama
docker compose exec ollama ollama list   # check model is present
docker compose exec ollama ollama pull qwen2.5:7b-instruct   # re-pull if missing
```

**Alembic migration fails**
```bash
docker compose exec api alembic current     # show current migration head
docker compose exec api alembic upgrade head
```

**Flutter can't reach the backend**
Check `_baseUrl` in [mipay_app/lib/core/api/dio_client.dart](mipay_app/lib/core/api/dio_client.dart) matches your host IP/port. On a physical Android device use `adb reverse tcp:8000 tcp:8000` for USB debugging, or set the LAN IP of your machine.

**High RAM usage**
Switch to the `tiny` or `base` Whisper model by setting `WHISPER_MODEL=tiny` in `.env` and restarting the `api` container.
