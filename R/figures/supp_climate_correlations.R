# =============================================================================
# supp_climate_correlations.R
# -----------------------------------------------------------------------------
# How much does each climate variable actually CHANGE from one time point to the
# next, at each site, in each era - in its own units (degC, mm), not standardised.
#
# This is the evidence for which variables the CCA should use. It retains the
# former 500-year resolution as an explicit diagnostic sensitivity and touches
# no ordination: climate only.
#
#   reads   output/MORA_climate.csv, output/NOCA_climate.csv   (raw monthly, V2.1)
#           output/paleo_env.csv                               (per sample, TraCE21k)
#   writes  output/test_climate_change_variables.csv
#           output/test_climate_pace_of_change.csv
#           plot/test_figures/climate_holocene_timeseries.pdf
#
# ALL EIGHT VARIABLES, not just the four the CCA currently constrains on:
#   temperature (degC)   MAT annual, MSpT spring, MST summer, MWT winter
#   precipitation (mm)   AP  annual, SpP spring, SP  summer, WP  winter
# Set INCLUDE_MINMAX = TRUE to add the tasmin- and tasmax-only temperature
# variants as well (the old pipeline's MWT/MST were really tasmin - see
# R/helpers/climate_variables.R).
#
# =============================================================================
# THREE THINGS THAT MUST NOT BE FUDGED
# =============================================================================
# 1. NO dt NORMALISATION. The Anthropocene interval is ~39 yr at MORA and ~32 at
#    NOCA; the Holocene interval is 500 yr. Dividing one by the other would
#    manufacture a comparison the data cannot support. Both are reported as raw
#    change over their own interval, and the
#    interval is printed beside every number.
#
# 2. LEVELS ARE NOT COMPARABLE ACROSS ERAS, DIFFERENCES ARE. The Anthropocene
#    arm is CHELSA V2.1 (downscaled reanalysis); the Holocene arm is CHELSA-
#    TraCE21k (a downscaled CCSM3 simulation), with raw TraCE21k selected in the primary analysis. A
#    constant product offset cancels when two time points of the SAME arm are
#    differenced, which is all this script does. Never compare a Holocene LEVEL
#    to an Anthropocene LEVEL here.
#
# 3. RAW UNITS, DELIBERATELY. No z-scoring, so "+1.4 degC" and "-60 mm" stay
#    physically readable. The cost is that variables are not directly comparable
#    to each other - a 1 degC change and a 1 mm change are not equivalent. Read
#    each variable against ITSELF across eras and sites, which is the comparison
#    variable-selection diagnostic needs.
# =============================================================================

library(here)
library(tidyverse)
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
source(here("R/helpers/figure_style.R"), local = TRUE)
plot_years = read_plot_years()

INCLUDE_MINMAX = FALSE
source(here("R/helpers/config.R"), local = TRUE)
# Which TraCE21k series the analysis uses; the single default is in config.R.
CORRECTION_IN_USE = if (PALEO_USE_BIAS_CORRECTED) "corrected" else "raw"
HOLO_BIN       = 500      # yr - former primary resolution, retained as a sensitivity

TEMP_VARS = c("MAT", "MSpT", "MST", "MWT")
PREC_VARS = c("AP", "SpP", "SP", "WP")
VARS = c(TEMP_VARS, PREC_VARS)
if (INCLUDE_MINMAX)
  VARS = c(VARS, paste0(rep(TEMP_VARS, each = 2), c("_min", "_max")))

UNIT = function(v) if_else(str_detect(v, "^(AP|SpP|SP|WP)$"), "mm", "degC")

# -----------------------------------------------------------------------------
# ANTHROPOCENE - per plot, past -> present
# -----------------------------------------------------------------------------
# Same derive_climate_vars() the Holocene arm uses, so a season means the same
# thing in both. Site is folded into the grouping key because "past" is a
# different set of years at the two sites.
monthly = bind_rows(
  read_csv(out("MORA_climate.csv"), show_col_types = FALSE),
  read_csv(out("NOCA_climate.csv"), show_col_types = FALSE)
)

anth_annual = monthly %>%
  transmute(unit = plot_id, period = paste(site, period, sep = "."),
            variable, time = year, month, value) %>%
  derive_climate_vars(winter_shift = TRUE) %>%
  restrict_modern_seasons(plot_years) %>%
  filter(if_any(all_of(VARS), ~ !is.na(.x)))

anth_plot = anth_annual %>%
  group_by(unit, period) %>%
  summarize(across(all_of(VARS), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  separate_wider_delim(period, ".", names = c("site", "period")) %>%
  mutate(across(all_of(VARS), ~ if_else(is.nan(.x), NA_real_, .x)))

# one interval per plot: present - past, on plots measured at both times
anth_delta = anth_plot %>%
  pivot_longer(all_of(VARS), names_to = "variable", values_to = "value") %>%
  pivot_wider(names_from = period, values_from = value) %>%
  filter(!is.na(past), !is.na(present)) %>%
  mutate(delta = present - past, era = "anthropocene") %>%
  left_join(plot_years %>% rename(unit = plot_id), by = c("site", "unit"))

# Report ranges; rates always divide each plot's change by its own interval.
interval_support = anth_delta %>% group_by(site) %>% summarise(
  vegetation_dt_min = min(vegetation_dt_years), vegetation_dt_max = max(vegetation_dt_years),
  climate_dt_min = min(climate_dt_years), climate_dt_max = max(climate_dt_years), .groups = "drop")
ANTH_INTERVAL = setNames(paste0(interval_support$climate_dt_min, "–",
  interval_support$climate_dt_max, " climate yr"), interval_support$site)

# -----------------------------------------------------------------------------
# HOLOCENE - per lake, consecutive 500-yr bins, forward in time
# -----------------------------------------------------------------------------
# ⚠ THE CLIMATE SERIES COMES FROM THE FULL TraCE21k RECORD AT EACH POND,
# NOT from output/paleo_env.csv.
#
# paleo_env.csv carries climate only at the ages where a CORE HAPPENS TO HAVE A
# SAMPLE - 28 irregularly spaced slices at ReflectionPond, 44 at JayBath. That is
# exactly right for the CCA, where every sample needs its own climate. It is
# WRONG for a figure about a location's climate history, because the line would
# then be shaped by when someone cored and how fast the sediment accumulated,
# not by the climate.
#
# Every pond has all 111 slices (0 to 11,000 cal BP), evenly spaced at ~100 yr.
# Using them gives the location's actual trend, with bins filled by real slices
# instead of by 1-3 macrofossil samples.
ponds_monthly = read_csv(out("chelsa_paleo_ponds.csv"), show_col_types = FALSE)

# winter_shift = FALSE: a slice is a 100-yr CLIMATOLOGY, so Dec/Jan/Feb of the
# same slice already are its winter. Shifting December would strand it a century
# away. Same convention as 08_paleo_climate.R.
# BOTH the bias-corrected and the RAW TraCE21k series are built, so the figure
# can show what the correction does. The expectation is exact and worth stating
# in advance:
#   TEMPERATURE  the correction is ADDITIVE (trace_slice20 - v21_mean), a constant
#                per pond x month, so it CANCELS EXACTLY in any difference. Raw
#                and corrected deltas must be identical to floating point.
#   PRECIPITATION the correction is MULTIPLICATIVE (v21_mean / trace_slice20), so
#                it SCALES every delta by that factor and does NOT cancel.
# If temperature ever differs, the correction is not what it claims to be.
pond_clim = map_dfr(c(corrected = "value_corrected", raw = "value_raw"), function(col) {
  ponds_monthly %>%
    transmute(unit = lake, period = site, variable, time = slice, month,
              value = .data[[col]]) %>%
    derive_climate_vars(winter_shift = FALSE) %>%
    rename(lake = unit, site = period, slice = time) %>%
    mutate(cal_BP = trace_slice_cal_bp(slice))
}, .id = "correction")

stopifnot(nrow(pond_clim) == 111 * 4 * 2)      # every pond, every slice, both versions
stopifnot(!any(is.na(pond_clim[VARS])))        # and no holes

# core coverage, for the caption only - the climate is not limited to it
core_cov = read_csv(out("paleo_env.csv"), show_col_types = FALSE) %>%
  group_by(lake) %>% summarize(core_max = max(age), .groups = "drop")

# --- MOVING WINDOW, former 500-year sensitivity -------------------------------
# Where the first bin edge falls is arbitrary, and shifting it changes which
# slices group together. The whole binning runs at 5 offsets and every offset is
# carried through; their spread is the bin-phase uncertainty.
OFFSETS = seq(0, HOLO_BIN - 100, by = 100)

holo_binned = map_dfr(OFFSETS, function(off) {
  pond_clim %>%
    mutate(bin = floor((cal_BP - off) / HOLO_BIN) * HOLO_BIN + off) %>%
    group_by(correction, site, lake, bin) %>%
    summarize(across(all_of(VARS), ~ mean(.x, na.rm = TRUE)),
              n_slices = n(), .groups = "drop") %>%
    filter(n_slices == 5) %>%     # only FULL bins - a partial bin is not a 500-yr mean
    mutate(offset = off)
})

# cal BP runs BACKWARDS, so sort descending and difference forwards in time.
holo_delta = holo_binned %>%
  arrange(correction, site, lake, offset, desc(bin)) %>%
  group_by(correction, site, lake, offset) %>%
  mutate(prev_bin = lag(bin), gap = prev_bin - bin,
         across(all_of(VARS), ~ .x - lag(.x), .names = "d_{.col}")) %>%
  ungroup() %>%
  filter(!is.na(prev_bin), gap == HOLO_BIN) %>%
  select(correction, site, lake, offset, bin, prev_bin, n_slices, starts_with("d_")) %>%
  pivot_longer(starts_with("d_"), names_to = "variable", values_to = "delta") %>%
  mutate(variable = str_remove(variable, "^d_"), era = "holocene")

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
summ = bind_rows(
  anth_delta %>% group_by(site, era, variable) %>%
    summarize(n = n(), median = median(delta), q05 = quantile(delta, .05),
              q95 = quantile(delta, .95), .groups = "drop"),
  holo_delta %>% filter(correction == CORRECTION_IN_USE) %>% group_by(site, era, variable) %>%
    summarize(n = n(), median = median(delta, na.rm = TRUE),
              q05 = quantile(delta, .05, na.rm = TRUE),
              q95 = quantile(delta, .95, na.rm = TRUE), .groups = "drop")
) %>%
  mutate(unit = UNIT(variable),
         interval = case_when(era == "holocene"            ~ paste0(HOLO_BIN, " yr"),
                              TRUE                         ~ ANTH_INTERVAL[site]),
         variable = factor(variable, levels = VARS)) %>%
  arrange(variable, site, era)

cat("\n=== change per interval, in native units - NOT rates, NOT standardised ===\n")
cat("    anthropocene: one interval per plot, n = plots; median across plots\n")
cat("    holocene    : one interval per consecutive ", HOLO_BIN,
    "-yr bin pair, n = intervals\n", sep = "")
cat("    the two eras have DIFFERENT interval lengths - see the `interval` column\n\n")
print(as.data.frame(summ %>%
  mutate(across(c(median, q05, q95), ~ round(.x, 2))) %>%
  select(variable, unit, site, era, interval, n, median, q05, q95)), row.names = FALSE)

write_csv(summ, out("report/test_climate_change_variables.csv"))

# --- which variables actually move, and where -------------------------------
cat("\n=== Anthropocene change vs the Holocene 500-yr spread ===\n")
cat("    |anthropocene median| expressed as a percentile of |holocene delta|,\n")
cat("    i.e. how unusual the modern step is against Holocene 500-yr steps.\n\n")
cmp = anth_delta %>% group_by(site, variable) %>%
  summarize(anth = median(delta), .groups = "drop") %>%
  left_join(holo_delta %>% filter(correction == CORRECTION_IN_USE) %>% group_by(site, variable) %>%
              summarize(holo = list(delta), .groups = "drop"), by = c("site","variable")) %>%
  filter(!map_lgl(holo, is.null)) %>%
  mutate(pctile = map2_dbl(anth, holo, ~ mean(abs(.y) <= abs(.x), na.rm = TRUE) * 100),
         holo_iqr = map_dbl(holo, ~ IQR(.x, na.rm = TRUE)),
         unit = UNIT(variable)) %>%
  select(site, variable, unit, anth_median = anth, holo_IQR = holo_iqr, pctile) %>%
  mutate(across(c(anth_median, holo_IQR, pctile), ~ round(.x, 1))) %>%
  arrange(site, desc(pctile))
print(as.data.frame(cmp), row.names = FALSE)

# -----------------------------------------------------------------------------
# FIGURE - the CHANGE through time, all four ponds, with the Anthropocene attached
# -----------------------------------------------------------------------------
# What is plotted is CHANGE per interval, not level, in native units. One panel
# per variable, free y.
#
#   faint   native 100-yr change   - the raw CHELSA step, what binning removes
#   bold    500-yr binned change   - the analysis resolution; the moving window's
#                                    5 offsets are all drawn, so the spread
#                                    between them IS the bin-phase uncertainty
#   right   Anthropocene change    - boxplot ACROSS PLOTS (present - past), one
#                                    box per site. A boxplot because the
#                                    Anthropocene has many plots and one
#                                    interval, the mirror image of the Holocene.
#
# ⚠ THE THREE LAYERS SPAN DIFFERENT INTERVALS - 100 yr, 500 yr and ~30 yr. They
# are raw changes, NOT rates, so they are not directly comparable by eye. The
# rates are in the pace table below, which is where the comparison belongs.
#
# The Anthropocene boxes sit at NEGATIVE cal BP, i.e. off the right-hand end of
# the Holocene axis, which is where they belong chronologically.
# Anthropocene boxes sit at NEGATIVE cal BP - off the right-hand end of the
# Holocene axis, which is where they belong chronologically. Spaced far enough
# apart that the two axis labels cannot collide.
ANTH_X = c(MORA = -1800, NOCA = -4400)

anth_box = anth_delta %>%
  mutate(x = ANTH_X[site], variable = factor(variable, levels = VARS))

holo_bin = holo_delta %>%
  mutate(variable = factor(variable, levels = VARS),
         mid = (bin + prev_bin) / 2)

# Break lines where a pond has a gap, so geom_line cannot draw straight across a
# hole and invent a trend that is not in the data.
holo_bin = holo_bin %>%
  arrange(correction, lake, variable, offset, desc(mid)) %>%
  group_by(correction, lake, variable, offset) %>%
  mutate(seg = cumsum(c(0, as.integer(abs(diff(mid)) > HOLO_BIN + 1)))) %>%
  ungroup()

# ROLLING MEAN, not median. A median of 5 values returns one OF those values, so
# consecutive windows repeat it and the line acquires flat plateaus and square
# step-jumps - an artefact of the estimator, not structure in the data.
roll_mean = function(x, k = 5) {
  n = length(x); if (n < k) return(rep(NA_real_, n))
  sapply(seq_len(n), function(i) {
    lo = max(1, i - (k - 1) %/% 2); hi = min(n, i + (k - 1) %/% 2)
    mean(x[lo:hi], na.rm = TRUE) })
}
holo_mw = holo_bin %>%
  arrange(correction, lake, variable, desc(mid)) %>%
  group_by(correction, lake, site, variable) %>%
  mutate(smooth = roll_mean(delta),
         seg_mw = cumsum(c(0, as.integer(abs(diff(mid)) > 150)))) %>%
  ungroup() %>% filter(!is.na(smooth))

mw_cor = holo_mw %>% filter(correction == CORRECTION_IN_USE)
mw_raw = holo_mw %>% filter(correction != CORRECTION_IN_USE)

# --- pace annotation, per panel ----------------------------------------------
# UNITS. Both eras are converted to the SAME unit - change PER CENTURY - so the
# numbers are directly comparable:
#     Holocene      delta is the change over HOLO_BIN = 500 yr
#                   delta / 500 * 100  ->  per century
#     Anthropocene  delta is the change over CLIM_DT yr (plot-specific 27.5–32.5)
#                   delta / CLIM_DT * 100  ->  per century
# ⚠ Numerically comparable is not the same as equivalent in meaning: a rate
# averaged over 500 yr suppresses everything faster than 500 yr, so the Holocene
# value is a FLOOR on how fast climate actually moved. The comparison is
# therefore conservative against the Holocene and generous to the Anthropocene.
stopifnot(HOLO_BIN == 500, all(anth_delta$climate_dt_years > 20), all(anth_delta$climate_dt_years < 40))
# min / mean / max of the SIGNED pace, per century, for every pond and every
# site. Signed rather than absolute on purpose: the Holocene mean sits at ~0
# because the record oscillates without net drift, while the Anthropocene mean is
# the change itself. That contrast is the point, and taking absolute values would
# hide it.
#
# Placement carries the meaning: pond statistics sit over the Holocene series on
# the left, site statistics over the Anthropocene boxes on the right. Colours
# match the lines and boxes they describe, so nothing needs an era label.
# %g emits scientific notation for large precipitation values (-2.39e+03), which
# is unreadable in a cramped annotation. Pick decimals by magnitude instead.
fmt = function(x) ifelse(abs(x) >= 100, sprintf("%.0f", x),
                  ifelse(abs(x) >= 10,  sprintf("%.1f", x),
                                        sprintf("%.3f", x)))

pace_pond = holo_delta %>%
  filter(correction == CORRECTION_IN_USE) %>%
  mutate(rate = delta / HOLO_BIN * 100) %>%
  group_by(variable, lake) %>%
  summarize(min = min(rate), mean = mean(rate), max = max(rate), .groups = "drop") %>%
  mutate(variable = factor(variable, levels = VARS),
         lab = sprintf("%-16s %8s %8s %8s", lake, fmt(min), fmt(mean), fmt(max))) %>%
  group_by(variable) %>% mutate(row = as.integer(factor(lake))) %>% ungroup()

pace_site = anth_delta %>%
  mutate(rate = delta / climate_dt_years * 100) %>%
  group_by(variable, site) %>%
  summarize(min = min(rate), mean = mean(rate), max = max(rate), .groups = "drop") %>%
  mutate(variable = factor(variable, levels = VARS),
         lab = sprintf("%-5s %8s %8s %8s", site, fmt(min), fmt(mean), fmt(max)),
         row = as.integer(factor(site)))

hdr = tibble(variable = factor(VARS, levels = VARS)) %>%
  mutate(lab = paste0("                     min     mean      max     ", UNIT(as.character(variable)), " per century"))

p_change = ggplot() +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4) +
  # the 5 moving-window offsets, very faint - their spread is the bin-phase uncertainty
  geom_line(data = filter(holo_bin, correction == CORRECTION_IN_USE),
            aes(mid, delta, colour = lake, group = interaction(lake, offset, seg)),
            alpha = 0.10, linewidth = 0.25) +
  # bias-corrected, bold but TRANSPARENT - the ponds sit on top of one another
  geom_line(data = mw_cor,
            aes(mid, smooth, colour = lake, group = interaction(lake, seg_mw)),
            linewidth = 0.8, alpha = 0.6) +
  geom_vline(xintercept = -600, linetype = "dotted", colour = "grey40") +
  geom_boxplot(data = anth_box, aes(x, delta, group = site, fill = site),
               width = 1300, outlier.size = 0.25, linewidth = 0.35,
               colour = "grey25", alpha = 0.85) +
  # ⚠ under scale_x_reverse, x = Inf is the LEFT edge of the panel and x = -Inf
  # the RIGHT edge. Pond stats go left, over the Holocene series; site stats go
  # right, over the Anthropocene boxes. Position is what says which era it is.
  geom_text(data = hdr, aes(x = Inf, y = Inf, label = lab),
            hjust = -0.02, vjust = 1.6, size = 2.5, colour = "grey45",
            family = "mono", inherit.aes = FALSE) +
  geom_text(data = pace_pond, aes(x = Inf, y = Inf, label = lab, colour = lake,
                                  vjust = 1.6 + 1.35 * row),
            hjust = -0.02, size = 2.5, family = "mono", show.legend = FALSE) +
  geom_text(data = filter(pace_site, site == "MORA"),
            aes(x = -Inf, y = Inf, label = lab, vjust = 1.6 + 1.35 * row),
            hjust = 1.02, size = 2.5, family = "mono", colour = "grey25",
            inherit.aes = FALSE) +
  geom_text(data = filter(pace_site, site == "NOCA"),
            aes(x = -Inf, y = Inf, label = lab, vjust = 1.6 + 1.35 * row),
            hjust = 1.02, size = 2.5, family = "mono", colour = "grey55",
            inherit.aes = FALSE) +
  facet_wrap(~ variable, scales = "free_y", ncol = 2, dir = "v") +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.34))) +
  scale_x_reverse(breaks = c(10000, 7500, 5000, 2500, 0, ANTH_X),
                  labels = c("10000", "7500", "5000", "2500", "0", "MORA", "NOCA"),
                  expand = expansion(mult = c(0.02, 0.04))) +
  scale_colour_brewer(palette = "Dark2", name = "Pond (Holocene)") +
  scale_fill_manual(values = PAPER_SITE_COLORS,
                    name = "Site (Anthropocene)") +
  labs(x = "cal BP  (time runs left to right)  |  Anthropocene",
       y = "Change over the interval  (degC or mm)",
       title = "Climate CHANGE per interval - four ponds through the Holocene, survey plots in the Anthropocene",
       subtitle = paste0("Holocene = UNCORRECTED CHELSA-TraCE21k (the series the analysis uses), ", HOLO_BIN,
                         "-yr rolling mean across the ", length(OFFSETS),
                         " moving-window offsets, which are drawn faint behind.\n",
                         "Right of the dotted line: Anthropocene change across survey plots (present - past), one box per site. All paces are PER CENTURY at both ends."),
       caption = paste0("Holocene = the FULL TraCE21k record at each pond (all 111 slices, ~100 yr apart), NOT the ages where cores happen to have samples - ",
                        "so the line is the location's\nclimate history, independent of coring. Cores themselves reach ",
                        paste(sprintf("%s %.0f", core_cov$lake, core_cov$core_max), collapse = ", "),
                        " cal BP. Intervals differ (", HOLO_BIN,
                        " yr vs ~30 yr): these are CHANGES, not rates - see the pace table. Anthropocene = V2.1.")) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "top", plot.title = element_text(face = "bold"),
        plot.caption = element_text(hjust = 0, colour = "grey35"),
        axis.text.x = element_text(size = 7.5),
        panel.grid.minor = element_blank())

# =============================================================================
# PAGE 2 - correlation between the climate variables, Holocene vs Anthropocene
# =============================================================================
# Compare marginal covariance structures in the two eras. Strong correlations
# can indicate overlapping information among constraints. Differences can limit
# transfer, but correlations alone do not test the fitted model's predictive
# validity or establish that a sign change invalidates its projections.
# Holocene     = across pond x slice (4 ponds x 111 slices), the location's own
#                climate through time
# Anthropocene = across survey plot x period, the spread the CCA is fitted on
cor_holo = pond_clim %>% filter(correction == CORRECTION_IN_USE) %>%
  select(all_of(VARS)) %>% cor(use = "pairwise.complete.obs")
cor_anth = anth_plot %>% select(all_of(VARS)) %>% cor(use = "pairwise.complete.obs")

as_long = function(m, era) as.data.frame(as.table(m)) %>%
  setNames(c("v1", "v2", "r")) %>% mutate(era = era)
cor_df = bind_rows(as_long(cor_holo, "Holocene  (pond x slice)"),
                   as_long(cor_anth, "Anthropocene  (plot x period)")) %>%
  mutate(v1 = factor(v1, levels = VARS), v2 = factor(v2, levels = rev(VARS)),
         era = factor(era, levels = c("Holocene  (pond x slice)",
                                      "Anthropocene  (plot x period)")))

# Flag pairs whose marginal correlations change sign between the eras.
flip = cor_df %>% select(v1, v2, era, r) %>%
  pivot_wider(names_from = era, values_from = r) %>%
  setNames(c("v1", "v2", "holo", "anth")) %>%
  filter(as.character(v1) != as.character(v2), sign(holo) != sign(anth),
         abs(holo) > 0.2, abs(anth) > 0.2)

p_cor = ggplot(cor_df, aes(v1, v2, fill = r)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.2f", r),
                colour = abs(r) > 0.6), size = 3, show.legend = FALSE) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "grey20")) +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                       midpoint = 0, limits = c(-1, 1), name = "Pearson r") +
  facet_wrap(~ era) +
  coord_equal() +
  labs(x = NULL, y = NULL,
       title = "Correlation between climate variables, Holocene vs Anthropocene",
       subtitle = paste0("The CCA learns the species-climate relationship from the ANTHROPOCENE plots and applies it to HOLOCENE samples.\n",
                         "Contrasting covariance structures can limit transfer; correlations alone do not test predictive validity."),
       caption = stringr::str_wrap(if (nrow(flip))
         paste0("Sign flips with |r| > 0.2 in both eras: ",
                paste(sprintf("%s~%s (%.2f vs %.2f)", flip$v1, flip$v2, flip$holo, flip$anth),
                      collapse = ";  "))
         else "No pair flips sign with |r| > 0.2 in both eras.", width = 120)) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"),
        plot.caption = element_text(hjust = 0, colour = "grey25"),
        panel.grid = element_blank(),
        axis.text.x = element_text(angle = 45, hjust = 1))

pdf(fig("supplementary", "climate_holocene_timeseries.pdf"), width = 13, height = 15)
print(p_change); print(p_cor)
dev.off()
# The correlation page on its own, as Fig. S10 of the README.
ggsave(fig("supplementary", "figS10_climate_correlations.pdf"), p_cor, width = 13, height = 15)

cat("\n=== variable pairs that FLIP SIGN between the eras ===\n")
if (nrow(flip)) print(as.data.frame(flip %>% mutate(across(c(holo, anth), ~round(.x, 2)))), row.names = FALSE) else
  cat("  none with |r| > 0.2 in both eras\n")

# does the correction behave as its arithmetic says it must?
chk = holo_delta %>%
  select(correction, site, lake, offset, bin, variable, delta) %>%
  pivot_wider(names_from = correction, values_from = delta) %>%
  group_by(variable) %>%
  summarize(max_abs_diff = max(abs(corrected - raw), na.rm = TRUE), .groups = "drop") %>%
  mutate(kind = if_else(variable %in% PREC_VARS, "precip (multiplicative)", "temp (additive)"))
cat("\n=== does the bias correction cancel in a DELTA? ===\n")
cat("  additive corrections must cancel EXACTLY; multiplicative ones must not.\n")
print(as.data.frame(chk %>% mutate(max_abs_diff = signif(max_abs_diff, 3))), row.names = FALSE)
stopifnot(all(chk$max_abs_diff[!chk$variable %in% PREC_VARS] < 1e-9))


# =============================================================================
# PACE OF CHANGE - change divided by the interval it happened over
# =============================================================================
# This is where the eras become comparable, because each is divided by ITS OWN
# interval. Expressed PER CENTURY throughout.
#
#   Holocene      delta / 500 yr, pooled over all moving-window offsets
#   Anthropocene  delta / the gap between the two CLIMATE window midpoints
#                 (1984 -> adult year Y minus 2.5),
#                 because the change is between two window AVERAGES, not between
#                 two instants.
#
# ⚠ A rate measured over 500 yr and one measured over ~30 yr are not the same
# kind of number. Averaging over 500 yr suppresses everything faster than that,
# so the Holocene rate is a FLOOR on how fast climate actually moved. Reporting
# the Anthropocene as faster is therefore conservative in one direction and
# unfair in the other; say so rather than quietly dividing.
pace_holo = holo_delta %>%
  filter(correction == CORRECTION_IN_USE) %>%
  mutate(rate = delta / HOLO_BIN * 100) %>%
  group_by(lake, site, variable) %>%
  summarize(n_int = n(),
            min = min(rate, na.rm = TRUE),
            median = median(rate, na.rm = TRUE),
            max = max(rate, na.rm = TRUE),
            median_abs = median(abs(rate), na.rm = TRUE), .groups = "drop") %>%
  mutate(era = "holocene", interval_yr = HOLO_BIN, interval_min = HOLO_BIN, interval_max = HOLO_BIN)

pace_anth = anth_delta %>%
  mutate(rate = delta / climate_dt_years * 100) %>%
  group_by(lake = site, site, variable) %>%
  summarize(n_int = n(),
            interval_min = min(climate_dt_years), interval_max = max(climate_dt_years),
            interval_yr = median(climate_dt_years),
            min = min(rate, na.rm = TRUE),
            median = median(rate, na.rm = TRUE),
            max = max(rate, na.rm = TRUE),
            median_abs = median(abs(rate), na.rm = TRUE), .groups = "drop") %>%
  mutate(era = "anthropocene")

pace = bind_rows(pace_holo, pace_anth) %>%
  mutate(unit = paste0(UNIT(variable), "/century"),
         variable = factor(variable, levels = VARS)) %>%
  arrange(variable, era, site, lake) %>%
  select(variable, unit, era, site, lake, interval_yr, interval_min, interval_max, n_int, min, median, max, median_abs)

cat("\n\n=== PACE OF CHANGE, per century ===\n")
cat("  Holocene    : one value per consecutive ", HOLO_BIN,
    "-yr bin pair, pooled over ", length(OFFSETS), " moving-window offsets\n", sep = "")
cat("  Anthropocene: one value per PLOT, over that site's climate-window gap\n")
cat("  min/median/max are over those intervals (signed); median_abs ignores sign\n\n")
print(as.data.frame(pace %>% mutate(across(c(min, median, max, median_abs), ~ round(.x, 3)))),
      row.names = FALSE)

write_csv(pace, out("report/test_climate_pace_of_change.csv"))

cat("\n=== how many times faster is the Anthropocene? (median |rate|) ===\n")
ratio = pace %>% group_by(variable, site, era) %>%
  summarize(m = median(median_abs), .groups = "drop") %>%
  pivot_wider(names_from = era, values_from = m) %>%
  mutate(times_faster = round(anthropocene / holocene, 1),
         across(c(holocene, anthropocene), ~ round(.x, 3))) %>%
  arrange(site, desc(times_faster))
print(as.data.frame(ratio), row.names = FALSE)
cat("\n  ⚠ Read with the caveat above: the Holocene rate is a 500-yr average and\n",
    "  therefore a FLOOR. This ratio is an upper bound on the true speed-up.\n", sep = "")


# =============================================================================
# STEP 3 EVIDENCE - what does keeping precipitation COST the temperature record?
# =============================================================================
# derive_climate_vars() aligns the variables at month level: only months present
# for ALL of them are kept, so MWT and WP describe the same period. Necessary
# while precipitation is a CCA constraint. But V2.1 has no precipitation before
# 1979, so that rule pins MORA's legacy TEMPERATURE to 1979-1980 too - and the
# missing Jan 1979 then kills winter 1979, leaving ONE complete year.
#
# The pre-1979 temperature was downloaded (V2.1 daily, 1974-1978) and IS in
# output/mora_climate_parts/. The alignment strips it before MORA_climate.csv is
# written, so this test has to go back to the cache. No re-download is needed -
# dropping precipitation is a re-write of the download script's final step.
parts_dir = c(MORA = "mora_climate_parts", NOCA = "noca_climate_parts")
if (all(dir.exists(out(parts_dir)))) {

  cache = imap(parts_dir, function(d, s) {
    list.files(out(d), pattern = "csv$", full.names = TRUE) %>%
      purrr::map(read_csv, show_col_types = FALSE, progress = FALSE) %>% bind_rows() %>%
      mutate(site = s)
  }) %>% bind_rows()

  # window years in full, plus December of the lead-in year only - the pipeline's
  # rule. MUST match R/pipeline/04_modern_climate.R and R/pipeline/04_modern_climate.R.
  cache = cache %>% filter(id %in% plot_years$plot_id) %>%
    left_join(plot_years %>% select(site, id = plot_id, climate_start, climate_end),
      by = c("site", "id")) %>%
    mutate(key = paste(site, period, sep = ".")) %>%
    filter(if_else(period == "past", year >= 1979 & year <= 1989,
      (year >= climate_start & year <= climate_end) |
        (year == climate_start - 1L & month == 12)))

  build = function(dat) {
    dat %>% transmute(unit = id, period = key, variable, time = year, month, value) %>%
      derive_climate_vars(winter_shift = TRUE) %>% restrict_modern_seasons(plot_years) %>%
      separate_wider_delim(period, ".", names = c("site", "period"))
  }
  with_pr = build(cache)
  temp_only = build(cache %>% filter(variable != "pr"))

  yrs = function(a, lab) a %>% group_by(site, period) %>%
    summarize(across(any_of(TEMP_VARS), ~ round(sum(!is.na(.x)) / n_distinct(unit))),
              .groups = "drop") %>% mutate(config = lab)

  cat("\n\n=== STEP 3: complete season-years of TEMPERATURE per plot ===\n")
  print(as.data.frame(bind_rows(yrs(with_pr, "with precipitation"),
                                yrs(temp_only, "temperature only")) %>%
          relocate(config)), row.names = FALSE)

  d = function(a, st, nm) {
    x = a %>% filter(site == st)
    mean(x[[nm]][x$period == "present"], na.rm = TRUE) -
    mean(x[[nm]][x$period == "past"],    na.rm = TRUE)
  }
  step3 = expand_grid(site = c("MORA", "NOCA"), variable = TEMP_VARS) %>%
    mutate(with_pr = map2_dbl(site, variable, ~ d(with_pr, .x, .y)),
           temp_only = map2_dbl(site, variable, ~ d(temp_only, .x, .y)),
           shift = temp_only - with_pr) %>%
    mutate(across(c(with_pr, temp_only, shift), ~ round(.x, 2)))
  cat("\n=== Anthropocene warming (present - past, degC) under each option ===\n")
  print(as.data.frame(step3), row.names = FALSE)
  write_csv(step3, out("report/test_climate_step3_precip_cost.csv"))

  shift_max = max(abs(step3$shift), na.rm = TRUE)
  if (shift_max < 0.005) {
    cat("\n  ⚠ THIS TEST NOW RETURNS ZERO - and that is the answer, not a failure.\n",
        "  Under the OLD windows (survey year + the 5 before it) keeping precipitation\n",
        "  truncated MORA's legacy temperature to ONE usable year, and dropping it\n",
        "  recovered five - worth up to 1.28 degC on a single variable. The 2026-08-13\n",
        "  windows (past = 1979-1989 at both sites) removed that cost entirely: every\n",
        "  variable now has 10-11 complete legacy years whether precipitation is kept\n",
        "  or not.\n\n",
        "  CONSEQUENCE FOR STEP 3: the strongest argument for dropping precipitation -\n",
        "  'it costs MORA its temperature record' - is SUPERSEDED. The remaining\n",
        "  arguments stand on their own and must be judged without it:\n",
        "    - TraCE21k resolves WP and MWT worst (lag-1 autocorrelation 0.15 / 0.04)\n",
        "    - configured paleo constraints must remain within calibration ranges,\n",
        "      but pond-to-survey geography still contributes to projected offsets\n",
        "      (retired diagnostic test_paleo_anthro_climate_match.R; see git history)\n",
        "    - every window-selection anomaly that survives detrending is a\n",
        "      precipitation one (R/figures/supp_climate_windows.R)\n",
        "  Against them: the literature wants SNOWPACK, which needs MWT and WP.\n", sep = "")
  } else {
    cat("\n  Keeping precipitation costs the temperature record up to ",
        round(shift_max, 2), " degC on a single variable, because month-level alignment\n",
        "  ties temperature to precipitation's availability.\n", sep = "")
  }
} else {
  cat("\n(Precipitation-cost sensitivity skipped - the *_climate_parts/ caches are absent.)\n")
}

cat("\nWrote output/test_climate_change_variables.csv\n")
cat("Wrote output/test_climate_pace_of_change.csv\n")
cat("Wrote plot/test_figures/climate_holocene_timeseries.pdf\n")
