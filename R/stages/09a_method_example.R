# =============================================================================
# 09a_method_example.R - worked example for the currently displayed metrics
# =============================================================================
# A methods figure, not a result. It follows a SINGLE interval at a SINGLE lake
# all the way through, with the actual numbers the analysis produced - so the
# machinery in R/stages/09_tracking_metrics.R can be checked by eye rather than taken
# on trust.
#
#   the example   PantherPotholes (NOCA), bin offset 0, using the valid
#                 consecutive primary bins nearest 3000 cal BP
#
#   reads   R/stages/09_tracking_metrics.R   (sourced - every number here is ITS output,
#                                      never recomputed, so the figure cannot
#                                      drift from the analysis it explains)
#   writes  plot/test_figures/fig_method_worked_example.pdf
#
# This implements the worked-method figure documented in README.md and
# docs/WORKFLOW.md; the former archived planning name is no longer authoritative.
#
# The four panels answer the four things that are actually confusing:
#   A  where a bin's CLIMATE comes from        -> average the native slices
#   B  why the VEGETATION side is uncertain    -> samples straddle the bin edge
#   C  what the two positions ARE              -> pred and obs in CCA space
#   D  what comes out                          -> the currently plotted metrics
# =============================================================================

library(here)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))
source(here("R/stages/09_tracking_metrics.R"))
library(patchwork)

MET_LAB = c(
  d_climate = "Delta predicted vegetation\n|| LC(t2) - LC(t1) ||",
  d_vegetation = "Delta vegetation\n|| obs(t2) - obs(t1) ||",
  d_offset = "Delta offset  (signed)\n|offset(t2)| - |offset(t1)|"
)
SHOW = names(MET_LAB)

LAKE   = "PantherPotholes"
SITE   = "NOCA"
OFF    = 0

# Choose a common-grid date retained in the final time series, then choose its
# real offset-0 interval. This keeps both the realization example (A-D) and the
# nested offset summary (E) synchronized with the configured primary interval
# width and with the actual fossil-sample support.
valid_grid = series %>%
  filter(site == SITE, metric %in% SHOW) %>%
  count(t, name = "n_metrics") %>%
  filter(n_metrics == length(SHOW)) %>%
  mutate(distance_from_target = abs(t - 3000)) %>%
  arrange(distance_from_target) %>%
  slice(1)
if (nrow(valid_grid) != 1) stop("Could not select a valid worked-example grid date")
GRID_T = valid_grid$t

example_interval = intervals %>%
  filter(site == SITE, offset == OFF, age_lo <= GRID_T, age_hi >= GRID_T) %>%
  count(age_hi, age_lo, name = "n_draws") %>%
  filter(n_draws > 0) %>%
  mutate(interval_mid = (age_hi + age_lo) / 2,
         distance_from_target = abs(interval_mid - GRID_T)) %>%
  arrange(distance_from_target, desc(n_draws)) %>%
  slice(1)
if (nrow(example_interval) != 1) stop("Could not select a valid worked-example interval")

BIN_T1 = example_interval$age_hi
BIN_T2 = example_interval$age_lo
BOUNDARY = (BIN_T1 + BIN_T2) / 2
EDGES = c(BIN_T2 - HOLO_BIN / 2, BOUNDARY, BIN_T1 + HOLO_BIN / 2)

fmt_range = function(lo, hi) paste0(format(lo, trim = TRUE), "-", format(hi, trim = TRUE))
T1_RANGE = fmt_range(BOUNDARY, max(EDGES))
T2_RANGE = fmt_range(min(EDGES), BOUNDARY)

# Two colours for the two bins. Deliberately NOT the MORA/NOCA palette - this
# figure is about one lake, and reusing the site colours here would read as a
# site contrast. Both are IBM colourblind-safe steps.
COL = c(t1 = "#785EF0", t2 = "#FFB000")
LAB = c(t1 = paste0("t1  ", T1_RANGE, " cal BP"),
        t2 = paste0("t2  ", T2_RANGE, " cal BP"))

base = theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold", size = 11),
        plot.subtitle = element_text(size = 8.5, colour = "grey35"),
        panel.grid.minor = element_blank(),
        legend.position = "top", legend.title = element_blank())

# -----------------------------------------------------------------------------
# A. The climate of a bin = the mean of its native CHELSA slices
# -----------------------------------------------------------------------------
sl = env_slice %>%
  filter(lake == LAKE, age >= min(EDGES), age < max(EDGES)) %>%
  mutate(bin = if_else(age < BOUNDARY, "t2", "t1")) %>%
  select(bin, age, all_of(CLIM_VARS)) %>%
  pivot_longer(all_of(CLIM_VARS), names_to = "variable", values_to = "value") %>%
  mutate(variable = factor(variable, levels = CLIM_VARS))

sl_mean = sl %>% group_by(bin, variable) %>%
  summarize(value = mean(value), .groups = "drop") %>%
  mutate(x0 = if_else(bin == "t1", max(EDGES), BOUNDARY),
         x1 = if_else(bin == "t1", BOUNDARY, min(EDGES)))

pA = ggplot(sl, aes(age, value, colour = bin)) +
  geom_vline(xintercept = EDGES, colour = "grey80", linewidth = 0.3) +
  geom_point(size = 1.6) +
  geom_segment(data = sl_mean, aes(x = x0, xend = x1, y = value, yend = value,
                                   colour = bin), linewidth = 0.9) +
  facet_wrap(~ variable, nrow = 1, scales = "free_y") +
  scale_x_reverse() +
  scale_colour_manual(values = COL, labels = LAB) +
  labs(x = "cal BP", y = NULL,
       title = paste0("A.  A bin's CLIMATE is the mean of its ",
                      N_CLIMATE_SLICES_PER_BIN, " native 100-yr CHELSA slices"),
       subtitle = paste0("Points = the native slices. Horizontal bar = the bin mean. ",
                         "The bin is a window on the TIME axis and TraCE21k slice ages are known\n",
                         "calendar dates, so this side of the calculation is FIXED - no age draw can move it.")) +
  base

# -----------------------------------------------------------------------------
# B. Which SAMPLES fall in a bin is uncertain - they straddle the edge
# -----------------------------------------------------------------------------
dr = paleo_age_draws() %>% filter(lake == LAKE)
near = dr %>% group_by(plot_id) %>%
  summarize(med = median(age), lo = quantile(age, 0.025), hi = quantile(age, 0.975),
            .groups = "drop") %>%
  filter(abs(med - BOUNDARY) < HOLO_BIN * 0.52) %>%
  arrange(med) %>%
  mutate(y = row_number(),
         straddles = lo < BOUNDARY & hi > BOUNDARY)

pB = ggplot(near) +
  geom_vline(xintercept = BOUNDARY, colour = "grey25", linewidth = 0.5) +
  geom_vline(xintercept = range(EDGES), colour = "grey80", linewidth = 0.3) +
  geom_segment(aes(x = lo, xend = hi, y = y, yend = y, colour = straddles),
               linewidth = 1.1, alpha = 0.85) +
  geom_point(aes(med, y), size = 0.9, colour = "grey20") +
  scale_x_reverse() +
  scale_colour_manual(values = c(`TRUE` = "#DC267F", `FALSE` = "grey65"),
                      labels = c(`TRUE` = "95% age range crosses the bin edge",
                                 `FALSE` = "stays on one side")) +
  labs(x = "cal BP", y = NULL,
       title = "B.  ...but which SAMPLES fall in it is not",
       subtitle = paste0("One line per macrofossil sample near the ", BOUNDARY,
                         " cal BP edge: its 95% Bacon age range,\n",
                         "dot = median age. ", sum(near$straddles), " of ", nrow(near),
                         " straddle the edge, so which bin they belong to changes from draw to draw.")) +
  base +
  theme(axis.text.y = element_blank(), legend.direction = "vertical")

# -----------------------------------------------------------------------------
# C. The two positions in CCA space
# -----------------------------------------------------------------------------
obs_ex = obs_bins %>%
  filter(site == SITE, offset == OFF, bin_mid %in% c(BIN_T1, BIN_T2)) %>%
  mutate(bin = if_else(bin_mid == BIN_T1, "t1", "t2"))
pred_ex = clim_bins %>%
  filter(site == SITE, offset == OFF, bin_mid %in% c(BIN_T1, BIN_T2)) %>%
  mutate(bin = if_else(bin_mid == BIN_T1, "t1", "t2"))

# the offset arrows are drawn from the MEDIAN obs of each bin, so there are two
# clean arrows rather than 200 overlapping ones
obs_med = obs_ex %>% group_by(bin) %>%
  summarize(o1 = median(o1), o2 = median(o2), .groups = "drop") %>%
  left_join(pred_ex %>% select(bin, p1, p2), by = "bin")

pC = ggplot() +
  geom_point(data = obs_ex, aes(o1, o2, colour = bin), size = 0.9, alpha = 0.30) +
  geom_segment(data = obs_med, aes(o1, o2, xend = p1, yend = p2, colour = bin),
               linewidth = 0.5, linetype = "22") +
  geom_point(data = obs_med, aes(o1, o2, colour = bin), size = 3, shape = 19) +
  geom_point(data = pred_ex, aes(p1, p2, colour = bin), size = 3.4, shape = 17) +
  geom_text(data = obs_med, aes(o1, o2, colour = bin, label = "obs"),
            nudge_y = 0.035, size = 3, fontface = "bold", show.legend = FALSE) +
  geom_text(data = pred_ex, aes(p1, p2, colour = bin, label = "pred"),
            nudge_y = -0.035, size = 3, fontface = "bold", show.legend = FALSE) +
  scale_colour_manual(values = COL, labels = LAB) +
  labs(x = "CCA1", y = "CCA2",
       title = "C.  Each bin gets TWO positions in the ordination",
       subtitle = paste0("Triangle = pred, from the bin's climate (one point - fixed). ",
                         "Faint dots = obs, one per age draw;\nlarge dot = their median. ",
                         "The dashed line is offset = pred - obs. The metrics are the lengths\n",
                         "of these things and how they change from t1 to t2.")) +
  base

# -----------------------------------------------------------------------------
# D. What comes out: the currently plotted metrics over the 100 draws
# -----------------------------------------------------------------------------
iv = intervals %>%
  filter(site == SITE, offset == OFF, age_hi == BIN_T1, age_lo == BIN_T2) %>%
  select(all_of(SHOW)) %>%
  pivot_longer(everything(), names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric, levels = SHOW, labels = MET_LAB[SHOW]))
if (!nrow(iv)) stop("The selected worked-example interval has no metric realizations")

iv_sum = iv %>% group_by(metric) %>%
  summarize(med = median(value), lo = quantile(value, 0.025),
            hi = quantile(value, 0.975), .groups = "drop") %>%
  mutate(lab = sprintf("median %.3f\n95%% %.3f to %.3f", med, lo, hi))

# The histogram is precomputed rather than left to geom_histogram, because
# d_climate has ZERO variance: with a free x scale and a bin count, ggplot
# stretches that single value into one bar filling the whole panel, which reads
# as a UNIFORM distribution - the exact opposite of what it is. Each metric gets
# its own padded range instead, so a zero-width distribution draws as a narrow
# spike and a wide one draws as a histogram.
NB = 26
iv_bars = iv %>%
  group_by(metric) %>%
  group_modify(function(g, k) {
    rng  = range(g$value)
    half = max(diff(rng) / 2, 0.02)          # floor, so a spike is not zero-wide
    ctr  = mean(rng)
    brks = seq(ctr - half * 1.3, ctr + half * 1.3, length.out = NB + 1)
    tibble(x = head(brks, -1) + diff(brks) / 2,
           w = diff(brks),
           n = as.integer(table(cut(g$value, brks, include.lowest = TRUE))))
  }) %>% ungroup()

pD = ggplot(iv_bars) +
  geom_col(aes(x, n, width = w), fill = "grey78", colour = NA) +
  geom_vline(data = iv_sum, aes(xintercept = med), colour = "#DC267F", linewidth = 0.7) +
  geom_vline(data = iv_sum, aes(xintercept = lo), colour = "#DC267F",
             linewidth = 0.4, linetype = "22") +
  geom_vline(data = iv_sum, aes(xintercept = hi), colour = "#DC267F",
             linewidth = 0.4, linetype = "22") +
  geom_text(data = iv_sum, aes(x = med, y = Inf, label = lab), vjust = 1.3,
            hjust = -0.06, size = 2.8, colour = "grey25") +
  facet_wrap(~ metric, nrow = 1, scales = "free") +
  labs(x = "CCA units", y = "age draws",
       title = "D.  The currently plotted metrics for this interval, over 100 age draws",
       subtitle = paste0(
         "LC-predicted vegetation displacement is a SPIKE because panel A is fixed. ",
         "The other two spread, because panel B is not.\n",
         "The pink median and dashed 95% are the realization-level quantities ",
         "summarized in the authoritative tracking tables for every interval,\n",
         "both sites, and ", length(OFFSETS), " bin offsets.")) +
  base

# -----------------------------------------------------------------------------
# E. ...and how those become one nested summary in the tracking tables
# -----------------------------------------------------------------------------
# Panels A-D used bin offset 0, i.e. ONE way to cut the timeline. The final
# figure combines all configured offsets, and the order matters (see the nesting block in
# R/stages/09_tracking_metrics.R). This panel shows that combination at the grid point
# sitting inside the worked interval, so it is the SAME two bins throughout.
#
# The selected grid point lies within the worked interval, so the offset-0 row
# here is panel D. It need not equal the interval midpoint because only grid
# dates supported by all configured offsets enter the combined time series.

bo = by_offset %>% filter(site == SITE, metric %in% SHOW, t == GRID_T)
se = series    %>% filter(site == SITE, metric %in% SHOW, t == GRID_T)
stopifnot(nrow(se) == length(SHOW), nrow(bo) == length(SHOW) * length(OFFSETS))

comb_lab = "COMBINED  = what the figure draws"
rows = bind_rows(
  bo %>% transmute(metric, kind = "offset",
                   lab = paste0("offset ", offset, if_else(offset == OFF,
                                                           "   <- panels A-D", "")),
                   ord = offset, med, lo, hi),
  se %>% transmute(metric, kind = "combined", lab = comb_lab,
                   ord = HOLO_BIN + 1, med = est, lo = age_lo, hi = age_hi)
) %>%
  mutate(metric = factor(metric, levels = SHOW, labels = MET_LAB[SHOW]),
         lab    = fct_reorder(lab, -ord))

pE = ggplot(rows, aes(med, lab, colour = kind)) +
  geom_linerange(data = rows %>% filter(kind == "combined"),
                 aes(xmin = lo, xmax = hi), linewidth = 4, alpha = 0.22) +
  # geom_errorbar + orientation, not geom_errorbarh: the latter is deprecated in
  # ggplot2 4.0 and silently translates `height` to `width`.
  geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0.24,
                linewidth = 0.5) +
  geom_point(aes(size = kind)) +
  facet_wrap(~ metric, nrow = 1, scales = "free_x") +
  scale_colour_manual(values = c(offset = "grey45", combined = "#DC267F"),
                      guide = "none") +
  scale_size_manual(values = c(offset = 1.9, combined = 3.1), guide = "none") +
  labs(x = "CCA units", y = NULL,
       title = paste0("E.  ...and how the ", length(OFFSETS),
                      " bin offsets become ONE point and ONE band, at t = ",
                      GRID_T, " cal BP"),
       subtitle = paste0(
         "Grey rows: each offset ON ITS OWN - dot = median over its ", N_DRAWS,
         " age draws, bar = its 2.5-97.5. The offset-0 row IS panel D.\n",
         "Pink row: dot = MEDIAN OF THE ", length(OFFSETS),
         " GREY DOTS (the retained nested estimate); ",
         "band = MEDIAN OF THE ", length(OFFSETS), " GREY BAR ENDS (the ribbon).\n",
         "The ribbon is therefore the TYPICAL age-uncertainty band - not a sum of the offsets, ",
         "and not an envelope. An envelope would be whichever offset happened to be\n",
         "widest, so it would keep growing the more offsets were tried; the median does not. ",
         "Bin phase is NOT in the ribbon - it is the spread of the grey dots, drawn as the\n",
         "thin lines on the final figure.")) +
  base +
  theme(axis.text.y = element_text(size = 8),
        panel.grid.major.y = element_blank())

fig = pA / (pB | pC) / pD / pE +
  plot_layout(heights = c(0.85, 1.25, 0.95, 0.80)) +
  plot_annotation(
    title = paste0("How the currently plotted metrics are built - one real interval at ", LAKE,
                   " (", SITE, "), bin offset ", OFF),
    subtitle = paste0("Every number is taken from R/stages/09_tracking_metrics.R, not recomputed. ",
                      "Bins are ", HOLO_BIN, " yr wide; ", N_DRAWS,
                      " Bacon age draws; this is 1 of the ", length(OFFSETS), " bin offsets."),
    theme = theme(plot.title = element_text(face = "bold", size = 14),
                  plot.subtitle = element_text(colour = "grey30", size = 9.5)))

if (render_figures) {
  pdf(here("plot/test_figures/fig_method_worked_example.pdf"),
      width = 14, height = 17)
  print(fig)
  dev.off()
}

cat("\n=== the numbers in the figure ===\n")
cat("\nA. bin climate (mean of ", N_CLIMATE_SLICES_PER_BIN, " slices):\n", sep = "")
print(as.data.frame(pred_ex %>% select(bin, all_of(CLIM_VARS), p1, p2)), digits = 4,
      row.names = FALSE)
cat("\nB. samples near the ", BOUNDARY, " edge: ", nrow(near), ", of which ", sum(near$straddles),
    " have a 95% age range crossing it\n", sep = "")
cat("\nC. obs, median over draws:\n")
print(as.data.frame(obs_med %>% select(bin, o1, o2)), digits = 4, row.names = FALSE)
cat("\nD. metrics over ", nrow(iv) / length(SHOW), " draws:\n", sep = "")
print(as.data.frame(iv_sum %>% select(-lab)), digits = 3, row.names = FALSE)

cat("\nE. the ", length(OFFSETS), " offsets at t = ", GRID_T,
    " cal BP, and their combination:\n", sep = "")
print(as.data.frame(rows %>%
  mutate(metric = sub("\n.*", "", as.character(metric))) %>%
  select(metric, lab, lo, med, hi) %>% arrange(metric, desc(lab))),
  digits = 3, row.names = FALSE)
if (render_figures) {
  cat("\nWritten: plot/test_figures/fig_method_worked_example.pdf\n")
} else {
  cat("\nFigure rendering skipped; worked-example audit tables were refreshed.\n")
}
