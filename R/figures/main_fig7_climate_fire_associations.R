# Figure 7: climate and fire associations as model slopes (Bills, 9 Nov 2026).
# Left, Holocene lake-periods: response ~ site + climate + fire_activity.
# Right, Anthropocene plot pairs: response ~ site + burned. The three responses
# (lag, pace effect, direction effect) side by side for each term, with
# conditional 95% intervals. Top row the responses not divided by time, with the
# climate change between the two ends as the climate term (added by Bills, 10 Nov
# 2026; on top since 11 Nov). Bottom row per century, with the climate change
# rate as the climate term. Each row has one x scale for both eras. Estimates whose interval
# includes zero are faded. No R² under the panels (Bills, 11 Nov 2026): the
# descriptive R² is in the model-check table of the README.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

dir = 'community_predictor_models'
coefficients = read_csv(out(file.path(dir, 'model_coefficients.csv')), show_col_types = FALSE)
# The responses of each row. The legend names the quantity, the row title says
# whether it is per century or a total.
rows = list(rate = c(lag_rate = 'lag', pace_effect = 'pace', direction_effect = 'direction'),
  total = c(lag = 'lag', pace_effect_total = 'pace', direction_effect_total = 'direction'))
quantity_labels = c(lag = 'Lag', pace = 'Pace effect', direction = 'Direction effect')
# Colours of the conceptual figure (Figure 1): mismatch and lag black, pace pink,
# direction blue.
quantity_colors = c(lag = 'grey10', pace = '#C27B93', direction = '#6AB2E4')
term_labels = c(siteNOCA = 'Site\nNOCA − MORA', climate_rate = 'Climate change rate',
  climate_change = 'Climate change', fire_activity = 'Fire activity', burnedBurned = 'Burned − unburned')
row_titles = c(rate = 'Per century', total = 'Not divided by time')

panel = function(era_name, version, terms, tag) {
  responses = rows[[version]]
  d = coefficients |> filter(era == era_name, metric %in% names(responses), term %in% terms) |>
    mutate(quantity = factor(responses[metric], levels = names(quantity_labels)),
      y = match(term, rev(terms)) + c(.22, 0, -.22)[as.integer(quantity)],
      faded = conf_low <= 0 & conf_high >= 0)
  # One x scale for both eras within a row, so that their effects compare directly.
  x_limits = range(coefficients |> filter(metric %in% names(responses), term %in% c('siteNOCA', 'climate_rate',
    'climate_change', 'fire_activity', 'burnedBurned')) |> select(conf_low, conf_high)) * 1.05
  ggplot(d, aes(estimate, y, color = quantity)) +
    geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed', linewidth = .6) +
    geom_errorbar(aes(xmin = conf_low, xmax = conf_high, alpha = faded), orientation = 'y', width = .12, linewidth = 1.3) +
    geom_point(aes(alpha = faded), size = 5) +
    scale_y_continuous(breaks = seq_along(terms), labels = unname(term_labels[rev(terms)]),
      limits = c(.5, length(terms) + .5), expand = expansion(0)) +
    scale_color_manual(values = quantity_colors, labels = quantity_labels, name = NULL, drop = FALSE,
      guide = guide_legend(override.aes = list(alpha = 1, size = 7, linewidth = 1.8))) +
    scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = .35), guide = 'none') +
    coord_cartesian(xlim = x_limits) +
    labs(tag = tag, title = era_name, subtitle = row_titles[[version]], x = 'Effect on response', y = NULL) +
    theme_paleoaces(base_size = 25) +
    theme(plot.title = element_text(size = 30, face = 'bold'), plot.subtitle = element_text(size = 27, color = 'grey25'),
      plot.tag = element_text(size = 32, face = 'bold'),
      axis.text.y = element_text(size = 30, color = 'grey15', lineheight = .9), axis.text.x = element_text(size = 23),
      axis.title.x = element_text(size = 25), panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
      legend.position = 'bottom', legend.text = element_text(size = 32), legend.key.size = unit(1.4, 'cm'),
      legend.spacing.x = unit(.6, 'cm'))
}
# The legend in its own row at the bottom (Bills, 11 Nov 2026).
# Top row the responses not divided by time, bottom row per century (Bills, 11 Nov 2026).
figure = (panel('Holocene', 'total', c('siteNOCA', 'climate_change', 'fire_activity'), 'A.') |
    panel('Anthropocene', 'total', c('siteNOCA', 'burnedBurned'), 'B.')) /
  (panel('Holocene', 'rate', c('siteNOCA', 'climate_rate', 'fire_activity'), 'C.') |
    panel('Anthropocene', 'rate', c('siteNOCA', 'burnedBurned'), 'D.')) /
  guide_area() +
  plot_layout(guides = 'collect', heights = c(1, 1, .07)) & theme(legend.position = 'bottom')
if (render_figures) {
  # cairo_pdf draws the minus signs of the term labels, which the default pdf device cannot.
  ggsave(fig('main', 'fig_climate_fire_associations.pdf'), figure, width = 21, height = 19, device = cairo_pdf, bg = 'white')
  ggsave(fig('main', 'fig_climate_fire_associations.png'), figure, width = 21, height = 19, dpi = 300, bg = 'white')
}
cat('Figure 7: model slopes drawn, per century and not divided by time.\n')
