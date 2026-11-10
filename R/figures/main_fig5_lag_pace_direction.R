# Figure 5 (PLAN.md section 6; redrawn by Bills, 10 Nov 2026): the pace effect
# (A) and the direction effect (B) as in Figure 4, fitted means and 95%
# intervals of the three period types per park from the Step 5a models, with
# connectors from the Anthropocene to each Holocene period type and a star
# where that contrast is significant. The lag rate is no longer shown here; it
# is panel D of Figure 4. Panels drawn by R/helpers/era_means_figure.R.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/era_means_figure.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Each effect is the lag at t2 minus the lag had the community moved at the
# predicted pace (A) or in the predicted direction (B). Positive: its own pace
# or direction widened the lag. Negative: it narrowed the lag. The second title
# line says so, with arrows along the axis (Bills, 10 Nov 2026).
sign_words = '\u2190 narrows the lag      widens the lag \u2192'
data = era_means_data(c(pace_effect = paste0(RESPONSE_AXIS_LABELS[['pace_effect']], '\n', sign_words),
  direction_effect = paste0(RESPONSE_AXIS_LABELS[['direction_effect']], '\n', sign_words)))
# Both panels on one y scale, so the two effects compare directly (Bills,
# 10 Nov 2026): from the lowest interval end to the highest connector star.
shared_y = range(data$means$conf_low, data$means$conf_high, data$connectors$y)
shared_y[2] = shared_y[2] + .04 * diff(shared_y)
figure = (era_means_panel('pace_effect', 'A.', data) | era_means_panel('direction_effect', 'B.', data)) +
  plot_layout(guides = 'collect') & coord_cartesian(ylim = shared_y) & theme(legend.position = 'bottom')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_lag_pace_direction.', ext)), figure, width = 18, height = 7.5, dpi = 300,
    device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Figure 5: pace and direction by era drawn.\n')
