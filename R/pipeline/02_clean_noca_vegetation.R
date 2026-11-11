source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(readxl)
  library(ggalluvial)
})
source(here("R/helpers/functions.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

# Get overstory ----
## Get resurveys ----
NOCA_plots = read_csv("data/NOCA/NOCA_plots_fromWilson.csv")%>%
  rename(plot_id = `2015.Plot.Name`, 
         plot_id_past = `1980.Plot.Name`,
         elevation = `2015.Elevation.m`)%>%
  select(-Resurvey.Year)%>%
  filter(!plot_id %in% c("Supp2026","ROSS4001REF", "Supp5127"))%>% #ASK!
  mutate(plot_id = toupper(plot_id))%>%
  filter(!is.na(Latitude))

# Initialize plot tracking dataframe
plot_tracking = data.frame(
  plot_id = character(),
  plot_id_past = double(),
  period = character(),
  status = character(),
  reason = character(),
  stringsAsFactors = FALSE
)

### Clean the present vegetation surveys ----
NOCA_present_splib =
  read_excel("data/NOCA/NOCA_vegetation_fromJHRL.xlsx", sheet = "Plant List") %>%
  rename(past_species_abv = `Legacy code`, 
         present_species_abv = `Resurvey code`, 
         species = `Resurvey species name`
  )%>%
  select(past_species_abv, present_species_abv, species)%>%
  distinct()%>%
  mutate(species = case_when(present_species_abv == "ABPE" ~ "Abies sp.",
                             present_species_abv == "THSE" ~ "Tsuga heterophylla",
                             present_species_abv == "CHNO" ~ "Chamaecyparis nootkatensis",
                             present_species_abv == "PISI" ~ "Picea sitchensis",
                             present_species_abv == "POAI" ~ "Populus balsamifera",
                             present_species_abv == "SARA" ~ "Sambucus racemosa",
                             present_species_abv == "SAXX" ~ "Salix sp.",
                             present_species_abv == "THPL" ~ "Thuja plicata",
                             .default = species))%>%
  mutate(species = str_to_sentence(species))%>%
  mutate(species = ifelse(species == "Thuja plicata.", "Thuja plicata", species))

# These labels are not identified tree species. Remove them before constructing
# any cleaned occurrence or stage table; the received files themselves remain
# immutable. Salix is also excluded as an understory/shrub taxon by the shared
# consolidation rules, but filtering it here keeps the NOCA cleaner species-only.
NOCA_UNSUPPORTED_TAXA = c("Unknown tree.", "unknown", "Abies sp.", "Salix sp.")
is_supported_noca_taxon = function(x) {
  !is.na(x) & !x %in% NOCA_UNSUPPORTED_TAXA
}

NOCA_present_raw =
  read_excel(here("data/NOCA/NOCA_vegetation_fromJHRL.xlsx"), sheet = "Tree Data") %>%
  transmute(
    plot_id = str_to_upper(str_trim(as.character(`Plot ID`))),
    present_species_abv = str_to_upper(str_trim(as.character(species_abv))),
    DBH = suppressWarnings(as.numeric(DBH))
  )

# The 2026 workbook is an authoritative correction layer, not a complete tree
# table. Most of its plots were omitted from the JHRL master; six old plot-ID
# groups must be retired to avoid retaining mislabeled or mixed records.
NOCA_tree_correction_file = here(
  "data/NOCA/OriginalDataFiles_NOCA/2026_corrected_trees_for_Billur.xlsx"
)
required_correction_columns = c("Plot", "Species", "DBH")
correction_columns = names(read_excel(NOCA_tree_correction_file, sheet = "Trees", n_max = 0))
if (!all(required_correction_columns %in% correction_columns)) {
  stop("Corrected NOCA tree workbook is missing columns: ",
       paste(setdiff(required_correction_columns, correction_columns), collapse = ", "))
}

NOCA_present_corrected = read_excel(NOCA_tree_correction_file, sheet = "Trees") %>%
  transmute(
    plot_id = str_to_upper(str_trim(as.character(Plot))),
    present_species_abv = str_to_upper(str_trim(as.character(Species))),
    DBH = suppressWarnings(as.numeric(DBH))
  )

if (nrow(NOCA_present_corrected) != 2366L ||
    n_distinct(NOCA_present_corrected$plot_id) != 54L) {
  stop("Unexpected corrected tree workbook size: expected 2,366 stems in 54 plots.")
}
if (anyNA(NOCA_present_corrected$plot_id) ||
    anyNA(NOCA_present_corrected$present_species_abv) ||
    anyNA(NOCA_present_corrected$DBH)) {
  stop("Corrected tree workbook contains a missing plot, species code, or numeric DBH.")
}

correction_groups = list(
  BBCR6065 = "BBCR6075",
  HB5134 = "HB5144",
  STE2022 = "STE2020",
  STE2077 = "STE2072",
  PYRA1015 = c("PYRA1013", "PYRA1015"),
  ROSS3048 = c("ROSS3044", "ROSS3048")
)
stem_multiset = function(x) {
  x %>% count(present_species_abv, DBH, name = "n") %>%
    arrange(present_species_abv, DBH, n)
}
for (source_id in names(correction_groups)) {
  old_stems = NOCA_present_raw %>% filter(plot_id == source_id) %>% stem_multiset()
  corrected_stems = NOCA_present_corrected %>%
    filter(plot_id %in% correction_groups[[source_id]]) %>% stem_multiset()
  if (!identical(old_stems, corrected_stems)) {
    stop("Corrected stems do not exactly reconcile with source group ", source_id, ".")
  }
}

corrected_plot_ids = sort(unique(NOCA_present_corrected$plot_id))
retired_source_ids = names(correction_groups)
replacement_ids = union(corrected_plot_ids, retired_source_ids)
NOCA_present_patched = bind_rows(
  NOCA_present_raw %>% filter(!plot_id %in% replacement_ids),
  NOCA_present_corrected
)
for (target_id in corrected_plot_ids) {
  final_stems = NOCA_present_patched %>%
    filter(plot_id == target_id) %>% stem_multiset()
  expected_stems = NOCA_present_corrected %>%
    filter(plot_id == target_id) %>% stem_multiset()
  if (!identical(final_stems, expected_stems)) {
    stop("Corrected target ", target_id,
         " was not replaced exactly once in the patched stem table.")
  }
}
retired_only_ids = setdiff(retired_source_ids, corrected_plot_ids)
if (any(NOCA_present_patched$plot_id %in% retired_only_ids)) {
  stop("Retired erroneous source IDs remain in the patched stem table: ",
       paste(intersect(retired_only_ids, NOCA_present_patched$plot_id), collapse = ", "))
}

NOCA_present = NOCA_present_patched %>%
  left_join(NOCA_present_splib, by = "present_species_abv")

unresolved_corrected = NOCA_present_corrected %>%
  anti_join(NOCA_present_splib %>% distinct(present_species_abv),
            by = "present_species_abv")
if (!identical(sort(unique(unresolved_corrected$present_species_abv)), "FRAXINUS?")) {
  stop("Unexpected unresolved species code(s) in corrected tree workbook: ",
       paste(sort(unique(unresolved_corrected$present_species_abv)), collapse = ", "))
}

# Track present plots with no supported species data, then remove every
# unsupported record before occurrences are built.
takeout_plots_present =
  NOCA_present %>%
  group_by(plot_id)%>%
  summarize(any_supported_taxon = any(is_supported_noca_taxon(species)),
            .groups = "drop") %>%
  filter(!any_supported_taxon) %>%
  pull(plot_id)%>%
  unique()

# Add to tracking
plot_tracking = bind_rows(plot_tracking,
                          data.frame(
                            plot_id = takeout_plots_present,
                            plot_id_past = NA,
                            period = "present",
                            status = "removed",
                            reason = "no species recorded"
                          ))

cat("There are", length(takeout_plots_present), "to take out because there are no species recorded.")

NOCA_present = NOCA_present %>%
  filter(!plot_id %in% takeout_plots_present,
         is_supported_noca_taxon(species))

# Get all present plots from NOCA_plots (includes plots with no trees)
all_present_plots_raw = NOCA_plots %>% filter(!plot_id %in% takeout_plots_present) %>% pull(plot_id)%>% unique()
present_plots_with_trees = NOCA_present %>%
  filter(!is.na(species)) %>%
  pull(plot_id) %>%
  unique()

# Present overstory (tree) occurrences: count = number of identified tree stems.
NOCA_present_occ_trees = NOCA_present %>%
  select(plot_id, species) %>%
  group_by(plot_id, species) %>% summarize(count = n(), .groups = "drop")

# --- Present seedlings (JHRL "Seedlings" sheet) ---
# Mirrors the MORA approach: a species is present in a plot if it occurs as a
# tree OR a seedling. Height tallies 10-50 + 51-140 cm (== MORA size class 1).
# This restores past<->present symmetry, since the legacy TREE data already
# counts the 0-3 m (regeneration) height class.
NOCA_present_seed =
  read_excel("data/NOCA/NOCA_vegetation_fromJHRL.xlsx", sheet = "Seedlings") %>%
  rename(plot_id = `Plot ID`, present_species_abv = Species) %>%
  mutate(plot_id = toupper(plot_id),
         seed_tally = coalesce(suppressWarnings(as.numeric(`10-50cm Tally`)), 0) +
                      coalesce(suppressWarnings(as.numeric(`51-140cm Tally`)), 0)) %>%
  filter(!is.na(present_species_abv), seed_tally > 0,
         !plot_id %in% takeout_plots_present) %>%
  left_join(NOCA_present_splib, by = "present_species_abv")

NOCA_present_seed_occ = NOCA_present_seed %>%
  filter(!is.na(species)) %>%
  group_by(plot_id, species) %>% summarize(count = sum(seed_tally), .groups = "drop")

# A plot has present vegetation if it has a tree OR a seedling record
present_plots_with_veg = union(present_plots_with_trees, unique(NOCA_present_seed_occ$plot_id))
present_empty_plots = setdiff(all_present_plots_raw, present_plots_with_veg)

# Merge tree + seedling into one presence record per plot-species
NOCA_present_occ = bind_rows(NOCA_present_occ_trees, NOCA_present_seed_occ) %>%
  group_by(plot_id, species) %>% summarize(count = sum(count), .groups = "drop") %>%
  mutate(occurence = 1)

seedling_only = anti_join(NOCA_present_seed_occ, NOCA_present_occ_trees,
                          by = c("plot_id", "species"))
cat("There are", length(unique(NOCA_present_occ$plot_id)), "plots in the present data.")
cat("\nSeedlings added", nrow(NOCA_present_seed_occ), "present plot-species records;",
    nrow(seedling_only), "are seedling-only (no tree);",
    n_distinct(setdiff(unique(NOCA_present_seed_occ$plot_id), present_plots_with_trees)),
    "plots gain present data purely from seedlings.\n")

## Get legacy ----
NOCA_past_splib = read_excel("data/NOCA/AGEEDATA_NEW.xlsx", sheet = "SPECIES")
NOCA_past_plot_info =  read_excel("data/NOCA/AGEEDATA_NEW.xlsx", sheet = "OVERVIEW") # plot area is here for past plots.

NOCA_past = read_excel("data/NOCA/AGEEDATA_NEW.xlsx", sheet = "TREE")%>%
  rename(plot_id_past = PLOT, 
         past_species_abv = SPEC)%>%
  left_join(NOCA_present_splib, by = "past_species_abv")%>%
  left_join(NOCA_plots)

# Take out some plots because of missing GPS coordinates
past_plot_takeout = NOCA_past %>%
  filter(is.na(Latitude)|is.na(Longitude))%>%
  pull(plot_id_past)%>%
  unique()

# Add to tracking
plot_tracking = bind_rows(plot_tracking,
                          data.frame(
                            plot_id = NA,
                            plot_id_past = past_plot_takeout,
                            period = "past",
                            status = "removed",
                            reason = "missing GPS coordinates"
                          ))

cat("There are", length(past_plot_takeout), "to take out because of missing GPS info.")

NOCA_past = 
  NOCA_past %>%
  filter(!plot_id_past %in% past_plot_takeout)%>%
  mutate(species = case_when(past_species_abv == "ACCI" ~ "Acer circinatum",
                             .default = species))
cat("There are", length(unique(NOCA_past$plot_id_past)), "past plots after we take out plots with missing GPS.")

# Preserve the eligible plot universe before removing unsupported taxon rows.
all_past_plots_raw = unique(NOCA_past$plot_id)
NOCA_plot_info = NOCA_past %>%
  select(plot_id, Latitude, Longitude, elevation) %>%
  distinct() %>%
  mutate(Longitude = ifelse(Longitude > 0, -Longitude, Longitude))

# CARI449 and CARI450 have opposite raw longitude signs but collapse to the
# same normalized coordinate after the positive longitude is corrected to
# west, despite a 527 m elevation difference. Rachel's September 2024 email
# warns against the 2014 workbook GPS sheet and identifies the paper's coordinate
# CSV as authoritative. That CSV retains this collision; her other notes supply
# no correction. At the author's request, exclude BOTH dates upstream under the
# study-level policy below. Keep raw coordinates in this audit for provenance.
NOCA_coordinate_collision_audit = NOCA_plots %>%
  transmute(
    plot_id,
    raw_latitude = Latitude,
    raw_longitude = Longitude,
    normalized_latitude = Latitude,
    normalized_longitude = ifelse(Longitude > 0, -Longitude, Longitude),
    elevation
  ) %>%
  distinct() %>%
  group_by(normalized_latitude, normalized_longitude) %>%
  mutate(
    shared_coordinate_count = n_distinct(plot_id),
    elevation_range_m = max(elevation, na.rm = TRUE) - min(elevation, na.rm = TRUE)
  ) %>%
  filter(shared_coordinate_count > 1L) %>%
  ungroup() %>%
  mutate(status = "excluded—GPS problem; no verified coordinate correction") %>%
  arrange(normalized_latitude, normalized_longitude, plot_id)
NOCA_past = NOCA_past %>% filter(is_supported_noca_taxon(species))

NOCA_past = 
  NOCA_past %>%
  mutate(`DEN_0-3` = ifelse(is.na(`DEN_0-3`), 0, `DEN_0-3`),
         `DEN_3-10` = ifelse(is.na(`DEN_3-10`), 0, `DEN_3-10`),
         `DEN >10` = ifelse(is.na(`DEN >10`), 0, `DEN >10`)
  )%>%
  mutate(count = `DEN_0-3` + `DEN_3-10` + `DEN >10`)

# Check if there are any species with no taxonomic names assigned. 
no_info_sp = NOCA_past %>% filter(is.na(species)) %>% pull(past_species_abv)%>% unique()
if(length(no_info_sp)>0) {cat(no_info_sp, " are the species abb. with no species name info.")}

NOCA_past_occ = NOCA_past %>% select(plot_id, species, count) %>%
  filter(count >0)%>%
  mutate(occurence = 1)

# Identify plots with zero trees in past (empty plots)
past_empty_plots = union(
  setdiff(all_past_plots_raw, unique(NOCA_past$plot_id)),
  NOCA_past %>%
  group_by(plot_id) %>% 
  summarize(total_count = sum(count, na.rm = TRUE)) %>%
  filter(total_count == 0) %>%
  pull(plot_id)
)

# Identify plots with trees in past but empty now
past_plots_with_trees = unique(NOCA_past_occ$plot_id)
plots_trees_past_empty_now = intersect(past_plots_with_trees, present_empty_plots)

# Identify plots empty in both periods
plots_empty_both_periods = intersect(present_empty_plots, past_empty_plots)

# A duplicated plot/species row would double-count a legacy occurrence.
past_duplicates = NOCA_past_occ %>%
  count(plot_id, species, name = "n") %>%
  filter(n > 1)
if (nrow(past_duplicates) > 0) {
  print(past_duplicates)
  stop("Duplicate NOCA legacy plot/species records detected.")
}

# Merge past and present occurences ----
# This now correctly includes empty present plots
plots_to_keep = unique(intersect(all_present_plots_raw, all_past_plots_raw))

# Remove plots that are empty in both periods from final dataset
plots_to_keep = setdiff(plots_to_keep, plots_empty_both_periods)

# Study-level exclusions agreed after reviewing Rachel Wilson's notes. These are
# valid source IDs, but they are not suitable paired observations for this study:
# BAK487 is an old clearcut removed from Wilson's final analysis; BEAV6061's
# historical location could not be identified reliably because its elevation was
# inaccurate and the resurvey landed in an avalanche chute.
# CARI449/CARI450 share unresolved coordinates in the authoritative CSV; the
# author elected to exclude both rather than assign an unsupported replacement.
NOCA_study_exclusions = tribble(
  ~plot_id,   ~exclusion_reason, ~source_note,
  "BAK487",  "old clearcut; removed from Wilson final analysis",
              "notes_from_Rachel/Burned plots.rtf",
  "BEAV6061", "historic plot location uncertain; resurvey is an avalanche chute",
              "notes_from_Rachel/Missing trees.rtf",
  "CARI449", "GPS problem; shared coordinates conflict with elevations; no verified correction",
              "data/NOCA/Correspondance_Kavya&Rachel_September2024.pdf (page 2); report/details/01_vegetation_noca_gps_exclusion.md",
  "CARI450", "GPS problem; shared coordinates conflict with elevations; no verified correction",
              "data/NOCA/Correspondance_Kavya&Rachel_September2024.pdf (page 2); report/details/01_vegetation_noca_gps_exclusion.md"
)
study_exclusion_ids = intersect(plots_to_keep, NOCA_study_exclusions$plot_id)
if (!setequal(study_exclusion_ids, NOCA_study_exclusions$plot_id)) {
  stop("Expected study-exclusion plots were not all otherwise eligible: ",
       paste(setdiff(NOCA_study_exclusions$plot_id, study_exclusion_ids), collapse = ", "))
}
plots_to_keep = setdiff(plots_to_keep, study_exclusion_ids)

plot_tracking = bind_rows(
  plot_tracking,
  NOCA_study_exclusions %>%
    transmute(plot_id, plot_id_past = NA_real_, period = "both",
              status = "removed", reason = exclusion_reason)
)

# Identify special cases within the plots to keep
plots_empty_past_present_now = intersect(past_empty_plots, intersect(present_plots_with_veg, plots_to_keep))
plots_trees_past_empty_now = intersect(past_plots_with_trees, intersect(present_empty_plots, plots_to_keep))
plots_with_data_both_periods = intersect(past_plots_with_trees, intersect(present_plots_with_veg, plots_to_keep))

# Add tracking for plots that are kept or removed
kept_plots = plots_to_keep
plot_tracking = bind_rows(plot_tracking,
                          data.frame(
                            plot_id = kept_plots,
                            plot_id_past = NA,
                            period = "both",
                            status = "kept",
                            reason = case_when(
                              kept_plots %in% plots_empty_past_present_now ~ "empty in past, trees present now",
                              kept_plots %in% plots_trees_past_empty_now ~ "trees in past, empty present now",
                              .default = "common plots with data"
                            )
                          ))

# Add tracking for plots empty in both periods
if(length(plots_empty_both_periods) > 0) {
  plot_tracking = bind_rows(plot_tracking,
                            data.frame(
                              plot_id = plots_empty_both_periods,
                              plot_id_past = NA,
                              period = "both",
                              status = "removed",
                              reason = "empty in both periods"
                            ))
}

# Track removed plots using raw data
removed_present = setdiff(all_present_plots_raw,
                          c(plots_to_keep, plots_empty_both_periods, study_exclusion_ids))
removed_past = setdiff(all_past_plots_raw,
                       c(plots_to_keep, plots_empty_both_periods, study_exclusion_ids))

if(length(removed_present) > 0) {
  plot_tracking = bind_rows(plot_tracking,
                            data.frame(
                              plot_id = removed_present,
                              plot_id_past = NA,
                              period = "present",
                              status = "removed",
                              reason = "no matching past plot"
                            ))
}

if(length(removed_past) > 0) {
  plot_tracking = bind_rows(plot_tracking,
                            data.frame(
                              plot_id = removed_past,
                              plot_id_past = NA,
                              period = "past",
                              status = "removed",
                              reason = "no matching present plot"
                            ))
}

length(setdiff(NOCA_present_occ$plot_id, NOCA_past_occ$plot_id))

NOCA_present_occ = NOCA_present_occ %>% filter(plot_id %in% plots_to_keep)
NOCA_past_occ = NOCA_past_occ %>% filter(plot_id %in% plots_to_keep)
NOCA_plot_info = NOCA_plot_info %>% filter(plot_id %in% plots_to_keep)

# For empty past plots, create empty occurrence records
if(length(plots_empty_past_present_now) > 0) {
  empty_past_records = data.frame(
    plot_id = plots_empty_past_present_now,
    species = "Abies amabilis", # just putting a random species to be able to create all 0 species matrix later.
    count = 0,
    occurence = 0
  )
  NOCA_past_occ = bind_rows(NOCA_past_occ, empty_past_records)
}

# For empty present plots, create empty occurrence records
if(length(plots_trees_past_empty_now) > 0) {
  empty_present_records = data.frame(
    plot_id = plots_trees_past_empty_now,
    species = "Abies amabilis", # just putting a random species to be able to create all 0 species matrix later.
    count = 0,
    occurence = 0
  )
  NOCA_present_occ = bind_rows(NOCA_present_occ, empty_present_records)
}

NOCA_occ = bind_rows(NOCA_past_occ %>% mutate(period = "past"), NOCA_present_occ %>% mutate(period = "present"))
length(unique(NOCA_occ$plot_id))

cat("There are", length(plots_empty_past_present_now), "plots that were empty in past but have trees now.")
cat("There are", length(plots_trees_past_empty_now), "plots that had trees in past but are empty now.")
cat("There are", length(plots_empty_both_periods), "plots that are empty in both periods.")

# Report plot tracking ----
# Create summary for visualization
plot_summary = plot_tracking %>%
  count(status, reason, name = "n_plots") %>%
  mutate(reason = fct_reorder(reason, n_plots),
         status_color = case_when(
           status == "kept" ~ "#2E8B57",
           status == "removed" ~ "#DC143C"
         ))

# Main visualization
p1 = ggplot(plot_summary, aes(x = reason, y = n_plots, fill = status_color)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = n_plots), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_fill_identity() +
  labs(title = "Plot Status Summary",
       subtitle = "Number of plots kept vs removed by reason",
       x = "Reason",
       y = "Number of plots") +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.text = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

# Create period breakdown
period_summary = plot_tracking %>%
  filter(!is.na(period)) %>%
  count(period, status, name = "n_plots")

p2 = ggplot(period_summary, aes(x = period, y = n_plots, fill = status)) +
  geom_col(position = "dodge", width = 0.7) +
  geom_text(aes(label = n_plots), position = position_dodge(width = 0.7), vjust = -0.3, size = 3.5) +
  scale_fill_manual(values = c("kept" = "#2E8B57", "removed" = "#DC143C")) +
  labs(title = "Plot Status by Period",
       x = "Period",
       y = "Number of plots",
       fill = "Status") +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "top"
  )

# Special cases breakdown  
special_cases = plot_tracking %>%
  filter(status == "kept", 
         reason %in% c("empty in past, trees present now", "trees in past, empty present now")) %>%
  count(reason, name = "n_plots") %>%
  mutate(change_type = case_when(
    reason == "empty in past, trees present now" ~ "Colonization",
    reason == "trees in past, empty present now" ~ "Extirpation"
  ))

p3 = ggplot(special_cases, aes(x = change_type, y = n_plots, fill = change_type)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = n_plots), vjust = -0.3, size = 4) +
  scale_fill_manual(values = c("Colonization" = "#228B22", "Extirpation" = "#FF6347")) +
  labs(title = "Forest Change Events",
       subtitle = "Plots showing colonization or extirpation",
       x = "Change Type",
       y = "Number of plots") +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "none"
  )

# Print plots
if (render_figures) {
  pdf(file = fig("supplementary", "NOCA_cleaning.pdf"), height = 8, width = 10)
  print(p1)
  print(p2)
  print(p3)
  dev.off()
}

# Print summary statistics
cat("PLOT TRACKING SUMMARY\n")
cat("====================\n")
cat("Total plots processed:", nrow(plot_tracking), "\n")
cat("Plots kept:", sum(plot_tracking$status == "kept"), "\n")
cat("Plots removed:", sum(plot_tracking$status == "removed"), "\n\n")

cat("CHANGE EVENTS\n")
cat("=============\n")
if(nrow(special_cases) > 0) {
  for(i in 1:nrow(special_cases)) {
    cat(special_cases$change_type[i], "events:", special_cases$n_plots[i], "\n")
  }
} else {
  cat("No change events detected\n")
}

NOCA_occ =
  NOCA_occ %>%
  mutate(species = ifelse(species == "Chamaecyparis nootkatensis","Callitropsis nootkatensis", species))%>%
  mutate(species = ifelse(species == "Cornus stolonifera", "Cornus sericea", species))%>%
  mutate(species = ifelse(species == "Unknown tree.", "unknown", species))%>%
  mutate(species = ifelse(is.na(species), "unknown", species))%>%
  filter(!species %in% NOCA_UNSUPPORTED_TAXA) %>%
  rename(occurrence = occurence)

NOCA_occ = distinct(NOCA_occ)

# Compare the modeled present composition with the same cleaner fed the
# unpatched JHRL tree table. Seedlings are held fixed, so this isolates the tree
# correction rather than mixing it with another data-source decision.
normalize_noca_species = function(x) {
  x = ifelse(x == "Chamaecyparis nootkatensis", "Callitropsis nootkatensis", x)
  x = ifelse(x == "Cornus stolonifera", "Cornus sericea", x)
  x = ifelse(x == "Unknown tree.", "unknown", x)
  ifelse(is.na(x), "unknown", x)
}
unpatched_present_presence = bind_rows(
  NOCA_present_raw %>%
    left_join(NOCA_present_splib, by = "present_species_abv") %>%
    transmute(plot_id, species = normalize_noca_species(species)),
  NOCA_present_seed_occ %>%
    transmute(plot_id, species = normalize_noca_species(species))
) %>%
  filter(plot_id %in% plots_to_keep,
         !species %in% NOCA_UNSUPPORTED_TAXA) %>%
  distinct(plot_id, species)

patched_present_presence = NOCA_occ %>%
  filter(period == "present", occurrence == 1,
         !species %in% NOCA_UNSUPPORTED_TAXA) %>%
  distinct(plot_id, species)

composition_signature = function(x, label) {
  x %>%
    arrange(plot_id, species) %>%
    group_by(plot_id) %>%
    summarize(
      !!paste0(label, "_n_species") := n(),
      !!paste0(label, "_species") := paste(species, collapse = "|"),
      .groups = "drop"
    )
}
lost_species = anti_join(unpatched_present_presence, patched_present_presence,
                         by = c("plot_id", "species")) %>%
  arrange(plot_id, species) %>%
  summarize(species_lost = paste(species, collapse = "|"), .by = plot_id)
gained_species = anti_join(patched_present_presence, unpatched_present_presence,
                           by = c("plot_id", "species")) %>%
  arrange(plot_id, species) %>%
  summarize(species_gained = paste(species, collapse = "|"), .by = plot_id)

NOCA_tree_composition_audit = tibble(plot_id = sort(unique(NOCA_occ$plot_id))) %>%
  left_join(composition_signature(unpatched_present_presence, "unpatched"), by = "plot_id") %>%
  left_join(composition_signature(patched_present_presence, "corrected"), by = "plot_id") %>%
  left_join(lost_species, by = "plot_id") %>%
  left_join(gained_species, by = "plot_id") %>%
  mutate(
    across(ends_with("_n_species"), ~ replace_na(.x, 0L)),
    across(c(unpatched_species, corrected_species, species_lost, species_gained),
           ~ replace_na(.x, "")),
    present_composition_changed = unpatched_species != corrected_species
  )
if (sum(NOCA_tree_composition_audit$present_composition_changed) != 50L) {
  stop("Expected the corrected tree layer to change present composition in 50 modeled plots; found ",
       sum(NOCA_tree_composition_audit$present_composition_changed), ".")
}

# Write all outputs ----
# -----------------------------------------------------------------------------
# Stage-resolved companion table (adult vs seedling/regeneration)
# -----------------------------------------------------------------------------
# Same plots and species as NOCA_occ.csv, one row per stage, so
# R/pipeline/10_species_occurrences.R can draw the adult-vs-seedling comparison
# WITHOUT source()-ing this script (which would rewrite these outputs as a side
# effect, which was the problem in the removed historical stage diagnostic).
#
# ⚠ The two eras do NOT measure regeneration the same way, and the figure must
# say so:
#   past    regeneration = the legacy 0-3 m HEIGHT class (Agee & Kertis 1987);
#           adult        = the 3-10 m and >10 m height classes
#   present regeneration = the JHRL Seedlings tallies (10-140 cm);
#           adult        = the Tree Data stems (DBH, i.e. >1.4 m)
# So "past regeneration" is a coarser, taller band (up to 3 m) than "present
# regeneration" (up to 1.4 m). Adult size limits also differ (>3 m vs >1.4 m),
# so neither label establishes identical size-class sampling across periods.
SEED = "Seedling / regeneration"; ADULT = "Adult"
fix_noca_sp = normalize_noca_species
NOCA_stage = bind_rows(
  NOCA_past %>% filter((`DEN_3-10` + `DEN >10`) > 0) %>%
    transmute(period = "past",    plot_id, species = fix_noca_sp(species), stage = ADULT),
  NOCA_past %>% filter(`DEN_0-3` > 0) %>%
    transmute(period = "past",    plot_id, species = fix_noca_sp(species), stage = SEED),
  NOCA_present_occ_trees %>%
    transmute(period = "present", plot_id, species = fix_noca_sp(species), stage = ADULT),
  NOCA_present_seed_occ %>%
    transmute(period = "present", plot_id, species = fix_noca_sp(species), stage = SEED)
) %>%
  filter(plot_id %in% plots_to_keep) %>%
  distinct(period, plot_id, species, stage) %>%
  arrange(plot_id, species, period, stage)

write_csv(NOCA_stage, file = out("NOCA_occ_stage.csv"))

# The stage table must not invent or lose plot x species x period combinations.
# It CAN legitimately be a subset: NOCA_occ.csv carries synthetic all-zero rows
# for plots that are empty in one period, and those have no stage.
stage_key = paste(NOCA_stage$plot_id, NOCA_stage$species, NOCA_stage$period)
occ_key   = NOCA_occ %>% filter(occurrence == 1) %>%
  { paste(.$plot_id, .$species, .$period) }
stopifnot(all(stage_key %in% occ_key))

write_csv(NOCA_present_occ, file = out("NOCA_present_occ.csv"))
write_csv(NOCA_past_occ, file = out("NOCA_past_occ.csv"))
write_csv(NOCA_plot_info, file = out("NOCA_plot_info.csv"))
write_csv(NOCA_coordinate_collision_audit,
          file = out("NOCA_coordinate_collision_audit.csv"))
write_csv(NOCA_occ, file = out("NOCA_occ.csv"))
# Wilson's plot-specific adult resurvey dates remain authoritative for NOCA.
# One shared table now feeds both sites' climate windows and rate denominators.
NOCA_plot_years = read_csv(here("data/NOCA/NOCA_plots_fromWilson.csv"),
  show_col_types = FALSE) %>%
  transmute(site = "NOCA", plot_id = toupper(trimws(`2015.Plot.Name`)),
    vegetation_t2_year = as.numeric(Resurvey.Year)) %>%
  filter(plot_id %in% NOCA_occ$plot_id) %>% survey_windows()
modern_plot_years = bind_rows(
  read_csv(out("MORA_plot_years.csv"), show_col_types = FALSE) %>%
    filter(plot_id %in% read_csv(out("MORA_occ.csv"),
      show_col_types = FALSE)$plot_id), NOCA_plot_years)
write_csv(modern_plot_years, out("modern_plot_years.csv"))
saveRDS(plot_year_input_hashes(), out("modern_plot_years_sources.rds"))
write_csv(plot_tracking, file = out("NOCA_plot_tracking.csv"))
write_csv(NOCA_study_exclusions,
          file = out("NOCA_study_exclusions.csv"))
write_csv(NOCA_tree_composition_audit,
          file = out("NOCA_tree_composition_audit.csv"))

# Per-corrected-plot provenance and inclusion audit. Raw inputs remain immutable.
raw_plot_counts = NOCA_present_raw %>% count(plot_id, name = "old_rows_at_plot")
corrected_plot_counts = NOCA_present_corrected %>%
  count(plot_id, name = "corrected_rows_added")
raw_coordinate_ids = read_csv(here("data/NOCA/NOCA_plots_fromWilson.csv"),
                              show_col_types = FALSE) %>%
  transmute(plot_id = str_to_upper(str_trim(as.character(`2015.Plot.Name`))),
            coordinates_available = !is.na(Latitude) & !is.na(Longitude))

NOCA_tree_correction_audit = corrected_plot_counts %>%
  left_join(raw_plot_counts, by = "plot_id") %>%
  left_join(raw_coordinate_ids, by = "plot_id") %>%
  left_join(NOCA_tree_composition_audit %>%
              select(plot_id, present_composition_changed),
            by = "plot_id") %>%
  mutate(
    old_rows_at_plot = replace_na(old_rows_at_plot, 0L),
    erroneous_source_id = case_when(
      plot_id == "BBCR6075" ~ "BBCR6065",
      plot_id == "HB5144" ~ "HB5134",
      plot_id == "STE2020" ~ "STE2022",
      plot_id == "STE2072" ~ "STE2077",
      plot_id %in% c("PYRA1013", "PYRA1015") ~ "PYRA1015",
      plot_id %in% c("ROSS3044", "ROSS3048") ~ "ROSS3048",
      TRUE ~ NA_character_
    ),
    erroneous_source_rows_removed = map_int(
      erroneous_source_id,
      ~ if (is.na(.x)) 0L else sum(NOCA_present_raw$plot_id == .x)
    ),
    correction_action = case_when(
      plot_id %in% c("PYRA1013", "PYRA1015") ~ "split corrected PYRA1015 source group",
      plot_id %in% c("ROSS3044", "ROSS3048") ~ "split corrected ROSS3048 source group",
      plot_id == "BBCR6075" ~ "renamed source BBCR6065",
      plot_id == "HB5144" ~ "renamed source HB5134",
      plot_id == "STE2020" ~ "renamed source STE2022",
      plot_id == "STE2072" ~ "renamed source STE2077",
      old_rows_at_plot > 0 ~ "authoritative replacement",
      TRUE ~ "previously omitted; added"
    ),
    final_status = case_when(
      plot_id %in% plots_to_keep ~ "included",
      !coalesce(coordinates_available, FALSE) ~ "excluded",
      !plot_id %in% all_past_plots_raw ~ "excluded",
      TRUE ~ "excluded"
    ),
    exclusion_reason = case_when(
      final_status == "included" ~ NA_character_,
      !coalesce(coordinates_available, FALSE) ~ "missing coordinates",
      !plot_id %in% all_past_plots_raw ~ "no matching legacy tree survey",
      TRUE ~ "removed by NOCA cleaning rules"
    )
  ) %>%
  arrange(plot_id)

expected_exclusions = c("HB5144", "MCAL5004", "ROSS3022")
actual_exclusions = NOCA_tree_correction_audit %>%
  filter(final_status == "excluded") %>% pull(plot_id)
if (!setequal(actual_exclusions, expected_exclusions)) {
  stop("Unexpected corrected-plot exclusions: ",
       paste(sort(actual_exclusions), collapse = ", "))
}
write_csv(NOCA_tree_correction_audit,
          out("NOCA_tree_correction_audit.csv"))

# Calculate turnover for NOCA data
noca_turnover_results = calculate_turnover(NOCA_occ)

# Print summary statistics
print_turnover_summary(noca_turnover_results)

# Create visualizations
noca_heatmap_plot = create_turnover_heatmap(noca_turnover_results$turnover_data) 
noca_alluvial_plot = create_alluvial_plot(noca_turnover_results$turnover_data)

# The CCA inclusion threshold belongs to R/pipeline/11_cca.R. This cleaner reports
# the raw NOCA occurrence counts without duplicating downstream model decisions.
noca_count_data = NOCA_occ %>%
  filter(occurrence == 1) %>%
  count(species, period, name = "n_plots")

sp_order = noca_count_data %>%
  group_by(species) %>% summarize(tot = sum(n_plots), .groups = "drop") %>%
  arrange(desc(tot)) %>% pull(species)
noca_count_data = noca_count_data %>% mutate(species = factor(species, levels = sp_order))

noca_count_plot =
  ggplot(noca_count_data, aes(species, n_plots, fill = period)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_fill_manual(values = c("past" = "#8B4513", "present" = "#228B22")) +
  labs(title = "NOCA species occurrence by period",
       subtitle = "Raw cleaning output; CCA eligibility is decided centrally in R/pipeline/11_cca.R",
       x = "Species", y = "Number of plots",
       fill = "Period") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
    plot.title  = element_text(size = 13, face = "bold"),
    legend.position = "top"
  )

# Display plots

if (render_figures) {
  pdf(file = fig("supplementary", "NOCA_dynamics.pdf"), width = 10, height = 8)
  print("NOCA Turnover heatmap...")
  print(noca_heatmap_plot)

  print("NOCA Alluvial flow diagram...")
  print(noca_alluvial_plot)

  print("NOCA Species count plot...")
  print(noca_count_plot)
  dev.off()
}
