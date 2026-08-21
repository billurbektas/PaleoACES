# =============================================================================
# 06b_displacements.R - Step 4. Tracking slope and the sideways test.
# =============================================================================
# Tracking slope = slope of  achieved ~ 0 + clim_len  per site x era.
#   slope 1 -> the gap is STABLE (not zero). slope 0 -> falling further behind
#   every step. Fitted, not averaged: along_n has variance scaling inversely
#   with clim_len, so short-demand intervals would dominate a mean with pure
#   noise. The regression is homoscedastic.
#
# Random effects (lake for the Holocene, plot for the Anthropocene) via
# lme4::lmer(achieved ~ 0 + clim_len + (1|unit)), given temporal and spatial
# autocorrelation. NOTE: the Holocene has 3 MORA lakes and 1 NOCA lake, so
# (1|unit) is not estimable for NOCA holocene - reported as NA there.
#
# Holocene statistics are fitted PER moving-window shift and summarized across
# shifts (median slope, min-max range). Shifts share samples; pooling them would
# reuse each sample n_shift times.
#
# Defines: slopes, slopes_by_shift, sideways_tests. Writes:
#   output/tracking_slopes.csv
#   output/sideways_tests.csv
# =============================================================================

library(here)
source(here("R/06_lag_common.R"))
has_lme4 = requireNamespace("lme4", quietly = TRUE)

# -----------------------------------------------------------------------------
# Tracking slope, per site x era x shift
# -----------------------------------------------------------------------------
fit_one = function(grp) {
  f  = lm(achieved ~ 0 + clim_len, data = grp)
  ci = confint(f)
  out = tibble(n = nrow(grp),
               slope    = unname(coef(f)[1]),
               slope_lo = ci[1, 1],
               slope_hi = ci[1, 2],
               p_vs_0   = summary(f)$coefficients[1, 4])
  # H0: slope = 1 (kept pace). t = (b - 1) / se
  se = summary(f)$coefficients[1, 2]
  out$p_vs_1 = 2 * pt(abs((out$slope - 1) / se), df = f$df.residual, lower.tail = FALSE)

  # Mixed model with a random intercept for unit, when there are enough units.
  out$slope_re = NA_real_; out$n_units = n_distinct(grp$unit)
  if (has_lme4 && out$n_units >= 3) {
    m = try(lme4::lmer(achieved ~ 0 + clim_len + (1 | unit), data = grp,
                       control = lme4::lmerControl(calc.derivs = FALSE)), silent = TRUE)
    if (!inherits(m, "try-error")) out$slope_re = unname(lme4::fixef(m)[1])
  }
  out
}

slopes_by_shift = turn %>%
  group_by(site, era, shift) %>%
  group_modify(~ fit_one(.x)) %>%
  ungroup()

# Summary across shifts. The Anthropocene has one shift, so median = that fit.
slopes = slopes_by_shift %>%
  group_by(site, era) %>%
  summarize(n_shifts   = n(),
            n          = round(median(n)),
            n_units    = first(n_units),
            slope      = median(slope),
            slope_lo   = median(slope_lo),
            slope_hi   = median(slope_hi),
            slope_min  = min(slope),
            slope_max  = max(slope),
            slope_re   = median(slope_re),
            p_vs_0     = median(p_vs_0),
            p_vs_1     = median(p_vs_1),
            .groups = "drop") %>%
  mutate(grp = interaction(site, era))

# -----------------------------------------------------------------------------
# Sideways test: is mean(sideways) different from zero?
# -----------------------------------------------------------------------------
# A non-zero mean is DIRECTIONAL change unrelated to climate - expected at NOCA
# given its fire regime. Sign is counter-clockwise relative to the demand
# direction, and is comparable across groups because there is one pooled
# ordination. Tested per shift, then summarized, for the same reason as above.
sideways_by_shift = turn %>%
  group_by(site, era, shift) %>%
  group_modify(~ {
    tt = t.test(.x$sideways)
    tibble(n = nrow(.x),
           mean_sideways = unname(tt$estimate),
           lo = tt$conf.int[1], hi = tt$conf.int[2], p = tt$p.value,
           mean_abs_sideways = mean(abs(.x$sideways)))
  }) %>% ungroup()

sideways_tests = sideways_by_shift %>%
  group_by(site, era) %>%
  summarize(n_shifts = n(), n = round(median(n)),
            mean_sideways = median(mean_sideways),
            lo = median(lo), hi = median(hi), p = median(p),
            mean_abs_sideways = median(mean_abs_sideways),
            .groups = "drop")

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
r3 = function(df) df %>% mutate(across(where(is.numeric), \(x) round(x, 3)))

cat("\n=== Tracking slope: lm(achieved ~ 0 + clim_len), per site x era ===\n")
cat("slope 1 = gap stable (NOT zero lag); slope 0 = falling further behind.\n")
cat("Holocene values are medians across", n_shift, "moving-window shifts.\n\n")
print(as.data.frame(r3(slopes %>%
  select(site, era, n, n_units, slope, slope_lo, slope_hi, slope_min, slope_max,
         slope_re, p_vs_1))), row.names = FALSE)
cat("\np_vs_1 tests H0: slope = 1 (kept pace). slope_re = lme4 (1|unit) fixed",
    "\neffect; NA where there are fewer than 3 units (NOCA holocene = 1 lake).\n")

cat("\n=== Sideways: mean component perpendicular to demand ===\n")
cat("H0: mean = 0, i.e. no directional non-climate change.\n\n")
print(as.data.frame(r3(sideways_tests)), row.names = FALSE)

cat("\n=== Intervals dropped by the clim_len filter ===\n")
print(as.data.frame(drop_report), row.names = FALSE)

write_csv(r3(slopes),         here(paste0("output/tracking_slopes", cca_suffix, ".csv")))
write_csv(r3(sideways_tests), here(paste0("output/sideways_tests", cca_suffix, ".csv")))
write_csv(r3(turn %>% select(site, era, unit, shift, time_t1, time_t2, dt,
                             vdx, vdy, cdx, cdy, clim_len, veg_len,
                             achieved, sideways, shortfall, along_n, across_n)),
          here(paste0("output/displacements", cca_suffix, ".csv")))
