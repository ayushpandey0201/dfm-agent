# Documentation Index

Everything written about **dfm-agent** — the AI-driven Design for
Manufacturing tool built for the Bosch (BGSW) DfM hackathon by Team Stack.
Start here; each file below has one job.

Last synced with the code: **2026-08-31** (HEAD `979dd7c`).

---

## Start here

| Doc | What it is | Read it when |
|---|---|---|
| [`../README.md`](../README.md) | Install & run the app (Windows / macOS / Linux), troubleshooting, test suite | You want the thing running |
| [`product-walkthrough.md`](product-walkthrough.md) | Demo script — upload a part, read every metric, what each colour means | You are demoing, or seeing the UI for the first time |
| [`product-document.md`](product-document.md) | Product view: audience, the 7 features, roadmap | Someone asks "what does this *do*?" |

## Deliverables (what was submitted)

| Doc | What it is |
|---|---|
| [`technical-document.md`](technical-document.md) | **Methodology report** — the required deliverable. Every algorithm, 11 sections, 6 Mermaid flowcharts, validation & performance numbers |
| [`phase2-presentation-content.md`](phase2-presentation-content.md) | Phase 2 slide content: 11 slides + 4 backup, speaker notes, numbers reference sheet, Q&A prep |

## Reference & history

| Doc | What it is |
|---|---|
| [`llm-context.md`](llm-context.md) | **Complete knowledge base** (~900 lines): project background, domain primer, everything the judges said with sources, repo map, the full pipeline calculation-by-calculation, consolidated decision table, validation history, known limitations, quote bank, glossary. The single richest file here — written to bring a person or a model fully up to speed in one read |
| [`decision-log.md`](decision-log.md) | ADR-style log of the 9 architectural decisions, each with context / decision / rationale |
| [`meeting-notes-2026-07-28.md`](meeting-notes-2026-07-28.md) | Full notes from the Bosch Phase 2 Q&A call (44:47) — the source document behind many decisions |
| [`untillnow.md`](untillnow.md) | Deep-dive write-up of the flat-parting-line fix on Part 1 (2026-08-17), including the approaches that were *measured wrong* and should not be retried |

---

## How the docs map to the code

| Module | Documented in |
|---|---|
| `core/step_parser.py` | technical §2 · llm-context §6.1 |
| `core/undercut_detector.py` | technical §3 · llm-context §6.2 |
| `core/mold_direction.py` | technical §4 · llm-context §6.3 |
| `core/silhouette.py` | technical §5 · llm-context §6.5 · decision-log §9 |
| `core/draft_angle.py` | technical §7 (inline) · llm-context §6.6 |
| `core/face_classifier.py` | technical §7 · llm-context §6.7 · decision-log §6, §8 · untillnow.md |
| `core/parting_line.py` | technical §8 · llm-context §6.8 · decision-log §5 |
| `core/undercut_regions.py` | technical §9 · llm-context §6.9 |
| `core/models.py` (score) | technical §10 · llm-context §6.10 · decision-log §4 |
| `api.py` / `frontend/src/` | llm-context §6.11–6.12 |

---

## Keeping this folder in sync

Two rules, learned the hard way (this folder briefly held three duplicate
docs and a stray `untitled folder/`):

1. **One file per topic, no copies.** If you edit a doc, edit it in place.
   Never leave a `name (1).md` — a downloaded copy silently became the only
   current version while the tracked file went stale.
2. **Any change to `core/` updates two docs**: `technical-document.md` (the
   algorithm) and `llm-context.md` (§4 repo map, §6 pipeline, §7 decision
   table). Add an entry to `decision-log.md` when the *approach* changed, not
   just the code.

After an algorithm change, re-run the regression harness and the suite before
updating the numbers quoted in the docs:

```bash
.venv/bin/python scripts/analyze_cli.py assets/Part3.stp
.venv/bin/python -m pytest tests/ -q
```
