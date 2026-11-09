# Adult resurvey dates and plot-specific modern climate windows (2026-10-07).
# Received CSVs remain unchanged. The same selected years feed vegetation,
# climate aggregation, diagnostics and rate denominators.
source(here::here('R/helpers/config.R'), local = TRUE)
normalize_mora_visit = function(x) {
  x = toupper(gsub("[[:space:]]", "", as.character(x)))
  gsub("-0+([0-9])", "-\\1", x)
}

survey_windows = function(x) {
  keys = c("site", "plot_id")
  if (any(!x$site %in% c("MORA", "NOCA")) || anyNA(x[c(keys, "vegetation_t2_year")]) || anyDuplicated(x[keys]) ||
      any(!is.finite(x$vegetation_t2_year) | x$vegetation_t2_year %% 1 != 0))
    stop("Every modern plot needs exactly one finite integer adult resurvey year.")
  x = x |>
    dplyr::mutate(climate_start = vegetation_t2_year - 5L,
      climate_end = vegetation_t2_year, climate_n_years = 6L,
      vegetation_t1_year = dplyr::if_else(site == "MORA", 1977.5, 1983),
      vegetation_dt_years = vegetation_t2_year - vegetation_t1_year,
      climate_t1_midyear = 1984, climate_t2_midyear = vegetation_t2_year - 2.5,
      climate_dt_years = climate_t2_midyear - climate_t1_midyear)
  if (any(x$vegetation_dt_years <= 0 | x$climate_dt_years <= 0))
    stop("Modern survey dates must follow both historical reference dates.")
  x
}

resolve_mora_resurveys = function(trees, seedlings, plot_library, visit_map) {
  if (anyDuplicated(plot_library$Plot_ID) || anyNA(plot_library[c("Plot_ID", "plot_id")]))
    stop("MORA plot library must map each supplied Plot_ID exactly once.")
  prep = function(x, stage) {
    x |> dplyr::mutate(source_row = dplyr::row_number() + 1L,
      source_year = Year, stage = stage,
      visit_name = normalize_mora_visit(Plot.ID)) |>
      dplyr::filter(Plot_ID %in% plot_library$Plot_ID)
  }
  adults = prep(trees, "adult"); seeds = prep(seedlings, "seedling")
  if (anyNA(adults[c("Plot_ID", "Year", "visit_name")]) ||
      any(!is.finite(adults$Year) | adults$Year %% 1 != 0))
    stop("Missing or ambiguous adult MORA visit date.")
  visits = adults |> dplyr::distinct(Plot_ID, Year) |>
    dplyr::group_by(Plot_ID) |>
    dplyr::summarise(n_adult_years = dplyr::n(), selected_year = max(Year),
      .groups = "drop")
  adults = adults |> dplyr::left_join(visits, by = "Plot_ID") |>
    dplyr::mutate(assigned_year = Year, assignment = "adult CSV year")
  map_keys = c("Plot_ID", "visit_name", "source_year")
  if (anyDuplicated(visit_map[map_keys]) || anyNA(visit_map[c(map_keys, "adult_year")]))
    stop("Verified MORA seedling-visit mappings must be complete and unique.")
  seeds = seeds |> dplyr::left_join(visits, by = "Plot_ID") |>
    dplyr::left_join(visit_map |> dplyr::select(dplyr::all_of(map_keys), adult_year),
      by = map_keys) |>
    dplyr::mutate(assigned_year = dplyr::if_else(n_adult_years == 1L,
      selected_year, adult_year), assignment = dplyr::if_else(n_adult_years == 1L,
      "single adult visit year", "verified original visit mapping"))
  adult_keys = paste(adults$Plot_ID, adults$Year)
  if (anyNA(seeds[c("selected_year", "assigned_year")]) ||
      any(!paste(seeds$Plot_ID, seeds$assigned_year) %in% adult_keys))
    stop("Seedling MORA visit cannot be assigned unambiguously to an adult year.")
  audit = dplyr::bind_rows(adults, seeds) |>
    dplyr::mutate(selected = assigned_year == selected_year,
      year_corrected = source_year != assigned_year,
      treatment = dplyr::if_else(selected, "retain latest adult visit",
        "discard earlier adult visit")) |>
    dplyr::left_join(plot_library |> dplyr::select(Plot_ID, plot_id), by = "Plot_ID") |>
    dplyr::select(Plot_ID, plot_id, stage, source_row, Plot.ID, source_year,
      assigned_year, selected_year, year_corrected, selected, assignment, treatment)
  selected = function(x) x |> dplyr::filter(assigned_year == selected_year) |>
    dplyr::mutate(Year = assigned_year)
  years = visits |> dplyr::left_join(plot_library |> dplyr::select(Plot_ID, plot_id),
    by = "Plot_ID") |>
    dplyr::transmute(site = "MORA", plot_id, vegetation_t2_year = selected_year) |>
    survey_windows()
  list(trees = selected(adults), seedlings = selected(seeds), years = years, audit = audit,
    visits = audit |> dplyr::group_by(Plot_ID, plot_id, stage, assigned_year, selected_year) |>
      dplyr::summarise(records = dplyr::n(), corrected_records = sum(year_corrected),
        selected = all(selected), .groups = "drop"))
}

read_plot_years = function(site = NULL) {
  signature = out("modern_plot_years_sources.rds")
  if (!file.exists(signature) || !identical(readRDS(signature), plot_year_input_hashes()))
    stop("Survey-date inputs changed: rerun both vegetation cleaners before using climate or tracking products.")
  x = readr::read_csv(out("modern_plot_years.csv"), show_col_types = FALSE)
  expected = survey_windows(x |> dplyr::select(site, plot_id, vegetation_t2_year))
  if (!isTRUE(all.equal(as.data.frame(x), as.data.frame(expected), check.attributes = FALSE)))
    stop("Modern plot-year table has inconsistent climate windows or elapsed times.")
  if (!is.null(site)) x = x[x$site == site, ]
  x
}

plot_year_input_hashes = function() {
  paths = c("data/MORA/MORA_TreeData_Resurvey_Cleaned.csv",
    "data/MORA/MORA_Seedlings_Resurvey_Cleaned.csv", "data/MORA/MORA_plot_lib.csv",
    "data/MORA/resurvey_seedling_visit_mapping.csv", "data/NOCA/NOCA_plots_fromWilson.csv")
  stats::setNames(unname(tools::md5sum(here::here(paths))), paths)
}

# Copy only absent native chunks from an independently validated V2.1 cache.
# An existing invalid native chunk still fails offline; it is never covered up.
reuse_survey_diagnostic_cache = function(todo, points) {
  for (i in which(!file.exists(todo$path) & todo$route == "monthly")) {
    alternate = file.path(out("anomaly_parts"),
      sprintf("%s_%d.csv", todo$var[i], todo$year[i]))
    if (!climate_cache_valid(alternate, points, todo$var[i], todo$year[i],
          expected_source = "v21_monthly", allow_point_superset = TRUE)) next
    x = readr::read_csv(alternate, show_col_types = FALSE) |>
      dplyr::filter(id %in% points$id) |>
      dplyr::mutate(period = todo$period[i])
    tmp = paste0(todo$path[i], ".tmp")
    readr::write_csv(x, tmp)
    if (!climate_cache_valid(tmp, points, todo$var[i], todo$year[i],
          expected_source = "v21_monthly") || !file.rename(tmp, todo$path[i]))
      stop("Could not restore a validated native climate chunk: ", todo$path[i])
    message("Reused validated survey diagnostic cache: ", basename(todo$path[i]))
  }
}

restrict_modern_months = function(x, years) {
  x = x |> dplyr::left_join(years |> dplyr::select(site, plot_id, climate_start, climate_end),
    by = c("site", "plot_id"))
  if (anyNA(x[c("climate_start", "climate_end")])) stop("Missing plot climate window.")
  x = x |> dplyr::filter(period == "past" |
    (year >= climate_start & year <= climate_end) |
    (year == climate_start - 1L & month == 12L)) |>
    dplyr::select(-climate_start, -climate_end)
  modern = x[x$period == "present", ]
  if (anyDuplicated(modern[c("site", "plot_id", "variable", "year", "month")]) ||
      any(!is.finite(modern$value)) || anyNA(modern$month) ||
      any(!modern$month %in% 1:12) || any(modern$year %% 1 != 0))
    stop("Invalid modern monthly climate keys/values.")
  counts = modern |> dplyr::count(site, plot_id, variable)
  required = tidyr::crossing(years |> dplyr::select(site, plot_id),
    variable = c("tasmin", "tasmax", "pr")) |>
    dplyr::left_join(counts, by = c("site", "plot_id", "variable"))
  if (anyNA(required$n) || any(required$n != 73L))
    stop("Each modern plot requires six complete calendar years plus lead-in December for every variable.")
  x
}

restrict_modern_seasons = function(x, years) {
  bounds = years |> dplyr::transmute(unit = plot_id,
    period = paste(site, "present", sep = "."), climate_start, climate_end)
  x = x |> dplyr::left_join(bounds, by = c("unit", "period"))
  modern = endsWith(x$period, ".present")
  if (anyNA(x[modern, c("climate_start", "climate_end")]))
    stop("Missing modern season-year window.")
  x |>
    dplyr::filter(!endsWith(period, ".present") |
      (time >= climate_start & time <= climate_end)) |>
    dplyr::select(-climate_start, -climate_end)
}
