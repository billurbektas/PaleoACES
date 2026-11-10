# Trial figures (Bills, 10 Nov 2026): fitted era means with 95% intervals per
# park and period type on a cut y axis. Holocene means are small and many
# Anthropocene means large, so each response gets up to three stacked
# segments: a middle segment on its own scale that holds every Holocene
# interval, and compressed segments above and below for the Anthropocene. The
# compressed segments carry their own axis colour. Not in the report yet.
# Figure 1: climate change rate, turnover rate, lag and lag rate.
# Figure 2: pace effect and direction effect.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

types = c('Holocene-S', 'Holocene-C', 'Anthropocene')
x_labels = c(`Holocene-S` = 'Holocene\nstability', `Holocene-C` = 'Holocene\nclimate change', Anthropocene = 'Anthropocene')
COMPRESSED_AXIS = '#7B4F9E'
MID_HEIGHT = 3
OUTER_MAX = .5
# Rates of change are magnitudes and positive by construction, so a star for
# "differs from zero" would say nothing there. Stars only on signed responses.
SIGNED = c('lag', 'lag_rate', 'pace_effect', 'direction_effect')
means = read_csv(out('era_comparison/era_means.csv'), show_col_types = FALSE) |>
  mutate(period_type = factor(period_type, levels = types), site = factor(site, levels = c('MORA', 'NOCA')))
minus = function(x) gsub('-', '−', x)

# Cuts follow the data. The middle segment spans every Holocene interval, zero,
# and any Anthropocene mean within twice that reach, padded and rounded out. An
# outer segment starts at the cut when an interval runs across it, so no part
# of an interval is hidden. Otherwise it skips the empty range and starts just
# below (above) the nearest interval end.
axis_cuts = function(m) {
  holocene = m |> filter(period_type != 'Anthropocene')
  core = range(0, holocene$conf_low, holocene$conf_high)
  near = m$estimate[m$period_type == 'Anthropocene' & abs(m$estimate) < 2 * max(abs(core))]
  mid = range(core, near)
  step = 10^floor(log10(diff(mid))) / 5
  mid = mid + c(-1, 1) * .12 * diff(mid)
  mid = c(floor(mid[1] / step), ceiling(mid[2] / step)) * step
  # A response that cannot be negative starts at zero.
  if (all(m$conf_low >= 0)) mid[1] = 0
  above = m |> filter(conf_high > mid[2])
  below = m |> filter(conf_low < mid[1])
  top = if (nrow(above)) {
    hi = max(above$conf_high)
    lo = if (any(above$conf_low <= mid[2])) mid[2] else min(above$conf_low)
    pad = .08 * (hi - lo)
    c(if (lo == mid[2]) lo else lo - pad, hi + pad)
  }
  bottom = if (nrow(below)) {
    lo = min(below$conf_low)
    hi = if (any(below$conf_high >= mid[1])) mid[1] else max(below$conf_high)
    pad = .08 * (hi - lo)
    c(lo - pad, if (hi == mid[1]) hi else hi + pad)
  }
  # An outer segment that joins the middle and would be shorter than a third
  # of it is folded into the middle, where it reads better than a sliver.
  if (!is.null(top) && top[1] == mid[2] && diff(top) < diff(mid) / 3) {mid[2] = top[2]; top = NULL}
  if (!is.null(bottom) && bottom[2] == mid[1] && diff(bottom) < diff(mid) / 3) {mid[1] = bottom[1]; bottom = NULL}
  list(top = top, mid = mid, bottom = bottom)
}

segment = function(m, ylim, compressed, first, last, y_title, tag, step) {
  span = diff(ylim)
  axis_color = if (compressed) COMPRESSED_AXIS else 'grey20'
  # The fitted mean is labelled in the segment that holds it.
  shown = m |> filter(estimate >= ylim[1], estimate < ylim[2])
  # Break marks: a short slash at the left edge of each facet, on both sides of
  # every cut, with a white gap between the segments.
  edges = as.numeric(c(if (!first) ylim[2], if (!last) ylim[1]))
  marks = expand_grid(site = factor(c('MORA', 'NOCA'), levels = c('MORA', 'NOCA')), edge = edges) |>
    mutate(inside = if_else(edge == ylim[2], -1, 1), y = edge, yend = edge + inside * .07 * span,
      x = if_else(inside < 0, .62, .5), xend = if_else(inside < 0, .5, .62))
  ggplot(m, aes(period_type, estimate)) +
    geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed') +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high, color = site), width = .16, linewidth = 1.3) +
    geom_point(aes(fill = site, shape = period_type), size = 6, color = 'grey10', stroke = .6) +
    # Every label to the right of its mean, with room kept at the right edge.
    geom_text(data = shown, aes(label = label), nudge_x = .15, hjust = 0, size = 6.5, color = 'grey10') +
    geom_segment(data = marks, aes(x = x, xend = xend, y = y, yend = yend), inherit.aes = FALSE,
      linewidth = 1.6, color = axis_color) +
    facet_grid(~ site) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, guide = 'none') +
    scale_x_discrete(labels = x_labels) +
    # No tick right at a cut, where the labels of two segments would collide.
    scale_y_continuous(breaks = function(l) {
      # The segments above and below share one tick step.
      b = if (compressed) round(seq(ceiling(l[1] / step) * step, floor(l[2] / step) * step, by = step), 10) else
        scales::breaks_extended(6)(l)
      keep = b >= ylim[1] & b <= ylim[2]
      if (!first) keep = keep & b < ylim[2] - .05 * span
      if (!last) keep = keep & b > ylim[1] + .05 * span
      b[keep]
    }, labels = function(b) minus(format(b, trim = TRUE, drop0trailing = TRUE))) +
    coord_cartesian(xlim = c(.5, 3.95), ylim = ylim, expand = FALSE) +
    labs(x = NULL, y = y_title, tag = tag) + theme_paleoaces(base_size = 22) +
    theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
      strip.text.x = if (first) element_text(size = 24, face = 'bold') else element_blank(),
      strip.background = element_blank(),
      axis.text.x = if (last) element_text(size = 18, lineheight = .9) else element_blank(),
      axis.ticks.x = if (last) element_line() else element_blank(),
      # The compressed segments have their own axis colour and a light ground,
      # so the change of scale is seen at once.
      axis.text.y = element_text(size = 19, color = axis_color, face = if (compressed) 'bold' else 'plain'),
      axis.ticks.y = element_line(color = axis_color, linewidth = if (compressed) 1 else .5),
      axis.line.y = element_line(color = axis_color, linewidth = if (compressed) 2.2 else .8),
      panel.background = element_rect(fill = if (compressed) '#F3EEF7' else 'white', color = NA),
      plot.tag = element_text(size = 28, face = 'bold'),
      plot.margin = margin(if (first) 8 else 9, 14, if (last) 8 else 9, 14))
}

# One response: its segments stacked, the y title on the middle segment.
response_block = function(r, tag) {
  m = means |> filter(response == r)
  m = m |> mutate(label = paste0(minus(case_when(abs(estimate) < 5e-4 ~ '0.000', abs(estimate) >= 1 ~ sprintf('%+.2f', estimate),
    TRUE ~ sprintf('%+.3f', estimate))), if_else(r %in% SIGNED & p_value < .05, '*', '')))
  cuts = axis_cuts(m)
  parts = list(top = cuts$top, mid = cuts$mid, bottom = cuts$bottom)
  parts = parts[!vapply(parts, is.null, logical(1))]
  n = length(parts)
  # The segments above and below share one scale: the same height per unit and
  # the same tick step, so equal distances look equal on both sides of zero.
  # The longer outer segment gets OUTER_MAX of the middle's height.
  spans = vapply(parts, diff, numeric(1))
  outer = spans[names(spans) != 'mid']
  per_unit_outer = if (length(outer)) OUTER_MAX * MID_HEIGHT / max(outer) else NA
  heights = ifelse(names(parts) == 'mid', MID_HEIGHT, spans * per_unit_outer)
  step = if (length(outer)) diff(scales::breaks_pretty(5)(c(0, max(outer))))[1] else NA
  plots = imap(unname(parts), function(ylim, i) segment(m, ylim, compressed = names(parts)[i] != 'mid',
    first = i == 1, last = i == n, y_title = if (names(parts)[i] == 'mid') RESPONSE_AXIS_LABELS[[r]] else NULL,
    tag = if (i == 1) tag else NULL, step = step))
  wrap_plots(plots, ncol = 1, heights = heights)
}

draw = function(responses, name, ncol, width, height) {
  blocks = imap(unname(responses), function(r, i) response_block(r, paste0(LETTERS[i], '.')))
  figure = wrap_plots(blocks, ncol = ncol)
  if (render_figures) for (ext in c('pdf', 'png'))
    ggsave(fig('presentation', paste0(name, '.', ext)), figure, width = width, height = height, dpi = 300,
      bg = 'white', device = if (ext == 'pdf') cairo_pdf else NULL)
}
draw(c('climate_rate', 'turnover_rate', 'lag', 'lag_rate'), 'trial_rates_lags_cut_axis', 2, 26, 22)
draw(c('pace_effect', 'direction_effect'), 'trial_pace_direction_cut_axis', 2, 26, 11)
cat('Trial era-mean figures with cut axes drawn.\n')
