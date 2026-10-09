# Analysis outputs

All filenames below are relative to `output/` unless a full project path is shown.
Active data and cache locations are preserved. See [repository inventory](REPOSITORY_INVENTORY.md) for archives and producers.


| Output | Contents |
|---|---|
| `MORA_occ.csv`, `NOCA_occ.csv`, `paleo_occ.csv` | Standardized plot/sample × species occurrences |
| `NOCA_tree_correction_audit.csv` | Corrected rows, action, inclusion, and exclusion reason |
| `NOCA_tree_composition_audit.csv` | Unpatched versus corrected present composition; 50 modeled plots change |
| `NOCA_study_exclusions.csv` | Exclusion reasons and source notes for `BAK487`, `BEAV6061`, `CARI449` and `CARI450` |
| `NOCA_coordinate_collision_audit.csv` | Raw/normalized coordinates and excluded status for GPS problems for the sole exact collision, `CARI449`/`CARI450` |
| `*_plot_info_fire.csv` | Modeling plot coordinates and fire classification |
| `NOCA_fire_assignment_audit.csv` | NOCA fire years, basis, and assignment provenance |
| `NOCA_fire_Wilson2024_comparison.csv` | PaleoACES versus publication universe and assignments |
| `MORA_climate.csv`, `NOCA_climate.csv`, `paleo_env.csv` | Climate inputs used by the CCA |
| `occ_consolidated.csv` | Harmonized occurrence table used by the model |
| `cca_sample_eligibility.csv`, `cca_pair_eligibility.csv` | CCA-stage per-observation and paired-plot audits: recorded presence, taxon filtering, climate validity, local reasons, calibration membership and shared WA/LC comparison membership |
| `cca_eligibility_counts.csv`, `cca_exclusion_summary.csv` | Totals and exclusion reasons for each site, era and use; shown immediately before CCA in the analysis review |
| `report/sample_selection_counts.csv`, `report/sample_selection_choices.csv` | Counts from the starting survey lists and core depths through matching, cleaning and CCA selection; choices that change records without removing plots are listed separately |
| `report/sample_selection_plot_sizes.csv` | Legacy adult-tree areas among the plots retained for CCA, with counts and the confirmed 500 m² resurvey area at both sites |
| `report/cca_anova.csv`, `report/cca_anova_full.csv` | Overall, sequential-axis and marginal climate-variable permutation tests of the fitted CCA; 9,999 permutations both unrestricted and within parks |
| `report/cca_species_contributions.csv`, `report/cca_climate_contributions.csv` | Species shares and unique climate effects on constrained inertia, calibration prevalence, CCA1–CCA2 scores and climate collinearity |
| `report/cca_model_code.R`, `report/cca_model_output.txt`, `report/cca_anova_output.txt` | Current fitting/projection code excerpt and readable model/permutation-test outputs displayed or linked immediately before Figure 3 |
| `plot/test_figures/plots_to_cca.pdf` | Single-page diagram showing starting counts, exclusion reasons, combined sample depths, legacy calibration counts and final paired/projection counts |
| `plot/test_figures/fig_method_worked_example.pdf` | Panther Potholes realization: WA/LC geometry, counterfactual endpoints, seven responses and chronology-draw distributions |
| `plot/test_figures/fig_tracking_offset_rates.pdf` | Four lake columns × three rows: tracking rates together, standardized climate-change rate, and continuous fire activity, with established regional climate-period bands; a fifth column shows MORA/NOCA modern boxplots |
| `plot/test_figures/fig_tracking_offset_ratios_angles.pdf` | Four lake columns × four rows: magnitude ratio, angle, standardized climate-change rate, and fire activity, with the same regional climate-period bands; a fifth column shows MORA/NOCA modern boxplots |
| `cca_tracking_anthropocene_*.csv` | Compact paired-plot model input and separate detailed calculation records |
| `cca_tracking_holocene_*.csv` | Primary lake realizations, compact model input, long uncertainty, seven-response reporting and support; later width experiments receive `_Nyr` suffixes |
| `cca_tracking_climate_scaling.csv` | Fixed pooled-legacy means, SDs, units, and sample sizes used for standardized climate rates |
| `holocene_era_climate_*.csv` | Lake/site/phase signed changes, pooled-calibration standardization, regional phase scores, 50%-maximum thresholds, directional cells, and unthresholded composite |
| `holocene_era_grid.csv`, `holocene_era_catalog.csv`, `holocene_era_driver_subintervals.csv`, `holocene_era_climate_change_subphases.csv` | Exhaustive complete-domain CC/S cells, eight merged eras, every variable/direction interval, and auditable driver-trough subdivisions |
| `walsh_charanalysis_*.csv` | Pinned official-engine inputs, settings, series, events, FRIs, package/source hashes, publication regression, and comparison with the separate primary `tapas` catalog |
| `holocene_fire_source_*.csv`, `holocene_fire_tapas_manifest.csv` | Authoritative all-`tapas` source series, accepted events, settings, coverage, package version, and hashes; the official Walsh engine remains a separate audit |
| `fire_event_detection_lake_audit.csv` | Four-core comparison of engine, chronology, interpolation, background smoother, local threshold, candidates, count-screen rejections, and accepted events |
| `holocene_era_fire_*.csv` | Normalized core/site frequency, robust thresholds, all retained high-fire runs, and strength/background corroboration |
| `holocene_era_fire_threshold_ratio.csv` | Display audit for normalized site fire frequency divided by its frozen robust threshold; values above 1 retain the existing high-fire classification |
| `holocene_fire_method_worked_example.csv` | Exact core- and site-level arithmetic used in the 2,300 cal-BP fire worked example |
| `holocene_anthropocene_raw_climate_rate_comparison.csv` | Raw physical-rate comparison: maximum-absolute Holocene equal-site regional median after ten-offset aggregation and annualized Anthropocene plot-rate medians for the exact MORA/NOCA windows, all per century |
| `plot/fig_standardized_climate_change_eras_fire.*` | Main-paper PDF/PNG of signed Holocene climate change, readable variable-specific stability brackets near 10 ka, raw-rate comparison, and threshold-normalized MORA/NOCA fire-frequency ratios |
| `plot/test_figures/fig_holocene_climate_period_method_worked_example.pdf` | PDF-only worked example for the 50% threshold, phase support, any-variable union, no-gap rule, composite role, and independent fire rule |
| `plot/test_figures/fig_holocene_fire_method_worked_example.pdf` | PDF-only six-step worked example of accepted-event counting, core normalization, site aggregation, robust thresholding, and high-fire classification |
| `plot/test_figures/fig_walsh_charanalysis_reproduction.pdf` | PDF-only three-page official Walsh reconstruction and publication discrepancy audit |
| `plot/test_figures/fig_fire_event_detection_workflow.pdf` | PDF-only three-page explanation: detection settings, all four lake residual/threshold plots in a 2 × 2 grid, and the separate MORA software/publication comparison |
| `plot/fig_cca_trajectories.*` | Main-paper PDF/PNG with A. pooled trajectories, B. biplot inset, C. climate contributions, D. species contributions, eight independently positioned two-line path names, transparent predicted paths/annotations, and an arrow-only observed/predicted legend |
| `cca_trajectory_era_centroids.csv` | Site × CC1–S4 observed WA and predicted LC centroids used by the selected trajectories |
| `cca_trajectory_anthropocene_centroids.csv` | Exact legacy/resurvey WA and LC site means from identical valid paired plots at both dates, plus pair counts |
| `bacon_run_manifest.csv` | Seed, versions, settings/control/output hashes, the historical whole-script hash used for five chronology runs, and a separately checked chronology-code fingerprint; the recorded post-run revision is limited to PDF location and PNG persistence |

## Adult survey dates and the 2026-10-07 climate update

The cleaners produce `output/modern_plot_years.csv`, shared by climate preparation,
CCA projections and tracking. MORA also exports `MORA_resurvey_record_audit.csv`
(assigned dates and selected/discarded raw rows) and `MORA_resurvey_visit_audit.csv`
(visit counts). The received data remain unchanged.

The review includes the [95-plot source discrepancies](assets/analysis/tables/year_source_discrepancies.csv),
[13 repeat-visit selections](assets/analysis/tables/mora_repeat_visits.csv),
[actual window/count table](assets/analysis/tables/survey_climate_windows.csv) and
[before/after effects](assets/analysis/tables/survey_decision_effects.csv).
Full per-plot effects remain in `output/survey_window_plot_effects.csv`.
The fixed pre-update reference in `docs/report/survey_window_baseline.csv` makes
that dated comparison reproducible; it is not a second active analysis.

The dated [whole-output comparison](review/SURVEY_WINDOW_OUTPUT_CHANGES.csv)
accounts for all 115 pre-update scientific CSVs: 88 are byte-identical, six have
only provenance or ordering changes, and 21 change scientifically. It records
matching keys, added/removed rows, changed fields and before/after checksums.
Historical climate and Holocene values remain unchanged in the mixed tables.

## Canonical tracking schemas

Stage `R/stages/09_tracking_metrics.R` calculates lake and plot records once,
then separates the seven source, uncertainty, descriptive and audit tables.
Stage `R/stages/09b_tracking_model_data.R` assembles one combined transition
input from these calculations without recalculating responses.
The complete ordered column dictionary is `output/cca_tracking_schema.csv`,
also exposed in the Analysis Review. One metric implementation serves both eras.

| CSV | Columns | Unique key | Role |
|---|---:|---|---|
| `cca_tracking_holocene_lake_by_offset.csv` | 23 | `site, lake, offset, age_hi, age_lo` | Model input: fixed predictors, independently summarized response medians and sampling support |
| `cca_tracking_anthropocene_plot_model_input.csv` | 21 | `site, plot_id` | Model input: known dates, both elapsed times, binary fire, seven responses and validity flags |
| `cca_tracking_holocene_lake_uncertainty.csv` | 15 | `site, lake, offset, age_hi, age_lo, metric, sampling_rule` | Chronology distributions and response-specific support under both sampling rules |
| `cca_tracking_holocene_lake_realizations.csv` | 138 | `site, lake, draw, offset, age_hi, age_lo` | Calculation audit: original WA/LC endpoints, geometry, own-lake seasonal climate, fire provenance and validity flags |
| `cca_tracking_anthropocene_plot_calculations.csv` | 79 | `site, plot_id` | Detailed modern calculation audit, including endpoints, seasonal changes, climate windows and fire-assignment sources |
| `cca_tracking_holocene_lake_timeseries.csv` | 15 | `site, lake, t, metric` | Seven-response descriptive 100-year grid with response-specific complete offset support |
| `cca_tracking_holocene_lake_support.csv` | 23 | `site, lake, offset` | Sampling, draw support, observed/retained/excluded realization counts and minimum-two-sample sensitivity |
| `cca_tracking_era_by_offset.csv` | 28 | Holocene: `site, lake, offset, age_hi, age_lo, metric`; Anthropocene: `site, plot_id, metric` | Sole input to offset GLS fits: actual transitions and modern pairs, with dates, predictors, support, response validity and WGS84 coordinates |

The exact model and uncertainty column orders are:

**Holocene model input (23)**

```text
site, lake, offset, age_hi, age_lo, interval_mid_cal_bp,
vegetation_dt_years, climate_dt_years,
standardized_climate_change_rate, fire_activity, fire_coverage_valid, high_fire,
lag_rate_per_century, observed_turnover_rate, magnitude_tracking_ratio,
rate_tracking_ratio, angle_degrees, pace_effect_on_lag_per_century,
direction_effect_on_lag_per_century,
n_draws_present, n_draws_nmin2, n_samples_t1_median, n_samples_t2_median
```

**Anthropocene model input (21)**

```text
site, plot_id, vegetation_t1_year, vegetation_t2_year,
climate_t1_midyear, climate_t2_midyear, vegetation_dt_years, climate_dt_years,
standardized_climate_change_rate, burned,
lag_rate_per_century, observed_turnover_rate, magnitude_tracking_ratio,
rate_tracking_ratio, angle_degrees, pace_effect_on_lag_per_century,
direction_effect_on_lag_per_century,
angle_valid, pace_counterfactual_valid, direction_counterfactual_valid,
tracking_ratio_valid
```

**Holocene uncertainty (15)**

```text
site, lake, offset, age_hi, age_lo, metric, sampling_rule,
median, q025, q975, n_expected_draws, n_present_draws, n_eligible_draws,
n_valid_draws, n_undefined_draws
```

`age_hi` and `age_lo` are the older and younger **endpoint-bin midpoints**,
in cal BP; their difference is the actual transition duration.
`interval_mid_cal_bp` is their mean. The primary elapsed times are both 1,000
years. The seven Holocene responses are medians across finite draws, calculated
independently for each response. `n_draws_present` counts existing transitions
before response-validity filtering; `n_draws_nmin2` counts present transitions
with at least two macrofossil samples in both endpoint bins. No majority threshold
filters either the model table or its underlying realizations.

The uncertainty table retains seven metrics × two sampling rules (`all`, `nmin2`)
for every actual transition. Expected draws are 100; present draws contain the
transition; eligible draws satisfy the sampling rule; valid draws have a finite
response; undefined draws equal eligible minus valid. Absent draws equal expected
minus present. Empty eligible or valid groups have `NA` statistics and zero
valid counts. These rows describe unavailable distributions without inventing
observations. Quantiles describe chronology uncertainty conditional on valid
realizations, not confidence intervals from a fitted model.

Definitions and units are authoritative in [Scientific Decisions](SCIENTIFIC_DECISIONS.md#lake-tracking-metrics).
CCA rates use CCA units/century, ratios are unitless, angles use degrees and
`standardized_climate_change_rate` uses calibration SD/century. The two tracking
ratios can differ in the Anthropocene because vegetation and climate elapsed
times differ. The counterfactual pace correction matches **displacement magnitude**.
The detailed audits preserve raw and standardized seasonal changes, supporting
geometry and coordinates; they contain no posterior-summary columns. Consumers
requiring modern endpoints or seasonal changes read the calculations CSV.

`fire_activity` is the equal-core mean of normalized event frequency. Detailed
lake records retain each core's source ID, coverage bounds/fraction, event count,
frequency per 1,000 years and maximum comparable-window frequency. MORA labels
are `sunrise,shadow,little_sunrise`; NOCA is `panther`. A covered zero-event
interval has zero activity. Inadequate coverage produces both `fire_activity=NA`
and `high_fire=NA`. MORA requires at least two covered cores, and all three
vegetation lakes share its regional exposure. Numerator and reference windows
have the same duration. `high_fire` remains a descriptive site label at the
transition midpoint from the existing 1,000-year classification. Modern `burned`
remains binary, with assignment provenance in the modern calculation audit.

The reporting grid contains only the seven response names. For each response,
finite chronology draws are summarized within actual transitions and offsets;
intervals are mapped to dates using `[age_lo, age_hi)`, then summarized across
offsets. A lake/date/response is reported only when **every configured offset**
has a finite transition median. Undefined angles or counterfactuals do not remove
other responses. `age_q025,age_q975` are medians of within-offset chronology
quantiles; `phase_min,phase_max` bound the offset medians. Support fields retain
observed offset counts and minimum draw presence. Neither interval is an
inferential confidence interval.

Stage 09b exports `cca_tracking_era_by_offset.csv` with exactly:

```text
era, site, lake, plot_id, offset, age_hi, age_lo, interval_mid_cal_bp,
vegetation_t1_year, vegetation_t2_year, climate_t1_midyear, climate_t2_midyear,
vegetation_dt_years, climate_dt_years, metric, estimate, response_valid,
standardized_climate_change_rate, fire_activity, fire_coverage_valid, high_fire,
burned, n_draws_present, n_draws_nmin2, n_samples_t1_median, n_samples_t2_median,
longitude, latitude
```

One row is one response for an actual lake/offset transition or modern pair.
The current file contains 6,160 rows: 273 transitions × seven responses plus
607 modern pairs × seven responses. Modern rows are stored once per response,
with `offset = NA`; every offset fit reuses the same modern observations.
Holocene estimates retain the finite-draw median within their actual transition;
there is no across-offset median or 100-year reporting-grid mapping. The physical
climate predictor and fire exposure are copied from that transition. Both elapsed
times and all original survey/climate midyears remain available.

`response_valid` is exactly `is.finite(estimate)`. Undefined responses remain
rows and are excluded only when that response is modeled. Inapplicable era
fields are `NA`: modern pairs have no cal-BP age, offset, lake, charcoal exposure
or chronology support; Holocene transitions have no survey calendar year or
binary burned assignment. WGS84 coordinates retain original identities and
normalized joins; missing or ambiguous locations stop export. The long layout
does not add ecological replicates. Alternative widths receive `_Nyr` suffixes.

Stage `R/stages/10_tracking_era_models.R` reads only the combined CSV and fits
lag-change rate, observed turnover and untransformed physical climate-change rate
separately for all ten offsets under AR1,
MA1 and no temporal autocorrelation
(`model_type=Independent`). Its initial fixed-effect specification remains exploratory: `estimate ~ era * site`,
REML, and separate residual SDs by era/site. All three responses run by default;
`--metric=NAME` selects one standalone response. Files below show lag rate;
the complete turnover and climate sets use `observed_turnover_rate` and
`standardized_climate_change_rate`, respectively, in place of `lag_rate_per_century`
in each directory and figure stem. Climate uses the existing physical-rate field
directly as the response, with one observation per transition or plot; the seven
tracking-response rows are not duplicate climate observations. No CSV schema
changes or response transformations are applied. Row counts apply
separately to each response. The primary outputs are:

| Output | Contents |
|---|---|
| `output/exploratory/tracking_offset_models/lag_rate_per_century/model_coefficients.csv` | 120 coefficient rows: four terms × ten offsets × three covariance types, flagged by `model_type`, with SEs, degrees of freedom, t statistics, p values, 95% intervals, group counts and fitted correlation parameter |
| `output/exploratory/tracking_offset_models/lag_rate_per_century/model_contrasts.csv` | 60 within-park Anthropocene-minus-Holocene contrasts: two parks × ten offsets × three covariance types, with SEs, Satterthwaite degrees of freedom, t statistics, unadjusted p values and 95% intervals, and park-specific observation counts |
| `output/exploratory/tracking_offset_models/lag_rate_per_century/model_results.txt` | One complete text record: provenance, fit overview, all 30 model summaries, park contrasts, residual SDs, warnings and diagnostic lag products |
| `output/exploratory/tracking_offset_models/lag_rate_per_century/model_comparison.csv` | 30 rows × 15 columns: response, offset, covariance type, Holocene/modern/total counts, method, parameter count, restricted log-likelihood, AIC, within-offset ΔAIC, relative Akaike weight, rank, correlation parameter and convergence |
| `output/exploratory/tracking_offset_models/lag_rate_per_century/model_group_means.csv` | 40 MA1-only rows × 11 columns: metric, offset, model_type, site, era, estimate, std_error, df, conf_low, conf_high, n |
| `plot/test_figures/fig_tracking_model_group_means_lag_rate_per_century.pdf` | Two park columns and three aligned rows: Holocene mean, Anthropocene mean and their difference, across all ten MA1 offsets; 95% Satterthwaite intervals; separate row scales and shared park scales within each row |
| `plot/test_figures/fig_tracking_model_coefficients_lag_rate_per_century.pdf` | MA1 only: 40 coefficients and unadjusted 95% t intervals across ten offsets |
| `plot/test_figures/fig_tracking_model_contrasts_lag_rate_per_century.pdf` | MA1 only: 20 era contrasts and unadjusted 95% intervals across ten offsets, with separate MORA and NOCA panels |
| `plot/test_figures/fig_tracking_model_residuals_lag_rate_per_century.pdf` | One page with one row per offset: scatter, Q-Q and Holocene lag products for the selected MA1 |
| `plot/test_figures/fig_tracking_model_aic_lag_rate_per_century.pdf` | Within-offset ΔAIC boxplots for the three candidates, with paired dots/lines for each offset |

The independent candidate uses `correlation=NULL` and retains the same era/site
residual variances. Its correlation parameter is `NA`. Each offset must use
identical observations across candidates before any results are exported. AIC
is `-2 × logLik + 2 × n_parameters`: nine parameters for AR1/MA1 and eight for
independent residuals. ΔAIC is relative to that offset’s lowest AIC, and relative
Akaike weights sum to one within its three candidates. REML is retained with
identical fixed effects and observations. The author selected MA1 on 2026-10-09
for reported results; all candidates remain in the calculation records. This
decision is recorded in `R/helpers/tracking_model_reporting.R`.
The boxes summarize sensitivity across offsets, not independent replicates;
selection uses paired within-offset differences rather than pooled raw AIC.

Modern pairs are singleton series. Holocene integer time indices retain gaps;
MA1 correlates only observations one actual time step apart. AICs compare
covariance choices within an offset; different offsets contain different
observations. The review shows the comparison first, followed by MA1-only
group means, coefficients, contrasts and residuals. Model inclusion, chronology uncertainty
and distribution choices remain exploratory. No lake random intercept or climate/fire fixed effects are
added to this initial model.

Stage `R/stages/10a_tracking_lake_sensitivity.R` then runs the agreed **offset-0
lake sensitivity**: each of the four Holocene lakes versus modern pairs from
its own park, under AR1 and MA1 (eight fits per response). The park is constant within each
fit, so the formula is `estimate ~ era`, with REML and separate era residual
SDs. The figures and review display MA1 only; the AR1 fits remain numerical
audit records. Time gaps and response-specific finite-value selection remain unchanged.

| Sensitivity output | Contents |
|---|---|
| `output/exploratory/tracking_lake_sensitivity/lag_rate_per_century/offset_0/model_coefficients.csv` | 16 rows: intercept and era coefficient for each lake and covariance type; lake/site identities, uncertainty, sample counts and correlation-boundary flags |
| `output/exploratory/tracking_lake_sensitivity/lag_rate_per_century/offset_0/model_contrasts.csv` | Eight Anthropocene-minus-Holocene contrasts, with Satterthwaite intervals, sample counts and boundary flags |
| `output/exploratory/tracking_lake_sensitivity/lag_rate_per_century/offset_0/model_results.txt` | All eight GLS summaries, era means, contrasts, warning records, boundary flags and provenance |
| `plot/test_figures/fig_tracking_lake_coefficients_lag_rate_per_century_offset_0.pdf` | MA1-only lake coefficients at offset 0; eight displayed estimates, separate scales for intercept and era effect |
| `plot/test_figures/fig_tracking_lake_contrasts_lag_rate_per_century_offset_0.pdf` | MA1-only lake contrasts at offset 0; four displayed estimates |

Triangles and `near_correlation_boundary` flag an absolute fitted correlation
parameter above 0.98; flagged fits remain in the outputs. The current Reflection
Pond and Panther Potholes MA1 parameters approach -1. MORA fits reuse the same
330 modern plots, so these are overlapping sensitivity comparisons. The workflow
runs offset 0 only; manual `--offset=N`, `--metric=NAME` and
`--bin-width-years=N` options write distinct offset/response/width products.
The maintained group-mean figure now shows MA1 across all ten offsets for all three
responses; it supersedes the earlier offset-0 preview. MA(2) remains outside
the workflow. Turnover has its own AIC comparison: independent residuals
minimize AIC at all offsets, with MA1 within two units everywhere. The requested
MA1 turnover exercise remains exploratory; its nonnegative response is not
transformed and unbounded Gaussian intervals are not clipped.

The climate exercise uses calibration SD per century, with the same 120
coefficients, 60 contrasts, 30 covariance comparisons, 40 MA1 group means,
one results TXT and five offset PDFs. Its offset-0 lake exercise adds 16
coefficients, eight contrasts, one TXT and two PDFs. Main results are under
`output/exploratory/tracking_offset_models/standardized_climate_change_rate/`;
lake results are under
`output/exploratory/tracking_lake_sensitivity/standardized_climate_change_rate/offset_0/`.
Independent residuals minimize climate AIC at four offsets, MA1 at three and
AR1 at three; MA1 remains the requested display choice. Panther Potholes has
a near-boundary MA1 lake parameter and is retained with its flag. Common
per-century units do not equalize Holocene and modern temporal averaging.

The previous combined reporting-grid CSV, exploratory modeling script and its
per-run inputs, model bundles, summaries and residual PDFs are retired. The
23/21-column canonical source tables, uncertainty and calculation records remain.
The maintained tracking figures reconstruct their aligned climate/fire context
directly from the source transitions and descriptive reporting dates.

The 273 primary Holocene rows span ten alternative bin placements. Offsets are
sensitivity realizations, not independent ecological replicates. The intended
primary modeling approach is to analyze non-overlapping transitions separately
within each offset, considering lake identity and temporal dependence during
later model development. Adjacent transitions share endpoint information.
Chronology draws and overlapping reporting dates are also not independent replicates.

The default stage uses ten offsets and 100 cached whole chronologies. A nondefault
`--bin-width-years=N` must be a positive multiple of 100; all five Holocene files
acquire `_Nyr` suffixes and modern/primary products remain untouched. Additional
widths are not run automatically. The separate 500-year wrapper, site-pooled
metric products, compatibility files and former Figures 4/5 are retired through
Git history. Primary expectations (273 model rows, 607 plot pairs and 3,822
uncertainty rows) are regression checks against fixed keys, verified before any
export is replaced. A discrepancy stops execution with changed-key and
incomplete-climate exclusion diagnostics; it never changes filtering to recover
an expected count.

`cca_calibration_reference.rds` preserves the existing CCA fit, 607 calibration
identities and matrices, retained taxa, species/environmental scores, exact
modern endpoints, paleo sample positions, climate labels/units/scaling and
input/source provenance. Its portable formula environment supports later
prediction without refitting. No future contribution analysis is implemented.
The report registers a [versioned copy of this reference bundle](assets/analysis/cca_calibration_reference.rds)
so the existing fitted calibration remains available from the branch.

## Tracking example and descriptive visualizations

`R/stages/09a_tracking_example_and_visualizations.R` reads the canonical stage-09
products and writes the three diagnostic PDFs listed above. Both descriptive
figures use four Holocene lake columns with aligned cal-BP axes and shared
scales across lakes within each row. The rates figure has three rows: the four
tracking rates together, standardized physical climate-change rate, and continuous
fire activity. The second figure gives magnitude ratio, angle, climate rate and
fire activity one row each. The duplicate Holocene rate-ratio display is omitted;
both ratios remain in both model tables and can differ in the Anthropocene.

Both figures read the established stage-13 `holocene_era_catalog.csv` and
`holocene_era_climate_change_subphases.csv`, the same sources as Figure 2.
Darker gray marks climate change (CC) and lighter gray relative stability (S)
across every Holocene row. Top-row labels show CC1a, CC1b and CC1c and the other
CC/S periods; dotted lines mark internal CC1 boundaries. These are regional
annotations shared across the four lakes. The margins outside the classified
9,600–1,300 cal-BP domain are unshaded. Bands are not added to modern boxplots.
The plotting stage does not recalculate eras, alter responses or add model fields.

Thin trajectories use each offset's transition values at `interval_mid_cal_bp`.
Response values are finite-draw medians. Thick response lines reuse the existing
100-year reporting-grid medians at `t`. Thick climate/fire context lines read
the aligned predictor medians reconstructed from the canonical transitions, requiring
complete finite offset support. The seven-response reporting CSV remains
unchanged. Missing transitions and undefined values break
lines; no extrapolation or smoothing is applied. All supported transition rows
remain visible, including sparse chronology support.

A fifth column shows MORA and NOCA boxplots of the same responses and climate
predictor, using matching colors and all original 607 paired plots. Finite values
are used separately for each metric, preserving valid responses when angle or
pace is undefined. The Anthropocene column has its own labeled y-scales because
the modern rates are substantially larger; the four Holocene columns retain
shared scales by row. Modern continuous charcoal fire activity is unavailable,
so that panel contains an annotation with no numeric fire axis. The original
binary `burned` assignments remain in the model input and are not substituted
for charcoal activity. MORA lakes share one regional fire history. Offsets are
sensitivity realizations, not independent ecological replicates.
