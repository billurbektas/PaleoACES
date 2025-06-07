env_present = read_csv("data/anthropocene_coords_climNA_Decade_2011_2019MSY.csv")%>%
  select(-Latitude, -Longitude, -id2)%>%
  group_by(id1)%>%
  summarize_all(mean)%>%
  rename(site = id1)%>%
  select(site, PAS, MAT, CMI)%>%
  mutate(era = "present")
  
env_past = read_csv("data/anthropocene_coords_climNA_Decade_1971_1980MSY.csv")%>%
  select(-Latitude, -Longitude, -id2)%>%
  group_by(id1)%>%
  summarize_all(mean)%>%
  rename(site = id1)%>%
  select(site, PAS, MAT, CMI)%>%
  mutate(era = "past")

env_paleo_1000 = read_csv("data/paleo_coords_climNA_4GCM-Ensemble_past1000MSY.csv")%>%
  select(-Latitude, -Longitude, -id2)%>%
  group_by(id1)%>%
  summarize_all(mean)%>%
  rename(site = id1)%>%
  select(site, PAS, MAT, CMI)%>%
  mutate(era = "holocene_1000")

env_paleo_6000 = read_csv("data/paleo_coords_climNA_4GCM-Ensemble_midHoloceneMSY.csv")%>%
  select(-Latitude, -Longitude, -id2)%>%
  group_by(id1)%>%
  summarize_all(mean)%>%
  rename(site = id1)%>%
  select(site, PAS, MAT, CMI)%>%
  mutate(era = "holocene_6000")

env = bind_rows(env_past, env_present, env_paleo_1000, env_paleo_6000)
era = env$era
# Create the base plot
p = fviz_pca_biplot(PCA(env %>% select(-site, -era)), 
                    repel = TRUE,
                    col.var = "grey30",
                    pointshape = 16,
                    alpha = 0.4,
                    col.ind = era,
                    palette = color_era2,
                    mean.point.size = 4,
                    label = "var",
                    title = "") +
  theme(legend.position = "bottom", legend.title = element_blank(),
        text = element_text(size = 16))
p
# Calculate centroid coordinates
pca_data = PCA(env %>% select(-site, -era), graph = FALSE)
coords = as.data.frame(pca_data$ind$coord[,1:2])
coords$era = env$era

centroids = coords %>%
  group_by(era) %>%
  summarise(x = mean(Dim.1), y = mean(Dim.2))

# Define the trajectory order
trajectory = c("holocene_6000", "holocene_1000", "past", "present")
centroids = centroids %>% 
  slice(match(trajectory, era))

# Create arrow segments manually
arrows_df = data.frame(
  x = centroids$x[1:3],
  y = centroids$y[1:3],
  xend = centroids$x[2:4],
  yend = centroids$y[2:4]
)[-2,]

# Add arrows
pdf(file = "plot/climate_PCA.pdf", height = 6, width = 8)
p1 = p + geom_segment(data = arrows_df,
                 aes(x = x, y = y, xend = xend, yend = yend),
                 arrow = arrow(length = unit(0.2, "cm"), type = "closed"),
                 color = "grey20", size = 1, alpha = 0.8)
p1
dev.off()

# Get PCA coordinates for all points
pca_data = PCA(env %>% select(-site, -era), graph = FALSE)
coords = as.data.frame(pca_data$ind$coord[,1:2])
coords$site = env$site
coords$era = env$era

# Calculate climate change between time periods
climate_change = coords %>%
  select(site, era, Dim.1, Dim.2) %>%
  pivot_wider(names_from = era, values_from = c(Dim.1, Dim.2)) %>%
  mutate(
    holocene = sqrt((Dim.1_holocene_1000 - Dim.1_holocene_6000)^2 + 
                             (Dim.2_holocene_1000 - Dim.2_holocene_6000)^2),
    anthropocene = sqrt((Dim.1_present - Dim.1_past)^2 + 
                                 (Dim.2_present - Dim.2_past)^2)
  ) %>%
  select(site, holocene, anthropocene)%>%
  mutate(type = "multidimension")%>%
  bind_rows(env %>%
              pivot_longer(cols = c(-site, -era), names_to = "type")%>%
              pivot_wider(names_from = "era", values_from = "value")%>%
              mutate(anthropocene = present-past,
                     holocene = holocene_1000 - holocene_6000
                     )%>%
              select(site, type, anthropocene, holocene)
            )%>%
  pivot_longer(cols = c(-site, -type))%>%
  mutate(name = factor(name, levels = c("holocene", "anthropocene")))%>%
  mutate(type = factor(type,levels = c("multidimension", "MAT", "CMI", "PAS")))

p2 = ggplot(climate_change, aes(type, value, color = name)) +
  geom_violin(position = position_dodge(width = 0.8), show.legend = FALSE) +
  stat_summary(fun = mean, geom = "point", size = 3, shape = 16, position = position_dodge(width = 0.8)) +
  stat_summary(fun = mean, geom = "text", aes(label = round(..y.., 2)), vjust = -0.6, 
               position = position_dodge(width = 0.8), show.legend = FALSE)+
  facet_wrap(~type, scales = "free",ncol = 4)+
  theme_bw()+
  theme(legend.title = element_blank(),
        legend.position = "bottom",
        text = element_text(size = 16), 
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank())+
  scale_color_manual(values = color_era3)+
  xlab("")+
  ylab("Climate change \n (Difference between era)")
p2

pdf(file = "plot/climate_change.pdf", height = 6, width = 15)
ggarrange(p1, p2, labels = c("A.", "B."))
dev.off()

# Calculate climate change between time periods
pace_change = coords %>%
  select(site, era, Dim.1, Dim.2) %>%
  pivot_wider(names_from = era, values_from = c(Dim.1, Dim.2)) %>%
  mutate(
    holocene = sqrt((Dim.1_holocene_1000 - Dim.1_holocene_6000)^2 + 
                      (Dim.2_holocene_1000 - Dim.2_holocene_6000)^2),
    anthropocene = sqrt((Dim.1_present - Dim.1_past)^2 + 
                          (Dim.2_present - Dim.2_past)^2)
  ) %>%
  select(site, holocene, anthropocene)%>%
  mutate(type = "multidimension")%>%
  bind_rows(env %>%
              pivot_longer(cols = c(-site, -era), names_to = "type")%>%
              pivot_wider(names_from = "era", values_from = "value")%>%
              mutate(anthropocene = present-past,
                     holocene = holocene_1000 - holocene_6000
              )%>%
              select(site, type, anthropocene, holocene)
  )%>%
  mutate(anthropocene = anthropocene/40,
        holocene = holocene/5000)%>%
  pivot_longer(cols = c(-site, -type), names_to = "era")%>%
  group_by(era, type)%>%
  summarize(mean = round(mean(value),5),
            sd = round(sd(value),5),
            se = round(sd(value) / sqrt(n()),5),
            .groups = "drop")%>%
  bind_rows(jaccard %>%
              mutate(pace = jaccard_dissimilarity/40)%>%
              summarize(mean = round(mean(pace),5),
                        sd = round(sd(pace),5),
                        se = round(sd(pace) / sqrt(n()),5),
                        .groups = "drop")%>%
              mutate(era = "anthropocene",
                     type = "vegetation")
            )%>%
  mutate(Location = NA)%>%
  bind_rows(pred_at_1000 %>%
              mutate(pred = round(pred/5000, 5))%>%
              select(-Predicted_Age)%>%
              mutate(era = "holocene",
                     type = "vegetation")%>%
              rename(mean = pred)
              )%>%
  mutate(era = factor(era, level = c("holocene", "anthropocene")))%>%
  mutate(type = factor(type, level = c("multidimension", "MAT", "CMI", "PAS", "vegetation")))

pace_change_wide = pace_change %>%
  select(era, type, mean, Location) %>%
  group_by(era, type)%>%
  summarize(mean = mean(mean))%>%
  pivot_wider(names_from = era, values_from = mean) %>%
  mutate(fold_change = anthropocene / holocene,
         fold_change_text = paste0(round(fold_change), "x"))

p3 = ggplot(pace_change, aes(x = era, y = mean, color = era, fill = Location)) +
  geom_pointrange(aes(ymin = mean - se, ymax = mean + se), 
                  position = position_dodge(width = 0.3),
                  size = 0.8, fatten = 3, shape = 21) +
  geom_text_repel(aes(label = mean), 
            position = position_dodge(width = 0.3),
            vjust = -1.5, size = 3, show.legend = FALSE, min.segment.length = 100 ) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  facet_wrap(~type, scales = "free", ncol = 5) +
  geom_segment(data = pace_change_wide,
               aes(x = 1, y = holocene, xend = 2, yend = anthropocene),
               arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
               color = "grey40", inherit.aes = FALSE) +
  geom_text(data = pace_change_wide,
            aes(x = 1, y = (holocene + anthropocene)/2, label = fold_change_text),
            color = "black", size = 5, inherit.aes = FALSE, fontface = "bold" ) +
  theme_bw() +
  theme(legend.position = "bottom",
        text = element_text(size = 12)
        ) +
  scale_color_manual(values = color_era3) +
  scale_fill_manual(values = color_site, na.value = "white", na.translate = FALSE) +
  labs(x = "", 
       y = "Pace of climate change",
       color = "") +
  guides(color = guide_legend(override.aes = list(size = 3)))

pdf(file = "plot/pace_climate_change.pdf", height = 6, width = 12)
p3
dev.off()

