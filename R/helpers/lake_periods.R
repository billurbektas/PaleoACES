# Lake-periods (PLAN.md sections 4 and 5, Steps 1 to 4): one lake within one
# climate period, compared from its oldest to its youngest sampled century.
# Differences between consecutive centuries are mostly sampling noise (one
# scoop of sediment against the next); comparing the two ends of a period lets
# the ecological drift outgrow that noise. Centuries in between enter no model.
# Used by R/pipeline/12_tracking.R and R/pipeline/15_contributions.R.
source(here::here('R/helpers/config.R'), local = TRUE)
source(here::here('R/helpers/tracking_metrics.R'), local = TRUE)

# The response names of PLAN.md, and the existing columns they come from.
LAKE_PERIOD_RESPONSES = c(climate_rate = 'standardized_climate_change_rate',
  turnover_rate = 'observed_turnover_rate', lag_rate = 'lag_rate_per_century',
  pace_effect = 'pace_effect_on_lag_per_century', direction_effect = 'direction_effect_on_lag_per_century')

# Assign each sampled century to the period that contains it. Century centres
# fall at x50 cal BP and period boundaries at whole centuries, so no century
# sits on a boundary.
lake_period_centuries = function(positions, periods) {
  k = vapply(positions$century_cal_bp, function(age) {
    i = which(age < periods$older_cal_bp & age >= periods$younger_cal_bp)
    if (length(i) > 1L) stop('Overlapping periods at ', age)
    if (length(i)) i else NA_integer_
  }, integer(1))
  positions$period = periods$period[k]
  positions$period_type = periods$period_type[k]
  positions
}

# Every lake x period with at least one sampled century ("on paper") and the
# two-century rule that decides which become lake-periods.
lake_period_candidates = function(positions, periods) {
  assigned = lake_period_centuries(positions, periods) |> dplyr::filter(!is.na(period))
  assigned |> dplyr::group_by(site, lake, period, period_type) |>
    dplyr::summarise(n_centuries = dplyr::n(), age_start = max(century_cal_bp),
      age_end = min(century_cal_bp), .groups = 'drop') |>
    dplyr::mutate(two_century_rule = n_centuries >= 2L) |>
    dplyr::arrange(site, lake, dplyr::desc(age_start))
}

# One row per lake-period with every Step 2 to 4 quantity. `positions` holds
# one row per lake and sampled century: o1, o2 (WA centroid), p1, p2 (LC of the
# lake's own climate), n_samples and the climate variables.
build_lake_periods = function(positions, periods, scaling, fire_fun) {
  candidates = lake_period_candidates(positions, periods) |> dplyr::filter(two_century_rule)
  end = function(age_col, suffix) {
    cols = c('o1', 'o2', 'p1', 'p2', 'n_samples', CCA_VARIABLES)
    x = positions |> dplyr::select(site, lake, century_cal_bp, dplyr::all_of(cols))
    names(x)[names(x) %in% cols] = paste0(cols, suffix)
    names(x)[names(x) == 'century_cal_bp'] = age_col
    x
  }
  units = candidates |>
    dplyr::left_join(end('age_start', ''), by = c('site', 'lake', 'age_start'), relationship = 'one-to-one') |>
    dplyr::left_join(end('age_end', '_2'), by = c('site', 'lake', 'age_end'), relationship = 'one-to-one') |>
    dplyr::rename(n_start = n_samples, n_end = n_samples_2) |>
    dplyr::mutate(duration_yr = age_start - age_end, endpoint_var = 1 / n_start + 1 / n_end,
      vegetation_dt_years = duration_yr, climate_dt_years = duration_yr) |>
    dplyr::group_by(site, lake) |> dplyr::arrange(dplyr::desc(age_start), .by_group = TRUE) |>
    dplyr::mutate(unit_index = dplyr::row_number()) |> dplyr::ungroup()
  # Rule (PLAN.md section 4.1): two distinct centuries, t1 older than t2.
  stopifnot(all(units$age_start > units$age_end), all(is.finite(units$o1_2)), all(is.finite(units$p1_2)))
  units = units |> calculate_tracking_metrics() |> add_climate_change_metrics(scaling) |>
    add_corrected_lag_rates()
  fire = fire_fun(units |> dplyr::transmute(site, age_hi = age_start, age_lo = age_end))$regional
  units = units |> dplyr::left_join(fire |> dplyr::rename(age_start = age_hi, age_end = age_lo),
    by = c('site', 'age_start', 'age_end'), relationship = 'many-to-one')
  lake_period_responses(units)
}

# PLAN.md names, and the epsilon rule of section 4.7: where the observed or the
# predicted position did not move, pace and direction are undefined.
lake_period_responses = function(x) {
  for (name in names(LAKE_PERIOD_RESPONSES)) x[[name]] = x[[LAKE_PERIOD_RESPONSES[[name]]]]
  x$M_start = x$lag_t1
  x$M_end = x$lag_t2
  x$direction_defined = x$angle_valid
  x$pace_effect[!x$direction_defined] = NA_real_
  x$direction_effect[!x$direction_defined] = NA_real_
  x
}

lake_period_table_columns = function() c('site', 'lake', 'period', 'period_type', 'age_start', 'age_end',
  'duration_yr', 'n_start', 'n_end', 'endpoint_var', 'unit_index', 'climate_rate',
  paste0(CCA_VARIABLES, '_change'), paste0(CCA_VARIABLES, '_rate_per_century'),
  'fire_activity', 'fire_coverage_valid', 'fire_covered_cores', 'fire_source_ids',
  'M_start', 'M_end', 'lag_rate', 'turnover_rate', 'pace_effect', 'direction_effect', 'direction_defined')

# Holocene lake-periods and Anthropocene plot pairs in one table for the era
# models. A plot is a series of one unit, measured once at each end. The lag
# (Bills, 10 Nov 2026) is the change in mismatch from t1 to t2, M_end - M_start,
# not divided by time. The displacement (Bills, 10 Nov 2026) is the observed
# community movement from t1 to t2 in CCA space, also not divided by time: the
# turnover rate times the interval between the vegetation samples / 100. The
# climate change (Bills, 10 Nov 2026) is the matching total for the climate: the
# distance between the two ends in standardized climate space, in calibration
# SD, the climate change rate times the climate interval / 100.
build_both_eras = function(units, plots) {
  holocene = units |> dplyr::transmute(period_type, site, lake, plot_id = NA_character_, period,
    series = paste('H', site, lake, sep = '_'), unit_index, age_start, age_end, duration_yr,
    n_start, n_end, endpoint_var, climate_rate, climate_change = standardized_climate_displacement,
    turnover_rate, displacement = observed_vegetation_displacement,
    lag_rate, lag = M_end - M_start, pace_effect,
    direction_effect, M_start, M_end, direction_defined, fire_activity, fire_coverage_valid, burned = NA)
  anthropocene = lake_period_responses(plots) |> dplyr::transmute(period_type = 'Anthropocene', site,
    lake = NA_character_, plot_id, period = 'Anthropocene', series = paste('A', site, plot_id, sep = '_'),
    unit_index = 1L, age_start = NA_real_, age_end = NA_real_, duration_yr = climate_dt_years,
    n_start = 1L, n_end = 1L, endpoint_var = 2, climate_rate, climate_change = standardized_climate_displacement,
    turnover_rate, displacement = observed_vegetation_displacement, lag_rate, lag = M_end - M_start,
    pace_effect, direction_effect, M_start, M_end, direction_defined, fire_activity = NA_real_,
    fire_coverage_valid = NA, burned)
  x = dplyr::bind_rows(holocene, anthropocene)
  # Rule: 607 Anthropocene pairs (330 MORA, 277 NOCA), each with endpoint_var 2.
  a = x[x$period_type == 'Anthropocene', ]
  stopifnot(nrow(a) == 607L, sum(a$site == 'MORA') == 330L, sum(a$site == 'NOCA') == 277L,
    all(a$endpoint_var == 2), !anyDuplicated(x[c('series', 'unit_index')]))
  x
}
