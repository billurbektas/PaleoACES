# Figs. S19 and S20 (Appendix S4, Bills, 11 Nov 2026): the three paleoclimates
# of the analysis compared. The main run corrects TraCE21k onto CHELSA V2.1 in two
# steps (TraCE21k to CHELSAcruts to V2.1), the sensitivity runs in one step
# (CHELSAcruts to V2.1) or not at all (raw). Both figures read the comparison
# written by R/sensitivity_paleoclimate.R.
# Fig. S19: every Holocene lake-period the three runs share (same lake, period
# type and ends), with the raw paleoclimate on x and the two corrected ones on y,
# each with its least-squares line, for the era responses the paleoclimate
# enters. Rows: climate change, lag, pace effect, direction effect; left the total
# over the lake-period, right the rate per century. On the dashed 1:1 line a
# correction changes nothing; in the shaded quadrants the value changes sign.
# Each panel gives the Pearson r of each corrected run with the raw one, per park.
# Turnover and displacement use only the observed positions and are the same in
# all runs, so they are not drawn.
# Fig. S20: the Holocene explanatory-model slopes of Figure 7A and C in the three runs.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

comparison_dir = here('output_paleoclimate_sensitivity', 'comparison')
if (!file.exists(file.path(comparison_dir, 'lake_period_responses.csv'))) {
  cat('Figs. S19 and S20 skipped: run Rscript R/sensitivity_paleoclimate.R first.\n')
} else {
  # The minus sign rather than the hyphen in printed numbers (cairo_pdf draws it).
  signed = function(x, digits) sub('^-', '−', formatC(x, format = 'f', digits = digits))
  run_labels = c(two_step = 'Two-step correction (main run)', one_step = 'One-step correction', raw = 'Raw paleoclimate')
  # The colours of Fig. S8: both steps red, step 2 alone grey.
  run_colors = c(two_step = '#C0392B', one_step = 'grey45')

  # Fig. S19 -------------------------------------------------------------------------
  d = read_csv(file.path(comparison_dir, 'lake_period_responses.csv'), show_col_types = FALSE) |>
    pivot_longer(c(two_step, one_step), names_to = 'run', values_to = 'corrected') |>
    # Pace and direction effects are undefined where a position did not move.
    filter(is.finite(raw), is.finite(corrected)) |>
    mutate(run = factor(run, names(run_colors)), site = factor(site, c('MORA', 'NOCA')))
  correlations = read_csv(file.path(comparison_dir, 'lake_period_correlations.csv'), show_col_types = FALSE)
  labels = c(climate_change = 'Climate change', climate_rate = 'Climate change rate', lag = 'Lag',
    lag_rate = 'Lag per century', pace_effect_total = 'Pace effect', pace_effect = 'Pace effect per century',
    direction_effect_total = 'Direction effect', direction_effect = 'Direction effect per century')
  panel = function(r, tag) {
    x = filter(d, response == r)
    # One square range per panel, around zero and every point of the three runs.
    lim = range(c(0, x$raw, x$corrected)); lim = lim + c(-1, 1) * .06 * diff(lim)
    flips = tibble(xmin = c(lim[1], 0), xmax = c(0, lim[2]), ymin = c(0, lim[1]), ymax = c(lim[2], 0))
    # r of each corrected run with the raw one, per park, in the top-left corner.
    r_labels = correlations |> filter(response == .env$r) |>
      mutate(run = factor(run, names(run_colors))) |> arrange(run, site) |> group_by(run) |>
      summarise(label = paste0(c(two_step = 'Two-step', one_step = 'One-step')[as.character(first(run))], ': ',
        paste(sprintf('%s r = %s', site, signed(r, 2)), collapse = ', ')), .groups = 'drop') |>
      mutate(raw = lim[1] + .03 * diff(lim), corrected = lim[2] - (.03 + .085 * (as.integer(run) - 1)) * diff(lim))
    ggplot(x, aes(raw, corrected, color = run, fill = run)) +
      geom_rect(data = flips, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), inherit.aes = FALSE,
        fill = 'grey93') +
      geom_hline(yintercept = 0, color = 'grey70') + geom_vline(xintercept = 0, color = 'grey70') +
      geom_abline(slope = 1, intercept = 0, linetype = 'dashed', color = 'grey40') +
      geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, linewidth = 1.2) +
      geom_point(aes(shape = site), size = 4, color = 'grey15', stroke = .5, alpha = .85) +
      geom_label(data = r_labels, aes(label = label, color = run), hjust = 0, vjust = 1, size = 5.4,
        fontface = 'bold', fill = alpha('white', .85), linewidth = 0, label.padding = unit(.12, 'lines'),
        show.legend = FALSE) +
      scale_color_manual(values = run_colors, labels = run_labels, name = NULL) +
      scale_fill_manual(values = run_colors, labels = run_labels, name = NULL,
        guide = guide_legend(override.aes = list(shape = 21, size = 5.5, linetype = 0), order = 1)) +
      scale_shape_manual(values = PAPER_SITE_SHAPES, name = NULL,
        guide = guide_legend(override.aes = list(fill = 'grey60', size = 5.5), order = 2)) +
      guides(color = 'none') +
      coord_equal(xlim = lim, ylim = lim, expand = FALSE) +
      labs(tag = tag, x = paste(labels[[r]], 'with raw paleoclimate'),
        y = paste(labels[[r]], 'with corrected\npaleoclimate')) +
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
    ggsave(fig('supplementary', 'figS19_paleoclimate_lake_periods.pdf'), figure, width = 14, height = 25,
      device = cairo_pdf)
  }
  cat('Fig. S19: lake-periods with the corrected against the raw paleoclimate drawn.\n')

  # Fig. S20 -------------------------------------------------------------------------
  slopes = read_csv(file.path(comparison_dir, 'explanatory_slopes.csv'), show_col_types = FALSE) |>
    pivot_longer(-c(response, term), names_to = c('.value', 'run'), names_pattern = '(.*)_(two_step|one_step|raw)$') |>
    mutate(run = factor(run, names(run_labels)))
  # Rows, responses, term labels and colours as in Figure 7 (lag black, pace pink,
  # direction blue): not divided by time on top, per century below.
  slope_rows = list(rate = c(lag_rate = 'lag', pace_effect = 'pace', direction_effect = 'direction'),
    total = c(lag = 'lag', pace_effect_total = 'pace', direction_effect_total = 'direction'))
  slope_terms = list(rate = c('siteNOCA', 'climate_rate', 'fire_activity'),
    total = c('siteNOCA', 'climate_change', 'fire_activity'))
  quantity_labels = c(lag = 'Lag', pace = 'Pace effect', direction = 'Direction effect')
  quantity_colors = c(lag = 'grey10', pace = '#C27B93', direction = '#6AB2E4')
  term_labels = c(siteNOCA = 'Site\nNOCA − MORA', climate_rate = 'Climate change rate',
    climate_change = 'Climate change', fire_activity = 'Fire activity')
  # Rule: every slope of Figure 7A and C is drawn in all three runs.
  stopifnot(nrow(slopes) == 3 * sum(lengths(slope_rows) * lengths(slope_terms)))
  slope_panel = function(version, tag, title) {
    responses = slope_rows[[version]]; terms = slope_terms[[version]]
    x = slopes |> filter(response %in% names(responses), term %in% terms) |>
      mutate(quantity = factor(responses[response], levels = names(quantity_labels)),
        y = match(term, rev(terms)) + c(.22, 0, -.22)[as.integer(run)])
    ggplot(x, aes(estimate, y, color = quantity)) +
      geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed', linewidth = .6) +
      geom_errorbar(aes(xmin = conf_low, xmax = conf_high, linetype = run), orientation = 'y', width = .1,
        linewidth = 1.2) +
      geom_point(aes(shape = run), fill = 'white', size = 4.6, stroke = 1.5) +
      facet_wrap(~quantity, nrow = 1, labeller = as_labeller(quantity_labels)) +
      scale_y_continuous(breaks = seq_along(terms), labels = unname(term_labels[rev(terms)]),
        limits = c(.5, length(terms) + .5), expand = expansion(0)) +
      scale_color_manual(values = quantity_colors, guide = 'none') +
      # Main run filled and solid, one-step open and dashed, raw open triangles and
      # dotted. Same name and labels, so the scales share one legend.
      scale_shape_manual(values = c(two_step = 19, one_step = 21, raw = 24), labels = run_labels, name = NULL) +
      scale_linetype_manual(values = c(two_step = 'solid', one_step = '22', raw = '11'), labels = run_labels, name = NULL,
        guide = guide_legend(override.aes = list(color = 'grey10', linewidth = 1.2))) +
      labs(tag = tag, title = title, x = 'Effect on response', y = NULL) +
      theme_paleoaces(base_size = 22) +
      theme(plot.title = element_text(size = 26, face = 'bold'), plot.tag = element_text(size = 28, face = 'bold'),
        strip.text = element_text(size = 23, face = 'bold'), axis.text.y = element_text(size = 21, color = 'grey15',
          lineheight = .9), panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        panel.spacing.x = unit(1.2, 'cm'), legend.position = 'bottom', legend.text = element_text(size = 22),
        legend.key.width = unit(1.6, 'cm'))
  }
  slope_figure = slope_panel('total', 'A.', 'Not divided by time') / slope_panel('rate', 'B.', 'Per century') +
    plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
  if (render_figures) {
    ggsave(fig('supplementary', 'figS20_paleoclimate_slopes.pdf'), slope_figure, width = 21, height = 17,
      device = cairo_pdf)
  }
  cat('Fig. S20: Holocene explanatory slopes in the three runs drawn.\n')
}
