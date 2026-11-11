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
# The correction of the paleoclimate (Appendix S2): 'two_step' in the main run
# (TraCE21k to CHELSAcruts to CHELSA V2.1, Bills, 11 Nov 2026), 'one_step'
# (CHELSAcruts to V2.1 only) and 'none' (raw TraCE21k, the main run until 11 Nov
# 2026) in the sensitivity runs of R/sensitivity_paleoclimate.R.
PALEO_CORRECTION = getOption('paleoaces.paleo_correction', 'two_step')
stopifnot(PALEO_CORRECTION %in% c('two_step', 'one_step', 'none'))
PALEO_USE_BIAS_CORRECTED = PALEO_CORRECTION != 'none'
# The four cored vegetation lakes (Holocene macrofossil records), read by
# R/pipeline/07_climate_products.R and R/pipeline/08_paleo_climate.R. Moved here
# from the paleo stage on 11 Nov 2026 with its provenance notes.
# MORA coords per Dunwiddie 1986; NOCA per Prichard 2009.
# =============================================================================
# POND COORDINATES - provenance and precision (audited 2026-08-13)
# =============================================================================
# CHELSA is 30 arcsec (~0.00833 deg, ~700 m E-W here), so coordinate precision
# below ~1 km changes the grid cell. Every coordinate below was traced to its
# most precise published source; GNIS, Neotoma, NOAA WDS-Paleo and the open web
# were all searched.
#
# PantherPotholes - CHANGED 2026-08-13, was (-121.0333, 48.6500).
#   Neotoma site 13042 carries a site POLYGON:
#     [-121.04089, 48.65816] .. [-121.0381, 48.65952], altitude 1033 m
#   centre = (-121.0395, 48.6588). This is the dataset PI's own site footprint,
#   precise to ~150 m. The old value was Prichard (2009)'s published
#   "48 deg 39' N, 121 deg 02' W" - the SAME site, rounded to arcminutes, which
#   put it 1.1 km away in a DIFFERENT CHELSA cell in both axes.
#   Measured cost of the old coordinate: precipitation was unaffected (annual
#   1231 vs 1224 mm) but temperature ran 0.85 degC COOL in every month - a
#   constant displacement of 0.171 CCA units, 47% of the span of the entire NOCA
#   Holocene climate trajectory. Corrected because it is wrong, not because of
#   the size of its effect.
#
# The three MORA ponds - ALL CHANGED 2026-08-13. The previous values were
# Dunwiddie (1986)'s published coordinates, given only to the ARCMINUTE:
#     Jay Bath          46 deg 46' N, 121 deg 46' W, 1311 m
#     Log Wallow        46 deg 46' N, 121 deg 45' W, "1.2 km NE of Jay Bath, +50 m"
#     Reflection Pond 1 46 deg 46' N, 121 deg 43' W, "2.4 km E of Log Wallow,
#                       easternmost of the ponds called the Reflection Lakes"
#   Arcminute rounding at 46.77 N is +/-928 m in latitude and +/-635 m in
#   longitude - MORE than one CHELSA cell - and it put all three ponds at the
#   IDENTICAL latitude, which is a rounding artefact, not geography.
#   ⚠ THE OLD JAY BATH COORDINATE HAD NO POND AT IT. Confirmed on satellite
#   imagery by Billur, 2026-08-13. These are not small errors; they were the
#   wrong locations.
#
#   The ponds are Dunwiddie's own informal names and appear in NO gazetteer or
#   database - GNIS, Neotoma and NOAA WDS-Paleo all return nothing - so the
#   ponds were located directly on satellite imagery by Billur. The values below
#   are those, and they are INDEPENDENTLY CORROBORATED three ways:
#
#     1. they reproduce Dunwiddie's published arcminutes
#          Jay Bath          46 46.23' / 121 46.10'   -> 46 46' / 121 46'  exact
#          Log Wallow        46 46.50' / 121 45.23'   -> 121 45' exact; the
#                            latitude falls exactly on the .50 rounding
#                            boundary, which truncation renders as 46 46'
#          Reflection Pond 1 46 46.17' / 121 43.49'   -> 46 46' / 121 43'  exact
#     2. they reproduce his stated inter-pond distances
#          Jay Bath -> Log Wallow    1.22 km   (he says 1.2 km)
#          Log Wallow -> Reflection  2.30 km   (he says 2.4 km)
#          Jay Bath -> Reflection    3.32 km   (he says a 3.5-km transect)
#     3. they RESOLVE the contradiction the old coordinates carried. Dunwiddie's
#        text says Log Wallow is NORTHEAST of Jay Bath; the rounded coordinates
#        put it due EAST at identical latitude. The located ponds give a bearing
#        of 65 deg - north of east. His prose was right; the rounding was the
#        artefact.
#
#   ⚠ GNIS "Reflection Lakes" (46.7695, -121.7300, 1481 m) is NOT this pond: it
#   is the group centroid, and Dunwiddie specifies the EASTERNMOST pond of that
#   group. Do not substitute it.
#
# CRS: all coordinates are WGS 84 decimal degrees (EPSG:4326), which is what
# Google Maps reports and what CHELSA rasters are stored in - verified directly
# from a CHELSA GeoTIFF header (EPSG:4326, 0.008333 deg = 30 arcsec). NO
# reprojection is needed or applied anywhere in this pipeline.
PALEO_LAKES = data.frame(
  ID  = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes"),
  lon = c(-121.768404, -121.753865, -121.724790,   -121.0395),
  lat = c(  46.770463,   46.775068,   46.769559,     48.6588),
  site = c("MORA", "MORA", "MORA", "NOCA"), stringsAsFactors = FALSE)

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
