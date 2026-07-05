# MiPay Thesis — Figure Guide

This file describes every image the document expects. Create or source each file,
save it under `figures/` with the **exact filename** shown, and it will appear
automatically the next time you compile. Until a file exists, the document shows a
labelled placeholder box in its place (so it always compiles).

**Format:** All content figures are `.jpg`. The two logos are `.png`.
**Tip:** Diagrams (architecture, DFD, ER, UML) are cleanest when drawn in
draw.io / diagrams.net, Lucidchart, or PlantUML and exported to JPG at ≥ 150 DPI.
Screenshots should be real captures from the running Flutter app.

---

## 1. Logos (title page)

| File | What it should show |
|---|---|
| `figures/faculty_logo.png` | Your faculty/college logo, transparent or white background. |
| `figures/university_logo.png` | Your university logo, transparent or white background. |

---

## 2. Chapter 1 — Introduction

### ~~`figures/friction_comparison.jpg`~~ — done, no image file needed
This figure is now drawn directly in LaTeX (TikZ) inside `chapters/chapter1.tex`
— a two-panel comparison: 5 numbered form-field steps (Manual Entry) vs. a
single spoken sentence → mic → ready transaction (Voice Input). It compiles as
a vector graphic, so there is nothing to source or drop into `figures/` for
this one. If you'd rather replace it with a designed illustration later, just
swap that `tikzpicture` block back for an `\includegraphics{figures/friction_comparison.jpg}`
call and source a JPG matching the description that used to be here.

---

## 3. Chapter 3 — System Analysis (diagrams)

### `figures/context_diagram.jpg`
A **context (level-0) diagram**. Center bubble = "MiPay System". One external
actor on the left = "User" with bidirectional arrows (voice/text in, results out).
Inside a dashed "deployment boundary" rectangle, show three internal subsystems
(Speech-to-Text, LLM Extraction, Database). **Important:** draw NO arrows leaving
the boundary to any third party — the absence is the point (privacy).

### `figures/dfd_level0.jpg`
**Level-0 data-flow diagram.** Process "1.0 MiPay" in the middle; external entity
"User"; data stores "D1 Transactions" and "D2 Categories". Flows: voice/text
request in; extraction result out; save → D1; read categories from D2.

### `figures/dfd_level1.jpg`
**Level-1 DFD expanding the voice pipeline** into sub-processes in order:
(1.1) Convert audio → 16 kHz WAV; (1.2) Transcribe (Whisper); (1.3) Normalize
numerals; (1.4) Constrained extraction (LLM); (1.5) Post-process (date/currency/
status). Show a transient "audio temp file" store that is **deleted** after 1.2
(mark it with a "deleted ✕" note), and the persistent transaction store written
only by the later save.

### `figures/er_diagram.jpg`
**Entity-Relationship diagram** with three entities:
- `users` (id PK, email, password_hash, display_name, default_currency, locale,
  token_version, created_at)
- `transactions` (id PK, user_id FK, transaction_type, amount, currency,
  category FK, name, date, note, source, transcript, created_at, updated_at)
- `categories` (key PK, label_en, label_ar, icon, kind, sort_order)
Relationships: users 1—∞ transactions (cascade delete); categories 1—∞
transactions. Use crow's-foot notation.

### `figures/use_case_diagram.jpg`
**UML use-case diagram.** Actor "Authenticated User" (stick figure) connected to
ovals: Register/Login, Record Voice Transaction, Type Text Transaction, Enter
Manually, Confirm & Edit, List & Filter, Edit/Delete, View Dashboard, Change
Settings. The three input ovals have `<<include>>` dashed arrows to a shared
"Confirm & Save" oval. A secondary actor "AI Pipeline" connects to the voice/text
ovals.

### `figures/activity_voice.jpg`
**UML activity diagram** for the voice flow. Start → Record → Stop → Upload →
Transcribe → Extract → Post-process → **decision diamond on status**:
- `ok`/`needs_review` → show confirmation cards → user edits → Save → end.
- `failed` → open manual form → end.
Make clear (e.g., a note) that the database write happens **only** on the Save
action.

### `figures/class_diagram.jpg`
**UML class diagram** of the backend. Classes/boxes:
- Models: `User`, `Transaction`, `Category` (with key attributes).
- Schemas: `TransactionCreate`, `VoiceExtractionResult`.
- Services: `STTService` (+transcribe), `extraction` (+extract), `postprocess`
  (+postprocess_many, +resolve_date), `voice_pipeline` (+process_audio,
  +process_text, −_extract_and_post).
Show `voice_pipeline` depending on `STTService`, `extraction`, `postprocess`.

### `figures/sequence_voice.jpg`
**UML sequence diagram**, lifelines: User, Flutter App, FastAPI, Whisper, Ollama,
Postgres. Messages: tap+speak; POST /transactions/voice (audio, client_date);
transcribe→transcript; extract→raw JSON; post-process; return result (saves
nothing); user confirms; POST /transactions/batch; INSERT; 201 created.
Annotate that the voice endpoint is **stateless** (no DB write).

### `figures/sequence_auth.jpg`
**UML sequence diagram** for token refresh: App → API request with access token →
401 → interceptor → POST /auth/refresh → new tokens → retry original request →
200. Show the "logout" branch if refresh also fails.

---

## 4. Chapter 4 — Implementation

### `figures/system_architecture.jpg`
**High-level architecture.** Three containers (Docker Compose): `api` (FastAPI +
Whisper in-process + ffmpeg), `postgres`, `ollama` (Qwen2.5-7B). Flutter phone on
the left talks REST/JSON to `api`; `api` → HTTP → `ollama`, and `api` → SQL →
`postgres`. Mark volumes (pgdata, ollama models, whisper cache). Show the whole
backend inside one "host machine (16 GB, CPU-only)" box.

### `figures/ai_pipeline.jpg`
**Detailed AI pipeline** (the project's core figure). Horizontal flow:
Audio → [ffmpeg 16 kHz WAV] → [faster-whisper STT] → transcript →
[numeral normalize] → [Qwen2.5-7B + JSON-schema constrained decoding] →
raw transactions[] → [deterministic post-process: date resolve, currency default,
status] → result. Add a dashed branch showing **text mode** entering at the
"numeral normalize" step (skipping STT). Colour-code the "fuzzy LLM" stage vs the
"deterministic code" stages.

---

## 5. Appendix A — UI Gallery (real app screenshots)

Capture these from the running app (use an emulator or device; PNG export from the
emulator is fine, just save as `.jpg`). Portrait phone aspect ratio.

| File | Screen |
|---|---|
| `figures/ui_login.jpg` | Login screen (email, password, link to register). |
| `figures/ui_home_record.jpg` | Home/Record screen: big mic button, "type instead" affordance, monthly mini-summary, last transactions. |
| `figures/ui_confirm.jpg` | Confirmation screen: transcript quoted at top, one editable card per extracted transaction, a `needs_review` card tinted amber, "Save All (N)" button. Ideally a **multi-transaction** example. |
| `figures/ui_transactions.jpg` | Transactions list grouped by day, with month/category/type filter bar. |
| `figures/ui_dashboard.jpg` | Dashboard: income/expense/balance stat cards + category donut chart. |
| `figures/ui_settings_ar.jpg` | Settings screen shown **in Arabic (RTL)** to demonstrate localization (language switch, default currency, logout). |

---

## How the placeholder fallback works
`settings/commands.tex` redefines `\includegraphics` so that a missing file
renders as a boxed `[ missing figure ]` label instead of throwing an error. Drop
the real file in `figures/` with the matching name and recompile — no LaTeX edits
needed.
