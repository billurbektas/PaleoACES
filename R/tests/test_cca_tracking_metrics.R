# =============================================================================
# test_cca_tracking_metrics.R - offline unit and integration gate
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
})
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/tracking_metrics.R"), local = TRUE)

# Tracking climate rates and scaling must follow the active fitted CCA exactly.
stopifnot(identical(CCA_VARIABLES, c("MSpT", "MWT", "SP", "WP")))

tol = 1e-10
near = function(x, y, tolerance = tol) {
  isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance = tolerance,
                   check.attributes = FALSE))
}

endpoint = function(o1 = 0, o2 = 0, o1_2, o2_2,
                    p1 = 0, p2 = 0, p1_2, p2_2,
                    vegetation_dt_years = 10, climate_dt_years = 10) {
  tibble(o1, o2, o1_2, o2_2, p1, p2, p1_2, p2_2,
         vegetation_dt_years, climate_dt_years)
}

# Perfect tracking: equal magnitude, rate and direction; no trajectory error.
perfect = endpoint(o1_2 = 1, o2_2 = 0, p1_2 = 1, p2_2 = 0) %>%
  calculate_tracking_metrics()
stopifnot(
  near(perfect$magnitude_tracking_ratio, 1),
  near(perfect$rate_tracking_ratio, 1),
  near(perfect$angle_degrees, 0),
  near(perfect$cosine_similarity, 1),
  near(perfect$climate_aligned_tracking, 1),
  near(perfect$perpendicular_movement, 0),
  near(perfect$tracking_error, 0)
)

# Opposite and perpendicular vectors exercise sign, angle and projection.
opposite = endpoint(o1_2 = -1, o2_2 = 0, p1_2 = 1, p2_2 = 0) %>%
  calculate_tracking_metrics()
stopifnot(near(opposite$angle_degrees, 180),
          near(opposite$cosine_similarity, -1),
          near(opposite$climate_aligned_displacement, -1),
          near(opposite$climate_aligned_tracking, -1),
          near(opposite$tracking_error, 2))

perpendicular = endpoint(o1_2 = 0, o2_2 = 1, p1_2 = 1, p2_2 = 0) %>%
  calculate_tracking_metrics()
stopifnot(near(perpendicular$angle_degrees, 90),
          near(perpendicular$cosine_similarity, 0),
          near(perpendicular$climate_aligned_displacement, 0),
          near(perpendicular$perpendicular_movement, 1))

# Equal displacements need not imply equal rates if their elapsed times differ.
unequal_dt = endpoint(o1_2 = 1, o2_2 = 0, p1_2 = 1, p2_2 = 0,
                      vegetation_dt_years = 20, climate_dt_years = 10) %>%
  calculate_tracking_metrics()
stopifnot(near(unequal_dt$magnitude_tracking_ratio, 1),
          near(unequal_dt$observed_turnover_rate, 5),
          near(unequal_dt$predicted_vegetation_change_rate, 10),
          near(unequal_dt$rate_tracking_ratio, 0.5))

# Lag is the signed change in endpoint mismatch. Its rate uses the climate
# interval, not the plot-specific vegetation interval.
lag_test = endpoint(o1 = 0, o2 = 0, o1_2 = 1, o2_2 = 0,
                    p1 = 1, p2 = 0, p1_2 = 3, p2_2 = 0,
                    vegetation_dt_years = 20, climate_dt_years = 50) %>%
  calculate_tracking_metrics()
stopifnot(near(lag_test$lag_t1, 1), near(lag_test$lag_t2, 2),
          near(lag_test$change_in_lag, 1), near(lag_test$lag, 1),
          near(lag_test$lag_rate_per_century, 2))

# A tiny predicted vector invalidates denominator and directional metrics, but
# tracking error and lag remain defined. A stationary observed vector has valid
# zero magnitude/rate ratios but no meaningful direction.
zero_pred = endpoint(o1_2 = 1, o2_2 = 0, p1_2 = 0, p2_2 = 0) %>%
  calculate_tracking_metrics()
stopifnot(zero_pred$small_predicted_movement,
          is.na(zero_pred$magnitude_tracking_ratio),
          is.na(zero_pred$rate_tracking_ratio),
          is.na(zero_pred$angle_degrees),
          is.na(zero_pred$climate_aligned_tracking),
          near(zero_pred$tracking_error, 1))

zero_obs = endpoint(o1_2 = 0, o2_2 = 0, p1_2 = 1, p2_2 = 0) %>%
  calculate_tracking_metrics()
stopifnot(zero_obs$small_observed_movement,
          near(zero_obs$magnitude_tracking_ratio, 0),
          near(zero_obs$rate_tracking_ratio, 0),
          is.na(zero_obs$angle_degrees),
          is.na(zero_obs$climate_aligned_displacement),
          near(zero_obs$tracking_error, 1))

tiny = endpoint(o1_2 = 1, o2_2 = 0, p1_2 = 1e-9, p2_2 = 0) %>%
  calculate_tracking_metrics(epsilon = 1e-8)
stopifnot(tiny$small_predicted_movement, is.na(tiny$normalized_tracking_error))

# Physical climate rates and their standardized Euclidean combination.
scale_test = tibble(variable = CCA_CLIMATE_VARS,
                    mean = c(0, 0, 0, 0), sd = c(2, 4, 10, 20),
                    n_calibration = 10L,
                    unit = c("degrees_C", "degrees_C", "mm", "mm"))
clim_test = tibble(
  climate_dt_years = 50,
  MSpT = 0, MWT = 0, SP = 0, WP = 0,
  MSpT_2 = 1, MWT_2 = -2, SP_2 = 5, WP_2 = -10
) %>% add_climate_change_metrics(scale_test)
stopifnot(near(clim_test$MSpT_rate_per_century, 2),
          near(clim_test$MWT_rate_per_century, -4),
          near(clim_test$SP_rate_per_century, 10),
          near(clim_test$WP_rate_per_century, -20),
          near(clim_test$standardized_climate_displacement, 1),
          near(clim_test$standardized_climate_change_rate, 2))

# Integration outputs ---------------------------------------------------------
paths = here("output", c(
  "cca_tracking_climate_scaling.csv",
  "cca_tracking_anthropocene_plot.csv",
  "cca_tracking_anthropocene_site.csv",
  "cca_tracking_holocene_realizations.csv",
  "cca_tracking_holocene_by_offset.csv",
  "cca_tracking_holocene_timeseries.csv"
))
if (!all(file.exists(paths)))
  stop("Missing tracking output(s): ", paste(paths[!file.exists(paths)], collapse = ", "))

scaling = read_csv(paths[1], show_col_types = FALSE)
anth = read_csv(paths[2], show_col_types = FALSE)
holo = read_csv(paths[4], show_col_types = FALSE)
by_offset = read_csv(paths[5], show_col_types = FALSE)
timeseries = read_csv(paths[6], show_col_types = FALSE)

stopifnot(setequal(scaling$variable, CCA_CLIMATE_VARS),
          all(scaling$sd > 0),
          nrow(anth) == 607L,
          all(table(anth$site)[c("MORA", "NOCA")] == c(330L, 277L)),
          !anyDuplicated(anth$plot_id),
          !anyNA(anth$vegetation_t2_year),
          identical(range(anth$vegetation_t2_year[anth$site == "MORA"]),
                    c(2014, 2019)),
          all(anth$vegetation_dt_years > 0),
          !anyDuplicated(holo %>% select(site, offset, draw, age_hi, age_lo)),
          all(holo$age_hi - holo$age_lo == 1000),
          setequal(unique(holo$offset), seq(0, 900, by = 100)),
          setequal(unique(holo$draw), seq_len(100)),
          identical(holo$sparse_bin, holo$n_min < 2L))

stopifnot(
  max(abs(holo$lag - holo$change_in_lag), na.rm = TRUE) < 1e-12,
  max(abs(holo$lag_rate_per_century - holo$lag / 10), na.rm = TRUE) < 1e-12,
  max(abs(anth$lag - anth$change_in_lag), na.rm = TRUE) < 1e-12,
  max(abs(anth$lag_rate_per_century -
          anth$lag / anth$climate_dt_years * 100), na.rm = TRUE) < 1e-12
)

holo_500 = read_csv(here("output/cca_tracking_holocene_realizations_500yr.csv"),
                    show_col_types = FALSE)
stopifnot(all(holo_500$age_hi - holo_500$age_lo == 500),
          setequal(unique(holo_500$offset), seq(0, 400, by = 100)),
          setequal(unique(holo_500$draw), seq_len(100)))

# The Holocene identity is algebra, not an independent result: both rates divide
# their respective displacements by the same 1,000 years. It is checked only where
# the predicted denominator is valid.
holo_valid = holo %>% filter(!small_predicted_movement)
stopifnot(max(abs(holo_valid$rate_tracking_ratio -
                  holo_valid$magnitude_tracking_ratio), na.rm = TRUE) < 1e-10)

# The unequal-dt synthetic case above proves the identity is not assumed for the
# Anthropocene. Current plot-specific intervals should produce real differences.
anth_valid = anth %>% filter(!small_predicted_movement)
stopifnot(any(abs(anth_valid$rate_tracking_ratio -
                  anth_valid$magnitude_tracking_ratio) > 1e-6))

# Independently recalculate every realization's combined standardized climate
# rate and a deterministic sample of the nonlinear CCA metrics.
z_rate_cols = paste0(CCA_CLIMATE_VARS, "_z_rate_per_century")
combined = sqrt(rowSums(holo[z_rate_cols]^2))
stopifnot(max(abs(combined - holo$standardized_climate_change_rate)) < 1e-10)

idx = unique(round(seq(1, nrow(holo), length.out = 101)))
recalc = sqrt((holo$o1_2[idx] - holo$o1[idx])^2 +
              (holo$o2_2[idx] - holo$o2[idx])^2)
stopifnot(max(abs(recalc - holo$observed_vegetation_displacement[idx])) < 1e-10)
recalc_error = sqrt(
  ((holo$o1_2[idx] - holo$o1[idx]) - (holo$p1_2[idx] - holo$p1[idx]))^2 +
  ((holo$o2_2[idx] - holo$o2[idx]) - (holo$p2_2[idx] - holo$p2[idx]))^2
)
stopifnot(max(abs(recalc_error - holo$tracking_error[idx])) < 1e-10)

# Bin climate is fixed at site x offset x interval; draws move samples, not the
# climate. Therefore actual and LC-predicted climate-only quantities must have
# zero variation across draws for the same interval.
climate_fixed = holo %>%
  group_by(site, offset, age_hi, age_lo) %>%
  summarize(n_climate_rate = n_distinct(round(standardized_climate_change_rate, 12)),
            n_predicted = n_distinct(round(predicted_vegetation_displacement, 12)),
            .groups = "drop")
stopifnot(all(climate_fixed$n_climate_rate == 1L),
          all(climate_fixed$n_predicted == 1L))

# Verify draw-first summaries for representative metrics and all interval keys.
check_metrics = c("rate_tracking_ratio", "angle_degrees",
                  "standardized_climate_change_rate", "change_in_lag")
manual = holo %>%
  select(site, offset, age_hi, age_lo, all_of(check_metrics)) %>%
  pivot_longer(all_of(check_metrics), names_to = "metric", values_to = "value") %>%
  group_by(site, offset, age_hi, age_lo, metric) %>%
  summarize(manual_median = median(value, na.rm = TRUE), .groups = "drop")
recorded = by_offset %>%
  filter(metric %in% check_metrics) %>%
  select(site, offset, age_hi, age_lo, metric, recorded_median = median)
summary_check = inner_join(manual, recorded,
                           by = c("site", "offset", "age_hi", "age_lo", "metric"))
stopifnot(nrow(summary_check) == nrow(manual),
          max(abs(summary_check$manual_median - summary_check$recorded_median),
              na.rm = TRUE) < 1e-10,
          all(timeseries$n_offsets == 10L))

# The primary grid uses half-open intervals [age_lo, age_hi), so an internal
# boundary cannot be assigned to two adjacent intervals in the same offset.
grid = tibble(t = seq(floor(min(holo$age_lo) / 100) * 100,
                      ceiling(max(holo$age_hi) / 100) * 100, by = 100))
mapped = by_offset %>%
  inner_join(grid, by = join_by(y$t >= x$age_lo, y$t < x$age_hi))
stopifnot(!anyDuplicated(mapped %>% select(site, offset, metric, t)))
date_coverage = timeseries %>% distinct(site, t) %>%
  group_by(site) %>% summarize(n_dates = n(), t_min = min(t), t_max = max(t),
                               .groups = "drop")
expected_coverage = tribble(
  ~site, ~n_dates, ~t_min, ~t_max,
  "MORA", 54L, 1300, 6600,
  "NOCA", 83L, 1300, 9500)
stopifnot(identical(date_coverage, expected_coverage))

# Re-source the model only for invariants and calibration-reference provenance.
source(here("R/stages/05_cca_model.R"), local = TRUE)
expected_scaling = make_climate_scaling(env_past_final, CCA_CLIMATE_VARS)
stopifnot(identical(cca_scaling, "sites"), !cca_hill,
          nrow(species_past_final) == 620L,
          ncol(species_past_final) == 13L,
          near(scaling$mean, expected_scaling$mean),
          near(scaling$sd, expected_scaling$sd))

cat("CCA tracking metric tests passed: synthetic formulas, 607 plots, ",
    format(nrow(holo), big.mark = ","), " Holocene realizations, draw-first summaries, ",
    "and fixed model/scaling.\n", sep = "")
