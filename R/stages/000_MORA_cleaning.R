# Clean MORA occurrence data (past 1978 survey + present resurvey) ----
#
# Both periods are built from a seedling source + an adult-tree source, and a
# species is treated as present in a plot if it occurs as a seedling OR an
# adult (merged to a single presence record per plot-species).
#
# Past (1978) -- "MORA_Cascade Legacy Data_Original1978.xlsx":
#   - seedlings: "Rainier Veg" sheet, tree size class 1 (10-140 cm tall)
#   - adult trees: "rawsizedata" sheet, summed binned DBH counts
# Present (resurvey):
#   - seedlings: MORA_Seedlings_Resurvey_Cleaned.csv (10-50 + 51-140 cm tallies)
#   - adult trees: MORA_TreeData_Resurvey_Cleaned.csv (individual tree records)

library(tidyverse)
library(readr)
library(readxl)
library(viridis)
library(ggalluvial)
library(here)
source(here("R/helpers/functions.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

# Past (1978) raw sources: seedlings from "Rainier Veg", adults from "rawsizedata"
MORA_raw_file = here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx")
MORA_veg  = read_excel(MORA_raw_file, sheet = "Rainier Veg")   # past seedling source
MORA_size = read_excel(MORA_raw_file, sheet = "rawsizedata")   # past adult tree source

# Present (resurvey) sources: seedling tallies and individual-tree records.
# Tally columns use "-" for not-recorded; coerce to numeric (NA) so they sum.
MORA_seedlings = read_csv(here("data/MORA/MORA_Seedlings_Resurvey_Cleaned.csv")) %>%
  mutate(across(c(X10.50cm.Tally, X51.140cm.Tally), ~ suppressWarnings(as.numeric(.))))
MORA_trees     = read_csv(here("data/MORA/MORA_TreeData_Resurvey_Cleaned.csv"))

MORA_plot_lib = read_csv(here("data/MORA/MORA_plot_lib.csv"))
MORA_sp_lib = read_csv(here("data/MORA/MORA_spp_lib.csv"))
MORA_sp_lib = MORA_sp_lib %>% mutate(past_code = ifelse(past_code == "TSH4", "TSHE", past_code))

# Resolve survey visits BEFORE coding modern species presence. Adult dates are
# authoritative. Match seedlings to their original adult visit first (including
# the verified mislabeled repeat visits), then retain the latest adult year.
# Records from visits tied within that year remain pooled. Received CSVs are
# preserved; assigned dates and every discarded row are exported for review.
MORA_visits = resolve_mora_resurveys(MORA_trees, MORA_seedlings, MORA_plot_lib,
  read_csv(here("data/MORA/resurvey_seedling_visit_mapping.csv"), show_col_types = FALSE))
MORA_trees = MORA_visits$trees
MORA_seedlings = MORA_visits$seedlings
write_csv(MORA_visits$audit, here("output/MORA_resurvey_record_audit.csv"))
write_csv(MORA_visits$visits, here("output/MORA_resurvey_visit_audit.csv"))
write_csv(MORA_visits$years, here("output/MORA_plot_years.csv"))

# ---- in-memory patch: the legacy Populus code (same pattern as TSH4 above) ---
# MORA_spp_lib.csv's only Populus row is `past_code = "absent_past" / prst_code =
# "POPBAL"`, i.e. it asserts Populus was not recorded in 1978. It was: the legacy
# workbook has POTR in `rawsizedata` (4 plots, 6 stems) and a POTR2 column in
# `Rainier Veg`. With no past_code == "POTR" row, the past join returns NA and
# those 4 plots are silently discarded - so MORA read "Populus 0 past / 3
# present", a false colonisation.
#
# Patched HERE and not in the CSV, on purpose: the library file is shared, and
# this is a code-LINKAGE fix, not a taxonomic one. The taxonomy (balsamifera and
# trichocarpa are one taxon -> Populus trichocarpa) stays where every other
# cross-site naming decision lives, in R/stages/000_occurrence_data_consolidate.R.
stopifnot(sum(MORA_sp_lib$prst_code == "POPBAL", na.rm = TRUE) == 1)
stopifnot(!"POTR" %in% MORA_sp_lib$past_code)   # no competing row to collide with
MORA_sp_lib = MORA_sp_lib %>%
  mutate(past_code = ifelse(prst_code == "POPBAL" & !is.na(prst_code), "POTR", past_code))

# Test function to validate data
run_tests = function() {
  cat("Running data validation tests...\n")

  # Test 1: Check if required datasets exist
  if (!exists("MORA_veg")) stop("ERROR: MORA_veg dataset not found")
  if (!exists("MORA_size")) stop("ERROR: MORA_size dataset not found")
  if (!exists("MORA_seedlings")) stop("ERROR: MORA_seedlings dataset not found")
  if (!exists("MORA_trees")) stop("ERROR: MORA_trees dataset not found")
  if (!exists("MORA_plot_lib")) stop("ERROR: MORA_plot_lib dataset not found")
  if (!exists("MORA_sp_lib")) stop("ERROR: MORA_sp_lib dataset not found")
  cat("✓ All required datasets found\n")

  # Test 2: Check required columns exist
  required_veg_cols = c("SiteName", "Plotno")
  if (!all(required_veg_cols %in% colnames(MORA_veg))) {
    stop("ERROR: Missing required columns in MORA_veg (Rainier Veg sheet)")
  }
  if (!any(str_detect(colnames(MORA_veg), "1$"))) {
    stop("ERROR: No size-class-1 (seedling) columns found in MORA_veg")
  }

  required_size_cols = c("Plotno", "Species", "DBH0", ">DBH120")
  if (!all(required_size_cols %in% colnames(MORA_size))) {
    stop("ERROR: Missing required columns in MORA_size (rawsizedata sheet)")
  }

  required_seedling_cols = c("Year", "Plot_ID", "Species", "X10.50cm.Tally", "X51.140cm.Tally")
  if (!all(required_seedling_cols %in% colnames(MORA_seedlings))) {
    stop("ERROR: Missing required columns in MORA_seedlings")
  }

  required_tree_cols = c("Year", "Plot_ID", "Species")
  if (!all(required_tree_cols %in% colnames(MORA_trees))) {
    stop("ERROR: Missing required columns in MORA_trees")
  }

  required_plot_cols = c("Plotno", "plot_id", "Plot_ID")
  if (!all(required_plot_cols %in% colnames(MORA_plot_lib))) {
    stop("ERROR: Missing required columns in MORA_plot_lib")
  }

  required_sp_cols = c("past_code", "prst_code", "final_species", "canopy_type")
  if (!all(required_sp_cols %in% colnames(MORA_sp_lib))) {
    stop("ERROR: Missing required columns in MORA_sp_lib")
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

# Report how the raw species/plot codes match the libraries
check_library_matching = function(mora_veg, mora_size, mora_seedlings, mora_trees,
                                   mora_plot_lib, mora_sp_lib) {

  cat("Checking library matching...\n")

  overstory = mora_sp_lib %>%
    filter(canopy_type %in% c("overstory", "overstory_full", "overstory_rare"))

  # Helper: report species-code matching against a library code column
  report_codes = function(label, codes, lib_codes) {
    codes = codes[!is.na(codes)]
    unmatched = setdiff(codes, lib_codes)
    cat("  -", label, ":", length(codes), "codes | unmatched:", length(unmatched),
        if (length(unmatched) > 0) paste0("(", paste(unmatched, collapse = ", "), ")") else "",
        "| overstory matches:", length(intersect(codes, overstory_codes)), "\n")
  }

  # --- Past species codes (matched on past_code) ---
  overstory_codes = overstory$past_code
  size_codes = unique(mora_size$Species)
  seedling_codes = colnames(mora_veg) %>% str_subset("[A-Z]+1$") %>% str_remove("1$") %>% unique()
  report_codes("rawsizedata (past adults)", size_codes, mora_sp_lib$past_code)
  report_codes("Rainier Veg class 1 (past seedlings)", seedling_codes, mora_sp_lib$past_code)

  # --- Present species codes (matched on prst_code) ---
  overstory_codes = overstory$prst_code
  report_codes("resurvey seedlings (present)", unique(mora_seedlings$Species), mora_sp_lib$prst_code)
  report_codes("resurvey trees (present)", unique(mora_trees$Species), mora_sp_lib$prst_code)

  # --- Plot matching ---
  report_plots = function(label, plots, lib_plots) {
    plots = unique(plots[!is.na(plots)])
    matched = intersect(plots, lib_plots)
    cat("  -", label, "plots matched to plot_lib:", length(matched), "/", length(plots),
        "(", length(plots) - length(matched), "not survey-resurvey plots, dropped )\n")
  }
  report_plots("rawsizedata", mora_size$Plotno, mora_plot_lib$Plotno)
  report_plots("Rainier Veg", mora_veg$Plotno, mora_plot_lib$Plotno)
  report_plots("resurvey seedlings", mora_seedlings$Plot_ID, mora_plot_lib$Plot_ID)
  report_plots("resurvey trees", mora_trees$Plot_ID, mora_plot_lib$Plot_ID)

  cat("Library matching check completed.\n\n")
}

# Clean MORA past (1978) data: seedlings from Rainier Veg, adults from rawsizedata
clean_past = function(mora_veg, mora_size, mora_plot_lib, mora_sp_lib) {

  cat("Cleaning MORA past (1978) data...\n")

  # --- Seedlings: "Rainier Veg" sheet, tree size class 1 only ---
  # Tree size classes: 1 = established seedlings (10-140 cm tall), 2 = saplings,
  # 3 = poles, 4 = standards. Classes 2-4 are redundant with rawsizedata, so only
  # class 1 is taken here. Low-abundance codes are corrected (per the workbook
  # metadata): 0.1 (present near but not in plot) -> 0, 0.2 (trace amount) -> 1.
  seedlings = mora_veg %>%
    select(-SiteName) %>%
    pivot_longer(cols = -Plotno,
                 names_to = "species_code",
                 values_to = "value") %>%
    mutate(
      size_class = str_extract(species_code, "[1-4]$"),
      species_code = str_remove(species_code, "[1-4]$"),
      value = case_when(value == 0.1 ~ 0,
                        value == 0.2 ~ 1,
                        .default = value)
    ) %>%
    filter(size_class == "1", value > 0) %>%
    distinct(Plotno, species_code) %>%
    mutate(stage = "seedling")

  cat("  - Seedling records (Rainier Veg, size class 1):", nrow(seedlings), "\n")

  # --- Adults: "rawsizedata" sheet, summed binned DBH counts ---
  # bigtree1-7 columns are excluded: those individuals are already counted in
  # the >DBH120 bin, so adding them would double-count.
  adults = mora_size %>%
    mutate(count_dbh = rowSums(across(DBH0:`>DBH120`), na.rm = TRUE)) %>%
    group_by(Plotno, species_code = Species) %>%
    summarize(count_dbh = sum(count_dbh, na.rm = TRUE), .groups = "drop") %>%
    filter(count_dbh > 0) %>%
    distinct(Plotno, species_code) %>%
    mutate(stage = "adult")

  cat("  - Adult records (rawsizedata):", nrow(adults), "\n")

  # Combine seedling and adult occurrences
  past_long = bind_rows(seedlings, adults) %>%
    mutate(period = "past", year = 1975, occurrence = 1)

  cat("  - Combined seedling + adult records:", nrow(past_long), "\n")

  # Join with species library to filter for overstory and rare species
  past_filtered = past_long %>%
    left_join(mora_sp_lib, by = c("species_code" = "past_code")) %>%
    filter(canopy_type %in% c("overstory", "overstory_full", "overstory_rare")) %>%
    filter(!is.na(final_species))

  cat("  - After filtering for target species:", nrow(past_filtered), "records\n")

  if (nrow(past_filtered) == 0) {
    warning("WARNING: No records found after species filtering for past data")
  }

  # Join with plot library to get standardized plot_id, then merge seedling +
  # adult into a single presence record per plot-species
  # `stage` is RETAINED here (it used to be dropped by this distinct()). The
  # caller collapses it away for MORA_occ.csv and keeps it for
  # MORA_occ_stage.csv, which is what lets the adult-vs-seedling figure be built
  # from an output file instead of from this script's in-memory objects.
  past_final = past_filtered %>%
    left_join(mora_plot_lib, by = "Plotno") %>%
    filter(!is.na(plot_id)) %>%
    distinct(period, year, plot_id, species = final_species, stage, occurrence)

  cat("  - Final past data (merged to presence):", nrow(past_final), "records\n")

  return(past_final)
}

# Clean MORA present (resurvey) data: seedlings from the seedling resurvey,
# adults from the individual-tree resurvey
clean_present = function(mora_seedlings, mora_trees, mora_plot_lib, mora_sp_lib) {

  cat("Cleaning MORA present (resurvey) data...\n")

  valid_plots = unique(mora_plot_lib$Plot_ID)
  valid_plots = valid_plots[!is.na(valid_plots)]

  cat("  - Filtering for", length(valid_plots), "plots from plot library\n")

  # --- Seedlings: resurvey seedling tallies (10-50 cm + 51-140 cm height bins) ---
  # This matches the 1978 "size class 1" definition (seedlings 10-140 cm tall).
  present_seedlings = mora_seedlings %>%
    filter(Plot_ID %in% valid_plots) %>%
    mutate(tally = coalesce(X10.50cm.Tally, 0) + coalesce(X51.140cm.Tally, 0)) %>%
    filter(tally > 0) %>%
    distinct(Plot_ID, species_code = Species) %>%
    mutate(stage = "seedling")

  cat("  - Seedling records (resurvey seedling survey):", nrow(present_seedlings), "\n")

  # --- Adults: resurvey individual-tree records (one row per tree) ---
  present_adults = mora_trees %>%
    filter(Plot_ID %in% valid_plots, !is.na(Species)) %>%
    distinct(Plot_ID, species_code = Species) %>%
    mutate(stage = "adult")

  cat("  - Adult records (resurvey tree survey):", nrow(present_adults), "\n")

  # Both inputs already represent the selected adult visit, with seedling years
  # assigned to that visit. A second year here would be an unresolved join error.
  present_year = mora_trees %>% select(Plot_ID, Year) %>%
    group_by(Plot_ID) %>%
    summarize(year = unique(Year), .groups = "drop")
  stopifnot(!anyDuplicated(present_year$Plot_ID))

  # Combine seedling and adult occurrences
  present_long = bind_rows(present_seedlings, present_adults) %>%
    mutate(period = "present", occurrence = 1)

  cat("  - Combined seedling + adult records:", nrow(present_long), "\n")

  # Join with species library to filter for overstory and rare species
  present_filtered = present_long %>%
    left_join(mora_sp_lib, by = c("species_code" = "prst_code")) %>%
    filter(canopy_type %in% c("overstory", "overstory_full", "overstory_rare")) %>%
    filter(!is.na(final_species))

  cat("  - After filtering for target species:", nrow(present_filtered), "records\n")

  if (nrow(present_filtered) == 0) {
    warning("WARNING: No records found after species filtering for present data")
  }

  # Attach standardized plot_id + survey year, then merge seedling + adult
  # into a single presence record per plot-species
  # `stage` retained - see the note in clean_past().
  present_final = present_filtered %>%
    left_join(mora_plot_lib %>% select(Plot_ID, plot_id), by = "Plot_ID") %>%
    filter(!is.na(plot_id)) %>%
    left_join(present_year, by = "Plot_ID") %>%
    distinct(period, year, plot_id, species = final_species, stage, occurrence)

  cat("  - Final present data (merged to presence):", nrow(present_final), "records\n")

  return(present_final)
}

# Test species occurrence counts between raw sources and cleaned data
test_species_counts = function(mora_veg, mora_size, mora_seedlings, mora_trees,
                               mora_occ, mora_sp_lib, mora_plot_lib) {

  cat("\nTesting species occurrence counts...\n")

  valid_plots_no = mora_plot_lib$Plotno     # numeric plot numbers (past sources)
  valid_plots_id = mora_plot_lib$Plot_ID    # standardized IDs (present sources)

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

    # Count raw past plot occurrences: present as a seedling (Rainier Veg
    # size class 1) OR as an adult (rawsizedata), among plot-library plots
    if (!is.na(past_code)) {
      seedling_col = paste0(past_code, "1")
      seedling_plots = numeric(0)
      if (seedling_col %in% colnames(mora_veg)) {
        veg_valid = mora_veg %>% filter(Plotno %in% valid_plots_no)
        sv = veg_valid[[seedling_col]]
        sv = case_when(sv == 0.1 ~ 0, sv == 0.2 ~ 1, .default = sv)
        seedling_plots = veg_valid$Plotno[!is.na(sv) & sv > 0]
      }

      adult_plots = mora_size %>%
        filter(Plotno %in% valid_plots_no, Species == past_code) %>%
        mutate(count_dbh = rowSums(across(DBH0:`>DBH120`), na.rm = TRUE)) %>%
        group_by(Plotno) %>%
        summarize(count_dbh = sum(count_dbh, na.rm = TRUE), .groups = "drop") %>%
        filter(count_dbh > 0) %>%
        pull(Plotno)

      raw_past_plots = length(unique(c(seedling_plots, adult_plots)))
    } else {
      raw_past_plots = 0
    }

    # Count raw present plot occurrences: present as a seedling (resurvey
    # seedling survey) OR as an adult (resurvey tree survey)
    if (!is.na(present_code)) {
      seed_plots = mora_seedlings %>%
        filter(Plot_ID %in% valid_plots_id, Species == present_code) %>%
        filter(coalesce(X10.50cm.Tally, 0) + coalesce(X51.140cm.Tally, 0) > 0) %>%
        pull(Plot_ID)

      tree_plots = mora_trees %>%
        filter(Plot_ID %in% valid_plots_id, Species == present_code) %>%
        pull(Plot_ID)

      raw_present_records = length(unique(c(seed_plots, tree_plots)))
    } else {
      raw_present_records = 0
    }

    # Count in cleaned data (occurrences only)
    cleaned_past_plots = mora_occ %>%
      filter(species == sp, period == "past") %>%
      nrow()

    cleaned_present_plots = mora_occ %>%
      filter(species == sp, period == "present") %>%
      nrow()

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
check_library_matching(MORA_veg, MORA_size, MORA_seedlings, MORA_trees,
                       MORA_plot_lib, MORA_sp_lib)

# Apply cleaning functions
mora_past_clean = clean_past(MORA_veg, MORA_size, MORA_plot_lib, MORA_sp_lib)
mora_present_clean = clean_present(MORA_seedlings, MORA_trees, MORA_plot_lib, MORA_sp_lib)

# Combine past and present data.
# The two cleaners now return one row per plot x species x STAGE. mora_stage
# keeps that resolution for the adult-vs-seedling figure; mora_occ collapses it
# back to one presence row per plot x species, which is what it always was -
# the distinct() below is what makes the seedling/adult merge, so it must not be
# dropped or every species present at both stages would be counted twice.
mora_stage = bind_rows(mora_past_clean, mora_present_clean) %>%
  distinct(period, plot_id, species, stage) %>%
  arrange(plot_id, species, period, stage)

mora_occ = bind_rows(mora_past_clean, mora_present_clean) %>%
  distinct(period, year, plot_id, species, occurrence) %>%
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
test_species_counts(MORA_veg, MORA_size, MORA_seedlings, MORA_trees,
                    mora_occ, MORA_sp_lib, MORA_plot_lib)

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
# Stage-resolved companion. Same plots and species as MORA_occ.csv, but one row
# per stage, so R/stages/000_occurrence_data_consolidate.R can draw the adult vs
# seedling comparison WITHOUT source()-ing this script (which would rewrite these
# outputs as a side effect, which was the problem in the removed historical stage diagnostic).
write_csv(mora_stage, file = here("output/MORA_occ_stage.csv"))
stopifnot(setequal(paste(mora_stage$plot_id, mora_stage$species, mora_stage$period),
                   paste(mora_occ$plot_id,   mora_occ$species,   mora_occ$period)))
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

if (render_figures) {
  pdf(file = here("plot/test_figures/MORA_dynamics.pdf"), width = 10, height = 8)
  print("Creating turnover heatmap...")
  print(heatmap_plot)

  print("Creating alluvial flow diagram...")
  print(alluvial_plot)

  print(count_plot)
  dev.off()
}
