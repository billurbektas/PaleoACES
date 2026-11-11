# Figure 2 (Bills, 11 Nov 2026; Fig. S1 until then): the study area. (A)
# Washington State, USA, with the two parks. (B) Mount Rainier National Park
# (MORA) and (C) the North Cascades National Park Service Complex (NOCA): the
# legacy-resurvey plot pairs that enter the CCA, burned and unburned between the
# surveys, and the lakes whose cores give the Holocene records, by what each
# record contributes (vegetation from macrofossils, fire from charcoal). The two
# park maps have the same size, grid lines at about the same spacing, the same
# 10 km scale bar and the same north arrow. The Washington map and the legend sit
# side by side above them (Bills, 11 Nov 2026).
# Sources are cited in the caption, not on the figure.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(sf); library(patchwork); library(ggrepel)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))
sf_use_s2(FALSE)

# The park maps are drawn in UTM zone 10N, which covers both parks, so the scale
# bars hold across each map and grid north is true north within 2 degrees.
UTM = 32610
# The overview in an equal-area projection centred on Washington.
WA_CRS = '+proj=aea +lat_0=47.2 +lon_0=-120.5 +lat_1=45.8 +lat_2=48.8 +datum=WGS84 +units=m +no_defs'

# The plot pairs of the analysis, with their coordinates and fire status.
coordinates = bind_rows(
  read_csv(out('MORA_plot_info.csv'), show_col_types = FALSE) |> transmute(key = toupper(plot_id), lon = longitude, lat = latitude),
  read_csv(out('NOCA_plot_info.csv'), show_col_types = FALSE) |> transmute(key = toupper(plot_id), lon = Longitude, lat = Latitude))
plots = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE) |>
  filter(period_type == 'Anthropocene') |>
  transmute(site, key = toupper(plot_id), status = if_else(burned, 'Burned between the surveys', 'Unburned')) |>
  left_join(coordinates, by = 'key', relationship = 'one-to-one')
# Rule: the Anthropocene plot pairs of config.R, every one located.
stopifnot(nrow(plots) == sum(ANTHROPOCENE_PAIRS), !anyNA(plots[c('lon', 'lat')]))

# The cored lakes. Vegetation lakes from the paleoclimate extraction points; the
# Sunrise Ridge fire lakes from Walsh et al. (2017), Table 1.
lake_names = c(JayBath = 'Jay Bath', LogWallow = 'Log Wallow', ReflectionPond = 'Reflection Pond',
  PantherPotholes = 'Panther Potholes')
lakes = bind_rows(
  read_csv(out('chelsa_paleo_ponds.csv'), show_col_types = FALSE) |> distinct(lake, site, lon, lat) |>
    transmute(site, name = lake_names[lake], lon, lat,
      role = if_else(lake == 'PantherPotholes', 'Vegetation and fire record', 'Vegetation record')),
  tibble(site = 'MORA', name = c('Shadow Lake', 'Sunrise Lake', 'Little Sunrise Lake'),
    lat = c(46.9114, 46.9198, 46.9231), lon = -c(121.6571, 121.5886, 121.5836), role = 'Fire record'))
stopifnot(nrow(lakes) == 7L)
roles = c('Vegetation record', 'Fire record', 'Vegetation and fire record')
# Where each lake name sits relative to its lake (metres east and north), so the
# names of the three close lakes in each MORA cluster stay apart.
label_offsets = tribble(
  ~name,                 ~dx,    ~dy,
  'Jay Bath',            -4600,  -2400,
  'Log Wallow',          -1500,   3000,
  'Reflection Pond',      3600,  -2900,
  'Shadow Lake',         -4300,   2500,
  'Sunrise Lake',         2600,  -3400,
  'Little Sunrise Lake', -1200,   4300,
  'Panther Potholes',     8000,   6500)
in_utm = function(d) {
  xy = st_coordinates(st_transform(st_as_sf(d, coords = c('lon', 'lat'), crs = 4326, remove = FALSE), UTM))
  mutate(d, x = xy[, 1], y = xy[, 2])
}
plots = in_utm(plots)
lakes = in_utm(lakes) |> left_join(label_offsets, by = 'name', relationship = 'one-to-one')

# Park boundaries (NPS administrative boundaries). The North Cascades National
# Park Service Complex includes the Ross Lake and Lake Chelan recreation areas.
parks = st_read(here('data/MORA_disturbances/records-2309935/Administrative Boundaries of National Park System Units.shp'),
    quiet = TRUE) |>
  filter(UNIT_CODE %in% c('MORA', 'NOCA', 'ROLA', 'LACH')) |>
  mutate(site = if_else(UNIT_CODE == 'MORA', 'MORA', 'NOCA')) |>
  # Joined in metres with a 30 m buffer in and out, so the units of the complex
  # merge without slivers along their shared borders.
  st_transform(UTM) |> st_make_valid() |> st_buffer(30) |> group_by(site) |> summarise(.groups = 'drop') |>
  st_buffer(-30)

# Washington and its neighbours for the overview, cut to the region.
region = st_bbox(c(xmin = -126.2, ymin = 44.9, xmax = -115.6, ymax = 49.9), crs = 4326)
land = function(map, names) st_as_sf(maps::map(map, names, plot = FALSE, fill = TRUE)) |> st_transform(4326) |> st_make_valid() |>
  st_crop(region) |> st_transform(WA_CRS)
washington = land('state', 'washington')
neighbours = bind_rows(land('state', c('oregon', 'idaho')), land('world', 'Canada'))

PAPER = 22  # base font size; the figure is drawn at 19.5 x 16 inches
OCEAN = '#DCE9F3'
theme_map = theme_paleoaces(base_size = PAPER) +
  theme(panel.grid = element_line(color = 'grey88', linewidth = .3), axis.title = element_blank(),
    axis.text = element_text(size = PAPER - 5, color = 'grey30'), axis.ticks = element_line(color = 'grey60'),
    plot.title = element_text(size = PAPER + 2, face = 'bold', lineheight = .95, margin = margin(b = 8)),
    plot.tag = element_text(size = PAPER + 6, face = 'bold'), panel.border = element_rect(color = 'grey40', fill = NA),
    legend.position = 'bottom')

# A scale bar of n alternating segments, lower left at (x0, y0), in metres.
scale_bar = function(x0, y0, km, n = 2, height, text_size = 6) {
  step = km * 1000 / n
  bars = tibble(xmin = x0 + (seq_len(n) - 1) * step, xmax = xmin + step, ymin = y0, ymax = y0 + height,
    fill = rep(c('black', 'white'), length.out = n))
  ticks = tibble(x = x0 + (0:n) * step, label = c(format(km / n * (0:(n - 1)), trim = TRUE), paste(km, 'km')))
  list(geom_rect(data = bars, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = bars$fill,
      color = 'black', linewidth = .4, inherit.aes = FALSE),
    geom_text(data = ticks, aes(x = x, y = y0 + height * 2.1, label = label), size = text_size, vjust = 0,
      hjust = c(.5, rep(.5, n - 1), .3), color = 'grey15', inherit.aes = FALSE))
}
# A north arrow of the given height (metres), tip at (x, y + height).
north_arrow = function(x, y, height, text_size = 7.5) {
  w = height * .5
  half = function(side) tibble(x = c(x, x + side * w / 2, x), y = c(y + height, y, y + height * .3))
  list(geom_polygon(data = half(-1), aes(x, y), fill = 'black', color = 'black', linewidth = .4, inherit.aes = FALSE),
    geom_polygon(data = half(1), aes(x, y), fill = 'white', color = 'black', linewidth = .4, inherit.aes = FALSE),
    annotate('text', x = x, y = y + height * 1.12, label = 'N', fontface = 'bold', size = text_size, vjust = 0))
}

# Map extents: the plots and lakes of each park with a margin, in metres.
extent = function(park, pad) {
  b = st_bbox(c(xmin = min(c(plots$x[plots$site == park], lakes$x[lakes$site == park])),
    xmax = max(c(plots$x[plots$site == park], lakes$x[lakes$site == park])),
    ymin = min(c(plots$y[plots$site == park], lakes$y[lakes$site == park])),
    ymax = max(c(plots$y[plots$site == park], lakes$y[lakes$site == park]))))
  as.numeric(b) + pad
}
ext = list(MORA = extent('MORA', c(-2500, -3200, 2500, 2800)), NOCA = extent('NOCA', c(-3000, -3000, 3000, 5000)))
# Both park maps the same size (Bills, 11 Nov 2026): each extent is widened to one
# common height-to-width ratio, and both panels are drawn PARK_WIDTH inches wide.
RATIO = max(sapply(ext, function(e) (e[4] - e[2]) / (e[3] - e[1])))
ext = lapply(ext, function(e) { d = (RATIO * (e[3] - e[1]) - (e[4] - e[2])) / 2; e[2] = e[2] - d; e[4] = e[4] + d; e })
PARK_WIDTH = 8.1
panel_size = theme(panel.widths = unit(PARK_WIDTH, 'in'), panel.heights = unit(PARK_WIDTH * RATIO, 'in'))

# The locator map: Washington State with the two parks, each named to its right
# (no boxes around the parks, Bills, 11 Nov 2026).
parks_wa = parks |> st_transform(WA_CRS)
park_labels = bind_rows(lapply(unique(parks_wa$site), function(p) {
  b = st_bbox(parks_wa[parks_wa$site == p, ]); tibble(site = p, x = b[['xmax']], y = (b[['ymin']] + b[['ymax']]) / 2)
}))
place = function(lon, lat, label, ...) {
  xy = st_coordinates(st_transform(st_sfc(st_point(c(lon, lat)), crs = 4326), WA_CRS))
  annotate('text', x = xy[1], y = xy[2], label = label, ...)
}
wa_extent = st_bbox(st_transform(st_as_sfc(st_bbox(c(xmin = -125.1, ymin = 45.45, xmax = -116.75, ymax = 49.25),
  crs = 4326)), WA_CRS))
overview = ggplot() +
  geom_sf(data = neighbours, fill = 'grey87', color = 'grey65', linewidth = .25) +
  geom_sf(data = washington, fill = 'white', color = 'grey25', linewidth = .5) +
  geom_sf(data = parks_wa, aes(fill = site), color = NA, alpha = .8) +
  geom_text(data = park_labels, aes(x = x + 12000, y = y, label = site, color = site), hjust = 0,
    fontface = 'bold', size = 7) +
  place(-120.3, 45.62, 'OREGON', size = 4.8, color = 'grey40', fontface = 'italic') +
  place(-119.0, 49.13, 'CANADA', size = 4.8, color = 'grey40', fontface = 'italic') +
  scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
  scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
  # Low enough that the bar and its labels stay clear of the Oregon border (Bills).
  scale_bar(wa_extent[['xmax']] - 180000, wa_extent[['ymin']] + 6000, km = 100, n = 1, height = 9000, text_size = 5.2) +
  coord_sf(crs = WA_CRS, xlim = wa_extent[c('xmin', 'xmax')], ylim = wa_extent[c('ymin', 'ymax')], expand = FALSE,
    datum = NA) +
  labs(tag = 'A.', title = 'Washington State, USA') +
  theme_void(base_size = PAPER) +
  theme(panel.background = element_rect(fill = OCEAN, color = NA),
    plot.tag = element_text(size = PAPER + 6, face = 'bold'),
    plot.title = element_text(size = PAPER + 2, face = 'bold', hjust = .5, margin = margin(b = 8)),
    plot.margin = margin(6, 6, 16, 6),
    # Larger than before (Bills): 6.4 inches wide.
    panel.widths = unit(6.4, 'in'),
    panel.heights = unit(6.4 * (wa_extent[['ymax']] - wa_extent[['ymin']]) / (wa_extent[['xmax']] - wa_extent[['xmin']]), 'in'))

park_panel = function(park, tag, title, grid) {
  e = ext[[park]]; w = e[3] - e[1]; h = e[4] - e[2]
  L = filter(lakes, site == park)
  ggplot() +
    geom_sf(data = filter(parks, site == park), fill = PAPER_SITE_COLORS[[park]], alpha = .1,
      color = PAPER_SITE_COLORS[[park]], linewidth = .8) +
    # Every plot and lake is drawn in both park panels (those outside the view are
    # clipped), so the two panels carry the same legend and it is shown once.
    # Each plot with a thin white halo, so overlapping plots stay distinct.
    geom_point(data = plots, aes(x, y), color = 'white', size = 4.1) +
    geom_point(data = plots |> arrange(status == 'Burned between the surveys'), aes(x, y, color = status), size = 3.2) +
    geom_segment(data = L, aes(x = x, y = y, xend = x + dx * .75, yend = y + dy * .75), color = 'grey20', linewidth = .5) +
    geom_label(data = L, aes(x + dx, y + dy, label = name), size = 6.4, fontface = 'bold', fill = alpha('white', .85),
      label.size = 0, label.padding = unit(.15, 'lines')) +
    geom_point(data = lakes, aes(x, y, shape = role, fill = role), color = 'black', stroke = 1, size = 7.5) +
    scale_color_manual(values = c(Unburned = 'grey35', `Burned between the surveys` = PAPER_FIRE_RED),
      breaks = c('Unburned', 'Burned between the surveys'), name = 'Anthropocene plot pairs',
      guide = guide_legend(override.aes = list(size = 7), order = 1, ncol = 1)) +
    scale_shape_manual(values = c(`Vegetation record` = 21, `Fire record` = 24,
      `Vegetation and fire record` = 23), name = 'Holocene cored lakes', limits = roles, drop = FALSE,
      guide = guide_legend(order = 2, ncol = 1, override.aes = list(size = 9))) +
    scale_fill_manual(values = c(`Vegetation record` = '#1B7837', `Fire record` = '#E8A33D',
      `Vegetation and fire record` = '#1B7837'), name = 'Holocene cored lakes', limits = roles, drop = FALSE,
      guide = guide_legend(order = 2, ncol = 1, override.aes = list(size = 9))) +
    # The same north arrow and 10 km bar in both maps, side by side in the
    # bottom-left corner (Bills, 11 Nov 2026). Sized and placed on the panel, which
    # is the same in both, so they sit at the same spot.
    north_arrow(e[1] + .05 * w, e[2] + .035 * h, h * .075) +
    scale_bar(e[1] + .11 * w, e[2] + .035 * h, km = 10, n = 2, height = h * .012, text_size = 6) +
    # Grid lines every `grid` degrees in both directions. NOCA covers about twice the
    # distance of MORA, so a step twice as large spaces its ticks like those of MORA
    # on the page (Bills, 11 Nov 2026).
    scale_x_continuous(breaks = seq(-122, -120, grid)) + scale_y_continuous(breaks = seq(46, 49.5, grid)) +
    coord_sf(crs = UTM, xlim = e[c(1, 3)], ylim = e[c(2, 4)], expand = FALSE) +
    labs(tag = tag, title = title) + theme_map + panel_size
}
p_mora = park_panel('MORA', 'B.', 'Mount Rainier National\nPark (MORA)', grid = .1)
p_noca = park_panel('NOCA', 'C.', 'North Cascades National Park\nService Complex (NOCA)', grid = .2)

# On top, the Washington map and the legend side by side. Below, the two park maps.
figure = overview + guide_area() + p_mora + p_noca +
  plot_layout(design = 'AB\nCD', guides = 'collect') &
  theme(legend.box = 'horizontal', legend.box.just = 'top', legend.title = element_text(size = PAPER + 2, face = 'bold'),
    legend.text = element_text(size = PAPER), legend.title.position = 'top', legend.spacing.x = unit(1, 'cm'),
    legend.key.size = unit(1.1, 'cm'),
    # A right margin moves the legend left within its area, towards the Washington map (Bills).
    legend.box.margin = margin(0, 3, 0, 0, 'cm'))
if (render_figures) {
  ggsave(fig('main', 'fig_study_area.pdf'), figure, width = 19.5, height = 16, device = cairo_pdf)
  ggsave(fig('main', 'fig_study_area.png'), figure, width = 19.5, height = 16, dpi = 300)
}
cat('Figure 2: study area drawn with', nrow(plots), 'plot pairs and', nrow(lakes), 'cored lakes.\n')
