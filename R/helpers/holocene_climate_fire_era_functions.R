# =============================================================================
# holocene_climate_fire_era_functions.R
# Side-effect-free tools for the unified 1,000-year climate/fire era analysis.
# =============================================================================

robust_sd = function(x, epsilon = 1e-12) {
  x = x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  out = 1.4826 * stats::mad(x, center = stats::median(x), constant = 1,
                            na.rm = TRUE)
  if (!is.finite(out) || out <= epsilon) 0 else out
}

collapse_grid_runs = function(grid, class_col, cell_years = 100L,
                               group_cols = character()) {
  class_name = rlang::as_name(rlang::ensym(class_col))
  required = c(group_cols, "t", class_name)
  missing = setdiff(required, names(grid))
  if (length(missing)) stop("Missing run columns: ", paste(missing, collapse = ", "))

  grouped = grid |>
    dplyr::arrange(dplyr::across(dplyr::all_of(group_cols)), dplyr::desc(.data$t))
  if (length(group_cols)) grouped = grouped |> dplyr::group_by(
    dplyr::across(dplyr::all_of(group_cols)))

  grouped |>
    dplyr::mutate(
      .run_break = .data[[class_name]] != dplyr::lag(
        .data[[class_name]], default = dplyr::first(.data[[class_name]])) |
        dplyr::lag(.data$t, default = dplyr::first(.data$t) + cell_years) -
          .data$t != cell_years,
      run_id = cumsum(.data$.run_break) + 1L) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(group_cols, "run_id", class_name)))) |>
    dplyr::summarise(
      older_cal_bp = max(.data$t) + cell_years,
      younger_cal_bp = min(.data$t),
      duration_years = .data$older_cal_bp - .data$younger_cal_bp,
      n_cells = dplyr::n(), .groups = "drop")
}

# Build adjacent complete 1,000-year climate-bin changes. MORA lakes are
# averaged first, so MORA and NOCA receive equal weight in the regional score.
build_climate_changes_1000yr = function(levels_wide, variables,
                                         variable_units,
                                         offsets = seq(0, 900, 100),
                                         cell_years = 100L) {
  bins = tidyr::crossing(offset = offsets, levels_wide) |>
    dplyr::mutate(
      bin = floor((.data$cal_bp - .data$offset) / 1000) * 1000 + .data$offset,
      bin_mid = .data$bin + 500) |>
    dplyr::group_by(.data$site, .data$lake, .data$offset, .data$bin_mid) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(variables), mean),
      n_slices = dplyr::n(), .groups = "drop") |>
    dplyr::filter(.data$n_slices == 10L)

  adjacent = bins |>
    dplyr::arrange(.data$site, .data$lake, .data$offset,
                   dplyr::desc(.data$bin_mid)) |>
    dplyr::group_by(.data$site, .data$lake, .data$offset) |>
    dplyr::mutate(dplyr::across(c("bin_mid", dplyr::all_of(variables)),
      dplyr::lead, .names = "younger_{.col}")) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(.data$younger_bin_mid)) |>
    dplyr::mutate(
      age_hi = .data$bin_mid,
      age_lo = .data$younger_bin_mid,
      interval_mid = (.data$age_hi + .data$age_lo) / 2,
      interval_years = .data$age_hi - .data$age_lo) |>
    dplyr::filter(.data$interval_years == 1000L)

  lake = purrr::map_dfr(variables, function(v) adjacent |>
    dplyr::transmute(
      site, lake, offset, age_hi, age_lo, interval_mid, interval_years,
      variable = v, unit = unname(variable_units[[v]]),
      older_bin_mean = .data[[v]],
      younger_bin_mean = .data[[paste0("younger_", v)]],
      signed_change = .data$younger_bin_mean - .data$older_bin_mean))

  site_intervals = lake |>
    dplyr::group_by(.data$site, .data$variable, .data$unit, .data$offset,
      .data$age_hi, .data$age_lo, .data$interval_mid, .data$interval_years) |>
    dplyr::summarise(signed_change = mean(.data$signed_change),
      n_lakes = dplyr::n_distinct(.data$lake), .groups = "drop")

  cells = tibble::tibble(t = seq(-100, 11000, by = cell_years)) |>
    tidyr::crossing(site_intervals) |>
    dplyr::filter(.data$t >= .data$age_lo, .data$t < .data$age_hi) |>
    dplyr::group_by(.data$site, .data$variable, .data$unit, .data$t) |>
    dplyr::filter(dplyr::n_distinct(.data$offset) == length(offsets)) |>
    dplyr::ungroup()

  list(lake = lake, site_intervals = site_intervals, site_cells = cells)
}

# Classify variable-specific cells, then take their union. The 50%-of-maximum
# threshold is variable-specific. It is applied to the median regional change,
# while direction support counts the ten bin phases. Site agreement is retained
# for audit only and never vetoes a regional classification.
classify_climate_era_union = function(site_cells, calibration_scaling,
                                       fraction = 0.50,
                                       required_phases = 8L,
                                       total_phases = 10L,
                                       cell_years = 100L) {
  if (!is.finite(fraction) || fraction <= 0 || fraction > 1)
    stop("fraction must lie in (0, 1].")

  site_standardized = site_cells |>
    dplyr::left_join(calibration_scaling |>
      dplyr::select("variable", calibration_sd = "sd",
                    calibration_unit = "unit"), by = "variable") |>
    dplyr::mutate(standardized_signed_change =
      .data$signed_change / .data$calibration_sd)
  if (any(!is.finite(site_standardized$standardized_signed_change)))
    stop("Invalid legacy-calibration standardization.")

  regional_phases = site_standardized |>
    dplyr::select("variable", "unit", "t", "offset", "site",
      "signed_change", "standardized_signed_change") |>
    tidyr::pivot_wider(names_from = "site",
      values_from = c("signed_change", "standardized_signed_change")) |>
    dplyr::mutate(
      regional_score = (.data$standardized_signed_change_MORA +
        .data$standardized_signed_change_NOCA) / 2,
      regional_direction = sign(.data$regional_score),
      sites_same_direction = sign(.data$standardized_signed_change_MORA) ==
        sign(.data$standardized_signed_change_NOCA) &
        sign(.data$standardized_signed_change_MORA) != 0)

  grid_base = regional_phases |>
    dplyr::group_by(.data$variable, .data$unit, .data$t) |>
    dplyr::summarise(
      regional_score = stats::median(.data$regional_score),
      mora_score = stats::median(.data$standardized_signed_change_MORA),
      noca_score = stats::median(.data$standardized_signed_change_NOCA),
      n_phases = dplyr::n_distinct(.data$offset), .groups = "drop") |>
    dplyr::mutate(direction_sign = sign(.data$regional_score))

  support = regional_phases |>
    dplyr::inner_join(grid_base |>
      dplyr::select("variable", "t", "direction_sign"),
      by = c("variable", "t")) |>
    dplyr::group_by(.data$variable, .data$t) |>
    dplyr::summarise(
      phase_direction_support = sum(.data$regional_direction ==
        .data$direction_sign & .data$regional_direction != 0),
      site_agreement_phases = sum(.data$sites_same_direction),
      .groups = "drop")

  thresholds = grid_base |>
    dplyr::filter(.data$n_phases == total_phases) |>
    dplyr::group_by(.data$variable, .data$unit) |>
    dplyr::summarise(
      maximum_absolute_regional_change = max(abs(.data$regional_score)),
      threshold_fraction_of_maximum = fraction,
      threshold_standardized_change = fraction *
        .data$maximum_absolute_regional_change,
      required_phases = as.integer(required_phases), .groups = "drop")

  variable_cells = grid_base |>
    dplyr::left_join(support, by = c("variable", "t")) |>
    dplyr::left_join(thresholds, by = c("variable", "unit")) |>
    dplyr::mutate(
      complete_phase_coverage = .data$n_phases == total_phases,
      magnitude_exceeded = abs(.data$regional_score) >=
        .data$threshold_standardized_change,
      qualifies = .data$complete_phase_coverage & .data$magnitude_exceeded &
        .data$phase_direction_support >= required_phases,
      direction = dplyr::case_when(
        .data$qualifies & .data$direction_sign > 0 ~ "increasing",
        .data$qualifies & .data$direction_sign < 0 ~ "decreasing",
        TRUE ~ "not qualifying"))

  complete_dates = variable_cells |>
    dplyr::group_by(.data$t) |>
    dplyr::summarise(n_variables = dplyr::n_distinct(.data$variable),
                     all_complete = all(.data$complete_phase_coverage),
                     .groups = "drop") |>
    dplyr::filter(.data$n_variables == dplyr::n_distinct(variable_cells$variable), .data$all_complete) |>
    dplyr::pull(.data$t)

  era_grid = variable_cells |>
    dplyr::filter(.data$t %in% complete_dates) |>
    dplyr::mutate(driver = dplyr::if_else(.data$qualifies,
      paste(.data$variable, .data$direction), NA_character_)) |>
    dplyr::group_by(.data$t) |>
    dplyr::summarise(
      era_class = ifelse(any(.data$qualifies), "climate change",
                         "relative stability"),
      n_active_variables = sum(.data$qualifies),
      active_drivers = paste(stats::na.omit(.data$driver), collapse = ";"),
      .groups = "drop") |>
    dplyr::arrange(dplyr::desc(.data$t)) |>
    dplyr::mutate(
      run_id = cumsum(.data$era_class != dplyr::lag(.data$era_class,
        default = dplyr::first(.data$era_class)) |
        dplyr::lag(.data$t, default = dplyr::first(.data$t) + cell_years) -
          .data$t != cell_years) + 1L)

  catalog = era_grid |>
    dplyr::group_by(.data$run_id, .data$era_class) |>
    dplyr::summarise(
      older_cal_bp = max(.data$t) + cell_years,
      younger_cal_bp = min(.data$t),
      duration_years = .data$older_cal_bp - .data$younger_cal_bp,
      maximum_active_variables = max(.data$n_active_variables),
      .groups = "drop") |>
    dplyr::arrange(dplyr::desc(.data$older_cal_bp)) |>
    dplyr::group_by(.data$era_class) |>
    dplyr::mutate(class_sequence = dplyr::row_number(),
      era_id = paste0(ifelse(.data$era_class == "climate change", "CC", "S"),
                      .data$class_sequence)) |>
    dplyr::ungroup()
  era_grid = era_grid |> dplyr::left_join(catalog |>
    dplyr::select("run_id", "era_id"), by = "run_id")

  drivers = variable_cells |>
    dplyr::filter(.data$qualifies, .data$t %in% complete_dates) |>
    dplyr::arrange(.data$variable, .data$direction, dplyr::desc(.data$t)) |>
    dplyr::group_by(.data$variable, .data$direction) |>
    dplyr::mutate(driver_run = cumsum(
      dplyr::lag(.data$t, default = dplyr::first(.data$t) + cell_years) -
        .data$t != cell_years) + 1L) |>
    dplyr::group_by(.data$variable, .data$unit, .data$direction,
                    .data$driver_run) |>
    dplyr::summarise(
      older_cal_bp = max(.data$t) + cell_years,
      younger_cal_bp = min(.data$t),
      duration_years = .data$older_cal_bp - .data$younger_cal_bp,
      minimum_phase_support = min(.data$phase_direction_support),
      maximum_absolute_score = max(abs(.data$regional_score)),
      .groups = "drop")

  list(site_standardized = site_standardized,
       regional_phases = regional_phases, thresholds = thresholds,
       variable_cells = variable_cells, era_grid = era_grid,
       era_catalog = catalog, drivers = drivers)
}

# Subdivide a climate-change era only when a sustained internal trough in the
# number of active directional drivers separates two multi-driver portions.
# This uses the classified 100-year cells and never searches the literature.
# Drivers name a subphase only when active in at least `driver_coverage` of its
# cells, preventing brief boundary overlaps from dominating the phase label.
subdivide_climate_change_eras = function(variable_cells, era_catalog,
                                          cell_years = 100L,
                                          min_trough_years = 300L,
                                          driver_coverage = 0.60) {
  if (!is.finite(driver_coverage) || driver_coverage <= 0 ||
      driver_coverage > 1) stop("driver_coverage must lie in (0, 1].")

  label_driver = function(variable, direction) dplyr::case_when(
    variable == "MSpT" & direction == "increasing" ~ "spring warming",
    variable == "MSpT" ~ "spring cooling",
    variable == "MWT" & direction == "increasing" ~ "winter warming",
    variable == "MWT" ~ "winter cooling",
    variable == "SP" & direction == "increasing" ~ "summer wetting",
    variable == "SP" ~ "summer drying",
    variable == "WP" & direction == "increasing" ~ "winter wetting",
    TRUE ~ "winter drying")

  summarize_phase = function(phase, cells) {
    phase_cells = cells |>
      dplyr::filter(.data$t < phase$older_cal_bp,
                    .data$t >= phase$younger_cal_bp)
    n_phase_cells = dplyr::n_distinct(phase_cells$t)
    active = phase_cells |>
      dplyr::filter(.data$qualifies) |>
      dplyr::group_by(.data$variable, .data$direction) |>
      dplyr::summarise(n_active_cells = dplyr::n_distinct(.data$t),
                       .groups = "drop") |>
      dplyr::mutate(coverage_fraction = .data$n_active_cells / n_phase_cells,
        driver_label = label_driver(.data$variable, .data$direction)) |>
      dplyr::filter(.data$coverage_fraction >= driver_coverage) |>
      dplyr::arrange(match(.data$variable, c("MSpT", "MWT", "SP", "WP")))
    labels = active$driver_label
    phase |>
      dplyr::mutate(
        duration_years = .data$older_cal_bp - .data$younger_cal_bp,
        n_cells = n_phase_cells,
        driver_coverage_rule = driver_coverage,
        active_driver_labels = paste(labels, collapse = ";"),
        active_driver_coverage = paste0(active$driver_label, "=",
          sprintf("%.2f", active$coverage_fraction), collapse = ";"),
        annotation_label = paste(c(if (.data$phase_role == "transition")
          "transition" else character(), labels), collapse = "\n"))
  }

  purrr::map_dfr(seq_len(nrow(era_catalog)), function(i) {
    era = era_catalog[i, ]
    if (era$era_class != "climate change") return(tibble::tibble())
    cells = variable_cells |>
      dplyr::filter(.data$t < era$older_cal_bp,
                    .data$t >= era$younger_cal_bp)
    counts = cells |>
      dplyr::group_by(.data$t) |>
      dplyr::summarise(n_active = sum(.data$qualifies), .groups = "drop")
    runs = collapse_grid_runs(counts, n_active, cell_years = cell_years)
    troughs = runs |>
      dplyr::filter(.data$n_active == min(counts$n_active),
        .data$duration_years >= min_trough_years,
        .data$older_cal_bp < era$older_cal_bp,
        .data$younger_cal_bp > era$younger_cal_bp) |>
      dplyr::rowwise() |>
      dplyr::mutate(
        older_flank_multidriver = any(counts$n_active[counts$t >=
          .data$older_cal_bp] >= 2L),
        younger_flank_multidriver = any(counts$n_active[counts$t <
          .data$younger_cal_bp] >= 2L)) |>
      dplyr::ungroup() |>
      dplyr::filter(.data$older_flank_multidriver,
                    .data$younger_flank_multidriver) |>
      dplyr::arrange(dplyr::desc(.data$duration_years),
                     dplyr::desc(.data$older_cal_bp))

    if (!nrow(troughs)) {
      phases = tibble::tibble(parent_era_id = era$era_id,
        subphase_id = era$era_id, phase_role = "unsplit",
        older_cal_bp = era$older_cal_bp,
        younger_cal_bp = era$younger_cal_bp,
        trough_n_active = NA_integer_)
    } else {
      trough = troughs[1, ]
      phases = tibble::tibble(parent_era_id = era$era_id,
        subphase_id = paste0(era$era_id, letters[1:3]),
        phase_role = c("early multi-driver", "transition", "late multi-driver"),
        older_cal_bp = c(era$older_cal_bp, trough$older_cal_bp,
                         trough$younger_cal_bp),
        younger_cal_bp = c(trough$older_cal_bp, trough$younger_cal_bp,
                           era$younger_cal_bp),
        trough_n_active = c(NA_integer_, as.integer(trough$n_active), NA_integer_))
    }
    purrr::map_dfr(seq_len(nrow(phases)),
      ~summarize_phase(phases[.x, ], cells))
  })
}

calculate_climate_composite = function(site_standardized) {
  site_phase = site_standardized |>
    dplyr::group_by(.data$site, .data$t, .data$offset) |>
    dplyr::summarise(
      n_variables = dplyr::n_distinct(.data$variable),
      composite_magnitude = sqrt(sum(.data$standardized_signed_change^2)),
      .groups = "drop")
  if (dplyr::n_distinct(site_phase$n_variables) != 1L)
    stop("Composite climate magnitude requires every variable at every phase.")
  regional_phase = site_phase |>
    dplyr::select("site", "t", "offset", "composite_magnitude") |>
    tidyr::pivot_wider(names_from = "site",
      values_from = "composite_magnitude") |>
    dplyr::mutate(regional_composite = (.data$MORA + .data$NOCA) / 2)
  grid = regional_phase |>
    dplyr::group_by(.data$t) |>
    dplyr::summarise(
      n_phases = dplyr::n_distinct(.data$offset),
      MORA = stats::median(.data$MORA), NOCA = stats::median(.data$NOCA),
      regional_composite = stats::median(.data$regional_composite),
      phase_min = min(.data$regional_composite),
      phase_max = max(.data$regional_composite), .groups = "drop")
  list(site_phase = site_phase, regional_phase = regional_phase, grid = grid)
}

add_peak_percentiles = function(events) {
  events |>
    dplyr::group_by(.data$site, .data$lake) |>
    dplyr::mutate(magnitude_percentile =
      (rank(.data$peak_magnitude, ties.method = "average") - 0.5) /
        dplyr::n()) |>
    dplyr::ungroup()
}

calculate_fire_frequency = function(events, continuous, window_years = 1000L,
                                     grid_step = 100L) {
  coverage = continuous |>
    dplyr::group_by(.data$site, .data$lake) |>
    dplyr::summarise(younger_cal_bp = min(.data$age_cal_yr_BP),
      older_cal_bp = max(.data$age_cal_yr_BP), .groups = "drop")
  events = add_peak_percentiles(events)
  half = window_years / 2
  rows = purrr::pmap_dfr(coverage, function(site, lake, younger_cal_bp,
                                            older_cal_bp) {
    if (ceiling((younger_cal_bp + half) / grid_step) >
        floor((older_cal_bp - half) / grid_step)) return(NULL)
    centers = seq(ceiling((younger_cal_bp + half) / grid_step) * grid_step,
                  floor((older_cal_bp - half) / grid_step) * grid_step,
                  by = grid_step)
    purrr::map_dfr(centers, function(tt) {
      ee = events |>
        dplyr::filter(.data$lake == .env$lake,
          .data$age_cal_yr_BP >= tt - half,
          .data$age_cal_yr_BP < tt + half)
      cc = continuous |>
        dplyr::filter(.data$lake == .env$lake,
          .data$age_cal_yr_BP >= tt - half,
          .data$age_cal_yr_BP < tt + half)
      tibble::tibble(site = site, lake = lake, cal_bp = tt,
        window_years = window_years,
        accepted_event_count = nrow(ee),
        peak_frequency_per_1000yr = nrow(ee) / window_years * 1000,
        peak_strength_percentile_sum = sum(ee$magnitude_percentile),
        background_char_z = if (nrow(cc)) mean(cc$background_z,
          na.rm = TRUE) else NA_real_)
    })
  })

  core = rows |>
    dplyr::group_by(.data$site, .data$lake) |>
    dplyr::mutate(
      core_max_frequency = max(.data$peak_frequency_per_1000yr, na.rm = TRUE),
      normalized_frequency = dplyr::if_else(.data$core_max_frequency > 0,
        .data$peak_frequency_per_1000yr / .data$core_max_frequency, NA_real_)) |>
    dplyr::ungroup()

  site_grid = core |>
    dplyr::group_by(.data$site, .data$cal_bp) |>
    dplyr::summarise(
      covered_cores = sum(is.finite(.data$normalized_frequency)),
      normalized_frequency = if (dplyr::first(.data$site) == "MORA" &
        .data$covered_cores < 2L) NA_real_ else
        mean(.data$normalized_frequency, na.rm = TRUE), .groups = "drop") |>
    dplyr::group_by(.data$site) |>
    dplyr::mutate(
      threshold_median = stats::median(.data$normalized_frequency, na.rm = TRUE),
      threshold_robust_sd = robust_sd(.data$normalized_frequency),
      high_fire_threshold = .data$threshold_median + .data$threshold_robust_sd,
      high_fire = is.finite(.data$normalized_frequency) &
        .data$normalized_frequency > .data$high_fire_threshold) |>
    dplyr::ungroup()

  fire_periods = site_grid |>
    dplyr::filter(is.finite(.data$normalized_frequency)) |>
    dplyr::arrange(.data$site, .data$cal_bp) |>
    dplyr::group_by(.data$site) |>
    dplyr::mutate(run_id = cumsum(.data$high_fire != dplyr::lag(
      .data$high_fire, default = dplyr::first(.data$high_fire)) |
      .data$cal_bp - dplyr::lag(.data$cal_bp,
        default = dplyr::first(.data$cal_bp) - grid_step) != grid_step) + 1L) |>
    dplyr::filter(.data$high_fire) |>
    dplyr::group_by(.data$site, .data$run_id) |>
    dplyr::summarise(
      older_cal_bp = if (length(.data$cal_bp)) max(.data$cal_bp) + grid_step / 2 else NA_real_,
      younger_cal_bp = if (length(.data$cal_bp)) min(.data$cal_bp) - grid_step / 2 else NA_real_,
      duration_years = .data$older_cal_bp - .data$younger_cal_bp,
      maximum_normalized_frequency = if (length(.data$normalized_frequency)) max(.data$normalized_frequency) else NA_real_,
      threshold = dplyr::first(.data$high_fire_threshold), .groups = "drop")

  corroboration_core = core |>
    tidyr::pivot_longer(c("peak_strength_percentile_sum",
      "background_char_z"), names_to = "stream", values_to = "value") |>
    dplyr::group_by(.data$site, .data$lake, .data$stream) |>
    dplyr::mutate(threshold_median = stats::median(.data$value, na.rm = TRUE),
      threshold_robust_sd = robust_sd(.data$value),
      threshold = .data$threshold_median + .data$threshold_robust_sd,
      elevated = is.finite(.data$value) & .data$value > .data$threshold) |>
    dplyr::ungroup()
  corroboration_site = corroboration_core |>
    dplyr::group_by(.data$site, .data$cal_bp, .data$stream) |>
    dplyr::summarise(
      covered_cores = sum(is.finite(.data$value)),
      elevated_cores = sum(.data$elevated, na.rm = TRUE),
      corroborates = if (dplyr::first(.data$site) == "MORA")
        .data$covered_cores >= 2L & .data$elevated_cores >= 2L else
        .data$covered_cores >= 1L & .data$elevated_cores >= 1L,
      .groups = "drop")

  list(coverage = coverage, core = core, site_grid = site_grid,
       thresholds = site_grid |>
         dplyr::select("site", "threshold_median", "threshold_robust_sd",
                       "high_fire_threshold") |>
         dplyr::distinct(),
       periods = fire_periods, corroboration_core = corroboration_core,
       corroboration_site = corroboration_site)
}
