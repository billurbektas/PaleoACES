# =============================================================================
# 09b_tracking_visualization_data.R - site-level tracking figure audit
# =============================================================================
# Run after both primary and 500-year tracking stages. This script does not
# recalculate CCA metrics. It reshapes the authoritative MORA/NOCA site series,
# joins the frozen CC/S eras, creates descriptive medians, and audits sensitivity
# to the 1,000- versus 500-year Holocene interval width.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
})

paths = c(
  holo_1000 = here("output/cca_tracking_holocene_timeseries.csv"),
  holo_500 = here("output/cca_tracking_holocene_timeseries_500yr.csv"),
  realization_1000 = here("output/cca_tracking_holocene_realizations.csv"),
  realization_500 = here("output/cca_tracking_holocene_realizations_500yr.csv"),
  anth = here("output/cca_tracking_anthropocene_plot.csv"),
  era_grid = here("output/holocene_era_grid.csv"),
  era_catalog = here("output/holocene_era_catalog.csv")
)
if (!all(file.exists(paths)))
  stop("Run the tracking and climate-era stages first. Missing: ",
       paste(paths[!file.exists(paths)], collapse = ", "))

holo_1000 = read_csv(paths[["holo_1000"]], show_col_types = FALSE)
holo_500 = read_csv(paths[["holo_500"]], show_col_types = FALSE)
realization_1000 = read_csv(paths[["realization_1000"]], show_col_types = FALSE)
realization_500 = read_csv(paths[["realization_500"]], show_col_types = FALSE)
anth = read_csv(paths[["anth"]], show_col_types = FALSE)
era_grid = read_csv(paths[["era_grid"]], show_col_types = FALSE)
era_catalog = read_csv(paths[["era_catalog"]], show_col_types = FALSE)

DISPLAY_METRICS = c(
  "predicted_vegetation_displacement",
  "observed_vegetation_displacement",
  "predicted_vegetation_change_rate",
  "observed_turnover_rate",
  "standardized_climate_change_rate",
  "rate_tracking_ratio",
  "change_in_lag",
  "lag",
  "lag_rate_per_century",
  "climate_aligned_tracking",
  "normalized_perpendicular_movement",
  "angle_degrees"
)
missing_holo = setdiff(DISPLAY_METRICS, unique(holo_1000$metric))
missing_anth = setdiff(DISPLAY_METRICS, names(anth))
if (length(missing_holo) || length(missing_anth))
  stop("Tracking input is incomplete. Holocene: ",
       paste(missing_holo, collapse = ", "), "; Anthropocene: ",
       paste(missing_anth, collapse = ", "))
if (any(holo_1000$n_offsets != 10L))
  stop("Primary Holocene site dates must all have ten offsets")

safe_median = function(x) {
  x = x[is.finite(x)]
  if (length(x)) median(x) else NA_real_
}

# One row is one site-date after realization metrics were summarized over age
# draws within offset and then over all ten offset phases.
holo_site_date = holo_1000 %>%
  filter(metric %in% DISPLAY_METRICS) %>%
  select(site, t, n_offsets, n_per_bin, metric, estimate) %>%
  distinct() %>%
  pivot_wider(names_from = metric, values_from = estimate) %>%
  left_join(era_grid %>% select(t, climate_era_id = era_id,
                                climate_era_class = era_class), by = "t") %>%
  mutate(
    point_class = "holocene_site_interval",
    macro_era = "Holocene",
    plot_id = NA_character_,
    point_id = paste(site, t, sep = "_"),
    source_shape = "Holocene site-date",
    label = NA_character_,
    source_n = 1L,
    aggregate = FALSE,
    coverage_status = "complete ten-offset support"
  )

anth_plot = anth %>%
  select(site, plot_id, all_of(DISPLAY_METRICS)) %>%
  mutate(
    t = NA_real_, n_offsets = NA_integer_, n_per_bin = NA_real_,
    climate_era_id = NA_character_, climate_era_class = NA_character_,
    point_class = "anthropocene_plot", macro_era = "Anthropocene",
    point_id = plot_id, source_shape = "Anthropocene plot",
    label = NA_character_, source_n = 1L, aggregate = FALSE,
    coverage_status = "paired plot"
  )

overall_medians = bind_rows(holo_site_date, anth_plot) %>%
  group_by(macro_era, site) %>%
  summarize(across(all_of(DISPLAY_METRICS), safe_median),
            source_n = n(), .groups = "drop") %>%
  mutate(
    t = NA_real_, n_offsets = NA_integer_, n_per_bin = NA_real_,
    climate_era_id = NA_character_, climate_era_class = NA_character_,
    plot_id = NA_character_, point_class = "site_macro_era_median",
    point_id = paste(site, macro_era, "median", sep = "_"),
    source_shape = "Overall site median", label = paste(macro_era, site),
    aggregate = TRUE, coverage_status = "descriptive coordinate-wise median"
  )

era_levels = era_catalog$era_id
era_lookup = era_catalog %>% select(climate_era_id = era_id,
                                    climate_era_class = era_class)
era_coverage = expand_grid(site = c("MORA", "NOCA"),
                           climate_era_id = era_levels) %>%
  left_join(era_lookup, by = "climate_era_id") %>%
  left_join(holo_site_date %>%
      count(site, climate_era_id, name = "n_site_dates"),
    by = c("site", "climate_era_id")) %>%
  mutate(
    n_site_dates = replace_na(n_site_dates, 0L),
    coverage_status = if_else(n_site_dates > 0,
      "complete ten-offset support",
      "insufficient complete-offset support"),
    climate_era_id = factor(climate_era_id, levels = era_levels)
  ) %>%
  arrange(site, climate_era_id) %>%
  mutate(climate_era_id = as.character(climate_era_id))
write_csv(era_coverage, here("output/cca_tracking_holocene_era_coverage.csv"))

era_medians_observed = holo_site_date %>%
  filter(!is.na(climate_era_id)) %>%
  group_by(site, climate_era_id, climate_era_class) %>%
  summarize(across(all_of(DISPLAY_METRICS), safe_median),
            source_n = n(), .groups = "drop")
era_medians = era_coverage %>%
  select(site, climate_era_id, climate_era_class, coverage_status,
         n_site_dates) %>%
  left_join(era_medians_observed,
    by = c("site", "climate_era_id", "climate_era_class")) %>%
  mutate(
    source_n = coalesce(source_n, n_site_dates),
    t = NA_real_, n_offsets = if_else(source_n > 0L, 10L, NA_integer_),
    n_per_bin = NA_real_, plot_id = NA_character_,
    point_class = "holocene_site_era_median", macro_era = "Holocene",
    point_id = paste(site, climate_era_id, "median", sep = "_"),
    source_shape = "CC/S site median", label = climate_era_id,
    aggregate = TRUE
  ) %>%
  select(-n_site_dates)

viz_points = bind_rows(holo_site_date, anth_plot, overall_medians, era_medians) %>%
  select(point_class, macro_era, site, climate_era_id, climate_era_class,
         plot_id, point_id, t, n_offsets, n_per_bin, source_shape, label,
         source_n, aggregate, coverage_status, all_of(DISPLAY_METRICS)) %>%
  arrange(factor(point_class, levels = c(
    "holocene_site_interval", "anthropocene_plot",
    "holocene_site_era_median", "site_macro_era_median")),
    site, climate_era_id, t, plot_id)
write_csv(viz_points, here("output/cca_tracking_visualization_points.csv"))

# Resolution sensitivity is descriptive. It does not require the two temporal
# supports to agree, and it never changes the 1,000-year primary estimates.
AUDIT_METRICS = c("observed_turnover_rate", "rate_tracking_ratio", "lag",
                  "lag_rate_per_century", "angle_degrees")
summarize_resolution = function(x, resolution) {
  x %>%
    filter(metric %in% AUDIT_METRICS) %>%
    group_by(site, metric) %>%
    summarize(
      record_type = "timeseries summary", resolution = resolution,
      n_dates = n_distinct(t), t_min = min(t), t_max = max(t),
      n_valid = sum(is.finite(estimate)),
      estimate_median = safe_median(estimate),
      estimate_q25 = quantile(estimate[is.finite(estimate)], .25, names = FALSE),
      estimate_q75 = quantile(estimate[is.finite(estimate)], .75, names = FALSE),
      n_per_bin_median = safe_median(n_per_bin), .groups = "drop"
    )
}
summarize_support = function(x, resolution) {
  x %>% group_by(site) %>% summarize(
    record_type = "realization support", resolution = resolution,
    metric = "all", n_realizations = n(), n_offsets = n_distinct(offset),
    n_draws = n_distinct(draw), sparse_fraction = mean(sparse_bin),
    n_per_bin_median = median(n_min), .groups = "drop")
}
matched = holo_1000 %>%
  filter(metric %in% AUDIT_METRICS) %>%
  select(site, metric, t, estimate_1000 = estimate) %>%
  inner_join(holo_500 %>% filter(metric %in% AUDIT_METRICS) %>%
      select(site, metric, t, estimate_500 = estimate),
    by = c("site", "metric", "t")) %>%
  group_by(site, metric) %>%
  summarize(
    record_type = "matched-date comparison",
    resolution = "1000 minus 500 years", matched_n = n(),
    median_difference_1000_minus_500 = median(estimate_1000 - estimate_500,
      na.rm = TRUE),
    iqr_difference_1000_minus_500 = IQR(estimate_1000 - estimate_500,
      na.rm = TRUE),
    spearman_correlation = if (sum(is.finite(estimate_1000) &
        is.finite(estimate_500)) >= 3L)
      cor(estimate_1000, estimate_500, method = "spearman",
          use = "complete.obs") else NA_real_, .groups = "drop")

resolution_audit = bind_rows(
  summarize_resolution(holo_1000, "1000 years (primary)"),
  summarize_resolution(holo_500, "500 years (sensitivity)"),
  summarize_support(realization_1000, "1000 years (primary)"),
  summarize_support(realization_500, "500 years (sensitivity)"),
  matched
)
write_csv(resolution_audit,
          here("output/cca_tracking_interval_resolution_audit.csv"))

cat("Written site-level figure and resolution audits:\n",
    "  output/cca_tracking_visualization_points.csv\n",
    "  output/cca_tracking_holocene_era_coverage.csv\n",
    "  output/cca_tracking_interval_resolution_audit.csv\n", sep = "")
