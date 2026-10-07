# =============================================================================
# 09c_tracking_comparison.R - integrated tracking comparison figure
# =============================================================================
# Boxplots are faceted by site with fixed scales. The scatter remains one panel:
# site is shape, lag is fill, and fire evidence is the only categorical colour.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(patchwork); library(ggrepel)
})
source(here("R/helpers/figure_style.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

input_path = here("output/cca_tracking_visualization_points.csv")
fire_paths = c(
  MORA = here("output/MORA_plot_info_fire.csv"),
  NOCA = here("output/NOCA_fire_assignment_audit.csv"),
  Holocene = here("output/holocene_era_fire_site_frequency.csv"))
if (!file.exists(input_path) || !all(file.exists(fire_paths)))
  stop("Run tracking visualization data and the harmonized fire-era stage first.")

points = read_csv(input_path, show_col_types = FALSE)
METRICS = c(
  lag = "Lag",
  lag_rate_per_century = "Lag per century",
  rate_tracking_ratio = "Tracking ratio (observed/predicted)",
  angle_degrees = "Angle (degrees)")
BOX_METRICS = METRICS[names(METRICS) != "lag"]
BOX_TAGS = c(lag_rate_per_century = "A.", rate_tracking_ratio = "B.",
             angle_degrees = "C.")
if (length(setdiff(names(METRICS), names(points))))
  stop("Tracking visualization points lack required metrics.")

FIRE_RED = PAPER_FIRE_RED
NO_FIRE = PAPER_NO_FIRE
site_shapes = PAPER_SITE_SHAPES
raw_all = points |>
  filter(point_class %in% c("holocene_site_interval", "anthropocene_plot"))
if (nrow(raw_all) != 742L) stop("Expected 137 Holocene and 605 Anthropocene rows.")

modern_fire = bind_rows(
  read_csv(fire_paths[["MORA"]], show_col_types = FALSE) |>
    transmute(site = "MORA", plot_id = str_to_upper(plot_id), burnt),
  read_csv(fire_paths[["NOCA"]], show_col_types = FALSE) |>
    transmute(site = "NOCA", plot_id = str_to_upper(plot_id), burnt))
modern_all = raw_all |>
  filter(point_class == "anthropocene_plot") |>
  mutate(plot_id = str_to_upper(plot_id)) |>
  left_join(modern_fire, by = c("site", "plot_id"))
if (nrow(modern_all) != 605L || anyNA(modern_all$burnt))
  stop("Every Anthropocene plot must have one fire assignment.")
modern = modern_all |>
  mutate(included = !(site == "MORA" & burnt),
    fire_status = if_else(burnt, "Burned", "Unburned")) |>
  filter(included)
if (nrow(modern) != 603L ||
    sum(modern_all$site == "MORA" & modern_all$burnt) != 2L ||
    sum(modern$site == "NOCA" & modern$burnt) != 23L)
  stop("Unexpected Anthropocene fire groups.")
write_csv(modern_all |>
    transmute(site, plot_id, burnt, included = !(site == "MORA" & burnt),
      analysis_group = case_when(
        site == "MORA" & burnt ~ "excluded: MORA burned",
        burnt ~ "included: NOCA burned", TRUE ~ "included: unburned")),
  here("output/cca_tracking_anthropocene_fire_scope_audit.csv"))

holocene_fire = read_csv(fire_paths[["Holocene"]], show_col_types = FALSE) |>
  transmute(site, t = cal_bp, high_fire,
    normalized_fire_frequency = normalized_frequency)
holocene = raw_all |>
  filter(point_class == "holocene_site_interval") |>
  left_join(holocene_fire, by = c("site", "t")) |>
  mutate(fire_status = if_else(high_fire,
    "High-fire evidence", "No high-fire evidence"))
if (nrow(holocene) != 137L || anyNA(holocene$high_fire))
  stop("Every Holocene site-date must match one harmonized fire date.")

raw = bind_rows(holocene, modern) |>
  mutate(site = factor(site, c("MORA", "NOCA")),
    macro_era = factor(macro_era, c("Holocene", "Anthropocene")),
    fire_class = if_else(fire_status %in% c("Burned", "High-fire evidence"),
      "Fire", "No fire"),
    fire_class = factor(fire_class, c("No fire", "Fire")))
state = holocene |>
  mutate(site = factor(site, c("MORA", "NOCA")),
    climate_state = if_else(climate_era_class == "climate change",
      "Holocene climate change", "Holocene climate stability"),
    climate_state = factor(climate_state,
      c("Holocene climate change", "Holocene climate stability")),
    fire_class = factor(if_else(high_fire, "Fire", "No fire"),
      c("No fire", "Fire")))

safe = function(x, f, ...) {
  x = x[is.finite(x)]
  if (length(x)) f(x, ...) else NA_real_
}
summarize_group = function(data, group_vars, level) {
  data |>
    select(all_of(group_vars), all_of(names(METRICS))) |>
    pivot_longer(all_of(names(METRICS)), names_to = "metric", values_to = "value") |>
    group_by(across(all_of(c(group_vars, "metric")))) |>
    summarise(summary_level = level, n_total = n(),
      n_valid = sum(is.finite(value)), median = safe(value, median),
      q25 = safe(value, quantile, .25, names = FALSE),
      q75 = safe(value, quantile, .75, names = FALSE),
      whisker_low = if (any(is.finite(value)))
        boxplot.stats(value[is.finite(value)])$stats[1] else NA_real_,
      whisker_high = if (any(is.finite(value)))
        boxplot.stats(value[is.finite(value)])$stats[5] else NA_real_,
      .groups = "drop")
}

main_summary = summarize_group(raw,
  c("site", "macro_era", "fire_class"), "macro era x fire")
detail_summary = summarize_group(state,
  c("site", "climate_state", "fire_class"), "Holocene climate state x fire")
macro_summary = summarize_group(raw,
  c("site", "macro_era"), "macro era")
noca_fire_summary = summarize_group(
  filter(raw, site == "NOCA", macro_era == "Anthropocene"),
  c("site", "fire_status"), "NOCA Anthropocene fire status")
comparison_summary = bind_rows(main_summary, detail_summary,
  macro_summary, noca_fire_summary)
write_csv(comparison_summary,
  here("output/cca_tracking_comparison_summary.csv"))

fmt = function(metric, x) formatC(x, format = "f",
  digits = if (metric == "angle_degrees") 1L else
    if (metric == "rate_tracking_ratio") 2L else 3L)
# Fire status is carried by the outline. Both boxes stay white so the median
# line remains visible; a solid dark-red box previously obscured it.
fire_fill = c(`No fire` = "white", Fire = "white")
fire_line = c(`No fire` = NO_FIRE, Fire = FIRE_RED)
base_theme = theme_paleoaces(base_size = 11.5) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    legend.position = "none", axis.title.x = element_blank(),
    axis.text.x = element_text(face = "bold", size = 9.4),
    strip.background = element_rect(fill = "grey95", color = "grey65"),
    strip.text = element_text(face = "bold", size = 11.5),
    axis.title.y = element_text(size = 13),
    plot.margin = margin(5, 5, 4, 5))

make_main_box = function(metric, tag = BOX_TAGS[[metric]]) {
  dat = filter(raw, is.finite(.data[[metric]]))
  sm = filter(main_summary, .data$metric == .env$metric) |>
    mutate(label = paste0(fmt(.env$metric, median), "\nn=", n_valid))
  dodge = position_dodge2(width = .68, preserve = "single", padding = .15)
  ggplot(dat, aes(macro_era, .data[[metric]], fill = fire_class,
      color = fire_class, group = interaction(macro_era, fire_class))) +
    geom_boxplot(position = dodge, width = .55, linewidth = .6,
      outlier.shape = NA, na.rm = TRUE) +
    geom_text(data = sm,
      aes(macro_era, whisker_high, label = label, color = fire_class,
        group = interaction(macro_era, fire_class)), inherit.aes = FALSE,
      position = dodge, vjust = -.35, size = 2.4, lineheight = .84,
      fontface = "bold", show.legend = FALSE) +
    facet_wrap(~site, nrow = 1, scales = "fixed") +
    scale_fill_manual(values = fire_fill) + scale_color_manual(values = fire_line) +
    scale_y_continuous(expand = expansion(mult = c(.08, .25))) +
    labs(title = tag, y = unname(METRICS[metric])) + base_theme +
    theme(plot.title = element_text(face = "bold", size = 15))
}

make_detail_box = function(metric) {
  dat = filter(state, is.finite(.data[[metric]]))
  sm = filter(detail_summary, .data$metric == .env$metric) |>
    mutate(label = paste0(fmt(.env$metric, median), "\nn=", n_valid))
  dodge = position_dodge2(width = .68, preserve = "single", padding = .15)
  ggplot(dat, aes(climate_state, .data[[metric]], fill = fire_class,
      color = fire_class, group = interaction(climate_state, fire_class))) +
    geom_boxplot(position = dodge, width = .55, linewidth = .55,
      outlier.shape = NA, na.rm = TRUE) +
    geom_text(data = sm,
      aes(climate_state, whisker_high, label = label, color = fire_class,
        group = interaction(climate_state, fire_class)), inherit.aes = FALSE,
      position = dodge, vjust = -.35, size = 2.05, lineheight = .82,
      fontface = "bold", show.legend = FALSE) +
    facet_wrap(~site, nrow = 1, scales = "fixed") +
    scale_fill_manual(values = fire_fill) + scale_color_manual(values = fire_line) +
    scale_x_discrete(labels = c("Holocene\nclimate change",
                                "Holocene\nclimate stability")) +
    scale_y_continuous(expand = expansion(mult = c(.09, .28))) +
    labs(title = NULL, y = unname(METRICS[metric])) + base_theme +
    theme(axis.text.x = element_text(size = 8.8, face = "bold"))
}

metric_stacks = purrr::map(names(BOX_METRICS), ~make_main_box(.x) /
  make_detail_box(.x) +
  plot_layout(heights = c(1.65, 1), axis_titles = "collect"))
panel_a = wrap_plots(metric_stacks, nrow = 1)
SCATTER_WIDTH_FRACTION = 0.75

wide_summary = function(x) x |>
  select(-summary_level, -n_valid, -q25, -q75,
         -whisker_low, -whisker_high) |>
  pivot_wider(names_from = metric, values_from = median)
macro_scatter = wide_summary(macro_summary) |>
  mutate(label = paste0(as.character(macro_era), "\nmedian"),
    fire_class = factor("No fire",
    levels = c("No fire", "Fire")), point_size = 6.2)
era_sets = state |>
  group_by(site, climate_state, fire_class) |>
  summarise(era_ids = paste(sort(unique(climate_era_id)), collapse = ", "),
            .groups = "drop")
detail_scatter = wide_summary(detail_summary) |>
  left_join(era_sets, by = c("site", "climate_state", "fire_class")) |>
  mutate(label = paste0("Holocene\n",
      if_else(climate_state == "Holocene climate change",
        paste0("Climate change (", era_ids, ")"),
        paste0("Climate stability (", era_ids, ")"))),
    point_size = 3.8)
noca_fire_scatter = wide_summary(noca_fire_summary) |>
  mutate(label = paste0("Anthropocene\n", str_to_lower(fire_status)),
    fire_class = factor(if_else(fire_status == "Burned", "Fire", "No fire"),
      levels = c("No fire", "Fire")), point_size = 4.8)

# One label layer is essential: separate ggrepel layers do not repel one
# another, which allowed macro-era, climate-state and burn-status text to sit on
# top of each other. Size remains a display attribute, not a data encoding.
scatter_labels = bind_rows(
  macro_scatter |> mutate(label_size = 3.2),
  detail_scatter |> mutate(label_size = 2.45),
  noca_fire_scatter |> mutate(label_size = 2.65))

background = raw |>
  filter(is.finite(angle_degrees), is.finite(rate_tracking_ratio))
stationary = raw |>
  filter(macro_era == "Anthropocene",
    observed_vegetation_displacement <= 1e-8) |>
  count(site, name = "n")
stationary_label = paste0("Stationary observed composition: angle undefined\n",
  paste0(stationary$site, " n=", stationary$n, collapse = "; "))
lag_limit = max(abs(c(macro_scatter$lag, detail_scatter$lag,
  noca_fire_scatter$lag)), na.rm = TRUE)
ratio_upper = max(c(1, background$rate_tracking_ratio,
  macro_scatter$rate_tracking_ratio, detail_scatter$rate_tracking_ratio,
  noca_fire_scatter$rate_tracking_ratio), na.rm = TRUE) * 1.05

panel_b = ggplot() +
  geom_vline(xintercept = 90, linetype = "dashed", color = "grey40") +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey40") +
  geom_point(data = background,
    aes(angle_degrees, rate_tracking_ratio, shape = site, color = fire_class),
    fill = "white", size = 1.2, stroke = .35, alpha = .13,
    show.legend = FALSE) +
  geom_point(data = detail_scatter,
    aes(angle_degrees, rate_tracking_ratio, shape = site,
      fill = lag, color = fire_class), size = 3.8, stroke = 1.0, alpha = .72) +
  geom_point(data = noca_fire_scatter,
    aes(angle_degrees, rate_tracking_ratio, shape = site,
      fill = lag, color = fire_class), size = 4.8, stroke = 1.25) +
  geom_point(data = macro_scatter,
    aes(angle_degrees, rate_tracking_ratio, shape = site,
      fill = lag, color = fire_class), size = 6.2, stroke = 1.45) +
  geom_text_repel(data = scatter_labels,
    aes(angle_degrees, rate_tracking_ratio, label = label,
      color = fire_class, size = label_size),
    fontface = "bold", min.segment.length = 0,
    box.padding = .48, point.padding = .18, force = 2,
    seed = 37, max.overlaps = Inf, max.iter = 200000,
    show.legend = FALSE) +
  annotate("label", x = 3, y = ratio_upper * .965,
    label = stationary_label, hjust = 0, vjust = 1,
    size = 3, color = "grey25", fill = "white", linewidth = .25) +
  scale_shape_manual(name = "Site", values = site_shapes) +
  scale_color_manual(name = "Fire evidence", values = fire_line,
    labels = c(`No fire` = "No fire evidence / unburned",
               Fire = "High-fire evidence / burned")) +
  scale_fill_gradient2(name = "Lag", low = PAPER_SIGNED_COLORS[["low"]],
    mid = PAPER_SIGNED_COLORS[["mid"]], high = PAPER_SIGNED_COLORS[["high"]],
    midpoint = 0, limits = c(-lag_limit, lag_limit)) +
  scale_size_identity() +
  scale_x_continuous(limits = c(0, 180), breaks = seq(0, 180, 30),
    expand = expansion(mult = c(0, .01))) +
  scale_y_continuous(limits = c(0, ratio_upper),
    expand = expansion(mult = c(0, .025))) +
  guides(shape = guide_legend(order = 1),
    color = guide_legend(order = 2, override.aes = list(shape = 21,
      fill = "white", size = 4)),
    fill = guide_colorbar(order = 3, barwidth = grid::unit(4.5, "cm"))) +
  labs(title = "D.",
    x = "Angle (degrees)", y = "Tracking ratio (observed/predicted)") +
  theme_paleoaces(base_size = 12.5) +
  theme(panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 15),
    legend.position = "bottom", legend.box = "horizontal")

scatter_side_fraction = (1 - SCATTER_WIDTH_FRACTION) / 2
panel_b_row = plot_spacer() + panel_b + plot_spacer() +
  plot_layout(widths = c(scatter_side_fraction, SCATTER_WIDTH_FRACTION,
                         scatter_side_fraction))
figure = panel_a / panel_b_row + plot_layout(heights = c(1.25, 1))

plot_limits = function(plot) {
  pp = ggplot_build(plot)$layout$panel_params[[1]]
  tibble(x_min = pp$x.range[1], x_max = pp$x.range[2],
         y_min = pp$y.range[1], y_max = pp$y.range[2])
}
box_spec = purrr::map_dfr(names(BOX_METRICS), function(metric) bind_rows(
  plot_limits(make_main_box(metric)) |>
    mutate(record_type = "box", panel = str_remove(BOX_TAGS[[metric]], "\\.$"),
      metric = metric,
      element = "macro era x fire, fixed site facets",
      grouping_contract = "x=macro_era;group=interaction(macro_era,fire_class)",
      box_width_contract = "width=0.55;position_dodge2(preserve=single)",
      panel_width_fraction = 1),
  plot_limits(make_detail_box(metric)) |>
    mutate(record_type = "box", panel = str_remove(BOX_TAGS[[metric]], "\\.$"),
      metric = metric,
      element = "Holocene climate state x fire, fixed site facets",
      grouping_contract = "x=climate_state;group=interaction(climate_state,fire_class)",
      box_width_contract = "width=0.55;position_dodge2(preserve=single)",
      panel_width_fraction = 1)))
scatter_spec = plot_limits(panel_b) |>
  mutate(record_type = "scatter", panel = "D",
    metric = "angle_degrees x rate_tracking_ratio",
    element = "single unfaceted panel; raw points and labelled medians",
    grouping_contract = "site=shape;lag=fill;fire=categorical outline;era=label",
    n_background = nrow(background), n_macro = nrow(macro_scatter),
    n_detail = nrow(detail_scatter), n_noca_fire = nrow(noca_fire_scatter),
    x_reference = 90, y_reference = 1, lag_limit = lag_limit,
    n_stationary_angle_undefined = sum(stationary$n),
    label_contract = paste0("one shared repel layer; Holocene/Anthropocene median; ",
      "Holocene climate-state labels list exact represented CC/S eras; ",
      "Anthropocene burn status"),
    box_metrics = paste(names(BOX_METRICS), collapse = ";"),
    fire_box_fill = "white; fire distinguished by dark-red outline",
    panel_width_fraction = SCATTER_WIDTH_FRACTION,
    layout_contract = "centered with symmetric side spacers")
spec = bind_rows(box_spec, scatter_spec) |>
  mutate(x_scale = "raw_linear", y_scale = "raw_linear")
write_csv(spec, here("output/cca_tracking_comparison_spec.csv"))

if (render_figures) {
  ggsave(here("plot/fig_tracking_comparison.pdf"), figure,
    width = 17, height = 11.5, bg = "white")
  ggsave(here("plot/fig_tracking_comparison.png"), figure,
    width = 17, height = 11.5, dpi = 300, bg = "white")
  cat("Written fixed-facet fire-aware boxplots and one unfaceted tracking scatter.\n")
}
