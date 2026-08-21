# Synthesis figures (SUBSET: without Taxus brevifolia, Acer circinatum, Pinus ponderosa)
# Reuses the subset pooled CCA from 05_cca_paleo.R.
extra_exclude = c("Taxus brevifolia", "Acer circinatum", "Pinus ponderosa")
cca_suffix    = "_subset"
source(here("R/05_cca_model.R"))

base_theme = theme_minimal(base_size = 14) +
  theme(legend.title = element_blank(), legend.position = "bottom")
col_se  = color_site_era
col_all = c(col_se, color_mt)   # adds MORA / NOCA site colors for the Past markers

comparison_df = comparison_df %>% mutate(grp = interaction(site, era))

# Axis variance explained (%) and labels (no parentheses)
imp    = summary(cca_model)$cont$importance[2, ] * 100
ax_lab = paste0(names(imp)[1:3], " ", round(imp[1:3], 1), "%")   # "CCA1 11%" ...

# Observed (WA) positions of the PAST calibration plots + per-site centroid
past_obs_df = bind_cols(
  tibble(plot_id = rownames(species_past_final)),
  as_tibble(predict(cca_model, newdata = species_past_final, type = "wa")[, 1:2])
) %>%
  rename(o1 = CCA1, o2 = CCA2) %>%
  left_join(env %>% filter(period == "past") %>% distinct(plot_id, site), by = "plot_id")
past_centroid = past_obs_df %>% group_by(site) %>%
  summarize(o1 = mean(o1), o2 = mean(o2), .groups = "drop")

# =====================================================================
# FIGURE 1 : CCA  |  2D-distance boxplots  |  axis contributions
# =====================================================================

## Panel A - CCA biplot ------------------------------------------------------
env_df = as_tibble(scores(cca_model, display = "bp",      choices = 1:2), rownames = "variable")
sp_df  = as_tibble(scores(cca_model, display = "species", choices = 1:2), rownames = "species")
cent = comparison_df %>%
  group_by(site, era, grp) %>%
  summarize(pred1 = mean(predicted_CCA1), pred2 = mean(predicted_CCA2),
            proj1 = mean(projected_CCA1), proj2 = mean(projected_CCA2), .groups = "drop")
underlying   = comparison_df %>% transmute(grp, x = projected_CCA1, y = projected_CCA2)
cent_anthro  = cent %>% filter(era == "anthropocene")

# Past -> Present resurvey link (same plots)
traj = bind_rows(
  past_centroid %>% transmute(site, stage = 1, x = o1,    y = o2),
  cent_anthro   %>% transmute(site, stage = 2, x = proj1, y = proj2)
) %>% arrange(site, stage)

# Holocene Pred vs Obs per 1000-yr step (disequilibrium at each millennium)
paleo_bins = comparison_df %>%
  filter(era == "holocene", !is.nan(projected_CCA1)) %>%
  mutate(year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[, 2]),
         tbin = round(year / 1000) * 1000) %>%
  group_by(site, grp, tbin) %>%
  summarize(ox = mean(projected_CCA1), oy = mean(projected_CCA2),
            px = mean(predicted_CCA1), py = mean(predicted_CCA2), .groups = "drop") %>%
  arrange(site, desc(tbin)) %>%
  mutate(age_lab = paste0(tbin / 1000, "kBP"))

# Zoom to displayed elements (clips far underlying points; CCA itself unchanged)
zx = range(c(env_df$CCA1 * 2.2, cent_anthro$pred1, cent_anthro$proj1, past_centroid$o1, paleo_bins$ox, paleo_bins$px))
zy = range(c(env_df$CCA2 * 2.2, cent_anthro$pred2, cent_anthro$proj2, past_centroid$o2, paleo_bins$oy, paleo_bins$py))
zx = zx + c(-0.15, 0.15) * diff(zx); zy = zy + c(-0.15, 0.15) * diff(zy)

# Present Pred/Obs + Past labels (one repel layer)
lab_df = bind_rows(
  cent_anthro %>% transmute(x = pred1, y = pred2, label = "Pred", ckey = as.character(grp)),
  cent_anthro %>% transmute(x = proj1, y = proj2, label = "Obs",  ckey = as.character(grp)),
  past_centroid %>% transmute(x = o1, y = o2, label = "Past", ckey = site)
)

pA = ggplot() +
  geom_hline(yintercept = 0, color = "grey85") +
  geom_vline(xintercept = 0, color = "grey85") +
  geom_point(data = underlying,  aes(x, y, color = grp), size = 0.6, alpha = 0.1) +
  geom_point(data = past_obs_df, aes(o1, o2, color = site), size = 0.6, alpha = 0.1, show.legend = FALSE) +
  geom_segment(data = env_df, aes(0, 0, xend = CCA1 * 2, yend = CCA2 * 2),
               arrow = arrow(length = unit(0.2, "cm")), color = "black", linewidth = 0.9) +
  geom_text(data = env_df, aes(CCA1 * 2.2, CCA2 * 2.2, label = variable), fontface = "bold", size = 6) +
  geom_path(data = traj, aes(x, y, group = site), color = "grey40", linewidth = 0.7, linetype = "dotted") +
  geom_segment(data = paleo_bins, aes(px, py, xend = ox, yend = oy, color = grp),
               arrow = arrow(length = unit(0.1, "cm"), type = "closed"), linewidth = 0.5) +
  geom_point(data = paleo_bins, aes(px, py, color = grp), shape = 21, fill = "white", size = 1.4, stroke = 0.6) +
  geom_point(data = paleo_bins, aes(ox, oy, color = grp), size = 1.6) +
  geom_text_repel(data = paleo_bins, aes(ox, oy, label = age_lab, color = grp),
                  size = 4, show.legend = FALSE, max.overlaps = Inf, segment.size = 0.2) +
  geom_segment(data = cent_anthro, aes(pred1, pred2, xend = proj1, yend = proj2, color = grp),
               arrow = arrow(length = unit(0.2, "cm"), type = "closed"), linewidth = 0.7) +
  geom_point(data = cent_anthro, aes(pred1, pred2, color = grp), shape = 21, fill = "white", size = 3, stroke = 1.1) +
  geom_point(data = cent_anthro, aes(proj1, proj2, color = grp), size = 3) +
  geom_point(data = past_centroid, aes(o1, o2, color = site), shape = 18, size = 4.5, show.legend = FALSE) +
  geom_text_repel(data = lab_df, aes(x, y, label = label, color = ckey),
                  size = 5, fontface = "bold", show.legend = FALSE,
                  box.padding = 0.6, max.overlaps = Inf, min.segment.length = 0) +
  scale_color_manual(values = col_all, breaks = names(col_se)) +
  coord_cartesian(xlim = zx, ylim = zy) +
  labs(x = ax_lab[1], y = ax_lab[2]) +
  base_theme +
  theme(axis.title = element_text(size = 18), axis.text = element_text(size = 14))

## Panel B - 2D distance boxplots, within-site era test ----------------------
era_tests = comparison_df %>%
  group_by(site) %>%
  summarize(p = wilcox.test(euclidean_dist_2D ~ era)$p.value,
            y = max(euclidean_dist_2D), .groups = "drop") %>%
  mutate(label = paste0("Wilcoxon p = ", signif(p, 2)))

pB = ggplot(comparison_df, aes(x = era, y = euclidean_dist_2D, fill = grp)) +
  geom_boxplot(outlier.size = 0.5, width = 0.6) +
  facet_wrap(~site, scales = "free_x") +
  geom_segment(data = era_tests, aes(x = 1, xend = 2, y = y * 1.08, yend = y * 1.08), inherit.aes = FALSE) +
  geom_text(data = era_tests, aes(x = 1.5, y = y * 1.13, label = label), inherit.aes = FALSE, size = 4) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.18))) +
  scale_fill_manual(values = col_se) +
  labs(x = NULL, y = "Forest community lag") +
  base_theme

## Panel C - axis contributions: climate + species loadings -----------------
sp_names = sp_df$species
load_df = bind_rows(
  as_tibble(scores(cca_model, display = "bp",      choices = 1:2), rownames = "variable") %>%
    pivot_longer(starts_with("CCA"), names_to = "axis", values_to = "loading") %>% mutate(type = "Climate"),
  as_tibble(scores(cca_model, display = "species", choices = 1:2), rownames = "variable") %>%
    pivot_longer(starts_with("CCA"), names_to = "axis", values_to = "loading") %>% mutate(type = "Species")
) %>%
  mutate(axis = factor(axis, levels = c("CCA1", "CCA2"), labels = ax_lab[1:2]))

# italicize species names only (climate codes stay upright)
ital_lab = function(x) parse(text = ifelse(x %in% sp_names, paste0("italic('", x, "')"), paste0("'", x, "'")))

pC = ggplot(load_df, aes(x = reorder(variable, abs(loading)), y = loading)) +
  geom_col(fill = "grey45") +
  facet_grid(type ~ axis, scales = "free_y", space = "free_y") +
  coord_flip() +
  scale_x_discrete(labels = ital_lab) +
  labs(x = NULL, y = "Loading") +
  base_theme + theme(strip.text = element_text(face = "bold"))

row_bc = ggarrange(pB, pC, ncol = 2, widths = c(1, 1.3), legend = "none",
                   labels = c("B", "C"), font.label = list(size = 16, face = "bold"))
fig1 = ggarrange(pA, row_bc, nrow = 2, heights = c(1.5, 1),
                 labels = c("A", ""), font.label = list(size = 16, face = "bold"),
                 common.legend = TRUE, legend = "bottom")
pdf(file = here("plot/fig1_cca_box_loadings_subset.pdf"), height = 13, width = 12)
print(fig1)
dev.off()

# =====================================================================
# FIGURE 2 : turnover-rate scatter (faceted)  |  mismatch vs clim-dist
# =====================================================================

## Turnover (CCA displacement) and rates per year ----------------------------
anthro_dt = c(MORA = 40, NOCA = 32)   # 1975->2015, 1983->2015

tp        = rownames(species_past_final)
past_obs  = predict(cca_model, newdata = species_past_final, type = "wa")
past_pred = predict(cca_model, newdata = env_past_final,     type = "lc")
past_tab    = tibble(plot_id = tp, o1 = past_obs[,1], o2 = past_obs[,2], p1 = past_pred[,1], p2 = past_pred[,2])
present_tab = tibble(plot_id = rownames(projected_present),
                     o1 = projected_present[,1], o2 = projected_present[,2],
                     p1 = predicted_present[,1], p2 = predicted_present[,2])
site_lookup = env %>% filter(period == "past") %>% distinct(plot_id, site)

anthro_turn = inner_join(past_tab, present_tab, by = "plot_id", suffix = c("_a", "_b")) %>%
  left_join(site_lookup, by = "plot_id") %>%
  filter(!is.nan(o1_b)) %>%
  transmute(site, era = "anthropocene", endpoint = plot_id,
            veg_turn  = sqrt((o1_b - o1_a)^2 + (o2_b - o2_a)^2),
            clim_turn = sqrt((p1_b - p1_a)^2 + (p2_b - p2_a)^2),
            dt = anthro_dt[site])

# Bin paleo to ~100 yr (CHELSA-TraCE climate resolution) before computing rates,
# so each step spans a real centennial climate change rather than sub-centennial
# spline interpolation. Aggregate CCA positions (observed WA + predicted LC) per
# bin, then take turnover between consecutive bins. Climate change is still the
# CCA (predicted/LC) displacement - just per century.
bin_width = 100
paleo_turn = comparison_df %>%
  filter(era == "holocene", !is.nan(projected_CCA1)) %>%
  mutate(lake = str_match(plot_id, "^(.*)_-?\\d+_BP$")[,2],
         year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[,2]),
         bin  = round(year / bin_width) * bin_width) %>%
  group_by(site, lake, bin) %>%
  summarize(proj1 = mean(projected_CCA1), proj2 = mean(projected_CCA2),
            pred1 = mean(predicted_CCA1), pred2 = mean(predicted_CCA2), .groups = "drop") %>%
  arrange(site, lake, bin) %>%
  group_by(site, lake) %>%
  mutate(veg_turn  = sqrt((proj1 - lag(proj1))^2 + (proj2 - lag(proj2))^2),
         clim_turn = sqrt((pred1 - lag(pred1))^2 + (pred2 - lag(pred2))^2),
         dt = bin - lag(bin)) %>%
  ungroup() %>%
  filter(!is.na(veg_turn), dt > 0) %>%
  transmute(site, era = "holocene", endpoint = paste0(lake, "_", bin, "_BP"), veg_turn, clim_turn, dt)

turn = bind_rows(anthro_turn, paleo_turn) %>%
  # forest community rate over the survey interval (dt = 40/32 yr anthro, 100 yr paleo);
  # climate rate over the climate-window interval (1983.5->2014.5 = 31 yr anthro, 100 yr paleo)
  mutate(clim_dt   = if_else(era == "anthropocene", 31, dt),
         veg_rate  = veg_turn / dt,
         clim_rate = clim_turn / clim_dt,
         grp = interaction(site, era))

# Drop NOCA forest community-turnover-rate outliers (upper 1.5 x IQR fence)
noca_fence = turn %>% filter(site == "NOCA") %>%
  summarize(f = quantile(veg_rate, 0.75) + 1.5 * IQR(veg_rate)) %>% pull(f)
turn = turn %>% filter(!(site == "NOCA" & veg_rate > noca_fence))

# Residuals from SITE x ERA specific models
turn = turn %>% group_by(grp) %>%
  mutate(residual = resid(lm(veg_rate ~ clim_rate))) %>% ungroup()

## Panel A - turnover rate vs climate change rate, faceted by site -----------
fig2A = ggplot(turn, aes(x = clim_rate, y = veg_rate, color = grp)) +
  geom_point(alpha = 0.45, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.9) +
  stat_cor(aes(color = grp), method = "pearson", show.legend = FALSE, size = 4) +
  facet_wrap(~era, scales = "free") +
  scale_color_manual(values = col_se) +
  labs(x = "Climate change rate",
       y = "Forest community turnover rate") +
  base_theme

## Panel B - climatic distance vs mismatch, colored by site x era -----------
b2 = lag_std %>% mutate(grp = interaction(site, era))

fig2B = ggplot(b2, aes(x = clim_dist, y = euclidean_dist_2D, color = grp)) +
  geom_point(alpha = 0.45, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.9) +
  stat_cor(aes(color = grp), method = "pearson", show.legend = FALSE, size = 4) +
  scale_color_manual(values = col_se) +
  labs(x = "Climatic distance",
       y = "Forest community mismatch") +
  base_theme

fig2 = ggarrange(fig2A, fig2B, nrow = 2, heights = c(1, 1),
                 labels = c("A", "B"), font.label = list(size = 16, face = "bold"),
                 common.legend = TRUE, legend = "bottom")
pdf(file = here("plot/fig2_turnoverrate_residual_subset.pdf"), height = 13, width = 10)
print(fig2)
dev.off()

cat("\nResidual now = per (site x era) lm(veg_rate ~ clim_rate); centered within each group.\n")
turn %>% group_by(site, era) %>%
  summarize(n = n(), med_veg_rate = round(median(veg_rate), 4),
            med_clim_rate = round(median(clim_rate), 4), .groups = "drop") %>% print()
