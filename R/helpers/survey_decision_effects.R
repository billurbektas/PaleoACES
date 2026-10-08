# Compare fixed before/after evidence for the 2026-10-07 survey-date decision.
# Regenerate the descriptive tables on every primary run, without attributing
# later CCA refits (including ponderosa reinstatement) to that earlier decision.
export_survey_decision_effects = function(current) {
  old = readr::read_csv(here::here("docs/report/survey_window_baseline.csv"), show_col_types = FALSE)
  after_path = here::here("docs/report/survey_window_after.csv")
  provenance = jsonlite::fromJSON(here::here("docs/report/survey_window_baseline.json"))
  if (!file.exists(after_path) ||
      !identical(digest::digest(file = after_path, algo = "sha256"), provenance$after_metrics_sha256))
    stop("Missing or changed post-decision survey-date evidence.")
  after = readr::read_csv(after_path, show_col_types = FALSE)
  if (anyDuplicated(old$plot_id) || anyDuplicated(after$plot_id) ||
      !setequal(old$plot_id, after$plot_id) ||
      anyDuplicated(current$plot_id))
    stop("Survey-window decision evidence requires uniquely matched before/after plots.")
  after = after[match(old$plot_id, after$plot_id), ]
  metrics = c("vegetation_t2_year", "vegetation_dt_years", "climate_dt_years",
    "MSpT_2", "MWT_2", "SP_2", "WP_2", "observed_vegetation_displacement",
    "predicted_vegetation_displacement", "observed_turnover_rate",
    "predicted_vegetation_change_rate", "rate_tracking_ratio", "angle_degrees",
    "change_in_lag", "lag_rate_per_century", "standardized_climate_change_rate")
  effects = dplyr::bind_rows(lapply(c("MORA", "NOCA"), function(site) {
    i = old$site == site
    dplyr::bind_rows(lapply(metrics, function(metric) {
      a = old[[metric]][i]; b = after[[metric]][i]
      valid = is.finite(a) & is.finite(b)
      changed = xor(is.finite(a), is.finite(b)) |
        (valid & abs(b - a) > 1e-10)
      data.frame(site, metric, plots = sum(i), changed_plots = sum(changed),
        before_median = median(a[is.finite(a)]), after_median = median(b[is.finite(b)]),
        median_difference = median(b[valid] - a[valid]),
        maximum_absolute_difference = max(c(0, abs(b[valid] - a[valid]))),
        before_valid = sum(is.finite(a)), after_valid = sum(is.finite(b)))
    }))
  }))
  readr::write_csv(effects, here::here("output/survey_window_decision_effects.csv"))
  paired_effects = after |>
    dplyr::select(site, plot_id, dplyr::all_of(metrics)) |>
    dplyr::rename_with(~ paste0(.x, "_after"), dplyr::all_of(metrics)) |>
    dplyr::left_join(old |> dplyr::select(plot_id, dplyr::all_of(metrics)) |>
      dplyr::rename_with(~ paste0(.x, "_before"), dplyr::all_of(metrics)), by = "plot_id")
  readr::write_csv(paired_effects, here::here("output/survey_window_plot_effects.csv"))
  before = readr::read_csv(here::here("docs/report/mora_repeat_presence_baseline.csv"), show_col_types = FALSE)
  after = readr::read_csv(here::here("output/MORA_occ.csv"), show_col_types = FALSE) |>
    dplyr::filter(period == "present", plot_id %in% before$plot_id)
  lost = dplyr::anti_join(before, after, by = c("plot_id", "species", "period")) |>
    dplyr::mutate(effect = "Earlier-visit presence absent from selected latest visit")
  added = dplyr::anti_join(after, before, by = c("plot_id", "species", "period")) |>
    dplyr::mutate(effect = "Presence added at selected latest visit")
  readr::write_csv(dplyr::bind_rows(lost, added), here::here("output/MORA_latest_visit_composition_effects.csv"))
}
