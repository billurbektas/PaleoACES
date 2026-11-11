# Figs. S16 and S17 (Appendix S3, Bills, 11 Nov 2026): raw against bias-corrected paleoclimate.
# Both read the comparison written by R/sensitivity_bias_corrected.R.
# Fig. S16: every Holocene lake-period with the raw paleoclimate (x) against the
# bias-corrected paleoclimate (y), for the era responses that the correction can
# change. Rows: climate change, lag, pace effect, direction effect; left the
# total over the lake-period, right the rate per century. On the dashed 1:1 line
# the correction changes nothing; in the shaded quadrants the value changes
# sign. Each panel gives the Pearson r between the runs in each park. Turnover
# and displacement use only the observed positions and are the same in both
# runs, so they are not drawn.
# Fig. S17: the Holocene explanatory-model slopes of Figure 7A and C with the
# raw and the bias-corrected paleoclimate side by side.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

comparison_dir = here('output_bias_corrected', 'comparison')
comparison = file.path(comparison_dir, 'lake_period_responses_raw_vs_corrected.csv')
if (!file.exists(comparison)) {
  cat('Figs. S16 and S17 skipped: run Rscript R/sensitivity_bias_corrected.R first.\n')
} else {
  # The minus sign rather than the hyphen in printed numbers (cairo_pdf draws it).
  signed = function(x, digits) sub('^-', '−', formatC(x, format = 'f', digits = digits))

  # Fig. S16 -------------------------------------------------------------------------
  d = read_csv(comparison, show_col_types = FALSE) |>
    # Pace and direction effects are undefined where a position did not move.
    filter(is.finite(raw), is.finite(corrected)) |>
    mutate(period_type = factor(period_type, levels = c('Holocene-S', 'Holocene-C')))
  correlations = read_csv(file.path(comparison_dir, 'lake_period_correlations_raw_vs_corrected.csv'),
    show_col_types = FALSE)
  labels = c(climate_change = 'Climate change', climate_rate = 'Climate change rate', lag = 'Lag',
    lag_rate = 'Lag rate', pace_effect_total = 'Pace effect', pace_effect = 'Pace effect rate',
    direction_effect_total = 'Direction effect', direction_effect = 'Direction effect rate')
  panel = function(r, tag) {
    x = filter(d, response == r)
    # One square range per panel, around zero and every point of both runs.
    lim = range(c(0, x$raw, x$corrected)); lim = lim + c(-1, 1) * .06 * diff(lim)
    flips = tibble(xmin = c(lim[1], 0), xmax = c(0, lim[2]), ymin = c(0, lim[1]), ymax = c(lim[2], 0))
    # The r of each park in the top-left corner, MORA above NOCA, in the park colour.
    r_labels = correlations |> filter(response == .env$r) |> arrange(site) |>
      mutate(label = paste0(site, '  r = ', signed(r, 2)), raw = lim[1] + .03 * diff(lim),
        corrected = lim[2] - (.03 + .085 * (row_number() - 1)) * diff(lim))
    ggplot(x, aes(raw, corrected)) +
      geom_rect(data = flips, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), inherit.aes = FALSE,
        fill = 'grey93') +
      geom_hline(yintercept = 0, color = 'grey70') + geom_vline(xintercept = 0, color = 'grey70') +
      geom_abline(slope = 1, intercept = 0, linetype = 'dashed', color = 'grey40') +
      geom_point(aes(fill = site, shape = period_type), size = 4.6, color = 'grey15', stroke = .6, alpha = .9) +
      geom_label(data = r_labels, aes(label = label, color = site), hjust = 0, vjust = 1, size = 6.3,
        fontface = 'bold', fill = alpha('white', .85), linewidth = 0, label.padding = unit(.12, 'lines'),
        show.legend = FALSE) +
      scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
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

  # Fig. S17 -------------------------------------------------------------------------
  slopes = read_csv(file.path(comparison_dir, 'explanatory_slopes_raw_vs_corrected.csv'), show_col_types = FALSE) |>
    pivot_longer(-c(response, term), names_to = c('.value', 'run'), names_pattern = '(.*)_(raw|corrected)$') |>
    mutate(run = factor(run, levels = c('raw', 'corrected')))
  # Rows, responses, term labels and colours as in Figure 7 (lag black, pace pink,
  # direction blue).
  slope_rows = list(rate = c(lag_rate = 'lag', pace_effect = 'pace', direction_effect = 'direction'),
    total = c(lag = 'lag', pace_effect_total = 'pace', direction_effect_total = 'direction'))
  slope_terms = list(rate = c('siteNOCA', 'climate_rate', 'fire_activity'),
    total = c('siteNOCA', 'climate_change', 'fire_activity'))
  quantity_labels = c(lag = 'Lag', pace = 'Pace effect', direction = 'Direction effect')
  quantity_colors = c(lag = 'grey10', pace = '#C27B93', direction = '#6AB2E4')
  term_labels = c(siteNOCA = 'Site\nNOCA − MORA', climate_rate = 'Climate change rate',
    climate_change = 'Climate change', fire_activity = 'Fire activity')
  run_labels = c(raw = 'Raw paleoclimate', corrected = 'Bias-corrected paleoclimate')
  # Rule: every slope of Figure 7A and C is drawn in both runs.
  stopifnot(nrow(slopes) == 2 * sum(lengths(slope_rows) * lengths(slope_terms)))
  slope_panel = function(version, tag, title) {
    responses = slope_rows[[version]]; terms = slope_terms[[version]]
    x = slopes |> filter(response %in% names(responses), term %in% terms) |>
      mutate(quantity = factor(responses[response], levels = names(quantity_labels)),
        y = match(term, rev(terms)) + c(.14, -.14)[as.integer(run)])
    ggplot(x, aes(estimate, y, color = quantity)) +
      geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed', linewidth = .6) +
      geom_errorbar(aes(xmin = conf_low, xmax = conf_high, linetype = run), orientation = 'y', width = .1,
        linewidth = 1.2) +
      geom_point(aes(shape = run), fill = 'white', size = 5, stroke = 1.6) +
      facet_wrap(~quantity, nrow = 1, labeller = as_labeller(quantity_labels)) +
      scale_y_continuous(breaks = seq_along(terms), labels = unname(term_labels[rev(terms)]),
        limits = c(.5, length(terms) + .5), expand = expansion(0)) +
      scale_color_manual(values = quantity_colors, guide = 'none') +
      # Raw filled and solid, corrected open and dashed. Same name and labels, so
      # the two scales share one legend with the point drawn over the line.
      scale_shape_manual(values = c(raw = 19, corrected = 21), labels = run_labels, name = NULL) +
      scale_linetype_manual(values = c(raw = 'solid', corrected = '22'), labels = run_labels, name = NULL,
        guide = guide_legend(override.aes = list(color = 'grey10', linewidth = 1.2))) +
      labs(tag = tag, title = title, x = 'Effect on response', y = NULL) +
      theme_paleoaces(base_size = 22) +
      theme(plot.title = element_text(size = 26, face = 'bold'), plot.tag = element_text(size = 28, face = 'bold'),
        strip.text = element_text(size = 23, face = 'bold'), axis.text.y = element_text(size = 21, color = 'grey15',
          lineheight = .9), panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        panel.spacing.x = unit(1.2, 'cm'), legend.position = 'bottom', legend.text = element_text(size = 22),
        legend.key.width = unit(1.6, 'cm'))
  }
  slope_figure = slope_panel('rate', 'A.', 'Per century') / slope_panel('total', 'B.', 'Not divided by time') +
    plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
  if (render_figures) {
    ggsave(fig('supplementary', 'figS17_bias_correction_slopes.pdf'), slope_figure, width = 21, height = 15,
      device = cairo_pdf)
  }
  cat('Fig. S17: Holocene explanatory slopes in both runs drawn.\n')
}
