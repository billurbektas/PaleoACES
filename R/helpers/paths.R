# Where every pipeline file lives. Source through R/config.R; never write a path
# under output/ or report/ by hand.
#
#   out("MORA_occ.csv")           -> output/01_mora_vegetation/MORA_occ.csv
#   out("chelsa_paleo")           -> output/cache/chelsa_paleo
#   fig("main", "fig_cca_trajectories.pdf") -> report/figures/main/fig_cca_trajectories.pdf
#
# The registry is keyed by the FIRST path component of the name, so a folder of
# chunks (e.g. "mora_climate_parts/...") is registered once. out() stops on an
# unregistered name, which keeps the list of outputs complete: an output that is
# not listed here cannot be written. report/details/11_outputs_and_workflow is
# generated from this table.
OUTPUT_REGISTRY = tibble::tribble(
  ~name, ~step, ~description,
  # 01 MORA vegetation ------------------------------------------------------
  "MORA_occ.csv", "01_mora_vegetation", "MORA tree presence by plot and survey (adults + seedlings)",
  "MORA_occ_stage.csv", "01_mora_vegetation", "MORA presence split by developmental stage (Fig. S1)",
  "MORA_plot_info.csv", "01_mora_vegetation", "MORA plot coordinates and attributes",
  "MORA_plot_years.csv", "01_mora_vegetation", "MORA survey year per plot and period",
  "MORA_resurvey_record_audit.csv", "01_mora_vegetation", "MORA resurvey records kept/dropped by latest-visit rule",
  "MORA_resurvey_visit_audit.csv", "01_mora_vegetation", "MORA plots with repeated resurvey visits (Fig. S2)",
  # 02 NOCA vegetation ------------------------------------------------------
  "NOCA_occ.csv", "02_noca_vegetation", "NOCA tree presence by plot and survey",
  "NOCA_occ_stage.csv", "02_noca_vegetation", "NOCA presence split by developmental stage (Fig. S1)",
  "NOCA_past_occ.csv", "02_noca_vegetation", "NOCA legacy presence before pairing",
  "NOCA_present_occ.csv", "02_noca_vegetation", "NOCA resurvey presence before pairing",
  "NOCA_plot_info.csv", "02_noca_vegetation", "NOCA plot coordinates and attributes",
  "NOCA_plot_tracking.csv", "02_noca_vegetation", "NOCA plot-by-plot cleaning trail (Fig. S2)",
  "NOCA_study_exclusions.csv", "02_noca_vegetation", "NOCA plots excluded and why",
  "NOCA_tree_correction_audit.csv", "02_noca_vegetation", "2026 NOCA tree corrections applied",
  "NOCA_tree_composition_audit.csv", "02_noca_vegetation", "NOCA composition before/after tree corrections",
  "NOCA_coordinate_collision_audit.csv", "02_noca_vegetation", "NOCA plots sharing GPS coordinates",
  "modern_plot_years.csv", "02_noca_vegetation", "Survey year per plot and period, both parks",
  "modern_plot_years_sources.rds", "02_noca_vegetation", "Source fingerprint of the survey years",
  # 03 modern fire ----------------------------------------------------------
  "MORA_plot_info_fire.csv", "03_modern_fire", "MORA plots with modern fire assignment",
  "NOCA_plot_info_fire.csv", "03_modern_fire", "NOCA plots with modern fire assignment",
  "NOCA_fire_assignment_audit.csv", "03_modern_fire", "NOCA fire assignment and its source",
  "NOCA_fire_Wilson2024_comparison.csv", "03_modern_fire", "NOCA fire assignment vs Wilson 2024",
  # 04 modern climate -------------------------------------------------------
  "MORA_climate.csv", "04_modern_climate", "MORA survey-window CHELSA V2.1 climate per plot",
  "NOCA_climate.csv", "04_modern_climate", "NOCA survey-window CHELSA V2.1 climate per plot",
  # 05 age-depth models -----------------------------------------------------
  "bacon_run_manifest.csv", "05_age_depth_models", "Bacon run settings, seeds and source hashes",
  "table_S1_1_chronological_controls.csv", "05_age_depth_models", "Table S1.1",
  "table_S1_2_rbacon_parameters.csv", "05_age_depth_models", "Table S1.2",
  # 06 paleo samples --------------------------------------------------------
  "paleo_occ.csv", "06_paleo_samples", "Macrofossil presence by sample",
  "paleo_sample_depths.csv", "06_paleo_samples", "Sample depth and median Bacon age",
  "paleo_macrofossil_long.csv", "06_paleo_samples", "All macrofossil measurements with ages",
  # 07 paleo climate --------------------------------------------------------
  "chelsa_paleo_ponds.csv", "07_paleo_climate", "CHELSA-TraCE21k monthly climate at each lake and century",
  "chelsa_paleo_bias_correction.csv", "07_paleo_climate", "V2.1 bias anchor (not used in the primary run)",
  "paleo_env.csv", "07_paleo_climate", "Climate at each macrofossil sample's age",
  # 08 fire records ---------------------------------------------------------
  "fire_walsh.csv", "08_fire_records", "MORA charcoal records (Walsh et al. 2017)",
  "fire_mora_tapas_series.csv", "08_fire_records", "MORA tapas peak-detection series",
  "fire_mora_tapas_events.csv", "08_fire_records", "MORA accepted fire events",
  "fire_mora_tapas_settings.csv", "08_fire_records", "MORA tapas settings (Table S2.1)",
  "fire_noca_peaks.csv", "08_fire_records", "NOCA charcoal peaks",
  "fire_noca_tapas_series.csv", "08_fire_records", "NOCA tapas peak-detection series",
  "fire_noca_tapas_events.csv", "08_fire_records", "NOCA accepted fire events",
  "fire_noca_tapas_settings.csv", "08_fire_records", "NOCA tapas settings (Table S2.1)",
  "fire_noca_tapas_sensitivity.csv", "08_fire_records", "NOCA threshold sensitivity",
  "paleo_fire.csv", "08_fire_records", "Fire evidence per macrofossil sample",
  "holocene_fire_source_settings.csv", "08_fire_records", "Accepted-event catalog settings (Table S2.1)",
  "holocene_fire_source_series.csv", "08_fire_records", "Accepted-event catalog series, four lakes",
  "holocene_fire_source_events.csv", "08_fire_records", "Accepted fire events, four lakes",
  "holocene_fire_tapas_manifest.csv", "08_fire_records", "Which tapas run each lake's events came from",
  "walsh_charanalysis_inputs", "08_fire_records", "CharAnalysis input files",
  "walsh_charanalysis_settings.csv", "08_fire_records", "CharAnalysis settings",
  "walsh_charanalysis_software_comparison.csv", "08_fire_records", "CharAnalysis vs tapas vs published",
  "walsh_charanalysis_table3_audit.csv", "08_fire_records", "Comparison with Walsh Table 3 (Table S2.2)",
  # 09 species occurrences --------------------------------------------------
  "occ_consolidated.csv", "09_species_occurrences", "All presence records, one taxonomy (Fig. S8)",
  # 10 CCA ------------------------------------------------------------------
  "cca_sample_eligibility.csv", "10_cca", "Per-sample CCA eligibility and reason",
  "cca_pair_eligibility.csv", "10_cca", "Per-plot-pair CCA eligibility and reason",
  "cca_eligibility_counts.csv", "10_cca", "Eligibility counts (Fig. S2)",
  "cca_exclusion_summary.csv", "10_cca", "Exclusion reasons summarised",
  "cca_calibration_reference.rds", "10_cca", "The fitted CCA and its calibration inputs",
  "cca_tracking_climate_scaling.csv", "10_cca", "Calibration means/SDs used to standardize climate",
  "cca_summary.csv", "10_cca", "CCA inertia, eigenvalues and fit summary",
  "cca_axes.csv", "10_cca", "Constrained axes: eigenvalues and variance explained",
  "cca_taxa.csv", "10_cca", "Retained taxa and their CCA scores",
  "cca_counts.csv", "10_cca", "Plots and samples used to fit and projected",
  "cca_anova.csv", "10_cca", "Permutation tests (model, axes, terms)",
  "cca_climate_contributions.csv", "10_cca", "Climate-variable contributions to the axes",
  "cca_species_contributions.csv", "10_cca", "Species contributions to the axes",
  "cca_model_output.txt", "10_cca", "Printed CCA model",
  "cca_anova_cache.rds", "10_cca", "Cached permutation tests, keyed on the fit",
  "cca_screening.csv", "10_cca", "Step 0.1 screening: VIF, correlation, R2, adjusted R2, extrapolation per constraint set",
  "cca_screening_correlations.csv", "10_cca", "Correlations of the four seasonal variables on the calibration plots",
  "cca_screening_addback.csv", "10_cca", "Permutation test of adding MWT and WP back to MSpT + SP",
  "cca_display_rotation.csv", "10_cca", "Display-only varimax angle, rotation matrix and axis orientation",
  # 11 climate eras and high-fire periods -----------------------------------
  "holocene_era", "11_climate_eras", "(prefix) era and high-fire classification tables",
  "holocene_periods.csv", "11_climate_eras", "The analysis periods (C and S, sub-periods where split) that define the lake-periods",
  "holocene_period_comparison.csv", "11_climate_eras", "Periods after Step 0 against the four-variable periods",
  # 12 tracking -------------------------------------------------------------
  "cca_tracking", "12_tracking", "(prefix) Holocene and Anthropocene tracking calculations",
  "chronology_reconstruction", "12_tracking", "Reconstruction bundle and primary reconstruction",
  # 13-15 models ------------------------------------------------------------
  "era_comparison", "13_era_models", "Era-comparison GLS fits, means and contrasts per response",
  "lake_checks", "13_era_models", "Individual-lake era comparisons per response",
  "community_predictor_models", "14_predictor_models", "Within-era predictor GLS fits",
  "lake_random_intercepts", "14_predictor_models", "Lake random-intercept sensitivity",
  "cca_transition_contributions", "15_contributions", "Species and climate contributions to displacement",
  "species_contribution_models", "15_contributions", "Species-contribution GLS fits",
  # tables written by figure scripts, worked examples and report-only figures
  "figures", "figures", "Tables behind the figures (centroids, annotations)",
  "worked_examples", "worked_examples", "Tables behind the worked examples",
  "report", "report", "Tables computed only for the report",
  # caches (the only things --offline relies on) ----------------------------
  "mora_climate_parts", "cache", "CHELSA V2.1 chunks, MORA",
  "noca_climate_parts", "cache", "CHELSA V2.1 chunks, NOCA",
  "chelsa_paleo", "cache", "CHELSA-TraCE21k slices and V2.1 anchor",
  "anomaly_parts", "cache", "CHELSA V2.1 1979-2021 chunks for the survey-window figure",
  "age_draws.rds", "cache", "1,000 seeded Bacon age draws per sample"
)

output_step = function(name) {
  first = sub('/.*$', '', name)
  hit = match(first, OUTPUT_REGISTRY$name)
  prefix = vapply(first, function(f) {
    i = which(startsWith(f, OUTPUT_REGISTRY$name) & grepl('^\\(prefix\\)', OUTPUT_REGISTRY$description))
    if (length(i)) i[1] else NA_integer_
  }, integer(1))
  hit = ifelse(is.na(hit), prefix, hit)
  if (anyNA(hit)) stop('Unregistered output: ', paste(name[is.na(hit)], collapse = ', '),
    '. Add it to OUTPUT_REGISTRY in R/helpers/paths.R.', call. = FALSE)
  OUTPUT_REGISTRY$step[hit]
}

out = function(name) {
  if (!length(name)) return(character(0))
  step = output_step(name)
  first = sub('/.*$', '', name)
  # A folder named after its own step ("figures/x.csv") is not nested twice.
  path = ifelse(first == step, here::here('output', name), here::here('output', step, name))
  for (d in unique(dirname(path))) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  path
}

FIGURE_FOLDERS = c('main', 'supplementary', 'models', 'worked_examples', 'presentation')
fig = function(folder, name) {
  if (!folder %in% FIGURE_FOLDERS) stop('Unknown figure folder: ', folder, call. = FALSE)
  path = here::here('report/figures', folder, name)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  path
}
