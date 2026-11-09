# Figure 6: climate and fire associations as model slopes (Bills, 9 Nov 2026).
# A, Holocene lake-periods: response ~ site + climate_rate + fire_activity.
# B, Anthropocene plot pairs: response ~ site + burned. The three responses
# (lag rate, pace effect, direction effect) side by side for each term, with
# conditional 95% intervals on one x scale. Estimates whose interval includes
# zero are faded.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

dir = 'community_predictor_models'
coefficients = read_csv(out(file.path(dir, 'model_coefficients.csv')), show_col_types = FALSE)
performance = read_csv(out(file.path(dir, 'model_performance.csv')), show_col_types = FALSE)
responses = c(lag_rate = 'Lag rate', pace_effect = 'Pace effect', direction_effect = 'Direction effect')
# Colours of the conceptual figure (Figure 1): mismatch and lag black, pace pink,
# direction blue.
response_colors = c(lag_rate = 'grey10', pace_effect = '#C27B93', direction_effect = '#6AB2E4')
term_labels = c(siteNOCA = 'Site\nNOCA − MORA', climate_rate = 'Climate change rate',
  fire_activity = 'Fire activity', burnedBurned = 'Burned − unburned')
# One x scale for both eras, so that Holocene and Anthropocene effects compare directly.
shown_terms = c('siteNOCA', 'climate_rate', 'fire_activity', 'burnedBurned')
x_limits = range(coefficients |> filter(term %in% shown_terms) |> select(conf_low, conf_high)) * 1.05

panel = function(era_name, terms, tag) {
  d = coefficients |> filter(era == era_name, term %in% terms) |>
    mutate(response = factor(metric, levels = names(responses)),
      y = match(term, rev(terms)) + c(.22, 0, -.22)[as.integer(response)],
      faded = conf_low <= 0 & conf_high >= 0)
  r2 = performance |> filter(era == era_name) |> arrange(match(response, names(responses)))
  ggplot(d, aes(estimate, y, color = response)) +
    geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed', linewidth = .6) +
    geom_errorbar(aes(xmin = conf_low, xmax = conf_high, alpha = faded), orientation = 'y', width = .12, linewidth = 1.3) +
    geom_point(aes(alpha = faded), size = 3.8) +
    scale_y_continuous(breaks = seq_along(terms), labels = unname(term_labels[rev(terms)]),
      limits = c(.5, length(terms) + .5), expand = expansion(0)) +
    scale_color_manual(values = response_colors, labels = responses, name = NULL,
      guide = guide_legend(override.aes = list(alpha = 1, size = 4.5, linewidth = 1.3))) +
    scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = .35), guide = 'none') +
    coord_cartesian(xlim = x_limits) +
    labs(tag = tag, title = era_name, x = 'Effect on response\n(CCA distance per century)', y = NULL,
      caption = paste0('Descriptive R²: ', paste(sprintf('%s %.3f', tolower(responses[r2$response]), r2$R2), collapse = ', '), '.')) +
    theme_paleoaces(base_size = 20) +
    theme(plot.title = element_text(size = 25, face = 'bold'), plot.tag = element_text(size = 27, face = 'bold'),
      axis.text.y = element_text(size = 19, color = 'grey15', lineheight = .9), axis.text.x = element_text(size = 18),
      axis.title.x = element_text(size = 19), panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
      legend.position = 'bottom', legend.text = element_text(size = 19),
      plot.caption = element_text(size = 16, hjust = 0), plot.caption.position = 'plot')
}
figure = (panel('Holocene', c('siteNOCA', 'climate_rate', 'fire_activity'), 'A.') |
  panel('Anthropocene', c('siteNOCA', 'burnedBurned'), 'B.')) + plot_layout(guides = 'collect') &
  theme(legend.position = 'bottom')
if (render_figures) {
  # cairo_pdf draws the minus signs of the term labels, which the default pdf device cannot.
  ggsave(fig('main', 'fig_climate_fire_associations.pdf'), figure, width = 20, height = 10, device = cairo_pdf, bg = 'white')
  ggsave(fig('main', 'fig_climate_fire_associations.png'), figure, width = 20, height = 10, dpi = 300, bg = 'white')
}
cat('Figure 6: model slopes drawn on one x scale.\n')
