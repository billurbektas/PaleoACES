# Fig. S16 (Appendix S3, Bills, 11 Nov 2026): every Holocene lake-period with
# the raw paleoclimate (x) against the bias-corrected paleoclimate (y), for the
# era responses that the correction can change. Rows: climate change, lag, pace
# effect, direction effect; left the total over the lake-period, right the rate
# per century. On the dashed 1:1 line the correction changes nothing; in the
# shaded quadrants the value changes sign. Turnover and displacement use only
# the observed positions and are the same in both runs, so they are not drawn.
# Reads the comparison written by R/sensitivity_bias_corrected.R.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

comparison = here('output_bias_corrected', 'comparison', 'lake_period_responses_raw_vs_corrected.csv')
if (!file.exists(comparison)) {
  cat('Fig. S16 skipped: run Rscript R/sensitivity_bias_corrected.R first.\n')
} else {
  d = read_csv(comparison, show_col_types = FALSE) |>
    # Pace and direction effects are undefined where a position did not move.
    filter(is.finite(raw), is.finite(corrected)) |>
    mutate(period_type = factor(period_type, levels = c('Holocene-S', 'Holocene-C')))
  labels = c(climate_change = 'Climate change', climate_rate = 'Climate change rate', lag = 'Lag',
    lag_rate = 'Lag rate', pace_effect_total = 'Pace effect', pace_effect = 'Pace effect rate',
    direction_effect_total = 'Direction effect', direction_effect = 'Direction effect rate')
  panel = function(r, tag) {
    x = filter(d, response == r)
    # One square range per panel, around zero and every point of both runs.
    lim = range(c(0, x$raw, x$corrected)); lim = lim + c(-1, 1) * .06 * diff(lim)
    flips = tibble(xmin = c(lim[1], 0), xmax = c(0, lim[2]), ymin = c(0, lim[1]), ymax = c(lim[2], 0))
    ggplot(x, aes(raw, corrected)) +
      geom_rect(data = flips, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), inherit.aes = FALSE,
        fill = 'grey93') +
      geom_hline(yintercept = 0, color = 'grey70') + geom_vline(xintercept = 0, color = 'grey70') +
      geom_abline(slope = 1, intercept = 0, linetype = 'dashed', color = 'grey40') +
      geom_point(aes(fill = site, shape = period_type), size = 4.6, color = 'grey15', stroke = .6, alpha = .9) +
      scale_fill_manual(values = PAPER_SITE_COLORS, name = NULL,
        guide = guide_legend(override.aes = list(shape = 21, size = 5.5), order = 1)) +
      scale_shape_manual(values = PERIOD_TYPE_SHAPES[c('Holocene-S', 'Holocene-C')], drop = FALSE, name = NULL,
        labels = c('Holocene stability periods', 'Holocene climate-change periods'),
        guide = guide_legend(override.aes = list(fill = 'grey60', size = 5.5), order = 2)) +
      coord_equal(xlim = lim, ylim = lim, expand = FALSE) +
      labs(tag = tag, x = paste(labels[[r]], 'with raw paleoclimate'),
        y = paste(labels[[r]], 'with bias-corrected\npaleoclimate')) +
      theme_paleoaces(base_size = 20) +
      theme(panel.grid.minor = element_blank(), plot.tag = element_text(size = 24, face = 'bold'),
        legend.position = 'bottom', legend.text = element_text(size = 19))
  }
  rows = list(c('climate_change', 'climate_rate'), c('lag', 'lag_rate'), c('pace_effect_total', 'pace_effect'),
    c('direction_effect_total', 'direction_effect'))
  tags = paste0(LETTERS[seq_len(2 * length(rows))], '.')
  panels = unlist(lapply(seq_along(rows), function(i) list(panel(rows[[i]][1], tags[2 * i - 1]),
    panel(rows[[i]][2], tags[2 * i]))), recursive = FALSE)
  figure = wrap_plots(panels, ncol = 2) + plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
  if (render_figures) {
    ggsave(fig('supplementary', 'figS16_bias_correction_lake_periods.pdf'), figure, width = 14, height = 25,
      device = cairo_pdf)
  }
  cat('Fig. S16: raw against bias-corrected lake-periods drawn.\n')
}
