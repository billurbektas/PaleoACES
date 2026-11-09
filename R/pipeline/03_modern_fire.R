# Anthropocene fire assignments for MORA and NOCA ----------------------------
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(sf)
  library(patchwork)
  library(maps)
})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

SURVEY_START = 1983L
SURVEY_END = 2015L
FIELD_VERIFIED_100M = c("HIBR2052", "HIBR2082", "STE2047")

# MORA: retain the existing LandTrendr fire method ----------------------------
mora_disturbances = st_read(
  here("data/MORA_disturbances/MORA_1987_2017_V2_1_UTM.shp"), quiet = TRUE
)
MORA_occ = read_csv(out("MORA_occ.csv"), show_col_types = FALSE)
MORA_plot_info = read_csv(out("MORA_plot_info.csv"), show_col_types = FALSE) %>%
  filter(plot_id %in% unique(MORA_occ$plot_id))

mora_points = MORA_plot_info %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
  st_transform(st_crs(mora_disturbances))

mora_fire_hits = suppressWarnings(st_intersection(
  st_buffer(mora_points, dist = 100),
  mora_disturbances %>% filter(ChangeType == "Fire")
)) %>%
  st_drop_geometry() %>%
  group_by(plot_id) %>%
  summarise(Dist_year = min(Dist_year, na.rm = TRUE), .groups = "drop")

MORA_plot_info_fire = MORA_plot_info %>%
  left_join(mora_fire_hits, by = "plot_id") %>%
  mutate(burnt = !is.na(Dist_year)) %>%
  arrange(plot_id)

if (nrow(MORA_plot_info_fire) != n_distinct(MORA_plot_info_fire$plot_id)) {
  stop("MORA fire assignment produced duplicate plot IDs.")
}

# NOCA: Wilson et al. (2024) method on the PaleoACES plot universe ------------
fire_dir = here("data/MORA_disturbances/fire_mapping_for_Billur")
NOCA_occ = read_csv(out("NOCA_occ.csv"), show_col_types = FALSE)
noca_ids = sort(unique(str_to_upper(NOCA_occ$plot_id)))
NOCA_plot_info = read_csv(out("NOCA_plot_info.csv"), show_col_types = FALSE) %>%
  transmute(
    plot_id = str_to_upper(plot_id),
    longitude = if_else(Longitude > 0, -Longitude, Longitude),
    latitude = Latitude,
    elevation
  ) %>%
  filter(plot_id %in% noca_ids) %>%
  distinct(plot_id, .keep_all = TRUE)

if (!setequal(NOCA_plot_info$plot_id, noca_ids)) {
  stop("NOCA plot-info IDs do not exactly match NOCA_occ.csv.")
}

wilson_join = read_csv(
  file.path(fire_dir, "0_All_Plots_Wildfire_Join.csv"), show_col_types = FALSE
) %>%
  transmute(
    plot_id = str_to_upper(str_trim(Name)),
    wildfire_year = if_else(
      !is.na(CAL_YEAR) & between(as.integer(CAL_YEAR), SURVEY_START, SURVEY_END),
      as.integer(CAL_YEAR), NA_integer_
    ),
    prescribed_burn_year = if_else(
      !is.na(Prescribed.burn.year) &
        between(as.integer(Prescribed.burn.year), SURVEY_START, SURVEY_END),
      as.integer(Prescribed.burn.year), NA_integer_
    )
  )

if (anyDuplicated(wilson_join$plot_id)) {
  stop("The supplied Wilson spatial join contains duplicate plot names.")
}

wilson_published = read_csv(
  here("data/NOCA/NOCA_fires_fromWilson.csv"), show_col_types = FALSE
) %>%
  filter(Data.Type == "Resurvey") %>%
  transmute(
    plot_id = str_to_upper(str_trim(Plot)),
    wilson_burnt = Fires == "Burned"
  )

if (nrow(wilson_published) != 369L || anyDuplicated(wilson_published$plot_id)) {
  stop("Expected 369 unique resurvey plots in NOCA_fires_fromWilson.csv.")
}

# Reconstruct the published rule independently: polygon membership plus three
# within-100 m plots whose field notes showed recent fire evidence.
wilson_reproduced = wilson_published %>%
  left_join(wilson_join, by = "plot_id") %>%
  mutate(
    spatial_join_available = plot_id %in% wilson_join$plot_id,
    natural_polygon = !is.na(wildfire_year),
    prescribed_polygon = !is.na(prescribed_burn_year),
    field_verified_100m = plot_id %in% FIELD_VERIFIED_100M,
    reproduced_burnt = natural_polygon | prescribed_polygon | field_verified_100m
  )

missing_join_ids = wilson_reproduced %>%
  filter(!spatial_join_available) %>% pull(plot_id)
if (!setequal(missing_join_ids, c("COPP6040", "THOR221", "THOR225")) ||
    any(wilson_reproduced$wilson_burnt[!wilson_reproduced$spatial_join_available])) {
  stop("Unexpected Wilson publication plots missing from the supplied spatial join.")
}
if (!identical(wilson_reproduced$wilson_burnt,
               wilson_reproduced$reproduced_burnt)) {
  bad = wilson_reproduced %>%
    filter(wilson_burnt != reproduced_burnt) %>% pull(plot_id)
  stop("Wilson fire reconstruction disagrees for: ", paste(bad, collapse = ", "))
}
if (sum(wilson_reproduced$reproduced_burnt) != 38L ||
    sum(wilson_reproduced$natural_polygon |
        wilson_reproduced$prescribed_polygon) != 35L) {
  stop("Wilson fire totals must be 35 polygon plots plus 3 field-verified plots.")
}

NOCA_plot_info_fire = NOCA_plot_info %>%
  left_join(wilson_join, by = "plot_id") %>%
  left_join(wilson_published, by = "plot_id") %>%
  mutate(
    natural_polygon = !is.na(wildfire_year),
    prescribed_polygon = !is.na(prescribed_burn_year),
    field_verified_100m = plot_id %in% FIELD_VERIFIED_100M,
    spatial_join_available = plot_id %in% wilson_join$plot_id,
    reproduced_burnt = natural_polygon | prescribed_polygon | field_verified_100m,
    burnt = coalesce(wilson_burnt, reproduced_burnt),
    fire_basis = case_when(
      !spatial_join_available & !is.na(wilson_burnt) ~
        "published_unburned_spatial_join_missing",
      natural_polygon & prescribed_polygon ~ "natural_and_prescribed_polygons",
      natural_polygon ~ "natural_fire_polygon",
      prescribed_polygon ~ "prescribed_fire_polygon",
      field_verified_100m ~ "within_100m_field_verified",
      TRUE ~ "unburned"
    ),
    assignment_source = if_else(
      is.na(wilson_burnt), "received_spatial_join", "Wilson_2024_published"
    )
  ) %>%
  select(plot_id, longitude, latitude, elevation, burnt,
         wildfire_year, prescribed_burn_year, fire_basis, assignment_source,
         spatial_join_available) %>%
  arrange(plot_id)

if (!setequal(NOCA_plot_info_fire$plot_id, noca_ids) ||
    nrow(NOCA_plot_info_fire) != 305L ||
    anyDuplicated(NOCA_plot_info_fire$plot_id)) {
  stop("NOCA fire output must contain exactly 305 unique modeled plots.")
}
if (sum(NOCA_plot_info_fire$burnt) != 32L ||
    sum(!NOCA_plot_info_fire$burnt) != 273L) {
  stop("Expected 32 burned and 273 unburned PaleoACES NOCA plots.")
}

# Universe and assignment comparison -----------------------------------------
study_exclusions = read_csv(out("NOCA_study_exclusions.csv"),
                            show_col_types = FALSE) %>%
  select(plot_id, study_exclusion_reason = exclusion_reason)
comparison_ids = union(noca_ids, wilson_published$plot_id)
NOCA_fire_Wilson2024_comparison = tibble(plot_id = sort(comparison_ids)) %>%
  left_join(wilson_reproduced %>%
              select(plot_id, wilson_burnt, reproduced_burnt,
                     spatial_join_available), by = "plot_id") %>%
  left_join(NOCA_plot_info_fire %>%
              select(plot_id, paleoaces_burnt = burnt), by = "plot_id") %>%
  left_join(study_exclusions, by = "plot_id") %>%
  mutate(
    universe_status = case_when(
      plot_id %in% noca_ids & plot_id %in% wilson_published$plot_id ~ "shared",
      plot_id %in% noca_ids ~ "PaleoACES_only",
      TRUE ~ "Wilson_only"
    ),
    assignment_discrepancy = case_when(
      universe_status != "shared" ~ NA,
      paleoaces_burnt != wilson_burnt ~ TRUE,
      TRUE ~ FALSE
    ),
    discrepancy_reason = case_when(
      universe_status == "PaleoACES_only" ~ "not in Wilson publication plot universe",
      universe_status == "Wilson_only" & !is.na(study_exclusion_reason) ~
        paste0("excluded from PaleoACES: ", study_exclusion_reason),
      universe_status == "Wilson_only" ~ "not retained in PaleoACES paired-plot universe",
      assignment_discrepancy ~ "fire assignment differs",
      !coalesce(spatial_join_available, TRUE) ~
        "published unburned assignment; supplied spatial-join row missing",
      TRUE ~ NA_character_
    )
  ) %>%
  select(plot_id, universe_status, paleoaces_burnt, wilson_burnt,
         reproduced_burnt, spatial_join_available, assignment_discrepancy,
         study_exclusion_reason, discrepancy_reason)

universe_counts = count(NOCA_fire_Wilson2024_comparison, universe_status)
observed_universe_counts = setNames(universe_counts$n, universe_counts$universe_status)
expected_universe_counts = c(shared = 303L, PaleoACES_only = 2L, Wilson_only = 66L)
if (!identical(observed_universe_counts[names(expected_universe_counts)],
               expected_universe_counts)) {
  stop("Unexpected PaleoACES/Wilson plot-universe comparison counts.")
}

write_csv(MORA_plot_info_fire, out("MORA_plot_info_fire.csv"))
write_csv(NOCA_plot_info_fire, out("NOCA_plot_info_fire.csv"))
write_csv(NOCA_plot_info_fire,
          out("NOCA_fire_assignment_audit.csv"))
write_csv(NOCA_fire_Wilson2024_comparison,
          out("NOCA_fire_Wilson2024_comparison.csv"))

cat("NOCA fire assignments: 305 plots; 32 burned, 273 unburned.\n")
cat("Wilson comparison: 303 shared, 2 PaleoACES-only, 66 Wilson-only; ",
    "no shared fire discrepancies.\n", sep = "")

# PaleoACES adaptation of Wilson et al. (2024) Figure 1 ----------------------
shape_dir = file.path(fire_dir, "shapefiles ")
wildfires = st_read(file.path(shape_dir, "fires/NOCA_Wildfire_History.shp"),
                    quiet = TRUE) %>%
  filter(!is.na(CAL_YEAR), between(as.integer(CAL_YEAR), SURVEY_START, SURVEY_END)) %>%
  st_make_valid()
prescribed = st_read(file.path(shape_dir, "fires/Prescribed_burn_history.shp"),
                     quiet = TRUE) %>%
  filter(!is.na(CAL_YEAR), between(as.integer(CAL_YEAR), SURVEY_START, SURVEY_END)) %>%
  st_make_valid()
treatments = st_read(file.path(shape_dir, "fires/Fire_treatment_history.shp"),
                     quiet = TRUE) %>%
  filter(!is.na(TreatYear), between(as.integer(TreatYear), SURVEY_START, SURVEY_END)) %>%
  st_make_valid()
park = st_read(file.path(shape_dir, "park/NOCA_Park_boundary.shp"), quiet = TRUE) %>%
  st_make_valid()

map_crs = "+proj=lcc +lon_0=-95 +lat_1=49 +lat_2=77 +datum=NAD83 +units=m +no_defs"
wildfires_map = st_transform(wildfires, map_crs)
prescribed_map = bind_rows(
  st_transform(prescribed, map_crs) %>% select(geometry),
  st_transform(treatments, map_crs) %>% select(geometry)
)
park_map = st_transform(park, map_crs)
noca_points_map = NOCA_plot_info_fire %>%
  mutate(fire_status = if_else(burnt, "Burned", "Unburned")) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) %>%
  st_transform(map_crs)

bb = st_bbox(park_map)
scale_x0 = unname(bb["xmax"] - 33000)
scale_y0 = unname(bb["ymax"] - 28000)

p_map = ggplot() +
  geom_sf(data = park_map, fill = "white", color = "black", linewidth = 0.45) +
  geom_sf(data = wildfires_map, aes(fill = "Natural fire"),
          color = "#A9342A", linewidth = 0.25, alpha = 0.55) +
  geom_sf(data = prescribed_map, aes(fill = "Prescribed fire"),
          color = "#E88A00", linewidth = 0.25, alpha = 0.45) +
  geom_sf(data = noca_points_map,
          aes(shape = fire_status), color = "black", size = 1.65,
          stroke = 0.75) +
  scale_fill_manual(values = c("Natural fire" = "#E99989",
                               "Prescribed fire" = "#F6C667"), name = NULL) +
  scale_shape_manual(values = c("Burned" = 4, "Unburned" = 1), name = NULL) +
  annotate("segment", x = scale_x0, xend = scale_x0 + 10000,
           y = scale_y0, yend = scale_y0, linewidth = 0.7) +
  annotate("segment", x = c(scale_x0, scale_x0 + 10000),
           xend = c(scale_x0, scale_x0 + 10000),
           y = scale_y0 - 900, yend = scale_y0 + 900, linewidth = 0.7) +
  annotate("text", x = scale_x0 + 5000, y = scale_y0 + 2400,
           label = "10 km", size = 3) +
  annotate("segment", x = unname(bb["xmax"] - 5000),
           xend = unname(bb["xmax"] - 5000),
           y = unname(bb["ymax"] - 19000),
           yend = unname(bb["ymax"] - 7000),
           arrow = arrow(length = unit(0.24, "cm")), linewidth = 0.9) +
  annotate("text", x = unname(bb["xmax"] - 5000),
           y = unname(bb["ymax"] - 4500), label = "N",
           fontface = "bold", size = 4) +
  coord_sf(crs = map_crs, datum = st_crs(4326), expand = FALSE) +
  labs(
    title = "NOCA fire history - 305 PaleoACES plots",
    caption = str_wrap(paste0(
      "Wilson et al. (2024) fire method and symbology applied to the 305 retained PaleoACES plots. ",
      "Natural and prescribed fires shown for 1983-2015; X = burned, circle = unburned."
    ), width = 105)
  ) +
  theme_bw(base_size = 10) +
  theme(
    panel.grid.major = element_line(color = "grey75", linetype = "dashed", linewidth = 0.25),
    panel.background = element_rect(fill = "white"),
    legend.position = c(0.03, 0.97),
    legend.justification = c(0, 1),
    legend.background = element_rect(fill = scales::alpha("white", 0.86), color = "black"),
    plot.title = element_text(face = "bold", size = 14),
    plot.caption = element_text(hjust = 0, size = 8)
  )

world = map_data("world")
mean_lon = mean(NOCA_plot_info_fire$longitude)
mean_lat = mean(NOCA_plot_info_fire$latitude)
p_inset = ggplot(world, aes(long, lat, group = group)) +
  geom_polygon(fill = "grey82", color = "grey35", linewidth = 0.15) +
  geom_point(data = data.frame(long = mean_lon, lat = mean_lat, group = 1),
             aes(long, lat), inherit.aes = FALSE, shape = 8, size = 2.4) +
  coord_map("ortho", orientation = c(48, -121, 0)) +
  theme_void() +
  theme(panel.border = element_rect(fill = NA, color = "black", linewidth = 0.4))

noca_fire_map = p_map + inset_element(
  p_inset, left = 0.02, bottom = 0.02, right = 0.30, top = 0.29,
  align_to = "panel"
)
if (render_figures) {
  ggsave(fig("supplementary", "NOCA_fire_map_Wilson2024_PaleoACES.pdf"),
         noca_fire_map, width = 7.5, height = 10, bg = "white")
}
