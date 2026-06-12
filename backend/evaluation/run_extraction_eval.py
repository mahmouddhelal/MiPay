#!/usr/bin/env python3
"""
Extraction Evaluation — per-field exact-match accuracy + P/R/F1.

Two evaluation conditions (§4.6):
  (a) gold  — gold transcript → POST /transactions/extract-text
              (isolates the LLM; no STT noise)
  (b) e2e   — audio file → POST /transactions/voice
              (full pipeline; only rows with resolvable audio_path)

Usage
-----
    # From repo root, containers running:
    EVAL_EMAIL=test@example.com EVAL_PASSWORD=secret \\
    BASE_URL=http://localhost:8000/api/v1 \\
    python backend/evaluation/run_extraction_eval.py

    # Run only condition (a):
    ... python run_extraction_eval.py --condition gold

    # Ablate Qwen 3B vs 7B (restart API between runs with EXTRACTION_MODEL changed):
    ... python run_extraction_eval.py --models qwen2.5:3b-instruct,qwen2.5:7b-instruct

    # Zero-shot ablation (set few_shot=false in extraction.py, restart API):
    ... python run_extraction_eval.py --label zero_shot

Prerequisites
-------------
- Containers running and user account created (EVAL_EMAIL / EVAL_PASSWORD).
- For condition (b): audio files in evaluation/audio/.

Environment variables
---------------------
BASE_URL       (default: http://localhost:8000/api/v1)
EVAL_EMAIL     Login email for the evaluation account (required)
EVAL_PASSWORD  Password (required)
EVAL_DATE      Fixed client_date sent to the API (default: 2026-06-15)
EVAL_LOCALE    client_locale sent with every request (default: ar)

Output
------
Prints per-field accuracy table → results_extraction.json
"""

import argparse
import json
import os
import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional

try:
    import httpx
except ImportError:
    sys.exit("httpx not found. Run: pip install httpx")

# ── Configuration ─────────────────────────────────────────────────────────────

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000/api/v1")
EVAL_DATE = os.getenv("EVAL_DATE", "2026-06-15")
EVAL_LOCALE = os.getenv("EVAL_LOCALE", "ar")
DATASET_PATH = Path(__file__).parent / "dataset.jsonl"
RESULTS_PATH = Path(__file__).parent / "results_extraction.json"
TIMEOUT_S = 60

# Fields evaluated with exact-match accuracy
EXACT_FIELDS = ["transaction_type", "amount", "currency", "date"]
# Fields evaluated with exact-match + per-class P/R/F1
CLASS_FIELDS = ["category", "name"]

# Amount tolerance: accept if |pred - gold| / gold < AMOUNT_TOL
AMOUNT_TOL = 0.01  # 1 %

# ── Auth ──────────────────────────────────────────────────────────────────────


def login(email: str, password: str, client: httpx.Client) -> str:
    r = client.post(
        f"{BASE_URL}/auth/login",
        json={"email": email, "password": password},
        timeout=15,
    )
    if r.status_code != 200:
        sys.exit(f"Login failed ({r.status_code}): {r.text}")
    return r.json()["access_token"]


# ── API calls ─────────────────────────────────────────────────────────────────


def extract_text(text: str, token: str, client: httpx.Client) -> Optional[dict]:
    """Condition (a): POST /transactions/extract-text"""
    r = client.post(
        f"{BASE_URL}/transactions/extract-text",
        json={"text": text, "client_date": EVAL_DATE, "client_locale": EVAL_LOCALE},
        headers={"Authorization": f"Bearer {token}"},
        timeout=TIMEOUT_S,
    )
    if r.status_code != 200:
        return None
    data = r.json()
    if data.get("status") == "failed":
        return None
    return data.get("extraction")


def extract_voice(audio_path: Path, token: str, client: httpx.Client) -> Optional[dict]:
    """Condition (b): POST /transactions/voice"""
    with audio_path.open("rb") as f:
        r = client.post(
            f"{BASE_URL}/transactions/voice",
            files={"audio": (audio_path.name, f)},
            data={"client_date": EVAL_DATE, "client_locale": EVAL_LOCALE},
            headers={"Authorization": f"Bearer {token}"},
            timeout=120,
        )
    if r.status_code != 200:
        return None
    data = r.json()
    if data.get("status") == "failed":
        return None
    return data.get("extraction")


# ── Comparison helpers ────────────────────────────────────────────────────────


def _amount_match(pred: Optional[float], gold: float) -> bool:
    if pred is None:
        return False
    try:
        pred_f = float(pred)
    except (TypeError, ValueError):
        return False
    if gold == 0:
        return pred_f == 0
    return abs(pred_f - gold) / gold < AMOUNT_TOL


def _name_match(pred: Optional[str], gold: Optional[str]) -> bool:
    """Case-insensitive normalised comparison; both null → True."""
    if gold is None and pred is None:
        return True
    if gold is None or pred is None:
        return False
    return pred.strip().lower() == gold.strip().lower()


def _field_match(field: str, pred: Optional[object], gold: Optional[object]) -> bool:
    if field == "amount":
        return _amount_match(pred, float(gold))  # type: ignore[arg-type]
    if field == "name":
        return _name_match(pred, gold)  # type: ignore[arg-type]
    if gold is None and pred is None:
        return True
    if gold is None or pred is None:
        return False
    return str(pred).strip().lower() == str(gold).strip().lower()


# ── Metrics ───────────────────────────────────────────────────────────────────


class FieldStats:
    """Accumulates per-field correct/total counts and per-class TP/FP/FN."""

    def __init__(self) -> None:
        self.correct = 0
        self.total = 0
        self.tp: dict[str, int] = defaultdict(int)
        self.fp: dict[str, int] = defaultdict(int)
        self.fn: dict[str, int] = defaultdict(int)

    def update(self, pred: Optional[object], gold: Optional[object], field: str) -> None:
        self.total += 1
        match = _field_match(field, pred, gold)
        if match:
            self.correct += 1
        gold_key = str(gold).lower() if gold is not None else "__null__"
        pred_key = str(pred).lower() if pred is not None else "__null__"
        if match:
            self.tp[gold_key] += 1
        else:
            self.fn[gold_key] += 1
            self.fp[pred_key] += 1

    @property
    def accuracy(self) -> float:
        return self.correct / self.total if self.total else float("nan")

    def macro_f1(self) -> float:
        """Macro-averaged F1 over all classes that appear in gold."""
        classes = set(self.tp) | set(self.fn)
        if not classes:
            return float("nan")
        f1s = []
        for c in classes:
            tp, fp, fn = self.tp[c], self.fp[c], self.fn[c]
            p = tp / (tp + fp) if (tp + fp) else 0.0
            r = tp / (tp + fn) if (tp + fn) else 0.0
            f1s.append(2 * p * r / (p + r) if (p + r) else 0.0)
        return sum(f1s) / len(f1s)

    def per_class_f1(self) -> dict[str, dict]:
        classes = sorted(set(self.tp) | set(self.fn))
        out = {}
        for c in classes:
            tp, fp, fn = self.tp[c], self.fp[c], self.fn[c]
            p = tp / (tp + fp) if (tp + fp) else 0.0
            r = tp / (tp + fn) if (tp + fn) else 0.0
            f1 = 2 * p * r / (p + r) if (p + r) else 0.0
            out[c] = {"precision": round(p, 4), "recall": round(r, 4), "f1": round(f1, 4),
                      "support": tp + fn}
        return out

    def to_dict(self) -> dict:
        return {
            "n": self.total,
            "correct": self.correct,
            "accuracy": round(self.accuracy, 4),
            "macro_f1": round(self.macro_f1(), 4),
            "per_class": self.per_class_f1(),
        }


# ── Evaluation run ────────────────────────────────────────────────────────────


def evaluate_condition(
    entries: list[dict],
    condition: str,
    token: str,
    label: str = "",
) -> dict:
    """
    Run one evaluation condition and return metrics dict.
    condition: "gold" | "e2e"
    """
    stats: dict[str, FieldStats] = {f: FieldStats() for f in EXACT_FIELDS + CLASS_FIELDS}
    skipped = errors = 0

    with httpx.Client() as client:
        for entry in entries:
            gold_ex = entry["extraction_gold"]

            if condition == "e2e":
                ap = entry.get("audio_path")
                if not ap:
                    skipped += 1
                    continue
                audio_file = (Path(__file__).parent / ap).resolve()
                if not audio_file.exists():
                    skipped += 1
                    continue
                pred_ex = extract_voice(audio_file, token, client)
            else:
                pred_ex = extract_text(entry["transcript_gold"], token, client)

            if pred_ex is None:
                print(f"  [null] {entry['id']}: pipeline returned null", file=sys.stderr)
                errors += 1
                # Count all fields as wrong
                for f in stats:
                    stats[f].update(None, gold_ex.get(f), f)
                continue

            for f in stats:
                stats[f].update(pred_ex.get(f), gold_ex.get(f), f)

    tag = f"[{condition.upper()}]" + (f" {label}" if label else "")
    n_total = len(entries) - skipped
    print(f"\n{'=' * 60}")
    print(f"  Condition: {tag}   n={n_total}  skipped={skipped}  failed={errors}")
    print(f"{'=' * 60}")
    _print_table(stats)

    return {
        "condition": condition,
        "label": label,
        "n": n_total,
        "skipped": skipped,
        "failed": errors,
        "fields": {f: s.to_dict() for f, s in stats.items()},
    }


def _print_table(stats: dict[str, FieldStats]) -> None:
    col_w = 14
    header = f"  {'Field':<{col_w}}  {'Accuracy':>10}  {'Macro-F1':>10}  {'n':>6}"
    print(header)
    print("  " + "-" * (len(header) - 2))
    for field, s in stats.items():
        acc_str = f"{s.accuracy:.1%}" if s.total else "n/a"
        f1_str = f"{s.macro_f1():.1%}" if s.total else "n/a"
        print(f"  {field:<{col_w}}  {acc_str:>10}  {f1_str:>10}  {s.total:>6}")


# ── CLI ───────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--condition",
        choices=["gold", "e2e", "both"],
        default="both",
        help="Which evaluation condition to run (default: both)",
    )
    parser.add_argument(
        "--models",
        default="",
        help="Comma-separated extraction model names for ablation (e.g. qwen2.5:3b-instruct,qwen2.5:7b-instruct). "
             "Restart the API with EXTRACTION_MODEL set before each run.",
    )
    parser.add_argument("--label", default="", help="Short label added to results (e.g. zero_shot)")
    args = parser.parse_args()

    email = os.getenv("EVAL_EMAIL")
    password = os.getenv("EVAL_PASSWORD")
    if not email or not password:
        sys.exit("Set EVAL_EMAIL and EVAL_PASSWORD environment variables.")

    entries = [
        json.loads(line)
        for line in DATASET_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]

    with httpx.Client() as client:
        token = login(email, password, client)
    print(f"Logged in as {email}")

    models = [m.strip() for m in args.models.split(",") if m.strip()] or [""]
    conditions = ["gold", "e2e"] if args.condition == "both" else [args.condition]

    all_results: list[dict] = []

    for model in models:
        if model:
            input(
                f"\nSet EXTRACTION_MODEL={model} and restart the API, then press Enter…"
            )
        for cond in conditions:
            if cond == "e2e" and not any(e.get("audio_path") for e in entries):
                print("\n[e2e] No audio_path entries — skipping end-to-end condition.")
                continue
            label = model or args.label
            result = evaluate_condition(entries, cond, token, label=label)
            all_results.append(result)

    RESULTS_PATH.write_text(
        json.dumps(all_results, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"\nResults written → {RESULTS_PATH}")

    # Summary table across conditions / models
    if len(all_results) > 1:
        key_fields = ["transaction_type", "amount", "category"]
        print("\nSummary (key fields):")
        header = f"  {'Label':<24}" + "".join(f"  {f:>14}" for f in key_fields)
        print(header)
        print("  " + "-" * (len(header) - 2))
        for r in all_results:
            tag = f"{r['condition']}|{r['label']}" if r["label"] else r["condition"]
            row = f"  {tag:<24}" + "".join(
                f"  {r['fields'][f]['accuracy']:>13.1%}" for f in key_fields
            )
            print(row)


if __name__ == "__main__":
    main()
