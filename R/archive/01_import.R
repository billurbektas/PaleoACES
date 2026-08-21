# Load disturbance shapefile
mora_disturbances = st_read(here("data/MORA_disturbances/MORA_1987_2017_V2_1_UTM.shp"))
noca_disturbances = st_read(here("data/MORA_disturbances/NOCA_1987_2017_V2_1_UTM.shp"))

# Get shapefiles
park_boundary = st_read(here("data/MORA_disturbances/records-2309935/Administrative Boundaries of National Park System Units.shp"))

# Get MORA data
load(here("data/MORA_overstory.rda"))
load(here("data/MORA_plots.rda"))
MORA_occ = over_long %>% filter(count>0)
MORA_plot_info = plot_info %>% filter(plot_id %in% MORA_occ$plot_id)

# Get NOCA data
NOCA_occ = read_csv(here("output/NOCA_occ.csv"))
NOCA_plot_info = read_csv(here("output/NOCA_plot_info.csv")) %>%
  rename(latitude = Latitude, longitude = Longitude) %>%
  filter(plot_id %in% NOCA_occ$plot_id)

# Get paleo data
paleo_plots = data.frame(Location = c("JayBath", "LogWallow", "ReflectionPond")) %>%
  mutate(latitude = case_when(Location == "JayBath" ~ 46.7667,
                              Location == "LogWallow" ~ 46.7667,
                              Location == "ReflectionPond" ~ 46.7667)) %>%
  mutate(longitude = case_when(Location == "JayBath" ~ -121.7667,
                               Location == "LogWallow" ~ -121.75,
                               Location == "ReflectionPond" ~ -121.7167))

paleo_coords = paleo_plots %>%
  select(longitude, latitude, Location) %>%
  distinct() %>%
  rename(id = Location)

paleo_coords_sf = paleo_coords %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

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

mora_elevation_raster = get_elev_raster(mount_rainier, z = 11)
mora_elevation_matrix = raster_to_matrix(mora_elevation_raster)
mora_shadow = ray_shade(mora_elevation_matrix)
mora_amb = ambient_shade(mora_elevation_matrix)
mora_extent = ext(mora_elevation_raster)
mora_crs = crs(mora_elevation_raster)

mora_coords_transformed = st_transform(mora_coords_sf, mora_crs)
paleo_coords_transformed = st_transform(paleo_coords_sf, mora_crs)
mora_coords_xy = st_coordinates(mora_coords_transformed)
paleo_xy = st_coordinates(paleo_coords_transformed)

terrain_elevations = raster::extract(mora_elevation_raster, mora_coords_transformed)
paleo_terrain_elevations = raster::extract(mora_elevation_raster, paleo_coords_transformed)

# Assign colors based on fire status
mora_point_colors = ifelse(MORA_plot_info_fire$burnt, "#FF4500", "#edeec9")

## MORA rayshader ----
if(!file.exists("mount_rainier.png"))
{mora_elevation_matrix %>%
    sphere_shade(texture=create_texture("#7CFFC4","#5E6973","#6ABEA7","#5E6973","#9FFFF5")) %>%
    add_shadow(mora_shadow, 0.5) %>%
    add_shadow(mora_amb, 0) %>%
    plot_3d(mora_elevation_matrix, zscale = 10, fov = 0, theta = 30, phi = 45,
            windowsize = c(3600, 3000))
  Sys.sleep(0.7)
  
  render_points(extent = mora_extent, 
                lat = mora_coords_xy[,2], long = mora_coords_xy[,1],
                altitude = 3000, zscale = 10, color = mora_point_colors, size = 30)
  
  for(i in 1:nrow(mora_coords_xy)) {
    start_altitude = terrain_elevations[i]
    
    render_path(extent = mora_extent,
                lat = c(mora_coords_xy[i,2], mora_coords_xy[i,2]),
                long = c(mora_coords_xy[i,1], mora_coords_xy[i,1]),
                altitude = c(start_altitude, 3000), zscale = 10,
                color = mora_point_colors[i], linewidth = 4)
  }
  
  render_points(extent = mora_extent,
                lat = paleo_xy[,2], long = paleo_xy[,1], 
                altitude = 5000, zscale = 10, color = "#edeec9", size = 70)
  
  for(i in 1:nrow(paleo_xy)) {
    start_altitude = paleo_terrain_elevations[i]
    
    render_path(extent = mora_extent,
                lat = c(paleo_xy[i,2], paleo_xy[i,2]),
                long = c(paleo_xy[i,1], paleo_xy[i,1]),
                altitude = c(start_altitude, 5000), zscale = 10,
                color = "#edeec9", linewidth = 15)
  }
  
  render_compass(position = "E", compass_radius = 160)
  render_snapshot("mount_rainier.png", clear = TRUE)
}

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

noca_elevation_raster = get_elev_raster(noca_coords_sf, z = 11)
noca_elevation_matrix = raster_to_matrix(noca_elevation_raster)
noca_shadow = ray_shade(noca_elevation_matrix)
noca_amb = ambient_shade(noca_elevation_matrix)
noca_extent = ext(noca_elevation_raster)
noca_crs = crs(noca_elevation_raster)

noca_coords_transformed = st_transform(noca_coords_sf, noca_crs)
noca_coords_xy = st_coordinates(noca_coords_transformed)
terrain_elevations = raster::extract(noca_elevation_raster, noca_coords_transformed)

# Assign colors based on fire status
noca_point_colors = ifelse(NOCA_plot_info_fire$burnt, "#FF4500", "#edeec9")

## NOCA rayshader ----
if(!file.exists("northern_cascades.png"))
{
  noca_elevation_matrix %>%
    sphere_shade(texture=create_texture("#7CFFC4","#5E6973","#6ABEA7","#5E6973","#9FFFF5")) %>%
    add_shadow(noca_shadow, 0.5) %>%
    add_shadow(noca_amb, 0) %>%
    plot_3d(noca_elevation_matrix, zscale = 10, fov = 0, theta = 30, phi = 45,
            windowsize = c(3600, 3000))
  Sys.sleep(0.7)
  
  render_points(extent = noca_extent, 
                lat = noca_coords_xy[,2], long = noca_coords_xy[,1],
                altitude = 3000, zscale = 10, color = noca_point_colors, size = 40)
  
  for(i in 1:nrow(noca_coords_xy)) {
    start_altitude = terrain_elevations[i]
    
    render_path(extent = noca_extent,
                lat = c(noca_coords_xy[i,2], noca_coords_xy[i,2]),
                long = c(noca_coords_xy[i,1], noca_coords_xy[i,1]),
                altitude = c(start_altitude, 3000), zscale = 10,
                color = noca_point_colors[i], linewidth = 4)
  }
  
  render_compass(position = "E", compass_radius = 160)
  render_snapshot("northern_cascades.png", clear = TRUE)
}

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


