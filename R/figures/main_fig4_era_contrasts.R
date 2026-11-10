# Figure 4 (PLAN.md section 6; redrawn by Bills, 10 Nov 2026): fitted means
# and 95% intervals of the three period types side by side per park, from the
# Step 5a models. A climate change rate and B turnover rate on log axes, where
# equal distances are equal folds, with an arrow labelled with the fold between
# the Holocene-C and Anthropocene means. C the lag and D the lag rate on linear
# axes, without folds.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

types = c('Holocene-S', 'Holocene-C', 'Anthropocene')
# Period types side by side within each park, stability on the left.
OFFSET = c(`Holocene-S` = -.3, `Holocene-C` = 0, Anthropocene = .3)
# Axis titles for this figure (Bills, 10 Nov 2026).
TITLES = c(climate_rate = 'Climate change rate', turnover_rate = 'Turnover rate',
  lag = 'Community-climate lag', lag_rate = 'Community-climate lag rate')
LOG_RESPONSES = c('climate_rate', 'turnover_rate')
minus = function(x) gsub('-', '−', x)

means = read_csv(out('era_comparison/era_means.csv'), show_col_types = FALSE) |>
  filter(response %in% names(TITLES)) |>
  mutate(period_type = factor(period_type, levels = types), site = factor(site, levels = c('MORA', 'NOCA')),
    x = as.integer(site) + OFFSET[as.character(period_type)],
    # Rates are positive by construction and printed without sign or star. The
    # lags are signed, and a star marks a mean that differs from zero (p < 0.05).
    signed = !response %in% LOG_RESPONSES,
    label = case_when(
      !signed & estimate >= 1 ~ sprintf('%.2f', estimate),
      !signed ~ sprintf('%.3f', estimate),
      abs(estimate) < 5e-4 ~ '0.000',
      TRUE ~ paste0(minus(sprintf('%+.3f', estimate)), if_else(p_value < .05, '*', ''))))
folds = read_csv(out('era_comparison/era_folds.csv'), show_col_types = FALSE) |>
  filter(against == 'Holocene-C', response %in% LOG_RESPONSES)
# The fold arrow runs between the Holocene-C and the Anthropocene means, between
# their two symbols, and stops short of both.
arrows = means |> filter(period_type %in% c('Holocene-C', 'Anthropocene')) |>
  select(response, site, period_type, estimate) |> pivot_wider(names_from = period_type, values_from = estimate) |>
  inner_join(folds |> mutate(site = factor(site, levels = c('MORA', 'NOCA'))), by = c('response', 'site')) |>
  mutate(x = as.integer(site) + .15, y = `Holocene-C` * 1.25, yend = Anthropocene / 1.12,
    y_text = sqrt(`Holocene-C` * Anthropocene),
    text = if_else(fold < 10, sprintf('%.1f-fold', fold), sprintf('%.0f-fold', fold)))

panel = function(r, tag) {
  d = means |> filter(response == r)
  p = ggplot(d, aes(x, estimate)) +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high, color = site), width = .1, linewidth = 1.1) +
    geom_point(aes(shape = period_type, fill = site), size = 5, color = 'grey10', stroke = .6) +
    # The fitted mean above its interval.
    geom_text(aes(y = conf_high, label = label), vjust = -.7, size = 5.6, color = 'grey10') +
    scale_x_continuous(breaks = 1:2, labels = c('MORA', 'NOCA'), limits = c(.5, 2.62), expand = c(0, 0)) +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, name = NULL, breaks = types, drop = FALSE,
      labels = c(`Holocene-S` = 'Holocene stability periods', `Holocene-C` = 'Holocene climate-change periods',
        Anthropocene = 'Anthropocene plot pairs')) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60', size = 5.5))) +
    labs(tag = tag, x = NULL, y = TITLES[[r]]) +
    theme_paleoaces(base_size = 20) +
    theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
      legend.text = element_text(size = 19), plot.tag = element_text(size = 24, face = 'bold'))
  if (r %in% LOG_RESPONSES) {
    a = arrows |> filter(response == r)
    p = p +
      geom_segment(data = a, aes(x = x, xend = x, y = y, yend = yend), color = 'grey35', linewidth = .8,
        arrow = arrow(length = unit(.18, 'cm'), ends = 'both', type = 'closed')) +
      geom_text(data = a, aes(x = x + .03, y = y_text, label = text), hjust = 0, size = 5.6, color = 'grey15',
        fontface = 'bold') +
      # Log axis, tick labels as plain decimals in real values.
      scale_y_log10(breaks = c(.005, .01, .02, .05, .1, .2, .5, 1, 2, 5),
        labels = function(b) format(b, scientific = FALSE, drop0trailing = TRUE, trim = TRUE),
        expand = expansion(mult = c(.05, .1)))
  } else {
    p = p + geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed') +
      scale_y_continuous(labels = function(b) minus(format(b, drop0trailing = TRUE, trim = TRUE)),
        expand = expansion(mult = c(.05, .12)))
  }
  p
}
# Two rows: climate and turnover on top, the lag and the lag rate below.
figure = (panel('climate_rate', 'A.') | panel('turnover_rate', 'B.')) /
  (panel('lag', 'C.') | panel('lag_rate', 'D.')) +
  plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_era_contrasts.', ext)), figure, width = 14, height = 13, dpi = 300,
    device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Figure 4: era means drawn.\n')
