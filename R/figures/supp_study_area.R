# Fig. S1 (Bills, 11 Nov 2026): the study area. (A) Washington State with the
# two parks. (B) Mount Rainier (MORA) and (C) North Cascades (NOCA): the
# legacy-resurvey plot pairs that enter the CCA, burned and unburned between
# the surveys, and the lakes whose cores give the Holocene records, by what
# each record contributes (vegetation from macrofossils, fire from charcoal).
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(sf); library(patchwork); library(ggrepel)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))
sf_use_s2(FALSE)

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

# Park boundaries (NPS administrative boundaries). The North Cascades National
# Park Service Complex includes the Ross Lake and Lake Chelan recreation areas.
parks = st_read(here('data/MORA_disturbances/records-2309935/Administrative Boundaries of National Park System Units.shp'),
    quiet = TRUE) |>
  filter(UNIT_CODE %in% c('MORA', 'NOCA', 'ROLA', 'LACH')) |>
  mutate(site = if_else(UNIT_CODE == 'MORA', 'MORA', 'NOCA')) |>
  # Joined in metres (UTM 10N) with a 30 m buffer in and out, so the units of the
  # complex merge without slivers along their shared borders.
  st_transform(32610) |> st_make_valid() |> st_buffer(30) |> group_by(site) |> summarise(.groups = 'drop') |>
  st_buffer(-30) |> st_transform(4326)
washington = st_as_sf(maps::map('state', 'washington', plot = FALSE, fill = TRUE)) |> st_transform(4326)

theme_map = theme_paleoaces(base_size = 14) +
  theme(panel.grid = element_blank(), axis.title = element_blank(), axis.text = element_text(size = 10),
    plot.title = element_text(size = 15, face = 'bold'), legend.position = 'bottom')
zoom = function(park) {
  box = st_bbox(filter(plots, site == park) |> st_as_sf(coords = c('lon', 'lat'), crs = 4326))
  pad = c(-.06, -.04, .06, .04)
  as.numeric(box) + pad
}
box_mora = zoom('MORA'); box_noca = zoom('NOCA')
boxes = tibble(site = c('MORA', 'NOCA'), xmin = c(box_mora[1], box_noca[1]), xmax = c(box_mora[3], box_noca[3]),
  ymin = c(box_mora[2], box_noca[2]), ymax = c(box_mora[4], box_noca[4]))

overview = ggplot() +
  geom_sf(data = washington, fill = 'grey95', color = 'grey40', linewidth = .4) +
  geom_sf(data = parks, aes(fill = site), color = NA, alpha = .45) +
  geom_rect(data = boxes, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, color = site),
    fill = NA, linewidth = .8) +
  geom_text(data = boxes, aes(x = xmax + .15, y = (ymin + ymax) / 2, label = site, color = site),
    hjust = 0, fontface = 'bold', size = 5) +
  scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') +
  scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
  coord_sf(expand = FALSE) + labs(tag = 'A.', title = 'Washington State') + theme_map

park_panel = function(park, tag, title) {
  b = boxes |> filter(site == park)
  ggplot() +
    geom_sf(data = filter(parks, site == park), fill = PAPER_SITE_COLORS[[park]], alpha = .12,
      color = PAPER_SITE_COLORS[[park]], linewidth = .5) +
    # Every plot and lake is drawn in both park panels (those outside the view are
    # clipped), so the two panels carry the same legend and it is shown once.
    geom_point(data = plots |> arrange(status == 'Burned between the surveys'),
      aes(lon, lat, color = status), size = 1.6, alpha = .85) +
    geom_point(data = lakes, aes(lon, lat, shape = role, fill = role), size = 5.2,
      color = 'black', stroke = .8) +
    geom_text_repel(data = filter(lakes, site == park), aes(lon, lat, label = name), size = 3.8,
      fontface = 'bold', min.segment.length = 0, box.padding = .9, point.padding = .5, seed = 42) +
    scale_color_manual(values = c(Unburned = 'grey45', `Burned between the surveys` = PAPER_FIRE_RED),
      name = 'Plot pairs', drop = FALSE) +
    scale_shape_manual(values = c(`Vegetation record` = 21, `Fire record (Walsh et al. 2017)` = 24,
      `Vegetation and fire record` = 23), name = 'Cored lakes', limits = roles, drop = FALSE) +
    scale_fill_manual(values = c(`Vegetation record` = '#1B7837', `Fire record (Walsh et al. 2017)` = '#E8A33D',
      `Vegetation and fire record` = '#1B7837'), name = 'Cored lakes', limits = roles, drop = FALSE) +
    coord_sf(xlim = c(b$xmin, b$xmax), ylim = c(b$ymin, b$ymax), expand = FALSE) +
    labs(tag = tag, title = title) + theme_map +
    guides(color = guide_legend(override.aes = list(size = 3.5, alpha = 1), order = 1),
      shape = guide_legend(order = 2), fill = guide_legend(order = 2))
}
counts = plots |> count(site, status)
title_of = function(park, name) {
  n = counts |> filter(site == park)
  sprintf('%s: %d plot pairs, %d burned', name, sum(n$n), sum(n$n[n$status != 'Unburned']))
}
p_mora = park_panel('MORA', 'B.', title_of('MORA', 'Mount Rainier'))
p_noca = park_panel('NOCA', 'C.', title_of('NOCA', 'North Cascades'))
figure = (overview | p_mora | p_noca) + plot_layout(widths = c(1, 1.15, 1.15), guides = 'collect') &
  theme(legend.position = 'bottom', legend.box = 'horizontal')
if (render_figures) {
  ggsave(fig('supplementary', 'figS01_study_area.pdf'), figure, width = 17, height = 7.5, device = cairo_pdf)
  ggsave(fig('supplementary', 'figS01_study_area.png'), figure, width = 17, height = 7.5, dpi = 300)
}
cat('Fig. S1: study area drawn with', nrow(plots), 'plot pairs and', nrow(lakes), 'cored lakes.\n')
