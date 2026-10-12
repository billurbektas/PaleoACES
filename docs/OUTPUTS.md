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
| `cca_figure_biplot_annotations.csv`, `cca_figure_trajectory_display.csv` | Auditable Figure 3 annotation percentages, coordinates, path colors and opacity |
| `report/cca_species_contributions.csv`, `report/cca_climate_contributions.csv` | Species shares and unique climate effects on constrained inertia, calibration prevalence, CCA1–CCA2 scores and climate collinearity |
| `report/cca_model_code.R`, `report/cca_model_output.txt`, `report/cca_anova_output.txt` | Current fitting/projection code excerpt and readable model/permutation-test outputs displayed or linked immediately before Figure 3 |
| `plot/test_figures/plots_to_cca.pdf` | Single-page diagram showing starting counts, exclusion reasons, combined sample depths, legacy calibration counts and final paired/projection counts |
| `plot/test_figures/fig_holocene_sampling_fire_100yr.pdf` | Before-CCA diagnostic from the consolidation stage: separate macrofossil lake lines on a shared MORA/NOCA count scale, above summed accepted fire detections by park on native 100-year climate cells; grey marks inadequate charcoal coverage |
| `plot/test_figures/fig_cca_transition_species_boxplots.pdf`, `plot/test_figures/fig_cca_transition_climate_boxplots.pdf` | Fixed-CCA transition contributions: species rates and climate-variable displacements on the y-axis, with primary Holocene transitions and Anthropocene pairs shown once by park; workflow stage 16 |
| `plot/test_figures/worked_examples/fig_method_worked_example.pdf` | Actual primary Panther Potholes transition: WA/LC geometry, counterfactual endpoints, seven responses, endpoint samples and elapsed time |
| `plot/test_figures/fig_tracking_transition_rates.pdf` | Four lake columns × three rows: tracking rates together, standardized climate-change rate, and continuous fire activity, with established regional climate-period bands; a fifth column shows MORA/NOCA modern boxplots |
| `plot/test_figures/fig_tracking_transition_ratios_angles.pdf` | Four lake columns × four rows: magnitude ratio, angle, standardized climate-change rate, and fire activity, with the same regional climate-period bands; a fifth column shows MORA/NOCA modern boxplots |
| `cca_tracking_anthropocene_*.csv` | Compact paired-plot model input and separate detailed calculation records |
| `cca_tracking_holocene_*.csv` | Primary century positions, compact transitions, detailed calculations, original-sample projections, chronology realizations and support; no ecological offsets |
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
| `plot/fig_standardized_climate_change_eras_fire.pdf` | Main-paper PDF of signed Holocene climate change, readable variable-specific stability brackets near 10 ka, raw-rate comparison, and threshold-normalized MORA/NOCA fire-frequency ratios |
| `plot/test_figures/worked_examples/fig_holocene_climate_period_method_worked_example.pdf` | PDF-only worked example for the 50% threshold, phase support, any-variable union, no-gap rule, composite role, and independent fire rule |
| `plot/test_figures/worked_examples/fig_holocene_fire_method_worked_example.pdf` | PDF-only six-step worked example of accepted-event counting, core normalization, site aggregation, robust thresholding, and high-fire classification |
| `plot/test_figures/fig_walsh_charanalysis_reproduction.pdf` | PDF-only three-page official Walsh reconstruction and publication discrepancy audit |
| `plot/test_figures/worked_examples/fig_fire_event_detection_workflow.pdf` | PDF-only three-page explanation: detection settings, all four lake residual/threshold plots in a 2 × 2 grid, and the separate MORA software/publication comparison |
| `plot/fig_cca_trajectories.*` | Wider main-paper PDF/PNG with A. full species/climate biplot colored by constrained inertia and species occurrence percentages, beside B. zoomed pooled trajectories with opaque lighter predicted paths, joint annotation placement and a grey observed/predicted arrow legend |
| `plot/fig_tracking_era_distributions.*` | Manuscript Figure 4, panels A–D: climate and community/observed-lag era contrasts above Holocene/Anthropocene violin panels grouped by MORA/NOCA; observed green, pace pink, direction purple; GLS fitted means, conditional 95% intervals, zero-test stars, and significant paired correction contrasts |
| `plot/fig_tracking_predictor_era_coefficients.*` | Manuscript Figure 5: observed lag change and pace/direction correction-effect responses, Holocene and basic Anthropocene predictor effects, no intercepts; shared fire/climate slopes and NOCA − MORA site contrast, with R² in captions |
| `plot/test_figures/primary_models/fig_tracking_predictor_extended_coefficients.pdf` | Appendix extended Anthropocene coefficients; no intercepts, elevation per 100 m, R² in caption |
| `plot/test_figures/primary_models/fig_tracking_correction_effect_contrasts.pdf` | Separate primary pace- and direction-correction-effect contrasts; embedded in the Analysis Review |
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

Stage [07_tracking_metrics.R](../R/stages/07_tracking_metrics.R) produces primary
reconstructions from original samples and unrounded full-posterior median ages.
Native CHELSA cells are half-open; consecutive occupied cells form variable-duration transitions.
There is no vegetation interpolation or ecological bin-offset field.

| File under `output/` | Unit and purpose |
|---|---|
| `cca_tracking_holocene_century_positions.csv` | Lake × occupied primary century: mean sample WA, endpoint climate/LC, actual sample count and diagnostic chronology occupancy |
| `cca_tracking_holocene_century_draws.csv` | Lake × complete chronology draw × occupied century; diagnostic centroids and sample counts |
| `cca_tracking_holocene_lake_transitions.csv` | Compact primary lake-transition model input; nine responses, elapsed times, climate/fire and sample support |
| `cca_tracking_holocene_lake_calculations.csv` | Detailed primary geometry, coordinates, seasonal changes and validity |
| `cca_tracking_holocene_lake_support.csv` | Primary occupied centuries, transition durations, gaps and fire-coverage losses |
| `cca_tracking_holocene_sample_projections.csv` | Every original sample, its median age, WA eligibility and exclusions |
| `cca_tracking_holocene_sample_assignments.csv` | Primary native-cell assignment and exclusion provenance |
| `cca_tracking_holocene_fire_provenance.csv` | Per-core full-transition counts, coverage and events per century |
| `cca_tracking_holocene_fire_events.csv` | Fixed event identities and inferred NOCA depths with primary redated ages |
| `cca_tracking_holocene_posterior_rows.csv` | Reproducible selection of complete stored chronology rows |
| `cca_tracking_anthropocene_plot_model_input.csv` | Unchanged 21-column input for 607 modern plot pairs |
| `cca_tracking_anthropocene_plot_calculations.csv` | Unchanged detailed modern endpoints, dates, geometry and fire assignments |
| `cca_tracking_era_model_input.csv` | Primary lake transition / modern plot pair × response, with series and temporal indices; assembled by stage 11 |
| `cca_tracking_schema.csv` | Dataset, ordered column, storage type and units |

The seven common responses remain `lag_rate_per_century`, `observed_turnover_rate`,
`magnitude_tracking_ratio`, `rate_tracking_ratio`, `angle_degrees`,
`pace_effect_on_lag_per_century` and `direction_effect_on_lag_per_century`.
Auxiliary pace- and direction-corrected lag-change rates remain available for geometric auditing;
the modeled responses are observed lag change, turnover, standardized climate change and the two correction effects.
Individual undefined responses remain NA without removing the transition's other responses.

Fire activity is events per century per eligible core. Covered zero-event intervals
are zero; inadequate coverage is NA. MORA exposure is shared regionally for identical intervals.
The descriptive 1,000-year normalized fire measure and CC/S classification outputs are separate.

## Model records and chronology sensitivity

Primary combined-era results are under `output/tracking_analysis/primary/era_comparison/`.
Its `joint_correction_effects/` subfolder contains the additional paired pace/direction correction-effect model,
fitted means, zero tests, correction/era contrasts, exclusions, covariance audit and saved fit.
Joint residual diagnostics are in `plot/test_figures/primary_models/fig_tracking_joint_correction_residuals.pdf`. Lake comparisons
under `output/tracking_analysis/sensitivity/lake_checks/era_comparisons/`, community explanatory models under
`output/tracking_analysis/primary/community_predictor_models/`, and stage-17 models under `output/tracking_analysis/primary/species_contribution_models/`.
Each family exports coefficients, model/covariance selection, exclusions, saved fits,
performance, predictions and readable text. Combined models additionally export fitted
means and Anthropocene-minus-Holocene contrasts.

Bacon model sensitivity is **on hold for both community and species models**. Default runs
skip it; a future explicit `--bacon-sensitivity` run can resume fingerprinted batches.
Saved results are historical or incomplete (the community run was interrupted), and are
excluded from the current review. Preserved Bacon records are separate under `output/tracking_analysis/sensitivity/bacon_chronologies/community/`
and `output/tracking_analysis/sensitivity/bacon_chronologies/species/`:

- `chronology_coefficients.csv`: draw × response/species × coefficient, SE and conditional CI.
- `chronology_status.csv`: all 1,000 requested outcomes per response/species, including failed or structurally unestimable models.
- `chronology_support.csv`: lake/draw transition counts, durations, gaps and coverage losses.
- `chronology_summary.csv`: primary estimate/CI, sensitivity quantiles, magnitude range, sign and interval-conclusion consistency, with explicit denominators.
- `chronology_temporal_ranges.csv` in the community output directory: finite-draw 50%/95% ranges and availability for transition-average values covering each native century.
- `chronology_batches/`: fingerprinted, resumable draw records, fitted models and detailed calculation records.

`output/chronology_reconstruction/` preserves the original-sample draw cache and
prepared reconstruction data. No MCMC is performed. Primary confidence intervals
condition on the median-age reconstruction; sensitivity quantiles are not conventional
confidence intervals or posterior probabilities.

## Contributions and figures

Stage 16 exports separate species and seasonal climate contribution records under
`output/cca_transition_contributions/`. Species parallel contributions are rates;
climate-variable parallel contributions remain displacements. Raw vectors and weight
changes remain available. No perpendicular contributions or climate-variable models are included.

Model PDFs are grouped under `plot/test_figures/primary_models/`,
`plot/test_figures/sensitivity/bacon_chronologies/`, and
`plot/test_figures/sensitivity/lake_checks/`. Worked examples are under `plot/test_figures/worked_examples/`; other descriptive/calculation
figures remain directly under `plot/test_figures/`. Figure 4 retains
`plot/fig_tracking_era_distributions.pdf` and PNG. Actual-transition displays replace
phase trajectories, and primary covariance comparisons replace phase AIC boxplots.
The [figure migration manifest](review/TRACKING_FIGURE_MIGRATION.csv) records adaptations,
renames, additions and retirements. The descriptive climate/fire Figure 2 is unchanged.

When sensitivity is enabled, detailed draw calculations are streamed into the Bacon sensitivity directories as
`community/transition_calculations.csv.gz` and `species/species_contributions.csv.gz`.
Compression does not change the long-format observational unit.

The retained historical `plot/test_figures/sensitivity/bacon_chronologies/fig_tracking_bacon_chronology_ranges.pdf` shows temporal ranges across
the 1,000 complete reconstructions, primary transition spans and draw availability. These
are chronology sensitivity ranges, separate from conditional model confidence intervals.
Contribution boxplots show primary transition/plot distributions, not Bacon draws or offsets.

Each combined-era model PDF contains the same five response pages: observed lag change,
community turnover, standardized climate change, pace correction effect, direction correction
effect. Group means, coefficients, contrasts, residuals and AIC comparisons each have one
PDF, rather than five separate metric files. Lake coefficients and contrasts use the same
page order in their two consolidated PDFs. Primary results stay separate from sensitivity
results; `covariance_comparison.csv` contains diagnostic candidates and the declared primary
MA(1) indicator. Lake random-intercept results are under
`output/tracking_analysis/sensitivity/lake_checks/random_intercepts/`.

The main predictor coefficient figure shows observed lag-change rate and pace/direction
correction effects, with Holocene and Anthropocene panels and response-specific descriptive R².
