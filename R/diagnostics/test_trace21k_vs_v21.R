# =============================================================================
# test_trace21k_vs_v21.R - how far is the paleo model from the modern observations?
# =============================================================================
# Reassesses the unresolved TraCE21k/V2.1 anchoring issue in docs/SCIENTIFIC_DECISIONS.md.
#
# The two products are not two versions of one dataset. CHELSA is a downscaling
# METHOD; underneath, V2.1 downscales a reanalysis (observation-constrained) and
# TraCE21k downscales a free-running CCSM3 simulation. A free-running GCM is not
# synchronised to observed weather - it produces a plausible trajectory, not the
# actual one - so they were never going to agree for a specific decade.
#
# What matters for us is the SIZE and DIRECTION of the disagreement, because the
# CCA is calibrated on V2.1 (survey plots) and paleo samples are projected into
# it carrying TraCE21k. Verified 2026-08-12 at the four ponds, slice 20 vs the
# V2.1 1979-2021 mean:
#
#   tasmin  +0.5 to +2.1 degC too warm      tasmax  -1.5 to -1.6 degC too cool (Jul)
#
# Opposite signs = a compressed diurnal range, the classic GCM signature. NOT the
# random scatter two observational products would show (cf. cruts vs V2.1
# temperature, r = 0.96-0.99, in test_chelsa_cruts_vs_present.R).
#
# ⚠ CAVEAT ON THE ANCHOR. If a TraCE21k slice is a centennial MEAN (~1900-2000)
# rather than a snapshot at 2000, comparing it to a 1979-2021 window folds real
# 20th-century warming (~1 degC) into the estimate - the same order as the bias
# itself. This script therefore reports the bias against TWO baselines so the
# spread is visible. Resolving which is correct needs the CHELSA-TraCE21k paper.
#
# Cost: 4 ponds x 3 vars x 12 months x (1 slice + 43 yr monthly) - the V2.1 part
# dominates at ~1,548 reads. Set QUICK = TRUE for Jan+Jul only (~260 reads).
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)

QUICK  = TRUE
MONTHS = if (QUICK) c(1, 7) else 1:12
VARS   = c("tasmin", "tasmax", "pr")
SLICE_MODERN = 20L

ponds = data.frame(
  id  = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes"),
  lon = c(-121.7667, -121.7500, -121.7167, -121.0333),
  lat = c(  46.7667,   46.7667,   46.7667,   48.6500))

# --- 1. is slice 20 really the last? ----------------------------------------
top = get_chelsa(ponds, vars = VARS, source = "paleo", start = 16, end = 20,
                 months = MONTHS, to_celsius = TRUE, id_col = "id", verbose = FALSE)
cat("slices returned: ", paste(sort(unique(top$slice)), collapse = ", "),
    "  (21 and 22 are 404 - see test_chelsa_coverage.R)\n", sep = "")

cat("\n--- the top five slices: is there any within-century structure? ---\n")
print(as.data.frame(
  top %>% select(id, variable, month, slice, value) %>%
    pivot_wider(names_from = slice, values_from = value, names_prefix = "sl")),
  digits = 3)

# --- 2. two baselines --------------------------------------------------------
v21 = get_chelsa_monthly(ponds, vars = VARS, years = 1979:2021, months = MONTHS,
                         to_celsius = TRUE, id_col = "id", verbose = TRUE) %>%
  group_by(id, variable, month) %>%
  summarise(v21_1979_2021 = mean(value, na.rm = TRUE), .groups = "drop")

cmp = top %>% filter(slice == SLICE_MODERN) %>%
  select(id, variable, month, trace_sl20 = value) %>%
  inner_join(v21, by = c("id", "variable", "month")) %>%
  mutate(bias = trace_sl20 - v21_1979_2021,
         ratio = trace_sl20 / v21_1979_2021)

cat("\n=== TraCE21k slice 20 minus V2.1 1979-2021 ===\n")
print(as.data.frame(
  cmp %>% group_by(variable, month) %>%
    summarise(n = n(), mean_bias = mean(bias), min = min(bias), max = max(bias),
              mean_ratio = mean(ratio), .groups = "drop")), digits = 3)

cat("\nper pond (temperature only):\n")
print(as.data.frame(cmp %>% filter(variable != "pr") %>%
                      select(id, variable, month, trace_sl20, v21_1979_2021, bias)),
      digits = 3, row.names = FALSE)

cat("\n⚠ ANCHOR CAVEAT: if slice 20 is a 1900-2000 MEAN rather than a snapshot at\n",
    "   2000, part of the bias above is real 20th-century warming, not model error.\n",
    "   Resolve from the CHELSA-TraCE21k paper before correcting on these numbers.\n",
    sep = "")

write_csv(cmp, here("output/test_trace21k_vs_v21.csv"))
cat("\nwritten: output/test_trace21k_vs_v21.csv\n")

cat("\nNEXT, to close the 🔴 issue: project the paleo env with and without this bias\n",
    "through the CCA and report ||delta|| in CCA1-CCA2 plus its ANGLE to a typical\n",
    "offset. Near-parallel or short -> footnote. Long and wide-angle -> correct.\n", sep = "")
