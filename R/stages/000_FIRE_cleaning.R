# =============================================================================
# 000_FIRE_cleaning.R - harmonized tapas detection for the three MORA records
# =============================================================================
# The MORA records retain Walsh et al.'s record-specific interpolation,
# background, local 95% threshold, and minimum-count settings. The implementation
# is shared with Panther Potholes through R/helpers/fire_detection_functions.R.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(readxl); library(tapas)
})
source(here("R/helpers/fire_detection_functions.R"))

settings = fire_source_settings() |> filter(site == "MORA")
results = pmap(settings, function(site, lake, input_source, chronology,
                                  interpolation_years, smoothing_years,
                                  threshold_probability) {
  run_tapas_fire_detection(
    prepare_mora_charcoal(here(input_source)), site, lake,
    interpolation_years, smoothing_years, threshold_probability,
    chronology, input_source)
})

fire_episodes_final = map_dfr(results, "peaks")
series = map_dfr(results, "series")
events = map_dfr(results, "events")
settings_audit = map_dfr(results, "settings")

if (nrow(events) == 0L || anyDuplicated(events[c("lake", "age_cal_yr_BP")]))
  stop("The harmonized MORA accepted-event catalog is empty or duplicated.")

write_csv(fire_episodes_final, here("output/fire_walsh.csv"))
write_csv(series, here("output/fire_mora_tapas_series.csv"))
write_csv(events, here("output/fire_mora_tapas_events.csv"))
write_csv(settings_audit, here("output/fire_mora_tapas_settings.csv"))

cat("Harmonized tapas MORA fire episodes:\n")
print(as.data.frame(fire_episodes_final |>
  group_by(lake, smoothing_window, interpolation_interval,
           threshold_probability) |>
  summarise(candidate_peaks = n(), accepted_events = sum(is_significant),
            older_cal_bp = max(age_cal_yr_BP),
            younger_cal_bp = min(age_cal_yr_BP), .groups = "drop")))
