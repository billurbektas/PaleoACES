# Figure 4: A, species and climate biplot; B, observed and predicted trajectories
# of both parks through the Holocene climate periods and the Anthropocene.
# Layout of the earlier figure (Bills, 9 Nov 2026), on the MSpT + SP CCA with
# the display-only varimax rotation (R/helpers/cca_display_rotation.R). The
# appendix figure is the unrotated biplot. Redrawn after a reviewer comment
# (Bills, 23 Nov 2026): observed symbols filled and predicted symbols open, the
# period-type symbols of Figures 5 and 6, one era tag per line in B,
# labels kept off lines and symbols, and the species shaded by commonness.
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

# Long form: one point per series and step, in display coordinates. Each point
# carries the symbol of its period type, as in Figures 5 and 6.
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
  mutate(series = paste(site, type, sep = '_'), group = paste(site, era, type),
    kind = case_when(era == 'Anthropocene' ~ 'Anthropocene', startsWith(lab, 'C') ~ 'Holocene-C', TRUE ~ 'Holocene-S')) |>
  arrange(group, order)

TEXT = 7.4  # label size in mm, matched to the larger axis text
theme_fig3 = theme_paleoaces(base_size = 26) +
  theme(legend.position = 'bottom', aspect.ratio = 1, axis.title = element_text(size = 26),
    axis.text = element_text(size = 23), legend.text = element_text(size = 25), legend.title = element_text(size = 24),
    plot.tag = element_text(size = 34, face = 'bold'), plot.margin = margin(12, 16, 12, 12),
    legend.key.width = unit(1.8, 'cm'))
# Side labels on the axis titles: the second line names the climate each end of
# the axis leads to. The zooms carry the side labels alone, since A and B name the axes.
rbp = rotate(bp)
side_title = function(variable, low, high) paste0(variable, '\n← ', low, strrep(' ', 14), high, ' →')
x_title = if (rbp['MSpT', 'x'] > 0) side_title('Spring temperature (rotated axis 1)', 'Colder springs', 'Warmer springs') else
  side_title('Spring temperature (rotated axis 1)', 'Warmer springs', 'Colder springs')
y_title = if (rbp['SP', 'y'] > 0) side_title('Summer precipitation (rotated axis 2)', 'Drier summers', 'Wetter summers') else
  side_title('Summer precipitation (rotated axis 2)', 'Wetter summers', 'Drier summers')
side_short = function(low, high) paste0('← ', low, strrep(' ', 6), high, ' →')
zoom_x = if (rbp['MSpT', 'x'] > 0) side_short('Colder springs', 'Warmer springs') else side_short('Warmer springs', 'Colder springs')
zoom_y = if (rbp['SP', 'y'] > 0) side_short('Drier summers', 'Wetter summers') else side_short('Wetter summers', 'Drier summers')
square = function(xr, yr, pad = .06) {
  half = max(diff(xr), diff(yr)) / 2 * (1 + pad)
  list(x = mean(xr) + c(-half, half), y = mean(yr) + c(-half, half))
}

# Panel A: species as vectors from the centre, shaded by their commonness (the
# share of legacy plots where they occur, in three steps); the two climate
# constraints as bold arrows. The shading replaced the share of the constrained
# inertia, which hardly varied among the species shown (Bills, 23 Nov 2026).
biplot = function(rotated = TRUE) {
  tr = if (rotated) rotate else as_xy
  sp = as_tibble(tr(species_scores)) |> mutate(species = rownames(species_scores)) |>
    left_join(contributions |> select(species, share = percent_constrained_inertia, prevalence_percent), by = 'species')
  # The main panel shows only species above half an equal share of the
  # constrained inertia (50% / number of taxa), to declutter it (Bills; a full
  # equal share until 23 Nov 2026); the appendix biplot shows every taxon.
  if (rotated) sp = sp |> filter(share > 50 / nrow(species_scores))
  sp = sp |> mutate(common = as.character(cut(prevalence_percent, c(-Inf, 10, 30, Inf),
    labels = c('Under 10%', '10 to 30%', 'Over 30%'))))
  arrows = as_tibble(tr(bp)) |> mutate(variable = rownames(bp), label = unname(CLIMATE_VARIABLE_LABELS[variable]))
  mult = .75 * max(sqrt(sp$x^2 + sp$y^2)) / max(sqrt(arrows$x^2 + arrows$y^2))
  arrows = mutate(arrows, x = x * mult, y = y * mult)
  # Empty labels along every vector and arrow keep the names off the lines. The
  # climate labels are placed with the species names, so neither covers the other.
  along = bind_rows(sp |> select(x, y), arrows |> select(x, y)) |> tidyr::crossing(f = seq(0, 1, length.out = 40)) |>
    transmute(x = f * x, y = f * y, label = '', fontface = 'plain', common = 'anchor', point_size = 1.5)
  labels = bind_rows(
    sp |> transmute(x, y, label = species, fontface = 'italic', common, point_size = 3),
    arrows |> transmute(x, y, label, fontface = 'bold', common = 'anchor', point_size = 4), along)
  lim = square(range(c(sp$x, arrows$x)), range(c(sp$y, arrows$y)), pad = .25)
  imp = 100 * model$CCA$eig[1:2] / model$tot.chi
  ggplot() +
    geom_hline(yintercept = 0, color = 'grey88', linewidth = .4) + geom_vline(xintercept = 0, color = 'grey88', linewidth = .4) +
    geom_segment(data = sp, aes(0, 0, xend = x, yend = y, color = common), linewidth = .8) +
    geom_point(data = sp, aes(x, y, color = common), size = 2.6) +
    geom_segment(data = arrows, aes(0, 0, xend = x, yend = y), linewidth = 1.4, color = 'black',
      arrow = arrow(length = unit(.3, 'cm'), type = 'closed')) +
    # White boxes without a border, leaders to the exact scores, species text
    # shaded like its vector.
    geom_label_repel(data = labels, aes(x, y, label = label, fontface = fontface, color = common, point.size = point_size),
      size = TEXT, fill = 'white', linewidth = 0, label.padding = unit(.10, 'lines'),
      box.padding = .45, point.padding = .2, force = 3, force_pull = 2, segment.size = .3, segment.color = 'grey65',
      min.segment.length = 0, max.overlaps = Inf, max.iter = 200000, max.time = 10, seed = 11,
      xlim = lim$x, ylim = lim$y, show.legend = FALSE) +
    scale_color_manual(values = c(`Under 10%` = 'grey58', `10 to 30%` = 'grey33', `Over 30%` = 'grey5', anchor = 'black'),
      breaks = c('Under 10%', '10 to 30%', 'Over 30%'), name = 'Legacy plots where the species occurs',
      guide = guide_legend(title.position = 'top', title.hjust = .5, override.aes = list(linewidth = 2.5, size = 4))) +
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
holocene = traj |> filter(era == 'Holocene')
reduced = holocene |> group_by(site, type) |> filter(order %in% range(order)) |> ungroup()
modern = traj |> filter(era == 'Anthropocene')
shown = bind_rows(reduced, modern) |> mutate(group = paste(site, era, type))
# Lines without arrowheads, only those Bills named (23 Nov 2026): in B the
# observed MORA Anthropocene and the predicted NOCA Holocene, in D the predicted
# NOCA Holocene. Every other line keeps its arrowheads.
NO_HEADS = tribble(~panel, ~site, ~era, ~type,
  'B', 'MORA', 'Anthropocene', 'observed',
  'B', 'NOCA', 'Holocene', 'predicted',
  'D', 'NOCA', 'Holocene', 'predicted')
with_heads = function(steps, p) steps |>
  mutate(heads = !paste(site, era, type) %in% with(NO_HEADS[NO_HEADS$panel == p, ], paste(site, era, type)))
steps_b = shown |> group_by(group) |> arrange(order, .by_group = TRUE) |>
  mutate(xend = lead(x), yend = lead(y), kind_end = lead(kind)) |> ungroup() |> filter(!is.na(xend)) |>
  with_heads('B')
boxes = holocene |> group_by(site) |> summarise(xmin = min(x), xmax = max(x), ymin = min(y), ymax = max(y)) |>
  mutate(pad = .06 * pmax(xmax - xmin, ymax - ymin), xmin = xmin - pad, xmax = xmax + pad,
    ymin = ymin - pad, ymax = ymax + pad, letter = c(MORA = 'C', NOCA = 'D')[site],
    color = PAPER_SITE_COLORS[site])
# Both zooms the same size (Bills, 11 Nov 2026): the narrower box is widened about
# its centre to the height-to-width ratio of the wider one, so both keep equal
# scaling on the two axes and draw at the same size.
ZOOM_RATIO = min((boxes$ymax - boxes$ymin) / (boxes$xmax - boxes$xmin))
boxes = boxes |> mutate(half = pmax(xmax - xmin, (ymax - ymin) / ZOOM_RATIO) / 2, centre = (xmin + xmax) / 2,
  xmin = centre - half, xmax = centre + half) |> select(-half, -centre)
# Panel B is cropped tightly around the trajectories, with
# equal scaling on both axes so that directions are not distorted; its frame is
# a little taller than wide (width 0.84 of the height).
B_ASPECT = 1 / .84
xr = range(shown$x); yr = range(shown$y)
yr = yr + c(-1, 1) * .06 * diff(yr)
half_x = max(diff(xr) * 1.08, diff(yr) / B_ASPECT) / 2
lim_b = list(x = mean(xr) + c(-half_x, half_x), y = mean(yr) + c(-1, 1) * max(diff(yr), 2 * half_x * B_ASPECT) / 2)

# Lines run from the outline of one symbol to the outline of the next. The
# trims are worked out in mm on the page and turned into data units with the
# panel widths (B and the zooms have equal scaling on both axes, so directions
# on the page are those in the data). The zooms, about a third narrower on the
# page, take smaller symbols, lines and arrowheads, so that close centroids
# crowd less (Bills, 23 Nov 2026).
W_B = 186; W_ZOOM = 118
STYLE_B = list(size = 5, line = 1.8, head_cm = .45)
STYLE_ZOOM = list(size = 4, line = 1.5, head_cm = .35)
# Distance in mm from a symbol's centre to its outline in the outward direction
# (ux, uy), for stroke 1.5: R0 the circle radius at size 5 (it scales with R's
# font size, size times .pt plus the stroke), STROKE the outline. R's diamond
# (pch 23) has half-diagonal 1.2533 R0 and its square (pch 22) half-side 0.8862
# R0, both with the circle's area.
R0 = 2.33; STROKE = .37
edge_mm = function(kind, ux, uy, size) {
  r = R0 * (size * .pt + 1.5 * .stroke / 2) / (5 * .pt + 1.5 * .stroke / 2)
  shape = PERIOD_TYPE_SHAPES[kind]
  case_when(shape == 23 ~ (1.2533 * r + STROKE * sqrt(2)) / (abs(ux) + abs(uy)),
    shape == 22 ~ (.8862 * r + STROKE) / pmax(abs(ux), abs(uy)),
    TRUE ~ r + STROKE)
}
# The arrowhead outline reaches about 1 mm past the line end, so an arrow stops
# that much earlier: its tip then just touches the symbol. Where the gap between
# two symbols is too short for the full arrowhead and 1.5 mm of line, the head
# shrinks to fit (down to 1.5 mm), and where even that does not fit, the step is
# not drawn because the symbols all but touch. A line of a series without
# arrowheads is drawn wherever 0.5 mm of it fits between the symbols.
TIP_MM = 1
trim_steps = function(steps, mm, size, full_cm) {
  len = sqrt((steps$xend - steps$x)^2 + (steps$yend - steps$y)^2)
  ux = (steps$xend - steps$x) / len; uy = (steps$yend - steps$y) / len
  a = edge_mm(steps$kind, ux, uy, size) * mm
  b = edge_mm(steps$kind_end, -ux, -uy, size) * mm
  gap_mm = (len - a - b) / mm
  head_mm = pmin(10 * full_cm, gap_mm - TIP_MM - 1.5)
  head = steps$heads & head_mm >= 1.5
  b = b + ifelse(head, TIP_MM * mm, 0)
  steps |> mutate(head, head_cm = ifelse(head, round(head_mm / 10, 2), NA_real_), shrunk = head & head_mm < 10 * full_cm,
    drawn = head | (!heads & gap_mm > .5),
    x = x + ux * a, y = y + uy * a, xend = xend - ux * b, yend = yend - uy * b)
}

# In B every line carries one tag at its arrowhead end, "Holocene" or
# "Anthropocene" (Bills, 23 Nov 2026; tags at both ends, H. start, H. end,
# A. legacy and A. resurvey, earlier that day). Tags take the colour of their
# line, the predicted ones also in italics.
labels_b = shown |> group_by(group) |> arrange(order, .by_group = TRUE) |>
  mutate(label = if_else(order == max(order), era, '')) |> ungroup() |>
  transmute(x, y, label, series, fontface = if_else(type == 'predicted', 'italic', 'plain'), size = TEXT - 1.2)

trajectory_layers = function(points, steps, labels, xl, yl, width_mm, style, legend = FALSE) {
  mm = diff(xl) / width_mm
  st = trim_steps(steps, mm, style$size, style$head_cm)
  # One legend for B to D, collected under the zooms (Bills, 23 Nov 2026).
  key_fill = c('MORA', 'NOCA', 'Observed', 'Predicted')
  key_shape = c('Holocene-S', 'Holocene-C', 'Anthropocene')
  # Empty labels along every line and on every symbol: ggrepel keeps the real
  # labels off them, while pulling each label close to its own symbol.
  along = steps |> tidyr::crossing(f = seq(0, 1, length.out = 40)) |>
    transmute(x = x + f * (xend - x), y = y + f * (yend - y), label = '', series, fontface = 'plain', size = TEXT,
      point_size = 2.5)
  # And along every arrowhead, as wide as the head, so that no label box cuts
  # into one (Bills, 23 Nov 2026).
  tips = st |> filter(drawn, head) |> mutate(share = pmin(1, head_cm * 10 * mm / sqrt((xend - x)^2 + (yend - y)^2))) |>
    tidyr::crossing(f = seq(0, 1, length.out = 6)) |>
    transmute(x = xend - (xend - x) * share * f, y = yend - (yend - y) * share * f, label = '', series,
      fontface = 'plain', size = TEXT, point_size = head_cm * 12)
  labels = bind_rows(labels |> mutate(point_size = style$size + 1), along, tips)
  list(
    # One layer per arrowhead length, since a layer takes a single arrow.
    lapply(sort(unique(st$head_cm[st$drawn & st$head])), function(h)
      geom_segment(data = filter(st, drawn, head, head_cm == h), aes(x, y, xend = xend, yend = yend, color = series),
        linewidth = style$line, arrow = arrow(length = unit(h, 'cm'), type = 'closed'), show.legend = FALSE)),
    geom_segment(data = filter(st, drawn, !head), aes(x, y, xend = xend, yend = yend, color = series),
      linewidth = style$line, show.legend = FALSE),
    # Observed symbols filled in the park colour, predicted symbols open.
    geom_point(data = points, aes(x, y, color = series, fill = series, shape = kind), size = style$size, stroke = 1.5,
      show.legend = FALSE),
    geom_label_repel(data = labels, aes(x, y, label = label, color = series, fontface = fontface, size = size,
        point.size = point_size),
      fill = 'white', linewidth = 0, label.padding = unit(.08, 'lines'), box.padding = .12, point.padding = .05,
      force = 3, force_pull = 2, segment.size = .3, segment.color = 'grey60', min.segment.length = unit(.5, 'lines'),
      max.overlaps = Inf, max.iter = 200000, max.time = 10, seed = 3, lineheight = .9, xlim = xl, ylim = yl,
      show.legend = FALSE),
    # Legend keys only.
    geom_point(data = tibble(x = NA_real_, y = NA_real_, key = key_fill), aes(x, y, fill = key), shape = 21, na.rm = TRUE),
    geom_point(data = tibble(x = NA_real_, y = NA_real_, kind = key_shape), aes(x, y, shape = kind), na.rm = TRUE),
    scale_color_manual(values = PARK_COLORS, guide = 'none'),
    scale_fill_manual(values = c(PAPER_SITE_COLORS, MORA_observed = PARK_COLORS[['MORA_observed']],
        NOCA_observed = PARK_COLORS[['NOCA_observed']], MORA_predicted = 'white', NOCA_predicted = 'white',
        Observed = 'grey25', Predicted = 'white'),
      breaks = key_fill, name = NULL,
      guide = if (legend) guide_legend(order = 1, override.aes = list(shape = 21, size = 7, stroke = 1.5,
        color = c(NA, NA, 'grey25', 'grey25'))) else 'none'),
    scale_shape_manual(values = PERIOD_TYPE_SHAPES, breaks = key_shape, name = NULL,
      labels = function(b) unname(c(`Holocene-S` = 'Holocene stability periods',
        `Holocene-C` = 'Holocene climate-change periods', Anthropocene = 'Anthropocene')[b]),
      guide = if (legend) guide_legend(order = 2, override.aes = list(fill = 'grey60', color = 'grey10', size = 7, stroke = 1))
        else 'none'),
    scale_size_identity())
}
p_trajectories = ggplot() +
  geom_hline(yintercept = 0, color = 'grey90') + geom_vline(xintercept = 0, color = 'grey90') +
  trajectory_layers(shown, steps_b, labels_b, lim_b$x, lim_b$y, W_B, STYLE_B) +
  coord_cartesian(xlim = lim_b$x, ylim = lim_b$y, expand = FALSE) +
  labs(tag = 'B.', x = x_title, y = y_title) + theme_fig3 +
  theme(aspect.ratio = diff(lim_b$y) / diff(lim_b$x))

zoom_steps = holocene |> mutate(group = paste(site, era, type)) |> group_by(group) |> arrange(order, .by_group = TRUE) |>
  mutate(xend = lead(x), yend = lead(y), kind_end = lead(kind)) |> ungroup() |> filter(!is.na(xend)) |>
  mutate(panel = c(MORA = 'C', NOCA = 'D')[site]) |> group_by(panel) |> group_modify(\(d, k) with_heads(d, k$panel)) |>
  ungroup()
# Read by the caption: per panel and line, whether it has arrowheads and how many
# of its steps are drawn (none where the symbols overlap).
zoom_mm = boxes |> transmute(site, mm = (xmax - xmin) / W_ZOOM)
write_csv(bind_rows(
    trim_steps(steps_b, diff(lim_b$x) / W_B, STYLE_B$size, STYLE_B$head_cm) |> mutate(panel = 'B'),
    zoom_steps |> left_join(zoom_mm, by = 'site') |> group_by(site) |>
      group_modify(\(d, k) trim_steps(d, d$mm[1], STYLE_ZOOM$size, STYLE_ZOOM$head_cm)) |> ungroup()) |>
    group_by(panel, site, era, type) |>
    summarise(arrowheads = any(heads), steps = n(), drawn = sum(drawn), smaller_heads = sum(shrunk),
      .groups = 'drop'),
  out('figures/cca_trajectory_lines.csv'))
zoom = function(park) {
  d = holocene |> filter(site == park) |> mutate(group = paste(site, era, type))
  box = boxes[boxes$site == park, ]
  st = zoom_steps |> filter(site == park)
  lab = bind_rows(d |> filter(type == 'observed') |> transmute(x, y, label = lab, series, fontface = 'plain', size = TEXT - .6),
    d |> filter(type == 'predicted') |> transmute(x, y, label = '', series, fontface = 'plain', size = TEXT))
  ggplot() + trajectory_layers(d, st, lab, c(box$xmin, box$xmax), c(box$ymin, box$ymax), W_ZOOM, STYLE_ZOOM, legend = TRUE) +
    coord_cartesian(xlim = c(box$xmin, box$xmax), ylim = c(box$ymin, box$ymax), expand = FALSE) +
    # Title on two lines: a zoom can be narrower than a one-line title (Bills, 11 Nov 2026).
    labs(tag = paste0(box$letter, '.'), title = paste0(park, '\nHolocene periods'), x = zoom_x, y = zoom_y) +
    theme_fig3 + theme(legend.position = 'bottom', aspect.ratio = (box$ymax - box$ymin) / (box$xmax - box$xmin),
      plot.title = element_text(size = 30, face = 'bold', color = box$color, lineheight = .9), axis.text = element_text(size = 22))
}
# A and B on top; the zooms C (MORA) and D (NOCA) below, as large as the top
# panels allow, titled in the park's colour.
figure = (p_biplot | p_trajectories) / ((zoom('MORA') | zoom('NOCA')) + plot_layout(guides = 'collect') &
  theme(legend.position = 'bottom', legend.box = 'vertical', legend.spacing.y = unit(.2, 'cm'))) +
  plot_layout(heights = c(1, .9))
if (render_figures) {
  # cairo_pdf draws the arrows of the axis titles, which the default pdf device cannot.
  ggsave(fig('main', 'fig_cca_trajectories.pdf'), figure, width = 24, height = 24, device = cairo_pdf, bg = 'white')
  ggsave(fig('main', 'fig_cca_trajectories.png'), figure, width = 24, height = 24, dpi = 300, bg = 'white')
  ggsave(fig('supplementary', 'figS14_cca_biplot_unrotated.pdf'), biplot(FALSE), width = 12, height = 12.5,
    device = cairo_pdf, bg = 'white')
}
cat(sprintf('Figure 4: display rotation %.1f degrees; %d period centroids.\n', rotation$angle_degrees, nrow(centroids)))
