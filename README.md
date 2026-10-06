# PaleoACES

PaleoACES compares climate-predicted and observed forest composition in Mount Rainier (MORA) and North Cascades (NOCA), using forest resurveys and four Holocene records. A pooled CCA calibrated on legacy survey plots provides the shared coordinate system.

```bash
# Rebuild with existing climate aggregates
Rscript R/workflow.R --offline

# Rebuild analysis, report diagnostics, checks, and review report from native caches
Rscript R/workflow.R --offline --report

# Render maintained documentation
Rscript R/render_docs.R
```

The entrypoint, [R/workflow.R](R/workflow.R), runs each script in its own environment. Analysis stages live in `R/stages/`; shared settings and functions live in `R/helpers/`. Active input, cache, and result paths are preserved. Raw inputs and native caches are local research materials; a Git checkout contains the review, previews, curated summaries, linked PDFs, and provenance documents. Running the analysis requires those local inputs and the R packages used by the scripts (the validated chronology used R 4.6.1 and rbacon 3.5.2; fire processing uses tapas 0.1.5 and CharAnalysis 2.0.3).

Read the **[analysis review](docs/ANALYSIS_REVIEW.md)** or its [self-contained HTML](docs/ANALYSIS_REVIEW.html) for the scientific narrative, intermediate diagnostics, and manuscript Figures 2–5. The [documentation index](docs/INDEX.md) connects all maintained methods and provenance. The [workflow](docs/WORKFLOW.md) gives execution order and commands, [scientific decisions](docs/SCIENTIFIC_DECISIONS.md) records rationale and unresolved questions, and [figure captions](docs/FIGURE_CAPTIONS.md) supplies publication captions.

The [repository inventory](docs/REPOSITORY_INVENTORY.md) explains file roles and relocations; the [output inventory](docs/OUTPUTS.md) describes result tables. Main figures remain PDF/PNG pairs in `plot/`; diagnostics remain PDF-only in `plot/test_figures/`. Historical code and products are archived. The [combined analysis script](docs/review/00_main_analysis_review.R) is a generated reading copy; execute the workflow driver for a real run.
