# Lake-level tracking data validation

The primary 1,000-year run on 2026-10-08 uses the existing 100 whole chronology
draws and ten offsets. No climate downloads, chronology regeneration, additional
interval runs or statistical response models were performed.

## Data contracts

| Output | Rows | Columns | Unit of observation |
|---|---:|---:|---|
| `cca_tracking_holocene_lake_realizations.csv` | 26,168 | 138 | Lake × whole chronology draw × offset × actual adjacent transition |
| `cca_tracking_holocene_lake_by_offset.csv` | 273 | 607 | Lake × offset × actual transition, with response distributions and fixed predictors |
| `cca_tracking_anthropocene_plot_model_input.csv` | 607 | 79 | Paired modern plot, retaining its original ID, endpoints, dates and binary fire assignment |
| `cca_tracking_holocene_lake_timeseries.csv` | 4,029 | 15 | Lake × response quantity × descriptive 100-year reporting date |
| `cca_tracking_holocene_lake_support.csv` | 40 | 23 | Lake × offset, including exclusions and two-sample sensitivity support |

These outputs are written under `output/`. The [machine-readable schema](../assets/analysis/tables/tracking_schema.csv)
defines all 862 columns across the five contracts. The [output register](../OUTPUTS.md)
documents keys, units and suffix conventions. The [analysis review](../ANALYSIS_REVIEW.md)
contains the maintained calculation code and portable copies of the wide, modern
and support tables.

## Observed support

| Lake | Eligible samples | Transitions per offset, any draw | Transitions per offset, ≥50 draws | Minimum present draws | Transitions present in <10 draws, across offsets | Incomplete-climate realization exclusions, across offsets |
|---|---:|---|---|---:|---:|---:|
| Jay Bath | 48 | 6–7 | 6 | 13 | 0 | 898 |
| Log Wallow | 40 | 6–7 | 6 | 2 | 1 | 899 |
| Reflection Pond | 29 | 5–6 | 5–6 | 1 | 3 | 897 |
| Panther Potholes | 790 | 9–10 | 9–10 | 100 | 0 | 1,444 |

The ≥50-draw column is descriptive; it does not filter the exported tables.
The 273 actual transition rows include 63 Jay Bath, 62 Log Wallow,
56 Reflection Pond and 92 Panther Potholes rows across offsets. The exclusion
counts refer to draw/offset realizations whose observed adjacent bins existed
but at least one climate endpoint lacked a complete native window. They are
not counts of independent transitions.

All exported transitions currently have covered, normalizable fire exposure.
MORA's three vegetation lakes share the equal-core regional history from
Sunrise, Shadow and Little Sunrise; NOCA uses Panther Potholes. Core reference
maxima are 3 events/1,000 years for each MORA core and 11 for Panther Potholes.
No current exported transition has zero regional activity; synthetic checks
therefore explicitly verify covered zero-event intervals and missing coverage.
The existing high-fire label is a descriptive, midpoint annotation with its
original 1,000-year temporal support.

In the modern table, 142 plots have stationary observed vegetation. Their
turnover and lag responses remain available; their pace counterfactual and
angle are undefined. The other 465 plots have defined angles and pace effects.

## Preservation and checks

- The pooled CCA remains 607 matched legacy plots and 14 taxa, including
  ponderosa pine. Calibration matrices and identities, numerical fitted
  components, eigenvalues, species scores and climate scores agree with the
  pre-migration snapshot. The [versioned reference bundle](../assets/analysis/cca_calibration_reference.rds) preserves that fit,
  its matrices, scaling, scores and provenance.
- Figure 3 PDF/PNG and both authoritative centroid CSVs are byte-identical to
  the baseline. The chronology-draw cache and all seven checked Bacon
  posterior/configuration pairs are also byte-identical: 19 protected files.
- All retained shared quantities match the previous NOCA output across all
  9,200 Panther Potholes realizations, with maximum absolute difference zero.
  The [full comparison by quantity](NOCA_TRACKING_MIGRATION_CHECK.csv) and the
  fixed 29-row fixture in `R/tests/fixtures/cca_noca_tracking_baseline.csv`
  preserve compact regression evidence. Counterfactual endpoints/effects are
  new quantities and are checked independently against known geometry.
- All 607 modern identities and retained shared quantities agree with the
  pre-migration output, allowing only CSV floating-point roundoff.
- Independent checks cover counterfactual origins and signs, nonadditivity,
  unequal elapsed times, opposing and stationary movement, and undefined
  directions without losing usable lag or turnover.
- Unique keys, consecutive bins and every lake-specific native climate
  endpoint are checked. Every response's mean, SD, median, quantiles and
  valid/missing counts are reconstructed from realizations, including the
  minimum-two-samples sensitivity. A synthetic case distinguishes an
  undefined present response from 98 absent draws.
- Fire checks cover half-open boundaries, covered zeros, insufficient core
  coverage, equal-core MORA exposure and numerator/reference compatibility.
  The primary stage verifies agreement with existing 1,000-year references;
  a small in-memory 500-year fixture checks interval propagation and the
  recalculated denominator without writing alternative-width products.
- All scientific gates in the offline workflow pass. Fresh sessions and
  repeated isolated execution of the canonical tracking stage reproduce
  identical scientific output hashes. The independent method audit passes
  501 checks, including CCA inertia, physical climate changes and the
  draw-to-offset-to-reporting hierarchy. Documentation and report validation
  check links, generated source code, registries and the two active figures.

The old tracking visualization and target-alignment stages, dedicated tests,
generated tables and Figures 4/5 are retired through Git history. The worked
example now reads a Panther Potholes realization from the canonical lake table.

## Limits for later modeling

Chronology draws, offsets and reporting dates represent uncertainty or
overlapping temporal support, not independent replicates. Draw distributions
are conditional on the transition being valid; a one-draw transition has no
estimable draw SD and its quantiles describe that single realization.
No majority threshold has been selected for future modeling.

Only four vegetation lakes and two regional fire histories are represented.
The sparse MORA transitions and shared MORA exposure give limited independent
support for a three-way interaction. Evaluating such an interaction will need
an explicit estimand, an assessment of predictor overlap and independent
support, and an uncertainty/inclusion strategy. This validation does not fit
that interaction, choose distributions, add AR(1), calculate contribution
attribution or replace the retired figures.
