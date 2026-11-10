# Figure 4 (PLAN.md section 6; redrawn by Bills, 10 Nov 2026): fitted means
# and 95% intervals of the three period types per park. Top row: A climate
# change rate, B observed community turnover (the displacement, not divided by
# time) and C its rate per century. Bottom row, centred: D the lag and E the
# lag rate. The climate change and turnover rates are on log axes with the
# Holocene-C fold, the others on linear axes with contrast connectors. The
# panels are drawn by R/helpers/era_means_figure.R, shared with Figure 5.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/era_means_figure.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Axis titles for this figure (Bills, 10 Nov 2026).
data = era_means_data(c(climate_rate = 'Climate change rate\n(log scale)',
  displacement = 'Observed community\nturnover', turnover_rate = 'Observed community\nturnover rate (log scale)',
  lag = 'Community-climate lag', lag_rate = 'Community-climate lag rate'),
  log_responses = c('climate_rate', 'turnover_rate'))
# Larger text than Figure 5 (Bills): axis text by kt, value labels by kl. The
# period types and the parks are spread further apart and the caps are
# narrower, so the larger labels clear the next interval.
panel = function(r, tag) era_means_panel(r, tag, data, k = 1.2, kl = 1.65, kt = 1.4, gap = .05, cap = .05,
  spread = 1.4, park_gap = 1.35, xmin = .45, xmax = 3.32)
# Each row is laid out on its own, so the panels of a row line up. The bottom
# row is centred with half-width spacers, giving its panels the width of the top ones.
top = panel('climate_rate', 'A.') + panel('displacement', 'B.') + panel('turnover_rate', 'C.') + plot_layout(nrow = 1)
bottom = plot_spacer() + panel('lag', 'D.') + panel('lag_rate', 'E.') + plot_spacer() +
  plot_layout(nrow = 1, widths = c(.5, 1, 1, .5))
figure = (top / bottom) + plot_layout(guides = 'collect') &
  theme(legend.position = 'bottom', legend.direction = 'horizontal',
    axis.text.x = element_text(size = 38, color = 'grey10'), axis.text.y = element_text(size = 30))
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_era_contrasts.', ext)), figure, width = 36, height = 22, dpi = 300,
    device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Figure 4: era means drawn.\n')
