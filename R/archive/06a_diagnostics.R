# =============================================================================
# 06a_diagnostics.R - Step 0. Run before looking at any figure.
# =============================================================================
# Writes output/diagnostics.txt.
#   0.1 scale check       - does vegan give WA and LC scores the same scaling?
#   0.2 species-env corr  - governs the variance of per-interval ratios
#   0.3 zero-response     - BLOCKING. Is the era contrast a detection artefact?
#   0.4 abundance         - deferred; counts are not comparable across
#                           sites/eras/data types, so everything stays P/A.
# =============================================================================

library(here)
source(here("R/06_lag_common.R"))

out = character(0)
add = function(...) out <<- c(out, paste0(...))
add_tab = function(df) out <<- c(out, capture.output(print(as.data.frame(df), row.names = FALSE)))

add("=====================================================================")
add("Displacement lag metric - diagnostics")
add("Pooled CCA: ", nrow(species_past_final), " past plots, ",
    ncol(species_past_final), " species")
add("Species excluded on top of the count.thr = ", count.thr, " rule: ",
    paste(extra_exclude, collapse = ", "))
add("Holocene binning: ", bin_width, " yr, ", n_shift, " moving-window shifts")
add("=====================================================================")

# -----------------------------------------------------------------------------
# 0.1 Scale check
# -----------------------------------------------------------------------------
# obs = pred + residual with residual orthogonal to climate, so E[obs|climate]
# = pred: same units, same axes, no scale factor. That identity is exact on the
# calibration data; it is checked there first, then on the projected samples,
# where a departure is an ecological/extrapolation signal rather than a units
# problem.
add(""); add("--- 0.1 Scale check: lm(WA ~ LC) -------------------------------------")
add("Want intercept ~ 0, slope ~ 1. A slope departing from 1 on the CALIBRATION")
add("rows would be a scaling problem and gives scale_correction. On projected")
add("rows it is model fit, not scaling.")

scale_check = function(sp, en, label) {
  cc = intersect(rownames(sp), rownames(en))
  w = predict(cca_model, newdata = sp[cc, keep_species, drop = FALSE], type = "wa")
  l = predict(cca_model, newdata = en[cc, c("MWT","MST","WP","SpP"), drop = FALSE], type = "lc")
  ok = !is.nan(w[, 1]) & !is.na(l[, 1])
  map_dfr(1:2, function(ax) {
    f = lm(w[ok, ax] ~ l[ok, ax])
    tibble(set = label, axis = paste0("CCA", ax), n = sum(ok),
           intercept = round(unname(coef(f)[1]), 4),
           slope     = round(unname(coef(f)[2]), 4),
           slope_lo  = round(confint(f)[2, 1], 4),
           slope_hi  = round(confint(f)[2, 2], 4),
           r2        = round(summary(f)$r.squared, 4))
  })
}

scale_tab = bind_rows(
  scale_check(species_past_final,    env_past_final,    "calibration (past)"),
  scale_check(species_present_final, env_present_final, "projected (present)"),
  scale_check(species_paleo,         env_paleo,         "projected (paleo)")
)
add(""); add_tab(scale_tab)

calib = scale_tab %>% filter(set == "calibration (past)")
add("")
if (all(calib$slope_lo <= 1 & calib$slope_hi >= 1)) {
  add("=> On the calibration rows the 95% CI for the slope contains 1 on both")
  add("   axes. WA and LC scores share one scaling; no scale_correction applied.")
} else {
  add("*** Calibration slope excludes 1. Record as scale_correction and multiply")
  add("    LC-derived quantities by it downstream:")
  add_tab(calib %>% select(axis, scale_correction = slope, slope_lo, slope_hi))
}

# -----------------------------------------------------------------------------
# 0.2 Species-environment correlation
# -----------------------------------------------------------------------------
add(""); add("--- 0.2 Species-environment correlation ------------------------------")
sec = spenvcor(cca_model)[1:2]
sec_tab = tibble(axis = names(sec), spenvcor = round(unname(sec), 4),
                 var_ratio_obs_pred = round(1 / unname(sec)^2, 3))
add_tab(sec_tab)
add("")
add("Observed positions are 1/spenvcor^2 times as variable as predicted ones.")
add("This inflates the variance of any per-interval ratio without biasing it,")
add("and is why the tracking slope is FITTED across intervals rather than")
add("obtained by averaging along_n.")

imp = summary(cca_model)$cont$importance[2, 1:2] * 100
add(""); add("Constrained inertia: CCA1 ", round(imp[1], 2), "%, CCA2 ", round(imp[2], 2),
             "%, total constrained ", round(sum(cca_model$CCA$eig) / cca_model$tot.chi * 100, 2), "%")
add("(HilleRisLambers et al. 2015 report 10.07% on 463 MORA plots; this is normal.)")

# -----------------------------------------------------------------------------
# 0.3 Zero-response fraction   *** BLOCKING CHECK ***
# -----------------------------------------------------------------------------
# Occurrence is binarised, so with ~10-14 taxa the response vector only moves
# when a species appears or disappears entirely. If the Anthropocene zero
# fraction is far above the Holocene, the era contrast is partly a detection
# artefact, not ecology, and must be reported as such.
add(""); add("--- 0.3 Zero-response fraction  *** BLOCKING *** ---------------------")

zero_tab = turn_all %>%
  group_by(site, era) %>%
  summarize(n_intervals   = n(),
            n_zero        = sum(veg_len == 0),
            frac_zero     = round(mean(veg_len == 0), 3),
            median_veg_len = round(median(veg_len), 4),
            median_clim_len = round(median(clim_len), 4),
            .groups = "drop")
add_tab(zero_tab)

# Compared WITHIN site - an across-site max() would hide a one-site asymmetry.
era_gap = zero_tab %>%
  select(site, era, frac_zero) %>%
  pivot_wider(names_from = era, values_from = frac_zero) %>%
  mutate(gap_anth_minus_holo = round(anthropocene - holocene, 3))
add(""); add_tab(era_gap)
add("")
flagged = era_gap %>% filter(abs(gap_anth_minus_holo) > 0.15)
if (nrow(flagged) > 0) {
  add("*** WARNING: within-site zero-response fractions differ between eras by")
  add("    more than 15 points at: ", paste(flagged$site, collapse = ", "))
  add("    Part of any era difference at those sites is a detection artefact of")
  add("    presence/absence data with few taxa, NOT ecology. State this wherever")
  add("    the era contrast appears.")
} else {
  add("=> Within-site zero-response fractions are comparable between eras; the")
  add("   era contrast is not obviously driven by detection. Still report these.")
}

# -----------------------------------------------------------------------------
# 0.4 Abundance availability - DEFERRED
# -----------------------------------------------------------------------------
add(""); add("--- 0.4 Abundance availability --------------------------------------")
add("Deferred by decision. Counts exist (NOCA stem counts; MORA summed DBH-bin")
add("counts; NOCA paleo macrofossil counts; MORA paleo is percentages only) but")
add("they are not comparable across sites, eras or data types. The whole")
add("analysis stays presence/absence for now.")

# -----------------------------------------------------------------------------
# Interval filter report (Step 3)
# -----------------------------------------------------------------------------
add(""); add("--- Interval filter: clim_len > 10th percentile within site x era ----")
add_tab(drop_report)
add("")
add("Intervals retained per site x era (this is the n for every figure):")
add_tab(turn %>% count(site, era, name = "n_retained"))
add("")
add("Holocene n is per moving-window shift x ", n_shift, " shifts; shifts share")
add("samples, so statistics are fitted per shift and summarized across them,")
add("never pooled.")
add_tab(turn %>% filter(era == "holocene") %>% count(site, shift, name = "n"))

writeLines(out, here("output/diagnostics.txt"))
cat(paste(out, collapse = "\n"), "\n")
