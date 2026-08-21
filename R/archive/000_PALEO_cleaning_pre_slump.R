# Re-calibration of the age-depth model ----
# Documentation for rbacon package: https://cran.r-project.org/web/packages/rbacon/vignettes/rbacon.html
# Install (once): install.packages(c("rbacon","readr","tidyverse","here"))
# ================================
# Bacon: JayBath, LogWallow, ReflectionPond (Option C + lahar)
# ================================
# install.packages(c("rbacon","readr","tidyverse","here"))
library(rbacon)
library(readr)
library(tidyverse)
library(here)

# ------------------------
# Paths
# ------------------------
coredir <- file.path(here(), "Cores")
dir.create(coredir, showWarnings = FALSE, recursive = TRUE)

# ------------------------
# Helpers
# ------------------------
read_bacon_ages <- function(core, coredir = file.path(getwd(), "Cores")) {
  # Prefer unsuffixed; else most recent suffixed <core>_*_ages.txt
  f1 <- file.path(coredir, core, paste0(core, "_ages.txt"))
  if (file.exists(f1)) {
    df <- read.table(f1, header = TRUE)
    names(df) <- tolower(names(df))
    return(df)
  }
  cand <- Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))
  if (length(cand) == 0) stop("No *_ages.txt found for core '", core, "' in ", file.path(coredir, core))
  latest <- cand[which.max(file.info(cand)$mtime)]
  df <- read.table(latest, header = TRUE)
  names(df) <- tolower(names(df))
  df
}

write_core_files <- function(core, dates_tbl, ties_tbl) {
  # Enforce Bacon-documented order and headers:
  # Dates CSV MUST be: ID,Age,Error,Depth,cc  (in that order)
  # Ties CSV.TI MUST be: Depth,Age,Error
  dir.create(file.path(coredir, core), showWarnings = FALSE, recursive = TRUE)
  
  dates_tbl <- dates_tbl %>%
    transmute(
      ID    = as.character(ID),
      Age   = as.numeric(Age),
      Error = as.numeric(Error),
      Depth = as.numeric(Depth),
      cc    = as.integer(cc)
    ) %>%
    arrange(Depth)
  stopifnot(all(diff(dates_tbl$Depth) > 0))
  write_csv(dates_tbl, file.path(coredir, core, paste0(core, ".csv")))
}

# -------------------------
# 1) JAY BATH
# -------------------------
# Radiocarbon (uncalibrated); ORDER: ID,Age,Error,Depth,cc
jay_dates <- tribble(
  ~ID,          ~Age, ~Error, ~Depth,  ~cc,
  "QL-1729",     1320,   30,     39.5,   1,
  "QL-1730",     2920,   60,     70.0,   1,
  "Beta-6332",   3740,   80,    124.5,   1,
  "QL-1704",     6050,  110,    152.25,  1
)

jay_ties <- tribble(
  ~id,            ~Depth, ~Age, ~Error, ~cc,
  "Surface",         0,      0,     5,    0,
  "Tephra_W",       22,    470,    10,    0,
  "Tephra_C",       62,   2250,   100,    0,
  "Tephra_Y",       87,   3650,   100,    0,
  "Tephra_Y_alt",  105,   3650,   100,    0,
  "Tephra_F",      142,   5740,   100,    0
)

jay_dates = bind_rows(jay_dates, jay_ties)

write_core_files("JayBath", jay_dates)

# -------------------------
# 2) LOG WALLOW
# -------------------------
lw_dates <- tribble(
  ~ID,        ~Age, ~Error, ~Depth, ~cc,
  "QL-1726",   1650,   80,     29.0,  1,
  "QL-1727",   4900,   80,    117.0,  1,
  "QL-1728",   5980,   60,    140.0,  1
)

lw_ties <- tribble(
  ~id,           ~Depth, ~Age, ~Error, ~cc,
  "Surface",       0,        0,     5,    0,  # surface
  "Tephra_W",     22,      470,    10,    0, # Wn (AD 1480) dendro # Taken from the Yamaguchi 1983
  "Tephra_Y",     40,     3650,   100,    0,  # Y (broad)
  "Tephra_Y_alt", 98,     3650,   100,    0, # Y (second pick; same age)
  "Tephra_F",     116,    5740,   100,    0 # F (broad)
)

lw_dates = bind_rows(lw_dates, lw_ties)

write_core_files("LogWallow", lw_dates)

# -------------------------
# 3) REFLECTION POND
# -------------------------
# Radiocarbon (uncalibrated); ORDER: ID,Age,Error,Depth,cc

rp_dates <- tribble(
  ~ID,            ~Depth, ~Age, ~Error, ~cc,
  "Surface",         0,      0,     5,    0,
  "Tephra_W",       10,    470,    10,    0,
  "Tephra_C",       26,   2250,   100,    0,
  "Tephra_Y",       45,   3650,    100,   0,
  "Tephra_Y_alt",   64,   3650,    100,   0,
  "Tephra_F",       82,   5740,    100,   0,
  "Basal_lahar",    90,   6000,    600,   0
)

rp_dates = bind_rows(rp_dates)

write_core_files("ReflectionPond", rp_dates)


# -------------------------
# 4) RUN BACON: JayBath & LogWallow & ReflectionPond
# -------------------------
Bacon(core = "JayBath", coredir = coredir, thick = 5, suggest = TRUE)
Bacon(core = "LogWallow", coredir = coredir, thick = 5, suggest = TRUE)
Bacon(core = "ReflectionPond", coredir = coredir, thick = 5, suggest = TRUE)

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
# Prichard et al. 2009 (Neotoma dataset 52207, site 13042). The "Gavin 2021"
# age model is already calibrated (older/median/younger cal yr BP), so no Bacon
# run is needed here. Mirrors the MORA paleo_occ structure (one plot_id per
# dated sample). Charcoal is not in this file, so NOCA paleo is added to
# paleo_occ and to paleo_env (via the CHELSA-TraCE21k lake climate below),
# but not to paleo_fire.
noca_raw = read_csv(here("data/NOCA/NOCA_paleo/dataset52207_site13042.csv"),
                    show_col_types = FALSE)
noca_desc = c("name", "group", "element", "units", "context")
noca_samples = setdiff(names(noca_raw), noca_desc)

# Per-sample depth + median calibrated age (middle value of older/median/younger)
noca_meta = noca_raw %>%
  filter(name %in% c("Depth", "Gavin 2021")) %>%
  select(name, all_of(noca_samples)) %>%
  pivot_longer(-name, names_to = "sample", values_to = "value") %>%
  pivot_wider(names_from = name, values_from = value) %>%
  transmute(
    sample,
    depth = as.numeric(Depth),
    year  = as.numeric(str_split_i(`Gavin 2021`, "/", 2))
  )

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


