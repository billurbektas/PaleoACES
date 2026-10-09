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

suppressPackageStartupMessages(library(here))

args = commandArgs(trailingOnly = TRUE)
offline = "--offline" %in% args
run_age_models = "--age-models" %in% args
skip_figures = "--skip-figures" %in% args
skip_tests = "--skip-tests" %in% args
build_report = "--report" %in% args
unknown = setdiff(args, c("--offline", "--age-models", "--skip-figures", "--skip-tests", "--report"))
if (length(unknown)) stop("Unknown workflow option(s): ", paste(unknown, collapse = ", "))

if (build_report && (skip_figures || skip_tests))
  stop("--report requires figures and all checks; remove --skip-figures and --skip-tests.")
options(paleoaces.offline = offline, paleoaces.report_pending = build_report)
if (build_report) {
  source(here("R/helpers/analysis_report.R"))
  report_state = report_begin()
}

# Shared by every workflow-owned script that can persist a PDF or PNG. Scripts
# run directly still render by default; the workflow option suppresses only
# persistent figure writes, never analytical tables or classifications.
options(paleoaces.render_figures = !skip_figures)

run_script = function(path, label = basename(path)) {
  cat("\n", strrep("=", 78), "\n", label, "\n", strrep("=", 78), "\n", sep = "")
  started = as.numeric(Sys.time())
  env = new.env(parent = globalenv())
  sys.source(here(path), envir = env)
  if (build_report) {
    if (path == "R/stages/05_cca_model.R") report_export_cca(env)
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

# 4. Consolidation and model
run_script("R/stages/000_occurrence_data_consolidate.R")
run_script("R/stages/05_cca_model.R")

# 5. Analysis products. These always run, including with --skip-figures.

# Assemble source-specific accepted fire events, then independently build the
# literature-blind unified climate-era/fire classification. Stage 13 creates the
# frozen era grid required by the main CCA trajectory render.
run_script("R/stages/12_walsh_fire_reproduction.R")
run_script("R/stages/13_holocene_climate_fire_eras.R")
run_script("R/stages/09_tracking_metrics.R")
run_script("R/stages/09b_tracking_model_data.R")
# Compare covariance candidates, then present the author-selected MA1; inference
# and model development remain exploratory. Both lag-change rate and observed
# turnover run in the same stages. Lake reporting uses offset 0 only.
run_script("R/stages/10_tracking_era_models.R")
run_script("R/stages/10a_tracking_lake_sensitivity.R")

# Derived audit/visualization data. Mixed scripts still write their CSV audits
# under --skip-figures; only their persistent PDF/PNG writes are suppressed.
# Stage 09a reuses stage 13's frozen climate-era catalog in both tracking figures.
run_script("R/stages/05a_cca_figure.R")
run_script("R/stages/09a_tracking_example_and_visualizations.R")
run_script("R/stages/12a_fire_event_detection_worked_example.R")
run_script("R/stages/13a_climate_change_figure.R")
run_script("R/stages/13b_fire_method_worked_example.R")

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

# 6. Fast, offline, load-bearing regression gates
if (!skip_tests) {
  run_script("R/tests/test_check_vegetation.R")
  run_script("R/tests/test_NOCA_tree_corrections.R")
  run_script("R/tests/test_NOCA_fire_assignments.R")
  run_script("R/tests/test_paleo_climate_age_match.R")
  run_script("R/tests/test_paleo_split_validation.R")
  run_script("R/tests/test_bacon_provenance.R")
  run_script("R/tests/test_cca_tracking_metrics.R")
  run_script("R/tests/test_tracking_offset_models.R")
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
