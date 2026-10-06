# =============================================================================
# 13a_climate_change_figure.R
# =============================================================================
# Two-panel display of standardized Holocene and Anthropocene climate change.
# This figure reads authoritative outputs and does not recalculate eras.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(patchwork); library(grid)
})
source(here("R/helpers/figure_style.R"))
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

required = c(
  climate = here("output/holocene_era_climate_directional_cells.csv"),
  eras = here("output/holocene_era_catalog.csv"),
  subphases = here("output/holocene_era_climate_change_subphases.csv"),
  fire = here("output/holocene_era_high_fire_periods.csv"),
  fire_frequency = here("output/holocene_era_fire_site_frequency.csv"),
  thresholds = here("output/holocene_era_climate_variable_thresholds.csv"),
  anthropocene = here("output/cca_tracking_anthropocene_plot.csv"),
  regional_phases = here("output/holocene_era_climate_regional_phase_changes.csv"))
if (!all(file.exists(required))) stop(
  "Run R/stages/09_tracking_metrics.R and R/stages/13_holocene_climate_fire_eras.R first.")

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
site_colors = c(MORA = "grey20", NOCA = "grey20")
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
  here("output/holocene_anthropocene_raw_climate_rate_comparison.csv"))

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
description_phrases = phase_annotations |>
  select(subphase_id, midpoint, description_y, phase_role,
    active_driver_labels) |>
  mutate(phrase = if_else(phase_role == "transition",
    paste("transition", active_driver_labels, sep = ";"),
    active_driver_labels)) |>
  separate_longer_delim(phrase, delim = ";") |>
  group_by(subphase_id) |>
  mutate(line_number = row_number(), n_lines = n(),
    phrase_y = description_y +
      ((n_lines + 1) / 2 - line_number) * diff(yrange) * .027,
    phrase_variable = case_when(
      str_detect(phrase, "^spring ") ~ "MSpT",
      str_detect(phrase, "^winter (warming|cooling)") ~ "MWT",
      str_detect(phrase, "^summer ") ~ "SP",
      str_detect(phrase, "^winter (wetting|drying)") ~ "WP",
      TRUE ~ "context")) |>
  ungroup()
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

p_climate = ggplot(climate,
    aes(t, regional_score, color = variable, group = variable)) +
  era_background() +
  geom_hline(yintercept = 0, color = "grey45", linewidth = .4) +
  geom_line(linewidth = 1.0) +
  geom_point(data = filter(climate, qualifies), size = 2.8) +
  geom_segment(data = stability_callouts,
    aes(x = x, xend = x, y = ymin, yend = ymax, color = variable),
    inherit.aes = FALSE, linewidth = .85, show.legend = FALSE) +
  geom_segment(data = stability_callouts,
    aes(x = cap_left, xend = cap_right, y = ymin, yend = ymin,
      color = variable), inherit.aes = FALSE, linewidth = .85,
    show.legend = FALSE) +
  geom_segment(data = stability_callouts,
    aes(x = cap_left, xend = cap_right, y = ymax, yend = ymax,
      color = variable), inherit.aes = FALSE, linewidth = .85,
    show.legend = FALSE) +
  geom_text(data = stability_callouts,
    aes(x = x - 48, y = 0, label = label, color = variable),
    inherit.aes = FALSE, angle = 90, size = 3.2, fontface = "bold",
    show.legend = FALSE) +
  geom_segment(data = phase_annotations,
    aes(x = older_cal_bp, xend = younger_cal_bp,
      y = arrow_y, yend = arrow_y),
    inherit.aes = FALSE, color = "grey25", linewidth = 1.05,
    arrow = arrow(type = "closed", length = unit(.065, "in")),
    show.legend = FALSE) +
  geom_label(data = phase_annotations,
    aes(midpoint, description_y, label = description),
    inherit.aes = FALSE, color = "transparent", fill = "white", linewidth = 0,
    size = 3.05, lineheight = .93, label.padding = unit(.09, "lines"),
    show.legend = FALSE) +
  geom_text(data = description_phrases,
    aes(midpoint, phrase_y, label = phrase, color = phrase_variable),
    inherit.aes = FALSE, size = 3.05, lineheight = .93,
    show.legend = FALSE) +
  geom_text(data = phase_annotations,
    aes(midpoint, id_y, label = subphase_id), inherit.aes = FALSE,
    color = "grey15", fontface = "bold", size = 4.1,
    show.legend = FALSE) +
  geom_text(data = stable_annotations,
    aes(midpoint, id_y, label = era_id), inherit.aes = FALSE,
    fontface = "bold", size = 4.1) +
  time_axis() +
  scale_y_continuous(expand = expansion(mult = c(.07, .16))) +
  scale_fill_manual(values = era_colors, guide = "none") +
  scale_color_manual(values = c(variable_colors, context = "grey25"),
    labels = variable_labels, name = NULL) +
  labs(tag = "A.", title = "Holocene climate change", x = NULL,
       y = "Signed standardized change") +
  theme_paleoaces(base_size = 14) +
  theme(panel.grid.minor = element_blank(),
        axis.text.x = element_blank(), axis.ticks.x = element_blank(),
        legend.position = "none",
        plot.title = element_text(face = "bold", size = 17),
        axis.title.y = element_text(size = 15),
        axis.text.y = element_text(size = 13.5))

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
  here("output/holocene_era_fire_threshold_ratio.csv"))

p_fire = ggplot(fire_ratio, aes(cal_bp, high_fire_ratio, group = site)) +
  era_background(.28) +
  geom_hline(yintercept = 1, color = "grey45", linetype = "dashed",
    linewidth = .55) +
  geom_line(color = "grey20", linewidth = .8) +
  geom_segment(data = filter(fire_ratio, high_fire),
    aes(xend = cal_bp, y = 1, yend = high_fire_ratio),
    color = PAPER_FIRE_RED, linewidth = 2.2, alpha = .55) +
  geom_point(data = filter(fire_ratio, high_fire), color = PAPER_FIRE_RED,
    size = 1.35) +
  facet_grid(rows = vars(site), scales = "fixed") +
  time_axis() +
  scale_fill_manual(values = era_colors, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(.05, .10))) +
  labs(tag = "B.", x = "cal BP", y = "Fire-frequency ratio\n(high fire > 1)") +
  theme_paleoaces(base_size = 13) +
  theme(panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey94", color = "grey65"),
    strip.text.y = element_text(face = "bold", size = 12),
    axis.text.y = element_text(size = 11),
    axis.text.x = element_text(size = 13),
    axis.title = element_text(size = 14.5))

# Put the numerical comparison directly beside the Holocene trajectories. This
# behaves like a compact figure annotation rather than a separate table panel.
# H max is the signed Holocene maximum; its age is shown in parentheses. MORA
# and NOCA are the plot-level Anthropocene medians. All columns use raw rates
# per century, with temperature and precipitation units stated in the rows.
rate_callout = rate_comparison |>
  mutate(
    y = seq(3.65, .80, length.out = n()),
    variable_callout = case_when(
      variable == "MSpT" ~ "Spring temp\n(deg C)",
      variable == "MWT" ~ "Winter temp\n(deg C)",
      variable == "SP" ~ "Summer precip\n(mm)",
      variable == "WP" ~ "Winter precip\n(mm)"),
    holocene_callout = sprintf("%+.2f\n(%.1f ka)",
      holocene_max_signed_rate_per_century, holocene_peak_cal_bp / 1000),
    mora_callout = sprintf("%+.2f",
      anthropocene_median_rate_per_century_MORA),
    noca_callout = sprintf("%+.2f",
      anthropocene_median_rate_per_century_NOCA))

p_rate_callout = ggplot(rate_callout) +
  annotate("rect", xmin = -.48, xmax = 4.85, ymin = .25, ymax = 5.25,
    fill = "grey98", color = "grey72", linewidth = .45) +
  annotate("rect", xmin = -.47, xmax = 4.84, ymin = 4.18, ymax = 5.24,
    fill = "grey93", color = NA) +
  annotate("segment", x = -.25, xend = 4.62, y = 4.18, yend = 4.18,
    color = "grey72", linewidth = .4) +
  annotate("text", x = -.25, y = 4.94, label = "Raw rates per century",
    hjust = 0, fontface = "bold", size = 5.15) +
  annotate("text", x = c(2.25, 3.85), y = 4.63,
    label = c("Holocene", "Anthropocene"), fontface = "bold",
    color = "grey25", size = 3.85) +
  annotate("text", x = c(2.25, 3.35, 4.35), y = 4.30,
    label = c("Maximum\nregional median", "MORA", "NOCA"),
    fontface = "bold", lineheight = .88, size = c(3.25, 3.65, 3.65)) +
  geom_point(aes(-.20, y, color = variable), size = 3.2,
    show.legend = FALSE) +
  geom_text(aes(.02, y, label = variable_callout, color = variable),
    hjust = 0, lineheight = .90, size = 3.85, show.legend = FALSE) +
  geom_text(aes(2.25, y, label = holocene_callout),
    lineheight = .90, size = 3.80) +
  geom_text(aes(3.35, y, label = mora_callout), size = 3.80) +
  geom_text(aes(4.35, y, label = noca_callout), size = 3.80) +
  scale_color_manual(values = variable_colors) +
  coord_cartesian(xlim = c(-.5, 4.9), ylim = c(.2, 5.3), clip = "off") +
  theme_void() +
  theme(plot.margin = margin(8, 6, 8, 4))

# The callout shares the main plotting row. A spacer below it preserves exact
# horizontal alignment between the Holocene time series and the fire lanes.
top_row = p_climate + p_rate_callout +
  plot_layout(widths = c(5.2, 1.95))
bottom_row = p_fire + plot_spacer() +
  plot_layout(widths = c(5.2, 1.95))
figure = top_row / bottom_row +
  plot_layout(heights = c(4.5, 1.45))
if (render_figures) {
  ggsave(here("plot/fig_standardized_climate_change_eras_fire.pdf"), figure,
    width = 16.2, height = 9.5)
  ggsave(here("plot/fig_standardized_climate_change_eras_fire.png"), figure,
    width = 16.2, height = 9.5, dpi = 300, bg = "white")
}
cat("Written fire-threshold ratio and raw-rate comparison CSV",
    if (render_figures) ", plus the climate/fire figure.\n" else ".\n", sep = "")
