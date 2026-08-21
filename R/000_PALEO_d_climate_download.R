# =============================================================================
# 000_PALEO_d_climate_download.R - CHELSA-TraCE21k climate for the four ponds
# =============================================================================
# RESUMABLE. One CSV per (variable, slice) is written to output/chelsa_paleo/ as
# soon as it lands, and any file already there is skipped. ~4,000 streamed reads
# at ~6 s each is close to seven hours, so just re-run this script after an
# interrupt and it picks up where it stopped. Safe to Ctrl-C or shut the laptop.
# Each chunk is written to .tmp and renamed, so a kill mid-write can never leave a
# half-written CSV that would be read back as complete.
#
# DECISION: the paleo arm takes ALL its climate from TraCE21k, core tops included.
# Some samples are younger than 50 cal BP and slice 20 is the last one, so they all
# fall in one slice and get one value. That is the reason for the choice, not an
# objection to it: the Holocene arm bins at 500 yr, so it was never going to
# resolve within-century change anyway; those samples all land in the youngest bin
# regardless, which averages slices 16-20. Detecting 20th-century climate change is
# the Anthropocene arm's job, from the survey plots.
#
# BIAS CORRECTION. The CCA is calibrated on survey plots carrying V2.1
# (observations); paleo samples are projected carrying TraCE21k (a CCSM3 run).
# Measured at these ponds, slice 20 vs V2.1 1979-2021: tasmin +0.5 to +2.1 degC
# too warm, tasmax ~1.5 degC too cool. Corrected here - additive for temperature,
# multiplicative for precipitation (bounded at zero) - per pond x variable x month.
# BOTH raw and corrected values are written, so it is auditable and reversible.
# ⚠ Anchored at ONE slice, so it assumes a stationary bias. See the 🔴 unresolved
# issue in SCIENTIFIC_DECISIONS.md; rerun with BIAS_CORRECT = FALSE only as the
# documented anchoring sensitivity.
#
# Output: output/chelsa_paleo_ponds.csv  (+ per-chunk cache in output/chelsa_paleo/)
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr)})
source(here("R/get_chelsa.R"))          # vendored, commit 3d410b8
source(here("R/get_chelsa_monthly.R"))  # V2.1 monthly, for the bias anchor
source(here("R/config.R"))

CACHE        = here("output/chelsa_paleo")
OUT          = here("output/chelsa_paleo_ponds.csv")
OUT_BIAS     = here("output/chelsa_paleo_bias_correction.csv")
BIAS_CORRECT = TRUE
V21_REF      = 1979:2021
SLICE_MODERN = 20L

# TraCE21k slice ids: integers -200..20, one step ~100 yr, 20 = present, 0 = 0 CE.
# -90 is ~11 kyr BP, covering NOCA's 10,609 cal BP, so both sites get the SAME
# window - which they never had before (MORA was cut at 6000 BP while its cores
# reach 6841). Slice 21 and 22 are 404: 20 really is the last.
SLICES = -90:20
VARS   = c("tasmin", "tasmax", "pr")

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
ponds = data.frame(
  ID  = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes"),
  lon = c(-121.768404, -121.753865, -121.724790,   -121.0395),
  lat = c(  46.770463,   46.775068,   46.769559,     48.6588),
  site = c("MORA", "MORA", "MORA", "NOCA"), stringsAsFactors = FALSE)

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))   # from a killed run

# -----------------------------------------------------------------------------
# 1. download, one chunk per (variable, slice), skipping what is already there
# -----------------------------------------------------------------------------
todo = expand.grid(var = VARS, slice = SLICES, stringsAsFactors = FALSE)
todo$key  = sprintf("%s_sl%+04d", todo$var, todo$slice)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))

EXPECT = 12 * nrow(ponds)     # 12 months x 4 ponds
paleo_cache_valid = function(path, variable, slice) {
  if (!file.exists(path)) return(FALSE)
  x = tryCatch(read_csv(path, show_col_types = FALSE), error = function(e) NULL)
  required = c("id", "lon", "lat", "source", "variable", "month", "slice", "value")
  if (is.null(x) || !all(required %in% names(x)) || nrow(x) != EXPECT ||
      anyNA(x$value) || !all(x$source == "paleo") ||
      !all(x$variable == variable) || !all(x$slice == slice) ||
      anyDuplicated(x[c("id", "month")]) ||
      !setequal(x$month, 1:12) || !setequal(x$id, ponds$ID)) return(FALSE)
  got = unique(x[c("id", "lon", "lat")])
  got = got[match(ponds$ID, got$id), ]
  all(abs(got$lon - ponds$lon) < 1e-8 & abs(got$lat - ponds$lat) < 1e-8)
}
todo$cache_valid = mapply(paleo_cache_valid, todo$path, todo$var, todo$slice)
cat("TraCE21k: ", sum(!todo$cache_valid), " of ", nrow(todo),
    " chunks to fetch (each = 12 months x 4 ponds)\n", sep = "")

# get_chelsa() swallows errors AND warnings (error = NULL, warning = NULL), so a
# transient network failure comes back as ZERO ROWS rather than an error. Caching
# that would mark the chunk done and never retry it. Only cache a COMPLETE chunk.
incomplete = character(0)

for (i in seq_len(nrow(todo))) {
  if (todo$cache_valid[i]) next
  if (file.exists(todo$path[i])) {
    message("invalidating stale paleo climate chunk: ", basename(todo$path[i]))
    file.remove(todo$path[i])
  }
  x = get_chelsa(ponds, vars = todo$var[i], source = "paleo",
                 start = todo$slice[i], end = todo$slice[i], months = 1:12,
                 to_celsius = TRUE, id_col = "ID", verbose = FALSE)
  if (nrow(x) != EXPECT) {
    incomplete = c(incomplete, todo$key[i])
    cat(sprintf("  [%4d/%4d] %-16s INCOMPLETE %d/%d - not cached, will retry\n",
                i, nrow(todo), todo$key[i], nrow(x), EXPECT))
    next
  }
  tmp = paste0(todo$path[i], ".tmp"); write_csv(x, tmp); file.rename(tmp, todo$path[i])
  cat(sprintf("  [%4d/%4d] %-16s %3d rows\n", i, nrow(todo), todo$key[i], nrow(x)))
}
if (length(incomplete))
  cat("\n", length(incomplete), " chunk(s) came back short and were NOT cached.\n",
      "Re-run to retry them: ", paste(head(incomplete, 8), collapse = ", "), "\n", sep = "")

todo$cache_valid = mapply(paleo_cache_valid, todo$path, todo$var, todo$slice)
got = todo$path[todo$cache_valid]
if (length(got) < nrow(todo))
  stop(nrow(todo) - length(got), " valid chunk(s) missing - re-run to finish the download.")

saveRDS(list(
  signature = object_fingerprint(list(points = ponds, variables = VARS,
                                      slices = SLICES, source = "CHELSA_TraCE21k_V1")),
  points = ponds, variables = VARS, slices = SLICES,
  source = "CHELSA_TraCE21k_V1"
), file.path(CACHE, "_paleo_cache_fingerprint.rds"))

paleo = bind_rows(lapply(got, read_csv, show_col_types = FALSE, progress = FALSE))

# -----------------------------------------------------------------------------
# 2. slice -> age, and check it rather than assuming it
# -----------------------------------------------------------------------------
paleo = paleo %>% mutate(year_CE = slice * 100, cal_BP = 1950 - year_CE)
cat("\nslices ", min(paleo$slice), " to ", max(paleo$slice), " -> cal BP ",
    max(paleo$cal_BP), " to ", min(paleo$cal_BP), "\n", sep = "")
stopifnot(max(paleo$cal_BP) > 10609,   # must cover NOCA's oldest sample
          min(paleo$cal_BP) <= -49)    # must reach the youngest (1999 CE)

# Do the three MORA ponds land in different ~1 km grid cells? They are 1.3-3.8 km
# apart. If the series are identical, "per-lake climate" is fiction and MORA is one
# climate point, which changes the interpretation of the per-lake sensitivity.
cat("\n--- do the 3 MORA ponds differ? (0 spread = same grid cell) ---\n")
print(as.data.frame(paleo %>%
  filter(id %in% c("JayBath", "LogWallow", "ReflectionPond")) %>%
  group_by(variable, slice, month) %>%
  summarise(spread = max(value) - min(value), .groups = "drop") %>%
  group_by(variable) %>%
  summarise(mean_spread = mean(spread), max_spread = max(spread),
            pct_identical = 100 * mean(spread == 0), .groups = "drop")), digits = 3)

# -----------------------------------------------------------------------------
# 3. bias correction against V2.1 (cached the same way)
# -----------------------------------------------------------------------------
if (BIAS_CORRECT) {
  v21_paths = file.path(CACHE, sprintf("v21_%s_%d.csv",
                        rep(VARS, each = length(V21_REF)), rep(V21_REF, length(VARS))))
  pond_points = ponds %>% transmute(id = ID, lon, lat)
  v21_vars = rep(VARS, each = length(V21_REF))
  v21_years = rep(V21_REF, length(VARS))
  v21_valid = mapply(climate_cache_valid, v21_paths,
                     MoreArgs = list(points = pond_points),
                     variable = v21_vars, year = v21_years,
                     expected_source = "v21_monthly")
  cat("\nV2.1 monthly anchor: ", sum(!v21_valid), " of ",
      length(v21_paths), " chunks to fetch\n", sep = "")
  k = 0
  for (v in VARS) for (yr in V21_REF) {
    k = k + 1; p = file.path(CACHE, sprintf("v21_%s_%d.csv", v, yr))
    if (climate_cache_valid(p, pond_points, v, yr,
                            expected_source = "v21_monthly")) next
    if (file.exists(p)) file.remove(p)
    x = get_chelsa_monthly(ponds, vars = v, years = yr, months = 1:12,
                           to_celsius = TRUE, id_col = "ID", verbose = FALSE)
    if (nrow(x) != 12L * nrow(ponds) || anyNA(x$value)) {
      cat(sprintf("  [%3d/%3d] v21_%s_%d INCOMPLETE - not cached\n",
                  k, length(v21_paths), v, yr))
      next
    }
    tmp = paste0(p, ".tmp"); write_csv(x, tmp); file.rename(tmp, p)
    cat(sprintf("  [%3d/%3d] v21_%s_%d\n", k, length(v21_paths), v, yr))
  }

  v21_valid = mapply(climate_cache_valid, v21_paths,
                     MoreArgs = list(points = pond_points),
                     variable = v21_vars, year = v21_years,
                     expected_source = "v21_monthly")
  if (!all(v21_valid))
    stop(sum(!v21_valid), " incomplete V2.1 anchor chunks; rerun to finish.")
  v21 = bind_rows(lapply(v21_paths[v21_valid], read_csv,
                         show_col_types = FALSE, progress = FALSE)) %>%
    group_by(id, variable, month) %>%
    summarise(v21_mean = mean(value, na.rm = TRUE), .groups = "drop")

  bias = paleo %>% filter(slice == SLICE_MODERN) %>%
    select(id, variable, month, trace_slice20 = value) %>%
    inner_join(v21, by = c("id", "variable", "month")) %>%
    mutate(add_offset = ifelse(variable == "pr", NA_real_, trace_slice20 - v21_mean),
           mul_factor = ifelse(variable == "pr" & trace_slice20 > 0,
                               v21_mean / trace_slice20, NA_real_))

  cat("\n--- bias: TraCE21k slice 20 minus V2.1 (degC; pr as ratio) ---\n")
  print(as.data.frame(bias %>% group_by(variable) %>%
    summarise(
      n = n(),
      mean_add = if (all(is.na(add_offset))) NA_real_ else mean(add_offset, na.rm = TRUE),
      min_add = if (all(is.na(add_offset))) NA_real_ else min(add_offset, na.rm = TRUE),
      max_add = if (all(is.na(add_offset))) NA_real_ else max(add_offset, na.rm = TRUE),
      mean_mul = if (all(is.na(mul_factor))) NA_real_ else mean(mul_factor, na.rm = TRUE),
      .groups = "drop"
    )), digits = 3)
  write_csv(bias, OUT_BIAS)

  paleo = paleo %>%
    left_join(bias %>% select(id, variable, month, add_offset, mul_factor),
              by = c("id", "variable", "month")) %>%
    mutate(value_raw = value,
           value_corrected = ifelse(variable == "pr", value * mul_factor,
                                    value - add_offset))

  chk = paleo %>% filter(slice == SLICE_MODERN) %>%
    inner_join(v21, by = c("id", "variable", "month"))
  stopifnot(max(abs(chk$value_corrected - chk$v21_mean), na.rm = TRUE) < 1e-6)
  cat("check: slice 20 now equals the V2.1 reference exactly\n")

} else {
  cat("\n!! BIAS_CORRECT = FALSE - paleo climate is raw TraCE21k, on a different\n",
      "   scale from the V2.1 climate the CCA is calibrated on.\n", sep = "")
  paleo = paleo %>% mutate(value_raw = value, value_corrected = value,
                           add_offset = NA_real_, mul_factor = NA_real_)
}

out = paleo %>%
  left_join(ponds %>% select(id = ID, site), by = "id") %>%
  select(lake = id, site, lon, lat, variable, slice, year_CE, cal_BP, month,
         value_raw, value_corrected, add_offset, mul_factor)

write_csv(out, OUT)
cat("\nwritten: ", OUT, "  (", nrow(out), " rows)\n",
    "Downstream uses value_raw by default; value_corrected is retained for the documented sensitivity run.\n", sep = "")
