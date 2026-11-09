# Figure 3 (PLAN.md section 6): A, the CCA biplot; B, first-to-final Holocene
# movement per park beside the Anthropocene legacy-to-resurvey movement; C and
# D, the full Holocene sequence of period centroids per park (zoom windows).
# Every coordinate is rotated for display only (R/helpers/cca_display_rotation.R).
# The appendix figure is the unrotated biplot.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan); library(patchwork); library(ggrepel)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/cca_display_rotation.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

reference = readRDS(out('cca_calibration_reference.rds'))
model = reference$model
bp = scores(model, display = 'bp', choices = 1:2, scaling = 'sites', hill = FALSE)
species_scores = scores(model, display = 'species', choices = 1:2, scaling = 'sites', hill = FALSE)
rotation = cca_display_rotation(bp)
rotate = function(m) { m = as.matrix(m) %*% rotation$matrix; colnames(m) = c('x', 'y'); m }
contributions = read_csv(out('cca_species_contributions.csv'), show_col_types = FALSE)
calibration = predict(model, newdata = reference$legacy_species, type = 'wa', scaling = 'sites', hill = FALSE)[, 1:2]

# Holocene period centroids per park: each lake's sampled centuries are
# averaged within a period, then the lakes of the park are averaged equally.
periods = read_csv(out('holocene_periods.csv'), show_col_types = FALSE)
positions = read_csv(out('cca_tracking_holocene_century_positions.csv'), show_col_types = FALSE)
k = vapply(positions$century_cal_bp, function(a) {
  i = which(a < periods$older_cal_bp & a >= periods$younger_cal_bp); if (length(i)) i else NA_integer_ }, integer(1))
positions = positions |> mutate(period = periods$period[k], period_type = periods$period_type[k],
  order = k) |> filter(!is.na(period))
centroids = positions |> group_by(site, lake, period, period_type, order) |>
  summarise(across(c(o1, o2, p1, p2), mean), .groups = 'drop') |>
  group_by(site, period, period_type, order) |>
  summarise(across(c(o1, o2, p1, p2), mean), n_lakes = n(), .groups = 'drop') |> arrange(site, order)
write_csv(centroids, out('figures/cca_trajectory_period_centroids.csv'))
plots = read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE)
anthropocene = plots |> group_by(site) |>
  summarise(o1 = mean(o1), o2 = mean(o2), p1 = mean(p1), p2 = mean(p2),
    o1_2 = mean(o1_2), o2_2 = mean(o2_2), p1_2 = mean(p1_2), p2_2 = mean(p2_2), n = n())
write_csv(anthropocene, out('figures/cca_trajectory_anthropocene_centroids.csv'))

long_points = function(d, x, y, kind) {
  r = rotate(d[c(x, y)]); tibble(site = d$site, kind, x = r[, 1], y = r[, 2])
}
holocene_points = bind_rows(
  bind_cols(centroids |> select(site, period, period_type, order), long_points(centroids, 'o1', 'o2', 'observed') |> select(kind, x, y)),
  bind_cols(centroids |> select(site, period, period_type, order), long_points(centroids, 'p1', 'p2', 'predicted') |> select(kind, x, y))) |>
  mutate(series = paste(site, kind, sep = '_'))
ends = holocene_points |> group_by(site, kind) |> filter(order %in% range(order)) |> arrange(order, .by_group = TRUE) |>
  summarise(period_start = first(period), period_end = last(period), type_start = first(period_type),
    type_end = last(period_type), xend = last(x), yend = last(y), x = first(x), y = first(y), .groups = 'drop') |>
  mutate(era = 'Holocene', series = paste(site, kind, sep = '_'))
anth_arrows = bind_rows(lapply(c('observed', 'predicted'), function(kind) {
  s = if (kind == 'observed') c('o1', 'o2', 'o1_2', 'o2_2') else c('p1', 'p2', 'p1_2', 'p2_2')
  a = rotate(anthropocene[s[1:2]]); b = rotate(anthropocene[s[3:4]])
  tibble(site = anthropocene$site, kind, x = a[, 1], y = a[, 2], xend = b[, 1], yend = b[, 2])
})) |> mutate(era = 'Anthropocene', series = paste(site, kind, sep = '_'))

# Side labels follow the rotated climate arrows: each arrow points to the warm
# or wet side of its axis.
rbp = rotate(bp)
sides = tibble(side = c('right', 'left', 'top', 'bottom'),
  label = c(if (rbp['MSpT', 1] > 0) c('Warmer springs', 'Colder springs') else c('Colder springs', 'Warmer springs'),
            if (rbp['SP', 2] > 0) c('Wetter summers', 'Drier summers') else c('Drier summers', 'Wetter summers')))
side_labels = function(p, xlim, ylim) {
  pad = .04
  p + annotate('text', x = xlim[2], y = mean(ylim), label = sides$label[1], angle = -90, vjust = -.4, size = 4, color = 'grey30') +
    annotate('text', x = xlim[1], y = mean(ylim), label = sides$label[2], angle = 90, vjust = -.4, size = 4, color = 'grey30') +
    annotate('text', x = mean(xlim), y = ylim[2], label = sides$label[3], vjust = -.5, size = 4, color = 'grey30') +
    annotate('text', x = mean(xlim), y = ylim[1], label = sides$label[4], vjust = 1.5, size = 4, color = 'grey30') +
    coord_equal(xlim = xlim, ylim = ylim, clip = 'off')
}
axis_titles = labs(x = 'Spring temperature (rotated axis 1)', y = 'Summer precipitation (rotated axis 2)')
theme_fig3 = theme_paleoaces(base_size = 13) + theme(legend.position = 'bottom', plot.margin = margin(18, 22, 18, 18))

biplot = function(rotated = TRUE) {
  tr = if (rotated) rotate else function(m) { m = as.matrix(m); colnames(m) = c('x', 'y'); m }
  sp = as_tibble(tr(species_scores)) |> mutate(species = rownames(species_scores)) |>
    left_join(contributions |> select(species, percent_constrained_inertia), by = 'species')
  cal = as_tibble(tr(calibration))
  arrows = as_tibble(tr(bp)) |> mutate(variable = rownames(bp), label = CLIMATE_VARIABLE_LABELS[variable])
  scale = .75 * max(abs(c(sp$x, sp$y))) / max(sqrt(arrows$x^2 + arrows$y^2))
  arrows = mutate(arrows, x = x * scale, y = y * scale)
  lim = range(c(sp$x, sp$y, cal$x, cal$y, arrows$x, arrows$y)) * 1.08
  p = ggplot() +
    geom_point(data = cal, aes(x, y), color = 'grey85', size = .7) +
    geom_hline(yintercept = 0, color = 'grey70', linewidth = .3) + geom_vline(xintercept = 0, color = 'grey70', linewidth = .3) +
    geom_segment(data = arrows, aes(0, 0, xend = x, yend = y), arrow = arrow(length = unit(.12, 'in')), linewidth = .9, color = 'grey10') +
    geom_label(data = arrows, aes(x * 1.12, y * 1.12, label = label), size = 3.6, fontface = 'bold', color = 'grey10', label.size = 0, fill = alpha('white', .8)) +
    geom_point(data = sp, aes(x, y, fill = percent_constrained_inertia), shape = 21, size = 3.2, color = 'grey20') +
    geom_text_repel(data = sp, aes(x, y, label = species), size = 3.2, fontface = 'italic', color = 'grey15',
      seed = 1, max.overlaps = Inf, box.padding = .3) +
    scale_fill_gradient(low = 'grey95', high = 'grey10', name = 'Share of constrained inertia (%)') +
    theme_fig3 + guides(fill = guide_colorbar(barwidth = unit(4, 'cm'), title.position = 'top'))
  if (rotated) side_labels(p, lim, lim) + axis_titles + labs(tag = 'A.') else {
    imp = 100 * model$CCA$eig[1:2] / model$tot.chi
    p + coord_equal(xlim = lim, ylim = lim) + labs(x = sprintf('CCA1 (%.1f%% of total inertia)', imp[1]),
      y = sprintf('CCA2 (%.1f%% of total inertia)', imp[2]))
  }
}
p_biplot = biplot(TRUE)

colors = PARK_COLORS
arrow_layer = function(d, linetype) geom_segment(data = d, aes(x, y, xend = xend, yend = yend, color = series),
  linetype = linetype, linewidth = 1.1, arrow = arrow(length = unit(.11, 'in'), type = 'closed'))
all_xy = c(ends$x, ends$xend, anth_arrows$x, anth_arrows$xend)
all_yy = c(ends$y, ends$yend, anth_arrows$y, anth_arrows$yend)
pad = .12 * max(diff(range(all_xy)), diff(range(all_yy)))
xlim_b = range(all_xy) + c(-pad, pad); ylim_b = range(all_yy) + c(-pad, pad)
zoom_box = holocene_points |> group_by(site) |>
  summarise(xmin = min(x), xmax = max(x), ymin = min(y), ymax = max(y)) |>
  mutate(px = .08 * pmax(xmax - xmin, ymax - ymin), xmin = xmin - px, xmax = xmax + px, ymin = ymin - px, ymax = ymax + px)
p_moves = ggplot() +
  geom_rect(data = zoom_box, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = NA, color = 'grey55',
    linetype = 'dotted') +
  geom_text(data = zoom_box, aes(xmin, ymax, label = paste(site, 'zoom')), hjust = 0, vjust = -.4, size = 3, color = 'grey40') +
  arrow_layer(ends, 'solid') + arrow_layer(anth_arrows, 'solid') +
  geom_point(data = ends, aes(x, y, shape = type_start, fill = series), size = 3, color = 'grey15') +
  geom_point(data = anth_arrows, aes(x, y, fill = series), shape = 23, size = 3, color = 'grey15') +
  scale_color_manual(values = colors, guide = 'none') +
  scale_fill_manual(values = colors, breaks = names(colors), labels = sub('_', ' ', names(colors)), name = NULL) +
  scale_shape_manual(values = PERIOD_TYPE_SHAPES, guide = 'none') +
  guides(fill = guide_legend(override.aes = list(shape = 22, size = 4), nrow = 2)) +
  axis_titles + labs(tag = 'B.') + theme_fig3
p_moves = side_labels(p_moves, xlim_b, ylim_b)

zoom = function(park, tag) {
  d = holocene_points |> filter(site == park) |> arrange(kind, order)
  first_last = d |> group_by(kind) |> filter(order %in% range(order))
  ggplot(d, aes(x, y, color = series, group = series)) +
    geom_path(linewidth = .8, arrow = arrow(length = unit(.08, 'in'), type = 'closed')) +
    geom_point(aes(shape = period_type, fill = series), size = 3, color = 'grey15') +
    geom_text_repel(data = first_last, aes(label = period), size = 3.2, color = 'grey15', seed = 2, show.legend = FALSE) +
    scale_color_manual(values = colors, guide = 'none') + scale_fill_manual(values = colors, guide = 'none') +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, name = NULL, breaks = c('Holocene-C', 'Holocene-S'),
      labels = c('Climate-change period (C)', 'Stability period (S)')) +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60'))) +
    coord_equal() + labs(tag = tag, title = paste(park, 'Holocene periods'),
      x = 'Spring temperature (rotated axis 1)', y = 'Summer precipitation (rotated axis 2)') +
    theme_fig3 + theme(plot.title = element_text(size = 12, face = 'bold'))
}
figure = (p_biplot | p_moves) / (zoom('MORA', 'C.') + theme(legend.position = 'none') | zoom('NOCA', 'D.')) +
  plot_layout(heights = c(1.25, 1))
if (render_figures) {
  for (ext in c('pdf', 'png')) ggsave(fig('main', paste0('fig_cca_trajectories.', ext)), figure, width = 15, height = 15, dpi = 300)
  ggsave(fig('supplementary', 'fig_cca_biplot_unrotated.pdf'), biplot(FALSE) + labs(tag = NULL), width = 8, height = 8.5)
}
spans = holocene_points |> filter(kind == 'observed') |> group_by(site) |>
  summarise(first_period = period[which.min(order)], last_period = period[which.max(order)])
write_csv(spans |> left_join(periods |> select(first_period = period, first_older = older_cal_bp), by = 'first_period') |>
  left_join(periods |> select(last_period = period, last_younger = younger_cal_bp), by = 'last_period'),
  out('figures/cca_trajectory_holocene_spans.csv'))
cat(sprintf('Figure 3: display rotation %.1f degrees; Holocene spans written.\n', rotation$angle_degrees))
