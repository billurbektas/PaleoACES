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

# Internal angle utility: no direction is assigned to nonfinite or tiny vectors.
safe_cosine_2d = function(ax, ay, bx, by, epsilon = TRACKING_EPSILON) {
  sizes = lengths(list(ax, ay, bx, by))
  n = max(sizes)
  if (any(!sizes %in% c(1L, n)) || !is.finite(epsilon) || epsilon <= 0)
    stop("Invalid vector lengths or movement tolerance")
  ax = rep_len(ax, n); ay = rep_len(ay, n)
  bx = rep_len(bx, n); by = rep_len(by, n)
  a = sqrt(ax^2 + ay^2); b = sqrt(bx^2 + by^2)
  ok = is.finite(a) & is.finite(b) & a > epsilon & b > epsilon
  result = rep(NA_real_, n)
  result[ok] = pmax(-1, pmin(1, (ax[ok]*bx[ok] + ay[ok]*by[ok])/(a[ok]*b[ok])))
  result
}

tracking_metric_names = function() c(
  "observed_vegetation_displacement", "predicted_vegetation_displacement",
  "observed_turnover_rate", "predicted_vegetation_change_rate",
  "magnitude_tracking_ratio", "rate_tracking_ratio", "angle_degrees",
  "lag_t1", "lag_t2", "change_in_lag", "lag_rate_per_century",
  "lag_t2_pace_corrected", "lag_t2_direction_corrected",
  "pace_effect_on_lag", "direction_effect_on_lag",
  "pace_effect_on_lag_per_century", "direction_effect_on_lag_per_century")

climate_metric_names = function(vars = CCA_CLIMATE_VARS) c(
  unlist(lapply(vars, function(v) paste0(v, c("_change", "_rate_per_century",
    "_z_change", "_z_rate_per_century")))),
  "standardized_climate_displacement", "standardized_climate_change_rate")

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

# Six response families and their supporting geometry, in one CCA1-CCA2 space.
# Counterfactuals start at the actual O1 and compare with the actual final P2.
# They correct displacement magnitude/direction, are nonadditive and noncausal.
calculate_tracking_metrics = function(x, epsilon = TRACKING_EPSILON) {
  coords = c("o1", "o2", "o1_2", "o2_2", "p1", "p2", "p1_2", "p2_2")
  need = c(coords, "vegetation_dt_years", "climate_dt_years")
  if (!all(need %in% names(x))) stop("Missing tracking endpoint/time columns")
  if (length(epsilon) != 1L || !is.finite(epsilon) || epsilon <= 0)
    stop("Movement tolerance must be finite and positive")
  if (any(!is.finite(x$vegetation_dt_years) | x$vegetation_dt_years <= 0) ||
      any(!is.finite(x$climate_dt_years) | x$climate_dt_years <= 0))
    stop("Elapsed times must be finite and positive")
# report-snippet: tracking-geometry
  # One row per unit (a Holocene lake-period or an Anthropocene plot pair),
  # with two ends, t1 (older) and t2 (younger). At each end the community has
  # an observed position (o1, o2: from its species) and a predicted position
  # (p1, p2: from its climate) on the two CCA axes. The suffix _2 marks t2.
  # Movement from t1 to t2: observed (ox, oy), predicted (px, py), and their
  # lengths a (observed distance) and b (predicted distance).
  ox = x$o1_2-x$o1; oy = x$o2_2-x$o2
  px = x$p1_2-x$p1; py = x$p2_2-x$p2
  a = sqrt(ox^2+oy^2); b = sqrt(px^2+py^2)
  # A movement shorter than epsilon has no direction, so the angle, the pace
  # and direction effects and the tracking ratio are left undefined there.
  x$finite_endpoints = rowSums(!is.finite(as.matrix(x[coords]))) == 0L
  x$small_observed_movement = is.finite(a) & a <= epsilon
  x$small_predicted_movement = is.finite(b) & b <= epsilon
  observed_direction = x$finite_endpoints & is.finite(a) & a > epsilon
  predicted_direction = x$finite_endpoints & is.finite(b) & b > epsilon
  x$angle_valid = observed_direction & predicted_direction
  x$pace_counterfactual_valid = observed_direction
  x$direction_counterfactual_valid = predicted_direction
  x$tracking_ratio_valid = predicted_direction
  x$delta_observed_CCA1 = ox; x$delta_observed_CCA2 = oy
  x$delta_predicted_CCA1 = px; x$delta_predicted_CCA2 = py
  x$observed_vegetation_displacement = a
  x$predicted_vegetation_displacement = b
  # Turnover rate: observed distance moved, per century. Tracking ratio:
  # observed over predicted distance (1 = moved as far as climate asked).
  # Angle: between the observed and the predicted movement (0 = same way).
  x$observed_turnover_rate = a/x$vegetation_dt_years*100
  x$predicted_vegetation_change_rate = b/x$climate_dt_years*100
  x$magnitude_tracking_ratio = ifelse(predicted_direction, a/b, NA_real_)
  x$rate_tracking_ratio = ifelse(predicted_direction,
    x$observed_turnover_rate/x$predicted_vegetation_change_rate, NA_real_)
  x$angle_degrees = acos(safe_cosine_2d(ox, oy, px, py, epsilon))*180/pi
  # Lag M at each end: the distance between observed and predicted position,
  # how far the community is from where its climate would put it. The lag is
  # M at t2 minus M at t1 (positive: the gap grew), the lag rate the same per
  # century.
  x$lag_t1 = sqrt((x$o1-x$p1)^2+(x$o2-x$p2)^2)
  x$lag_t2 = sqrt((x$o1_2-x$p1_2)^2+(x$o2_2-x$p2_2)^2)
  x$change_in_lag = x$lag_t2-x$lag_t1
  x$lag_rate_per_century = x$change_in_lag/x$climate_dt_years*100
# end-snippet: tracking-geometry

  # Only divide by a direction's magnitude when that direction is defined.
# report-snippet: tracking-corrections
  # Two "what if" end points at t2, both starting from the observed t1 position:
  #   pace-corrected: the community's own direction, but the predicted
  #     distance b (as if it had moved at the climate's pace);
  #   direction-corrected: the predicted direction, but its own distance a
  #     (as if it had moved the climate's way).
  # Each effect is the observed lag at t2 minus the lag at that "what if" end
  # point, per century. Positive: the community's own pace (or direction)
  # widened the lag. Negative: it narrowed the lag.
  x$pace_corrected_CCA1 = x$pace_corrected_CCA2 = rep(NA_real_, nrow(x))
  x$direction_corrected_CCA1 = x$direction_corrected_CCA2 = rep(NA_real_, nrow(x))
  i = observed_direction
  x$pace_corrected_CCA1[i] = x$o1[i]+b[i]*ox[i]/a[i]
  x$pace_corrected_CCA2[i] = x$o2[i]+b[i]*oy[i]/a[i]
  i = predicted_direction
  x$direction_corrected_CCA1[i] = x$o1[i]+a[i]*px[i]/b[i]
  x$direction_corrected_CCA2[i] = x$o2[i]+a[i]*py[i]/b[i]
  x$lag_t2_pace_corrected = sqrt((x$pace_corrected_CCA1-x$p1_2)^2+
    (x$pace_corrected_CCA2-x$p2_2)^2)
  x$lag_t2_direction_corrected = sqrt((x$direction_corrected_CCA1-x$p1_2)^2+
    (x$direction_corrected_CCA2-x$p2_2)^2)
  x$pace_effect_on_lag = x$lag_t2-x$lag_t2_pace_corrected
  x$direction_effect_on_lag = x$lag_t2-x$lag_t2_direction_corrected
  x$pace_effect_on_lag_per_century = x$pace_effect_on_lag/x$climate_dt_years*100
  x$direction_effect_on_lag_per_century = x$direction_effect_on_lag/x$climate_dt_years*100
# end-snippet: tracking-corrections
  x
}

# Additional modeling responses derived from the maintained counterfactual
# geometry. Apply within each realization before taking chronology medians;
# subtracting medians of lag rate and effect does not preserve this identity.
add_corrected_lag_rates = function(x) {
  needed = c('lag_t1', 'lag_t2_pace_corrected', 'lag_t2_direction_corrected',
    'climate_dt_years', 'pace_counterfactual_valid', 'direction_counterfactual_valid')
  if (!all(needed %in% names(x)) ||
      any(!is.finite(x$climate_dt_years) | x$climate_dt_years <= 0))
    stop('Missing corrected-lag calculations or invalid climate elapsed time')
  x$pace_corrected_lag_rate_per_century = ifelse(x$pace_counterfactual_valid,
    (x$lag_t2_pace_corrected-x$lag_t1)*100/x$climate_dt_years, NA_real_)
  x$direction_corrected_lag_rate_per_century = ifelse(x$direction_counterfactual_valid,
    (x$lag_t2_direction_corrected-x$lag_t1)*100/x$climate_dt_years, NA_real_)
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
    metric %in% c("magnitude_tracking_ratio", "rate_tracking_ratio") ~ "unitless",
    metric %in% c("observed_turnover_rate", "predicted_vegetation_change_rate") |
      grepl("^(lag_rate|pace_effect|direction_effect).*per_century$", metric) ~ "CCA_units_per_century",
    metric %in% tracking_metric_names() ~ "CCA_units",
    grepl("_z_rate_per_century$", metric) | metric == "standardized_climate_change_rate" ~ "calibration_SD_per_century",
    grepl("_z_change$", metric) | metric == "standardized_climate_displacement" ~ "calibration_SD",
    grepl("_rate_per_century$", metric) ~ paste0(unname(CLIMATE_VARIABLE_UNITS[sub("_rate_per_century$", "", metric)]), "_per_century"),
    grepl("_change$", metric) ~ unname(CLIMATE_VARIABLE_UNITS[sub("_change$", "", metric)]),
    TRUE ~ NA_character_
  )
}

safe_stat = function(x, fun, ...) {
  x = x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  fun(x, ...)
}
