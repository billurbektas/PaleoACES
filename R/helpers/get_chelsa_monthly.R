# =============================================================================
# get_chelsa_monthly() - CHELSA V2.1 MONTHLY timeseries, 1979-01 to 2021-12
# =============================================================================
# A LOCAL SUPPLEMENT to the vendored R/vendor/get_chelsa.R, which is not edited (see the
# header in that file). get_chelsa(source = "present") hardcodes the V2.1 DAILY
# url, so a monthly value costs ~30 streamed reads instead of 1. For this project
# that is the difference between a ~40 hour download and a ~6 hour one, at
# identical information content: we only ever use monthly aggregates.
#
#   daily   .../global/daily/{var}/{year}/CHELSA_{var}_{DD}_{MM}_{YYYY}_V.2.1.tif
#   monthly .../global/monthly/{var}/{year}/CHELSA_{var}_{MM}_{YYYY}_V.2.1.tif
#
# TODO upstream: add source = "monthly" to get_chelsa() and re-vendor, then
# delete this file.
#
# COVERAGE, verified by HTTP HEAD 2026-08-12 (do not trust documentation):
#
#   V2.1 monthly, ALL vars (tasmin/tasmax/pr)   1979-01  ->  2021-12
#   V2.1 daily,   tasmin/tasmax                 1941-01-01 -> 2025-09-30
#   V2.1 daily,   pr                            1979-01-01 -> 2019-12-31
#   CHELSAcruts monthly, tmin/tmax/prec         1901     ->  2016
#
# So V2.1 monthly starts in 1979 for everything; only DAILY temperature reaches
# back to 1941. Nothing in V2.1 gives precipitation before 1979.
#
# UNITS: temperature is Kelvin in the file; converted to degC here when
# to_celsius = TRUE. Precipitation is returned in its native units, as in
# get_chelsa() - it is NOT rescaled.
# =============================================================================

CHELSA_MONTHLY_FIRST_YEAR = 1979L
CHELSA_MONTHLY_LAST_YEAR  = 2021L

get_chelsa_monthly <- function(coords, vars, years, months = 1:12,
                               to_celsius = TRUE, id_col = NULL, verbose = TRUE) {

  if (!requireNamespace("terra", quietly = TRUE))
    stop("Package 'terra' is required. install.packages('terra')")

  valid = c("tas", "tasmax", "tasmin", "pr")
  bad = setdiff(vars, valid)
  if (length(bad))
    warning("V2.1 monthly variables are: ", paste(valid, collapse = ", "),
            ". Unrecognised: ", paste(bad, collapse = ", "))

  out_of_range = years[years < CHELSA_MONTHLY_FIRST_YEAR | years > CHELSA_MONTHLY_LAST_YEAR]
  if (length(out_of_range))
    warning("CHELSA V2.1 monthly covers ", CHELSA_MONTHLY_FIRST_YEAR, "-",
            CHELSA_MONTHLY_LAST_YEAR, "; dropping year(s): ",
            paste(out_of_range, collapse = ", "))
  years = years[years >= CHELSA_MONTHLY_FIRST_YEAR & years <= CHELSA_MONTHLY_LAST_YEAR]
  if (!length(years)) return(data.frame())

  # reuse the vendored coordinate handling so ids behave identically
  pts = .chelsa_prep_coords(coords, id_col = id_col)
  xy  = pts[, c("lon", "lat")]

  jobs = list()
  for (v in vars) for (yr in years) for (m in months)
    jobs[[length(jobs) + 1]] = list(
      var = v, year = as.integer(yr), month = as.integer(m),
      url = sprintf(paste0("https://os.unil.cloud.switch.ch/chelsa02/chelsa/global/",
                           "monthly/%s/%d/CHELSA_%s_%02d_%d_V.2.1.tif"),
                    v, as.integer(yr), v, as.integer(m), as.integer(yr)))

  if (verbose)
    cat(sprintf("[get_chelsa_monthly] %d coordinate(s) | %d file(s) to read\n",
                nrow(pts), length(jobs)))

  out = vector("list", length(jobs)); n_ok = 0L; n_missing = 0L; missing_urls = character(0)

  for (i in seq_along(jobs)) {
    j = jobs[[i]]
    val = tryCatch({
      r = terra::rast(paste0("/vsicurl/", j$url))
      as.numeric(terra::extract(r, xy)[, 2])
    }, error = function(e) NULL, warning = function(w) NULL)

    if (is.null(val)) {
      n_missing = n_missing + 1L; missing_urls = c(missing_urls, j$url)
      if (verbose) cat(sprintf("  ! missing: %s\n", basename(j$url)))
      next
    }
    n_ok = n_ok + 1L
    if (.chelsa_is_temp(j$var) && to_celsius) val = val - 273.15

    out[[i]] = data.frame(id = pts$id, lon = pts$lon, lat = pts$lat,
                          source = "v21_monthly", variable = j$var,
                          year = j$year, month = j$month,
                          date = as.Date(sprintf("%d-%02d-01", j$year, j$month)),
                          slice = NA_integer_, value = val,
                          stringsAsFactors = FALSE)

    if (verbose && (i %% 25 == 0 || i == length(jobs)))
      cat(sprintf("  ... %d/%d (%d ok, %d missing)\n", i, length(jobs), n_ok, n_missing))
  }

  res = do.call(rbind, out[!vapply(out, is.null, logical(1))])
  if (is.null(res)) res = data.frame()
  if (verbose)
    cat(sprintf("[get_chelsa_monthly] done: %d read, %d missing, %d rows\n",
                n_ok, n_missing, nrow(res)))
  if (n_missing) attr(res, "missing_urls") = missing_urls
  res
}
