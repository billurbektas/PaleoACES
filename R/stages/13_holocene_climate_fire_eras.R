# =============================================================================
# 13_holocene_climate_fire_eras.R
# =============================================================================
# Literature-blind unified Holocene climate-era and high-fire-period analysis.
# Climate and fire are classified independently. This stage freezes the era
# grid; site-level vegetation tracking joins it later without moving boundaries.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(patchwork)
})
source(here("R/helpers/config.R"))
source(here("R/helpers/climate_variables.R"))
source(here("R/helpers/holocene_climate_fire_era_functions.R"))
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

CLIMATE_INPUT = here("output/chelsa_paleo_ponds.csv")
CLIMATE_SCALING = here("output/cca_tracking_climate_scaling.csv")
FIRE_EVENTS = here("output/holocene_fire_source_events.csv")
FIRE_SERIES = here("output/holocene_fire_source_series.csv")
FIRE_SETTINGS = here("output/holocene_fire_source_settings.csv")
required = c(CLIMATE_INPUT, CLIMATE_SCALING, FIRE_EVENTS, FIRE_SERIES,
             FIRE_SETTINGS)
if (!all(file.exists(required))) stop("Missing unified-era input(s): ",
  paste(required[!file.exists(required)], collapse = ", "),
  ". Run tracking and R/stages/12_walsh_fire_reproduction.R first.")

# The interpretive stage is read-only with respect to the fitted analysis,
# climate caches, chronology products, and active paleo-fire assignments.
protected_paths = c(
  here("output/MORA_climate.csv"), here("output/NOCA_climate.csv"),
  here("output/chelsa_paleo_ponds.csv"),
  here("output/cca_tracking_climate_scaling.csv"),
  here("output/cca_tracking_anthropocene_plot.csv"),
  here("output/cca_tracking_anthropocene_site.csv"),
  here("output/cca_tracking_holocene_realizations.csv"),
  here("output/cca_tracking_holocene_by_offset.csv"),
  here("output/cca_tracking_holocene_timeseries.csv"),
  here("output/bacon_run_manifest.csv"), here("output/fire_walsh.csv"),
  here("output/paleo_fire.csv"))
if (file.exists(here("output/bacon_run_manifest.csv"))) {
  bacon_manifest = read_csv(here("output/bacon_run_manifest.csv"),
    show_col_types = FALSE)
  bacon_products = unique(c(bacon_manifest$control_file,
    bacon_manifest$posterior_file, bacon_manifest$ages_file))
  protected_paths = c(protected_paths, here(bacon_products))
}
protected_paths = protected_paths[file.exists(protected_paths)]
protected_before = unname(tools::md5sum(protected_paths))

PRIMARY_VARS = c("MSpT", "MWT", "SP", "WP")
if (!identical(CCA_VARIABLES, PRIMARY_VARS))
  stop("CCA variables changed; review the unified-era contract.")
VARIABLE_UNITS = c(MSpT = "deg C", MWT = "deg C", SP = "mm", WP = "mm")
VARIABLE_LABELS = c(MSpT = "Spring temperature", MWT = "Winter temperature",
                    SP = "Summer precipitation", WP = "Winter precipitation")
THRESHOLD_FRACTION = 0.50
REQUIRED_PHASES = 8L

# =============================================================================
# CLIMATE: signed, calibration-standardized 1,000-year changes
# =============================================================================
ponds = read_csv(CLIMATE_INPUT, show_col_types = FALSE)
levels = ponds |>
  transmute(unit = lake, period = site, variable, time = slice, month,
            value = value_raw) |>
  derive_climate_vars(winter_shift = FALSE) |>
  rename(lake = unit, site = period, slice = time) |>
  mutate(cal_bp = 1950 - slice * 100) |>
  select(site, lake, cal_bp, all_of(PRIMARY_VARS))
counts = levels |> count(site, lake, name = "n_slices")
if (nrow(counts) != 4L || any(counts$n_slices != 111L) ||
    any(is.na(levels[PRIMARY_VARS])))
  stop("Expected four complete 111-slice lake climate trajectories.")

climate_raw = build_climate_changes_1000yr(levels, PRIMARY_VARS,
  VARIABLE_UNITS)
scaling = read_csv(CLIMATE_SCALING, show_col_types = FALSE) |>
  filter(variable %in% PRIMARY_VARS)
if (nrow(scaling) != 4L || any(!is.finite(scaling$sd)) || any(scaling$sd <= 0))
  stop("Legacy CCA climate scaling is incomplete or invalid.")

climate = classify_climate_era_union(climate_raw$site_cells, scaling,
  fraction = THRESHOLD_FRACTION, required_phases = REQUIRED_PHASES)
composite = calculate_climate_composite(climate$site_standardized)

era_domain = range(climate$era_grid$t)
if (!identical(era_domain, c(1300, 9500)))
  stop("Complete ten-phase climate domain changed; review before interpreting eras.")

direction_terms = climate$drivers |>
  mutate(driver_label = case_when(
    variable == "MSpT" & direction == "increasing" ~ "spring warming",
    variable == "MSpT" ~ "spring cooling",
    variable == "MWT" & direction == "increasing" ~ "winter warming",
    variable == "MWT" ~ "winter cooling",
    variable == "SP" & direction == "increasing" ~ "summer wetting",
    variable == "SP" ~ "summer drying",
    variable == "WP" & direction == "increasing" ~ "winter wetting",
    TRUE ~ "winter drying"))
era_catalog = climate$era_catalog |>
  mutate(active_variable_directions = map2_chr(
    older_cal_bp, younger_cal_bp, function(era_old, era_young) {
      direction_terms |>
        filter(.data$older_cal_bp > era_young,
               .data$younger_cal_bp < era_old) |>
        pull(.data$driver_label) |> unique() |> paste(collapse = ";")
    })) |>
  mutate(analytical_status = paste(
    "literature-blind operational era; joined downstream to descriptive",
    "site-level tracking summaries without changing boundaries"))

# Descriptive subdivisions are permitted only where an internal, sustained
# low-driver interval separates two multi-driver parts of a climate-change era.
climate_subphases = subdivide_climate_change_eras(
  climate$variable_cells, era_catalog, min_trough_years = 300L,
  driver_coverage = 0.60)

# =============================================================================
# FIRE: source-specific accepted events, independent 1,000-year frequency rule
# =============================================================================
events = read_csv(FIRE_EVENTS, show_col_types = FALSE)
continuous = read_csv(FIRE_SERIES, show_col_types = FALSE)
fire = calculate_fire_frequency(events, continuous, 1000L, 100L)

fire_settings = read_csv(FIRE_SETTINGS, show_col_types = FALSE) |>
  transmute(site, lake, engine, chronology, interpolation_years,
    background_years = smoothing_years,
    peak_probability = threshold_probability,
    minimum_count_probability, minimum_count_window_years,
    analytical_role = if_else(site == "MORA",
      "regional MORA evidence; Walsh settings implemented in tapas",
      "local Panther Potholes evidence; Prichard-style settings implemented in tapas"))
if (nrow(fire_settings) != 4L || any(fire_settings$engine != "tapas"))
  stop("High-fire periods require four all-tapas source settings.")

# =============================================================================
# AUDIT OUTPUTS
# =============================================================================
write_csv(climate_raw$lake, here("output/holocene_era_climate_lake_changes.csv"))
write_csv(climate$site_standardized,
  here("output/holocene_era_climate_site_phase_changes.csv"))
write_csv(climate$regional_phases,
  here("output/holocene_era_climate_regional_phase_changes.csv"))
write_csv(climate$thresholds,
  here("output/holocene_era_climate_variable_thresholds.csv"))
write_csv(climate$variable_cells,
  here("output/holocene_era_climate_directional_cells.csv"))
write_csv(climate$era_grid, here("output/holocene_era_grid.csv"))
write_csv(era_catalog, here("output/holocene_era_catalog.csv"))
write_csv(direction_terms, here("output/holocene_era_driver_subintervals.csv"))
write_csv(climate_subphases,
  here("output/holocene_era_climate_change_subphases.csv"))
write_csv(composite$site_phase,
  here("output/holocene_era_climate_composite_site_phase.csv"))
write_csv(composite$regional_phase,
  here("output/holocene_era_climate_composite_regional_phase.csv"))
write_csv(composite$grid,
  here("output/holocene_era_climate_composite_grid.csv"))
write_csv(fire_settings, here("output/holocene_era_fire_source_settings.csv"))
write_csv(fire$coverage, here("output/holocene_era_fire_core_coverage.csv"))
write_csv(fire$core, here("output/holocene_era_fire_core_frequency.csv"))
write_csv(fire$site_grid, here("output/holocene_era_fire_site_frequency.csv"))
write_csv(fire$thresholds, here("output/holocene_era_fire_thresholds.csv"))
write_csv(fire$periods, here("output/holocene_era_high_fire_periods.csv"))
write_csv(fire$corroboration_core,
  here("output/holocene_era_fire_corroboration_core.csv"))
write_csv(fire$corroboration_site,
  here("output/holocene_era_fire_corroboration_site.csv"))
write_csv(tribble(
  ~field, ~value,
  "climate_interval_years", "1000",
  "climate_offsets", paste(seq(0, 900, 100), collapse = ";"),
  "threshold_fraction_of_variable_maximum", "0.50",
  "threshold_population", "absolute maximum of median equal-weight MORA-NOCA regional standardized change",
  "phase_support", "at least 8 of 10 regional phases match the median regional direction",
  "site_direction_veto", "FALSE; site trajectories retained for audit",
  "era_union", "climate change if any of MSpT, MWT, SP, or WP qualifies",
  "subphase_rule", "split a CC era only at an internal >=300-year minimum-active-driver trough flanked by multi-driver cells",
  "subphase_driver_label", "driver active in >=60% of subphase cells",
  "gap_bridging", "FALSE",
  "composite_role", "unsigned unthresholded context only",
  "fire_interval_years", "centered 1000-year accepted-event frequency",
  "fire_threshold", "site median + 1.4826 * MAD of normalized frequency",
  "fire_gap_or_duration_filter", "none",
  "literature_used", "FALSE",
  "tracking_periods_assigned", "FALSE"),
  here("output/holocene_era_settings.csv"))

# =============================================================================
# SINGLE-PAGE INTEGRATED FIGURE
# =============================================================================
site_cols = c(MORA = "#1769AA", NOCA = "#D56B22")
variable_cols = c(MSpT = "#D73027", MWT = "#4575B4",
                  SP = "#E6AB02", WP = "#1B9E77")
direction_cols = c(increasing = "#C84335", decreasing = "#2675B8",
                   `not qualifying` = "grey88")
era_cols = c(`climate change` = "#B85C38", `relative stability` = "#D9E2E8")
fire_cols = site_cols
time_scale = function() scale_x_reverse(limits = c(11000, -100),
  breaks = c(10000, 8000, 6000, 4000, 2000, 0),
  labels = scales::label_number(big.mark = ","))
shade_incomplete = function() list(
  annotate("rect", xmin = 9600, xmax = 11000, ymin = -Inf, ymax = Inf,
    fill = "grey80", alpha = .22),
  annotate("rect", xmin = -100, xmax = 1300, ymin = -Inf, ymax = Inf,
    fill = "grey80", alpha = .22))

threshold_lines = climate$thresholds |>
  select(variable, threshold_standardized_change) |>
  crossing(sign = c(-1, 1)) |>
  mutate(y = sign * threshold_standardized_change)
p1 = ggplot(climate$variable_cells,
  aes(t, regional_score, color = variable)) +
  shade_incomplete() + geom_hline(yintercept = 0, color = "grey65") +
  geom_hline(data = threshold_lines, aes(yintercept = y),
    inherit.aes = FALSE, linetype = 2, color = "grey35") +
  geom_line(linewidth = .7) +
  geom_point(data = filter(climate$variable_cells, qualifies), size = 1.5) +
  facet_wrap(~variable, nrow = 1) + time_scale() +
  scale_color_manual(values = variable_cols) + theme_bw(base_size = 9) +
  theme(legend.position = "none", panel.grid.minor = element_blank()) +
  labs(title = "A. Signed 1,000-year climate change",
    subtitle = "Regional median in pooled legacy-calibration SD units; dashed = 50% of each variable's maximum",
    x = NULL, y = "Signed standardized change")

bands = climate$variable_cells |>
  mutate(display = if_else(qualifies, direction, "not qualifying"))
p2 = ggplot(bands, aes(t, variable, fill = display)) +
  shade_incomplete() + geom_tile(width = 100, height = .82) + time_scale() +
  scale_fill_manual(values = direction_cols) + theme_bw(base_size = 9) +
  theme(panel.grid = element_blank(), legend.position = "bottom") +
  labs(title = "B. Variable-specific directional cells",
    subtitle = "Direction comes from the regional score; no MORA-NOCA agreement veto",
    x = NULL, y = NULL, fill = NULL)

era_plot = climate$era_grid |>
  mutate(y = "Unified era")
p3 = ggplot(era_plot, aes(t, y, fill = era_class)) +
  shade_incomplete() + geom_tile(width = 100, height = .8) +
  geom_text(data = era_catalog, aes(x = (older_cal_bp + younger_cal_bp) / 2,
    y = "Unified era", label = era_id), inherit.aes = FALSE, size = 3) +
  time_scale() + scale_fill_manual(values = era_cols) + theme_bw(base_size = 9) +
  theme(panel.grid = element_blank(), legend.position = "bottom") +
  labs(title = "C. Any-variable union", subtitle =
    "Any qualifying variable creates climate change; contiguous cells only; gray margins lack all ten phases",
    x = NULL, y = NULL, fill = NULL)

composite_long = composite$grid |>
  select(t, MORA, NOCA, Regional = regional_composite) |>
  pivot_longer(-t, names_to = "series", values_to = "magnitude")
p4 = ggplot(composite_long, aes(t, magnitude, color = series)) +
  shade_incomplete() + geom_line(linewidth = .75) + time_scale() +
  scale_color_manual(values = c(site_cols, Regional = "black")) +
  theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(),
    legend.position = "bottom") +
  labs(title = "D. Unthresholded four-variable composite",
    subtitle = "Euclidean magnitude is contextual and non-directional; it cannot define an era",
    x = NULL, y = "Climate displacement (calibration SD units)", color = NULL)

p5 = ggplot(filter(fire$site_grid, between(cal_bp, -100, 11000)),
  aes(cal_bp, normalized_frequency, color = site)) +
  geom_line(linewidth = .8, na.rm = TRUE) +
  geom_line(aes(y = high_fire_threshold), linetype = 2, linewidth = .55) +
  time_scale() + scale_color_manual(values = fire_cols) + theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom") +
  labs(title = "E. Independent centered 1,000-year fire-event frequency",
    subtitle = "Each core is normalized to its own maximum; MORA is an equal-core mean where >=2 cores are covered",
    x = NULL, y = "Normalized accepted-event frequency", color = NULL)

fire_band = fire$site_grid |>
  filter(is.finite(normalized_frequency), between(cal_bp, -100, 11000)) |>
  mutate(state = if_else(high_fire, "high fire", "not high fire"))
markers = fire$corroboration_site |>
  filter(corroborates, between(cal_bp, -100, 11000)) |>
  mutate(marker = recode(stream,
    peak_strength_percentile_sum = "peak strength",
    background_char_z = "background CHAR"))
p6 = ggplot(fire_band, aes(cal_bp, site, fill = state)) +
  geom_tile(width = 100, height = .72) +
  geom_point(data = markers, aes(cal_bp, site, shape = marker),
    inherit.aes = FALSE, size = 1.7, color = "black") +
  time_scale() +
  scale_fill_manual(values = c(`high fire` = "#B22222",
    `not high fire` = "grey90")) +
  scale_shape_manual(values = c(`peak strength` = 17, `background CHAR` = 18)) +
  theme_bw(base_size = 9) + theme(panel.grid = element_blank(),
    legend.position = "bottom") +
  labs(title = "F. High-fire periods and corroboration",
    subtitle = "Frequency alone selects periods; symbols show independent strength/background support",
    x = "cal BP (older to younger)", y = NULL, fill = NULL, shape = NULL)

# =============================================================================
# REVISED WORKED EXAMPLE
# =============================================================================
example_phase = climate$regional_phases |>
  filter(variable == "MWT", between(t, 6500, 10000))
example_grid = climate$variable_cells |>
  filter(between(t, 6500, 10000))
w1 = ggplot(example_phase, aes(t, regional_score, group = factor(offset),
  color = factor(offset))) +
  geom_hline(yintercept = 0, color = "grey65") + geom_line(alpha = .55) +
  time_scale() + scale_color_viridis_d(option = "turbo") + theme_bw() +
  labs(title = "1. Ten phases expose placement sensitivity",
    subtitle = "Example: winter temperature; direction is evaluated regionally",
    x = NULL, y = "Regional standardized change", color = "Offset")
w2 = ggplot(example_grid, aes(t, regional_score, color = variable)) +
  geom_hline(data = threshold_lines, aes(yintercept = y), inherit.aes = FALSE,
    linetype = 2, color = "grey35") + geom_hline(yintercept = 0,
    color = "grey65") + geom_line() +
  geom_point(data = filter(example_grid, qualifies), size = 2) +
  facet_wrap(~variable, nrow = 1) + time_scale() +
  scale_color_manual(values = variable_cols) + theme_bw() +
  theme(legend.position = "none") +
  labs(title = "2. Apply each variable's 50%-of-maximum threshold",
    subtitle = "A filled cell also needs >=8/10 phases in the regional direction",
    x = NULL, y = "Median regional change")
w3 = p2 + labs(title = "3. Keep direction, then take the any-variable union",
  subtitle = "One qualifying variable is sufficient; below-threshold gaps remain stable")
w4 = p3 + labs(title = "4. Merge only adjacent cells and number CC/S eras",
  subtitle = "No site-direction veto, transition state, forward extension, or gap bridging")
w5 = p4 + labs(title = "5. Composite magnitude is a visual cross-check",
  subtitle = "It is unsigned and unthresholded, so it never selects direction or eras")
w6 = (p5 + labs(title = "6a. Fire is classified independently",
    subtitle = "High fire = normalized site frequency > median + 1.4826 x MAD")) /
  (p6 + labs(title = "6b. Every contiguous run is retained",
    subtitle = "Frequency selects periods; strength/background are corroboration only")) +
  plot_layout(heights = c(1.2, .8))
worked = w1 / w2 / w3 / w4 / w5 / w6 +
  plot_layout(heights = c(1.1, 1.4, 1.1, .8, 1.0, 1.8)) +
  plot_annotation(title = "Worked example: unified Holocene climate eras and fire periods")
if (render_figures) {
  ggsave(here("plot/test_figures/fig_holocene_climate_period_method_worked_example.pdf"),
    worked, width = 15, height = 20)
}

protected_after = unname(tools::md5sum(protected_paths))
if (!identical(protected_before, protected_after))
  stop("Unified era stage modified a protected analytical artifact.")
write_csv(tibble(file = normalizePath(protected_paths),
  md5_before = protected_before, md5_after = protected_after,
  unchanged = protected_before == protected_after),
  here("output/holocene_era_protected_hash_audit.csv"))

cat("Unified climate eras:\n")
print(as.data.frame(era_catalog |>
  select(era_id, era_class, older_cal_bp, younger_cal_bp,
         active_variable_directions)))
cat("High-fire periods: ", nrow(fire$periods), "\n", sep = "")
