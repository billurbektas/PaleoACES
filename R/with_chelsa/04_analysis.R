# Get anthropocene climate ----
## Get temperature data ----
tasmin = read_csv("output/tasmin.present.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
  mutate(
    lon = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    lat = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = lubridate::year(time),
    month = lubridate::month(time)
  ) %>%
  select(-location) %>%
  left_join(plots %>% select(lon, lat, id))

tasmin_summary = tasmin %>%
  # Calculate annual mean
  group_by(id, year) %>%
  summarize(annual_mean = mean(tasmin, na.rm = TRUE)) %>%
  ungroup()

# Calculate spring and summer means
seasonal_means = tasmin %>%
  # Define seasons (spring: months 3-5, summer: months 6-8)
  mutate(
    season = case_when(
      month %in% c(3, 4, 5) ~ "spring",
      month %in% c(6, 7, 8) ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  # Filter to include only spring and summer
  filter(!is.na(season)) %>%
  # Group and calculate means
  group_by(id, year, season) %>%
  summarize(mean_temp = mean(tasmin, na.rm = TRUE)) %>%
  ungroup() %>%
  # Create wide format for seasonal means
  pivot_wider(
    names_from = season,
    values_from = mean_temp,
    names_prefix = "mean_"
  )

# Join annual and seasonal means
tasmin_summary = tasmin_summary %>%
  left_join(seasonal_means, by = c("id", "year"))%>%
  mutate(annual_mean = annual_mean - 273.15,
         mean_spring = mean_spring - 273.15, 
         mean_summer = mean_summer - 273.15)

pdf(file = "plot/temperature_trend_anthropocene.pdf", width = 10, height = 8)
ggplot(tasmin_summary %>% 
         pivot_longer(cols = c(annual_mean, mean_spring, mean_summer), 
                      names_to = "period", 
                      values_to = "temperature")) +
  geom_line(aes(year, temperature, group = id), linewidth = 0.5, alpha = 0.1) +
  stat_smooth(aes(year, temperature), method = "lm", se = FALSE, linewidth = 1) +
  facet_grid(. ~ period) +
  theme_bw() +
  labs(x = "Year", y = "Temperature (°C)", title = "Temperature Trends")
dev.off()

## Get precipitation data ----
pre = read_csv("output/pre.present.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
  mutate(
    lon = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    lat = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = lubridate::year(time),
    month = lubridate::month(time)
  ) %>%
  select(-location) %>%
  left_join(plots %>% select(lon, lat, id))

pre_summary = pre %>%
  # Calculate annual sum
  group_by(id, year) %>%
  summarize(annual_sum = sum(pre, na.rm = TRUE)) %>%
  ungroup()

# Calculate winter, spring and summer sums
seasonal_sums = pre %>%
  # Define seasons (winter: months 12, 1, 2, spring: months 3-5, summer: months 6-8)
  mutate(
    # Create a winter year that assigns December to the following year's winter
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5) ~ "spring",
      month %in% c(6, 7, 8) ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  # Filter to include only winter, spring and summer
  filter(!is.na(season)) %>%
  # For winter, group by winter_year, for others use regular year
  group_by(id, season, year = if_else(season == "winter", winter_year, year)) %>%
  summarize(sum_pre = sum(pre, na.rm = TRUE)) %>%
  ungroup() %>%
  # Create wide format for seasonal sums
  pivot_wider(
    names_from = season,
    values_from = sum_pre,
    names_prefix = "sum_"
  )

# Join annual and seasonal sums
pre_summary = pre_summary %>%
  left_join(seasonal_sums, by = c("id", "year"))

# Create plot
pdf(file = "plot/precipitation_trend_anthropocene.pdf", width = 10, height = 8)
ggplot(pre_summary %>% 
         pivot_longer(cols = c(annual_sum, sum_winter, sum_spring, sum_summer), 
                      names_to = "period", 
                      values_to = "precipitation")) +
  geom_line(aes(year, precipitation, group = id), linewidth = 0.5, alpha = 0.1) +
  stat_smooth(aes(year, precipitation), method = "lm", se = FALSE, linewidth = 1) +
  facet_wrap(. ~ period, scales = "free", ncol = 4) +
  theme_bw() +
  labs(x = "Year", y = "Precipitation (mm)", title = "Precipitation Trends")
dev.off()

# Get holocene climate data ----
paleo_coords = 
  paleo_plots %>%
  select(Location, lon, lat)%>%
  distinct()%>%
  rename(id = Location)

## Get precipitation data ----
pre_paleo = read_csv("output/pre.paleo.ponds.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
  mutate(
    lon = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    lat = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
   ) %>%
  separate(time, into = c("year", "month", "day"), sep = "-", remove = FALSE) %>%
  mutate(
    year = if_else(year == "", paste0("-", month), year) %>% as.numeric(),
    month = if_else(year < 0, day, month) %>% as.numeric(),
    day = NULL
  ) %>%
  select(-location) %>%
  left_join(paleo_coords %>% select(lon, lat, id))

# Calculate annual sum
pre_paleo_summary = pre_paleo %>%
  group_by(id, year) %>%
  summarize(annual_sum = sum(pre, na.rm = TRUE)) %>%
  ungroup()

# Calculate winter, spring and summer sums
seasonal_sums_paleo = pre_paleo %>%
  # Define seasons (winter: months 12, 1, 2, spring: months 3-5, summer: months 6-8)
  mutate(
    # Create a winter year that assigns December to the following year's winter
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5) ~ "spring",
      month %in% c(6, 7, 8) ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  # Filter to include only winter, spring and summer
  filter(!is.na(season)) %>%
  # For winter, group by winter_year, for others use regular year
  group_by(id, season, year = if_else(season == "winter", winter_year, year)) %>%
  summarize(sum_pre = sum(pre, na.rm = TRUE)) %>%
  ungroup() %>%
  # Create wide format for seasonal sums
  pivot_wider(
    names_from = season,
    values_from = sum_pre,
    names_prefix = "sum_"
  )

# Join annual and seasonal sums
pre_paleo_summary = pre_paleo_summary %>%
  left_join(seasonal_sums_paleo, by = c("id", "year"))

# Create plot
pdf(file = "plot/precipitation_trend_paleo.pdf", width = 10, height = 8)
ggplot(pre_paleo_summary %>% 
         pivot_longer(cols = c(annual_sum, sum_winter, sum_spring, sum_summer), 
                      names_to = "period", 
                      values_to = "precipitation")) +
  geom_line(aes(year*100, precipitation, group = id), linewidth = 0.5, alpha = 0.1) +
  stat_smooth(aes(year*100, precipitation), method = "lm", se = FALSE, linewidth = 1) +
  facet_wrap(. ~ period, scales = "free", ncol = 4) +
  theme_bw() +
  labs(x = "Year", y = "Precipitation (mm)", title = "Paleoclimate Precipitation Trends")
dev.off()

## Get temperature data -----
tasmin_paleo = read_csv("output/tasmin.paleo.ponds.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
  mutate(
    lon = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    lat = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    # Convert temperature from Kelvin to Celsius
    tasmin = tasmin - 273.15
  ) %>%
  separate(time, into = c("year_part", "month_part", "day_part"), sep = "-", remove = FALSE) %>%
  mutate(
    # Handle negative years correctly
    year = if_else(year_part == "", paste0("-", month_part), year_part) %>% as.numeric(),
    month = if_else(year < 0, day_part, month_part) %>% as.numeric(),
    # No need to keep the day and separated parts
    year_part = NULL,
    month_part = NULL,
    day_part = NULL
  ) %>%
  select(-location) %>%
  left_join(paleo_coords %>% select(lon, lat, id))

# Calculate annual mean
tasmin_paleo_summary = tasmin_paleo %>%
  group_by(id, year) %>%
  summarize(annual_mean = mean(tasmin, na.rm = TRUE)) %>%
  ungroup()

# Calculate winter, spring and summer means
seasonal_means_paleo = tasmin_paleo %>%
  # Define seasons (winter: months 12, 1, 2, spring: months 3-5, summer: months 6-8)
  mutate(
    # Create a winter year that assigns December to the following year's winter
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5) ~ "spring",
      month %in% c(6, 7, 8) ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  # Filter to include only winter, spring and summer
  filter(!is.na(season)) %>%
  # For winter, group by winter_year, for others use regular year
  group_by(id, season, year = if_else(season == "winter", winter_year, year)) %>%
  summarize(mean_temp = mean(tasmin, na.rm = TRUE)) %>%
  ungroup() %>%
  # Create wide format for seasonal means
  pivot_wider(
    names_from = season,
    values_from = mean_temp,
    names_prefix = "mean_"
  )

# Rename the winter column to winter_mean to differentiate it
seasonal_means_paleo = seasonal_means_paleo %>%
  rename(winter_mean = mean_winter)

# Join annual and seasonal means
tasmin_paleo_summary = tasmin_paleo_summary %>%
  left_join(seasonal_means_paleo, by = c("id", "year"))

# Create plot
pdf(file = "plot/temperature_trend_paleo.pdf", width = 10, height = 8)
ggplot(tasmin_paleo_summary %>% 
         pivot_longer(cols = c(annual_mean, winter_mean, mean_spring, mean_summer), 
                      names_to = "period", 
                      values_to = "temperature")) +
  geom_line(aes(year*100, temperature, group = id), linewidth = 0.5, alpha = 0.1) +
  stat_smooth(aes(year*100, temperature), method = "lm", se = FALSE, linewidth = 1) +
  facet_wrap(. ~ period, scales = "free", ncol = 4) +
  theme_bw() +
  labs(x = "Year", y = "Temperature (°C)", title = "Paleoclimate Temperature Trends")
dev.off()

env.ant = left_join(tasmin_summary, pre_summary)
env.paleo = left_join(tasmin_paleo_summary, pre_paleo_summary)
env.paleo =
  left_join(tasmin_paleo_summary, pre_paleo_summary)%>%
  filter(year<0)%>%
  mutate(year = year * 100)%>%
  mutate(year = year * (-1))

paleo_plots = paleo_plots %>%
  mutate(
    year = ceiling(Predicted_Age / 100) * 100,
    period = paste0(year, "-", year - 100)
  ) 

env.paleo = 
  left_join(paleo_plots %>% rename(id = Location), env.paleo)

climate_data_scaled = env.ant %>%
  select(id, year, annual_mean, mean_spring, mean_summer, 
         annual_sum, sum_spring, sum_summer, sum_winter) %>%
  mutate(across(c(annual_mean, mean_spring, mean_summer, 
                  annual_sum, sum_spring, sum_summer, sum_winter), scale))

climate_means = climate_data_scaled %>%
  filter(year >= 1980 & year <= 1985 | year >= 2015 & year <= 2020) %>%
  mutate(period = ifelse(year <= 1985, "past", "present")) %>%
  group_by(id, period) %>%
  summarize(across(c(annual_mean, mean_spring, mean_summer, 
                     annual_sum, sum_spring, sum_summer, sum_winter),
                   mean, na.rm = TRUE),
            .groups = "drop")

climate_wide = climate_means %>%
  pivot_wider(
    id_cols = id,
    names_from = period,
    values_from = c(annual_mean, mean_spring, mean_summer, 
                    annual_sum, sum_spring, sum_summer, sum_winter)
  )

env = 
  climate_means %>%
  mutate(id = paste0(period, "_", id))%>%
  column_to_rownames(var = "id")%>%
  select(-period)%>%
  select(annual_mean, annual_sum)%>%
  rename(MAT = annual_mean, MAP = annual_sum)

env.holocene = 
  env.paleo %>%
  na.omit()%>%
  select(id, plot, year, annual_mean, annual_sum)%>%
  rename(MAT = annual_mean, MAP = annual_sum)%>%
  mutate(across(c(MAT, MAP), scale))
  

period <- ifelse(grepl("^past", rownames(env)), "past", "present")
  
  # Plot PCA biplot with custom colors
  fviz_pca_biplot(PCA(env), repel = TRUE,
                  col.var = "#2E9FDF",         # Color for variables (arrows)
                  col.ind = period,            # Color individuals by period
                  palette = c("past" = "#E69F00", "present" = "#56B4E9"),
                  title = "PCA Biplot - Environmental Data (Past vs Present)", label = "var")
# CCA ----
comm = result$matrix2
paleo_comm = result$matrix1

cca_model <- cca(comm ~ ., data = env[rownames(comm),])
summary(cca_model)
RsquareAdj(cca_model)$r.squared
RsquareAdj(cca_model)$adj.r.squared
anova(cca_model)
anova(cca_model, by = "axis")
screeplot(cca_model, bstick = TRUE, main = "Broken-stick model")

# Predict holocene
holocene_scores <- predict(cca_model, newdata = env.holocene %>% select(MAT, MAP), 
                           type = "lc")
holocene_df <- as.data.frame(holocene_scores)
holocene_df$period <- "holocene"
holocene_df$year = env.holocene$year
holocene_df$period = ifelse(env.holocene$year<3000, "3000 - 0", "6000 - 3000")
holocene_centroids = 
  holocene_df %>%
  group_by(period)%>%
  summarize(CCA1 = mean(CCA1),
            CCA2 = mean(CCA2))
  
holocene_comm_scores <- predict(cca_model, newdata = paleo_comm[env.holocene$plot,], type = "wa")
holocene_comm_df <- as.data.frame(holocene_comm_scores)
holocene_comm_df$year <- env.holocene$year
holocene_comm_df$label <- env.holocene$plot
holocene_comm_df$period = ifelse(env.holocene$year<3000, "3000 - 0", "6000 - 3000")
holocene_comm_centroids = 
  holocene_comm_df %>%
  group_by(period)%>%
  summarize(CCA1 = mean(CCA1),
            CCA2 = mean(CCA2))
# Extract scores for sites and environmental variables
site_scores <- scores(cca_model, display = "sites")
env_scores <- scores(cca_model, display = "bp")

# Create a data frame for sites
site_df <- as.data.frame(site_scores)
site_df$period <- ifelse(grepl("^past", rownames(site_df)), "past", "present")
site_df$site_id <- str_remove(rownames(site_df), "^past_|^present_")

# Create a data frame for environmental variables
env_df <- as.data.frame(env_scores)
env_df$env_var <- rownames(env_df)

# Add scaling factor for arrows
arrow_scale <- 8

# Scale the environmental scores to make arrows more visible
env_df$CCA1 <- env_df$CCA1 * arrow_scale
env_df$CCA2 <- env_df$CCA2 * arrow_scale

# Calculate centroids for each period
centroids <- site_df %>%
  group_by(period) %>%
  summarize(
    CCA1 = mean(CCA1),
    CCA2 = mean(CCA2)
  )

# Now create the plot with points, arrows, and centroids
ggplot() +
  # Add site points
  geom_point(data = site_df, aes(x = CCA1, y = CCA2, color = period), size = 1, alpha = 0.8) +
  # Add environmental arrows
  geom_segment(data = env_df, aes(x = 0, y = 0, xend = CCA1, yend = CCA2),
               arrow = arrow(length = unit(0.2, "cm")), color = "blue") +
  # Add environmental variable labels
  geom_text(data = env_df, aes(x = CCA1 * 1.1, y = CCA2 * 1.1, label = env_var),
            color = "blue", size = 5) +
  # Add centroids as larger points with black outline
  geom_point(data = centroids, aes(x = CCA1, y = CCA2, color = period), 
             size = 4, shape = 8, fill = "white") +
  # Add labs and theme
  labs(title = "CCA of Species Composition", x = "CCA1", y = "CCA2") +
  theme_minimal() +
  scale_color_manual(values = c("past" = "grey50", "present" = "black")) +
  # Add intersecting lines at origin
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray")+
  geom_point(data = holocene_df, aes(x = CCA1, y = CCA2, fill = period), shape = 21, size = 2, alpha = 0.7)+
  geom_point(data = holocene_centroids, aes(x = CCA1, y = CCA2, fill = period), shape = 21, size = 4)+
  geom_point(data = holocene_comm_df, aes(x = CCA1, y = CCA2, fill = period), 
            shape = 22, size = 2, alpha = 0.7)+
  geom_point(data = holocene_comm_centroids, aes(x = CCA1, y = CCA2, fill = period), 
         shape = 22, size = 4)

# RDA ----
rda_result = rda(comm ~ ., data = env)
summary(rda_result)

# Calculate the variance explained by each axis
R2 = RsquareAdj(rda_result)$r.squared
R2adj = RsquareAdj(rda_result)$adj.r.squared
cat("Variance explained (R²):", R2, "\n")
cat("Adjusted variance explained (R² adj):", R2adj, "\n")

anova_rda = anova.cca(rda_result)
print(anova_rda)

anova_axis = anova.cca(rda_result, by = "axis")
print(anova_axis)

plot(rda_result, scaling = 2, main = "RDA Biplot - Species and Environmental Variables")

# Extract species scores (scaling 2)
species_scores = scores(rda_result, choices = 1:2, scaling = 2, display = "species") %>% 
  as.data.frame() %>%
  rownames_to_column(var = "species")

# Extract environmental variable scores (biplot)
env_scores = scores(rda_result, choices = 1:2, scaling = 2, display = "bp") %>% 
  as.data.frame() %>%
  rownames_to_column(var = "env_var")

# Extract site scores
site_scores = scores(rda_result, choices = 1:2, scaling = 2, display = "sites") %>%
  as.data.frame() %>%
  rownames_to_column(var = "site_id")

# Modified grouping based on whether site names contain "past" or "present"
site_scores = site_scores %>%
  mutate(site_group = case_when(
    str_detect(site_id, "^present") ~ "Present",
    str_detect(site_id, "^past") ~ "Past",
    TRUE ~ "Other"
  ))

# Calculate centroids for site groups
centroids = site_scores %>%
  group_by(site_group) %>%
  summarize(
    mean_x = mean(RDA1),
    mean_y = mean(RDA2)
  )

# Create the plot with adjusted scales
rda_plot = ggplot() +
  # Set adjusted limits based on the actual range of your data
  # You might need to adjust these values based on your actual data
  xlim(-2.5, 2.5) + ylim(-2.5, 2.5) +
  
  # Add reference lines
  geom_vline(xintercept = 0, color = "grey60") +
  geom_hline(yintercept = 0, color = "grey60") +
  
  # Add site points
  geom_point(data = site_scores, 
             aes(x = RDA1, y = RDA2, fill = site_group),
             shape = 21, size = 3, color = "white") +
  
  # Add centroids
  geom_point(data = centroids, 
             aes(x = mean_x, y = mean_y, fill = site_group),
             size = 4, shape = 23) +
  
  # Add species vectors
  geom_segment(data = species_scores,
               aes(x = 0, y = 0, xend = RDA1, yend = RDA2),
               arrow = arrow(type = "closed", length = unit(0.15, "inches")),
               color = "grey50", size = 0.8) +
  
  # Add species labels
  geom_text_repel(data = species_scores,
                  aes(x = RDA1, y = RDA2, label = species),
                  color = "grey50", min.segment.length = Inf, 
                  force = 10, size = 3.5) +
  
  # Add environmental vectors (longer for visibility)
  geom_segment(data = env_scores,
               aes(x = 0, y = 0, xend = RDA1 * 2, yend = RDA2 * 2),
               color = "#43AA8B", 
               arrow = arrow(type = "open", length = unit(0.1, "inches"))) +
  
  # Add environmental variable labels
  geom_text_repel(data = env_scores,
                  aes(x = RDA1 * 2, y = RDA2 * 2, label = env_var),
                  color = "#43AA8B", force = 100,
                  nudge_x = 0.1, nudge_y = 0.1, 
                  min.segment.length = Inf, size = 3.5) +
  
  # Set distinct colors for Past/Present groups
  scale_fill_manual(values = c(
    "Past" = "#E76F51", 
    "Present" = "#2A9D8F", 
    "Other" = "#E9C46A"
  )) +
  
  # Theme
  theme_bw() +
  theme(legend.position = "bottom",
        text = element_text(size = 14),
        legend.box = "vertical") +
  
  # Labels
  labs(x = "RDA1", y = "RDA2", fill = "Time Period")

# Display the plot
print(rda_plot)

# Bray - Curtis ----
## Present ----
# Extract site codes (without the time prefix)
site_codes = rownames(comm) %>%
  str_remove("^past_past_|^present_past_past_") %>%
  unique()

# Function to calculate Bray-Curtis dissimilarity for a single site
calc_bray_curtis = function(site_code, data_matrix) {
  # Extract rows for past and present for this site
  past_row = data_matrix[paste0("past_past_", site_code), , drop = FALSE]
  present_row = data_matrix[paste0("present_past_past_", site_code), , drop = FALSE]
  
  # Calculate Bray-Curtis dissimilarity
  vegdist(rbind(past_row, present_row), method = "bray")[1]
}

# Calculate Bray-Curtis dissimilarity for all sites
results = map_dfr(site_codes, ~{
  bc_dist = calc_bray_curtis(.x, comm)
  tibble(
    site = .x,
    bray_curtis = bc_dist
  )
})

# Display results
results

climate_data_scaled = env.ant %>%
  select(id, year, annual_mean, mean_spring, mean_summer, 
         annual_sum, sum_spring, sum_summer, sum_winter) %>%
  mutate(across(c(annual_mean, mean_spring, mean_summer, 
                  annual_sum, sum_spring, sum_summer, sum_winter), scale))

climate_means = climate_data_scaled %>%
  filter(year >= 1980 & year <= 1985 | year >= 2015 & year <= 2020) %>%
  mutate(period = ifelse(year <= 1985, "past", "present")) %>%
  group_by(id, period) %>%
  summarize(across(c(annual_mean, mean_spring, mean_summer, 
                     annual_sum, sum_spring, sum_summer, sum_winter),
                   mean, na.rm = TRUE),
            .groups = "drop")

climate_wide = climate_means %>%
  pivot_wider(
    id_cols = id,
    names_from = period,
    values_from = c(annual_mean, mean_spring, mean_summer, 
                    annual_sum, sum_spring, sum_summer, sum_winter)
  )

euclidean_distances = climate_wide %>%
  rowwise() %>%
  mutate(
    euclidean_distance = sqrt(
      (annual_mean_present - annual_mean_past)^2 +
      
        (sum_spring_present - sum_spring_past)^2 +
        (sum_winter_present - sum_winter_past)^2
    )
  ) %>%
  select(id, euclidean_distance)

euclidean_distances

results = left_join(results %>% rename(id = site), euclidean_distances)

results = results %>% mutate(ratio = bray_curtis/euclidean_distance)

ggplot(results, aes(ratio))+
  geom_density()

ggplot(results, aes(euclidean_distance, bray_curtis))+
  geom_point()+
  geom_smooth(method = "lm")

## Paleo ----
env.paleo =
  left_join(tasmin_paleo_summary, pre_paleo_summary)%>%
  filter(year<0)%>%
  mutate(year = year * 100)%>%
  mutate(year = year * (-1))
  

# Create the periods dynamically
paleo_plots = paleo_plots %>%
  mutate(
    year = ceiling(Predicted_Age / 100) * 100,
    period = paste0(year, "-", year - 100)
  ) 

env.paleo = 
  left_join(paleo_plots %>% rename(id = Location), env.paleo)
  
# Function to calculate Bray-Curtis between consecutive time points
calc_bray_consecutive = function(plot_name, data_matrix, plot_data) {
  # Get all time points for this plot, sorted by age
  plot_times = plot_data %>% 
    filter(str_detect(plot, paste0("^", plot_name))) %>%
    arrange(Predicted_Age)
  
  # For consecutive time points, calculate Bray-Curtis
  results = tibble(
    plot_t1 = character(),
    plot_t2 = character(),
    age_t1 = numeric(),
    age_t2 = numeric(),
    bray_curtis = numeric()
  )
  
  # If we have at least 2 time points
  if (nrow(plot_times) >= 2) {
    for (i in 1:(nrow(plot_times)-1)) {
      # Get the plot names
      plot1 = plot_times$plot[i]
      plot2 = plot_times$plot[i+1]
      
      # Extract community data for these plots
      comm1 = data_matrix[plot1, , drop = FALSE]
      comm2 = data_matrix[plot2, , drop = FALSE]
      
      # Calculate Bray-Curtis
      bc = vegdist(rbind(comm1, comm2), method = "bray")[1]
      
      # Add to results
      results = results %>% add_row(
        plot_t1 = plot1,
        plot_t2 = plot2,
        age_t1 = plot_times$Predicted_Age[i],
        age_t2 = plot_times$Predicted_Age[i+1],
        bray_curtis = bc
      )
    }
  }
  
  return(results)
}

# Get unique location names (assuming format like "JayBath")
locations = paleo_plots %>% 
  pull(Location) %>% 
  unique()

paleobc = map_dfr(locations, ~{
  calc_bray_consecutive(.x, paleo_cleaned, paleo_plots) %>%
    mutate(location = .x)
}) %>%
  # Calculate additional metrics
  mutate(
    time_diff = age_t2 - age_t1,
    bray_per_year = bray_curtis / time_diff
  )
