# Figure 6 (PLAN.md section 6): climate and fire associations. A, Holocene:
# rows lag rate, pace effect, direction effect; columns climate change rate
# and fire activity. Per park the fitted partial-effect line over the park's
# own range with its 95% band, the other predictor at the park's mean, and each
# lake-period as a partial residual (circle C, triangle S). B, Anthropocene:
# MORA unburned, NOCA unburned and NOCA burned plots with fitted means.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

responses = c('lag_rate', 'pace_effect', 'direction_effect')
dir = 'community_predictor_models'
lines = read_csv(out(file.path(dir, 'partial_effects.csv')), show_col_types = FALSE)
residuals = read_csv(out(file.path(dir, 'partial_residuals.csv')), show_col_types = FALSE)
both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE)

holocene_cell = function(r, predictor, tag = NULL) {
  l = lines |> filter(response == r, predictor == .env$predictor)
  p = residuals |> filter(response == r, predictor == .env$predictor)
  ggplot(l, aes(x, fit)) +
    geom_hline(yintercept = 0, color = 'grey70', linetype = 'dashed') +
    geom_ribbon(aes(ymin = conf_low, ymax = conf_high, fill = site), alpha = .18) +
    geom_line(aes(color = site), linewidth = 1) +
    geom_point(data = p, aes(x, partial_residual, shape = period_type, fill = site), size = 2.6, color = 'grey15') +
    scale_color_manual(values = PAPER_SITE_COLORS, name = NULL) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, name = NULL, breaks = c('Holocene-C', 'Holocene-S'),
      labels = c('Holocene climate-change period', 'Holocene stability period')) +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60'))) +
    labs(tag = tag, x = str_wrap(RESPONSE_AXIS_LABELS[[predictor]], 34), y = str_wrap(RESPONSE_AXIS_LABELS[[r]], 26)) +
    theme_paleoaces(base_size = 11)
}
groups = c('MORA unburned', 'NOCA unburned', 'NOCA burned')
anthropocene_cell = function(r, tag = NULL) {
  d = both |> filter(period_type == 'Anthropocene', is.finite(.data[[r]])) |>
    mutate(value = .data[[r]], group = factor(paste(site, if_else(burned, 'burned', 'unburned')), levels = c(groups, 'MORA burned')))
  m = lines |> filter(response == r, predictor == 'burned') |>
    mutate(group = factor(paste(site, tolower(burned)), levels = groups))
  ggplot(d |> filter(group %in% groups), aes(group, value)) +
    geom_hline(yintercept = 0, color = 'grey70', linetype = 'dashed') +
    geom_point(aes(color = site), size = .8, alpha = .3, position = position_jitter(width = .15, seed = 1)) +
    geom_errorbar(data = m, aes(y = fit, ymin = conf_low, ymax = conf_high), width = .12, linewidth = .9, color = 'grey10') +
    # Burned plots: a red-filled diamond (PLAN.md section 6).
    geom_point(data = m, aes(y = fit, fill = if_else(group == 'NOCA burned', 'burned', site)),
      shape = PERIOD_TYPE_SHAPES[['Anthropocene']], size = 4.2, color = 'grey10') +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_fill_manual(values = c(PAPER_SITE_COLORS, burned = PAPER_FIRE_RED), guide = 'none') +
    scale_x_discrete(labels = function(x) sub(' ', '\n', x)) +
    labs(tag = tag, x = NULL, y = str_wrap(RESPONSE_AXIS_LABELS[[r]], 26)) +
    theme_paleoaces(base_size = 11)
}
cells = list()
for (i in seq_along(responses)) {
  r = responses[i]
  cells = c(cells, list(holocene_cell(r, 'climate_rate', if (i == 1) 'A.' else NULL), holocene_cell(r, 'fire_activity'),
    anthropocene_cell(r, if (i == 1) 'B.' else NULL)))
}
figure = wrap_plots(cells, ncol = 3, widths = c(1, 1, .9)) + plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_climate_fire_associations.', ext)), figure, width = 13, height = 11, dpi = 300)
cat('Figure 6: climate and fire associations drawn.\n')
