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
source(here("R/vendor/get_chelsa.R"), local = TRUE)
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)

CACHE = here("output/mora_climate_parts")
OUT   = here("output/MORA_climate.csv")

plot_years = read_plot_years("MORA")
PAST_START = 1979
PAST_END = 1989
WINDOWS = list(past = PAST_START:PAST_END,
  present = min(plot_years$climate_start):max(plot_years$climate_end))
# The union is fetched once; each plot is subsequently restricted to its own
# six-year window and its preceding December.
WINDOWS_FETCH = lapply(WINDOWS, function(y) c(min(y) - 1L, y))
VARS    = c("tasmin", "tasmax", "pr")
BACKFILL_DAILY_TEMP = FALSE    # 1978 daily temperature is unusable without 1978 pr
V21_MONTHLY_FIRST   = 1979

MORA_occ = read_csv(here("output/MORA_occ.csv"), show_col_types = FALSE)
pts = read_csv(here("output/MORA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = longitude, lat = latitude) %>%
  filter(plot_id %in% MORA_occ$plot_id, !is.na(lon), !is.na(lat)) %>%
  distinct(plot_id, .keep_all = TRUE) %>%
  select(id = plot_id, lon, lat)
stopifnot(nrow(pts) > 0)
cat("MORA: ", nrow(pts), " plots\n", sep = "")

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)

# --- what to fetch, and from which product -----------------------------------
todo = do.call(rbind, lapply(names(WINDOWS), function(p)
  expand.grid(period = p, var = VARS, year = WINDOWS_FETCH[[p]], stringsAsFactors = FALSE)))
todo$route = ifelse(todo$year >= V21_MONTHLY_FIRST, "monthly",
                    ifelse(todo$var == "pr", "unavailable", "daily"))
todo = todo[todo$route != "unavailable", ]          # no V2.1 pr before 1979
if (!BACKFILL_DAILY_TEMP) todo = todo[todo$route != "daily", ]
todo$key  = sprintf("%s_%s_%d", todo$period, todo$var, todo$year)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))
todo$expected_source = ifelse(todo$route == "monthly", "v21_monthly",
                              "v21_daily_agg")
reuse_survey_diagnostic_cache(todo, pts)
todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)

require_offline_cache(todo$path, todo$cache_valid, "MORA climate")
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))
cat(sum(!todo$cache_valid), " of ", nrow(todo), " chunks to fetch (",
    sum(todo$route == "daily"), " are DAILY - ~365 files each)\n", sep = "")

# A transient failure comes back as ZERO ROWS, not an error (the fetchers swallow
# both). Caching that would mark the chunk done forever. Only cache COMPLETE chunks.
# For the daily route a few missing days are tolerable, so the test is on months
# built from >= 28 days rather than on an exact file count.
EXPECT = 12 * nrow(pts)
incomplete = character(0)
short      = character(0)   # chunks the SERVER is missing months for, accepted and recorded

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
    # daily -> monthly mean. Temperature only, so a mean is always right.
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

  # Short chunk: retry once. A transient failure usually clears; a genuine gap in
  # the product does not. CHELSA really is missing tasmin and tasmax for JANUARY
  # 1979 (pr is present) - verified by HTTP HEAD - so this must not loop forever.
  if (!ok && nrow(x) > 0) {
    if (todo$route[i] == "monthly") {
      x2 = get_chelsa_monthly(pts, vars = v, years = yr, months = 1:12,
                              to_celsius = TRUE, id_col = "id", verbose = FALSE)
      if (nrow(x2) > nrow(x)) { x = x2; ok = nrow(x) == EXPECT }
    }
    if (!ok) {
      short = c(short, sprintf("%s (%d/%d months)", todo$key[i],
                               nrow(x) / nrow(pts), 12))
      ok = TRUE     # accept and record: the data is genuinely not there
    }
  }
  if (!ok) {        # zero rows = transient failure. Do NOT cache; retry next run.
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
  cat("\n", length(incomplete), " chunk(s) came back EMPTY and were NOT cached.\n",
      "Re-run to retry: ", paste(incomplete, collapse = ", "), "\n", sep = "")
if (length(short))
  cat("\n⚠ ", length(short), " chunk(s) are MISSING MONTHS on the CHELSA server and were\n",
      "  accepted as-is (re-running will not fix them): ",
      paste(short, collapse = ", "), "\n",
      "  CHELSA has no tasmin/tasmax for JANUARY 1979 - so any winter variable for\n",
      "  1979 is built from 2 months, not 3; the shared seasonal derivation records this.\n", sep = "")

todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)
got = todo$path[todo$cache_valid]
if (length(got) < nrow(todo))
  stop(nrow(todo) - length(got), " chunk(s) missing - re-run to finish.")

clim = bind_rows(lapply(got, read_csv, show_col_types = FALSE, progress = FALSE)) %>%
  mutate(site = "MORA", era = "anthropocene") %>%
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

# --- coverage actually achieved, per period x variable -----------------------
coverage = clim %>% group_by(period, variable) %>%
  summarise(n_years = n_distinct(year), years = paste(range(year), collapse = "-"),
            n = n(), mean = mean(value), .groups = "drop")
cat("\n--- coverage achieved ---\n"); print(as.data.frame(coverage), digits = 4)

pr_past = coverage %>% filter(period == "past", variable == "pr")
if (nrow(pr_past) && pr_past$n_years < length(WINDOWS$past))
  cat("\n⚠ MORA legacy PRECIPITATION covers ", pr_past$n_years, " of ",
      length(WINDOWS$past), " window years (", pr_past$years,
      "). No V2.1 precipitation exists before 1979; see data/SOURCES_SURVEY_YEARS.md.\n",
      sep = "")

# If the historical daily option is restored, be explicit that alignment removes
# it: precipitation has no corresponding pre-1979 month, so the final output is
# still entirely V2.1 monthly and no cross-route splice occurs.
if (BACKFILL_DAILY_TEMP && any(todo$route == "daily")) {
  cat("\nNOTE: daily lead-in temperature was requested, but all-variable alignment\n",
      "removes it because matching precipitation is unavailable.\n", sep = "")
}

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
