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

---

## 4. STT upgrade path: better Arabic & true code-switching (research notes — NOT scheduled)

> Status: **text only — do not implement.** Added 2026-06-12 after Phase 3/4 testing.
> Current baseline: `faster-whisper small`, `language=None`, which detects ONE dominant
> language per clip and transcribes embedded foreign words "best effort" (§4.1). Two known
> weaknesses: (a) heavy-dialect Arabic accuracy, (b) genuinely mixed ar↔en utterances where
> the wrong dominant language wins.

### 4.1 Cheapest upgrades first (no new code — env var only)

| Option | What changes | Cost | Expected gain |
|---|---|---|---|
| `WHISPER_MODEL=medium` | nothing else | ~2.5× slower on CPU, ~3 GB RAM | Noticeably better MSA + Gulf Arabic; already the spec's documented fallback |
| `WHISPER_MODEL=large-v3` | nothing else | needs GPU realistically (≥10 GB VRAM fp16; int8 CPU is painfully slow) | Best open-weights Arabic WER in the Whisper family; **also measurably better at code-switching** — the dominant-language problem shrinks |
| `WHISPER_MODEL=large-v3-turbo` | nothing else | ~809M params; usable on 6 GB GPU, tolerable on strong CPU | ~large-v3 quality at ~6× the speed; best quality/latency ratio if any GPU is available |

These slot directly into the existing ablation table (§4.6 of the spec): adding a
`small vs medium vs large-v3-turbo` row to the thesis results is nearly free.

### 4.2 Arabic-specialised models (self-hosted, replaces/augments Whisper)

- **Dialect fine-tuned Whisper checkpoints (Hugging Face)** — community/academic Whisper
  fine-tunes trained on Common Voice Arabic, MGB-2 (Aljazeera MSA), MGB-3/MGB-5 (Egyptian),
  and QASR. Any HF Whisper checkpoint converts to faster-whisper format with one
  `ct2-transformers-converter` command, so the existing `stt.py` works unchanged —
  only the model path env var changes. *This is the lowest-friction "better Arabic" route.*
- **Meta SeamlessM4T v2** — strong Arabic ASR, self-hostable, but a different inference
  stack (no faster-whisper/CTranslate2 path) → real integration work + more RAM.
- **Meta MMS (Massively Multilingual Speech)** — covers many Arabic varieties; generally
  strong for low-resource languages but does not beat Whisper large on MSA; niche option.
- ❌ **NVIDIA Canary/Parakeet** — excellent WER but no Arabic support; not applicable.

### 4.3 True code-switching (ar+en in the same sentence)

The honest framing for the thesis: code-switched ASR is an open research problem, and
Whisper's single-language-token design is the root limitation. Options, in increasing effort:

1. **Upgrade to large-v3/turbo** (§4.1) — partial fix, zero work. Larger Whisper models
   transcribe embedded English inside Arabic sentences much more reliably.
2. **Segment-level two-pass decoding** (engineering mitigation, no new model): split the
   clip on VAD pauses, run language detection per segment, transcribe each segment with its
   own language token, stitch transcripts. Helps "sentence in Arabic, sentence in English";
   does NOT help intra-sentence mixing. ~1 day of work in `stt.py`.
3. **Fine-tune Whisper on code-switched corpora** — the research-grade answer and the natural
   thesis extension (pairs with the existing "fine-tuning" future-work item). Public datasets:
   - **ArzEn / ArzEn-ST** — Egyptian Arabic–English code-switched speech (the standard CS benchmark)
   - **Mixat** — Emirati Arabic–English code-switched dataset
   - **QASR** — 2,000 h Aljazeera; contains natural MSA-with-English-terms segments
   A LoRA fine-tune of `whisper-small`/`medium` on ArzEn+Mixat, evaluated with per-language
   WER + code-switch-point accuracy, would be a publishable thesis chapter on its own.
4. ❌ **Cloud ASR with native CS support** (ElevenLabs Scribe, Google Chirp 2, Azure STT) —
   several handle mixed ar/en well, but using them breaks the project's core self-hosted /
   privacy / zero-per-request-cost thesis claims (§1 of the spec). Mention as comparison
   baseline in the thesis at most; do not ship.

### 4.4 Recommendation (when this is picked up)

Ordered plan: **(1)** add `medium` + `large-v3-turbo` to the §4.6 ablation and pick by
measured ar-WER on the project's own 250-utterance dataset → **(2)** if dialect WER is still
the bottleneck, swap in a dialect fine-tuned Whisper checkpoint via ct2 conversion (no code
change) → **(3)** if code-switching specifically is the bottleneck and thesis time allows,
the ArzEn/Mixat LoRA fine-tune is the highest-value academic contribution available here.
