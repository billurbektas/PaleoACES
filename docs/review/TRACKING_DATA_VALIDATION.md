# Lake-level tracking data validation

The primary 1,000-year run on 2026-10-08 uses the existing 100 whole chronology
draws and ten offsets. No climate downloads, chronology regeneration, additional
interval runs or statistical response models were performed.

The 2026-10-09 extension assembles a combined actual-transition input and
maintains provisional AR1/MA1/independent era/site comparisons separately at every offset.
It retires the earlier reporting-grid comparison input and exploratory model
script/outputs while preserving the source calculations and descriptive plots.

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
| `cca_tracking_era_by_offset.csv` | 7,920 | 28 | Actual Holocene lake × offset × transition × response, or modern plot × response, with dates, elapsed times, original predictors/support and WGS84 coordinates |

These outputs are written under `output/`. The [machine-readable schema](../assets/analysis/tables/tracking_schema.csv)
defines all 342 columns across the eight contracts. Stage 09b assembles the combined
input after stage 09 calculates the canonical records. The [output register](../OUTPUTS.md)
documents keys, units and suffix conventions. The [analysis review](../ANALYSIS_REVIEW.md)
contains focused excerpts of the maintained metric calculations and portable copies
of the compact inputs, uncertainty, modern calculations and support tables.
The exact column orders are specified in the output register. Fixed primary key
fixtures check 273 transitions and 607 pairs; uncertainty must contain 14 rows
per actual transition (3,822). These checks precede every primary export. A
changed key or row count stops execution with added/removed keys and climate
exclusion diagnostics; no filtering is adjusted and no observation is filled.

The offline tracking gate independently reconstructs each descriptive predictor
median from actual offset transitions using the original reporting rule. The
combined-input/model gate independently matches all seven responses, dates,
elapsed times, fire assignments, sampling support and WGS84 coordinates to
canonical source records. Original ID case remains, including `EAGl-120`; all
142 undefined modern angles remain rows with `response_valid = FALSE`.
Synthetic shifted intervals retain half-open reporting boundaries, covered zero
fire and missing coverage. Combined coordinate joins reject absent or ambiguous
locations. No global response-validity filter is introduced.

The new offset-0 AR1 coefficients and standard errors exactly reproduce the
previous offset-0 exploration (maximum absolute coefficient difference: zero).
Independent covariance checks confirm that MA1 correlations are zero at lags
greater than one, while AR1 preserves correlations across actual missing-time
gaps. The model gate checks all 120 coefficient rows, model type/offset keys,
t statistics, p values, interval bounds and observation counts. It also checks
all 60 park contrasts against the fitted coefficients: MORA uses the era term;
NOCA uses the era term plus the era/site interaction. Contrast signs, p values,
95% intervals and park-specific counts are verified. All 30 current fits
converge without warnings. The four diagnostic PDFs each have one page.
The new independent coefficients and era contrasts reconstruct the raw era/site
cell means. Explicit independent GLS refits reproduce their exported likelihoods.
The 30-row AIC comparison is checked against `-2 × logLik + 2 × n_parameters`
and its paired ΔAIC, weights and ranks are independently reconstructed.
Each candidate within an offset uses identical data and fixed effects.
All 80 pre-existing AR1/MA1 coefficient rows and 40 park-contrast rows are
exactly preserved (maximum absolute numerical differences: zero).
MA1 minimizes AIC at five offsets, independent residuals at four and AR1 at
one. AR1–MA1 AIC differences remain below 1.2 at every offset; the independent
candidate is within 1.71 of the minimum except at offset 900 (ΔAIC 3.30).
These checks validate implementation. On 2026-10-09 the author selected MA1
for the reported covariance structure. The review shows all three model
specifications and ΔAIC, followed by only MA1 results: 40 offset coefficients,
20 park contrasts, eight offset-0 lake coefficients and four lake contrasts.
Comparison records remain complete and numerically unchanged; the selected
figures share a theme and color. This covariance decision does not settle
distribution, lake effects or chronology uncertainty treatment.

The maintained offset-0 lake sensitivity produces eight fits, 16 coefficients
and eight era contrasts. The model gate independently matches each selected
Holocene lake to its canonical transitions and its park's original modern IDs,
checks coefficient/contrast signs, interval arithmetic and observation counts,
and verifies that missing transitions retain their time gaps. MORA fits use
330 modern pairs; NOCA uses 277. The Holocene counts are 7 Jay Bath, 7 Log
Wallow, 6 Reflection Pond and 10 Panther Potholes. Reflection Pond and Panther
Potholes MA1 fits approach -1; both are retained with explicit boundary flags.
The two lake-sensitivity PDFs are single-page MA1-only outputs at offset 0.
All offset/lake coefficient, contrast and comparison CSVs remain byte-identical
to their pre-selection calculations, as do source calculations, CCA, chronology
inputs and approved main figures. The changes affect reported figures,
selection/provenance notes and review presentation. MA(2) remains outside the workflow; the group-mean display is now maintained
for all maintained responses across all ten offsets.

## Group means and observed-turnover extension

The author requested MA1 fitted groups across all offsets and the same complete
exercise for `observed_turnover_rate` on 2026-10-09. This extension added turnover
to the two model stages' default responses, without changing the combined input or the
23/21-column canonical model tables. Each response exports 40 MA1 group means
in an 11-column table and the same five offset PDFs: means/differences,
coefficients, contrasts, residuals and ΔAIC. The lake sensitivity remains
at offset 0, with two MA1-only PDFs and complete AR1/MA1 audit records.

The gate independently reconstructs group means from the four fixed-effect
coefficients, matches observation counts to actual inputs and verifies every
mean/contrast interval. At offset 0 it checks SEs against X V X′ and verifies
that contrast variance includes covariance between fitted means. It repeats
coefficient, contrast, AIC, gap, lake-selection and interval checks for turnover.
All pre-existing lag coefficient, contrast and AIC CSVs remain byte-identical.
Scientific inputs, calibration, chronology, canonical tracking calculations
and Figures 2/3 remain unchanged.

All 60 offset fits and 16 lake fits converge without warnings. For turnover,
independent residuals minimize AIC at every offset and MA1 is within two units
of the minimum everywhere. MA1 is displayed as the requested working exercise,
with response-specific covariance evidence retained. Jay Bath’s turnover MA1
lake parameter approaches +1 and is retained with the boundary flag. Turnover
is nonnegative; some Gaussian Holocene mean intervals extend below zero and
remain visible without clipping. Distribution and final covariance treatment
remain open for turnover. Chronology uncertainty is not propagated and offsets
are not independent replicates.

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
  check links, generated source code, registries and the active manuscript figures.

The old tracking visualization and target-alignment stages, dedicated tests,
generated tables and former Figures 4/5 are retired through Git history. The worked
example now reads a Panther Potholes realization from the canonical lake table.

## Raw physical climate-rate GLS extension (2026-10-09)

The same maintained model stages now include `standardized_climate_change_rate`
on its original scale. Stage 10 fits ten offsets under AR1, MA1 and independent
residuals; stage 10a fits four offset-0 lake sensitivities under AR1 and MA1.
All 38 climate fits converge without warnings. MA1 results use the same figure
layouts and covariance-based group means and era contrasts as the two tracking
responses, with calibration SD per century replacing CCA units per century.

Focused checks in `R/tests/test_tracking_offset_models.R` verify all three
response sets: 120 coefficient rows, 60 contrasts, 30 comparison rows, 40 MA1
group means, 16 lake coefficients and eight lake contrasts per response.
Climate estimates match the canonical source column without transformation.
Repeated seven-response copies reduce to one observation, conflicting copies
stop selection, and tracking invalidity cannot exclude a finite climate value.
A missing climate value excludes only its own response and retains its identity
in the exclusion record. Independent fits verify cell means and AIC; a separate
MA1 fit verifies group-mean and contrast covariance. Time gaps remain intact.

All 1,443 pre-existing data/cache, output, model-result, figure and calibration
configuration files remain byte-identical to the pre-extension snapshot. No
canonical CSV schema, chronology, CCA calibration or Figure 3 output is changed.
The new climate set adds seven single-page diagnostic PDFs and separate CSV/TXT
outputs. Its covariance comparison favors independent residuals at four offsets,
MA1 at three and AR1 at three; MA1 remains the requested reporting specification.
Panther Potholes has a near-boundary MA1 lake fit and remains flagged. The raw-scale
Gaussian exercise does not select a transformation, propagate chronology uncertainty
or equalize the temporal averaging of Holocene and modern climate intervals.

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
that interaction, choose a final distribution/covariance, calculate contribution
attribution or replace the retired figures.

## Original offset-0 manuscript figure (2026-10-09)

This records the earlier display, replaced by the 2026-10-10 extension below.

Stage `R/stages/10b_tracking_manuscript_figure.R` reads the maintained combined
input and existing MA1 group-mean/contrast tables. The figure contains 1,911
untransformed input values across the three responses, 12 fitted means and
six contrasts. For each response, MORA has 20 Holocene transitions and 330
modern pairs; NOCA has 10 Holocene transitions and 277 pairs. The stage checks
group identities and sample counts, confirms each contrast equals its fitted
mean difference, and reads confidence bounds directly from the model records.
No fits or source CSVs are replaced. The preserved-file snapshot verifies
all 1,457 prior data, cache, output and figure files remain byte-identical,
including Figures 2/3 and every model result. The new Figure 4 is a distinct
producer; historical tracking visualizations remain retired.

## Corrected lag-rate models and anchored Figure 4 (2026-10-10)

The combined input retains 28 columns and now contains 7,920 rows: nine response
names for 273 transitions and 607 paired plots. The original 23/21-column tables,
15-column uncertainty, seven-response reporting and detailed calculation records
are unchanged. Pace/direction corrected rates are derived by the maintained
metric helper within each chronology draw before taking finite-draw transition
medians. Independent endpoint geometry reproduces both corrected responses for
every lake and modern pair. Within each realization, observed rate minus its
correction effect equals the corrected rate; subtraction of summary medians is
explicitly tested and rejected as an equivalent calculation.

All five requested responses pass the model gate: 120 coefficients, 60 contrasts,
30 covariance comparisons and 40 MA1 means across ten offsets, plus 16 lake
coefficients and eight lake contrasts at offset 0 per response. All fits converge.
MA1 remains the reporting covariance; AR1/independent comparisons remain audits.
Pace alone excludes 142 stationary modern pairs, leaving 254 MORA and 211 NOCA.
Direction retains all 607 pairs. Empty corrected groups preserve observation
identities and other finite responses. Corrupted draw counts, conflicting elapsed
times and missing calculation identities stop assembly before export.
Reflection Pond's corrected-pace MA1 lake fit approaches the parameter boundary;
Jay Bath, Log Wallow and Reflection Pond direction-corrected MA1 lake fits do too.
They remain explicitly flagged, not excluded. These are exploratory sensitivities.

The final figure verifies 20 offset-0 MA1 means, ten contrasts and 3,043 finite
untransformed values. Its upper row shows climate, turnover and three lag variants
with aligned zeros on their separate unit scales. Its lower row contains 1,132
finite scatter points: 60 Holocene, 607 modern direction and 465 modern pace.
Spearman coefficients/p values are independently reproduced from those same
points. Observed-rate densities use 30 Holocene transitions and 607 modern pairs
once each, with original observed-lag model means and intervals. Corrected
marginal distributions, title, caption and count subtitles are absent.

[Preservation fingerprints](TRACKING_CORRECTED_RATE_PRESERVATION.csv) confirm
17 protected input/calculation/calibration/chronology/Figure-2/3 files and all
12 original numerical model CSVs remain byte-identical. Offline metric, model,
workflow, figure-contract, documentation and portable review checks pass.
The Analysis Review and generated R reading copy expose the focused corrected-rate
calculation directly from the maintained helper and register all new diagnostics.
No chronology regeneration, downloads, model transformation or merge occurs.
