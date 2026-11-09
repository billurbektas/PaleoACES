# Offline regression checks for the authoritative 2026 NOCA tree patch.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(dplyr); library(readr); library(readxl)})

corrected = read_excel(
  here("data/NOCA/OriginalDataFiles_NOCA/2026_corrected_trees_for_Billur.xlsx"),
  sheet = "Trees"
)
audit = read_csv(out("NOCA_tree_correction_audit.csv"), show_col_types = FALSE)
composition_audit = read_csv(
  out("NOCA_tree_composition_audit.csv"), show_col_types = FALSE
)
study_exclusions = read_csv(
  out("NOCA_study_exclusions.csv"), show_col_types = FALSE
)
occ = read_csv(out("NOCA_occ.csv"), show_col_types = FALSE)
plot_info = read_csv(out("NOCA_plot_info.csv"), show_col_types = FALSE)
coordinate_audit = read_csv(
  out("NOCA_coordinate_collision_audit.csv"), show_col_types = FALSE
)

coordinate_collisions = plot_info %>%
  group_by(Latitude, Longitude) %>%
  filter(n_distinct(plot_id) > 1L) %>%
  ungroup()

stopifnot(
  nrow(corrected) == 2366L,
  n_distinct(corrected$Plot) == 54L,
  nrow(audit) == 54L,
  sum(audit$corrected_rows_added) == 2366L,
  !"unresolved_stems" %in% names(audit),
  sum(composition_audit$present_composition_changed) == 50L,
  setequal(composition_audit$plot_id, occ$plot_id),
  setequal(audit$plot_id[audit$final_status == "excluded"],
           c("HB5144", "MCAL5004", "ROSS3022")),
  n_distinct(occ$plot_id) == 305L,
  nrow(occ) == 1775L,
  n_distinct(occ$species) == 31L,
  !any(occ$species %in% c("unknown", "Unknown tree.", "Abies sp.", "Salix sp.")),
  setequal(study_exclusions$plot_id, c("BAK487", "BEAV6061", "CARI449", "CARI450")),
  !any(study_exclusions$plot_id %in% occ$plot_id),
  !any(study_exclusions$plot_id %in% plot_info$plot_id),
  !anyDuplicated(occ[c("plot_id", "species", "period")]),
  all(occ$occurrence %in% c(0, 1)),
  nrow(coordinate_audit) == 2L,
  setequal(coordinate_audit$plot_id, c("CARI449", "CARI450")),
  nrow(coordinate_collisions) == 0L,
  all(coordinate_audit$raw_latitude == 48.51429),
  setequal(coordinate_audit$raw_longitude, c(121.21725, -121.21725)),
  all(coordinate_audit$normalized_latitude == 48.51429),
  all(coordinate_audit$normalized_longitude == -121.21725),
  setequal(coordinate_audit$elevation, c(622, 1149)),
  all(coordinate_audit$shared_coordinate_count == 2L),
  all(coordinate_audit$elevation_range_m == 527),
  all(coordinate_audit$status ==
        "excluded—GPS problem; no verified coordinate correction"),
  all(grepl("GPS problem", study_exclusions$exclusion_reason[
    study_exclusions$plot_id %in% c("CARI449", "CARI450")]))
)
# Both dates, stage records and kept-plot accounting must share this exclusion.
for (name in c("NOCA_present_occ", "NOCA_past_occ", "NOCA_occ_stage")) {
  x = read_csv(out(paste0(name, ".csv")), show_col_types = FALSE)
  stopifnot(!any(c("CARI449", "CARI450") %in% x$plot_id))
}
tracking = read_csv(out("NOCA_plot_tracking.csv"), show_col_types = FALSE)
gps = tracking %>% filter(plot_id %in% c("CARI449", "CARI450"))
stopifnot(nrow(gps) == 2L, all(gps$period == "both"),
          all(gps$status == "removed"), all(grepl("GPS problem", gps$reason)))
cat(paste0(
  "NOCA tree correction checks passed: 2,366 stems, 54 corrected plots, ",
  "305 retained plots; CARI449/CARI450 excluded at both dates for GPS problems.\n"
))
