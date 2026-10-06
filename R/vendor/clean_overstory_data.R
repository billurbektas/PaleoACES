# Author: Agostina Torres
# Project: CLIMreassembly
# Script: clean_overstory.R
# Description:
# This script processes and integrates overstory (tree) data for the MORA dataset (Mount Rainier National Park),
# as part of the MORAcleaning subproject within the CLIMreassembly project.
# It focuses on standardizing, reshaping, and combining legacy (1975) and resurvey (2010s) data
# on species occurrence and cover, and generates matrices and long-format tables
# for downstream analyses.
#
# Source data:
# - MORA_TreeData_Legacy_Cleaned.csv
# - MORA_TreeData_Resurvey_Cleaned.csv
#   (located in: CLIMreassembly/MORAcleaning/data_raw/)
#
# Steps include:
# - Cleaning and reshaping species-by-plot occurrence data for both time periods
# - Estimating cover per species per plot from diameter classes
# - Harmonizing old and new species codes using prst_code
# - Generating species-by-plot cover and presence/absence matrices
# - Checking consistency between datasets
#
# Outputs:
# - File: CLIMreassembly/MORAcleaning/outputs/AT_MORA_overstory.rda
#   containing:
#     - over_long: combined long-format data with cover and presence
#     - over_matrix_occ: presence-absence matrix (species x plots)
#     - over_matrix_cov: cover matrix (species x plots)
#
# Last updated: 2025-04-25

# Load cleaned species and plot reference data
source("MORAcleaning/scripts/clean_species_names.R")
source("MORAcleaning/scripts/clean_plots.R")


# 1. Past | Overstory | Cleaning    ----------------------------------------

# Read cover data from legacy overstory survey
past_over <- read.csv('MORAcleaning/data_raw/MORA_TreeData_Legacy_Cleaned.csv',
                              row.names = 1) # irrelevant rownames

# Count unique Plotno values with missing Plot_ID
num_unique_plotno <- past_over|>
  filter(Plot_ID == "" | is.na(Plot_ID)) |>  
  summarise(unique_plotno = n_distinct(Plotno)) |>  
  pull(unique_plotno)

print(paste("Unique Plotno in rows with blank Plot_ID:", num_unique_plotno,
            "I assume this plots were not resurveyed"))


# Clean and reformat legacy cover data
past_over_clean <- past_over |>
  # Merge cleaned plot IDs
  left_join(plot_lib |>
              select(Plot_ID, plot_id), 
            by = "Plot_ID") |>
  # Keep only important cols
  select(Plotno_old = Plotno,
         Plot_ID,
         plot_id,
         prst_code = Species,
         past_code = SpeciesOld,
         plot_area = Plot_area_m2,
         everything()) |>
    # Rename DBH120, delete then
  rename(DBH120 = X.DBH120) |>
    # Merge clean species names
  left_join(
    spp_list |> 
      filter(canopy_type == "overstory") |> 
      select(prst_code, species),
    by = "prst_code"
  ) |>  
  relocate(species, .after = past_code) |>
  # Keep only common overstory species
  filter(!is.na(species)) |>
  # Remove empty Plot_ID if any
  filter(Plot_ID != "" & !is.na(Plot_ID))  

print(paste("Number of plots for past tree survey:",
            length(unique(past_over_clean$plot_id))
))

# Reshape DBH columns into long format
past_over_dbh <- past_over_clean %>%
  select(-starts_with("bigtree")) %>%
  pivot_longer(
    cols = starts_with("DBH"),  
    names_to = "class_size",
    values_to = "num_ind"
  ) |> 
  mutate(diam_class = case_when(
    str_starts(class_size, "DBH") ~ as.numeric(str_extract(class_size, "\\d+")) + 5,  # Sumar 5 solo si es DBH
    # Keep exact value if DBH > 120
    TRUE ~ as.numeric(class_size)  
  )) |>
  mutate(class_size = as.character(class_size))

# Reshape bigtree columns to long format
past_over_bigtree <- past_over_clean %>%
  select(plot_id, species, starts_with("bigtree")) %>%
  pivot_longer(
    cols = starts_with("bigtree"),  
    names_to = "bigtree_index",
    values_to = "class_size"
  ) %>%
  filter(!is.na(class_size)) %>%  # Eliminar filas sin valores
  mutate(class_size = as.numeric(class_size),  # Convertir a número
         num_ind = 1,  # Siempre 1 individuo por bigtree
         diam_class = class_size) %>%  # diam_class toma el valor del diámetro real
  select(-bigtree_index) |>  # Eliminar la columna de índice
  mutate(class_size = as.character(class_size))


# Combine both DBH and bigtree formats
past_over_cleaner <-  bind_rows(past_over_dbh, 
                            past_over_bigtree)

# Calculate individual basal area and cover per class
past_over_cov <- past_over_cleaner |>
  # Remove DBH120 because bigtrees are already included
    filter(class_size != 'DBH120') |> 
  mutate(num_ind = replace_na(num_ind, 0)) |>
  mutate(basal_area_class_cm = pi * (diam_class / 2)^2, #diam class en cm, area_class en cm2
         basal_area_class_m2 = basal_area_class_cm / 10000,   #convierto a m2
         basal_area_class_weighted = basal_area_class_m2 * num_ind)

# Aggregate cover per species and plot
past_over_cov_spp <- past_over_cov |>
  group_by(species, plot_id) |>
  summarise(basal_area_spp = sum(basal_area_class_weighted, 
                             na.rm = TRUE),
            plot_area = first(plot_area),
            .groups = "drop")  # Suma ignorando NAs


# Check if plot area is inconsistent within plots
plot_with_issues <- past_over_cov_spp |> 
  group_by(plot_id) |> 
  summarise(unique_areas = n_distinct(plot_area)) |> 
  filter(unique_areas > 1)

print(paste('Plots with inconsistencies in area column:',
            plot_with_issues$plot_id
))

# Fix plot_area by keeping most common value per plot
plot_area_fix <- past_over_cov_spp |> 
  group_by(plot_id) |> 
  summarise(correct_plot_area = as.numeric(names(sort(table(plot_area), 
                                                      decreasing = TRUE)[1])))

# Recalculate relative cover
past_over_cov_spp <- past_over_cov_spp |> 
  left_join(plot_area_fix, by = "plot_id") |>
  select( -c(plot_area)) |>
  mutate(basal_area_percent = (basal_area_spp / correct_plot_area)*100) |>
  mutate(year = 1975,
         period = 'past')

# Total cover per plot
past_over_cov_plot <- past_over_cov_spp |>
  group_by(plot_id) |>
  summarise(total_basal_area_percent = sum(basal_area_percent,
                          na.rm = TRUE),
            total_basal_area_m2 = sum(basal_area_spp,
                                      na.rm = TRUE)) |>
  mutate(year = 1975,
         period = 'past')



hist(past_over_cov_plot$total_basal_area_m2,
     xlab = 'Basal area per plot (m2)', 
     main = 'Past basal area histogram')
hist(past_over_cov_plot$total_basal_area_percent,
     xlab = 'Basal area per plot (%)', 
     main = 'Past basal area histogram')

# 2. Present | Overstory | Tree cover -------------------------------------

# Read cleaned cover data from the resurvey (present-day) overstory survey
prst_over <- read.csv('MORAcleaning/data_raw/MORA_TreeData_Resurvey_Cleaned.csv',
                              row.names = 1) # irrelevant rownames

# Identify how many rows have blank or missing Plot_ID
blank_plot_id <- prst_over |>
  filter(Plot_ID == "" | is.na(Plot_ID))
nrow(blank_plot_id)

print(paste("Plot_ID that are NAs:", nrow(blank_plot_id),
            "I will delete them"))

# Clean and format resurvey tree cover data
prst_over_clean <- prst_over |>
  # Add cleaned plot_id from plot reference table
  left_join(plot_lib |>
              select(Plot_ID, plot_id), 
            by = "Plot_ID") |>
  # Keep only important cols
  select(year = Year,
         Plot_ID,
         plot_id,
         prst_code = Species,
         DBH) |>
  # Merge clean species names
  left_join(
    spp_list |> 
      filter(canopy_type == "overstory") |> 
      select(prst_code, species),
    by = "prst_code"
  ) |>  
  relocate(species, .after = prst_code) |>
  # Keep only common overstory species
  filter(!is.na(species)) |>
  # Remove rows with blank Plot_ID or plot_id
  filter(Plot_ID != "" & !is.na(Plot_ID)) |>
  filter(plot_id != "" & !is.na(plot_id))

print(paste("Number of plots for present tree survey:",
            length(unique(prst_over_clean$plot_id))
))


# Keep only plots that were also present in the past survey
prst_over_clean <- prst_over_clean |>
  filter(plot_id %in% past_over_cov_plot$plot_id)

all(prst_over_clean$plot_id %in% past_over_cov_plot$plot_id)

if (all(prst_over_clean$plot_id %in% past_over_cov_plot$plot_id)) {
  print("All plots match")
} else {
  print("Some plots do NOT match")
}


print(paste("Number of plots for new tree survey:",
            length(unique(prst_over_clean$plot_id))
))


# Fix likely typo in DBH: replace "1703" with "170.3" for Abies amabilis in plot SMO-366
prst_over_clean <- prst_over_clean |>
  mutate(DBH = ifelse(
    plot_id == "SMO-366" & species == "Abies amabilis" & DBH == "1703",
    "170.3",
    DBH
  )) |>
  mutate(DBH = as.numeric(DBH))

# Estimate cover based on DBH
## No distinction needed between DBH and bigtrees
## But DBH must be binned into classes before estimating area

prst_over_dbh <- prst_over_clean %>%
  # Guardar la columna original como DBH_old
  mutate(DBH_old = DBH) %>%
  # Limpiar caracteres y transformar en nueva columna
  mutate(DBH_clean = str_replace_all(DBH_old, "[^0-9.<]", ""), 
         DBH_clean = case_when(
           DBH_clean == "<0.5" ~ "0.25",  
           DBH_clean == "<1" ~ "0.5",
           DBH_clean == "<1.0" ~ "0.5", 
           DBH_clean == "" ~ NA_character_,  
           TRUE ~ DBH_clean), 
         DBH = as.numeric(DBH_clean))|>
  select(-DBH_old, -DBH_clean) |>
  filter(!is.na(DBH)) %>%  
  mutate(class_size = case_when(
    # Keep exact value if DBH > 120
    DBH > 120 ~ as.character(DBH), 
    TRUE ~ as.character(cut(DBH, 
                            breaks = seq(0, 130, by = 10),  
                            labels = paste0("DBH", seq(0, 120, by = 10)),  
                            include.lowest = TRUE, right = FALSE))
  ))  %>%
  mutate(diam_class = case_when(
    str_starts(class_size, "DBH") ~ as.numeric(str_extract(class_size, "\\d+")) + 5,  # Sumar 5 solo si es DBH
    TRUE ~ as.numeric(class_size)  # Mantener el valor exacto si DBH > 120
  )) |>
  mutate(class_size = as.character(class_size))


# Count individuals per species, class, and plot
prst_over_cov <- prst_over_dbh |>
  group_by(plot_id, species, year, class_size, diam_class) |>
  summarise(num_ind = n()) |>
  ungroup()

# Estimate basal area and cover per class
prst_over_cov <- prst_over_cov |>
  mutate(basal_area_class_cm = pi * (diam_class / 2)^2, #diam class en cm, area_class en cm2
         basal_area_class_m2 = basal_area_class_cm / 10000,   #convierto a m2
         basal_area_class_weighted = basal_area_class_m2 * num_ind)

# Sum cover per species and plot
prst_over_cov_spp <- prst_over_cov |>
  group_by(year, plot_id, species) |>
  summarise(basal_area_spp = sum(basal_area_class_weighted, 
                             na.rm = TRUE),
            .groups = "drop")  # Suma ignorando NAs


# Check number of plots sampled per year
plot_count_per_year <- prst_over_cov_spp %>%
  group_by(year) %>%
  summarise(num_plots = n_distinct(plot_id))

# Plot number of sampled plots per year
ggplot(plot_count_per_year, aes(x = year, y = num_plots)) +
  geom_line(color = "blue", size = 1) +  # Línea azul
  geom_point(color = "red", size = 2) +  # Puntos rojos
  labs(title = " ",
       x = "Year",
       y = "Number of plots") +
  theme_minimal()


print(paste('Not all plots were surveyed each year'))


# Average cover across all present years 2014-2019
prst_over_cov_spp_avg <- prst_over_cov_spp |>
  group_by(plot_id, species) |>
  summarise(basal_area_spp_m2 = mean(basal_area_spp))|> #Average of present years
  ungroup() |>
  mutate(
    plot_area = 500, # Adding plot area in m2
    basal_area_spp_percent = (basal_area_spp_m2 / plot_area) * 100, #Estimating rel cover %
    period = 'present',
    year = '2015' #year of reference, it's an average
  )

# Total relative cover per plot
prst_over_cov_plot <- prst_over_cov_spp_avg |>
  group_by(plot_id) |>
  summarise(tot_basal_area_plot_percent = sum(basal_area_spp_percent,
                          na.rm = TRUE),
            tot_basal_area_plot_m2 = sum(basal_area_spp_m2,
                                      na.rm = TRUE)) |>
  ungroup()


hist(prst_over_cov_plot$tot_basal_area_plot_percent,
     xlab = "Basal area per plot (%)",
     main = 'Present basal area histogram')
hist(prst_over_cov_plot$tot_basal_area_plot_m2,
     xlab = "Basal area per plot (m2)",
     main = 'Present basal area histogram')

# Check plots match!
missing_plots <- prst_over_cov_spp$plot_id[!prst_over_cov_spp$plot_id %in% past_over_cov_spp$plot_id]

print(paste('Number of plots that doesnt match:', missing_plots))





# 3. Past | Overstory | Tree count/abundance ------------------------------

past_over_count_spp <- past_over_cov %>%
  group_by(plot_id, species) %>%
  summarise(count = sum(num_ind, 
                        na.rm = TRUE), 
            .groups = "drop") %>%
  mutate(year = 1975, period = 'past')


# 4. Present | Overstory | Tree count/abundance ---------------------------

prst_over_count_spp <- prst_over_cov %>%
  group_by(plot_id, species) %>%
  summarise(count = sum(num_ind, na.rm = TRUE), .groups = "drop") %>%
  mutate(year = 2015, period = 'prst')



# 5. Past | Overstory | Long ----------------------------------------------

# Join occurrence, cover, and abundance data for past survey (1975)
past_over_all <- past_over_cov_spp |> 
  # Select relevant cover columns
  select(plot_id, correct_plot_area, species,
         basal_area_spp_m2 = basal_area_spp,
         basal_area_spp_percent = basal_area_percent) |>
  # Join abundance per species per plot
  left_join(
    past_over_count_spp |> select(plot_id, species, count),
    by = c("plot_id", "species")
  ) |>
  # Add binary occurrence: 1 if count > 0, else 0
  mutate(occurrence = if_else(count > 0, 1, 0)) |>
  mutate(period = 'past',
         year = 1975)



# 6. Present | Overstory | Long ----------------------------------------------

# Join occurrence, cover, and abundance data for past survey (1975)
prst_over_all <- prst_over_cov_spp_avg |> 
  # Select relevant cover columns
  select(plot_id, plot_area, species,
         basal_area_spp_m2,
         basal_area_spp_percent) |>
  # Join abundance per species per plot
  left_join(
    prst_over_count_spp |> select(plot_id, species, count),
    by = c("plot_id", "species")
  ) |>
  # Add binary occurrence: 1 if count > 0, else 0
  mutate(occurrence = if_else(count > 0, 1, 0)) |>
  mutate(period = 'present',
         year = 1975)




# 7. Overstory | Long --------------------------------------------------------

# 7.1 | Overstory | Long | Past -------------------------------------------

past_over_long <- past_over_all |>
  select(period, year,
         plot_id, plot_area = correct_plot_area,
         species,
         occurrence,
         count,
         basal_area_spp_m2, 
         basal_area_spp_percent) |>
  mutate(density = count/plot_area)


# 7.2 | Overstory | Long | Present ----------------------------------------

prst_over_long <- prst_over_all |>
  select(period, year,
         plot_id, plot_area,
         species,
         occurrence,
         count,
         basal_area_spp_m2,
         basal_area_spp_percent) |>
  mutate(density = count/plot_area)



# 7.3 | Overstory | Long | All --------------------------------------------
# Combine both periods into a single long-format table
over_long <- rbind(past_over_long, prst_over_long)

# Check if both surveys include the same set of plots
length(unique(past_over_long$plot_id)) == length(unique(prst_over_long$plot_id))

# Validate set equality between surveys
setequal(unique(prst_over_long$plot_id), unique(past_over_long$plot_id))

# Add a column indicating mismatch between original and inferred occurrence
over_long_check <- over_long |>
  mutate(match = occurrence)




# 8 | Overstory | Matrix --------------------------------------------------
# 8.1 | Overstory | Matrix | Past -----------------------------------------

# Occurrence matrix past
past_over_matrix_occ <- past_over_long |>
  select(-count, -basal_area_spp_m2, 
         -basal_area_spp_percent, -density) |>
  pivot_wider(
    names_from = species,  # Columns = species
    values_from = occurrence     # Values
  ) |>
  # Remove species that were never recorded
  select(where(~ any(!is.na(.))))

# Count matrix past  
past_over_matrix_abun <- past_over_long |>
  select(-occurrence, -basal_area_spp_m2, 
         -basal_area_spp_percent, -density) |>
  pivot_wider(
    names_from = species,  # Columns = species
    values_from = count     # Values
  ) |>
  # Remove species that were never recorded
  select(where(~ any(!is.na(.))))


# Cover matrix past (with percent cover)
past_over_matrix_cov <- past_over_long |>
  select(-occurrence, -count, 
         -basal_area_spp_m2, - density) |> 
  pivot_wider(
    names_from = species,  # Columns = species
    values_from = basal_area_spp_percent     # Values
  ) |>
  # Remove species that were never recorded
  select(where(~ any(!is.na(.))))



# 8.2 | Overstory | Matrix | Present --------------------------------------

# Occurrence matrix present
prst_over_matrix_occ <- prst_over_long |>
  select(-count, -basal_area_spp_m2, 
         -basal_area_spp_percent, -density) |>
  pivot_wider(
    names_from = species,  # Columns = species
    values_from = occurrence     # Values
  ) |>
  # Remove species that were never recorded
  select(where(~ any(!is.na(.))))

# Count matrix present
prst_over_matrix_abun <- prst_over_long |>
  select(-occurrence, -basal_area_spp_m2, 
         -basal_area_spp_percent, - density) |>
  pivot_wider(
    names_from = species,  # Columns = species
    values_from = count     # Values
  ) |>
  # Remove species that were never recorded
  select(where(~ any(!is.na(.))))


# Cover matrix present (with percent cover)
prst_over_matrix_cov <- prst_over_long |>
  select(-occurrence, -count, 
         -basal_area_spp_m2, -density) |> 
  pivot_wider(
    names_from = species,  # Columns = species
    values_from = basal_area_spp_percent     # Values
  ) |>
  # Remove species that were never recorded
  select(where(~ any(!is.na(.))))


# 8.3 | Overstory | Matrix | All ------------------------------------------

## Occurrence
over_matrix_occ <- bind_rows(past_over_matrix_occ,
                             prst_over_matrix_occ)

## Occurrence
over_matrix_abun <- bind_rows(past_over_matrix_abun,
                              prst_over_matrix_abun)

## Cover (%)
over_matrix_cov <- bind_rows(past_over_matrix_cov,
                            prst_over_matrix_cov)



# 10 | Overstory | Abundance by age ---------------------------------------


# 10.1 | Overstory | Abundance by age | Past ------------------------------

past_over_ageclass_spp <- past_over_cov |> 
  group_by(plot_id, species, class_size) |> 
  summarise(num_ind = sum(num_ind, na.rm = TRUE),
            .groups = "drop") |> 
  mutate(year = 1975, period = "past")

# 10.1 | Overstory | Abundance by age | Prst ------------------------------

prst_over_ageclass_spp <- prst_over_cov |> 
  group_by(plot_id, species, class_size) |> 
  summarise(num_ind = sum(num_ind, na.rm = TRUE),
            .groups = "drop") |> 
  mutate(year = 2015, period = "present")

# 10.1 | Overstory | Abundance by age | All   ------------------------------

over_ageclass_spp <- bind_rows(past_over_ageclass_spp,
                               prst_over_ageclass_spp)


# 11 | Save ----------------------------------------------------------------

save(over_long,
     over_matrix_occ,
     over_matrix_abun,
     over_matrix_cov,
     over_ageclass_spp,
     file = 'MORAcleaning/outputs/MORA_overstory.rda')



past_over_long %>%
  distinct(plot_id, plot_area) %>%
  count(plot_area, sort = TRUE)

