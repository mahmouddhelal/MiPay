# MiPay — Feature Additions & Input Modes

> Companion to [MIPAY_SPEC.md](MIPAY_SPEC.md). This file tracks features decided **after** the
> original spec was frozen. Anything here overrides/extends the spec; the spec stays untouched
> as the baseline document.

---

## 1. Three input modes (decided 2026-06-12)

The app must support three ways to add a transaction, from most-assisted to fully manual:

| Mode | Pipeline | Status in spec |
|---|---|---|
| **A. Voice** | record audio → Whisper STT → LLM extraction → confirm sheet → save | ✅ Already specced (§3.2, the core flow) |
| **B. Typed text** | user types a sentence ("paid 50 for groceries at Carrefour") → **skip STT** → LLM extraction → confirm sheet → save | 🆕 **NEW — defined below** |
| **C. Manual** | user fills the transaction form directly → save (no AI at all) | ✅ Already specced (FR-09, Phase 2 form) |

All three converge on the same confirm/edit step and the same `POST /transactions` save —
the human-in-the-loop checkpoint is identical regardless of input mode.

---

## 2. Mode B spec: text extraction endpoint

### 2.1 Backend

New endpoint (add alongside `POST /transactions/voice`):

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/transactions/extract-text` | 🔒 | JSON body: `{text, client_date, client_locale}`. Runs the **same** extraction pipeline as voice, minus STT. Saves nothing. |

**Request body:**

```json
{
  "text": "دفعت خمسين ريال على البقالة من كارفور أمس",
  "client_date": "2026-06-12",
  "client_locale": "ar"
}
```

**Response shape:** identical to `POST /transactions/voice` (§5.2), except:
- `transcript` echoes the submitted text (after Arabic-numeral normalization)
- `detected_language` is `null` (no Whisper language detection — not needed, the LLM is bilingual)
- `timing_ms` has no `stt` key: `{ "extraction": 1830, "total": 1845 }`

**Validation:** `text` required, 1–500 chars after trim. Empty/whitespace-only → 422 `VALIDATION_ERROR`.

**Implementation note:** this is nearly free once Phase 4 is done — `voice_pipeline.py` should be
structured so the STT step is separable:

```
voice_pipeline.process_audio(file, client_date, user)   # audio → stt → _extract_and_post
voice_pipeline.process_text(text, client_date, user)    # ───────────→ _extract_and_post
```

Both share `_extract_and_post(transcript, client_date, user)` = normalize numerals → Ollama
extraction → postprocess → status decision. **Build it this way in Phase 4 from the start.**

### 2.2 Flutter

On the **Home/Record screen**, alongside the big mic button:

- A text field (or a "type instead" affordance under the mic) where the user can type/paste a sentence
  in Arabic, English, or mixed.
- Submitting it calls `POST /transactions/extract-text`, shows the same "Analyzing…" state
  (no "Transcribing…" step), then opens the **same Confirm sheet** used by voice.
- The recording state machine gains one entry path:
  `idle → analyzing(text) → result | error` (skips `recording`/`uploading`).
- Keyboard "send" action submits; field clears after the confirm sheet is dismissed.

Manual mode (C) entry point: a "+" button on the Transactions list screen (already planned in
Phase 2) **and** an "Enter manually" option near the mic for discoverability.

### 2.3 Phase placement

- Backend endpoint: **Phase 4** (extraction pipeline) — add `process_text` + the route + tests
  in the same phase; the few-shot sentences from §4.4 double as test inputs with no audio needed.
  This also gives you a way to demo/eval extraction **before** STT is wired (Phase 3 and 4 become
  independently demoable).
- Flutter text input: **Phase 5** (voice UX) — same screen, same confirm sheet.

### 2.4 Thesis angle

Mode B is also useful academically:
- It isolates the extraction stage for live demos (no mic/noise variables).
- It maps directly to evaluation condition (a) in §4.6 — gold transcript → extraction.
- It's an accessibility story (noisy environments, privacy in public, mute users).

---

## 3. Future feature candidates (not scheduled)

Parked ideas — do **not** build without explicit decision:

- Edit transcript before extraction (when STT got words slightly wrong, let the user fix the
  transcript text and re-run extraction — combines A + B).
- Quick-add templates ("same as last time" / repeat a frequent transaction).
- Multiple transactions in one utterance ("paid 50 for fuel and 30 for lunch") — currently
  out of scope; LLM schema is single-object.
- Photo/receipt OCR input (already in spec §11 future work).
