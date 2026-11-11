# 08 Paleo climate: CHELSA-TraCE21k monthly climate at each lake and century,
# bias-corrected onto CHELSA V2.1 with the factors of R/pipeline/07_climate_products.R
# (Appendix S2), then the climate at each macrofossil sample's own age (paleo_env.csv).
# The download is resumable and cached in output/cache/chelsa_paleo/; an
# --offline run assembles the pond climate from that cache and stops if a chunk is missing.

# =============================================================================
# 1. CHELSA-TraCE21k for the four ponds (cache first; network only for missing chunks)
# =============================================================================
library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)          # vendored, commit 3d410b8
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)

CACHE        = out("chelsa_paleo")
OUT          = out("chelsa_paleo_ponds.csv")

# TraCE21k slice ids: integers -200..20, one step ~100 yr, 20 = present, 0 = 0 CE.
# -90 is ~11 kyr BP, covering NOCA's 10,609 cal BP, so both sites get the SAME
# window - which they never had before (MORA was cut at 6000 BP while its cores
# reach 6841). Slice 21 and 22 are 404: 20 really is the last.
SLICES = -90:20
VARS   = c("tasmin", "tasmax", "pr")

# The four lakes and their coordinates (provenance in R/helpers/config.R).
ponds = PALEO_LAKES

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)

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
      anyNA(x[required]) || !is.numeric(x$value) ||
      !is.numeric(x$lon) || !is.numeric(x$lat) ||
      any(!is.finite(x$value) | !is.finite(x$lon) | !is.finite(x$lat)) ||
      !all(x$source == "paleo") ||
      !all(x$variable == variable) || !all(x$slice == slice) ||
      anyDuplicated(x[c("id", "month")]) ||
      !setequal(x$month, 1:12) || !setequal(x$id, ponds$ID)) return(FALSE)
  got = unique(x[c("id", "lon", "lat")])
  if (anyDuplicated(got$id)) return(FALSE)
  got = got[match(ponds$ID, got$id), ]
  all(abs(got$lon - ponds$lon) < 1e-8 & abs(got$lat - ponds$lat) < 1e-8)
}
todo$cache_valid = mapply(paleo_cache_valid, todo$path, todo$var, todo$slice)
require_offline_cache(todo$path, todo$cache_valid, "TraCE21k climate")
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))   # from a killed run
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
# Each slice at the centre of its century (config.R, trace_slice_cal_bp), and
# year_CE the same centre in calendar years.
paleo = paleo %>% mutate(cal_BP = trace_slice_cal_bp(slice), year_CE = 1950 - cal_BP)
cat("\nslices ", min(paleo$slice), " to ", max(paleo$slice), " -> cal BP ",
    max(paleo$cal_BP), " to ", min(paleo$cal_BP), "\n", sep = "")
# Each slice stands for the 50 years either side of its centre.
stopifnot(max(paleo$cal_BP) + 50 > 10609,   # must cover NOCA's oldest sample
          min(paleo$cal_BP) - 50 <= -49)    # must reach the youngest (1999 CE)

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
# 3. bias correction onto CHELSA V2.1 (Appendix S2, Bills, 11 Nov 2026)
# -----------------------------------------------------------------------------
# Factors per park, calendar month and variable from stage 07, on the 5 km disc
# around the park's lakes: step 1 TraCE21k to CHELSAcruts (1900 to 1990), step 2
# CHELSAcruts to V2.1 (1979 to 2016). Temperature gets the offset added,
# precipitation is multiplied by the ratio, at every slice and for every lake of
# the park. The run's correction (config.R, PALEO_CORRECTION) gives
# value_corrected: both steps in the main run, step 2 alone or none in the
# sensitivity runs. All three series are kept.
factors = read_csv(out("climate_bias_correction_factors.csv"), show_col_types = FALSE)
apply_factor = function(x, f, kind) if_else(kind == "ratio", x * f, x + f)
paleo = paleo %>%
  left_join(ponds %>% select(id = ID, site), by = "id") %>%
  left_join(factors %>% select(site, variable, month, kind, one_step, two_step), by = c("site", "variable", "month")) %>%
  mutate(value_raw = value,
         value_one_step = apply_factor(value, one_step, kind),
         value_two_step = apply_factor(value, two_step, kind),
         value_corrected = switch(PALEO_CORRECTION, two_step = value_two_step, one_step = value_one_step, none = value_raw),
         factor = switch(PALEO_CORRECTION, two_step = two_step, one_step = one_step, none = if_else(kind == "ratio", 1, 0)),
         correction_offset = if_else(kind == "offset", factor, NA_real_),
         correction_ratio = if_else(kind == "ratio", factor, NA_real_))
# Rule: every lake, slice, month and variable has its park's factors.
stopifnot(!anyNA(paleo$two_step), !anyNA(paleo$one_step), !anyNA(paleo$value_corrected))
cat("\nbias correction: ", n_distinct(paleo$id), " lakes x ", n_distinct(paleo$slice), " slices; this run uses ",
    c(two_step = "both steps", one_step = "step 2 alone", none = "no correction")[[PALEO_CORRECTION]], "\n", sep = "")

paleo_out = paleo %>%
  select(lake = id, site, lon, lat, variable, slice, year_CE, cal_BP, month,
         value_raw, value_one_step, value_two_step, value_corrected, correction_offset, correction_ratio)

write_csv(paleo_out, OUT)
cat("\nwritten: ", OUT, "  (", nrow(paleo_out), " rows)\n",
    "value_corrected is the series of this run (", PALEO_CORRECTION, "); value_raw, value_one_step and value_two_step are all kept.\n", sep = "")

# =============================================================================
# 2. Climate at each sample age
# =============================================================================
library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr)})
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)

if (!exists("USE_CORRECTED")) USE_CORRECTED = PALEO_USE_BIAS_CORRECTED

ponds = read_csv(out("chelsa_paleo_ponds.csv"), show_col_types = FALSE)
occ   = read_csv(out("paleo_occ.csv"),          show_col_types = FALSE)

cat("pond series: ", nrow(ponds), " rows | ", n_distinct(ponds$lake), " lakes | slices ",
    min(ponds$slice), " to ", max(ponds$slice), "\n", sep = "")

# --- climate variables, per lake x slice -------------------------------------
env_slice = ponds %>%
  transmute(unit = lake, period = "paleo", variable, time = slice, month,
            value = if (USE_CORRECTED) value_corrected else value_raw) %>%
  derive_climate_vars(winter_shift = FALSE) %>%
  rename(lake = unit, slice = time) %>%
  mutate(slice_age_calBP = trace_slice_cal_bp(slice))

# The winter group of the OLDEST slice has no December from a previous slice and
# the youngest has a December that belongs nowhere - with winter_shift = FALSE
# neither happens, but check the slice set survived intact.
stopifnot(setequal(unique(env_slice$slice), unique(ponds$slice)))
cat("variables built for ", nrow(env_slice), " lake x slice combinations\n", sep = "")

# --- each sample -> the slice covering its age -------------------------------
samples = occ %>% distinct(period,plot_id,site,era,lake) %>%
  left_join(read_csv(out('paleo_sample_depths.csv'),show_col_types=FALSE) %>%
    select(plot_id,age=median_age),by='plot_id',relationship='one-to-one') %>%
  mutate(slice_age_calBP=trace_century_cal_bp(age))
paleo_env = samples %>% left_join(env_slice,by=c('lake','slice_age_calBP')) %>%
  mutate(age_error=slice_age_calBP-age) %>%
  select(period=period.x,plot_id,site,era,lake,age,slice,slice_age_calBP,age_error,
    MAT,MSpT,MST,MWT,AP,SpP,SP,WP,ends_with('_min'),ends_with('_max'),ends_with('_mean'))

# --- checks before writing ---------------------------------------------------
cat("\nsamples: ", nrow(paleo_env), " of ", n_distinct(occ$plot_id), "\n", sep = "")
stopifnot(nrow(paleo_env) == n_distinct(occ$plot_id))

ccavars = CCA_VARIABLES
na_n = sapply(paleo_env[ccavars], function(z) sum(is.na(z)))
cat("NA in the CCA variables: ", paste(sprintf("%s=%d", names(na_n), na_n),
    collapse = " "), "\n", sep = "")

cat("\nage match (assigned slice age minus sample age, yr):\n")
print(as.data.frame(paleo_env %>% group_by(lake) %>%
  summarise(n = n(), min = min(age_error), max = max(age_error),
            n_over_50 = sum(abs(age_error) > 50), .groups = "drop")))

cat("\nCCA variable ranges:\n")
print(as.data.frame(t(sapply(paleo_env[ccavars], range))), digits = 4)

write_csv(paleo_env, out("paleo_env.csv"))
cat("\nwritten: output/paleo_env.csv\n")
