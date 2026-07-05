# MiPay — Graduation Thesis (LaTeX)

This is the LaTeX source for the MiPay graduation-project documentation. It is a
full thesis (Introduction → Related Work → System Analysis → Implementation →
Experimental Results → Conclusion → Appendices) grounded in the actual MiPay
codebase.

## Build

Requires a TeX distribution (TeX Live / MiKTeX) with `pdflatex` and `bibtex`.

```bash
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex   # twice more to resolve refs, citations, ToC
```

Or simply: `latexmk -pdf main.tex`.

## What you must fill in

1. **Title page** — open `sections/title_page.tex` and replace every
   `[bracketed]` placeholder (university, faculty, department, author names,
   supervisor, degree).
2. **Figures** — see `FIGURE_GUIDE.md`. Drop each described image into `figures/`
   with the exact filename. Missing images render as labelled placeholder boxes,
   so the document compiles before you add them.
3. **Experimental results** — every yellow-highlighted cell in Chapter 5 (e.g.
   `[XX.X]`) is a placeholder. Run the evaluation harness
   (`backend/evaluation/run_stt_eval.py` and `run_extraction_eval.py`) and paste
   the measured numbers in, replacing each `\result{...}` with the value.

## Structure

```
main.tex                      # master file
settings/packages.tex         # packages + listings styles
settings/commands.tex         # macros, \result placeholder, missing-figure fallback
sections/                     # title page, acknowledgments, abstract
chapters/chapter1..6.tex      # the six chapters
chapters/appendices.tex       # Appendix A (technical reference + UI gallery)
bibliography/bibliography.bib # references (IEEE / NeurIPS / arXiv / Google, etc.)
figures/                      # drop sourced .jpg / .png here (see FIGURE_GUIDE.md)
FIGURE_GUIDE.md               # description of every image to create
```

## Editing notes

- The document is **English-only** by design; Arabic examples are transliterated
  so the file compiles with standard `pdflatex` (no Arabic font/XeLaTeX needed).
- The model strategy is **as-built + documented upgrade path**: Chapters 1–5
  describe the implemented stack (Whisper-small + Qwen2.5-7B); Chapter 6 presents
  the recommended upgrades (faster-whisper large-v3-turbo, larger/newer LLMs,
  LoRA fine-tuning) as principled future work. If you later change the code, the
  thesis stays consistent.
- `\result{...}` (yellow box) marks every number to be replaced after evaluation.
- `\TODO{...}` is available for any other placeholder you want to flag.
