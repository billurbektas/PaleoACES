# Shared analysis settings. Source this file; do not run it as a pipeline stage.
# Output and figure locations: out() and fig() from R/helpers/paths.R.
source(here::here('R/helpers/paths.R'), local = TRUE)
CCA_COUNT_THRESHOLD = 20L
# Active CCA constraints (decision 2026-11-09, report/details/10_decisions.md):
# spring temperature and summer precipitation, one temperature and one
# precipitation variable. The former four (MSpT, MWT, SP, WP) had variance
# inflation factors near 30 for the two temperatures, whose separate
# coefficients were not identifiable; MSpT is the temperature that changes most
# through the Holocene. These are seasonal climate correlates, not direct
# growing-degree or drought indices.
CCA_VARIABLES = c("MSpT", "SP")
# Figures show the CCA plane rotated (varimax, display only) so that the
# temperature and precipitation arrows lie along the two axes.
CCA_DISPLAY_ROTATION = TRUE
# Seasonal variables shown in the appendix climate figures. Only CCA_VARIABLES
# enter the CCA, the climate eras and every tracking metric; the others are
# standardized with the same legacy calibration plots for display alone.
CLIMATE_DISPLAY_VARIABLES = c("MSpT", "MWT", "SP", "WP")
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
# The Anthropocene legacy-resurvey plot pairs of the analysis. The two MORA
# plots burned between the surveys are left out (Bills, 11 Nov 2026), so MORA
# has 328 pairs (330 before).
ANTHROPOCENE_PAIRS = c(MORA = 328L, NOCA = 277L)
# Raw TraCE21k in the primary run. The bias-corrected sensitivity run
# (R/sensitivity_bias_corrected.R) sets the option to TRUE.
PALEO_USE_BIAS_CORRECTED = isTRUE(getOption('paleoaces.bias_corrected', FALSE))
# Dating of the CHELSA-TraCE21k slices. timeID k is the mean of the years
# 100(k - 1) to 100k - 1 CE, and timeID 20 the mean of 1900 to 1990 (technical
# specification v1.0, Table 4). A slice is dated at the centre of its century,
# 100k - 50 CE = 2000 - 100k cal BP, and stands for the 100 years around it, so
# century cells, bins and period boundaries fall at x50 cal BP. timeID 20 stands
# for 1900 to 2000 CE (0 cal BP): the samples of the 1990s get the 1900 to 1990
# mean, the youngest the product has. Until 11 Nov 2026 every slice was dated 50
# years too young (1950 - 100k cal BP), which gave about half of the samples the
# climate of the century before their own.
trace_slice_cal_bp = function(slice) 2000 - 100 * slice
# The centre (cal BP) of the slice century that holds an age.
trace_century_cal_bp = function(age_cal_bp) floor((age_cal_bp + 50) / 100) * 100

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
  point_columns = c("id", "lon", "lat")
  if (!all(point_columns %in% names(points)) || !nrow(points) ||
      anyNA(points[point_columns]) || anyDuplicated(points$id) ||
      !is.numeric(points$lon) || !is.numeric(points$lat) ||
      any(!is.finite(points$lon) | !is.finite(points$lat))) return(FALSE)
  if (is.null(x) || !all(required %in% names(x)) || !nrow(x) ||
      anyNA(x[required]) || !is.numeric(x$value) ||
      !is.numeric(x$lon) || !is.numeric(x$lat) ||
      any(!is.finite(x$value) | !is.finite(x$lon) | !is.finite(x$lat)) ||
      !all(x$variable == variable) || !all(x$year == year))
    return(FALSE)
  cached_ids = unique(x$id)
  ids_ok = if (allow_point_superset) all(points$id %in% cached_ids) else
    setequal(cached_ids, points$id)
  if (!ids_ok) return(FALSE)
  if (!is.null(expected_source) &&
      (!("source" %in% names(x)) || anyNA(x$source) ||
       !all(x$source == expected_source))) return(FALSE)
  if (!is.null(expected_source) && !"month" %in% names(x)) return(FALSE)
  if ("month" %in% names(x)) {
    current = x[c("id", "month")]
    # CHELSA V2.1 genuinely has no January 1979 tasmin/tasmax file. This is a
    # documented source gap, not permission to accept arbitrary short chunks.
    expected_months = if (identical(as.integer(year), 1979L) &&
                            variable %in% c("tasmin", "tasmax") &&
                            identical(expected_source, "v21_monthly")) 2:12 else 1:12
    expected = expand.grid(id = cached_ids, month = expected_months,
                           stringsAsFactors = FALSE)
    current_key = paste(current$id, current$month, sep = "::")
    expected_key = paste(expected$id, expected$month, sep = "::")
    if (anyDuplicated(current_key) || !setequal(current_key, expected_key)) return(FALSE)
  }
  got = unique(x[c("id", "lon", "lat")])
  if (anyDuplicated(got$id)) return(FALSE)
  got = got[match(points$id, got$id), ]
  all(abs(got$lon - points$lon) < 1e-8 & abs(got$lat - points$lat) < 1e-8)
}
