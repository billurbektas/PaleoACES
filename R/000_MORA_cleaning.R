library(tidyverse)
library(readr)
library(viridis)
library(ggalluvial)
library(here)

MORA_past = read_csv(here("data/MORA/MORA_VegData_Legacy_Cleaned.csv"))
MORA_present = read_csv(here("data/MORA/MORA_VegData_Resurvey_Cleaned.csv"))
MORA_plot_lib = read_csv(here("data/MORA/MORA_plot_lib.csv"))
MORA_sp_lib = read_csv(here("data/MORA/MORA_spp_lib.csv"))
MORA_sp_lib = MORA_sp_lib %>% mutate(past_code = ifelse(past_code == "TSH4", "TSHE", past_code))

# Test function to validate data
run_tests = function() {
  cat("Running data validation tests...\n")
  
  # Test 1: Check if required datasets exist
  if (!exists("MORA_past")) stop("ERROR: MORA_past dataset not found")
  if (!exists("MORA_plot_lib")) stop("ERROR: MORA_plot_lib dataset not found") 
  if (!exists("MORA_sp_lib")) stop("ERROR: MORA_sp_lib dataset not found")
  if (!exists("MORA_present")) stop("ERROR: MORA_present dataset not found")
  cat("✓ All required datasets found\n")
  
  # Test 2: Check required columns exist
  required_past_cols = c("Plotno", "SiteName", "Plot_ID")
  if (!all(required_past_cols %in% colnames(MORA_past))) {
    stop("ERROR: Missing required columns in MORA_past")
  }
  
  required_plot_cols = c("Plotno", "plot_id", "Plot_ID")
  if (!all(required_plot_cols %in% colnames(MORA_plot_lib))) {
    stop("ERROR: Missing required columns in MORA_plot_lib")
  }
  
  required_sp_cols = c("past_code", "prst_code", "final_species", "canopy_type")
  if (!all(required_sp_cols %in% colnames(MORA_sp_lib))) {
    stop("ERROR: Missing required columns in MORA_sp_lib")
  }
  
  required_present_cols = c("Year", "Plot_ID", "Species", "Percent.Cover")
  if (!all(required_present_cols %in% colnames(MORA_present))) {
    stop("ERROR: Missing required columns in MORA_present")
  }
  cat("✓ All required columns found\n")
  
  # Test 3: Check for target canopy types
  target_canopy = c("overstory", "overstory_full", "overstory_rare")
  available_canopy = unique(MORA_sp_lib$canopy_type)
  overstory_count = sum(str_detect(available_canopy, "overstory|rare"))
  
  if (overstory_count == 0) {
    warning("WARNING: No overstory or rare species found in canopy_type")
  } else {
    cat("✓", overstory_count, "target canopy types found\n")
  }
  
  cat("Tests completed successfully!\n\n")
}

# Clean MORA_past data
clean_past = function(mora_past, mora_plot_lib, mora_sp_lib) {
  
  cat("Cleaning MORA_past data...\n")
  
  # Pivot all species columns to long format
  past_long = mora_past %>%
    select(-...1) %>%
    pivot_longer(cols = -c(SiteName, Plotno, Plot_ID), 
                 names_to = "species_code", 
                 values_to = "value") %>%
    filter(value > 0) %>%
    mutate(
      # Remove numbers from species codes (for tree species with size classes)
      seedling_detect = str_extract(species_code, "[1-4]$"),
      species_code = str_remove(species_code, "[1-4]$"),
      period = "past",
      year = 1975,
      occurrence = 1
    ) %>%
    filter(seedling_detect %in% c(2,3,4))%>%
    select(-seedling_detect)%>%
    # Keep only unique plot-species combinations
    distinct(Plotno, SiteName, Plot_ID, species_code, period, year, occurrence)
  
  cat("  - Created long format:", nrow(past_long), "records\n")
  
  # Join with species library to filter for overstory and rare species
  past_filtered = past_long %>%
    left_join(mora_sp_lib, by = c("species_code" = "past_code")) %>%
    filter(canopy_type %in% c("overstory", "overstory_full", "overstory_rare")) %>%
    filter(!is.na(final_species))
  
  cat("  - After filtering for target species:", nrow(past_filtered), "records\n")
  
  if (nrow(past_filtered) == 0) {
    warning("WARNING: No records found after species filtering for past data")
  }
  
  # Join with plot library to get proper plot_id
  past_final = past_filtered %>%
    left_join(mora_plot_lib, by = "Plot_ID") %>%
    select(period, year, plot_id, species = final_species, occurrence)

    # Keep records with valid plot_ids only
    past_final = past_final %>% filter(!is.na(plot_id))
 
  return(past_final)
}

# Clean MORA_present data
clean_present = function(mora_present, mora_plot_lib, mora_sp_lib) {
  
  cat("Cleaning MORA_present data...\n")
  
  # Get plot IDs from past data
  valid_plots = unique(mora_plot_lib$Plot_ID) # these are the valid plots with the code in present data
  valid_plots = valid_plots[!is.na(valid_plots)]
  
  cat("  - Filtering for", length(valid_plots), "plots from past data\n")
  
  # Get overstory and rare species from species library
  target_species = mora_sp_lib %>%
    filter(canopy_type %in% c("overstory", "overstory_full", "overstory_rare")) %>%
    pull(prst_code)
  
  cat("  - Target species identified:", length(target_species), "species\n")
  
  # Extract species code from Species column and filter for past plots
  present_clean = mora_present %>%
    filter(Plot_ID %in% valid_plots) %>%  # Only get the valid plots
    mutate(species_code = str_extract(Species, "^[A-Z]+")) %>%
    filter(species_code %in% target_species) %>%
    mutate(
      period = "present",
      occurrence = 1
    )
  
  cat("  - After filtering for valid plots and target species:", nrow(present_clean), "records\n")
  
  if (nrow(present_clean) == 0) {
    warning("WARNING: No records found after filtering for present data")
  }
  
  # Join with species library to get proper species names and keep unique occurrences
  present_final = present_clean %>%
    left_join(mora_sp_lib, by = c("species_code" = "prst_code")) %>%
    filter(!is.na(final_species)) %>%
    # Keep only one occurrence record per plot-species combination
    distinct(Plot_ID, final_species, .keep_all = TRUE) %>%
    # Get standardized plot_id from plot library
    left_join(MORA_plot_lib %>% select(Plot_ID, plot_id), by = "Plot_ID") %>%
    filter(plot_id %in% valid_plots) %>%  # Double-check: only plot_ids from library
    rename(year = Year)%>%
    select(period, year, plot_id,
           species = final_species, occurrence)
  
  cat("  - Final present data:", nrow(present_final), "records\n")
  return(present_final)
}

# Test species occurrence counts between raw and cleaned data
test_species_counts = function(mora_past, mora_present, mora_occ, mora_sp_lib, mora_plot_lib) {
  
  cat("\nTesting species occurrence counts...\n")
  
  # Get 5 random species from cleaned data
  set.seed(123)  # For reproducible results
  test_species = sample(unique(mora_occ$species), min(5, length(unique(mora_occ$species))))
  
  cat("Testing these species:", paste(test_species, collapse = ", "), "\n\n")
  
  for (sp in test_species) {
    cat("Species:", sp, "\n")
    
    # Get species codes for this species
    sp_codes = mora_sp_lib %>% 
      filter(final_species == sp) %>%
      select(past_code, prst_code)
    
    if (nrow(sp_codes) == 0) {
      cat("  WARNING: No species codes found in library\n")
      next
    }
    
    past_code = sp_codes$past_code[1]
    present_code = sp_codes$prst_code[1]
    
    # Count in raw MORA_past data (occurrences only)
    if (!is.na(past_code)) {
      # Get all columns that start with this code (including numbered versions)
      past_cols = grep(paste0("^", past_code, "[1-4]?$"), colnames(mora_past), value = TRUE)
      
      if (length(past_cols) > 0) {
        # Get plot IDs that exist in plot library
        valid_plots = mora_plot_lib$Plot_ID
        
        raw_past_plots = mora_past %>%
          filter(Plot_ID %in% valid_plots) %>%  # Only plots in plot library
          select(Plot_ID, all_of(past_cols)) %>%
          rowwise() %>%
          mutate(total = sum(c_across(-Plot_ID), na.rm = TRUE)) %>%
          filter(total > 0) %>%
          nrow()
      } else {
        raw_past_plots = 0
      }
    } else {
      raw_past_plots = 0
    }
    
    # Count in raw MORA_present data (occurrences only)
    if (!is.na(present_code)) {
      # Get plot IDs that exist in plot library
      valid_plots = mora_plot_lib$Plot_ID
      
      raw_present_records = mora_present %>%
        filter(str_detect(Species, paste0("^", present_code))) %>%
        filter(Plot_ID %in% valid_plots) %>%  # Only plots in plot library
        distinct(Plot_ID) %>%  # Only count unique plot occurrences
        nrow()
    } else {
      raw_present_records = 0
    }
    
    # Count in cleaned data (occurrences only)
    cleaned_past = mora_occ %>%
      filter(species == sp, period == "past")
    
    cleaned_present = mora_occ %>%
      filter(species == sp, period == "present")
    
    cleaned_past_plots = nrow(cleaned_past)
    cleaned_present_plots = nrow(cleaned_present)
    
    # Compare occurrences only
    cat("  Past data:\n")
    cat("    Raw plot occurrences:", raw_past_plots, "| Cleaned plot occurrences:", cleaned_past_plots, "\n")
    
    cat("  Present data:\n")
    cat("    Raw plot occurrences:", raw_present_records, "| Cleaned plot occurrences:", cleaned_present_plots, "\n")
    
    # Flag major discrepancies in occurrences
    if (abs(raw_past_plots - cleaned_past_plots) > 0 && raw_past_plots > 0) {
      cat("  ⚠️  WARNING: Discrepancy in past plot occurrences\n")
    }
    if (abs(raw_present_records - cleaned_present_plots) > 0 && raw_present_records > 0) {
      cat("  ⚠️  WARNING: Discrepancy in present plot occurrences\n")
    }
    
    cat("\n")
  }
}

# Run tests before processing
run_tests()

# Apply cleaning functions
mora_past_clean = clean_past(MORA_past, MORA_plot_lib, MORA_sp_lib)
mora_present_clean = clean_present(MORA_present, MORA_plot_lib, MORA_sp_lib)

# Combine past and present data
mora_occ = bind_rows(mora_past_clean, mora_present_clean) %>%
  arrange(plot_id, species, period)

cat("Combined dataset created with", nrow(mora_occ), "total records\n")

# Final validation
if (nrow(mora_occ) == 0) {
  stop("ERROR: Final dataset is empty!")
}

# Check for required columns in final dataset
final_required_cols = c("period", "year", "plot_id", "species", "occurrence")
missing_final_cols = setdiff(final_required_cols, colnames(mora_occ))
if (length(missing_final_cols) > 0) {
  stop("ERROR: Missing columns in final dataset: ", paste(missing_final_cols, collapse = ", "))
}

# Add missing columns to match occ_long format
mora_occ = mora_occ %>%
  select(period, plot_id, species, occurrence)

# Run species count test
test_species_counts(MORA_past, MORA_present, mora_occ, MORA_sp_lib, MORA_plot_lib)

# Diagnostic check for plot_id issue
cat("\nDiagnostic check:\n")
cat("- Unique plots in plot library:", length(unique(MORA_plot_lib$plot_id)), "\n")
cat("- Unique plots in cleaned data:", length(unique(mora_occ$plot_id)), "\n")

# Check for duplicates in plot library
duplicate_plots = MORA_plot_lib %>% 
  count(Plot_ID) %>% 
  filter(n > 1)
cat("- Duplicate Plot_IDs in library:", nrow(duplicate_plots), "\n")

# Check for NA plot_ids in cleaned data
na_plots = sum(is.na(mora_occ$plot_id))
cat("- NA plot_ids in cleaned data:", na_plots, "\n")

# Find plot_ids in cleaned data that are NOT in plot library
extra_plots = setdiff(unique(mora_occ$plot_id), unique(MORA_plot_lib$plot_id))
cat("- Plot_ids in cleaned data but not in library:", length(extra_plots), "\n")
if (length(extra_plots) > 0) {
  cat("  Examples:", paste(head(extra_plots, 5), collapse = ", "), "\n")
}

# Final summary
cat("Final dataset summary:\n")
cat("- Total records:", nrow(mora_occ), "\n")
cat("- Unique plots:", length(unique(mora_occ$plot_id)), "\n") 
cat("- Unique species:", length(unique(mora_occ$species)), "\n")
cat("- Past records:", sum(mora_occ$period == "past"), "\n")
cat("- Present records:", sum(mora_occ$period == "present"), "\n")

# Write to CSV (commented out for safety)
write_csv(mora_occ, file = here("output/MORA_occ.csv"))
load(here("data/MORA_plots.rda"))
write_csv(plot_info, file = here("output/MORA_plot_info.csv"))

# Preview the result
cat("\nFirst 10 rows:\n")
print(head(mora_occ, 10))
cat("\nDataset structure:\n")
print(summary(mora_occ))

#### Colonization and extinction visuals ----
# Main execution (add this after your existing code)
# Calculate turnover
turnover_results = calculate_turnover(mora_occ)

# Print summary statistics
print_turnover_summary(turnover_results)

# Create visualizations
heatmap_plot = create_turnover_heatmap(turnover_results$turnover_data) 
alluvial_plot = create_alluvial_plot(turnover_results$turnover_data)

#Just a simple count
count_plot = 
  ggplot(mora_occ, aes(species, fill = period))+
  geom_bar(position = "dodge") +
  scale_fill_manual(values = c("past" = "#8B4513", "present" = "#228B22")) +
  theme_bw()+
  xlab("")+
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

pdf(file = here("plot/MORA_dynamics.pdf"), width = 10, height = 8)
print("Creating turnover heatmap...")  
print(heatmap_plot)

print("Creating alluvial flow diagram...")
print(alluvial_plot)

print(count_plot)
dev.off()




