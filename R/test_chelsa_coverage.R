# =============================================================================
# test_chelsa_coverage.R - the exact year bounds of every CHELSA product
# =============================================================================
# Establishes the coverage table in data/SOURCES_SURVEY_YEARS.md. Uses HTTP HEAD, not
# downloads, so it costs seconds.
#
# DO NOT TRUST THE DOCUMENTATION. The vendored get_chelsa.R header says V2.1 is
# "1979 - ~present" for all variables. Verified 2026-08-12, it is wrong at both
# ends AND the variable groups differ:
#
#   V2.1 monthly, all vars        1979-01     -> 2021-12
#   V2.1 daily, tasmin/tasmax     1941-01-01  -> 2025-09-30
#   V2.1 daily, pr                1979-01-01  -> 2019-12-31
#   CHELSAcruts monthly           1901        -> 2016
#
# Re-run this if CHELSA is updated; the download windows depend on it.
# =============================================================================

library(here)

head_code = function(url) {
  con = url(url, method = "libcurl")
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  code = tryCatch({
    suppressWarnings(open(con, "rb")); 200L
  }, error = function(e) 404L)
  code
}

# curl is faster and gives the real status; fall back to R if unavailable
status = function(u) {
  out = suppressWarnings(system2("curl", c("-s", "-o", "/dev/null",
                                           "-w", "%{http_code}", "-I", shQuote(u)),
                                 stdout = TRUE, stderr = FALSE))
  if (length(out) && grepl("^[0-9]{3}$", out[1])) as.integer(out[1]) else head_code(u)
}

B21   = "https://os.unil.cloud.switch.ch/chelsa02/chelsa/global"
BCRU  = "https://os.zhdk.cloud.switch.ch/chelsav1/chelsa_cruts"
BPAL  = "https://os.zhdk.cloud.switch.ch/chelsa01/chelsa_trace21k/global/centennial"

u_daily   = function(v, d, m, y) sprintf("%s/daily/%s/%d/CHELSA_%s_%02d_%02d_%d_V.2.1.tif", B21, v, y, v, d, m, y)
u_monthly = function(v, m, y)    sprintf("%s/monthly/%s/%d/CHELSA_%s_%02d_%d_V.2.1.tif",    B21, v, y, v, m, y)
u_cruts   = function(v, m, y)    sprintf("%s/%s/CHELSAcruts_%s_%d_%d_V.1.0.tif",            BCRU, v, v, m, y)
u_paleo   = function(v, m, s)    sprintf("%s/%s/CHELSA_TraCE21k_%s_%02d_%04d_V.1.0.tif",    BPAL, v, v, m, s)

report = function(label, urls, keys) {
  ok = vapply(urls, function(u) status(u) == 200L, logical(1))
  cat("\n", label, "\n", sep = "")
  for (i in seq_along(keys))
    cat(sprintf("   %-14s %s\n", keys[i], ifelse(ok[i], "ok", "MISSING")))
  invisible(ok)
}

cat("=== CHELSA V2.1 DAILY - temperature ===")
yrs = c(1939, 1940, 1941, 1942, 2024, 2025, 2026)
report("tasmin, 15 June", lapply(yrs, function(y) u_daily("tasmin", 15, 6, y)), yrs)
report("tasmin, boundary days",
       list(u_daily("tasmin", 31, 12, 1940), u_daily("tasmin", 1, 1, 1941),
            u_daily("tasmin", 30, 9, 2025),  u_daily("tasmin", 1, 10, 2025)),
       c("1940-12-31", "1941-01-01", "2025-09-30", "2025-10-01"))

cat("\n=== CHELSA V2.1 DAILY - precipitation (DIFFERENT range) ===")
yrs = c(1975, 1978, 1979, 2019, 2020)
report("pr, 15 June", lapply(yrs, function(y) u_daily("pr", 15, 6, y)), yrs)
report("pr, boundary days",
       list(u_daily("pr", 31, 12, 1978), u_daily("pr", 1, 1, 1979),
            u_daily("pr", 31, 12, 2019), u_daily("pr", 1, 1, 2020)),
       c("1978-12-31", "1979-01-01", "2019-12-31", "2020-01-01"))

cat("\n=== CHELSA V2.1 MONTHLY (all vars; 30x cheaper than daily) ===")
for (v in c("tasmin", "tasmax", "pr")) {
  yrs = c(1978, 1979, 2021, 2022)
  report(sprintf("%s, June", v), lapply(yrs, function(y) u_monthly(v, 6, y)), yrs)
}

cat("\n=== CHELSAcruts ===")
yrs = c(1900, 1901, 2016, 2017)
report("tmin, June", lapply(yrs, function(y) u_cruts("tmin", 6, y)), yrs)

cat("\n=== TraCE21k - is slice 20 the last? ===")
for (v in c("tasmin", "tasmax", "pr")) {
  sl = c(18, 19, 20, 21)
  report(sprintf("%s, month 1", v), lapply(sl, function(s) u_paleo(v, 1, s)),
         paste("slice", sl))
}

cat("\nKnown stray gap: daily tasmin 1979-01-01 is a genuine 404 while 1979-01-02 works.\n")
cat("If any bound above has moved, update data/SOURCES_SURVEY_YEARS.md and the WINDOWS blocks in R/000_MORA_climate.R and R/000_NOCA_climate.R.\n")
