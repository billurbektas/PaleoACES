# =============================================================================
# test_survey_year_anomaly.R - were the survey years climatically unusual?
# =============================================================================
# The analysis characterises each survey by a climate window. If those years happened
# to be anomalous - a run of drought, a warm spell - then the "climate the vegetation
# experienced" is not the site's climate, and any lag inferred from it partly reflects
# window choice rather than ecology.
#
# ⚠ WINDOWS UPDATED 2026-08-13 to match the download scripts:
#     past    1979-1989  at BOTH sites (earliest available -> a common 1989 end)
#     present 2010-2019 MORA / 2010-2015 NOCA (2010 -> last vegetation survey year)
#
# This test is much LESS load-bearing than it was. It existed because MORA legacy
# rested on 1979-1980 - effectively one complete year after alignment - and a single
# year sits wherever it happens to sit in the distribution. The legacy windows are now
# ~10 yr at both sites, so they average over interannual variability by construction
# and cannot be badly unrepresentative. The test is kept because the PRESENT windows
# are still short (6 yr at NOCA) and because the answer for the old windows is part of
# the record - see data/SOURCES_SURVEY_YEARS.md.
#
# METHOD. Download the FULL V2.1 monthly record (1979-2021) at every MORA and NOCA
# plot, build the same variables through the SAME R/climate_variables.R, then locate
# each survey window's mean in the full-record distribution - z-score and percentile.
#
# COST ~1,548 files, ~2.5 h. Both sites go in ONE download: a CHELSA file is read
# once and extracted at all current plots, so splitting by site would double the time
# for no benefit. Resumable, one chunk per (variable, year).
#
# ⚠ The full record starts in 1979, the same year the legacy windows do. So the
# legacy windows are being compared against a distribution they sit at the very
# start of, and pre-1979 climate is invisible to this test. It answers "unusual
# relative to 1979-2021", not "unusual relative to the Holocene".
#
# Writes output/test_survey_year_anomaly.csv and plot/test_figures/.
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2)})
source(here("R/get_chelsa.R"))
source(here("R/get_chelsa_monthly.R"))
source(here("R/climate_variables.R"))
source(here("R/config.R"))

CACHE  = here("output/anomaly_parts")
ALL_YEARS = 1979:2021
VARS   = c("tasmin", "tasmax", "pr")

# The windows under test - MUST match R/000_MORA_climate.R and R/000_NOCA_climate.R.
# past is identical at the two sites by design; present is anchored to each site's
# own last vegetation survey year, so the two present windows differ in length.
WINDOWS = list(
  MORA_past    = 1979:1989,
  MORA_present = 2010:2019,
  NOCA_past    = 1979:1989,
  NOCA_present = 2010:2015)

mora = read_csv(here("output/MORA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = longitude, lat = latitude) %>%
  filter(!is.na(lon), !is.na(lat)) %>% distinct(plot_id, .keep_all = TRUE) %>%
  transmute(id = plot_id, lon, lat, site = "MORA")
noca = read_csv(here("output/NOCA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = Longitude, lat = Latitude) %>%
  filter(!is.na(lon), !is.na(lat)) %>% distinct(plot_id, .keep_all = TRUE) %>%
  transmute(id = plot_id, lon, lat, site = "NOCA")
pts = bind_rows(mora, noca)
cat("points: ", nrow(pts), " (MORA ", nrow(mora), " + NOCA ", nrow(noca), ")\n", sep = "")

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))

todo = expand.grid(var = VARS, year = ALL_YEARS, stringsAsFactors = FALSE)
todo$key  = sprintf("%s_%d", todo$var, todo$year)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))
todo$cache_valid = mapply(
  climate_cache_valid, todo$path,
  variable = todo$var, year = todo$year,
  MoreArgs = list(points = pts, expected_source = "v21_monthly",
                  allow_point_superset = TRUE)
)
cat(sum(!todo$cache_valid), " of ", nrow(todo), " chunks to fetch\n", sep = "")

EXPECT = 12 * nrow(pts)
for (i in seq_len(nrow(todo))) {
  if (todo$cache_valid[i]) next
  if (file.exists(todo$path[i])) file.remove(todo$path[i])
  x = get_chelsa_monthly(pts, vars = todo$var[i], years = todo$year[i], months = 1:12,
                         to_celsius = TRUE, id_col = "id", verbose = FALSE)
  if (!nrow(x)) { cat(sprintf("  [%3d/%3d] %-14s EMPTY - will retry\n", i, nrow(todo), todo$key[i])); next }
  tmp = paste0(todo$path[i], ".tmp"); write_csv(x, tmp); file.rename(tmp, todo$path[i])
  cat(sprintf("  [%3d/%3d] %-14s %5d rows%s\n", i, nrow(todo), todo$key[i], nrow(x),
              ifelse(nrow(x) < EXPECT, "  (short - server gap)", "")))
}

todo$cache_valid = mapply(
  climate_cache_valid, todo$path,
  variable = todo$var, year = todo$year,
  MoreArgs = list(points = pts, expected_source = "v21_monthly",
                  allow_point_superset = TRUE)
)
got = todo$path[todo$cache_valid]
if (length(got) < nrow(todo)) stop(nrow(todo) - length(got), " valid chunk(s) missing - re-run.")

clim = bind_rows(lapply(got, read_csv, show_col_types = FALSE, progress = FALSE)) %>%
  filter(id %in% pts$id) %>%
  left_join(pts %>% select(id, site), by = "id")

# --- same variables, same function, same completeness rule -------------------
env = clim %>%
  transmute(unit = id, period = site, variable, time = year, month, value) %>%
  derive_climate_vars(winter_shift = TRUE) %>%
  rename(plot_id = unit, site = period, year = time)

vars_test = unique(c(CCA_VARIABLES, "MAT", "AP"))

# site-level annual series: mean across plots, per year
series = env %>% group_by(site, year) %>%
  summarise(across(all_of(vars_test), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  pivot_longer(all_of(vars_test), names_to = "variable", values_to = "value") %>%
  filter(!is.nan(value), !is.na(value))

# --- where does each window sit? THREE comparisons, not one ------------------
# 1. vs the whole record        - naive, and CONFOUNDED BY THE WARMING TREND: an
#    early window looks "cool" partly because it IS early in a warming record,
#    which is not the same as being unusual.
# 2. vs all rolling windows OF THE SAME LENGTH - like for like. A short window has a
#    wider sampling distribution than a long one, so comparing a 6-yr window to a
#    43-yr mean overstates how extreme it is. This matters most for NOCA present
#    (6 yr); the 11-yr legacy windows are close to the record mean by construction.
# 3. vs the DETRENDED series - removes the linear trend first, so this answers
#    "unusual FOR ITS OWN TIME", which is the question that actually matters.
rolling_mean = function(v, n) if (n >= length(v)) mean(v) else
  sapply(seq_len(length(v) - n + 1), function(i) mean(v[i:(i + n - 1)]))

res = bind_rows(lapply(names(WINDOWS), function(w) {
  s = sub("_.*", "", w); yrs = WINDOWS[[w]]
  series %>% filter(site == s) %>% group_by(variable) %>%
    group_modify(function(d, k) {
      d   = arrange(d, year)
      inw = d$year %in% yrs
      n   = sum(inw)
      if (n == 0) return(tibble())
      wm  = mean(d$value[inw])

      # 3. detrend on year, then compare the window's mean RESIDUAL
      fit  = lm(value ~ year, data = d)
      res_ = residuals(fit)
      wr   = mean(res_[inw])
      roll_res = rolling_mean(res_, n)

      tibble(window = w, n_yr = n,
             window_mean = wm,
             # 1. naive
             z_record   = (wm - mean(d$value)) / sd(d$value),
             # 2. like-for-like: same-length rolling windows
             z_roll     = (wm - mean(rolling_mean(d$value, n))) / sd(rolling_mean(d$value, n)),
             pct_roll   = 100 * mean(rolling_mean(d$value, n) <= wm),
             # 3. detrended - "unusual for its own time"
             trend_per_decade = 10 * coef(fit)[["year"]],
             z_detrend  = wr / sd(roll_res),
             pct_detrend = 100 * mean(roll_res <= wr))
    }) %>% ungroup()
}))

cat("\n=== 1. NAIVE: window vs the whole 1979-2021 mean (trend-confounded) ===\n")
print(as.data.frame(res %>% select(window, variable, n_yr, window_mean, z_record)), digits = 3)

cat("\n=== 2. LIKE-FOR-LIKE: vs all rolling windows of the SAME length ===\n")
print(as.data.frame(res %>% select(window, variable, n_yr, z_roll, pct_roll)), digits = 3)

cat("\n=== 3. DETRENDED: unusual FOR ITS OWN TIME (this is the one that counts) ===\n")
print(as.data.frame(res %>% select(window, variable, n_yr, trend_per_decade,
                                   z_detrend, pct_detrend)), digits = 3)

cat("\n--- does the naive view overstate things? z_record vs z_detrend ---\n")
print(as.data.frame(res %>%
  mutate(shrunk_by = abs(z_record) - abs(z_detrend)) %>%
  arrange(desc(abs(z_record))) %>%
  select(window, variable, z_record, z_roll, z_detrend, shrunk_by) %>% head(10)), digits = 3)

cat("\n|z_detrend| > 1 = genuinely unusual for its era:\n")
flag = res %>% filter(abs(z_detrend) > 1) %>% arrange(desc(abs(z_detrend)))
if (nrow(flag)) {
  print(as.data.frame(flag %>% select(window, variable, n_yr, z_detrend, pct_detrend)), digits = 3)
} else {
  cat("  none - once the trend is removed, no window is more than 1 SD from normal\n")
}

write_csv(res, here("output/test_survey_year_anomaly.csv"))

# --- figure: full series with the windows marked -----------------------------
wdf = bind_rows(lapply(names(WINDOWS), function(w) data.frame(
  window = w, site = sub("_.*", "", w),
  xmin = min(WINDOWS[[w]]) - 0.5, xmax = max(WINDOWS[[w]]) + 0.5)))

p = ggplot(series, aes(year, value)) +
  geom_rect(data = wdf, inherit.aes = FALSE,
            aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = window),
            alpha = 0.22) +
  geom_line(linewidth = 0.4, colour = "grey30") +
  geom_point(size = 0.7, colour = "grey30") +
  facet_grid(variable ~ site, scales = "free_y") +
  labs(x = NULL, y = NULL, fill = "survey window",
       title = "Were the survey years climatically unusual?",
       subtitle = "Plot-mean climate per year, CHELSA V2.1 1979-2021; shaded = the windows used in the analysis") +
  theme_bw(base_size = 10) + theme(legend.position = "bottom")

ggsave(here("plot/test_figures/test_survey_year_anomaly.pdf"), p, width = 10, height = 11)
cat("\nwritten: output/test_survey_year_anomaly.csv + plot/test_figures/\n")
