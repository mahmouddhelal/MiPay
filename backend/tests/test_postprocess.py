"""Unit tests for the deterministic post-processing layer (§4.5).
Pure functions — no DB, no Ollama, no Whisper needed.
Run with: docker compose exec api pytest tests/test_postprocess.py -v
"""
from datetime import date

from app.services.postprocess import (
    normalize_numerals,
    postprocess,
    postprocess_many,
    resolve_date,
)

CLIENT_DATE = date(2026, 6, 12)  # a Friday


def _raw(**overrides) -> dict:
    base = {
        "transaction_type": "expense",
        "amount": 50.0,
        "currency": "SAR",
        "category": "groceries",
        "name": "كارفور",
        "date_text": None,
        "confidence": "high",
    }
    return {**base, **overrides}


# ── Numeral normalization (§4.5.2) ──────────────────────────────────────────

class TestNormalizeNumerals:
    def test_arabic_indic_digits(self):
        assert normalize_numerals("١٨ ريال") == "18 ريال"

    def test_all_ten_digits(self):
        assert normalize_numerals("٠١٢٣٤٥٦٧٨٩") == "0123456789"

    def test_arabic_decimal_separator(self):
        assert normalize_numerals("٥٫٢") == "5.2"

    def test_mixed_text_untouched(self):
        assert normalize_numerals("paid 50 SAR") == "paid 50 SAR"

    def test_empty(self):
        assert normalize_numerals("") == ""


# ── Date resolution (§4.5.3) ────────────────────────────────────────────────

class TestResolveDate:
    def test_null_defaults_to_client_date(self):
        assert resolve_date(None, CLIENT_DATE) == CLIENT_DATE

    def test_blank_defaults_to_client_date(self):
        assert resolve_date("   ", CLIENT_DATE) == CLIENT_DATE

    def test_english_yesterday(self):
        assert resolve_date("yesterday", CLIENT_DATE) == date(2026, 6, 11)

    def test_english_today(self):
        assert resolve_date("today", CLIENT_DATE) == CLIENT_DATE

    def test_arabic_yesterday_with_hamza(self):
        assert resolve_date("أمس", CLIENT_DATE) == date(2026, 6, 11)

    def test_arabic_yesterday_without_hamza(self):
        assert resolve_date("امس", CLIENT_DATE) == date(2026, 6, 11)

    def test_gulf_dialect_yesterday(self):
        assert resolve_date("البارح", CLIENT_DATE) == date(2026, 6, 11)
        assert resolve_date("البارحة", CLIENT_DATE) == date(2026, 6, 11)

    def test_egyptian_dialect_yesterday(self):
        assert resolve_date("امبارح", CLIENT_DATE) == date(2026, 6, 11)
        assert resolve_date("إمبارح", CLIENT_DATE) == date(2026, 6, 11)

    def test_day_before_yesterday(self):
        assert resolve_date("أول أمس", CLIENT_DATE) == date(2026, 6, 10)

    def test_egyptian_day_before_yesterday(self):
        assert resolve_date("أول امبارح", CLIENT_DATE) == date(2026, 6, 10)

    def test_arabic_today(self):
        assert resolve_date("اليوم", CLIENT_DATE) == CLIENT_DATE

    def test_egyptian_today(self):
        assert resolve_date("النهارده", CLIENT_DATE) == CLIENT_DATE
        assert resolve_date("النهاردة", CLIENT_DATE) == CLIENT_DATE

    def test_relative_days_ago(self):
        assert resolve_date("2 days ago", CLIENT_DATE) == date(2026, 6, 10)

    def test_arabic_qabl_yawmayn(self):
        # «قبل يومين» = two days ago (FR-06 example)
        assert resolve_date("قبل يومين", CLIENT_DATE) == date(2026, 6, 10)

    def test_last_friday_is_in_past(self):
        resolved = resolve_date("last friday", CLIENT_DATE)
        assert resolved < CLIENT_DATE
        assert resolved.weekday() == 4  # Friday

    def test_egyptian_mabarch_yesterday(self):
        assert resolve_date("مبارح", CLIENT_DATE) == date(2026, 6, 11)

    def test_egyptian_awel_mabarch(self):
        assert resolve_date("اول مبارح", CLIENT_DATE) == date(2026, 6, 10)

    def test_egyptian_enhardy_today(self):
        assert resolve_date("انهارده", CLIENT_DATE) == CLIENT_DATE
        assert resolve_date("انهاردة", CLIENT_DATE) == CLIENT_DATE

    def test_egyptian_delwaqti_today(self):
        assert resolve_date("دلوقتي", CLIENT_DATE) == CLIENT_DATE
        assert resolve_date("دلوقتى", CLIENT_DATE) == CLIENT_DATE

    def test_egyptian_last_week(self):
        resolved = resolve_date("الاسبوع اللي فات", CLIENT_DATE)
        assert (CLIENT_DATE - resolved).days in range(7, 14)

    def test_egyptian_last_month(self):
        resolved = resolve_date("الشهر اللي فات", CLIENT_DATE)
        assert resolved.month == 5 and resolved.year == 2026

    def test_egyptian_men_yomain(self):
        assert resolve_date("من يومين", CLIENT_DATE) == date(2026, 6, 10)

    def test_egyptian_men_osboo(self):
        resolved = resolve_date("من اسبوع", CLIENT_DATE)
        assert (CLIENT_DATE - resolved).days in range(7, 14)

    def test_unparseable_falls_back(self):
        assert resolve_date("blorptastic gibberish", CLIENT_DATE) == CLIENT_DATE

    def test_arabic_indic_digits_in_date(self):
        # "٣ مارس" = March 3rd; PREFER_DATES_FROM=past → March of the current year
        resolved = resolve_date("٣ مارس", CLIENT_DATE)
        assert (resolved.month, resolved.day) == (3, 3)


# ── Full postprocess: defaults, guards, status machine (§4.5.4–6) ───────────

class TestPostprocess:
    def test_ok_status(self):
        result = postprocess(_raw(), "transcript", CLIENT_DATE, "SAR")
        assert result.status == "ok"
        assert result.extraction is not None
        assert result.extraction.amount == 50.0
        assert result.extraction.date == CLIENT_DATE  # date_text null → client_date

    def test_currency_default_applied(self):
        result = postprocess(_raw(currency=None), "t", CLIENT_DATE, "EGP")
        assert result.extraction.currency == "EGP"

    def test_explicit_currency_kept(self):
        result = postprocess(_raw(currency="USD"), "t", CLIENT_DATE, "EGP")
        assert result.extraction.currency == "USD"

    def test_category_guard(self):
        result = postprocess(_raw(category=None), "t", CLIENT_DATE, "SAR")
        assert result.extraction.category == "other"

    def test_category_stays_null_when_type_null(self):
        result = postprocess(
            _raw(transaction_type=None, category=None, amount=None, confidence="low"),
            "t", CLIENT_DATE, "SAR",
        )
        assert result.extraction.category is None

    def test_needs_review_when_amount_missing(self):
        result = postprocess(_raw(amount=None), "t", CLIENT_DATE, "SAR")
        assert result.status == "needs_review"
        assert result.extraction is not None  # partial data still returned (FR-07)

    def test_needs_review_when_type_missing(self):
        result = postprocess(_raw(transaction_type=None), "t", CLIENT_DATE, "SAR")
        assert result.status == "needs_review"

    def test_needs_review_on_low_confidence(self):
        result = postprocess(_raw(confidence="low"), "t", CLIENT_DATE, "SAR")
        assert result.status == "needs_review"

    def test_failed_on_empty_transcript(self):
        result = postprocess(_raw(), "", CLIENT_DATE, "SAR")
        assert result.status == "failed"
        assert result.extraction is None

    def test_failed_on_invalid_llm_output(self):
        result = postprocess({"garbage": True}, "t", CLIENT_DATE, "SAR")
        assert result.status == "failed"

    def test_name_numerals_normalized(self):
        result = postprocess(_raw(name="فرع ٥"), "t", CLIENT_DATE, "SAR")
        assert result.extraction.name == "فرع 5"

    def test_date_text_resolved(self):
        result = postprocess(_raw(date_text="أمس"), "t", CLIENT_DATE, "SAR")
        assert result.extraction.date == date(2026, 6, 11)


# ── Multi-transaction post-processing (one utterance → many) ─────────────────

class TestPostprocessMany:
    def test_empty_list_yields_nothing(self):
        assert postprocess_many([], CLIENT_DATE, "EGP") == []

    def test_three_transactions_all_processed(self):
        raw_list = [
            _raw(transaction_type="expense", amount=50, currency="USD",
                 category="restaurants", name="coffee"),
            _raw(transaction_type="expense", amount=100, currency="USD",
                 category="restaurants", name="croissant"),
            _raw(transaction_type="income", amount=200, currency="USD",
                 category="transfer_in", name="father"),
        ]
        results = postprocess_many(raw_list, CLIENT_DATE, "EGP")
        assert len(results) == 3
        assert [r.status for r in results] == ["ok", "ok", "ok"]
        assert [r.extraction.amount for r in results] == [50, 100, 200]
        assert results[2].extraction.transaction_type == "income"

    def test_junk_item_dropped(self):
        # An all-null stray object must not become a blank confirm card.
        raw_list = [
            _raw(amount=50),
            {"transaction_type": None, "amount": None, "currency": None,
             "category": None, "name": None, "date_text": None, "confidence": "low"},
        ]
        results = postprocess_many(raw_list, CLIENT_DATE, "EGP")
        assert len(results) == 1
        assert results[0].extraction.amount == 50

    def test_per_item_needs_review(self):
        # Missing amount on the second item → that item is needs_review, first stays ok.
        raw_list = [_raw(amount=50), _raw(amount=None)]
        results = postprocess_many(raw_list, CLIENT_DATE, "EGP")
        assert len(results) == 2
        assert results[0].status == "ok"
        assert results[1].status == "needs_review"

    def test_currency_default_applied_per_item(self):
        results = postprocess_many([_raw(currency=None)], CLIENT_DATE, "EGP")
        assert results[0].extraction.currency == "EGP"
