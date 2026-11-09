# =============================================================================
# 11_climate_eras_high_fire.R
# =============================================================================
# Literature-blind unified Holocene climate-era and high-fire-period analysis.
# Climate and fire are classified independently. This stage freezes the era
# grid; lake-level vegetation tracking joins it later without moving boundaries.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(patchwork)
})
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/holocene_climate_fire_era_functions.R"), local = TRUE)
source(here("R/helpers/figure_style.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

CLIMATE_INPUT = out("chelsa_paleo_ponds.csv")
CLIMATE_SCALING = out("cca_tracking_climate_scaling.csv")
FIRE_EVENTS = out("holocene_fire_source_events.csv")
FIRE_SERIES = out("holocene_fire_source_series.csv")
FIRE_SETTINGS = out("holocene_fire_source_settings.csv")
required = c(CLIMATE_INPUT, CLIMATE_SCALING, FIRE_EVENTS, FIRE_SERIES,
             FIRE_SETTINGS)
if (!all(file.exists(required))) stop("Missing unified-era input(s): ",
  paste(required[!file.exists(required)], collapse = ", "),
  ". Run CCA reference and R/pipeline/08_fire_records.R first.")

# Eras are classified from the CCA constraints (R/helpers/config.R).
PRIMARY_VARS = CCA_VARIABLES
VARIABLE_UNITS = setNames(ifelse(CLIMATE_VARIABLE_UNITS[PRIMARY_VARS] == "mm", "mm", "deg C"), PRIMARY_VARS)
VARIABLE_LABELS = CLIMATE_VARIABLE_LABELS[PRIMARY_VARS]
THRESHOLD_FRACTION = 0.50
REQUIRED_PHASES = 8L

# =============================================================================
# CLIMATE: signed, calibration-standardized 1,000-year changes
# =============================================================================
ponds = read_csv(CLIMATE_INPUT, show_col_types = FALSE)
levels = ponds |>
  transmute(unit = lake, period = site, variable, time = slice, month,
            value = value_raw) |>
  derive_climate_vars(winter_shift = FALSE) |>
  rename(lake = unit, site = period, slice = time) |>
  mutate(cal_bp = 1950 - slice * 100) |>
  select(site, lake, cal_bp, all_of(union(PRIMARY_VARS, CLIMATE_DISPLAY_VARIABLES)))
counts = levels |> count(site, lake, name = "n_slices")
if (nrow(counts) != 4L || any(counts$n_slices != 111L) ||
    any(is.na(levels[PRIMARY_VARS])))
  stop("Expected four complete 111-slice lake climate trajectories.")

climate_raw = build_climate_changes_1000yr(levels, PRIMARY_VARS,
  VARIABLE_UNITS)
all_scaling = read_csv(CLIMATE_SCALING, show_col_types = FALSE)
scaling = all_scaling |> filter(variable %in% PRIMARY_VARS)
if (nrow(scaling) != length(PRIMARY_VARS) || any(!is.finite(scaling$sd)) || any(scaling$sd <= 0))
  stop("Legacy CCA climate scaling is incomplete or invalid.")

climate = classify_climate_era_union(climate_raw$site_cells, scaling,
  fraction = THRESHOLD_FRACTION, required_phases = REQUIRED_PHASES)
composite = calculate_climate_composite(climate$site_standardized)

# Display only (appendix figure): the same per-variable rule applied to every
# seasonal variable in CLIMATE_DISPLAY_VARIABLES. These tables never define eras.
display_vars = CLIMATE_DISPLAY_VARIABLES
display_units = setNames(ifelse(CLIMATE_VARIABLE_UNITS[display_vars] == "mm", "mm", "deg C"), display_vars)
climate_display = classify_climate_era_union(
  build_climate_changes_1000yr(levels, display_vars, display_units)$site_cells,
  all_scaling |> filter(variable %in% display_vars),
  fraction = THRESHOLD_FRACTION, required_phases = REQUIRED_PHASES)
write_csv(climate_display$variable_cells, out("holocene_era_display_directional_cells.csv"))
write_csv(climate_display$thresholds, out("holocene_era_display_variable_thresholds.csv"))

era_domain = range(climate$era_grid$t)
if (!identical(era_domain, c(1300, 9500)))
  stop("Complete ten-phase climate domain changed; review before interpreting eras.")

direction_terms = climate$drivers |>
  mutate(driver_label = case_when(
    variable == "MSpT" & direction == "increasing" ~ "spring warming",
    variable == "MSpT" ~ "spring cooling",
    variable == "MWT" & direction == "increasing" ~ "winter warming",
    variable == "MWT" ~ "winter cooling",
    variable == "SP" & direction == "increasing" ~ "summer wetting",
    variable == "SP" ~ "summer drying",
    variable == "WP" & direction == "increasing" ~ "winter wetting",
    TRUE ~ "winter drying"))
era_catalog = climate$era_catalog |>
  mutate(active_variable_directions = map2_chr(
    older_cal_bp, younger_cal_bp, function(era_old, era_young) {
      direction_terms |>
        filter(.data$older_cal_bp > era_young,
               .data$younger_cal_bp < era_old) |>
        pull(.data$driver_label) |> unique() |> paste(collapse = ";")
    })) |>
  mutate(analytical_status = paste(
    "literature-blind operational era; joined downstream to descriptive",
    "lake-level tracking summaries without changing boundaries"))

# Descriptive subdivisions are permitted only where an internal, sustained
# low-driver interval separates two multi-driver parts of a climate-change era.
climate_subphases = subdivide_climate_change_eras(
  climate$variable_cells, era_catalog, min_trough_years = 300L,
  driver_coverage = 0.60)

# =============================================================================
# FIRE: source-specific accepted events, independent 1,000-year frequency rule
# =============================================================================
events = read_csv(FIRE_EVENTS, show_col_types = FALSE)
continuous = read_csv(FIRE_SERIES, show_col_types = FALSE)
fire = calculate_fire_frequency(events, continuous, 1000L, 100L)

fire_settings = read_csv(FIRE_SETTINGS, show_col_types = FALSE) |>
  transmute(site, lake, engine, chronology, interpolation_years,
    background_years = smoothing_years,
    peak_probability = threshold_probability,
    minimum_count_probability, minimum_count_window_years,
    analytical_role = if_else(site == "MORA",
      "regional MORA evidence; Walsh settings implemented in tapas",
      "local Panther Potholes evidence; Prichard-style settings implemented in tapas"))
if (nrow(fire_settings) != 4L || any(fire_settings$engine != "tapas"))
  stop("High-fire periods require four all-tapas source settings.")

# =============================================================================
# AUDIT OUTPUTS
# =============================================================================
write_csv(climate$site_standardized,
  out("holocene_era_climate_site_phase_changes.csv"))
write_csv(climate$regional_phases,
  out("holocene_era_climate_regional_phase_changes.csv"))
write_csv(climate$thresholds,
  out("holocene_era_climate_variable_thresholds.csv"))
write_csv(climate$variable_cells,
  out("holocene_era_climate_directional_cells.csv"))
write_csv(climate$era_grid, out("holocene_era_grid.csv"))
write_csv(era_catalog, out("holocene_era_catalog.csv"))
write_csv(direction_terms, out("holocene_era_driver_subintervals.csv"))
write_csv(climate_subphases,
  out("holocene_era_climate_change_subphases.csv"))
write_csv(composite$site_phase,
  out("holocene_era_climate_composite_site_phase.csv"))
write_csv(fire_settings, out("holocene_era_fire_source_settings.csv"))
write_csv(fire$core, out("holocene_era_fire_core_frequency.csv"))
write_csv(fire$site_grid, out("holocene_era_fire_site_frequency.csv"))
write_csv(fire$thresholds, out("holocene_era_fire_thresholds.csv"))
write_csv(fire$periods, out("holocene_era_high_fire_periods.csv"))


cat("Unified climate eras:\n")
print(as.data.frame(era_catalog |>
  select(era_id, era_class, older_cal_bp, younger_cal_bp,
         active_variable_directions)))
cat("High-fire periods: ", nrow(fire$periods), "\n", sep = "")
