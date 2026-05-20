# Dowload chelsa ----
# Python setup for CHELSA
py_install("chelsa-cmip6", pip = TRUE)
chelsa_cmip6 = import('chelsa_cmip6')


# Get MORA data
MORA_occ = read_csv(here("output/MORA_occ.csv"))
MORA_plot_info = read_csv(here("output/MORA_plot_info.csv"))
MORA_plot_info = MORA_plot_info  %>% filter(plot_id %in% MORA_occ$plot_id)
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
write.csv(tasmin, here("output/tasmin_present_organized.csv"))
write.csv(tasmin_summary, here("output/tasmin_summary_organized.csv"))

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

write.csv(pre, here("output/precip_present_organized.csv"))
write.csv(pre_summary, here("output/precip_summary_organized.csv"))

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

# MORA-only anthropocene trends: MAT and AP ----
mora_mat = tasmin_summary %>%
  filter(site == "MORA") %>%
  select(plot_id, elevation, year, value = annual_mean) %>%
  mutate(variable = "Mean Annual Temperature (°C)")

mora_ap = pre_summary %>%
  filter(site == "MORA") %>%
  select(plot_id, elevation, year, value = annual_sum) %>%
  mutate(variable = "Annual Precipitation (mm)")

mora_anthro = bind_rows(mora_mat, mora_ap) %>%
  mutate(variable = factor(variable,
                           levels = c("Mean Annual Temperature (°C)",
                                      "Annual Precipitation (mm)")))

p_mora_anthro =
  ggplot(mora_anthro, aes(x = year, y = value)) +
  geom_line(aes(group = plot_id, color = elevation), linewidth = 0.3, alpha = 0.1) +
  stat_smooth(method = "lm", se = FALSE, color = "black", linewidth = 0.9, linetype = "dashed") +
  stat_regline_equation(aes(label = paste(after_stat(eq.label), after_stat(rr.label), sep = "~~~~")),
                        label.x.npc = "left", label.y.npc = 0.97, size = 4) +
  facet_wrap(~ variable, scales = "free_y", ncol = 2, strip.position = "top") +
  scale_color_berlin(midpoint = 1100, reverse = TRUE) +
  theme_bw() +
  theme(strip.background = element_blank(),
        strip.text = element_text(size = 12, face = "bold"),
        legend.key.width = unit(2, "cm"),
        legend.position = "bottom",
        axis.title.y = element_blank()) +
  labs(x = "Year",
       title = "MORA Anthropocene Climate Trends",
       color = "Altitude (m)")

pdf(file = "plot/climate_trend_anthropocene_MORA.pdf", width = 12, height = 5)
print(p_mora_anthro)
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

write_csv(climate_timeseries, file = here("output/climate_timeseries.csv"))
write_csv(climate_summary, file = here("output/climate_summary.csv"))

# Paleo ponds climate analysis ----
# Define paleo pond locations (same as used in 000_PALEO_cleaning.R)
paleo_plots = data.frame(Location = c("JayBath", "LogWallow", "ReflectionPond")) %>%
  mutate(latitude = case_when(Location == "JayBath" ~ 46.7667,
                              Location == "LogWallow" ~ 46.7667,
                              Location == "ReflectionPond" ~ 46.7667)) %>%
  mutate(longitude = case_when(Location == "JayBath" ~ -121.7667,
                               Location == "LogWallow" ~ -121.75,
                               Location == "ReflectionPond" ~ -121.7167))

## Get paleo ponds precipitation data ----
pre_paleo_ponds =
  read_csv("output/mora_climate/pre.paleo.ponds.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = as.numeric(str_extract(time, "^-?\\d+"))*100,
    month = as.numeric(str_extract(time, "(?<=-\\d{1,2}-)\\d{2}")),
    day = as.numeric(str_extract(time, "\\d+$"))
  ) %>%
  select(-location) %>%
  left_join(paleo_plots, by = c("longitude", "latitude")) %>%
  filter(year < 0) %>%
  rename(plot_id = Location) %>%
  mutate(site = "MORA",
         elevation = NA,
         aspect = NA,
         slope = NA)

# Calculate annual sum
pre_paleo_ponds_summary = pre_paleo_ponds %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
  summarize(annual_sum = sum(pre, na.rm = TRUE)) %>%
  ungroup()

# Calculate seasonal sums
seasonal_sums_paleo_ponds = pre_paleo_ponds %>%
  mutate(
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5) ~ "spring",
      month %in% c(6, 7, 8) ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(season)) %>%
  group_by(site, plot_id, elevation, aspect, slope, season, year = if_else(season == "winter", winter_year, year)) %>%
  summarize(sum_pre = sum(pre, na.rm = TRUE)) %>%
  ungroup() %>%
  pivot_wider(
    names_from = season,
    values_from = sum_pre,
    names_prefix = "sum_"
  )

# Join annual and seasonal sums
pre_paleo_ponds_summary = pre_paleo_ponds_summary %>%
  left_join(seasonal_sums_paleo_ponds, by = c("site","plot_id", "year", "elevation", "aspect", "slope"))

## Get paleo ponds temperature data ----
tasmin_paleo_ponds =
  read_csv("output/mora_climate/tasmin.paleo.ponds.csv")[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year = as.numeric(str_extract(time, "^-?\\d+"))*100,
    month = as.numeric(str_extract(time, "(?<=-\\d{1,2}-)\\d{2}")),
    day = as.numeric(str_extract(time, "\\d+$"))
  ) %>%
  select(-location) %>%
  left_join(paleo_plots, by = c("longitude", "latitude")) %>%
  filter(year < 0) %>%
  rename(plot_id = Location) %>%
  mutate(site = "MORA",
         elevation = NA,
         aspect = NA,
         slope = NA)

# Calculate annual mean
tasmin_paleo_ponds_summary = tasmin_paleo_ponds %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
  summarize(annual_mean = mean(tasmin, na.rm = TRUE)) %>%
  ungroup()

# Calculate seasonal means
seasonal_means_paleo_ponds = tasmin_paleo_ponds %>%
  mutate(
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5) ~ "spring",
      month %in% c(6, 7, 8) ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(season)) %>%
  group_by(site, plot_id, elevation, aspect, slope, season, year = if_else(season == "winter", winter_year, year)) %>%
  summarize(mean_temp = mean(tasmin, na.rm = TRUE)) %>%
  ungroup() %>%
  pivot_wider(
    names_from = season,
    values_from = mean_temp,
    names_prefix = "mean_"
  )

# Rename winter column
seasonal_means_paleo_ponds = seasonal_means_paleo_ponds %>%
  rename(winter_mean = mean_winter)

# Join annual and seasonal means
tasmin_paleo_ponds_summary = tasmin_paleo_ponds_summary %>%
  left_join(seasonal_means_paleo_ponds, by = c("site","plot_id", "year", "elevation", "aspect", "slope")) %>%
  mutate(annual_mean = annual_mean - 273.15,
         mean_spring = mean_spring - 273.15,
         mean_summer = mean_summer - 273.15,
         winter_mean = winter_mean - 273.15)

## Combine paleo ponds climate data ----
climate_paleo_ponds = left_join(tasmin_paleo_ponds_summary %>% mutate(era = "holocene"),
                                pre_paleo_ponds_summary %>% mutate(era = "holocene")) %>%
  rename(MAT = annual_mean, MSpT = mean_spring, MST = mean_summer,
         MWT = winter_mean, AP = annual_sum, SpP = sum_spring, SP = sum_summer,
         WP = sum_winter)

climate_paleo_ponds_summary = climate_paleo_ponds %>%
  mutate(period = as.character(year)) %>%
  group_by(site, era, period, plot_id, elevation, slope, aspect) %>%
  summarize(across(c(MAT, MSpT, MST, MWT, AP, SpP, SP, WP), \(x) mean(x, na.rm = TRUE)), .groups = "drop")

# Write paleo ponds climate summary
write_csv(climate_paleo_ponds_summary, file = here("output/climate_paleo_ponds_summary.csv"))



