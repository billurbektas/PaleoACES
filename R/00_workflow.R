library(here)
library(tidyverse)
library(conflicted)
library(readxl)
library(lubridate)
library(TNRS)
library(splines)
library(vegan)
library(ggrepel)
library(factoextra)
library(FactoMineR)
library(betareg)
library(ggpubr)
library(gt)
library(e1071)
library(DBI)
library(RSQLite)
library(visNetwork)
library(sf)
library(maptiles)
library(tidyterra)
library(khroma)
library(rayshader)
library(elevatr)
library(terra)
library(rnaturalearth)
library(rnaturalearthdata)
library(ggspatial)
library(devtools)
library(Rchelsa)
library(reticulate)
library(corrplot)

# Python setup for CHELSA
py_install("chelsa-cmip6", pip = TRUE)
chelsa_cmip6 = import('chelsa_cmip6')

here()
conflict_prefer("select", "dplyr")
conflict_prefer("filter", "dplyr")
conflicts_prefer(rayshader::plot_map)
conflicts_prefer(base::intersect)
conflicts_prefer(base::union)

source(here("R/functions.R"))

color_era = c("paleo" = "#44AA99",
              "past" = "#88CCEE",
              "present" = "#CC6677"
              )
color_era2 = c("holocene_6000" = "#117733",
               "holocene_1000" = "#44AA99",
              "past" = "#88CCEE",
              "present" = "#CC6677"
)
color_era3 = c("holocene" = "#785EF0",
              "anthropocene" = "#DC267F"
)
color_site = c("JayBath" = "#117733",
               "LogWallow" = "#A8E69A",
               "ReflectionPond" = "#356F90"
               )
color_mt = c("MORA"="#648FFF", "NOCA"="#FE6100")

## FUNCTIONS ----
calculate_mess = function(reference_matrix, projection_matrix) {
  mess_scores = matrix(NA, nrow = nrow(projection_matrix), ncol = ncol(projection_matrix))
  
  for(i in 1:ncol(projection_matrix)) {
    ref_var = reference_matrix[, i]
    proj_var = projection_matrix[, i]
    
    ref_min = min(ref_var, na.rm = TRUE)
    ref_max = max(ref_var, na.rm = TRUE)
    ref_range = ref_max - ref_min
    
    mess_scores[, i] = ifelse(proj_var < ref_min, 
                              100 * (proj_var - ref_min) / ref_range,
                              ifelse(proj_var > ref_max,
                                     100 * (ref_max - proj_var) / ref_range,
                                     100))
  }
  
  apply(mess_scores, 1, min, na.rm = TRUE)
}
