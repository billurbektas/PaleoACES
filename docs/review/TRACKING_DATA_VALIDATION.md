# Lake-level tracking data validation

The primary 1,000-year run on 2026-10-08 uses the existing 100 whole chronology
draws and ten offsets. No climate downloads, chronology regeneration, additional
interval runs or statistical response models were performed.

The 2026-10-09 extension adds the long era comparison from these existing
calculation records. All 898 snapshotted data/cache and figure files remain
byte-identical; only the schema dictionary and new comparison product change.

## Data contracts

| Output | Rows | Columns | Unit of observation |
|---|---:|---:|---|
| `cca_tracking_holocene_lake_realizations.csv` | 26,168 | 138 | Lake × whole chronology draw × offset × actual adjacent transition |
| `cca_tracking_holocene_lake_by_offset.csv` | 273 | 23 | Lake × offset × actual transition: fixed predictors, seven response medians and sampling support |
| `cca_tracking_anthropocene_plot_model_input.csv` | 607 | 21 | Paired modern plot: original ID, known dates, both elapsed times, binary fire, seven responses and validity flags |
| `cca_tracking_holocene_lake_uncertainty.csv` | 3,822 | 15 | Lake × offset × actual transition × response × sampling rule |
| `cca_tracking_anthropocene_plot_calculations.csv` | 607 | 79 | Detailed modern calculation record, preserving endpoints, seasonal climate and provenance |
| `cca_tracking_holocene_lake_timeseries.csv` | 1,657 | 15 | Lake × one of seven responses × descriptive 100-year reporting date |
| `cca_tracking_holocene_lake_support.csv` | 40 | 23 | Lake × offset, including exclusions and two-sample sensitivity support |
| `cca_tracking_era_comparison.csv` | 5,906 | 16 | Holocene lake × reporting date × response, or modern plot × response, with aligned predictors, offset sensitivity, dates and WGS84 coordinates |

These outputs are written under `output/`. The [machine-readable schema](../assets/analysis/tables/tracking_schema.csv)
defines all 330 columns across the eight contracts. The [output register](../OUTPUTS.md)
documents keys, units and suffix conventions. The [analysis review](../ANALYSIS_REVIEW.md)
contains focused excerpts of the maintained metric calculations and portable copies
of the compact inputs, uncertainty, modern calculations and support tables.
The exact column orders are specified in the output register. Fixed primary key
fixtures check 273 transitions and 607 pairs; uncertainty must contain 14 rows
per actual transition (3,822). These checks precede every primary export. A
changed key or row count stops execution with added/removed keys and climate
exclusion diagnostics; no filtering is adjusted and no observation is filled.

The extended offline tracking gate independently reconstructs every comparison
response and aligned predictor median/sample SD from actual offset transitions.
It checks all original modern responses (including 142 undefined angle values),
resurvey years, fire assignments and coordinate joins against the original plot
and lake locations. Original ID case is retained, including `EAGl-120`.
Synthetic shifted intervals verify half-open boundaries, response-specific
eligibility, missing fire coverage, covered zero fire, single-offset undefined
SDs, and rejection of absent or ambiguous coordinates. No global response
validity filter is introduced, and modern `t` remains `NA`.

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
  the baseline, including species and climate contribution panels. The CCA
  reference and scaling, chronology-draw cache, chronology inputs, stored
  posteriors/configurations and their maintained sources are unchanged. The
  [preservation evidence](TRACKING_COMPACT_PRESERVATION.csv) records 59
  successful SHA-256 comparisons, including byte-identical lake realizations,
  lake support and all 79 fields in the detailed modern record.
- All retained shared quantities match the previous NOCA output across all
  9,200 Panther Potholes realizations, with maximum absolute difference zero.
  The [full comparison by quantity](NOCA_TRACKING_MIGRATION_CHECK.csv) and the
  fixed 29-row fixture in `R/tests/fixtures/cca_noca_tracking_baseline.csv`
  preserve compact regression evidence. Counterfactual endpoints/effects are
  new quantities and are checked independently against known geometry.
- All 607 modern identities and retained shared quantities agree with the
  pre-migration output, allowing only CSV floating-point roundoff. For this
  compact-table refactor, the separate modern calculations CSV is byte-identical
  to the prior 79-column modern output. Its 21 model columns match those detailed
  records exactly, including validity flags, dates and the two burned MORA plots.
- Independent checks cover counterfactual origins and signs, nonadditivity,
  unequal elapsed times, opposing and stationary movement, and undefined
  directions without losing usable lag or turnover.
- Unique keys, consecutive bins and every lake-specific native climate
  endpoint are checked. MORA formulas are verified independently using each
  lake's actual WA/LC endpoints and elapsed times, without requiring historical
  pooled-site agreement. Every response's median, chronology quantiles and all
  support counts are reconstructed from realizations under both sampling rules.
  A synthetic case distinguishes an undefined present response from 98 absent
  draws; empty sensitivity groups remain explicit with missing statistics.
- Every reporting estimate, chronology bound, phase range and support field is
  independently reconstructed through the draw → actual transition/offset →
  half-open date mapping → across-offset hierarchy. All 1,657 retained reporting
  rows match their prior values exactly. Only angle and pace effect at Reflection
  Pond, 5,900 cal BP, are removed for nine-of-ten finite offset support. The other
  five responses and the transition-level model/uncertainty records remain.
  Eligibility is tested separately for every response.
- Fire checks cover half-open boundaries, covered zeros, insufficient core
  coverage, equal-core MORA exposure and numerator/reference compatibility.
  The primary stage verifies agreement with existing 1,000-year references;
  a small in-memory 500-year fixture checks interval propagation and the
  recalculated denominator without writing alternative-width products. A
  300-year in-memory fixture also verifies date mapping for 50-year endpoint
  midpoints, preserving the half-open boundary convention.
- All scientific gates in the offline workflow pass. Fresh sessions and
  repeated isolated execution of the canonical tracking stage reproduce
  identical scientific output hashes. The independent method audit passes
  [564 checks](TRACKING_INDEPENDENT_CHECKS.csv), including independently
  reconstructed CCA inertia, physical climate changes and the
  draw-to-offset-to-reporting hierarchy. Documentation and report validation
  check links, generated source code, registries and the two active figures.

The old tracking visualization and target-alignment stages, dedicated tests,
generated tables and Figures 4/5 are retired through Git history. The worked
example now reads a Panther Potholes realization from the canonical lake table.

## Limits for later modeling

Chronology draws, offsets and reporting dates represent uncertainty or
overlapping temporal support, not independent replicates. The 273 Holocene
rows span ten alternative placements. The intended primary approach is to
analyze non-overlapping transitions separately within each offset, considering
lake identity and temporal dependence during later model development. Adjacent
transitions share endpoint information. Draw distributions are conditional on
valid realizations; a one-draw transition has coincident chronology quantiles
without information about a wider distribution.
No majority threshold has been selected for future modeling.

Only four vegetation lakes and two regional fire histories are represented.
The sparse MORA transitions and shared MORA exposure give limited independent
support for a three-way interaction. Evaluating such an interaction will need
an explicit estimand, an assessment of predictor overlap and independent
support, and an uncertainty/inclusion strategy. This validation does not fit
that interaction, choose distributions, add AR(1), calculate contribution
attribution or replace the retired figures.
