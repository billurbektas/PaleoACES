# =============================================================================
# 000_MORA_climate.R - CHELSA V2.1 climate for the MORA survey plots
# =============================================================================
# RESUMABLE, exactly like 000_NOCA_climate.R: one CSV per (variable, year) in
# output/mora_climate_parts/, written as it lands, existing chunks skipped, .tmp +
# rename so a kill mid-write cannot leave a half-written file.
#
# Windows (decided 2026-08-13 - full rationale at the WINDOWS block below):
#   past    = earliest available -> 1989      = 1979-1989   (IDENTICAL at both sites)
#   present = 2010 -> last vegetation survey  = 2010-2019
# Survey years from the Agostina Torres draft - see data/SOURCES_SURVEY_YEARS.md.
#
# V2.1 MONTHLY starts 1979-01 and there is NO V2.1 precipitation before then, so
# 1979 is the earliest the window can start while precipitation is a constraint:
#   1979-1989   tasmin, tasmax, pr   -> V2.1 monthly
#   pre-1979    tasmin, tasmax       -> V2.1 DAILY (1941+), aggregated to monthly
#   pre-1979    pr                   -> NOTHING.
#
# ⚠ The 1978 lead-in December is fetched for temperature but month-level alignment
# drops it (no 1978 precipitation), so winter 1979 is lost and the winter record
# runs 1980-1989 - 10 complete winters, against 1 under the old window. Do NOT
# patch the pre-1979 precipitation gap with cruts: the two products are not
# interchangeable for precipitation (V2.1 +69-74% wetter in July, r only 0.59-0.81
# across plots vs 0.96-0.99 for temperature - R/diagnostics/test_chelsa_cruts_vs_present.R).
#
# Cost: ~20 yr x 3 vars = 60 monthly chunks of 12 files. A historical backfill
# option can add the 1978 lead-in as daily tasmin/tasmax, but those months cannot
# survive the all-variable intersection because 1978 precipitation does not
# exist. All chunks are cached per
# (variable, year), so re-running after a window change only fetches what is new.
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)

CACHE = here("output/mora_climate_parts")
OUT   = here("output/MORA_climate.csv")

# =============================================================================
# THE CLIMATE WINDOWS  (decided 2026-08-13, supersedes the "max survey year and
# the 5 before it" rule, which itself superseded +/-2 yr)
# =============================================================================
#   past    = the EARLIEST year the data exist  ->  1989
#   present = 2010  ->  the LAST vegetation survey year at this site
#
# WHY. The previous rule anchored a 6-yr window to each survey. For MORA that
# left ONE usable legacy year: V2.1 has no precipitation before 1979, month-level
# alignment therefore pinned temperature to 1979 too, and the missing Jan 1979
# killed winter 1979. A single year is not a climate - it is one draw from a
# distribution, and 1980 happened to be a wet, cool one, which distorted MORA's
# whole Anthropocene signal (verified: MWT warming read +0.84 degC on one year vs
# +0.28 on five - see R/diagnostics/test_climate_change_variables.R).
#
# Taking everything available up to a common 1989 end instead gives ~10 usable
# years at BOTH sites, so the legacy climate is an estimate of a climate rather
# than of a year, and INTERANNUAL VARIABILITY is actually sampled. The working
# assumption is that interannual variability in 1979-1989 resembles that of the
# years before 1978, which we cannot measure - that assumption is the price, and
# it is a far smaller one than estimating a site's climate from a single year.
#
# The present window starts at a fixed 2010 for the same reason - enough years to
# average over - and ends at the last vegetation survey year so the climate never
# post-dates the vegetation it is paired with.
#
# ⚠ TRADE-OFFS, both accepted in data/SOURCES_SURVEY_YEARS.md:
#  1. This ABANDONS "antecedent-only". The 1979-1989 window extends 9 yr past
#     MORA's 1980 survey and 6 yr past NOCA's 1983 one, so it includes years that
#     cannot have influenced the vegetation recorded. Accepted because the
#     alternative is a one-year climate.
#  2. The two sites' PRESENT windows now differ in length (MORA 2010-2019 = 10 yr,
#     NOCA 2010-2015 = 6 yr) because each is anchored to its own last survey year.
#     The PAST window is now IDENTICAL at both sites (1979-1989), which is a gain:
#     the legacy climate is the same period at the two sites being differenced.
#
# PAST_START is "earliest available" = 1979: V2.1 monthly begins 1979-01, and
# V2.1 has NO precipitation at all before then, so month-level alignment ties
# every variable to 1979 while precipitation is a constraint. If a sensitivity drops
# precipitation, temperature alone could reach back to 1941 via the daily
# product - see BACKFILL_DAILY_TEMP.
PAST_START    = 1979
PAST_END      = 1989
PRESENT_START = 2010
SURVEY_MAX    = 2019     # MORA last vegetation survey year (Agostina Torres draft)

WINDOWS = list(past    = PAST_START:PAST_END,
               present = PRESENT_START:SURVEY_MAX)
# Winter Y = Dec(Y-1) + Jan(Y) + Feb(Y), so the first winter of a window needs the
# December BEFORE it. Fetch one extra year at the start and keep only its December,
# otherwise every window yields one fewer winter than summer.
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
                                      variables = VARS,
                                      backfill_daily_temp = BACKFILL_DAILY_TEMP,
                                      source_routes = todo[c("period", "var", "year", "route")],
                                      client = "CHELSA_V2.1")),
  points = pts, windows = WINDOWS, variables = VARS,
  source_routes = todo[c("period", "var", "year", "route")]
), file.path(CACHE, "_cache_fingerprint.rds"))
cat("\nwritten: ", OUT, "\n", sep = "")
