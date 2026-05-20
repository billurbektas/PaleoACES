
# Harmonize both datasets ----
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
  group_by(site, species)%>%
  mutate(total = sum(count))

takeoutsp = 
  occ_summary %>%
  filter(total<14)%>%
  pull(species)%>%
  unique()

ggplot(occ_summary, aes(x = reorder(species, count), y = count, fill = site)) +
  geom_col() +
  scale_fill_manual(values = color_mt) +
  coord_flip() +
  labs(x = "Species", y = "Count", fill = "Site") +
  theme_minimal()

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

# Extract scores for visualization
past_sites = scores(cca_model, display = "sites", choices = 1:2)
species_scores = scores(cca_model, display = "species", choices = 1:2)
env_scores = scores(cca_model, display = "bp", choices = 1:2)

# Identify top contributing species
species_contribution = sqrt(species_scores[,1]^2 + species_scores[,2]^2)
top_species = names(sort(species_contribution, decreasing = TRUE)[1:8])

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
  projected_CCA1 = projected_present[,1],
  projected_CCA2 = projected_present[,2]
) %>%
  left_join(site_fire_info_present, by = "plot_id")%>%
  filter(!is.nan(projected_CCA1))

# Visualization 1: Enhanced CCA biplot with environmental vectors and top species
color_mt = c("MORA" = "#648FFF", "NOCA" = "#FE6100")

# Visualization 2: Predicted vs Observed correlation
ggplot(comparison_df, aes(predicted_CCA1, projected_CCA1, color = site)) +
  geom_point(size = 3, alpha = 0.7) +
  #geom_smooth(method = "lm", se = TRUE, aes(group = 1), color = "gray30") +
  geom_smooth(method = "lm", se = TRUE) +
  
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  scale_color_manual(values = color_mt) +
  scale_shape_manual(values = c("TRUE" = 17, "FALSE" = 16),
                     labels = c("TRUE" = "Burnt", "FALSE" = "Unburnt")) +
  labs(x = "Predicted CCA1", y = "Observed CCA1", 
       title = "Predicted vs Observed Vegetation State (CCA1)") +
  theme_minimal()

## Visualization 3: Enhanced prediction error vectors with centroids, species, and environmental vectors
# Calculate centroids
centroids = comparison_df %>%
  filter(!is.nan(projected_CCA1))%>%
  group_by(site) %>%
  summarise(
    pred_CCA1_mean = mean(predicted_CCA1),
    pred_CCA2_mean = mean(predicted_CCA2),
    proj_CCA1_mean = mean(projected_CCA1),
    proj_CCA2_mean = mean(projected_CCA2)
  )

ggplot() +
  geom_hline(yintercept = 0, color = "grey70", size = 0.5)+
  geom_vline(xintercept = 0, color = "grey70", size = 0.5)+
  # Individual prediction error vectors (very faded background)
  geom_segment(data = comparison_df,
               aes(x = predicted_CCA1, y = predicted_CCA2,
                   xend = projected_CCA1, yend = projected_CCA2,
                   color = site),
               arrow = arrow(length = unit(0.1, "inches")), 
               alpha = 0.1, size = 0.5) +
  # Environmental variable arrows
  geom_segment(data = env_df,
               aes(x = 0, y = 0, xend = CCA1*2, yend = CCA2*2),
               arrow = arrow(length = unit(0.2, "cm")), 
               color = "black", size = 1) +
  geom_text(data = env_df,
            aes(x = CCA1*2.2, y = CCA2*2.2, label = variable),
            color = "black", fontface = "bold", size = 3) +
  # Top species text
  geom_text(data = species_df,
            aes(x = CCA1, y = CCA2, label = species),
            color = "black", alpha = 0.6, size = 2.5) +
  # Individual points (faded)
  # geom_point(data = comparison_df,
  #            aes(predicted_CCA1, predicted_CCA2, color = site), 
  #            size = 2, alpha = 0.2) +
  # geom_point(data = comparison_df,
  #            aes(projected_CCA1, projected_CCA2, color = site), 
  #            size = 2, alpha = 0.3) +
  # Centroid arrows (bold)
  geom_segment(data = centroids,
               aes(x = pred_CCA1_mean, y = pred_CCA2_mean,
                   xend = proj_CCA1_mean, yend = proj_CCA2_mean,
                   color = site),
               arrow = arrow(length = unit(0.2, "cm"), type = "closed"), 
               size = 1) +
  # Centroid points
  geom_point(data = centroids,
             aes(x = pred_CCA1_mean, y = pred_CCA2_mean, color = site),
             size = 1, shape = 21, fill = "white", stroke = 1) +
  geom_point(data = centroids,
             aes(x = proj_CCA1_mean, y = proj_CCA2_mean, color = site),
             size = 1, shape = 21, stroke = 1, fill = "white") +
  # Labels for centroids
  geom_text_repel(data = centroids,
            aes(x = pred_CCA1_mean, y = pred_CCA2_mean, label = paste(site, "Pred"), color = site),
            size = 2, fontface = "bold") +
  geom_text_repel(data = centroids,
            aes(x = proj_CCA1_mean, y = proj_CCA2_mean, label = paste(site, "Obs"), color = site),
            size = 2, fontface = "bold") +
  scale_color_manual(values = color_mt) +
  scale_fill_manual(values = color_mt) +
  labs(title = "Vegetation Change: Predicted vs Observed with Environmental Drivers",
       subtitle = "Bold arrows show site centroids; faded arrows show individual plots",
       x = paste0("CCA1 (", round(summary(cca_model)$cont$importance[2,1]*100, 1), "%)"),
       y = paste0("CCA2 (", round(summary(cca_model)$cont$importance[2,2]*100, 1), "%)")) +
  theme_minimal() +
  theme(legend.position = "right")

# Calculate prediction accuracy metrics
rmse_cca1 = sqrt(mean((comparison_df$predicted_CCA1 - comparison_df$projected_CCA1)^2))
rmse_cca2 = sqrt(mean((comparison_df$predicted_CCA2 - comparison_df$projected_CCA2)^2))
correlation_cca1 = cor(comparison_df$predicted_CCA1, comparison_df$projected_CCA1)

cat("RMSE CCA1:", round(rmse_cca1, 3), "\n")
cat("RMSE CCA2:", round(rmse_cca2, 3), "\n")
cat("Correlation CCA1:", round(correlation_cca1, 3), "\n")
