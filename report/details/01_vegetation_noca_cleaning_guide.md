# NOCA modern vegetation cleaning guide

> **Documents:** How the NOCA legacy and resurvey tree records are cleaned and paired.  
> **Used by:** `R/pipeline/02_clean_noca_vegetation.R`  
> **Originally:** `docs/review/000_NOCA_cleaning_guide.md` (moved into the report on 2026-11-09)

Operational script: [`R/pipeline/02_clean_noca_vegetation.R`](../../R/pipeline/02_clean_noca_vegetation.R). This guide
describes the current 2026 correction and paired-plot contract; it is not an
executable stage. See the root [workflow](11_outputs_and_workflow.md) for order and commands.

## Purpose

The cleaner harmonizes the 1983 Agee legacy tree survey with the 2014–2015 JHRL
tree and seedling resurvey, applies the received corrected-tree workbook as an
authoritative patch, excludes records that are not supported taxonomic
identifications, and retains only defensible paired plots.

Presence means a species occurs as either an adult tree or regeneration. The
separate stage table preserves those strata for diagnostics. NOCA legacy
regeneration is the 0–3 m height class, whereas resurvey seedlings are 10–140 cm;
stage-specific temporal comparisons therefore have a measurement caveat.

## Immutable inputs

| Input | Role |
|---|---|
| `data/NOCA/AGEEDATA_NEW.xlsx` | Legacy TREE, overview, and species-code sheets. |
| `data/NOCA/NOCA_vegetation_fromJHRL.xlsx` | Original resurvey trees, seedlings, and species lookup. |
| `data/NOCA/NOCA_plots_fromWilson.csv` | Resurvey ID mapping and coordinates. |
| `data/NOCA/OriginalDataFiles_NOCA/2026_corrected_trees_for_Billur.xlsx` | Authoritative 2026 replacement rows. |
| `notes_from_Rachel/Missing trees.rtf` | Historical-location evidence for one study exclusion. |
| `notes_from_Rachel/Burned plots.rtf` | Old-clearcut evidence for one study exclusion. |

Raw inputs are never edited.

## Authoritative tree patch

The workbook must contain `Plot`, `Species`, and numeric `DBH`, exactly 2,366
rows across 54 corrected targets. Plot and species strings are normalized before
matching. Existing rows at corrected target/source groups are removed first, then
all valid corrected stems are appended once. This makes the operation idempotent
and prevents duplicate inflation.

The patch explicitly resolves four renamed source IDs and two mixed source groups
that split into separate corrected plot IDs. Species codes are resolved through
the existing JHRL crosswalk. Rows lacking a supported taxonomic identification
are discarded before occurrence and stage construction and are not analytical
findings or taxa.

Three corrected targets are not in the retained paired universe:

| Plot | Reason |
|---|---|
| `HB5144` | Missing coordinates. |
| `ROSS3022` | No matching legacy tree survey. |
| `MCAL5004` | No matching legacy tree survey. |

The correction changes present-period composition in 50 retained plots. The
coordinate set remains unchanged, so this data correction does not invalidate
coordinate-fingerprinted climate caches.

`CARI449` and `CARI450` have opposite raw longitude signs but normalize to the
same coordinate (48.51429, −121.21725) despite elevations of 622 and 1,149 m.
Rachel's September 2024 email warns against the 2014 GPS worksheet and points
to the paper's coordinate CSV, which still contains this collision. Her other
notes provide no correction. The author requested exclusion of both plots for
a **GPS problem**. The cleaner removes both dates before downstream outputs
and preserves raw coordinates in the collision audit with an excluded status.
See the [source review and decision](01_vegetation_noca_gps_exclusion.md).

## Paired-plot rules

Plots must have a valid present ID, valid coordinates, and an eligible legacy
counterpart. A plot with no supported occurrence in one period is retained with
an explicit zero placeholder when the other period has vegetation. Plots empty in
both periods are removed.

Four otherwise paired plots are excluded at study level:

| Plot | Reason and source |
|---|---|
| `BAK487` | Old clearcut; removed from Wilson's final analysis (`notes_from_Rachel/Burned plots.rtf`). |
| `BEAV6061` | Historical location uncertain; elevation was inaccurate and the resurvey landed in an avalanche chute (`notes_from_Rachel/Missing trees.rtf`). |
| `CARI449` | GPS problem; shares coordinates with CARI450 despite different elevation, with no verified replacement ([source review](01_vegetation_noca_gps_exclusion.md)). |
| `CARI450` | GPS problem; shares coordinates with CARI449 despite different elevation, with no verified replacement ([source review](01_vegetation_noca_gps_exclusion.md)). |

These are study-design exclusions, not silent cleaning losses.

## Verified outputs

| Output | Contract |
|---|---|
| `output/NOCA_occ.csv` | 305 paired plots, 1,775 rows, 31 identified taxa; unique plot × taxon × period; occurrence in `{0,1}`. |
| `output/NOCA_occ_stage.csv` | Adult/regeneration evidence only; no synthetic zero rows and no unsupported labels. |
| `output/NOCA_present_occ.csv`, `output/NOCA_past_occ.csv` | Period-specific occurrence components. |
| `output/NOCA_plot_info.csv` | Exactly the 305 paired plot IDs and their coordinates/elevation. |
| `output/NOCA_coordinate_collision_audit.csv` | Raw and normalized coordinates, elevations, shared-coordinate count, elevation range, and GPS-excluded status for `CARI449`/`CARI450`; no exact coordinate collision remains in the active plot table. |
| `output/NOCA_plot_tracking.csv` | Kept/removed plot accounting and reasons. |
| `output/NOCA_tree_correction_audit.csv` | One row per corrected target with removed/added counts, action, final status, and exclusion reason. |
| `output/NOCA_tree_composition_audit.csv` | Unpatched-versus-corrected present composition for all retained plots; 50 changes. |
| `output/NOCA_study_exclusions.csv` | The four explicit study exclusions and source/decision provenance. |

The 1,775 rows include 18 explicit zero placeholders. Removing unsupported
identifications upstream adds two placeholders relative to the former downstream-
only exclusion, so consolidated row count changes while presence content and the
CCA result do not.

## Validation

Run immediately after cleaning:

```bash
Rscript R/pipeline/02_clean_noca_vegetation.R
Rscript R/tests/test_NOCA_tree_corrections.R
Rscript R/tests/test_check_vegetation.R
```

The focused patch test validates workbook shape, target coverage, exact audit
accounting, correction exclusions, changed-composition count, unsupported-label
absence, paired-plot count, uniqueness, study exclusions, and the preserved
GPS evidence for the excluded collision. The general
vegetation gate additionally requires the occurrence and plot-info universes to
match and both periods to contain the same 305 plots.
