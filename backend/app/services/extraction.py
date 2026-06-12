"""LLM extraction via Ollama (§4.2–4.4). The JSON schema and prompt are
verbatim from MIPAY_SPEC.md — do not edit them without updating the spec."""
import json
import logging

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class ExtractionError(Exception):
    """Ollama unreachable, model missing, or non-JSON reply."""


# §4.3 — verbatim
EXTRACTION_SCHEMA: dict = {
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
            "enum": ["groceries", "restaurants", "transport", "fuel", "shopping",
                     "bills", "rent", "health", "education", "entertainment",
                     "travel", "personal_care", "gifts_donations", "salary",
                     "business", "transfer_in", "other", None],
        },
        "name": {"type": ["string", "null"]},
        "date_text": {"type": ["string", "null"]},
        "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
    },
    "required": ["transaction_type", "amount", "currency", "category", "name",
                 "date_text", "confidence"],
}

# §4.4 — verbatim
SYSTEM_PROMPT = """You are a financial transaction extraction engine for a personal finance app.
The user message is a voice-note transcript in Arabic, English, or a mix of both.
Extract the transaction fields into JSON following the provided schema. Rules:

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
- Never invent values. Prefer null over guessing."""

# §4.4 few-shots — verbatim, sent as alternating user/assistant messages
FEW_SHOT_EXAMPLES: list[tuple[str, str]] = [
    (
        "دفعت خمسين ريال على البقالة من كارفور أمس",
        '{"transaction_type":"expense","amount":50,"currency":"SAR","category":"groceries","name":"كارفور","date_text":"أمس","confidence":"high"}',
    ),
    (
        "I got my salary today, 4500",
        '{"transaction_type":"income","amount":4500,"currency":null,"category":"salary","name":"salary","date_text":"today","confidence":"high"}',
    ),
    (
        "حولت لي أمي مية وخمسين دولار يوم الجمعة",
        '{"transaction_type":"income","amount":150,"currency":"USD","category":"transfer_in","name":"أمي","date_text":"يوم الجمعة","confidence":"high"}',
    ),
    (
        "paid like 30 bucks for the uber to the airport",
        '{"transaction_type":"expense","amount":30,"currency":"USD","category":"transport","name":"uber to the airport","date_text":null,"confidence":"high"}',
    ),
    (
        "اشتريت قهوة من ستاربكس بـ ١٨ ريال",
        '{"transaction_type":"expense","amount":18,"currency":"SAR","category":"restaurants","name":"ستاربكس","date_text":null,"confidence":"high"}',
    ),
    (
        "الجو حلو اليوم والحمد لله",
        '{"transaction_type":null,"amount":null,"currency":null,"category":null,"name":null,"date_text":null,"confidence":"low"}',
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
