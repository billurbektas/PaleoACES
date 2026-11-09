# PaleoACES

PaleoACES compares climate-predicted and observed forest composition in Mount Rainier (MORA) and
North Cascades (NOCA) National Parks, using forest resurveys and four Holocene macrofossil records.
One CCA calibrated on the legacy survey plots provides the shared coordinate system.

**Read the [analysis report](report/README.md)**: the supplementary appendix, with every figure,
reported table and modelling code in the order of the analysis, and links to the detailed
records in [`report/details/`](report/details).

```sh
Rscript R/run_all.R --offline   # run the whole analysis from the cached climate
Rscript R/build_report.R        # rebuild the report from the outputs
```

| Folder | Contents |
|---|---|
| `R/pipeline/` | The analysis, numbered in run order (01–15); writes `output/` only |
| `R/figures/` | Main and supplementary figures, drawn from `output/` |
| `R/worked_examples.R` | Step-by-step method illustrations |
| `R/tests/` | Scientific regression checks, run last by `R/run_all.R` |
| `R/helpers/` | Shared functions; `paths.R` declares every output file |
| `report/` | The report, its figures, tables and detail pages |
| `data/`, `Cores/`, `output/` | Raw data, Bacon runs and outputs (local, not in git) |

[Outputs and workflow](report/details/11_outputs_and_workflow.md) lists every script and every
output file. Software: R with rbacon 3.5.2, tapas 0.1.5 and CharAnalysis 2.0.3, plus `pdftoppm`
(poppler) for the report.
