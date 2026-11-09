# Figure 4 (PLAN.md section 6): era contrasts for climate change rate, turnover
# rate and lag rate. Per park, Anthropocene minus Holocene-C (circle) and
# Anthropocene minus Holocene-S (triangle) with 95% intervals from the Step 5a
# models. The fold is printed beside the Holocene-C point for climate and turnover.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

contrasts = read_csv(out('era_comparison/era_contrasts.csv'), show_col_types = FALSE) |>
  filter(contrast %in% c('Anthropocene - Holocene-C', 'Anthropocene - Holocene-S')) |>
  mutate(against = sub('Anthropocene - ', '', contrast), site = factor(site, levels = c('MORA', 'NOCA')))
folds = read_csv(out('era_comparison/era_folds.csv'), show_col_types = FALSE)
contrasts = contrasts |> left_join(folds |> select(response, site, against, fold) |> mutate(site = factor(site, levels = c('MORA', 'NOCA'))),
  by = c('response', 'site', 'against'))
dodge = position_dodge(width = .45)
panel = function(r, tag) {
  d = contrasts |> filter(response == r)
  p = ggplot(d, aes(site, estimate, group = against)) +
    geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed') +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high, color = site), width = .12, linewidth = .8, position = dodge) +
    geom_point(aes(shape = against, fill = site), size = 4.6, color = 'grey15', position = dodge) +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES[c('Holocene-C', 'Holocene-S')], name = NULL,
      labels = c(`Holocene-C` = 'Anthropocene minus Holocene climate-change periods',
        `Holocene-S` = 'Anthropocene minus Holocene stability periods')) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    labs(tag = tag, x = NULL, y = two_line_title(paste('Difference in', sub('^(.)', '\\L\\1', RESPONSE_AXIS_LABELS[[r]], perl = TRUE)), 32)) +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60'), ncol = 1)) +
    theme_paleoaces(base_size = 20) + theme(legend.position = 'bottom', legend.text = element_text(size = 19), plot.tag = element_text(size = 24, face = 'bold'))
  if (r %in% c('climate_rate', 'turnover_rate')) p = p +
    # The fold sits just above the circle's interval (the circle is dodged left
    # by a quarter of the dodge width), clear of the points and the panel edge.
    geom_text(data = filter(d, against == 'Holocene-C'),
      aes(x = as.integer(site) - .45 / 4, y = conf_high, label = sprintf('%.0f-fold', fold)),
      vjust = -.7, size = 6, fontface = 'bold', color = 'grey15') +
    scale_y_continuous(expand = expansion(mult = c(.05, .14)))
  p
}
figure = (panel('climate_rate', 'A.') | panel('turnover_rate', 'B.') | panel('lag_rate', 'C.')) +
  plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_era_contrasts.', ext)), figure, width = 15, height = 7.5, dpi = 300)
cat('Figure 4: era contrasts drawn.\n')
