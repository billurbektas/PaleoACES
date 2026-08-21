# =============================================================================
# test_chelsa_cruts_vs_present.R - are CHELSAcruts and CHELSA V2.1 comparable?
# =============================================================================
# The Anthropocene climate is spliced from two CHELSA products, because neither
# covers both survey eras:
#
#   MORA legacy  ~1975  (+/-2 = 1973-1977) -> cruts ONLY   (V2.1 starts 1979)
#   NOCA legacy   1983  (+/-2 = 1981-1985) -> BOTH
#   NOCA present  2014-2015 (+/-2 = 2012-2017) -> BOTH to 2016, V2.1 after
#   MORA present  2014-2019 (+/-2 = 2012-2021) -> BOTH to 2016, V2.1 after
#
# So MORA's legacy end can ONLY come from cruts and MORA's resurvey end can only
# be completed with V2.1. If the two products disagree, that disagreement is
# indistinguishable from real climate change between the surveys - which is the
# whole quantity this study measures. Hence this test.
#
# It compares the RAW extracted values (monthly tmin/tmax/prec), not the derived
# CCA variables, over years where both products exist.
#
# THREE THINGS THAT MAKE THE RAW VALUES NOT DIRECTLY COMPARABLE - handled here:
#
#  1. Different variable names.  cruts = tmin/tmax/prec;  V2.1 = tasmin/tasmax/pr
#  2. Different units.  get_chelsa() converts cruts temperature by /10 and V2.1
#     temperature by -273.15, so both come back in degC. Precipitation is NOT
#     converted for either: cruts prec is mm/MONTH, V2.1 pr is per DAY. They must
#     be aggregated before they can be compared at all.
#  3. Different time steps.  cruts is MONTHLY (one file per month); V2.1 is DAILY
#     (one file per day). A monthly comparison therefore needs ~30 V2.1 files per
#     month per variable, so this script deliberately tests a SUBSET of months.
#
# Run configuration below. Start small - each V2.1 month is ~30 streamed reads
# per variable, so one month x 3 vars x 2 sites is ~180 file reads.
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2)})
source(here("R/get_chelsa.R"))

# --- what to test ------------------------------------------------------------
# Years where both products exist AND that we actually need (NOCA legacy window
# and the shared resurvey window). Months chosen as the two that feed the CCA
# variables: January (MWT/WP), April (MSpT), and July (SP).
TEST_YEARS  = c(1983, 2014)
TEST_MONTHS = c(1, 4, 7)

# Points: the four ponds (paleo splice) plus a sample of survey plots per site.
N_PLOTS_PER_SITE = 5
set.seed(42)

ponds = data.frame(
  id   = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes"),
  lon  = c(-121.7667, -121.7500, -121.7167, -121.0333),
  lat  = c(  46.7667,   46.7667,   46.7667,   48.6500),
  kind = "pond")

mora_pts = read_csv(here("output/MORA_plot_info.csv"), show_col_types = FALSE) %>%
  select(id = plot_id, lon = longitude, lat = latitude) %>%
  filter(!is.na(lon), !is.na(lat)) %>% distinct(id, .keep_all = TRUE) %>%
  slice_sample(n = N_PLOTS_PER_SITE) %>% mutate(kind = "MORA_plot")

noca_pts = read_csv(here("output/NOCA_plot_info.csv"), show_col_types = FALSE) %>%
  select(id = plot_id, lon = Longitude, lat = Latitude) %>%
  filter(!is.na(lon), !is.na(lat)) %>% distinct(id, .keep_all = TRUE) %>%
  slice_sample(n = N_PLOTS_PER_SITE) %>% mutate(kind = "NOCA_plot")

pts = bind_rows(ponds, mora_pts, noca_pts)
cat("Testing at", nrow(pts), "points:",
    paste(names(table(pts$kind)), table(pts$kind), collapse = ", "), "\n\n")

# --- pull cruts (monthly) ----------------------------------------------------
# NOTE: get_chelsa(source="cruts") builds the FULL year RANGE between start and
# end, so start=1983/end=2014 would fetch 32 years. Call it once per year.
cruts = bind_rows(lapply(TEST_YEARS, function(yr)
  get_chelsa(pts, vars = c("tmin", "tmax", "prec"), source = "cruts",
             start = yr, end = yr, months = TEST_MONTHS, to_celsius = TRUE,
             id_col = "id", verbose = TRUE))) %>%
  mutate(var = recode(variable, tmin = "tmin", tmax = "tmax", prec = "precip"))

# --- pull V2.1 daily, one month at a time, and aggregate to monthly ----------
# Temperature -> monthly MEAN of the daily values.
# Precipitation -> monthly SUM of the daily values.
v21_list = list()
for (yr in TEST_YEARS) for (mo in TEST_MONTHS) {
  d0 = as.Date(sprintf("%d-%02d-01", yr, mo))
  d1 = seq(d0, by = "month", length.out = 2)[2] - 1
  cat(sprintf("\n--- CHELSA V2.1 daily: %s to %s ---\n", d0, d1))
  v21_list[[length(v21_list) + 1]] =
    get_chelsa(pts, vars = c("tasmin", "tasmax", "pr"), source = "present",
               start = d0, end = d1, to_celsius = TRUE,
               id_col = "id", verbose = TRUE)
}
v21_daily = bind_rows(v21_list)

v21 = v21_daily %>%
  mutate(var = recode(variable, tasmin = "tmin", tasmax = "tmax", pr = "precip")) %>%
  group_by(id, lon, lat, var, year, month) %>%
  summarise(monthly_mean = mean(value, na.rm = TRUE),
            monthly_sum  = sum(value,  na.rm = TRUE),
            n_days = n(), .groups = "drop") %>%
  mutate(value = ifelse(var == "precip", monthly_sum, monthly_mean))

# --- join and compare --------------------------------------------------------
cmp = cruts %>%
  select(id, var, year, month, cruts = value) %>%
  inner_join(v21 %>% select(id, var, year, month, v21 = value, n_days),
             by = c("id", "var", "year", "month")) %>%
  left_join(pts %>% select(id, kind), by = "id") %>%
  mutate(diff = v21 - cruts)

cat("\n\n================ RAW VALUE COMPARISON ================\n")
cmp %>%
  group_by(var, year, month) %>%
  summarise(n = n(),
            mean_cruts = mean(cruts), mean_v21 = mean(v21),
            mean_diff  = mean(diff),  sd_diff = sd(diff),
            max_abs_diff = max(abs(diff)),
            r = if (n() > 2) cor(cruts, v21) else NA_real_,
            .groups = "drop") %>%
  as.data.frame() %>% print(digits = 4)

cat("\nPer point-type:\n")
cmp %>% group_by(var, kind) %>%
  summarise(n = n(), mean_diff = mean(diff), max_abs_diff = max(abs(diff)),
            .groups = "drop") %>% as.data.frame() %>% print(digits = 4)

write_csv(cmp, here("output/test_chelsa_cruts_vs_present.csv"))

# --- figure ------------------------------------------------------------------
p = ggplot(cmp, aes(cruts, v21, colour = kind, shape = factor(year))) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey40") +
  geom_point(size = 2.4, alpha = 0.85) +
  facet_wrap(~ var, scales = "free") +
  labs(x = "CHELSAcruts (monthly)", y = "CHELSA V2.1 (daily, aggregated)",
       colour = NULL, shape = "year",
       title = "Are the two CHELSA products comparable?",
       subtitle = paste0("Raw monthly values, months ",
                         paste(TEST_MONTHS, collapse = " & "), ", years ",
                         paste(TEST_YEARS, collapse = " & "),
                         ". Temperature degC; precipitation mm/month",
                         " (cruts native, V2.1 summed from daily).")) +
  theme_bw() + theme(legend.position = "bottom")

ggsave(here("plot/test_figures/test_chelsa_cruts_vs_present.pdf"), p, width = 11, height = 4.5)
cat("\nwritten: plot/test_figures/test_chelsa_cruts_vs_present.pdf\n")
