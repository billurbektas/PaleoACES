# Figure 5 (PLAN.md section 6; redrawn by Bills, 10 Nov 2026): fitted means
# and 95% intervals of the three period types per park. Three rows, each a
# total between the two ends of a unit (left) and its rate per century
# (right): A and B the climate change, C and D the observed community turnover
# (the displacement), E and F the climate-community lag. The climate change
# and turnover rates are on log axes with the Holocene-C fold, the others on
# linear axes with contrast connectors. The panels are drawn by
# R/helpers/era_means_figure.R, shared with Figure 6.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/era_means_figure.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Axis titles for this figure (Bills, 10 Nov 2026).
data = era_means_data(c(climate_change = 'Climate change', climate_rate = 'Climate change rate\n(log scale)',
  displacement = 'Observed community turnover', turnover_rate = 'Observed community turnover rate\n(log scale)',
  lag = 'Climate-community lag', lag_rate = 'Climate-community lag rate'),
  log_responses = c('climate_rate', 'turnover_rate'))
# Larger text than Figure 6 (Bills): axis text by kt, value labels by kl. The
# period types and the parks are spread further apart and the caps are
# narrower, so the larger labels clear the next interval.
panel = function(r, tag) era_means_panel(r, tag, data, k = 1.2, kl = 1.65, kt = 1.4, gap = .05, cap = .05,
  spread = 1.4, park_gap = 1.35, xmin = .45, xmax = 3.32)
figure = panel('climate_change', 'A.') + panel('climate_rate', 'B.') +
  panel('displacement', 'C.') + panel('turnover_rate', 'D.') +
  panel('lag', 'E.') + panel('lag_rate', 'F.') +
  plot_layout(ncol = 2, guides = 'collect') &
  theme(legend.position = 'bottom', legend.direction = 'horizontal',
    axis.text.x = element_text(size = 38, color = 'grey10'), axis.text.y = element_text(size = 30))
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_era_contrasts.', ext)), figure, width = 26, height = 30, dpi = 300,
    device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Figure 5: era means drawn.\n')
