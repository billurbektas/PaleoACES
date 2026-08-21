# Load required data (assumes fire info script has been run)
MORA_plot_info_fire = read_csv(here("output/MORA_plot_info_fire.csv"))
NOCA_plot_info_fire = read_csv(here("output/NOCA_plot_info_fire.csv"))

# Load disturbance shapefile
mora_disturbances = st_read(here("data/MORA_disturbances/MORA_1987_2017_V2_1_UTM.shp"))
noca_disturbances = st_read(here("data/MORA_disturbances/NOCA_1987_2017_V2_1_UTM.shp"))

# Get shapefiles
park_boundary = st_read(here("data/MORA_disturbances/records-2309935/Administrative Boundaries of National Park System Units.shp"))

# Get boundaries 
mount_rainier = park_boundary %>% filter(PARKNAME == "Mount Rainier")
north_cascades = park_boundary %>% filter(PARKNAME == "North Cascades")

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

# MOUNT RAINIER ----
mora_coords_sf = MORA_plot_info_fire %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

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
noca_coords_sf = NOCA_plot_info_fire %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

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