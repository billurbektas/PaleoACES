# Standalone integrity checks for cleaned MORA and NOCA vegetation outputs.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(dplyr); library(readr)})

check_site = function(site, occ_path, plot_path) {
  occ = read_csv(occ_path, show_col_types = FALSE)
  plots = read_csv(plot_path, show_col_types = FALSE)
  required = c("plot_id", "species", "period", "occurrence")
  if (!all(required %in% names(occ)))
    stop(site, " occurrence output is missing: ",
         paste(setdiff(required, names(occ)), collapse = ", "))
  if (any(!occ$occurrence %in% c(0, 1)) || anyNA(occ$plot_id))
    stop(site, " has invalid occurrence values or missing plot IDs.")
  if (anyDuplicated(occ[c("plot_id", "species", "period")]))
    stop(site, " has duplicate plot/species/period rows.")
  if (any(occ$species %in% c("unknown", "Unknown tree.", "Abies sp.", "Salix sp.")))
    stop(site, " contains an unsupported non-taxon label.")
  if (!all(unique(occ$plot_id) %in% unique(plots$plot_id)))
    stop(site, " occurrence output contains IDs absent from plot info.")
  past = unique(occ$plot_id[occ$period == "past"])
  present = unique(occ$plot_id[occ$period == "present"])
  if (!setequal(past, present))
    stop(site, " past and present paired-plot sets differ.")
  cat(site, ": ", length(past), " paired plots, ",
      n_distinct(occ$species), " species; ",
      length(setdiff(plots$plot_id, occ$plot_id)),
      " plot-info rows outside the paired universe; checks passed.\n", sep = "")
}

check_site("MORA", out("MORA_occ.csv"), out("MORA_plot_info.csv"))
check_site("NOCA", out("NOCA_occ.csv"), out("NOCA_plot_info.csv"))
