# Figure 5 (PLAN.md section 6): lag rate, pace effect and direction effect by
# era. A, Holocene: per park, Holocene-C and Holocene-S side by side, each
# lake-period a small symbol, the fitted mean and 95% interval a large symbol.
# B, Anthropocene: the plot pairs as points, the fitted mean and 95% interval
# as a diamond. Fitted means come from the Step 5a models.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

responses = c('lag_rate', 'pace_effect', 'direction_effect')
both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE) |>
  pivot_longer(all_of(responses), names_to = 'response', values_to = 'value') |> filter(is.finite(value))
means = read_csv(out('era_comparison/era_means.csv'), show_col_types = FALSE) |> filter(response %in% responses)
dodge = position_dodge(width = .5)
holocene_panel = function(r, tag) {
  d = both |> filter(response == r, period_type != 'Anthropocene')
  m = means |> filter(response == r, period_type != 'Anthropocene')
  ggplot(d, aes(site, value, group = period_type)) +
    geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed') +
    geom_point(aes(shape = period_type, fill = site), size = 1.8, alpha = .55, color = 'grey30',
      position = position_jitterdodge(jitter.width = .12, dodge.width = .5, seed = 1)) +
    geom_errorbar(data = m, aes(y = estimate, ymin = conf_low, ymax = conf_high, color = site), width = .1,
      linewidth = .8, position = dodge) +
    geom_point(data = m, aes(y = estimate, shape = period_type, fill = site), size = 4, color = 'grey10', position = dodge) +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, name = NULL, breaks = c('Holocene-C', 'Holocene-S'),
      labels = c('Holocene climate-change periods', 'Holocene stability periods')) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') + scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60', alpha = 1, size = 3.5))) +
    labs(tag = tag, x = NULL, y = str_wrap(RESPONSE_AXIS_LABELS[[r]], 26)) +
    theme_paleoaces(base_size = 12)
}
anthropocene_panel = function(r, tag) {
  d = both |> filter(response == r, period_type == 'Anthropocene')
  m = means |> filter(response == r, period_type == 'Anthropocene')
  ggplot(d, aes(site, value)) +
    geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed') +
    geom_point(aes(color = site), size = .8, alpha = .3, position = position_jitter(width = .18, seed = 1)) +
    geom_errorbar(data = m, aes(y = estimate, ymin = conf_low, ymax = conf_high), width = .12, linewidth = .9, color = 'grey10') +
    geom_point(data = m, aes(y = estimate, fill = site), shape = PERIOD_TYPE_SHAPES[['Anthropocene']], size = 4.2, color = 'grey10') +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') + scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    labs(tag = tag, x = NULL, y = str_wrap(RESPONSE_AXIS_LABELS[[r]], 26)) +
    theme_paleoaces(base_size = 12)
}
top = wrap_plots(holocene_panel('lag_rate', 'A.'), holocene_panel('pace_effect', NULL), holocene_panel('direction_effect', NULL), nrow = 1)
bottom = wrap_plots(anthropocene_panel('lag_rate', 'B.'), anthropocene_panel('pace_effect', NULL),
  anthropocene_panel('direction_effect', NULL), nrow = 1)
figure = (top / bottom) + plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_lag_pace_direction.', ext)), figure, width = 12, height = 9, dpi = 300)
cat('Figure 5: lag, pace and direction by era drawn.\n')
