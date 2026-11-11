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
  # Bins start halfway between slice centres (x50 cal BP, config.R).
  setequal(unique(phase$offset), seq(50, 950, 100)),
  all(cells$n_phases == 10L),
  all(cells$phase_direction_support >= 0L &
      cells$phase_direction_support <= 10L),
  !any(c("site_divergent", "transition", "forward_extension") %in% names(cells)),
  identical(range(era_grid$t), c(1350, 9550)),  # 1300 to 9500 before the slice dating fix
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

# Regression: the eras classified from the MSpT + SP constraints (2026-11-09),
# every boundary 50 years older since the slice dating fix (2026-11-11).
expected = tribble(
  ~era_id, ~era_class, ~older_cal_bp, ~younger_cal_bp,
  "C1", "climate change", 9650, 8650,
  "S1", "relative stability", 8650, 8250,
  "C2", "climate change", 8250, 7250,
  "S2", "relative stability", 7250, 6850,
  "C3", "climate change", 6850, 6250,
  "S3", "relative stability", 6250, 5450,
  "C4", "climate change", 5450, 4950,
  "S4", "relative stability", 4950, 2250,
  "C5", "climate change", 2250, 1750,
  "S5", "relative stability", 1750, 1350)
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

# Fire settings and the fire frequency (Bills, 11 Nov 2026: the high-fire
# classification was dropped; Figure 3C shows events per 1,000 years). Every
# window count is recounted from the accepted events, and the park series is
# checked as the mean over the covered cores.
fire_settings = read_csv(out("holocene_era_fire_source_settings.csv"),
  show_col_types = FALSE)
core = read_csv(out("holocene_era_fire_core_frequency.csv"),
  show_col_types = FALSE)
site = read_csv(out("holocene_era_fire_site_frequency.csv"),
  show_col_types = FALSE)
events = read_csv(out("holocene_fire_source_events.csv"),
  show_col_types = FALSE)
stopifnot(
  nrow(fire_settings) == 4L,
  all(fire_settings$engine == "tapas"),
  identical(fire_settings$interpolation_years, c(48, 47, 42, 12)),
  identical(fire_settings$background_years, c(800, 1000, 500, 500)),
  identical(fire_settings$peak_probability, c(.95, .95, .95, .99)),
  sum(events$lake == "PantherPotholes") == 66L,
  all(core$window_years == 1000),
  all(abs(core$peak_frequency_per_1000yr - core$accepted_event_count) < 1e-12),
  # The dropped classification leaves no columns or tables behind.
  !any(c("normalized_frequency", "high_fire", "high_fire_threshold") %in% c(names(core), names(site))),
  !file.exists(out("holocene_era_high_fire_periods.csv")),
  !file.exists(out("holocene_era_fire_thresholds.csv")))
# Independent recount of every window: events in [t - 500, t + 500).
recount = vapply(seq_len(nrow(core)), function(i) {
  e = events$age_cal_yr_BP[events$lake == core$lake[i]]
  sum(e >= core$cal_bp[i] - 500 & e < core$cal_bp[i] + 500)
}, numeric(1))
stopifnot(all(recount == core$accepted_event_count))
site_check = core |> group_by(site, cal_bp) |>
  summarise(covered = sum(is.finite(peak_frequency_per_1000yr)),
    check = ifelse(first(site) == "MORA" & covered < 2, NA_real_, mean(peak_frequency_per_1000yr)),
    .groups = "drop") |>
  inner_join(site, by = c("site", "cal_bp"))
stopifnot(nrow(site_check) == nrow(site), all(site_check$covered == site_check$covered_cores),
  identical(is.na(site_check$check), is.na(site_check$events_per_1000yr)),
  isTRUE(all.equal(site_check$check[!is.na(site_check$check)],
    site_check$events_per_1000yr[!is.na(site_check$events_per_1000yr)])))

# No literature input or retired state machine may influence the stage.
source_text = paste(readLines(here("R/pipeline/11_climate_eras_fire_frequency.R"),
  warn = FALSE), collapse = "\n")
helper_text = paste(readLines(here("R/helpers/holocene_climate_fire_era_functions.R"),
  warn = FALSE), collapse = "\n")
figure_text = paste(readLines(here("R/figures/main_fig3_climate_eras_fire.R"),
  warn = FALSE), collapse = "\n")
stopifnot(!grepl("holocene_period_candidates", source_text, fixed = TRUE),
  !grepl("forward_state", paste(source_text, helper_text), fixed = TRUE),
  grepl('"Holocene max", "Anthropocene MORA", "Anthropocene NOCA"',
    figure_text, fixed = TRUE),
  grepl("`Holocene max` = holocene_max_signed_rate_per_century",
    figure_text, fixed = TRUE))


required_figures = c(fig("main", "fig_climate_levels_eras_fire.pdf"),
  fig("worked_examples", "fig_holocene_climate_period_method_worked_example.pdf"))
if (render_figures)
  stopifnot(all(file.exists(required_figures)),
            all(file.info(required_figures)$size > 10000))
cat("PASS: unified climate eras and the fire frequency of each park",
    if (render_figures) ", including figures.\n" else ".\n", sep = "")
