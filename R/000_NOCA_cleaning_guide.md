# NOCA modern vegetation cleaning guide

Operational script: [`R/000_NOCA_cleaning.R`](000_NOCA_cleaning.R). This guide
describes the current 2026 correction and paired-plot contract; it is not an
executable stage. See the root [workflow](../WORKFLOW.md) for order and commands.

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
Both are retained pending confirmation from a primary coordinate source. The
cleaner records this unresolved collision explicitly rather than silently
changing coordinates or excluding either plot.

## Paired-plot rules

Plots must have a valid present ID, valid coordinates, and an eligible legacy
counterpart. A plot with no supported occurrence in one period is retained with
an explicit zero placeholder when the other period has vegetation. Plots empty in
both periods are removed.

Two otherwise paired plots are excluded at study level:

| Plot | Reason and source |
|---|---|
| `BAK487` | Old clearcut; removed from Wilson's final analysis (`notes_from_Rachel/Burned plots.rtf`). |
| `BEAV6061` | Historical location uncertain; elevation was inaccurate and the resurvey landed in an avalanche chute (`notes_from_Rachel/Missing trees.rtf`). |

These are study-design exclusions, not silent cleaning losses.

## Verified outputs

| Output | Contract |
|---|---|
| `output/NOCA_occ.csv` | 307 paired plots, 1,790 rows, 31 identified taxa; unique plot × taxon × period; occurrence in `{0,1}`. |
| `output/NOCA_occ_stage.csv` | Adult/regeneration evidence only; no synthetic zero rows and no unsupported labels. |
| `output/NOCA_present_occ.csv`, `output/NOCA_past_occ.csv` | Period-specific occurrence components. |
| `output/NOCA_plot_info.csv` | Exactly the 307 paired plot IDs and their coordinates/elevation. |
| `output/NOCA_coordinate_collision_audit.csv` | Raw and normalized coordinates, elevations, shared-coordinate count, elevation range, and unresolved-retained status for `CARI449`/`CARI450`. |
| `output/NOCA_plot_tracking.csv` | Kept/removed plot accounting and reasons. |
| `output/NOCA_tree_correction_audit.csv` | One row per corrected target with removed/added counts, action, final status, and exclusion reason. |
| `output/NOCA_tree_composition_audit.csv` | Unpatched-versus-corrected present composition for all retained plots; 50 changes. |
| `output/NOCA_study_exclusions.csv` | The two explicit study exclusions and note provenance. |

The 1,790 rows include 18 explicit zero placeholders. Removing unsupported
identifications upstream adds two placeholders relative to the former downstream-
only exclusion, so consolidated row count changes while presence content and the
CCA result do not.

## Validation

Run immediately after cleaning:

```bash
Rscript R/000_NOCA_cleaning.R
Rscript R/test_NOCA_tree_corrections.R
Rscript R/test_check_vegetation.R
```

The focused patch test validates workbook shape, target coverage, exact audit
accounting, correction exclusions, changed-composition count, unsupported-label
absence, paired-plot count, uniqueness, study exclusions, and the sole exact
normalized-coordinate collision. The general
vegetation gate additionally requires the occurrence and plot-info universes to
match and both periods to contain the same 307 plots.
