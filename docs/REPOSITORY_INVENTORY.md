# Repository inventory

The reorganization preserves the sequential workflow, stage names and order, isolated environments, scientific calculations, and all active data/cache/result paths. A full local backup was made before relocation on 2026-10-05; no commit or push is part of this change.

| Area | Role and active producers/consumers |
|---|---|
| Root | README and RStudio project; input/reference directories retain their names. |
| `R/workflow.R` | Sequential analysis and automatic checks; optional report refresh. |
| `R/` | Workflow and documentation/report rendering entrypoints. |
| `R/stages/` | All 25 ordered analysis stages, including the conditional age-depth stage, consumed by the driver and downstream stages. |
| `R/helpers/` | Shared config and Bacon settings, plus climate, chronology, fire, geometry, styling, documentation, and report functions. |
| `R/tests/` | The 16 existing automatic gates; an additional report integrity gate. |
| `R/diagnostics/` | Optional scientific diagnostics; four are refreshed by report runs. Filenames are retained. |
| `R/vendor/` | CHELSA downloader and Torres reference script; source contents preserved. |
| `R/archive/` | Existing historical code, preserved and excluded from active checks. |
| `data/`, `notes_from_Rachel/` | Authoritative local inputs; colocated provenance is linked in the documentation index. |
| `Cores/` | Protected chronology controls, posteriors, ages and their provenance. Historical sensitivity models already here stay in place because age-draw signatures include all posterior files. |
| `archive/chronology/` | Former `Cores_pre_slump/`, outside the active chronology tree. |
| `output/` | Active scientific results, native climate chunks, age draws, and source/software manifests. Stage producers are listed in the workflow; model and figure consumers use these unchanged paths. |
| `output/archive/` | Verified unused legacy aggregates, organized-climate CSVs, old-coordinate products, and retired monthly directories. Historical consumers remain in the R archive. |
| `plot/` | Four main figure stems, each PDF and PNG; producers 05a, 09c, 13a, 14. |
| `plot/test_figures/` | Diagnostic PDFs; no persistent PNGs. |
| `plot/archive/` | Former `plot/archieve/` and unused root graphics, preserved. |
| `docs/` | Maintained operational/scientific documents, review Markdown and self-contained HTML. |
| `docs/methods/`, `docs/references/` | Detailed methods and context; publication decisions remain in SCIENTIFIC_DECISIONS and FIGURE_CAPTIONS. |
| `docs/review/` | Generated combined reading copy; tests excluded, workflow order retained. |
| `docs/report/`, `docs/assets/analysis/` | Authored narrative template, diagnostic selection registry, generated previews, curated summaries, and provenance. |
| `related_publications/` | Local reference literature; does not define climate eras or fire classifications. |

## Relocation and preservation records

The [relocation map](reorganization/relocation_map.csv) records original/new paths, original byte counts, and SHA-256 checksums. The [baseline inventory](reorganization/baseline_inventory.csv) lists every pre-change research file, original and current locations, and literal active-code references. The [baseline check log](reorganization/baseline-gates.log) records all 16 successful automatic gates before changes. Generated products can change when rerendered; archived inputs and third-party source retain their recorded checksums.

The age-depth stage now lives in `R/stages/`; Bacon settings and shared config live in `R/helpers/`. At the preserved reorganization checkpoint, config was byte-identical and the age-depth script and Bacon settings changed only literal file references, including comments. The review branch subsequently strengthened config's climate-cache validation without changing scientific constants; the age-depth script and Bacon settings remain identical to that checkpoint. The [chronology relocation record](reorganization/chronology_relocation.json) contains the exact relocations and hashes of [the original age-depth source](reorganization/chronology_sources_before_move/000_PALEO_a_agedepth.R.txt), [Bacon settings](reorganization/chronology_sources_before_move/bacon_settings.R.txt), and [shared config](reorganization/chronology_sources_before_move/config.R.txt). See the [audit](REVIEW_AUDIT.md) for subsequent technical corrections.

The provenance gate accepts historical hashes only when the current source exactly equals its verified snapshot after these replacements. Age-draw cache fingerprints use the historical settings identity under the same condition. Any other code or settings edit loses that equivalence; model-setting checks and cache invalidation still apply. Existing posterior files, chronology manifests, and cached draws are preserved. Future chronology runs record the actual current source hashes. All active script comments use current locations.

## Raw duplicates and authority

Raw duplicates are retained. The cleaner's actual read path identifies authority; duplicates are never automatically substituted.

| Authoritative input | Retained duplicate/context |
|---|---|
| `data/raw/MORA_Cascade Legacy Data_Original1978.xlsx` (MORA cleaner) | Same workbook under `data/NOCA/`; retained historical copy. |
| `data/NOCA/AGEEDATA_NEW.xlsx` (NOCA cleaner) | `data/raw/AGEEDATA_NEW.xlsx`; retained identical copy. |
| `data/NOCA/NOCA_plots_fromWilson.csv` (NOCA metadata/fire) | Received coordinate CSV under MORA disturbance package and vendored Wilson raw data; retained. |
| MORA original 1978 workbook plus cleaned resurvey tree/seedling CSVs | Master2018 workbook copies retain context; they do not replace the original legacy input. |
| Received NOCA fire spatial join and Wilson reference in `data/NOCA/` | External Wilson package copies remain for source comparison. |

The input documents in the [index](INDEX.md) describe corrections and provenance. The [output inventory](OUTPUTS.md) and [workflow](WORKFLOW.md) give detailed table roles and producer/consumer order.

## Verification

The [acceptance record](reorganization/VALIDATION.md) reports scientific-table equivalence, protected chronology and archive checksums, complete workflow checks, deliberate deletion recovery, offline cache rejection, stale-evidence rejection, and portability without raw data.
