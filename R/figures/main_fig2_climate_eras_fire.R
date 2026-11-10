# =============================================================================
# main_fig2_climate_eras_fire.R
# =============================================================================
# Two-panel display of standardized Holocene and Anthropocene climate change.
# This figure reads authoritative outputs and does not recalculate eras.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(patchwork); library(grid)
})
source(here::here('R/helpers/config.R'), local = TRUE)
source(here("R/helpers/figure_style.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))
# Presentation versions are opt-in: Rscript R/run_all.R --presentation
render_presentation = render_figures && isTRUE(getOption('paleoaces.presentation', FALSE))

required = c(
  climate = out("holocene_era_climate_directional_cells.csv"),
  eras = out("holocene_era_catalog.csv"),
  subphases = out("holocene_era_climate_change_subphases.csv"),
  fire = out("holocene_era_high_fire_periods.csv"),
  fire_frequency = out("holocene_era_fire_site_frequency.csv"),
  thresholds = out("holocene_era_climate_variable_thresholds.csv"),
  anthropocene = out("cca_tracking_anthropocene_plot_calculations.csv"),
  regional_phases = out("holocene_era_climate_regional_phase_changes.csv"),
  paleo_climate = out("chelsa_paleo_ponds.csv"),
  scaling = out("cca_tracking_climate_scaling.csv"))
if (!all(file.exists(required))) stop(
  "Run R/pipeline/12_tracking.R and R/pipeline/11_climate_eras_high_fire.R first.")

climate = read_csv(required[["climate"]], show_col_types = FALSE)
eras = read_csv(required[["eras"]], show_col_types = FALSE)
subphases = read_csv(required[["subphases"]], show_col_types = FALSE)
fire = read_csv(required[["fire"]], show_col_types = FALSE)
fire_frequency = read_csv(required[["fire_frequency"]], show_col_types = FALSE)
anthropocene = read_csv(required[["anthropocene"]], show_col_types = FALSE)
regional_phases = read_csv(required[["regional_phases"]], show_col_types = FALSE)
thresholds = read_csv(required[["thresholds"]], show_col_types = FALSE)

variables = CCA_VARIABLES
variable_labels = c(MSpT = "Spring temperature", MWT = "Winter temperature",
  SP = "Summer precipitation", WP = "Winter precipitation")
# Paul Tol-inspired, color-vision-deficiency-safe colors. Temperature and
# precipitation remain distinguishable in grayscale through their luminance as
# well as hue; era backgrounds are deliberately much lighter than the data.
variable_colors = c(MSpT = "#EE6677", MWT = "#4477AA",
                    SP = "#CCBB44", WP = "#228833")
# The aligned MORA/NOCA lanes carry the site distinction. High-fire observations
# use the same restrained red as burned/high-fire groups in every main figure.
site_colors = PAPER_SITE_COLORS
era_colors = c(`climate change` = "#D3D3D6",
               `relative stability` = "#EEEEF0")
time_limits = c(10500, 0)
time_breaks = c(10000, 8000, 6000, 4000, 2000, 0)

stopifnot(
  setequal(unique(climate$variable), variables),
  identical(range(climate$t), c(1300, 9500)),
  all(grepl("^(C|S)[0-9]+$", eras$era_id)), !anyDuplicated(eras$era_id),
  all(c(paste0(variables, "_z_change")) %in% names(anthropocene)))

era_rects = eras |>
  transmute(xmin = younger_cal_bp, xmax = older_cal_bp,
    era_id, era_class, midpoint = (younger_cal_bp + older_cal_bp) / 2)

era_background = function(alpha = .38) {
  geom_rect(data = era_rects,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf,
        fill = era_class), inherit.aes = FALSE, alpha = alpha,
    color = NA, show.legend = FALSE)
}
time_axis = function() scale_x_reverse(limits = time_limits,
  breaks = time_breaks, labels = scales::label_number(big.mark = ","),
  expand = expansion(mult = c(.005, .005)))

# A1. Equal-site regional median change. The points identify cells that passed
# both the 50%-of-maximum magnitude rule and the >=8/10 phase-direction rule.
yrange = range(climate$regional_score, na.rm = TRUE)
# Era identifiers, interval arrows, and driver descriptions occupy distinct
# lanes. All C/S identifiers share one baseline; the short C1b description
# alone is lifted to prevent collision with the adjacent multi-line boxes.
era_id_y = yrange[2] + diff(yrange) * .30
arrow_y = yrange[2] + diff(yrange) * .18
description_y = yrange[2] + diff(yrange) * .095

# Raw physical-rate comparison. Holocene changes span exactly 1,000 years, so
# division by ten expresses them per century. We first form the equal-site raw
# change within each offset, then take the regional median across offsets at
# each date. The maximum-absolute regional median retains its sign.
holocene_raw_grid = regional_phases |>
  mutate(equal_site_raw_change =
      (signed_change_MORA + signed_change_NOCA) / 2,
    raw_rate_per_century = equal_site_raw_change / 10) |>
  group_by(variable, unit, t) |>
  summarise(raw_rate_per_century = median(raw_rate_per_century),
    n_offsets = n_distinct(offset), .groups = "drop")
holocene_max = holocene_raw_grid |>
  group_by(variable, unit) |>
  slice_max(abs(raw_rate_per_century), n = 1, with_ties = FALSE) |>
  ungroup() |>
  transmute(variable, raw_unit = unit,
    holocene_max_signed_rate_per_century = raw_rate_per_century,
    holocene_max_absolute_rate_per_century = abs(raw_rate_per_century),
    holocene_peak_cal_bp = t,
    holocene_peak_direction = if_else(raw_rate_per_century > 0,
      "increasing", "decreasing"), holocene_offsets = n_offsets)

anthro_raw = anthropocene |>
  select(plot_id, site, all_of(paste0(variables, "_rate_per_century"))) |>
  pivot_longer(ends_with("_rate_per_century"), names_to = "variable",
    values_to = "raw_rate_per_century") |>
  mutate(variable = str_remove(variable, "_rate_per_century$"))
anthro_site = anthro_raw |>
  group_by(variable, site) |>
  summarise(anthropocene_median_rate_per_century =
      median(raw_rate_per_century, na.rm = TRUE),
    anthropocene_n_plots = n_distinct(plot_id), .groups = "drop") |>
  pivot_wider(names_from = site,
    values_from = c(anthropocene_median_rate_per_century,
      anthropocene_n_plots), names_sep = "_")
anthro_all = anthro_raw |>
  group_by(variable) |>
  summarise(anthropocene_median_rate_per_century_all =
      median(raw_rate_per_century, na.rm = TRUE),
    anthropocene_n_plots_all = n_distinct(plot_id), .groups = "drop")

rate_comparison = holocene_max |>
  left_join(anthro_site, by = "variable") |>
  left_join(anthro_all, by = "variable") |>
  mutate(variable_label = unname(variable_labels[variable]),
    rate_unit = if_else(raw_unit == "deg C", "deg C / century",
      "mm / century")) |>
  arrange(match(variable, variables))
stopifnot(nrow(rate_comparison) == length(variables),
  all(rate_comparison$holocene_offsets == 10L))
write_csv(rate_comparison,
  out("figures/holocene_anthropocene_raw_climate_rate_comparison.csv"))

# Climate-change subphase arrows share a top annotation lane. C1a--c are
# derived from the internal driver-count trough; the shorter CC eras remain
# unsplit. Stable-era labels use the same lane between these arrows.
phase_annotations = subphases |>
  mutate(midpoint = (older_cal_bp + younger_cal_bp) / 2,
    description = annotation_label,
    id_y = era_id_y,
    arrow_y = arrow_y,
    description_y = description_y + if_else(
      phase_role == "transition", diff(yrange) * .105, 0))
# Split the multi-line descriptions so each phrase can use the color of the
# climate variable it describes. "Transition" remains neutral because it is a
# phase role rather than a climate variable.
# line_step is the vertical spacing between phrases as a fraction of the
# y range; larger text needs proportionally larger spacing.
make_description_phrases = function(line_step = .027,
                                     annotations = phase_annotations,
                                     yr = yrange) {
  annotations |>
    select(subphase_id, midpoint, description_y, phase_role,
      active_driver_labels) |>
    mutate(phrase = if_else(phase_role == "transition",
      paste("transition", active_driver_labels, sep = ";"),
      active_driver_labels)) |>
    separate_longer_delim(phrase, delim = ";") |>
    group_by(subphase_id) |>
    mutate(line_number = row_number(), n_lines = n(),
      phrase_y = description_y +
        ((n_lines + 1) / 2 - line_number) * diff(yr) * line_step,
      phrase_variable = case_when(
        str_detect(phrase, "^spring ") ~ "MSpT",
        str_detect(phrase, "^winter (warming|cooling)") ~ "MWT",
        str_detect(phrase, "^summer ") ~ "SP",
        str_detect(phrase, "^winter (wetting|drying)") ~ "WP",
        TRUE ~ "context")) |>
    ungroup()
}
stable_annotations = era_rects |>
  filter(era_class == "relative stability") |>
  mutate(id_y = era_id_y)

# Stability-range keys sit in the older incomplete-coverage margin near 10 ka.
# Each vertical bracket connects the exact negative and positive threshold used
# for that variable; the text is rotated so the four ranges remain legible
# without covering the climate trajectories or era annotations.
stability_callouts = thresholds |>
  filter(variable %in% variables) |>
  arrange(match(variable, variables)) |>
  mutate(x = c(10465, 10295, 10125, 9955)[seq_along(variable)],
    ymin = -threshold_standardized_change,
    ymax = threshold_standardized_change,
    cap_left = x - 27, cap_right = x + 27,
    label = sprintf("%s  [%+.3f, %+.3f]",
      variable, ymin, ymax))
stopifnot(nrow(stability_callouts) == length(variables))

# text_scale enlarges every text element (and the phrase spacing) together;
# show_stability toggles the stability-range brackets in the left margin.
# panel_data needs t, variable, value and qualifies; the default is the signed
# standardized change. background_data (optional) is drawn as thin faint lines.
# Annotation lanes are placed relative to the y range of the plotted series.
climate_panel = function(text_scale = 1, show_stability = TRUE,
    panel_data = mutate(climate, value = regional_score),
    background_data = NULL, show_qualifying = TRUE, callouts = stability_callouts,
    title = "Holocene climate change",
    y_label = "Signed standardized change") {
  s = text_scale
  yr = range(c(panel_data$value, background_data$value), na.rm = TRUE)
  # Taller text blocks are lowered so they clear the arrow lane.
  phase_annotations = phase_annotations |>
    mutate(id_y = yr[2] + diff(yr) * .30, arrow_y = yr[2] + diff(yr) * .18,
      description_y = yr[2] + diff(yr) * .095 +
        if_else(phase_role == "transition", diff(yr) * .105, 0) -
        (s - 1) * diff(yr) * .045)
  stable_annotations = mutate(stable_annotations,
    id_y = yr[2] + diff(yr) * .30)
  description_phrases = make_description_phrases(.027 * s, phase_annotations,
    yr)
  background_layer = if (!is.null(background_data)) geom_line(
    data = background_data, linewidth = .35 * sqrt(s), alpha = .35)
  qualifying_layer = if (show_qualifying) geom_point(
    data = filter(panel_data, qualifies), size = 2.8 * sqrt(s))
  stability_layers = if (show_stability) list(
    geom_segment(data = callouts,
      aes(x = x, xend = x, y = ymin, yend = ymax, color = variable),
      inherit.aes = FALSE, linewidth = .85, show.legend = FALSE),
    geom_segment(data = callouts,
      aes(x = cap_left, xend = cap_right, y = ymin, yend = ymin,
        color = variable), inherit.aes = FALSE, linewidth = .85,
      show.legend = FALSE),
    geom_segment(data = callouts,
      aes(x = cap_left, xend = cap_right, y = ymax, yend = ymax,
        color = variable), inherit.aes = FALSE, linewidth = .85,
      show.legend = FALSE),
    geom_text(data = callouts,
      aes(x = x - 48, y = 0, label = label, color = variable),
      inherit.aes = FALSE, angle = 90, size = 3.2, fontface = "bold",
      show.legend = FALSE))
  ggplot(panel_data,
      aes(t, value, color = variable, group = variable)) +
    era_background() +
    geom_hline(yintercept = 0, color = "grey45", linewidth = .4) +
    background_layer +
    geom_line(linewidth = 1.0 * sqrt(s)) +
    qualifying_layer +
    stability_layers +
    geom_segment(data = phase_annotations,
      aes(x = older_cal_bp, xend = younger_cal_bp,
        y = arrow_y, yend = arrow_y),
      inherit.aes = FALSE, color = "grey25", linewidth = 1.05,
      arrow = arrow(type = "closed", length = unit(.065 * s, "in")),
      show.legend = FALSE) +
    geom_label(data = phase_annotations,
      aes(midpoint, description_y, label = description),
      inherit.aes = FALSE, color = "transparent", fill = "white",
      linewidth = 0, size = 3.05 * s, lineheight = .93,
      label.padding = unit(.09, "lines"), show.legend = FALSE) +
    geom_text(data = description_phrases,
      aes(midpoint, phrase_y, label = phrase, color = phrase_variable),
      inherit.aes = FALSE, size = 3.05 * s, lineheight = .93,
      show.legend = FALSE) +
    geom_text(data = phase_annotations,
      aes(midpoint, id_y, label = subphase_id), inherit.aes = FALSE,
      color = "grey15", fontface = "bold", size = 4.1 * s,
      show.legend = FALSE) +
    geom_text(data = stable_annotations,
      aes(midpoint, id_y, label = era_id), inherit.aes = FALSE,
      fontface = "bold", size = 4.1 * s) +
    time_axis() +
    scale_y_continuous(expand = expansion(mult = c(.07, .16))) +
    scale_fill_manual(values = era_colors, guide = "none") +
    scale_color_manual(values = c(variable_colors, context = "grey25"),
      labels = variable_labels[variables], name = NULL) +
    labs(tag = "A.", title = title, x = NULL, y = y_label) +
    theme_paleoaces(base_size = 14 * s) +
    theme(panel.grid.minor = element_blank(),
          axis.text.x = element_blank(), axis.ticks.x = element_blank(),
          legend.position = "none",
          plot.title = element_text(face = "bold", size = 17 * s),
          plot.tag = element_text(face = "bold",
            size = PAPER_PANEL_TAG_SIZE * s),
          axis.title.y = element_text(size = 15 * s),
          axis.text.y = element_text(size = 13.5 * s))
}
p_climate = climate_panel()

# A2. The fire-frequency ratio exposes the actual classification rule. A value
# of 1 is the site-specific robust threshold; values above 1 are high fire.
# This threshold normalization is dimensionless and avoids comparing raw
# charcoal magnitudes between the regional MORA and local NOCA records.
fire_ratio = fire_frequency |>
  filter(between(cal_bp, time_limits[2], time_limits[1]),
    is.finite(normalized_frequency), is.finite(high_fire_threshold),
    high_fire_threshold > 0) |>
  mutate(site = factor(site, levels = c("MORA", "NOCA")),
    high_fire_ratio = normalized_frequency / high_fire_threshold)
stopifnot(nrow(fire_ratio) > 0,
  all(fire_ratio$high_fire == (fire_ratio$high_fire_ratio > 1)))
write_csv(fire_ratio,
  out("figures/holocene_era_fire_threshold_ratio.csv"))

# sites selects which fire lanes are drawn (both by default).
fire_panel = function(text_scale = 1, sites = c("MORA", "NOCA")) {
  s = text_scale
  fire_data = filter(fire_ratio, site %in% sites)
  ggplot(fire_data, aes(cal_bp, high_fire_ratio, group = site)) +
    era_background(.28) +
    geom_hline(yintercept = 1, color = "grey45", linetype = "dashed",
      linewidth = .55) +
    geom_line(color = "grey20", linewidth = .8) +
    geom_segment(data = filter(fire_data, high_fire),
      aes(xend = cal_bp, y = 1, yend = high_fire_ratio),
      color = PAPER_FIRE_RED, linewidth = 2.2, alpha = .55) +
    geom_point(data = filter(fire_data, high_fire), color = PAPER_FIRE_RED,
      size = 1.35 * sqrt(s)) +
    facet_grid(rows = vars(site), scales = "fixed") +
    time_axis() +
    scale_fill_manual(values = era_colors, guide = "none") +
    scale_y_continuous(expand = expansion(mult = c(.05, .10))) +
    labs(tag = "B.", x = "cal BP",
      y = "Fire-frequency ratio\n(high fire > 1)") +
    theme_paleoaces(base_size = 13 * s) +
    theme(panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "grey94", color = "grey65"),
      strip.text.y = element_text(face = "bold", size = 12 * s),
      axis.text.y = element_text(size = 11 * s),
      axis.text.x = element_text(size = 13 * s),
      axis.title = element_text(size = 14.5 * s),
      plot.tag = element_text(face = "bold",
        size = PAPER_PANEL_TAG_SIZE * s))
}
# Larger text throughout the manuscript and appendix versions (Bills, 9 Nov 2026).
FIG2_TEXT = 1.7
p_fire = fire_panel(FIG2_TEXT)

# Appendix record of how the periods were drawn: the signed standardized
# 1,000-year changes of all four seasonal variables. Only the CCA constraints
# define the periods and carry qualifying points.
display_cells = read_csv(out("holocene_era_display_directional_cells.csv"), show_col_types = FALSE)
display_thresholds = read_csv(out("holocene_era_display_variable_thresholds.csv"), show_col_types = FALSE)
stopifnot(setequal(unique(display_cells$variable), CLIMATE_DISPLAY_VARIABLES))
display_callouts = display_thresholds |>
  filter(variable %in% CLIMATE_DISPLAY_VARIABLES) |>
  arrange(match(variable, CLIMATE_DISPLAY_VARIABLES)) |>
  mutate(x = c(10465, 10295, 10125, 9955)[seq_along(variable)],
    ymin = -threshold_standardized_change, ymax = threshold_standardized_change,
    cap_left = x - 27, cap_right = x + 27,
    label = sprintf("%s  [%+.3f, %+.3f]", variable, ymin, ymax))
four_variable_key = function(p) p +
  scale_color_manual(values = c(variable_colors, context = "grey25"),
    breaks = CLIMATE_DISPLAY_VARIABLES,
    labels = paste0(CLIMATE_VARIABLE_LABELS[CLIMATE_DISPLAY_VARIABLES],
      if_else(CLIMATE_DISPLAY_VARIABLES %in% CCA_VARIABLES, " (CCA constraint)", "")),
    name = NULL) +
  guides(color = guide_legend(nrow = 1, override.aes = list(linewidth = 1.6))) +
  theme(legend.position = "bottom", legend.text = element_text(size = 12 * FIG2_TEXT))
p_climate_display = four_variable_key(climate_panel(text_scale = FIG2_TEXT,
  panel_data = display_cells |> mutate(value = regional_score,
    qualifies = qualifies & variable %in% CCA_VARIABLES),
  callouts = display_callouts, title = NULL,
  y_label = "Standardized 1,000-year change\n(calibration SD)"))
if (render_figures) {
  ggsave(fig("supplementary", "fig_standardized_climate_change_four_variables.pdf"),
    p_climate_display / p_fire + plot_layout(heights = c(4.5, 1.45)),
    width = 15, height = 11.5, device = cairo_pdf)
}

# Figure 2A: standardized climate LEVELS. Each lake's centennial CHELSA-TraCE
# value is scaled with the legacy calibration SD of the CCA, lakes are averaged
# within park and the parks weighted equally. Zero is the mean of the legacy
# calibration plots, as in the CCA (Bills, 9 Nov 2026). Thin lines:
# centennial slices; bold lines: centred 1,000-year running mean (11 slices).
climate_helpers = new.env()
sys.source(here("R/helpers/config.R"), envir = climate_helpers)
sys.source(here("R/helpers/climate_variables.R"), envir = climate_helpers)
calibration_scaling = read_csv(required[["scaling"]], show_col_types = FALSE)
level_series = function(vars) read_csv(required[["paleo_climate"]], show_col_types = FALSE) |>
  transmute(unit = lake, period = site, variable, time = slice, month, value = value_raw) |>
  climate_helpers$derive_climate_vars(winter_shift = FALSE) |>
  transmute(site = period, lake = unit, t = 1950 - time * 100, across(all_of(vars))) |>
  pivot_longer(all_of(vars), names_to = "variable", values_to = "raw_value") |>
  left_join(select(calibration_scaling, variable, calibration_mean = mean, calibration_sd = sd), by = "variable") |>
  group_by(variable, site, t) |>
  summarise(raw = mean(raw_value), reference = first(calibration_mean), sd = first(calibration_sd), n_lakes = n(), .groups = "drop") |>
  pivot_wider(names_from = site, values_from = c(raw, n_lakes)) |>
  arrange(variable, t) |>
  group_by(variable) |>
  mutate(regional_raw = (raw_MORA + raw_NOCA) / 2,
    regional_raw_1000yr = as.numeric(stats::filter(regional_raw, rep(1 / 11, 11), sides = 2)),
    in_view = between(t, time_limits[2], time_limits[1]),
    level = (regional_raw - reference) / sd,
    level_1000yr = (regional_raw_1000yr - reference) / sd) |>
  ungroup()
climate_levels = level_series(union(variables, CLIMATE_DISPLAY_VARIABLES))
stopifnot(all(climate_levels$n_lakes_MORA == 3L), all(climate_levels$n_lakes_NOCA == 1L))
write_csv(climate_levels, out("figures/holocene_standardized_climate_levels.csv"))
unit_label = function(v) if_else(CLIMATE_VARIABLE_UNITS[v] == "mm", "mm", "°C")

# Real-unit change per century over each period, read off the running-mean line
# at the period boundaries, written only where the period names that driver.
period_rates = read_csv(out("holocene_periods.csv"), show_col_types = FALSE) |>
  separate_longer_delim(drivers, delim = ";") |>
  filter(!is.na(drivers), drivers != "") |>
  mutate(variable = case_when(str_detect(drivers, "^spring") ~ "MSpT", str_detect(drivers, "^summer") ~ "SP",
    str_detect(drivers, "^winter (warming|cooling)") ~ "MWT", TRUE ~ "WP")) |>
  filter(variable %in% variables) |>
  rowwise() |>
  # Climate slices sit at century centres (x50 cal BP) and period boundaries at
  # whole centuries, so the line is interpolated at the boundaries.
  mutate(line = list(filter(climate_levels, variable == .env$variable, is.finite(regional_raw_1000yr))),
    older = approx(line$t, line$regional_raw_1000yr, older_cal_bp)$y,
    younger = approx(line$t, line$regional_raw_1000yr, younger_cal_bp)$y,
    rate = (younger - older) / duration_years * 100,
    t = (older_cal_bp + younger_cal_bp) / 2,
    level = approx(line$t, line$level_1000yr, t)$y) |>
  ungroup() |> select(-line) |>
  mutate(label = if_else(variable == "SP", sprintf("%+.1f mm/century", rate), sprintf("%+.2f °C/century", rate)))
# The largest century-to-century step of the unsmoothed regional series.
largest_steps = climate_levels |> filter(in_view, variable %in% variables) |> group_by(variable) |>
  arrange(desc(t), .by_group = TRUE) |>
  mutate(step = regional_raw - lag(regional_raw), from_t = lag(t)) |>
  filter(is.finite(step)) |> slice_max(abs(step), n = 1, with_ties = FALSE) |> ungroup() |>
  mutate(label = if_else(variable == "SP", sprintf("largest step %+.1f mm/century", step),
    sprintf("largest step %+.2f °C/century", step)))
write_csv(bind_rows(period_rates |> transmute(kind = "period", variable, period, t, rate, level),
    largest_steps |> transmute(kind = "largest century step", variable, period = NA_character_, t, rate = step, level)),
  out("figures/holocene_climate_level_rates.csv"))

# Anthropocene rates per park: plot medians of the change from the legacy to
# the resurvey climate window, per century, in real units and in SD.
anthropocene_rates = anthropocene |>
  select(site, plot_id, all_of(paste0(variables, "_rate_per_century")), all_of(paste0(variables, "_z_rate_per_century"))) |>
  pivot_longer(-c(site, plot_id), names_to = c("variable", "kind"), names_pattern = "^(.*?)_(rate|z_rate)_per_century$") |>
  group_by(variable, site, kind) |> summarise(median = median(value), .groups = "drop") |>
  pivot_wider(names_from = kind, values_from = median) |>
  mutate(label = if_else(variable == "SP", sprintf("%s %+.0f mm (%+.1f SD)", site, rate, z_rate),
    sprintf("%s %+.2f °C (%+.1f SD)", site, rate, z_rate)))
write_csv(anthropocene_rates, out("figures/anthropocene_climate_rates.csv"))

levels_panel = function(vars, show_rates = TRUE) {
  in_view = filter(climate_levels, in_view, variable %in% vars)
  p = climate_panel(text_scale = FIG2_TEXT, panel_data = in_view |> filter(is.finite(level_1000yr)) |>
      transmute(t, variable, value = level_1000yr, qualifies = FALSE),
    background_data = transmute(in_view, t, variable, value = level),
    show_stability = FALSE, show_qualifying = FALSE, title = NULL,
    y_label = "Standardized climate level\n(calibration SD from the modern mean)")
  # White vertical lines separate the sub-periods of a split C period.
  splits = subphases |> filter(phase_role != "unsplit")
  if (nrow(splits)) splits = splits |> group_by(parent_era_id) |>
    filter(younger_cal_bp > min(younger_cal_bp)) |> ungroup()
  if (nrow(splits)) p = p + geom_vline(data = splits, aes(xintercept = younger_cal_bp), color = "white", linewidth = .9)
  if (show_rates) p = p +
    geom_point(data = period_rates, aes(t, level, color = variable), inherit.aes = FALSE, size = 1.8, show.legend = FALSE) +
    # Spring labels above their line, summer labels below, so the two never collide.
    geom_label(data = period_rates, aes(t, level, label = label, color = variable,
        vjust = if_else(variable == "SP", 1.5, -.5)), inherit.aes = FALSE,
      size = 2.9 * FIG2_TEXT, label.size = 0, fill = alpha("white", .8), label.padding = unit(.08, "lines"), show.legend = FALSE) +
    geom_point(data = largest_steps, aes(t, level, color = variable), inherit.aes = FALSE, shape = 4, size = 3,
      stroke = 1.1, show.legend = FALSE) +
    geom_label(data = largest_steps, aes(t, level, label = label, color = variable,
        hjust = if_else(t > 9500, 0, .5)), inherit.aes = FALSE, size = 2.7 * FIG2_TEXT, vjust = 1.5, label.size = 0, fill = alpha("white", .8), label.padding = unit(.08, "lines"),
      show.legend = FALSE)
  p
}
# Figure 2 in raw units (Bills, 9 Nov 2026): one panel per CCA variable in °C
# or mm, black lines, rates only in real units per century, then fire. The
# park-average lake climate is the same series as above, before standardizing.
raw_unit = c(MSpT = "°C", SP = "mm")
raw_axis = c(MSpT = "Spring temperature (°C)", SP = "Summer precipitation (mm)")
rate_text = function(v, x) if (v == "SP") sprintf("%+.1f mm", x) else sprintf("%+.2f °C", x)
raw_panel = function(v, tag, show_periods) {
  d = climate_levels |> filter(in_view, variable == v)
  line = d |> filter(is.finite(regional_raw_1000yr))
  yr = range(d$regional_raw)
  span = diff(yr)
  top = if (show_periods) yr[2] + span * 1.05 else yr[2] + span * .08
  rates = period_rates |> filter(variable == v) |>
    mutate(y = approx(line$t, line$regional_raw_1000yr, t)$y, label = paste0(rate_text(v, rate), "/century"),
      # Neighbouring periods alternate above and below the line, so labels never touch.
      vjust = if_else(row_number() %% 2 == 1, -.45, 1.45))
  # No "largest step" marker (Bills, 10 Nov 2026).
  p = ggplot(d, aes(t, regional_raw)) +
    era_background() +
    geom_line(linewidth = .35 * sqrt(FIG2_TEXT), color = "grey55", alpha = .7) +
    geom_line(data = line, aes(y = regional_raw_1000yr), linewidth = 1.1 * sqrt(FIG2_TEXT), color = "grey10") +
    geom_point(data = rates, aes(t, y), size = 2.2, color = "grey10") +
    geom_label(data = rates, aes(t, y, label = label, vjust = vjust), size = 3 * FIG2_TEXT, color = "grey10",
      label.size = 0, fill = alpha("white", .85), label.padding = unit(.08, "lines")) +
    time_axis() +
    scale_y_continuous(expand = expansion(mult = 0)) +
    scale_fill_manual(values = era_colors, guide = "none") +
    coord_cartesian(ylim = c(yr[1] - span * .14, top), clip = "off") +
    labs(tag = tag, x = NULL, y = raw_axis[[v]]) +
    theme_paleoaces(base_size = 13 * FIG2_TEXT) +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), panel.grid.minor = element_blank())
  if (show_periods) {
    # Period names, interval arrows and driver words above the series, in grey.
    ann = phase_annotations |> mutate(id_y = yr[2] + span * .95, arrow_y = yr[2] + span * .72,
      description_y = yr[2] + span * .45)
    p = p +
      geom_segment(data = ann, aes(x = older_cal_bp, xend = younger_cal_bp, y = arrow_y, yend = arrow_y),
        inherit.aes = FALSE, color = "grey25", linewidth = 1, arrow = arrow(type = "closed", length = unit(.08, "in"))) +
      geom_text(data = ann, aes(midpoint, description_y,
        # Only the direction: the panels already name the season (Bills, 10 Nov 2026).
        label = gsub(";", "\n", gsub("(spring|summer) ", "", active_driver_labels))), inherit.aes = FALSE,
        size = 3 * FIG2_TEXT, lineheight = .9, color = "grey30") +
      geom_text(data = ann, aes(midpoint, id_y, label = subphase_id), inherit.aes = FALSE, fontface = "bold",
        size = 4 * FIG2_TEXT, color = "grey10") +
      geom_text(data = stable_annotations |> mutate(id_y = yr[2] + span * .95), aes(midpoint, id_y, label = era_id),
        inherit.aes = FALSE, fontface = "bold", size = 4 * FIG2_TEXT, color = "grey10")
  }
  p
}
# Anthropocene change per century, plot median per park, as text beside each
# panel at the height where its running-mean line ends.
anthropocene_column = function(v, panel, first) {
  y_range = ggplot_build(panel)$layout$panel_params[[1]]$y.range
  end = climate_levels |> filter(in_view, variable == v, is.finite(regional_raw_1000yr)) |> slice_min(t, n = 1)
  d = anthropocene_rates |> filter(variable == v) |> arrange(site) |>
    mutate(y = end$regional_raw_1000yr + (row_number() - 1.5) * diff(y_range) * .2,
      label = paste0(rate_text(v, rate), "/century"))
  # The park name in its colour, the rate after it (Bills, 10 Nov 2026).
  p = ggplot(d, aes(0, y)) +
    # Shifted left over the width taken by the fire panel's park strips, so the
    # text starts right after the end of the time axis.
    geom_text(aes(x = -.05, label = site, color = site), hjust = 0, size = 4.6 * FIG2_TEXT, fontface = "bold") +
    geom_text(aes(x = .2, label = label), hjust = 0, size = 4.6 * FIG2_TEXT, color = "grey10") +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = "none") +
    coord_cartesian(xlim = c(0, 1), ylim = y_range, expand = FALSE, clip = "off") + theme_void() +
    theme(plot.margin = margin(0, 0, 0, 0))
  if (first) p = p + annotate("text", x = -.05, y = y_range[2], label = "Anthropocene", hjust = 0, vjust = 1,
    size = 4.8 * FIG2_TEXT, fontface = "bold", color = "grey20")
  p
}
p_spring = raw_panel("MSpT", "A.", TRUE)
p_summer = raw_panel("SP", "B.", FALSE)
# One grid, so that the time axes of A, B and C line up.
# The Anthropocene column sits right against the end of the time axis.
tight = theme(plot.margin = margin(5.5, 2, 5.5, 5.5))
figure = wrap_plots(p_spring + tight, anthropocene_column("MSpT", p_spring, TRUE),
  p_summer + tight, anthropocene_column("SP", p_summer, FALSE),
  # Three lines for the fire title, so it stays within its panel at the larger text.
  p_fire + labs(tag = "C.", y = "Fire-frequency\nratio\n(high fire > 1)") + tight, plot_spacer(),
  ncol = 2, widths = c(5.2, 1.75), heights = c(3.6, 2.8, 2.5))
if (render_figures) {
  # cairo_pdf draws the degree signs and arrows.
  ggsave(fig("main", "fig_climate_levels_eras_fire.pdf"), figure, width = 19, height = 18, device = cairo_pdf)
  ggsave(fig("main", "fig_climate_levels_eras_fire.png"), figure, width = 19, height = 18, dpi = 300)
}

# Appendix: the same levels for all four seasonal variables, without rates.
p_levels_four = four_variable_key(levels_panel(CLIMATE_DISPLAY_VARIABLES, show_rates = FALSE))
if (render_figures) ggsave(fig("supplementary", "fig_standardized_climate_levels_four_variables.pdf"),
  p_levels_four / p_fire + plot_layout(heights = c(4.5, 1.45)), width = 15, height = 11.5, device = cairo_pdf)

# Presentation version of panels A and B: no stability-range brackets, and all
# text enlarged so the era annotations read from the back of a room.
presentation_scale = 1.4
figure_presentation = climate_panel(presentation_scale,
    show_stability = FALSE) / fire_panel(presentation_scale) +
  plot_layout(heights = c(4.5, 1.45))
if (render_presentation) {
  for (ext in c("pdf", "png"))
    ggsave(fig("presentation", 
        paste0("fig_holocene_climate_eras_fire.", ext)), figure_presentation,
      width = 16, height = 10.5, dpi = 300)
}

# Same presentation figure with only the MORA fire lane. Page size and layout
# are unchanged; the single lane fills panel B's space so its axis title fits.
figure_presentation_mora = climate_panel(presentation_scale,
    show_stability = FALSE) / fire_panel(presentation_scale, sites = "MORA") +
  plot_layout(heights = c(4.5, 1.45))
if (render_presentation) {
  for (ext in c("pdf", "png"))
    ggsave(fig("presentation", 
        paste0("fig_holocene_climate_eras_fire_MORA.", ext)),
      figure_presentation_mora, width = 16, height = 10.5, dpi = 300)
}

# Presentation figure: raw rates per century as lollipops, one panel per climate
# variable in a single row. Rows are the signed Holocene maximum regional median
# (its age in the label) and the plot-level Anthropocene medians at MORA and
# NOCA; values are exactly those in rate_comparison. Each variable has its own
# linear axis in its physical unit. The fold column is |Anthropocene rate| /
# |Holocene maximum rate|; direction is read from the lollipops themselves.
rate_rows = c("Holocene max", "Anthropocene MORA", "Anthropocene NOCA")
rate_unit_label = c(MSpT = "deg C / century", MWT = "deg C / century",
  SP = "mm / century", WP = "mm / century")
rate_long = rate_comparison |>
  transmute(variable,
    `Holocene max` = holocene_max_signed_rate_per_century,
    `Anthropocene MORA` = anthropocene_median_rate_per_century_MORA,
    `Anthropocene NOCA` = anthropocene_median_rate_per_century_NOCA,
    holocene_max = holocene_max_signed_rate_per_century,
    peak_ka = holocene_peak_cal_bp / 1000) |>
  pivot_longer(all_of(rate_rows), names_to = "row", values_to = "rate") |>
  mutate(row = factor(row, levels = rev(rate_rows)),
    fold = abs(rate) / abs(holocene_max),
    label = if_else(row == "Holocene max",
      sprintf("%+.2f (%.1f ka)", rate, peak_ka), sprintf("%+.2f", rate)),
    fold_label = if_else(row == "Holocene max", "fold",
      sprintf("%.0f×", fold)))
stopifnot(all(is.finite(rate_long$fold)))
row_fill = c(`Holocene max` = era_colors[["relative stability"]],
  `Anthropocene MORA` = "#FBE6DC", `Anthropocene NOCA` = "#FBE6DC")

# Slide-sized text: k scales every text, point and line element together.
rate_text_scale = 1.8
rate_panel = function(v, first, k = rate_text_scale) {
  d = filter(rate_long, variable == v)
  # Room on each side for the value labels, which sit beyond the lollipop head.
  span = diff(range(c(0, d$rate)))
  pad = 1.05 * span
  xlim = c(min(0, d$rate) - if (any(d$rate < 0)) pad else .05 * span,
           max(0, d$rate) + if (any(d$rate > 0)) pad else .05 * span)
  # Anthropocene labels sit beyond the lollipop head; the near-zero Holocene
  # label goes on whichever side of its point has more room.
  d = mutate(d, label_left = if_else(row == "Holocene max",
      rate - xlim[1] > xlim[2] - rate, rate < 0),
    label_hjust = if_else(label_left, 1.3, -.3))
  ggplot(d, aes(y = row)) +
    geom_rect(aes(xmin = -Inf, xmax = Inf, ymin = as.integer(row) - .5,
        ymax = as.integer(row) + .5, fill = row), show.legend = FALSE) +
    geom_vline(xintercept = 0, color = "grey45", linewidth = .5) +
    geom_segment(aes(x = 0, xend = rate, yend = row),
      color = variable_colors[[v]], linewidth = 1.6 * k) +
    geom_point(aes(x = rate), color = variable_colors[[v]], size = 4 * k) +
    geom_text(aes(x = rate, label = label, hjust = label_hjust),
      size = 4 * k, color = "grey15") +
    # Fold column just outside the panel's right edge.
    geom_text(aes(x = Inf, label = fold_label,
        color = row == "Holocene max",
        fontface = if_else(row == "Holocene max", "plain", "bold")),
      hjust = -.2, size = 4.6 * k, show.legend = FALSE) +
    scale_color_manual(values = c(`TRUE` = "grey45",
      `FALSE` = variable_colors[[v]])) +
    scale_x_continuous(limits = xlim, expand = c(0, 0),
      breaks = scales::breaks_pretty(n = 4),
      labels = scales::label_number(big.mark = ",", drop0trailing = TRUE)) +
    scale_y_discrete() +
    scale_fill_manual(values = row_fill) +
    coord_cartesian(clip = "off") +
    labs(title = variable_labels[[v]], x = rate_unit_label[[v]], y = NULL) +
    theme_paleoaces(base_size = 14 * k) +
    theme(panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      plot.title = element_text(color = variable_colors[[v]],
        face = "bold", size = 16 * k),
      axis.text.y = if (first) element_text(size = 13 * k, color = "grey15")
                    else element_blank(),
      axis.ticks.y = element_blank(),
      axis.text.x = element_text(size = 11.5 * k),
      axis.title.x = element_text(size = 12.5 * k),
      plot.margin = margin(6, 52 * k, 10, 6))
}
# Temperature on the top row, precipitation on the bottom row; row labels are
# drawn only in the left column.
p_rates = wrap_plots(map2(variables, variables %in% c("MSpT", "SP"),
    rate_panel), nrow = 2, byrow = TRUE) +
  plot_annotation(title = "Raw climate rates per century",
    theme = theme(plot.title = element_text(face = "bold",
      size = 19 * rate_text_scale)))
if (render_presentation) {
  for (ext in c("pdf", "png"))
    ggsave(fig("presentation", 
        paste0("fig_raw_climate_rate_lollipops.", ext)), p_rates,
      width = 20, height = 11.25, dpi = 300)
}
cat("Written fire-threshold ratio and raw-rate comparison CSV",
    if (render_figures) ", plus the climate/fire and rate figures.\n" else ".\n",
    sep = "")
