# =============================================================================
# fire_detection_functions.R - shared tapas fire-event detection
# =============================================================================
# Function-only module. All four maintained charcoal records use this exact
# implementation; record-specific chronology, interpolation, background, and
# threshold choices are supplied through a settings table by the calling stage.

capture_tapas_graphics = function(expression) {
  temporary_plot = tempfile("tapas_internal_", fileext = ".pdf")
  grDevices::pdf(temporary_plot)
  on.exit({
    grDevices::dev.off()
    unlink(temporary_plot)
  }, add = TRUE)
  force(expression)
}

prepare_mora_charcoal = function(path) {
  readxl::read_xlsx(path) |>
    dplyr::transmute(
      CmTop = as.numeric(trimws(.data[["Depth Top (cm)"]])),
      CmBot = as.numeric(trimws(.data[["Depth bottom (cm)"]])),
      AgeTop = as.numeric(trimws(.data[["Age Top"]])),
      AgeBot = as.numeric(trimws(.data[["Age Bottom"]])),
      Volume = as.numeric(trimws(.data[["Volume (cc)"]])),
      Total = as.numeric(trimws(.data[["Total"]])),
      variable1 = as.numeric(trimws(.data[["Charcoal Concentration"]]))) |>
    dplyr::filter(dplyr::if_all(
      dplyr::all_of(c("CmTop", "CmBot", "AgeTop", "AgeBot", "Volume", "Total")),
      is.finite)) |>
    as.data.frame()
}

prepare_noca_charcoal = function(charcoal, bacon_ages) {
  charcoal |>
    dplyr::transmute(
      CmTop = .data$depth - .data$thickness / 2,
      CmBot = .data$depth + .data$thickness / 2,
      AgeTop = stats::approx(bacon_ages$depth, bacon_ages$median, CmTop,
        rule = 2)$y,
      AgeBot = stats::approx(bacon_ages$depth, bacon_ages$median, CmBot,
        rule = 2)$y,
      Volume = .data$volume_ml,
      Total = .data$charcoal_150_1000_) |>
    dplyr::filter(dplyr::if_all(dplyr::everything(), is.finite)) |>
    as.data.frame()
}

run_tapas_fire_detection = function(series, site, lake, interpolation_years,
                                     smoothing_years, threshold_probability,
                                     chronology, input_source,
                                     minimum_count_probability = 0.05,
                                     minimum_count_window_years = 75) {
  required = c("CmTop", "CmBot", "AgeTop", "AgeBot", "Volume", "Total")
  if (!all(required %in% names(series)))
    stop("Charcoal input for ", lake, " lacks: ",
      paste(setdiff(required, names(series)), collapse = ", "))
  if (any(!is.finite(unlist(series[required]))) || any(series$Volume <= 0))
    stop("Charcoal input for ", lake, " contains invalid values.")

  checked = capture_tapas_graphics(tapas::check_pretreat(series))
  checked$Total[checked$Total == 0] = 0.001
  fit = capture_tapas_graphics(tapas::peak_detection(
    series = checked, proxy = "Total", out = "accI",
    first = min(checked$AgeTop), last = max(checked$AgeBot),
    smoothing_yr = smoothing_years,
    thresh_type = "local", thresh_value = threshold_probability,
    min_CountP = minimum_count_probability,
    MinCountP_window = minimum_count_window_years,
    yrInterp = interpolation_years,
    keep_consecutive = FALSE, plotit = FALSE,
    detr_type = "rob.lowess", sens = TRUE))

  interpolated = tibble::as_tibble(fit$int$series.int) |>
    dplyr::transmute(age_cal_yr_BP = .data$age,
      char_interpolated = .data$TotalAR)
  detrended = tibble::as_tibble(fit$detr$detr) |>
    dplyr::transmute(age_cal_yr_BP = .data$age,
      peak_component = .data$TotalAR)
  magnitude = tibble::as_tibble(fit$thresh$PeakMag_pos) |>
    dplyr::transmute(age_cal_yr_BP = .data$ageI,
      peak_magnitude = .data$peak_mag)

  n_grid = nrow(interpolated)
  candidate = as.logical(fit$thresh$peaks.pos) |
    as.logical(fit$thresh$peaks.pos.insig)
  rejected = as.logical(fit$thresh$peaks.pos.insig)
  if (length(candidate) != n_grid || length(rejected) != n_grid ||
      length(fit$thresh$thresh.pos.sm) != n_grid)
    stop("Unexpected tapas output dimensions for ", lake, ".")

  continuous = interpolated |>
    dplyr::left_join(detrended, by = "age_cal_yr_BP") |>
    dplyr::left_join(magnitude, by = "age_cal_yr_BP") |>
    dplyr::mutate(
      site = site, lake = lake,
      background_char = .data$char_interpolated - .data$peak_component,
      positive_threshold = as.numeric(fit$thresh$thresh.pos.sm),
      minimum_count_p = NA_real_,
      candidate_before_count_screen = candidate,
      rejected_by_count_screen = rejected,
      is_significant = .data$age_cal_yr_BP %in% fit$thresh$peaks.pos.ages,
      background_z = as.numeric(scale(log1p(pmax(.data$background_char, 0))))) |>
    dplyr::select(.data$site, .data$lake, .data$age_cal_yr_BP,
      .data$char_interpolated, .data$background_char, .data$peak_component,
      .data$positive_threshold, .data$minimum_count_p,
      .data$candidate_before_count_screen, .data$rejected_by_count_screen,
      .data$is_significant, .data$peak_magnitude, .data$background_z)

  events = continuous |>
    dplyr::filter(.data$is_significant) |>
    dplyr::select(.data$site, .data$lake, .data$age_cal_yr_BP,
      .data$peak_magnitude)
  peaks = magnitude |>
    dplyr::mutate(
      lake = lake,
      is_significant = .data$age_cal_yr_BP %in% fit$thresh$peaks.pos.ages,
      smoothing_window = smoothing_years,
      interpolation_interval = interpolation_years,
      threshold_probability = threshold_probability) |>
    dplyr::select(.data$lake, .data$age_cal_yr_BP, .data$peak_magnitude,
      .data$is_significant, .data$smoothing_window,
      .data$interpolation_interval, .data$threshold_probability) |>
    dplyr::arrange(dplyr::desc(.data$age_cal_yr_BP))
  settings = tibble::tibble(
    site = site, lake = lake, engine = "tapas",
    chronology = chronology, input_source = input_source,
    interpolation_years = interpolation_years,
    smoothing_years = smoothing_years,
    threshold_probability = threshold_probability,
    threshold_type = "local Gaussian-mixture noise",
    transform = "none", background_method = "robust LOWESS",
    minimum_count_probability = minimum_count_probability,
    minimum_count_window_years = minimum_count_window_years,
    consecutive_rule = "collapse adjacent exceedances")

  list(series = continuous, events = events, peaks = peaks,
       settings = settings, fit = fit, checked_input = checked)
}

fire_source_settings = function() {
  tibble::tribble(
    ~site, ~lake, ~input_source, ~chronology, ~interpolation_years,
      ~smoothing_years, ~threshold_probability,
    "MORA", "Sunrise Lake", "data/PALEO/char_sunrise_lake.xlsx",
      "published core chronology", 48, 800, .95,
    "MORA", "Shadow Lake", "data/PALEO/char_shadow_lake.xlsx",
      "published core chronology", 47, 1000, .95,
    "MORA", "Little Sunrise Lake", "data/PALEO/char_little_sunrise.xlsx",
      "published core chronology", 42, 500, .95,
    "NOCA", "PantherPotholes",
      "data/NOCA/NOCA_paleo/neotoma_macrocharcoal_52210.csv",
      "active PaleoACES Bacon median chronology", 12, 500, .99)
}
