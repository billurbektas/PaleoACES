# =============================================================================
# 000_PALEO_b_vegetation.R - paleo macrofossil occurrences
# =============================================================================
# Vegetation portion of R/archive/000b_paleo_cleaning.R; see WORKFLOW.md.
# The fire third is now 000_PALEO_c_fire.R; the climate third was NOT split out -
# The downstream climate-match stage replaces its former embedded implementation.
#
# Ages come from R/000_PALEO_a_agedepth.R via R/paleo_ages.R. Run that first.
#
# Provenance of every control point: Cores/CONTROL_POINTS.md, with the detail in
# Cores/SOURCES_MORA.md and data/NOCA/NOCA_paleo/SOURCES.md.
#
# Outputs
#   output/paleo_occ.csv             presence/absence, one row per plot_id x species
#   output/paleo_macrofossil_long.csv  MORA long table WITH Percentage and the fire
#                                      categories still in it - the input to
#                                      000_PALEO_c_fire.R. Written here because the
#                                      fire categories are only separable partway
#                                      through this script's harmonisation, and
#                                      re-deriving them in the fire script would
#                                      duplicate that logic.
#
# Dropped in the split as dead code (assigned, never used in the original):
#   `occ`         - a bind_rows of NOCA_occ/MORA_occ, unreferenced
#   `paleo_plots` / `paleo_coords` / `paleo_coords_sf` - pond coordinates,
#                   unreferenced. They now live in 000_PALEO_d_climate_download.R.
# =============================================================================

library(readr)
library(tidyverse)
library(here)
library(readxl)     # DunwiddieMacrofossils.xlsx

source(here("R/paleo_ages.R"))

# -----------------------------------------------------------------------------
# MORA: Dunwiddie macrofossils -> harmonised species
# -----------------------------------------------------------------------------
takeoutpaleosp = c("Carex Achenes Lenticular", "Carex Achenes Trigonous",
                   "Isoetes Megaspores", "Nuphar Polysepalum Seeds",
                   "Potamogeton Species Achenes", "Ranunculus CF Aquatilis Achenes",
                   "Juncus Seeds", "Sparganium Seeds", "Phyllodoce Leaves",
                   "Abies-Type Seeds", "Tsuga-Type Seeds")
paleo_occ = read_excel(here("data/PALEO/DunwiddieMacrofossils.xlsx"), sheet = "MacrofossilData")
paleo_occ = paleo_occ %>%
  rename(species = Species) %>%
  filter(!species %in% takeoutpaleosp)%>%
  mutate(
    species = str_squish(species),
    species = case_when(
      species == "Abies Amabilis" ~ "Abies amabilis",
      species == "Abies Lasiocarpa" ~ "Abies lasiocarpa",
      species == "Abies Procera" ~ "Abies procera",
      species %in% c("Pinus Contorta Fascilcles", "Pinus Contorta Fascicles",
                     "Pinus Contorta Needle Fragments") ~ "Pinus contorta",
      species %in% c("Pinus Monticola Fascicles", "Pinus Monticola Needle Fragments",
                     "Pinus Montocola Needle Fragments") ~ "Pinus monticola",
      species == "Picea Engelmannii" ~ "Picea engelmannii",
      species == "Pseudotsuga Menziesii" ~ "Pseudotsuga menziesii",
      species == "Tsuga Heterophylla" ~ "Tsuga heterophylla",
      species %in% c("Tsuga Mertensiana", "Tsuga Mertinsiana") ~ "Tsuga mertensiana",
      species %in% c("Chamaecyparis", "Chamaecyparis Seeds") ~ "Callitropsis nootkatensis",
      species %in% c("Needle Concentration (per CC)", "Needle Concentration (Per CC)") ~ "needle_concentration",
      species == "Charcoal Fragments" ~ "charcoal_fragments",
      species == "Charred Needles" ~ "charred_needles",
      TRUE ~ species
    )
  )


paleo_occ =
  paleo_occ %>%
  rename(site = Location, depth = Depth)%>%
  select(site, species, depth, Percentage)%>%
  left_join(age_depth)

# Hand-off to 000_PALEO_c_fire.R: this is the state the fire categories are read
# from, before they are filtered out below.
write_csv(paleo_occ, here("output", "paleo_macrofossil_long.csv"))

# THE DEPTH LOOKUP THE AGE DRAWS NEED -----------------------------------------
# plot_id is built from the Bacon MEDIAN age, i.e. a point estimate. The moving-
# window analysis (R/paleo_runs.R) needs the full age POSTERIOR, and Bacon
# delivers that per DEPTH - which the select() below otherwise discards. Captured
# here, while depth is still attached, and written as its OWN table rather than a
# column on paleo_occ because a plot_id can cover MORE THAN ONE depth: three
# ReflectionPond depths (47/49/64 cm) all date to 3641 cal BP, because that core
# has no radiocarbon and its age-depth model is flat over 17 cm. Adding depth as
# a column would multiply those samples' rows - the exact bug that tripled a
# sample in the CCA via paleo_fire (see 000_PALEO_c_fire.R).
mora_depths = paleo_occ %>% distinct(lake = site, depth, year)

paleo_occ =
  paleo_occ %>%
  filter(!species %in% c("charred_needles", "needle_concentration", "charcoal_fragments"))%>%
  mutate(occurrence = ifelse(Percentage>0, 1, 0))%>%
  mutate(plot_id = paste0(site, "_", year, "_BP"),
         lake = site,
         era = "holocene",
         period = "paleo",
         site = "MORA")%>%
  select(period, plot_id, species, occurrence, site, era, lake)%>%
  distinct()

# -----------------------------------------------------------------------------
# NOCA paleo: Panther Potholes core
# -----------------------------------------------------------------------------
# Macrofossil counts: Neotoma dataset 52207, site 13042 (Prichard et al. 2009).
# Ages: OUR Bacon run, NOT the "Gavin 2021" column in this file. Both describe the
# same chronology - our medians reproduce Gavin's to a median of 14 yr over a
# 10,600 yr record - but Neotoma publishes only three quantiles per level, and the
# interval metrics need the full posterior (see SOURCES.md). Taking ages from our
# own run keeps the point estimates and the draws from one and the same model.
# Mirrors the MORA structure (one plot_id per dated sample). Charcoal is NOT in
# this file, so NOCA paleo enters paleo_occ and paleo_env but not paleo_fire.
noca_raw = read_csv(here("data/NOCA/NOCA_paleo/dataset52207_site13042.csv"),
                    show_col_types = FALSE)
noca_desc = c("name", "group", "element", "units", "context")
noca_samples = setdiff(names(noca_raw), noca_desc)

# Per-sample depth, and the age our Bacon model gives at that depth.
# Sample depths are 0.5, 1.5, ... 869.5; Bacon was run with d.by = 0.5, so every
# sample depth is on the output grid and approx() is an exact lookup, not a
# smoothing step. The Gavin column is retained alongside purely as a check.
noca_bacon = read_bacon_ages("PantherPotholes", coredir)

noca_meta = noca_raw %>%
  filter(name %in% c("Depth", "Gavin 2021")) %>%
  select(name, all_of(noca_samples)) %>%
  pivot_longer(-name, names_to = "sample", values_to = "value") %>%
  pivot_wider(names_from = name, values_from = value) %>%
  transmute(
    sample,
    depth      = as.numeric(Depth),
    year       = round(approx(noca_bacon$depth, noca_bacon$median, depth)$y),
    year_gavin = as.numeric(str_split_i(`Gavin 2021`, "/", 2))
  )

# Report the agreement rather than assume it.
cat("\nPantherPotholes ages, ours vs Gavin 2021 (cal yr BP):\n")
print(summary(noca_meta$year - noca_meta$year_gavin))
stopifnot(!any(is.na(noca_meta$year)))
noca_meta = noca_meta %>% select(sample, depth, year)

# Tree/shrub macrofossils -> harmonized species (drop genus/family "undiff.")
noca_paleo_occ = noca_raw %>%
  filter(group == "TRSH") %>%
  mutate(species = case_when(
    name == "Abies lasiocarpa"       ~ "Abies lasiocarpa",
    name == "Cupressus nootkatensis" ~ "Callitropsis nootkatensis",
    name == "Picea engelmannii"      ~ "Picea engelmannii",
    name == "Pinus contorta"         ~ "Pinus contorta",
    name == "Pinus monticola"        ~ "Pinus monticola",
    name == "Pseudotsuga menziesii"  ~ "Pseudotsuga menziesii",
    name == "Thuja plicata"          ~ "Thuja plicata",
    name == "Tsuga heterophylla"     ~ "Tsuga heterophylla",
    name == "Tsuga mertensiana"      ~ "Tsuga mertensiana",
    name == "Juniperus communis"     ~ "Juniperus communis",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(species)) %>%
  select(species, all_of(noca_samples)) %>%
  pivot_longer(-species, names_to = "sample", values_to = "count") %>%
  mutate(count = replace_na(as.numeric(count), 0)) %>%
  group_by(species, sample) %>%
  summarize(count = sum(count), .groups = "drop") %>%
  left_join(noca_meta, by = "sample") %>%
  mutate(
    occurrence = ifelse(count > 0, 1, 0),
    lake = "PantherPotholes",
    site = "NOCA",
    era  = "holocene",
    period = "paleo",
    plot_id = paste0(lake, "_", year, "_BP")
  ) %>%
  select(period, plot_id, species, occurrence, site, era, lake) %>%
  distinct()

paleo_occ = bind_rows(paleo_occ, noca_paleo_occ)

# -----------------------------------------------------------------------------
# Collapse to ONE row per (plot_id, species)
# -----------------------------------------------------------------------------
# distinct() above left 71 (plot_id, species) pairs with TWO rows - one saying
# occurrence 0 and the other 1 - from two unrelated causes:
#
# MORA (59 pairs). Several raw categories map to one species, and they are
# recorded on DIFFERENT bases:
#   Pinus contorta   <- "Pinus Contorta Fascicles" / "...Fascilcles" (typo)
#                       / "Pinus Contorta Needle Fragments"
#   Pinus monticola  <- "Pinus Monticola Fascicles"
#                       / "Pinus Monticola Needle Fragments" / "...Montocola..." (typo)
#   Callitropsis nootkatensis <- "Chamaecyparis" / "Chamaecyparis Seeds"
#   Dunwiddie 1986 counted Pinus fascicles as needle equivalents but tallied
#   needle FRAGMENTS separately, and Fig. 2's caption states "Pinus fragments
#   ... are excluded from the needle sum". Seeds are likewise on their own basis.
#   So the percentages must NOT be summed - they are not commensurable. For a
#   presence/absence analysis it does not matter: any category above zero means
#   the species is present.
#
# NOCA (12 pairs, at PantherPotholes 2678 / 3785 / 7616 BP). Two different core
# DEPTHS whose ages round to the same year, so they share a plot_id. Same
# situation as macrofossil samples inside a slump: contemporaneous within dating
# resolution, so merging them is the honest reading.
#
# Both are handled by the same rule - present if present in any contributing row.
paleo_occ = paleo_occ %>%
  group_by(period, plot_id, species, site, era, lake) %>%
  summarize(occurrence = as.integer(any(occurrence == 1)), .groups = "drop") %>%
  select(period, plot_id, species, occurrence, site, era, lake)

write_csv(paleo_occ, here("output", "paleo_occ.csv"))

cat("\npaleo_occ.csv: ", nrow(paleo_occ), " rows, ",
    n_distinct(paleo_occ$plot_id), " samples, ",
    n_distinct(paleo_occ$species), " species\n", sep = "")

# -----------------------------------------------------------------------------
# paleo_sample_depths.csv - which core depth(s) each sample came from
# -----------------------------------------------------------------------------
# One row per (plot_id, depth). Consumed by R/paleo_runs.R, which asks Bacon for
# the age posterior AT A DEPTH; without this the age draws cannot be attached to
# a sample at all, because plot_id carries only the median age.
#
# n_depths > 1 marks the samples where two or more depths collapsed onto one
# median age. They are contemporaneous within dating resolution - that is why
# they were merged - but their POSTERIORS are not identical, so the run
# machinery must decide what to draw for them rather than inherit an accident.
sample_depths = bind_rows(
  mora_depths,
  noca_meta %>% distinct(depth, year) %>% mutate(lake = "PantherPotholes")
) %>%
  mutate(plot_id = paste0(lake, "_", year, "_BP")) %>%
  group_by(plot_id) %>%
  mutate(n_depths = n()) %>%
  ungroup() %>%
  select(lake, plot_id, depth, median_age = year, n_depths) %>%
  arrange(lake, depth)

# The two tables must describe the SAME samples, or a sample would silently get
# no age draws (and vanish from every binned figure) while looking healthy here.
stopifnot(setequal(sample_depths$plot_id, paleo_occ$plot_id),
          !any(is.na(sample_depths$depth)))

write_csv(sample_depths, here("output", "paleo_sample_depths.csv"))
cat("paleo_sample_depths.csv: ", nrow(sample_depths), " depths for ",
    n_distinct(sample_depths$plot_id), " samples; ",
    sum(sample_depths$n_depths > 1), " depths share a collapsed age\n", sep = "")
