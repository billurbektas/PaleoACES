# Offline gate for the unified, literature-blind climate-era/fire analysis.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse)})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))
source(here("R/helpers/holocene_climate_fire_era_functions.R"), local = TRUE)

thresholds = read_csv(out("holocene_era_climate_variable_thresholds.csv"),
  show_col_types = FALSE)
phase = read_csv(out("holocene_era_climate_regional_phase_changes.csv"),
  show_col_types = FALSE)
cells = read_csv(out("holocene_era_climate_directional_cells.csv"),
  show_col_types = FALSE)
era_grid = read_csv(out("holocene_era_grid.csv"), show_col_types = FALSE)
eras = read_csv(out("holocene_era_catalog.csv"), show_col_types = FALSE)
drivers = read_csv(out("holocene_era_driver_subintervals.csv"),
  show_col_types = FALSE)
subphases = read_csv(out("holocene_era_climate_change_subphases.csv"),
  show_col_types = FALSE)
site_changes = read_csv(out("holocene_era_climate_site_phase_changes.csv"),
  show_col_types = FALSE)
composite = read_csv(out("holocene_era_climate_composite_site_phase.csv"),
  show_col_types = FALSE)
rate_comparison = read_csv(
  out("figures/holocene_anthropocene_raw_climate_rate_comparison.csv"),
  show_col_types = FALSE)
anthropocene_climate = read_csv(
  out("cca_tracking_anthropocene_plot_calculations.csv"), show_col_types = FALSE)

stopifnot(
  setequal(thresholds$variable, CCA_VARIABLES),
  all(thresholds$threshold_fraction_of_maximum == .5),
  all(thresholds$required_phases == 8L),
  isTRUE(all.equal(thresholds$threshold_standardized_change,
    .5 * thresholds$maximum_absolute_regional_change)),
  setequal(unique(phase$offset), seq(0, 900, 100)),
  all(cells$n_phases == 10L),
  all(cells$phase_direction_support >= 0L &
      cells$phase_direction_support <= 10L),
  !any(c("site_divergent", "transition", "forward_extension") %in% names(cells)),
  identical(range(era_grid$t), c(1300, 9500)),
  nrow(eras) == 10L)

# Recalculate the regional medians, phase support, and any-variable union.
recalc = phase |>
  group_by(variable, t) |>
  summarise(regional_score_check = median(regional_score),
    direction = sign(regional_score_check),
    support_check = sum(sign(regional_score) == direction &
      sign(regional_score) != 0), .groups = "drop")
stopifnot(isTRUE(all.equal(
  cells |> arrange(variable, t) |> pull(regional_score),
  recalc |> arrange(variable, t) |> pull(regional_score_check))),
  isTRUE(all.equal(cells |> arrange(variable, t) |> pull(phase_direction_support),
    recalc |> arrange(variable, t) |> pull(support_check))))
union_check = cells |> group_by(t) |>
  summarise(class_check = ifelse(any(qualifies), "climate change",
    "relative stability"), .groups = "drop")
stopifnot(identical(
  era_grid |> arrange(t) |> pull(era_class),
  union_check |> arrange(t) |> pull(class_check)))

# Regression: the eras classified from the MSpT + SP constraints (2026-11-09).
expected = tribble(
  ~era_id, ~era_class, ~older_cal_bp, ~younger_cal_bp,
  "C1", "climate change", 9600, 8600,
  "S1", "relative stability", 8600, 8200,
  "C2", "climate change", 8200, 7200,
  "S2", "relative stability", 7200, 6800,
  "C3", "climate change", 6800, 6200,
  "S3", "relative stability", 6200, 5400,
  "C4", "climate change", 5400, 4900,
  "S4", "relative stability", 4900, 2200,
  "C5", "climate change", 2200, 1700,
  "S5", "relative stability", 1700, 1300)
stopifnot(isTRUE(all.equal(
  eras |> select(era_id, era_class, older_cal_bp, younger_cal_bp) |>
    arrange(desc(older_cal_bp)), expected, check.attributes = FALSE)),
  all(drivers$direction %in% c("increasing", "decreasing")))

# No climate-change era contains a sustained internal driver trough, so none is
# split; driver labels require >=60% cell coverage.
stopifnot(
  identical(subphases$subphase_id, c("C1", "C2", "C3", "C4", "C5")),
  all(subphases$phase_role == "unsplit"),
  identical(subphases$active_driver_labels[1:2], c(
    "spring cooling;summer drying", "spring warming;summer wetting")),
  all(subphases$driver_coverage_rule == 0.60))

# Raw-rate table uses equal-site Holocene physical changes and the plot-level
# Anthropocene physical rates; both are expressed per century.
rate_holo_check = phase |>
  mutate(raw_rate = ((signed_change_MORA + signed_change_NOCA) / 2) / 10) |>
  group_by(variable, t) |>
  summarise(raw_rate = median(raw_rate), .groups = "drop") |>
  group_by(variable) |>
  slice_max(abs(raw_rate), n = 1, with_ties = FALSE) |>
  ungroup() |>
  arrange(match(variable, CCA_VARIABLES))
rate_anthro_check = anthropocene_climate |>
  select(plot_id, site,
    all_of(paste0(CCA_VARIABLES, "_rate_per_century"))) |>
  pivot_longer(ends_with("_rate_per_century"), names_to = "variable",
    values_to = "rate") |>
  mutate(variable = str_remove(variable, "_rate_per_century$")) |>
  group_by(variable, site) |>
  summarise(rate = median(rate), .groups = "drop") |>
  pivot_wider(names_from = site, values_from = rate) |>
  arrange(match(variable, CCA_VARIABLES))
stopifnot(
  isTRUE(all.equal(rate_comparison$holocene_max_signed_rate_per_century,
    rate_holo_check$raw_rate)),
  identical(rate_comparison$holocene_peak_cal_bp, rate_holo_check$t),
  isTRUE(all.equal(
    rate_comparison$anthropocene_median_rate_per_century_MORA,
    rate_anthro_check$MORA)),
  isTRUE(all.equal(
    rate_comparison$anthropocene_median_rate_per_century_NOCA,
    rate_anthro_check$NOCA)))

# Independently recalculate the unsigned composite at the realization level.
composite_check = site_changes |>
  group_by(site, t, offset) |>
  summarise(check = sqrt(sum(standardized_signed_change^2)), .groups = "drop")
stopifnot(isTRUE(all.equal(
  composite |> arrange(site, t, offset) |> pull(composite_magnitude),
  composite_check |> arrange(site, t, offset) |> pull(check))))

# Fire settings, normalization, equal-core aggregation, robust thresholds, and
# every contiguous above-threshold run are independently checked.
fire_settings = read_csv(out("holocene_era_fire_source_settings.csv"),
  show_col_types = FALSE)
core = read_csv(out("holocene_era_fire_core_frequency.csv"),
  show_col_types = FALSE)
site = read_csv(out("holocene_era_fire_site_frequency.csv"),
  show_col_types = FALSE)
fire_thresholds = read_csv(out("holocene_era_fire_thresholds.csv"),
  show_col_types = FALSE)
periods = read_csv(out("holocene_era_high_fire_periods.csv"),
  show_col_types = FALSE)
events = read_csv(out("holocene_fire_source_events.csv"),
  show_col_types = FALSE)
fire_ratio = read_csv(out("figures/holocene_era_fire_threshold_ratio.csv"),
  show_col_types = FALSE)
fire_example = read_csv(
  out("worked_examples/holocene_fire_method_worked_example.csv"),
  show_col_types = FALSE)
stopifnot(
  nrow(fire_settings) == 4L,
  all(fire_settings$engine == "tapas"),
  identical(fire_settings$interpolation_years, c(48, 47, 42, 12)),
  identical(fire_settings$background_years, c(800, 1000, 500, 500)),
  identical(fire_settings$peak_probability, c(.95, .95, .95, .99)),
  fire_settings$interpolation_years[fire_settings$lake == "PantherPotholes"] == 12,
  fire_settings$background_years[fire_settings$lake == "PantherPotholes"] == 500,
  fire_settings$peak_probability[fire_settings$lake == "PantherPotholes"] == .99,
  sum(events$lake == "PantherPotholes") == 66L,
  all(abs((core$peak_frequency_per_1000yr / core$core_max_frequency) -
    core$normalized_frequency) < 1e-12),
  all(core |> group_by(site, lake) |>
    summarise(mx = max(normalized_frequency), .groups = "drop") |> pull(mx) == 1))

mora_check = core |> filter(site == "MORA") |>
  group_by(cal_bp) |>
  summarise(covered = sum(is.finite(normalized_frequency)),
    check = ifelse(covered >= 2, mean(normalized_frequency), NA_real_),
    .groups = "drop") |>
  inner_join(site |> filter(site == "MORA"), by = "cal_bp") |>
  filter(covered >= 2)
stopifnot(isTRUE(all.equal(mora_check$check, mora_check$normalized_frequency)))
threshold_check = site |> group_by(site) |>
  summarise(med = median(normalized_frequency, na.rm = TRUE),
    rsd = robust_sd(normalized_frequency), threshold = med + rsd,
    .groups = "drop") |>
  arrange(site)
stopifnot(isTRUE(all.equal(threshold_check$threshold,
  fire_thresholds |> arrange(site) |> pull(high_fire_threshold))))

period_check = site |> filter(is.finite(normalized_frequency)) |>
  arrange(site, cal_bp) |> group_by(site) |>
  mutate(run_id = cumsum(high_fire != lag(high_fire,
    default = first(high_fire))) + 1L) |>
  filter(high_fire) |> group_by(site, run_id) |>
  summarise(older_cal_bp = max(cal_bp) + 50,
    younger_cal_bp = min(cal_bp) - 50, .groups = "drop")
stopifnot(isTRUE(all.equal(
  periods |> select(site, run_id, older_cal_bp, younger_cal_bp), period_check,
  check.attributes = FALSE)),
  sum(periods$site == "MORA") == 5L,
  sum(periods$site == "NOCA") == 6L)

# The display ratio is exactly normalized frequency / the already-frozen
# site-specific robust threshold. It visualizes, but does not redefine, fire.
fire_ratio_check = site |>
  filter(between(cal_bp, 0, 10500), is.finite(normalized_frequency),
    is.finite(high_fire_threshold), high_fire_threshold > 0) |>
  transmute(site, cal_bp,
    check_ratio = normalized_frequency / high_fire_threshold,
    check_high_fire = high_fire) |>
  inner_join(fire_ratio |>
      select(site, cal_bp, high_fire_ratio, high_fire),
    by = c("site", "cal_bp"))
stopifnot(
  nrow(fire_ratio_check) == nrow(fire_ratio),
  max(abs(fire_ratio_check$check_ratio -
          fire_ratio_check$high_fire_ratio)) < 1e-12,
  all(fire_ratio_check$check_high_fire == fire_ratio_check$high_fire),
  all(fire_ratio$high_fire == (fire_ratio$high_fire_ratio > 1))
)

# The worked example is an auditable slice of the same frozen method. Event
# counts are independently recovered from the half-open [1,800, 2,800) window.
example_counts = events |>
  filter(age_cal_yr_BP >= 1800, age_cal_yr_BP < 2800) |>
  count(site, lake, name = "count_check")
example_check = fire_example |>
  left_join(example_counts, by = c("site", "lake")) |>
  mutate(count_check = coalesce(count_check, 0L))
stopifnot(
  nrow(fire_example) == 4L,
  all(fire_example$example_cal_bp == 2300),
  all(fire_example$window_younger_cal_bp == 1800),
  all(fire_example$window_older_cal_bp == 2800),
  identical(fire_example$accepted_event_count, c(3, 2, 3, 7)),
  all(example_check$accepted_event_count == example_check$count_check),
  max(abs(fire_example$normalized_core_frequency -
      fire_example$frequency_per_1000_years /
        fire_example$core_max_frequency)) < 1e-12,
  abs(unique(fire_example$normalized_site_frequency[
      fire_example$site == "MORA"]) -
    mean(fire_example$normalized_core_frequency[
      fire_example$site == "MORA"])) < 1e-12,
  abs(unique(fire_example$normalized_site_frequency[
      fire_example$site == "NOCA"]) -
    fire_example$normalized_core_frequency[fire_example$site == "NOCA"]) <
      1e-12,
  max(abs(fire_example$high_fire_threshold -
      (fire_example$threshold_median +
       fire_example$threshold_robust_sd))) < 1e-12,
  max(abs(fire_example$fire_frequency_ratio -
      fire_example$normalized_site_frequency /
        fire_example$high_fire_threshold)) < 1e-12,
  all(fire_example$high_fire ==
      (fire_example$fire_frequency_ratio > 1)),
  all(fire_example$high_fire[fire_example$site == "MORA"]),
  !any(fire_example$high_fire[fire_example$site == "NOCA"])
)

# No literature input or retired state machine may influence the stage.
source_text = paste(readLines(here("R/pipeline/11_climate_eras_high_fire.R"),
  warn = FALSE), collapse = "\n")
helper_text = paste(readLines(here("R/helpers/holocene_climate_fire_era_functions.R"),
  warn = FALSE), collapse = "\n")
figure_text = paste(readLines(here("R/figures/main_fig2_climate_eras_fire.R"),
  warn = FALSE), collapse = "\n")
stopifnot(!grepl("holocene_period_candidates", source_text, fixed = TRUE),
  !grepl("forward_state", paste(source_text, helper_text), fixed = TRUE),
  grepl('"Holocene max", "Anthropocene MORA", "Anthropocene NOCA"',
    figure_text, fixed = TRUE),
  grepl("`Holocene max` = holocene_max_signed_rate_per_century",
    figure_text, fixed = TRUE))


required_figures = c(fig("main", "fig_climate_levels_eras_fire.pdf"),
  fig("worked_examples", "fig_holocene_climate_period_method_worked_example.pdf"),
  fig("worked_examples", "fig_holocene_fire_method_worked_example.pdf"))
if (render_figures)
  stopifnot(all(file.exists(required_figures)),
            all(file.info(required_figures)$size > 10000))
cat("PASS: unified climate eras and independent fire periods",
    if (render_figures) ", including figures.\n" else ".\n", sep = "")
