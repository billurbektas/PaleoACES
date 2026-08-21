# Per-site CCA variant of 05_cca_paleo.R --------------------------------------
# Instead of one pooled CCA (MORA + NOCA past plots), build a SEPARATE CCA for
# each site, trained on that site's "past" plots, then project that site's
# "present" and "paleo" samples onto its own model. The lag (observed-vs-
# predicted Euclidean distance in CCA1-CCA2) is therefore measured within each
# site's own ordination space. NOTE: because the two models are independent,
# absolute lag magnitudes are only loosely comparable between sites.
#
# Same species selection + output-label toggle as 05_cca_paleo.R.
if (!exists("extra_exclude")) extra_exclude = character(0)
if (!exists("cca_suffix"))    cca_suffix    = ""

color_mt = c("MORA" = "#648FFF", "NOCA" = "#FE6100")

# Data prep (mirrors 05_cca_paleo.R) -----------------------------------------
NOCA_occ  = read_csv(here("output/NOCA_occ.csv"),  show_col_types = FALSE)
MORA_occ  = read_csv(here("output/MORA_occ.csv"),  show_col_types = FALSE)
paleo_occ = read_csv(here("output/paleo_occ.csv"), show_col_types = FALSE)

occ = bind_rows(
  NOCA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "NOCA"),
  MORA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "MORA")
) %>%
  mutate(era = "anthropocene") %>%
  filter(!species %in% c("unknown", "Abies sp.", "Salix sp.")) %>%
  bind_rows(paleo_occ %>% select(period, plot_id, species, occurrence, site, era))

# Species selection: count.thr = 25 across modern + MORA paleo (+ toggle)
occ_summary = occ %>%
  filter(occurrence == 1) %>%
  group_by(site, period, species) %>%
  summarize(count = n(), .groups = "drop") %>%
  pivot_wider(names_from = c("site", "period"), values_from = "count", values_fill = 0)

count.thr = 25
takeoutsp = occ_summary %>%
  filter(MORA_past < count.thr & MORA_present < count.thr &
           NOCA_past < count.thr & NOCA_present < count.thr & MORA_paleo < count.thr) %>%
  pull(species) %>% unique()
takeoutsp = c(takeoutsp, "Tsuga heterophylla", extra_exclude)
occ = occ %>% filter(!species %in% takeoutsp)

# Environment (anthropocene from climate_summary, paleo from paleo_env)
climate_summary       = read_csv(here("output/climate_summary.csv"), show_col_types = FALSE)
paleo_climate_summary = read_csv(here("output/paleo_env.csv"),       show_col_types = FALSE)
env = bind_rows(
  climate_summary %>% select(site, era, period, plot_id, MWT, MST, WP, SpP) %>%
    filter(era == "anthropocene"),
  paleo_climate_summary %>% select(site, era, period, plot_id, MWT, MST, WP, SpP)
)

all_combinations = expand_grid(
  plot_id = unique(occ$plot_id),
  period  = unique(occ$period),
  species = unique(occ$species)
)
species_complete = all_combinations %>%
  left_join(occ, by = c("plot_id", "period", "species")) %>%
  mutate(occurrence = replace_na(occurrence, 0)) %>%
  select(plot_id, period, species, occurrence)

plot_site = occ %>% distinct(plot_id, site)

# Per-site CCA + lag ---------------------------------------------------------
make_wide = function(per, plots) {
  species_complete %>%
    filter(period == per, plot_id %in% plots) %>%
    group_by(plot_id, species) %>%
    summarize(occurrence = as.integer(sum(occurrence) > 0), .groups = "drop") %>%
    pivot_wider(names_from = species, values_from = occurrence, values_fill = 0) %>%
    column_to_rownames("plot_id")
}
make_env = function(per, site_name) {
  env %>%
    filter(period == per, site == site_name) %>%
    select(plot_id, MWT, MST, WP, SpP) %>%
    distinct() %>%
    column_to_rownames("plot_id") %>%
    filter(!is.na(MST))
}
build_site_result = function(site_name) {
  site_plots = plot_site %>% filter(site == site_name) %>% pull(plot_id)

  sp_past  = make_wide("past", site_plots)
  env_past = make_env("past", site_name)

  # Train on this site's past plots: align rows, keep occupied plots + species
  cp = intersect(rownames(sp_past), rownames(env_past))
  sp_past = sp_past[cp, , drop = FALSE]; env_past = env_past[cp, , drop = FALSE]
  ok = rowSums(sp_past) > 0
  sp_past = sp_past[ok, , drop = FALSE]; env_past = env_past[ok, , drop = FALSE]
  sp_past = sp_past[, colSums(sp_past) > 0, drop = FALSE]
  keep_species = colnames(sp_past)

  cca_s = cca(sp_past ~ MWT + MST + WP + SpP, data = env_past)

  project_period = function(per, era_label) {
    sp = make_wide(per, site_plots); en = make_env(per, site_name)
    cc = intersect(rownames(sp), rownames(en))
    if (length(cc) == 0) return(NULL)
    sp = sp[cc, keep_species, drop = FALSE]; en = en[cc, , drop = FALSE]
    pred = predict(cca_s, newdata = en, type = "lc")
    proj = predict(cca_s, newdata = sp, type = "wa")
    tibble(site = site_name, era = era_label, plot_id = cc,
           pred_CCA1 = pred[, 1], pred_CCA2 = pred[, 2],
           proj_CCA1 = proj[, 1], proj_CCA2 = proj[, 2]) %>%
      filter(!is.nan(proj_CCA1)) %>%
      mutate(lag = sqrt((pred_CCA1 - proj_CCA1)^2 + (pred_CCA2 - proj_CCA2)^2))
  }

  list(
    site           = site_name,
    env_scores     = scores(cca_s, display = "bp",      choices = 1:2),
    species_scores = scores(cca_s, display = "species", choices = 1:2),
    importance     = summary(cca_s)$cont$importance,
    comparison     = bind_rows(project_period("present", "anthropocene"),
                               project_period("paleo",   "holocene"))
  )
}

res_mora = build_site_result("MORA")
res_noca = build_site_result("NOCA")
lag_bysite = bind_rows(res_mora$comparison, res_noca$comparison)

# Per-site CCA ordination biplots (env arrows, species, pred->obs centroids) --
color_era_pp = c("anthropocene" = "#DC267F", "holocene" = "#785EF0")

plot_site_cca = function(res) {
  env_df = as_tibble(res$env_scores) %>% mutate(variable = rownames(res$env_scores))
  sp_df  = as_tibble(res$species_scores) %>% mutate(species = rownames(res$species_scores))
  comp   = res$comparison
  centroids = comp %>% group_by(era) %>%
    summarize(across(c(pred_CCA1, pred_CCA2, proj_CCA1, proj_CCA2), mean), .groups = "drop")
  ax = res$importance

  ggplot() +
    geom_hline(yintercept = 0, color = "grey80") +
    geom_vline(xintercept = 0, color = "grey80") +
    geom_segment(data = comp,
                 aes(pred_CCA1, pred_CCA2, xend = proj_CCA1, yend = proj_CCA2, color = era),
                 arrow = arrow(length = unit(0.07, "inches")), alpha = 0.08, size = 0.4) +
    geom_segment(data = env_df, aes(0, 0, xend = CCA1 * 2, yend = CCA2 * 2),
                 arrow = arrow(length = unit(0.2, "cm")), color = "black", size = 0.9) +
    geom_text(data = env_df, aes(CCA1 * 2.2, CCA2 * 2.2, label = variable),
              fontface = "bold", size = 3) +
    geom_text(data = sp_df, aes(CCA1, CCA2, label = species),
              color = "grey30", alpha = 0.7, size = 2.3) +
    geom_segment(data = centroids,
                 aes(pred_CCA1, pred_CCA2, xend = proj_CCA1, yend = proj_CCA2, color = era),
                 arrow = arrow(length = unit(0.25, "cm"), type = "closed"), size = 1.1) +
    geom_point(data = centroids, aes(pred_CCA1, pred_CCA2, color = era),
               shape = 21, fill = "white", size = 2, stroke = 1) +
    geom_point(data = centroids, aes(proj_CCA1, proj_CCA2, color = era), size = 2) +
    geom_text_repel(data = centroids,
                    aes(proj_CCA1, proj_CCA2, label = paste(era, "obs"), color = era),
                    size = 2.6, fontface = "bold") +
    scale_color_manual(values = color_era_pp) +
    labs(title = paste0(res$site, " CCA (own model)"),
         x = paste0("CCA1 (", round(ax[2, 1] * 100, 1), "%)"),
         y = paste0("CCA2 (", round(ax[2, 2] * 100, 1), "%)"),
         color = "Era") +
    theme_minimal()
}

p_bysite_cca = ggarrange(plot_site_cca(res_mora), plot_site_cca(res_noca),
                         ncol = 2, common.legend = TRUE, legend = "bottom")
print(p_bysite_cca)
pdf(file = here(paste0("plot/cca_bysite", cca_suffix, ".pdf")), height = 6, width = 13)
print(p_bysite_cca)
dev.off()

# Figure: paleo lag time series + anthropocene violin (same layout as 05) -----
lag_ymax = max(lag_bysite$lag, na.rm = TRUE)

paleo_lag = lag_bysite %>%
  filter(era == "holocene") %>%
  mutate(bp_year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[, 2]))

p_lag = ggplot(paleo_lag, aes(x = bp_year, y = lag, color = site)) +
  geom_point(alpha = 0.35, size = 1) +
  geom_smooth(method = "loess", span = 0.3, se = TRUE) +
  scale_x_reverse() +
  scale_color_manual(values = color_mt) +
  coord_cartesian(ylim = c(0, lag_ymax)) +
  labs(x = "Age (cal yr BP)",
       y = "Observed - predicted distance (CCA1-CCA2)",
       color = "Site",
       title = "Forest community-climate lag through time (per-site CCAs)",
       subtitle = "Separate CCA per site; paleo time series (left), anthropocene distribution (right)") +
  theme_minimal()

p_violin = ggplot(filter(lag_bysite, era == "anthropocene"),
                  aes(x = site, y = lag, fill = site)) +
  geom_violin(alpha = 0.6, scale = "width", trim = FALSE, color = NA) +
  geom_boxplot(width = 0.15, alpha = 0.9, outlier.size = 0.4) +
  scale_fill_manual(values = color_mt) +
  coord_cartesian(ylim = c(0, lag_ymax)) +
  labs(x = NULL, y = NULL, title = "Anthropocene") +
  theme_minimal() +
  theme(legend.position = "none", axis.text.y = element_blank())

p_lag_combined = ggarrange(p_lag, p_violin, ncol = 2, widths = c(4, 1),
                           align = "h", common.legend = TRUE, legend = "bottom")
print(p_lag_combined)

pdf(file = here(paste0("plot/paleo_lag_timeseries_bysite", cca_suffix, ".pdf")),
    height = 6, width = 11)
print(p_lag_combined)
dev.off()
