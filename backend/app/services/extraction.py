"""LLM extraction via Ollama (§4.2–4.4). The JSON schema and prompt are
kept in sync with MIPAY_SPEC.md §4.3/§4.4 — update the spec in the same commit."""
import json
import logging

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class ExtractionError(Exception):
    """Ollama unreachable, model missing, or non-JSON reply."""


# §4.3 — per-transaction object (verbatim fields). A single utterance may contain
# several transactions, so the wire schema (EXTRACTION_SCHEMA) wraps a list of these.
TRANSACTION_ITEM_SCHEMA: dict = {
    "type": "object",
    "properties": {
        "transaction_type": {"type": ["string", "null"], "enum": ["expense", "income", None]},
        "amount": {"type": ["number", "null"]},
        "currency": {
            "type": ["string", "null"],
            "enum": ["SAR", "USD", "EUR", "EGP", "AED", "KWD", "QAR", "BHD", "OMR",
                     "JOD", "IQD", "SYP", "YER", "LYD", "TND", "DZD", "MAD", "SDG",
                     "LBP", None],
        },
        "category": {
            "type": ["string", "null"],
            "enum": [
                "groceries", "restaurants", "transport", "fuel", "shopping",
                "bills", "rent", "health", "education", "entertainment",
                "travel", "personal_care", "gifts_donations", "salary",
                "business", "transfer_in", "other",
                # Egyptian additions (migration 0003)
                "coffee", "internet_mobile", "subscriptions", "household",
                "tuition", "clothes", "pets", "insurance", "savings",
                "transfer_out", "freelance", "investments",
                None,
            ],
        },
        "name": {"type": ["string", "null"]},
        "date_text": {"type": ["string", "null"]},
        "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
    },
    "required": ["transaction_type", "amount", "currency", "category", "name",
                 "date_text", "confidence"],
}

# §4.3 — the wire schema sent to Ollama. One transcript → a list of transactions
# (often length 1, but "coffee 50, croissant 100, and dad sent me 200" → length 3).
EXTRACTION_SCHEMA: dict = {
    "type": "object",
    "properties": {"transactions": {"type": "array", "items": TRANSACTION_ITEM_SCHEMA}},
    "required": ["transactions"],
}

# §4.4 — Egyptian-first prompt (updated in migration 0003 commit)
SYSTEM_PROMPT = """You are a financial transaction extraction engine for an Egyptian personal finance app.
The user message is a voice-note transcript in Egyptian Arabic, English, or a mix of both.
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
- "currency": ISO code of the spoken currency. Egyptian-first rule: bare جنيه/جنيهات/
  geneh/pound/pounds without a country qualifier → EGP. Full dialect map:
  ريال/riyal/ryal → SAR (unless qatari/قطري → QAR or omani/عماني → OMR),
  دولار/dollar(s)/بكس → USD, درهم/dirham → AED (unless مغربي → MAD),
  دينار → KWD if كويتي, JOD if أردني, BHD if بحريني, IQD if عراقي, LYD if ليبي,
  TND if تونسي, يورو/euro → EUR, ليرة (Lebanese context) → LBP, (Syrian) → SYP.
  If no currency is spoken, return null.
- "category": pick the single best matching value from the schema enum. Examples:
  بقالة/سوبرماركت/كارفور/spinneys/groceries → groceries;
  مطعم/غداء/عشا/أكل برة/lunch/dinner → restaurants;
  قهوة/كافيه/coffee/كابتشينو → coffee;
  كارت شحن/فودافون/اتصالات/نت/باقة/internet_mobile → internet_mobile;
  نتفليكس/Netflix/جيم/اشتراك/subscription → subscriptions;
  مصاريف البيت/سوق/لماما/بابا → household;
  درس/سنتر/مدرس خصوصي/tuition → tuition;
  هدوم/لبس/جاكيت/clothes → clothes;
  جمعية/حوّشت/savings → savings;
  بعت فلوس لحد/حولت لحد → transfer_out;
  شغل فريلانس/مشروع/freelance → freelance;
  أسهم/شهادة/دهب/استثمار → investments;
  بنزين/وقود/petrol/gas → fuel; أوبر/تاكسي/مواصلات/uber/taxi/metro → transport;
  فاتورة/كهرباء/مياه/bill/electricity → bills; إيجار/rent → rent;
  صيدلية/دكتور/مستشفى/pharmacy/doctor → health;
  راتب/معاش/salary/paycheck/مرتب → salary;
  حوالة واردة/someone sent me money → transfer_in. If nothing fits, use "other".
- "name": the merchant, store, person, or a 2-4 word description of what the money
  was for. Use the EXACT language and words the user actually spoke — if the
  transcript is in English, "name" must be in English; NEVER translate it into
  Arabic (or any other language) even if the category value or these
  instructions use Arabic elsewhere. null if not mentioned.
- "date_text": copy the EXACT date/time phrase from the transcript ("أمس", "امبارح",
  "yesterday", "يوم الجمعة", "last week", "3 مارس"). Do NOT resolve it to a date.
  null if no date phrase is present.
- "confidence": "high" if amount and type are explicit; "medium" if you inferred
  something; "low" if the utterance barely describes a transaction.
- Never invent values. Prefer null over guessing."""

# §4.4 few-shots — Egyptian-weighted (7 shots covering new categories + one Gulf + one English)
FEW_SHOT_EXAMPLES: list[tuple[str, str]] = [
    # Egyptian groceries
    (
        "دفعت خمسين جنيه على البقالة من كارفور امبارح",
        '{"transactions":[{"transaction_type":"expense","amount":50,"currency":"EGP","category":"groceries","name":"كارفور","date_text":"امبارح","confidence":"high"}]}',
    ),
    # Egyptian salary
    (
        "قبضت المرتب النهارده ١٨ ألف",
        '{"transactions":[{"transaction_type":"income","amount":18000,"currency":"EGP","category":"salary","name":"المرتب","date_text":"النهارده","confidence":"high"}]}',
    ),
    # English salary — no employer named, so "name" is null (not a translated
    # copy of the Arabic example above). Without this, salary/income requests
    # in English were leaking the Arabic "name" value from the example above.
    (
        "I got my salary today, 3500 dollars",
        '{"transactions":[{"transaction_type":"income","amount":3500,"currency":"USD","category":"salary","name":null,"date_text":"today","confidence":"high"}]}',
    ),
    # New category: internet_mobile
    (
        "شحنت كارت فودافون بخمسة وسبعين جنيه امبارح",
        '{"transactions":[{"transaction_type":"expense","amount":75,"currency":"EGP","category":"internet_mobile","name":"فودافون","date_text":"امبارح","confidence":"high"}]}',
    ),
    # New category: coffee
    (
        "اشتريت قهوة من الكافيه بثلاثين جنيه",
        '{"transactions":[{"transaction_type":"expense","amount":30,"currency":"EGP","category":"coffee","name":"الكافيه","date_text":null,"confidence":"high"}]}',
    ),
    # Gulf dialect still works (SAR)
    (
        "اشتريت قهوة من ستاربكس بـ ١٨ ريال",
        '{"transactions":[{"transaction_type":"expense","amount":18,"currency":"SAR","category":"coffee","name":"ستاربكس","date_text":null,"confidence":"high"}]}',
    ),
    # English
    (
        "paid like 30 bucks for the uber to the airport",
        '{"transactions":[{"transaction_type":"expense","amount":30,"currency":"USD","category":"transport","name":"uber to the airport","date_text":null,"confidence":"high"}]}',
    ),
    # Multi-transaction Egyptian
    (
        "اشتريت هدوم بمية وخمسين جنيه وحطيت بنزين بمية جنيه",
        '{"transactions":['
        '{"transaction_type":"expense","amount":150,"currency":"EGP","category":"clothes","name":"هدوم","date_text":null,"confidence":"high"},'
        '{"transaction_type":"expense","amount":100,"currency":"EGP","category":"fuel","name":"بنزين","date_text":null,"confidence":"high"}'
        ']}',
    ),
    # No transaction at all → empty array
    (
        "الجو حلو اليوم والحمد لله",
        '{"transactions":[]}',
    ),
]


def _build_messages(transcript: str) -> list[dict[str, str]]:
    messages: list[dict[str, str]] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for user_msg, assistant_msg in FEW_SHOT_EXAMPLES:
        messages.append({"role": "user", "content": user_msg})
        messages.append({"role": "assistant", "content": assistant_msg})
    messages.append({"role": "user", "content": transcript})
    return messages


async def extract(transcript: str) -> dict:
    """One constrained-decoding chat call. Returns the raw extraction dict.

    Raises ExtractionError if Ollama is unreachable or replies with garbage.
    """
    payload = {
        "model": settings.EXTRACTION_MODEL,
        "messages": _build_messages(transcript),
        "format": EXTRACTION_SCHEMA,   # constrained decoding — guaranteed schema-valid JSON
        "options": {"temperature": 0},
        "stream": False,
    }
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(180.0, connect=5.0)) as client:
            response = await client.post(f"{settings.OLLAMA_URL}/api/chat", json=payload)
            response.raise_for_status()
            content = response.json()["message"]["content"]
            return json.loads(content)
    except (httpx.HTTPError, KeyError, json.JSONDecodeError) as exc:
        logger.error("Extraction call failed: %s", exc)
        raise ExtractionError(str(exc)) from exc
