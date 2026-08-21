# Download CHELSA-TraCE21k paleo climate at the NOCA paleo lake (Panther Potholes).
# Mirrors the MORA ponds download in dowload_chelsa.R (lines 104-112): same
# getChelsa() variables, date range, frequency and version - only the coordinates
# and the output directory differ.
#
# Rchelsa is installed in the R 4.4 user library; add it so getChelsa() is found
# when running under R 4.5 (harmless if already on the path).
rchelsa_lib <- "~/Library/R/arm64/4.4/library"
if (dir.exists(rchelsa_lib)) .libPaths(c(.libPaths(), rchelsa_lib))

library(here)
library(terra)
library(Rchelsa)

dir.create(here("output/noca_climate"), showWarnings = FALSE, recursive = TRUE)

# Panther Potholes lake, Fourth of July Pass, North Cascades NP
# (Prichard et al. 2009: 48 deg 39' N, 121 deg 02' W)
panther_coords <- data.frame(lon = -121.0333, lat = 48.65)

## Paleo. Same parameters as the MORA ponds download, but the start is pushed
## back to 11,000 BP (c(1, -110)) so the climate covers the full NOCA core
## (oldest macrofossil sample ~10,600 BP); MORA used c(1, -60) = 6000 BP.
tasmin.paleo <- getChelsa("tasmin", coords = panther_coords,
                          startdate = c(1, -110), enddate = c(12, 19),
                          freq = "centennial", version = "chelsa_trace21k")
pre.paleo <- getChelsa("pr", coords = panther_coords,
                       startdate = c(1, -110), enddate = c(12, 19),
                       freq = "centennial", version = "chelsa_trace21k")

write.csv(tasmin.paleo, file = here("output/noca_climate/tasmin.paleo.ponds.csv"))
write.csv(pre.paleo,    file = here("output/noca_climate/pre.paleo.ponds.csv"))
