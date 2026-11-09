# CHELSA V2.1 for paired survey plots. Decision 2026-10-07:
# legacy climate remains 1979-1989; each modern plot uses adult year Y-5 through
# Y inclusive (six season-years). Winter Y includes December Y-1. Adult dates
# and windows come from the same table used in cleaning and tracking.
# Native chunks remain resumable and coordinate/source validated. Missing chunks
# may be restored from the validated full-record diagnostic cache before the
# offline guard; an invalid existing chunk still fails before any download.
# Historical January 1979 temperature and pre-1979 precipitation are unavailable:
# retain the established 10 complete legacy winters and 11 springs/summers.
# Full rationale and source evidence: data/SOURCES_SURVEY_YEARS.md.

library(here)
suppressMessages({library(dplyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)          # vendored; provides .chelsa_prep_coords()
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)

CACHE = out("noca_climate_parts")
OUT   = out("NOCA_climate.csv")

plot_years = read_plot_years("NOCA")
PAST_START = 1979
PAST_END = 1989
WINDOWS = list(past = PAST_START:PAST_END,
  present = min(plot_years$climate_start):max(plot_years$climate_end))
# The union is fetched once; each plot is subsequently restricted to its own
# six-year window and its preceding December.
WINDOWS_FETCH = lapply(WINDOWS, function(y) c(min(y) - 1L, y))

VARS  = c("tasmin", "tasmax", "pr")
BACKFILL_DAILY_TEMP = FALSE  # 1978 daily temperature is unusable without 1978 pr
V21_MONTHLY_FIRST   = 1979

cat("windows: ", paste(sapply(names(WINDOWS), function(p)
  sprintf("%s %d-%d", p, min(WINDOWS[[p]]), max(WINDOWS[[p]]))), collapse = " | "), "\n", sep = "")

NOCA_occ = read_csv(out("NOCA_occ.csv"), show_col_types = FALSE)
pts = read_csv(out("NOCA_plot_info.csv"), show_col_types = FALSE) %>%
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
reuse_survey_diagnostic_cache(todo, pts)
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

# Preserve the historical all-variable intersection; modern coverage is strict
# for every plot, including December preceding that plot's first winter.
clim = restrict_modern_months(clim, plot_years)
avail = clim %>% distinct(plot_id, period, year, month, variable) %>%
  count(plot_id, period, year, month, name = "n_var")
keep = avail %>% filter(n_var == length(VARS)) %>% select(plot_id, period, year, month)
clim = clim %>% semi_join(keep, by = c("plot_id", "period", "year", "month"))
clim = restrict_modern_months(clim, plot_years)

cat("\nrows: ", nrow(clim), "  plots: ", n_distinct(clim$plot_id), "\n", sep = "")
coverage = clim %>% group_by(period, variable) %>%
  summarise(n_years = n_distinct(year),
            n_months = n_distinct(paste(year, month)),
            years = paste(range(year), collapse = "-"),
            n = n(), mean = mean(value), .groups = "drop")
cat("\n--- coverage achieved (past 1979-1989; present plot-specific six-year windows; ",
    "lead-in December retained when available) ---\n", sep = "")
print(as.data.frame(coverage), digits = 4)
month_balance = coverage %>% count(period, n_months, name = "n_variables")
if (any(month_balance$n_variables != length(VARS)))
  stop("Climate variables do not cover identical months within a NOCA period.")

write_csv(clim, OUT)
saveRDS(list(
  signature = object_fingerprint(list(points = pts, windows = WINDOWS,
                                      plot_years = plot_years,
                                      variables = VARS,
                                      backfill_daily_temp = BACKFILL_DAILY_TEMP,
                                      source_routes = todo[c("period", "var", "year", "route")],
                                      client = "CHELSA_V2.1")),
  points = pts, windows = WINDOWS, plot_years = plot_years, variables = VARS,
  source_routes = todo[c("period", "var", "year", "route")]
), file.path(CACHE, "_cache_fingerprint.rds"))
cat("\nwritten: ", OUT, "\n", sep = "")
