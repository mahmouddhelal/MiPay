"""
Arabic text normalisation used before computing WER.

Applied to both hypothesis and reference before jiwer.wer() so that
acoustically identical utterances that differ only in orthographic
convention (diacritics, alef shape, ta-marbuta) are not penalised.

Normalisation steps (ordered):
  1. Strip Arabic diacritics / harakat (U+064B–U+065F) and tatweel (U+0640).
  2. Unify all alef variants (أ إ آ ٱ) to bare alef (ا).
  3. Unify ta-marbuta (ة) to ha (ه) — common in dialects and Whisper output.
  4. Unify Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) to ASCII digits.
  5. Collapse repeated whitespace; strip leading/trailing space.

Note: we do NOT remove punctuation or normalise hamza forms other than
alef-hamza, because Whisper rarely outputs punctuation for Arabic.
"""

import re
import unicodedata


# Arabic-Indic to ASCII digit map
_INDIC_MAP = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")

# Diacritics range: harakat (U+064B–U+065F) + superscript alef (U+0670)
_DIACRITIC_RE = re.compile(r"[ً-ٰٟ]")

# Tatweel / kashida
_TATWEEL_RE = re.compile(r"ـ")

# Alef variants → bare alef
_ALEF_RE = re.compile(r"[أإآٱ]")

# Alef-wasla (U+0671) → bare alef
_ALEF_WASLA_RE = re.compile(r"ٱ")

# Ta-marbuta → ha
_TAMARBUTA_RE = re.compile(r"ة")

# Whitespace
_WS_RE = re.compile(r"\s+")


def normalize_arabic(text: str) -> str:
    """Return a normalised form of *text* suitable for WER comparison."""
    # Translate Arabic-Indic numerals
    text = text.translate(_INDIC_MAP)
    # Strip diacritics
    text = _DIACRITIC_RE.sub("", text)
    # Remove tatweel
    text = _TATWEEL_RE.sub("", text)
    # Unify alef variants
    text = _ALEF_RE.sub("ا", text)
    text = _ALEF_WASLA_RE.sub("ا", text)
    # Unify ta-marbuta → ha
    text = _TAMARBUTA_RE.sub("ه", text)
    # Normalise whitespace
    text = _WS_RE.sub(" ", text).strip()
    return text


if __name__ == "__main__":
    import sys

    samples = [
        "دَفَعْتُ خَمْسِيْنَ رِيَالاً عَلَى البَقَالَةِ مِنْ كَارِفُور أَمْس",
        "دفعت ٥٠ ريالاً على البقالة من كارفور أمس",
        "إستلمت الراتب",
        "اشتريت ملابس",
    ]
    for s in samples:
        print(f"  IN:  {s}")
        print(f"  OUT: {normalize_arabic(s)}")
        print()
