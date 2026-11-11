# Figure 4: A, species and climate biplot; B, observed and predicted trajectories
# of both parks through the Holocene climate periods and the Anthropocene.
# Layout of the earlier figure (Bills, 9 Nov 2026), on the MSpT + SP CCA with
# the display-only varimax rotation (R/helpers/cca_display_rotation.R). The
# appendix figure is the unrotated biplot.
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
as_xy = function(m) { m = as.matrix(m); colnames(m) = c('x', 'y'); m }
rotate = function(m) as_xy(as.matrix(m) %*% rotation$matrix)
contributions = read_csv(out('cca_species_contributions.csv'), show_col_types = FALSE)
calibration = predict(model, newdata = reference$legacy_species, type = 'wa', scaling = 'sites', hill = FALSE)[, 1:2]

# Holocene period centroids per park: each lake's sampled centuries are
# averaged within a period, then the lakes of the park are averaged equally.
periods = read_csv(out('holocene_periods.csv'), show_col_types = FALSE)
positions = read_csv(out('cca_tracking_holocene_century_positions.csv'), show_col_types = FALSE)
k = vapply(positions$century_cal_bp, function(a) {
  i = which(a < periods$older_cal_bp & a >= periods$younger_cal_bp); if (length(i)) i else NA_integer_ }, integer(1))
positions = positions |> mutate(period = periods$period[k], order = k) |> filter(!is.na(period))
centroids = positions |> group_by(site, lake, period, order) |>
  summarise(across(c(o1, o2, p1, p2), mean), .groups = 'drop') |>
  group_by(site, period, order) |>
  summarise(across(c(o1, o2, p1, p2), mean), n_lakes = n(), .groups = 'drop') |> arrange(site, order)
write_csv(centroids, out('figures/cca_trajectory_period_centroids.csv'))
plots = read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE)
anthropocene = plots |> group_by(site) |>
  summarise(o1 = mean(o1), o2 = mean(o2), p1 = mean(p1), p2 = mean(p2),
    o1_2 = mean(o1_2), o2_2 = mean(o2_2), p1_2 = mean(p1_2), p2_2 = mean(p2_2), n = n())
write_csv(anthropocene, out('figures/cca_trajectory_anthropocene_centroids.csv'))
spans = centroids |> group_by(site) |>
  summarise(first_period = period[which.min(order)], last_period = period[which.max(order)]) |>
  left_join(periods |> select(first_period = period, first_older = older_cal_bp), by = 'first_period') |>
  left_join(periods |> select(last_period = period, last_younger = younger_cal_bp), by = 'last_period')
write_csv(spans, out('figures/cca_trajectory_holocene_spans.csv'))

# Long form: one point per series and step, in display coordinates.
point_rows = function(d, x, y, type, era, order, lab) {
  r = rotate(d[c(x, y)])
  tibble(site = d$site, era, type, order = order, lab = lab, x = r[, 1], y = r[, 2])
}
traj = bind_rows(
  point_rows(centroids, 'o1', 'o2', 'observed', 'Holocene', centroids$order, centroids$period),
  point_rows(centroids, 'p1', 'p2', 'predicted', 'Holocene', centroids$order, centroids$period),
  point_rows(anthropocene, 'o1', 'o2', 'observed', 'Anthropocene', 1, 'legacy'),
  point_rows(anthropocene, 'o1_2', 'o2_2', 'observed', 'Anthropocene', 2, 'resurvey'),
  point_rows(anthropocene, 'p1', 'p2', 'predicted', 'Anthropocene', 1, 'legacy'),
  point_rows(anthropocene, 'p1_2', 'p2_2', 'predicted', 'Anthropocene', 2, 'resurvey')) |>
  mutate(series = paste(site, type, sep = '_'), group = paste(site, era, type)) |> arrange(group, order)
steps = traj |> group_by(group) |> mutate(xend = lead(x), yend = lead(y)) |> ungroup() |> filter(!is.na(xend))

TEXT = 7.4  # label size in mm, matched to the larger axis text
theme_fig3 = theme_paleoaces(base_size = 26) +
  theme(legend.position = 'bottom', aspect.ratio = 1, axis.title = element_text(size = 26),
    axis.text = element_text(size = 23), legend.text = element_text(size = 25), legend.title = element_text(size = 24),
    plot.tag = element_text(size = 34, face = 'bold'), plot.margin = margin(12, 16, 12, 12))
# Side labels on the axis titles: the second line names the climate each end of
# the axis leads to.
rbp = rotate(bp)
side_title = function(variable, low, high) paste0(variable, '\n\u2190 ', low, strrep(' ', 14), high, ' \u2192')
x_title = if (rbp['MSpT', 'x'] > 0) side_title('Spring temperature (rotated axis 1)', 'Colder springs', 'Warmer springs') else
  side_title('Spring temperature (rotated axis 1)', 'Warmer springs', 'Colder springs')
y_title = if (rbp['SP', 'y'] > 0) side_title('Summer precipitation (rotated axis 2)', 'Drier summers', 'Wetter summers') else
  side_title('Summer precipitation (rotated axis 2)', 'Wetter summers', 'Drier summers')
square = function(xr, yr, pad = .06) {
  half = max(diff(xr), diff(yr)) / 2 * (1 + pad)
  list(x = mean(xr) + c(-half, half), y = mean(yr) + c(-half, half))
}

# Panel A: species as vectors from the centre, shaded by their share of the
# constrained inertia; the two climate constraints as bold arrows.
biplot = function(rotated = TRUE) {
  tr = if (rotated) rotate else as_xy
  sp = as_tibble(tr(species_scores)) |> mutate(species = rownames(species_scores)) |>
    left_join(contributions |> select(species, share = percent_constrained_inertia, prevalence_percent), by = 'species')
  # The main panel shows only species above an equal share of the constrained
  # inertia (100% / number of taxa), to declutter it (Bills); the appendix
  # biplot shows every taxon.
  if (rotated) sp = sp |> filter(share > 100 / nrow(species_scores))
  arrows = as_tibble(tr(bp)) |> mutate(variable = rownames(bp), label = unname(CLIMATE_VARIABLE_LABELS[variable]))
  mult = .75 * max(sqrt(sp$x^2 + sp$y^2)) / max(sqrt(arrows$x^2 + arrows$y^2))
  arrows = mutate(arrows, x = x * mult, y = y * mult)
  # Species labels repel each other, the species points and the arrow tips;
  # the climate labels sit just beyond their arrow tips, clear of the arrowheads.
  labels = bind_rows(
    sp |> transmute(x, y, label = sprintf('%s (%.1f%%)', species, prevalence_percent), fontface = 'italic', share),
    arrows |> transmute(x, y, label = '', fontface = 'plain', share = NA_real_))
  arrow_labels = arrows |> mutate(lx = x * 1.1, ly = y * 1.1,
    hjust = if_else(abs(x) > abs(y), if_else(x > 0, 1, 0), .5),
    vjust = if_else(abs(x) > abs(y), if_else(y > 0, -.6, 1.6), if_else(y > 0, -.4, 1.4)))
  lim = square(range(c(sp$x, arrows$x)), range(c(sp$y, arrows$y)), pad = .25)
  imp = 100 * model$CCA$eig[1:2] / model$tot.chi
  ggplot() +
    geom_hline(yintercept = 0, color = 'grey88', linewidth = .4) + geom_vline(xintercept = 0, color = 'grey88', linewidth = .4) +
    geom_segment(data = sp, aes(0, 0, xend = x, yend = y, color = share), linewidth = .6) +
    geom_point(data = sp, aes(x, y, color = share), size = 2.2) +
    geom_segment(data = arrows, aes(0, 0, xend = x, yend = y), linewidth = 1.4, color = 'black',
      arrow = arrow(length = unit(.3, 'cm'), type = 'closed')) +
    geom_text(data = arrow_labels, aes(lx, ly, label = label, hjust = hjust, vjust = vjust), size = TEXT,
      fontface = 'bold', color = 'black') +
    # Labels as in the earlier figure: white boxes without a border, leaders to
    # the exact scores, species text shaded like its vector.
    geom_label_repel(data = labels, aes(x, y, label = label, fontface = fontface, color = share),
      size = TEXT, fill = 'white', linewidth = 0, label.padding = unit(.10, 'lines'),
      box.padding = .45, point.padding = .2, force = 3, force_pull = 2, segment.size = .3, segment.color = 'grey65',
      min.segment.length = 0, max.overlaps = Inf, max.iter = 200000, max.time = 10, seed = 11,
      xlim = lim$x, ylim = lim$y, show.legend = FALSE) +
    scale_color_gradient(low = 'grey65', high = 'grey5', na.value = 'black', name = 'Share of constrained inertia (%)',
      limits = c(0, max(contributions$percent_constrained_inertia)),
      guide = guide_colorbar(title.position = 'top', title.hjust = .5, barwidth = unit(9, 'cm'), barheight = unit(.6, 'cm'))) +
    coord_cartesian(xlim = lim$x, ylim = lim$y, expand = FALSE) +
    labs(tag = if (rotated) 'A.' else NULL,
      x = if (rotated) x_title else sprintf('CCA1 (%.1f%% of total inertia)', imp[1]),
      y = if (rotated) y_title else sprintf('CCA2 (%.1f%% of total inertia)', imp[2])) +
    theme_fig3
}
p_biplot = biplot(TRUE)

# Panel B: the reduced Holocene trajectory of each park (first to last period
# with samples) beside the Anthropocene legacy-to-resurvey movement. Panels C
# and D: the full Holocene sequence of each park, framed in the park's colour.
cal = as_tibble(rotate(calibration))
holocene = traj |> filter(era == 'Holocene')
reduced = holocene |> group_by(site, type) |> filter(order %in% range(order)) |> ungroup()
modern = traj |> filter(era == 'Anthropocene')
shown = bind_rows(reduced, modern) |> mutate(group = paste(site, era, type))
steps_b = shown |> group_by(group) |> arrange(order, .by_group = TRUE) |>
  mutate(xend = lead(x), yend = lead(y)) |> ungroup() |> filter(!is.na(xend))
boxes = holocene |> group_by(site) |> summarise(xmin = min(x), xmax = max(x), ymin = min(y), ymax = max(y)) |>
  mutate(pad = .06 * pmax(xmax - xmin, ymax - ymin), xmin = xmin - pad, xmax = xmax + pad,
    ymin = ymin - pad, ymax = ymax + pad, letter = c(MORA = 'C', NOCA = 'D')[site],
    color = PAPER_SITE_COLORS[site])
# Panel B is cropped tightly around the trajectories, with
# equal scaling on both axes so that directions are not distorted; its frame is
# a little taller than wide (width 0.84 of the height).
B_ASPECT = 1 / .84
xr = range(shown$x); yr = range(shown$y)
yr = yr + c(-1, 1) * .06 * diff(yr)
half_x = max(diff(xr) * 1.08, diff(yr) / B_ASPECT) / 2
lim_b = list(x = mean(xr) + c(-half_x, half_x), y = mean(yr) + c(-1, 1) * max(diff(yr), 2 * half_x * B_ASPECT) / 2)
# In B the Holocene ends are named by their role, not their period (Bills).
end_labels = shown |> filter(type == 'observed') |> group_by(site, era) |>
  mutate(lab = if_else(era == 'Holocene', if_else(order == min(order), 'Holocene start', 'Holocene end'), lab)) |>
  ungroup()
labels_b = bind_rows(end_labels |> transmute(x, y, label = lab, series, fontface = 'plain', size = TEXT - .6),
  shown |> filter(type == 'predicted') |> transmute(x, y, label = '', series, fontface = 'plain', size = TEXT))
# Arrows run from the edge of one circle to the edge of the next instead of
# across the circles: each step is trimmed by the circle radius at both ends
# (the radius as a share of the panel width, matched to the point size below).
trim_steps = function(steps, xl, r = .011 * diff(xl)) {
  len = sqrt((steps$xend - steps$x)^2 + (steps$yend - steps$y)^2)
  keep = len > 2.2 * r
  steps = steps[keep, ]; len = len[keep]
  ux = (steps$xend - steps$x) / len; uy = (steps$yend - steps$y) / len
  steps |> mutate(x = x + ux * r, y = y + uy * r, xend = xend - ux * r, yend = yend - uy * r)
}
trajectory_layers = function(points, steps, labels, xl, yl, force = 3, box_padding = .45) list(
  geom_segment(data = trim_steps(steps, xl), aes(x, y, xend = xend, yend = yend, color = series),
    linewidth = 1.4, arrow = arrow(length = unit(.32, 'cm'), type = 'closed'), show.legend = FALSE),
  geom_point(data = points, aes(x, y, color = series), shape = 21, fill = 'white', size = 4, stroke = 1.3,
    show.legend = FALSE),
  geom_label_repel(data = labels, aes(x, y, label = label, color = series, fontface = fontface, size = size),
    fill = 'white', linewidth = 0, label.padding = unit(.08, 'lines'), box.padding = box_padding, point.padding = .3,
    force = force, force_pull = 1, segment.size = .3, segment.color = 'grey60', min.segment.length = 0,
    max.overlaps = Inf, max.iter = 200000, max.time = 10, seed = 3, lineheight = .9, xlim = xl, ylim = yl,
    show.legend = FALSE),
  # Legend keys only: the parks in their dark colours, and observed against
  # predicted as a dark and a light dot.
  geom_point(data = tibble(x = NA_real_, y = NA_real_, park = c('MORA', 'NOCA'), kind = c('Observed', 'Predicted')),
    aes(x, y, fill = park, shape = kind), na.rm = TRUE),
  scale_color_manual(values = PARK_COLORS, guide = 'none'),
  scale_fill_manual(values = PAPER_SITE_COLORS, name = NULL,
    guide = guide_legend(order = 1, override.aes = list(shape = 21, size = 7, color = NA))),
  scale_shape_manual(values = c(Observed = 21, Predicted = 21), name = NULL,
    guide = guide_legend(order = 2, override.aes = list(fill = c('grey15', 'grey72'), color = NA, size = 7))),
  scale_size_identity())
p_trajectories = ggplot() +
  geom_hline(yintercept = 0, color = 'grey90') + geom_vline(xintercept = 0, color = 'grey90') +
  geom_point(data = cal, aes(x, y), color = 'grey80', size = .7, alpha = .4) +
  # Stronger repulsion in B, where the NOCA Anthropocene points crowd together.
  trajectory_layers(shown, steps_b, labels_b, lim_b$x, lim_b$y, force = 10, box_padding = 1) +
  coord_cartesian(xlim = lim_b$x, ylim = lim_b$y, expand = FALSE) +
  labs(tag = 'B.', x = x_title, y = y_title) + theme_fig3 +
  theme(aspect.ratio = diff(lim_b$y) / diff(lim_b$x))

zoom = function(park) {
  d = holocene |> filter(site == park) |> mutate(group = paste(site, era, type))
  st = d |> group_by(group) |> arrange(order, .by_group = TRUE) |> mutate(xend = lead(x), yend = lead(y)) |>
    ungroup() |> filter(!is.na(xend))
  box = boxes[boxes$site == park, ]
  lab = bind_rows(d |> filter(type == 'observed') |> transmute(x, y, label = lab, series, fontface = 'plain', size = TEXT - .6),
    d |> filter(type == 'predicted') |> transmute(x, y, label = '', series, fontface = 'plain', size = TEXT))
  ggplot() + trajectory_layers(d, st, lab, c(box$xmin, box$xmax), c(box$ymin, box$ymax)) +
    coord_cartesian(xlim = c(box$xmin, box$xmax), ylim = c(box$ymin, box$ymax), expand = FALSE) +
    labs(tag = paste0(box$letter, '.'), title = paste(park, 'Holocene periods'), x = NULL, y = NULL) +
    # Only the observed and predicted key under the zooms: the park is in the title (Bills, 10 Nov 2026).
    guides(fill = 'none') +
    theme_fig3 + theme(legend.position = 'bottom', aspect.ratio = (box$ymax - box$ymin) / (box$xmax - box$xmin),
      plot.title = element_text(size = 30, face = 'bold', color = box$color), axis.text = element_text(size = 22))
}
# A and B on top; the zooms C (MORA) and D (NOCA) below, as large as the top
# panels allow, titled in the park's colour.
figure = (p_biplot | p_trajectories) / ((zoom('MORA') | zoom('NOCA')) + plot_layout(guides = 'collect') &
  theme(legend.position = 'bottom')) + plot_layout(heights = c(1, .9))
if (render_figures) {
  # cairo_pdf draws the arrows of the axis titles, which the default pdf device cannot.
  ggsave(fig('main', 'fig_cca_trajectories.pdf'), figure, width = 24, height = 24, device = cairo_pdf, bg = 'white')
  ggsave(fig('main', 'fig_cca_trajectories.png'), figure, width = 24, height = 24, dpi = 300, bg = 'white')
  ggsave(fig('supplementary', 'figS12_cca_biplot_unrotated.pdf'), biplot(FALSE), width = 12, height = 12.5,
    device = cairo_pdf, bg = 'white')
}
cat(sprintf('Figure 4: display rotation %.1f degrees; %d period centroids.\n', rotation$angle_degrees, nrow(centroids)))
