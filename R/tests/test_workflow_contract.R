# Offline structural gate for workflow order and render-only skip semantics.
suppressPackageStartupMessages(library(here))

workflow_path = here("R/workflow.R")
workflow_lines = readLines(workflow_path, warn = FALSE, encoding = "UTF-8")
workflow = paste(workflow_lines, collapse = "\n")

# The retired climate-trend diagnostic must not return as an active stage.
# Its source is preserved in Git history; local archive files are unnecessary.
stopifnot(
  !file.exists(here("R/08_climate_trends_cca_vars.R")),
  !file.exists(here("R/stages/08_climate_trends_cca_vars.R")),
  !grepl("08_climate_trends_cca_vars.R", workflow, fixed = TRUE))

call_lines = grep('^[[:space:]]*run_script\\("R/', workflow_lines, value = TRUE)
calls = sub('^[[:space:]]*run_script\\("([^\"]+)".*$', '\\1', call_lines)
position = function(path) {
  hit = which(calls == path)
  if (length(hit) != 1L) stop("Expected one workflow call for ", path)
  hit
}

# Analysis numbers are consecutive in execution order; 000 remains preparation.
stage_calls = calls[startsWith(calls, "R/stages/")]
numbered_calls = stage_calls[!startsWith(basename(stage_calls), "000_")]
stage_numbers = as.integer(sub("_.*", "", basename(numbered_calls)))
stopifnot(identical(stage_numbers, seq_len(17L)),
  all(file.exists(here(stage_calls))))
standalone = here("R/stages/16_cca_transition_contributions.R")
stopifnot(file.exists(standalone), standalone %in% here(calls),
  position("R/stages/16_cca_transition_contributions.R")<position("R/stages/17_species_contribution_models.R"))

# Source fire reconstruction precedes calibration; classifications use its SDs.
stopifnot(
  position("R/stages/000_FIRE_cleaning.R") < position("R/stages/02_walsh_fire_reproduction.R"),
  position("R/stages/000_PALEO_c_fire.R") < position("R/stages/02_walsh_fire_reproduction.R"),
  position("R/stages/02_walsh_fire_reproduction.R") < position("R/stages/03_fire_event_detection_worked_example.R"),
  position("R/stages/03_fire_event_detection_worked_example.R") < position("R/stages/000_occurrence_data_consolidate.R"),
  position("R/stages/04_cca_model.R") < position("R/stages/05_holocene_climate_fire_eras.R"),
  position("R/stages/000_occurrence_data_consolidate.R") + 1L == position("R/stages/04_cca_model.R"),
  position("R/stages/02_walsh_fire_reproduction.R") < position("R/stages/05_holocene_climate_fire_eras.R"),
  position("R/stages/05_holocene_climate_fire_eras.R") < position("R/stages/07_tracking_metrics.R"),
  position("R/stages/05_holocene_climate_fire_eras.R") < position("R/stages/08_cca_figure.R"),
  position("R/stages/05_holocene_climate_fire_eras.R") < position("R/stages/06_fire_method_worked_example.R"),
  position("R/stages/07_tracking_metrics.R") < position("R/stages/10_climate_change_figure.R"),
  position("R/stages/07_tracking_metrics.R") < position("R/stages/11_tracking_model_data.R"),
  position("R/stages/11_tracking_model_data.R") < position("R/stages/12_tracking_era_models.R"),
  position("R/stages/12_tracking_era_models.R") < position("R/stages/13_tracking_lake_sensitivity.R"),
  position("R/stages/12_tracking_era_models.R") < position("R/stages/14_tracking_manuscript_figure.R"),
  position("R/stages/11_tracking_model_data.R") < position("R/stages/15_tracking_predictor_models.R"),
  position("R/stages/07_tracking_metrics.R") < position("R/stages/09_tracking_example_and_visualizations.R"))

# Native sampling/fire support is produced before CCA and shown directly before it.
registry = jsonlite::fromJSON(here("docs/report/artifacts.json"))$diagnostics
sampling = registry[registry$id == "holocene_sampling_fire_100yr", ]
stopifnot(nrow(sampling) == 1L,
  sampling$producer == "R/stages/000_occurrence_data_consolidate.R",
  sampling$section == "sampling_support")
template = readLines(here("docs/report/analysis_review_template.md"), warn = FALSE)
stopifnot(which(template == "{{sampling_support_diagnostics}}") <
  which(template == "## CCA calibration and geometry"),
  which(template == "## Accepted fire events") <
    which(template == "## CCA calibration and geometry"),
  which(template == "## CCA calibration and geometry") <
    which(template == "## Climate eras and high-fire periods"),
  which(template == "## Climate eras and high-fire periods") <
    which(template == "## Community trajectories"),
  which(template == "## Tracking calculations") <
    which(template == "## Community trajectories"))

# --skip-figures is a render option, not an analysis-stage branch.
stopifnot(
  grepl("options(paleoaces.render_figures = !skip_figures", workflow, fixed = TRUE),
  !grepl("if (skip_figures)", workflow, fixed = TRUE),
  !grepl("if (!skip_figures)", workflow, fixed = TRUE))

analysis_stages = c(
  "R/stages/07_tracking_metrics.R",
  "R/stages/11_tracking_model_data.R",
  "R/stages/12_tracking_era_models.R",
  "R/stages/13_tracking_lake_sensitivity.R",
  "R/stages/14_tracking_manuscript_figure.R",
  "R/stages/15_tracking_predictor_models.R",
  "R/stages/02_walsh_fire_reproduction.R",
  "R/stages/05_holocene_climate_fire_eras.R",
  "R/stages/08_cca_figure.R",
  "R/stages/09_tracking_example_and_visualizations.R",
  "R/stages/03_fire_event_detection_worked_example.R",
  "R/stages/10_climate_change_figure.R",
  "R/stages/06_fire_method_worked_example.R")
stopifnot(all(analysis_stages %in% calls))

automatic_gates = c(
  "R/tests/test_tracking_predictor_models.R",
  "R/tests/test_century_tracking.R",
  "R/tests/test_walsh_fire_reproduction.R",
  "R/tests/test_holocene_climate_fire_eras.R",
  "R/tests/test_cca_trajectory_figure.R",
  "R/tests/test_figure_output_contract.R",
  "R/tests/test_workflow_contract.R",
  "R/tests/test_documentation.R")
stopifnot(all(automatic_gates %in% calls))

render_aware = c(
  "R/stages/000_MORA_cleaning.R", "R/stages/000_NOCA_cleaning.R",
  "R/stages/000_occurrence_data_consolidate.R", "R/stages/01_get_fire_info.R",
  "R/stages/000_PALEO_a_agedepth.R", "R/stages/08_cca_figure.R",
  "R/stages/09_tracking_example_and_visualizations.R",
  "R/stages/12_tracking_era_models.R",
  "R/stages/13_tracking_lake_sensitivity.R",
  "R/stages/14_tracking_manuscript_figure.R",
  "R/stages/15_tracking_predictor_models.R",
  "R/stages/02_walsh_fire_reproduction.R", "R/stages/03_fire_event_detection_worked_example.R",
  "R/stages/05_holocene_climate_fire_eras.R", "R/stages/10_climate_change_figure.R",
  "R/stages/06_fire_method_worked_example.R")
for (path in render_aware) {
  code = paste(readLines(here(path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl("paleoaces.render_figures", code, fixed = TRUE))
    stop(path, " does not honor the shared render option.")
}

cat("Workflow contract passed: fresh-order dependencies, analysis-complete skip mode, and automatic gates.\n")
