library(here)
library(tidyverse)
library(conflicted)
library(readxl)
library(TNRS)
library(splines)
library(vegan)
library(ggrepel)
library(factoextra)
library(FactoMineR)
library(betareg)
library(ggpubr)
library(gt)
library(sjSDM)
library(sf)
library(maptiles)
library(tidyterra)

here()
conflict_prefer("select", "dplyr")
conflict_prefer("filter", "dplyr")
conflicts_prefer(base::union)

color_era = c("paleo" = "#44AA99",
              "past" = "#88CCEE",
              "present" = "#CC6677"
              )
color_era2 = c("holocene_6000" = "#117733",
               "holocene_1000" = "#44AA99",
              "past" = "#88CCEE",
              "present" = "#CC6677"
)
color_era3 = c("holocene" = "#44AA99",
              "anthropocene" = "#CC6677"
)
color_site = c("JayBath" = "#117733",
               "LogWallow" = "#A8E69A",
               "ReflectionPond" = "#356F90"
               )

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
