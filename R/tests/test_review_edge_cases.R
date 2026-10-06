# Independent known examples and regressions from the 2026-10-06 audit.
# This gate needs no local raw data, stored posteriors, or network access.
suppressPackageStartupMessages(library(here))
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/tracking_metrics.R"), local = TRUE)
source(here("R/helpers/functions.R"), local = TRUE)
source(here("R/helpers/holocene_climate_fire_era_functions.R"), local = TRUE)
must_fail = function(expr) stopifnot(inherits(tryCatch(
  {force(expr); NULL}, error = identity), "error"))
equal = function(x, y) stopifnot(isTRUE(all.equal(x, y, tolerance = 1e-10,
                                                check.attributes = FALSE)))

# Missing change classes have zero counts, including entirely persistent groups.
for (periods in list(c("past", "present"), "past", "present")) {
  turnover = calculate_turnover(tibble::tibble(plot_id = "A", species = "SP1",
    period = periods, occurrence = 1))
  equal(turnover$plot_turnover$turnover_rate,
        if (length(periods) == 2L) 0 else 1)
  equal(turnover$species_turnover$total_occurrences, 1)
}

# O moves (3,4); P moves (4,0). Distinct elapsed times separate M from MR.
x = data.frame(o1 = 0, o2 = 0, o1_2 = 3, o2_2 = 4,
               p1 = 1, p2 = 0, p1_2 = 5, p2_2 = 0,
               vegetation_dt_years = 20, climate_dt_years = 40)
m = calculate_tracking_metrics(x)
equal(m$observed_vegetation_displacement, 5)
equal(m$predicted_vegetation_displacement, 4)
equal(m$observed_turnover_rate, 25)
equal(m$predicted_vegetation_change_rate, 10)
equal(m$magnitude_tracking_ratio, 1.25)
equal(m$rate_tracking_ratio, 2.5)
equal(m$cosine_similarity, .6)
equal(m$climate_aligned_displacement, 3)
equal(m$perpendicular_movement, 4)
equal(m$tracking_error, sqrt(17))
equal(m$lag, sqrt(20) - 1)

transform_endpoints = function(x, matrix, translation = c(0, 0)) {
  for (cols in list(c("o1", "o2"), c("p1", "p2"),
                   c("o1_2", "o2_2"), c("p1_2", "p2_2")))
    x[cols] = sweep(as.matrix(x[cols]) %*% t(matrix), 2, translation, "+")
  x
}
for (a in list(diag(2), matrix(c(0, 1, -1, 0), 2), diag(c(-1, 1)))) {
  y = calculate_tracking_metrics(transform_endpoints(x, a, c(17, -23)))
  equal(y[tracking_metric_names()], m[tracking_metric_names()])
}
y = calculate_tracking_metrics(transform_endpoints(x, 5 * diag(2)))
equal(y$cosine_similarity, m$cosine_similarity)
equal(y$rate_tracking_ratio, m$rate_tracking_ratio)
equal(y$lag, 5 * m$lag)
# Unequal axis scaling changes the chosen Euclidean metric, hence its angle.
y = calculate_tracking_metrics(transform_endpoints(x, diag(c(2, 1))))
stopifnot(abs(y$cosine_similarity - m$cosine_similarity) > .1)
for (v in c(0, 1e-10, NA_real_, Inf)) {
  z = x; z$o1_2 = v; z$o2_2 = 0
  stopifnot(is.na(calculate_tracking_metrics(z)$cosine_similarity))
}
for (dt in c(0, -1, NA_real_, Inf)) {
  z = x; z$vegetation_dt_years = dt; must_fail(calculate_tracking_metrics(z))
}
equal(safe_cosine_2d(c(1, -1, 0), c(0, 0, 1), 1, 0)$association,
      c(1, -1, 0))

# Complete seasonal sums and the exact December -> next winter mapping.
a = tidyr::expand_grid(unit = "A", period = "past", time = 2000:2001,
  variable = c("tasmin", "tasmax", "pr"), month = 1:12) |>
  dplyr::mutate(value = as.numeric(month))
d = derive_climate_vars(a)
equal(d$SP[d$time == 2000], 21)
equal(d$MWT[d$time == 2001], 5)
stopifnot(is.na(d$MWT[d$time == 2000]))
z = a; z$value[1] = NA_real_; must_fail(derive_climate_vars(z))
z = a; z$value[1] = Inf; must_fail(derive_climate_vars(z))
must_fail(derive_climate_vars(dplyr::bind_rows(a, a[1, ])))
z = a; z$month[1] = 13; must_fail(derive_climate_vars(z))

# Valid source gaps stay valid; inconsistent coordinates and values cannot pass.
f = tempfile(fileext = ".csv")
points = data.frame(id = "A", lon = -121, lat = 48)
c = data.frame(id = "A", lon = -121, lat = 48, variable = "pr", year = 2000,
               month = 1:12, source = "v21_monthly", value = 1)
valid = function(x, p = points) {
  readr::write_csv(x, f)
  climate_cache_valid(f, p, "pr", 2000, "v21_monthly")
}
stopifnot(valid(c))
for (v in c(NA_real_, Inf, NaN)) {
  z = c; z$value[1] = v; stopifnot(identical(valid(z), FALSE))
}
z = c; z$lon[12] = -122; stopifnot(!valid(z))
z = c; z$lat[1] = NA_real_; stopifnot(identical(valid(z), FALSE))
z = c; z$source[1] = NA_character_; stopifnot(identical(valid(z), FALSE))
stopifnot(!valid(c[-1, ]), !valid(dplyr::bind_rows(c, c[1, ])),
          !valid(c, dplyr::bind_rows(points, points)))
z = c[-1, ]; z$variable = "tasmin"; z$year = 1979
readr::write_csv(z, f)
stopifnot(climate_cache_valid(f, points, "tasmin", 1979, "v21_monthly"))
unlink(f)

# Disconnected dates cannot be promoted into one continuous climate era.
s = tidyr::expand_grid(site = c("MORA", "NOCA"), variable = CCA_VARIABLES,
  unit = "x", t = c(800, 1000), offset = seq(0, 900, 100)) |>
  dplyr::mutate(signed_change = 1)
r = classify_climate_era_union(s, data.frame(variable = CCA_VARIABLES,
                                             sd = 1, unit = "x"))
stopifnot(nrow(r$era_catalog) == 2L,
          all(r$era_catalog$duration_years == 100L))
# Only one MORA core covers the intervening center: it must remain a gap.
continuous = data.frame(site = "MORA", lake = rep(c("A", "B", "C"), each = 2),
  age_cal_yr_BP = c(0, 10000, 0, 4600, 5400, 10000), background_z = 0)
events = data.frame(site = "MORA", lake = c("A", "A", "B", "C"),
  age_cal_yr_BP = c(4000, 6000, 4000, 6000), peak_magnitude = 1)
f = calculate_fire_frequency(events, continuous, grid_step = 1000)
stopifnot(nrow(f$periods) == 2L, all(f$periods$duration_years == 1000),
          is.na(f$site_grid$normalized_frequency[f$site_grid$cal_bp == 5000]))
cat("Review regressions passed: independent geometry, unequal time supports, seasons, invalid caches, coverage gaps.\n")
