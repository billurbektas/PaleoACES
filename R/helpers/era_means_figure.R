# Era-means panels shared by Figures 5 and 6 (Bills, 10 Nov 2026): fitted
# means and 95% intervals of the three period types side by side per park,
# from the Step 5a models, each mean printed beside its point in the park
# colour. Rates on log axes carry an arrow with the Holocene-C fold. Signed
# responses on linear axes carry connectors from the Anthropocene to each
# Holocene period type, with a star where that contrast is significant after
# the Holm adjustment.
# Linear-axis responses that are positive (the displacement) carry connectors
# the same way.
# Used by R/figures/main_fig5_era_contrasts.R and R/figures/main_fig6_lag_pace_direction.R.
ERA_TYPES = c('Holocene-S', 'Holocene-C', 'Anthropocene')
ERA_SITES = c('MORA', 'NOCA')
# Period types side by side within each park, stability on the left.
ERA_OFFSET = c(`Holocene-S` = -.32, `Holocene-C` = 0, Anthropocene = .32)
era_minus = function(x) gsub('-', '\u2212', x)
# Responses that are positive by construction, printed without a sign.
ERA_POSITIVE = c('climate_rate', 'climate_change', 'turnover_rate', 'displacement')

# Means, fold arrows and contrast connectors for the responses in `titles`.
era_means_data = function(titles, log_responses = character()) {
  means = readr::read_csv(out('era_comparison/era_means.csv'), show_col_types = FALSE) |>
    dplyr::filter(response %in% names(titles)) |>
    dplyr::mutate(period_type = factor(period_type, levels = ERA_TYPES), site = factor(site, levels = ERA_SITES),
      x = as.integer(site) + ERA_OFFSET[as.character(period_type)],
      # Rates, the climate change and the displacement are positive by construction and printed
      # without sign. Signed responses carry their sign. No stars on means:
      # stars belong to the contrasts (Bills).
      label = dplyr::case_when(
        response %in% c(log_responses, ERA_POSITIVE) & estimate >= 1 ~ sprintf('%.2f', estimate),
        response %in% c(log_responses, ERA_POSITIVE) ~ sprintf('%.3f', estimate),
        abs(estimate) < 5e-4 ~ '0.000',
        TRUE ~ era_minus(sprintf('%+.3f', estimate))))
  folds = readr::read_csv(out('era_comparison/era_folds.csv'), show_col_types = FALSE) |>
    dplyr::filter(against == 'Holocene-C', response %in% log_responses)
  # The fold arrow runs from just above the Holocene-C interval to just below
  # the Anthropocene interval, between the two symbols, clear of the labels.
  arrows = means |> dplyr::filter(period_type %in% c('Holocene-C', 'Anthropocene')) |>
    dplyr::select(response, site, period_type, estimate, conf_low, conf_high) |>
    tidyr::pivot_wider(names_from = period_type, values_from = c(estimate, conf_low, conf_high)) |>
    dplyr::inner_join(folds |> dplyr::mutate(site = factor(site, levels = ERA_SITES)), by = c('response', 'site')) |>
    dplyr::mutate(x = as.integer(site) + .16, y = `conf_high_Holocene-C` * 1.1, yend = conf_low_Anthropocene / 1.1,
      y_text = sqrt(y * yend), text = dplyr::if_else(fold < 10, sprintf('%.1f-fold', fold), sprintf('%.0f-fold', fold)))
  # Connectors above each park's intervals: Anthropocene to Holocene-C on the
  # lower level, Anthropocene to Holocene-S on the upper one.
  connectors = readr::read_csv(out('era_comparison/era_contrasts.csv'), show_col_types = FALSE) |>
    dplyr::filter(response %in% names(titles), !response %in% log_responses,
      contrast %in% c('Anthropocene - Holocene-C', 'Anthropocene - Holocene-S')) |>
    dplyr::mutate(against = sub('Anthropocene - ', '', contrast), site = factor(site, levels = ERA_SITES)) |>
    dplyr::left_join(means |> dplyr::group_by(response) |> dplyr::summarise(span = max(conf_high) - min(conf_low)), by = 'response') |>
    dplyr::left_join(means |> dplyr::group_by(response, site) |> dplyr::summarise(top = max(conf_high), .groups = 'drop'),
      by = c('response', 'site')) |>
    dplyr::mutate(level = dplyr::if_else(against == 'Holocene-C', 1, 2), y = top + (.03 + .085 * level) * span, drop = .03 * span,
      x = as.integer(site) + ERA_OFFSET[against], xend = as.integer(site) + ERA_OFFSET[['Anthropocene']],
      # Stars use the Holm-adjusted p of the response's six contrasts (Bills, 10 Nov 2026).
      star = dplyr::if_else(p_adjusted < .05, '*', ''))
  list(means = means, arrows = arrows, connectors = connectors, titles = titles, log_responses = log_responses)
}

# `k` scales the internals (points, intervals, connectors, stars), `kl` the
# value and fold labels, which must still fit between neighbouring symbols,
# and `kt` the axis, tag and legend text. A figure with larger labels can make
# room for them: `spread` widens the spacing of the period types within a
# park, `park_gap` moves the second park further right, `gap` sets the label's
# distance from its point and `cap` the width of the interval caps, all in x
# units, and `xmin` and `xmax` bound the axis.
era_means_panel = function(r, tag, data, k = 1, kl = k, kt = 1, gap = .045 + .01 * k, cap = .08,
  spread = 1, park_gap = 1, xmin = .5, xmax = 1.72 + park_gap) {
  # Park p (1 or 2) sits at 1 + (p - 1) * park_gap, each symbol at its offset times spread.
  xs = function(x) { p = round(x); 1 + (p - 1) * park_gap + (x - p) * spread }
  d = data$means |> dplyr::filter(response == r) |> dplyr::mutate(x = xs(x))
  log_axis = r %in% data$log_responses
  p = ggplot(d, aes(x, estimate)) +
    (if (!log_axis) geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed')) +
    # The fitted mean beside its point, in the park colour, on a white backing
    # that hides the zero line but sits under the intervals.
    geom_label(aes(x = x + gap, label = label, color = site), hjust = 0, size = 5.2 * kl, fontface = 'bold',
      fill = 'white', label.size = 0, label.padding = unit(.06, 'lines')) +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high, color = site), width = cap, linewidth = 1.1 * k) +
    geom_point(aes(shape = period_type, fill = site), size = 5 * k, color = 'grey10', stroke = .6 * k) +
    scale_x_continuous(breaks = c(1, 1 + park_gap), labels = ERA_SITES, limits = c(xmin, xmax), expand = c(0, 0)) +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, name = NULL, breaks = ERA_TYPES, drop = FALSE,
      labels = c(`Holocene-S` = 'Holocene stability periods', `Holocene-C` = 'Holocene climate-change periods',
        Anthropocene = 'Anthropocene')) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60', size = 7 * kt))) +
    labs(tag = tag, x = NULL, y = data$titles[[r]]) +
    theme_paleoaces(base_size = 20 * kt) +
    theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
      legend.text = element_text(size = 24 * kt), plot.tag = element_text(size = 24 * kt, face = 'bold'),
      axis.title.y = element_text(size = 24 * kt, lineheight = .95))
  if (log_axis) {
    a = data$arrows |> dplyr::filter(response == r) |> dplyr::mutate(x = xs(x))
    p = p +
      geom_segment(data = a, aes(x = x, xend = x, y = y, yend = yend), color = 'grey35', linewidth = .8 * k,
        arrow = arrow(length = unit(.18, 'cm'), ends = 'both', type = 'closed')) +
      geom_text(data = a, aes(x = x + .03, y = y_text, label = text), hjust = 0, size = 5.6 * kl, color = 'grey15',
        fontface = 'bold') +
      # Log axis, tick labels as plain decimals in real values.
      scale_y_log10(breaks = c(.005, .01, .02, .05, .1, .2, .5, 1, 2, 5),
        labels = function(b) format(b, scientific = FALSE, drop0trailing = TRUE, trim = TRUE),
        expand = expansion(mult = c(.05, .08)))
  } else {
    cn = data$connectors |> dplyr::filter(response == r) |> dplyr::mutate(x = xs(x), xend = xs(xend))
    p = p +
      geom_segment(data = cn, aes(x = x, xend = xend, y = y, yend = y), color = 'grey25', linewidth = .7 * k) +
      geom_segment(data = cn, aes(x = x, xend = x, y = y, yend = y - drop), color = 'grey25', linewidth = .7 * k) +
      geom_segment(data = cn, aes(x = xend, xend = xend, y = y, yend = y - drop), color = 'grey25', linewidth = .7 * k) +
      geom_text(data = cn, aes(x = (x + xend) / 2, y = y, label = star), vjust = .25, size = 9 * k, color = 'grey10') +
      scale_y_continuous(labels = function(b) era_minus(format(b, drop0trailing = TRUE, trim = TRUE)),
        expand = expansion(mult = c(.05, .06)))
  }
  p
}
