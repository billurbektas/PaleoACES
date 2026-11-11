# Compare the actual plot-specific survey windows with V2.1 1979-2021.
# Modern: selected adult Y, six complete season-years Y-5 through Y.
# Legacy: unchanged 1979-1989, with winter 1979 unavailable. Evaluate each
# paired plot's window against its own full-record and detrended series, then
# summarize within survey-year cohorts. This is a representativeness diagnostic,
# not evidence that CHELSA precipitation is homogeneous through time.
library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2); library(patchwork)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
source(here("R/helpers/figure_style.R"), local = TRUE)

CACHE  = out("anomaly_parts")
ALL_YEARS = 1979:2021
VARS   = c("tasmin", "tasmax", "pr")

plot_years = read_plot_years()
paired = read_csv(out("cca_pair_eligibility.csv"), show_col_types = FALSE) %>%
  filter(comparison_included) %>% select(site, plot_id)
plot_years = plot_years %>% semi_join(paired, by = c("site", "plot_id"))
windows = bind_rows(
  plot_years %>% transmute(site, plot_id, period = "past", survey_year = NA_real_,
    climate_start = 1979, climate_end = 1989),
  plot_years %>% transmute(site, plot_id, period = "present",
    survey_year = vegetation_t2_year, climate_start, climate_end))
cohorts = windows %>% count(site, period, survey_year, climate_start, climate_end,
  name = "analyzed_plots")
write_csv(cohorts, out("report/survey_climate_windows.csv"))

mora = read_csv(out("MORA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = longitude, lat = latitude) %>%
  filter(!is.na(lon), !is.na(lat)) %>% distinct(plot_id, .keep_all = TRUE) %>%
  transmute(id = plot_id, lon, lat, site = "MORA")
noca = read_csv(out("NOCA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = Longitude, lat = Latitude) %>%
  filter(!is.na(lon), !is.na(lat)) %>% distinct(plot_id, .keep_all = TRUE) %>%
  transmute(id = plot_id, lon, lat, site = "NOCA")
pts = bind_rows(mora, noca)
cat("points: ", nrow(pts), " (MORA ", nrow(mora), " + NOCA ", nrow(noca), ")\n", sep = "")

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)

todo = expand.grid(var = VARS, year = ALL_YEARS, stringsAsFactors = FALSE)
todo$key  = sprintf("%s_%d", todo$var, todo$year)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))
todo$cache_valid = mapply(
  climate_cache_valid, todo$path,
  variable = todo$var, year = todo$year,
  MoreArgs = list(points = pts, expected_source = "v21_monthly",
                  allow_point_superset = TRUE)
)
require_offline_cache(todo$path, todo$cache_valid, "survey-window climate")
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))
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
  rename(plot_id = unit, site = period, year = time) %>%
  semi_join(paired, by = c("site", "plot_id"))

vars_test = unique(c(CCA_VARIABLES, "MAT", "AP"))

# site-level annual series: mean across plots, per year
series = env %>% group_by(site, year) %>%
  summarise(across(all_of(vars_test), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  pivot_longer(all_of(vars_test), names_to = "variable", values_to = "value") %>%
  filter(!is.nan(value), !is.na(value))

# Per-plot comparisons avoid evaluating a cohort window on plots surveyed in
# different years. All rolling references contain consecutive complete years.
rolling_mean = function(value, year, n) {
  if (length(value) < n) return(numeric())
  vapply(seq_len(length(value) - n + 1L), function(i) {
    j = i:(i + n - 1L)
    if (all(diff(year[j]) == 1L)) mean(value[j]) else NA_real_
  }, numeric(1)) |> stats::na.omit() |> as.numeric()
}
long = env %>% select(site, plot_id, year, all_of(vars_test)) %>%
  pivot_longer(all_of(vars_test), names_to = "variable", values_to = "value") %>%
  filter(is.finite(value))
plot_results = long %>% group_by(site, plot_id, variable) %>%
  group_modify(function(d, k) {
    d = arrange(d, year)
    w = windows %>% filter(site == k$site, plot_id == k$plot_id)
    bind_rows(lapply(seq_len(nrow(w)), function(i) {
      z = w[i, ]; selected = d$year >= z$climate_start & d$year <= z$climate_end
      n = sum(selected)
      expected = if (z$period == "present") 6L else
        if (k$variable %in% c("MWT", "WP", "MAT", "AP")) 10L else 11L
      if (n != expected || any(diff(d$year[selected]) != 1L))
        stop("Incomplete survey-window diagnostic coverage: ", k$plot_id, " ", k$variable)
      wm = mean(d$value[selected]); fit = lm(value ~ year, data = d)
      residual = residuals(fit)
      roll = rolling_mean(d$value, d$year, n)
      roll_res = rolling_mean(residual, d$year, n)
      tibble(period = z$period, survey_year = z$survey_year,
        climate_start = z$climate_start, climate_end = z$climate_end,
        n_yr = n, window_mean = wm,
        z_record = (wm - mean(d$value)) / sd(d$value),
        z_roll = (wm - mean(roll)) / sd(roll), pct_roll = 100 * mean(roll <= wm),
        trend_per_decade = 10 * coef(fit)[["year"]],
        z_detrend = mean(residual[selected]) / sd(roll_res),
        pct_detrend = 100 * mean(roll_res <= mean(residual[selected])))
    }))
  }) %>% ungroup()
res = plot_results %>% group_by(site, period, survey_year, climate_start, climate_end, variable) %>%
  summarise(n_plots = n(), n_yr = unique(n_yr), window_mean = mean(window_mean),
    across(c(z_record, z_roll, pct_roll, trend_per_decade, z_detrend, pct_detrend), median),
    z_detrend_min = min(z_detrend), z_detrend_max = max(z_detrend), .groups = "drop") %>%
  mutate(window = paste(site, period, if_else(is.na(survey_year), "legacy", as.character(survey_year)), sep = "_"))
write_csv(res, out("report/test_survey_year_anomaly.csv"))
write_csv(plot_results, out("report/test_survey_year_anomaly_plot.csv"))
print(res %>% select(site, period, survey_year, variable, n_plots, n_yr, z_detrend), n = 60)

# Annual series use the same paired comparison universe as the window counts.
# Separate bands keep overlapping modern windows individually readable.
p_series = ggplot(series, aes(year, value, colour = site)) +
  geom_rect(data = cohorts %>% filter(period == "past"), inherit.aes = FALSE,
    aes(xmin = climate_start - .5, xmax = climate_end + .5,
      ymin = -Inf, ymax = Inf, fill = site), alpha = .12) +
  geom_line(linewidth = .45) + geom_point(size = .55) +
  facet_grid(variable ~ site, scales = "free_y") +
  scale_colour_manual(values = PAPER_SITE_COLORS, guide = "none") +
  scale_fill_manual(values = PAPER_SITE_COLORS, guide = "none") +
  labs(x = NULL, y = NULL, title = "Climate experienced before and during each resurvey",
    subtitle = "Annual means across analyzed paired plots; CHELSA V2.1 1979–2021. Pale band: unchanged legacy window.") +
  theme_bw(base_size = 10)
bands = cohorts %>% mutate(label = if_else(period == "past", "Legacy",
    paste("Resurvey", survey_year)),
    text = paste0(climate_start, "–", climate_end, "; n = ", analyzed_plots))
p_bands = ggplot(bands, aes(y = label, colour = site)) +
  geom_segment(aes(x = climate_start - .5, xend = climate_end + .5, yend = label),
    linewidth = 6, alpha = .75) +
  geom_text(aes(x = climate_end + 1, label = text), hjust = 0, size = 3.1, colour = "grey15") +
  facet_wrap(~site, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = PAPER_SITE_COLORS, guide = "none") +
  scale_y_discrete(limits = function(x) rev(x)) +
  scale_x_continuous(limits = c(1978, 2037), breaks = c(1980, 1990, 2000, 2010, 2020)) +
  labs(x = "Climate season-year", y = NULL,
    subtitle = "Separate bands: survey year, six climate years and number of analyzed plots. Winter begins with the preceding December.") +
  theme_bw(base_size = 10) + theme(panel.grid.major.y = element_blank())
p = p_series / p_bands + plot_layout(heights = c(3, 1.2))
ggsave(fig("supplementary", "figS07_survey_climate_windows.pdf"), p, width = 13, height = 13)
