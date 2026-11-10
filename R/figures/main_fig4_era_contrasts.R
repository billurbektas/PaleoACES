# Figure 4 (PLAN.md section 6; redrawn by Bills, 10 Nov 2026): fitted means
# and 95% intervals of the three period types per park. A climate change rate
# and B observed community turnover on log axes with the Holocene-C fold, C the
# lag and D the lag rate on linear axes with contrast connectors. The panels
# are drawn by R/helpers/era_means_figure.R, shared with Figure 5.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/era_means_figure.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Axis titles for this figure (Bills, 10 Nov 2026).
data = era_means_data(c(climate_rate = 'Climate change rate\n(log scale)',
  turnover_rate = 'Observed community turnover\n(log scale)', lag = 'Community-climate lag',
  lag_rate = 'Community-climate lag rate'), log_responses = c('climate_rate', 'turnover_rate'))
# Two rows: climate and turnover on top, the lag and the lag rate below.
figure = (era_means_panel('climate_rate', 'A.', data) | era_means_panel('turnover_rate', 'B.', data)) /
  (era_means_panel('lag', 'C.', data) | era_means_panel('lag_rate', 'D.', data)) +
  plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_era_contrasts.', ext)), figure, width = 18, height = 13, dpi = 300,
    device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Figure 4: era means drawn.\n')
