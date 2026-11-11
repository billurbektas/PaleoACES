# Appendix figures of the lake-period values over time (redrawn on lake-periods
# by Bills's request, 10 Nov 2026; before the remodelling they showed steps
# between consecutive centuries, which PLAN.md section 2 replaced because those
# steps are mostly sampling noise). One column per lake: each lake-period a
# bar from its oldest to its youngest sampled century at its value, with its
# symbol at the middle (circle C, triangle S, PLAN.md section 6), under the C
# and S period bands. A last column holds the Anthropocene plot pairs of each
# park as boxplots, on their own scale. Units are in the captions.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

lake_order = c('JayBath', 'LogWallow', 'ReflectionPond', 'PantherPotholes')
lake_labels = c('Jay Bath (MORA)', 'Log Wallow (MORA)', 'Reflection Pond (MORA)', 'Panther Potholes (NOCA)')
periods = read_csv(out('holocene_periods.csv'), show_col_types = FALSE) |>
  mutate(midpoint = (older_cal_bp + younger_cal_bp) / 2)
lake_periods = read_csv(out('cca_tracking_lake_period_calculations.csv'), show_col_types = FALSE) |>
  # Ratio and angle are undefined where a position did not move (PLAN.md 4.7).
  mutate(magnitude_tracking_ratio = if_else(tracking_ratio_valid, magnitude_tracking_ratio, NA_real_),
    angle_degrees = if_else(angle_valid, angle_degrees, NA_real_),
    lake = factor(lake, levels = lake_order, labels = lake_labels), t = (age_start + age_end) / 2)
plots = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE) |> filter(period_type == 'Anthropocene') |>
  left_join(read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE) |>
      transmute(plot_id = as.character(plot_id), magnitude_tracking_ratio = if_else(tracking_ratio_valid, magnitude_tracking_ratio, NA_real_),
        angle_degrees = if_else(angle_valid, angle_degrees, NA_real_)),
    by = 'plot_id', relationship = 'one-to-one')
stopifnot(nrow(plots) == sum(ANTHROPOCENE_PAIRS))  # Rule: the Anthropocene plot pairs of config.R.

lake_period_panels = function(rows, title_text) {
  long = lake_periods |> pivot_longer(all_of(names(rows)), names_to = 'response', values_to = 'value') |>
    filter(is.finite(value)) |> mutate(response = factor(rows[response], levels = rows))
  modern = plots |> pivot_longer(any_of(names(rows)), names_to = 'response', values_to = 'value') |>
    filter(is.finite(value)) |> mutate(response = factor(rows[response], levels = rows), column = 'Anthropocene')
  reference = tibble(response = factor(rows, levels = rows),
    y = case_when(names(rows) == 'magnitude_tracking_ratio' ~ 1, names(rows) == 'angle_degrees' ~ 90,
      names(rows) == 'fire_activity' ~ NA_real_, TRUE ~ 0))
  # Period names above the first row only.
  # Staggered on two lines, so short neighbouring periods do not collide.
  labels = periods |> mutate(response = factor(rows[[1]], levels = rows), vjust = if_else(row_number() %% 2 == 1, 1.3, 2.7))
  left = ggplot(long) +
    geom_rect(data = periods, aes(xmin = younger_cal_bp, xmax = older_cal_bp, ymin = -Inf, ymax = Inf, fill = period_type),
      inherit.aes = FALSE, alpha = .5) +
    geom_hline(data = filter(reference, is.finite(y)), aes(yintercept = y), color = 'grey55', linetype = 'dashed') +
    geom_segment(aes(x = age_start, xend = age_end, y = value, yend = value, color = site), linewidth = 1.6) +
    geom_point(aes(t, value, shape = period_type, fill = site), size = 3.6, color = 'grey10', stroke = .5) +
    geom_text(data = labels, aes(midpoint, Inf, label = period, vjust = vjust), inherit.aes = FALSE, size = 3.8,
      fontface = 'bold', color = 'grey25') +
    facet_grid(response ~ lake, scales = 'free_y', switch = 'y') +
    scale_x_reverse(limits = c(10500, 0), breaks = seq(10000, 0, -2500), labels = scales::label_comma()) +
    scale_y_continuous(expand = expansion(mult = c(.08, .32))) +
    scale_fill_manual(values = c(`Holocene-C` = 'grey86', `Holocene-S` = 'grey96', PAPER_SITE_COLORS), guide = 'none') +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES[c('Holocene-C', 'Holocene-S')], name = NULL,
      labels = c(`Holocene-C` = 'Holocene climate-change period', `Holocene-S` = 'Holocene stability period')) +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60', size = 5))) +
    labs(x = 'cal BP', y = NULL) +
    theme_paleoaces(base_size = 17) +
    theme(strip.placement = 'outside', strip.text.y.left = element_text(angle = 90, face = 'bold'),
      strip.text.x = element_text(face = 'bold'), panel.grid.minor = element_blank(), legend.position = 'bottom')
  right = ggplot(modern, aes(site, value, fill = site)) +
    geom_hline(data = filter(reference, is.finite(y)), aes(yintercept = y), color = 'grey55', linetype = 'dashed') +
    geom_boxplot(alpha = .45, outlier.size = .7, outlier.alpha = .5, width = .6) +
    facet_grid(response ~ column, scales = 'free_y', drop = FALSE) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    labs(x = NULL, y = NULL) + theme_paleoaces(base_size = 17) +
    theme(strip.text.y = element_blank(), strip.text.x = element_text(face = 'bold'), panel.grid.minor = element_blank())
  # The plot pairs have no continuous fire activity, only burned or unburned.
  if ('fire_activity' %in% names(rows)) right = right +
    geom_text(data = tibble(response = factor(rows[['fire_activity']], levels = rows), column = 'Anthropocene'),
      aes(x = 1.5, y = .5, label = 'No continuous fire\nactivity for plots'), inherit.aes = FALSE, size = 4, color = 'grey35') +
    geom_blank(data = tibble(response = factor(rows[['fire_activity']], levels = rows), column = 'Anthropocene', site = 'MORA', value = c(0, 1)))
  (left | right) + plot_layout(widths = c(4, 1), guides = 'collect') +
    plot_annotation(title = title_text, theme = theme(plot.title = element_text(size = 20, face = 'bold'))) &
    theme(legend.position = 'bottom')
}
p_rates = lake_period_panels(c(climate_rate = 'Climate change rate', turnover_rate = 'Turnover rate',
  lag_rate = 'Lag rate', pace_effect = 'Pace effect', direction_effect = 'Direction effect',
  fire_activity = 'Fire activity'), 'Lake-period values over time')
p_other = lake_period_panels(c(magnitude_tracking_ratio = 'Magnitude ratio', angle_degrees = 'Movement angle',
  climate_rate = 'Climate change rate', fire_activity = 'Fire activity'), 'Lake-period tracking ratio and angle over time')
if (render_figures) {
  ggsave(fig('supplementary', 'fig_tracking_transition_rates.pdf'), p_rates, width = 22, height = 17, device = cairo_pdf)
  ggsave(fig('supplementary', 'fig_tracking_transition_ratios_angles.pdf'), p_other, width = 22, height = 12, device = cairo_pdf)
}
cat('Appendix lake-period displays drawn.\n')
