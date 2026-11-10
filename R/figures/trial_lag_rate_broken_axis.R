# Trial figure (Bills, 10 Nov 2026): fitted lag rates with 95% intervals per
# park and period type on a cut y axis. The Holocene means are small and the
# Anthropocene ones large, so the axis is split into three stacked segments: a
# stretched middle that holds every Holocene interval, and compressed segments
# above and below for the Anthropocene. The segments join without a gap, so no
# part of an interval is hidden. Only the scale changes at a cut. Not in the
# report yet.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

types = c('Holocene-S', 'Holocene-C', 'Anthropocene')
m = read_csv(out('era_comparison/era_means.csv'), show_col_types = FALSE) |> filter(response == 'lag_rate') |>
  mutate(period_type = factor(period_type, levels = types), site = factor(site, levels = c('MORA', 'NOCA')),
    label = paste0(if_else(abs(estimate) < 5e-4, '0.000', sub('-', '\u2212', sprintf('%+.3f', estimate))),
      if_else(p_value < .05, '*', '')))
# Cuts follow the data. The middle segment spans every Holocene interval, zero,
# and any Anthropocene mean within twice that reach, padded and rounded out to
# 0.02, so no mean sits on a cut. The outer segments reach the extreme interval ends.
holocene = m |> filter(period_type != 'Anthropocene')
core = range(0, holocene$conf_low, holocene$conf_high)
near = m$estimate[m$period_type == 'Anthropocene' & abs(m$estimate) < 2 * max(abs(core))]
mid = range(core, near)
mid = mid + c(-1, 1) * .12 * diff(mid)
mid = c(floor(mid[1] / .02), ceiling(mid[2] / .02)) * .02
top = if (max(m$conf_high) > mid[2]) c(mid[2], max(m$conf_high) + .08 * (max(m$conf_high) - mid[2]))
bottom = if (min(m$conf_low) < mid[1]) c(min(m$conf_low) - .08 * (mid[1] - min(m$conf_low)), mid[1])
x_labels = c(`Holocene-S` = 'Holocene\nstability', `Holocene-C` = 'Holocene\nclimate change', Anthropocene = 'Anthropocene')

COMPRESSED_AXIS = '#7B4F9E'
segment = function(ylim, position) {
  span = diff(ylim)
  axis_color = if (position == 'middle') 'grey20' else COMPRESSED_AXIS
  # The fitted mean is labelled in the segment that holds it.
  shown = m |> filter(estimate >= ylim[1], estimate < ylim[2])
  # Break marks: a short slash at the left edge of each facet, on both sides of
  # every cut, with a white gap between the segments.
  edges = c(if (position != 'top') ylim[2], if (position != 'bottom') ylim[1])
  marks = expand_grid(site = factor(c('MORA', 'NOCA'), levels = c('MORA', 'NOCA')), edge = edges) |>
    mutate(inside = if_else(edge == ylim[2], -1, 1),
      y = edge, yend = edge + inside * .07 * span,
      x = if_else(inside < 0, .62, .5), xend = if_else(inside < 0, .5, .62))
  ggplot(m, aes(period_type, estimate)) +
    geom_hline(yintercept = 0, color = 'grey60', linetype = 'dashed') +
    geom_errorbar(aes(ymin = conf_low, ymax = conf_high, color = site), width = .16, linewidth = 1.3) +
    geom_point(aes(fill = site, shape = period_type), size = 6, color = 'grey10', stroke = .6) +
    # Labels to the right of Holocene means and to the left of Anthropocene
    # means, which sit at the panel edge.
    geom_text(data = shown, aes(label = label, x = as.numeric(period_type) + if_else(period_type == 'Anthropocene', -.17, .17),
      hjust = if_else(period_type == 'Anthropocene', 1, 0)), size = 6.5, color = 'grey10') +
    geom_segment(data = marks, aes(x = x, xend = xend, y = y, yend = yend), inherit.aes = FALSE,
      linewidth = 1.6, color = axis_color) +
    facet_grid(~ site) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, guide = 'none') +
    scale_x_discrete(labels = x_labels) +
    # No tick right at a cut, where the labels of two segments would collide.
    scale_y_continuous(breaks = function(l) {
      b = if (position == 'middle') scales::breaks_extended(6)(l) else scales::breaks_pretty(5)(l)
      b[b > ylim[1] + .05 * span & b < ylim[2] - .05 * span]
    }, labels = function(b) sub('-', '\u2212', format(b, trim = TRUE, drop0trailing = TRUE))) +
    coord_cartesian(xlim = c(.5, 3.5), ylim = ylim, expand = FALSE) +
    labs(x = NULL, y = if (position == 'middle') 'Lag rate' else NULL) + theme_paleoaces(base_size = 22) +
    theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
      strip.text.x = if (position == 'top') element_text(size = 24, face = 'bold') else element_blank(),
      strip.background = element_blank(),
      axis.text.x = if (position == 'bottom') element_text(size = 18, lineheight = .9) else element_blank(),
      axis.ticks.x = if (position == 'bottom') element_line() else element_blank(),
      # The compressed segments have their own axis colour and a light ground,
      # so the change of scale is seen at once.
      axis.text.y = element_text(size = 19, color = axis_color, face = if (position == 'middle') 'plain' else 'bold'),
      axis.ticks.y = element_line(color = axis_color, linewidth = if (position == 'middle') .5 else 1),
      axis.line.y = element_line(color = axis_color, linewidth = if (position == 'middle') .8 else 2.2),
      panel.background = element_rect(fill = if (position == 'middle') 'white' else '#F3EEF7', color = NA),
      plot.margin = margin(if (position == 'top') 8 else 9, 10, if (position == 'bottom') 8 else 9, 10))
}
panels = list(if (!is.null(top)) segment(top, 'top'), segment(mid, 'middle'),
  if (!is.null(bottom)) segment(bottom, 'bottom'))
heights = c(if (!is.null(top)) 2, 3, if (!is.null(bottom)) 1.6)
# Without a lower segment the middle one carries the x axis.
if (is.null(bottom)) panels[[2]] = segment(mid, 'bottom') + labs(y = 'Lag rate')
figure = wrap_plots(compact(panels), ncol = 1, heights = heights) & theme(panel.spacing.y = unit(0, 'pt'))
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('presentation', paste0('trial_lag_rate_broken_axis.', ext)), figure, width = 12, height = 13, dpi = 300,
    bg = 'white', device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Trial lag-rate figure with a cut axis drawn.\n')
