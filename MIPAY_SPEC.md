# MiPay — MVP Technical Specification

> **Audience:** This document is a complete, self-contained implementation specification. It is written to be handed to a developer or an AI coding agent who has **no other context** about the project. Follow it section by section; all model names, package names, schemas, endpoints, and folder structures are prescriptive, not suggestions.
>
> **Project type:** Master's degree (Computer Science) graduation project.
> **Date:** June 2026.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Requirements](#2-requirements)
3. [System Design](#3-system-design)
4. [AI/ML Pipeline](#4-aiml-pipeline)
5. [Backend Specification](#5-backend-specification)
6. [Database Schema](#6-database-schema)
7. [Flutter App Specification](#7-flutter-app-specification)
8. [Folder Structure](#8-folder-structure)
9. [Dev Environment & Deployment](#9-dev-environment--deployment)
10. [Implementation Milestones](#10-implementation-milestones)
11. [Risks & Future Work](#11-risks--future-work)

---

## 1. Project Overview

**MiPay** is a bilingual (Arabic/English) voice-first personal finance tracker.

The core user flow: the user **presses a button and speaks** a sentence describing money they spent or received — in Arabic, English, or a mix of both:

> 🎤 "I paid 50 riyals for groceries at Carrefour yesterday"
>
> 🎤 «دفعت خمسين ريال على البقالة من كارفور أمس»
>
> 🎤 "حولت لي أمي 200 dollars اليوم"

The system then:

1. **Transcribes** the audio (speech-to-text) using a self-hosted Whisper model.
2. **Extracts** structured data from the transcript using a self-hosted LLM:
   - `type` — expense or income
   - `amount` — numeric value
   - `currency` — currency code
   - `category` — from a fixed bilingual category list
   - `name` — merchant / payee / payer / short description
   - `date` — resolved absolute date (handles "yesterday" / «أمس»)
3. Shows the extracted transaction to the user for **confirmation or quick editing**.
4. **Saves** it to the user's account and displays it in lists and a simple dashboard.

### Architecture summary (decided — do not change)

| Concern | Decision |
|---|---|
| Mobile app | **Flutter** (Android primary target; iOS-compatible code) |
| Backend framework | **FastAPI** (Python 3.11+) |
| Database | **PostgreSQL 16** + SQLAlchemy 2.0 (async) + Alembic migrations |
| Speech-to-text | **Self-hosted Whisper** via `faster-whisper` (no cloud STT) |
| Extraction NLP | **Self-hosted open-source LLM** via **Ollama**, model `qwen2.5:7b-instruct`, with JSON-schema-constrained output |
| Auth | **JWT** (access + refresh tokens), multi-user, per-user data isolation |
| Deployment | Docker Compose: `api` + `postgres` + `ollama` |

**Why this matters academically:** the entire AI pipeline (STT + NLP extraction) is self-hosted open-source ML, not a thin wrapper over a paid cloud API. This gives the thesis: model selection rationale, an evaluation methodology with measurable metrics (WER, field-level F1), zero per-request cost, and full data privacy.

### MVP scope

**In scope:**
- Voice recording → transcription → extraction → confirm → save (the core loop)
- Manual transaction entry/edit/delete (fallback when voice fails)
- Bilingual UI (Arabic with RTL + English) switchable in settings
- Transaction list with filters (month, category, type)
- Simple dashboard: monthly total income, total expenses, balance, per-category breakdown
- Register / login / logout

**Out of scope (do NOT build for MVP):**
- Budgets, goals, recurring transactions, notifications
- Receipt OCR / camera input
- Bank integrations
- Offline-first sync (app requires connectivity for voice processing)
- Social features, export, multi-currency conversion rates
- Admin panel

---

## 2. Requirements

### 2.1 Functional Requirements

| ID | Requirement |
|---|---|
| FR-01 | A user can register with email + password and log in; sessions persist via refresh tokens. |
| FR-02 | A user can record a voice note (max 30 seconds) from the home screen with a single tap (tap to start, tap to stop). |
| FR-03 | The recorded audio is uploaded to the backend, which returns the transcript **and** the extracted transaction fields in one response. |
| FR-04 | Extraction must work for utterances in Modern Standard Arabic, common Arabic dialects (Gulf/Egyptian/Levantine — best effort), English, and mixed Arabic-English (code-switching). |
| FR-05 | The extracted fields are: `type` (expense/income), `amount`, `currency`, `category`, `name`, `date`. Missing fields are returned as `null` (except `type` and `amount`, which are required — see FR-07). |
| FR-06 | Relative dates ("yesterday", «أمس», "last Friday», «قبل يومين») are resolved to absolute ISO dates server-side using the device-supplied current date. |
| FR-07 | If `amount` cannot be extracted, the API returns a structured "needs_review" result; the app opens the manual entry form pre-filled with whatever was extracted. |
| FR-08 | Before saving, the app shows a confirmation sheet where the user can edit any field; categories are picked from a fixed bilingual list. |
| FR-09 | A user can create, view, edit, and delete transactions manually (full CRUD). |
| FR-10 | A user can view transactions in a list, filterable by month, category, and type, sorted newest-first. |
| FR-11 | A user can view a dashboard for a selected month: total income, total expenses, net balance, and expenses-per-category breakdown. |
| FR-12 | The UI is fully localized in Arabic (RTL) and English (LTR); the user can switch language in settings; default follows device locale. |
| FR-13 | Users can only ever access their own data (enforced server-side on every endpoint). |

### 2.2 Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-01 | End-to-end voice processing latency target: **≤ 10 s** for a 10-second clip on the reference server (CPU-only); ≤ 4 s with GPU. Show a progress indicator in the app. |
| NFR-02 | Extraction quality target on the evaluation set (§4.6): **≥ 90% exact-match on `amount`**, ≥ 80% on `category`, ≥ 85% on `type`. STT target: WER ≤ 20% (Arabic), ≤ 12% (English). |
| NFR-03 | Passwords hashed with **bcrypt**; JWTs signed with HS256; secrets only via environment variables; HTTPS assumed at the reverse-proxy layer (out of scope for MVP code). |
| NFR-04 | Audio files are **deleted from the server immediately after processing** (privacy). Only the transcript is stored, attached to the transaction for traceability. |
| NFR-05 | All API responses follow a consistent JSON envelope and error format (§5.4). |
| NFR-06 | The backend runs entirely on one machine with 16 GB RAM, no GPU required (GPU optional acceleration). |
| NFR-07 | Code quality: backend typed (mypy-clean preferred), tests for the extraction post-processing layer and auth; Flutter analyzer-clean. |

---

## 3. System Design

### 3.1 Architecture diagram

```
┌─────────────────────────┐
│      Flutter App        │
│  (Android / iOS)        │
│                         │
│  • record 16 kHz audio  │
│  • JWT auth storage     │
│  • Riverpod state       │
│  • ar/en l10n + RTL     │
└───────────┬─────────────┘
            │ HTTPS / REST (JSON, multipart for audio)
            ▼
┌─────────────────────────────────────────────────────┐
│                 FastAPI Backend (api)                │
│                                                      │
│  /auth/*          /transactions/*       /summary     │
│        │                  │                          │
│        │         ┌────────┴─────────┐                │
│        │         │  Voice Pipeline   │               │
│        │         │  (service layer)  │               │
│        │         └───┬──────────┬───┘                │
│        │             │          │                    │
│        │             ▼          ▼                    │
│        │   ┌──────────────┐  ┌─────────────────┐     │
│        │   │ STT Service  │  │ Extraction Svc  │     │
│        │   │ faster-      │  │ HTTP → Ollama   │     │
│        │   │ whisper      │  │ (JSON schema)   │     │
│        │   │ (in-process) │  └────────┬────────┘     │
│        │   └──────────────┘           │              │
│        │                              │              │
│  ┌─────┴──────────────────────────┐   │              │
│  │  SQLAlchemy 2.0 (async)        │   │              │
│  └─────┬──────────────────────────┘   │              │
└────────┼──────────────────────────────┼──────────────┘
         ▼                              ▼
┌──────────────────┐         ┌──────────────────────┐
│  PostgreSQL 16   │         │  Ollama server       │
│  (users,         │         │  qwen2.5:7b-instruct │
│   transactions,  │         │  (separate container) │
│   categories)    │         └──────────────────────┘
└──────────────────┘
```

Three containers via Docker Compose: **api** (FastAPI + faster-whisper in-process), **postgres**, **ollama**. The Flutter app is a separate client project.

### 3.2 Voice transaction sequence

```
User          Flutter App           FastAPI              Whisper        Ollama         Postgres
 │  tap+speak     │                    │                    │              │               │
 │───────────────▶│                    │                    │              │               │
 │                │ POST /api/v1/transactions/voice         │              │               │
 │                │  (multipart: audio.m4a, client_date,    │              │               │
 │                │   client_locale)   │                    │              │               │
 │                │───────────────────▶│                    │              │               │
 │                │                    │ transcribe(audio)  │              │               │
 │                │                    │───────────────────▶│              │               │
 │                │                    │◀── transcript, lang─┤              │               │
 │                │                    │ extract(transcript, client_date)  │               │
 │                │                    │──────────────────────────────────▶│               │
 │                │                    │◀──── raw JSON ─────────────────────┤               │
 │                │                    │ post-process + validate (Pydantic,│               │
 │                │                    │ numerals, dates, category map)    │               │
 │                │                    │ delete audio file  │              │               │
 │                │◀── 200 {transcript, extraction, status}─┤              │               │
 │  review sheet  │                    │                    │              │               │
 │◀───────────────│                    │                    │              │               │
 │  confirm/edit  │                    │                    │              │               │
 │───────────────▶│ POST /api/v1/transactions (final JSON)  │              │               │
 │                │───────────────────▶│ INSERT ────────────────────────────────────────-─▶│
 │                │◀────── 201 created ┤                    │              │               │
```

**Design choice — two-step save:** the voice endpoint does **not** save anything. It returns the extraction; the app saves via the normal `POST /transactions` after user confirmation. This keeps the AI pipeline stateless, makes wrong extractions harmless, and gives a natural human-in-the-loop checkpoint (important to state in the thesis).

**Design choice — synchronous processing:** the voice endpoint processes inline (request waits ~3–10 s). At MVP scale (single user demoing) this is fine and far simpler than a job queue. Document the upgrade path (FastAPI `BackgroundTasks` or Celery + polling endpoint) in code comments but do not build it.

### 3.3 Component rationale (for the thesis write-up)

| Component | Chosen | Rejected alternatives & why |
|---|---|---|
| STT | faster-whisper (CTranslate2 reimplementation of OpenAI Whisper) | Cloud STT APIs (cost, privacy, no academic ML contribution); on-device `speech_to_text` plugin (inconsistent Arabic quality across devices, no control); vanilla `openai-whisper` (4× slower than faster-whisper on CPU) |
| Extraction | Qwen2.5-7B-Instruct via Ollama | Cloud LLM APIs (cost/privacy, thin-wrapper criticism); regex/rule-based (cannot handle dialects/code-switching); fine-tuned BERT NER (needs labeled training data that doesn't exist for this domain — listed as future work) |
| Backend | FastAPI | Django (heavier, sync-first ORM by default); Node/NestJS (would split the stack away from the Python ML ecosystem) |
| DB | PostgreSQL | SQLite (fine locally but weaker concurrency/typing story for a multi-user demo); MongoDB (transactions are relational/aggregated data — SQL is the right shape) |

---

## 4. AI/ML Pipeline

This is the academic core of the project. Implement it exactly as specified.

### 4.1 Speech-to-Text: faster-whisper

- **Package:** `faster-whisper` (PyPI). Loads Whisper weights converted to CTranslate2; ~4× faster than reference Whisper on CPU with same accuracy.
- **Model size:** default **`small`** (~466 MB, good ar/en balance on CPU). Make it configurable via env var `WHISPER_MODEL` (`base`/`small`/`medium`). Use `medium` if a GPU is available — noticeably better Arabic.
- **Compute type:** `int8` on CPU, `float16` on GPU (env `WHISPER_COMPUTE_TYPE`).
- **Loading:** load the model **once at app startup** (FastAPI lifespan handler), keep it as a singleton. Never load per-request.
- **Audio input:** accept `m4a`/`aac`/`wav`/`mp3`; convert to 16 kHz mono WAV with `ffmpeg` (subprocess) before transcription. `ffmpeg` must be in the api container image.

```python
# app/services/stt.py — core call (illustrative)
from faster_whisper import WhisperModel

model = WhisperModel(settings.WHISPER_MODEL, compute_type=settings.WHISPER_COMPUTE_TYPE)

segments, info = model.transcribe(
    wav_path,
    language=None,        # None = auto-detect; critical for ar/en/mixed
    beam_size=5,
    vad_filter=True,      # trims silence; improves short-clip accuracy
)
transcript = " ".join(s.text for s in segments).strip()
detected_language = info.language          # "ar" or "en"
language_probability = info.language_probability
```

**Code-switching note:** Whisper detects one dominant language per clip but transcribes embedded foreign words reasonably well. Pass `language=None` always. The downstream LLM handles mixed-language transcripts; do not try to split the audio.

### 4.2 Extraction: Qwen2.5-7B-Instruct via Ollama

- **Server:** Ollama (official Docker image `ollama/ollama`), reachable from the api container at `OLLAMA_URL` (default `http://ollama:11434`).
- **Model:** **`qwen2.5:7b-instruct`** — chosen for strong multilingual (incl. Arabic) instruction following at 7B. Pull at provisioning time: `ollama pull qwen2.5:7b-instruct`.
- **Low-spec fallback:** `qwen2.5:3b-instruct` (env `EXTRACTION_MODEL`). Document in README that 3B reduces extraction accuracy.
- **API call:** `POST {OLLAMA_URL}/api/chat` with:
  - `"format": <json schema object>` — Ollama constrains decoding to the schema → output is **guaranteed parseable JSON** matching the schema. This is mandatory; do not rely on "please answer in JSON" prompting alone.
  - `"options": {"temperature": 0}` — deterministic extraction.
  - `"stream": false`.

### 4.3 Extraction JSON schema (verbatim — use exactly this)

A single utterance may describe **several** transactions ("coffee 50, croissant 100, and
my dad sent me 200" → three). The model therefore returns a **list** of per-transaction
objects under a `transactions` key. The per-transaction object is unchanged.

```json
{
  "type": "object",
  "properties": {
    "transactions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "transaction_type": { "type": ["string", "null"], "enum": ["expense", "income", null] },
          "amount":           { "type": ["number", "null"] },
          "currency":         { "type": ["string", "null"],
                                "enum": ["SAR", "USD", "EUR", "EGP", "AED", "KWD", "QAR", "BHD", "OMR", "JOD", "IQD", "SYP", "YER", "LYD", "TND", "DZD", "MAD", "SDG", "LBP", null] },
          "category":         { "type": ["string", "null"],
                                "enum": ["groceries", "restaurants", "transport", "fuel", "shopping", "bills", "rent", "health", "education", "entertainment", "travel", "personal_care", "gifts_donations", "salary", "business", "transfer_in", "other", null] },
          "name":             { "type": ["string", "null"] },
          "date_text":        { "type": ["string", "null"] },
          "confidence":       { "type": "string", "enum": ["high", "medium", "low"] }
        },
        "required": ["transaction_type", "amount", "currency", "category", "name", "date_text", "confidence"]
      }
    }
  },
  "required": ["transactions"]
}
```

**Key design points:**
- One utterance → a `transactions` array (length 1 for the common single-transaction case,
  0 when no transaction is described, N for compound utterances). Each element is
  post-processed independently and carries its own `status` (§4.5).
- The LLM outputs `date_text` — the **raw date phrase from the utterance** («أمس», "last
  friday", "March 3rd") — NOT a resolved date. Date resolution is done deterministically in
  Python (§4.5). LLMs are unreliable at date arithmetic; the deterministic resolver is also a
  testable contribution.

### 4.4 Extraction prompt (verbatim — use exactly this, few-shots included)

System message:

```
You are a financial transaction extraction engine for a personal finance app.
The user message is a voice-note transcript in Arabic, English, or a mix of both.
Return JSON of the form {"transactions": [ ... ]} following the provided schema.

- A single transcript may describe MULTIPLE transactions. Emit one object per distinct
  transaction in the "transactions" array, in the order spoken. Split into separate
  transactions whenever there are separate amounts or separate items/recipients
  (e.g. "I bought coffee for 50 and a croissant for 100 and my dad sent me 200" is THREE
  transactions). A single item with one amount is ONE transaction.
- If the transcript describes no transaction at all, return {"transactions": []}.

Per-transaction field rules:

- "transaction_type": "expense" if the user paid/spent/bought, "income" if the user
  received/earned/was paid/was sent money. null only if truly impossible to tell.
- "amount": the numeric amount only. Convert spelled-out numbers in either language
  (e.g. "fifty", "خمسين" -> 50; "مية وخمسين" -> 150). Keep it as spoken — do not
  convert currencies.
- "currency": ISO code of the spoken currency. Map words: ريال/riyal/ryal -> SAR
  (unless qatari/قطري -> QAR or omani/عماني -> OMR), دولار/dollar(s)/بكس -> USD,
  جنيه/pound (Egyptian context) -> EGP, درهم/dirham -> AED (unless مغربي -> MAD),
  دينار -> KWD if كويتي, JOD if أردني, BHD if بحريني, IQD if عراقي, LYD if ليبي,
  TND if تونسي, يورو/euro -> EUR, ليرة (Lebanese context) -> LBP, (Syrian) -> SYP.
  If no currency is spoken, return null.
- "category": pick the single best matching value from the schema enum. Examples:
  بقالة/سوبرماركت/groceries/تموينات -> groceries; مطعم/كافيه/غداء/قهوة/lunch/
  dinner/coffee -> restaurants; بنزين/وقود/petrol/gas -> fuel; أوبر/تاكسي/
  مواصلات/uber/taxi/metro -> transport; فاتورة/كهرباء/انترنت/جوال/bill/electricity
  -> bills; إيجار/rent -> rent; صيدلية/دكتور/مستشفى/pharmacy/doctor -> health;
  راتب/معاش/salary/paycheck -> salary; حوالة واردة/someone sent me money ->
  transfer_in. If nothing fits, use "other".
- "name": the merchant, store, person, or a 2-4 word description of what the money
  was for, in the language it was spoken. null if not mentioned.
- "date_text": copy the EXACT date/time phrase from the transcript ("أمس",
  "yesterday", "يوم الجمعة", "last week", "3 مارس"). Do NOT resolve it to a date.
  null if no date phrase is present.
- "confidence": "high" if amount and type are explicit; "medium" if you inferred
  something; "low" if the utterance barely describes a transaction.
- Never invent values. Prefer null over guessing.
```

Few-shot examples (send as alternating user/assistant chat messages before the real transcript):

Each assistant reply is the full `{"transactions":[...]}` envelope so the model learns to
wrap single transactions in a list and to split compound utterances.

```
user:      دفعت خمسين ريال على البقالة من كارفور أمس
assistant: {"transactions":[{"transaction_type":"expense","amount":50,"currency":"SAR","category":"groceries","name":"كارفور","date_text":"أمس","confidence":"high"}]}

user:      I got my salary today, 4500
assistant: {"transactions":[{"transaction_type":"income","amount":4500,"currency":null,"category":"salary","name":"salary","date_text":"today","confidence":"high"}]}

user:      حولت لي أمي مية وخمسين دولار يوم الجمعة
assistant: {"transactions":[{"transaction_type":"income","amount":150,"currency":"USD","category":"transfer_in","name":"أمي","date_text":"يوم الجمعة","confidence":"high"}]}

user:      paid like 30 bucks for the uber to the airport
assistant: {"transactions":[{"transaction_type":"expense","amount":30,"currency":"USD","category":"transport","name":"uber to the airport","date_text":null,"confidence":"high"}]}

user:      i bought a coffee 50 bucks and a croissant with 100 bucks and my father gave me 200
assistant: {"transactions":[{"transaction_type":"expense","amount":50,"currency":"USD","category":"restaurants","name":"coffee","date_text":null,"confidence":"high"},{"transaction_type":"expense","amount":100,"currency":"USD","category":"restaurants","name":"croissant","date_text":null,"confidence":"high"},{"transaction_type":"income","amount":200,"currency":"USD","category":"transfer_in","name":"father","date_text":null,"confidence":"high"}]}

user:      اشتريت قهوة بعشرين جنيه وحطيت بنزين بمية جنيه
assistant: {"transactions":[{"transaction_type":"expense","amount":20,"currency":"EGP","category":"restaurants","name":"قهوة","date_text":null,"confidence":"high"},{"transaction_type":"expense","amount":100,"currency":"EGP","category":"fuel","name":"بنزين","date_text":null,"confidence":"high"}]}

user:      اشتريت قهوة من ستاربكس بـ ١٨ ريال
assistant: {"transactions":[{"transaction_type":"expense","amount":18,"currency":"SAR","category":"restaurants","name":"ستاربكس","date_text":null,"confidence":"high"}]}

user:      الجو حلو اليوم والحمد لله
assistant: {"transactions":[]}
```

Final user message: the actual transcript.

### 4.5 Post-processing & validation layer (`app/services/postprocess.py`)

Deterministic Python that runs on the LLM output **before** it reaches the client. This layer must have unit tests.

The layer iterates over the LLM's `transactions` array, post-processing **each item
independently** (`postprocess_item`); steps 1,3–6 below run per item. Junk items where both
`transaction_type` and `amount` are null are dropped (they would otherwise become blank
confirm cards). The empty-transcript `failed` check is a single per-utterance step.

1. **Pydantic validation** — parse each transaction object into a Pydantic model mirroring the
   §4.3 item schema. On parse failure (shouldn't happen with constrained decoding, but defend):
   that item is dropped.
2. **Arabic-Indic numeral normalization** — anywhere in the transcript pipeline, map `٠١٢٣٤٥٦٧٨٩` → `0123456789` and `٫` → `.` (apply to the transcript **before** sending to the LLM, and to each `name` after).
3. **Date resolution** — resolve `date_text` → ISO `date` using the request's `client_date` (the device's current local date) as the anchor. Use the `dateparser` library (`pip install dateparser`), which handles Arabic and English relative dates natively:
   ```python
   import dateparser
   resolved = dateparser.parse(
       date_text,
       languages=["ar", "en"],
       settings={"RELATIVE_BASE": client_date_as_datetime, "PREFER_DATES_FROM": "past"},
   )
   ```
   Custom pre-mappings before calling dateparser (it misses some dialect forms): `أمس/امس/البارح/البارحة/امبارح/إمبارح → "yesterday"`, `أول أمس/أول البارح/أول امبارح → "2 days ago"`, `اليوم/النهارده/النهاردة → "today"`. If `date_text` is null or unparseable → default `date = client_date`.
4. **Currency default** — if `currency` is null, fill with the user's `default_currency` (from their profile, default `"SAR"`).
5. **Category guard** — if `category` is null but `transaction_type` is not, set `"other"`.
6. **Status decision** (per item + per utterance):
   - Each surviving item gets `ok` (its `transaction_type` and `amount` are both present) or
     `needs_review` (its `amount` or `transaction_type` is null, or `confidence == "low"`).
   - The top-level utterance status is `failed` if the transcript was empty/garbage or zero
     items survived; `needs_review` if any item needs review; otherwise `ok`.

### 4.6 Evaluation methodology (thesis chapter — build as scripts, not app features)

Create `backend/evaluation/`:

- **Dataset:** `evaluation/dataset.jsonl` — **250+ labeled utterances**: 100 Arabic (mix MSA + Gulf + Egyptian), 100 English, 50 code-switched, plus ~15–20 multi-transaction utterances. Each row: `{"id", "audio_path" (optional), "transcript_gold", "transactions_gold": [ {...all six fields...}, ... ]}` — a **list** of gold transactions (length 1 for single-transaction rows). The team records ~50–100 of these as real audio clips for end-to-end testing; the rest are text-only (extraction-stage evaluation).
- **STT metric:** Word Error Rate via the `jiwer` package, reported per language. Normalize Arabic before WER (strip diacritics, unify alef forms ا/أ/إ/آ, unify ة/ه endings) — note the normalization in the thesis.
- **Extraction metrics:** predicted transactions are aligned to gold by greedy best-match on (type, amount); then per-field **exact-match accuracy** (amount, type, currency, date) and **precision/recall/F1** for category and name (name matched case-insensitively after normalization) are computed over matched pairs, with unmatched gold counted as false-negatives and unmatched predictions as false-positives. A **transaction-count accuracy** (did the model detect the right number of transactions?) is also reported. Report two conditions: (a) gold transcript → extraction (isolates the LLM), (b) audio → STT → extraction (end-to-end).
- **Scripts:** `evaluation/run_stt_eval.py`, `evaluation/run_extraction_eval.py`, each printing a results table and writing `results_*.json`.
- **Ablations worth reporting:** Whisper `base` vs `small` vs `medium`; Qwen 3B vs 7B; with vs without few-shot examples.

---

## 5. Backend Specification

### 5.1 Stack & key packages

| Purpose | Package |
|---|---|
| Framework | `fastapi`, `uvicorn[standard]` |
| ORM / DB | `sqlalchemy>=2.0` (async), `asyncpg`, `alembic` |
| Validation | `pydantic>=2`, `pydantic-settings` |
| Auth | `python-jose[cryptography]` (JWT), `passlib[bcrypt]` |
| STT | `faster-whisper` (+ system `ffmpeg`) |
| Extraction client | `httpx` (async calls to Ollama) |
| Dates | `dateparser` |
| Uploads | `python-multipart` |
| Tests | `pytest`, `pytest-asyncio`, `httpx` test client |

### 5.2 API endpoints

All routes prefixed `/api/v1`. 🔒 = requires `Authorization: Bearer <access_token>`.

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | — | Body: `{email, password, display_name, default_currency?}`. Creates user. Returns tokens + user. |
| POST | `/auth/login` | — | Body: `{email, password}`. Returns `{access_token, refresh_token, user}`. |
| POST | `/auth/refresh` | — | Body: `{refresh_token}`. Returns new token pair. |
| GET | `/users/me` | 🔒 | Current user profile. |
| PATCH | `/users/me` | 🔒 | Update `display_name`, `default_currency`, `locale`. |
| POST | `/transactions/voice` | 🔒 | **The AI endpoint.** Multipart form: `audio` (file, ≤ 30 s / ≤ 5 MB), `client_date` (ISO date), `client_locale` (`ar`/`en`). Returns extraction result (below) — a **list** of transactions. Saves nothing. |
| POST | `/transactions/extract-text` | 🔒 | Same as `/voice` but body `{text, client_date, client_locale}` — typed input, no STT. Same response shape. |
| POST | `/transactions` | 🔒 | Create one transaction. Body = TransactionCreate (below). |
| POST | `/transactions/batch` | 🔒 | Create many transactions atomically. Body `{items: [TransactionCreate]}`. Returns the created list. Backs the multi-transaction "Save All". |
| GET | `/transactions` | 🔒 | List, newest first. Query: `month` (`YYYY-MM`), `category`, `type`, `page`, `page_size` (default 20). |
| GET | `/transactions/{id}` | 🔒 | Single transaction (404 if not owner's). |
| PATCH | `/transactions/{id}` | 🔒 | Partial update. |
| DELETE | `/transactions/{id}` | 🔒 | Delete. Returns 204. |
| GET | `/categories` | 🔒 | Fixed category list with bilingual labels + icons (served from DB seed). |
| GET | `/summary` | 🔒 | Query: `month` (`YYYY-MM`, required). Returns totals + per-category breakdown. |
| GET | `/health` | — | `{status, whisper_loaded, ollama_reachable, db_ok}` — used by Docker healthcheck and the demo. |

**`POST /transactions/voice` — response shape:** `extractions` is a **list** (one entry per
transaction found; empty when none). Each entry carries its own `status`. The top-level
`status` is `failed` if the list is empty, `needs_review` if any entry needs review, else `ok`.

```json
{
  "status": "ok",                       // "ok" | "needs_review" | "failed"
  "transcript": "اشتريت قهوة بعشرين جنيه وحطيت بنزين بمية جنيه",
  "detected_language": "ar",
  "extractions": [
    {
      "status": "ok",
      "transaction_type": "expense",
      "amount": 20.0,
      "currency": "EGP",
      "category": "restaurants",
      "name": "قهوة",
      "date": "2026-06-11",
      "confidence": "high"
    },
    {
      "status": "ok",
      "transaction_type": "expense",
      "amount": 100.0,
      "currency": "EGP",
      "category": "fuel",
      "name": "بنزين",
      "date": "2026-06-11",
      "confidence": "high"
    }
  ],
  "timing_ms": { "stt": 2140, "extraction": 1830, "total": 4210 }
}
```

(`timing_ms` is for the thesis evaluation/demo; cheap to include.)

**`TransactionCreate` body (for `POST /transactions`):**

```json
{
  "transaction_type": "expense",
  "amount": 50.0,
  "currency": "SAR",
  "category": "groceries",
  "name": "كارفور",
  "date": "2026-06-11",
  "note": null,
  "source": "voice",                    // "voice" | "manual"
  "transcript": "دفعت خمسين ريال ..."   // nullable; only when source=voice
}
```

**`GET /summary` response:**

```json
{
  "month": "2026-06",
  "currency": "SAR",
  "total_income": 4500.0,
  "total_expense": 1280.5,
  "balance": 3219.5,
  "by_category": [
    { "category": "groceries", "total": 420.0, "count": 6 },
    { "category": "restaurants", "total": 310.5, "count": 9 }
  ]
}
```

(MVP simplification: summary sums amounts ignoring currency conversion; it reports in the user's default currency and counts all transactions. Note this limitation in code + thesis.)

### 5.3 Auth details

- Access token: JWT HS256, 30 min expiry, `sub` = user id.
- Refresh token: JWT HS256, 30 days, rotated on every refresh; store a `token_version` int on the user row and embed it in refresh tokens so logout-all = increment version.
- Password policy: min 8 chars (don't over-engineer).
- FastAPI dependency `get_current_user` extracts and validates the bearer token; **every** transaction/summary query filters `WHERE user_id = current_user.id`.

### 5.4 Error format

All errors return:

```json
{ "error": { "code": "INVALID_CREDENTIALS", "message": "Email or password is incorrect." } }
```

Codes used by the app: `VALIDATION_ERROR` (422), `INVALID_CREDENTIALS` (401), `TOKEN_EXPIRED` (401), `NOT_FOUND` (404), `AUDIO_TOO_LONG` (413), `AUDIO_UNSUPPORTED` (415), `EXTRACTION_FAILED` (502 — Ollama unreachable etc.), `INTERNAL` (500). Implement via a global exception handler.

---

## 6. Database Schema

```
┌────────────────────┐        ┌──────────────────────────────┐
│ users              │        │ transactions                 │
│────────────────────│ 1    * │──────────────────────────────│
│ id (UUID, PK)      │───────▶│ id (UUID, PK)                │
│ email (unique)     │        │ user_id (UUID, FK→users)     │
│ password_hash      │        │ transaction_type (enum)      │
│ display_name       │        │ amount (NUMERIC(12,2))       │
│ default_currency   │        │ currency (VARCHAR(3))        │
│ locale (ar|en)     │        │ category (VARCHAR, FK→categories.key)
│ token_version (int)│        │ name (VARCHAR(200), null)    │
│ created_at         │        │ date (DATE)                  │
└────────────────────┘        │ note (TEXT, null)            │
                              │ source (enum: voice|manual)  │
┌────────────────────┐        │ transcript (TEXT, null)      │
│ categories (seed)  │ 1    * │ created_at, updated_at       │
│────────────────────│───────▶└──────────────────────────────┘
│ key (PK, varchar)  │
│ label_en           │
│ label_ar           │
│ icon (string)      │
│ kind (expense|income|both)
│ sort_order (int)   │
└────────────────────┘
```

**Notes:**
- `transaction_type`: Postgres enum `('expense','income')`. `source`: enum `('voice','manual')`.
- `amount` is `NUMERIC(12,2)` — never float in the DB.
- Indexes: `transactions(user_id, date DESC)` and `transactions(user_id, category)`.
- `categories` is a **seed table** (Alembic data migration) containing exactly the 17 enum keys from §4.3 with Arabic + English labels and a Material icon name (e.g. `groceries / بقالة / "shopping_cart"`). The app renders labels by current locale.
- Deleting a user cascades to their transactions (`ON DELETE CASCADE`).

---

## 7. Flutter App Specification

### 7.1 Stack & key packages

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod` (v2, with `riverpod_annotation` codegen optional) |
| HTTP | `dio` (+ interceptor for JWT attach & auto-refresh on 401) |
| Audio recording | `record` (records AAC/m4a; request mic permission via `permission_handler`) |
| Secure token storage | `flutter_secure_storage` |
| Localization | `flutter_localizations` + `intl` with ARB files (`app_en.arb`, `app_ar.arb`) |
| Routing | `go_router` |
| Charts (dashboard) | `fl_chart` (one pie/donut chart is enough) |
| Models | `freezed` + `json_serializable` (or plain classes — implementer's choice, but be consistent) |

Audio recording config: AAC-LC in `.m4a`, **16 kHz, mono, ~64 kbps**, max duration 30 s (auto-stop with countdown UI).

### 7.2 Screens

| # | Screen | Contents / behavior |
|---|---|---|
| 1 | **Splash/Gate** | Checks stored tokens → routes to Login or Home. |
| 2 | **Login** | Email + password, link to Register. Error states per §5.4 codes. |
| 3 | **Register** | Email, password, display name, default currency dropdown. |
| 4 | **Home / Record** | The hero screen. Big mic button (tap to record, tap to stop; pulsing animation + elapsed timer while recording). After stop: uploading/processing state ("Transcribing…" → "Analyzing…"), then opens the Confirm sheet. Below the button: current month mini-summary (income/expense/balance) + last 5 transactions. |
| 5 | **Confirm transactions screen** | Shows the transcript (quoted, original language) once at top, then **one editable card per extracted transaction** (an utterance may contain several). Each card: type toggle (expense/income), amount, currency, category picker (icons + localized labels), name, date picker; cards whose `status == needs_review` are tinted amber, and a card can be removed. One **Save All (N)** button → `POST /transactions/batch` (atomic). When no transaction is detected, the empty manual form opens instead ("Enter manually"). |
| 6 | **Transactions list** | Grouped by day, newest first. Filter bar: month selector, category chips, type toggle. Tap → edit (reuses confirm-sheet form). Swipe → delete with confirmation. |
| 7 | **Dashboard** | Month selector; three stat cards (income/expense/balance); donut chart of expenses by category; per-category list. Data from `GET /summary`. |
| 8 | **Settings** | Language switch (ar/en, applies instantly + persists via `PATCH /users/me`), default currency, display name, logout. |

Navigation: bottom nav bar with 3 tabs — **Home (record)**, **Transactions**, **Dashboard** — plus settings icon in the app bar.

### 7.3 Localization & RTL rules

- Wrap `MaterialApp.router` with `locale` from a Riverpod settings provider; `supportedLocales: [Locale('en'), Locale('ar')]`.
- **Never hardcode user-facing strings** — everything through ARB keys.
- RTL comes free from `Directionality` when locale is `ar`; verify the mic screen, list swipe actions, and chart legends mirror correctly.
- Numbers/dates display: use `intl` `NumberFormat.currency` and `DateFormat.yMMMd` with the active locale (Arabic month names etc.).
- Category labels come from the API (`label_ar`/`label_en`) — display by locale.

### 7.4 State architecture (Riverpod)

- `authControllerProvider` — login/register/logout, token persistence, exposes `AuthState (unauthenticated | authenticated(User))`.
- `dioProvider` — Dio configured with base URL + auth interceptor (reads tokens, refreshes on 401 once, then logs out).
- `recordingControllerProvider` — state machine: `idle → recording(elapsed) → uploading → processing → result(VoiceExtractionResult) | error`.
- `transactionsProvider(filter)` — paginated list, invalidated after create/edit/delete.
- `summaryProvider(month)` — dashboard data.
- `settingsProvider` — locale + currency, persisted locally and synced to API.

---

## 8. Folder Structure

Monorepo layout:

```
MiPay/
├── MIPAY_SPEC.md                  # this document
├── docker-compose.yml
├── README.md                      # setup & run instructions
├── backend/
│   ├── Dockerfile                 # python:3.11-slim + ffmpeg
│   ├── pyproject.toml             # or requirements.txt
│   ├── alembic.ini
│   ├── alembic/
│   │   └── versions/              # incl. category seed data migration
│   ├── app/
│   │   ├── main.py                # FastAPI app, lifespan (load Whisper), routers, exception handlers
│   │   ├── core/
│   │   │   ├── config.py          # pydantic-settings: env vars (§9.2)
│   │   │   ├── security.py        # JWT create/verify, bcrypt hash
│   │   │   └── deps.py            # get_db, get_current_user dependencies
│   │   ├── db/
│   │   │   ├── session.py         # async engine + sessionmaker
│   │   │   └── base.py
│   │   ├── models/                # SQLAlchemy models
│   │   │   ├── user.py
│   │   │   ├── transaction.py
│   │   │   └── category.py
│   │   ├── schemas/               # Pydantic request/response models
│   │   │   ├── auth.py
│   │   │   ├── user.py
│   │   │   ├── transaction.py     # TransactionCreate/Read/Update, VoiceExtractionResult
│   │   │   └── summary.py
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── router.py      # aggregates sub-routers under /api/v1
│   │   │       ├── auth.py
│   │   │       ├── users.py
│   │   │       ├── transactions.py  # incl. POST /transactions/voice
│   │   │       ├── categories.py
│   │   │       └── summary.py
│   │   └── services/
│   │       ├── stt.py             # faster-whisper singleton + transcribe()
│   │       ├── extraction.py      # Ollama client, schema (§4.3), prompt (§4.4)
│   │       ├── postprocess.py     # §4.5: numerals, dateparser, validation, status
│   │       ├── audio.py           # ffmpeg convert, duration/size checks, temp-file cleanup
│   │       └── voice_pipeline.py  # orchestrates: audio→stt→extraction→postprocess
│   ├── evaluation/
│   │   ├── dataset.jsonl
│   │   ├── run_stt_eval.py
│   │   ├── run_extraction_eval.py
│   │   └── normalize_ar.py        # Arabic text normalization for WER
│   └── tests/
│       ├── test_auth.py
│       ├── test_transactions.py
│       ├── test_postprocess.py    # the most important test file
│       └── conftest.py
└── mipay_app/                     # Flutter project
    ├── pubspec.yaml
    ├── l10n.yaml
    └── lib/
        ├── main.dart
        ├── app.dart               # MaterialApp.router, theme, locale wiring
        ├── core/
        │   ├── api/
        │   │   ├── dio_client.dart      # base URL, auth interceptor
        │   │   └── api_exceptions.dart  # maps §5.4 error codes
        │   ├── router/app_router.dart   # go_router config
        │   ├── theme/app_theme.dart
        │   └── utils/formatters.dart    # currency/date intl helpers
        ├── l10n/
        │   ├── app_en.arb
        │   └── app_ar.arb
        └── features/
            ├── auth/
            │   ├── data/auth_repository.dart
            │   ├── providers/auth_controller.dart
            │   └── ui/ (login_screen.dart, register_screen.dart)
            ├── record/
            │   ├── data/voice_repository.dart     # multipart upload
            │   ├── providers/recording_controller.dart
            │   └── ui/ (home_screen.dart, confirm_sheet.dart, mic_button.dart)
            ├── transactions/
            │   ├── data/transactions_repository.dart
            │   ├── models/transaction.dart
            │   ├── providers/transactions_provider.dart
            │   └── ui/ (transactions_screen.dart, transaction_form.dart, transaction_tile.dart)
            ├── dashboard/
            │   ├── data/summary_repository.dart
            │   ├── providers/summary_provider.dart
            │   └── ui/dashboard_screen.dart
            └── settings/
                ├── providers/settings_provider.dart
                └── ui/settings_screen.dart
```

---

## 9. Dev Environment & Deployment

### 9.1 docker-compose.yml (plan)

Three services:

```yaml
services:
  postgres:
    image: postgres:16
    environment: { POSTGRES_USER: mipay, POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}, POSTGRES_DB: mipay }
    volumes: [pgdata:/var/lib/postgresql/data]
    ports: ["5432:5432"]

  ollama:
    image: ollama/ollama:latest
    volumes: [ollama:/root/.ollama]
    ports: ["11434:11434"]
    # GPU (optional): uncomment deploy.resources.reservations.devices for nvidia

  api:
    build: ./backend
    depends_on: [postgres, ollama]
    env_file: .env
    ports: ["8000:8000"]
    volumes: [whisper_models:/root/.cache/huggingface]   # cache Whisper weights

volumes: { pgdata: {}, ollama: {}, whisper_models: {} }
```

One-time provisioning after first `docker compose up`:
`docker compose exec ollama ollama pull qwen2.5:7b-instruct` and `docker compose exec api alembic upgrade head`. Put both in a `make setup` / `scripts/setup.sh`.

For Flutter dev against a local backend on Android emulator, base URL is `http://10.0.2.2:8000` (document in README).

### 9.2 Environment variables (`.env`)

| Var | Default | Notes |
|---|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://mipay:...@postgres:5432/mipay` | |
| `JWT_SECRET` | — (required) | generate 32+ random bytes |
| `ACCESS_TOKEN_MINUTES` | `30` | |
| `REFRESH_TOKEN_DAYS` | `30` | |
| `WHISPER_MODEL` | `small` | `base`/`small`/`medium` |
| `WHISPER_COMPUTE_TYPE` | `int8` | `float16` on GPU |
| `OLLAMA_URL` | `http://ollama:11434` | |
| `EXTRACTION_MODEL` | `qwen2.5:7b-instruct` | `qwen2.5:3b-instruct` on weak hardware |
| `MAX_AUDIO_SECONDS` | `30` | |
| `MAX_AUDIO_BYTES` | `5242880` | 5 MB |

### 9.3 Hardware requirements (document in README)

| Setup | RAM | Notes |
|---|---|---|
| Minimum (CPU) | 12 GB | Whisper `small` (int8 ≈ 1 GB) + Qwen 7B (Q4 ≈ 5 GB) + Postgres + OS. Voice round-trip ≈ 6–10 s. |
| Comfortable | 16 GB | Same models, headroom. |
| Low-spec fallback | 8 GB | `WHISPER_MODEL=base` + `EXTRACTION_MODEL=qwen2.5:3b-instruct`; reduced accuracy. |
| GPU (optional) | ≥ 6 GB VRAM | Whisper `medium` float16 + faster Qwen inference; round-trip ≈ 2–4 s. |

---

## 10. Implementation Milestones

Build in this order; each phase has acceptance criteria. (Sized for a 1–2 person graduation project.)

| Phase | Deliverable | Acceptance criteria |
|---|---|---|
| **0. Scaffold** | Monorepo, docker-compose with postgres+ollama, FastAPI hello-world, Flutter blank app with router/theme/l10n wiring, `GET /health` | `docker compose up` works; health endpoint reports db_ok + ollama_reachable |
| **1. Auth + DB** | User model, register/login/refresh, JWT deps, Alembic baseline + category seed, Flutter login/register screens with token storage | Can register+login from the app; protected route rejects bad tokens; tests for auth pass |
| **2. Transactions CRUD** | Transaction model + endpoints, categories endpoint, Flutter manual entry form, transactions list with filters | Full manual CRUD from the app, per-user isolation verified by test |
| **3. STT service** | `stt.py` + `audio.py`, Whisper loaded at startup, a temporary `POST /debug/transcribe` endpoint | Arabic and English clips transcribe correctly; audio deleted after processing |
| **4. Extraction pipeline** | `extraction.py` + `postprocess.py` + `voice_pipeline.py`, `POST /transactions/voice` complete; unit tests for postprocess (numerals, dates, status logic) | The 6 few-shot example sentences (§4.4) round-trip correctly end-to-end; `needs_review` path works |
| **5. Voice UX in Flutter** | Mic button + recording state machine, upload, confirm sheet, save flow | Demo flow: speak Arabic sentence → confirm → appears in list. Same for English and mixed |
| **6. Dashboard + settings** | Summary endpoint + dashboard screen, settings (language switch with RTL, currency), polish empty/error states | Language switch flips entire app incl. RTL instantly; dashboard matches list data |
| **7. Evaluation (thesis)** | 250-row dataset, eval scripts, results tables, ablations (Whisper sizes, Qwen 3B vs 7B, few-shot vs zero-shot) | Reproducible `results_*.json` + tables ready to paste into thesis |
| **8. Hardening & demo prep** | Error-code coverage in app, README with full setup, seed demo account script | Fresh-machine setup from README succeeds; rehearsed 5-minute demo path has no crashes |

---

## 11. Risks & Future Work

### Risks & mitigations

| Risk | Mitigation |
|---|---|
| Whisper struggles with heavy dialect / noisy audio | VAD filter on; `medium` model if GPU available; the confirm-sheet edit step means errors are recoverable, never silently saved |
| Qwen mislabels category/currency on rare phrasings | Constrained decoding limits damage to wrong-enum-choice (never invalid JSON); few-shots cover common dialect patterns; `needs_review` path catches low confidence |
| Latency on weak CPU feels slow in the demo | Show staged progress text ("Transcribing… / Analyzing…"); demo on the comfortable spec; report timing honestly in thesis |
| Ollama container down | `EXTRACTION_FAILED` error → app offers manual entry; health endpoint surfaces it early |
| Mixed-language clip detected as the wrong dominant language | Acceptable: extraction LLM is bilingual and works off the transcript regardless of detected language tag |

### Future work (thesis "future directions" section)

- **Fine-tuning:** collect the confirmed (user-corrected) transactions as training data and fine-tune a small model (e.g. Qwen 3B LoRA or a multilingual BERT NER head) on the extraction task — the natural academic extension.
- **On-device inference:** whisper.cpp + a 1–3B quantized LLM on-device for full offline mode.
- **Streaming UX:** background job queue + push when processing finishes; live partial transcripts.
- **Budgets, recurring detection, receipt OCR, bank-SMS parsing** as product extensions.
- **Dialect-specific evaluation:** expand the dataset per dialect and report per-dialect WER/F1.

---

*End of specification. Implement top-down: §10 defines the order, §§4–8 define the details. When in doubt, prefer the simplest implementation that satisfies the stated requirement.*
