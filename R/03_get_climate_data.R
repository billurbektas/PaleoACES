# Dowload chelsa ----
# Get MORA data
load(here("data/MORA_overstory.rda"))
load(here("data/MORA_plots.rda"))
MORA_occ = over_long %>% filter(count>0)
MORA_plot_info = plot_info %>% filter(plot_id %in% MORA_occ$plot_id)
chelsa_mora_plot = MORA_plot_info %>% 
  rename(lon = longitude, lat = latitude, id = plot_id)%>%
  select(lon, lat, id)

# Get NOCA data
NOCA_occ = read_csv(here("output/NOCA_occ.csv"))
NOCA_plot_info = read_csv(here("output/NOCA_plot_info.csv")) %>%
  rename(latitude = Latitude, longitude = Longitude) %>%
  filter(plot_id %in% NOCA_occ$plot_id)
chelsa_noca_plot = NOCA_plot_info %>% 
  rename(lon = longitude, lat = latitude, id = plot_id)%>%
  select(lon, lat, id)

# Get Chelsa NOCA ----
if(!file.exists(here("output/noca_climate/tasmin.present.csv"))){
noca_tasmin = get_chelsa_data(chelsa_noca_plot, "tasmin", "present")
}
if(!file.exists(here("output/noca_climate/pre.present.csv"))){
  noca_pre = get_chelsa_data(chelsa_noca_plot, "pr", "present")
}
if(!file.exists(here("output/noca_climate/tasmin.paleo.csv"))){
  noca_tasmin_paleo = get_chelsa_data(chelsa_noca_plot, "tasmin", "paleo")
}
if(!file.exists(here("output/noca_climate/pre.paleo.csv"))){
  noca_pre_paleo = get_chelsa_data(chelsa_noca_plot, "pr", "paleo")
}

# Get Chelsa MORA ----
if(!file.exists(here("output/mora_climate/tasmin.present.csv"))){
  noca_tasmin = get_chelsa_data(chelsa_mora_plot, "tasmin", "present")
}
if(!file.exists(here("output/mora_climate/pre.present.csv"))){
  noca_pre = get_chelsa_data(chelsa_mora_plot, "pr", "present")
}
if(!file.exists(here("output/mora_climate/tasmin.paleo.csv"))){
  noca_tasmin_paleo = get_chelsa_data(chelsa_mora_plot, "tasmin", "paleo")
}
if(!file.exists(here("output/mora_climate/pre.paleo.csv"))){
  noca_pre_paleo = get_chelsa_data(chelsa_mora_plot, "pr", "paleo")
}

# Get anthropocene climate ----
## Get temperature data ----
tasmin = 
  bind_rows(
  read_csv("output/mora_climate/tasmin.present.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = lubridate::year(time),
    month = lubridate::month(time)
  ) %>%
  select(-location) %>%
  left_join(MORA_plot_info)%>%
  mutate(site = "MORA"),
  
  read_csv("output/noca_climate/tasmin.present.csv")[, -1] %>%
    pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
    mutate(
      longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
      latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
      year = lubridate::year(time),
      month = lubridate::month(time)
    ) %>%
    select(-location) %>%
    left_join(NOCA_plot_info) %>%
    mutate(site = "NOCA")%>%
    filter(!is.na(latitude)) # There are two plots with same coordites. We take them out. "CARI449" "CARI450"
  )

tasmin_summary = 
  tasmin %>%
  # Calculate annual mean
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
  summarize(annual_mean = mean(tasmin, na.rm = TRUE)) %>%
  ungroup()

# Calculate spring and summer means
seasonal_means = tasmin %>%
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
  group_by(site, plot_id, elevation, aspect, slope, season, year = if_else(season == "winter", winter_year, year)) %>%
  summarize(mean_temp = mean(tasmin, na.rm = TRUE)) %>%
  ungroup() %>%
  # Create wide format for seasonal means
  pivot_wider(
    names_from = season,
    values_from = mean_temp,
    names_prefix = "mean_"
  )

seasonal_means = seasonal_means %>%
  rename(winter_mean = mean_winter)

# Join annual and seasonal means
tasmin_summary = tasmin_summary %>%
  left_join(seasonal_means, by = c("site","plot_id", "year", "elevation", "aspect", "slope"))%>%
  mutate(annual_mean = annual_mean - 273.15,
         mean_spring = mean_spring - 273.15, 
         mean_summer = mean_summer - 273.15,
         winter_mean = winter_mean - 273.15)

p1=
  ggplot(tasmin_summary %>% 
         pivot_longer(cols = c(annual_mean, mean_spring, mean_summer, winter_mean), 
                      names_to = "period", 
                      values_to = "temperature")) +
  geom_line(aes(year, temperature, group = plot_id, color = elevation), linewidth = 0.3, alpha = 0.05) +
  stat_smooth(aes(year, temperature), color = "black", method = "lm", se = FALSE, linewidth = 0.8, linetype = "dashed") +
  facet_grid(period~site, scales = "free") +
  theme_bw() +
  scale_color_berlin(midpoint = 1100, reverse = TRUE)+
  labs(x = "Year", y = "Temperature (°C)", title = "Anthropocene Temperature Trends", color = "Altitude (m)")
p1

## Get precipitation data ----
pre = 
  bind_rows(
  read_csv("output/mora_climate/pre.present.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = lubridate::year(time),
    month = lubridate::month(time)) %>%
  select(-location) %>%
  left_join(MORA_plot_info) %>%
  mutate(site = "MORA"),
  
  read_csv("output/noca_climate/pre.present.csv")[, -1] %>%
    pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
    mutate(
      longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
      latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
      year = lubridate::year(time),
      month = lubridate::month(time)) %>%
    select(-location) %>%
    left_join(NOCA_plot_info) %>%
    mutate(site = "NOCA") %>%
    filter(!is.na(latitude))
  
  )

pre_summary = pre %>%
  # Calculate annual sum
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
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
  group_by(site, plot_id, elevation, aspect, slope, season, year = if_else(season == "winter", winter_year, year)) %>%
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
  left_join(seasonal_sums, by = c("site","plot_id", "year", "elevation", "aspect", "slope"))

# Create plot
p2=
  ggplot(pre_summary %>% 
         pivot_longer(cols = c(annual_sum, sum_winter, sum_spring, sum_summer), 
                      names_to = "period", 
                      values_to = "precipitation")) +
  geom_line(aes(year, precipitation, group = plot_id, color = elevation), linewidth = 0.3, alpha = 0.05) +
  stat_smooth(aes(year, precipitation), color = "black", method = "lm", se = FALSE, linewidth = 0.8, linetype = "dashed") +
  facet_grid(period~site, scales = "free") +
  theme_bw() +
  scale_color_berlin(midpoint = 1100, reverse = TRUE)+
  labs(x = "Year", y = "Precipitation (mm)", title = "Anthropocene Precipitation Trends", color = "Altitude(m)")

p1 = p1 + theme(legend.key.width = unit(2, "cm"))
p2 = p2 + theme(legend.key.width = unit(2, "cm"))

pdf(file = "plot/climate_trend_anthropocene.pdf", width = 12, height = 8)
ggarrange(p1,p2, nrow = 1, ncol = 2, common.legend = TRUE, legend = "bottom")
dev.off()

# Get holocene climate data ----
# paleo_coords = 
#   paleo_plots %>%
#   select(Location, lon, lat)%>%
#   distinct()%>%
#   rename(id = Location)

## Get precipitation data ----
pre_paleo = 
  bind_rows(
  read_csv("output/mora_climate/pre.paleo.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = as.numeric(str_extract(time, "^-?\\d+"))*100,
    month = as.numeric(str_extract(time, "(?<=-\\d{1,2}-)\\d{2}")),
    day = as.numeric(str_extract(time, "\\d+$"))
  )%>%
  select(-location) %>%
  left_join(MORA_plot_info)%>%
  filter(year<0)%>%
  mutate(site = "MORA"),
  
  read_csv("output/noca_climate/pre.paleo.csv")[, -1] %>%
    pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
    mutate(
      longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
      latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
      year = as.numeric(str_extract(time, "^-?\\d+"))*100,
      month = as.numeric(str_extract(time, "(?<=-\\d{1,2}-)\\d{2}")),
      day = as.numeric(str_extract(time, "\\d+$"))
    )%>%
    select(-location) %>%
    left_join(NOCA_plot_info)%>%
    filter(year<0)%>%
    mutate(site = "NOCA")%>%
    filter(!is.na(latitude))
  )

# Calculate annual sum
pre_paleo_summary = pre_paleo %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
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
  group_by(site, plot_id, elevation, aspect, slope, season, year = if_else(season == "winter", winter_year, year)) %>%
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
  left_join(seasonal_sums_paleo, by = c("site","plot_id", "year", "elevation", "aspect", "slope"))

# Create plot
p3 = 
ggplot(pre_paleo_summary %>% 
         pivot_longer(cols = c(annual_sum, sum_winter, sum_spring, sum_summer), 
                      names_to = "period", 
                      values_to = "precipitation")) +
  geom_line(aes(year, precipitation, group = plot_id, color = elevation), linewidth = 0.3, alpha = 0.05) +
  stat_smooth(aes(year, precipitation), se = FALSE, linewidth = 0.8, color = "black",) +
  stat_smooth(aes(year, precipitation), color = "black", method = "lm", se = FALSE, linewidth = 0.8, linetype = "dashed") +
  theme_bw() +
  scale_color_berlin(midpoint = 1100, reverse = TRUE)+
  facet_grid(period~site, scales = "free") +
  theme_bw() +
  labs(x = "Year (BP)", y = "Precipitation (mm)", title = "Holocene Precipitation Trends")
p3
## Get temperature data -----
tasmin_paleo = 
  bind_rows(
  read_csv("output/mora_climate/tasmin.paleo.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = as.numeric(str_extract(time, "^-?\\d+"))*100,
    month = as.numeric(str_extract(time, "(?<=-\\d{1,2}-)\\d{2}")),
    day = as.numeric(str_extract(time, "\\d+$")))%>%
  select(-location) %>%
  left_join(plot_info)%>%
  filter(year<0)%>%
  mutate(site = "MORA"),
  
  read_csv("output/noca_climate/tasmin.paleo.csv")[, -1] %>%
    pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
    mutate(
      longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
      latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
      year = as.numeric(str_extract(time, "^-?\\d+"))*100,
      month = as.numeric(str_extract(time, "(?<=-\\d{1,2}-)\\d{2}")),
      day = as.numeric(str_extract(time, "\\d+$"))
    )%>%
    select(-location) %>%
    left_join(NOCA_plot_info)%>%
    filter(year<0)%>%
    filter(!is.na(latitude))%>%
    mutate(site = "NOCA")
  )

# Calculate annual mean
tasmin_paleo_summary = tasmin_paleo %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
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
  group_by(site, plot_id, elevation, aspect, slope, season, year = if_else(season == "winter", winter_year, year)) %>%
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
  left_join(seasonal_means_paleo, by = c("site","plot_id", "year", "elevation", "aspect", "slope"))%>%
  mutate(annual_mean = annual_mean - 273.15,
         mean_spring = mean_spring - 273.15, 
         mean_summer = mean_summer - 273.15,
         winter_mean = winter_mean - 273.15)

# Create plot
p4 = ggplot(tasmin_paleo_summary %>% 
         pivot_longer(cols = c(annual_mean, winter_mean, mean_spring, mean_summer), 
                      names_to = "period", 
                      values_to = "temperature")) +
  geom_line(aes(year, temperature, group = plot_id, color = elevation), linewidth = 0.3, alpha = 0.05) +
  stat_smooth(aes(year, temperature), se = FALSE, linewidth = 0.8, color = "black",) +
  stat_smooth(aes(year, temperature), color = "black", method = "lm", se = FALSE, linewidth = 0.8, linetype = "dashed") +
  theme_bw() +
  scale_color_berlin(midpoint = 1100, reverse = TRUE)+
  facet_grid(period~site, scales = "free") +
  theme_bw() +
  labs(x = "Year (BP)", y = "Temperature (°C)", title = "Holocene Temperature Trends", color = "Altitude (m)")

p3 = p3 + theme(legend.key.width = unit(2, "cm"))
p4 = p4 + theme(legend.key.width = unit(2, "cm"))

pdf(file = "plot/climate_trend_holocene.pdf", width = 12, height = 8)
ggarrange(p4,p3, nrow = 1, ncol = 2, common.legend = TRUE, legend = "bottom")
dev.off()

# Climate PCA ----
climate = left_join(bind_rows(tasmin_paleo_summary %>% mutate(era = "holocene"),
                    tasmin_summary %>% mutate(era = "anthropocene")),
                    bind_rows(pre_paleo_summary %>% mutate(era = "holocene"),
                              pre_summary %>% mutate(era = "anthropocene")))%>%
  rename(MAT = annual_mean, MSpT = mean_spring, MST = mean_summer,
         MWT = winter_mean, AP = annual_sum, SpP = sum_spring, SP = sum_summer,
         WP = sum_winter
         )

climate_summary =
  climate %>%
  mutate(period = case_when(
    year %in% 1981:1986 ~ "past",
    year %in% 2010:2019 ~ "present", 
    TRUE ~ as.character(year)
  )) %>%
  group_by(site, era, period, plot_id, elevation, slope, aspect) %>%
  summarize(across(c(MAT, MSpT, MST, MWT, AP, SpP, SP, WP), \(x) mean(x, na.rm = TRUE)), .groups = "drop")%>%
  filter(!period %in% as.character(c(1987:2009, 2020)))
  
climate_timeseries = climate %>%
  mutate(period = case_when(
    year %in% 1981:1986 ~ "past",
    year %in% 2010:2019 ~ "present", 
    TRUE ~ as.character(year)
  )) %>%
  filter(!year %in% c(1987:2009, 2020)) %>%
  mutate(time_order = case_when(
    year < 0 ~ year,
    period == "past" ~ 1983.5,
    period == "present" ~ 2014.5
  )) %>%
  pivot_longer(cols = c(MAT, MSpT, MST, MWT, AP, SpP, SP, WP), 
               names_to = "variable", values_to = "value")

ggplot(climate_timeseries, aes(x = time_order, y = value)) +
  geom_line(aes(group = interaction(site, plot_id))) +
  facet_grid(variable ~ site, scales = "free_y") +
  labs(x = "Time", y = "Climate Value") +
  theme_minimal()

climate_cor1 = climate_summary %>% 
  filter(era == "anthropocene") %>%
  select(MAT, MSpT, MST, MWT, AP, SpP, SP, WP) %>%
  cor(use = "complete.obs")

climate_cor2 = climate_summary %>% 
  filter(era == "holocene") %>%
  select(MAT, MSpT, MST, MWT, AP, SpP, SP, WP) %>%
  cor(use = "complete.obs")

climate_cor3 = climate %>% 
  filter(era == "anthropocene") %>%
  select(MAT, MSpT, MST, MWT, AP, SpP, SP, WP) %>%
  cor(use = "complete.obs")

climate_cor4 = climate %>% 
  filter(era == "holocene") %>%
  select(MAT, MSpT, MST, MWT, AP, SpP, SP, WP) %>%
  cor(use = "complete.obs")

pdf(file = "plot/climate_correlations_sum.pdf", width = 10, height = 8)
par(mfrow = c(1, 2))
corrplot(climate_cor1, method = "color", type = "upper", diag = FALSE, addCoef.col = "black", title = "Anthropocene")
corrplot(climate_cor2, method = "color", type = "upper", diag = FALSE, addCoef.col = "black", title = "Holocene")
dev.off()

pdf(file = "plot/climate_correlations.pdf", width = 10, height = 8)
par(mfrow = c(1, 2))
corrplot(climate_cor3, method = "color", type = "upper", diag = FALSE, addCoef.col = "black", title = "Anthropocene")
corrplot(climate_cor4, method = "color", type = "upper", diag = FALSE, addCoef.col = "black", title = "Holocene")
dev.off()

era = climate_summary %>% select(era) %>% pull(era)
site = climate_summary %>% select(site) %>% pull(site)
period = climate_summary %>% select(period) %>% pull(period)

# Create the base plot
p = fviz_pca_biplot(PCA(climate_summary %>% select(MST, MWT, SpP, WP)), 
                    repel = TRUE,
                    col.var = "grey30",
                    alpha = 0.1,
                    pointshape = 21,
                    col.ind = site,
                    fill.ind = era,
                    mean.point.size = 4,
                    label = "var",
                    title = "") +
  theme(legend.position = "bottom", legend.title = element_blank(),
        text = element_text(size = 16))+
  scale_fill_manual(values=color_era3)+
  scale_color_manual(values = color_mt)
  

p

# Calculate centroid coordinates

pca_result = PCA(climate_summary %>% select(MST, MWT, SpP, WP))
pca_coords = as.data.frame(pca_result$ind$coord[,1:2])
pca_coords$site = climate_summary$site
pca_coords$period = climate_summary$period

dfcentroids = pca_coords %>%
  group_by(site, period) %>%
  summarise(PC1 = mean(Dim.1), PC2 = mean(Dim.2), .groups = "drop") %>%
  mutate(period_num = ifelse(period == "past", 1983.5, 
                             ifelse(period == "present", 2014.5, period))) %>%
  mutate(period_num = as.numeric(period_num)) %>%
  arrange(site, period_num)

# Filter for 1000-year intervals in paleo period
paleo_1000yr = dfcentroids %>%
  filter(period_num < 0 & period_num %% 1000 == 0) %>%
  bind_rows(dfcentroids %>% filter(period %in% c("past", "present")))

# Add era information to paleo data
paleo_1000yr = paleo_1000yr %>%
  mutate(era = ifelse(period_num < 0, "holocene", "anthropocene"),
         period_label = case_when(
           period == "past" ~ "past",
           period == "present" ~ "present",
           period_num < 0 ~ paste0(period_num/1000, "k")
         ))

# Create arrow segments for paleo (1000yr intervals) and modern periods
arrows = paleo_1000yr %>%
  group_by(site) %>%
  mutate(PC1_end = lead(PC1),
         PC2_end = lead(PC2),
         era_arrow = era) %>%
  filter(!is.na(PC1_end)) %>%
  ungroup()

# Create the plot
pdf(file = "plot/climate_PCA.pdf", height = 7, width = 9)
p = fviz_pca_biplot(pca_result, 
                    repel = TRUE,
                    col.var = "grey30",
                    alpha = 0.1,
                    pointsize = 0.6,
                    pointshape = 21,
                    col.ind = climate_summary$era,
                    fill.ind = climate_summary$site,
                    mean.point = FALSE,
                    label = "var",
                    title = "",
                    stroke = 0.2) +
  geom_point(data = paleo_1000yr, aes(x = PC1, y = PC2, fill = site), size = 4, shape = 21, stroke = 0.5, color = "white", alpha = 0.8) +
  geom_segment(data = arrows, aes(x = PC1, y = PC2, xend = PC1_end, yend = PC2_end, color = era_arrow),
               arrow = arrow(length = unit(0.15, "cm"), type = "closed"), size = 0.5) +
  geom_text_repel(data = paleo_1000yr, aes(x = PC1, y = PC2, label = period_label), 
             size = 4, color = "grey20", show.legend = FALSE) +
  theme(legend.position = "bottom", legend.title = element_blank(),
        text = element_text(size = 16)) +
  scale_color_manual(values = color_era3) +
  scale_fill_manual(values = color_mt)
p
dev.off()

####LEFT HERE!!!! ----

# Get PCA coordinates for all points
pca_data = PCA(env %>% select(-site, -era), graph = FALSE)
coords = as.data.frame(pca_data$ind$coord[,1:2])
coords$site = env$site
coords$era = env$era

                    
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

clim_mora = get(load(here("data/plots_climNA.rda")))
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

