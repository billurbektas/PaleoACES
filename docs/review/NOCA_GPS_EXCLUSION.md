# NOCA GPS exclusions: CARI449 and CARI450

Decision date: 2026-10-06. The author requested exclusion of both plots if
Rachel's notes did not provide a satisfactory coordinate correction.

## Source review

- The three files in `notes_from_Rachel/` (`Missing trees.rtf`, `Burned plots.rtf`
  and `Review of tree species.rtf`) contain no correction for either plot.
- Rachel's email of 24 September 2024, on page 2 of
  `data/NOCA/Correspondance_Kavya&Rachel_September2024.pdf`,
  warns of a sorting problem in the 2014 master workbook's GPS sheet and directs
  readers to the paper repository's latitude/longitude CSV instead.
- The received `data/NOCA/NOCA_plots_fromWilson.csv` and the local paper-repository
  copy `data/NOCA/rachelnorawilson-cascades-shifts-4b7fd12/data/0_Lat.Long.csv`
  both retain the conflicting entries below. Their agreement does not supply a
  corrected location. The suspicious-data checklist contains no correction.

| Plot | Legacy ID | Latitude | Raw longitude | Normalized longitude | Elevation (m) |
|---|---|---|---|---|---|
| CARI449 | 7077 | 48.51429 | 121.21725 | -121.21725 | 622 |
| CARI450 | 7078 | 48.51429 | -121.21725 | -121.21725 | 1149 |

Correcting the longitude sign places the plots at the same horizontal location,
despite a 527 m elevation difference. Neither plot can be assigned a verified
replacement coordinate from the reviewed sources. This documents a GPS problem;
it does not establish which original entry is wrong.

## Implemented decision

Both plots are excluded at both dates in
[`000_NOCA_cleaning.R`](../../R/stages/000_NOCA_cleaning.R), before occurrence,
stage, coordinate, climate, fire, calibration or projection outputs are built.
The reason is **GPS problem; shared coordinates conflict with elevations; no
verified correction**. Raw inputs and native climate caches remain intact.

`NOCA_study_exclusions.csv` and `NOCA_plot_tracking.csv` record the exclusion;
`NOCA_coordinate_collision_audit.csv` preserves the original coordinate evidence
with an excluded status. This is a study-level GPS exclusion, separate from CCA
taxon eligibility and all-zero-row exclusions.

The NOCA cleaning universe changes from 307 to 305 paired plots (1,790 to 1,775
occurrence rows). Legacy calibration changes from 620 to 618 plots, and modern
CCA comparisons from 607 to 605 pairs (330 MORA, 275 NOCA). The CCA is refitted
with the same species rule, constraints and geometry. Consequently, downstream
coordinates and metrics for retained observations may also change. Chronology
controls and stored posteriors are not refitted.

The [analysis review](../ANALYSIS_REVIEW.md) contains current tables and figures;
the [scientific decisions](../SCIENTIFIC_DECISIONS.md#study-universes-and-vegetation)
records the adopted exclusion and its consequences.
