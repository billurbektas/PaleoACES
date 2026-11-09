# PaleoACES active workflow driver -------------------------------------------
#
# Standard cached rebuild:
#   Rscript R/workflow.R
# Offline rebuild from existing climate products:
#   Rscript R/workflow.R --offline
# Refit the slow Bacon age-depth models first:
#   Rscript R/workflow.R --age-models
# Rebuild the scientific review from validated native caches:
#   Rscript R/workflow.R --offline --report
# Optional: --skip-figures, --skip-tests
# Bacon model sensitivity is on hold by default; opt in later with --bacon-sensitivity.

suppressPackageStartupMessages(library(here))

args = commandArgs(trailingOnly = TRUE)
offline = "--offline" %in% args
run_age_models = "--age-models" %in% args
skip_figures = "--skip-figures" %in% args
skip_tests = "--skip-tests" %in% args
build_report = "--report" %in% args
run_bacon_sensitivity = "--bacon-sensitivity" %in% args
unknown = setdiff(args, c("--offline", "--age-models", "--skip-figures", "--skip-tests", "--report", "--bacon-sensitivity"))
if (length(unknown)) stop("Unknown workflow option(s): ", paste(unknown, collapse = ", "))

if (build_report && (skip_figures || skip_tests))
  stop("--report requires figures and all checks; remove --skip-figures and --skip-tests.")
options(paleoaces.offline = offline, paleoaces.report_pending = build_report)
options(device=function(...) grDevices::pdf(file=tempfile(fileext='.pdf'),...))
if (build_report) {
  source(here("R/helpers/analysis_report.R"))
  report_state = report_begin()
}

# Shared by every workflow-owned script that can persist a PDF or PNG. Scripts
# run directly still render by default; the workflow option suppresses only
# persistent figure writes, never analytical tables or classifications.
options(paleoaces.render_figures = !skip_figures, paleoaces.primary_only=FALSE,
        paleoaces.run_bacon_sensitivity=run_bacon_sensitivity)

run_script = function(path, label = basename(path)) {
  cat("\n", strrep("=", 78), "\n", label, "\n", strrep("=", 78), "\n", sep = "")
  started = as.numeric(Sys.time())
  env = new.env(parent = globalenv())
  protected_display=path %in% c('R/stages/02_walsh_fire_reproduction.R',
    'R/stages/03_fire_event_detection_worked_example.R','R/stages/05_holocene_climate_fire_eras.R',
    'R/stages/06_fire_method_worked_example.R','R/stages/10_climate_change_figure.R')
  previous_render=getOption('paleoaces.render_figures')
  if(protected_display) options(paleoaces.render_figures=FALSE)
  tryCatch(sys.source(here(path),envir=env),finally=options(paleoaces.render_figures=previous_render))
  if (build_report) {
    if (path == "R/stages/04_cca_model.R") report_export_cca(env)
    report_state <<- report_record(report_state, path, started)
  }
  invisible(env)
}
require_outputs = function(paths, reason) {
  paths = here(paths)
  missing = paths[!file.exists(paths)]
  if (length(missing))
    stop(reason, " Missing: ", paste(missing, collapse = ", "))
}

# 1. Modern vegetation and Anthropocene fire
run_script("R/stages/000_MORA_cleaning.R")
run_script("R/stages/000_NOCA_cleaning.R")
run_script("R/stages/01_get_fire_info.R")

# 2. Modern climate. Chunk caches are validated against coordinates/settings.
# Always rebuild modern aggregates from validated native chunks. This prevents
# a changed adult year/window from reusing a stale monthly aggregate offline.
run_script("R/stages/000_MORA_climate.R")
run_script("R/stages/000_NOCA_climate.R")

# 3. Paleo age-depth, vegetation, fire, and climate
if (run_age_models) run_script("R/stages/000_PALEO_a_agedepth.R")
run_script("R/stages/000_PALEO_b_vegetation.R")
run_script("R/stages/000_FIRE_cleaning.R")
run_script("R/stages/000_PALEO_c_fire.R")

if (offline && !build_report) {
  require_outputs("output/chelsa_paleo_ponds.csv",
                  "Offline mode requires the cached paleo pond climate product.")
} else {
  run_script("R/stages/000_PALEO_d_climate_download.R")
}
run_script("R/stages/000_PALEO_e_climate.R")

# 4. Accepted fire events and their independent software/detection audits.
# These depend on prepared charcoal records, not on the fitted CCA.
run_script("R/stages/02_walsh_fire_reproduction.R")
run_script("R/stages/03_fire_event_detection_worked_example.R")

# 5. Consolidation, native 100-year sampling/fire diagnostic, then CCA.
# Keep 000 for preparation; numbered analysis stages follow execution order.
run_script("R/stages/000_occurrence_data_consolidate.R")
run_script("R/stages/04_cca_model.R")

# 6. Classifications need fixed calibration SDs and accepted fire events.
# Freeze these before CCA trajectories or tracking use their boundaries.
run_script("R/stages/05_holocene_climate_fire_eras.R")
run_script("R/stages/06_fire_method_worked_example.R")

# 7. Calculate tracking once, then derive examples, displays and model input.
# All stages run under --skip-figures; only persistent PDF/PNG writes stop.
run_script("R/stages/07_tracking_metrics.R")
run_script("R/stages/08_cca_figure.R")
run_script("R/stages/09_tracking_example_and_visualizations.R")
run_script("R/stages/10_climate_change_figure.R")
run_script("R/stages/11_tracking_model_data.R")

# 8. Model comparisons and downstream manuscript/predictor products.
# Compare independent, neighboring MA1 and continuous-time AR1 on identical primary rows.
# Lake comparisons are primary-only; explanatory community/species stages refit
# their primary selected covariance families under 1,000 whole chronologies.
run_script("R/stages/12_tracking_era_models.R")
run_script("R/stages/13_tracking_lake_sensitivity.R")
run_script("R/stages/14_tracking_manuscript_figure.R")
# Separate within-era predictor models, preserving the era-comparison products.
run_script("R/stages/15_tracking_predictor_models.R")

run_script("R/stages/16_cca_transition_contributions.R")
run_script("R/stages/17_species_contribution_models.R")

# Reporting-only diagnostics run in the same isolated script environments.
if (build_report) {
  run_script("R/diagnostics/plot_sample_selection.R")
  run_script("R/diagnostics/test_cca_scaling_comparison.R")
  run_script("R/diagnostics/test_species_through_time.R")
  run_script("R/diagnostics/test_climate_change_variables.R")
  run_script("R/diagnostics/test_survey_year_anomaly.R")
  started = as.numeric(Sys.time())
  report_redraw_chronology()
  report_state = report_record(report_state, "R/stages/000_PALEO_a_agedepth.R", started,
    paths = c("plot/test_figures/fig_bacon_agedepth_slump.pdf", "plot/test_figures/fig_bacon_pb210_sensitivity.pdf"))
}

# 9. Fast, offline, load-bearing regression gates
if (!skip_tests) {
  run_script("R/tests/test_check_vegetation.R")
  run_script("R/tests/test_NOCA_tree_corrections.R")
  run_script("R/tests/test_NOCA_fire_assignments.R")
  run_script("R/tests/test_paleo_climate_age_match.R")
  run_script("R/tests/test_paleo_split_validation.R")
  run_script("R/tests/test_bacon_provenance.R")
  run_script("R/tests/test_chronology_tables.R")
  run_script("R/tests/test_cca_tracking_metrics.R")
  run_script("R/tests/test_century_tracking.R")
  run_script("R/tests/test_cca_transition_contributions.R")
  run_script("R/tests/test_tracking_predictor_models.R")
  if(run_bacon_sensitivity) run_script("R/tests/test_chronology_figures.R")
  run_script("R/tests/test_review_edge_cases.R")
  run_script("R/tests/test_walsh_fire_reproduction.R")
  run_script("R/tests/test_holocene_climate_fire_eras.R")
  run_script("R/tests/test_cca_trajectory_figure.R")
  run_script("R/tests/test_figure_output_contract.R")
  run_script("R/tests/test_workflow_contract.R")
  run_script("R/tests/test_documentation.R")
}

if (build_report) {
  report_finish(report_state)
  options(paleoaces.report_pending = FALSE)
  run_script("R/tests/test_analysis_report.R")
  run_script("R/tests/test_documentation.R", label = "Documentation after report publication")
}

cat("\nPaleoACES workflow completed successfully.\n")
