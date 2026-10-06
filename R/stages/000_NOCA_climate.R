# =============================================================================
# 000_NOCA_climate.R - CHELSA V2.1 monthly climate for the NOCA survey plots
# =============================================================================
# RESUMABLE. One CSV per (variable, year) is written to output/noca_climate_parts/
# as soon as it lands, and anything already there is skipped. Re-run after an
# interrupt and it continues. Chunks are written to .tmp and renamed, so a kill
# mid-write cannot leave a half-written file that reads back as complete.
#
# Windows (decided 2026-08-13 - see the long rationale in R/stages/000_MORA_climate.R):
#   past    = earliest available -> 1989      = 1979-1989  (IDENTICAL at both sites)
#   present = 2010 -> last vegetation survey  = 2010-2015  (max survey year 2015)
# Survey years from Wilson et al. 2024 ONLY - see data/SOURCES_SURVEY_YEARS.md.
#
# The short version: the previous rule (survey year + the 5 before it) gave MORA
# ONE usable legacy year, because V2.1 has no precipitation before 1979 and
# month-level alignment then pinned temperature to 1979 as well. A single year is
# one draw from a distribution, not a climate. Running from the earliest available
# year to a common 1989 end gives ~10 usable years at BOTH sites and actually
# samples INTERANNUAL VARIABILITY, on the assumption that variability in 1979-1989
# resembles that of the unmeasurable years before 1978.
#
# ⚠ This ABANDONS the antecedent-only rule: 1979-1989 runs 6 yr past NOCA's 1983
# survey. Accepted - the alternative is estimating a site's climate from one year.
#
# COVERAGE: V2.1 monthly starts 1979-01, and there is no V2.1 precipitation at all
# before then, so the window cannot start earlier while precipitation is a CCA
# constraint. The 1978 lead-in December is fetched for temperature (daily product,
# 1941+) but alignment drops it, since precipitation has no 1978 - so winter 1979
# is lost and the record runs 1980-1989, 10 complete winters.
#
# Replaces the NOCA half of the archived 02_get_climate_data.R. climate_summary.csv
# is retired; 05_cca_model.R binds NOCA_climate.csv with MORA_climate.csv the same
# way it already binds NOCA_occ / MORA_occ.
#
# Cost: 11 yr x 3 vars = 33 chunks of 12 files = 396 reads, ~40 min. The number of
# PLOTS does not affect it - each file is read once and extracted at every point.
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)          # vendored; provides .chelsa_prep_coords()
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)

CACHE = here("output/noca_climate_parts")
OUT   = here("output/NOCA_climate.csv")

# past = earliest available -> 1989; present = 2010 -> last survey year.
# PAST_START/PAST_END are deliberately identical to 000_MORA_climate.R: the legacy
# climate must describe the same period at the two sites being differenced.
PAST_START    = 1979     # V2.1 monthly begins 1979-01; no V2.1 pr exists earlier
PAST_END      = 1989
PRESENT_START = 2010
SURVEY_MAX    = 2015     # NOCA last vegetation survey year (Wilson et al. 2024)

WINDOWS = list(past    = PAST_START:PAST_END,
               present = PRESENT_START:SURVEY_MAX)
# Winter Y = Dec(Y-1) + Jan(Y) + Feb(Y), so the first winter of a window needs the
# December BEFORE it. Fetch one extra year at the start and keep only its December,
# otherwise every window yields one fewer winter than summer.
WINDOWS_FETCH = lapply(WINDOWS, function(y) c(min(y) - 1L, y))

VARS  = c("tasmin", "tasmax", "pr")
BACKFILL_DAILY_TEMP = FALSE  # 1978 daily temperature is unusable without 1978 pr
V21_MONTHLY_FIRST   = 1979

cat("windows: ", paste(sapply(names(WINDOWS), function(p)
  sprintf("%s %d-%d", p, min(WINDOWS[[p]]), max(WINDOWS[[p]]))), collapse = " | "), "\n", sep = "")

NOCA_occ = read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE)
pts = read_csv(here("output/NOCA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = Longitude, lat = Latitude) %>%
  filter(plot_id %in% NOCA_occ$plot_id, !is.na(lon), !is.na(lat)) %>%
  distinct(plot_id, .keep_all = TRUE) %>%
  select(id = plot_id, lon, lat)
stopifnot(nrow(pts) > 0)
cat("NOCA: ", nrow(pts), " plots\n", sep = "")

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)

todo = do.call(rbind, lapply(names(WINDOWS), function(p)
  expand.grid(period = p, var = VARS, year = WINDOWS_FETCH[[p]], stringsAsFactors = FALSE)))
# route: monthly where V2.1 monthly exists; daily backfill for pre-1979 temperature;
# pre-1979 precipitation does not exist in V2.1 at all.
todo$route = ifelse(todo$year >= V21_MONTHLY_FIRST, "monthly",
                    ifelse(todo$var == "pr", "unavailable", "daily"))
dropped = todo[todo$route == "unavailable", ]
todo = todo[todo$route != "unavailable", ]
if (!BACKFILL_DAILY_TEMP) todo = todo[todo$route != "daily", ]
todo$key  = sprintf("%s_%s_%d", todo$period, todo$var, todo$year)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))
todo$expected_source = ifelse(todo$route == "monthly", "v21_monthly",
                              "v21_daily_agg")
todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts, allow_point_superset = TRUE),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)
require_offline_cache(todo$path, todo$cache_valid, "NOCA climate")
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))
if (nrow(dropped))
  cat("no V2.1 data at all for: ",
      paste(sprintf("%s %s %d", dropped$period, dropped$var, dropped$year),
            collapse = ", "), "\n", sep = "")
cat(sum(!todo$cache_valid), " of ", nrow(todo), " chunks to fetch (",
    sum(todo$route == "daily"), " are DAILY - ~365 files each)\n", sep = "")

# A transient failure comes back as ZERO ROWS, not an error (the fetchers swallow
# both). Caching that would mark the chunk done forever. Only cache COMPLETE chunks.
EXPECT = 12 * nrow(pts)
incomplete = character(0)

short = character(0)   # months the SERVER is missing - accepted and recorded

for (i in seq_len(nrow(todo))) {
  if (todo$cache_valid[i]) next
  if (file.exists(todo$path[i])) {
    message("invalidating stale climate chunk: ", basename(todo$path[i]))
    file.remove(todo$path[i])
  }
  yr = todo$year[i]; v = todo$var[i]; ok = TRUE

  if (todo$route[i] == "monthly") {
    x = get_chelsa_monthly(pts, vars = v, years = yr, months = 1:12,
                           to_celsius = TRUE, id_col = "id", verbose = FALSE)
    ok = nrow(x) == EXPECT
  } else {
    d = get_chelsa(pts, vars = v, source = "present",
                   start = sprintf("%d-01-01", yr), end = sprintf("%d-12-31", yr),
                   to_celsius = TRUE, id_col = "id", verbose = FALSE)
    if (!nrow(d)) { x = d; ok = FALSE } else {
      x = d %>% group_by(id, lon, lat, variable, year, month) %>%
        summarise(value = mean(value, na.rm = TRUE), n_days = n(), .groups = "drop") %>%
        mutate(source = "v21_daily_agg")
      ok = nrow(x) == EXPECT && all(x$n_days >= 28)
    }
  }

  # short but non-empty = a genuine server gap (e.g. CHELSA has no tasmin/tasmax for
  # January 1979). Retry once, then accept and record rather than looping forever.
  if (!ok && nrow(x) > 0) {
    if (todo$route[i] == "monthly") {
      x2 = get_chelsa_monthly(pts, vars = v, years = yr, months = 1:12,
                              to_celsius = TRUE, id_col = "id", verbose = FALSE)
      if (nrow(x2) > nrow(x)) { x = x2; ok = nrow(x) == EXPECT }
    }
    if (!ok) {
      short = c(short, sprintf("%s (%d/12 months)", todo$key[i], nrow(x) / nrow(pts)))
      ok = TRUE
    }
  }
  if (!ok) {   # empty = transient failure. Do NOT cache; retry next run.
    incomplete = c(incomplete, todo$key[i])
    cat(sprintf("  [%2d/%2d] %-22s EMPTY - not cached, will retry\n",
                i, nrow(todo), todo$key[i]))
    next
  }
  x$period = todo$period[i]
  tmp = paste0(todo$path[i], ".tmp"); write_csv(x, tmp); file.rename(tmp, todo$path[i])
  cat(sprintf("  [%2d/%2d] %-22s %-8s %5d rows\n", i, nrow(todo), todo$key[i],
              todo$route[i], nrow(x)))
}
if (length(incomplete))
  cat("\n", length(incomplete), " chunk(s) came back EMPTY, NOT cached. Re-run: ",
      paste(incomplete, collapse = ", "), "\n", sep = "")
if (length(short))
  cat("\n⚠ ", length(short), " chunk(s) missing months on the server, accepted as-is: ",
      paste(short, collapse = ", "), "\n", sep = "")

todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts, allow_point_superset = TRUE),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)
got = todo$path[todo$cache_valid]
if (length(got) < nrow(todo))
  stop(nrow(todo) - length(got), " chunk(s) missing - re-run to finish.")

clim = bind_rows(lapply(got, read_csv, show_col_types = FALSE, progress = FALSE)) %>%
  filter(id %in% pts$id) %>%
  mutate(site = "NOCA", era = "anthropocene") %>%
  select(site, era, period, plot_id = id, lon, lat, variable, year, month, value)

stopifnot(!any(is.na(clim$value)))

# --- keep only DECEMBER of the lead-in year -----------------------------------
lead_in = data.frame(period = names(WINDOWS),
                     lead_year = sapply(WINDOWS, function(y) min(y) - 1L))
before_lead = nrow(clim)
clim = clim %>% left_join(lead_in, by = "period") %>%
  filter(year != lead_year | month == 12) %>% select(-lead_year)
cat("lead-in year: kept December only, dropped ", before_lead - nrow(clim), " rows\n", sep = "")

# --- ALIGN THE VARIABLES: keep only months present for ALL THREE ---------------
# Decided 2026-08-12. If precipitation does not exist before 1979 then temperature
# must not either, or MWT would describe a different span from WP and
# the two would not be estimates of the same period. The intersection is taken at
# MONTH level, not year, because CHELSA is also missing tasmin/tasmax for January
# 1979 - so that month goes for precipitation too.
avail = clim %>% distinct(period, year, month, variable) %>%
  count(period, year, month, name = "n_var")
keep = avail %>% filter(n_var == length(VARS)) %>% select(period, year, month)
dropped_mo = avail %>% filter(n_var < length(VARS))
before = nrow(clim)
clim = clim %>% semi_join(keep, by = c("period", "year", "month"))
if (nrow(dropped_mo))
  cat("\ndropped ", nrow(dropped_mo), " month(s) not present for all ", length(VARS),
      " variables:\n  ", paste(sprintf("%s %d-%02d", dropped_mo$period, dropped_mo$year,
      dropped_mo$month), collapse = ", "), "\n  (", before - nrow(clim),
      " rows removed so every variable covers the same months)\n", sep = "")

cat("\nrows: ", nrow(clim), "  plots: ", n_distinct(clim$plot_id), "\n", sep = "")
coverage = clim %>% group_by(period, variable) %>%
  summarise(n_years = n_distinct(year),
            n_months = n_distinct(paste(year, month)),
            years = paste(range(year), collapse = "-"),
            n = n(), mean = mean(value), .groups = "drop")
cat("\n--- coverage achieved (past 1979-1989; present 2010-2015; ",
    "lead-in December retained when available) ---\n", sep = "")
print(as.data.frame(coverage), digits = 4)
month_balance = coverage %>% count(period, n_months, name = "n_variables")
if (any(month_balance$n_variables != length(VARS)))
  stop("Climate variables do not cover identical months within a NOCA period.")

write_csv(clim, OUT)
saveRDS(list(
  signature = object_fingerprint(list(points = pts, windows = WINDOWS,
                                      variables = VARS,
                                      backfill_daily_temp = BACKFILL_DAILY_TEMP,
                                      source_routes = todo[c("period", "var", "year", "route")],
                                      client = "CHELSA_V2.1")),
  points = pts, windows = WINDOWS, variables = VARS,
  source_routes = todo[c("period", "var", "year", "route")]
), file.path(CACHE, "_cache_fingerprint.rds"))
cat("\nwritten: ", OUT, "\n", sep = "")
