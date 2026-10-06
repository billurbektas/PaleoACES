# Offline structural gate for workflow order and render-only skip semantics.
suppressPackageStartupMessages(library(here))

workflow_path = here("R/workflow.R")
workflow_lines = readLines(workflow_path, warn = FALSE, encoding = "UTF-8")
workflow = paste(workflow_lines, collapse = "\n")

# The retired climate-trend diagnostic is archived and must not return as an
# active top-level stage.
stopifnot(
  file.exists(here("R/archive/08_climate_trends_cca_vars.R")),
  !file.exists(here("R/08_climate_trends_cca_vars.R")),
  !grepl("08_climate_trends_cca_vars.R", workflow, fixed = TRUE))

call_lines = grep('^[[:space:]]*run_script\\("R/', workflow_lines, value = TRUE)
calls = sub('^[[:space:]]*run_script\\("([^\"]+)".*$', '\\1', call_lines)
position = function(path) {
  hit = which(calls == path)
  if (length(hit) != 1L) stop("Expected one workflow call for ", path)
  hit
}

# Producers must precede consumers on a fresh output tree.
stopifnot(
  position("R/stages/09_tracking_metrics.R") < position("R/stages/13_holocene_climate_fire_eras.R"),
  position("R/stages/12_walsh_fire_reproduction.R") < position("R/stages/13_holocene_climate_fire_eras.R"),
  position("R/stages/13_holocene_climate_fire_eras.R") < position("R/stages/05a_cca_figure.R"),
  position("R/stages/13_holocene_climate_fire_eras.R") < position("R/stages/09b_tracking_visualization_data.R"),
  position("R/stages/09b_tracking_visualization_data.R") < position("R/stages/09c_tracking_comparison.R"),
  position("R/stages/09_tracking_metrics.R") < position("R/stages/14_cca_direction_analysis.R"),
  position("R/stages/13_holocene_climate_fire_eras.R") < position("R/stages/14_cca_direction_analysis.R"),
  position("R/stages/09c_tracking_comparison.R") < position("R/stages/14_cca_direction_analysis.R"),
  position("R/stages/14_cca_direction_analysis.R") < position("R/tests/test_cca_direction_analysis.R"))

# --skip-figures is a render option, not an analysis-stage branch.
stopifnot(
  grepl("options(paleoaces.render_figures = !skip_figures)", workflow, fixed = TRUE),
  !grepl("if (skip_figures)", workflow, fixed = TRUE),
  !grepl("if (!skip_figures)", workflow, fixed = TRUE))

analysis_stages = c(
  "R/stages/09_tracking_metrics_500yr_sensitivity.R",
  "R/stages/09_tracking_metrics.R",
  "R/stages/12_walsh_fire_reproduction.R",
  "R/stages/13_holocene_climate_fire_eras.R",
  "R/stages/05a_cca_figure.R",
  "R/stages/09a_method_example.R",
  "R/stages/12a_fire_event_detection_worked_example.R",
  "R/stages/13a_climate_change_figure.R",
  "R/stages/13b_fire_method_worked_example.R",
  "R/stages/09b_tracking_visualization_data.R",
  "R/stages/09c_tracking_comparison.R",
  "R/stages/14_cca_direction_analysis.R")
stopifnot(all(analysis_stages %in% calls))

automatic_gates = c(
  "R/tests/test_cca_tracking_visualizations.R",
  "R/tests/test_walsh_fire_reproduction.R",
  "R/tests/test_holocene_climate_fire_eras.R",
  "R/tests/test_cca_trajectory_figure.R",
  "R/tests/test_cca_direction_geometry.R",
  "R/tests/test_cca_direction_analysis.R",
  "R/tests/test_figure_output_contract.R",
  "R/tests/test_workflow_contract.R",
  "R/tests/test_documentation.R")
stopifnot(all(automatic_gates %in% calls))

render_aware = c(
  "R/stages/000_MORA_cleaning.R", "R/stages/000_NOCA_cleaning.R",
  "R/stages/000_occurrence_data_consolidate.R", "R/stages/01_get_fire_info.R",
  "R/stages/000_PALEO_a_agedepth.R", "R/stages/05a_cca_figure.R",
  "R/stages/09a_method_example.R",
  "R/stages/12_walsh_fire_reproduction.R", "R/stages/12a_fire_event_detection_worked_example.R",
  "R/stages/13_holocene_climate_fire_eras.R", "R/stages/13a_climate_change_figure.R",
  "R/stages/13b_fire_method_worked_example.R", "R/stages/09c_tracking_comparison.R",
  "R/stages/14_cca_direction_analysis.R")
for (path in render_aware) {
  code = paste(readLines(here(path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl("paleoaces.render_figures", code, fixed = TRUE))
    stop(path, " does not honor the shared render option.")
}

cat("Workflow contract passed: fresh-order dependencies, analysis-complete skip mode, and automatic gates.\n")
