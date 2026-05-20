# Load disturbance shapefile
mora_disturbances = st_read(here("data/MORA_disturbances/MORA_1987_2017_V2_1_UTM.shp"))
noca_disturbances = st_read(here("data/MORA_disturbances/NOCA_1987_2017_V2_1_UTM.shp"))

# Get shapefiles
park_boundary = st_read(here("data/MORA_disturbances/records-2309935/Administrative Boundaries of National Park System Units.shp"))

# Get MORA data
MORA_occ = read_csv(here("output/MORA_occ.csv"))
MORA_plot_info = read_csv(here("output/MORA_plot_info.csv")) %>% 
  filter(plot_id %in% MORA_occ$plot_id)

# Get NOCA data
NOCA_occ = read_csv(here("output/NOCA_occ.csv"))
NOCA_plot_info = read_csv(here("output/NOCA_plot_info.csv")) %>%
  rename(latitude = Latitude, longitude = Longitude) %>%
  filter(plot_id %in% NOCA_occ$plot_id)

# Get boundaries 
mount_rainier = park_boundary %>% filter(PARKNAME == "Mount Rainier")
north_cascades = park_boundary %>% filter(PARKNAME == "North Cascades")

# Transform boundaries to match disturbance CRS
mount_rainier_tr = st_transform(mount_rainier, crs = st_crs(mora_disturbances))
north_cascades_tr = st_transform(north_cascades, crs = st_crs(noca_disturbances))

# MOUNT RAINIER ----
mora_coords_sf = MORA_plot_info %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Project points to disturbances CRS
mora_coords_dist = st_transform(mora_coords_sf, crs = st_crs(mora_disturbances))

# Create circular buffers of 100m radius
mora_plots = st_buffer(mora_coords_dist, dist = 100)

# Intersect plots with disturbances
mora_intersec = st_intersection(mora_plots, mora_disturbances) %>%
  filter(ChangeType == "Fire") %>%
  select(plot_id, elevation, Dist_year)

# Create fire dataframe
mora_fire = mora_intersec %>%
  left_join(MORA_plot_info, by = "plot_id") %>%
  select(plot_id, longitude, latitude, Dist_year)

# Add fire information to plot data
MORA_plot_info_fire = MORA_plot_info %>%
  left_join(mora_intersec) %>%
  mutate(burnt = !is.na(Dist_year))%>%
  st_drop_geometry()%>%
  select(-geometry)%>%
  distinct()

# NORTH CASCADES -----
noca_coords_sf = NOCA_plot_info %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Project points to disturbances CRS
noca_coords_dist = st_transform(noca_coords_sf, crs = st_crs(noca_disturbances))

# Create circular buffers of 100m radius
noca_plots = st_buffer(noca_coords_dist, dist = 100)

# Intersect plots with disturbances
noca_intersec = st_intersection(noca_plots, noca_disturbances) %>%
  filter(ChangeType == "Fire") %>%
  select(plot_id, elevation, Dist_year)

# Create fire dataframe
noca_fire = noca_intersec %>%
  left_join(NOCA_plot_info, by = "plot_id") %>%
  select(plot_id, longitude, latitude, Dist_year)

# Add fire information to plot data
NOCA_plot_info_fire = NOCA_plot_info %>%
  left_join(noca_intersec) %>%
  mutate(burnt = !is.na(Dist_year))%>%
  st_drop_geometry()%>%
  select(-geometry, -Dist_year)%>%
  distinct()

# Visualization plots
ggplot() +
  geom_sf(data = north_cascades_tr, color = "gray40") +
  geom_sf(data = noca_disturbances, aes(fill = ChangeType), color = "gray40") +
  geom_sf(data = noca_coords_dist)+
  theme_minimal() + 
  ggtitle("NOCA disturbances by change type and 1000 m² plot buffers")

ggplot() +
  geom_sf(data = mount_rainier_tr, color = "gray40") +
  geom_sf(data = mora_disturbances, aes(fill = ChangeType), color = "gray40") +
  geom_sf(data = mora_coords_dist)+
  theme_minimal() +
  ggtitle("MORA disturbances by change type and 1000 m² plot buffers")

# Final map
us_states = ne_states(country = "United States of America", returnclass = "sf")
washington = us_states %>% filter(name == "Washington")

png(filename = here("plot/study_sites_map.png"), height = 1500, width = 3000, res = 400)
ggplot() +
  geom_sf(data = washington, fill = "white", color = "#5E6973", linewidth = 0.5) +
  geom_sf(data = mount_rainier, fill = "#6ABEA7", color = "#6ABEA7", linewidth = 0.5, alpha = 0.8) +
  geom_sf(data = north_cascades, fill = "#6ABEA7", color = "#6ABEA7", linewidth = 0.5, alpha = 0.8) +
  #theme_minimal() +
  theme(panel.grid = element_blank(), panel.background = element_rect(fill = "white")) +
  annotation_scale(location = "bl", width_hint = 0.3)
dev.off()

write_csv(NOCA_plot_info_fire, file = here("output/NOCA_plot_info_fire.csv"))
write_csv(MORA_plot_info_fire, file = here("output/MORA_plot_info_fire.csv"))