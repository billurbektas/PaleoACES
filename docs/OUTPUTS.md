# Analysis outputs

All filenames below are relative to `output/` unless a full project path is shown.
Active data and cache locations are preserved. See [repository inventory](REPOSITORY_INVENTORY.md) for archives and producers.


| Output | Contents |
|---|---|
| `MORA_occ.csv`, `NOCA_occ.csv`, `paleo_occ.csv` | Standardized plot/sample × species occurrences |
| `NOCA_tree_correction_audit.csv` | Corrected rows, action, inclusion, and exclusion reason |
| `NOCA_tree_composition_audit.csv` | Unpatched versus corrected present composition; 50 modeled plots change |
| `NOCA_study_exclusions.csv` | Study-level exclusion reasons and source notes for `BAK487` and `BEAV6061` |
| `NOCA_coordinate_collision_audit.csv` | Raw/normalized coordinates and excluded status for GPS problems for the sole exact collision, `CARI449`/`CARI450` |
| `*_plot_info_fire.csv` | Modeling plot coordinates and fire classification |
| `NOCA_fire_assignment_audit.csv` | NOCA fire years, basis, and assignment provenance |
| `NOCA_fire_Wilson2024_comparison.csv` | PaleoACES versus publication universe and assignments |
| `MORA_climate.csv`, `NOCA_climate.csv`, `paleo_env.csv` | Climate inputs used by the CCA |
| `occ_consolidated.csv` | Harmonized occurrence table used by the model |
| `cca_sample_eligibility.csv`, `cca_pair_eligibility.csv` | CCA-stage per-observation and paired-plot audits: recorded presence, taxon filtering, climate validity, local reasons, calibration membership and shared WA/LC comparison membership |
| `cca_eligibility_counts.csv`, `cca_exclusion_summary.csv` | Generated pre-fit totals and mutually exclusive exclusion reasons for each site, era and use; reproduced near the beginning of the analysis review |
| `cca_tracking_anthropocene_*.csv` | Plot-level tracking metrics and descriptive MORA/NOCA summaries |
| `cca_tracking_holocene_*.csv` | Primary 1,000-year realization, draw-within-offset, and full 100-year-grid tracking series; `_500yr` files are sensitivity outputs |
| `cca_tracking_climate_scaling.csv` | Fixed pooled-legacy means, SDs, units, and sample sizes used for standardized climate rates |
| `cca_tracking_visualization_points.csv` | Common Holocene site-date and Anthropocene plot source, plus compatibility aggregates; the active figure recalculates its summaries only from raw rows |
| `cca_tracking_holocene_era_coverage.csv` | Complete-ten-offset site-date coverage for every MORA/NOCA × CC/S combination, including explicit missing slots |
| `cca_tracking_interval_resolution_audit.csv` | Descriptive support, distribution, and matched-date comparison of primary 1,000-year and sensitivity 500-year tracking |
| `cca_tracking_comparison_summary.csv` | Independently calculated counts, medians, quartiles, and whiskers for fire-stratified main boxes, macro eras, NOCA Anthropocene fire status, and Holocene climate state × fire status across the four displayed metrics |
| `cca_tracking_anthropocene_fire_scope_audit.csv` | All 605 modern pairs with burned status, inclusion decision, and explicit exclusion of the two burned MORA pairs |
| `cca_tracking_comparison_spec.csv` | Auditable fixed-site facets, explicit era/state × fire grouping, raw-linear lag/rate/ratio/angle contracts, 589-point background, four macro medians, eight climate-state/fire medians, two NOCA fire-status medians, stationary-angle annotation, reference lines, symmetric raw-lag fill limits, and panel-width fractions |
| `cca_direction_anthropocene_realizations.csv`, `cca_direction_holocene_realizations.csv.gz` | All 10,285 modern and 259,590 primary Holocene unit × taxon/climate paired rows, with predicted and observed cosines, predicted-minus-observed contrasts, direct movement angle/cosine, and explicit validity flags |
| `cca_direction_holocene_by_offset.csv.gz`, `cca_direction_holocene_timeseries.csv` | 2,635 draw-within-offset and 2,329 complete-ten-offset site-date directional-difference summaries using the tracking stage's half-open mapping |
| `cca_direction_group_summaries.csv`, `cca_direction_scope_audit.csv` | All 204 descriptive site × climate/fire or site × burned summaries, support/NA counts, geometry settings, and upstream hashes; no rankings |
| `holocene_era_climate_*.csv` | Lake/site/phase signed changes, pooled-calibration standardization, regional phase scores, 50%-maximum thresholds, directional cells, and unthresholded composite |
| `holocene_era_grid.csv`, `holocene_era_catalog.csv`, `holocene_era_driver_subintervals.csv`, `holocene_era_climate_change_subphases.csv` | Exhaustive complete-domain CC/S cells, eight merged eras, every variable/direction interval, and auditable driver-trough subdivisions |
| `walsh_charanalysis_*.csv` | Pinned official-engine inputs, settings, series, events, FRIs, package/source hashes, publication regression, and comparison with the separate primary `tapas` catalog |
| `holocene_fire_source_*.csv`, `holocene_fire_tapas_manifest.csv` | Authoritative all-`tapas` source series, accepted events, settings, coverage, package version, and hashes; the official Walsh engine remains a separate audit |
| `fire_event_detection_lake_audit.csv` | Four-core comparison of engine, chronology, interpolation, background smoother, local threshold, candidates, count-screen rejections, and accepted events |
| `holocene_era_fire_*.csv` | Normalized core/site frequency, robust thresholds, all retained high-fire runs, and strength/background corroboration |
| `holocene_era_fire_threshold_ratio.csv` | Display audit for normalized site fire frequency divided by its frozen robust threshold; values above 1 retain the existing high-fire classification |
| `holocene_fire_method_worked_example.csv` | Exact core- and site-level arithmetic used in the 2,300 cal-BP fire worked example |
| `offset_timeseries*.csv` | Backward-compatible LC-predicted vegetation, observed vegetation, and offset data; no offset figures are generated |
| `plot/fig_tracking_comparison.*` | Main-paper PDF/PNG with equal-width fixed-site-facet boxplot/detail panels A–C (lag rate, ratio, angle) and a centered 75%-width panel-D angle × tracking-ratio scatter; pooled state labels list their exact represented CC/S eras |
| `holocene_anthropocene_raw_climate_rate_comparison.csv` | Raw physical-rate comparison: maximum-absolute Holocene equal-site regional median after ten-offset aggregation and annualized Anthropocene plot-rate medians for the exact MORA/NOCA windows, all per century |
| `plot/fig_standardized_climate_change_eras_fire.*` | Main-paper PDF/PNG of signed Holocene climate change, readable variable-specific stability brackets near 10 ka, raw-rate comparison, and threshold-normalized MORA/NOCA fire-frequency ratios |
| `plot/test_figures/fig_holocene_climate_period_method_worked_example.pdf` | PDF-only worked example for the 50% threshold, phase support, any-variable union, no-gap rule, composite role, and independent fire rule |
| `plot/test_figures/fig_holocene_fire_method_worked_example.pdf` | PDF-only six-step worked example of accepted-event counting, core normalization, site aggregation, robust thresholding, and high-fire classification |
| `plot/test_figures/fig_walsh_charanalysis_reproduction.pdf` | PDF-only three-page official Walsh reconstruction and publication discrepancy audit |
| `plot/test_figures/fig_fire_event_detection_workflow.pdf` | PDF-only six-page all-core explanation of how charcoal residual candidates become accepted fire events, plus the separate MORA software/publication audit |
| `plot/fig_cca_trajectories.*` | Main-paper PDF/PNG with A. pooled trajectories, B. biplot inset, C. climate contributions, D. species contributions, eight independently positioned two-line path names, transparent predicted paths/annotations, and an arrow-only observed/predicted legend |
| `cca_trajectory_era_centroids.csv` | Site × CC1–S4 observed WA and predicted LC centroids used by the selected trajectories |
| `cca_trajectory_anthropocene_centroids.csv` | Exact legacy/resurvey WA and LC site means from identical valid paired plots at both dates, plus pair counts |
| `plot/fig_cca_direction_differences.*` | Main-paper PDF/PNG with A. Climate and B. Species median heatmaps of target-alignment discrepancy (predicted minus observed); display labels use climate stability, species names are italicized, and neutral era labels highlight only high fire/burned status in red within MORA/NOCA facets |
| `plot/test_figures/fig_cca_direction_differences_audit.pdf` | Three-page complete taxon/climate boxplot audit retaining individual valid units, distributions, and explicit two-unit groups |
| `bacon_run_manifest.csv` | Seed, versions, settings/control/output hashes, the historical whole-script hash used for five chronology runs, and a separately checked chronology-code fingerprint; the recorded post-run revision is limited to PDF location and PNG persistence |
