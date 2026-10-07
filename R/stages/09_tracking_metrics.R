# =============================================================================
# 09_tracking_metrics.R - authoritative CCA tracking and climate-rate stage
# =============================================================================
# Run directly:
#   Rscript R/stages/09_tracking_metrics.R
#
# Reads the fitted pooled CCA and the primary 1,000-year x 100-year-phase x Bacon
# draw framework. Writes plot/realization/site-level tracking tables but no
# figures. Compatibility objects and CSVs are retained for the worked-method
# figure and provenance, but the retired offset figures are no longer drawn.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
})
if (!exists("extra_exclude")) extra_exclude = character(0)
if (!exists("cca_suffix")) cca_suffix = ""
# The primary run is 1,000 years. R/stages/09_tracking_metrics_500yr_sensitivity.R
# sets these objects before sourcing this file and writes explicitly suffixed
# sensitivity products. Anthropocene results are invariant to this setting.
if (!exists("TRACKING_OUTPUT_SUFFIX", inherits = FALSE))
  TRACKING_OUTPUT_SUFFIX = ""
if (identical(TRACKING_OUTPUT_SUFFIX, "_500yr")) {
  HOLO_BIN = 500
  OFFSETS = seq(0, 400, by = 100)
} else {
  # Force the primary contract locally. Do not inherit 500-year constants left
  # by the trajectory figure or another sourced stage in the workflow driver.
  HOLO_BIN = 1000
  OFFSETS = seq(0, 900, by = 100)
}
source(here("R/stages/05_cca_model.R"), local = TRUE)
source(here("R/helpers/paleo_runs.R"), local = TRUE)
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/tracking_metrics.R"), local = TRUE)

if (!exists("USE_CORRECTED")) USE_CORRECTED = PALEO_USE_BIAS_CORRECTED
if (!exists("TRACKING_EPS")) TRACKING_EPS = TRACKING_EPSILON

CLIM_VARS = CCA_CLIMATE_VARS
ALL_TRACKING_METRICS = all_cca_metric_names(CLIM_VARS)
METRICS = c("d_climate", "d_vegetation", "d_offset", "d_offset_vec")

holo_output = function(stem) {
  here("output", paste0(stem, TRACKING_OUTPUT_SUFFIX, ".csv"))
}

# =============================================================================
# NEW: FIXED CLIMATE STANDARDIZATION REFERENCE
# =============================================================================
climate_scaling = make_climate_scaling(env_past_final, CLIM_VARS)
write_csv(climate_scaling, here("output/cca_tracking_climate_scaling.csv"))

# Nominal climate-window midpoints. The four constraints share one LC endpoint,
# so its rate uses the documented window midpoint rather than variable-specific
# effective-year adjustments.

# =============================================================================
# NEW: HOLOCENE ENDPOINTS AND REALIZATION-LEVEL METRICS
# =============================================================================
# Climate belongs to fixed time bins, not samples. Each bin is the equally
# weighted site mean of its ponds and must contain every native 100-year slice.
N_CLIMATE_SLICES_PER_BIN = as.integer(HOLO_BIN / 100)
ponds = read_csv(here("output/chelsa_paleo_ponds.csv"), show_col_types = FALSE)

env_slice = ponds %>%
  transmute(unit = lake, period = "paleo", variable, time = slice, month,
            value = if (USE_CORRECTED) value_corrected else value_raw) %>%
  derive_climate_vars(winter_shift = FALSE) %>%
  rename(lake = unit, slice = time) %>%
  mutate(age = 1950 - slice * 100) %>%
  left_join(ponds %>% distinct(lake, site), by = "lake")

mora_spread = env_slice %>%
  filter(site == "MORA") %>%
  group_by(slice) %>%
  summarize(across(all_of(CLIM_VARS), ~ diff(range(.x))), .groups = "drop")
cat("\nMORA between-pond range at the same slice (max over slices):\n")
print(as.data.frame(mora_spread %>%
  summarize(across(all_of(CLIM_VARS), ~ round(max(.x), 3)))))

clim_bins = expand_grid(offset = OFFSETS, env_slice) %>%
  mutate(bin = floor((age - offset) / HOLO_BIN) * HOLO_BIN + offset,
         bin_mid = bin + HOLO_BIN / 2) %>%
  group_by(site, offset, bin_mid, lake) %>%
  summarize(across(all_of(CLIM_VARS), mean), n_slices = n(), .groups = "drop") %>%
  group_by(site, offset, bin_mid) %>%
  summarize(across(all_of(CLIM_VARS), mean), n_slices = min(n_slices),
            n_lakes = n(), .groups = "drop")

cat("\nclimate bins with fewer than ", N_CLIMATE_SLICES_PER_BIN,
    " native slices: ", sum(clim_bins$n_slices < N_CLIMATE_SLICES_PER_BIN),
    " of ", nrow(clim_bins), " (dropped)\n", sep = "")
clim_bins = clim_bins %>% filter(n_slices == N_CLIMATE_SLICES_PER_BIN)

clim_lc = predict(cca_model, newdata = as.data.frame(clim_bins[, CLIM_VARS]),
                  type = "lc", scaling = cca_scaling, hill = cca_hill)
clim_bins = clim_bins %>% mutate(p1 = clim_lc[, 1], p2 = clim_lc[, 2])

# Retain the established within-bin method: average sample WA positions within
# each age-draw realization. Do not pool sample presences into a union assemblage.
holo_obs = comparison_df %>%
  filter(era == "holocene") %>%
  select(plot_id, site, o1 = projected_CCA1, o2 = projected_CCA2)

runs = make_runs(bin_width = HOLO_BIN, offsets = OFFSETS)
obs_bins = runs %>%
  inner_join(holo_obs, by = "plot_id") %>%
  group_by(site, run_id, draw, offset, bin_mid) %>%
  summarize(o1 = mean(o1), o2 = mean(o2), n_samples = n(), .groups = "drop")

bins = obs_bins %>%
  inner_join(
    clim_bins %>% select(site, offset, bin_mid, p1, p2, all_of(CLIM_VARS)),
    by = c("site", "offset", "bin_mid")
  )

# t1 is the older bin and t2 the next younger bin. Lead every endpoint column,
# including the physical climate variables, before calculating any metric.
intervals_all = bins %>%
  arrange(site, run_id, desc(bin_mid)) %>%
  group_by(site, run_id) %>%
  mutate(across(c(o1, o2, p1, p2, n_samples, bin_mid, all_of(CLIM_VARS)),
                ~ lead(.x), .names = "{.col}_2")) %>%
  ungroup() %>%
  filter(!is.na(bin_mid_2)) %>%
  mutate(gap = bin_mid - bin_mid_2)

cat("\nintervals between non-adjacent bins (dropped): ",
    sum(intervals_all$gap != HOLO_BIN), " of ", nrow(intervals_all), "\n", sep = "")

intervals = intervals_all %>%
  filter(gap == HOLO_BIN) %>%
  mutate(
    vegetation_dt_years = as.numeric(HOLO_BIN),
    climate_dt_years = as.numeric(HOLO_BIN),
    n_min = pmin(n_samples, n_samples_2),
    sparse_bin = n_min < 2L,
    age_hi = bin_mid,
    age_lo = bin_mid_2
  ) %>%
  calculate_tracking_metrics(epsilon = TRACKING_EPS) %>%
  add_climate_change_metrics(climate_scaling, CLIM_VARS)

stopifnot(all(intervals$age_hi - intervals$age_lo == HOLO_BIN),
          all(intervals$offset %in% OFFSETS),
          !anyDuplicated(intervals %>% select(site, offset, draw, age_hi, age_lo)))

write_csv(intervals, holo_output("cca_tracking_holocene_realizations"))
write_csv(filter(intervals, n_min >= 2L),
          holo_output("cca_tracking_holocene_realizations_nmin2"))

# LEVEL 1: posterior summaries across age draws, separately within each offset
# and actual Holocene interval. These quantiles describe chronology uncertainty,
# not ecological replication and not confidence intervals.
holo_by_offset = summarize_metric_distribution(
  intervals,
  c("site", "offset", "age_hi", "age_lo"),
  ALL_TRACKING_METRICS
)

holo_interval_support = intervals %>%
  group_by(site, offset, age_hi, age_lo) %>%
  summarize(
    n_draws_present = n_distinct(draw),
    n_per_bin = median(n_min),
    n_small_predicted = sum(small_predicted_movement),
    n_small_observed = sum(small_observed_movement),
    .groups = "drop"
  )
holo_by_offset = holo_by_offset %>%
  left_join(holo_interval_support,
            by = c("site", "offset", "age_hi", "age_lo"))
write_csv(holo_by_offset, holo_output("cca_tracking_holocene_by_offset"))

# LEVEL 2: expose every per-offset step function on the established 100-year
# grid, then summarize the offset medians. Intervals are half-open on the older
# endpoint: age_lo <= t < age_hi. This prevents a boundary date from belonging
# to two adjacent intervals in the same offset. Posterior quantiles and phase
# sensitivity remain separate rather than being pooled.
grid = tibble(t = seq(floor(min(intervals$age_lo) / 100) * 100,
                      ceiling(max(intervals$age_hi) / 100) * 100, by = 100))

holo_by_offset_grid = holo_by_offset %>%
  inner_join(grid, by = join_by(y$t >= x$age_lo, y$t < x$age_hi))

if (anyDuplicated(holo_by_offset_grid %>%
    select(site, offset, metric, t)))
  stop("Half-open interval mapping produced duplicate site-offset-metric dates")

cat("\n(offset, interval) metric rows with fewer than 50% of ", N_DRAWS,
    " draws (retained and audited): ",
    sum(holo_by_offset$n_draws_present < 0.5 * N_DRAWS), " of ",
    nrow(holo_by_offset), "\n", sep = "")

holo_timeseries_all = holo_by_offset_grid %>%
  group_by(site, metric, unit, t) %>%
  summarize(
    estimate = median(median),
    age_q025 = median(q025),
    age_q975 = median(q975),
    phase_min = min(median),
    phase_q25 = quantile(median, 0.25),
    phase_q75 = quantile(median, 0.75),
    phase_max = max(median),
    n_offsets = n_distinct(offset),
    n_draws_min = min(n_draws_present),
    n_draws_median = median(n_draws_present),
    n_per_bin = median(n_per_bin),
    .groups = "drop"
  )

cat("grid points dropped (fewer than all ", length(OFFSETS), " offsets present): ",
    sum(holo_timeseries_all$n_offsets < length(OFFSETS)), " of ",
    nrow(holo_timeseries_all), "\n", sep = "")
holo_timeseries = holo_timeseries_all %>%
  filter(n_offsets == length(OFFSETS))
write_csv(holo_timeseries, holo_output("cca_tracking_holocene_timeseries"))

# Existing figure interfaces. These retain the historical names, but d_climate
# is now explicitly documented as predicted VEGETATION displacement from LC
# scores, not physical climate change.
by_offset = holo_by_offset_grid %>%
  filter(metric %in% c(
    "predicted_vegetation_displacement", "observed_vegetation_displacement",
    "change_in_lag", "tracking_error"
  )) %>%
  mutate(metric = recode(
    metric,
    predicted_vegetation_displacement = "d_climate",
    observed_vegetation_displacement = "d_vegetation",
    change_in_lag = "d_offset",
    tracking_error = "d_offset_vec"
  )) %>%
  transmute(site, metric, offset, t, med = median, lo = q025, hi = q975,
            n_draws = n_draws_present, n_per_bin)

series = by_offset %>%
  group_by(site, metric, t) %>%
  summarize(
    est = median(med),
    age_lo = median(lo),
    age_hi = median(hi),
    phase_min = min(med),
    phase_max = max(med),
    n_offsets = n_distinct(offset),
    n_per_bin = median(n_per_bin),
    .groups = "drop"
  ) %>%
  filter(n_offsets == length(OFFSETS))

write_csv(series, holo_output("offset_timeseries"))
write_csv(by_offset, holo_output("offset_timeseries_by_offset"))

# =============================================================================
# NEW: ANTHROPOCENE PLOT-LEVEL ENDPOINTS AND METRICS
# =============================================================================
past_scores = tibble(
  plot_id = rownames(species_past_paired),
  o1 = predict(cca_model, newdata = species_past_paired, type = "wa",
               scaling = cca_scaling, hill = cca_hill)[, 1],
  o2 = predict(cca_model, newdata = species_past_paired, type = "wa",
               scaling = cca_scaling, hill = cca_hill)[, 2],
  p1 = predict(cca_model, newdata = env_past_paired, type = "lc",
               scaling = cca_scaling, hill = cca_hill)[, 1],
  p2 = predict(cca_model, newdata = env_past_paired, type = "lc",
               scaling = cca_scaling, hill = cca_hill)[, 2]
) %>% bind_cols(as_tibble(env_past_paired) %>% select(all_of(CLIM_VARS)))

present_scores = tibble(
  plot_id = rownames(species_present_final),
  o1_2 = projected_present[, 1], o2_2 = projected_present[, 2],
  p1_2 = predicted_present[, 1], p2_2 = predicted_present[, 2]
) %>% bind_cols(
  as_tibble(env_present_final) %>%
    select(all_of(CLIM_VARS)) %>%
    rename_with(~ paste0(.x, "_2"))
)

# The cleaners resolved adult visits once. Climate windows and both elapsed
# times come from that same plot-year table; no seedling minima or site means.
source(here("R/helpers/survey_years.R"), local = TRUE)
resurvey_years = read_plot_years()

# Membership and finite WA/LC positions were resolved once in the CCA stage.
anth = tibble(plot_id = present_pairs) %>%
  left_join(past_scores, by = "plot_id") %>%
  left_join(present_scores, by = "plot_id") %>%
  left_join(site_lookup, by = "plot_id") %>%
  left_join(resurvey_years, by = c("site", "plot_id"))

if (anyNA(anth$vegetation_t2_year) ||
    any(!is.finite(anth$vegetation_dt_years) | anth$vegetation_dt_years <= 0))
  stop("Every Anthropocene modeled plot must have one valid positive vegetation interval")

anth = anth %>%
  calculate_tracking_metrics(epsilon = TRACKING_EPS) %>%
  add_climate_change_metrics(climate_scaling, CLIM_VARS) %>%
  mutate(dt = vegetation_dt_years)  # compatibility alias

cat("\nAnthropocene tracking pairs:\n")
print(as.data.frame(anth %>% count(site, name = "n_pairs")), row.names = FALSE)

write_csv(anth, here("output/cca_tracking_anthropocene_plot.csv"))
if (!nzchar(TRACKING_OUTPUT_SUFFIX)) {
  source(here("R/helpers/survey_decision_effects.R"), local = TRUE)
  export_survey_decision_effects(anth)
}

anth_support = anth %>%
  group_by(site) %>%
  summarize(
    n_plots = n(),
    n_small_predicted = sum(small_predicted_movement),
    n_small_observed = sum(small_observed_movement),
    vegetation_dt_min = min(vegetation_dt_years),
    vegetation_dt_max = max(vegetation_dt_years),
    climate_dt_min = min(climate_dt_years),
    climate_dt_max = max(climate_dt_years),
    climate_dt_median = median(climate_dt_years),
    .groups = "drop"
  )
anth_site = summarize_metric_distribution(
  anth, "site", ALL_TRACKING_METRICS
) %>% left_join(anth_support, by = "site")
write_csv(anth_site, here("output/cca_tracking_anthropocene_site.csv"))

# Compatibility objects/files consumed by the existing figures.
write_csv(anth, here("output/offset_anthropocene.csv"))
anth_long = anth %>%
  pivot_longer(all_of(METRICS), names_to = "metric", values_to = "value")

ANTH_VEG_DT_RANGE = anth %>%
  group_by(site) %>%
  summarize(dt_min = min(vegetation_dt_years),
            dt_max = max(vegetation_dt_years), .groups = "drop")
ANTH_VEG_DT_LABEL = setNames(
  ifelse(ANTH_VEG_DT_RANGE$dt_min == ANTH_VEG_DT_RANGE$dt_max,
         as.character(ANTH_VEG_DT_RANGE$dt_min),
         paste0(ANTH_VEG_DT_RANGE$dt_min, "-", ANTH_VEG_DT_RANGE$dt_max)),
  ANTH_VEG_DT_RANGE$site
)

TRACKING_METRICS_READY = TRUE

cat("\nWritten tracking outputs:\n",
    "  output/cca_tracking_climate_scaling.csv\n",
    "  output/cca_tracking_anthropocene_plot.csv\n",
    "  output/cca_tracking_anthropocene_site.csv\n",
    "  output/cca_tracking_holocene_realizations.csv\n",
    "  output/cca_tracking_holocene_by_offset.csv\n",
    "  output/cca_tracking_holocene_timeseries.csv\n",
    "  primary/suffixed Holocene interval outputs for ", HOLO_BIN,
    "-year bins\n", sep = "")
# =============================================================================
# END NEW TRACKING STAGE
# =============================================================================
