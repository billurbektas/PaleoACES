# Figure 4 (PLAN.md section 6; redrawn by Bills, 10 Nov 2026): fitted means
# and 95% intervals of the three period types side by side per park, from the
# Step 5a models, each mean printed beside its point in the park colour.
# A climate change rate and B observed community turnover on log axes, where
# equal distances are equal folds, with an arrow labelled with the fold between
# the Holocene-C and Anthropocene means. C the lag and D the lag rate on linear
# axes, with connectors from the Anthropocene to each Holocene period type and
# a star where that contrast is significant (p < 0.05).
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

types = c('Holocene-S', 'Holocene-C', 'Anthropocene')
sites = c('MORA', 'NOCA')
# Period types side by side within each park, stability on the left.
OFFSET = c(`Holocene-S` = -.32, `Holocene-C` = 0, Anthropocene = .32)
# Axis titles for this figure (Bills, 10 Nov 2026).
TITLES = c(climate_rate = 'Climate change rate\n(log scale)', turnover_rate = 'Observed community turnover\n(log scale)',
  lag = 'Community-climate lag', lag_rate = 'Community-climate lag rate')
LOG_RESPONSES = c('climate_rate', 'turnover_rate')
minus = function(x) gsub('-', '−', x)

means = read_csv(out('era_comparison/era_means.csv'), show_col_types = FALSE) |>
  filter(response %in% names(TITLES)) |>
  mutate(period_type = factor(period_type, levels = types), site = factor(site, levels = sites),
    x = as.integer(site) + OFFSET[as.character(period_type)],
    # Rates are positive by construction and printed without sign. The lags are
    # signed. No stars on means: stars belong to the contrasts (Bills).
    label = case_when(
      response %in% LOG_RESPONSES & estimate >= 1 ~ sprintf('%.2f', estimate),
      response %in% LOG_RESPONSES ~ sprintf('%.3f', estimate),
      abs(estimate) < 5e-4 ~ '0.000',
      TRUE ~ minus(sprintf('%+.3f', estimate))))
folds = read_csv(out('era_comparison/era_folds.csv'), show_col_types = FALSE) |>
  filter(against == 'Holocene-C', response %in% LOG_RESPONSES)
# The fold arrow runs from just above the Holocene-C interval to just below the
# Anthropocene interval, between the two symbols, clear of the mean labels.
arrows = means |> filter(period_type %in% c('Holocene-C', 'Anthropocene')) |>
  select(response, site, period_type, estimate, conf_low, conf_high) |>
  pivot_wider(names_from = period_type, values_from = c(estimate, conf_low, conf_high)) |>
  inner_join(folds |> mutate(site = factor(site, levels = sites)), by = c('response', 'site')) |>
  mutate(x = as.integer(site) + .16, y = `conf_high_Holocene-C` * 1.1, yend = conf_low_Anthropocene / 1.1,
    y_text = sqrt(y * yend), text = if_else(fold < 10, sprintf('%.1f-fold', fold), sprintf('%.0f-fold', fold)))
# Connectors above each park's intervals: Anthropocene to Holocene-C on the
# lower level, Anthropocene to Holocene-S on the upper one.
contrasts = read_csv(out('era_comparison/era_contrasts.csv'), show_col_types = FALSE) |>
  filter(!response %in% LOG_RESPONSES, contrast %in% c('Anthropocene - Holocene-C', 'Anthropocene - Holocene-S')) |>
  mutate(against = sub('Anthropocene - ', '', contrast), site = factor(site, levels = sites))
connectors = contrasts |>
  left_join(means |> group_by(response) |> summarise(span = max(conf_high) - min(conf_low)), by = 'response') |>
  left_join(means |> group_by(response, site) |> summarise(top = max(conf_high), .groups = 'drop'), by = c('response', 'site')) |>
  mutate(level = if_else(against == 'Holocene-C', 1, 2), y = top + (.03 + .085 * level) * span, drop = .03 * span,
    x = as.integer(site) + OFFSET[against], xend = as.integer(site) + OFFSET[['Anthropocene']],
    star = if_else(p_value < .05, '*', ''))

panel = function(r, tag) {
  d = means |> filter(response == r)
  p = ggplot(d, aes(x, estimate)) +
    (if (!r %in% LOG_RESPONSES) geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed')) +
    # The fitted mean beside its point, in the park colour, on a white backing
    # that hides the zero line but sits under the intervals.
    geom_label(aes(x = x + .055, label = label, color = site), hjust = 0, size = 5.2, fontface = 'bold',
      fill = 'white', label.size = 0, label.padding = unit(.06, 'lines')) +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high, color = site), width = .08, linewidth = 1.1) +
    geom_point(aes(shape = period_type, fill = site), size = 5, color = 'grey10', stroke = .6) +
    scale_x_continuous(breaks = 1:2, labels = sites, limits = c(.5, 2.72), expand = c(0, 0)) +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, name = NULL, breaks = types, drop = FALSE,
      labels = c(`Holocene-S` = 'Holocene stability periods', `Holocene-C` = 'Holocene climate-change periods',
        Anthropocene = 'Anthropocene')) +
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
        expand = expansion(mult = c(.05, .08)))
  } else {
    k = connectors |> filter(response == r)
    p = p +
      geom_segment(data = k, aes(x = x, xend = xend, y = y, yend = y), color = 'grey25', linewidth = .7) +
      geom_segment(data = k, aes(x = x, xend = x, y = y, yend = y - drop), color = 'grey25', linewidth = .7) +
      geom_segment(data = k, aes(x = xend, xend = xend, y = y, yend = y - drop), color = 'grey25', linewidth = .7) +
      geom_text(data = k, aes(x = (x + xend) / 2, y = y, label = star), vjust = .25, size = 9, color = 'grey10') +
      scale_y_continuous(labels = function(b) minus(format(b, drop0trailing = TRUE, trim = TRUE)),
        expand = expansion(mult = c(.05, .06)))
  }
  p
}
# Two rows: climate and turnover on top, the lag and the lag rate below.
figure = (panel('climate_rate', 'A.') | panel('turnover_rate', 'B.')) /
  (panel('lag', 'C.') | panel('lag_rate', 'D.')) +
  plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_era_contrasts.', ext)), figure, width = 18, height = 13, dpi = 300,
    device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Figure 4: era means drawn.\n')
