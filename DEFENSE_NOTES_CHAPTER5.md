# Chapter 5 Defense Notes — Read tonight, keep nearby tomorrow

Your results are stronger than they feel right now. The pattern below is exactly
what a good empirical evaluation is supposed to produce: most things work very
well, the things that don't have a *specific, named, explainable* cause, and
you already know the fix. That's a better story than "everything is 95%" with
no analysis behind it.

## The one-sentence version, if you only remember one thing

> "Four of six fields hit 96–100% accuracy, well above target. The two that
> fell short — amount and category — didn't fail randomly; we traced both to a
> specific, fixable cause, which is itself a contribution of the evaluation."

## The numbers, framed for a room

| Field | Result | Target | Read this as |
|---|---|---|---|
| `transaction_type` | **99.3%** | ≥85% | exceeded |
| `date` | **99.3%** | — | excellent |
| `currency` | **96.6%** | — | excellent |
| transaction-count (multi-tx split) | **100%** | — | perfect |
| `amount` | 65.6% | ≥90% | **explained below** |
| `category` (F1) | 0.554 | ≥0.80 | **explained below** |

## Root cause 1 — amount: this is a known, narrow linguistic failure, not general unreliability

- English amount accuracy: **99.2%**. Arabic: **37.3%**. Code-switched: 53.6%.
- The gap is entirely in one place: Qwen2.5-7B mis-parses Egyptian **compound
  number words** — e.g. "تلتمية وعشرين" (300+20=320) gets read as just 20; it
  drops the hundreds word. "ميتين" (200, dual form) sometimes gets read as
  "ميه" (100, singular).
- Simple numbers, digits, and English amounts are essentially unaffected.
- **If asked "is the system unreliable?"**: No — it's reliable everywhere
  except one specific, well-defined construction in spoken Arabic numerals,
  which is a solved problem in NLP (deterministic numeral parsing) and is
  exactly why the human confirmation step exists before anything saves.

## Root cause 2 — category: a prompt-coverage gap, not a model weakness

- Errors concentrate almost entirely on 6 of 17 categories (shopping,
  business, gifts_donations, education, entertainment, personal_care) — every
  time, misclassified as "other."
- Why: the system prompt gives worked keyword examples for 9 categories
  (groceries, restaurants, fuel, transport, bills, rent, health, salary,
  transfer_in) but **zero examples** for those other 6.
- **If asked "how would you fix this?"**: Add one example per missing
  category to the prompt — a ~10-line, no-retraining change. This is
  literally in Chapter 6 as the first, cheapest, highest-confidence next step.

## Other numbers you'll be asked about

- **WER (Arabic 76%, n=4 clips)**: this is a tiny pilot (6 clips total), not a
  statistically powered benchmark — say so directly, it's already stated in
  the thesis. Two of the four Arabic clips were the team's own rough retakes
  recorded informally (one was even mis-detected as Japanese). This reflects
  real-world dialectal ASR difficulty, a documented open problem, not a bug.
- **English WER (17.4%, n=2)**: close to the 12% target; small n, don't
  over-claim precision here either.
- **"Why only 6 audio clips?"**: honest answer — time/resource constraint this
  pass; the corpus was designed for 50–100, and scaling the audio pilot is
  named explicitly in Chapter 6 future work. Don't dodge this, just say it
  plainly — reviewers respect a clearly-scoped limitation far more than a
  hidden one.
- **The `name` field looks low (28%) but is misleading**: 81% of the "errors"
  are cases where the gold label was deliberately left blank but the model
  still extracted a reasonable value anyway — that's a scoring-convention
  artifact, not a real failure. This is already written into the thesis
  discussion; if asked, just repeat it.
- **Ablation tables (Whisper size / LLM size / few-shot) are placeholders**:
  say plainly these require additional container restarts and re-runs that
  didn't fit in this pass, and are the immediate next step. This is a
  scope/time statement, not a hidden gap — it's stated as such in the chapter.

## "The app shows more categories / EGP by default — the thesis says 17 / SAR?"

This will come up if anyone demos the live app alongside the PDF. Answer it
head-on, don't dodge:

- The evaluation in Chapter 5 was run against the system as it stood at
  evaluation time: **17 categories, SAR-default**. That's the honest,
  documented snapshot the numbers describe.
- Since then the system was extended for the Egyptian market: **29
  categories, EGP-default** — this is what the live app shows, and Chapter 4
  documents the current 29-category taxonomy and EGP default directly.
- Chapter 5 has an explicit "Note on system version" saying exactly this, and
  Chapter 6 lists re-running the evaluation against the 29-category schema as
  an immediate next step, right alongside the ablation studies.
- **The takeaway, if pressed**: the two root causes found (Arabic
  compound-number parsing, prompt-example coverage gaps) are properties of
  the *approach*, not the old category count — they'd be expected to still
  apply, likely to a similar or larger degree with 12 more categories added to
  the "coverage gap" problem, which is precisely why closing that gap is
  called out as the top-priority next step.

## If someone pushes "so is the product actually usable?"

Yes — and this is the actual thesis argument, not a deflection: **every
extraction is a human-confirmed suggestion, never an auto-save.** A wrong
Arabic amount is a one-tap correction on the confirmation screen, not a
corrupted record. The measured accuracy numbers describe *how often the user
edits a field*, not *whether the data is trustworthy*. That's why the
two-step save / confirmation UX is architecturally central, not an
afterthought.

## Tone for tomorrow

Don't apologize for the 65%/category numbers. State them, state the cause,
state the fix, move on. The moment you sound uncertain about a number you can
actually explain, it reads as a bigger problem than it is. You ran a real
274-utterance + 6-clip evaluation against a live system, found a genuine,
specific, three-cause failure pattern, and can name the fix for each one —
that's the actual bar for this kind of chapter, and you've cleared it.
