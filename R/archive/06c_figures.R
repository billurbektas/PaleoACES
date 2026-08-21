# =============================================================================
# 06c_figures.R - Figures 1 and 2 for the displacement metric
# =============================================================================
# Fig 1 (mechanism): A ordination with observed trajectories + demand arrows,
#                    B along_n vs across_n, C loadings.
# Fig 2 (quantities): A achieved vs clim_len against the 1:1 line,
#                     B tracking slope with 95% CI.
#
# Fig 3 (years behind) needs Step 5 and is not built here.
#
# Plotting convention for the Holocene: statistics use all n_shift moving-window
# shifts, but point clouds show shift 0 only. The shifts share samples, so
# plotting all of them would show each sample n_shift times.
# =============================================================================

library(here)
source(here("R/06b_displacements.R"))
library(ggrepel)
library(ggpubr)

base_theme = theme_minimal(base_size = 14) +
  theme(legend.title = element_blank(), legend.position = "bottom")
col_se = color_site_era

turn_plot = turn %>% filter(era == "anthropocene" | shift == 0)
n_lab = turn_plot %>% count(site, era) %>%
  mutate(lab = paste0(site, " ", era, ": n = ", n))

imp    = summary(cca_model)$cont$importance[2, ] * 100
ax_lab = paste0(c("CCA1", "CCA2"), " ", round(imp[1:2], 1), "%")

# =============================================================================
# FIGURE 1
# =============================================================================

## Panel A - ordination -------------------------------------------------------
env_df = as_tibble(scores(cca_model, display = "bp",      choices = 1:2), rownames = "variable")
sp_df  = as_tibble(scores(cca_model, display = "species", choices = 1:2), rownames = "species")

# Faint calibration plots (observed WA positions of the past training plots)
calib_df = scores_past %>% left_join(site_lookup, by = "plot_id")

# Holocene: 1000-yr centroids per site, from the raw samples (shift-independent).
holo_cent = paleo_samples %>%
  mutate(tbin = round(year / 1000) * 1000) %>%
  group_by(site, tbin) %>%
  summarize(across(c(obs1, obs2, pred1, pred2), mean), n = n(), .groups = "drop") %>%
  arrange(site, desc(tbin)) %>%                       # old -> young
  group_by(site) %>%
  mutate(dx = lead(pred1) - pred1, dy = lead(pred2) - pred2) %>%   # demand over next kyr
  ungroup() %>%
  mutate(grp = interaction(site, "holocene"), age_lab = paste0(tbin / 1000, " ka"))

# Anthropocene: one observed path per site, plus the demand over the interval.
anth_cent = pos %>%
  filter(era == "anthropocene") %>%
  group_by(site, time) %>%
  summarize(across(c(obs1, obs2, pred1, pred2), mean), .groups = "drop") %>%
  arrange(site, time) %>%
  group_by(site) %>%
  mutate(dx = lead(pred1) - pred1, dy = lead(pred2) - pred2) %>%
  ungroup() %>%
  mutate(grp = interaction(site, "anthropocene"))

traj = bind_rows(
  holo_cent %>% transmute(site, grp, obs1, obs2, ord = -tbin),
  anth_cent %>% transmute(site, grp, obs1, obs2, ord = time)
)

arrow_df = bind_rows(
  holo_cent %>% transmute(grp, obs1, obs2, dx, dy),
  anth_cent %>% transmute(grp, obs1, obs2, dx, dy)
) %>% filter(!is.na(dx))

pA = ggplot() +
  geom_hline(yintercept = 0, color = "grey88") +
  geom_vline(xintercept = 0, color = "grey88") +
  geom_point(data = calib_df, aes(obs1, obs2), color = "grey70",
             size = 0.5, alpha = 0.25) +
  # demand: what climate asked for over the following interval, anchored at the
  # observed position (HilleRisLambers et al. 2015, Objective 3)
  geom_segment(data = arrow_df, aes(obs1, obs2, xend = obs1 + dx, yend = obs2 + dy),
               arrow = arrow(length = unit(0.16, "cm"), type = "closed"),
               color = "grey35", linewidth = 0.5) +
  # response: what the forest actually did
  geom_path(data = traj %>% filter(str_detect(grp, "holocene")),
            aes(obs1, obs2, color = grp, group = grp), linewidth = 1) +
  geom_path(data = traj %>% filter(str_detect(grp, "anthropocene")),
            aes(obs1, obs2, color = grp, group = grp), linewidth = 1.2) +
  geom_point(data = traj, aes(obs1, obs2, color = grp), size = 2) +
  geom_segment(data = env_df, aes(0, 0, xend = CCA1 * 2, yend = CCA2 * 2),
               arrow = arrow(length = unit(0.2, "cm")), color = "black", linewidth = 0.9) +
  geom_text(data = env_df, aes(CCA1 * 2.2, CCA2 * 2.2, label = variable),
            fontface = "bold", size = 5) +
  geom_text_repel(data = holo_cent %>% filter(tbin %% 2000 == 0),
                  aes(obs1, obs2, label = age_lab, color = grp),
                  size = 3.5, show.legend = FALSE, max.overlaps = Inf) +
  scale_color_manual(values = col_se) +
  labs(x = ax_lab[1], y = ax_lab[2]) +
  base_theme

## Panel B - along_n vs across_n ---------------------------------------------
# Every interval rotated so demand points right and rescaled to unit length.
# (1, 0) = response exactly equal to demand. x < 0 = moved away from what
# climate asked. coord_fixed, otherwise the angles are unreadable.
# Ratios have heavy tails (short-demand intervals), so the panel is clipped at
# the 90th percentile of |ratio| and the excluded count is reported.
lim = quantile(abs(c(turn_plot$along_n, turn_plot$across_n)), 0.90, na.rm = TRUE)
n_out = turn_plot %>%
  summarize(n_out = sum(abs(along_n) > lim | abs(across_n) > lim), n = n())

pB = ggplot(turn_plot, aes(along_n, across_n, color = grp)) +
  geom_hline(yintercept = 0, color = "grey85") +
  geom_vline(xintercept = 0, color = "grey85") +
  geom_point(size = 1.4, alpha = 0.35) +
  geom_point(aes(x = 1, y = 0), inherit.aes = FALSE, shape = 21, size = 5,
             stroke = 1.2, color = "black", fill = NA) +
  annotate("text", x = 1, y = lim * 0.86, label = "response = demand",
           size = 3.6, hjust = 0.5) +
  scale_color_manual(values = col_se) +
  coord_fixed(xlim = c(-lim, lim), ylim = c(-lim, lim)) +
  labs(x = "achieved / demand", y = "sideways / demand") +
  base_theme

## Panel C - loadings ---------------------------------------------------------
sp_names = sp_df$species
load_df = bind_rows(
  as_tibble(scores(cca_model, display = "bp", choices = 1:2), rownames = "variable") %>%
    pivot_longer(starts_with("CCA"), names_to = "axis", values_to = "loading") %>%
    mutate(type = "Climate"),
  as_tibble(scores(cca_model, display = "species", choices = 1:2), rownames = "variable") %>%
    pivot_longer(starts_with("CCA"), names_to = "axis", values_to = "loading") %>%
    mutate(type = "Species")
) %>%
  mutate(axis = factor(axis, levels = c("CCA1", "CCA2"), labels = ax_lab))

ital_lab = function(x) parse(text = ifelse(x %in% sp_names,
                                           paste0("italic('", x, "')"), paste0("'", x, "'")))

pC = ggplot(load_df, aes(x = reorder(variable, abs(loading)), y = loading)) +
  geom_col(fill = "grey45") +
  facet_grid(type ~ axis, scales = "free_y", space = "free_y") +
  coord_flip() +
  scale_x_discrete(labels = ital_lab) +
  labs(x = NULL, y = "Loading") +
  base_theme + theme(strip.text = element_text(face = "bold"))

row_bc = ggarrange(pB, pC, ncol = 2, widths = c(1, 1.15), legend = "none",
                   labels = c("B", "C"), font.label = list(size = 16, face = "bold"))
fig1 = ggarrange(pA, row_bc, nrow = 2, heights = c(1.4, 1),
                 labels = c("A", ""), font.label = list(size = 16, face = "bold"),
                 common.legend = TRUE, legend = "bottom")

pdf(here(paste0("plot/fig1_displacement_mechanism", cca_suffix, ".pdf")), height = 13, width = 12)
print(fig1); dev.off()

# =============================================================================
# FIGURE 2
# =============================================================================

## Panel A - achieved vs demand length ---------------------------------------
# Shared axes on purpose: the question is distance from the 1:1 line, which is
# only readable if all four groups sit in one coordinate system. No stat_cor -
# a correlation answers a different question than "did it keep pace".
# coord_fixed so that "distance from the 1:1 line" is read at 45 degrees rather
# than distorted by the aspect ratio. y is therefore clipped to the x range and
# the number of points falling below is reported.
xmax = max(turn_plot$clim_len, na.rm = TRUE)
n_below = sum(turn_plot$achieved < -xmax, na.rm = TRUE)

fig2A = ggplot(turn_plot, aes(clim_len, achieved, color = grp)) +
  geom_hline(yintercept = 0, color = "grey85") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  annotate("text", x = xmax * 0.9, y = xmax * 0.97, label = "1:1", size = 4.5) +
  geom_point(size = 1.6, alpha = 0.4) +
  geom_smooth(method = "lm", formula = y ~ 0 + x, se = FALSE, linewidth = 1) +
  scale_color_manual(values = col_se) +
  coord_fixed(xlim = c(0, xmax), ylim = c(-xmax, xmax)) +
  labs(x = "demand length (CCA units)", y = "achieved (CCA units)") +
  base_theme

## Panel B - tracking slope with 95% CI --------------------------------------
slope_df = slopes %>%
  mutate(lab = paste0(site, "\n", str_sub(era, 1, 4), "."),
         lab = factor(lab, levels = c("MORA\nanth.", "NOCA\nanth.",
                                      "MORA\nholo.", "NOCA\nholo.")))

fig2B = ggplot(slope_df, aes(lab, slope, color = grp)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey40") +
  geom_hline(yintercept = 0, color = "grey85") +
  geom_text(data = tibble(lab = factor("MORA\nanth.", levels = levels(slope_df$lab))),
            aes(lab, 1), label = "gap stable", size = 3.6, hjust = 0, vjust = -0.7,
            inherit.aes = FALSE, color = "grey30") +
  geom_errorbar(aes(ymin = slope_lo, ymax = slope_hi), width = 0.12, linewidth = 0.9) +
  geom_point(size = 3.5) +
  scale_color_manual(values = col_se) +
  labs(x = NULL, y = "tracking slope   (achieved ~ 0 + demand)") +
  base_theme

fig2 = ggarrange(fig2A, fig2B, ncol = 2, widths = c(1.25, 1),
                 labels = c("A", "B"), font.label = list(size = 16, face = "bold"),
                 common.legend = TRUE, legend = "bottom")

pdf(here(paste0("plot/fig2_displacement_quantities", cca_suffix, ".pdf")), height = 7, width = 14)
print(fig2); dev.off()

# =============================================================================
# Caption material - every figure must state n and the dropped fraction
# =============================================================================
cat("\n=== Caption numbers ===\n")
cat("Intervals per site x era, and fraction dropped by the clim_len filter:\n")
print(as.data.frame(drop_report), row.names = FALSE)
cat("\nPoints shown in Fig 1B / Fig 2A (Holocene = moving-window shift 0 only,",
    "\nto avoid showing each sample", n_shift, "times):\n")
print(as.data.frame(n_lab %>% select(site, era, n)), row.names = FALSE)
cat("\nFig 1B axis limits clipped at +/-", round(lim, 2), "-",
    n_out$n_out, "of", n_out$n, "points fall outside.\n")
cat("Fig 2A y clipped to +/-", round(xmax, 2), "(equal aspect) -",
    n_below, "of", nrow(turn_plot), "points fall below.\n")
cat("\nWritten: plot/fig1_displacement_mechanism", cca_suffix, ".pdf",
    " and plot/fig2_displacement_quantities", cca_suffix, ".pdf\n", sep = "")
