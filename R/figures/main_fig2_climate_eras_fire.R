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

variables = c("MSpT", "MWT", "SP", "WP")
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
  identical(eras$era_id, c("CC1", "S1", "CC2", "S2", "CC3", "S3", "CC4", "S4")),
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
# lanes. All CC/S identifiers share one baseline; the short CC1b description
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
stopifnot(nrow(rate_comparison) == 4L,
  all(rate_comparison$holocene_offsets == 10L))
write_csv(rate_comparison,
  out("figures/holocene_anthropocene_raw_climate_rate_comparison.csv"))

# Climate-change subphase arrows share a top annotation lane. CC1a--c are
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
  mutate(x = c(10465, 10295, 10125, 9955),
    ymin = -threshold_standardized_change,
    ymax = threshold_standardized_change,
    cap_left = x - 27, cap_right = x + 27,
    label = sprintf("%s  [%+.3f, %+.3f]",
      variable, ymin, ymax))
stopifnot(nrow(stability_callouts) == 4L)

# text_scale enlarges every text element (and the phrase spacing) together;
# show_stability toggles the stability-range brackets in the left margin.
# panel_data needs t, variable, value and qualifies; the default is the signed
# standardized change. background_data (optional) is drawn as thin faint lines.
# Annotation lanes are placed relative to the y range of the plotted series.
climate_panel = function(text_scale = 1, show_stability = TRUE,
    panel_data = mutate(climate, value = regional_score),
    background_data = NULL, show_qualifying = TRUE,
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
    geom_segment(data = stability_callouts,
      aes(x = x, xend = x, y = ymin, yend = ymax, color = variable),
      inherit.aes = FALSE, linewidth = .85, show.legend = FALSE),
    geom_segment(data = stability_callouts,
      aes(x = cap_left, xend = cap_right, y = ymin, yend = ymin,
        color = variable), inherit.aes = FALSE, linewidth = .85,
      show.legend = FALSE),
    geom_segment(data = stability_callouts,
      aes(x = cap_left, xend = cap_right, y = ymax, yend = ymax,
        color = variable), inherit.aes = FALSE, linewidth = .85,
      show.legend = FALSE),
    geom_text(data = stability_callouts,
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
      labels = variable_labels, name = NULL) +
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
p_fire = fire_panel()

# Manuscript figure: Holocene climate trajectories above the fire lanes. The
# raw-rate comparison is shown separately as a presentation figure below.
figure = p_climate / p_fire +
  plot_layout(heights = c(4.5, 1.45))
if (render_figures) {
  ggsave(fig("main", "fig_standardized_climate_change_eras_fire.pdf"), figure,
    width = 12.5, height = 9.5)
}

# Companion figure: standardized climate LEVELS instead of 1,000-year changes.
# Each lake's centennial CHELSA-TraCE value is scaled with the same legacy
# calibration mean and SD as the CCA, (x - mean) / sd, so 0 is the mean modern
# calibration plot and 1 is one calibration SD. Lakes are averaged within park
# and the two parks weighted equally, as in panel A. Thin lines: centennial
# slices; thick lines: centred 1,000-year running mean (11 slices), matching
# the 1,000-year window of the change analysis. Era shading is unchanged.
climate_helpers = new.env()
sys.source(here("R/helpers/config.R"), envir = climate_helpers)
sys.source(here("R/helpers/climate_variables.R"), envir = climate_helpers)
calibration_scaling = read_csv(required[["scaling"]], show_col_types = FALSE)
stopifnot(setequal(intersect(calibration_scaling$variable, variables),
  variables))
climate_levels = read_csv(required[["paleo_climate"]],
    show_col_types = FALSE) |>
  transmute(unit = lake, period = site, variable, time = slice, month,
    value = value_raw) |>
  climate_helpers$derive_climate_vars(winter_shift = FALSE) |>
  transmute(site = period, lake = unit, t = 1950 - time * 100,
    across(all_of(variables))) |>
  pivot_longer(all_of(variables), names_to = "variable",
    values_to = "raw_value") |>
  left_join(select(calibration_scaling, variable, calibration_mean = mean,
    calibration_sd = sd), by = "variable") |>
  mutate(z = (raw_value - calibration_mean) / calibration_sd) |>
  group_by(variable, site, t) |>
  summarise(z = mean(z), n_lakes = n(), .groups = "drop") |>
  pivot_wider(names_from = site, values_from = c(z, n_lakes)) |>
  arrange(variable, t) |>
  group_by(variable) |>
  mutate(regional_z = (z_MORA + z_NOCA) / 2,
    regional_z_1000yr = as.numeric(stats::filter(regional_z, rep(1 / 11, 11),
      sides = 2))) |>
  ungroup()
stopifnot(nrow(climate_levels) == 4L * 111L,
  all(climate_levels$n_lakes_MORA == 3L), all(climate_levels$n_lakes_NOCA == 1L))
write_csv(climate_levels, out("figures/holocene_standardized_climate_levels.csv"))
levels_in_view = filter(climate_levels,
  between(t, time_limits[2], time_limits[1]))
p_levels = climate_panel(
  panel_data = levels_in_view |>
    filter(is.finite(regional_z_1000yr)) |>
    transmute(t, variable, value = regional_z_1000yr, qualifies = FALSE),
  background_data = transmute(levels_in_view, t, variable,
    value = regional_z),
  show_stability = FALSE, show_qualifying = FALSE,
  title = "Holocene climate",
  y_label = "Standardized climate\n(calibration SD from modern mean)") +
  # Without the qualifying points the lines need a key of their own.
  scale_color_manual(values = c(variable_colors, context = "grey25"),
    breaks = variables, labels = variable_labels, name = NULL) +
  guides(color = guide_legend(nrow = 1,
    override.aes = list(linewidth = 1.6))) +
  theme(legend.position = "bottom", legend.text = element_text(size = 12.5),
    legend.margin = margin(0, 0, 0, 0))
figure_levels = p_levels / p_fire + plot_layout(heights = c(4.5, 1.45))
if (render_figures) {
  ggsave(fig("supplementary", "fig_standardized_climate_levels_eras_fire.pdf"),
    figure_levels, width = 12.5, height = 9.5)
}

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
