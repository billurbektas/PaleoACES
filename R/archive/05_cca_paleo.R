# Run configuration ----
# Full run (default): extra_exclude = character(0), cca_suffix = "".
# Subset run: extra_exclude = c("Taxus brevifolia", "Acer circinatum", "Pinus ponderosa")
#             and cca_suffix = "_subset".
# Set these before source()-ing this script to override (e.g. from R/05b_cca_bysite.R).
if (!exists("extra_exclude")) extra_exclude = character(0)
if (!exists("cca_suffix"))    cca_suffix    = ""

# Harmonize both datasets ----
NOCA_occ = read_csv(here("output/NOCA_occ.csv"))
MORA_occ = read_csv(here("output/MORA_occ.csv"))
paleo_occ = read_csv(here("output/paleo_occ.csv"))

occ = bind_rows(NOCA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "NOCA"),
                MORA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "MORA")) %>%
  mutate(era = "anthropocene") %>%
  filter(!species %in% c("unknown", "Abies sp.", "Salix sp."))%>%
  bind_rows(
    paleo_occ %>% select(period, plot_id, species, occurrence, site, era)
  )
  

# Get frequencies ----
occ_summary = 
  occ %>% 
  filter(occurrence == 1)%>%
  group_by(site, period, species)%>%
  summarize(count = n())%>%
  pivot_wider(names_from = c("site", "period"), values_from = "count", values_fill = 0)

count.thr = 25
takeoutsp = 
  occ_summary %>%
  ungroup()%>%
  filter(MORA_past<count.thr & MORA_present<count.thr & NOCA_past<count.thr & NOCA_present<count.thr & MORA_paleo < count.thr)

takeoutsp =
  takeoutsp %>%
  pull(species)%>%
  unique()

takeoutsp = c(takeoutsp, "Tsuga heterophylla", extra_exclude)

occ = occ %>% filter(!species %in% takeoutsp)
length(unique(occ$species)) # 14 species left

# Harmonize with climate & fire data ----
NOCA_plot_info_fire = read_csv(here("output/NOCA_plot_info_fire.csv"))
MORA_plot_info_fire = read_csv(here("output/MORA_plot_info_fire.csv"))
paleo_info_fire = read_csv(here("output/paleo_fire.csv")) %>%
  mutate(burnt = ifelse(fire_peak_magnitude>0, TRUE, FALSE)) %>%
  mutate(site = "MORA",
         era = "holocene")
  
fire_summary = bind_rows(NOCA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "NOCA"),
                         MORA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "MORA")) %>%
  mutate(era = "anthropocene")%>%
  bind_rows(paleo_info_fire %>% select(plot_id, burnt, site, era))

climate_summary = read_csv(here("output/climate_summary.csv"))
paleo_climate_summary = read_csv(here("output/paleo_env.csv"))

env = 
  bind_rows(climate_summary %>% select(site, era, period, plot_id, MWT, MST, WP, SpP) %>%
              filter(era == "anthropocene"),
            paleo_climate_summary %>% select(site, era, period, plot_id, MWT, MST, WP, SpP))%>%
  left_join(fire_summary)
  

## CCA ----
all_combinations = expand_grid(
  plot_id = unique(occ$plot_id),
  period = unique(occ$period),
  species = unique(occ$species)
)

species_complete = all_combinations %>%
  left_join(occ) %>%
  mutate(occurrence = replace_na(occurrence, 0)) %>%
  select(plot_id, period, species, occurrence)

species_past = species_complete %>%
  filter(period == "past") %>%
  select(-period) %>%
  pivot_wider(names_from = species, values_from = occurrence, values_fill = 0) %>%
  column_to_rownames("plot_id")

species_present = species_complete %>%
  filter(period == "present") %>%
  select(-period) %>%
  pivot_wider(names_from = species, values_from = occurrence, values_fill = 0) %>%
  column_to_rownames("plot_id")

env_past = env %>%
  filter(period == "past") %>%
  select(plot_id, MWT, MST, WP, SpP) %>%
  column_to_rownames("plot_id")

env_present = env %>%
  filter(period == "present") %>%
  select(plot_id, MWT, MST, WP, SpP) %>%
  column_to_rownames("plot_id")

env_paleo = env %>%
  filter(period == "paleo") %>%
  select(plot_id, MWT, MST, WP, SpP) %>%
  column_to_rownames("plot_id")%>%
  filter(!is.na(MST))

species_paleo = species_complete %>%
  filter(period == "paleo") %>%
  filter(plot_id %in% rownames(env_paleo))%>%
  distinct()%>%
  select(-period) %>%
  group_by(species, plot_id)%>% # You need to check why there are duplicates!
  summarize(occurrence = sum(occurrence))%>%
  mutate(occurrence = ifelse(occurrence>0, 1, 0))%>%
  pivot_wider(names_from = species, values_from = occurrence, values_fill = 0) %>%
  column_to_rownames("plot_id")

# Keep paleo env and species in the same row order so the predicted (env-based)
# and projected (species-based) scores line up by plot_id when combined below.
common_paleo = intersect(rownames(env_paleo), rownames(species_paleo))
env_paleo = env_paleo[common_paleo, , drop = FALSE]
species_paleo = species_paleo[common_paleo, , drop = FALSE]

common_past = intersect(rownames(species_past), rownames(env_past))
species_past_matched = species_past[common_past, ]
env_past_matched = env_past[common_past, ]

valid_plots = rowSums(species_past_matched) > 0
species_past_final = species_past_matched[valid_plots, ]
env_past_final = env_past_matched[valid_plots, ] %>% select(MWT, MST, WP, SpP)

cca_model = cca(species_past_final ~ MWT + MST + WP + SpP, data = env_past_final)
anova(cca_model)
anova(cca_model, by = "axis")
anova(cca_model, by = "terms")
RsquareAdj(cca_model)

common_present = intersect(rownames(species_present), rownames(env_present))
species_present_matched = species_present[common_present, ]
env_present_matched = env_present[common_present, ]

species_present_final = species_present_matched[valid_plots, ]
env_present_final = env_present_matched[valid_plots, ] %>% select(MWT, MST, WP, SpP)

predicted_present = predict(cca_model, newdata = env_present_final[,colnames(env_present_final)], type = "lc")
projected_present = predict(cca_model, newdata = species_present_final, type = "wa")

predicted_paleo = predict(cca_model, newdata = env_paleo, type = "lc")
projected_paleo = predict(cca_model, newdata = species_paleo, type = "wa")


# Get site and fire information for plotting
site_fire_info_past = env %>%
  filter(period == "past") %>%
  select(plot_id, site, burnt) %>%
  filter(plot_id %in% rownames(species_past_final))

site_fire_info_present = env %>%
  filter(period == "present") %>%
  select(plot_id, site, burnt) %>%
  filter(plot_id %in% rownames(species_present_final))

site_fire_info_paleo = env %>%
  filter(period == "paleo") %>%
  select(plot_id, site, burnt) %>%
  filter(plot_id %in% rownames(species_paleo))

# Extract scores for visualization INCLUDING CCA3
past_sites = scores(cca_model, display = "sites", choices = 1:3)
species_scores = scores(cca_model, display = "species", choices = 1:3)
env_scores = scores(cca_model, display = "bp", choices = 1:3)

# Identify top contributing species
species_contribution = sqrt(species_scores[,1]^2 + species_scores[,2]^2)
top_species = names(sort(species_contribution, decreasing = TRUE))

# Create plotting dataframes
sites_df = as_tibble(past_sites) %>%
  mutate(plot_id = rownames(past_sites)) %>%
  left_join(site_fire_info_past, by = "plot_id")

species_df = as_tibble(species_scores) %>%
  mutate(species = rownames(species_scores)) %>%
  filter(species %in% top_species)

env_df = as_tibble(env_scores) %>%
  mutate(variable = rownames(env_scores))

comparison_df = tibble(
  plot_id = rownames(species_present_final),
  predicted_CCA1 = predicted_present[,1],
  predicted_CCA2 = predicted_present[,2],
  predicted_CCA3 = predicted_present[,3],
  projected_CCA1 = projected_present[,1],
  projected_CCA2 = projected_present[,2],
  projected_CCA3 = projected_present[,3]
) %>%
  left_join(site_fire_info_present, by = "plot_id")%>%
  filter(!is.nan(projected_CCA1))

# Visualization 1: Enhanced CCA biplot with environmental vectors and top species
color_mt = c("MORA" = "#648FFF", "NOCA" = "#FE6100")

# Visualization 2: Predicted vs Observed correlation
p2 = ggplot(comparison_df, aes(predicted_CCA1, projected_CCA1, color = site)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  scale_color_manual(values = color_mt) +
  scale_shape_manual(values = c("TRUE" = 17, "FALSE" = 16),
                     labels = c("TRUE" = "Burnt", "FALSE" = "Unburnt")) +
  labs(x = "Predicted CCA1", y = "Observed CCA1", 
       title = "Predicted vs Observed Forest community State (CCA1)") +
  theme_minimal()
print(p2)

## Visualization 3: Enhanced prediction error vectors with centroids, species, and environmental vectors
# Calculate centroids
centroids = comparison_df %>%
  filter(!is.nan(projected_CCA1))%>%
  group_by(site) %>%
  summarise(
    pred_CCA1_mean = mean(predicted_CCA1),
    pred_CCA2_mean = mean(predicted_CCA2),
    pred_CCA3_mean = mean(predicted_CCA3),
    proj_CCA1_mean = mean(projected_CCA1),
    proj_CCA2_mean = mean(projected_CCA2),
    proj_CCA3_mean = mean(projected_CCA3)
  )

p3 = ggplot() +
  geom_hline(yintercept = 0, color = "grey70", size = 0.5)+
  geom_vline(xintercept = 0, color = "grey70", size = 0.5)+
  geom_segment(data = comparison_df,
               aes(x = predicted_CCA1, y = predicted_CCA2,
                   xend = projected_CCA1, yend = projected_CCA2,
                   color = site),
               arrow = arrow(length = unit(0.1, "inches")), 
               alpha = 0.1, size = 0.5) +
  geom_segment(data = env_df,
               aes(x = 0, y = 0, xend = CCA1*2, yend = CCA2*2),
               arrow = arrow(length = unit(0.2, "cm")), 
               color = "black", size = 1) +
  geom_text(data = env_df,
            aes(x = CCA1*2.2, y = CCA2*2.2, label = variable),
            color = "black", fontface = "bold", size = 3) +
  geom_text(data = species_df,
            aes(x = CCA1, y = CCA2, label = species),
            color = "black", alpha = 0.6, size = 2.5) +
  geom_segment(data = centroids,
               aes(x = pred_CCA1_mean, y = pred_CCA2_mean,
                   xend = proj_CCA1_mean, yend = proj_CCA2_mean,
                   color = site),
               arrow = arrow(length = unit(0.2, "cm"), type = "closed"), 
               size = 1) +
  geom_point(data = centroids,
             aes(x = pred_CCA1_mean, y = pred_CCA2_mean, color = site),
             size = 1, shape = 21, fill = "white", stroke = 1) +
  geom_point(data = centroids,
             aes(x = proj_CCA1_mean, y = proj_CCA2_mean, color = site),
             size = 1, shape = 21, stroke = 1, fill = "white") +
  geom_text_repel(data = centroids,
                  aes(x = pred_CCA1_mean, y = pred_CCA2_mean, label = paste(site, "Pred"), color = site),
                  size = 2, fontface = "bold") +
  geom_text_repel(data = centroids,
                  aes(x = proj_CCA1_mean, y = proj_CCA2_mean, label = paste(site, "Obs"), color = site),
                  size = 2, fontface = "bold") +
  scale_color_manual(values = color_mt) +
  scale_fill_manual(values = color_mt) +
  labs(title = "Forest community Change: Predicted vs Observed with Environmental Drivers (CCA1 vs CCA2)",
       subtitle = "Bold arrows show site centroids; faded arrows show individual plots",
       x = paste0("CCA1 (", round(summary(cca_model)$cont$importance[2,1]*100, 1), "%)"),
       y = paste0("CCA2 (", round(summary(cca_model)$cont$importance[2,2]*100, 1), "%)")) +
  theme_minimal() +
  theme(legend.position = "right")
print(p3)

# NEW: Visualization for CCA2 vs CCA3
p3b = ggplot() +
  geom_hline(yintercept = 0, color = "grey70", size = 0.5)+
  geom_vline(xintercept = 0, color = "grey70", size = 0.5)+
  geom_segment(data = comparison_df,
               aes(x = predicted_CCA2, y = predicted_CCA3,
                   xend = projected_CCA2, yend = projected_CCA3,
                   color = site),
               arrow = arrow(length = unit(0.1, "inches")), 
               alpha = 0.1, size = 0.5) +
  geom_segment(data = env_df,
               aes(x = 0, y = 0, xend = CCA2*2, yend = CCA3*2),
               arrow = arrow(length = unit(0.2, "cm")), 
               color = "black", size = 1) +
  geom_text(data = env_df,
            aes(x = CCA2*2.2, y = CCA3*2.2, label = variable),
            color = "black", fontface = "bold", size = 3) +
  geom_text(data = species_df,
            aes(x = CCA2, y = CCA3, label = species),
            color = "black", alpha = 0.6, size = 2.5) +
  geom_segment(data = centroids,
               aes(x = pred_CCA2_mean, y = pred_CCA3_mean,
                   xend = proj_CCA2_mean, yend = proj_CCA3_mean,
                   color = site),
               arrow = arrow(length = unit(0.2, "cm"), type = "closed"), 
               size = 1) +
  geom_point(data = centroids,
             aes(x = pred_CCA2_mean, y = pred_CCA3_mean, color = site),
             size = 1, shape = 21, fill = "white", stroke = 1) +
  geom_point(data = centroids,
             aes(x = proj_CCA2_mean, y = proj_CCA3_mean, color = site),
             size = 1, shape = 21, stroke = 1, fill = "white") +
  geom_text_repel(data = centroids,
                  aes(x = pred_CCA2_mean, y = pred_CCA3_mean, label = paste(site, "Pred"), color = site),
                  size = 2, fontface = "bold") +
  geom_text_repel(data = centroids,
                  aes(x = proj_CCA2_mean, y = proj_CCA3_mean, label = paste(site, "Obs"), color = site),
                  size = 2, fontface = "bold") +
  scale_color_manual(values = color_mt) +
  scale_fill_manual(values = color_mt) +
  labs(title = "Forest community Change: Predicted vs Observed with Environmental Drivers (CCA2 vs CCA3)",
       subtitle = "Bold arrows show site centroids; faded arrows show individual plots",
       x = paste0("CCA2 (", round(summary(cca_model)$cont$importance[2,2]*100, 1), "%)"),
       y = paste0("CCA3 (", round(summary(cca_model)$cont$importance[2,3]*100, 1), "%)")) +
  theme_minimal() +
  theme(legend.position = "right")
print(p3b)

# Calculate differences between observed (projected) and predicted for each axis
comparison_df = comparison_df %>%
  mutate(
    diff_CCA1 = abs(projected_CCA1 - predicted_CCA1),
    diff_CCA2 = abs(projected_CCA2 - predicted_CCA2),
    diff_CCA3 = abs(projected_CCA3 - predicted_CCA3),
    euclidean_dist_2D = sqrt(diff_CCA1^2 + diff_CCA2^2),
    euclidean_dist_3D = sqrt(diff_CCA1^2 + diff_CCA2^2 + diff_CCA3^2)
  )

# Prepare data for boxplots - transform to long format
diff_long = comparison_df %>%
  select(plot_id, site, diff_CCA1, diff_CCA2, diff_CCA3, euclidean_dist_2D, euclidean_dist_3D) %>%
  pivot_longer(cols = c(diff_CCA1, diff_CCA2, diff_CCA3, euclidean_dist_2D, euclidean_dist_3D),
               names_to = "metric",
               values_to = "value") %>%
  mutate(metric = factor(metric,
                         levels = c("diff_CCA1", "diff_CCA2", "diff_CCA3", "euclidean_dist_2D", "euclidean_dist_3D"),
                         labels = c("CCA1", "CCA2", "CCA3", "2D Distance", "3D Distance")))

p4 = ggplot(diff_long, aes(x = metric, y = value, fill = site)) +
  geom_boxplot(position = position_dodge(0.8)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  facet_wrap(metric~., scales = "free", ncol = 5)+
  scale_fill_manual(values = color_mt) +
  labs(x = "Metric",
       y = "Euclidean Distance",
       title = "CCA Prediction Errors and Euclidean Distances by Site",
       fill = "Site") +
  theme_minimal() +
  theme(axis.text.x = element_blank(),
        legend.position = "bottom")
print(p4)

# Summary statistics
summary_stats = comparison_df %>%
  group_by(site, burnt) %>%
  summarise(
    mean_diff_CCA1 = mean(diff_CCA1, na.rm = TRUE),
    sd_diff_CCA1 = sd(diff_CCA1, na.rm = TRUE),
    mean_diff_CCA2 = mean(diff_CCA2, na.rm = TRUE),
    sd_diff_CCA2 = sd(diff_CCA2, na.rm = TRUE),
    mean_diff_CCA3 = mean(diff_CCA3, na.rm = TRUE),
    sd_diff_CCA3 = sd(diff_CCA3, na.rm = TRUE),
    mean_euclidean_2D = mean(euclidean_dist_2D, na.rm = TRUE),
    sd_euclidean_2D = sd(euclidean_dist_2D, na.rm = TRUE),
    mean_euclidean_3D = mean(euclidean_dist_3D, na.rm = TRUE),
    sd_euclidean_3D = sd(euclidean_dist_3D, na.rm = TRUE),
    n = n()
  )

print(summary_stats)

# Calculate prediction accuracy metrics
rmse_cca1 = sqrt(mean((comparison_df$predicted_CCA1 - comparison_df$projected_CCA1)^2))
rmse_cca2 = sqrt(mean((comparison_df$predicted_CCA2 - comparison_df$projected_CCA2)^2))
rmse_cca3 = sqrt(mean((comparison_df$predicted_CCA3 - comparison_df$projected_CCA3)^2))
correlation_cca1 = cor(comparison_df$predicted_CCA1, comparison_df$projected_CCA1)
correlation_cca2 = cor(comparison_df$predicted_CCA2, comparison_df$projected_CCA2)
correlation_cca3 = cor(comparison_df$predicted_CCA3, comparison_df$projected_CCA3)

cat("RMSE CCA1:", round(rmse_cca1, 3), "\n")
cat("RMSE CCA2:", round(rmse_cca2, 3), "\n")
cat("RMSE CCA3:", round(rmse_cca3, 3), "\n")
cat("Correlation CCA1:", round(correlation_cca1, 3), "\n")
cat("Correlation CCA2:", round(correlation_cca2, 3), "\n")
cat("Correlation CCA3:", round(correlation_cca3, 3), "\n")

# Create loadings summary figure ----
# Prepare environmental loadings data for all three axes
env_loadings_long = env_df %>%
  select(variable, CCA1, CCA2, CCA3) %>%
  pivot_longer(cols = c(CCA1, CCA2, CCA3), 
               names_to = "axis", 
               values_to = "loading") %>%
  mutate(type = "Environmental",
         axis = factor(axis, levels = c("CCA1", "CCA2", "CCA3")))

# Prepare species loadings data for all three axes (using top species)
species_loadings_long = species_df %>%
  select(species, CCA1, CCA2, CCA3) %>%
  pivot_longer(cols = c(CCA1, CCA2, CCA3), 
               names_to = "axis", 
               values_to = "loading") %>%
  mutate(type = "Species",
         axis = factor(axis, levels = c("CCA1", "CCA2", "CCA3"))) %>%
  rename(variable = species)

# Combine environmental and species loadings
all_loadings = bind_rows(env_loadings_long, species_loadings_long)

# Create the loadings plot
p_loadings = ggplot(all_loadings, aes(x = reorder(variable, abs(loading)), y = loading)) +
  geom_hline(yintercept = c(-1,-0.5,0,0.5,1), color = "grey50", size = 0.3) +
  geom_col(alpha = 0.8) +
  facet_grid(type~ axis, scales = "free_y") +
  coord_flip() +
  labs(title = "CCA Loadings: Environmental Variables and Top Species",
       subtitle = "Contribution of variables and species to canonical axes",
       x = "Variables/Species",
       y = "Loading",
       fill = "Type") +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold"),
    legend.position = "bottom",
    axis.text.y = element_text(size = 8)
  )

print(p_loadings)

pdf(file = here(paste0("plot/cca_anthropocene", cca_suffix, ".pdf")), height = 8, width = 10)
print(p2)
print(p3)
print(p3b)
print(p4)
print(p_loadings)
dev.off()

# PALEO PLOT on the same plot: ----
# Extract scores for visualization INCLUDING CCA3
past_sites = scores(cca_model, display = "sites", choices = 1:3)
species_scores = scores(cca_model, display = "species", choices = 1:3)
env_scores = scores(cca_model, display = "bp", choices = 1:3)

# Identify top contributing species
species_contribution = sqrt(species_scores[,1]^2 + species_scores[,2]^2)
top_species = names(sort(species_contribution, decreasing = TRUE))

# Create plotting dataframes
sites_df = as_tibble(past_sites) %>%
  mutate(plot_id = rownames(past_sites)) %>%
  left_join(site_fire_info_past, by = "plot_id")

species_df = as_tibble(species_scores) %>%
  mutate(species = rownames(species_scores)) %>%
  filter(species %in% top_species)

env_df = as_tibble(env_scores) %>%
  mutate(variable = rownames(env_scores))

comparison_df = tibble(
  plot_id = rownames(species_present_final),
  predicted_CCA1 = predicted_present[,1],
  predicted_CCA2 = predicted_present[,2],
  predicted_CCA3 = predicted_present[,3],
  projected_CCA1 = projected_present[,1],
  projected_CCA2 = projected_present[,2],
  projected_CCA3 = projected_present[,3]
) %>%
  left_join(site_fire_info_present, by = "plot_id")%>%
  filter(!is.nan(projected_CCA1)) %>%
  mutate(era = "anthropocene")%>%
  bind_rows(
    tibble(
      plot_id = rownames(species_paleo),
      predicted_CCA1 = predicted_paleo[,1],
      predicted_CCA2 = predicted_paleo[,2],
      predicted_CCA3 = predicted_paleo[,3],
      projected_CCA1 = projected_paleo[,1],
      projected_CCA2 = projected_paleo[,2],
      projected_CCA3 = projected_paleo[,3]
    ) %>%
      left_join(site_fire_info_paleo, by = "plot_id")%>%
      filter(!is.nan(projected_CCA1))%>%
      mutate(era = "holocene")
  )

# Visualization 1: Enhanced CCA biplot with environmental vectors and top species
color_mt = c("MORA" = "#648FFF", "NOCA" = "#FE6100")
# Colors for site x era; paleo adds NOCA.holocene as a 4th group
color_site_era = c("MORA.anthropocene" = "#648FFF", "NOCA.anthropocene" = "#FE6100",
                   "MORA.holocene" = "#394e82", "NOCA.holocene" = "#8C3B00")

# Visualization 2: Predicted vs Observed correlation
p2 = ggplot(comparison_df, aes(predicted_CCA1, projected_CCA1, color = interaction(site, era))) +
  geom_point(size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  #scale_color_manual(values = color_mt) +
  scale_shape_manual(values = c("TRUE" = 17, "FALSE" = 16),
                     labels = c("TRUE" = "Burnt", "FALSE" = "Unburnt")) +
  labs(x = "Predicted CCA1", y = "Observed CCA1", 
       title = "Predicted vs Observed Forest community State (CCA1)") +
  theme_minimal()
print(p2)

## Visualization 3: Enhanced prediction error vectors with centroids, species, and environmental vectors
# Calculate centroids
centroids = comparison_df %>%
  filter(!is.nan(projected_CCA1))%>%
  group_by(site, era) %>%
  summarise(
    pred_CCA1_mean = mean(predicted_CCA1),
    pred_CCA2_mean = mean(predicted_CCA2),
    pred_CCA3_mean = mean(predicted_CCA3),
    proj_CCA1_mean = mean(projected_CCA1),
    proj_CCA2_mean = mean(projected_CCA2),
    proj_CCA3_mean = mean(projected_CCA3)
  )

p3 = ggplot() +
  geom_hline(yintercept = 0, color = "grey70", size = 0.5)+
  geom_vline(xintercept = 0, color = "grey70", size = 0.5)+
  geom_segment(data = comparison_df,
               aes(x = predicted_CCA1, y = predicted_CCA2,
                   xend = projected_CCA1, yend = projected_CCA2,
                   color = interaction(site, era)),
               arrow = arrow(length = unit(0.1, "inches")), 
               alpha = 0.1, size = 0.5) +
  geom_segment(data = env_df,
               aes(x = 0, y = 0, xend = CCA1*2, yend = CCA2*2),
               arrow = arrow(length = unit(0.2, "cm")), 
               color = "black", size = 1) +
  geom_text(data = env_df,
            aes(x = CCA1*2.2, y = CCA2*2.2, label = variable),
            color = "black", fontface = "bold", size = 3) +
  geom_text(data = species_df,
            aes(x = CCA1, y = CCA2, label = species),
            color = "black", alpha = 0.6, size = 2.5) +
  geom_segment(data = centroids,
               aes(x = pred_CCA1_mean, y = pred_CCA2_mean,
                   xend = proj_CCA1_mean, yend = proj_CCA2_mean,
                   color = interaction(site, era)),
               arrow = arrow(length = unit(0.2, "cm"), type = "closed"), 
               size = 1) +
  geom_point(data = centroids,
             aes(x = pred_CCA1_mean, y = pred_CCA2_mean, color = interaction(site, era)),
             size = 1, shape = 21, fill = "white", stroke = 1) +
  geom_point(data = centroids,
             aes(x = proj_CCA1_mean, y = proj_CCA2_mean, color = interaction(site, era)),
             size = 1, shape = 21, stroke = 1, fill = "white") +
  geom_text_repel(data = centroids,
                  aes(x = pred_CCA1_mean, y = pred_CCA2_mean, label = paste(site, era, "Pred"), color = interaction(site, era)),
                  size = 2, fontface = "bold") +
  geom_text_repel(data = centroids,
                  aes(x = proj_CCA1_mean, y = proj_CCA2_mean, label = paste(site, era, "Obs"), color = interaction(site, era)),
                  size = 2, fontface = "bold") +
  scale_color_manual(values = color_site_era) +
  scale_fill_manual(values = color_site_era) +
  labs(title = "Forest community Change: Predicted vs Observed with Environmental Drivers (CCA1 vs CCA2)",
       subtitle = "Bold arrows show site centroids; faded arrows show individual plots",
       x = paste0("CCA1 (", round(summary(cca_model)$cont$importance[2,1]*100, 1), "%)"),
       y = paste0("CCA2 (", round(summary(cca_model)$cont$importance[2,2]*100, 1), "%)")) +
  theme_minimal() +
  theme(legend.position = "right")
print(p3)

# NEW: Visualization for CCA2 vs CCA3
p3b = ggplot() +
  geom_hline(yintercept = 0, color = "grey70", size = 0.5)+
  geom_vline(xintercept = 0, color = "grey70", size = 0.5)+
  geom_segment(data = comparison_df,
               aes(x = predicted_CCA2, y = predicted_CCA3,
                   xend = projected_CCA2, yend = projected_CCA3,
                   color = site),
               arrow = arrow(length = unit(0.1, "inches")), 
               alpha = 0.1, size = 0.5) +
  geom_segment(data = env_df,
               aes(x = 0, y = 0, xend = CCA2*2, yend = CCA3*2),
               arrow = arrow(length = unit(0.2, "cm")), 
               color = "black", size = 1) +
  geom_text(data = env_df,
            aes(x = CCA2*2.2, y = CCA3*2.2, label = variable),
            color = "black", fontface = "bold", size = 3) +
  geom_text(data = species_df,
            aes(x = CCA2, y = CCA3, label = species),
            color = "black", alpha = 0.6, size = 2.5) +
  geom_segment(data = centroids,
               aes(x = pred_CCA2_mean, y = pred_CCA3_mean,
                   xend = proj_CCA2_mean, yend = proj_CCA3_mean,
                   color = site),
               arrow = arrow(length = unit(0.2, "cm"), type = "closed"), 
               size = 1) +
  geom_point(data = centroids,
             aes(x = pred_CCA2_mean, y = pred_CCA3_mean, color = site),
             size = 1, shape = 21, fill = "white", stroke = 1) +
  geom_point(data = centroids,
             aes(x = proj_CCA2_mean, y = proj_CCA3_mean, color = site),
             size = 1, shape = 21, stroke = 1, fill = "white") +
  geom_text_repel(data = centroids,
                  aes(x = pred_CCA2_mean, y = pred_CCA3_mean, label = paste(site, "Pred"), color = site),
                  size = 2, fontface = "bold") +
  geom_text_repel(data = centroids,
                  aes(x = proj_CCA2_mean, y = proj_CCA3_mean, label = paste(site, "Obs"), color = site),
                  size = 2, fontface = "bold") +
  scale_color_manual(values = color_mt) +
  scale_fill_manual(values = color_mt) +
  labs(title = "Forest community Change: Predicted vs Observed with Environmental Drivers (CCA2 vs CCA3)",
       subtitle = "Bold arrows show site centroids; faded arrows show individual plots",
       x = paste0("CCA2 (", round(summary(cca_model)$cont$importance[2,2]*100, 1), "%)"),
       y = paste0("CCA3 (", round(summary(cca_model)$cont$importance[2,3]*100, 1), "%)")) +
  theme_minimal() +
  theme(legend.position = "right")
print(p3b)

# Calculate differences between observed (projected) and predicted for each axis
comparison_df = comparison_df %>%
  mutate(
    diff_CCA1 = abs(projected_CCA1 - predicted_CCA1),
    diff_CCA2 = abs(projected_CCA2 - predicted_CCA2),
    diff_CCA3 = abs(projected_CCA3 - predicted_CCA3),
    euclidean_dist_2D = sqrt(diff_CCA1^2 + diff_CCA2^2),
    euclidean_dist_3D = sqrt(diff_CCA1^2 + diff_CCA2^2 + diff_CCA3^2)
  )

# Lag (observed-vs-predicted disequilibrium) through time + anthropocene violin ----
# Lag = Euclidean distance in CCA1-CCA2 space between the observed (species-based
# WA) and climate-predicted (LC) position of each sample. Paleo is shown as a
# MORA + NOCA time series; the anthropocene lag is a violin at the present end.
lag_ymax = max(comparison_df$euclidean_dist_2D, na.rm = TRUE)

paleo_lag = comparison_df %>%
  filter(era == "holocene") %>%
  mutate(bp_year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[, 2]))

p_lag = ggplot(paleo_lag, aes(x = bp_year, y = euclidean_dist_2D, color = site)) +
  geom_point(alpha = 0.35, size = 1) +
  geom_smooth(method = "loess", span = 0.3, se = TRUE) +
  scale_x_reverse() +
  scale_color_manual(values = color_mt) +
  coord_cartesian(ylim = c(0, lag_ymax)) +
  labs(x = "Age (cal yr BP)",
       y = "Observed - predicted distance (CCA1-CCA2)",
       color = "Site",
       title = "Forest community-climate lag through time",
       subtitle = "Paleo: time series (left); Anthropocene: present-day distribution (right)") +
  theme_minimal()

p_violin = ggplot(filter(comparison_df, era == "anthropocene"),
                  aes(x = site, y = euclidean_dist_2D, fill = site)) +
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

pdf(file = here(paste0("plot/paleo_lag_timeseries", cca_suffix, ".pdf")), height = 6, width = 11)
print(p_lag_combined)
dev.off()

# Lag standardized by climatic distance from the CCA calibration envelope -----
# Climatic distance = standardized (z by past-plot SD) Euclidean distance of a
# point's climate from the centroid of the PAST plots used to fit the CCA.
# Then express forest community lag relative to it: lag per unit climatic distance.
# Climatic distance from the PREDICTOR (LC) side of the CCA -------------------
# Climate is the constraint, so a point's "climatic position" in the ordination
# is its LC score (predicted_CCA*, the linear combination of climate). Climatic
# distance = distance of that LC position from the centroid of the SITE's past-
# plot LC scores (the calibration envelope, predictor side), in CCA1-CCA2 - the
# same space as the forest community lag, so lag/clim_dist is a clean within-space ratio.
train_plots = rownames(species_past_final)
past_lc = predict(cca_model, newdata = env_past_final, type = "lc")
past_lc_centroid = tibble(plot_id = train_plots, lc1 = past_lc[, 1], lc2 = past_lc[, 2]) %>%
  left_join(env %>% filter(period == "past") %>% distinct(plot_id, site), by = "plot_id") %>%
  group_by(site) %>%
  summarize(c1 = mean(lc1), c2 = mean(lc2), .groups = "drop")

lag_std = comparison_df %>%
  left_join(past_lc_centroid, by = "site") %>%
  mutate(clim_dist = sqrt((predicted_CCA1 - c1)^2 + (predicted_CCA2 - c2)^2),
         lag_per_climdist = euclidean_dist_2D / clim_dist,
         bp_year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[, 2])) %>%
  filter(!is.na(clim_dist), clim_dist > 0)

ratio_ymax = as.numeric(quantile(lag_std$lag_per_climdist, 0.98, na.rm = TRUE))

p_ratio = ggplot(filter(lag_std, era == "holocene"),
                 aes(x = bp_year, y = lag_per_climdist, color = site)) +
  geom_point(alpha = 0.35, size = 1) +
  geom_smooth(method = "loess", span = 0.3, se = TRUE) +
  scale_x_reverse() +
  scale_color_manual(values = color_mt) +
  coord_cartesian(ylim = c(0, ratio_ymax)) +
  labs(x = "Age (cal yr BP)", y = "Forest community lag / climatic distance",
       color = "Site",
       title = "Forest community lag standardized by climatic distance from CCA calibration",
       subtitle = "Climatic distance = LC (predictor) distance from the site's past-plot envelope, in CCA space") +
  theme_minimal()

p_ratio_violin = ggplot(filter(lag_std, era == "anthropocene"),
                        aes(x = site, y = lag_per_climdist, fill = site)) +
  geom_violin(alpha = 0.6, scale = "width", trim = FALSE, color = NA) +
  geom_boxplot(width = 0.15, alpha = 0.9, outlier.size = 0.4) +
  scale_fill_manual(values = color_mt) +
  coord_cartesian(ylim = c(0, ratio_ymax)) +
  labs(x = NULL, y = NULL, title = "Anthropocene") +
  theme_minimal() +
  theme(legend.position = "none", axis.text.y = element_blank())

p_ratio_combined = ggarrange(p_ratio, p_ratio_violin, ncol = 2, widths = c(4, 1),
                             align = "h", common.legend = TRUE, legend = "bottom")
print(p_ratio_combined)

pdf(file = here(paste0("plot/lag_per_climdist", cca_suffix, ".pdf")), height = 6, width = 11)
print(p_ratio_combined)
dev.off()

# Scatter: forest community lag vs (within-site) climatic distance, colored by site --
p_lagscatter = ggplot(lag_std, aes(x = clim_dist, y = euclidean_dist_2D, color = site)) +
  geom_point(aes(shape = era), alpha = 0.4, size = 1.3) +
  geom_smooth(aes(linetype = era), method = "lm", se = TRUE) +
  scale_color_manual(values = color_mt) +
  labs(x = "Climatic distance (LC/predictor displacement from site's past envelope, CCA1-CCA2)",
       y = "Forest community lag (CCA1-CCA2)",
       color = "Site", shape = "Era", linetype = "Era",
       title = "Forest community lag vs climatic distance (LC/predictor space, within-site)",
       subtitle = "Both axes are CCA-space distances; climatic distance = predicted-position shift from the site's past LC centroid") +
  theme_minimal()
print(p_lagscatter)

pdf(file = here(paste0("plot/lag_vs_climdist", cca_suffix, ".pdf")), height = 6, width = 8)
print(p_lagscatter)
dev.off()

# Prepare data for boxplots - transform to long format
diff_long = comparison_df %>%
  select(plot_id, site, era, diff_CCA1, diff_CCA2, diff_CCA3, euclidean_dist_2D, euclidean_dist_3D) %>%
  pivot_longer(cols = c(diff_CCA1, diff_CCA2, diff_CCA3, euclidean_dist_2D, euclidean_dist_3D),
               names_to = "metric",
               values_to = "value") %>%
  mutate(metric = factor(metric,
                         levels = c("diff_CCA1", "diff_CCA2", "diff_CCA3", "euclidean_dist_2D", "euclidean_dist_3D"),
                         labels = c("CCA1", "CCA2", "CCA3", "2D Distance", "3D Distance")))

# Alternative visualization: interaction between site and fire status using alpha
p4 = ggplot(diff_long, aes(x = metric, y = value, fill = interaction(site, era))) +
  geom_boxplot(position = position_dodge(0.8)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  facet_wrap(metric~., scales = "free", ncol = 5)+
  scale_fill_manual(values = color_site_era) +
  labs(x = "Metric",
       y = "Euclidean Distance",
       title = "CCA Prediction Errors and Euclidean Distances by Site",
       fill = "Site") +
  theme_minimal() +
  theme(axis.text.x = element_blank(),
        legend.position = "bottom")
print(p4)

# Summary statistics
summary_stats = comparison_df %>%
  group_by(site, burnt) %>%
  summarise(
    mean_diff_CCA1 = mean(diff_CCA1, na.rm = TRUE),
    sd_diff_CCA1 = sd(diff_CCA1, na.rm = TRUE),
    mean_diff_CCA2 = mean(diff_CCA2, na.rm = TRUE),
    sd_diff_CCA2 = sd(diff_CCA2, na.rm = TRUE),
    mean_diff_CCA3 = mean(diff_CCA3, na.rm = TRUE),
    sd_diff_CCA3 = sd(diff_CCA3, na.rm = TRUE),
    mean_euclidean_2D = mean(euclidean_dist_2D, na.rm = TRUE),
    sd_euclidean_2D = sd(euclidean_dist_2D, na.rm = TRUE),
    mean_euclidean_3D = mean(euclidean_dist_3D, na.rm = TRUE),
    sd_euclidean_3D = sd(euclidean_dist_3D, na.rm = TRUE),
    n = n()
  )

print(summary_stats)

# Calculate prediction accuracy metrics
rmse_cca1 = sqrt(mean((comparison_df$predicted_CCA1 - comparison_df$projected_CCA1)^2))
rmse_cca2 = sqrt(mean((comparison_df$predicted_CCA2 - comparison_df$projected_CCA2)^2))
rmse_cca3 = sqrt(mean((comparison_df$predicted_CCA3 - comparison_df$projected_CCA3)^2))
correlation_cca1 = cor(comparison_df$predicted_CCA1, comparison_df$projected_CCA1)
correlation_cca2 = cor(comparison_df$predicted_CCA2, comparison_df$projected_CCA2)
correlation_cca3 = cor(comparison_df$predicted_CCA3, comparison_df$projected_CCA3)

cat("RMSE CCA1:", round(rmse_cca1, 3), "\n")
cat("RMSE CCA2:", round(rmse_cca2, 3), "\n")
cat("RMSE CCA3:", round(rmse_cca3, 3), "\n")
cat("Correlation CCA1:", round(correlation_cca1, 3), "\n")
cat("Correlation CCA2:", round(correlation_cca2, 3), "\n")
cat("Correlation CCA3:", round(correlation_cca3, 3), "\n")

# Create loadings summary figure ----
# Prepare environmental loadings data for all three axes
env_loadings_long = env_df %>%
  select(variable, CCA1, CCA2, CCA3) %>%
  pivot_longer(cols = c(CCA1, CCA2, CCA3), 
               names_to = "axis", 
               values_to = "loading") %>%
  mutate(type = "Environmental",
         axis = factor(axis, levels = c("CCA1", "CCA2", "CCA3")))

# Prepare species loadings data for all three axes (using top species)
species_loadings_long = species_df %>%
  select(species, CCA1, CCA2, CCA3) %>%
  pivot_longer(cols = c(CCA1, CCA2, CCA3), 
               names_to = "axis", 
               values_to = "loading") %>%
  mutate(type = "Species",
         axis = factor(axis, levels = c("CCA1", "CCA2", "CCA3"))) %>%
  rename(variable = species)

# Combine environmental and species loadings
all_loadings = bind_rows(env_loadings_long, species_loadings_long)

# Create the loadings plot
p_loadings = ggplot(all_loadings, aes(x = reorder(variable, abs(loading)), y = loading)) +
  geom_hline(yintercept = c(-1,-0.5,0,0.5,1), color = "grey50", size = 0.3) +
  geom_col(alpha = 0.8) +
  facet_grid(type~ axis, scales = "free_y") +
  coord_flip() +
  labs(title = "CCA Loadings: Environmental Variables and Top Species",
       subtitle = "Contribution of variables and species to canonical axes",
       x = "Variables/Species",
       y = "Loading",
       fill = "Type") +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold"),
    legend.position = "bottom",
    axis.text.y = element_text(size = 8)
  )

print(p_loadings)

pdf(file = here(paste0("plot/cca_anthropocene", cca_suffix, ".pdf")), height = 8, width = 10)
print(p2)
print(p3)
print(p3b)
print(p4)
print(p_loadings)
dev.off()

pdf(file = here(paste0("plot/cca_holocene", cca_suffix, ".pdf")), height = 8, width = 10)
print(p3)
print(p4)
dev.off()


