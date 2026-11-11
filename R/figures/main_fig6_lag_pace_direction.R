# Figure 6 (PLAN.md section 6; redrawn by Bills, 10 Nov 2026): the pace and
# direction effects in the design of Figure 5, fitted means and 95% intervals
# of the three period types per park from the Step 5a models, with connectors
# from the Anthropocene to each Holocene period type and a star where that
# contrast is significant. Two rows, each the effect over the whole unit
# (left, not divided by time) and per century (right): A and B the pace
# effect, C and D the direction effect. Panels drawn by R/helpers/era_means_figure.R.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/era_means_figure.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Each effect is the lag at t2 minus the lag had the community moved at the
# predicted pace (A, B) or in the predicted direction (C, D). Positive: its own
# pace or direction widened the lag. Negative: it narrowed the lag. The second
# title line says so, with arrows along the axis (Bills, 10 Nov 2026).
sign_words = '← narrows the lag      widens the lag →'
titles = c(pace_effect_total = 'Pace effect', pace_effect = 'Pace effect per century',
  direction_effect_total = 'Direction effect', direction_effect = 'Direction effect per century')
data = era_means_data(setNames(paste0(titles, '\n', sign_words), names(titles)))
# All four panels share one y scale (Bills, 11 Nov 2026; until then the totals
# one and the rates per century another), from the lowest interval end to the
# highest connector star, so the effects compare directly.
y_range = function(responses) {
  y = range(dplyr::filter(data$means, response %in% responses)[c('conf_low', 'conf_high')],
    dplyr::filter(data$connectors, response %in% responses)$y)
  y + c(0, .04 * diff(y))
}
y_all = y_range(c('pace_effect_total', 'direction_effect_total', 'pace_effect', 'direction_effect'))
# Text and spacing as in Figure 5 (Bills, 10 Nov 2026).
panel = function(r, tag, ylim) era_means_panel(r, tag, data, k = 1.2, kl = 1.65, kt = 1.4, gap = .05, cap = .05,
  spread = 1.4, park_gap = 1.35, xmin = .45, xmax = 3.32) + coord_cartesian(ylim = ylim)
figure = panel('pace_effect_total', 'A.', y_all) + panel('pace_effect', 'B.', y_all) +
  panel('direction_effect_total', 'C.', y_all) + panel('direction_effect', 'D.', y_all) +
  plot_layout(ncol = 2, guides = 'collect') &
  theme(legend.position = 'bottom', legend.direction = 'horizontal',
    axis.text.x = element_text(size = 38, color = 'grey10'), axis.text.y = element_text(size = 30))
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_lag_pace_direction.', ext)), figure, width = 26, height = 21, dpi = 300,
    device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Figure 6: pace and direction by era drawn.\n')
