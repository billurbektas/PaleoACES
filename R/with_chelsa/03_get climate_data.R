library("terra")
library("tidyverse")
library("readxl")
library("lubridate")
library("e1071")
library("DBI")
library("RSQLite")
library("visNetwork")
library("sf")
library("devtools")
library(tidyverse)
library(ggrepel)
library(maptiles)
library(sf)
library(terra)
library(tidyterra)  # This package provides geom_spatraster_rgb
#install_git("https://gitlabext.wsl.ch/karger/rchelsa.git")
library(Rchelsa)
library(reticulate)
py_install("chelsa-cmip6", pip=T)
chelsa_cmip6 <- import('chelsa_cmip6')

#https://gitlabext.wsl.ch/karger/chelsa_cmip6/-/tree/master/
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

# Get data from CHELSA ----
coords = plots %>% 
  select(lon, lat)

coords = as.data.frame(coords)
paleo_coords = 
  paleo_plots %>%
  select(lon, lat)%>%
  distinct()

## Paleo ----
tasmin.paleo = getChelsa("tasmin",coords=coords, startdate= c(1, -60), enddate=c(12, 19), freq = "centennial", version = "chelsa_trace21k")
pre.paleo = getChelsa("pr",coords=coords, startdate= c(1, -60), enddate=c(12, 19), freq = "centennial", version = "chelsa_trace21k")
write.csv(tasmin.paleo, file = here("output/tasmin.paleo.csv"))
write.csv(pre.paleo, file = here("output/pre.paleo.csv"))

tasmin.paleo = getChelsa("tasmin",coords=paleo_coords, startdate= c(1, -60), enddate=c(12, 19), freq = "centennial", version = "chelsa_trace21k")
pre.paleo = getChelsa("pr",coords=paleo_coords, startdate= c(1, -60), enddate=c(12, 19), freq = "centennial", version = "chelsa_trace21k")
write.csv(tasmin.paleo, file = here("output/tasmin.paleo.ponds.csv"))
write.csv(pre.paleo, file = here("output/pre.paleo.ponds.csv"))

# GET Present ----
tasmin.present = getChelsa("tasmin",coords=coords, startdate=as.Date("1981-1-1"), enddate=as.Date("2020-12-31"), freq = "daily")
write.csv(tasmin.present, file = here("output/tasmin.present.csv"))
pre.present = getChelsa("pr",coords=coords, startdate=as.Date("1981-1-1"), enddate=as.Date("2019-12-31"), freq = "daily")
pre.presentcc = getChelsa("pr",coords=coords, startdate=as.Date("2019-12-31"), enddate=as.Date("2020-1-4"), freq = "daily")
pre.presentc = getChelsa("pr",coords=coords, startdate=as.Date("2020-1-6"), enddate=as.Date("2020-12-31"), freq = "daily")

write.csv(pre.present, file = here("output/pre.present.csv"))

## Precipitation ----
pr = getChelsa('pr',coords=coords, startdate=as.Date("2005-1-1"), enddate=as.Date("2020-1-1"))
prc = getChelsa('pr',coords=coords, startdate=as.Date("2020-1-1"), enddate=as.Date("2020-1-4"))
prc2 = getChelsa('pr',coords=coords, startdate=as.Date("2020-1-6"), enddate=as.Date("2020-3-1"))
prc3 = getChelsa('pr',coords=coords, startdate=as.Date("2020-3-3"), enddate=as.Date("2020-4-4"))
prc4 = getChelsa('pr',coords=coords, startdate=as.Date("2020-4-6"), enddate=as.Date("2020-5-1"))
prc5 = getChelsa('pr',coords=coords, startdate=as.Date("2020-5-3"), enddate=as.Date("2020-6-1"))
prc6 = getChelsa('pr',coords=coords, startdate=as.Date("2020-6-3"), enddate=as.Date("2020-11-4"))
prc7 = getChelsa('pr',coords=coords, startdate=as.Date("2020-11-6"), enddate=as.Date("2020-12-31"))

prx = 
  list(pr, prc, prc2, prc3, prc4, prc5, prc6, prc7) %>% 
  map(get.df) %>% 
  bind_rows()
