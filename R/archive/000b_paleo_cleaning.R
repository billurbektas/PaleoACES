# =============================================================================
# 000b_paleo_cleaning.R - paleo occurrence, climate and fire tables
# =============================================================================
# Part 2 of what used to be 000_PALEO_cleaning.R. Part 1 is
# R/000a_bacon_agedepth.R, which builds the age-depth models and writes
# Cores/<core>/<core>_<K>_ages.txt. THIS script only READS those ages.
#
# Run 000a first (or whenever a control point changes); it is slow (four MCMC
# runs, ~25 min). This script is fast and can be re-run on its own.
#
# Provenance of every control point: Cores/CONTROL_POINTS.md, with the detail in
# Cores/SOURCES_MORA.md and data/NOCA/NOCA_paleo/SOURCES.md.
#
# Outputs: output/paleo_occ.csv, output/paleo_env.csv, output/paleo_fire.csv
#
# NOTE Binning / rate-of-change (Mottl et al. 2021, R-Ratepol) is NOT done here.
# That is a separate decision still to be made - see the roc-binning notes.
# =============================================================================

library(rbacon)     # read_bacon_ages() reads Bacon output; no MCMC is run here
library(readr)
library(tidyverse)
library(here)
library(readxl)     # DunwiddieMacrofossils.xlsx
library(sf)         # st_as_sf for the pond coordinates

coredir <- file.path(here(), "Cores")

# Reads <core>_<K>_ages.txt written by 000a. Prefers the unsuffixed file, else
# the most recent suffixed one - so a stale file from a different K would be a
# problem; 000a's reset_core() deletes them before every run.
read_bacon_ages <- function(core, coredir = file.path(getwd(), "Cores")) {
  f1 <- file.path(coredir, core, paste0(core, "_ages.txt"))
  if (file.exists(f1)) {
    df <- read.table(f1, header = TRUE)
    names(df) <- tolower(names(df))
    return(df)
  }
  cand <- Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))
  if (length(cand) == 0)
    stop("No *_ages.txt found for core '", core, "' in ", file.path(coredir, core),
         " - run R/000a_bacon_agedepth.R first.")
  latest <- cand[which.max(file.info(cand)$mtime)]
  df <- read.table(latest, header = TRUE)
  names(df) <- tolower(names(df))
  df
}


# -------------------------
# 5) Pool Y & F ages from the dated cores
# -------------------------
JB <- read_bacon_ages("JayBath", coredir) %>% mutate(site = "JayBath")
LW <- read_bacon_ages("LogWallow", coredir) %>% mutate(site = "LogWallow")
RP <- read_bacon_ages("ReflectionPond", coredir) %>% mutate(site = "ReflectionPond")

age_depth = rbind(JB, LW, RP) %>%
  rename(year = median)%>%
  select(site, depth, year)

# Get paleo data ----
paleo_plots = data.frame(Location = c("JayBath", "LogWallow", "ReflectionPond")) %>%
  mutate(latitude = case_when(Location == "JayBath" ~ 46.7667,
                              Location == "LogWallow" ~ 46.7667,
                              Location == "ReflectionPond" ~ 46.7667)) %>%
  mutate(longitude = case_when(Location == "JayBath" ~ -121.7667,
                               Location == "LogWallow" ~ -121.75,
                               Location == "ReflectionPond" ~ -121.7167))

paleo_coords = paleo_plots %>%
  select(longitude, latitude, Location) %>%
  distinct() %>%
  rename(id = Location)

paleo_coords_sf = paleo_coords %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Get MORA/NOCA data for species matching ----
NOCA_occ = read_csv(here("output/NOCA_occ.csv"))
MORA_occ = read_csv(here("output/MORA_occ.csv"))

occ = bind_rows(NOCA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "NOCA"),
                MORA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "MORA")) %>%
  mutate(era = "anthropocene") %>%
  filter(!species %in% c("unknown", "Abies sp.", "Salix sp."))

# Harmonize species ----
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
  
#Get fire info
fire_walsh = read_csv(here("output", "fire_walsh.csv"))

paleo_fire = 
  paleo_occ %>%
  filter(species %in% c("charred_needles", "needle_concentration", "charcoal_fragments"))%>%
  pivot_wider(names_from = species, values_from = Percentage)

dim(paleo_fire) #119

paleo_prev_fire = paleo_fire %>%
  # join any fire that is BEFORE the paleo year (older in cal yr BP)
  left_join(fire_walsh, by = join_by(year <= age_cal_yr_BP),
            relationship = "many-to-many") %>%
  # filter to fires within 50 years and keep the nearest earlier event
  filter(is.na(age_cal_yr_BP) | (age_cal_yr_BP - year <= 50)) %>%
  group_by(site, depth, year) %>%
  slice_min(age_cal_yr_BP, with_ties = FALSE) %>%
  ungroup() %>%
  # tidy names and calculate years before
  rename(
    fire_event_year_BP  = age_cal_yr_BP,
    fire_lake           = lake,
    fire_peak_magnitude = peak_magnitude,
    fire_is_significant = is_significant
  ) %>%
  mutate(
    years_before_fire = fire_event_year_BP - year,
    has_fire_within_50yr = !is.na(fire_event_year_BP)
  ) %>%
  filter(!is.na(year))%>%
  filter(fire_is_significant)

paleo_fire = 
  paleo_prev_fire %>%
  select(site, depth, year, charcoal_fragments, needle_concentration, charred_needles, fire_lake, fire_peak_magnitude, years_before_fire)%>%
  right_join(paleo_fire)%>%
  mutate(plot_id = paste0(site, "_", year, "_BP"))%>%
  mutate(period = "paleo")%>%
  rename(lake = site)

paleo_fire = 
  paleo_fire %>%
  mutate(charred_needles = ifelse(is.na(charred_needles), 0, charred_needles),
         fire_peak_magnitude = ifelse(is.na(fire_peak_magnitude), 0, fire_peak_magnitude),
         years_before_fire = ifelse(is.na(years_before_fire), 0, years_before_fire),
         fire_lake = ifelse(is.na(fire_lake), "no_fire_record", fire_lake)
         )

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

paleo_env = read_csv(here("output", "climate_paleo_ponds_summary.csv"))

# Interpolate climate data to match paleo occurrence years ----

# Get climate data range
max_climate_year = abs(min(paleo_env$period))  # Convert -6000 to 6000
print(paste("Climate data available from 0 to", max_climate_year, "years BP"))

# Create fine-resolution years for interpolation (every year)
fine_years = 0:max_climate_year

# Climate variables to interpolate
climate_vars = c("MAT", "MSpT", "MST", "MWT", "AP", "SpP", "SP", "WP")

paleo_env = 
  paleo_env %>% 
  rename(lake = plot_id)

# Interpolate climate for each site
interpolated_list = map(unique(paleo_env$lake), function(lake_name) {

  # Get climate data for this site and convert to positive years
  site_data = paleo_env %>%
    filter(lake == lake_name) %>%
    mutate(year_positive = abs(period)) %>%
    arrange(year_positive)

  # Interpolate each climate variable
  interpolated_site = tibble(
    lake = lake_name,
    year = fine_years,
    plot_id = paste0(fine_years, "_BP")
  )

  for (var in climate_vars) {
    spline_fit = smooth.spline(site_data$year_positive, site_data[[var]], spar = 0.3)
    interpolated_site[[var]] = predict(spline_fit, fine_years)$y
  }

  return(interpolated_site)
})

# Combine all sites
interpolated_climate = bind_rows(interpolated_list) %>%
  mutate(site = "MORA", era = "holocene", period = "paleo") %>%
  select(site, lake, era, period, plot_id, everything(), -year)%>%
  mutate(plot_id = paste0(lake, "_", plot_id))

# Join with paleo occurrence data
paleo_env = paleo_occ %>%
  left_join(interpolated_climate)%>%
  select(-species, -occurrence)%>%
  distinct()
  
  

# NOCA paleo: Panther Potholes core ----
# Macrofossil counts: Neotoma dataset 52207, site 13042 (Prichard et al. 2009).
# Ages: OUR Bacon run from section 4b, NOT the "Gavin 2021" column in this file.
# Both describe the same chronology - our medians reproduce Gavin's to a median
# of 14 yr over a 10,600 yr record - but Neotoma publishes only three quantiles
# per level, and the interval metrics need the full posterior (see SOURCES.md and
# the note at section 3b). Taking ages from our own run keeps the point estimates
# and the draws from one and the same model.
# Mirrors the MORA paleo_occ structure (one plot_id per dated sample). Charcoal is
# NOT in this file, so NOCA paleo enters paleo_occ and paleo_env (via the
# CHELSA-TraCE21k lake climate below) but not paleo_fire.
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

# NOCA paleo lake climate: Panther Potholes (CHELSA-TraCE21k) ----
# Mirrors the MORA ponds processing in 02_get_climate_data.R (lines 628-748)
# and the interpolation above, so NOCA paleo enters the CCA with MWT/MST/WP/SpP.
panther_plots = data.frame(
  Location  = "PantherPotholes",
  latitude  = 48.65,
  longitude = -121.0333
)

## Precipitation: annual + seasonal sums ----
noca_pre_ponds =
  read_csv(here("output/noca_climate/pre.paleo.ponds.csv"), show_col_types = FALSE)[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude  = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year  = as.numeric(str_extract(time, "^-?\\d+")) * 100,
    month = as.numeric(str_match(time, "^-?\\d+-(\\d{1,2})-")[, 2])
  ) %>%
  select(-location) %>%
  left_join(panther_plots, by = c("longitude", "latitude")) %>%
  filter(year < 0) %>%
  rename(plot_id = Location) %>%
  mutate(site = "NOCA", elevation = NA, aspect = NA, slope = NA)

noca_pre_summary = noca_pre_ponds %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
  summarize(annual_sum = sum(pre, na.rm = TRUE), .groups = "drop")

noca_pre_seasonal = noca_pre_ponds %>%
  mutate(
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5)  ~ "spring",
      month %in% c(6, 7, 8)  ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(season)) %>%
  group_by(site, plot_id, elevation, aspect, slope, season,
           year = if_else(season == "winter", winter_year, year)) %>%
  summarize(sum_pre = sum(pre, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = season, values_from = sum_pre, names_prefix = "sum_")

noca_pre_summary = noca_pre_summary %>%
  left_join(noca_pre_seasonal, by = c("site", "plot_id", "year", "elevation", "aspect", "slope"))

## Temperature: annual + seasonal means (K -> C) ----
noca_tasmin_ponds =
  read_csv(here("output/noca_climate/tasmin.paleo.ponds.csv"), show_col_types = FALSE)[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude  = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year  = as.numeric(str_extract(time, "^-?\\d+")) * 100,
    month = as.numeric(str_match(time, "^-?\\d+-(\\d{1,2})-")[, 2])
  ) %>%
  select(-location) %>%
  left_join(panther_plots, by = c("longitude", "latitude")) %>%
  filter(year < 0) %>%
  rename(plot_id = Location) %>%
  mutate(site = "NOCA", elevation = NA, aspect = NA, slope = NA)

noca_tasmin_summary = noca_tasmin_ponds %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
  summarize(annual_mean = mean(tasmin, na.rm = TRUE), .groups = "drop")

noca_tasmin_seasonal = noca_tasmin_ponds %>%
  mutate(
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5)  ~ "spring",
      month %in% c(6, 7, 8)  ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(season)) %>%
  group_by(site, plot_id, elevation, aspect, slope, season,
           year = if_else(season == "winter", winter_year, year)) %>%
  summarize(mean_temp = mean(tasmin, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = season, values_from = mean_temp, names_prefix = "mean_") %>%
  rename(winter_mean = mean_winter)

noca_tasmin_summary = noca_tasmin_summary %>%
  left_join(noca_tasmin_seasonal, by = c("site", "plot_id", "year", "elevation", "aspect", "slope")) %>%
  mutate(annual_mean = annual_mean - 273.15,
         mean_spring = mean_spring - 273.15,
         mean_summer = mean_summer - 273.15,
         winter_mean = winter_mean - 273.15)

## Combine and interpolate to fine years (mirror of the MORA block above) ----
noca_ponds_summary = left_join(noca_tasmin_summary, noca_pre_summary) %>%
  rename(MAT = annual_mean, MSpT = mean_spring, MST = mean_summer, MWT = winter_mean,
         AP = annual_sum, SpP = sum_spring, SP = sum_summer, WP = sum_winter) %>%
  mutate(era = "holocene") %>%
  rename(lake = plot_id) %>%
  mutate(period = year)

noca_max_year = abs(min(noca_ponds_summary$period))
noca_fine_years = 0:noca_max_year

noca_interp_list = map(unique(noca_ponds_summary$lake), function(lake_name) {
  site_data = noca_ponds_summary %>%
    filter(lake == lake_name) %>%
    mutate(year_positive = abs(period)) %>%
    arrange(year_positive)

  interpolated_site = tibble(
    lake = lake_name,
    year = noca_fine_years,
    plot_id = paste0(noca_fine_years, "_BP")
  )

  for (var in climate_vars) {
    spline_fit = smooth.spline(site_data$year_positive, site_data[[var]], spar = 0.3)
    interpolated_site[[var]] = predict(spline_fit, noca_fine_years)$y
  }

  interpolated_site
})

noca_interpolated_climate = bind_rows(noca_interp_list) %>%
  mutate(site = "NOCA", era = "holocene", period = "paleo") %>%
  select(site, lake, era, period, plot_id, everything(), -year) %>%
  mutate(plot_id = paste0(lake, "_", plot_id))

noca_paleo_env = noca_paleo_occ %>%
  left_join(noca_interpolated_climate) %>%
  select(-species, -occurrence) %>%
  distinct()

paleo_env = bind_rows(paleo_env, noca_paleo_env)

# Save results
write_csv(paleo_env, here("output", "paleo_env.csv"))
write_csv(paleo_occ, here("output", "paleo_occ.csv"))
write_csv(paleo_fire, here("output", "paleo_fire.csv"))


