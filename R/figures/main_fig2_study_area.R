# Figure 2 (Bills, 11 Nov 2026; Fig. S1 until then): the study area. (A) Mount
# Rainier National Park (MORA) and (B) the North Cascades National Park Service
# Complex (NOCA): the legacy-resurvey plot pairs that enter the CCA, burned and
# unburned between the surveys, and the lakes whose cores give the Holocene
# records, by what each record contributes (vegetation from macrofossils, fire
# from charcoal). The two park maps sit side by side at full size, each with its
# own scale bar and north arrow, and Washington State, USA, is an inset in the
# corner of the NOCA map that holds no plots.
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
    lat = c(46.9114, 46.9198, 46.9231), lon = -c(121.6571, 121.5886, 121.5836), role = 'Fire record (Walsh et al. 2017)'))
stopifnot(nrow(lakes) == 7L)
roles = c('Vegetation record', 'Fire record (Walsh et al. 2017)', 'Vegetation and fire record')
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
  'Panther Potholes',     6500,   5500)
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

PAPER = 22  # base font size; the figure is drawn at 19 x 11 inches
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

# The inset: Washington State, with the two map extents.
boxes = bind_rows(lapply(names(ext), function(p) {
  e = ext[[p]]
  st_as_sf(st_as_sfc(st_bbox(c(xmin = e[1], ymin = e[2], xmax = e[3], ymax = e[4]), crs = UTM))) |>
    st_transform(WA_CRS) |> mutate(site = p)
}))
box_sides = bind_rows(lapply(seq_len(nrow(boxes)), function(i) {
  b = st_bbox(boxes[i, ]); tibble(site = boxes$site[i], x = b[['xmax']], y = (b[['ymin']] + b[['ymax']]) / 2)
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
  geom_sf(data = parks |> st_transform(WA_CRS), aes(fill = site), color = NA, alpha = .8) +
  geom_sf(data = boxes, aes(color = site), fill = NA, linewidth = .8) +
  geom_text(data = box_sides, aes(x = x + 12000, y = y, label = site, color = site), hjust = 0,
    fontface = 'bold', size = 6.2) +
  place(-120.3, 45.62, 'OREGON', size = 4.2, color = 'grey40', fontface = 'italic') +
  place(-119.0, 49.13, 'CANADA', size = 4.2, color = 'grey40', fontface = 'italic') +
  scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
  scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
  scale_bar(wa_extent[['xmax']] - 205000, wa_extent[['ymin']] + 32000, km = 100, n = 1, height = 9000, text_size = 4.6) +
  coord_sf(crs = WA_CRS, xlim = wa_extent[c('xmin', 'xmax')], ylim = wa_extent[c('ymin', 'ymax')], expand = FALSE,
    datum = NA) +
  labs(title = 'Washington State, USA') +
  theme_void(base_size = PAPER) +
  theme(panel.background = element_rect(fill = OCEAN, color = NA),
    plot.background = element_rect(fill = 'white', color = 'grey40', linewidth = .6),
    plot.title = element_text(size = PAPER - 3, face = 'bold', hjust = .5, margin = margin(t = 5, b = 4)),
    plot.margin = margin(2, 6, 6, 6))

park_panel = function(park, tag, title, bar_km, bar_corner, arrow_corner) {
  e = ext[[park]]; w = e[3] - e[1]; h = e[4] - e[2]
  at = function(corner, fx, fy) c(e[1] + corner[1] * w + fx, e[2] + corner[2] * h + fy)
  bar = at(bar_corner, 0, 0); arrow = at(arrow_corner, 0, 0)
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
      breaks = c('Unburned', 'Burned between the surveys'), name = 'Plot pairs',
      guide = guide_legend(override.aes = list(size = 5.5), order = 1)) +
    scale_shape_manual(values = c(`Vegetation record` = 21, `Fire record (Walsh et al. 2017)` = 24,
      `Vegetation and fire record` = 23), name = 'Cored lakes', limits = roles, drop = FALSE,
      guide = guide_legend(order = 2)) +
    scale_fill_manual(values = c(`Vegetation record` = '#1B7837', `Fire record (Walsh et al. 2017)` = '#E8A33D',
      `Vegetation and fire record` = '#1B7837'), name = 'Cored lakes', limits = roles, drop = FALSE,
      guide = guide_legend(order = 2)) +
    scale_bar(bar[1], bar[2], km = bar_km, n = 2, height = h * .012, text_size = 6) +
    north_arrow(arrow[1], arrow[2], h * .085) +
    coord_sf(crs = UTM, xlim = e[c(1, 3)], ylim = e[c(2, 4)], expand = FALSE) +
    labs(tag = tag, title = title) + theme_map
}
p_mora = park_panel('MORA', 'A.', 'Mount Rainier National Park (MORA)', bar_km = 10,
  bar_corner = c(.66, .035), arrow_corner = c(.935, .83)) +
  scale_x_continuous(breaks = seq(-121.9, -121.5, .1)) + scale_y_continuous(breaks = seq(46.7, 47, .1))
p_noca = park_panel('NOCA', 'B.', 'North Cascades National Park\nService Complex (NOCA)', bar_km = 20,
  bar_corner = c(.66, .935), arrow_corner = c(.935, .76)) +
  scale_x_continuous(breaks = seq(-121.6, -120.6, .2)) + scale_y_continuous(breaks = seq(48.3, 49, .1)) +
  # The inset over the south-west corner of the NOCA map, where no plot lies.
  inset_element(overview, left = .005, bottom = .005, right = .45, top = .36, align_to = 'panel')

figure = (p_mora | p_noca) + plot_layout(widths = c(1, 1), guides = 'collect') &
  theme(legend.position = 'bottom', legend.box = 'vertical', legend.box.just = 'left', legend.title = element_text(size = PAPER, face = 'bold'),
    legend.text = element_text(size = PAPER - 2), legend.spacing.x = unit(.3, 'cm'))
if (render_figures) {
  ggsave(fig('main', 'fig_study_area.pdf'), figure, width = 19, height = 11, device = cairo_pdf)
  ggsave(fig('main', 'fig_study_area.png'), figure, width = 19, height = 11, dpi = 300)
}
cat('Figure 2: study area drawn with', nrow(plots), 'plot pairs and', nrow(lakes), 'cored lakes.\n')
