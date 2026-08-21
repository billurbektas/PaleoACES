# =============================================================================
# walsh_fire_functions.R - official CharAnalysis source-method audit
# =============================================================================

walsh_input_data = function(path) {
  readxl::read_xlsx(path) |>
    dplyr::transmute(
      cmTop = as.numeric(.data[["Depth Top (cm)"]]),
      cmBot = as.numeric(.data[["Depth bottom (cm)"]]),
      ageTop = as.numeric(.data[["Age Top"]]),
      ageBot = as.numeric(.data[["Age Bottom"]]),
      CharVol = as.numeric(.data[["Volume (cc)"]]),
      CharCount = as.numeric(.data[["Total"]])) |>
    dplyr::filter(dplyr::if_all(dplyr::everything(), is.finite))
}

walsh_parameter_vector = function(data, interpolation_years, smoothing_years) {
  c(min(data$ageTop), max(data$ageBot), rep(-9999, 6),
    interpolation_years, 0, 2, smoothing_years, 1, 2, 3,
    .95, .99, .999, .95, .05, 1000, 0, 0, 0, 0)
}

write_charanalysis_inputs = function(data, site_id, interpolation_years,
                                      smoothing_years, directory) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  data_path = file.path(directory, paste0(site_id, "_charData.csv"))
  params_path = file.path(directory, paste0(site_id, "_charParams.csv"))
  readr::write_csv(data, data_path)
  params = walsh_parameter_vector(data, interpolation_years, smoothing_years)
  readr::write_csv(tibble::tibble(Stage = "", Variable = "", Parameters = params),
                   params_path)
  list(data = data_path, params = params_path, parameters = params)
}

extract_charanalysis_result = function(out, lake, site = "MORA") {
  ch = out$charcoal
  min_count_p = out$char_thresh$minCountP[, 4]
  series = tibble::tibble(
    site = site, lake = lake, age_cal_yr_BP = ch$ybpI,
    char_interpolated = ch$accI, background_char = ch$accIS,
    peak_component = ch$peak,
    positive_threshold = out$char_thresh$pos[, 4],
    minimum_count_p = min_count_p,
    candidate_before_count_screen = is.finite(min_count_p),
    rejected_by_count_screen = is.finite(min_count_p) & min_count_p > .05,
    is_significant = as.logical(ch$charPeaks[, 4]),
    peak_magnitude = ch$peakMagnitude,
    fire_frequency_per_1000yr = ch$smoothedFireFrequ)
  series = series |>
    dplyr::group_by(.data$lake) |>
    dplyr::mutate(background_z = as.numeric(scale(log1p(pmax(.data$background_char, 0))))) |>
    dplyr::ungroup()
  events = series |>
    dplyr::filter(.data$is_significant) |>
    dplyr::select(site, lake, age_cal_yr_BP, peak_magnitude)
  fri = tibble::tibble(site = site, lake = lake,
    event_index = seq_along(out$post$FRI), fire_return_interval_years = out$post$FRI)
  list(series = series, events = events, fri = fri,
       char_results = as.data.frame(out$char_results))
}

add_event_percentiles = function(events) {
  events |>
    dplyr::group_by(.data$site, .data$lake) |>
    dplyr::mutate(
      magnitude_rank = rank(.data$peak_magnitude, ties.method = "average"),
      magnitude_percentile = (.data$magnitude_rank - 0.5) / dplyr::n()) |>
    dplyr::ungroup()
}

rolling_fire_evidence = function(events, continuous, coverage,
                                  window_years = 1000L,
                                  grid_step = 100L) {
  half = window_years / 2
  ev = add_event_percentiles(events)
  rows = list(); k = 0L
  for (i in seq_len(nrow(coverage))) {
    cv = coverage[i, ]
    centers = seq(ceiling((cv$younger_cal_bp + half) / grid_step) * grid_step,
                  floor((cv$older_cal_bp - half) / grid_step) * grid_step,
                  by = grid_step)
    for (tt in centers) {
      ee = ev |>
        dplyr::filter(.data$lake == cv$lake,
          .data$age_cal_yr_BP >= tt - half, .data$age_cal_yr_BP < tt + half)
      cc = continuous |>
        dplyr::filter(.data$lake == cv$lake,
          .data$age_cal_yr_BP >= tt - half, .data$age_cal_yr_BP < tt + half)
      k = k + 1L
      rows[[k]] = tibble::tibble(
        site = cv$site, lake = cv$lake, cal_bp = tt,
        window_years = window_years, covered = TRUE,
        peak_frequency_per_1000yr = nrow(ee) / window_years * 1000,
        peak_strength_percentile_sum = sum(ee$magnitude_percentile),
        background_char_z = if (nrow(cc)) mean(cc$background_z, na.rm = TRUE) else NA_real_)
    }
  }
  dplyr::bind_rows(rows)
}

interval_overlap_years = function(old1, young1, old2, young2) {
  pmax(0, pmin(old1, old2) - pmax(young1, young2))
}
