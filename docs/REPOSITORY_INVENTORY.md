# Repository inventory

PaleoACES uses the sequential [workflow](WORKFLOW.md). This inventory identifies
the maintained code, scientific documents and authoritative local inputs.

| Area | Role |
|---|---|
| Root | Project README, RStudio project and reference material. |
| `R/` | Workflow and documentation/report entrypoints. |
| `R/stages/` | The 21 analysis stages, in the workflow's execution order; chronology fitting is optional. |
| `R/helpers/` | Shared settings and functions for vegetation, climate, chronology, fire, CCA metrics, figures and reporting. |
| `R/tests/` | The 14 automatic analysis gates and an additional report check. |
| `R/diagnostics/` | Scientific diagnostics and optional sensitivities; five diagnostics are refreshed with the report, including the counts from starting plots and samples to CCA. |
| `R/vendor/` | Preserved CHELSA downloader and Torres reference script. |
| `tools/` | Report construction, dependency diagram and reusable independent verification tools. |
| `data/`, `notes_from_Rachel/` | Local study inputs and source correspondence. |
| `Cores/` | Controls, settings, stored posteriors and ages; existing sensitivity models are retained. |
| `Cores/provenance/` | Original chronology source snapshots and records needed to verify unchanged stored models. |
| `output/` | Active tables, native climate caches, age draws and model/report summaries. |
| `plot/` | Manuscript Figures 2 and 3, each as a PDF and PNG. |
| `plot/test_figures/` | Diagnostic PDFs. |
| `docs/` | Scientific review, decisions, captions, workflow, indexes and HTML companions. |
| `docs/methods/`, `docs/references/` | Detailed cleaning, consolidation, metric methods and literature context. |
| `docs/review/` | Combined analysis reading copy, tracking support and preservation evidence, GPS source note, stored Pb210 comparison and TraCE21k–V2.1 appendix. |
| `docs/report/`, `docs/assets/analysis/` | Review template, figure selection and dated survey-decision baseline; generated previews, curated tables and verification metadata. |
| `related_publications/` | Local reference papers. |

Raw inputs, large results, native caches, stored posteriors and local settings
remain excluded from Git. The review, required source notes, curated tables and
linked figures are available in a checkout without those research inputs.
Retired scripts remain recoverable from Git history, including commit
`513febb95a965a3437db8f69e2fc795b938f6989`; local archive directories have been removed.

## Raw duplicates and authority

The cleaners' actual input paths identify the authoritative copies. Raw
duplicates are retained and are not substituted automatically.

| Authoritative input | Retained duplicate or context |
|---|---|
| `data/raw/MORA_Cascade Legacy Data_Original1978.xlsx` | The workbook under `data/NOCA/` is a historical copy. |
| `data/NOCA/AGEEDATA_NEW.xlsx` | An identical copy remains under `data/raw/`. |
| `data/NOCA/NOCA_plots_fromWilson.csv` | Received coordinate and Wilson paper-repository copies support source comparison. |
| Original MORA legacy workbook and cleaned resurvey tree/seedling CSVs | Master2018 copies provide context and do not replace the original legacy input. |
| Received NOCA fire spatial join and Wilson reference in `data/NOCA/` | External Wilson package copies support comparison. |

The [documentation index](INDEX.md) links the detailed source notes.
[OUTPUTS](OUTPUTS.md) identifies result tables and their producers;
[WORKFLOW](WORKFLOW.md) gives script order, dependencies and verification commands.

The two small versioned MORA reference CSVs record vetted seedling-to-adult visit
mappings and the source-year discrepancy audit. They supplement the received
inputs without editing them. `R/helpers/survey_years.R` applies the date rule;
`R/helpers/survey_decision_effects.R` compares its results with the dated baseline.
