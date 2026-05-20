# install.packages("remotes")
# remotes::install_github("wfinsinger/tapas")
library(readxl)
library(dplyr)
library(here)
library(tapas)
library(tibble)

# Function to process charcoal data for tapas analysis with lake-specific parameters
process_charcoal_data = function(file_path, lake_name, smoothing_years, interp_years) {
  # Read the data
  raw_data = read_xlsx(file_path)

  # Process data for tapas
  processed_data = raw_data %>%
    transmute(
      CmTop  = as.numeric(trimws(`Depth Top (cm)`)),
      CmBot  = as.numeric(trimws(`Depth bottom (cm)`)),
      AgeTop = as.numeric(trimws(`Age Top`)),
      AgeBot = as.numeric(trimws(`Age Bottom`)),
      Volume = as.numeric(trimws(`Volume (cc)`)),
      Total  = as.numeric(trimws(Total)),
      variable1 = as.numeric(trimws(`Charcoal Concentration`))
    ) %>%
    filter(!if_any(c(CmTop,CmBot,AgeTop,AgeBot,Volume), is.na)) %>%
    as.data.frame()

  # Check tapas compatibility
  processed_data = tapas::check_pretreat(processed_data)

  # Replace zero values with small positive values
  processed_data$Total[processed_data$Total == 0] <- 0.001

  # Run tapas peak detection with lake-specific parameters
  res = tapas::peak_detection(
    series            = processed_data,
    proxy             = "Total",
    out               = "accI",
    first             = min(processed_data$AgeTop),
    last              = max(processed_data$AgeBot),
    smoothing_yr      = smoothing_years,    # Lake-specific smoothing window
    thresh_type       = "local",
    thresh_value      = 0.95,
    min_CountP        = 0.05,
    MinCountP_window  = 75,
    yrInterp          = interp_years,       # Lake-specific interpolation interval
    keep_consecutive  = FALSE,
    plotit            = FALSE,
    detr_type         = "rob.lowess",
    sens              = TRUE
  )

  # Extract all peaks with significance information
  all_peaks = res$thresh$PeakMag_pos
  significant_ages = res$thresh$peaks.pos.ages

  # Create comprehensive results dataframe
  peaks_df = tibble(
    lake = lake_name,
    age_cal_yr_BP = all_peaks$ageI,
    peak_magnitude = all_peaks$peak_mag,
    is_significant = all_peaks$ageI %in% significant_ages,
    smoothing_window = smoothing_years,
    interpolation_interval = interp_years
  ) %>%
    arrange(desc(age_cal_yr_BP))

  return(peaks_df)
}

# Process all three lakes with Walsh et al. (2017) lake-specific parameters
sunrise_results = process_charcoal_data(
  here("data", "PALEO", "char_sunrise_lake.xlsx"),
  "Sunrise Lake",
  smoothing_years = 800,  # Walsh et al. optimized for Sunrise Lake
  interp_years = 48       # Median temporal resolution for Sunrise Lake
)

shadow_results = process_charcoal_data(
  here("data", "PALEO", "char_shadow_lake.xlsx"),
  "Shadow Lake",
  smoothing_years = 1000, # Walsh et al. optimized for Shadow Lake
  interp_years = 47       # Median temporal resolution for Shadow Lake
)

little_sunrise_results = process_charcoal_data(
  here("data", "PALEO", "char_little_sunrise.xlsx"),
  "Little Sunrise Lake",
  smoothing_years = 500,  # Walsh et al. optimized for Little Sunrise Lake
  interp_years = 42       # Median temporal resolution for Little Sunrise Lake
)

# Combine all results into final tibble
all_fire_episodes = bind_rows(
  sunrise_results,
  shadow_results,
  little_sunrise_results
)

# Display results summary
print("Fire episodes by lake (using Walsh et al. 2017 parameters):")
summary_results = all_fire_episodes %>%
  group_by(lake, smoothing_window, interpolation_interval) %>%
  summarise(
    total_peaks = n(),
    significant_peaks = sum(is_significant),
    age_range_start = max(age_cal_yr_BP),
    age_range_end = min(age_cal_yr_BP),
    .groups = "drop"
  )

print(summary_results)

# View significant episodes only
significant_episodes = all_fire_episodes %>%
  filter(is_significant == TRUE) %>%
  arrange(lake, desc(age_cal_yr_BP))

print("\nSignificant fire episodes:")
print(significant_episodes)

# Create final comprehensive dataset
fire_episodes_final = all_fire_episodes

ggplot(fire_episodes_final %>% filter(age_cal_yr_BP>0), 
       aes(age_cal_yr_BP, peak_magnitude, color = lake))+
  geom_line(linewidth = 1)+
  scale_x_reverse()+
  theme_minimal()

write_csv(fire_episodes_final, here("output", "fire_walsh.csv"))
  
