# Figure 5 and Fig. S16 (PLAN.md section 6; Bills, 23 Nov 2026): fitted means
# and 95% intervals of the three period types per park from the Step 5a
# models. The main text keeps the rates per century only (Figure 5) and the
# appendix the same quantities not divided by time (Fig. S16), in one layout:
# the climate change and the observed community turnover in the first row,
# the climate-community lag, the pace contribution and the direction contribution in the
# second. Until 23 Nov 2026 Figure 5 held the climate change, turnover and lag
# as total and rate side by side, and Figure 6 the pace and direction contributions.
# The climate change and turnover rates are on log axes with the Holocene-C
# fold, the others on linear axes with connectors for the three differences
# between period types of each park. Panels drawn by R/helpers/era_means_figure.R.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/era_means_figure.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# The pace and direction contributions are the lag at t2 minus the lag had the
# community moved at the predicted pace or in the predicted direction.
# Positive: its own pace or direction widened the lag. Negative: it narrowed
# the lag. The last title line says so, with arrows along the axis (Bills,
# 10 Nov 2026). Axis titles named by Bills (23 Nov 2026): the unit on the
# second line in the first row, on the title line in the second row, which
# leaves more width to the panels.
sign_words = '← narrows the lag      widens the lag →'
rate_titles = c(climate_rate = 'Climate change\n(per century, log scale)',
  turnover_rate = 'Observed community turnover\n(per century, log scale)',
  lag_rate = 'Climate-community lag (per century)',
  pace_effect = paste0('Pace contribution (per century)\n', sign_words),
  direction_effect = paste0('Direction contribution (per century)\n', sign_words))
total_titles = c(climate_change = 'Climate change\n(not divided by time)',
  displacement = 'Observed community turnover\n(not divided by time)',
  lag = 'Climate-community lag (not divided by time)',
  pace_effect_total = paste0('Pace contribution (not divided by time)\n', sign_words),
  direction_effect_total = paste0('Direction contribution (not divided by time)\n', sign_words))

# The pace and direction panels of a figure share one y scale, from the lowest
# interval end to the highest connector star, so the two compare directly
# (Bills, 11 Nov 2026, when their totals and rates shared one scale in Figure 6).
y_range = function(data, responses) {
  y = range(dplyr::filter(data$means, response %in% responses)[c('conf_low', 'conf_high')],
    dplyr::filter(data$connectors, response %in% responses)$y)
  y + c(0, .04 * diff(y))
}

# Text and spacing as in Figures 5 and 6 until 23 Nov 2026 (Bills: font sizes
# never smaller). Axis text by kt, value labels by kl. The figure is three
# panels wide, so it is drawn as narrow as the value labels allow (they must
# clear the next interval), which keeps the text as large as possible on the
# page. The legend sits below the figure (Bills, 23 Nov 2026).
# Fig. S16 is 2 inches taller, so that its longer one-line titles fit the panels.
FIG5_WIDTH = 35; FIG5_HEIGHT = 21
era_figure = function(titles, log_responses, pace_direction) {
  data = era_means_data(titles, log_responses = log_responses)
  y_pd = y_range(data, pace_direction)
  panel = function(r, tag) {
    p = era_means_panel(r, tag, data, k = 1.2, kl = 1.65, kt = 1.4, gap = .05, cap = .05,
      spread = 1.4, park_gap = 1.35, xmin = .45, xmax = 3.32)
    if (r %in% pace_direction) p + coord_cartesian(ylim = y_pd) else p
  }
  r = names(titles)
  # A and B centred over C to E (Bills, 23 Nov 2026). Each row is laid out on
  # its own, so that the axis titles of one row do not change the panel widths
  # of the other, and the lower panels are equally wide.
  top = plot_spacer() + panel(r[1], 'A.') + panel(r[2], 'B.') + plot_spacer() +
    plot_layout(widths = c(.5, 1, 1, .5))
  bottom = panel(r[3], 'C.') + panel(r[4], 'D.') + panel(r[5], 'E.')
  (top / bottom) + plot_layout(guides = 'collect') &
    theme(legend.position = 'bottom', legend.direction = 'horizontal',
      axis.text.x = element_text(size = 38, color = 'grey10'), axis.text.y = element_text(size = 30))
}
rates = era_figure(rate_titles, c('climate_rate', 'turnover_rate'), c('pace_effect', 'direction_effect'))
totals = era_figure(total_titles, character(), c('pace_effect_total', 'direction_effect_total'))
if (render_figures) {
  for (ext in c('pdf', 'png'))
    ggsave(fig('main', paste0('fig_era_contrasts.', ext)), rates, width = FIG5_WIDTH, height = FIG5_HEIGHT, dpi = 300,
      device = if (ext == 'pdf') cairo_pdf else NULL)
  ggsave(fig('supplementary', 'figS16_era_totals.pdf'), totals, width = FIG5_WIDTH, height = FIG5_HEIGHT + 2,
    device = cairo_pdf)
}
cat('Figure 5 (rates per century) and Fig. S16 (not divided by time): era means drawn.\n')
