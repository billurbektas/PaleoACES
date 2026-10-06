# =============================================================================
# 000_PALEO_e_climate.R - paleo_env.csv: climate per dated macrofossil sample
# =============================================================================
# Reads the pond series from 000_PALEO_d_climate_download.R, turns it into the CCA
# variables via the SHARED R/helpers/climate_variables.R, and joins each sample to the
# TraCE21k slice covering its own age.
#
# USES value_raw - the UNCORRECTED TraCE21k. Decided by Billur 2026-08-13,
# reversing the earlier default. Rationale and consequences are in
# docs/SCIENTIFIC_DECISIONS.md
# under "the TraCE21k bias"; the short form:
#   - the correction was ADDITIVE for temperature, and an additive constant
#     CANCELS EXACTLY in any difference. Verified at ~1e-15 in
#     R/diagnostics/test_climate_change_variables.R. So for Dclimate and Dvegetation the
#     choice is provably irrelevant.
#   - for precipitation it was MULTIPLICATIVE, so it scaled every delta. Raw
#     therefore keeps the model's own internal amplitude rather than rescaling
#     it to a modern anchor.
#   - the correction was anchored on ONE slice (slice 20) against V2.1 1979-2021
#     and then applied to all 111 slices, i.e. it assumed the bias is stationary
#     over 11 kyr. That assumption is untestable and the raw series avoids it.
# ⚠ THE COST: offset = pred - obs takes a NORM, so it does NOT cancel there.
# The Holocene offset now carries the full TraCE21k bias. Re-run with
# USE_CORRECTED = TRUE as an explicit sensitivity override.
#
# winter_shift = FALSE: slices are ~100 yr apart, so shifting December into the
# "next" slice would move it a century.
#
# AGE -> SLICE IS A JOIN, NOT AN INTERPOLATION. Slices are the native 100-yr step
# and primary tracking averages ten of them per 1,000-year bin, so interpolating here would
# invent structure the binning then smooths away. paleo_env.csv records which slice
# each sample got and that slice's age, so R/tests/test_paleo_climate_age_match.R can
# verify the match rather than trusting it.
#
# Output: output/paleo_env.csv
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr)})
source(here("R/helpers/climate_variables.R"))
source(here("R/helpers/config.R"))

if (!exists("USE_CORRECTED")) USE_CORRECTED = PALEO_USE_BIAS_CORRECTED

ponds = read_csv(here("output/chelsa_paleo_ponds.csv"), show_col_types = FALSE)
occ   = read_csv(here("output/paleo_occ.csv"),          show_col_types = FALSE)

cat("pond series: ", nrow(ponds), " rows | ", n_distinct(ponds$lake), " lakes | slices ",
    min(ponds$slice), " to ", max(ponds$slice), "\n", sep = "")

# --- climate variables, per lake x slice -------------------------------------
env_slice = ponds %>%
  transmute(unit = lake, period = "paleo", variable, time = slice, month,
            value = if (USE_CORRECTED) value_corrected else value_raw) %>%
  derive_climate_vars(winter_shift = FALSE) %>%
  rename(lake = unit, slice = time) %>%
  mutate(slice_age_calBP = 1950 - slice * 100)

# The winter group of the OLDEST slice has no December from a previous slice and
# the youngest has a December that belongs nowhere - with winter_shift = FALSE
# neither happens, but check the slice set survived intact.
stopifnot(setequal(unique(env_slice$slice), unique(ponds$slice)))
cat("variables built for ", nrow(env_slice), " lake x slice combinations\n", sep = "")

# --- each sample -> the slice covering its age -------------------------------
samples = occ %>%
  distinct(period, plot_id, site, era, lake) %>%
  mutate(age = as.numeric(regmatches(plot_id,
                regexpr("-?[0-9.]+(?=_BP$)", plot_id, perl = TRUE))))
stopifnot(!any(is.na(samples$age)))

nearest_slice = function(age, lake_slices) lake_slices[which.min(abs(lake_slices - age))]

paleo_env = samples %>%
  rowwise() %>%
  mutate(slice_age_calBP = nearest_slice(
    age, env_slice$slice_age_calBP[env_slice$lake == lake])) %>%
  ungroup() %>%
  left_join(env_slice, by = c("lake", "slice_age_calBP")) %>%
  mutate(age_error = slice_age_calBP - age) %>%
  select(period = period.x, plot_id, site, era, lake, age, slice, slice_age_calBP,
         age_error, MAT, MSpT, MST, MWT, AP, SpP, SP, WP,
         ends_with("_min"), ends_with("_max"), ends_with("_mean"))

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

write_csv(paleo_env, here("output/paleo_env.csv"))
cat("\nwritten: output/paleo_env.csv\n")
