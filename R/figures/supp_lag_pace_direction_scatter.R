# Appendix figure A4 (Bills, 10 Nov 2026): lag rate against the pace effect
# and the direction effect, for the Holocene lake-periods (top row) and the
# Anthropocene plot pairs (bottom row), with Pearson r per park.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE) |>
  mutate(era = if_else(period_type == 'Anthropocene', 'Anthropocene', 'Holocene'),
    period_type = factor(period_type, levels = names(PERIOD_TYPE_SHAPES))) |>
  pivot_longer(c(pace_effect, direction_effect), names_to = 'effect', values_to = 'value') |>
  filter(is.finite(value), is.finite(lag_rate))
correlations = both |> group_by(era, effect, site) |>
  summarise(n = n(), r = cor(lag_rate, value), .groups = 'drop')
write_csv(correlations, out('figures/lag_pace_direction_correlations.csv'))

panel = function(era_name, effect_name, tag) {
  d = both |> filter(era == era_name, effect == effect_name)
  r = correlations |> filter(era == era_name, effect == effect_name) |>
    arrange(site) |> mutate(label = sprintf('%s r = %.2f', site, r))
  ggplot(d, aes(lag_rate, value)) +
    geom_hline(yintercept = 0, color = 'grey65', linetype = 'dashed') +
    geom_vline(xintercept = 0, color = 'grey65', linetype = 'dashed') +
    # 1:1 line: a correction equal to the whole lag.
    geom_abline(slope = 1, intercept = 0, color = 'grey40', linewidth = .6) +
    geom_point(aes(fill = site, shape = period_type), size = if (era_name == 'Holocene') 4.2 else 2.4,
      alpha = if (era_name == 'Holocene') .9 else .55, color = 'grey20', stroke = .4) +
    # Invisible points of every period type and park, so every panel draws the
    # same legend keys and patchwork collects a single legend.
    geom_point(data = expand_grid(period_type = factor(names(PERIOD_TYPE_SHAPES), levels = names(PERIOD_TYPE_SHAPES)),
        site = c('MORA', 'NOCA')) |> mutate(lag_rate = median(d$lag_rate), value = median(d$value)),
      aes(fill = site, shape = period_type), alpha = 0) +
    annotate('text', x = -Inf, y = Inf, label = paste(r$label, collapse = '\n'), hjust = -.08, vjust = 1.3,
      size = 6, color = 'grey15', lineheight = 1) +
    scale_fill_manual(values = PAPER_SITE_COLORS, name = NULL) +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, name = NULL, drop = FALSE,
      labels = c(`Holocene-C` = 'Holocene climate-change period', `Holocene-S` = 'Holocene stability period',
        Anthropocene = 'Anthropocene plot pair')) +
    # Identical legend keys in every panel, so patchwork collects one legend.
    guides(fill = guide_legend(override.aes = list(shape = 21, size = 5, alpha = 1)),
      # One period-type legend for the whole figure, drawn from the bottom row.
      shape = if (era_name == 'Holocene') 'none' else guide_legend(override.aes = list(fill = 'grey60', size = 5, alpha = 1))) +
    labs(tag = tag, title = era_name, x = 'Lag rate', y = RESPONSE_AXIS_LABELS[[effect_name]]) +
    theme_paleoaces(base_size = 22) + theme(plot.title = element_text(size = 22, face = 'bold'))
}
figure = (panel('Holocene', 'pace_effect', 'A.') | panel('Holocene', 'direction_effect', 'B.')) /
  (panel('Anthropocene', 'pace_effect', 'C.') | panel('Anthropocene', 'direction_effect', 'D.')) +
  plot_layout(guides = 'collect') & theme(legend.position = 'bottom', legend.box = 'vertical')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('supplementary', paste0('fig_lag_pace_direction_scatter.', ext)), figure, width = 15, height = 15, dpi = 300)
cat('Appendix figure A4: lag rate against pace and direction drawn.\n')
