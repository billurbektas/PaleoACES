# Shared analysis settings. Source this file; do not run it as a pipeline stage.
CCA_COUNT_THRESHOLD = 20L
# Active CCA constraints, ordered by ecological interpretation. These are
# seasonal climate correlates, not direct GDD, FDD, dryness, or snowpack:
# warmer MWT implies less freezing exposure and greater SP implies less dryness.
CCA_VARIABLES = c("MSpT", "MWT", "SP", "WP")
CLIMATE_VARIABLE_LABELS = c(
  MAT = "Annual temperature", MSpT = "Spring temperature",
  MST = "Summer temperature", MWT = "Winter temperature",
  AP = "Annual precipitation", SpP = "Spring precipitation",
  SP = "Summer precipitation", WP = "Winter precipitation"
)
CLIMATE_VARIABLE_UNITS = c(
  MAT = "degrees_C", MSpT = "degrees_C", MST = "degrees_C", MWT = "degrees_C",
  AP = "mm", SpP = "mm", SP = "mm", WP = "mm"
)
NOCA_FIRE_START = 1983L
NOCA_FIRE_END = 2015L
PALEO_USE_BIAS_CORRECTED = FALSE

object_fingerprint = function(x) {
  f = tempfile(pattern = "paleoaces-fingerprint-", fileext = ".rds")
  on.exit(unlink(f), add = TRUE)
  saveRDS(x, f, version = 2)
  unname(tools::md5sum(f))
}

climate_cache_valid = function(path, points, variable, year,
                               expected_source = NULL,
                               allow_point_superset = FALSE) {
  if (!file.exists(path)) return(FALSE)
  x = tryCatch(readr::read_csv(path, show_col_types = FALSE),
               error = function(e) NULL)
  required = c("id", "lon", "lat", "variable", "year", "value")
  if (is.null(x) || !all(required %in% names(x)) || !nrow(x) ||
      anyNA(x$value) || !all(x$variable == variable) || !all(x$year == year))
    return(FALSE)
  cached_ids = unique(x$id)
  ids_ok = if (allow_point_superset) all(points$id %in% cached_ids) else
    setequal(cached_ids, points$id)
  if (!ids_ok) return(FALSE)
  if (!is.null(expected_source) &&
      (!("source" %in% names(x)) || !all(x$source == expected_source))) return(FALSE)
  if ("month" %in% names(x)) {
    current = x[x$id %in% points$id, c("id", "month")]
    # CHELSA V2.1 genuinely has no January 1979 tasmin/tasmax file. This is a
    # documented source gap, not permission to accept arbitrary short chunks.
    expected_months = if (identical(as.integer(year), 1979L) &&
                            variable %in% c("tasmin", "tasmax") &&
                            identical(expected_source, "v21_monthly")) 2:12 else 1:12
    expected = expand.grid(id = points$id, month = expected_months,
                           stringsAsFactors = FALSE)
    current_key = paste(current$id, current$month, sep = "::")
    expected_key = paste(expected$id, expected$month, sep = "::")
    if (anyDuplicated(current_key) || !setequal(current_key, expected_key)) return(FALSE)
  }
  got = unique(x[c("id", "lon", "lat")])
  got = got[match(points$id, got$id), ]
  all(abs(got$lon - points$lon) < 1e-8 & abs(got$lat - points$lat) < 1e-8)
}
