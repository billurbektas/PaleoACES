# Harmonize both datasets ----
NOCA_occ = read_csv(here("output/NOCA_occ.csv"))
MORA_occ = read_csv(here("output/MORA_occ.csv"))

occ = bind_rows(NOCA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "NOCA"),
                MORA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "MORA")) %>%
  mutate(era = "anthropocene") %>%
  filter(!species %in% c("unknown", "Abies sp.", "Salix sp."))

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
  filter(MORA_past<count.thr & MORA_present<count.thr & NOCA_past<count.thr & NOCA_present<count.thr)

takeoutsp =
  takeoutsp %>%
  pull(species)%>%
  unique()

takeoutsp = c(takeoutsp, "Tsuga heterophylla")

occ = occ %>% filter(!species %in% takeoutsp)

# Harmonize with climate & fire data ----
NOCA_plot_info_fire = read_csv(here("output/NOCA_plot_info_fire.csv"))
MORA_plot_info_fire = read_csv(here("output/MORA_plot_info_fire.csv"))

fire_summary = bind_rows(NOCA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "NOCA"),
                         MORA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "MORA")) %>%
  mutate(era = "anthropocene")

climate_summary = read_csv(here("output/climate_summary.csv"))

env = left_join(climate_summary %>% select(site, era, period, plot_id, elevation, slope, aspect, MWT, MST, WP, SpP),
                fire_summary) %>%
  filter(era == "anthropocene")

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
  select(plot_id, elevation, slope, aspect, MWT, MST, WP, SpP) %>%
  column_to_rownames("plot_id")

env_present = env %>%
  filter(period == "present") %>%
  select(plot_id, elevation, slope, aspect, MWT, MST, WP, SpP) %>%
  column_to_rownames("plot_id")

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

# Get site and fire information for plotting
site_fire_info_past = env %>%
  filter(period == "past") %>%
  select(plot_id, site, burnt) %>%
  filter(plot_id %in% rownames(species_past_final))

site_fire_info_present = env %>%
  filter(period == "present") %>%
  select(plot_id, site, burnt) %>%
  filter(plot_id %in% rownames(species_present_final))

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
       title = "Predicted vs Observed Vegetation State (CCA1)") +
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
  labs(title = "Vegetation Change: Predicted vs Observed with Environmental Drivers (CCA1 vs CCA2)",
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
  labs(title = "Vegetation Change: Predicted vs Observed with Environmental Drivers (CCA2 vs CCA3)",
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
  select(plot_id, site, burnt, diff_CCA1, diff_CCA2, diff_CCA3, euclidean_dist_2D, euclidean_dist_3D) %>%
  pivot_longer(cols = c(diff_CCA1, diff_CCA2, diff_CCA3, euclidean_dist_2D, euclidean_dist_3D),
               names_to = "metric",
               values_to = "value") %>%
  mutate(metric = factor(metric, 
                         levels = c("diff_CCA1", "diff_CCA2", "diff_CCA3", "euclidean_dist_2D", "euclidean_dist_3D"),
                         labels = c("CCA1", "CCA2", "CCA3", "2D Distance", "3D Distance")),
         burnt_label = ifelse(burnt, "Burnt", "Unburnt"))%>%
  filter(!(burnt_label == "Burnt" & site == "MORA"))

# Alternative visualization: interaction between site and fire status using alpha
p4 = ggplot(diff_long, aes(x = metric, y = value, fill = site, alpha = burnt_label)) +
  geom_boxplot(position = position_dodge(0.8)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  facet_wrap(metric~., scales = "free", ncol = 5)+
  scale_fill_manual(values = color_mt) +
  scale_alpha_manual(values = c("Burnt" = 0.9, "Unburnt" = 0.3)) +
  labs(x = "Metric", 
       y = "Euclidean Distance",
       title = "CCA Prediction Errors and Euclidean Distances by Site and Fire Status",
       fill = "Site",
       alpha = "Fire Status") +
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

pdf(file = here("plot/cca_anthropocene.pdf"), height = 8, width = 10)
print(p2)
print(p3)
print(p3b)
print(p4)
print(p_loadings)
dev.off()
