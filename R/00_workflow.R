# PaleoACES active workflow driver -------------------------------------------
#
# Standard cached rebuild:
#   Rscript R/00_workflow.R
# Offline rebuild from existing climate products:
#   Rscript R/00_workflow.R --offline
# Refit the slow Bacon age-depth models first:
#   Rscript R/00_workflow.R --age-models
# Optional: --skip-figures, --skip-tests

suppressPackageStartupMessages(library(here))

args = commandArgs(trailingOnly = TRUE)
offline = "--offline" %in% args
run_age_models = "--age-models" %in% args
skip_figures = "--skip-figures" %in% args
skip_tests = "--skip-tests" %in% args
unknown = setdiff(args, c("--offline", "--age-models", "--skip-figures", "--skip-tests"))
if (length(unknown)) stop("Unknown workflow option(s): ", paste(unknown, collapse = ", "))

# Shared by every workflow-owned script that can persist a PDF or PNG. Scripts
# run directly still render by default; the workflow option suppresses only
# persistent figure writes, never analytical tables or classifications.
options(paleoaces.render_figures = !skip_figures)

run_script = function(path, label = basename(path)) {
  cat("\n", strrep("=", 78), "\n", label, "\n", strrep("=", 78), "\n", sep = "")
  sys.source(here(path), envir = new.env(parent = globalenv()))
}
require_outputs = function(paths, reason) {
  paths = here(paths)
  missing = paths[!file.exists(paths)]
  if (length(missing))
    stop(reason, " Missing: ", paste(missing, collapse = ", "))
}

# 1. Modern vegetation and Anthropocene fire
run_script("R/000_MORA_cleaning.R")
run_script("R/000_NOCA_cleaning.R")
run_script("R/01_get_fire_info.R")

# 2. Modern climate. Chunk caches are validated against coordinates/settings.
if (offline) {
  require_outputs(c("output/MORA_climate.csv", "output/NOCA_climate.csv"),
                  "Offline mode requires existing Anthropocene climate outputs.")
} else {
  run_script("R/000_MORA_climate.R")
  run_script("R/000_NOCA_climate.R")
}

# 3. Paleo age-depth, vegetation, fire, and climate
if (run_age_models) run_script("R/000_PALEO_a_agedepth.R")
run_script("R/000_PALEO_b_vegetation.R")
run_script("R/000_FIRE_cleaning.R")
run_script("R/000_PALEO_c_fire.R")

if (offline) {
  require_outputs("output/chelsa_paleo_ponds.csv",
                  "Offline mode requires the cached paleo pond climate product.")
} else {
  run_script("R/000_PALEO_d_climate_download.R")
}
run_script("R/000_PALEO_e_climate.R")

# 4. Consolidation and model
run_script("R/000_occurrence_data_consolidate.R")
run_script("R/05_cca_model.R")

# 5. Analysis products. These always run, including with --skip-figures.
# Primary tracking uses 1,000-year bins; the former 500-year framework is an
# explicitly suffixed sensitivity and runs first so the primary products win.
run_script("R/09_tracking_metrics_500yr_sensitivity.R")
run_script("R/09_tracking_metrics.R")

# Assemble source-specific accepted fire events, then independently build the
# literature-blind unified climate-era/fire classification. Stage 13 creates the
# frozen era grid required by the main CCA trajectory render.
run_script("R/12_walsh_fire_reproduction.R")
run_script("R/13_holocene_climate_fire_eras.R")

# Derived audit/visualization data. Mixed scripts still write their CSV audits
# under --skip-figures; only their persistent PDF/PNG writes are suppressed.
run_script("R/05a_cca_figure.R")
run_script("R/09a_method_example.R")
run_script("R/12a_fire_event_detection_worked_example.R")
run_script("R/13a_climate_change_figure.R")
run_script("R/13b_fire_method_worked_example.R")
run_script("R/09b_tracking_visualization_data.R")
run_script("R/09c_tracking_comparison.R")
run_script("R/14_cca_direction_analysis.R")

# 6. Fast, offline, load-bearing regression gates
if (!skip_tests) {
  run_script("R/test_check_vegetation.R")
  run_script("R/test_NOCA_tree_corrections.R")
  run_script("R/test_NOCA_fire_assignments.R")
  run_script("R/test_paleo_climate_age_match.R")
  run_script("R/test_paleo_split_validation.R")
  run_script("R/test_bacon_provenance.R")
  run_script("R/test_cca_tracking_metrics.R")
  run_script("R/test_cca_tracking_visualizations.R")
  run_script("R/test_walsh_fire_reproduction.R")
  run_script("R/test_holocene_climate_fire_eras.R")
  run_script("R/test_cca_trajectory_figure.R")
  run_script("R/test_cca_direction_geometry.R")
  run_script("R/test_cca_direction_analysis.R")
  run_script("R/test_figure_output_contract.R")
  run_script("R/test_workflow_contract.R")
  run_script("R/test_documentation.R")
}

cat("\nPaleoACES workflow completed successfully.\n")
