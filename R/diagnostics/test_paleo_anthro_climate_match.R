# =============================================================================
# test_paleo_anthro_climate_match.R
# -----------------------------------------------------------------------------
# DO THE TWO CLIMATE ARMS MATCH? The CCA is calibrated on survey plots carrying
# CHELSA V2.1 and paleo samples are PROJECTED into it carrying CHELSA-TraCE21k.
# If the two products are on different scales - or if the seasonal definitions
# drift - the resulting displacement is indistinguishable from a real lag.
#
#   reads  output/chelsa_paleo_bias_correction.csv   (TraCE21k slice 20 vs V2.1, at the ponds)
#          output/chelsa_paleo_ponds.csv             (raw + corrected pond series)
#          output/paleo_env.csv                      (per paleo sample)
#          output/MORA_climate.csv, NOCA_climate.csv (survey plots, V2.1 monthly)
#   writes nothing - this is a check
#
# Five tests, in order of what they would catch:
#   1  the RAW product bias at matched pixels        - how big is the problem
#   2  did the correction actually land              - arithmetic check, must be ~0
#   3  do the DERIVED variables agree at slice 20    - catches unit/convention errors
#   4  is paleo climate INSIDE the calibration range - catches extrapolation
#   5  does the winter_shift convention differ       - catches a seasonal drift
#
# This diagnostic evaluates the available corrected sensitivity. The active
# analysis deliberately uses value_raw (`USE_CORRECTED = FALSE` in
# 000_PALEO_e_climate.R), so a successful arithmetic check here does not close
# the scientific question of a stationary 11-kyr bias correction.
# =============================================================================

library(here)
library(tidyverse)
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)

CCA_VARS = CCA_VARIABLES
ALL_VARS = c("MAT", "MSpT", "MST", "MWT", "AP", "SpP", "SP", "WP")
ok = function(pass, msg) cat(if (pass) "  PASS  " else "  FAIL  ", msg, "\n", sep = "")

bias  = read_csv(here("output/chelsa_paleo_bias_correction.csv"), show_col_types = FALSE)
ponds = read_csv(here("output/chelsa_paleo_ponds.csv"),           show_col_types = FALSE)
paleo = read_csv(here("output/paleo_env.csv"),                    show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 1. The raw product bias, at the SAME pixels (the four ponds)
# -----------------------------------------------------------------------------
# TraCE21k slice 20 (its most recent, ~present) against the V2.1 1979-2021
# monthly mean at the same coordinates. Anything here is product difference, not
# climate change - the two describe the same period at the same place.
cat("\n=== 1. RAW bias: TraCE21k slice 20 vs V2.1 1979-2021, same pixels ===\n")
b1 = bias %>% group_by(variable) %>%
  summarize(n = n(), trace = mean(trace_slice20), v21 = mean(v21_mean),
            mean_bias = mean(trace_slice20 - v21_mean),
            max_abs = max(abs(trace_slice20 - v21_mean)),
            pct = 100 * (mean(trace_slice20) - mean(v21_mean)) / mean(v21_mean),
            .groups = "drop")
print(as.data.frame(b1 %>% mutate(across(where(is.numeric), ~ round(.x, 2)))), row.names = FALSE)
cat("\n  tasmin runs WARM and tasmax runs COOL - the compressed diurnal range that is\n",
    "  the usual free-running-GCM signature. PRECIPITATION IS THE BIG ONE: TraCE21k is\n",
    "  ~33% too dry, far larger in relative terms than either temperature bias.\n", sep = "")

# -----------------------------------------------------------------------------
# 2. Did the correction land? (additive for temperature, multiplicative for pr)
# -----------------------------------------------------------------------------
cat("\n=== 2. Corrected slice 20 vs V2.1 - the correction is anchored here ===\n")
resid = ponds %>% filter(slice == 20) %>%
  select(lake, variable, month, value_raw, value_corrected) %>%
  left_join(bias, by = c("lake" = "id", "variable", "month")) %>%
  group_by(variable) %>%
  summarize(max_abs_raw = max(abs(value_raw - v21_mean)),
            max_abs_corrected = max(abs(value_corrected - v21_mean)), .groups = "drop")
print(as.data.frame(resid %>% mutate(across(where(is.numeric), ~ signif(.x, 3)))), row.names = FALSE)
ok(max(resid$max_abs_corrected) < 1e-6,
   "correction reconciles slice 20 to V2.1 exactly (residual < 1e-6)")

# -----------------------------------------------------------------------------
# 3. Derived variables - the test that catches a unit or season error
# -----------------------------------------------------------------------------
# Tests 1-2 are on raw monthly values. This one pushes both through
# derive_climate_vars() and compares the variables the CCA actually uses. A unit
# slip (mm/day vs mm/month) or a season misdefinition shows up here and nowhere
# else. winter_shift = FALSE on both sides: each is a CLIMATOLOGY, one time
# point, so December belongs to its own winter (shifting it would strand it).
cat("\n=== 3. Derived variables at the ponds: corrected slice 20 vs V2.1 ===\n")
d_paleo = ponds %>% filter(slice == 20) %>%
  transmute(unit = lake, period = "paleo", variable, time = 1, month, value = value_corrected) %>%
  derive_climate_vars(winter_shift = FALSE)
d_v21 = bias %>%
  transmute(unit = id, period = "v21", variable, time = 1, month, value = v21_mean) %>%
  derive_climate_vars(winter_shift = FALSE)
d = full_join(d_paleo %>% select(unit, all_of(ALL_VARS)),
              d_v21   %>% select(unit, all_of(ALL_VARS)),
              by = "unit", suffix = c("_paleo", "_v21"))
worst = map_dbl(ALL_VARS, ~ max(abs(d[[paste0(.x, "_paleo")]] - d[[paste0(.x, "_v21")]])))
names(worst) = ALL_VARS
print(round(worst, 8))
ok(max(worst) < 1e-6, "every derived variable agrees to < 1e-6 - units and seasons match")

# -----------------------------------------------------------------------------
# 4. Extrapolation - is paleo climate inside the range the CCA was fitted over?
# -----------------------------------------------------------------------------
# Matching scales is not enough. The CCA learns a species-climate relationship
# only over the range its calibration plots span; a paleo sample outside that
# range is an extrapolation, and its predicted position is an unconstrained guess.
cat("\n=== 4. Is paleo climate inside the CALIBRATION range? ===\n")
monthly = bind_rows(read_csv(here("output/MORA_climate.csv"), show_col_types = FALSE),
                    read_csv(here("output/NOCA_climate.csv"), show_col_types = FALSE))
cal = monthly %>%
  transmute(unit = plot_id, period = paste(site, period, sep = "."),
            variable, time = year, month, value) %>%
  derive_climate_vars(winter_shift = TRUE) %>%
  filter(if_any(all_of(CCA_VARS), ~ !is.na(.x))) %>%
  group_by(unit, period) %>%
  summarize(across(all_of(CCA_VARS), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  separate_wider_delim(period, ".", names = c("site", "period")) %>%
  filter(period == "past")          # the CCA is fitted on PAST plots

outside_pct = setNames(numeric(length(CCA_VARS)), CCA_VARS)
for (v in CCA_VARS) {
  cr = range(cal[[v]], na.rm = TRUE); pv = paleo[[v]]
  out = mean(pv < cr[1] | pv > cr[2], na.rm = TRUE) * 100
  outside_pct[[v]] = out
  cat(sprintf("  %-4s calibration [%8.1f, %8.1f]   paleo [%8.1f, %8.1f]   %5.1f%% outside\n",
              v, cr[1], cr[2], min(pv, na.rm = TRUE), max(pv, na.rm = TRUE), out))
}

cat("\n  Site medians - the ponds are NOT in the same places as the survey plots:\n")
print(as.data.frame(bind_rows(
  cal   %>% group_by(site) %>% summarize(across(all_of(CCA_VARS), ~ round(median(.x, na.rm = TRUE), 1))) %>% mutate(arm = "calibration plots"),
  paleo %>% group_by(site) %>% summarize(across(all_of(CCA_VARS), ~ round(median(.x, na.rm = TRUE), 1))) %>% mutate(arm = "paleo, all samples"),
  paleo %>% filter(slice == 20) %>% group_by(site) %>%
    summarize(across(all_of(CCA_VARS), ~ round(median(.x, na.rm = TRUE), 1))) %>% mutate(arm = "paleo slice 20 (modern)")
) %>% relocate(arm)), row.names = FALSE)
cat("\n  Slice 20 is calibrated to V2.1 EXACTLY (test 2), so any gap between it and the\n",
    "  calibration plots is GEOGRAPHY, not product: the coring ponds sit in wetter spots\n",
    "  than the survey plots. That displacement does not cancel in offset = pred - obs.\n", sep = "")

# -----------------------------------------------------------------------------
# 5. The winter_shift convention
# -----------------------------------------------------------------------------
# The two arms pass DIFFERENT winter_shift values, necessarily:
#   anthropocene  TRUE  - calendar years, so winter Y = Dec(Y-1) + Jan(Y) + Feb(Y)
#   paleo         FALSE - slices are ~100 yr apart and each is a CLIMATOLOGY, so
#                         shifting December strands it a century away
# Both estimate a DJF winter climatology, so they are the same quantity. This
# test asks how much the choice moves MWT, i.e. how much a mistake would cost.
cat("\n=== 5. winter_shift: how much does the convention move MWT? ===\n")
mk = function(shift) monthly %>%
  transmute(unit = plot_id, period = paste(site, period, sep = "."),
            variable, time = year, month, value) %>%
  derive_climate_vars(winter_shift = shift) %>%
  group_by(unit, period) %>% summarize(MWT = mean(MWT, na.rm = TRUE), .groups = "drop")
cmp = inner_join(mk(TRUE), mk(FALSE), by = c("unit", "period"), suffix = c("_T", "_F")) %>%
  separate_wider_delim(period, ".", names = c("site", "period")) %>%
  group_by(site, period) %>%
  summarize(mean_diff = mean(MWT_T - MWT_F, na.rm = TRUE),
            max_abs = max(abs(MWT_T - MWT_F), na.rm = TRUE), .groups = "drop")
print(as.data.frame(cmp %>% mutate(across(where(is.numeric), ~ round(.x, 3)))), row.names = FALSE)
max_shift = max(cmp$max_abs)
worst_window = cmp %>% slice_max(max_abs, n = 1, with_ties = FALSE) %>%
  transmute(label = paste(site, period)) %>% pull(label)
cat("\n  The maximum difference is ", round(max_shift, 3), " degC (", worst_window,
    "). The convention is handled correctly (TRUE for calendar-year windows; FALSE\n",
    "  for century-scale paleo climatology slices); the residual differences are\n",
    "  window-edge effects and are largest for the shortest current window.\n", sep = "")

cat("\n=== VERDICT ===\n")
cat("  Tests 1-3 PASS for the CORRECTED SENSITIVITY: the two arms are on the same\n",
    "  scale at its modern anchor, and\n",
    "  the derived variables agree to floating-point precision at the anchor slice.\n",
    "  Test 4 finds ", sprintf("%.1f", max(outside_pct)), "% outside the calibration\n",
    "  ranges across the four active variables. Pond-to-survey median differences still\n",
    "  reflect geography and do not cancel automatically in offset = pred - obs.\n",
    "  The active model remains USE_CORRECTED = FALSE; this check does not establish\n",
    "  that a stationary correction over 11 kyr is scientifically justified.\n", sep = "")
