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

# CCA eligibility: analytically specified plots, without fitting a model or
# reading local data. Extract only the two pure preparation functions.
cca_functions = parse(here("R/stages/05_cca_model.R"))
for (name in c("cca_classify_samples", "cca_pair_samples")) {
  definition = Filter(function(x) is.call(x) && is.symbol(x[[1]]) &&
    as.character(x[[1]]) %in% c("=", "<-") && identical(x[[2]], as.name(name)),
    as.list(cca_functions))
  stopifnot(length(definition) == 1L)
  eval(definition[[1]])
}
raw = tibble::tribble(
  ~plot_id, ~period, ~species, ~occurrence,
  "valid", "past", "SP1", 1, "valid", "present", "SP1", 1,
  "empty_legacy", "past", "SP1", 0, "empty_legacy", "present", "SP1", 1,
  "lost_presence", "past", "SP1", 1, "lost_presence", "present", "SP1", 0,
  "consolidation", "past", "UNDERSTORY", 1, "consolidation", "present", "SP1", 1,
  "threshold", "past", "RARE", 1, "threshold", "present", "SP1", 1,
  "resurvey_threshold", "past", "SP1", 1, "resurvey_threshold", "present", "RARE", 1,
  "novel", "past", "SP1", 1, "novel", "present", "NOVEL", 1,
  "bad_climate", "past", "SP1", 1, "bad_climate", "present", "SP1", 1,
  "missing_climate", "past", "SP1", 1, "missing_climate", "present", "SP1", 1,
  "unmatched", "past", "SP1", 1,
  "paleo_valid", "paleo", "SP1", 1, "paleo_empty", "paleo", "SP1", 0,
  "paleo_rare", "paleo", "RARE", 1, "paleo_consolidation", "paleo", "UNDERSTORY", 1
) %>% mutate(site = "TEST", era = if_else(period == "paleo", "holocene", "anthropocene"))
con = raw %>% filter(species != "UNDERSTORY")
clim = raw %>% distinct(site, era, period, plot_id) %>% mutate(MSpT = 1) %>%
  mutate(MSpT = if_else(plot_id == "bad_climate" & period == "present", Inf, MSpT)) %>%
  filter(!(plot_id == "missing_climate" & period == "present")) %>%
  bind_rows(tibble(site = "TEST", era = "holocene", period = "paleo",
                   plot_id = "unrecorded", MSpT = 1))
classify = function(cleaned = raw, climate = clim) cca_classify_samples(
  cleaned, con, c("SP1", "NOVEL"), "SP1", climate, "MSpT")
classified = classify()
paired = cca_pair_samples(classified)
stopifnot(identical(paired$plot_id[paired$comparison_included], "valid"),
          identical(paired$plot_id[paired$calibration_included], "valid"),
          identical(classified$plot_id[classified$period == "paleo" & classified$eligible], "paleo_valid"))
expected = c(empty_legacy = "no_recorded_taxa", lost_presence = "no_recorded_taxa",
             consolidation = "consolidation", threshold = "species_selection",
             resurvey_threshold = "species_selection", novel = "no_calibration_taxa",
             bad_climate = "climate", missing_climate = "climate", unmatched = "missing_period")
stopifnot(identical(paired$reason_code[match(names(expected), paired$plot_id)], unname(expected)),
          paired$reason[paired$plot_id == "lost_presence"] ==
            "Loss of all recorded tree-taxon presence at resurvey",
          classified$reason_code[classified$plot_id == "unrecorded"] == "missing_occurrence")
stopifnot(identical(classify(bind_rows(raw, raw[1, ])), classified))
must_fail(classify(climate = bind_rows(clim, clim[1, ])))
bad_occurrence = raw; bad_occurrence$occurrence[1] = NA_real_
must_fail(classify(cleaned = bad_occurrence))
nan_climate = clim; nan_climate$MSpT[nan_climate$plot_id == "bad_climate"] = NaN
stopifnot(!any(classify(climate = nan_climate)$eligible[
  classify(climate = nan_climate)$plot_id == "bad_climate"]))

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
equal(m$change_in_lag, sqrt(20) - 1)

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
equal(y$angle_degrees, m$angle_degrees)
equal(y$rate_tracking_ratio, m$rate_tracking_ratio)
equal(y$change_in_lag, 5 * m$change_in_lag)
# Unequal axis scaling changes the chosen Euclidean metric, hence its angle.
y = calculate_tracking_metrics(transform_endpoints(x, diag(c(2, 1))))
stopifnot(abs(y$angle_degrees - m$angle_degrees) > .1)
for (v in c(0, 1e-10, NA_real_, Inf)) {
  z = x; z$o1_2 = v; z$o2_2 = 0
  stopifnot(is.na(calculate_tracking_metrics(z)$angle_degrees))
}
for (dt in c(0, -1, NA_real_, Inf)) {
  z = x; z$vegetation_dt_years = dt; must_fail(calculate_tracking_metrics(z))
}
equal(safe_cosine_2d(c(1, -1, 0), c(0, 0, 1), 1, 0),
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
source(here("R/helpers/survey_years.R"), local = TRUE)
# Swapped seedling labels must be assigned to their original adult visit BEFORE
# latest-year filtering. Tied adult records retain their existing pooling.
adult = tibble::tribble(~Plot_ID, ~Plot.ID, ~Year,
  "P1", "P1-FIELD", 2018, "P1", "P1-FIELD-2", 2019,
  "P1", "P1-FIELD-2", 2019, "P2", "P2", 2014)
seed = tibble::tribble(~Plot_ID, ~Plot.ID, ~Year,
  "P1", "P1-FIELD", 2019, "P1", "P1-FIELD-2", 2018,
  "P2", "P2", 2018)
map = tibble::tribble(~Plot_ID, ~visit_name, ~source_year, ~adult_year,
  "P1", "P1-FIELD", 2019, 2018, "P1", "P1-FIELD-2", 2018, 2019)
lib = tibble::tibble(Plot_ID = c("P1", "P2"), plot_id = c("P1", "P2"))
resolved = resolve_mora_resurveys(adult, seed, lib, map)
stopifnot(nrow(resolved$trees) == 3L, nrow(resolved$seedlings) == 2L,
  resolved$seedlings$Year[resolved$seedlings$Plot_ID == "P1"] == 2019,
  resolved$seedlings$Year[resolved$seedlings$Plot_ID == "P2"] == 2014,
  all(resolved$audit$assigned_year[resolved$audit$Plot.ID == "P1-FIELD"] == 2018))
bad = adult; bad$Year[1] = NA_real_; must_fail(resolve_mora_resurveys(bad, seed, lib, map))
must_fail(resolve_mora_resurveys(adult, seed, lib, map[0, ]))
must_fail(resolve_mora_resurveys(adult, seed, lib, dplyr::bind_rows(map, map[1, ])))
must_fail(survey_windows(tibble::tibble(site = "MORA", plot_id = "x", vegetation_t2_year = NA_real_)))
must_fail(survey_windows(tibble::tibble(site = "MORA", plot_id = "x", vegetation_t2_year = 2014.5)))
equal(resolved$years$climate_t2_midyear, resolved$years$vegetation_t2_year - 2.5)
equal(resolved$years$climate_dt_years, resolved$years$vegetation_t2_year - 1986.5)

# Winter 2009 includes December 2008. Exactly six complete season-years survive,
# including 2014 and excluding the trailing partial winter 2015.
w = survey_windows(tibble::tibble(site = "MORA", plot_id = "x", vegetation_t2_year = 2014))
monthly = tidyr::expand_grid(site = "MORA", plot_id = "x", period = "present",
  year = 2008:2014, month = 1:12, variable = c("tasmin", "tasmax", "pr")) |>
  dplyr::mutate(value = dplyr::case_when(variable == "tasmin" ~ 1,
    variable == "tasmax" ~ 3, year == 2008 & month == 12 ~ 40, TRUE ~ 10))
bounded = restrict_modern_months(monthly, w)
stopifnot(nrow(bounded) == 219L, min(bounded$year) == 2008,
  all(bounded$month[bounded$year == 2008] == 12L))
annual = bounded |>
  dplyr::transmute(unit = plot_id, period = paste(site, period, sep = "."),
    time = year, month, variable, value) |>
  derive_climate_vars(winter_shift = TRUE) |> restrict_modern_seasons(w)
equal(annual$time, 2009:2014)
stopifnot(all(is.finite(as.matrix(annual[, c("MSpT", "MWT", "SP", "WP")]))))
equal(annual$WP, c(60, 30, 30, 30, 30, 30))
equal(annual$MWT, rep(2, 6))
must_fail(restrict_modern_months(bounded[-1, ], w))
must_fail(restrict_modern_months(dplyr::filter(bounded, !(year == 2008 & variable == "pr")), w))
must_fail(restrict_modern_months(dplyr::bind_rows(bounded, bounded[1, ]), w))
bad = bounded; bad$value[1] = Inf; must_fail(restrict_modern_months(bad, w))
cat("Review regressions passed: geometry, time supports, seasons, invalid caches, coverage gaps, adult visits and six-year windows.\n")
