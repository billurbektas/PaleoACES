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
| `cca_tracking_anthropocene_*.csv` | Plot-level tracking metrics and descriptive MORA/NOCA summaries |
| `cca_tracking_holocene_*.csv` | Primary 1,000-year realization, draw-within-offset, and full 100-year-grid tracking series; `_500yr` files are sensitivity outputs |
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

All five datasets are local reproducible CSVs in `output/`. The complete
column-by-column dictionary is `output/cca_tracking_schema.csv`, also exposed
in the Analysis Review. One metric implementation serves both eras.

| CSV | Unique key | Contents |
|---|---|---|
| `cca_tracking_holocene_lake_realizations.csv` | `site, lake, draw, offset, age_hi, age_lo` | WA/LC endpoints, focused responses, own-lake physical climate, interval charcoal activity, sample support and validity flags |
| `cca_tracking_holocene_lake_by_offset.csv` | `site, lake, offset, age_hi, age_lo` | Fixed climate/fire predictors and wide chronology distributions; primary prospective model input |
| `cca_tracking_anthropocene_plot_model_input.csv` | `site, plot_id` | All 607 original pairs, endpoints, survey/window dates, both elapsed times, physical climate, binary fire and focused responses |
| `cca_tracking_holocene_lake_timeseries.csv` | `site, lake, t, metric` | Descriptive 100-year grid; complete offset support within each lake, without cross-lake coverage restrictions |
| `cca_tracking_holocene_lake_support.csv` | `site, lake, offset` | Eligible samples, observed/retained/excluded realization counts, transitions, draw support, sample density and minimum-two-sample sensitivity |

`age_hi` is the older endpoint and `age_lo` the younger endpoint in calendar
years BP; their difference is the actual transition duration. `o1,o2` are
initial observed CCA1/CCA2; `o1_2,o2_2` are final observed coordinates. The `p`
columns follow the same convention for climate-predicted positions.

Metrics and units are authoritative in [Scientific Decisions](SCIENTIFIC_DECISIONS.md#lake-tracking-metrics).
CCA displacement/lag/effects use CCA units, their rates use CCA units/century,
ratios are unitless, and angles use degrees. Seasonal temperature changes use
°C; precipitation changes use mm; seasonal rates use those units/century.
`standardized_climate_change_rate` uses calibration SD/century.

In the wide table, `<metric>_mean`, `_sd`, `_median`, `_q025`, `_q25`, `_q75`
and `_q975` describe valid chronology draws. `<metric>_n_valid_draws` counts
finite values; `_n_missing_draws` is 100 minus that count; `_n_undefined_draws`
counts invalid values among present realizations. `n_present_draws` and
`n_absent_draws` distinguish chronology support from undefined response geometry.
Unprefixed `n_valid_draws,n_missing_draws` describe the primary lag-rate response.
Statistics with `_nmin2` restrict both endpoint bins to at least two vegetation
samples. Zero valid sensitivity draws have missing statistics and zero valid
count; they are not assigned zero responses. No majority threshold filters data.

`fire_activity` is the equal-core mean of normalized charcoal event frequency.
Each `fire_<core>_*` group provides its exact source ID, coverage bounds/fraction,
full-coverage and normalization flags, event count, frequency per 1,000 years,
maximum comparable-window frequency and normalized activity. MORA core labels
are `sunrise,shadow,little_sunrise`; NOCA is `panther`. Missing core coverage
produces missing counts, while a covered zero-event interval produces zero.
`fire_history_id` records shared regional exposure across MORA vegetation lakes.
`fire_window_years,fire_reference_window_years` must match the transition width.
`high_fire` uses the existing midpoint annotation with `high_fire_window_years=1000`.
Modern `burned` is binary and `fire_assignment_source` retains assignment provenance.

Reporting fields `age_q025,age_q975` are typical within-offset posterior
quantiles, while `phase_min,phase_max` describe offset-median spread. Neither
is an inferential confidence interval. Reporting rows, offsets and draws are
not independent observations for modeling.

The default 1,000-year stage has ten offsets and 100 cached whole chronologies.
A nondefault `--bin-width-years=N` must be a positive multiple of 100; Holocene
files acquire `_Nyr` suffixes and modern/primary outputs are not overwritten.
The separate 500-year stage, site-pooled metric products, compatibility files
and former Figures 4/5 are retired through Git history.

`cca_calibration_reference.rds` preserves the existing CCA fit, 607 calibration
identities and matrices, retained taxa, species/environmental scores, exact
modern endpoints, paleo sample positions, climate labels/units/scaling and
input/source provenance. Its portable formula environment supports later
prediction without refitting. No future contribution analysis is implemented.
The report registers a [versioned copy of this reference bundle](assets/analysis/cca_calibration_reference.rds)
so the existing fitted calibration remains available from the branch.
