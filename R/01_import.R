# Get recent past and present data
load(here("data/MORA_tree_occ_cleaned_AT.rda"))

# Get paleo data
paleo_surveys = read_excel(here("data/DunwiddieMacrofossils.xlsx"), sheet = "MacrofossilData")
paleo_age = read_excel(here("data/DunwiddieMacrofossils.xlsx"), sheet = "AgeDepth")

# Get climate 
clim_mora = get(load(here("data/plots_climNA.rda")))

coords = plots %>% 
  select(lon, lat, id)

coords = as.data.frame(coords)

paleo_coords = 
  paleo_plots %>%
  select(lon, lat, Location)%>%
  distinct()%>%
  rename(id = Location)

# Your existing code
coords_sf = coords %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)
paleo_coords_sf = paleo_coords %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326)

# Combine to get bounding box
all_points = rbind(
  coords_sf %>% select(geometry),
  paleo_coords_sf %>% select(geometry)
)

# Get map tiles with natural features
osm_tiles = get_tiles(all_points, provider = "OpenTopoMap", zoom = 10)

# Extract coordinates for ggrepel
coords_for_repel = coords_sf %>%
  mutate(lon = st_coordinates(.)[,1],
         lat = st_coordinates(.)[,2])

paleo_coords_for_repel = paleo_coords_sf %>%
  mutate(lon = st_coordinates(.)[,1],
         lat = st_coordinates(.)[,2])

# Plot with geom_text_repel for labels
pdf(file = "plot/plots.pdf", width = 12, height = 10)
ggplot() +
  geom_spatraster_rgb(data = osm_tiles) +
  geom_sf(data = coords_sf, color = "grey40", size = 3) +
  # geom_text_repel(data = coords_for_repel, aes(x = lon, y = lat, label = id),
  #                 box.padding = 0.5,
  #                 point.padding = 0.3,
  #                 min.segment.length = 0,
  #                 max.overlaps = 10,
  #                 force = 2) +
  geom_sf(data = paleo_coords_sf, color = "black", size = 3) +
  geom_text_repel(data = paleo_coords_for_repel, aes(x = lon, y = lat, label = id),
                  size = 6,
                  color = "black",
                  box.padding = 0.5,
                  point.padding = 0.3,
                  min.segment.length = 0, 
                  max.overlaps = 30,
                  force = 2) +
  theme_minimal() +
  labs(x = "Longitude", y = "Latitude", 
       title = "Coordinates on Topographic Map")

dev.off()

# Find closest 10 grey points to each black point
closest_matches = map_dfr(1:nrow(paleo_coords_sf), function(i) {
  distances = st_distance(paleo_coords_sf[i,], coords_sf)
  closest_index = which.min(distances[1,])
  
  coords_sf[closest_index, ] %>%
    mutate(matched_to = paleo_coords_sf$id[i],
           distance = as.numeric(min(distances[1,])))
})
paleo_matches =closest_matches$id


# Create the plot highlighting matched pairs
# Create the plot highlighting matched pairs
ggplot() +
  geom_spatraster_rgb(data = osm_tiles) +
  geom_sf(data = coords_sf, color = "grey70", size = 2) +
  geom_sf(data = closest_matches, color = "darkgreen", size = 3) +
  geom_sf(data = paleo_coords_sf, color = "black", size = 3) +
  geom_text_repel(data = paleo_coords_for_repel, aes(x = lon, y = lat, label = id),
                  size = 6,
                  color = "black",
                  box.padding = 0.5,
                  point.padding = 0.3,
                  min.segment.length = 0, 
                  max.overlaps = 30,
                  force = 2) +
  theme_minimal() +
  labs(x = "Longitude", y = "Latitude", 
       title = "Coordinates on Topographic Map")

