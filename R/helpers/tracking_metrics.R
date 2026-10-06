# =============================================================================
# tracking_metrics.R - pure functions for CCA tracking and climate-change rates
# =============================================================================
# This file has no data-loading or file-writing side effects. Both the executable
# tracking stage and its unit tests source these functions.
#
# Required endpoint columns in `calculate_tracking_metrics()`:
#   observed WA: o1, o2 at t1 and o1_2, o2_2 at t2
#   predicted LC: p1, p2 at t1 and p1_2, p2_2 at t2
#   elapsed years: vegetation_dt_years and climate_dt_years
#
# Required climate columns in `add_climate_change_metrics()`:
#   the configured CCA variables at t1 and their `_2` counterparts at t2.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

TRACKING_EPSILON = 1e-8
if (!exists("CCA_VARIABLES") || !exists("CLIMATE_VARIABLE_UNITS"))
  stop("Source R/helpers/config.R before R/helpers/tracking_metrics.R")
CCA_CLIMATE_VARS = CCA_VARIABLES

# Vectorized two-dimensional cosine used by the community-direction stage.
# Magnitudes are returned with the association so every undefined direction is
# auditable. Non-finite components and vectors at or below `epsilon` are never
# assigned an arbitrary direction.
safe_cosine_2d = function(movement_x, movement_y, target_x, target_y,
                          epsilon = TRACKING_EPSILON) {
  lengths = lengths(list(movement_x, movement_y, target_x, target_y))
  n = max(lengths)
  if (any(!lengths %in% c(1L, n)))
    stop("safe_cosine_2d(): inputs must have a common length or length one")
  if (!is.numeric(epsilon) || length(epsilon) != 1L ||
      !is.finite(epsilon) || epsilon <= 0)
    stop("safe_cosine_2d(): epsilon must be one positive finite number")

  movement_x = rep_len(movement_x, n)
  movement_y = rep_len(movement_y, n)
  target_x = rep_len(target_x, n)
  target_y = rep_len(target_y, n)
  nonfinite_input = !(is.finite(movement_x) & is.finite(movement_y) &
                      is.finite(target_x) & is.finite(target_y))
  movement_magnitude = sqrt(movement_x^2 + movement_y^2)
  target_magnitude = sqrt(target_x^2 + target_y^2)
  small_movement = !is.finite(movement_magnitude) |
    movement_magnitude <= epsilon
  small_target_vector = !is.finite(target_magnitude) |
    target_magnitude <= epsilon
  association_valid = !(nonfinite_input | small_movement | small_target_vector)
  association = rep(NA_real_, n)
  association[association_valid] =
    (movement_x[association_valid] * target_x[association_valid] +
     movement_y[association_valid] * target_y[association_valid]) /
    (movement_magnitude[association_valid] * target_magnitude[association_valid])
  association[association_valid] = pmax(-1, pmin(1,
    association[association_valid]))

  tibble(
    association,
    movement_magnitude,
    target_magnitude,
    nonfinite_input,
    small_movement,
    small_target_vector,
    association_valid
  )
}

tracking_metric_names = function() {
  c(
    "predicted_vegetation_displacement",
    "observed_vegetation_displacement",
    "predicted_vegetation_change_rate",
    "observed_turnover_rate",
    "magnitude_tracking_ratio",
    "rate_tracking_ratio",
    "angle_degrees",
    "cosine_similarity",
    "climate_aligned_displacement",
    "climate_aligned_tracking",
    "perpendicular_movement",
    "normalized_perpendicular_movement",
    "tracking_error",
    "normalized_tracking_error",
    "lag_t1", "lag_t2", "change_in_lag", "lag", "lag_rate_per_century"
  )
}

climate_metric_names = function(vars = CCA_CLIMATE_VARS) {
  c(
    unlist(lapply(vars, function(v) c(
      paste0(v, "_change"),
      paste0(v, "_rate_per_century"),
      paste0(v, "_z_change"),
      paste0(v, "_z_rate_per_century")
    ))),
    "standardized_climate_displacement",
    "standardized_climate_change_rate"
  )
}

all_cca_metric_names = function(vars = CCA_CLIMATE_VARS) {
  c(tracking_metric_names(), climate_metric_names(vars))
}

# Return the fixed standardization reference used by both eras. The pooled
# legacy calibration set is the reference because it trained the CCA; using a
# future or paleo distribution would make one era help define the other's scale.
make_climate_scaling = function(calibration_env, vars = CCA_CLIMATE_VARS) {
  missing = setdiff(vars, names(calibration_env))
  if (length(missing))
    stop("make_climate_scaling(): missing calibration variable(s): ",
         paste(missing, collapse = ", "))

  out = tibble(
    variable = vars,
    mean = vapply(calibration_env[vars], mean, numeric(1), na.rm = TRUE),
    sd = vapply(calibration_env[vars], stats::sd, numeric(1), na.rm = TRUE),
    n_calibration = vapply(calibration_env[vars], function(x) sum(is.finite(x)), integer(1)),
    unit = unname(CLIMATE_VARIABLE_UNITS[variable])
  )
  if (any(!is.finite(out$sd) | out$sd <= 0))
    stop("make_climate_scaling(): every calibration SD must be finite and positive")
  out
}

# Calculate the PDF's metrics from two displacement vectors.
#
# Delta O = O(t2)-O(t1): observed vegetation movement from WA scores.
# Delta P = P(t2)-P(t1): climate-predicted vegetation movement from LC scores.
# DO and DP are their Euclidean lengths in CCA1-CCA2 space.
# Rates use their own elapsed times and are expressed per century.
#
# Directional quantities are deliberately NA when either vector is too short to
# have a meaningful direction. Magnitudes, raw rates, tracking error and lag are
# retained wherever they remain mathematically defined.
calculate_tracking_metrics = function(x, epsilon = TRACKING_EPSILON) {
  need = c("o1", "o2", "o1_2", "o2_2", "p1", "p2", "p1_2", "p2_2",
           "vegetation_dt_years", "climate_dt_years")
  missing = setdiff(need, names(x))
  if (length(missing))
    stop("calculate_tracking_metrics(): missing column(s): ",
         paste(missing, collapse = ", "))
  if (!is.numeric(epsilon) || length(epsilon) != 1L || !is.finite(epsilon) || epsilon <= 0)
    stop("calculate_tracking_metrics(): epsilon must be one positive finite number")
  if (any(!is.finite(x$vegetation_dt_years) | x$vegetation_dt_years <= 0) ||
      any(!is.finite(x$climate_dt_years) | x$climate_dt_years <= 0))
    stop("calculate_tracking_metrics(): elapsed times must be finite and positive")

  d_o1 = x$o1_2 - x$o1
  d_o2 = x$o2_2 - x$o2
  d_p1 = x$p1_2 - x$p1
  d_p2 = x$p2_2 - x$p2
  d_o = sqrt(d_o1^2 + d_o2^2)
  d_p = sqrt(d_p1^2 + d_p2^2)
  dot = d_o1 * d_p1 + d_o2 * d_p2

  small_o = !is.finite(d_o) | d_o <= epsilon
  small_p = !is.finite(d_p) | d_p <= epsilon
  direction_ok = !(small_o | small_p)

  cosine = rep(NA_real_, nrow(x))
  cosine[direction_ok] = dot[direction_ok] / (d_o[direction_ok] * d_p[direction_ok])
  cosine[direction_ok] = pmax(-1, pmin(1, cosine[direction_ok]))

  parallel = rep(NA_real_, nrow(x))
  parallel[direction_ok] = dot[direction_ok] / d_p[direction_ok]
  perpendicular = rep(NA_real_, nrow(x))
  perpendicular[direction_ok] = sqrt(pmax(
    0, d_o[direction_ok]^2 - parallel[direction_ok]^2
  ))

  x$delta_observed_CCA1 = d_o1
  x$delta_observed_CCA2 = d_o2
  x$delta_predicted_CCA1 = d_p1
  x$delta_predicted_CCA2 = d_p2
  x$observed_vegetation_displacement = d_o
  x$predicted_vegetation_displacement = d_p
  x$observed_turnover_rate = d_o / x$vegetation_dt_years * 100
  x$predicted_vegetation_change_rate = d_p / x$climate_dt_years * 100
  x$small_observed_movement = small_o
  x$small_predicted_movement = small_p

  # M = DO/DP: displacement magnitudes only, irrespective of direction.
  x$magnitude_tracking_ratio = ifelse(small_p, NA_real_, d_o / d_p)
  # MR = RO/RP: whether vegetation turnover kept pace after applying the
  # appropriate, potentially different, vegetation and climate time intervals.
  x$rate_tracking_ratio = ifelse(
    small_p, NA_real_, x$observed_turnover_rate / x$predicted_vegetation_change_rate
  )
  # theta and cos(theta): directional agreement, undefined for a tiny vector.
  x$cosine_similarity = cosine
  x$angle_degrees = acos(cosine) * 180 / pi
  # D_parallel = DeltaO dot DeltaP / ||DeltaP||, in CCA units.
  x$climate_aligned_displacement = parallel
  # T_parallel = D_parallel/DP: predicted movement actually realized along the
  # predicted trajectory; negative values mean movement in the opposite direction.
  x$climate_aligned_tracking = ifelse(direction_ok, parallel / d_p, NA_real_)
  # D_perpendicular: observed turnover not aligned with the predicted trajectory.
  x$perpendicular_movement = perpendicular
  x$normalized_perpendicular_movement = ifelse(
    direction_ok, perpendicular / d_p, NA_real_
  )
  # E = ||DeltaO-DeltaP||: overall trajectory mismatch.
  x$tracking_error = sqrt((d_o1 - d_p1)^2 + (d_o2 - d_p2)^2)
  x$normalized_tracking_error = ifelse(small_p, NA_real_, x$tracking_error / d_p)
  # L(t) = ||P(t)-O(t)||. Lag is the signed endpoint change
  # L(t2)-L(t1): positive values mean that vegetation-climate mismatch opened,
  # while negative values mean it closed. Dividing by the climate interval
  # keeps this rate on the same temporal support as LC-predicted movement.
  x$lag_t1 = sqrt((x$p1 - x$o1)^2 + (x$p2 - x$o2)^2)
  x$lag_t2 = sqrt((x$p1_2 - x$o1_2)^2 + (x$p2_2 - x$o2_2)^2)
  x$change_in_lag = x$lag_t2 - x$lag_t1
  x$lag = x$change_in_lag
  x$lag_rate_per_century = x$lag / x$climate_dt_years * 100

  # Compatibility aliases used by the existing figures and worked example.
  x$d_climate = x$predicted_vegetation_displacement
  x$d_vegetation = x$observed_vegetation_displacement
  x$off_len_1 = x$lag_t1
  x$off_len_2 = x$lag_t2
  x$d_offset = x$change_in_lag
  x$d_offset_vec = x$tracking_error
  x
}

# Actual climate change in predictor space, kept separate from LC movement.
# Per-variable rates remain signed and in physical units. The combined index is
# the Euclidean norm after scaling every variable by its pooled legacy SD:
#   standardized rate = sqrt(sum_v ((X2_v-X1_v)/SD_v/dt*100)^2).
# It is nonnegative and measures multivariate climate speed; signed component
# columns retain whether each season became warmer/colder or wetter/drier.
add_climate_change_metrics = function(x, scaling, vars = CCA_CLIMATE_VARS) {
  need_scaling = c("variable", "mean", "sd", "unit", "n_calibration")
  if (!all(need_scaling %in% names(scaling)) || !setequal(vars, scaling$variable))
    stop("add_climate_change_metrics(): invalid or incomplete scaling table")
  need = c("climate_dt_years", vars, paste0(vars, "_2"))
  missing = setdiff(need, names(x))
  if (length(missing))
    stop("add_climate_change_metrics(): missing column(s): ",
         paste(missing, collapse = ", "))
  if (any(!is.finite(x$climate_dt_years) | x$climate_dt_years <= 0))
    stop("add_climate_change_metrics(): climate elapsed times must be positive")

  z_change_cols = character(0)
  z_rate_cols = character(0)
  for (v in vars) {
    s = scaling$sd[match(v, scaling$variable)]
    delta = x[[paste0(v, "_2")]] - x[[v]]
    x[[paste0(v, "_change")]] = delta
    x[[paste0(v, "_rate_per_century")]] = delta / x$climate_dt_years * 100
    x[[paste0(v, "_z_change")]] = delta / s
    x[[paste0(v, "_z_rate_per_century")]] = delta / s / x$climate_dt_years * 100
    z_change_cols = c(z_change_cols, paste0(v, "_z_change"))
    z_rate_cols = c(z_rate_cols, paste0(v, "_z_rate_per_century"))
  }
  x$standardized_climate_displacement = sqrt(rowSums(x[z_change_cols]^2))
  x$standardized_climate_change_rate = sqrt(rowSums(x[z_rate_cols]^2))
  x
}

metric_unit = function(metric) {
  case_when(
    metric == "angle_degrees" ~ "degrees",
    metric %in% c("magnitude_tracking_ratio", "rate_tracking_ratio",
                  "cosine_similarity", "climate_aligned_tracking",
                  "normalized_perpendicular_movement", "normalized_tracking_error") ~ "unitless",
    metric %in% c("predicted_vegetation_change_rate", "observed_turnover_rate",
                  "lag_rate_per_century") ~ "CCA_units_per_century",
    metric %in% c("predicted_vegetation_displacement", "observed_vegetation_displacement",
                  "climate_aligned_displacement", "perpendicular_movement",
                  "tracking_error", "lag_t1", "lag_t2", "change_in_lag", "lag") ~ "CCA_units",
    sub("_(change|rate_per_century)$", "", metric) %in%
      names(CLIMATE_VARIABLE_UNITS)[CLIMATE_VARIABLE_UNITS == "degrees_C"] &
      grepl("_change$", metric) ~ "degrees_C",
    sub("_(change|rate_per_century)$", "", metric) %in%
      names(CLIMATE_VARIABLE_UNITS)[CLIMATE_VARIABLE_UNITS == "degrees_C"] &
      grepl("_rate_per_century$", metric) ~ "degrees_C_per_century",
    sub("_(change|rate_per_century)$", "", metric) %in%
      names(CLIMATE_VARIABLE_UNITS)[CLIMATE_VARIABLE_UNITS == "mm"] &
      grepl("_change$", metric) ~ "mm",
    sub("_(change|rate_per_century)$", "", metric) %in%
      names(CLIMATE_VARIABLE_UNITS)[CLIMATE_VARIABLE_UNITS == "mm"] &
      grepl("_rate_per_century$", metric) ~ "mm_per_century",
    grepl("_z_change$", metric) | metric == "standardized_climate_displacement" ~ "calibration_SD",
    grepl("_z_rate_per_century$", metric) | metric == "standardized_climate_change_rate" ~ "calibration_SD_per_century",
    TRUE ~ NA_character_
  )
}

safe_stat = function(x, fun, ...) {
  x = x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  fun(x, ...)
}

# Long descriptive summaries. These are distributions over ecological plots for
# the Anthropocene, but descriptive posterior summaries over age draws for the
# Holocene; callers label that distinction explicitly.
summarize_metric_distribution = function(x, group_cols, metrics) {
  x %>%
    pivot_longer(all_of(metrics), names_to = "metric", values_to = "value") %>%
    group_by(across(all_of(c(group_cols, "metric")))) %>%
    summarize(
      n_total = n(),
      n_valid = sum(is.finite(value)),
      n_missing = n_total - n_valid,
      mean = safe_stat(value, base::mean),
      sd = safe_stat(value, stats::sd),
      median = safe_stat(value, stats::median),
      q025 = safe_stat(value, stats::quantile, probs = 0.025, names = FALSE),
      q25 = safe_stat(value, stats::quantile, probs = 0.25, names = FALSE),
      q75 = safe_stat(value, stats::quantile, probs = 0.75, names = FALSE),
      q975 = safe_stat(value, stats::quantile, probs = 0.975, names = FALSE),
      .groups = "drop"
    ) %>%
    mutate(unit = metric_unit(metric), .after = metric)
}
