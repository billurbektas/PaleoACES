# The three figures that Appendices S4 and S5 share (Bills, 25 Nov 2026): the era
# means of Figure 5, the model slopes of Figure 6 and the species contributions of
# Figure 7, with every version of the analysis in the same panels, one colour and
# symbol per version and the parks in facets. Appendix S4 compares the correction of the Holocene climate
# (R/figures/supp_paleoclimate_sensitivity.R), Appendix S5 the Anthropocene climate
# products (R/figures/supp_climate_product_sensitivity.R). The data carry a factor
# `version` whose levels are the names of `labels`, `colors` and `shapes`; `labels`
# holds only the versions drawn. Needs tidyverse, patchwork and figure_style.R.

sensitivity_theme = function(base_size = 17) theme_paleoaces(base_size) +
  theme(legend.position = 'bottom', legend.text = element_text(size = base_size), legend.key.width = unit(1.2, 'cm'))

sensitivity_scales = function(labels, colors, shapes, aesthetics = c('colour', 'fill', 'shape')) {
  versions = names(labels); labels = unname(labels)
  list(colour = scale_color_manual(values = colors, labels = labels, breaks = versions, name = NULL, drop = FALSE),
    fill = scale_fill_manual(values = colors, labels = labels, breaks = versions, name = NULL, drop = FALSE),
    shape = scale_shape_manual(values = shapes, labels = labels, breaks = versions, name = NULL, drop = FALSE))[aesthetics]
}

# Figure 5: the fitted means of its responses with their 95% intervals, by period
# type, park and version. Rates of climate change and turnover on log axes, as in Figure 5.
sensitivity_era_means_figure = function(means, labels, colors, shapes) {
  responses = c(climate_rate = 'Climate change (per century, log scale)',
    turnover_rate = 'Observed community turnover (per century, log scale)', lag_rate = 'Climate-community lag (per century)',
    pace_effect = 'Pace contribution (per century)', direction_effect = 'Direction contribution (per century)')
  ticks = c(`Holocene-S` = 'Holocene\nstability', `Holocene-C` = 'Holocene\nclimate change', Anthropocene = 'Anthropocene')
  dodge = position_dodge(width = .55)
  means = means |> filter(response %in% names(responses)) |> mutate(period_type = factor(ticks[period_type], ticks))
  panel = function(r, tag) {
    x = filter(means, response == r)
    # On the log axes an interval that reaches zero or below is cut at the axis floor.
    if (r %in% c('climate_rate', 'turnover_rate')) {
      floor = min(c(x$estimate, x$conf_low[x$conf_low > 0])) / 3
      x = x |> mutate(conf_low = pmax(conf_low, floor))
    }
    p = ggplot(x, aes(period_type, estimate, color = version, fill = version, shape = version)) +
      geom_errorbar(aes(ymin = conf_low, ymax = conf_high), position = dodge, width = .3, linewidth = .9) +
      geom_point(position = dodge, size = 3.8, color = 'grey15', stroke = .5) +
      facet_grid(. ~ site) + sensitivity_scales(labels, colors, shapes) +
      labs(x = NULL, y = NULL, title = responses[[r]], tag = tag) +
      sensitivity_theme(16) + theme(plot.title = element_text(size = 17, face = 'bold'))
    if (r %in% c('climate_rate', 'turnover_rate')) p + scale_y_log10() else
      p + geom_hline(yintercept = 0, color = 'grey55', linetype = 'dashed')
  }
  wrap_plots(imap(names(responses), \(r, i) panel(r, LETTERS[i])), ncol = 1) +
    plot_layout(guides = 'collect') & theme(legend.position = 'bottom')
}

# Figure 6: the slopes of its models (responses per century), estimate and 95%
# interval per version, faded where the interval includes zero.
sensitivity_slopes_figure = function(slopes, labels, colors, shapes) {
  quantities = c(lag_rate = 'Lag', pace_effect = 'Pace contribution', direction_effect = 'Direction contribution')
  terms = c(`Holocene.siteNOCA` = 'Holocene\nsite NOCA − MORA', `Holocene.climate_rate` = 'Holocene\nclimate change rate',
    `Holocene.fire_activity` = 'Holocene\nfire activity', `Anthropocene.siteNOCA` = 'Anthropocene\nsite NOCA − MORA',
    `Anthropocene.burnedBurned` = 'Anthropocene\nburned − unburned')
  slopes = slopes |> mutate(key = paste(era, term, sep = '.')) |>
    filter(metric %in% names(quantities), key %in% names(terms)) |>
    mutate(quantity = factor(quantities[metric], quantities), term = factor(terms[key], terms),
      faded = conf_low <= 0 & conf_high >= 0)
  ggplot(slopes, aes(estimate, fct_rev(version), color = version, fill = version, shape = version)) +
    geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed') +
    geom_errorbar(aes(xmin = conf_low, xmax = conf_high, alpha = faded), orientation = 'y', width = .3, linewidth = 1) +
    geom_point(aes(alpha = faded), size = 3.8, color = 'grey15', stroke = .5) +
    facet_grid(term ~ quantity, scales = 'free_x', switch = 'y') + sensitivity_scales(labels, colors, shapes) +
    scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = .35), guide = 'none') +
    labs(x = 'Effect on response (per century)', y = NULL) + sensitivity_theme(16) +
    theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), strip.placement = 'outside',
      strip.text.y.left = element_text(angle = 0, hjust = 1))
}

# Figure 7: the species contributions in the climate-predicted direction (per
# century), means and 95% intervals per version, faded where the interval includes
# zero. Species in the order of Figure 7 (highest elevation first), read from the
# main run; species absent from a park and period type left out.
sensitivity_species_figure = function(means, labels, colors, shapes) {
  types = c(`Holocene-S` = 'Holocene stability', `Holocene-C` = 'Holocene climate change', Anthropocene = 'Anthropocene')
  order_file = out('figures/species_order_elevation.csv')
  order_species = if (file.exists(order_file)) read_csv(order_file, show_col_types = FALSE) |>
    arrange(desc(max_elevation), desc(mean_elevation)) |> pull(species) else sort(unique(means$species))
  means = means |> filter(present, interval_defined | n == 1) |>
    mutate(species = factor(species, rev(order_species)), period_type = factor(types[period_type], types),
      faded = !interval_defined | (conf_low <= 0 & conf_high >= 0))
  dodge_y = position_dodge(width = .7)
  ggplot(means, aes(estimate, species, color = version, fill = version, shape = version, group = fct_rev(version))) +
    geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed') +
    geom_errorbar(aes(xmin = conf_low, xmax = conf_high, alpha = faded), orientation = 'y', position = dodge_y,
      width = .5, linewidth = .8) +
    geom_point(aes(alpha = faded), position = dodge_y, size = 3, color = 'grey15', stroke = .4) +
    facet_grid(period_type ~ site, scales = 'free', space = 'free_y') + sensitivity_scales(labels, colors, shapes) +
    scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = .3), guide = 'none') +
    labs(x = 'Species contribution in the climate-predicted direction (per century)', y = NULL) + sensitivity_theme(16) +
    theme(axis.text.y = element_text(face = 'italic'))
}
