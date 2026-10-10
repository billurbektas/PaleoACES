# GENERATED REVIEW COPY — DO NOT EXECUTE AS THE WORKFLOW
# Rebuild: Rscript R/workflow.R --offline --report
# Bodies are copied verbatim in workflow order; automatic and optional tests are excluded.
# The driver provides conditional execution and isolated environments that concatenation does not preserve.
# Retained helper sources refer to the actual shared definitions.
# Historical chronology source hashes are preserved in Cores/provenance/chronology_relocation.json.
#
# 01. R/stages/000_MORA_cleaning.R
# 02. R/stages/000_NOCA_cleaning.R
# 03. R/stages/01_get_fire_info.R
# 04. R/stages/000_MORA_climate.R
# 05. R/stages/000_NOCA_climate.R
# 06. R/stages/000_PALEO_a_agedepth.R [OPTIONAL: --age-models; control generation and MCMC]
# 07. R/stages/000_PALEO_b_vegetation.R
# 08. R/stages/000_FIRE_cleaning.R
# 09. R/stages/000_PALEO_c_fire.R
# 10. R/stages/000_PALEO_d_climate_download.R
# 11. R/stages/000_PALEO_e_climate.R
# 12. R/stages/000_occurrence_data_consolidate.R
# 13. R/stages/05_cca_model.R
# 14. R/stages/12_walsh_fire_reproduction.R
# 15. R/stages/13_holocene_climate_fire_eras.R
# 16. R/stages/09_tracking_metrics.R
# 17. R/stages/09b_tracking_model_data.R
# 18. R/stages/10_tracking_era_models.R
# 19. R/stages/10a_tracking_lake_sensitivity.R
# 20. R/stages/10b_tracking_manuscript_figure.R
# 21. R/stages/05a_cca_figure.R
# 22. R/stages/09a_tracking_example_and_visualizations.R
# 23. R/stages/12a_fire_event_detection_worked_example.R
# 24. R/stages/13a_climate_change_figure.R
# 25. R/stages/13b_fire_method_worked_example.R

# ============================================================================
# BEGIN R/stages/000_MORA_cleaning.R
# ============================================================================
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
# END R/stages/000_MORA_cleaning.R

# ============================================================================
# BEGIN R/stages/000_NOCA_cleaning.R
# ============================================================================
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(readxl)
  library(ggalluvial)
})
source(here("R/helpers/functions.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

# Get overstory ----
## Get resurveys ----
NOCA_plots = read_csv("data/NOCA/NOCA_plots_fromWilson.csv")%>%
  rename(plot_id = `2015.Plot.Name`, 
         plot_id_past = `1980.Plot.Name`,
         elevation = `2015.Elevation.m`)%>%
  select(-Resurvey.Year)%>%
  filter(!plot_id %in% c("Supp2026","ROSS4001REF", "Supp5127"))%>% #ASK!
  mutate(plot_id = toupper(plot_id))%>%
  filter(!is.na(Latitude))

# Initialize plot tracking dataframe
plot_tracking = data.frame(
  plot_id = character(),
  plot_id_past = double(),
  period = character(),
  status = character(),
  reason = character(),
  stringsAsFactors = FALSE
)

### Clean the present vegetation surveys ----
NOCA_present_splib =
  read_excel("data/NOCA/NOCA_vegetation_fromJHRL.xlsx", sheet = "Plant List") %>%
  rename(past_species_abv = `Legacy code`, 
         present_species_abv = `Resurvey code`, 
         species = `Resurvey species name`
  )%>%
  select(past_species_abv, present_species_abv, species)%>%
  distinct()%>%
  mutate(species = case_when(present_species_abv == "ABPE" ~ "Abies sp.",
                             present_species_abv == "THSE" ~ "Tsuga heterophylla",
                             present_species_abv == "CHNO" ~ "Chamaecyparis nootkatensis",
                             present_species_abv == "PISI" ~ "Picea sitchensis",
                             present_species_abv == "POAI" ~ "Populus balsamifera",
                             present_species_abv == "SARA" ~ "Sambucus racemosa",
                             present_species_abv == "SAXX" ~ "Salix sp.",
                             present_species_abv == "THPL" ~ "Thuja plicata",
                             .default = species))%>%
  mutate(species = str_to_sentence(species))%>%
  mutate(species = ifelse(species == "Thuja plicata.", "Thuja plicata", species))

# These labels are not identified tree species. Remove them before constructing
# any cleaned occurrence or stage table; the received files themselves remain
# immutable. Salix is also excluded as an understory/shrub taxon by the shared
# consolidation rules, but filtering it here keeps the NOCA cleaner species-only.
NOCA_UNSUPPORTED_TAXA = c("Unknown tree.", "unknown", "Abies sp.", "Salix sp.")
is_supported_noca_taxon = function(x) {
  !is.na(x) & !x %in% NOCA_UNSUPPORTED_TAXA
}

NOCA_present_raw =
  read_excel(here("data/NOCA/NOCA_vegetation_fromJHRL.xlsx"), sheet = "Tree Data") %>%
  transmute(
    plot_id = str_to_upper(str_trim(as.character(`Plot ID`))),
    present_species_abv = str_to_upper(str_trim(as.character(species_abv))),
    DBH = suppressWarnings(as.numeric(DBH))
  )

# The 2026 workbook is an authoritative correction layer, not a complete tree
# table. Most of its plots were omitted from the JHRL master; six old plot-ID
# groups must be retired to avoid retaining mislabeled or mixed records.
NOCA_tree_correction_file = here(
  "data/NOCA/OriginalDataFiles_NOCA/2026_corrected_trees_for_Billur.xlsx"
)
required_correction_columns = c("Plot", "Species", "DBH")
correction_columns = names(read_excel(NOCA_tree_correction_file, sheet = "Trees", n_max = 0))
if (!all(required_correction_columns %in% correction_columns)) {
  stop("Corrected NOCA tree workbook is missing columns: ",
       paste(setdiff(required_correction_columns, correction_columns), collapse = ", "))
}

NOCA_present_corrected = read_excel(NOCA_tree_correction_file, sheet = "Trees") %>%
  transmute(
    plot_id = str_to_upper(str_trim(as.character(Plot))),
    present_species_abv = str_to_upper(str_trim(as.character(Species))),
    DBH = suppressWarnings(as.numeric(DBH))
  )

if (nrow(NOCA_present_corrected) != 2366L ||
    n_distinct(NOCA_present_corrected$plot_id) != 54L) {
  stop("Unexpected corrected tree workbook size: expected 2,366 stems in 54 plots.")
}
if (anyNA(NOCA_present_corrected$plot_id) ||
    anyNA(NOCA_present_corrected$present_species_abv) ||
    anyNA(NOCA_present_corrected$DBH)) {
  stop("Corrected tree workbook contains a missing plot, species code, or numeric DBH.")
}

correction_groups = list(
  BBCR6065 = "BBCR6075",
  HB5134 = "HB5144",
  STE2022 = "STE2020",
  STE2077 = "STE2072",
  PYRA1015 = c("PYRA1013", "PYRA1015"),
  ROSS3048 = c("ROSS3044", "ROSS3048")
)
stem_multiset = function(x) {
  x %>% count(present_species_abv, DBH, name = "n") %>%
    arrange(present_species_abv, DBH, n)
}
for (source_id in names(correction_groups)) {
  old_stems = NOCA_present_raw %>% filter(plot_id == source_id) %>% stem_multiset()
  corrected_stems = NOCA_present_corrected %>%
    filter(plot_id %in% correction_groups[[source_id]]) %>% stem_multiset()
  if (!identical(old_stems, corrected_stems)) {
    stop("Corrected stems do not exactly reconcile with source group ", source_id, ".")
  }
}

corrected_plot_ids = sort(unique(NOCA_present_corrected$plot_id))
retired_source_ids = names(correction_groups)
replacement_ids = union(corrected_plot_ids, retired_source_ids)
NOCA_present_patched = bind_rows(
  NOCA_present_raw %>% filter(!plot_id %in% replacement_ids),
  NOCA_present_corrected
)
for (target_id in corrected_plot_ids) {
  final_stems = NOCA_present_patched %>%
    filter(plot_id == target_id) %>% stem_multiset()
  expected_stems = NOCA_present_corrected %>%
    filter(plot_id == target_id) %>% stem_multiset()
  if (!identical(final_stems, expected_stems)) {
    stop("Corrected target ", target_id,
         " was not replaced exactly once in the patched stem table.")
  }
}
retired_only_ids = setdiff(retired_source_ids, corrected_plot_ids)
if (any(NOCA_present_patched$plot_id %in% retired_only_ids)) {
  stop("Retired erroneous source IDs remain in the patched stem table: ",
       paste(intersect(retired_only_ids, NOCA_present_patched$plot_id), collapse = ", "))
}

NOCA_present = NOCA_present_patched %>%
  left_join(NOCA_present_splib, by = "present_species_abv")

unresolved_corrected = NOCA_present_corrected %>%
  anti_join(NOCA_present_splib %>% distinct(present_species_abv),
            by = "present_species_abv")
if (!identical(sort(unique(unresolved_corrected$present_species_abv)), "FRAXINUS?")) {
  stop("Unexpected unresolved species code(s) in corrected tree workbook: ",
       paste(sort(unique(unresolved_corrected$present_species_abv)), collapse = ", "))
}

# Track present plots with no supported species data, then remove every
# unsupported record before occurrences are built.
takeout_plots_present =
  NOCA_present %>%
  group_by(plot_id)%>%
  summarize(any_supported_taxon = any(is_supported_noca_taxon(species)),
            .groups = "drop") %>%
  filter(!any_supported_taxon) %>%
  pull(plot_id)%>%
  unique()

# Add to tracking
plot_tracking = bind_rows(plot_tracking,
                          data.frame(
                            plot_id = takeout_plots_present,
                            plot_id_past = NA,
                            period = "present",
                            status = "removed",
                            reason = "no species recorded"
                          ))

cat("There are", length(takeout_plots_present), "to take out because there are no species recorded.")

NOCA_present = NOCA_present %>%
  filter(!plot_id %in% takeout_plots_present,
         is_supported_noca_taxon(species))

# Get all present plots from NOCA_plots (includes plots with no trees)
all_present_plots_raw = NOCA_plots %>% filter(!plot_id %in% takeout_plots_present) %>% pull(plot_id)%>% unique()
present_plots_with_trees = NOCA_present %>%
  filter(!is.na(species)) %>%
  pull(plot_id) %>%
  unique()

# Present overstory (tree) occurrences: count = number of identified tree stems.
NOCA_present_occ_trees = NOCA_present %>%
  select(plot_id, species) %>%
  group_by(plot_id, species) %>% summarize(count = n(), .groups = "drop")

# --- Present seedlings (JHRL "Seedlings" sheet) ---
# Mirrors the MORA approach: a species is present in a plot if it occurs as a
# tree OR a seedling. Height tallies 10-50 + 51-140 cm (== MORA size class 1).
# This restores past<->present symmetry, since the legacy TREE data already
# counts the 0-3 m (regeneration) height class.
NOCA_present_seed =
  read_excel("data/NOCA/NOCA_vegetation_fromJHRL.xlsx", sheet = "Seedlings") %>%
  rename(plot_id = `Plot ID`, present_species_abv = Species) %>%
  mutate(plot_id = toupper(plot_id),
         seed_tally = coalesce(suppressWarnings(as.numeric(`10-50cm Tally`)), 0) +
                      coalesce(suppressWarnings(as.numeric(`51-140cm Tally`)), 0)) %>%
  filter(!is.na(present_species_abv), seed_tally > 0,
         !plot_id %in% takeout_plots_present) %>%
  left_join(NOCA_present_splib, by = "present_species_abv")

NOCA_present_seed_occ = NOCA_present_seed %>%
  filter(!is.na(species)) %>%
  group_by(plot_id, species) %>% summarize(count = sum(seed_tally), .groups = "drop")

# A plot has present vegetation if it has a tree OR a seedling record
present_plots_with_veg = union(present_plots_with_trees, unique(NOCA_present_seed_occ$plot_id))
present_empty_plots = setdiff(all_present_plots_raw, present_plots_with_veg)

# Merge tree + seedling into one presence record per plot-species
NOCA_present_occ = bind_rows(NOCA_present_occ_trees, NOCA_present_seed_occ) %>%
  group_by(plot_id, species) %>% summarize(count = sum(count), .groups = "drop") %>%
  mutate(occurence = 1)

seedling_only = anti_join(NOCA_present_seed_occ, NOCA_present_occ_trees,
                          by = c("plot_id", "species"))
cat("There are", length(unique(NOCA_present_occ$plot_id)), "plots in the present data.")
cat("\nSeedlings added", nrow(NOCA_present_seed_occ), "present plot-species records;",
    nrow(seedling_only), "are seedling-only (no tree);",
    n_distinct(setdiff(unique(NOCA_present_seed_occ$plot_id), present_plots_with_trees)),
    "plots gain present data purely from seedlings.\n")

## Get legacy ----
NOCA_past_splib = read_excel("data/NOCA/AGEEDATA_NEW.xlsx", sheet = "SPECIES")
NOCA_past_plot_info =  read_excel("data/NOCA/AGEEDATA_NEW.xlsx", sheet = "OVERVIEW") # plot area is here for past plots.

NOCA_past = read_excel("data/NOCA/AGEEDATA_NEW.xlsx", sheet = "TREE")%>%
  rename(plot_id_past = PLOT, 
         past_species_abv = SPEC)%>%
  left_join(NOCA_present_splib, by = "past_species_abv")%>%
  left_join(NOCA_plots)

# Take out some plots because of missing GPS coordinates
past_plot_takeout = NOCA_past %>%
  filter(is.na(Latitude)|is.na(Longitude))%>%
  pull(plot_id_past)%>%
  unique()

# Add to tracking
plot_tracking = bind_rows(plot_tracking,
                          data.frame(
                            plot_id = NA,
                            plot_id_past = past_plot_takeout,
                            period = "past",
                            status = "removed",
                            reason = "missing GPS coordinates"
                          ))

cat("There are", length(past_plot_takeout), "to take out because of missing GPS info.")

NOCA_past = 
  NOCA_past %>%
  filter(!plot_id_past %in% past_plot_takeout)%>%
  mutate(species = case_when(past_species_abv == "ACCI" ~ "Acer circinatum",
                             .default = species))
cat("There are", length(unique(NOCA_past$plot_id_past)), "past plots after we take out plots with missing GPS.")

# Preserve the eligible plot universe before removing unsupported taxon rows.
all_past_plots_raw = unique(NOCA_past$plot_id)
NOCA_plot_info = NOCA_past %>%
  select(plot_id, Latitude, Longitude, elevation) %>%
  distinct() %>%
  mutate(Longitude = ifelse(Longitude > 0, -Longitude, Longitude))

# CARI449 and CARI450 have opposite raw longitude signs but collapse to the
# same normalized coordinate after the positive longitude is corrected to
# west, despite a 527 m elevation difference. Rachel's September 2024 email
# warns against the 2014 workbook GPS sheet and identifies the paper's coordinate
# CSV as authoritative. That CSV retains this collision; her other notes supply
# no correction. At the author's request, exclude BOTH dates upstream under the
# study-level policy below. Keep raw coordinates in this audit for provenance.
NOCA_coordinate_collision_audit = NOCA_plots %>%
  transmute(
    plot_id,
    raw_latitude = Latitude,
    raw_longitude = Longitude,
    normalized_latitude = Latitude,
    normalized_longitude = ifelse(Longitude > 0, -Longitude, Longitude),
    elevation
  ) %>%
  distinct() %>%
  group_by(normalized_latitude, normalized_longitude) %>%
  mutate(
    shared_coordinate_count = n_distinct(plot_id),
    elevation_range_m = max(elevation, na.rm = TRUE) - min(elevation, na.rm = TRUE)
  ) %>%
  filter(shared_coordinate_count > 1L) %>%
  ungroup() %>%
  mutate(status = "excluded—GPS problem; no verified coordinate correction") %>%
  arrange(normalized_latitude, normalized_longitude, plot_id)
NOCA_past = NOCA_past %>% filter(is_supported_noca_taxon(species))

NOCA_past = 
  NOCA_past %>%
  mutate(`DEN_0-3` = ifelse(is.na(`DEN_0-3`), 0, `DEN_0-3`),
         `DEN_3-10` = ifelse(is.na(`DEN_3-10`), 0, `DEN_3-10`),
         `DEN >10` = ifelse(is.na(`DEN >10`), 0, `DEN >10`)
  )%>%
  mutate(count = `DEN_0-3` + `DEN_3-10` + `DEN >10`)

# Check if there are any species with no taxonomic names assigned. 
no_info_sp = NOCA_past %>% filter(is.na(species)) %>% pull(past_species_abv)%>% unique()
if(length(no_info_sp)>0) {cat(no_info_sp, " are the species abb. with no species name info.")}

NOCA_past_occ = NOCA_past %>% select(plot_id, species, count) %>%
  filter(count >0)%>%
  mutate(occurence = 1)

# Identify plots with zero trees in past (empty plots)
past_empty_plots = union(
  setdiff(all_past_plots_raw, unique(NOCA_past$plot_id)),
  NOCA_past %>%
  group_by(plot_id) %>% 
  summarize(total_count = sum(count, na.rm = TRUE)) %>%
  filter(total_count == 0) %>%
  pull(plot_id)
)

# Identify plots with trees in past but empty now
past_plots_with_trees = unique(NOCA_past_occ$plot_id)
plots_trees_past_empty_now = intersect(past_plots_with_trees, present_empty_plots)

# Identify plots empty in both periods
plots_empty_both_periods = intersect(present_empty_plots, past_empty_plots)

# A duplicated plot/species row would double-count a legacy occurrence.
past_duplicates = NOCA_past_occ %>%
  count(plot_id, species, name = "n") %>%
  filter(n > 1)
if (nrow(past_duplicates) > 0) {
  print(past_duplicates)
  stop("Duplicate NOCA legacy plot/species records detected.")
}

# Merge past and present occurences ----
# This now correctly includes empty present plots
plots_to_keep = unique(intersect(all_present_plots_raw, all_past_plots_raw))

# Remove plots that are empty in both periods from final dataset
plots_to_keep = setdiff(plots_to_keep, plots_empty_both_periods)

# Study-level exclusions agreed after reviewing Rachel Wilson's notes. These are
# valid source IDs, but they are not suitable paired observations for this study:
# BAK487 is an old clearcut removed from Wilson's final analysis; BEAV6061's
# historical location could not be identified reliably because its elevation was
# inaccurate and the resurvey landed in an avalanche chute.
# CARI449/CARI450 share unresolved coordinates in the authoritative CSV; the
# author elected to exclude both rather than assign an unsupported replacement.
NOCA_study_exclusions = tribble(
  ~plot_id,   ~exclusion_reason, ~source_note,
  "BAK487",  "old clearcut; removed from Wilson final analysis",
              "notes_from_Rachel/Burned plots.rtf",
  "BEAV6061", "historic plot location uncertain; resurvey is an avalanche chute",
              "notes_from_Rachel/Missing trees.rtf",
  "CARI449", "GPS problem; shared coordinates conflict with elevations; no verified correction",
              "data/NOCA/Correspondance_Kavya&Rachel_September2024.pdf (page 2); docs/review/NOCA_GPS_EXCLUSION.md",
  "CARI450", "GPS problem; shared coordinates conflict with elevations; no verified correction",
              "data/NOCA/Correspondance_Kavya&Rachel_September2024.pdf (page 2); docs/review/NOCA_GPS_EXCLUSION.md"
)
study_exclusion_ids = intersect(plots_to_keep, NOCA_study_exclusions$plot_id)
if (!setequal(study_exclusion_ids, NOCA_study_exclusions$plot_id)) {
  stop("Expected study-exclusion plots were not all otherwise eligible: ",
       paste(setdiff(NOCA_study_exclusions$plot_id, study_exclusion_ids), collapse = ", "))
}
plots_to_keep = setdiff(plots_to_keep, study_exclusion_ids)

plot_tracking = bind_rows(
  plot_tracking,
  NOCA_study_exclusions %>%
    transmute(plot_id, plot_id_past = NA_real_, period = "both",
              status = "removed", reason = exclusion_reason)
)

# Identify special cases within the plots to keep
plots_empty_past_present_now = intersect(past_empty_plots, intersect(present_plots_with_veg, plots_to_keep))
plots_trees_past_empty_now = intersect(past_plots_with_trees, intersect(present_empty_plots, plots_to_keep))
plots_with_data_both_periods = intersect(past_plots_with_trees, intersect(present_plots_with_veg, plots_to_keep))

# Add tracking for plots that are kept or removed
kept_plots = plots_to_keep
plot_tracking = bind_rows(plot_tracking,
                          data.frame(
                            plot_id = kept_plots,
                            plot_id_past = NA,
                            period = "both",
                            status = "kept",
                            reason = case_when(
                              kept_plots %in% plots_empty_past_present_now ~ "empty in past, trees present now",
                              kept_plots %in% plots_trees_past_empty_now ~ "trees in past, empty present now",
                              .default = "common plots with data"
                            )
                          ))

# Add tracking for plots empty in both periods
if(length(plots_empty_both_periods) > 0) {
  plot_tracking = bind_rows(plot_tracking,
                            data.frame(
                              plot_id = plots_empty_both_periods,
                              plot_id_past = NA,
                              period = "both",
                              status = "removed",
                              reason = "empty in both periods"
                            ))
}

# Track removed plots using raw data
removed_present = setdiff(all_present_plots_raw,
                          c(plots_to_keep, plots_empty_both_periods, study_exclusion_ids))
removed_past = setdiff(all_past_plots_raw,
                       c(plots_to_keep, plots_empty_both_periods, study_exclusion_ids))

if(length(removed_present) > 0) {
  plot_tracking = bind_rows(plot_tracking,
                            data.frame(
                              plot_id = removed_present,
                              plot_id_past = NA,
                              period = "present",
                              status = "removed",
                              reason = "no matching past plot"
                            ))
}

if(length(removed_past) > 0) {
  plot_tracking = bind_rows(plot_tracking,
                            data.frame(
                              plot_id = removed_past,
                              plot_id_past = NA,
                              period = "past",
                              status = "removed",
                              reason = "no matching present plot"
                            ))
}

length(setdiff(NOCA_present_occ$plot_id, NOCA_past_occ$plot_id))

NOCA_present_occ = NOCA_present_occ %>% filter(plot_id %in% plots_to_keep)
NOCA_past_occ = NOCA_past_occ %>% filter(plot_id %in% plots_to_keep)
NOCA_plot_info = NOCA_plot_info %>% filter(plot_id %in% plots_to_keep)

# For empty past plots, create empty occurrence records
if(length(plots_empty_past_present_now) > 0) {
  empty_past_records = data.frame(
    plot_id = plots_empty_past_present_now,
    species = "Abies amabilis", # just putting a random species to be able to create all 0 species matrix later.
    count = 0,
    occurence = 0
  )
  NOCA_past_occ = bind_rows(NOCA_past_occ, empty_past_records)
}

# For empty present plots, create empty occurrence records
if(length(plots_trees_past_empty_now) > 0) {
  empty_present_records = data.frame(
    plot_id = plots_trees_past_empty_now,
    species = "Abies amabilis", # just putting a random species to be able to create all 0 species matrix later.
    count = 0,
    occurence = 0
  )
  NOCA_present_occ = bind_rows(NOCA_present_occ, empty_present_records)
}

NOCA_occ = bind_rows(NOCA_past_occ %>% mutate(period = "past"), NOCA_present_occ %>% mutate(period = "present"))
length(unique(NOCA_occ$plot_id))

cat("There are", length(plots_empty_past_present_now), "plots that were empty in past but have trees now.")
cat("There are", length(plots_trees_past_empty_now), "plots that had trees in past but are empty now.")
cat("There are", length(plots_empty_both_periods), "plots that are empty in both periods.")

# Report plot tracking ----
# Create summary for visualization
plot_summary = plot_tracking %>%
  count(status, reason, name = "n_plots") %>%
  mutate(reason = fct_reorder(reason, n_plots),
         status_color = case_when(
           status == "kept" ~ "#2E8B57",
           status == "removed" ~ "#DC143C"
         ))

# Main visualization
p1 = ggplot(plot_summary, aes(x = reason, y = n_plots, fill = status_color)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = n_plots), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_fill_identity() +
  labs(title = "Plot Status Summary",
       subtitle = "Number of plots kept vs removed by reason",
       x = "Reason",
       y = "Number of plots") +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.text = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

# Create period breakdown
period_summary = plot_tracking %>%
  filter(!is.na(period)) %>%
  count(period, status, name = "n_plots")

p2 = ggplot(period_summary, aes(x = period, y = n_plots, fill = status)) +
  geom_col(position = "dodge", width = 0.7) +
  geom_text(aes(label = n_plots), position = position_dodge(width = 0.7), vjust = -0.3, size = 3.5) +
  scale_fill_manual(values = c("kept" = "#2E8B57", "removed" = "#DC143C")) +
  labs(title = "Plot Status by Period",
       x = "Period",
       y = "Number of plots",
       fill = "Status") +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "top"
  )

# Special cases breakdown  
special_cases = plot_tracking %>%
  filter(status == "kept", 
         reason %in% c("empty in past, trees present now", "trees in past, empty present now")) %>%
  count(reason, name = "n_plots") %>%
  mutate(change_type = case_when(
    reason == "empty in past, trees present now" ~ "Colonization",
    reason == "trees in past, empty present now" ~ "Extirpation"
  ))

p3 = ggplot(special_cases, aes(x = change_type, y = n_plots, fill = change_type)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = n_plots), vjust = -0.3, size = 4) +
  scale_fill_manual(values = c("Colonization" = "#228B22", "Extirpation" = "#FF6347")) +
  labs(title = "Forest Change Events",
       subtitle = "Plots showing colonization or extirpation",
       x = "Change Type",
       y = "Number of plots") +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "none"
  )

# Print plots
if (render_figures) {
  pdf(file = "plot/test_figures/NOCA_cleaning.pdf", height = 8, width = 10)
  print(p1)
  print(p2)
  print(p3)
  dev.off()
}

# Print summary statistics
cat("PLOT TRACKING SUMMARY\n")
cat("====================\n")
cat("Total plots processed:", nrow(plot_tracking), "\n")
cat("Plots kept:", sum(plot_tracking$status == "kept"), "\n")
cat("Plots removed:", sum(plot_tracking$status == "removed"), "\n\n")

cat("CHANGE EVENTS\n")
cat("=============\n")
if(nrow(special_cases) > 0) {
  for(i in 1:nrow(special_cases)) {
    cat(special_cases$change_type[i], "events:", special_cases$n_plots[i], "\n")
  }
} else {
  cat("No change events detected\n")
}

NOCA_occ =
  NOCA_occ %>%
  mutate(species = ifelse(species == "Chamaecyparis nootkatensis","Callitropsis nootkatensis", species))%>%
  mutate(species = ifelse(species == "Cornus stolonifera", "Cornus sericea", species))%>%
  mutate(species = ifelse(species == "Unknown tree.", "unknown", species))%>%
  mutate(species = ifelse(is.na(species), "unknown", species))%>%
  filter(!species %in% NOCA_UNSUPPORTED_TAXA) %>%
  rename(occurrence = occurence)

NOCA_occ = distinct(NOCA_occ)

# Compare the modeled present composition with the same cleaner fed the
# unpatched JHRL tree table. Seedlings are held fixed, so this isolates the tree
# correction rather than mixing it with another data-source decision.
normalize_noca_species = function(x) {
  x = ifelse(x == "Chamaecyparis nootkatensis", "Callitropsis nootkatensis", x)
  x = ifelse(x == "Cornus stolonifera", "Cornus sericea", x)
  x = ifelse(x == "Unknown tree.", "unknown", x)
  ifelse(is.na(x), "unknown", x)
}
unpatched_present_presence = bind_rows(
  NOCA_present_raw %>%
    left_join(NOCA_present_splib, by = "present_species_abv") %>%
    transmute(plot_id, species = normalize_noca_species(species)),
  NOCA_present_seed_occ %>%
    transmute(plot_id, species = normalize_noca_species(species))
) %>%
  filter(plot_id %in% plots_to_keep,
         !species %in% NOCA_UNSUPPORTED_TAXA) %>%
  distinct(plot_id, species)

patched_present_presence = NOCA_occ %>%
  filter(period == "present", occurrence == 1,
         !species %in% NOCA_UNSUPPORTED_TAXA) %>%
  distinct(plot_id, species)

composition_signature = function(x, label) {
  x %>%
    arrange(plot_id, species) %>%
    group_by(plot_id) %>%
    summarize(
      !!paste0(label, "_n_species") := n(),
      !!paste0(label, "_species") := paste(species, collapse = "|"),
      .groups = "drop"
    )
}
lost_species = anti_join(unpatched_present_presence, patched_present_presence,
                         by = c("plot_id", "species")) %>%
  arrange(plot_id, species) %>%
  summarize(species_lost = paste(species, collapse = "|"), .by = plot_id)
gained_species = anti_join(patched_present_presence, unpatched_present_presence,
                           by = c("plot_id", "species")) %>%
  arrange(plot_id, species) %>%
  summarize(species_gained = paste(species, collapse = "|"), .by = plot_id)

NOCA_tree_composition_audit = tibble(plot_id = sort(unique(NOCA_occ$plot_id))) %>%
  left_join(composition_signature(unpatched_present_presence, "unpatched"), by = "plot_id") %>%
  left_join(composition_signature(patched_present_presence, "corrected"), by = "plot_id") %>%
  left_join(lost_species, by = "plot_id") %>%
  left_join(gained_species, by = "plot_id") %>%
  mutate(
    across(ends_with("_n_species"), ~ replace_na(.x, 0L)),
    across(c(unpatched_species, corrected_species, species_lost, species_gained),
           ~ replace_na(.x, "")),
    present_composition_changed = unpatched_species != corrected_species
  )
if (sum(NOCA_tree_composition_audit$present_composition_changed) != 50L) {
  stop("Expected the corrected tree layer to change present composition in 50 modeled plots; found ",
       sum(NOCA_tree_composition_audit$present_composition_changed), ".")
}

# Write all outputs ----
# -----------------------------------------------------------------------------
# Stage-resolved companion table (adult vs seedling/regeneration)
# -----------------------------------------------------------------------------
# Same plots and species as NOCA_occ.csv, one row per stage, so
# R/stages/000_occurrence_data_consolidate.R can draw the adult-vs-seedling comparison
# WITHOUT source()-ing this script (which would rewrite these outputs as a side
# effect, which was the problem in the removed historical stage diagnostic).
#
# ⚠ The two eras do NOT measure regeneration the same way, and the figure must
# say so:
#   past    regeneration = the legacy 0-3 m HEIGHT class (Agee & Kertis 1987);
#           adult        = the 3-10 m and >10 m height classes
#   present regeneration = the JHRL Seedlings tallies (10-140 cm);
#           adult        = the Tree Data stems (DBH, i.e. >1.4 m)
# So "past regeneration" is a coarser, taller band (up to 3 m) than "present
# regeneration" (up to 1.4 m). Adult size limits also differ (>3 m vs >1.4 m),
# so neither label establishes identical size-class sampling across periods.
SEED = "Seedling / regeneration"; ADULT = "Adult"
fix_noca_sp = normalize_noca_species
NOCA_stage = bind_rows(
  NOCA_past %>% filter((`DEN_3-10` + `DEN >10`) > 0) %>%
    transmute(period = "past",    plot_id, species = fix_noca_sp(species), stage = ADULT),
  NOCA_past %>% filter(`DEN_0-3` > 0) %>%
    transmute(period = "past",    plot_id, species = fix_noca_sp(species), stage = SEED),
  NOCA_present_occ_trees %>%
    transmute(period = "present", plot_id, species = fix_noca_sp(species), stage = ADULT),
  NOCA_present_seed_occ %>%
    transmute(period = "present", plot_id, species = fix_noca_sp(species), stage = SEED)
) %>%
  filter(plot_id %in% plots_to_keep) %>%
  distinct(period, plot_id, species, stage) %>%
  arrange(plot_id, species, period, stage)

write_csv(NOCA_stage, file = here("output/NOCA_occ_stage.csv"))

# The stage table must not invent or lose plot x species x period combinations.
# It CAN legitimately be a subset: NOCA_occ.csv carries synthetic all-zero rows
# for plots that are empty in one period, and those have no stage.
stage_key = paste(NOCA_stage$plot_id, NOCA_stage$species, NOCA_stage$period)
occ_key   = NOCA_occ %>% filter(occurrence == 1) %>%
  { paste(.$plot_id, .$species, .$period) }
stopifnot(all(stage_key %in% occ_key))

write_csv(NOCA_present_occ, file = here("output/NOCA_present_occ.csv"))
write_csv(NOCA_past_occ, file = here("output/NOCA_past_occ.csv"))
write_csv(NOCA_plot_info, file = here("output/NOCA_plot_info.csv"))
write_csv(NOCA_coordinate_collision_audit,
          file = here("output/NOCA_coordinate_collision_audit.csv"))
write_csv(NOCA_occ, file = here("output/NOCA_occ.csv"))
# Wilson's plot-specific adult resurvey dates remain authoritative for NOCA.
# One shared table now feeds both sites' climate windows and rate denominators.
NOCA_plot_years = read_csv(here("data/NOCA/NOCA_plots_fromWilson.csv"),
  show_col_types = FALSE) %>%
  transmute(site = "NOCA", plot_id = toupper(trimws(`2015.Plot.Name`)),
    vegetation_t2_year = as.numeric(Resurvey.Year)) %>%
  filter(plot_id %in% NOCA_occ$plot_id) %>% survey_windows()
write_csv(NOCA_plot_years, here("output/NOCA_plot_years.csv"))
modern_plot_years = bind_rows(
  read_csv(here("output/MORA_plot_years.csv"), show_col_types = FALSE) %>%
    filter(plot_id %in% read_csv(here("output/MORA_occ.csv"),
      show_col_types = FALSE)$plot_id), NOCA_plot_years)
write_csv(modern_plot_years, here("output/modern_plot_years.csv"))
saveRDS(plot_year_input_hashes(), here("output/modern_plot_years_sources.rds"))
write_csv(plot_tracking, file = here("output/NOCA_plot_tracking.csv"))
write_csv(NOCA_study_exclusions,
          file = here("output/NOCA_study_exclusions.csv"))
write_csv(NOCA_tree_composition_audit,
          file = here("output/NOCA_tree_composition_audit.csv"))

# Per-corrected-plot provenance and inclusion audit. Raw inputs remain immutable.
raw_plot_counts = NOCA_present_raw %>% count(plot_id, name = "old_rows_at_plot")
corrected_plot_counts = NOCA_present_corrected %>%
  count(plot_id, name = "corrected_rows_added")
raw_coordinate_ids = read_csv(here("data/NOCA/NOCA_plots_fromWilson.csv"),
                              show_col_types = FALSE) %>%
  transmute(plot_id = str_to_upper(str_trim(as.character(`2015.Plot.Name`))),
            coordinates_available = !is.na(Latitude) & !is.na(Longitude))

NOCA_tree_correction_audit = corrected_plot_counts %>%
  left_join(raw_plot_counts, by = "plot_id") %>%
  left_join(raw_coordinate_ids, by = "plot_id") %>%
  left_join(NOCA_tree_composition_audit %>%
              select(plot_id, present_composition_changed),
            by = "plot_id") %>%
  mutate(
    old_rows_at_plot = replace_na(old_rows_at_plot, 0L),
    erroneous_source_id = case_when(
      plot_id == "BBCR6075" ~ "BBCR6065",
      plot_id == "HB5144" ~ "HB5134",
      plot_id == "STE2020" ~ "STE2022",
      plot_id == "STE2072" ~ "STE2077",
      plot_id %in% c("PYRA1013", "PYRA1015") ~ "PYRA1015",
      plot_id %in% c("ROSS3044", "ROSS3048") ~ "ROSS3048",
      TRUE ~ NA_character_
    ),
    erroneous_source_rows_removed = map_int(
      erroneous_source_id,
      ~ if (is.na(.x)) 0L else sum(NOCA_present_raw$plot_id == .x)
    ),
    correction_action = case_when(
      plot_id %in% c("PYRA1013", "PYRA1015") ~ "split corrected PYRA1015 source group",
      plot_id %in% c("ROSS3044", "ROSS3048") ~ "split corrected ROSS3048 source group",
      plot_id == "BBCR6075" ~ "renamed source BBCR6065",
      plot_id == "HB5144" ~ "renamed source HB5134",
      plot_id == "STE2020" ~ "renamed source STE2022",
      plot_id == "STE2072" ~ "renamed source STE2077",
      old_rows_at_plot > 0 ~ "authoritative replacement",
      TRUE ~ "previously omitted; added"
    ),
    final_status = case_when(
      plot_id %in% plots_to_keep ~ "included",
      !coalesce(coordinates_available, FALSE) ~ "excluded",
      !plot_id %in% all_past_plots_raw ~ "excluded",
      TRUE ~ "excluded"
    ),
    exclusion_reason = case_when(
      final_status == "included" ~ NA_character_,
      !coalesce(coordinates_available, FALSE) ~ "missing coordinates",
      !plot_id %in% all_past_plots_raw ~ "no matching legacy tree survey",
      TRUE ~ "removed by NOCA cleaning rules"
    )
  ) %>%
  arrange(plot_id)

expected_exclusions = c("HB5144", "MCAL5004", "ROSS3022")
actual_exclusions = NOCA_tree_correction_audit %>%
  filter(final_status == "excluded") %>% pull(plot_id)
if (!setequal(actual_exclusions, expected_exclusions)) {
  stop("Unexpected corrected-plot exclusions: ",
       paste(sort(actual_exclusions), collapse = ", "))
}
write_csv(NOCA_tree_correction_audit,
          here("output/NOCA_tree_correction_audit.csv"))

# Calculate turnover for NOCA data
noca_turnover_results = calculate_turnover(NOCA_occ)

# Print summary statistics
print_turnover_summary(noca_turnover_results)

# Create visualizations
noca_heatmap_plot = create_turnover_heatmap(noca_turnover_results$turnover_data) 
noca_alluvial_plot = create_alluvial_plot(noca_turnover_results$turnover_data)

# The CCA inclusion threshold belongs to R/stages/05_cca_model.R. This cleaner reports
# the raw NOCA occurrence counts without duplicating downstream model decisions.
noca_count_data = NOCA_occ %>%
  filter(occurrence == 1) %>%
  count(species, period, name = "n_plots")

sp_order = noca_count_data %>%
  group_by(species) %>% summarize(tot = sum(n_plots), .groups = "drop") %>%
  arrange(desc(tot)) %>% pull(species)
noca_count_data = noca_count_data %>% mutate(species = factor(species, levels = sp_order))

noca_count_plot =
  ggplot(noca_count_data, aes(species, n_plots, fill = period)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_fill_manual(values = c("past" = "#8B4513", "present" = "#228B22")) +
  labs(title = "NOCA species occurrence by period",
       subtitle = "Raw cleaning output; CCA eligibility is decided centrally in R/stages/05_cca_model.R",
       x = "Species", y = "Number of plots",
       fill = "Period") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
    plot.title  = element_text(size = 13, face = "bold"),
    legend.position = "top"
  )

# Display plots

if (render_figures) {
  pdf(file = here("plot/test_figures/NOCA_dynamics.pdf"), width = 10, height = 8)
  print("NOCA Turnover heatmap...")
  print(noca_heatmap_plot)

  print("NOCA Alluvial flow diagram...")
  print(noca_alluvial_plot)

  print("NOCA Species count plot...")
  print(noca_count_plot)
  dev.off()
}
# END R/stages/000_NOCA_cleaning.R

# ============================================================================
# BEGIN R/stages/01_get_fire_info.R
# ============================================================================
# Anthropocene fire assignments for MORA and NOCA ----------------------------
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(sf)
  library(patchwork)
  library(maps)
})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

SURVEY_START = 1983L
SURVEY_END = 2015L
FIELD_VERIFIED_100M = c("HIBR2052", "HIBR2082", "STE2047")

# MORA: retain the existing LandTrendr fire method ----------------------------
mora_disturbances = st_read(
  here("data/MORA_disturbances/MORA_1987_2017_V2_1_UTM.shp"), quiet = TRUE
)
MORA_occ = read_csv(here("output/MORA_occ.csv"), show_col_types = FALSE)
MORA_plot_info = read_csv(here("output/MORA_plot_info.csv"), show_col_types = FALSE) %>%
  filter(plot_id %in% unique(MORA_occ$plot_id))

mora_points = MORA_plot_info %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
  st_transform(st_crs(mora_disturbances))

mora_fire_hits = suppressWarnings(st_intersection(
  st_buffer(mora_points, dist = 100),
  mora_disturbances %>% filter(ChangeType == "Fire")
)) %>%
  st_drop_geometry() %>%
  group_by(plot_id) %>%
  summarise(Dist_year = min(Dist_year, na.rm = TRUE), .groups = "drop")

MORA_plot_info_fire = MORA_plot_info %>%
  left_join(mora_fire_hits, by = "plot_id") %>%
  mutate(burnt = !is.na(Dist_year)) %>%
  arrange(plot_id)

if (nrow(MORA_plot_info_fire) != n_distinct(MORA_plot_info_fire$plot_id)) {
  stop("MORA fire assignment produced duplicate plot IDs.")
}

# NOCA: Wilson et al. (2024) method on the PaleoACES plot universe ------------
fire_dir = here("data/MORA_disturbances/fire_mapping_for_Billur")
NOCA_occ = read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE)
noca_ids = sort(unique(str_to_upper(NOCA_occ$plot_id)))
NOCA_plot_info = read_csv(here("output/NOCA_plot_info.csv"), show_col_types = FALSE) %>%
  transmute(
    plot_id = str_to_upper(plot_id),
    longitude = if_else(Longitude > 0, -Longitude, Longitude),
    latitude = Latitude,
    elevation
  ) %>%
  filter(plot_id %in% noca_ids) %>%
  distinct(plot_id, .keep_all = TRUE)

if (!setequal(NOCA_plot_info$plot_id, noca_ids)) {
  stop("NOCA plot-info IDs do not exactly match NOCA_occ.csv.")
}

wilson_join = read_csv(
  file.path(fire_dir, "0_All_Plots_Wildfire_Join.csv"), show_col_types = FALSE
) %>%
  transmute(
    plot_id = str_to_upper(str_trim(Name)),
    wildfire_year = if_else(
      !is.na(CAL_YEAR) & between(as.integer(CAL_YEAR), SURVEY_START, SURVEY_END),
      as.integer(CAL_YEAR), NA_integer_
    ),
    prescribed_burn_year = if_else(
      !is.na(Prescribed.burn.year) &
        between(as.integer(Prescribed.burn.year), SURVEY_START, SURVEY_END),
      as.integer(Prescribed.burn.year), NA_integer_
    )
  )

if (anyDuplicated(wilson_join$plot_id)) {
  stop("The supplied Wilson spatial join contains duplicate plot names.")
}

wilson_published = read_csv(
  here("data/NOCA/NOCA_fires_fromWilson.csv"), show_col_types = FALSE
) %>%
  filter(Data.Type == "Resurvey") %>%
  transmute(
    plot_id = str_to_upper(str_trim(Plot)),
    wilson_burnt = Fires == "Burned"
  )

if (nrow(wilson_published) != 369L || anyDuplicated(wilson_published$plot_id)) {
  stop("Expected 369 unique resurvey plots in NOCA_fires_fromWilson.csv.")
}

# Reconstruct the published rule independently: polygon membership plus three
# within-100 m plots whose field notes showed recent fire evidence.
wilson_reproduced = wilson_published %>%
  left_join(wilson_join, by = "plot_id") %>%
  mutate(
    spatial_join_available = plot_id %in% wilson_join$plot_id,
    natural_polygon = !is.na(wildfire_year),
    prescribed_polygon = !is.na(prescribed_burn_year),
    field_verified_100m = plot_id %in% FIELD_VERIFIED_100M,
    reproduced_burnt = natural_polygon | prescribed_polygon | field_verified_100m
  )

missing_join_ids = wilson_reproduced %>%
  filter(!spatial_join_available) %>% pull(plot_id)
if (!setequal(missing_join_ids, c("COPP6040", "THOR221", "THOR225")) ||
    any(wilson_reproduced$wilson_burnt[!wilson_reproduced$spatial_join_available])) {
  stop("Unexpected Wilson publication plots missing from the supplied spatial join.")
}
if (!identical(wilson_reproduced$wilson_burnt,
               wilson_reproduced$reproduced_burnt)) {
  bad = wilson_reproduced %>%
    filter(wilson_burnt != reproduced_burnt) %>% pull(plot_id)
  stop("Wilson fire reconstruction disagrees for: ", paste(bad, collapse = ", "))
}
if (sum(wilson_reproduced$reproduced_burnt) != 38L ||
    sum(wilson_reproduced$natural_polygon |
        wilson_reproduced$prescribed_polygon) != 35L) {
  stop("Wilson fire totals must be 35 polygon plots plus 3 field-verified plots.")
}

NOCA_plot_info_fire = NOCA_plot_info %>%
  left_join(wilson_join, by = "plot_id") %>%
  left_join(wilson_published, by = "plot_id") %>%
  mutate(
    natural_polygon = !is.na(wildfire_year),
    prescribed_polygon = !is.na(prescribed_burn_year),
    field_verified_100m = plot_id %in% FIELD_VERIFIED_100M,
    spatial_join_available = plot_id %in% wilson_join$plot_id,
    reproduced_burnt = natural_polygon | prescribed_polygon | field_verified_100m,
    burnt = coalesce(wilson_burnt, reproduced_burnt),
    fire_basis = case_when(
      !spatial_join_available & !is.na(wilson_burnt) ~
        "published_unburned_spatial_join_missing",
      natural_polygon & prescribed_polygon ~ "natural_and_prescribed_polygons",
      natural_polygon ~ "natural_fire_polygon",
      prescribed_polygon ~ "prescribed_fire_polygon",
      field_verified_100m ~ "within_100m_field_verified",
      TRUE ~ "unburned"
    ),
    assignment_source = if_else(
      is.na(wilson_burnt), "received_spatial_join", "Wilson_2024_published"
    )
  ) %>%
  select(plot_id, longitude, latitude, elevation, burnt,
         wildfire_year, prescribed_burn_year, fire_basis, assignment_source,
         spatial_join_available) %>%
  arrange(plot_id)

if (!setequal(NOCA_plot_info_fire$plot_id, noca_ids) ||
    nrow(NOCA_plot_info_fire) != 305L ||
    anyDuplicated(NOCA_plot_info_fire$plot_id)) {
  stop("NOCA fire output must contain exactly 305 unique modeled plots.")
}
if (sum(NOCA_plot_info_fire$burnt) != 32L ||
    sum(!NOCA_plot_info_fire$burnt) != 273L) {
  stop("Expected 32 burned and 273 unburned PaleoACES NOCA plots.")
}

# Universe and assignment comparison -----------------------------------------
study_exclusions = read_csv(here("output/NOCA_study_exclusions.csv"),
                            show_col_types = FALSE) %>%
  select(plot_id, study_exclusion_reason = exclusion_reason)
comparison_ids = union(noca_ids, wilson_published$plot_id)
NOCA_fire_Wilson2024_comparison = tibble(plot_id = sort(comparison_ids)) %>%
  left_join(wilson_reproduced %>%
              select(plot_id, wilson_burnt, reproduced_burnt,
                     spatial_join_available), by = "plot_id") %>%
  left_join(NOCA_plot_info_fire %>%
              select(plot_id, paleoaces_burnt = burnt), by = "plot_id") %>%
  left_join(study_exclusions, by = "plot_id") %>%
  mutate(
    universe_status = case_when(
      plot_id %in% noca_ids & plot_id %in% wilson_published$plot_id ~ "shared",
      plot_id %in% noca_ids ~ "PaleoACES_only",
      TRUE ~ "Wilson_only"
    ),
    assignment_discrepancy = case_when(
      universe_status != "shared" ~ NA,
      paleoaces_burnt != wilson_burnt ~ TRUE,
      TRUE ~ FALSE
    ),
    discrepancy_reason = case_when(
      universe_status == "PaleoACES_only" ~ "not in Wilson publication plot universe",
      universe_status == "Wilson_only" & !is.na(study_exclusion_reason) ~
        paste0("excluded from PaleoACES: ", study_exclusion_reason),
      universe_status == "Wilson_only" ~ "not retained in PaleoACES paired-plot universe",
      assignment_discrepancy ~ "fire assignment differs",
      !coalesce(spatial_join_available, TRUE) ~
        "published unburned assignment; supplied spatial-join row missing",
      TRUE ~ NA_character_
    )
  ) %>%
  select(plot_id, universe_status, paleoaces_burnt, wilson_burnt,
         reproduced_burnt, spatial_join_available, assignment_discrepancy,
         study_exclusion_reason, discrepancy_reason)

universe_counts = count(NOCA_fire_Wilson2024_comparison, universe_status)
observed_universe_counts = setNames(universe_counts$n, universe_counts$universe_status)
expected_universe_counts = c(shared = 303L, PaleoACES_only = 2L, Wilson_only = 66L)
if (!identical(observed_universe_counts[names(expected_universe_counts)],
               expected_universe_counts)) {
  stop("Unexpected PaleoACES/Wilson plot-universe comparison counts.")
}

write_csv(MORA_plot_info_fire, here("output/MORA_plot_info_fire.csv"))
write_csv(NOCA_plot_info_fire, here("output/NOCA_plot_info_fire.csv"))
write_csv(NOCA_plot_info_fire,
          here("output/NOCA_fire_assignment_audit.csv"))
write_csv(NOCA_fire_Wilson2024_comparison,
          here("output/NOCA_fire_Wilson2024_comparison.csv"))

cat("NOCA fire assignments: 305 plots; 32 burned, 273 unburned.\n")
cat("Wilson comparison: 303 shared, 2 PaleoACES-only, 66 Wilson-only; ",
    "no shared fire discrepancies.\n", sep = "")

# PaleoACES adaptation of Wilson et al. (2024) Figure 1 ----------------------
shape_dir = file.path(fire_dir, "shapefiles ")
wildfires = st_read(file.path(shape_dir, "fires/NOCA_Wildfire_History.shp"),
                    quiet = TRUE) %>%
  filter(!is.na(CAL_YEAR), between(as.integer(CAL_YEAR), SURVEY_START, SURVEY_END)) %>%
  st_make_valid()
prescribed = st_read(file.path(shape_dir, "fires/Prescribed_burn_history.shp"),
                     quiet = TRUE) %>%
  filter(!is.na(CAL_YEAR), between(as.integer(CAL_YEAR), SURVEY_START, SURVEY_END)) %>%
  st_make_valid()
treatments = st_read(file.path(shape_dir, "fires/Fire_treatment_history.shp"),
                     quiet = TRUE) %>%
  filter(!is.na(TreatYear), between(as.integer(TreatYear), SURVEY_START, SURVEY_END)) %>%
  st_make_valid()
park = st_read(file.path(shape_dir, "park/NOCA_Park_boundary.shp"), quiet = TRUE) %>%
  st_make_valid()

map_crs = "+proj=lcc +lon_0=-95 +lat_1=49 +lat_2=77 +datum=NAD83 +units=m +no_defs"
wildfires_map = st_transform(wildfires, map_crs)
prescribed_map = bind_rows(
  st_transform(prescribed, map_crs) %>% select(geometry),
  st_transform(treatments, map_crs) %>% select(geometry)
)
park_map = st_transform(park, map_crs)
noca_points_map = NOCA_plot_info_fire %>%
  mutate(fire_status = if_else(burnt, "Burned", "Unburned")) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) %>%
  st_transform(map_crs)

bb = st_bbox(park_map)
scale_x0 = unname(bb["xmax"] - 33000)
scale_y0 = unname(bb["ymax"] - 28000)

p_map = ggplot() +
  geom_sf(data = park_map, fill = "white", color = "black", linewidth = 0.45) +
  geom_sf(data = wildfires_map, aes(fill = "Natural fire"),
          color = "#A9342A", linewidth = 0.25, alpha = 0.55) +
  geom_sf(data = prescribed_map, aes(fill = "Prescribed fire"),
          color = "#E88A00", linewidth = 0.25, alpha = 0.45) +
  geom_sf(data = noca_points_map,
          aes(shape = fire_status), color = "black", size = 1.65,
          stroke = 0.75) +
  scale_fill_manual(values = c("Natural fire" = "#E99989",
                               "Prescribed fire" = "#F6C667"), name = NULL) +
  scale_shape_manual(values = c("Burned" = 4, "Unburned" = 1), name = NULL) +
  annotate("segment", x = scale_x0, xend = scale_x0 + 10000,
           y = scale_y0, yend = scale_y0, linewidth = 0.7) +
  annotate("segment", x = c(scale_x0, scale_x0 + 10000),
           xend = c(scale_x0, scale_x0 + 10000),
           y = scale_y0 - 900, yend = scale_y0 + 900, linewidth = 0.7) +
  annotate("text", x = scale_x0 + 5000, y = scale_y0 + 2400,
           label = "10 km", size = 3) +
  annotate("segment", x = unname(bb["xmax"] - 5000),
           xend = unname(bb["xmax"] - 5000),
           y = unname(bb["ymax"] - 19000),
           yend = unname(bb["ymax"] - 7000),
           arrow = arrow(length = unit(0.24, "cm")), linewidth = 0.9) +
  annotate("text", x = unname(bb["xmax"] - 5000),
           y = unname(bb["ymax"] - 4500), label = "N",
           fontface = "bold", size = 4) +
  coord_sf(crs = map_crs, datum = st_crs(4326), expand = FALSE) +
  labs(
    title = "NOCA fire history - 305 PaleoACES plots",
    caption = str_wrap(paste0(
      "Wilson et al. (2024) fire method and symbology applied to the 305 retained PaleoACES plots. ",
      "Natural and prescribed fires shown for 1983-2015; X = burned, circle = unburned."
    ), width = 105)
  ) +
  theme_bw(base_size = 10) +
  theme(
    panel.grid.major = element_line(color = "grey75", linetype = "dashed", linewidth = 0.25),
    panel.background = element_rect(fill = "white"),
    legend.position = c(0.03, 0.97),
    legend.justification = c(0, 1),
    legend.background = element_rect(fill = scales::alpha("white", 0.86), color = "black"),
    plot.title = element_text(face = "bold", size = 14),
    plot.caption = element_text(hjust = 0, size = 8)
  )

world = map_data("world")
mean_lon = mean(NOCA_plot_info_fire$longitude)
mean_lat = mean(NOCA_plot_info_fire$latitude)
p_inset = ggplot(world, aes(long, lat, group = group)) +
  geom_polygon(fill = "grey82", color = "grey35", linewidth = 0.15) +
  geom_point(data = data.frame(long = mean_lon, lat = mean_lat, group = 1),
             aes(long, lat), inherit.aes = FALSE, shape = 8, size = 2.4) +
  coord_map("ortho", orientation = c(48, -121, 0)) +
  theme_void() +
  theme(panel.border = element_rect(fill = NA, color = "black", linewidth = 0.4))

noca_fire_map = p_map + inset_element(
  p_inset, left = 0.02, bottom = 0.02, right = 0.30, top = 0.29,
  align_to = "panel"
)
if (render_figures) {
  ggsave(here("plot/test_figures/NOCA_fire_map_Wilson2024_PaleoACES.pdf"),
         noca_fire_map, width = 7.5, height = 10, bg = "white")
}
# END R/stages/01_get_fire_info.R

# ============================================================================
# BEGIN R/stages/000_MORA_climate.R
# ============================================================================
# CHELSA V2.1 for paired survey plots. Decision 2026-10-07:
# legacy climate remains 1979-1989; each modern plot uses adult year Y-5 through
# Y inclusive (six season-years). Winter Y includes December Y-1. Adult dates
# and windows come from the same table used in cleaning and tracking.
# Native chunks remain resumable and coordinate/source validated. Missing chunks
# may be restored from the validated full-record diagnostic cache before the
# offline guard; an invalid existing chunk still fails before any download.
# Historical January 1979 temperature and pre-1979 precipitation are unavailable:
# retain the established 10 complete legacy winters and 11 springs/summers.
# Full rationale and source evidence: data/SOURCES_SURVEY_YEARS.md.

library(here)
suppressMessages({library(dplyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)

CACHE = here("output/mora_climate_parts")
OUT   = here("output/MORA_climate.csv")

plot_years = read_plot_years("MORA")
PAST_START = 1979
PAST_END = 1989
WINDOWS = list(past = PAST_START:PAST_END,
  present = min(plot_years$climate_start):max(plot_years$climate_end))
# The union is fetched once; each plot is subsequently restricted to its own
# six-year window and its preceding December.
WINDOWS_FETCH = lapply(WINDOWS, function(y) c(min(y) - 1L, y))
VARS    = c("tasmin", "tasmax", "pr")
BACKFILL_DAILY_TEMP = FALSE    # 1978 daily temperature is unusable without 1978 pr
V21_MONTHLY_FIRST   = 1979

MORA_occ = read_csv(here("output/MORA_occ.csv"), show_col_types = FALSE)
pts = read_csv(here("output/MORA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = longitude, lat = latitude) %>%
  filter(plot_id %in% MORA_occ$plot_id, !is.na(lon), !is.na(lat)) %>%
  distinct(plot_id, .keep_all = TRUE) %>%
  select(id = plot_id, lon, lat)
stopifnot(nrow(pts) > 0)
cat("MORA: ", nrow(pts), " plots\n", sep = "")

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)

# --- what to fetch, and from which product -----------------------------------
todo = do.call(rbind, lapply(names(WINDOWS), function(p)
  expand.grid(period = p, var = VARS, year = WINDOWS_FETCH[[p]], stringsAsFactors = FALSE)))
todo$route = ifelse(todo$year >= V21_MONTHLY_FIRST, "monthly",
                    ifelse(todo$var == "pr", "unavailable", "daily"))
todo = todo[todo$route != "unavailable", ]          # no V2.1 pr before 1979
if (!BACKFILL_DAILY_TEMP) todo = todo[todo$route != "daily", ]
todo$key  = sprintf("%s_%s_%d", todo$period, todo$var, todo$year)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))
todo$expected_source = ifelse(todo$route == "monthly", "v21_monthly",
                              "v21_daily_agg")
reuse_survey_diagnostic_cache(todo, pts)
todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)

require_offline_cache(todo$path, todo$cache_valid, "MORA climate")
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))
cat(sum(!todo$cache_valid), " of ", nrow(todo), " chunks to fetch (",
    sum(todo$route == "daily"), " are DAILY - ~365 files each)\n", sep = "")

# A transient failure comes back as ZERO ROWS, not an error (the fetchers swallow
# both). Caching that would mark the chunk done forever. Only cache COMPLETE chunks.
# For the daily route a few missing days are tolerable, so the test is on months
# built from >= 28 days rather than on an exact file count.
EXPECT = 12 * nrow(pts)
incomplete = character(0)
short      = character(0)   # chunks the SERVER is missing months for, accepted and recorded

for (i in seq_len(nrow(todo))) {
  if (todo$cache_valid[i]) next
  if (file.exists(todo$path[i])) {
    message("invalidating stale climate chunk: ", basename(todo$path[i]))
    file.remove(todo$path[i])
  }
  yr = todo$year[i]; v = todo$var[i]; ok = TRUE

  if (todo$route[i] == "monthly") {
    x = get_chelsa_monthly(pts, vars = v, years = yr, months = 1:12,
                           to_celsius = TRUE, id_col = "id", verbose = FALSE)
    ok = nrow(x) == EXPECT
  } else {
    # daily -> monthly mean. Temperature only, so a mean is always right.
    d = get_chelsa(pts, vars = v, source = "present",
                   start = sprintf("%d-01-01", yr), end = sprintf("%d-12-31", yr),
                   to_celsius = TRUE, id_col = "id", verbose = FALSE)
    if (!nrow(d)) { x = d; ok = FALSE } else {
      x = d %>% group_by(id, lon, lat, variable, year, month) %>%
        summarise(value = mean(value, na.rm = TRUE), n_days = n(), .groups = "drop") %>%
        mutate(source = "v21_daily_agg")
      ok = nrow(x) == EXPECT && all(x$n_days >= 28)
    }
  }

  # Short chunk: retry once. A transient failure usually clears; a genuine gap in
  # the product does not. CHELSA really is missing tasmin and tasmax for JANUARY
  # 1979 (pr is present) - verified by HTTP HEAD - so this must not loop forever.
  if (!ok && nrow(x) > 0) {
    if (todo$route[i] == "monthly") {
      x2 = get_chelsa_monthly(pts, vars = v, years = yr, months = 1:12,
                              to_celsius = TRUE, id_col = "id", verbose = FALSE)
      if (nrow(x2) > nrow(x)) { x = x2; ok = nrow(x) == EXPECT }
    }
    if (!ok) {
      short = c(short, sprintf("%s (%d/%d months)", todo$key[i],
                               nrow(x) / nrow(pts), 12))
      ok = TRUE     # accept and record: the data is genuinely not there
    }
  }
  if (!ok) {        # zero rows = transient failure. Do NOT cache; retry next run.
    incomplete = c(incomplete, todo$key[i])
    cat(sprintf("  [%2d/%2d] %-22s EMPTY - not cached, will retry\n",
                i, nrow(todo), todo$key[i]))
    next
  }
  x$period = todo$period[i]
  tmp = paste0(todo$path[i], ".tmp"); write_csv(x, tmp); file.rename(tmp, todo$path[i])
  cat(sprintf("  [%2d/%2d] %-22s %-8s %5d rows\n", i, nrow(todo), todo$key[i],
              todo$route[i], nrow(x)))
}
if (length(incomplete))
  cat("\n", length(incomplete), " chunk(s) came back EMPTY and were NOT cached.\n",
      "Re-run to retry: ", paste(incomplete, collapse = ", "), "\n", sep = "")
if (length(short))
  cat("\n⚠ ", length(short), " chunk(s) are MISSING MONTHS on the CHELSA server and were\n",
      "  accepted as-is (re-running will not fix them): ",
      paste(short, collapse = ", "), "\n",
      "  CHELSA has no tasmin/tasmax for JANUARY 1979 - so any winter variable for\n",
      "  1979 is built from 2 months, not 3; the shared seasonal derivation records this.\n", sep = "")

todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)
got = todo$path[todo$cache_valid]
if (length(got) < nrow(todo))
  stop(nrow(todo) - length(got), " chunk(s) missing - re-run to finish.")

clim = bind_rows(lapply(got, read_csv, show_col_types = FALSE, progress = FALSE)) %>%
  mutate(site = "MORA", era = "anthropocene") %>%
  select(site, era, period, plot_id = id, lon, lat, variable, year, month, value)
stopifnot(!any(is.na(clim$value)))

# Preserve the historical all-variable intersection; modern coverage is strict
# for every plot, including December preceding that plot's first winter.
clim = restrict_modern_months(clim, plot_years)
avail = clim %>% distinct(plot_id, period, year, month, variable) %>%
  count(plot_id, period, year, month, name = "n_var")
keep = avail %>% filter(n_var == length(VARS)) %>% select(plot_id, period, year, month)
clim = clim %>% semi_join(keep, by = c("plot_id", "period", "year", "month"))
clim = restrict_modern_months(clim, plot_years)

# --- coverage actually achieved, per period x variable -----------------------
coverage = clim %>% group_by(period, variable) %>%
  summarise(n_years = n_distinct(year), years = paste(range(year), collapse = "-"),
            n = n(), mean = mean(value), .groups = "drop")
cat("\n--- coverage achieved ---\n"); print(as.data.frame(coverage), digits = 4)

pr_past = coverage %>% filter(period == "past", variable == "pr")
if (nrow(pr_past) && pr_past$n_years < length(WINDOWS$past))
  cat("\n⚠ MORA legacy PRECIPITATION covers ", pr_past$n_years, " of ",
      length(WINDOWS$past), " window years (", pr_past$years,
      "). No V2.1 precipitation exists before 1979; see data/SOURCES_SURVEY_YEARS.md.\n",
      sep = "")

# If the historical daily option is restored, be explicit that alignment removes
# it: precipitation has no corresponding pre-1979 month, so the final output is
# still entirely V2.1 monthly and no cross-route splice occurs.
if (BACKFILL_DAILY_TEMP && any(todo$route == "daily")) {
  cat("\nNOTE: daily lead-in temperature was requested, but all-variable alignment\n",
      "removes it because matching precipitation is unavailable.\n", sep = "")
}

write_csv(clim, OUT)
saveRDS(list(
  signature = object_fingerprint(list(points = pts, windows = WINDOWS,
                                      plot_years = plot_years,
                                      variables = VARS,
                                      backfill_daily_temp = BACKFILL_DAILY_TEMP,
                                      source_routes = todo[c("period", "var", "year", "route")],
                                      client = "CHELSA_V2.1")),
  points = pts, windows = WINDOWS, plot_years = plot_years, variables = VARS,
  source_routes = todo[c("period", "var", "year", "route")]
), file.path(CACHE, "_cache_fingerprint.rds"))
cat("\nwritten: ", OUT, "\n", sep = "")
# END R/stages/000_MORA_climate.R

# ============================================================================
# BEGIN R/stages/000_NOCA_climate.R
# ============================================================================
# CHELSA V2.1 for paired survey plots. Decision 2026-10-07:
# legacy climate remains 1979-1989; each modern plot uses adult year Y-5 through
# Y inclusive (six season-years). Winter Y includes December Y-1. Adult dates
# and windows come from the same table used in cleaning and tracking.
# Native chunks remain resumable and coordinate/source validated. Missing chunks
# may be restored from the validated full-record diagnostic cache before the
# offline guard; an invalid existing chunk still fails before any download.
# Historical January 1979 temperature and pre-1979 precipitation are unavailable:
# retain the established 10 complete legacy winters and 11 springs/summers.
# Full rationale and source evidence: data/SOURCES_SURVEY_YEARS.md.

library(here)
suppressMessages({library(dplyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)          # vendored; provides .chelsa_prep_coords()
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)

CACHE = here("output/noca_climate_parts")
OUT   = here("output/NOCA_climate.csv")

plot_years = read_plot_years("NOCA")
PAST_START = 1979
PAST_END = 1989
WINDOWS = list(past = PAST_START:PAST_END,
  present = min(plot_years$climate_start):max(plot_years$climate_end))
# The union is fetched once; each plot is subsequently restricted to its own
# six-year window and its preceding December.
WINDOWS_FETCH = lapply(WINDOWS, function(y) c(min(y) - 1L, y))

VARS  = c("tasmin", "tasmax", "pr")
BACKFILL_DAILY_TEMP = FALSE  # 1978 daily temperature is unusable without 1978 pr
V21_MONTHLY_FIRST   = 1979

cat("windows: ", paste(sapply(names(WINDOWS), function(p)
  sprintf("%s %d-%d", p, min(WINDOWS[[p]]), max(WINDOWS[[p]]))), collapse = " | "), "\n", sep = "")

NOCA_occ = read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE)
pts = read_csv(here("output/NOCA_plot_info.csv"), show_col_types = FALSE) %>%
  rename(lon = Longitude, lat = Latitude) %>%
  filter(plot_id %in% NOCA_occ$plot_id, !is.na(lon), !is.na(lat)) %>%
  distinct(plot_id, .keep_all = TRUE) %>%
  select(id = plot_id, lon, lat)
stopifnot(nrow(pts) > 0)
cat("NOCA: ", nrow(pts), " plots\n", sep = "")

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)

todo = do.call(rbind, lapply(names(WINDOWS), function(p)
  expand.grid(period = p, var = VARS, year = WINDOWS_FETCH[[p]], stringsAsFactors = FALSE)))
# route: monthly where V2.1 monthly exists; daily backfill for pre-1979 temperature;
# pre-1979 precipitation does not exist in V2.1 at all.
todo$route = ifelse(todo$year >= V21_MONTHLY_FIRST, "monthly",
                    ifelse(todo$var == "pr", "unavailable", "daily"))
dropped = todo[todo$route == "unavailable", ]
todo = todo[todo$route != "unavailable", ]
if (!BACKFILL_DAILY_TEMP) todo = todo[todo$route != "daily", ]
todo$key  = sprintf("%s_%s_%d", todo$period, todo$var, todo$year)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))
todo$expected_source = ifelse(todo$route == "monthly", "v21_monthly",
                              "v21_daily_agg")
reuse_survey_diagnostic_cache(todo, pts)
todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts, allow_point_superset = TRUE),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)
require_offline_cache(todo$path, todo$cache_valid, "NOCA climate")
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))
if (nrow(dropped))
  cat("no V2.1 data at all for: ",
      paste(sprintf("%s %s %d", dropped$period, dropped$var, dropped$year),
            collapse = ", "), "\n", sep = "")
cat(sum(!todo$cache_valid), " of ", nrow(todo), " chunks to fetch (",
    sum(todo$route == "daily"), " are DAILY - ~365 files each)\n", sep = "")

# A transient failure comes back as ZERO ROWS, not an error (the fetchers swallow
# both). Caching that would mark the chunk done forever. Only cache COMPLETE chunks.
EXPECT = 12 * nrow(pts)
incomplete = character(0)

short = character(0)   # months the SERVER is missing - accepted and recorded

for (i in seq_len(nrow(todo))) {
  if (todo$cache_valid[i]) next
  if (file.exists(todo$path[i])) {
    message("invalidating stale climate chunk: ", basename(todo$path[i]))
    file.remove(todo$path[i])
  }
  yr = todo$year[i]; v = todo$var[i]; ok = TRUE

  if (todo$route[i] == "monthly") {
    x = get_chelsa_monthly(pts, vars = v, years = yr, months = 1:12,
                           to_celsius = TRUE, id_col = "id", verbose = FALSE)
    ok = nrow(x) == EXPECT
  } else {
    d = get_chelsa(pts, vars = v, source = "present",
                   start = sprintf("%d-01-01", yr), end = sprintf("%d-12-31", yr),
                   to_celsius = TRUE, id_col = "id", verbose = FALSE)
    if (!nrow(d)) { x = d; ok = FALSE } else {
      x = d %>% group_by(id, lon, lat, variable, year, month) %>%
        summarise(value = mean(value, na.rm = TRUE), n_days = n(), .groups = "drop") %>%
        mutate(source = "v21_daily_agg")
      ok = nrow(x) == EXPECT && all(x$n_days >= 28)
    }
  }

  # short but non-empty = a genuine server gap (e.g. CHELSA has no tasmin/tasmax for
  # January 1979). Retry once, then accept and record rather than looping forever.
  if (!ok && nrow(x) > 0) {
    if (todo$route[i] == "monthly") {
      x2 = get_chelsa_monthly(pts, vars = v, years = yr, months = 1:12,
                              to_celsius = TRUE, id_col = "id", verbose = FALSE)
      if (nrow(x2) > nrow(x)) { x = x2; ok = nrow(x) == EXPECT }
    }
    if (!ok) {
      short = c(short, sprintf("%s (%d/12 months)", todo$key[i], nrow(x) / nrow(pts)))
      ok = TRUE
    }
  }
  if (!ok) {   # empty = transient failure. Do NOT cache; retry next run.
    incomplete = c(incomplete, todo$key[i])
    cat(sprintf("  [%2d/%2d] %-22s EMPTY - not cached, will retry\n",
                i, nrow(todo), todo$key[i]))
    next
  }
  x$period = todo$period[i]
  tmp = paste0(todo$path[i], ".tmp"); write_csv(x, tmp); file.rename(tmp, todo$path[i])
  cat(sprintf("  [%2d/%2d] %-22s %-8s %5d rows\n", i, nrow(todo), todo$key[i],
              todo$route[i], nrow(x)))
}
if (length(incomplete))
  cat("\n", length(incomplete), " chunk(s) came back EMPTY, NOT cached. Re-run: ",
      paste(incomplete, collapse = ", "), "\n", sep = "")
if (length(short))
  cat("\n⚠ ", length(short), " chunk(s) missing months on the server, accepted as-is: ",
      paste(short, collapse = ", "), "\n", sep = "")

todo$cache_valid = mapply(climate_cache_valid, todo$path,
                          MoreArgs = list(points = pts, allow_point_superset = TRUE),
                          variable = todo$var, year = todo$year,
                          expected_source = todo$expected_source)
got = todo$path[todo$cache_valid]
if (length(got) < nrow(todo))
  stop(nrow(todo) - length(got), " chunk(s) missing - re-run to finish.")

clim = bind_rows(lapply(got, read_csv, show_col_types = FALSE, progress = FALSE)) %>%
  filter(id %in% pts$id) %>%
  mutate(site = "NOCA", era = "anthropocene") %>%
  select(site, era, period, plot_id = id, lon, lat, variable, year, month, value)

stopifnot(!any(is.na(clim$value)))

# Preserve the historical all-variable intersection; modern coverage is strict
# for every plot, including December preceding that plot's first winter.
clim = restrict_modern_months(clim, plot_years)
avail = clim %>% distinct(plot_id, period, year, month, variable) %>%
  count(plot_id, period, year, month, name = "n_var")
keep = avail %>% filter(n_var == length(VARS)) %>% select(plot_id, period, year, month)
clim = clim %>% semi_join(keep, by = c("plot_id", "period", "year", "month"))
clim = restrict_modern_months(clim, plot_years)

cat("\nrows: ", nrow(clim), "  plots: ", n_distinct(clim$plot_id), "\n", sep = "")
coverage = clim %>% group_by(period, variable) %>%
  summarise(n_years = n_distinct(year),
            n_months = n_distinct(paste(year, month)),
            years = paste(range(year), collapse = "-"),
            n = n(), mean = mean(value), .groups = "drop")
cat("\n--- coverage achieved (past 1979-1989; present plot-specific six-year windows; ",
    "lead-in December retained when available) ---\n", sep = "")
print(as.data.frame(coverage), digits = 4)
month_balance = coverage %>% count(period, n_months, name = "n_variables")
if (any(month_balance$n_variables != length(VARS)))
  stop("Climate variables do not cover identical months within a NOCA period.")

write_csv(clim, OUT)
saveRDS(list(
  signature = object_fingerprint(list(points = pts, windows = WINDOWS,
                                      plot_years = plot_years,
                                      variables = VARS,
                                      backfill_daily_temp = BACKFILL_DAILY_TEMP,
                                      source_routes = todo[c("period", "var", "year", "route")],
                                      client = "CHELSA_V2.1")),
  points = pts, windows = WINDOWS, plot_years = plot_years, variables = VARS,
  source_routes = todo[c("period", "var", "year", "route")]
), file.path(CACHE, "_cache_fingerprint.rds"))
cat("\nwritten: ", OUT, "\n", sep = "")
# END R/stages/000_NOCA_climate.R

# ============================================================================
# BEGIN R/stages/000_PALEO_a_agedepth.R
# ============================================================================
# OPTIONAL WORKFLOW STAGE: runs only with --age-models.
# Do not run this review copy to inspect stored chronology figures.
# =============================================================================
# 000_PALEO_a_agedepth.R - age-depth models for all four cores
# =============================================================================
# Age-depth part of the former monolithic paleo cleaner. The active split stages
# R/stages/000_PALEO_b_vegetation.R through R/stages/000_PALEO_e_climate.R read its ages.
#
# SLOW: four primary MCMC runs plus the configured +-10-year 210Pb sensitivity.
# Re-run when a control point, Bacon setting, seed, or chronology dependency changes.
#
# PROVENANCE OF EVERY NUMBER: Cores/CONTROL_POINTS.md (master table + glossary),
# with the detail in Cores/SOURCES_MORA.md and data/NOCA/NOCA_paleo/SOURCES.md.
#
# rbacon vignette: https://cran.r-project.org/web/packages/rbacon/vignettes/rbacon.html
# install.packages(c("rbacon","readr","tidyverse","here"))
# =============================================================================

library(rbacon)
library(readr)
library(tidyverse)
library(here)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

# CORE_ARGS, slumps and bacon_draws(). Pure definitions - sourcing it reads and
# writes nothing, which is why it is safe here, before any core has been run.
source(here("R/helpers/bacon_settings.R"))
source(here("R/helpers/config.R"))

# ------------------------
# Paths
# ------------------------
coredir <- file.path(here(), "Cores")
dir.create(coredir, showWarnings = FALSE, recursive = TRUE)

# -----------------------------------------------------------------------------
# CLEAN SLATE - run before every Bacon call
# -----------------------------------------------------------------------------
# rbacon caches aggressively, and three separate mechanisms can silently make a
# "re-run" reuse the OLD model:
#
#   1. An existing <core>_<K>.out makes Bacon offer to LOAD rather than re-run.
#      With ask = FALSE that choice is made for you, and the only hint is the
#      warning "The file with the dates seems newer than the run you are
#      loading ... please run Bacon.cleanup()".
#   2. `info` persists in .GlobalEnv between calls within one R session, so a
#      later core can inherit an earlier core's settings.
#   3. Stale <core>_<K>_ages.txt from a DIFFERENT K survives a re-run at a new
#      thick, and read_bacon_ages() picks by modification time - so downstream
#      can silently read the wrong model. (This bit us once already, with a
#      leftover PantherPotholes_43_ages.txt beside the real _169 one.)
#
# reset_core() removes everything Bacon generated for a core, keeping only the
# input <core>.csv, and clears `info`. remember = FALSE on every call stops
# rbacon writing settings back for reuse.
reset_core <- function(core, coredir = file.path(here(), "Cores")) {
  d <- file.path(coredir, core)
  if (dir.exists(d)) {
    keep <- paste0(core, ".csv")
    gone <- setdiff(list.files(d), keep)
    if (length(gone)) unlink(file.path(d, gone), recursive = TRUE)
  }
  if (exists("info", envir = .GlobalEnv)) rm("info", envir = .GlobalEnv)
  invisible(NULL)
}

# Every Bacon call in this script goes through here, so no run can inherit
# state from a previous one. Args are passed straight to Bacon().
run_bacon <- function(core, ...) {
  reset_core(core, coredir)
  Bacon(core = core, coredir = coredir,
        suggest = FALSE, ask = FALSE, remember = FALSE, seed = 42, ...)
  # confirm exactly one age file was produced, and that it is new
  f <- Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))
  stopifnot(length(f) == 1)
  cat("  -> ", basename(f), "\n", sep = "")
  invisible(f)
}

# ------------------------
# Helpers
# ------------------------
# read_bacon_ages() lives in R/helpers/paleo_ages.R, the shared downstream reader that
# consumes the ages. Kept there rather than duplicated here so the two copies
# cannot drift apart.

# bacon_draws() - posterior age draws for a finished run - now lives in
# R/helpers/bacon_settings.R, sourced above, because R/helpers/paleo_runs.R needs it too. It
# could not move into R/helpers/paleo_ages.R: that file reads Cores/*_ages.txt at source
# time, and THIS script is what creates them.

write_core_files <- function(core, dates_tbl, ties_tbl) {
  # Enforce Bacon-documented order and headers:
  # Dates CSV MUST be: ID,Age,Error,Depth,cc  (in that order)
  # Ties CSV.TI MUST be: Depth,Age,Error
  dir.create(file.path(coredir, core), showWarnings = FALSE, recursive = TRUE)
  
  dates_tbl <- dates_tbl %>%
    transmute(
      ID    = as.character(ID),
      Age   = as.numeric(Age),
      Error = as.numeric(Error),
      Depth = as.numeric(Depth),
      cc    = as.integer(cc)
    ) %>%
    arrange(Depth)
  stopifnot(all(diff(dates_tbl$Depth) > 0))
  write_csv(dates_tbl, file.path(coredir, core, paste0(core, ".csv")))
}

# -------------------------
# 1) JAY BATH
# -------------------------
# Radiocarbon (uncalibrated); ORDER: ID,Age,Error,Depth,cc
jay_dates <- tribble(
  ~ID,          ~Age, ~Error, ~Depth,  ~cc,
  "QL-1729",     1320,   30,     39.5,   1,
  "QL-1730",     2920,   60,     70.0,   1,
  "Beta-6332",   3740,   80,    124.5,   1,
  "QL-1704",     6050,  110,    152.25,  1
)

# NOTE the column name must be ~ID, not ~id. With ~id, bind_rows() below creates
# a SECOND column and write_core_files() (which reads ID) writes NA for every
# tephra and surface tie into the Bacon .csv.
#
# Tephra_Y and Tephra_Y_alt are the TOP and BOTTOM of one instantaneous deposit,
# not two alternative picks - see the slump note at the Bacon call below.
jay_ties <- tribble(
  ~ID,            ~Depth, ~Age, ~Error, ~cc,
  "Surface",         0,    -31.5,   10,    0,   # see SURFACE note at the Bacon call
  "Tephra_W",       22,    470,    10,    0,
  "Tephra_C",       62,   2250,   100,    0,
  "Tephra_Y",       87,   3650,   100,    0,
  "Tephra_Y_alt",  105,   3650,   100,    0,
  "Tephra_F",      142,   5740,   100,    0
)

jay_dates = bind_rows(jay_dates, jay_ties)

write_core_files("JayBath", jay_dates)

# -------------------------
# 2) LOG WALLOW
# -------------------------
lw_dates <- tribble(
  ~ID,        ~Age, ~Error, ~Depth, ~cc,
  "QL-1726",   1650,   80,     29.0,  1,
  "QL-1727",   4900,   80,    117.0,  1,
  "QL-1728",   5980,   60,    140.0,  1
)

lw_ties <- tribble(
  ~ID,           ~Depth, ~Age, ~Error, ~cc,
  "Surface",       0,      -31.5,   10,    0,  # see SURFACE note at the Bacon call
  "Tephra_W",     22,      470,    10,    0, # Wn (AD 1480) dendro # Taken from the Yamaguchi 1983
  "Tephra_Y",     40,     3650,   100,    0,  # Y (broad)
  "Tephra_Y_alt", 98,     3650,   100,    0, # Y (second pick; same age)
  "Tephra_F",     116,    5740,   100,    0 # F (broad)
)

lw_dates = bind_rows(lw_dates, lw_ties)

write_core_files("LogWallow", lw_dates)

# -------------------------
# 3) REFLECTION POND
# -------------------------
# Radiocarbon (uncalibrated); ORDER: ID,Age,Error,Depth,cc

rp_dates <- tribble(
  ~ID,            ~Depth, ~Age, ~Error, ~cc,
  "Surface",         0,    -31.5,   10,    0,   # see SURFACE note at the Bacon call
  "Tephra_W",       10,    470,    10,    0,
  "Tephra_C",       26,   2250,   100,    0,
  "Tephra_Y",       45,   3650,    100,   0,
  "Tephra_Y_alt",   64,   3650,    100,   0,
  "Tephra_F",       82,   5740,    100,   0,
  # Paradise lahar - the mudflow all three ponds sit ON, so a MAXIMUM age for the
  # basal sediment. Crandell 1971 (USGS Prof. Paper 677) p.63: "The Paradise lahar
  # is between 5,800 and 6,600 years old" -> midpoint 6200, half-range 400.
  #
  # TWO CONVERSIONS, both easy to get wrong:
  # 1. Crandell's ages are ALREADY CALIBRATED, so cc = 0 is correct. p.11: ages
  #    under 6,000 yr "have been corrected ... take into account past variations in
  #    atmospheric C14", and his Table 4 calls them "true dates". Re-calibrating
  #    them (which would give ~6845 cal BP) DOUBLE-COUNTS the correction.
  # 2. He reports "Years ago in 1970", NOT cal BP. Verified on his own row: W-1120,
  #    290 14C -> "1525 A.D." -> "450 years ago in 1970" (1970-1525 = 445). So
  #    cal BP = years_ago_in_1970 - 20, giving 5780-6580 cal BP -> 6180 +- 400.
  #
  # Was 6000 +- 600 (Dunwiddie p.59's rounded "6000-yr-old Paradise lahar"). That
  # spans 5400-6600 and so covered the truth, but sat ~180 yr low with a wider error
  # than the source needs. This matters most for ReflectionPond, which has NO
  # radiocarbon at all - it is dated entirely by tephra plus this lahar.
  "Basal_lahar",    90,   6180,    400,   0
)

rp_dates = bind_rows(rp_dates)

write_core_files("ReflectionPond", rp_dates)


# -------------------------
# 3b) PANTHER POTHOLES (NOCA)
# -------------------------
# FULL PROVENANCE: data/NOCA/NOCA_paleo/SOURCES.md. Summary of every number below.
#
# The site already has a published Bayesian chronology - "Gavin 2021" (Daniel G.
# Gavin, prepared 2021-11-09), which IS a Bacon run. Its complete settings string
# and all 15 control points are stored by Neotoma and checked in here:
#   data/NOCA/NOCA_paleo/neotoma_chronology_52207_gavin2021.json
#   data/NOCA/NOCA_paleo/neotoma_chroncontrols_52207_gavin2021.csv
# retrieved 2026-08-07 from
#   https://api.neotomadb.org/v2.0/data/downloads/52207
#
# WHY RE-RUN A MODEL THAT ALREADY EXISTS. Not to re-estimate it - Gavin's
# chronology is sound. Neotoma publishes only three quantiles per level
# (older/median/younger), and every metric in this project is measured over an
# INTERVAL (delta climate / vegetation / offset from t1 to t2, with dt in the
# denominator). Propagating age uncertainty through those needs whole coherent
# chronologies, which is also what RRatepol::estimate_roc(age_uncertainty=) takes:
# "one row per age sequence drawn from a posterior age-depth model". Quantiles
# cannot be turned back into draws - tested on JayBath, where we have both:
# sampling each level independently from its own quantiles yields 0.000 monotone
# chronologies (all 4000 contain an age reversal) vs 1.000 for the true posterior,
# and collapses the down-core error correlation that keeps dt stable (r = 0.741
# true, 0.003 rebuilt). Re-running regenerates that ensemble.
#
# !! DO NOT USE THE DEPTHS PRINTED IN PRICHARD'S TABLES 1a/1b !!
# Neotoma sitenotes: "See geochronology notes about errors in sample depths and
# tephra depths in publication and Neotoma, corrected November 2021." Prichard's
# own Results text agrees with the corrections and contradicts their own Table 1b
# ("the basal date ... at 864 cm ... the most recent date ... at 214 cm" vs 972
# and 219 in the table). Shifts: -5, -15, -15, -25, -78, -108 cm. Two traps this
# springs if ignored: the model then looks like it rejects Beta-169208 by ~880 yr
# (it fits to -148 at the right depth), and Beta-169624 appears to sit inside the
# MSH Y tephra (it is 7 cm above it at 389 cm).
pp_dates <- tribble(
  ~ID,          ~Age,  ~Error, ~Depth, ~cc,
  # --- Core top. Coring year 1999, derived two ways (SOURCES.md): Gavin's own
  # core-top control is -49 cal BP = 1999 CE, and a 1999 coring year reproduces
  # all five 210Pb controls to RMSE 1.0 yr.
  "CoreTop",      -49,   1,       0.5,  0,
  # --- 210Pb. Prichard Table 1c, CRS model (Flett Research Ltd., Winnipeg).
  # Table 1c is in YEARS BEFORE CORING; cal BP = yr_before_coring - 49.
  # NOTE the errors are Prichard's DPM/g ACTIVITY errors, which Gavin carried into
  # the age-error column (3.47/1.15/0.72/0.74/0.77 in both). A DPM/g s.e. is not a
  # year. Kept here to reproduce Gavin faithfully; see the pb210_err variant below.
  "Pb210_7",    -36.7,   3.47,    7,    0,   # T1c 12.3 yr before coring
  "Pb210_14",      -9,   1.15,   14,    0,   # T1c 40
  "Pb210_21",      12,   0.72,   21,    0,   # T1c 61
  "Pb210_28",      21,   0.74,   28,    0,   # T1c 70
  "Pb210_35",      36,   0.77,   35,    0,   # T1c 85
  # --- AMS 14C, UNCALIBRATED (cc = 1, Bacon calibrates with IntCal20).
  # Ages/errors are Prichard Table 1b verbatim (Beta Analytic); depths corrected.
  "Beta-172005", 1950,  50,     214,    1,   # conifer seed   (Table 1b says 219)
  "Beta-169623", 3260,  40,     363,    1,   # seed                        (378)
  "Beta-169624", 3520,  40,     389,    1,   # pollen cone                 (404)
  "Beta-169207", 4500,  40,     479,    1,   # pollen cone                 (504)
  "Beta-169208", 7330,  40,     678,    1,   # seed                        (756)
  "Beta-169625", 9370,  40,     864,    1,   # Pinus contorta needles      (972)
  # --- Tephra, calendar ages (cc = 0). Layers identified by glass chemistry
  # (F. Foit, WSU); similarity coefficients 0.99 / 0.97 / 0.99. Ages are Gavin's
  # literature values, NOT Prichard's core-derived brackets.
  # MSH P  : 2620 +- 70. Prichard's 2590-3184 is the calibration of the broad
  #          2500-3000 14C literature range for set P; its midpoint (2887) is too old.
  # MSH Y  : 3660 +- 65. SAME ERUPTION as MORA's Tephra_Y, entered above as
  #          3650 +- 100. The two sites agree to 10 yr independently.
  # Mazama : 7633 +- 25. Matches Egan et al. 2015 (7584-7682, 2sd) and Zdanowicz
  #          et al. 1999 (7627 +- 150); Prichard's 7610-7690 agrees too.
  "Tephra_MSH_P",  2620, 70,   305.5,   0,   # 303-308,  5 cm
  "Tephra_MSH_Y",  3660, 65,   401.0,   0,   # 396-406, 10 cm
  "Tephra_Mazama", 7633, 25,   629.0,   0    # 623-635, 12 cm (Table 1a said 623-639)
)

# Verify the hand-entered table against the checked-in Neotoma extract, so a typo
# in the numbers above cannot pass silently.
pp_neotoma = read_csv(here("data/NOCA/NOCA_paleo/neotoma_chroncontrols_52207_gavin2021.csv"),
                      show_col_types = FALSE) %>% arrange(depth)
stopifnot(
  nrow(pp_dates) == nrow(pp_neotoma),
  all.equal(sort(pp_dates$Depth), pp_neotoma$depth),
  all.equal((pp_dates %>% arrange(Depth))$Age,   pp_neotoma$age),
  all.equal((pp_dates %>% arrange(Depth))$Error, pp_neotoma$error)
)

write_core_files("PantherPotholes", pp_dates)

# -------------------------
# 4) RUN BACON: JayBath & LogWallow & ReflectionPond
# -------------------------
# SLUMP. The Y tephra is entered at two depths per core, both 3650 cal BP. Those
# are the TOP and BOTTOM of one instantaneously deposited unit, not alternative
# picks. Dunwiddie 1986 (Ecology 67:58-68):
#   p.62  "The Y tephra is overlain by 43 cm of redeposited Y tephra"
#   Fig.4 "Redeposited Y tephra (86-43 cm) is omitted"
#   p.59  layer Yn is "the thickest of the set Y tephra, with deposits of 15 cm
#         common on the south side of the mountain"
# so JayBath 87-105 (18 cm) and ReflectionPond 45-64 (19 cm) are the airfall,
# and LogWallow 40-98 (58 cm) is ~15 cm airfall plus 43 cm of redeposited Y.
# `slump` excises these before age-modelling and re-inserts them afterwards at
# zero elapsed time. Without it Bacon tried to accumulate 58 cm of LogWallow in
# no time, blew its 95% CI out to a median of 1513 yr, and REJECTED the 40 cm
# date (model 2180 vs stated 3650). With it: CI median 397 yr and every date in
# every core inside the 95% envelope.
# SURFACE = -31.5 cal BP, NOT 0. The core top is the sediment surface at the moment
# of coring, and cal BP is measured from A.D. 1950 - so entering 0 asserts the tops
# are A.D. 1950. **Billur confirmed with Dunwiddie that the lakes were cored in
# 1981-1982**, so the tops are 1950 - 1981.5 = -31.5 cal BP. Neither Dunwiddie 1986
# nor 1987 states the coring year (1986 Methods: "Cores were collected with a
# modified 5 cm diameter Livingstone piston corer from a floating platform" - no
# date); the published bound is only "manuscript received 17 April 1984".
#
# Error 10, not 5. The coring year is now known to ~1 yr, so the residual
# uncertainty is whether the sediment-water interface survived extrusion. At these
# cores' accumulation rates (~23-50 yr/cm) even 0.5 cm of lost floc is ~15-25 yr,
# so +-10 is the honest floor. It spans A.D. 1972-1992.
#
# Effect of the fix, measured: core tops move to -32/-33/-32 as intended, and the
# median absolute change BELOW 40 cm is 3/5/1 yr - i.e. nothing. This matters for
# consistency with NOCA (whose core top was derived as -49 cal BP = A.D. 1999),
# not because it moves any result.
# `slumps` and CORE_ARGS - the single definition of every core's Bacon settings,
# used to run the models, to redraw them in section 5, and by R/helpers/paleo_runs.R to
# read their posteriors - are defined in R/helpers/bacon_settings.R, sourced at the top.

# d.max. JayBath has a macrofossil sample at 153 cm but its deepest date sits at
# 152.25, so by default Bacon models only to 152 and the basal (oldest) sample
# joins to no age - it became "JayBath_NA_BP". Extrapolating 1 cm (~40 yr at this
# core's accumulation rate) recovers it. The other two cores need nothing:
# LogWallow samples reach 140 and ReflectionPond 90, both within their models.
d_max = list(JayBath = 153, LogWallow = NULL, ReflectionPond = NULL)

# acc.mean = 50 MUST be given explicitly. It was previously supplied by accepting
# Bacon's interactive suggestion; with suggest = FALSE that prompt never appears
# and Bacon silently falls back to its default of 20 yr/cm. That is far too fast
# for these cores (ReflectionPond runs ~90 yr/cm below the slump), and the model
# then ignores the F tephra and basal lahar entirely.
# suggest/ask = FALSE so the script can be sourced without prompting.
for (core in names(slumps)) {
  cat("\n=== ", core, " ===\n", sep = "")
  do.call(run_bacon, c(list(core = core, plot.pdf = TRUE, verbose = TRUE),
                       CORE_ARGS[[core]]))
}

# -------------------------
# 4b) RUN BACON: PantherPotholes (NOCA)
# -------------------------
# Every setting below is Gavin's, read off the settings string Neotoma stores with
# the chronology (data/NOCA/NOCA_paleo/neotoma_chronology_52207_gavin2021.json):
#
#   0 #d.min | 870 #d.max | 0.5 #d.by | 303308396406623635 #slump
#   10 #acc.mean | 1.5 #acc.shape | 0.7 #mem.mean | 10 #mem.strength
#   1 #cc | IntCal20 #cc1 | 0 #normal | 15 #t.a | 16 #t.b | 0.95 #prob
#
# acc.mean = 10, NOT the 50 used for the MORA ponds. acc.mean is the mean of a
# gamma prior on accumulation in yr/cm; the standard way to set it is age span /
# depth span. Here 10594 yr / 941 slump-free cm ~ 11, and Prichard's stated core
# mean is 12.8 yr/cm (0.078 cm/yr); Gavin used 10. The MORA ponds run ~50. Passing
# the MORA value here would be as wrong as the silent fallback to 20 was there.
#
# SLUMP: the three tephras are instantaneous deposits with real thickness -
# 303-308 (5 cm), 396-406 (10 cm), 623-635 (12 cm), 27 cm total. Same treatment as
# the MORA Y tephra. With remove = FALSE a control that falls inside its own slump
# is collapsed onto the slump horizon rather than dropped, so all three tephra
# dates survive (verified against rbacon:::toslump).
#
# normal = 0 with t.a = 15, t.b = 16 is Bacon's Student-t outlier model, which
# tolerates a scattered date instead of being dragged by it. The MORA cores use
# rbacon's defaults; this is Gavin's choice and is kept.
pp_slump = c(303, 308, 396, 406, 623, 635)

# thick = 5 (rbacon's default; K = 169 sections) and ssize = 10000.
# `thick` is the ONE Gavin setting Neotoma does not store - a Bacon _settings.txt
# does not record it - so it was recovered by sweeping it against his published
# quantiles. Our _settings.txt is otherwise byte-identical to the string Neotoma
# holds for his run, so this is the only free parameter.
#
#   thick   K   median |ours - Gavin|   max |diff|   our 95% width   MCMC ESS
#      50  17          34 yr               167 yr        550            37
#      30  29          36                  213           618             6
#      20  43          26                  126           614           106
#      10  85          13                   52           526           863
#       5 169           3                   17           418          2621   <-
#
# Gavin's published 95% width is 417 yr. At thick = 5 ours is 418 and the medians
# agree to 3 yr over a 10,600 yr record, so this is a reproduction, not a refit.
# ssize is raised from the default 4000 because at 4000 this core mixes badly
# (ESS 37); at 10000 mixing is "excellent" (ESS 2621). Do not lower it.

# PRIMARY run - reproduces Gavin 2021.
cat("\n=== PantherPotholes ===\n")
do.call(run_bacon, c(list(core = "PantherPotholes", plot.pdf = TRUE, verbose = TRUE),
                     CORE_ARGS$PantherPotholes))

# SENSITIVITY - 210Pb age errors instead of activity errors.
#
# THE PROBLEM (sourced). Prichard Table 1c has NO age-error column; its
# "Error (1sigma)" is on total 210Pb ACTIVITY in DPM/g, per its own footnote, and
# those five numbers were carried verbatim into the age-error column of the
# published model (3.47/1.15/0.72/0.74/0.77 in both). So Bacon was told the age at
# 21 cm is 12 cal BP +- 0.72 YEARS. Consequence: the top 35 cm carries a 95% width
# of ~7 yr against a core median of 417 yr.
#
# THE REPLACEMENT (NOT sourced - ASSUMED BY US).
# ------------------------------------------------------------------------------
# There is no way to recover the real CRS age errors from Table 1c: proper
# propagation needs supported 210Pb, dry bulk density and sample mass, none of
# which are published. The Flett Research report or Prichard's 2003 thesis would
# have them; until then this number is OUR ASSUMPTION and nothing else.
#
# ONE CONSTANT, +-10 yr, deliberately. An earlier version used an age-proportional
# rule (25% of the age, floor 5 yr), on the argument that CRS errors grow downcore
# as unsupported 210Pb decays toward background. That argument is correct - it
# produces a widening envelope (20/30/37/44/62 yr at 7/14/21/28/35 cm) where a
# constant produces a flat one (28/32/30/30/36) - but it is IRRELEVANT to the only
# question this run exists to answer, and it is harder to defend. Tested directly,
# all four assumptions give the same answer:
#
#   assumption      95% width, top 35 cm    35-214 cm    below 214 cm
#   published                        7            436            417
#   constant 10                     30            441            422
#   proportional                    34            437            416
#   constant 15                     39            439            419
#   constant 20                     46            438            418
#
# So: 7 -> 30-46 yr in the 210Pb section and NOTHING below 35 cm moves, under every
# assumption tried. That range, not any single value, is the result - which is why
# a constant is preferred: it makes the weaker, more defensible claim and reaches
# the same conclusion. Reproduce the other rows with PB210_ROBUSTNESS below.
#
# This affects ONLY the sensitivity run. The primary run keeps Gavin's values, so
# the reproduction claim is untouched.
PB210_ASSUMED_ERROR = 10
PB210_ROBUSTNESS    = c()   # set to c(15, 20) to rebuild the table above

pp_dates_pb = pp_dates %>%
  mutate(Error = ifelse(grepl("^Pb210_", ID), PB210_ASSUMED_ERROR, Error))
cat("\n210Pb errors - published (DPM/g activity, mis-entered as years) vs ASSUMED:\n")
print(pp_dates %>% filter(grepl("^Pb210_", ID)) %>%
        transmute(ID, Depth, Age, published_error = Error,
                  assumed_error = PB210_ASSUMED_ERROR))
write_core_files("PantherPotholes_pb210err", pp_dates_pb)

cat("\n=== PantherPotholes_pb210err (210Pb sensitivity) ===\n")
do.call(run_bacon, c(list(core = "PantherPotholes_pb210err", plot.pdf = TRUE, verbose = TRUE),
                     CORE_ARGS$PantherPotholes_pb210err))

# Optional: rebuild the robustness table in the comment above. Off by default -
# each run is a full MCMC and adds several minutes to sourcing this script.
for (E in PB210_ROBUSTNESS) {
  nm = paste0("PantherPotholes_pbconst", E)
  write_core_files(nm, pp_dates %>%
    mutate(Error = ifelse(grepl("^Pb210_", ID), E, Error)))
  do.call(run_bacon, c(list(core = nm, plot.pdf = FALSE, verbose = FALSE),
                       CORE_ARGS$PantherPotholes))
}

# =============================================================================
# 5) FIGURES - redraw the stored models
# =============================================================================
# Nothing here re-runs an MCMC. Each panel is redrawn from the .out on disk using
# the SAME settings the model was run with, taken from CORE_ARGS above so the two
# cannot diverge.
#
# TWO TRAPS, both hit in practice:
#  1. Bacon(run = FALSE) rebuilds `info` but does NOT read the iterations back, so
#     agedepth() would draw the PRIORS only (green curves, no grey posterior).
#     They must be loaded with rbacon:::Bacon.AnaOut.
#  2. Bacon(run = FALSE) can THIN the stored .out to its own ssize - drawing a
#     figure would silently destroy iterations. The .out is snapshotted and
#     restored, so redrawing can never damage a run.
if (render_figures) {
library(magick); library(ggplot2); library(patchwork)

render_panel = function(core, outdir) {
  out = Sys.glob(file.path(coredir, core, paste0(core, "_*.out")))
  if (!length(out)) return(NA_character_)
  bak = file.path(tempdir(), paste0("bak_", basename(out)))
  file.copy(out, bak, overwrite = TRUE)
  on.exit(file.copy(bak, out, overwrite = TRUE), add = TRUE)

  do.call(Bacon, c(list(core = core, coredir = coredir, run = FALSE,
                        suggest = FALSE, ask = FALSE, remember = FALSE,
                        plot.pdf = FALSE, verbose = FALSE), CORE_ARGS[[core]]))
  set = get("info", envir = .GlobalEnv)
  set = rbacon:::Bacon.AnaOut(
          file.path(set$coredir, core, paste0(core, "_", set$K, ".out")), set)
  assign("info", set, envir = .GlobalEnv)
  f = file.path(outdir, paste0(core, ".png"))
  # Larger text remains readable when the four panels are shown together.
  png(f, width = 1500, height = 1750, res = 190)
  par(cex.lab = 1.6)
  agedepth(set = set, BCAD = FALSE,
           mainpanel.tickfontsize = 1.8, mainpanel.labelfontsize = 2,
           toppanel.fontsize = 1.5, prior.fontsize = 1.6, title.size = 2.6,
           mar.main = c(4.8, 5, 1, 1), mar.left = c(4.5, 5, 1, 0.8),
           mar.middle = c(4.5, 1.1, 1, 1.8), mar.right = c(4.5, 1.8, 1, 1.1),
           mgp = c(2.8, 0.9, 0))
  dev.off()
  cat("rendered", core, " (K =", set$K, ",", nrow(set$output), "iterations)\n")
  f
}

tmpdir = file.path(tempdir(), "bacon_panels"); dir.create(tmpdir, showWarnings = FALSE)
panels = na.omit(vapply(c("JayBath","LogWallow","ReflectionPond","PantherPotholes"),
                        render_panel, character(1), outdir = tmpdir))

# compose 2 x 2
pp   = image_border(image_read(panels), color = "grey80", geometry = "6x6")
rows = split(seq_along(panels), ceiling(seq_along(panels)/2))
fig  = image_border(image_append(image_join(lapply(rows, function(i) image_append(pp[i]))),
                                 stack = TRUE), color = "white", geometry = "20x20")
image_write(fig, here("plot/test_figures","fig_bacon_agedepth_slump.pdf"),
            format = "pdf")
cat("\nWritten plot/test_figures/fig_bacon_agedepth_slump.pdf\n")

# -----------------------------------------------------------------------------
# 210Pb sensitivity. NOT two agedepth() panels side by side: the difference is
# ~28 yr inside the top 35 cm of an 870 cm core, invisible on a 10,600 yr axis.
# Two panels instead - whole core (effect does NOT propagate) and a top-40 cm zoom.
# -----------------------------------------------------------------------------
if (dir.exists(file.path(coredir, "PantherPotholes_pb210err"))) {
  lab_pub = "published: DPM/g activity errors (0.7-3.5 yr)"
  lab_var = "assumed: flat +-10 yr age error"
  rd = function(core) {
    f = Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))[1]
    setNames(read.table(f, header = TRUE), c("depth","lo","hi","median","mean"))
  }
  env = bind_rows(rd("PantherPotholes")          %>% mutate(run = lab_pub),
                  rd("PantherPotholes_pb210err") %>% mutate(run = lab_var)) %>%
        mutate(run = factor(run, levels = c(lab_var, lab_pub)))   # level order = DRAW order
  pb = tibble(depth = c(7,14,21,28,35), age = c(-36.7,-9,12,21,36),
              e_pub = c(3.47,1.15,0.72,0.74,0.77), e_age = rep(PB210_ASSUMED_ERROR, 5))
  cols = setNames(c("#d1670a","#1b6ca8"), c(lab_var, lab_pub))
  base = function(d) ggplot(d, aes(depth)) +
    geom_ribbon(aes(ymin = lo, ymax = hi, fill = run), alpha = .45) +
    geom_line(aes(y = median, colour = run), linewidth = .45) +
    scale_fill_manual(values = cols, name = NULL, breaks = c(lab_pub, lab_var)) +
    scale_colour_manual(values = cols, name = NULL, breaks = c(lab_pub, lab_var)) +
    labs(x = "Depth (cm)", y = "cal yr BP") + theme_bw(base_size = 10) +
    theme(panel.grid.minor = element_blank(), plot.subtitle = element_text(size = 8.5))
  w = env %>% filter(depth <= 35) %>% group_by(run) %>% summarise(w = median(hi - lo))
  sens = (base(env) +
      annotate("rect", xmin = 0, xmax = 35, ymin = -Inf, ymax = Inf,
               fill = NA, colour = "grey35", linewidth = .3, linetype = "22") +
      labs(subtitle = "Whole core: similar below 35 cm")) +
    (base(env %>% filter(depth <= 40)) +
      geom_linerange(data = pb, inherit.aes = FALSE,
        aes(x = depth - .45, ymin = age - e_pub, ymax = age + e_pub),
        colour = cols[[lab_pub]], linewidth = 1.1) +
      geom_linerange(data = pb, inherit.aes = FALSE,
        aes(x = depth + .45, ymin = age - e_age, ymax = age + e_age),
        colour = cols[[lab_var]], linewidth = 1.1) +
      geom_point(data = pb, inherit.aes = FALSE, aes(depth, age), size = 1.2, colour = "grey15") +
      labs(subtitle = sprintf("Top 40 cm: 95%% width %g -> %g yr. Bars = error given to each control",
                              round(w$w[w$run == lab_pub]), round(w$w[w$run == lab_var])))) +
    plot_layout(guides = "collect") & theme(legend.position = "top")
  ggsave(here("plot/test_figures","fig_bacon_pb210_sensitivity.pdf"), sens, width = 9.5, height = 4.2, device = cairo_pdf)
  cat("Written plot/test_figures/fig_bacon_pb210_sensitivity.pdf\n")
}
}

# =============================================================================
# 6) RUN MANIFEST - durable proof of exactly what the seeded rebuild produced
# =============================================================================
manifest_models = c("JayBath", "LogWallow", "ReflectionPond",
                    "PantherPotholes", "PantherPotholes_pb210err")
manifest_file = function(core, suffix) {
  f = Sys.glob(file.path(coredir, core, paste0(core, suffix)))
  if (length(f) != 1L) stop("Expected exactly one ", suffix, " file for ", core)
  f
}
project_relative = function(path) {
  sub(paste0(normalizePath(here()), "/"), "", normalizePath(path), fixed = TRUE)
}
age_model_code_md5 = function(path = here("R/stages/000_PALEO_a_agedepth.R")) {
  code = readLines(path, warn = FALSE, encoding = "UTF-8")
  figure_header = which(startsWith(code, "# 5) FIGURES"))
  if (length(figure_header) != 1L)
    stop("Could not isolate the chronology-generating section.")
  fingerprint_file = tempfile(fileext = ".R")
  on.exit(unlink(fingerprint_file), add = TRUE)
  writeLines(code[seq_len(figure_header - 2L)], fingerprint_file,
             useBytes = TRUE)
  unname(tools::md5sum(fingerprint_file))
}

bacon_manifest = map_dfr(manifest_models, function(core) {
  control = file.path(coredir, core, paste0(core, ".csv"))
  posterior = manifest_file(core, "_*.out")
  ages = manifest_file(core, "_*_ages.txt")
  settings = CORE_ARGS[[core]]
  tibble(
    model = core,
    role = if_else(core == "PantherPotholes_pb210err",
                   "configured +-10-year 210Pb sensitivity", "primary"),
    seed = 42L,
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    rbacon_version = as.character(packageVersion("rbacon")),
    settings_fingerprint = object_fingerprint(settings),
    control_file = project_relative(control),
    control_md5 = unname(tools::md5sum(control)),
    posterior_file = project_relative(posterior),
    posterior_md5 = unname(tools::md5sum(posterior)),
    posterior_bytes = file.info(posterior)$size,
    ages_file = project_relative(ages),
    ages_md5 = unname(tools::md5sum(ages)),
    ages_bytes = file.info(ages)$size,
    age_model_script_md5 = unname(tools::md5sum(here("R/stages/000_PALEO_a_agedepth.R"))),
    age_model_code_md5 = age_model_code_md5(),
    post_run_script_revision = "none",
    bacon_settings_md5 = unname(tools::md5sum(here("R/helpers/bacon_settings.R"))),
    generated_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
})
write_csv(bacon_manifest, here("output/bacon_run_manifest.csv"))
cat("Written output/bacon_run_manifest.csv for", nrow(bacon_manifest), "seeded runs.\n")
# END R/stages/000_PALEO_a_agedepth.R

# ============================================================================
# BEGIN R/stages/000_PALEO_b_vegetation.R
# ============================================================================
# =============================================================================
# 000_PALEO_b_vegetation.R - paleo macrofossil occurrences
# =============================================================================
# Paleo vegetation preparation; see docs/WORKFLOW.md.
# The fire third is now 000_PALEO_c_fire.R; the climate third was NOT split out -
# The downstream climate-match stage replaces its former embedded implementation.
#
# Ages come from R/stages/000_PALEO_a_agedepth.R via R/helpers/paleo_ages.R. Run that first.
#
# Provenance of every control point: Cores/CONTROL_POINTS.md, with the detail in
# Cores/SOURCES_MORA.md and data/NOCA/NOCA_paleo/SOURCES.md.
#
# Outputs
#   output/paleo_occ.csv             presence/absence, one row per plot_id x species
#   output/paleo_macrofossil_long.csv  MORA long table WITH Percentage and the fire
#                                      categories still in it - the input to
#                                      000_PALEO_c_fire.R. Written here because the
#                                      fire categories are only separable partway
#                                      through this script's harmonisation, and
#                                      re-deriving them in the fire script would
#                                      duplicate that logic.
#
# Dropped in the split as dead code (assigned, never used in the original):
#   `occ`         - a bind_rows of NOCA_occ/MORA_occ, unreferenced
#   `paleo_plots` / `paleo_coords` / `paleo_coords_sf` - pond coordinates,
#                   unreferenced. They now live in 000_PALEO_d_climate_download.R.
# =============================================================================

library(readr)
library(tidyverse)
library(here)
library(readxl)     # DunwiddieMacrofossils.xlsx

source(here("R/helpers/paleo_ages.R"), local = TRUE)

# -----------------------------------------------------------------------------
# MORA: Dunwiddie macrofossils -> harmonised species
# -----------------------------------------------------------------------------
takeoutpaleosp = c("Carex Achenes Lenticular", "Carex Achenes Trigonous",
                   "Isoetes Megaspores", "Nuphar Polysepalum Seeds",
                   "Potamogeton Species Achenes", "Ranunculus CF Aquatilis Achenes",
                   "Juncus Seeds", "Sparganium Seeds", "Phyllodoce Leaves",
                   "Abies-Type Seeds", "Tsuga-Type Seeds")
paleo_occ = read_excel(here("data/PALEO/DunwiddieMacrofossils.xlsx"), sheet = "MacrofossilData")
paleo_occ = paleo_occ %>%
  rename(species = Species) %>%
  filter(!species %in% takeoutpaleosp)%>%
  mutate(
    species = str_squish(species),
    species = case_when(
      species == "Abies Amabilis" ~ "Abies amabilis",
      species == "Abies Lasiocarpa" ~ "Abies lasiocarpa",
      species == "Abies Procera" ~ "Abies procera",
      species %in% c("Pinus Contorta Fascilcles", "Pinus Contorta Fascicles",
                     "Pinus Contorta Needle Fragments") ~ "Pinus contorta",
      species %in% c("Pinus Monticola Fascicles", "Pinus Monticola Needle Fragments",
                     "Pinus Montocola Needle Fragments") ~ "Pinus monticola",
      species == "Picea Engelmannii" ~ "Picea engelmannii",
      species == "Pseudotsuga Menziesii" ~ "Pseudotsuga menziesii",
      species == "Tsuga Heterophylla" ~ "Tsuga heterophylla",
      species %in% c("Tsuga Mertensiana", "Tsuga Mertinsiana") ~ "Tsuga mertensiana",
      species %in% c("Chamaecyparis", "Chamaecyparis Seeds") ~ "Callitropsis nootkatensis",
      species %in% c("Needle Concentration (per CC)", "Needle Concentration (Per CC)") ~ "needle_concentration",
      species == "Charcoal Fragments" ~ "charcoal_fragments",
      species == "Charred Needles" ~ "charred_needles",
      TRUE ~ species
    )
  )


paleo_occ =
  paleo_occ %>%
  rename(site = Location, depth = Depth)%>%
  select(site, species, depth, Percentage)%>%
  left_join(age_depth)

# Hand-off to 000_PALEO_c_fire.R: this is the state the fire categories are read
# from, before they are filtered out below.
write_csv(paleo_occ, here("output", "paleo_macrofossil_long.csv"))

# THE DEPTH LOOKUP THE AGE DRAWS NEED -----------------------------------------
# plot_id is built from the Bacon MEDIAN age, i.e. a point estimate. The moving-
# window analysis (R/helpers/paleo_runs.R) needs the full age POSTERIOR, and Bacon
# delivers that per DEPTH - which the select() below otherwise discards. Captured
# here, while depth is still attached, and written as its OWN table rather than a
# column on paleo_occ because a plot_id can cover MORE THAN ONE depth: three
# ReflectionPond depths (47/49/64 cm) all date to 3641 cal BP, because that core
# has no radiocarbon and its age-depth model is flat over 17 cm. Adding depth as
# a column would multiply those samples' rows - the exact bug that tripled a
# sample in the CCA via paleo_fire (see 000_PALEO_c_fire.R).
mora_depths = paleo_occ %>% distinct(lake = site, depth, year)

paleo_occ =
  paleo_occ %>%
  filter(!species %in% c("charred_needles", "needle_concentration", "charcoal_fragments"))%>%
  mutate(occurrence = ifelse(Percentage>0, 1, 0))%>%
  mutate(plot_id = paste0(site, "_", year, "_BP"),
         lake = site,
         era = "holocene",
         period = "paleo",
         site = "MORA")%>%
  select(period, plot_id, species, occurrence, site, era, lake)%>%
  distinct()

# -----------------------------------------------------------------------------
# NOCA paleo: Panther Potholes core
# -----------------------------------------------------------------------------
# Macrofossil counts: Neotoma dataset 52207, site 13042 (Prichard et al. 2009).
# Ages: OUR Bacon run, NOT the "Gavin 2021" column in this file. Both describe the
# same chronology - our medians reproduce Gavin's to a median of 14 yr over a
# 10,600 yr record - but Neotoma publishes only three quantiles per level, and the
# interval metrics need the full posterior (see SOURCES.md). Taking ages from our
# own run keeps the point estimates and the draws from one and the same model.
# Mirrors the MORA structure (one plot_id per dated sample). Charcoal is NOT in
# this file, so NOCA paleo enters paleo_occ and paleo_env but not paleo_fire.
noca_raw = read_csv(here("data/NOCA/NOCA_paleo/dataset52207_site13042.csv"),
                    show_col_types = FALSE)
noca_desc = c("name", "group", "element", "units", "context")
noca_samples = setdiff(names(noca_raw), noca_desc)

# Per-sample depth, and the age our Bacon model gives at that depth.
# Sample depths are 0.5, 1.5, ... 869.5; Bacon was run with d.by = 0.5, so every
# sample depth is on the output grid and approx() is an exact lookup, not a
# smoothing step. The Gavin column is retained alongside purely as a check.
noca_bacon = read_bacon_ages("PantherPotholes", coredir)

noca_meta = noca_raw %>%
  filter(name %in% c("Depth", "Gavin 2021")) %>%
  select(name, all_of(noca_samples)) %>%
  pivot_longer(-name, names_to = "sample", values_to = "value") %>%
  pivot_wider(names_from = name, values_from = value) %>%
  transmute(
    sample,
    depth      = as.numeric(Depth),
    year       = round(approx(noca_bacon$depth, noca_bacon$median, depth)$y),
    year_gavin = as.numeric(str_split_i(`Gavin 2021`, "/", 2))
  )

# Report the agreement rather than assume it.
cat("\nPantherPotholes ages, ours vs Gavin 2021 (cal yr BP):\n")
print(summary(noca_meta$year - noca_meta$year_gavin))
stopifnot(!any(is.na(noca_meta$year)))
noca_meta = noca_meta %>% select(sample, depth, year)

# Tree/shrub macrofossils -> harmonized species (drop genus/family "undiff.")
noca_paleo_occ = noca_raw %>%
  filter(group == "TRSH") %>%
  mutate(species = case_when(
    name == "Abies lasiocarpa"       ~ "Abies lasiocarpa",
    name == "Cupressus nootkatensis" ~ "Callitropsis nootkatensis",
    name == "Picea engelmannii"      ~ "Picea engelmannii",
    name == "Pinus contorta"         ~ "Pinus contorta",
    name == "Pinus monticola"        ~ "Pinus monticola",
    name == "Pseudotsuga menziesii"  ~ "Pseudotsuga menziesii",
    name == "Thuja plicata"          ~ "Thuja plicata",
    name == "Tsuga heterophylla"     ~ "Tsuga heterophylla",
    name == "Tsuga mertensiana"      ~ "Tsuga mertensiana",
    name == "Juniperus communis"     ~ "Juniperus communis",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(species)) %>%
  select(species, all_of(noca_samples)) %>%
  pivot_longer(-species, names_to = "sample", values_to = "count") %>%
  mutate(count = replace_na(as.numeric(count), 0)) %>%
  group_by(species, sample) %>%
  summarize(count = sum(count), .groups = "drop") %>%
  left_join(noca_meta, by = "sample") %>%
  mutate(
    occurrence = ifelse(count > 0, 1, 0),
    lake = "PantherPotholes",
    site = "NOCA",
    era  = "holocene",
    period = "paleo",
    plot_id = paste0(lake, "_", year, "_BP")
  ) %>%
  select(period, plot_id, species, occurrence, site, era, lake) %>%
  distinct()

paleo_occ = bind_rows(paleo_occ, noca_paleo_occ)

# -----------------------------------------------------------------------------
# Collapse to ONE row per (plot_id, species)
# -----------------------------------------------------------------------------
# distinct() above left 71 (plot_id, species) pairs with TWO rows - one saying
# occurrence 0 and the other 1 - from two unrelated causes:
#
# MORA (59 pairs). Several raw categories map to one species, and they are
# recorded on DIFFERENT bases:
#   Pinus contorta   <- "Pinus Contorta Fascicles" / "...Fascilcles" (typo)
#                       / "Pinus Contorta Needle Fragments"
#   Pinus monticola  <- "Pinus Monticola Fascicles"
#                       / "Pinus Monticola Needle Fragments" / "...Montocola..." (typo)
#   Callitropsis nootkatensis <- "Chamaecyparis" / "Chamaecyparis Seeds"
#   Dunwiddie 1986 counted Pinus fascicles as needle equivalents but tallied
#   needle FRAGMENTS separately, and Fig. 2's caption states "Pinus fragments
#   ... are excluded from the needle sum". Seeds are likewise on their own basis.
#   So the percentages must NOT be summed - they are not commensurable. For a
#   presence/absence analysis it does not matter: any category above zero means
#   the species is present.
#
# NOCA (12 pairs, at PantherPotholes 2678 / 3785 / 7616 BP). Two different core
# DEPTHS whose ages round to the same year, so they share a plot_id. Same
# situation as macrofossil samples inside a slump: contemporaneous within dating
# resolution, so merging them is the honest reading.
#
# Both are handled by the same rule - present if present in any contributing row.
paleo_occ = paleo_occ %>%
  group_by(period, plot_id, species, site, era, lake) %>%
  summarize(occurrence = as.integer(any(occurrence == 1)), .groups = "drop") %>%
  select(period, plot_id, species, occurrence, site, era, lake)

write_csv(paleo_occ, here("output", "paleo_occ.csv"))

cat("\npaleo_occ.csv: ", nrow(paleo_occ), " rows, ",
    n_distinct(paleo_occ$plot_id), " samples, ",
    n_distinct(paleo_occ$species), " species\n", sep = "")

# -----------------------------------------------------------------------------
# paleo_sample_depths.csv - which core depth(s) each sample came from
# -----------------------------------------------------------------------------
# One row per (plot_id, depth). Consumed by R/helpers/paleo_runs.R, which asks Bacon for
# the age posterior AT A DEPTH; without this the age draws cannot be attached to
# a sample at all, because plot_id carries only the median age.
#
# n_depths > 1 marks the samples where two or more depths collapsed onto one
# median age. They are contemporaneous within dating resolution - that is why
# they were merged - but their POSTERIORS are not identical, so the run
# machinery must decide what to draw for them rather than inherit an accident.
sample_depths = bind_rows(
  mora_depths,
  noca_meta %>% distinct(depth, year) %>% mutate(lake = "PantherPotholes")
) %>%
  mutate(plot_id = paste0(lake, "_", year, "_BP")) %>%
  group_by(plot_id) %>%
  mutate(n_depths = n()) %>%
  ungroup() %>%
  select(lake, plot_id, depth, median_age = year, n_depths) %>%
  arrange(lake, depth)

# The two tables must describe the SAME samples, or a sample would silently get
# no age draws (and vanish from every binned figure) while looking healthy here.
stopifnot(setequal(sample_depths$plot_id, paleo_occ$plot_id),
          !any(is.na(sample_depths$depth)))

write_csv(sample_depths, here("output", "paleo_sample_depths.csv"))
cat("paleo_sample_depths.csv: ", nrow(sample_depths), " depths for ",
    n_distinct(sample_depths$plot_id), " samples; ",
    sum(sample_depths$n_depths > 1), " depths share a collapsed age\n", sep = "")
# END R/stages/000_PALEO_b_vegetation.R

# ============================================================================
# BEGIN R/stages/000_FIRE_cleaning.R
# ============================================================================
# =============================================================================
# 000_FIRE_cleaning.R - harmonized tapas detection for the three MORA records
# =============================================================================
# The MORA records retain Walsh et al.'s record-specific interpolation,
# background, local 95% threshold, and minimum-count settings. The implementation
# is shared with Panther Potholes through R/helpers/fire_detection_functions.R.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(readxl); library(tapas)
})
source(here("R/helpers/fire_detection_functions.R"), local = TRUE)

settings = fire_source_settings() |> filter(site == "MORA")
results = pmap(settings, function(site, lake, input_source, chronology,
                                  interpolation_years, smoothing_years,
                                  threshold_probability) {
  run_tapas_fire_detection(
    prepare_mora_charcoal(here(input_source)), site, lake,
    interpolation_years, smoothing_years, threshold_probability,
    chronology, input_source)
})

fire_episodes_final = map_dfr(results, "peaks")
series = map_dfr(results, "series")
events = map_dfr(results, "events")
settings_audit = map_dfr(results, "settings")

if (nrow(events) == 0L || anyDuplicated(events[c("lake", "age_cal_yr_BP")]))
  stop("The harmonized MORA accepted-event catalog is empty or duplicated.")

write_csv(fire_episodes_final, here("output/fire_walsh.csv"))
write_csv(series, here("output/fire_mora_tapas_series.csv"))
write_csv(events, here("output/fire_mora_tapas_events.csv"))
write_csv(settings_audit, here("output/fire_mora_tapas_settings.csv"))

cat("Harmonized tapas MORA fire episodes:\n")
print(as.data.frame(fire_episodes_final |>
  group_by(lake, smoothing_window, interpolation_interval,
           threshold_probability) |>
  summarise(candidate_peaks = n(), accepted_events = sum(is_significant),
            older_cal_bp = max(age_cal_yr_BP),
            younger_cal_bp = min(age_cal_yr_BP), .groups = "drop")))
# END R/stages/000_FIRE_cleaning.R

# ============================================================================
# BEGIN R/stages/000_PALEO_c_fire.R
# ============================================================================
# =============================================================================
# 000_PALEO_c_fire.R - charcoal and charred needles per paleo sample
# =============================================================================
# Paleo fire preparation; see docs/WORKFLOW.md.
#
# RUN AFTER 000_PALEO_b_vegetation.R. It reads output/paleo_macrofossil_long.csv,
# which b writes: the harmonised MORA long table with Percentage and the three
# fire categories still present. They are only separable partway through b's
# harmonisation, so re-deriving them here would duplicate that logic and let the
# two drift apart.
#
# MORA uses the Dunwiddie charcoal/charred-needle records; NOCA uses the Neotoma
# macrocharcoal series added below. Both sites receive one fire row per sample.
#
# Output: output/paleo_fire.csv
# =============================================================================

library(readr)
library(tidyverse)
library(here)

macro_long = read_csv(here("output", "paleo_macrofossil_long.csv"),
                      show_col_types = FALSE)
fire_walsh = read_csv(here("output", "fire_walsh.csv"), show_col_types = FALSE)

paleo_fire =
  macro_long %>%
  filter(species %in% c("charred_needles", "needle_concentration", "charcoal_fragments"))%>%
  pivot_wider(names_from = species, values_from = Percentage)

stopifnot(nrow(paleo_fire) == 119)   # was `dim(paleo_fire) #119` in the original

paleo_prev_fire = paleo_fire %>%
  # join any fire that is BEFORE the paleo year (older in cal yr BP)
  left_join(fire_walsh, by = join_by(year <= age_cal_yr_BP),
            relationship = "many-to-many") %>%
  # filter to fires within 50 years and keep the nearest earlier event
  filter(is.na(age_cal_yr_BP) | (age_cal_yr_BP - year <= 50)) %>%
  group_by(site, depth, year) %>%
  slice_min(age_cal_yr_BP, with_ties = FALSE) %>%
  ungroup() %>%
  # tidy names and calculate years before
  rename(
    fire_event_year_BP  = age_cal_yr_BP,
    fire_lake           = lake,
    fire_peak_magnitude = peak_magnitude,
    fire_is_significant = is_significant
  ) %>%
  mutate(
    years_before_fire = fire_event_year_BP - year,
    has_fire_within_50yr = !is.na(fire_event_year_BP)
  ) %>%
  filter(!is.na(year))%>%
  filter(fire_is_significant)

paleo_fire =
  paleo_prev_fire %>%
  select(site, depth, year, charcoal_fragments, needle_concentration, charred_needles, fire_lake, fire_peak_magnitude, years_before_fire)%>%
  right_join(paleo_fire)%>%
  mutate(plot_id = paste0(site, "_", year, "_BP"))%>%
  mutate(period = "paleo")%>%
  rename(lake = site)

paleo_fire =
  paleo_fire %>%
  mutate(charred_needles = ifelse(is.na(charred_needles), 0, charred_needles),
         fire_peak_magnitude = ifelse(is.na(fire_peak_magnitude), 0, fire_peak_magnitude),
         years_before_fire = ifelse(is.na(years_before_fire), 0, years_before_fire),
         fire_lake = ifelse(is.na(fire_lake), "no_fire_record", fire_lake)
         )

# -----------------------------------------------------------------------------
# Collapse to ONE row per plot_id
# -----------------------------------------------------------------------------
# plot_id is built from the AGE, so several core DEPTHS whose Bacon ages round to
# the same year share one plot_id. At ReflectionPond, 47 / 49 / 64 cm all date to
# 3641 cal BP - the age-depth model is flat over that 17 cm because the core has
# no radiocarbon (see the Reflection Pond caveat in Cores/SOURCES_MORA.md).
#
# 000_PALEO_b_vegetation.R already collapses exactly this collision on the
# vegetation side ("present if present in any contributing row"), so paleo_occ has
# one row per sample while paleo_fire had three. Left unmerged, the left_join in
# 05_cca_model.R multiplies that sample's env row threefold and it is counted
# three times in the CCA.
#
# Two different rules, because the columns are two different kinds of thing:
#   fire_peak_magnitude  max  - a peak at ANY contributing depth means the sample
#                              is burnt; mirrors b's any(occurrence == 1)
#   the Dunwiddie percentages  mean - concentrations measured on depths that are
#                              contemporaneous within dating resolution, so the
#                              honest summary is their average, not the largest
paleo_fire = paleo_fire %>%
  group_by(lake, period, plot_id, year) %>%
  summarize(depth               = mean(depth),
            charcoal_fragments  = mean(charcoal_fragments,  na.rm = TRUE),
            needle_concentration= mean(needle_concentration, na.rm = TRUE),
            charred_needles     = mean(charred_needles,     na.rm = TRUE),
            fire_peak_magnitude = max(fire_peak_magnitude),
            # the event that justifies `burnt` is the one with the largest peak
            fire_lake           = fire_lake[which.max(fire_peak_magnitude)],
            years_before_fire   = years_before_fire[which.max(fire_peak_magnitude)],
            .groups = "drop") %>%
  mutate(across(c(charcoal_fragments, needle_concentration, charred_needles),
                ~ ifelse(is.nan(.x), NA_real_, .x)))

# =============================================================================
# NOCA: Panther Potholes macrocharcoal (Neotoma dataset 52210)
# =============================================================================
# Charcoal is a SEPARATE Neotoma dataset from the macrofossils (52207), which is
# why it looked missing - 52207 holds only TRSH and LABO. See
# data/NOCA/NOCA_paleo/SOURCES.md.
#
# 870 samples, contiguous 1 cm, on exactly the same depths as the macrofossils, so
# fire and vegetation are measured on the SAME samples. Counts of 150-1000 um
# charcoal plus sample volume, so tapas can build concentration itself.
#
# AGES: ours, not Neotoma's. Matched on depth to 000_PALEO_a's Bacon run, exactly
# as the macrofossils are, so vegetation and fire share one chronology and one set
# of age draws. (They agree closely anyway: -50 to 10616 vs Neotoma's -49 to 10609.)
#
# ⚠ THE TWO SITES ARE NOT SAMPLED AT THE SAME RESOLUTION.
#   Panther Potholes   12 yr / sample
#   MORA Walsh lakes   42, 47, 48 yr / sample
# MORA retains each lake's published settings. NOCA is analyzed independently at
# its native median 12-year resolution, so its primary peak catalog is not
# artificially coarsened to the MORA grids. The sites' raw peak counts and
# magnitudes are never compared directly.
library(tapas)
source(here("R/helpers/paleo_ages.R"), local = TRUE)
source(here("R/helpers/fire_detection_functions.R"), local = TRUE)

NOCA_YRINTERP_PRIMARY = 12
NOCA_SMOOTH_PRIMARY   = 500
NOCA_THRESHOLD_PRIMARY = 0.99  # source setting used for reported fire-return intervals

ch = read_csv(here("data/NOCA/NOCA_paleo/neotoma_macrocharcoal_52210.csv"),
              show_col_types = FALSE)
pp_bacon = read_bacon_ages("PantherPotholes", coredir)

noca_char = prepare_noca_charcoal(ch, pp_bacon)

run_peaks = function(smoothing_yr, yrInterp, threshold_probability) {
  run_tapas_fire_detection(
    noca_char, "NOCA", "PantherPotholes", yrInterp, smoothing_yr,
    threshold_probability, "active PaleoACES Bacon median chronology",
    "data/NOCA/NOCA_paleo/neotoma_macrocharcoal_52210.csv")$peaks
}

cat("\n--- NOCA peak-detection sensitivity (n significant peaks) ---\n")
sens = tribble(
  ~setting, ~smoothing, ~yrInterp, ~threshold,
  "primary_native12_smooth500_q99", 500, 12, .99,
  "native12_smooth500_q95",         500, 12, .95,
  "native12_smooth500_q999",        500, 12, .999,
  "native12_smooth800_q99",         800, 12, .99,
  "native12_smooth1000_q99",       1000, 12, .99,
  "publication12.5_smooth500_q99",  500, 12.5, .99,
  "coarse45_smooth500_q99",         500, 45, .99)
sens$n_sig = pmap_int(sens[c("smoothing", "yrInterp", "threshold")],
  function(smoothing, yrInterp, threshold)
    sum(run_peaks(smoothing, yrInterp, threshold)$is_significant))
print(as.data.frame(sens))
cat("primary: smoothing =", NOCA_SMOOTH_PRIMARY, " yrInterp =", NOCA_YRINTERP_PRIMARY,
    " threshold =", NOCA_THRESHOLD_PRIMARY, "(native NOCA/source-faithful)\n")

noca_primary = run_tapas_fire_detection(
  noca_char, "NOCA", "PantherPotholes", NOCA_YRINTERP_PRIMARY,
  NOCA_SMOOTH_PRIMARY, NOCA_THRESHOLD_PRIMARY,
  "active PaleoACES Bacon median chronology",
  "data/NOCA/NOCA_paleo/neotoma_macrocharcoal_52210.csv")
noca_peaks = noca_primary$peaks
if (sum(noca_peaks$is_significant) != 66L ||
    sum(noca_peaks$is_significant & noca_peaks$age_cal_yr_BP > 8200 &
          noca_peaks$age_cal_yr_BP <= 9200) != 6L)
  stop("Primary NOCA source-faithful peak catalog changed unexpectedly.")
write_csv(noca_peaks, here("output", "fire_noca_peaks.csv"))
write_csv(noca_primary$series, here("output/fire_noca_tapas_series.csv"))
write_csv(noca_primary$events, here("output/fire_noca_tapas_events.csv"))
write_csv(noca_primary$settings, here("output/fire_noca_tapas_settings.csv"))
write_csv(sens, here("output/fire_noca_tapas_sensitivity.csv"))

# Join to the NOCA samples with the SAME rule as MORA: the nearest significant peak
# in the 50 yr before the sample.
noca_samples = read_csv(here("output", "paleo_occ.csv"), show_col_types = FALSE) %>%
  filter(lake == "PantherPotholes") %>%
  distinct(period, plot_id, lake, site) %>%
  mutate(year = as.numeric(regmatches(plot_id,
                  regexpr("-?[0-9.]+(?=_BP$)", plot_id, perl = TRUE))))

# The nearest significant peak in the 50 yr before each sample. NOTE the right_join
# back onto noca_samples: the filter drops samples that matched a peak but none
# within 50 yr, so without it those samples vanish from paleo_fire entirely rather
# than being recorded as "no fire". (The MORA block above does the same thing via
# its own right_join.)
noca_matched = noca_samples %>%
  left_join(noca_peaks %>% filter(is_significant) %>%
              select(age_cal_yr_BP, peak_magnitude),
            by = join_by(year <= age_cal_yr_BP), relationship = "many-to-many") %>%
  filter(!is.na(age_cal_yr_BP), age_cal_yr_BP - year <= 50) %>%
  group_by(plot_id) %>% slice_min(age_cal_yr_BP, with_ties = FALSE) %>% ungroup() %>%
  select(plot_id, age_cal_yr_BP, peak_magnitude)

noca_fire = noca_samples %>%
  left_join(noca_matched, by = "plot_id") %>%
  transmute(period, plot_id, lake, year,
            fire_lake = ifelse(is.na(age_cal_yr_BP), "no_fire_record", "PantherPotholes"),
            fire_peak_magnitude = ifelse(is.na(peak_magnitude), 0, peak_magnitude),
            years_before_fire = ifelse(is.na(age_cal_yr_BP), 0, age_cal_yr_BP - year))
stopifnot(nrow(noca_fire) == nrow(noca_samples))

paleo_fire = bind_rows(paleo_fire, noca_fire)

# ONE row per sample, and the same samples the vegetation has. Without this the
# left_join in 05_cca_model.R silently multiplies rows: a plot_id appearing twice
# here makes that paleo sample count twice in the CCA.
stopifnot(!any(duplicated(paleo_fire$plot_id)))
paleo_occ_ids = read_csv(here("output", "paleo_occ.csv"), show_col_types = FALSE)$plot_id
stopifnot(setequal(paleo_fire$plot_id, unique(paleo_occ_ids)))

write_csv(paleo_fire, here("output", "paleo_fire.csv"))

cat("\npaleo_fire.csv: ", nrow(paleo_fire), " rows across ",
    n_distinct(paleo_fire$lake), " lakes\n", sep = "")
print(as.data.frame(paleo_fire %>% group_by(lake) %>%
  summarise(n = n(), with_fire = sum(fire_peak_magnitude > 0), .groups = "drop")))
cat("\nNOTE: MORA rows carry Dunwiddie's charcoal_fragments / needle_concentration /\n",
    "charred_needles (percentages, in-core) and the Walsh REGIONAL peaks from three\n",
    "OTHER lakes. NOCA rows carry in-core macrocharcoal peaks from its own core.\n",
    "The fire evidence is not of the same kind at the two sites - say so.\n", sep = "")
# END R/stages/000_PALEO_c_fire.R

# ============================================================================
# BEGIN R/stages/000_PALEO_d_climate_download.R
# ============================================================================
# =============================================================================
# 000_PALEO_d_climate_download.R - CHELSA-TraCE21k climate for the four ponds
# =============================================================================
# RESUMABLE. One CSV per (variable, slice) is written to output/chelsa_paleo/ as
# soon as it lands, and any file already there is skipped. ~4,000 streamed reads
# at ~6 s each is close to seven hours, so just re-run this script after an
# interrupt and it picks up where it stopped. Safe to Ctrl-C or shut the laptop.
# Each chunk is written to .tmp and renamed, so a kill mid-write can never leave a
# half-written CSV that would be read back as complete.
#
# DECISION: the paleo arm takes ALL its climate from TraCE21k, core tops included.
# Some samples are younger than 50 cal BP and slice 20 is the last one, so they all
# fall in one slice and get one value. That is the reason for the choice, not an
# objection to it: the Holocene arm bins at 500 yr, so it was never going to
# resolve within-century change anyway; those samples all land in the youngest bin
# regardless, which averages slices 16-20. Detecting 20th-century climate change is
# the Anthropocene arm's job, from the survey plots.
#
# BIAS CORRECTION. The CCA is calibrated on survey plots carrying V2.1
# (observations); paleo samples are projected carrying TraCE21k (a CCSM3 run).
# Measured at these ponds, slice 20 vs V2.1 1979-2021: tasmin +0.5 to +2.1 degC
# too warm, tasmax ~1.5 degC too cool. Corrected here - additive for temperature,
# multiplicative for precipitation (bounded at zero) - per pond x variable x month.
# BOTH raw and corrected values are written, so it is auditable and reversible.
# ⚠ Anchored at ONE slice, so it assumes a stationary bias. See the 🔴 unresolved
# issue in docs/SCIENTIFIC_DECISIONS.md; rerun with BIAS_CORRECT = FALSE only as the
# documented anchoring sensitivity.
#
# Output: output/chelsa_paleo_ponds.csv  (+ per-chunk cache in output/chelsa_paleo/)
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr)})
source(here("R/vendor/get_chelsa.R"), local = TRUE)          # vendored, commit 3d410b8
source(here("R/helpers/get_chelsa_monthly.R"), local = TRUE)  # V2.1 monthly, for the bias anchor
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/offline_cache.R"), local = TRUE)

CACHE        = here("output/chelsa_paleo")
OUT          = here("output/chelsa_paleo_ponds.csv")
OUT_BIAS     = here("output/chelsa_paleo_bias_correction.csv")
BIAS_CORRECT = TRUE
V21_REF      = 1979:2021
SLICE_MODERN = 20L

# TraCE21k slice ids: integers -200..20, one step ~100 yr, 20 = present, 0 = 0 CE.
# -90 is ~11 kyr BP, covering NOCA's 10,609 cal BP, so both sites get the SAME
# window - which they never had before (MORA was cut at 6000 BP while its cores
# reach 6841). Slice 21 and 22 are 404: 20 really is the last.
SLICES = -90:20
VARS   = c("tasmin", "tasmax", "pr")

# MORA coords per Dunwiddie 1986; NOCA per Prichard 2009.
# =============================================================================
# POND COORDINATES - provenance and precision (audited 2026-08-13)
# =============================================================================
# CHELSA is 30 arcsec (~0.00833 deg, ~700 m E-W here), so coordinate precision
# below ~1 km changes the grid cell. Every coordinate below was traced to its
# most precise published source; GNIS, Neotoma, NOAA WDS-Paleo and the open web
# were all searched.
#
# PantherPotholes - CHANGED 2026-08-13, was (-121.0333, 48.6500).
#   Neotoma site 13042 carries a site POLYGON:
#     [-121.04089, 48.65816] .. [-121.0381, 48.65952], altitude 1033 m
#   centre = (-121.0395, 48.6588). This is the dataset PI's own site footprint,
#   precise to ~150 m. The old value was Prichard (2009)'s published
#   "48 deg 39' N, 121 deg 02' W" - the SAME site, rounded to arcminutes, which
#   put it 1.1 km away in a DIFFERENT CHELSA cell in both axes.
#   Measured cost of the old coordinate: precipitation was unaffected (annual
#   1231 vs 1224 mm) but temperature ran 0.85 degC COOL in every month - a
#   constant displacement of 0.171 CCA units, 47% of the span of the entire NOCA
#   Holocene climate trajectory. Corrected because it is wrong, not because of
#   the size of its effect.
#
# The three MORA ponds - ALL CHANGED 2026-08-13. The previous values were
# Dunwiddie (1986)'s published coordinates, given only to the ARCMINUTE:
#     Jay Bath          46 deg 46' N, 121 deg 46' W, 1311 m
#     Log Wallow        46 deg 46' N, 121 deg 45' W, "1.2 km NE of Jay Bath, +50 m"
#     Reflection Pond 1 46 deg 46' N, 121 deg 43' W, "2.4 km E of Log Wallow,
#                       easternmost of the ponds called the Reflection Lakes"
#   Arcminute rounding at 46.77 N is +/-928 m in latitude and +/-635 m in
#   longitude - MORE than one CHELSA cell - and it put all three ponds at the
#   IDENTICAL latitude, which is a rounding artefact, not geography.
#   ⚠ THE OLD JAY BATH COORDINATE HAD NO POND AT IT. Confirmed on satellite
#   imagery by Billur, 2026-08-13. These are not small errors; they were the
#   wrong locations.
#
#   The ponds are Dunwiddie's own informal names and appear in NO gazetteer or
#   database - GNIS, Neotoma and NOAA WDS-Paleo all return nothing - so the
#   ponds were located directly on satellite imagery by Billur. The values below
#   are those, and they are INDEPENDENTLY CORROBORATED three ways:
#
#     1. they reproduce Dunwiddie's published arcminutes
#          Jay Bath          46 46.23' / 121 46.10'   -> 46 46' / 121 46'  exact
#          Log Wallow        46 46.50' / 121 45.23'   -> 121 45' exact; the
#                            latitude falls exactly on the .50 rounding
#                            boundary, which truncation renders as 46 46'
#          Reflection Pond 1 46 46.17' / 121 43.49'   -> 46 46' / 121 43'  exact
#     2. they reproduce his stated inter-pond distances
#          Jay Bath -> Log Wallow    1.22 km   (he says 1.2 km)
#          Log Wallow -> Reflection  2.30 km   (he says 2.4 km)
#          Jay Bath -> Reflection    3.32 km   (he says a 3.5-km transect)
#     3. they RESOLVE the contradiction the old coordinates carried. Dunwiddie's
#        text says Log Wallow is NORTHEAST of Jay Bath; the rounded coordinates
#        put it due EAST at identical latitude. The located ponds give a bearing
#        of 65 deg - north of east. His prose was right; the rounding was the
#        artefact.
#
#   ⚠ GNIS "Reflection Lakes" (46.7695, -121.7300, 1481 m) is NOT this pond: it
#   is the group centroid, and Dunwiddie specifies the EASTERNMOST pond of that
#   group. Do not substitute it.
#
# CRS: all coordinates are WGS 84 decimal degrees (EPSG:4326), which is what
# Google Maps reports and what CHELSA rasters are stored in - verified directly
# from a CHELSA GeoTIFF header (EPSG:4326, 0.008333 deg = 30 arcsec). NO
# reprojection is needed or applied anywhere in this pipeline.
ponds = data.frame(
  ID  = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes"),
  lon = c(-121.768404, -121.753865, -121.724790,   -121.0395),
  lat = c(  46.770463,   46.775068,   46.769559,     48.6588),
  site = c("MORA", "MORA", "MORA", "NOCA"), stringsAsFactors = FALSE)

if (!dir.exists(CACHE)) dir.create(CACHE, recursive = TRUE)

# -----------------------------------------------------------------------------
# 1. download, one chunk per (variable, slice), skipping what is already there
# -----------------------------------------------------------------------------
todo = expand.grid(var = VARS, slice = SLICES, stringsAsFactors = FALSE)
todo$key  = sprintf("%s_sl%+04d", todo$var, todo$slice)
todo$path = file.path(CACHE, paste0(todo$key, ".csv"))

EXPECT = 12 * nrow(ponds)     # 12 months x 4 ponds
paleo_cache_valid = function(path, variable, slice) {
  if (!file.exists(path)) return(FALSE)
  x = tryCatch(read_csv(path, show_col_types = FALSE), error = function(e) NULL)
  required = c("id", "lon", "lat", "source", "variable", "month", "slice", "value")
  if (is.null(x) || !all(required %in% names(x)) || nrow(x) != EXPECT ||
      anyNA(x[required]) || !is.numeric(x$value) ||
      !is.numeric(x$lon) || !is.numeric(x$lat) ||
      any(!is.finite(x$value) | !is.finite(x$lon) | !is.finite(x$lat)) ||
      !all(x$source == "paleo") ||
      !all(x$variable == variable) || !all(x$slice == slice) ||
      anyDuplicated(x[c("id", "month")]) ||
      !setequal(x$month, 1:12) || !setequal(x$id, ponds$ID)) return(FALSE)
  got = unique(x[c("id", "lon", "lat")])
  if (anyDuplicated(got$id)) return(FALSE)
  got = got[match(ponds$ID, got$id), ]
  all(abs(got$lon - ponds$lon) < 1e-8 & abs(got$lat - ponds$lat) < 1e-8)
}
todo$cache_valid = mapply(paleo_cache_valid, todo$path, todo$var, todo$slice)
require_offline_cache(todo$path, todo$cache_valid, "TraCE21k climate")
file.remove(list.files(CACHE, "\\.tmp$", full.names = TRUE))   # from a killed run
cat("TraCE21k: ", sum(!todo$cache_valid), " of ", nrow(todo),
    " chunks to fetch (each = 12 months x 4 ponds)\n", sep = "")

# get_chelsa() swallows errors AND warnings (error = NULL, warning = NULL), so a
# transient network failure comes back as ZERO ROWS rather than an error. Caching
# that would mark the chunk done and never retry it. Only cache a COMPLETE chunk.
incomplete = character(0)

for (i in seq_len(nrow(todo))) {
  if (todo$cache_valid[i]) next
  if (file.exists(todo$path[i])) {
    message("invalidating stale paleo climate chunk: ", basename(todo$path[i]))
    file.remove(todo$path[i])
  }
  x = get_chelsa(ponds, vars = todo$var[i], source = "paleo",
                 start = todo$slice[i], end = todo$slice[i], months = 1:12,
                 to_celsius = TRUE, id_col = "ID", verbose = FALSE)
  if (nrow(x) != EXPECT) {
    incomplete = c(incomplete, todo$key[i])
    cat(sprintf("  [%4d/%4d] %-16s INCOMPLETE %d/%d - not cached, will retry\n",
                i, nrow(todo), todo$key[i], nrow(x), EXPECT))
    next
  }
  tmp = paste0(todo$path[i], ".tmp"); write_csv(x, tmp); file.rename(tmp, todo$path[i])
  cat(sprintf("  [%4d/%4d] %-16s %3d rows\n", i, nrow(todo), todo$key[i], nrow(x)))
}
if (length(incomplete))
  cat("\n", length(incomplete), " chunk(s) came back short and were NOT cached.\n",
      "Re-run to retry them: ", paste(head(incomplete, 8), collapse = ", "), "\n", sep = "")

todo$cache_valid = mapply(paleo_cache_valid, todo$path, todo$var, todo$slice)
got = todo$path[todo$cache_valid]
if (length(got) < nrow(todo))
  stop(nrow(todo) - length(got), " valid chunk(s) missing - re-run to finish the download.")

saveRDS(list(
  signature = object_fingerprint(list(points = ponds, variables = VARS,
                                      slices = SLICES, source = "CHELSA_TraCE21k_V1")),
  points = ponds, variables = VARS, slices = SLICES,
  source = "CHELSA_TraCE21k_V1"
), file.path(CACHE, "_paleo_cache_fingerprint.rds"))

paleo = bind_rows(lapply(got, read_csv, show_col_types = FALSE, progress = FALSE))

# -----------------------------------------------------------------------------
# 2. slice -> age, and check it rather than assuming it
# -----------------------------------------------------------------------------
paleo = paleo %>% mutate(year_CE = slice * 100, cal_BP = 1950 - year_CE)
cat("\nslices ", min(paleo$slice), " to ", max(paleo$slice), " -> cal BP ",
    max(paleo$cal_BP), " to ", min(paleo$cal_BP), "\n", sep = "")
stopifnot(max(paleo$cal_BP) > 10609,   # must cover NOCA's oldest sample
          min(paleo$cal_BP) <= -49)    # must reach the youngest (1999 CE)

# Do the three MORA ponds land in different ~1 km grid cells? They are 1.3-3.8 km
# apart. If the series are identical, "per-lake climate" is fiction and MORA is one
# climate point, which changes the interpretation of the per-lake sensitivity.
cat("\n--- do the 3 MORA ponds differ? (0 spread = same grid cell) ---\n")
print(as.data.frame(paleo %>%
  filter(id %in% c("JayBath", "LogWallow", "ReflectionPond")) %>%
  group_by(variable, slice, month) %>%
  summarise(spread = max(value) - min(value), .groups = "drop") %>%
  group_by(variable) %>%
  summarise(mean_spread = mean(spread), max_spread = max(spread),
            pct_identical = 100 * mean(spread == 0), .groups = "drop")), digits = 3)

# -----------------------------------------------------------------------------
# 3. bias correction against V2.1 (cached the same way)
# -----------------------------------------------------------------------------
if (BIAS_CORRECT) {
  v21_paths = file.path(CACHE, sprintf("v21_%s_%d.csv",
                        rep(VARS, each = length(V21_REF)), rep(V21_REF, length(VARS))))
  pond_points = ponds %>% transmute(id = ID, lon, lat)
  v21_vars = rep(VARS, each = length(V21_REF))
  v21_years = rep(V21_REF, length(VARS))
  v21_valid = mapply(climate_cache_valid, v21_paths,
                     MoreArgs = list(points = pond_points),
                     variable = v21_vars, year = v21_years,
                     expected_source = "v21_monthly")
  require_offline_cache(v21_paths, v21_valid, "paleo V2.1 bias anchor")
  cat("\nV2.1 monthly anchor: ", sum(!v21_valid), " of ",
      length(v21_paths), " chunks to fetch\n", sep = "")
  k = 0
  for (v in VARS) for (yr in V21_REF) {
    k = k + 1; p = file.path(CACHE, sprintf("v21_%s_%d.csv", v, yr))
    if (climate_cache_valid(p, pond_points, v, yr,
                            expected_source = "v21_monthly")) next
    if (file.exists(p)) file.remove(p)
    x = get_chelsa_monthly(ponds, vars = v, years = yr, months = 1:12,
                           to_celsius = TRUE, id_col = "ID", verbose = FALSE)
    if (nrow(x) != 12L * nrow(ponds) || anyNA(x$value)) {
      cat(sprintf("  [%3d/%3d] v21_%s_%d INCOMPLETE - not cached\n",
                  k, length(v21_paths), v, yr))
      next
    }
    tmp = paste0(p, ".tmp"); write_csv(x, tmp); file.rename(tmp, p)
    cat(sprintf("  [%3d/%3d] v21_%s_%d\n", k, length(v21_paths), v, yr))
  }

  v21_valid = mapply(climate_cache_valid, v21_paths,
                     MoreArgs = list(points = pond_points),
                     variable = v21_vars, year = v21_years,
                     expected_source = "v21_monthly")
  if (!all(v21_valid))
    stop(sum(!v21_valid), " incomplete V2.1 anchor chunks; rerun to finish.")
  v21 = bind_rows(lapply(v21_paths[v21_valid], read_csv,
                         show_col_types = FALSE, progress = FALSE)) %>%
    group_by(id, variable, month) %>%
    summarise(v21_mean = mean(value, na.rm = TRUE), .groups = "drop")

  bias = paleo %>% filter(slice == SLICE_MODERN) %>%
    select(id, variable, month, trace_slice20 = value) %>%
    inner_join(v21, by = c("id", "variable", "month")) %>%
    mutate(add_offset = ifelse(variable == "pr", NA_real_, trace_slice20 - v21_mean),
           mul_factor = ifelse(variable == "pr" & trace_slice20 > 0,
                               v21_mean / trace_slice20, NA_real_))

  cat("\n--- bias: TraCE21k slice 20 minus V2.1 (degC; pr as ratio) ---\n")
  print(as.data.frame(bias %>% group_by(variable) %>%
    summarise(
      n = n(),
      mean_add = if (all(is.na(add_offset))) NA_real_ else mean(add_offset, na.rm = TRUE),
      min_add = if (all(is.na(add_offset))) NA_real_ else min(add_offset, na.rm = TRUE),
      max_add = if (all(is.na(add_offset))) NA_real_ else max(add_offset, na.rm = TRUE),
      mean_mul = if (all(is.na(mul_factor))) NA_real_ else mean(mul_factor, na.rm = TRUE),
      .groups = "drop"
    )), digits = 3)
  write_csv(bias, OUT_BIAS)

  paleo = paleo %>%
    left_join(bias %>% select(id, variable, month, add_offset, mul_factor),
              by = c("id", "variable", "month")) %>%
    mutate(value_raw = value,
           value_corrected = ifelse(variable == "pr", value * mul_factor,
                                    value - add_offset))

  chk = paleo %>% filter(slice == SLICE_MODERN) %>%
    inner_join(v21, by = c("id", "variable", "month"))
  stopifnot(max(abs(chk$value_corrected - chk$v21_mean), na.rm = TRUE) < 1e-6)
  cat("check: slice 20 now equals the V2.1 reference exactly\n")

} else {
  cat("\n!! BIAS_CORRECT = FALSE - paleo climate is raw TraCE21k, on a different\n",
      "   scale from the V2.1 climate the CCA is calibrated on.\n", sep = "")
  paleo = paleo %>% mutate(value_raw = value, value_corrected = value,
                           add_offset = NA_real_, mul_factor = NA_real_)
}

out = paleo %>%
  left_join(ponds %>% select(id = ID, site), by = "id") %>%
  select(lake = id, site, lon, lat, variable, slice, year_CE, cal_BP, month,
         value_raw, value_corrected, add_offset, mul_factor)

write_csv(out, OUT)
cat("\nwritten: ", OUT, "  (", nrow(out), " rows)\n",
    "Downstream uses value_raw by default; value_corrected is retained for the documented sensitivity run.\n", sep = "")
# END R/stages/000_PALEO_d_climate_download.R

# ============================================================================
# BEGIN R/stages/000_PALEO_e_climate.R
# ============================================================================
# =============================================================================
# 000_PALEO_e_climate.R - paleo_env.csv: climate per dated macrofossil sample
# =============================================================================
# Reads the pond series from 000_PALEO_d_climate_download.R, turns it into the CCA
# variables via the SHARED R/helpers/climate_variables.R, and joins each sample to the
# TraCE21k slice covering its own age.
#
# USES value_raw - the UNCORRECTED TraCE21k. Decided by Billur 2026-08-13,
# reversing the earlier default. Rationale and consequences are in
# docs/SCIENTIFIC_DECISIONS.md
# under "the TraCE21k bias"; the short form:
#   - the correction was ADDITIVE for temperature, and an additive constant
#     CANCELS EXACTLY in any difference. Verified at ~1e-15 in
#     R/diagnostics/test_climate_change_variables.R. So for Dclimate and Dvegetation the
#     choice is provably irrelevant.
#   - for precipitation it was MULTIPLICATIVE, so it scaled every delta. Raw
#     therefore keeps the model's own internal amplitude rather than rescaling
#     it to a modern anchor.
#   - the correction was anchored on ONE slice (slice 20) against V2.1 1979-2021
#     and then applied to all 111 slices, i.e. it assumed the bias is stationary
#     over 11 kyr. That assumption is untestable and the raw series avoids it.
# ⚠ THE COST: offset = pred - obs takes a NORM, so it does NOT cancel there.
# The Holocene offset now carries the full TraCE21k bias. Re-run with
# USE_CORRECTED = TRUE as an explicit sensitivity override.
#
# winter_shift = FALSE: slices are ~100 yr apart, so shifting December into the
# "next" slice would move it a century.
#
# AGE -> SLICE IS A JOIN, NOT AN INTERPOLATION. Slices are the native 100-yr step
# and primary tracking averages ten of them per 1,000-year bin, so interpolating here would
# invent structure the binning then smooths away. paleo_env.csv records which slice
# each sample got and that slice's age, so R/tests/test_paleo_climate_age_match.R can
# verify the match rather than trusting it.
#
# Output: output/paleo_env.csv
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(tidyr); library(readr)})
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/config.R"), local = TRUE)

if (!exists("USE_CORRECTED")) USE_CORRECTED = PALEO_USE_BIAS_CORRECTED

ponds = read_csv(here("output/chelsa_paleo_ponds.csv"), show_col_types = FALSE)
occ   = read_csv(here("output/paleo_occ.csv"),          show_col_types = FALSE)

cat("pond series: ", nrow(ponds), " rows | ", n_distinct(ponds$lake), " lakes | slices ",
    min(ponds$slice), " to ", max(ponds$slice), "\n", sep = "")

# --- climate variables, per lake x slice -------------------------------------
env_slice = ponds %>%
  transmute(unit = lake, period = "paleo", variable, time = slice, month,
            value = if (USE_CORRECTED) value_corrected else value_raw) %>%
  derive_climate_vars(winter_shift = FALSE) %>%
  rename(lake = unit, slice = time) %>%
  mutate(slice_age_calBP = 1950 - slice * 100)

# The winter group of the OLDEST slice has no December from a previous slice and
# the youngest has a December that belongs nowhere - with winter_shift = FALSE
# neither happens, but check the slice set survived intact.
stopifnot(setequal(unique(env_slice$slice), unique(ponds$slice)))
cat("variables built for ", nrow(env_slice), " lake x slice combinations\n", sep = "")

# --- each sample -> the slice covering its age -------------------------------
samples = occ %>%
  distinct(period, plot_id, site, era, lake) %>%
  mutate(age = as.numeric(regmatches(plot_id,
                regexpr("-?[0-9.]+(?=_BP$)", plot_id, perl = TRUE))))
stopifnot(!any(is.na(samples$age)))

nearest_slice = function(age, lake_slices) lake_slices[which.min(abs(lake_slices - age))]

paleo_env = samples %>%
  rowwise() %>%
  mutate(slice_age_calBP = nearest_slice(
    age, env_slice$slice_age_calBP[env_slice$lake == lake])) %>%
  ungroup() %>%
  left_join(env_slice, by = c("lake", "slice_age_calBP")) %>%
  mutate(age_error = slice_age_calBP - age) %>%
  select(period = period.x, plot_id, site, era, lake, age, slice, slice_age_calBP,
         age_error, MAT, MSpT, MST, MWT, AP, SpP, SP, WP,
         ends_with("_min"), ends_with("_max"), ends_with("_mean"))

# --- checks before writing ---------------------------------------------------
cat("\nsamples: ", nrow(paleo_env), " of ", n_distinct(occ$plot_id), "\n", sep = "")
stopifnot(nrow(paleo_env) == n_distinct(occ$plot_id))

ccavars = CCA_VARIABLES
na_n = sapply(paleo_env[ccavars], function(z) sum(is.na(z)))
cat("NA in the CCA variables: ", paste(sprintf("%s=%d", names(na_n), na_n),
    collapse = " "), "\n", sep = "")

cat("\nage match (assigned slice age minus sample age, yr):\n")
print(as.data.frame(paleo_env %>% group_by(lake) %>%
  summarise(n = n(), min = min(age_error), max = max(age_error),
            n_over_50 = sum(abs(age_error) > 50), .groups = "drop")))

cat("\nCCA variable ranges:\n")
print(as.data.frame(t(sapply(paleo_env[ccavars], range))), digits = 4)

write_csv(paleo_env, here("output/paleo_env.csv"))
cat("\nwritten: output/paleo_env.csv\n")
# END R/stages/000_PALEO_e_climate.R

# ============================================================================
# BEGIN R/stages/000_occurrence_data_consolidate.R
# ============================================================================
# =============================================================================
# 000_occurrence_data_consolidate.R
# -----------------------------------------------------------------------------
# ONE place where every cross-site, cross-era taxonomic decision is applied.
#
#   reads   output/MORA_occ.csv   (000_MORA_cleaning.R)
#           output/NOCA_occ.csv   (000_NOCA_cleaning.R)
#           output/paleo_occ.csv  (000_PALEO_b_vegetation.R)
#   writes  output/occ_consolidated.csv   <- the ONLY occurrence input to 05_cca_model.R
#
# Nothing upstream is re-run. The three cleaning scripts keep producing exactly
# what they produce now; this script is a pure transformation on their outputs,
# so a decision here can be changed and re-applied in seconds.
#
# Full prose rationale, with the quotes and the evidence tables:
#   docs/methods/README_occurrence_consolidation.md
#
# =============================================================================
# WHY THERE IS AN UNDERSTORY PROBLEM AT ALL
# =============================================================================
# This study is about OVERSTORY (tree-stratum) communities. Both legacy surveys
# recorded a tree stratum AND a separate understory/shrub stratum, and each site
# put a group of tall shrubs / small trees in the UNDERSTORY one. Both resurveys
# then measured that same group as trees. Left alone, the group produces large
# false colonisations - species that appear to arrive between the surveys purely
# because the second survey counted them and the first did not:
#
#        species              MORA past  MORA present   NOCA past  NOCA present
#        Acer circinatum          0          46             2          19
#        Taxus brevifolia         0          54             6           8
#
# Both were among the 13 species entering the CCA, so this was not cosmetic.
#
# =============================================================================
# HOW "UNDERSTORY" WAS IDENTIFIED  -- from the RAW SURVEY RECORDS, and nothing else
# =============================================================================
# NOT from MORA_spp_lib.csv. That file's `canopy_type` calls ACCI / ACGL / ALSI /
# TABR / SOOC / PREM "overstory_full", which CONTRADICTS the 1978 workbook's own
# metadata (below). The raw workbooks and the legacy publication overrule it.
#
# --- MORA 1978: the workbook states the rule itself -------------------------
# "MORA_Cascade Legacy Data_Original1978.xlsx", sheet `Metadata`, verbatim:
#
#   "Four letter species codes. For trees, these numbers represent stem counts;
#    for understory plants these numbers represent percent cover"
#   "For trees; size class 1 (i.e. ABAM1) = established seedlings (10-140 cm),
#    2 = saplings (dbh 0-20 cm), 3 = poles (20-50), 4 = standards (>50)."
#
# So in sheet `Rainier Veg` a column carrying a TRAILING DIGIT (ABAM1..ABAM4) is
# a tree measured in size classes, and a BARE four-letter column (ACCI, TABR) is
# an understory plant measured as percent cover. The operational test is then:
#
#   MORA measured species X as a tree  <=>  X has size-class columns in
#                                           `Rainier Veg`  OR  X has >0 stems in
#                                           `rawsizedata`
#
# Result (re-derivable; VERIFY_AGAINST_RAW below re-runs it):
#
#   code  size-class cols  bare cover col  rawsizedata stems  verdict
#   ACCI       no               yes               -          UNDERSTORY
#   ACGL       no               yes               -          UNDERSTORY
#   ALSI       no               yes               -          UNDERSTORY
#   TABR       no               yes               0          UNDERSTORY  <- code exists, ZERO stems
#   SOOC       no               yes               -          UNDERSTORY
#   PREM       no               yes               -          UNDERSTORY
#   SASC       no               yes               -          UNDERSTORY
#   CONU       no               yes               -          UNDERSTORY
#   ALRU       no               yes             108          TREE  <- cover AND stems: a real tree
#   PIAL       no               yes               2          TREE
#   POTR      yes               no                6          TREE
#   PISI      yes               no                2          TREE
#   ABPR      yes               no              393          TREE
#
# --- NOCA 1983: two strata in the workbook, and the paper says so ------------
# `AGEEDATA_NEW.xlsx` has SEPARATE `TREE` and `SHRUB` worksheets. Agee & Kertis
# (1987, Can. J. Bot. 65:1520-1530), Methods, verbatim:
#
#   "A dimensioned plot of varying size was used to determine tree density of
#    each species by height class (0-3, 3-10, and > 10 m)."
#
# so `DEN_0-3` / `DEN_3-10` / `DEN >10` are HEIGHT classes in metres and the
# `TREE` sheet is the tree stratum. The test is which sheet holds the species:
#
#   code   legacy SHRUB plots   legacy TREE plots   verdict
#   ACCI          87                   2            UNDERSTORY
#   SOSI          58                   1            UNDERSTORY
#   ALSI          28                   1            UNDERSTORY
#   ACGL          18                   5            UNDERSTORY
#   COST          13                   0            UNDERSTORY
#   PREM           9                   4            UNDERSTORY
#   SARA           8                   0            UNDERSTORY
#   ALRU           2                  23            TREE
#
# Agee & Kertis Table 3 (the published tree list) likewise omits Acer circinatum,
# Alnus sinuata and Sorbus sitchensis, and names Sorbus sitchensis among the
# "dominant shrubs".
#
# --- The rule that follows, and the trap it avoids ---------------------------
# DROP a species if EITHER legacy survey POSITIVELY recorded it in its
# understory/shrub stratum instead of its tree stratum.
#
# ABSENCE from one site's legacy is NOT evidence of understory status - it is a
# real absence. Betula papyrifera, Acer macrophyllum, Pinus ponderosa, Larix
# lyallii and Populus balsamifera have no column at all at MORA and are tree-
# stratum species at NOCA; they are KEPT. Conflating "not recorded" with
# "recorded as understory" would delete genuine species.
#
# The two criteria are independent (a workbook legend at one site, a separate
# worksheet plus a published methods statement at the other) and they agree
# wherever both have evidence - which is why this is a finding and not a choice.
# =============================================================================

library(tidyverse)
library(here)
library(readxl)
source(here("R/helpers/config.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

VERIFY_AGAINST_RAW = TRUE   # re-derive the two tables above from the raw workbooks

# -----------------------------------------------------------------------------
# THE DECISIONS
# -----------------------------------------------------------------------------

# (1) UNDERSTORY - removed from BOTH sites and BOTH eras.
# Every name a taxon appears under anywhere in the three inputs is listed, so a
# synonym cannot slip through. Confirmed 2026-08-13.
UNDERSTORY = c(
  "Acer circinatum",                    # MORA bare cover col; NOCA SHRUB 87 vs TREE 2
  "Acer glabrum",                       # MORA bare cover col; NOCA SHRUB 18 vs TREE 5
  "Alnus alnobetula subsp. sinuata",    # MORA bare cover col (ALSI); NOCA SHRUB 28 vs TREE 1
  "Alnus sinuata", "Alnus viridis", "Alnus crispa",   # same taxon, other spellings
  "Taxus brevifolia",                   # MORA bare cover col AND zero stems in rawsizedata
  "Sorbus sitchensis",                  # MORA bare cover col (SOOC); NOCA SHRUB 58 vs TREE 1
  "Cornus nuttallii",                   # MORA bare cover col (CONU)
  "Cornus sericea", "Cornus stolonifera",  # NOCA SHRUB 13 vs TREE 0; absent at MORA
  "Sambucus racemosa",                  # NOCA SHRUB 8 vs TREE 0; absent at MORA
  "Prunus emarginata",                  # MORA bare cover col; NOCA SHRUB 9 vs TREE 4
  "Salix sp.", "Salix scouleriana", "Salix barclayi",  # MORA bare cover col (SASC)
  "Corylus cornuta"                     # NOCA shrub; 1 plot
)

# (2) NON-TAXA - carry no ecological information, removed everywhere.
#     "Abies sp." is dropped rather than lumped (decided 2026-08-13): its code
#     ABPE sits at 622 and 658 m, where subalpine fir is implausible - NOCA's
#     ABLA plots have a median elevation of 1658 m - and the resurvey Plant List
#     annotates it "Should be some sort of abies ... No existing Abies spp.
#     starting with Pe." An identification nobody can make should not be forced.
NON_TAXA = c("unknown", "Abies sp.", "Unknown tree.")

# (2b) FORMER ANALYSIS EXCLUSION REVERSED - decided 2026-10-08.
# Pinus ponderosa is a valid tree taxon and is retained here. Its former manual
# exclusion was not justified by identification evidence or a general selection
# rule. Site concentration, absence from the Holocene records and an extreme
# ordination position are not exclusion criteria. It now follows the same >=20
# species-selection rule as other tree taxa in 05_cca_model.R.
# The former rationale and the author's reversal are recorded in
# docs/methods/README_occurrence_consolidation.md and SCIENTIFIC_DECISIONS.md.

# (3) TAXONOMIC HARMONISATION.
# Each entry says WHICH SITE and WHICH PERIOD it applies to, because two of the
# three are wrong to apply globally.
RENAMES = tribble(
  ~site,   ~period,     ~from,                 ~to,                    ~why,
  # --- Populus: one taxon recorded under two names ---------------------------
  # Agee & Kertis 1987 Table 3 lists "Populus trichocarpa"; the legacy code is
  # POTR. The resurvey's POAI -> "Populus balsamifera" rests only on the Plant
  # List note "some unknown tree; from Rachel: POPBAL most likely". Applied at
  # both sites so one taxon has one name. Removes a false extinction (NOCA 8->0)
  # and a false colonisation (NOCA 0->2, MORA 0->3).
  "NOCA",  NA,          "Populus balsamifera", "Populus trichocarpa",  "one taxon, two names; Agee 1987 Table 3 uses trichocarpa",
  "MORA",  NA,          "Populus balsamifera", "Populus trichocarpa",  "same taxon as NOCA; see the MORA caveat printed below",

  # --- Picea sitchensis: not a recordable taxon in 1983 ----------------------
  # The AGEEDATA `SPECIES` codebook has 494 entries and exactly one Picea:
  # PIEN. Agee & Kertis Table 3 has no P. sitchensis. So "0 -> 7" cannot be a
  # colonisation - the 1983 crew had no code for it. The 7 resurvey plots are at
  # 966-1691 m (median 1569), far above Sitka spruce's coastal range, and three
  # of them recorded PIEN in 1983 at exactly the elevations Engelmann occupies.
  # NOCA PRESENT ONLY: at MORA, PISI has its own tree size classes (PISI2,
  # PISI4) and stems in rawsizedata, so it is a legitimate species there.
  "NOCA",  "present",   "Picea sitchensis",    "Picea engelmannii",    "no legacy code existed; 966-1691 m is outside Sitka spruce's range",

  # --- Abies procera: NOCA only ---------------------------------------------
  # At MORA this is a real, abundant species - 68 past / 50 present survey plots
  # and 43 Holocene macrofossil samples - so lumping it there would destroy a
  # genuine taxon. At NOCA it is 3 resurvey plots (1402-1564 m), absent from the
  # legacy, and outside the species' main range north of Snoqualmie Pass.
  "NOCA",  NA,          "Abies procera",       "Abies lasiocarpa",     "NOCA ONLY - A. procera is genuine at MORA (68/50 plots, 43 paleo samples)"
)

# -----------------------------------------------------------------------------
# Load the three cleaned sources
# -----------------------------------------------------------------------------
occ = bind_rows(
  read_csv(here("output/MORA_occ.csv"), show_col_types = FALSE) %>%
    transmute(site = "MORA", era = "anthropocene", period, plot_id, species, occurrence),
  read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE) %>%
    transmute(site = "NOCA", era = "anthropocene", period, plot_id, species, occurrence),
  read_csv(here("output/paleo_occ.csv"), show_col_types = FALSE) %>%
    transmute(site, era, period, plot_id, species, occurrence)
)

before = occ %>% filter(occurrence == 1) %>%
  count(site, period, species, name = "n_before")

# -----------------------------------------------------------------------------
# Apply (3) renames -> (2) non-taxa -> (1) understory, in that order
# -----------------------------------------------------------------------------
# One function, so the stage-resolved table below cannot drift from the main one.
# Renames run FIRST, so a name being dropped is dropped under every alias.
apply_decisions = function(x, verbose = FALSE) {
  for (i in seq_len(nrow(RENAMES))) {
    r = RENAMES[i, ]
    hit = x$species == r$from & x$site == r$site &
          (is.na(r$period) | x$period == r$period)
    if (verbose) {
      cat(sprintf("rename  %-4s %-8s %-20s -> %-20s (%s)\n",
                  r$site, coalesce(r$period, "both"), r$from, r$to,
                  if (any(hit)) paste(sum(hit), "records") else "NO RECORDS - check"))
    }
    x$species[hit] = r$to
  }
  x = x %>% filter(!species %in% NON_TAXA, !species %in% UNDERSTORY)
  x
}

occ = apply_decisions(occ, verbose = TRUE)

# A rename can leave two rows for one plot x species (e.g. a plot holding both
# Picea sitchensis and Picea engelmannii). Presence is presence.
occ = occ %>%
  group_by(site, era, period, plot_id, species) %>%
  summarize(occurrence = as.integer(any(occurrence == 1)), .groups = "drop")

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
after = occ %>% filter(occurrence == 1) %>% count(site, period, species, name = "n_after")
delta = full_join(before, after, by = c("site", "period", "species")) %>%
  mutate(across(c(n_before, n_after), ~ replace_na(.x, 0L))) %>%
  filter(n_before != n_after)

cat("\n--- species x site x period records that changed ---\n")
print(as.data.frame(delta %>% arrange(site, period, species)), row.names = FALSE)

cat("\n--- surviving species, plots per site x period ---\n")
print(as.data.frame(occ %>% filter(occurrence == 1) %>%
  count(species, site, period) %>%
  pivot_wider(names_from = c(site, period), values_from = n, values_fill = 0) %>%
  arrange(species)), row.names = FALSE)

# MORA legacy Populus - FIXED UPSTREAM 2026-08-13, verify it stayed fixed.
# MORA_spp_lib.csv's only Populus row is `past_code = "absent_past"`, asserting
# Populus was not recorded in 1978. It was: `rawsizedata` holds POTR in 4 plots.
# With no past_code == "POTR" row the past join returned NA and those plots were
# discarded, so MORA read "Populus 0 past / 3 present" - a false colonisation.
# 000_MORA_cleaning.R now patches past_code IN MEMORY (the CSV is untouched), and
# 3 of the 4 plots come through; the 4th is not in MORA_plot_lib, i.e. not a
# survey-resurvey plot, so dropping it is correct.
mora_pop = occ %>% filter(site == "MORA", species == "Populus trichocarpa", occurrence == 1) %>% count(period)
cat("\nMORA Populus trichocarpa (was 0 past / 3 present before the upstream fix):\n")
print(as.data.frame(mora_pop), row.names = FALSE)
if (!"past" %in% mora_pop$period)
  warning("MORA legacy Populus is missing again - check the POTR past_code patch ",
          "in 000_MORA_cleaning.R")

# ⚠ Juniperus communis is a prostrate shrub and survives here because it occurs
# ONLY in the NOCA Holocene macrofossils, where no legacy survey stratum exists
# to test it against. It is far below count.thr so it never enters the CCA.
cat("\nNOTE - Juniperus communis (NOCA paleo only, 8 samples) is a shrub but has\n",
    "  no survey-stratum evidence either way; kept, and it never reaches the CCA.\n", sep = "")

write_csv(occ, here("output/occ_consolidated.csv"))
cat("\nWrote output/occ_consolidated.csv:", nrow(occ), "rows,",
    n_distinct(occ$species), "species,", n_distinct(occ$plot_id), "samples\n")

# =============================================================================
# SPECIES COUNTS - the evidence for choosing count.thr
# =============================================================================
# Absorbed from the removed historical species-count diagnostic, which built this from the UNCONSOLIDATED
# tables and so counted species that no longer exist and split taxa that are now
# merged. The threshold must be chosen on the data the CCA will actually see.
#
# NOTHING IS FILTERED OR DECIDED HERE. This block reports the RAW EVIDENCE - how
# many plots each species occupies in each site x period. The threshold itself
# lives at the top of 05_cca_model.R as `count.thr`, so it can be swept:
#
#   for (thr in c(10, 15, 20, 25, 30)) { count.thr = thr; source("R/stages/05_cca_model.R") }
#
# The rule there: a species is DROPPED only if it is below the threshold in EVERY
# site x period group - so a species common in one group survives even if it is
# rare everywhere else. That is why max_group below is the number to compare a
# candidate threshold against.
counts = occ %>%
  filter(occurrence == 1) %>%
  distinct(site, period, species, plot_id) %>%
  count(site, period, species, name = "n") %>%
  pivot_wider(names_from = c(site, period), values_from = n, values_fill = 0)

grp = setdiff(names(counts), "species")
counts = counts %>%
  mutate(max_group = do.call(pmax, c(across(all_of(grp)), na.rm = TRUE))) %>%
  arrange(desc(max_group))

cat("\n=== plots (or paleo samples) per species, by site x period ===\n")
cat("    max_group = the largest count in any one group. A candidate count.thr\n",
    "    is compared against THIS, because 05_cca_model.R drops a species only\n",
    "    if it is below the cut-off in every group. Set the threshold there.\n", sep = "")
print(as.data.frame(counts), row.names = FALSE)

# --- figure -----------------------------------------------------------------
color_era = c("paleo" = "#44AA99", "past" = "#88CCEE", "present" = "#CC6677")
cnt_long = occ %>%
  filter(occurrence == 1) %>%
  distinct(site, period, species, plot_id) %>%
  count(site, period, species, name = "n") %>%
  mutate(species = factor(species, levels = rev(counts$species)),
         period  = factor(period, levels = c("paleo", "past", "present")))

p_counts = ggplot(cnt_long, aes(species, n, fill = period)) +
  geom_col(position = position_dodge(preserve = "single"), width = 0.75) +
  geom_hline(yintercept = CCA_COUNT_THRESHOLD, linetype = "dashed",
             colour = "#B03A2E", linewidth = 0.5) +
  scale_fill_manual(values = color_era,
                    labels = c(paleo = "Holocene", past = "Legacy", present = "Resurvey")) +
  facet_wrap(~ site, scales = "free_x") +
  coord_flip() +
  labs(x = NULL, y = "Number of plots (Holocene: number of samples)", fill = "Period",
       title = "Species occurrence after consolidation",
       subtitle = paste0("Dashed line: selection threshold of ", CCA_COUNT_THRESHOLD, " plots or samples.\n",
                         "A species is retained if it reaches the threshold in any site and period.\n",
                         "Understory and unresolved taxa are removed; ponderosa pine is retained.")) +
  theme_minimal(base_size = 16) +
  theme(plot.title = element_text(size = 18, face = "bold"),
        plot.subtitle = element_text(size = 14),
        axis.text = element_text(size = 14),
        strip.text = element_text(size = 16, face = "bold"),
        legend.text = element_text(size = 14),
        panel.grid.major.y = element_blank(),
        legend.position = "top")

if (render_figures) {
  ggsave(here("plot/test_figures/species_counts_consolidated.pdf"), p_counts,
         width = 11, height = 8)
  cat("\nWrote plot/test_figures/species_counts_consolidated.pdf\n")
}

# =============================================================================
# ADULT vs SEEDLING / REGENERATION
# =============================================================================
# Absorbed from the removed historical stage diagnostic, which had to source() BOTH
# cleaning scripts to reach their in-memory raw objects - and so rewrote
# MORA_occ.csv, NOCA_occ.csv and two PDFs every time it ran. The cleaning scripts
# now write MORA_occ_stage.csv / NOCA_occ_stage.csv, so this reads files and has
# no side effects.
#
# Presence-based (number of plots a species occupies at each stage) because the
# raw counts are in incompatible units across the four datasets.
#
# ⚠ REGENERATION IS NOT MEASURED THE SAME WAY IN THE TWO ERAS AT NOCA:
#     NOCA past    regeneration = legacy 0-3 m HEIGHT class (Agee & Kertis 1987)
#                  adult        = 3-10 m and >10 m height classes
#     NOCA present regeneration = JHRL Seedlings tallies (10-140 cm)
#                  adult        = Tree Data stems (DBH, i.e. >1.4 m)
#     MORA both    regeneration = 10-140 cm;  adult = DBH / tree records
# So NOCA's "past regeneration" spans a taller band (to 3 m) than every other
# regeneration cell (to 1.4 m). ADULTS are comparable throughout; REGENERATION is
# a proxy and the past-vs-present regeneration contrast at NOCA is confounded by
# the band width. This is stated on the figure, not buried here.
SEED = "Seedling / regeneration"; ADULT = "Adult"

stage = bind_rows(
  read_csv(here("output/MORA_occ_stage.csv"), show_col_types = FALSE) %>% mutate(site = "MORA"),
  read_csv(here("output/NOCA_occ_stage.csv"), show_col_types = FALSE) %>% mutate(site = "NOCA")
) %>%
  # MORA writes "adult"/"seedling", NOCA writes "Adult"/"Seedling / regeneration"
  mutate(stage = if_else(str_starts(str_to_lower(stage), "a"), ADULT, SEED),
         era = "anthropocene") %>%
  apply_decisions() %>%
  distinct(site, period, plot_id, species, stage)

# the stage table must not contain a species the consolidated table dropped
stopifnot(all(stage$species %in% occ$species))

stage_counts = stage %>% count(site, period, species, stage, name = "n_plots")

sp_ord = stage_counts %>% group_by(species) %>%
  summarize(t = sum(n_plots), .groups = "drop") %>% arrange(t) %>% pull(species)

stage_counts = stage_counts %>%
  mutate(species = factor(species, levels = sp_ord),
         period  = factor(period,  levels = c("past", "present")),
         site    = factor(site,    levels = c("MORA", "NOCA")),
         stage   = factor(stage,   levels = c(ADULT, SEED)))

p_stage = ggplot(stage_counts, aes(species, n_plots, fill = period)) +
  geom_col(position = position_dodge(preserve = "single"), width = 0.75) +
  facet_grid(site ~ stage) +
  coord_flip() +
  scale_fill_manual(values = c(past = "#88CCEE", present = "#CC6677"),
                    labels = c(past = "Legacy", present = "Resurvey"), name = "Period") +
  labs(x = NULL, y = "Number of plots",
       title = "Adults and regeneration: legacy versus resurvey",
       subtitle = "Plots per species at each vegetation stage.\nConsolidated tree taxa; understory taxa excluded.",
       caption = paste0("NOCA adults: >3 m in legacy surveys; >1.4 m in resurveys.\n",
                        "NOCA regeneration: 0-3 m in legacy surveys; 10-140 cm in resurveys. MORA: 10-140 cm at both dates.\n",
                        "The NOCA legacy versus resurvey regeneration comparison therefore uses different height bands.")) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "top",
        panel.grid.major.y = element_blank(),
        axis.text = element_text(size = 14),
        axis.text.y = element_text(size = 14, face = "italic"),
        strip.text = element_text(size = 16, face = "bold"),
        legend.text = element_text(size = 14),
        plot.title = element_text(size = 18, face = "bold"),
        plot.subtitle = element_text(size = 14),
        plot.caption = element_text(size = 12, hjust = 0, colour = "grey35"))

if (render_figures) {
  ggsave(here("plot/test_figures/stage_adult_seedling_past_present.pdf"), p_stage,
         width = 12, height = 12)
}

cat("\n=== adult vs regeneration, plot occupancy ===\n")
print(as.data.frame(stage_counts %>% group_by(site, period, stage) %>%
  summarize(species = n(), plot_occurrences = sum(n_plots), .groups = "drop")), row.names = FALSE)
if (render_figures)
  cat("\nWrote plot/test_figures/stage_adult_seedling_past_present.pdf\n")

# =============================================================================
# VERIFICATION - re-derive the classification from the raw workbooks
# =============================================================================
# The lists above are written out explicitly so they can be read and argued
# with. This block re-derives the evidence from the raw files and stops if the
# data no longer supports it, so the two cannot drift apart.
if (VERIFY_AGAINST_RAW) {
  cat("\n--- verifying the understory classification against the raw workbooks ---\n")

  f    = here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx")
  veg  = read_excel(f, sheet = "Rainier Veg")
  size = read_excel(f, sheet = "rawsizedata")

  tree_cols = unique(substr(grep("^[A-Z]{4}[1-4]$", names(veg), value = TRUE), 1, 4))
  bare_cols = setdiff(grep("^[A-Z]{4}$", names(veg), value = TRUE), "SiteName")
  stems = size %>% mutate(n = rowSums(across(DBH0:`>DBH120`), na.rm = TRUE)) %>%
    group_by(Species) %>% summarize(stems = sum(n), .groups = "drop")

  mora_is_tree = function(code) {
    s = stems$stems[stems$Species == code]
    code %in% tree_cols || (length(s) == 1 && s > 0)
  }
  # every MORA code we call understory must be a bare cover column AND not a tree
  mora_understory_codes = c("ACCI","ACGL","ALSI","TABR","SOOC","PREM","SASC","CONU")
  for (cd in mora_understory_codes) {
    stopifnot(cd %in% bare_cols)     # recorded as understory percent cover
    stopifnot(!mora_is_tree(cd))     # and never measured as a tree
  }
  # and the ones we keep must be trees
  for (cd in c("ALRU","PIAL","POTR","PISI","ABPR")) stopifnot(mora_is_tree(cd))
  cat("  MORA: 8 understory codes confirmed cover-only; 5 kept codes confirmed trees\n")

  A  = here("data/NOCA/AGEEDATA_NEW.xlsx")
  tr = read_excel(A, sheet = "TREE")
  sh = read_excel(A, sheet = "SHRUB") %>% select(PLOT, starts_with("SPEC")) %>%
    pivot_longer(-PLOT, values_to = "code") %>% filter(!is.na(code))
  nplots = function(tbl, cd, col) length(unique(tbl[[1]][tbl[[col]] == cd]))
  shrub_n = function(cd) n_distinct(sh$PLOT[sh$code == cd])
  tree_n  = function(cd) n_distinct(tr$PLOT[tr$SPEC == cd])
  for (cd in c("ACCI","SOSI","ALSI","ACGL","COST","PREM","SARA")) {
    stopifnot(shrub_n(cd) > tree_n(cd))   # predominantly the shrub stratum
  }
  stopifnot(tree_n("ALRU") > shrub_n("ALRU"))   # Alnus rubra is the tree-stratum control
  cat("  NOCA: 7 understory codes confirmed SHRUB-dominant; ALRU confirmed TREE-dominant\n")

  # the legacy codebook really has no Sitka spruce
  sp = read_excel(A, sheet = "SPECIES")
  stopifnot(!"PISI" %in% sp$CODE)
  stopifnot("PIEN" %in% sp$CODE)
  cat("  NOCA: legacy codebook has PIEN and no PISI - confirmed\n")

  cat("  all checks passed\n")
}
# END R/stages/000_occurrence_data_consolidate.R

# ============================================================================
# BEGIN R/stages/05_cca_model.R
# ============================================================================
# =============================================================================
# 05_cca_model.R - the pooled CCA and everything derived from it. NO FIGURES.
# =============================================================================
# This file defines the ordination without rendering figures and is sourced by
# the downstream analysis and figure stages.
#
# THE MODEL: one pooled CCA trained on matched MORA + NOCA "past" plots, constrained
# by MSpT + MWT + SP + WP. "present" and "paleo" samples are projected into it -
# they do not calibrate it. Because there is a single ordination, positions and
# lengths are directly comparable across both sites and both eras.
#
# Defines:
#   cca_model                          the pooled CCA
#   species_past_final, env_past_final  the calibration matrices
#   predicted_present / projected_present, predicted_paleo / projected_paleo
#   comparison_df   per-sample predicted (LC) + observed (WA) positions, all eras
#   env, species_complete, site_lookup, keep_species
#   cca_sample_eligibility / cca_pair_eligibility  exclusion reasons and membership
#   cca_eligibility_counts / cca_exclusion_summary  report tables, before fitting
#   species_past_paired / env_past_paired  legacy endpoints of valid modern pairs
#   color_mt, color_site_era, color_era_pp
#
library(here)
library(tidyverse)
library(vegan)
conflicted::conflicts_prefer(dplyr::select, dplyr::filter, dplyr::lag, .quiet = TRUE)
source(here("R/helpers/config.R"), local = TRUE)

# Run configuration ----------------------------------------------------------
# EVERY knob for this model is here, and every one is `if (!exists())`, so a
# calling script can set any of them before source()-ing to run a variant
# without editing this file:
#
#   count.thr = 10; source(here("R/stages/05_cca_model.R"))
#
# Taxus brevifolia and Acer circinatum are removed by the documented understory
# rule in R/stages/000_occurrence_data_consolidate.R. The former manual exclusion
# of Pinus ponderosa was reversed on 2026-10-08; it now follows the ordinary
# frequency rule below. There is one active model and no extra exclusion by default.
if (!exists("extra_exclude")) extra_exclude = character(0)
if (!exists("cca_suffix"))    cca_suffix    = ""

# SPECIES INCLUSION THRESHOLD --------------------------------------------------
# A species is dropped only if it occurs in fewer than count.thr plots in EVERY
# site x period group - so a species common in one group survives even if it is
# rare in the others. Set it here, not in the consolidation script, because the
# whole point is to be able to sweep it:
#
#   for (thr in c(10, 15, 20, 25, 30)) { count.thr = thr; source(...); ... }
#
# The evidence for choosing it - plots per species per site x period - is printed
# and plotted by R/stages/000_occurrence_data_consolidate.R. On the consolidated species
# set after the 2026 NOCA correction and the BAK487/BEAV6061 exclusions:
# 10 and 15 -> 15 species, 20 -> 13, 25 -> 11, and 30 -> 10.
#
# SET TO 20 by Billur, 2026-08-13. History: 25 (inherited) -> 10 -> 20.
#
# 10 was chosen as the low end of a plateau (10 and 15 give the identical
# 15-species set) and to add calibration plots. It was reverted to 20 because
# the resulting ordination was unsatisfactory. After the corrected NOCA trees,
# the TWO species that 10 admits and 20 does not are:
#
#                     MORA_paleo  MORA_past  MORA_present  NOCA_paleo  NOCA_past  NOCA_present
#   Alnus rubra            0         15           16            0          11          18
#   Acer macrophyllum      0          0            4            0          17          19
#
# Both are zero in both paleo columns. They exist only in the survey
# plots, so they widen the CALIBRATION while contributing nothing whatever to the
# Holocene arm - they add unconstrained variance to the axes the Holocene
# samples are projected onto. (Pinus albicaulis is NOT among them; it survives at
# 20. An earlier archived plan listed it as a fourth species gained at 10,
# which was wrong.) The 2026 NOCA tree correction raised Abies grandis from 19
# to 22 NOCA-present plots, so it now legitimately survives threshold 20.
#
# Historical threshold comparison: constrained inertia rose from 13.4% to 16.3%.
# These are historical diagnostics, not the current fit's summary. That is NOT
# the justification and must not be quoted as one: it rises mechanically as
# species are removed, because there is less total inertia left to explain. The
# justification is the one above - which species, and whether they exist in both
# arms.
#
# ⚠⚠ DO NOT RAISE count.thr TO 21 OR ABOVE WITHOUT READING THIS.
# Pinus albicaulis survives at exactly 20, by ONE PLOT: its largest group count is
# NOCA past = 20, and a species is kept only while some group reaches count.thr.
# It is KEPT DELIBERATELY (Billur, 2026-08-13) because whitebark pine is a listed
# species - ESA-threatened, IUCN endangered - so its presence/absence is of
# interest in its own right, independent of what it does to the ordination.
# At count.thr = 21 it disappears silently. No other retained species is anywhere
# near the edge: the next-lowest max group count is Picea engelmannii at 26, then
# a jump to 68. So count.thr = 20 is now pinned by this decision as well as by
# the axis-interpretability argument above.
if (!exists("count.thr")) count.thr = CCA_COUNT_THRESHOLD

# ⚠ WHAT KEEPING IT COSTS - to be reported, not fixed:
# The following numbers record the historical threshold decision; current
# coordinates and inertia must be read from the rebuilt model/report.
#   occurrences  MORA 0 paleo / 0 past / 2 present | NOCA 0 paleo / 20 past / 7 present
#   position     CCA1 3.57, CCA2 4.39 - the extreme of BOTH axes; the next most
#                extreme are Abies lasiocarpa (1.80) and Pinus contorta (2.75)
#   share        14.9% of the constrained inertia, the largest of any species
# It is not detected in either paleo record and is concentrated at NOCA
# (27 survey-date occurrences vs 2 at MORA). Its position affects the CCA1-CCA2
# plane in which distances are measured. These features are not exclusion rules:
# Pinus ponderosa's former exclusion for similar reasons was reversed on
# 2026-10-08. Both species now follow the same frequency-selection rule.

# ORDINATION SCALING -----------------------------------------------------------
# "sites" (vegan scaling 1): SITE scores are scaled by the eigenvalues, species
# scores are left unscaled. Chosen because every quantity in this analysis is a
# distance or a displacement between SAMPLE positions, and scaling 1 is the
# scaling in which Euclidean distance among samples represents their chi-square
# distance. Under "none"/"species" (0/2) sites are in standard coordinates, where
# each axis carries equal metric weight regardless of its eigenvalue - so CCA2
# would count as much per unit of displacement as CCA1 despite different inertia.
#
# Nothing is lost on the species side: with scaling 1 the species scores are
# left unscaled, i.e. bit-identical to scaling 0, and species rank order and sign
# along each axis are identical under these positive scalings. Two-axis angles
# are not invariant to unequal axis scaling; all metrics use the selected scaling.
#
# Set cca_scaling = "sites" with hill = TRUE to express site scores in SD units
# of species turnover instead (gradient lengths CCA1 3.28 SD, CCA2 3.96 SD).
if (!exists("cca_scaling")) cca_scaling = "sites"
if (!exists("cca_hill"))    cca_hill    = FALSE

color_mt       = c("MORA" = "#648FFF", "NOCA" = "#FE6100")
color_site_era = c("MORA.anthropocene" = "#648FFF", "NOCA.anthropocene" = "#FE6100",
                   "MORA.holocene"     = "#648FFF", "NOCA.holocene"     = "#FE6100")
color_era_pp   = c("anthropocene" = "#DC267F", "holocene" = "#785EF0")

# -----------------------------------------------------------------------------
# CCA ELIGIBILITY POLICY: resolve absence BEFORE fitting or projecting
# -----------------------------------------------------------------------------
# Species selection remains here, with the configured >= count.thr rule.
# An all-zero retained-taxon row has no observed WA position (0/0), including
# genuine recorded absence. Never assign it the ordination origin or keep its
# climate prediction in a paired WA/LC comparison.
#
# The preparation section below applies this policy after climate and species
# matrices exist, but BEFORE cca(). It distinguishes cleaned recorded absence,
# consolidation exclusions, frequency exclusions, and unavailable climate.
# Legacy calibration and modern comparisons use the SAME valid matched plot IDs
# at both dates (decision 2026-10-08); paleo WA and LC use the SAME samples.
# Recorded loss at resurvey is absence of the study's recorded tree taxa, not
# proof of biological extinction. A zero macrofossil sample is non-detection.
# Counts are unique plots/samples, not species records, age draws or time bins.
cca_classify_samples = function(cleaned, consolidated, selected_taxa,
                                calibration_taxa, climate, variables) {
  keys = c("site", "era", "period", "plot_id")
  if (anyDuplicated(climate[keys])) stop("Duplicate climate sample keys in CCA eligibility.")
  for (x in list(cleaned, consolidated)) {
    if (anyNA(x[c(keys, "species", "occurrence")]) ||
        any(!x$occurrence %in% 0:1)) stop("CCA eligibility requires identified binary occurrence records.")
  }
  count_taxa = function(x, name, taxa = unique(x$species)) {
    x %>% filter(occurrence == 1, species %in% taxa) %>%
      group_by(across(all_of(keys))) %>%
      summarize(!!name := n_distinct(species), .groups = "drop")
  }
  out = bind_rows(cleaned %>% distinct(across(all_of(keys))),
                  climate %>% distinct(across(all_of(keys)))) %>% distinct() %>%
    left_join(cleaned %>% distinct(across(all_of(keys))) %>%
                mutate(has_occurrence_record = TRUE), by = keys) %>%
    left_join(count_taxa(cleaned, "cleaned_taxa"), by = keys) %>%
    left_join(count_taxa(consolidated, "consolidated_taxa"), by = keys) %>%
    left_join(count_taxa(consolidated, "selected_taxa", selected_taxa), by = keys) %>%
    left_join(count_taxa(consolidated, "calibration_taxa", calibration_taxa), by = keys) %>%
    left_join(climate %>% select(all_of(c(keys, variables))) %>%
                mutate(climate_complete = if_all(all_of(variables), is.finite)) %>%
                select(all_of(keys), climate_complete), by = keys) %>%
    mutate(across(ends_with("_taxa"), ~ replace_na(.x, 0L)),
           has_occurrence_record = replace_na(has_occurrence_record, FALSE),
           climate_complete = replace_na(climate_complete, FALSE))
  legacy = out %>% filter(period == "past") %>%
    select(site, plot_id, legacy_cleaned_taxa = cleaned_taxa)
  out %>% left_join(legacy, by = c("site", "plot_id")) %>%
    mutate(
      reason_code = case_when(
        !has_occurrence_record ~ "missing_occurrence",
        cleaned_taxa == 0 ~ "no_recorded_taxa",
        consolidated_taxa == 0 ~ "consolidation",
        selected_taxa == 0 ~ "species_selection",
        calibration_taxa == 0 ~ "no_calibration_taxa",
        !climate_complete ~ "climate",
        TRUE ~ "included"),
      reason = case_when(
        reason_code == "missing_occurrence" ~ "No cleaned occurrence record",
        reason_code == "no_recorded_taxa" & period == "past" ~ "No tree taxa recorded at legacy",
        reason_code == "no_recorded_taxa" & period == "present" &
          coalesce(legacy_cleaned_taxa, 0L) > 0 ~ "Loss of all recorded tree-taxon presence at resurvey",
        reason_code == "no_recorded_taxa" & period == "present" ~ "No tree taxa recorded at resurvey",
        reason_code == "no_recorded_taxa" ~ "No tree taxa detected in paleo sample",
        reason_code == "consolidation" ~ "Only taxa excluded during consolidation",
        reason_code == "species_selection" ~ "Only taxa excluded by CCA species selection",
        reason_code == "no_calibration_taxa" ~ "Only taxa absent from legacy calibration",
        reason_code == "climate" ~ "Missing or nonfinite CCA climate constraints",
        TRUE ~ "Included"),
      eligible = reason_code == "included") %>%
    arrange(era, site, plot_id, period)
}

cca_pair_samples = function(samples) {
  past = samples %>% filter(period == "past") %>%
    select(site, plot_id, legacy_eligible = eligible,
           legacy_reason_code = reason_code, legacy_reason = reason)
  present = samples %>% filter(period == "present") %>%
    select(site, plot_id, resurvey_eligible = eligible,
           resurvey_reason_code = reason_code, resurvey_reason = reason)
  full_join(past, present, by = c("site", "plot_id")) %>%
    mutate(
      calibration_included = coalesce(legacy_eligible & resurvey_eligible, FALSE),
      comparison_included = coalesce(legacy_eligible & resurvey_eligible, FALSE),
      # One primary reason per excluded pair: legacy first, then resurvey.
      # The sample audit keeps BOTH dates' local reasons and taxon counts.
      exclusion_period = case_when(is.na(legacy_eligible) | !legacy_eligible ~ "past",
                                    is.na(resurvey_eligible) | !resurvey_eligible ~ "present",
                                    TRUE ~ NA_character_),
      reason_code = case_when(is.na(legacy_eligible) | is.na(resurvey_eligible) ~ "missing_period",
                              !legacy_eligible ~ legacy_reason_code,
                              !resurvey_eligible ~ resurvey_reason_code,
                              TRUE ~ "included"),
      reason = case_when(is.na(legacy_eligible) ~ "No matched legacy observation",
                         is.na(resurvey_eligible) ~ "No matched resurvey observation",
                         !legacy_eligible ~ legacy_reason,
                         !resurvey_eligible ~ resurvey_reason,
                         TRUE ~ "Included")) %>% arrange(site, plot_id)
}

# -----------------------------------------------------------------------------
# Occurrence data
# -----------------------------------------------------------------------------
# ONE input, already consolidated. R/stages/000_occurrence_data_consolidate.R binds the
# three cleaned sources and applies every cross-site taxonomic decision - the
# understory removal, the Populus/Picea/Abies harmonisation, the non-taxa drops -
# with the evidence for each written out beside it. Run that script if any of
# those decisions changes; do NOT re-derive them here, and do not re-run the
# cleaning scripts, which have side effects.
#
# The ad-hoc filter that used to live on this line
#     filter(!species %in% c("unknown", "Abies sp.", "Salix sp."))
# is now part of that script, where it is justified rather than asserted.
occ_consolidated = read_csv(here("output/occ_consolidated.csv"), show_col_types = FALSE) %>%
  select(period, plot_id, species, occurrence, site, era)
occ = occ_consolidated

# Species selection: drop species occurring in fewer than count.thr plots in
# every site x period, plus any run-specific exclusions.
#
# TSUGA HETEROPHYLLA IS NOW KEPT (decided 2026-08-13). It had been dropped by
# hand since the earliest version of this analysis. Three reasons for reversing:
#
# 1. The exclusion was never justified. The original model had the bare
#    line with no comment; a historical species-count diagnostic also
#    recorded that its exclusion was undocumented. The "range truncation, see
#    HilleRisLambers et al. 2015 Appendix B" note that used to sit here was
#    reconstructed after the fact, not carried over from the original author.
#
# 2. That citation does not single it out. HilleRisLambers et al. 2015 says
#    elevational range limits were estimated "for three species (Abies amabilis,
#    Callitropsis nootkatensis, Tsuga mertensiana), but not for the three species
#    whose ranges extend to elevations below the lowest elevation of the park
#    (Pseudotsuga menziesii, Thuja plicata, Tsuga heterophylla)". It names THREE
#    truncated species; this script dropped one and kept the other two, which are
#    among the most abundant in the dataset. That is not a defensible reading.
#
# 3. The data do not support it. At MORA (lowest plot 541 m) the species sitting
#    on the lower bound are Abies amabilis, Tsuga heterophylla, Pseudotsuga
#    menziesii AND Thuja plicata - truncation is a property of where the plots
#    stop, not of this species. Its MORA median (1091 m) is HIGHER than Thuja
#    plicata's (907) and Pseudotsuga's (1040), so it is mid-gradient, not edge-
#    clinging. It is also one of the best-represented taxa in the whole study:
#    281/283 MORA survey plots, 91/108 NOCA, and present in BOTH paleo records
#    (MORA 54, NOCA 179 samples).
#
# The paper's concern is estimating where a range EDGE lies, which needs the
# whole range sampled. This analysis ordinates composition, where a species whose
# range continues past the sampled window is ordinary rather than disqualifying.
#
occ_summary = occ %>%
  filter(occurrence == 1) %>%
  group_by(site, period, species) %>%
  summarize(count = n(), .groups = "drop") %>%
  pivot_wider(names_from = c("site", "period"), values_from = "count", values_fill = 0)

# count.thr is set in the run-configuration block at the top of this file.
# NOCA_paleo belongs here and was missing: the condition dates from when
# PantherPotholes had no macrofossil data, so a species common ONLY in NOCA's
# Holocene record would have been dropped. Verified that adding it changes
# nothing today - both versions drop the same species - so this is a latent bug
# made correct by construction, not a change to the current model.
takeoutsp = occ_summary %>%
  filter(MORA_past < count.thr & MORA_present < count.thr &
           NOCA_past < count.thr & NOCA_present < count.thr &
           MORA_paleo < count.thr & NOCA_paleo < count.thr) %>%
  pull(species) %>% unique()
takeoutsp = c(takeoutsp, extra_exclude)
occ = occ %>% filter(!species %in% takeoutsp)

# -----------------------------------------------------------------------------
# Fire and climate
# -----------------------------------------------------------------------------
NOCA_plot_info_fire = read_csv(here("output/NOCA_plot_info_fire.csv"), show_col_types = FALSE)
MORA_plot_info_fire = read_csv(here("output/MORA_plot_info_fire.csv"), show_col_types = FALSE)

# Paleo fire now exists for BOTH sites - NOCA's came from Neotoma dataset 52210
# (see data/NOCA/NOCA_paleo/SOURCES.md), so the site is read from the lake instead of being
# hardcoded to "MORA" as it was while PantherPotholes had no charcoal.
# The two sites' fire evidence is not the same KIND (MORA = in-core Dunwiddie
# percentages plus a REGIONAL Walsh proxy from three other lakes; NOCA = in-core
# macrocharcoal from its own core) - that is a reporting caveat, not a data fix.
paleo_info_fire = read_csv(here("output/paleo_fire.csv"), show_col_types = FALSE) %>%
  mutate(burnt = fire_peak_magnitude > 0,
         site  = if_else(lake == "PantherPotholes", "NOCA", "MORA"),
         era   = "holocene")

fire_summary = bind_rows(
  NOCA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "NOCA"),
  MORA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "MORA")
) %>%
  mutate(era = "anthropocene") %>%
  bind_rows(paleo_info_fire %>% select(plot_id, burnt, site, era))

# -----------------------------------------------------------------------------
# Anthropocene climate: raw monthly -> CCA variables -> one value per survey window
# -----------------------------------------------------------------------------
# Replaces the retired climate summary, which carried a FIXED 1981-86
# "past" climatology that
# post-dated MORA's survey by ~8 yr and NOCA's by ~2 - unequally, between the two
# sites the whole study differences against each other.
#
# 000_MORA_climate.R / 000_NOCA_climate.R now write RAW MONTHLY tasmin/tasmax/pr
# for each plot over that site's own survey window (max survey year and the five
# before it). derive_climate_vars() turns them into the CCA variables and is the
# SAME function 000_PALEO_e_climate.R uses, so a season cannot mean one thing in
# the Holocene arm and another in the Anthropocene arm.
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
plot_years = read_plot_years()

climate_monthly = bind_rows(
  read_csv(here("output/MORA_climate.csv"), show_col_types = FALSE),
  read_csv(here("output/NOCA_climate.csv"), show_col_types = FALSE)
) %>% restrict_modern_months(plot_years)

# site is folded into the grouping key because derive_climate_vars() groups by
# unit x period, and "past" means a different set of years at the two sites.
climate_annual = climate_monthly %>%
  transmute(unit = plot_id, period = paste(site, period, sep = "."),
            variable, time = year, month, value) %>%
  derive_climate_vars(winter_shift = TRUE) %>%
  restrict_modern_seasons(plot_years) %>%
  # winter_shift moves each December into the FOLLOWING winter, so the last
  # December of a window opens a trailing year that holds nothing else. Restricting
  # to the plot-specific season-years removes it. Dropping
  # rows where every CCA variable is NA removes it, and removes the lead-in year
  # for the same reason, without hardcoding the windows a third time.
  filter(if_any(all_of(CCA_VARIABLES), ~ !is.na(.x)))

# Average the surviving years of each window. n_* records HOW MANY complete
# season-years each variable actually got. The missing January 1979 removes that
# first winter, leaving 10 complete legacy MWT/WP years; spring and summer retain
# all 11 years. These counts stay visible rather than being silently assumed.
climate_summary = climate_annual %>%
  group_by(unit, period) %>%
  # both statistics in ONE across(): a second across() referring to MWT would read
  # the mean the first one had just created, and every count would come out as 1.
  summarize(across(all_of(CCA_VARIABLES),
                   list(v = ~ mean(.x, na.rm = TRUE), n = ~ sum(!is.na(.x))),
                   .names = "{.fn}|{.col}"),
            .groups = "drop") %>%
  rename_with(~ sub("^v\\|", "",   .x), starts_with("v|")) %>%
  rename_with(~ sub("^n\\|", "n_", .x), starts_with("n|")) %>%
  separate_wider_delim(period, ".", names = c("site", "period")) %>%
  rename(plot_id = unit) %>%
  mutate(era = "anthropocene")

if (any(as.matrix(climate_summary %>% filter(period == "present") %>%
      select(starts_with("n_"))) != 6L))
  stop("Every modern CCA climate constraint requires six complete season-years.")

cat("\nAnthropocene climate - complete season-years per window:\n")
print(as.data.frame(climate_summary %>% group_by(site, period) %>%
  summarize(plots = n(), across(starts_with("n_"), max), .groups = "drop")))

paleo_climate_summary = read_csv(here("output/paleo_env.csv"), show_col_types = FALSE)

env = bind_rows(
  climate_summary %>% select(site, era, period, plot_id, all_of(CCA_VARIABLES)),
  paleo_climate_summary %>% select(site, era, period, plot_id, all_of(CCA_VARIABLES))
) %>%
  left_join(fire_summary, by = c("plot_id", "site", "era"))

# The fire join must not multiply rows. paleo_fire's plot_id is built from the
# AGE, so core depths whose Bacon ages round to the same year collide - three
# ReflectionPond depths at 3641 cal BP did, and tripled that sample in the CCA
# until 000_PALEO_c_fire.R was made to collapse them the way the vegetation is.
stopifnot(!any(duplicated(env %>% select(plot_id, site, era, period))))

site_lookup = env %>% distinct(plot_id, site)

# -----------------------------------------------------------------------------
# Species x plot matrices
# -----------------------------------------------------------------------------
all_combinations = expand_grid(
  plot_id = unique(occ$plot_id),
  period  = unique(occ$period),
  species = unique(occ$species)
)
species_complete = all_combinations %>%
  left_join(occ, by = c("plot_id", "period", "species")) %>%
  mutate(occurrence = replace_na(occurrence, 0)) %>%
  select(plot_id, period, species, occurrence)

make_wide = function(per) {
  species_complete %>%
    filter(period == per) %>%
    group_by(plot_id, species) %>%
    summarize(occurrence = as.integer(sum(occurrence) > 0), .groups = "drop") %>%
    pivot_wider(names_from = species, values_from = occurrence, values_fill = 0) %>%
    column_to_rownames("plot_id")
}
# This filter is where 30 paleo samples used to vanish without trace: before the
# the corrected paleo-climate download they had a climate ROW whose values were all NA, so a
# row-count check passed while a complete-case filter quietly removed them. It should
# now drop NOTHING - so it says what it drops instead of doing it silently.
make_env = function(per) {
  e = env %>%
    filter(period == per) %>%
    select(plot_id, all_of(CCA_VARIABLES)) %>%
    distinct() %>%
    column_to_rownames("plot_id")
  ok = rowSums(!is.finite(as.matrix(e))) == 0L
  if (any(!ok))
    message("make_env('", per, "'): DROPPED ", sum(!ok), " of ", nrow(e),
            " plots with missing/nonfinite climate - ",
            paste(head(rownames(e)[!ok], 5), collapse = ", "),
            if (sum(!ok) > 5) ", ..." else "")
  e[ok, , drop = FALSE]
}

species_past  = make_wide("past");    env_past  = make_env("past")
species_present = make_wide("present"); env_present = make_env("present")
species_paleo = make_wide("paleo");   env_paleo = make_env("paleo")

# -----------------------------------------------------------------------------
# Prepare eligible calibration, paired modern comparisons and paleo projections
# -----------------------------------------------------------------------------
# Determine candidate model taxa from eligible legacy rows, then restrict the
# fitted calibration to plots with eligible observations at BOTH dates.
# The whole cleaned universe is kept for the exclusion audit, including plots
# that disappear entirely from the consolidated occurrence table.
common_past = intersect(rownames(species_past), rownames(env_past))
common_past = common_past[rowSums(species_past[common_past, , drop = FALSE]) > 0]
keep_species = colnames(species_past)[colSums(species_past[common_past, , drop = FALSE]) > 0]

cleaned_occ = bind_rows(
  read_csv(here("output/MORA_occ.csv"), show_col_types = FALSE) %>%
    mutate(site = "MORA", era = "anthropocene"),
  read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE) %>%
    mutate(site = "NOCA", era = "anthropocene"),
  read_csv(here("output/paleo_occ.csv"), show_col_types = FALSE)
) %>% select(site, era, period, plot_id, species, occurrence)

# Recheck eligibility if pairing leaves a taxon absent from calibration. Such a
# taxon cannot supply WA projections in this fitted model. The frequency rule
# itself still uses the existing site-by-period counts above.
repeat {
  cca_sample_eligibility = cca_classify_samples(
    cleaned_occ, occ_consolidated, unique(occ$species), keep_species,
    env, CCA_VARIABLES)
  cca_pair_eligibility = cca_pair_samples(cca_sample_eligibility)
  present_pairs = cca_pair_eligibility %>% filter(comparison_included) %>% pull(plot_id)
  present_pairs = rownames(species_present)[rownames(species_present) %in% present_pairs]
  if (!length(present_pairs)) stop("CCA calibration requires eligible matched plots at both dates.")
  paired_species = species_past[present_pairs, keep_species, drop = FALSE]
  fitted_taxa = colnames(paired_species)[colSums(paired_species) > 0]
  if (identical(fitted_taxa, keep_species)) break
  keep_species = fitted_taxa
}
common_paleo = cca_sample_eligibility %>%
  filter(period == "paleo", eligible) %>% pull(plot_id)
common_paleo = rownames(species_paleo)[rownames(species_paleo) %in% common_paleo]
stopifnot(setequal(common_past, cca_sample_eligibility %>%
                    filter(period == "past", eligible) %>% pull(plot_id)),
          !anyDuplicated(present_pairs), !anyDuplicated(common_paleo))

# Fit on exactly the matched legacy endpoints used by BOTH observed and
# predicted comparisons. No other eligible legacy plots enter the CCA fit or
# its climate-SD reference.
species_past_final = species_past[present_pairs, keep_species, drop = FALSE]
env_past_final = env_past[present_pairs, CCA_VARIABLES, drop = FALSE]
species_past_paired = species_past_final
env_past_paired = env_past_final
species_present_final = species_present[present_pairs, keep_species, drop = FALSE]
env_present_final = env_present[present_pairs, CCA_VARIABLES, drop = FALSE]
species_paleo = species_paleo[common_paleo, keep_species, drop = FALSE]
env_paleo = env_paleo[common_paleo, CCA_VARIABLES, drop = FALSE]

cca_sample_eligibility = cca_sample_eligibility %>%
  left_join(cca_pair_eligibility %>%
              select(site, plot_id, pair_included = comparison_included,
                     pair_exclusion_period = exclusion_period,
                     pair_reason = reason), by = c("site", "plot_id")) %>%
  mutate(calibration_included = period == "past" & coalesce(pair_included, FALSE),
         comparison_included = if_else(period == "paleo", eligible,
                                       coalesce(pair_included, FALSE)),
         comparison_reason = if_else(period == "paleo", reason, pair_reason))

cca_eligibility_units = bind_rows(
  cca_pair_eligibility %>%
    transmute(era = "anthropocene", site, use = "Legacy calibration", plot_id,
              exclusion_period, reason_code, reason, included = calibration_included),
  cca_pair_eligibility %>%
    transmute(era = "anthropocene", site, use = "Modern paired comparison",
              plot_id, exclusion_period, reason_code, reason,
              included = comparison_included),
  cca_sample_eligibility %>% filter(period == "paleo") %>%
    transmute(era, site, use = "Paleo projection", plot_id,
              exclusion_period = period, reason_code, reason, included = eligible))
cca_eligibility_counts = cca_eligibility_units %>%
  group_by(era, site, use) %>%
  summarize(input_units = n(), excluded_units = sum(!included),
            included_units = sum(included), .groups = "drop")
cca_exclusion_summary = cca_eligibility_units %>% filter(!included) %>%
  count(era, site, use, exclusion_period, reason_code, reason, name = "excluded_units")
cat("\nCCA eligibility BEFORE fitting/projection (unique plots or paleo samples):\n")
print(as.data.frame(cca_eligibility_counts), row.names = FALSE)
cat("\nExclusion reasons (each plot/sample counted once within each use):\n")
print(as.data.frame(cca_exclusion_summary %>% select(-reason_code)), row.names = FALSE)
# Every primary model invocation regenerates these tables. Threshold variants
# retain their own in-memory audit and cannot overwrite the primary report.
if (count.thr == CCA_COUNT_THRESHOLD && !length(extra_exclude) && !nzchar(cca_suffix)) {
  write_csv(cca_sample_eligibility, here("output/cca_sample_eligibility.csv"))
  write_csv(cca_pair_eligibility, here("output/cca_pair_eligibility.csv"))
  write_csv(cca_eligibility_counts, here("output/cca_eligibility_counts.csv"))
  write_csv(cca_exclusion_summary, here("output/cca_exclusion_summary.csv"))
}

# -----------------------------------------------------------------------------
# Fit the pooled CCA ONLY after resolving and reporting eligibility
# -----------------------------------------------------------------------------
cca_formula = reformulate(CCA_VARIABLES, response = "species_past_final")
cca_model = cca(cca_formula, data = env_past_final)

# Projection helper. Rows are matched by plot_id, not by position: the former
# model reused the `valid_plots` logical built from the PAST
# matrices to subset the PRESENT matrices, which is correct only while the two
# intersections happen to come out in the same order.
project_period = function(sp, en, era_label) {
  cc = intersect(rownames(sp), rownames(en))
  sp = sp[cc, keep_species, drop = FALSE]
  en = en[cc, CCA_VARIABLES, drop = FALSE]
  pred = predict(cca_model, newdata = en, type = "lc", scaling = cca_scaling, hill = cca_hill)
  proj = predict(cca_model, newdata = sp, type = "wa", scaling = cca_scaling, hill = cca_hill)
  list(plot_id = cc, pred = pred, proj = proj, era = era_label)
}

# All projection inputs are already eligible: never filter WA and LC separately.
predicted_present = predict(cca_model, newdata = env_present_final, type = "lc", scaling = cca_scaling, hill = cca_hill)
projected_present = predict(cca_model, newdata = species_present_final,
                            type = "wa", scaling = cca_scaling, hill = cca_hill)

predicted_paleo = predict(cca_model, newdata = env_paleo[, CCA_VARIABLES, drop = FALSE],
                          type = "lc", scaling = cca_scaling, hill = cca_hill)
projected_paleo = predict(cca_model, newdata = species_paleo[, keep_species, drop = FALSE],
                          type = "wa", scaling = cca_scaling, hill = cca_hill)
stopifnot(identical(rownames(predicted_present), rownames(projected_present)),
          identical(rownames(predicted_paleo), rownames(projected_paleo)),
          all(is.finite(predicted_present)), all(is.finite(projected_present)),
          all(is.finite(predicted_paleo)), all(is.finite(projected_paleo)))

# -----------------------------------------------------------------------------
# Scores and plotting frames shared by the maintained figure stages
# -----------------------------------------------------------------------------
past_sites     = scores(cca_model, display = "sites",   choices = 1:3, scaling = cca_scaling, hill = cca_hill)
species_scores = scores(cca_model, display = "species", choices = 1:3, scaling = cca_scaling, hill = cca_hill)
env_scores     = scores(cca_model, display = "bp",      choices = 1:3, scaling = cca_scaling, hill = cca_hill)

species_contribution = sqrt(species_scores[, 1]^2 + species_scores[, 2]^2)
top_species = names(sort(species_contribution, decreasing = TRUE))

site_fire_info_past = env %>% filter(period == "past") %>%
  select(plot_id, site, burnt) %>% filter(plot_id %in% rownames(species_past_final))
site_fire_info_present = env %>% filter(period == "present") %>%
  select(plot_id, site, burnt) %>% filter(plot_id %in% rownames(species_present_final))
site_fire_info_paleo = env %>% filter(period == "paleo") %>%
  select(plot_id, site, burnt) %>% filter(plot_id %in% rownames(species_paleo))

sites_df = as_tibble(past_sites, rownames = "plot_id") %>%
  left_join(site_fire_info_past, by = "plot_id")
species_df = as_tibble(species_scores, rownames = "species") %>%
  filter(species %in% top_species)
env_df = as_tibble(env_scores, rownames = "variable")

# -----------------------------------------------------------------------------
# comparison_df - predicted (LC) vs observed (WA) position of every sample
# -----------------------------------------------------------------------------
comparison_df = bind_rows(
  tibble(plot_id = rownames(species_present_final),
         predicted_CCA1 = predicted_present[, 1], predicted_CCA2 = predicted_present[, 2],
         predicted_CCA3 = predicted_present[, 3],
         projected_CCA1 = projected_present[, 1], projected_CCA2 = projected_present[, 2],
         projected_CCA3 = projected_present[, 3]) %>%
    left_join(site_fire_info_present, by = "plot_id") %>%
    mutate(era = "anthropocene"),
  tibble(plot_id = rownames(species_paleo),
         predicted_CCA1 = predicted_paleo[, 1], predicted_CCA2 = predicted_paleo[, 2],
         predicted_CCA3 = predicted_paleo[, 3],
         projected_CCA1 = projected_paleo[, 1], projected_CCA2 = projected_paleo[, 2],
         projected_CCA3 = projected_paleo[, 3]) %>%
    left_join(site_fire_info_paleo, by = "plot_id") %>%
    mutate(era = "holocene")
) %>%
  {cat("\ncomparison_df: ", nrow(.), " of ",
       nrow(species_present_final) + nrow(species_paleo),
       " eligible samples positioned; exclusions are in cca_exclusion_summary.\n",
       sep = ""); .}

# Publish the existing primary fit before climate/fire classification and tracking.
# Diagnostic alternative calibrations must never overwrite this reference.
if (count.thr == CCA_COUNT_THRESHOLD && !length(extra_exclude) && !nzchar(cca_suffix)) {
  source(here('R/helpers/cca_reference.R'), local = TRUE)
  export_cca_reference(environment())
}
# END R/stages/05_cca_model.R

# ============================================================================
# BEGIN R/stages/12_walsh_fire_reproduction.R
# ============================================================================
# =============================================================================
# 12_walsh_fire_reproduction.R
# =============================================================================
# Assemble the authoritative all-tapas four-core source catalog, then run the
# official CharAnalysis R 2.0.3 Walsh reproduction as a separate audit. This
# stage never overwrites fire_walsh.csv, paleo_fire.csv, or CCA fire assignments.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(readxl); library(CharAnalysis)
  library(tapas); library(patchwork)
})
source(here("R/helpers/walsh_fire_functions.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

FROZEN_FIRE_PATHS = here("output", c("fire_walsh.csv", "paleo_fire.csv"))
if (!all(file.exists(FROZEN_FIRE_PATHS))) stop("Active paleo-fire outputs are missing.")
frozen_fire_before = unname(tools::md5sum(FROZEN_FIRE_PATHS))

EXPECTED_CHAR_VERSION = "2.0.3"
if (as.character(packageVersion("CharAnalysis")) != EXPECTED_CHAR_VERSION)
  stop("Official Walsh audit requires CharAnalysis ", EXPECTED_CHAR_VERSION,
       "; installed version is ", packageVersion("CharAnalysis"), ".")

INPUT_DIR = here("output/walsh_charanalysis_inputs")
dir.create(INPUT_DIR, recursive = TRUE, showWarnings = FALSE)
settings = tribble(
  ~lake, ~site_id, ~input, ~interpolation_years, ~smoothing_years,
  "Sunrise Lake", "Sunrise", "data/PALEO/char_sunrise_lake.xlsx", 48, 800,
  "Shadow Lake", "Shadow", "data/PALEO/char_shadow_lake.xlsx", 47, 1000,
  "Little Sunrise Lake", "LittleSunrise", "data/PALEO/char_little_sunrise.xlsx", 42, 500) |>
  mutate(input = here(input), transform = "none", background_method = "robust LOWESS",
         peak_component = "residual", threshold_type = "local",
         threshold_method = "Gaussian mixture noise distribution",
         final_threshold_probability = .95, minimum_count_probability = .05,
         minimum_count_window_years = 75, frequency_smoother_years = 1000)

results = vector("list", nrow(settings))
input_audit = vector("list", nrow(settings))
raw_results = vector("list", nrow(settings))

# CharAnalysis 2.0.3 draws its complete internal diagnostic suite as a side
# effect of fitting. Capture those plots on a temporary device so an accidental
# root-level Rplots.pdf is not created; the maintained audit figure below is
# built explicitly from the returned numerical objects.
capture_internal_graphics = function(expression) {
  temporary_plot = tempfile("charanalysis_internal_", fileext = ".pdf")
  grDevices::pdf(temporary_plot)
  on.exit({
    grDevices::dev.off()
    unlink(temporary_plot)
  }, add = TRUE)
  force(expression)
}

for (i in seq_len(nrow(settings))) {
  s = settings[i, ]
  dat = walsh_input_data(s$input)
  inp = write_charanalysis_inputs(dat, s$site_id, s$interpolation_years,
                                  s$smoothing_years, INPUT_DIR)
  out = capture_internal_graphics(CharAnalysis(inp$params))
  raw_results[[i]] = out
  results[[i]] = extract_charanalysis_result(out, s$lake)
  input_audit[[i]] = tibble(lake = s$lake, data_file = inp$data,
    parameter_file = inp$params, input_rows = nrow(dat),
    data_md5 = unname(tools::md5sum(inp$data)),
    parameter_md5 = unname(tools::md5sum(inp$params)))
}

mora_series = map_dfr(results, "series")
mora_events = map_dfr(results, "events")
mora_fri = map_dfr(results, "fri")
input_audit = bind_rows(input_audit)

# Published totals are a regression reference, not a target to force by tuning.
published = tribble(
  ~lake, ~published_total_episodes,
  "Shadow Lake", 18L,
  "Sunrise Lake", 24L,
  "Little Sunrise Lake", 16L)
regression = mora_events |> count(lake, name = "official_r_episodes") |>
  full_join(published, by = "lake") |>
  mutate(difference = official_r_episodes - published_total_episodes,
    exact_match = difference == 0,
    interpretation = if_else(exact_match,
      "official R result matches reported total",
      "official R 2.0.3 result retained; discrepancy from Walsh reported total"))

tapas_counts = read_csv(here("output/fire_walsh.csv"), show_col_types = FALSE) |>
  filter(is_significant) |> count(lake, name = "tapas_episodes")
software_comparison = regression |> left_join(tapas_counts, by = "lake") |>
  mutate(tapas_minus_official_r = tapas_episodes - official_r_episodes,
         tapas_status = "primary harmonized source catalog")

# The downstream source catalog is all-tapas. Official CharAnalysis objects
# above remain a publication-reproduction audit and never replace these events.
active_paths = here("output", c(
  "fire_mora_tapas_series.csv", "fire_mora_tapas_events.csv",
  "fire_mora_tapas_settings.csv", "fire_noca_tapas_series.csv",
  "fire_noca_tapas_events.csv", "fire_noca_tapas_settings.csv"))
if (!all(file.exists(active_paths)))
  stop("Run R/stages/000_FIRE_cleaning.R and R/stages/000_PALEO_c_fire.R first.")
all_continuous = bind_rows(
  read_csv(active_paths[1], show_col_types = FALSE),
  read_csv(active_paths[4], show_col_types = FALSE))
all_events = bind_rows(
  read_csv(active_paths[2], show_col_types = FALSE),
  read_csv(active_paths[5], show_col_types = FALSE))
tapas_settings = bind_rows(
  read_csv(active_paths[3], show_col_types = FALSE),
  read_csv(active_paths[6], show_col_types = FALSE))
if (n_distinct(all_events$lake) != 4L ||
    anyDuplicated(all_events[c("lake", "age_cal_yr_BP")]) ||
    !all(unique(tapas_settings$engine) == "tapas"))
  stop("The harmonized all-tapas source catalog is incomplete or duplicated.")
coverage = all_continuous |> group_by(site, lake) |>
  summarise(younger_cal_bp = min(age_cal_yr_BP),
            older_cal_bp = max(age_cal_yr_BP), .groups = "drop")

write_csv(settings, here("output/walsh_charanalysis_settings.csv"))
write_csv(input_audit, here("output/walsh_charanalysis_input_audit.csv"))
write_csv(mora_series, here("output/walsh_charanalysis_series.csv"))
write_csv(mora_events, here("output/walsh_charanalysis_events.csv"))
write_csv(mora_fri, here("output/walsh_charanalysis_fri.csv"))
write_csv(regression, here("output/walsh_charanalysis_table3_audit.csv"))
write_csv(software_comparison, here("output/walsh_charanalysis_software_comparison.csv"))
write_csv(tapas_settings, here("output/holocene_fire_source_settings.csv"))
write_csv(all_continuous, here("output/holocene_fire_source_series.csv"))
write_csv(all_events, here("output/holocene_fire_source_events.csv"))
write_csv(coverage, here("output/holocene_fire_source_coverage.csv"))

pkg_desc = system.file("DESCRIPTION", package = "CharAnalysis")
manifest_paths = c(settings$input, input_audit$data_file, input_audit$parameter_file,
  here("output/walsh_charanalysis_series.csv"),
  here("output/walsh_charanalysis_events.csv"),
  here("output/walsh_charanalysis_table3_audit.csv"))
manifest = tibble(
  engine = "official CharAnalysis R", version = EXPECTED_CHAR_VERSION,
  release_source = "CRAN CharAnalysis 2.0.3",
  package_description_md5 = unname(tools::md5sum(pkg_desc)),
  file = normalizePath(manifest_paths), md5 = unname(tools::md5sum(manifest_paths)),
  active_fire_pipeline_modified = FALSE)
write_csv(manifest, here("output/walsh_charanalysis_manifest.csv"))
tapas_desc = system.file("DESCRIPTION", package = "tapas")
tapas_manifest_paths = c(active_paths,
  here("output/holocene_fire_source_settings.csv"),
  here("output/holocene_fire_source_series.csv"),
  here("output/holocene_fire_source_events.csv"))
tapas_manifest = tibble(
  engine = "tapas", version = as.character(packageVersion("tapas")),
  analytical_role = "primary harmonized fire-event detector",
  package_description_md5 = unname(tools::md5sum(tapas_desc)),
  file = normalizePath(tapas_manifest_paths),
  md5 = unname(tools::md5sum(tapas_manifest_paths)))
write_csv(tapas_manifest, here("output/holocene_fire_tapas_manifest.csv"))
frozen_fire_after = unname(tools::md5sum(FROZEN_FIRE_PATHS))
if (!identical(frozen_fire_before, frozen_fire_after))
  stop("Walsh reproduction modified an active paleo-fire output.")
write_csv(tibble(file = normalizePath(FROZEN_FIRE_PATHS),
  md5_before = frozen_fire_before, md5_after = frozen_fire_after,
  unchanged = frozen_fire_before == frozen_fire_after),
  here("output/walsh_active_fire_hash_audit.csv"))

lake_cols = c("Sunrise Lake" = "#3B82A0", "Shadow Lake" = "#7B5EA7",
              "Little Sunrise Lake" = "#C47A31", PantherPotholes = "#D95F43")
p1 = ggplot(mora_series, aes(age_cal_yr_BP, char_interpolated, color = lake)) +
  geom_line(linewidth = .35) + geom_line(aes(y = background_char), linewidth = .8) +
  geom_point(data = mora_events, aes(y = peak_magnitude), shape = 4, size = 2) +
  facet_wrap(~lake, ncol = 1, scales = "free_y") + scale_x_reverse() +
  scale_color_manual(values = lake_cols) + theme_bw() +
  labs(title = "Official CharAnalysis reconstruction of Walsh MORA records",
       subtitle = "Thin: interpolated CHAR; bold: background; X: accepted peak magnitude",
       x = "cal BP", y = "Within-record CHAR units", color = NULL)
p2 = ggplot(mora_series, aes(age_cal_yr_BP, fire_frequency_per_1000yr,
                             color = lake)) +
  geom_line() + facet_wrap(~lake, ncol = 1, scales = "free_y") +
  scale_x_reverse() + scale_color_manual(values = lake_cols) + theme_bw() +
  labs(title = "Walsh-style smoothed fire frequency", x = "cal BP",
       y = "Fire episodes per 1,000 years", color = NULL)
p3 = regression |> pivot_longer(c(published_total_episodes, official_r_episodes),
  names_to = "source", values_to = "episodes") |>
  ggplot(aes(lake, episodes, fill = source)) + geom_col(position = "dodge") +
  geom_text(aes(label = episodes), position = position_dodge(.9), vjust = -.2) +
  theme_bw() + labs(title = "Walsh reported totals versus official R 2.0.3",
    subtitle = "Discrepancies are retained, not tuned away", x = NULL, y = "Episodes")
pages = list(p1, p2, p3)
if (render_figures) {
  pdf(here("plot/test_figures/fig_walsh_charanalysis_reproduction.pdf"), width = 13,
      height = 9, onefile = TRUE); walk(pages, print); dev.off()
}

cat("Official CharAnalysis episode counts:\n")
print(as.data.frame(regression))
cat("Wrote source series and accepted events for the independent era stage.\n")
# END R/stages/12_walsh_fire_reproduction.R

# ============================================================================
# BEGIN R/stages/13_holocene_climate_fire_eras.R
# ============================================================================
# =============================================================================
# 13_holocene_climate_fire_eras.R
# =============================================================================
# Literature-blind unified Holocene climate-era and high-fire-period analysis.
# Climate and fire are classified independently. This stage freezes the era
# grid; lake-level vegetation tracking joins it later without moving boundaries.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(patchwork)
})
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/holocene_climate_fire_era_functions.R"), local = TRUE)
source(here("R/helpers/figure_style.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

CLIMATE_INPUT = here("output/chelsa_paleo_ponds.csv")
CLIMATE_SCALING = here("output/cca_tracking_climate_scaling.csv")
FIRE_EVENTS = here("output/holocene_fire_source_events.csv")
FIRE_SERIES = here("output/holocene_fire_source_series.csv")
FIRE_SETTINGS = here("output/holocene_fire_source_settings.csv")
required = c(CLIMATE_INPUT, CLIMATE_SCALING, FIRE_EVENTS, FIRE_SERIES,
             FIRE_SETTINGS)
if (!all(file.exists(required))) stop("Missing unified-era input(s): ",
  paste(required[!file.exists(required)], collapse = ", "),
  ". Run CCA reference and R/stages/12_walsh_fire_reproduction.R first.")

# The interpretive stage is read-only with respect to the fitted analysis,
# climate caches, chronology products, and active paleo-fire assignments.
protected_paths = c(
  here("output/MORA_climate.csv"), here("output/NOCA_climate.csv"),
  here("output/chelsa_paleo_ponds.csv"),
  here("output/cca_tracking_climate_scaling.csv"),
  here("output/bacon_run_manifest.csv"), here("output/fire_walsh.csv"),
  here("output/paleo_fire.csv"))
if (file.exists(here("output/bacon_run_manifest.csv"))) {
  bacon_manifest = read_csv(here("output/bacon_run_manifest.csv"),
    show_col_types = FALSE)
  bacon_products = unique(c(bacon_manifest$control_file,
    bacon_manifest$posterior_file, bacon_manifest$ages_file))
  protected_paths = c(protected_paths, here(bacon_products))
}
protected_paths = protected_paths[file.exists(protected_paths)]
protected_before = unname(tools::md5sum(protected_paths))

PRIMARY_VARS = c("MSpT", "MWT", "SP", "WP")
if (!identical(CCA_VARIABLES, PRIMARY_VARS))
  stop("CCA variables changed; review the unified-era contract.")
VARIABLE_UNITS = c(MSpT = "deg C", MWT = "deg C", SP = "mm", WP = "mm")
VARIABLE_LABELS = c(MSpT = "Spring temperature", MWT = "Winter temperature",
                    SP = "Summer precipitation", WP = "Winter precipitation")
THRESHOLD_FRACTION = 0.50
REQUIRED_PHASES = 8L

# =============================================================================
# CLIMATE: signed, calibration-standardized 1,000-year changes
# =============================================================================
ponds = read_csv(CLIMATE_INPUT, show_col_types = FALSE)
levels = ponds |>
  transmute(unit = lake, period = site, variable, time = slice, month,
            value = value_raw) |>
  derive_climate_vars(winter_shift = FALSE) |>
  rename(lake = unit, site = period, slice = time) |>
  mutate(cal_bp = 1950 - slice * 100) |>
  select(site, lake, cal_bp, all_of(PRIMARY_VARS))
counts = levels |> count(site, lake, name = "n_slices")
if (nrow(counts) != 4L || any(counts$n_slices != 111L) ||
    any(is.na(levels[PRIMARY_VARS])))
  stop("Expected four complete 111-slice lake climate trajectories.")

climate_raw = build_climate_changes_1000yr(levels, PRIMARY_VARS,
  VARIABLE_UNITS)
scaling = read_csv(CLIMATE_SCALING, show_col_types = FALSE) |>
  filter(variable %in% PRIMARY_VARS)
if (nrow(scaling) != 4L || any(!is.finite(scaling$sd)) || any(scaling$sd <= 0))
  stop("Legacy CCA climate scaling is incomplete or invalid.")

climate = classify_climate_era_union(climate_raw$site_cells, scaling,
  fraction = THRESHOLD_FRACTION, required_phases = REQUIRED_PHASES)
composite = calculate_climate_composite(climate$site_standardized)

era_domain = range(climate$era_grid$t)
if (!identical(era_domain, c(1300, 9500)))
  stop("Complete ten-phase climate domain changed; review before interpreting eras.")

direction_terms = climate$drivers |>
  mutate(driver_label = case_when(
    variable == "MSpT" & direction == "increasing" ~ "spring warming",
    variable == "MSpT" ~ "spring cooling",
    variable == "MWT" & direction == "increasing" ~ "winter warming",
    variable == "MWT" ~ "winter cooling",
    variable == "SP" & direction == "increasing" ~ "summer wetting",
    variable == "SP" ~ "summer drying",
    variable == "WP" & direction == "increasing" ~ "winter wetting",
    TRUE ~ "winter drying"))
era_catalog = climate$era_catalog |>
  mutate(active_variable_directions = map2_chr(
    older_cal_bp, younger_cal_bp, function(era_old, era_young) {
      direction_terms |>
        filter(.data$older_cal_bp > era_young,
               .data$younger_cal_bp < era_old) |>
        pull(.data$driver_label) |> unique() |> paste(collapse = ";")
    })) |>
  mutate(analytical_status = paste(
    "literature-blind operational era; joined downstream to descriptive",
    "lake-level tracking summaries without changing boundaries"))

# Descriptive subdivisions are permitted only where an internal, sustained
# low-driver interval separates two multi-driver parts of a climate-change era.
climate_subphases = subdivide_climate_change_eras(
  climate$variable_cells, era_catalog, min_trough_years = 300L,
  driver_coverage = 0.60)

# =============================================================================
# FIRE: source-specific accepted events, independent 1,000-year frequency rule
# =============================================================================
events = read_csv(FIRE_EVENTS, show_col_types = FALSE)
continuous = read_csv(FIRE_SERIES, show_col_types = FALSE)
fire = calculate_fire_frequency(events, continuous, 1000L, 100L)

fire_settings = read_csv(FIRE_SETTINGS, show_col_types = FALSE) |>
  transmute(site, lake, engine, chronology, interpolation_years,
    background_years = smoothing_years,
    peak_probability = threshold_probability,
    minimum_count_probability, minimum_count_window_years,
    analytical_role = if_else(site == "MORA",
      "regional MORA evidence; Walsh settings implemented in tapas",
      "local Panther Potholes evidence; Prichard-style settings implemented in tapas"))
if (nrow(fire_settings) != 4L || any(fire_settings$engine != "tapas"))
  stop("High-fire periods require four all-tapas source settings.")

# =============================================================================
# AUDIT OUTPUTS
# =============================================================================
write_csv(climate_raw$lake, here("output/holocene_era_climate_lake_changes.csv"))
write_csv(climate$site_standardized,
  here("output/holocene_era_climate_site_phase_changes.csv"))
write_csv(climate$regional_phases,
  here("output/holocene_era_climate_regional_phase_changes.csv"))
write_csv(climate$thresholds,
  here("output/holocene_era_climate_variable_thresholds.csv"))
write_csv(climate$variable_cells,
  here("output/holocene_era_climate_directional_cells.csv"))
write_csv(climate$era_grid, here("output/holocene_era_grid.csv"))
write_csv(era_catalog, here("output/holocene_era_catalog.csv"))
write_csv(direction_terms, here("output/holocene_era_driver_subintervals.csv"))
write_csv(climate_subphases,
  here("output/holocene_era_climate_change_subphases.csv"))
write_csv(composite$site_phase,
  here("output/holocene_era_climate_composite_site_phase.csv"))
write_csv(composite$regional_phase,
  here("output/holocene_era_climate_composite_regional_phase.csv"))
write_csv(composite$grid,
  here("output/holocene_era_climate_composite_grid.csv"))
write_csv(fire_settings, here("output/holocene_era_fire_source_settings.csv"))
write_csv(fire$coverage, here("output/holocene_era_fire_core_coverage.csv"))
write_csv(fire$core, here("output/holocene_era_fire_core_frequency.csv"))
write_csv(fire$site_grid, here("output/holocene_era_fire_site_frequency.csv"))
write_csv(fire$thresholds, here("output/holocene_era_fire_thresholds.csv"))
write_csv(fire$periods, here("output/holocene_era_high_fire_periods.csv"))
write_csv(fire$corroboration_core,
  here("output/holocene_era_fire_corroboration_core.csv"))
write_csv(fire$corroboration_site,
  here("output/holocene_era_fire_corroboration_site.csv"))
write_csv(tribble(
  ~field, ~value,
  "climate_interval_years", "1000",
  "climate_offsets", paste(seq(0, 900, 100), collapse = ";"),
  "threshold_fraction_of_variable_maximum", "0.50",
  "threshold_population", "absolute maximum of median equal-weight MORA-NOCA regional standardized change",
  "phase_support", "at least 8 of 10 regional phases match the median regional direction",
  "site_direction_veto", "FALSE; site trajectories retained for audit",
  "era_union", "climate change if any of MSpT, MWT, SP, or WP qualifies",
  "subphase_rule", "split a CC era only at an internal >=300-year minimum-active-driver trough flanked by multi-driver cells",
  "subphase_driver_label", "driver active in >=60% of subphase cells",
  "gap_bridging", "FALSE",
  "composite_role", "unsigned unthresholded context only",
  "fire_interval_years", "centered 1000-year accepted-event frequency",
  "fire_threshold", "site median + 1.4826 * MAD of normalized frequency",
  "fire_gap_or_duration_filter", "none",
  "literature_used", "FALSE",
  "tracking_periods_assigned", "FALSE"),
  here("output/holocene_era_settings.csv"))

# =============================================================================
# SINGLE-PAGE INTEGRATED FIGURE
# =============================================================================
site_cols = PAPER_SITE_COLORS
variable_cols = c(MSpT = "#D73027", MWT = "#4575B4",
                  SP = "#E6AB02", WP = "#1B9E77")
direction_cols = c(increasing = "#C84335", decreasing = "#2675B8",
                   `not qualifying` = "grey88")
era_cols = c(`climate change` = "#B85C38", `relative stability` = "#D9E2E8")
fire_cols = site_cols
time_scale = function() scale_x_reverse(limits = c(11000, -100),
  breaks = c(10000, 8000, 6000, 4000, 2000, 0),
  labels = scales::label_number(big.mark = ","))
shade_incomplete = function() list(
  annotate("rect", xmin = 9600, xmax = 11000, ymin = -Inf, ymax = Inf,
    fill = "grey80", alpha = .22),
  annotate("rect", xmin = -100, xmax = 1300, ymin = -Inf, ymax = Inf,
    fill = "grey80", alpha = .22))

threshold_lines = climate$thresholds |>
  select(variable, threshold_standardized_change) |>
  crossing(sign = c(-1, 1)) |>
  mutate(y = sign * threshold_standardized_change)
p1 = ggplot(climate$variable_cells,
  aes(t, regional_score, color = variable)) +
  shade_incomplete() + geom_hline(yintercept = 0, color = "grey65") +
  geom_hline(data = threshold_lines, aes(yintercept = y),
    inherit.aes = FALSE, linetype = 2, color = "grey35") +
  geom_line(linewidth = .7) +
  geom_point(data = filter(climate$variable_cells, qualifies), size = 1.5) +
  facet_wrap(~variable, nrow = 1) + time_scale() +
  scale_color_manual(values = variable_cols) + theme_bw(base_size = 9) +
  theme(legend.position = "none", panel.grid.minor = element_blank()) +
  labs(title = "A. Signed 1,000-year climate change",
    subtitle = "Regional median in pooled legacy-calibration SD units; dashed = 50% of each variable's maximum",
    x = NULL, y = "Signed standardized change")

bands = climate$variable_cells |>
  mutate(display = if_else(qualifies, direction, "not qualifying"))
p2 = ggplot(bands, aes(t, variable, fill = display)) +
  shade_incomplete() + geom_tile(width = 100, height = .82) + time_scale() +
  scale_fill_manual(values = direction_cols) + theme_bw(base_size = 9) +
  theme(panel.grid = element_blank(), legend.position = "bottom") +
  labs(title = "B. Variable-specific directional cells",
    subtitle = "Direction comes from the regional score; no MORA-NOCA agreement veto",
    x = NULL, y = NULL, fill = NULL)

era_plot = climate$era_grid |>
  mutate(y = "Unified era")
p3 = ggplot(era_plot, aes(t, y, fill = era_class)) +
  shade_incomplete() + geom_tile(width = 100, height = .8) +
  geom_text(data = era_catalog, aes(x = (older_cal_bp + younger_cal_bp) / 2,
    y = "Unified era", label = era_id), inherit.aes = FALSE, size = 3) +
  time_scale() + scale_fill_manual(values = era_cols) + theme_bw(base_size = 9) +
  theme(panel.grid = element_blank(), legend.position = "bottom") +
  labs(title = "C. Any-variable union", subtitle =
    "Any qualifying variable creates climate change; contiguous cells only; gray margins lack all ten phases",
    x = NULL, y = NULL, fill = NULL)

composite_long = composite$grid |>
  select(t, MORA, NOCA, Regional = regional_composite) |>
  pivot_longer(-t, names_to = "series", values_to = "magnitude")
p4 = ggplot(composite_long, aes(t, magnitude, color = series)) +
  shade_incomplete() + geom_line(linewidth = .75) + time_scale() +
  scale_color_manual(values = c(site_cols, Regional = "black")) +
  theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(),
    legend.position = "bottom") +
  labs(title = "D. Unthresholded four-variable composite",
    subtitle = "Euclidean magnitude is contextual and non-directional; it cannot define an era",
    x = NULL, y = "Climate displacement (calibration SD units)", color = NULL)

p5 = ggplot(filter(fire$site_grid, between(cal_bp, -100, 11000)),
  aes(cal_bp, normalized_frequency, color = site)) +
  geom_line(linewidth = .8, na.rm = TRUE) +
  geom_line(aes(y = high_fire_threshold), linetype = 2, linewidth = .55) +
  time_scale() + scale_color_manual(values = fire_cols) + theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom") +
  labs(title = "E. Independent centered 1,000-year fire-event frequency",
    subtitle = "Each core is normalized to its own maximum; MORA is an equal-core mean where >=2 cores are covered",
    x = NULL, y = "Normalized accepted-event frequency", color = NULL)

fire_band = fire$site_grid |>
  filter(is.finite(normalized_frequency), between(cal_bp, -100, 11000)) |>
  mutate(state = if_else(high_fire, "high fire", "not high fire"))
markers = fire$corroboration_site |>
  filter(corroborates, between(cal_bp, -100, 11000)) |>
  mutate(marker = recode(stream,
    peak_strength_percentile_sum = "peak strength",
    background_char_z = "background CHAR"))
p6 = ggplot(fire_band, aes(cal_bp, site, fill = state)) +
  geom_tile(width = 100, height = .72) +
  geom_point(data = markers, aes(cal_bp, site, shape = marker),
    inherit.aes = FALSE, size = 1.7, color = "black") +
  time_scale() +
  scale_fill_manual(values = c(`high fire` = "#B22222",
    `not high fire` = "grey90")) +
  scale_shape_manual(values = c(`peak strength` = 17, `background CHAR` = 18)) +
  theme_bw(base_size = 9) + theme(panel.grid = element_blank(),
    legend.position = "bottom") +
  labs(title = "F. High-fire periods and corroboration",
    subtitle = "Frequency alone selects periods; symbols show independent strength/background support",
    x = "cal BP (older to younger)", y = NULL, fill = NULL, shape = NULL)

# =============================================================================
# REVISED WORKED EXAMPLE
# =============================================================================
example_phase = climate$regional_phases |>
  filter(variable == "MWT", between(t, 6500, 10000))
example_grid = climate$variable_cells |>
  filter(between(t, 6500, 10000))
w1 = ggplot(example_phase, aes(t, regional_score, group = factor(offset),
  color = factor(offset))) +
  geom_hline(yintercept = 0, color = "grey65") + geom_line(alpha = .55) +
  time_scale() + scale_color_viridis_d(option = "turbo") + theme_bw() +
  labs(title = "1. Ten phases expose placement sensitivity",
    subtitle = "Example: winter temperature; direction is evaluated regionally",
    x = NULL, y = "Regional standardized change", color = "Offset")
w2 = ggplot(example_grid, aes(t, regional_score, color = variable)) +
  geom_hline(data = threshold_lines, aes(yintercept = y), inherit.aes = FALSE,
    linetype = 2, color = "grey35") + geom_hline(yintercept = 0,
    color = "grey65") + geom_line() +
  geom_point(data = filter(example_grid, qualifies), size = 2) +
  facet_wrap(~variable, nrow = 1) + time_scale() +
  scale_color_manual(values = variable_cols) + theme_bw() +
  theme(legend.position = "none") +
  labs(title = "2. Apply each variable's 50%-of-maximum threshold",
    subtitle = "A filled cell also needs >=8/10 phases in the regional direction",
    x = NULL, y = "Median regional change")
w3 = p2 + labs(title = "3. Keep direction, then take the any-variable union",
  subtitle = "One qualifying variable is sufficient; below-threshold gaps remain stable")
w4 = p3 + labs(title = "4. Merge only adjacent cells and number CC/S eras",
  subtitle = "No site-direction veto, transition state, forward extension, or gap bridging")
w5 = p4 + labs(title = "5. Composite magnitude is a visual cross-check",
  subtitle = "It is unsigned and unthresholded, so it never selects direction or eras")
w6 = (p5 + labs(title = "6a. Fire is classified independently",
    subtitle = "High fire = normalized site frequency > median + 1.4826 x MAD")) /
  (p6 + labs(title = "6b. Every contiguous run is retained",
    subtitle = "Frequency selects periods; strength/background are corroboration only")) +
  plot_layout(heights = c(1.2, .8))
worked = w1 / w2 / w3 / w4 / w5 / w6 +
  plot_layout(heights = c(1.1, 1.4, 1.1, .8, 1.0, 1.8)) +
  plot_annotation(title = "Worked example: unified Holocene climate eras and fire periods")
if (render_figures) {
  ggsave(here("plot/test_figures/fig_holocene_climate_period_method_worked_example.pdf"),
    worked, width = 15, height = 20)
}

protected_after = unname(tools::md5sum(protected_paths))
if (!identical(protected_before, protected_after))
  stop("Unified era stage modified a protected analytical artifact.")
write_csv(tibble(file = normalizePath(protected_paths),
  md5_before = protected_before, md5_after = protected_after,
  unchanged = protected_before == protected_after),
  here("output/holocene_era_protected_hash_audit.csv"))

cat("Unified climate eras:\n")
print(as.data.frame(era_catalog |>
  select(era_id, era_class, older_cal_bp, younger_cal_bp,
         active_variable_directions)))
cat("High-fire periods: ", nrow(fire$periods), "\n", sep = "")
# END R/stages/13_holocene_climate_fire_eras.R

# ============================================================================
# BEGIN R/stages/09_tracking_metrics.R
# ============================================================================
# Canonical lake-level and paired-plot tracking datasets. No figure/model fits.
# Rscript R/stages/09_tracking_metrics.R [--bin-width-years=500]
# Nondefault widths write only suffixed Holocene products.
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)
source(here('R/helpers/tracking_data.R'),local=TRUE)
N_DRAWS = 100; DRAW_SEED = 42
source(here('R/helpers/paleo_runs.R'),local=TRUE)
source(here('R/helpers/climate_variables.R'),local=TRUE)
source(here('R/helpers/holocene_climate_fire_era_functions.R'),local=TRUE)
width_arg = grep('^--bin-width-years=',commandArgs(trailingOnly=TRUE),value=TRUE)
if (length(width_arg)>1L) stop('Specify one bin width')
bin_width_years = validate_tracking_width(if(length(width_arg))
  as.numeric(sub('^--bin-width-years=','',width_arg)) else 1000L)
suffix = if (bin_width_years==1000L) '' else paste0('_',bin_width_years,'yr')
output_path = function(stem) here('output',paste0(stem,suffix,'.csv'))
required = here('output',c('cca_calibration_reference.rds','chelsa_paleo_ponds.csv',
  'paleo_age_draws.rds','holocene_fire_source_events.csv','holocene_fire_source_series.csv',
  'holocene_era_fire_core_frequency.csv','holocene_era_fire_site_frequency.csv'))
if (!all(file.exists(required))) stop('Run CCA reference and climate/fire stages first')
reference = readRDS(required[1])
if (!identical(reference$scaling,'sites') || reference$hill ||
    nrow(reference$legacy_species)!=607L || length(reference$retained_species)!=14L)
  stop('Expected the unchanged primary 607-plot, 14-taxon CCA')
if (any(tools::md5sum(names(reference$provenance$input_md5)) != reference$provenance$input_md5) ||
    any(tools::md5sum(names(reference$provenance$model_source_md5)) != reference$provenance$model_source_md5))
  stop('CCA reference is stale; rerun the unchanged calibration stage')
# Cache-only chronology access: never regenerate draws or mutate Bacon products.
draws = paleo_age_draws(allow_rebuild=FALSE)
ponds = read_csv(required[2],show_col_types=FALSE)
env_slice = ponds |> transmute(unit=lake,period=site,variable,time=slice,month,
  value=if(PALEO_USE_BIAS_CORRECTED) value_corrected else value_raw) |>
  derive_climate_vars(winter_shift=FALSE) |> rename(lake=unit,site=period,slice=time) |>
  mutate(age=1950-slice*100)
built = build_lake_tracking(reference,draws,env_slice,bin_width_years)
realizations = built$realizations
events = read_csv(required[4],show_col_types=FALSE)
continuous = read_csv(required[5],show_col_types=FALSE)
fire = transition_fire(realizations,events,continuous,bin_width_years,
  core_reference=if(bin_width_years==1000L) read_csv(required[6],show_col_types=FALSE) else NULL,
  high_fire=read_csv(required[7],show_col_types=FALSE))
realizations = realizations |> left_join(fire,by=c('site','offset','age_hi','age_lo'),relationship='many-to-one')
keys = c('site','lake','draw','offset','age_hi','age_lo')
if (anyDuplicated(realizations[keys])) stop('Duplicate lake realization key')
uncertainty = lake_uncertainty(realizations,N_DRAWS)
by_offset = lake_offset_summary(realizations,uncertainty)
timeseries = lake_reporting_grid(uncertainty,bin_width_years)
sample_support = built$samples |> distinct(site,lake,plot_id) |> count(site,lake,name='n_eligible_samples')
excluded = built$raw |> group_by(site,lake,offset) |> summarize(
  n_observed_realizations=n(),n_incomplete_climate_realizations=sum(!climate_complete),.groups='drop')
support = realizations |> group_by(site,lake,offset) |> summarize(
  n_realizations=n(),n_nmin2_realizations=sum(n_min>=2),
  youngest_endpoint=min(age_lo),oldest_endpoint=max(age_hi),
  endpoint_samples_min=min(c(n_samples,n_samples_2)),
  endpoint_samples_median=median(c(n_samples,n_samples_2)),
  endpoint_samples_max=max(c(n_samples,n_samples_2)),.groups='drop') |>
  left_join(by_offset |> group_by(site,lake,offset) |> summarize(
    n_transitions=n(),n_transitions_nmin2=sum(n_draws_nmin2>0),
    n_transitions_full_draw_support=sum(n_draws_present==N_DRAWS),
    n_transitions_majority_draw_support=sum(n_draws_present>=N_DRAWS/2),
    n_transitions_nmin2_majority_support=sum(n_draws_nmin2>=N_DRAWS/2),
    present_draws_min=min(n_draws_present),present_draws_median=median(n_draws_present),
    n_fire_missing_transitions=sum(!is.finite(fire_activity)),.groups='drop'),by=c('site','lake','offset')) |>
  left_join(sample_support,by=c('site','lake')) |> left_join(excluded,by=c('site','lake','offset')) |>
  mutate(bin_width_years=bin_width_years,n_expected_draws=N_DRAWS)
if (bin_width_years==1000L) {
  modern_fire = bind_rows(
    read_csv(here('output/MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
      transmute(site='MORA',plot_id=str_to_upper(plot_id),burned=burnt,
        fire_assignment_source='MORA mapped disturbance 1987-2017'),
    read_csv(here('output/NOCA_fire_assignment_audit.csv'),show_col_types=FALSE) |>
      transmute(site='NOCA',plot_id=str_to_upper(plot_id),burned=burnt,
        fire_assignment_source=assignment_source))
  if (anyDuplicated(modern_fire[c('site','plot_id')])) stop('Duplicate plot fire assignment')
  anth = reference$modern_endpoints |> calculate_tracking_metrics() |>
    add_climate_change_metrics(reference$climate_scaling) |>
    mutate(fire_plot_key=str_to_upper(plot_id)) |>
    left_join(modern_fire |> rename(fire_plot_key=plot_id),
      by=c('site','fire_plot_key'),relationship='many-to-one') |> select(-fire_plot_key)
  if (anyNA(anth$burned)) stop('Missing modern plot fire assignment')
  anth_model = anth |> select(all_of(anthropocene_model_columns()))
}
# Validate calculated products and regression keys before replacing any exports.
tryCatch(validate_tracking_products(by_offset,uncertainty,
  if(bin_width_years==1000L) anth_model else NULL,bin_width_years),error=function(e) {
  stop(conditionMessage(e),'\nObserved/excluded realization diagnostics:\n',
    paste(capture.output(print(excluded,n=40)),collapse='\n'),call.=FALSE)
})
tables = list(cca_tracking_holocene_lake_realizations=realizations,
  cca_tracking_holocene_lake_by_offset=by_offset,
  cca_tracking_holocene_lake_uncertainty=uncertainty,
  cca_tracking_holocene_lake_timeseries=timeseries,
  cca_tracking_holocene_lake_support=support)
for(stem in names(tables)) write_csv(tables[[stem]],output_path(stem))
if(bin_width_years==1000L) {
  tables$cca_tracking_anthropocene_plot_model_input = anth_model
  tables$cca_tracking_anthropocene_plot_calculations = anth
  write_csv(anth_model,here('output/cca_tracking_anthropocene_plot_model_input.csv'))
  write_csv(anth,here('output/cca_tracking_anthropocene_plot_calculations.csv'))
  write_csv(tracking_schema(tables),here('output/cca_tracking_schema.csv'))
  source(here('R/helpers/survey_decision_effects.R'),local=TRUE)
  export_survey_decision_effects(anth)
}
cat('Tracking completed:',nrow(realizations),'lake realizations;',nrow(by_offset),
  'actual lake/offset transitions;',nrow(uncertainty),'uncertainty rows; width',
  bin_width_years,'years.\n')
# END R/stages/09_tracking_metrics.R

# ============================================================================
# BEGIN R/stages/09b_tracking_model_data.R
# ============================================================================
# One combined model input, assembled after the canonical tracking calculations.
# Rscript R/stages/09b_tracking_model_data.R [--bin-width-years=500]
suppressPackageStartupMessages({library(here);library(tidyverse)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
width_arg=grep('^--bin-width-years=',commandArgs(trailingOnly=TRUE),value=TRUE)
if(length(width_arg)>1L) stop('Specify one bin width')
width=validate_tracking_width(if(length(width_arg))
  as.numeric(sub('^--bin-width-years=','',width_arg)) else 1000L)
suffix=if(width==1000L) '' else paste0('_',width,'yr')
b=read_csv(here('output',paste0('cca_tracking_holocene_lake_by_offset',suffix,'.csv')),
  show_col_types=FALSE)
a=read_csv(here('output/cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE)
hc=read_csv(here('output',paste0('cca_tracking_holocene_lake_realizations',suffix,'.csv')),
  show_col_types=FALSE)
ac=read_csv(here('output/cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
if(any(b$climate_dt_years!=width)) stop('Requested width and source table disagree')
lake_locations=read_csv(here('output/chelsa_paleo_ponds.csv'),show_col_types=FALSE) |>
  distinct(site,lake,longitude=lon,latitude=lat)
plot_locations=bind_rows(
  read_csv(here('output/MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='MORA',plot_id,longitude,latitude),
  read_csv(here('output/NOCA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='NOCA',plot_id,longitude,latitude))
combined=combine_tracking_model_data(b,a,lake_locations,plot_locations,hc,ac)
write_csv(combined,here('output',paste0('cca_tracking_era_by_offset',suffix,'.csv')))
if(width==1000L) {
  schema=read_csv(here('output/cca_tracking_schema.csv'),show_col_types=FALSE) |>
    filter(!dataset %in% c('cca_tracking_era_comparison','cca_tracking_era_by_offset'))
  schema=bind_rows(schema,tracking_schema(list(cca_tracking_era_by_offset=combined)))
  write_csv(schema,here('output/cca_tracking_schema.csv'))
}
cat('Combined model input:',nrow(combined),'rows;',ncol(combined),'columns;',
  nrow(b),'Holocene transitions and',nrow(a),'modern pairs, each with',
  length(tracking_combined_response_names()),'responses.\n')
# END R/stages/09b_tracking_model_data.R

# ============================================================================
# BEGIN R/stages/10_tracking_era_models.R
# ============================================================================
# Covariance comparison and selected MA1 results: one transition offset per fit.
# Default: observed and two corrected lag rates, turnover and physical climate rate.
# --metric=NAME selects one response; no response transformation is applied.
# Rscript R/stages/10_tracking_era_models.R [--metric=observed_turnover_rate]
# Optional later width experiments: --bin-width-years=N; never run automatically.
# Same fixed effects and variance groups for AR1, MA1 and independent residuals.
suppressPackageStartupMessages({
  library(here);library(tidyverse);library(nlme);library(emmeans);library(patchwork)
})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
argument=function(name,default) {
  prefix=paste0('--',name,'=')
  found=commandArgs(trailingOnly=TRUE)
  found=found[startsWith(found,prefix)]
  if(length(found)>1L) stop('Specify ',name,' once')
  if(length(found)) substring(found,nchar(prefix)+1L) else default
}
response_metrics=trimws(strsplit(argument('metric',paste(tracking_model_response_names(),collapse=',')),
  ',',fixed=TRUE)[[1]])
if(!length(response_metrics) || any(!response_metrics %in% tracking_model_available_names()) ||
   anyDuplicated(response_metrics)) stop('Specify distinct known responses with --metric')
width=validate_tracking_width(as.numeric(argument('bin-width-years','1000')))
suffix=if(width==1000L) '' else paste0('_',width,'yr')
input_path=here('output',paste0('cca_tracking_era_by_offset',suffix,'.csv'))
combined=read_csv(input_path,show_col_types=FALSE)
if(validate_tracking_model_data(combined)!=width) stop('Requested interval width differs from input')
offsets=seq(0,width-100,100)
model_types=c('AR1','MA1','Independent')
selected_model_type=tracking_selected_model_type()

for(response_metric in response_metrics) {
  response_label=tracking_model_response_label(response_metric)
  response_unit=tracking_model_response_unit(response_metric)

  fit_offset=function(offset,model_type) {
    selected=tracking_offset_model_input(combined,response_metric,offset)
    d=selected$data
    correlation=switch(model_type,
      AR1=corAR1(form=~time_index | series),
      MA1=corARMA(p=0,q=1,form=~time_index | series),
      Independent=NULL,stop('Unknown covariance model'))
    warnings=character()
    fit=withCallingHandlers(
      gls(estimate ~ era * site,data=d,correlation=correlation,
        weights=varIdent(form=~1 | era_site),method='REML',na.action=na.fail,
        control=glsControl(msMaxIter=200)),
      warning=function(w) {warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
    summary_fit=summary(fit)
    tt=summary_fit$tTable
    df=fit$dims$N-fit$dims$p
    ci=qt(.975,df)*tt[,'Std.Error']
    parameters=if(is.null(fit$modelStruct$corStruct)) numeric() else
      unname(coef(fit$modelStruct$corStruct,unconstrained=FALSE))
    if(length(parameters)!=as.integer(model_type!='Independent') ||
       any(!is.finite(parameters)) || any(!is.finite(tt)) || !is.finite(as.numeric(logLik(fit))))
      stop('Invalid fitted numerical results')
    parameter=if(length(parameters)) parameters else NA_real_
    coefficients=tibble(metric=response_metric,offset,model_type,term=rownames(tt),
      estimate=tt[,'Value'],std_error=tt[,'Std.Error'],df,
      t_value=tt[,'t-value'],p_value=tt[,'p-value'],
      conf_low=tt[,'Value']-ci,conf_high=tt[,'Value']+ci,
      n_holocene=sum(d$era=='Holocene'),n_anthropocene=sum(d$era=='Anthropocene'),
      correlation_parameter=parameter,converged=TRUE)
    residuals=d
    residuals$fitted=as.numeric(fitted(fit))
    residuals$normalized_residual=as.numeric(stats::residuals(fit,type='normalized'))
    h=residuals[residuals$era=='Holocene',]
    scale=mean(h$normalized_residual^2)
    lag_products=map_dfr(1:3,function(lag) {
      j=match(paste(h$series,h$time_index+lag),paste(h$series,h$time_index))
      keep=!is.na(j)
      tibble(lag,lag_years=lag*width,n_pairs=sum(keep),
        lag_product=if(any(keep) && scale>0)
          mean(h$normalized_residual[keep]*h$normalized_residual[j[keep]])/scale else NA_real_)
    })
    means=emmeans(fit,~era | site,data=d,mode='satterthwaite')
    mt=as.data.frame(summary(means,infer=c(TRUE,FALSE)))
    mean_table=tibble(metric=response_metric,offset,model_type,site=as.character(mt$site),
      era=as.character(mt$era),estimate=mt$emmean,std_error=mt$SE,df=mt$df,
      conf_low=mt$lower.CL,conf_high=mt$upper.CL,
      n=vapply(seq_len(nrow(mt)),function(i) sum(d$site==mt$site[i] & d$era==mt$era[i]),integer(1)))
    contrasts=contrast(means,method=list('Anthropocene - Holocene'=c(-1,1)))
    ct=as.data.frame(summary(contrasts,infer=c(TRUE,TRUE),adjust='none'))
    contrast_table=tibble(metric=response_metric,offset,model_type,site=as.character(ct$site),
      contrast=as.character(ct$contrast),estimate=ct$estimate,std_error=ct$SE,df=ct$df,
      t_value=ct$t.ratio,p_value=ct$p.value,conf_low=ct$lower.CL,conf_high=ct$upper.CL,
      n_holocene=vapply(as.character(ct$site),function(s) sum(d$era=='Holocene' & d$site==s),integer(1)),
      n_anthropocene=vapply(as.character(ct$site),function(s) sum(d$era=='Anthropocene' & d$site==s),integer(1)))
    counts=as.data.frame(table(d$era,d$site))
    names(counts)=c('era','site','n')
    variance=coef(fit$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
    block=c(paste0('OFFSET ',offset,' | MODEL ',model_type),
      paste('Selected rows:',nrow(d)+nrow(selected$excluded),
        '| Finite rows:',nrow(d),'| Undefined selected responses:',nrow(selected$excluded)),
      if(model_type=='Independent') 'Temporal correlation: none; era/site residual variances retained' else
        paste('Correlation parameter:',format(parameter,digits=8),
          if(model_type=='AR1') '(phi; lag-1 correlation)' else
            paste0('(theta; lag-1 correlation = ',format(parameter/(1+parameter^2),digits=8),')')),
      paste('Warnings:',if(length(warnings)) paste(unique(warnings),collapse='; ') else 'none'),
      capture.output(print(counts)),capture.output(print(summary_fit)),
      'Era means within each park:',capture.output(summary(means,infer=c(TRUE,FALSE))),
      'Anthropocene - Holocene within each park (unadjusted exploratory contrasts):',
      capture.output(summary(contrasts,infer=c(TRUE,TRUE),adjust='none')),
      'Residual SDs:',capture.output(print(fit$sigma*variance)),
      'Holocene normalized residual lag products (diagnostic, not significance tests):',
      capture.output(print(lag_products)),
      if(nrow(selected$excluded)) c('Undefined response identities:',
        capture.output(print(selected$excluded[c('era','site','lake','plot_id','age_hi','age_lo')]))),
      '')
    list(fit=fit,data=d,coefficients=coefficients,means=mean_table,contrasts=contrast_table,residuals=residuals,
      lag_products=lag_products,text=block,offset=offset,model_type=model_type)
  }

  # Calculate every fit before replacing results. A failed fit stops with its key;
  # it never changes observation selection or silently omits an offset/model type.
  fits=list()
  for(offset in offsets) for(model_type in model_types) {
    cat('Fitting',response_metric,'| offset',offset,'|',model_type,'\n')
    fits[[paste(offset,model_type,sep='_')]]=tryCatch(fit_offset(offset,model_type),
      error=function(e) stop('Offset ',offset,' / ',model_type,': ',conditionMessage(e),call.=FALSE))
  }
  coefficients=bind_rows(map(fits,'coefficients'))
  contrasts=bind_rows(map(fits,'contrasts'))
  group_means=tracking_selected_model_results(bind_rows(map(fits,'means')))
  if(nrow(group_means)!=length(offsets)*4L ||
     anyDuplicated(group_means[c('metric','offset','model_type','site','era')]) ||
     any(!is.finite(as.matrix(group_means[c('estimate','std_error','df','conf_low','conf_high')]))))
    stop('Missing, duplicate or undefined selected-model group means')
  if(anyDuplicated(coefficients[c('metric','offset','model_type','term')]) ||
     nrow(coefficients)!=length(offsets)*length(model_types)*4L)
    stop('Missing or duplicate fitted coefficients')
  if(anyDuplicated(contrasts[c('metric','offset','model_type','site')]) ||
     nrow(contrasts)!=length(offsets)*length(model_types)*2L ||
     any(!is.finite(contrasts$estimate) | !is.finite(contrasts$std_error)))
    stop('Missing, duplicate or undefined park contrasts')
  # AIC comparisons require identical observations and fixed effects within an
  # offset. Different offsets remain sensitivity fits with different input rows.
  for(offset in offsets) {
    group=fits[paste(offset,model_types,sep='_')]
    if(!all(vapply(group,function(x) identical(x$data,group[[1]]$data),logical(1))))
      stop('Covariance models use different observations at offset ',offset)
  }
  fit_overview=map_dfr(fits,function(x) tibble(metric=response_metric,offset=x$offset,
    model_type=x$model_type,n_holocene=sum(x$data$era=='Holocene'),
    n_anthropocene=sum(x$data$era=='Anthropocene'),n=nrow(x$data),method=x$fit$method,
    n_parameters=attr(logLik(x$fit),'df'),log_likelihood=as.numeric(logLik(x$fit)),AIC=AIC(x$fit),
    correlation_parameter=x$coefficients$correlation_parameter[1],converged=TRUE)) |>
    group_by(offset) |> mutate(delta_AIC=AIC-min(AIC),
      akaike_weight=exp(-delta_AIC/2)/sum(exp(-delta_AIC/2)),aic_rank=min_rank(AIC)) |>
    ungroup() |> select(metric,offset,model_type,n_holocene,n_anthropocene,n,method,
      n_parameters,log_likelihood,AIC,delta_AIC,akaike_weight,aic_rank,correlation_parameter,converged)
  notes=c('MA1 covariance selected by the author on 2026-10-09; model development and inference remain exploratory.',
    paste('Response:',response_metric,'| Holocene interval / time step:',width,'years'),
    paste('Response units:',response_unit,'| Transformation: none'),
    'Fixed effects: estimate ~ era * site; REML; separate residual SDs by era/site.',
    'Reference categories: Holocene and MORA. Coefficient units follow the selected response.',
    'AR1: corAR1(~ time_index | series). MA1: corARMA(p=0, q=1, ~ time_index | series).',
    'Independent: correlation=NULL; the same era/site residual SDs and fixed effects are retained.',
    'MA1 correlates only observations one actual time step apart within a series; gaps are retained.',
    'For MA1, theta is not the lag-1 correlation: rho(1) = theta/(1 + theta^2); rho(k)=0 for k>1.',
    'Each fit uses one offset and all original modern pairs with a finite selected response.',
    'Modern pairs are singleton series; their internal time index is 0 and their actual dates are retained.',
    'Offsets are sensitivity realizations; the same modern data are reused, so fits are not independent.',
    'Holocene responses are finite chronology-draw medians within actual transitions, without offset aggregation.',
    'Corrected lag rates use (corrected final lag - initial lag)*100/climate elapsed years within each draw before summarizing.',
    'Pace correction remains magnitude-based. Its undefined directions exclude only the pace-corrected response.',
    'No chronology uncertainty propagation, lake random intercept, climate/fire fixed effects or support threshold.',
    'Adjacent Holocene transitions share endpoints; only four lakes and two fire histories are available.',
    'AIC comparisons are meaningful between covariance types within the same offset, not across offsets.',
    'Delta AIC is measured from the minimum within each offset; Akaike weights are relative to these three candidates only.',
    'Boxplots show within-offset delta AIC and summarize offset sensitivity, not independent samples; raw AIC remains in the CSV.',
    'REML is retained because these covariance comparisons use identical fixed effects and observations within each offset.',
    'The comparison retains all candidates; reported coefficients, contrasts and residuals use the author-selected MA1.',
    'The MA1 reporting specification is applied to every requested response; covariance comparisons and diagnostics are response-specific.',
    'Group means and era contrasts use emmeans with Satterthwaite degrees of freedom; contrast SEs use the fitted covariance of the means.',
    'Coefficient intervals and park contrasts are unadjusted exploratory intervals/tests.',
    paste('Input:',basename(input_path),'| MD5:',unname(tools::md5sum(input_path))),
    paste('Script MD5:',unname(tools::md5sum(here('R/stages/10_tracking_era_models.R')))),
    paste('Packages:',paste(sapply(c('nlme','emmeans'),function(p)
      paste(p,as.character(packageVersion(p)))),collapse='; ')))
  out=here('output/exploratory/tracking_offset_models',paste0(response_metric,suffix))
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  write_csv(coefficients,file.path(out,'model_coefficients.csv'))
  write_csv(contrasts,file.path(out,'model_contrasts.csv'))
  write_csv(fit_overview,file.path(out,'model_comparison.csv'))
  write_csv(group_means,file.path(out,'model_group_means.csv'))
  writeLines(c(notes,'','Fit overview:',capture.output(print(as.data.frame(fit_overview),
    digits=8,row.names=FALSE)), '',
    unlist(map(fits,'text')),capture.output(sessionInfo())),file.path(out,'model_results.txt'))

  # Only the selected covariance is presented after the comparison figure.
  model_colors=tracking_model_colors()
  plot_coefficients=tracking_selected_model_results(coefficients)
  plot_contrasts=tracking_selected_model_results(contrasts)
  selected_fits=fits[vapply(fits,function(x) x$model_type==selected_model_type,logical(1))]
  means_plot=tracking_model_group_means_plot(group_means,plot_contrasts,response_metric,offsets)
  coef_plot=ggplot(plot_coefficients,aes(offset,estimate))+
    geom_hline(yintercept=0,color='grey65',linetype='dashed')+
    geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=20,
      color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_line(color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_point(color=unname(model_colors[selected_model_type]),size=2.8)+
    facet_wrap(~term,scales='free_y',ncol=2)+
    scale_x_continuous(breaks=offsets)+
    labs(title=paste('MA(1) coefficients:',response_label),
      subtitle=paste(length(offsets),'offsets; era × site; REML and separate era/site residual variances'),
      x='Bin offset (years)',y='Coefficient estimate',
      caption='Points: coefficients; bars: unadjusted 95% t intervals. Reference: Holocene / MORA.\nOffsets reuse the same modern pairs and are sensitivity fits, not independent replicates.')+
    tracking_model_plot_theme()+theme(
      axis.text.x=element_text(angle=45,hjust=1))
  contrast_plot=ggplot(plot_contrasts,aes(offset,estimate))+
    geom_hline(yintercept=0,color='grey65',linetype='dashed')+
    geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=20,
      color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_line(color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_point(color=unname(model_colors[selected_model_type]),size=2.8)+
    facet_wrap(~site,scales='free_y',nrow=1)+
    scale_x_continuous(breaks=offsets)+
    labs(title=paste('MA(1) era contrasts:',response_label),
      subtitle='Anthropocene minus Holocene within each park; selected MA(1) at every offset',
      x='Bin offset (years)',y='Anthropocene - Holocene',
      caption='Points: model-based era contrasts; bars: unadjusted 95% intervals with Satterthwaite degrees of freedom.\nPositive estimates indicate higher Anthropocene responses. Parks have separate y-scales. Offsets reuse modern pairs and are sensitivity fits.')+
    tracking_model_plot_theme()+theme(
      axis.text.x=element_text(angle=45,hjust=1))

  # Pair each offset's three comparisons. Deterministic point displacement keeps
  # identical-offset pairs visible without treating them as independent samples.
  aic_data=fit_overview |> mutate(model_index=match(model_type,model_types),
    point_x=model_index+(match(offset,offsets)-(length(offsets)+1)/2)/
      max(1,length(offsets)-1)*.24)
  aic_plot=ggplot(aic_data,
    aes(model_index,delta_AIC,group=model_type,fill=model_type))+
    geom_hline(yintercept=0,color='grey55',linetype='dashed')+
    geom_boxplot(width=.48,alpha=.2,outlier.shape=NA,color='grey45')+
    geom_line(aes(x=point_x,group=offset),color='grey65',alpha=.6,linewidth=.4)+
    geom_point(aes(x=point_x,color=model_type),size=2.4)+
    scale_x_continuous(breaks=seq_along(model_types),labels=c('AR(1)','MA(1)','No temporal\nautocorrelation'))+
    scale_color_manual(values=model_colors)+scale_fill_manual(values=model_colors)+
    labs(title=paste('Within-offset covariance comparison:',response_label),
      subtitle=paste(length(offsets),'offsets; same observations, fixed effects, REML and era/site residual variances within each offset'),
      x=NULL,y='AIC - minimum AIC within offset (lower is better)',
      caption='Zero identifies the lowest AIC within each offset. Boxes summarize offsets; dots are fits; grey lines connect the same offset.\nOffsets reuse modern plots and are sensitivity fits, not independent replicates. Raw AIC values remain in model_comparison.csv.\nMA(1) is the requested reporting structure. Assess covariance support separately for each response using this comparison.')+
    theme_minimal(base_size=12)+theme(legend.position='none',panel.grid.minor=element_blank(),
      plot.title=element_text(size=17,face='bold'),plot.subtitle=element_text(size=11),
      plot.caption=element_text(size=10,hjust=0))
  group_colors=c(Holocene.MORA='#059669',Anthropocene.MORA='#2563eb',
    Holocene.NOCA='#c97710',Anthropocene.NOCA='#d42d75')
  residual_panels=list()
  for(x in selected_fits) {
    tag=paste('Offset',x$offset,'|',x$model_type)
    common=theme_minimal(base_size=8)+theme(legend.position='none',
      plot.title=element_text(size=9,face='bold'),plot.subtitle=element_text(size=7))
    p1=ggplot(x$residuals,aes(fitted,normalized_residual,color=era_site))+
      geom_hline(yintercept=0,color='grey65')+geom_point(alpha=.35,size=.5)+
      scale_color_manual(values=group_colors)+
      labs(title=tag,subtitle='Normalized residuals versus fitted',x='Fitted',y='Normalized residual')+common
    qq=x$residuals[order(x$residuals$normalized_residual),]
    qq$theoretical=qnorm(ppoints(nrow(qq)))
    p2=ggplot(qq,aes(theoretical,normalized_residual,color=era_site))+
      geom_abline(intercept=0,slope=1,color='grey50')+geom_point(alpha=.4,size=.5)+
      scale_color_manual(values=group_colors)+
      labs(title=tag,subtitle='Normal Q-Q; pooled normalized residuals',x='Normal quantile',y='Normalized residual')+common
    p3=ggplot(x$lag_products,aes(lag,lag_product))+
      geom_hline(yintercept=0,color='grey65')+
      geom_segment(aes(xend=lag,yend=0),color=unname(model_colors[x$model_type]))+
      geom_point(color=unname(model_colors[x$model_type]),size=1)+
      geom_text(aes(label=paste0('n=',n_pairs)),vjust=-.7,size=2)+
      scale_x_continuous(breaks=1:3)+
      labs(title=tag,subtitle='Holocene residual lag products',x=paste0('Lag (',width,'-year steps)'),y='Lag product')+common
    residual_panels=c(residual_panels,list(p1,p2,p3))
  }
  residual_plot=wrap_plots(residual_panels,ncol=3)+plot_annotation(
    title=paste('MA(1) offset-model residual checks:',response_label),
    subtitle='One row per offset: scatter / Q-Q / Holocene lag products for the selected MA(1)',
    caption='Colors: Holocene MORA green, Holocene NOCA orange, Anthropocene MORA blue, Anthropocene NOCA pink.\nHolocene lag products match actual within-lake time gaps; labels give pair counts. Modern singletons are excluded. No formal lag tests or confidence bands.\nMA(1) selected; distribution and inference remain exploratory. Chronology uncertainty is not propagated.',
    theme=theme(plot.title=element_text(size=18,face='bold'),plot.subtitle=element_text(size=11),
      plot.caption=element_text(size=10,hjust=0)))
  figure_stem=paste0(response_metric,suffix)
  if(render_figures) {
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_group_means_',figure_stem,'.pdf')),
      means_plot,width=14,height=11)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_coefficients_',figure_stem,'.pdf')),
      coef_plot,width=13,height=9)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_contrasts_',figure_stem,'.pdf')),
      contrast_plot,width=13,height=7)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_residuals_',figure_stem,'.pdf')),
      residual_plot,width=12,height=2.6*length(offsets)+1.5,limitsize=FALSE)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_aic_',figure_stem,'.pdf')),
      aic_plot,width=13,height=7)
  }
  cat('Saved',length(fits),'comparison fits; MA1 reported;',nrow(coefficients),'coefficient rows and',
    nrow(contrasts),'park contrasts in',out,'\n')
}
# END R/stages/10_tracking_era_models.R

# ============================================================================
# BEGIN R/stages/10a_tracking_lake_sensitivity.R
# ============================================================================
# Maintained sensitivity: offset 0, one Holocene lake versus its park's modern pairs.
# Default: five rate responses, including the two corrected lag rates; offset 0 only.
# Rscript R/stages/10a_tracking_lake_sensitivity.R [--metric=NAME]
# Optional manual runs: --metric=NAME --offset=N --bin-width-years=N.
suppressPackageStartupMessages({
  library(here);library(tidyverse);library(nlme);library(emmeans)
})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
argument=function(name,default) {
  prefix=paste0('--',name,'=')
  found=commandArgs(trailingOnly=TRUE)
  found=found[startsWith(found,prefix)]
  if(length(found)>1L) stop('Specify ',name,' once')
  if(length(found)) substring(found,nchar(prefix)+1L) else default
}
response_metrics=trimws(strsplit(argument('metric',paste(tracking_model_response_names(),collapse=',')),
  ',',fixed=TRUE)[[1]])
if(!length(response_metrics) || any(!response_metrics %in% tracking_model_available_names()) ||
   anyDuplicated(response_metrics)) stop('Specify distinct known responses with --metric')
width=validate_tracking_width(as.numeric(argument('bin-width-years','1000')))
offset=as.numeric(argument('offset','0'))
suffix=if(width==1000L) '' else paste0('_',width,'yr')
input_path=here('output',paste0('cca_tracking_era_by_offset',suffix,'.csv'))
combined=read_csv(input_path,show_col_types=FALSE)
if(validate_tracking_model_data(combined)!=width) stop('Requested width differs from input')
lakes=combined |> filter(era=='Holocene') |> distinct(site,lake) |> arrange(site,lake)
model_types=c('AR1','MA1')
selected_model_type=tracking_selected_model_type()

for(response_metric in response_metrics) {
  response_label=tracking_model_response_label(response_metric)

  fit_lake=function(lake,model_type) {
    selected=tracking_lake_model_input(combined,response_metric,lake,offset)
    d=selected$data
    correlation=if(model_type=='AR1') corAR1(form=~time_index | series) else
      corARMA(p=0,q=1,form=~time_index | series)
    warnings=character()
    fit=withCallingHandlers(
      gls(estimate ~ era,data=d,correlation=correlation,
        weights=varIdent(form=~1 | era),method='REML',na.action=na.fail,
        control=glsControl(msMaxIter=200)),
      warning=function(w) {warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
    tt=summary(fit)$tTable
    df=fit$dims$N-fit$dims$p
    ci=qt(.975,df)*tt[,'Std.Error']
    parameter=unname(coef(fit$modelStruct$corStruct,unconstrained=FALSE))
    boundary=abs(parameter)>.98
    means=emmeans(fit,~era,data=d,mode='satterthwaite')
    ct=as.data.frame(summary(contrast(means,
      method=list('Anthropocene - Holocene'=c(-1,1))),infer=c(TRUE,TRUE),adjust='none'))
    if(length(parameter)!=1L || any(!is.finite(tt)) ||
       any(!is.finite(ct$estimate) | !is.finite(ct$SE) | !is.finite(ct$df)) ||
       !is.finite(as.numeric(logLik(fit)))) stop('Invalid lake fit or contrast')
    coefficients=tibble(metric=response_metric,offset,site=selected$site,lake,model_type,
      term=rownames(tt),estimate=tt[,'Value'],std_error=tt[,'Std.Error'],df,
      t_value=tt[,'t-value'],p_value=tt[,'p-value'],
      conf_low=tt[,'Value']-ci,conf_high=tt[,'Value']+ci,
      n_holocene=sum(d$era=='Holocene'),n_anthropocene=sum(d$era=='Anthropocene'),
      correlation_parameter=parameter,near_correlation_boundary=boundary,converged=TRUE)
    contrasts=tibble(metric=response_metric,offset,site=selected$site,lake,model_type,
      contrast=as.character(ct$contrast),estimate=ct$estimate,std_error=ct$SE,df=ct$df,
      t_value=ct$t.ratio,p_value=ct$p.value,conf_low=ct$lower.CL,conf_high=ct$upper.CL,
      n_holocene=sum(d$era=='Holocene'),n_anthropocene=sum(d$era=='Anthropocene'),
      correlation_parameter=parameter,near_correlation_boundary=boundary,converged=TRUE)
    block=c(paste('LAKE',lake,'| PARK',selected$site,'| OFFSET',offset,'| MODEL',model_type),
      paste('Holocene transitions:',sum(d$era=='Holocene'),'| Modern pairs:',sum(d$era=='Anthropocene'),
        '| Undefined selected responses:',nrow(selected$excluded)),
      paste('Correlation parameter:',format(parameter,digits=8),
        if(model_type=='AR1') '(phi)' else paste0('(theta; rho(1) = ',
          format(parameter/(1+parameter^2),digits=8),')')),
      paste('Near correlation boundary (absolute parameter > 0.98):',boundary),
      paste('Warnings:',if(length(warnings)) paste(unique(warnings),collapse='; ') else 'none'),
      capture.output(print(summary(fit))),
      'Era means:',capture.output(summary(means,infer=c(TRUE,FALSE))),
      'Anthropocene - Holocene:',capture.output(print(ct)),
      if(nrow(selected$excluded)) c('Undefined response identities:',
        capture.output(print(selected$excluded[c('era','site','lake','plot_id','age_hi','age_lo')]))),'')
    list(coefficients=coefficients,contrasts=contrasts,text=block)
  }

  # A failed fit stops with its key before replacing the sensitivity products.
  fits=list()
  for(lake in lakes$lake) for(model_type in model_types) {
    cat('Lake sensitivity:',lake,'| offset',offset,'|',model_type,'\n')
    fits[[paste(lake,model_type,sep='_')]]=tryCatch(fit_lake(lake,model_type),
      error=function(e) stop('Lake ',lake,' / ',model_type,': ',conditionMessage(e),call.=FALSE))
  }
  coefficients=bind_rows(map(fits,'coefficients'))
  contrasts=bind_rows(map(fits,'contrasts'))
  if(nrow(coefficients)!=nrow(lakes)*length(model_types)*2L ||
     anyDuplicated(coefficients[c('metric','offset','site','lake','model_type','term')]) ||
     nrow(contrasts)!=nrow(lakes)*length(model_types) ||
     anyDuplicated(contrasts[c('metric','offset','site','lake','model_type')]))
    stop('Missing or duplicate lake sensitivity results')
  out=here('output/exploratory/tracking_lake_sensitivity',paste0(response_metric,suffix),paste0('offset_',offset))
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  write_csv(coefficients,file.path(out,'model_coefficients.csv'))
  write_csv(contrasts,file.path(out,'model_contrasts.csv'))
  notes=c('Lake sensitivity; MA1 selected by the author on 2026-10-09; inference remains exploratory.',
    paste('Response:',response_metric,'| Offset:',offset,'| Holocene interval:',width,'years'),
    paste('Response units:',tracking_model_response_unit(response_metric),'| Transformation: none'),
    'Each fit compares one Holocene lake with all finite modern responses from the same park.',
    'Constant site is removed: estimate ~ era; REML; separate residual variances by era.',
    'AR1 or MA1 correlation retains actual within-lake gaps; modern pairs are singleton series.',
    'Comparison records retain AR1 and MA1; reported lake coefficients and contrasts use only the selected MA1.',
    'MORA lake fits reuse the same modern plots; they are not independent comparisons.',
    'Near-boundary fits are retained and flagged when the absolute correlation parameter exceeds 0.98.',
    'No chronology propagation, support cutoff, lake random effect or climate/fire fixed effects.',
    'No pooled averaging of lake fits and no AIC comparisons between different lake inputs.',
    paste('Input MD5:',unname(tools::md5sum(input_path))),
    paste('Script MD5:',unname(tools::md5sum(here('R/stages/10a_tracking_lake_sensitivity.R')))))
  writeLines(c(notes,'',unlist(map(fits,'text')),capture.output(sessionInfo())),file.path(out,'model_results.txt'))

  lake_labels=c(JayBath='Jay Bath',LogWallow='Log Wallow',ReflectionPond='Reflection Pond',
    PantherPotholes='Panther Potholes')
  counts=contrasts |> distinct(lake,site,n_holocene,n_anthropocene)
  counts$label=paste0(unname(lake_labels[counts$lake]),' (',counts$site,')\n',
    counts$n_holocene,' Holocene / ',counts$n_anthropocene,' modern')
  plot_coefficients=tracking_selected_model_results(coefficients) |>
    left_join(counts |> select(lake,label),by='lake',relationship='many-to-one')
  plot_contrasts=tracking_selected_model_results(contrasts) |>
    left_join(counts |> select(lake,label),by='lake',relationship='many-to-one')
  plot_coefficients$label=factor(plot_coefficients$label,levels=rev(counts$label))
  plot_contrasts$label=factor(plot_contrasts$label,levels=rev(counts$label))
  plot_coefficients$term=factor(plot_coefficients$term,levels=c('(Intercept)','eraAnthropocene'),
    labels=c('Holocene mean (intercept)','Anthropocene - Holocene (era coefficient)'))
  colors=tracking_model_colors()
  base_plot=function(tbl) ggplot(tbl,aes(estimate,label))+
    geom_vline(xintercept=0,linetype='dashed',color='grey60')+
    geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.2,
      color=unname(colors[selected_model_type]),linewidth=.6)+
    geom_point(aes(shape=near_correlation_boundary),color=unname(colors[selected_model_type]),size=2.8)+
    scale_shape_manual(values=c('FALSE'=16,'TRUE'=17),labels=c('FALSE'='No','TRUE'='Yes'))+
    tracking_model_plot_theme()
  coef_plot=base_plot(plot_coefficients)+facet_wrap(~term,scales='free_x',nrow=1)+
    labs(title=paste('MA(1) lake sensitivity coefficients:',response_label),
      subtitle=paste('Offset',offset,'; each lake compared with modern pairs from its own park'),
      x='Coefficient estimate',y=NULL,shape='Near boundary',
      caption='Bars: unadjusted 95% t intervals. Coefficient panels use separate x-scales.\nTriangles flag absolute correlation parameters > 0.98. MORA fits reuse modern plots. MA(1) selected; inference remains exploratory.')
  contrast_plot=base_plot(plot_contrasts)+
    labs(title=paste('MA(1) lake sensitivity era contrasts:',response_label),
      subtitle=paste('Offset',offset,'; Anthropocene minus Holocene within each lake/park comparison'),
      x='Anthropocene - Holocene',y=NULL,shape='Near boundary',
      caption='Bars: unadjusted 95% intervals with Satterthwaite degrees of freedom.\nTriangles flag absolute correlation parameters > 0.98. Only 6-10 Holocene transitions support primary fits; inference remains exploratory.')
  if(render_figures) {
    stem=paste0(response_metric,suffix,'_offset_',offset)
    ggsave(here('plot/test_figures',paste0('fig_tracking_lake_coefficients_',stem,'.pdf')),coef_plot,width=14,height=7.5)
    ggsave(here('plot/test_figures',paste0('fig_tracking_lake_contrasts_',stem,'.pdf')),contrast_plot,width=12,height=7)
  }
  cat('Saved',length(fits),'lake sensitivity fits in',out,'\n')
}
# END R/stages/10a_tracking_lake_sensitivity.R

# ============================================================================
# BEGIN R/stages/10b_tracking_manuscript_figure.R
# ============================================================================
# Manuscript Figure 4: offset-0 MA1 contrasts and corrected-lag scatter panels.
# Read maintained model input/results; no refitting, transforms or geometry calculations.
# Rscript R/stages/10b_tracking_manuscript_figure.R
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
metrics=c('standardized_climate_change_rate','observed_turnover_rate','lag_rate_per_century',
  tracking_corrected_response_names())
combined=read_csv(here('output/cca_tracking_era_by_offset.csv'),show_col_types=FALSE)
if(validate_tracking_model_data(combined)!=1000L)
  stop('The primary manuscript figure requires the 1,000-year analysis')
raw=map_dfr(metrics,function(metric) tracking_offset_model_input(combined,metric,0)$data)
read_results=function(metric,filename) {
  read_csv(here('output/exploratory/tracking_offset_models',metric,filename),show_col_types=FALSE) |>
    filter(offset==0,model_type==tracking_selected_model_type())
}
means=map_dfr(metrics,read_results,filename='model_group_means.csv')
contrasts=map_dfr(metrics,read_results,filename='model_contrasts.csv')
keys=c('metric','site','era')
counts=raw |> count(across(all_of(keys)),name='n_raw')
check=full_join(means,counts,by=keys,relationship='one-to-one')
if(nrow(means)!=20L || anyDuplicated(means[keys]) ||
   nrow(contrasts)!=10L || anyDuplicated(contrasts[c('metric','site')]) ||
   nrow(check)!=20L || anyNA(check[c('n','n_raw')]) || any(check$n!=check$n_raw) ||
   any(!is.finite(as.matrix(means[c('estimate','conf_low','conf_high')]))) ||
   any(!is.finite(as.matrix(contrasts[c('estimate','conf_low','conf_high','p_value')]))) ||
   any(contrasts$p_value<0 | contrasts$p_value>1))
  stop('Missing, duplicate or inconsistent offset-0 model results and raw inputs')
ratios=means |> select(all_of(keys),estimate) |>
  pivot_wider(names_from=era,values_from=estimate) |>
  left_join(contrasts |> select(metric,site,contrast_estimate=estimate),
    by=c('metric','site'),relationship='one-to-one')
if(any(abs(ratios$Anthropocene-ratios$Holocene-ratios$contrast_estimate)>1e-8))
  stop('Displayed contrast disagrees with the difference between fitted means')
ratios=ratios |> transmute(metric,site,ratio=Anthropocene/Holocene)
site_colors=c(MORA='#648FFF',NOCA='#FE6100')
response_colors=c(Observed='#40AB9D',Direction='#8B85F1',Pace='#DE85F0')
metric_kind=c(lag_rate_per_century='Observed',pace_corrected_lag_rate_per_century='Pace',
  direction_corrected_lag_rate_per_century='Direction')
cl=contrasts |> left_join(ratios,by=c('metric','site'),relationship='one-to-one') |>
  mutate(metric=factor(metric,levels=metrics),site=factor(site,levels=names(site_colors)),
    kind=unname(metric_kind[as.character(metric)]),
    error_alpha=if_else(p_value<.05,1,.20),
    label=sprintf('%+.2f%s',estimate,if_else(p_value<.05,' *','')),
    fold_label=if_else(is.finite(ratio),sprintf('%.1f\u00d7',ratio),'undefined'))
base_theme=theme_minimal(base_size=22)+theme(panel.grid.minor=element_blank(),
  panel.grid.major.x=element_blank(),axis.text=element_text(size=20,color='grey20'),
  axis.title=element_text(size=23),legend.title=element_text(size=22),
  legend.text=element_text(size=21),plot.margin=margin(10,14,12,14))
pd=position_dodge(width=.64)
# Use two unit scales, but align zero at the same physical height in both panels.
limits=cl |> mutate(panel=if_else(metric=='standardized_climate_change_rate','Climate','CCA')) |>
  group_by(panel) |> summarise(lo=min(c(conf_low,0)),hi=max(c(conf_high,0)),.groups='drop') |>
  mutate(span=pmax(hi-lo,1e-6),upper=hi+.22*span,lower=lo-.22*span)
zero_fraction=max(-limits$lower/(limits$upper-limits$lower))
limits=limits |> mutate(lower=-upper*zero_fraction/(1-zero_fraction))
stopifnot(diff(range(-limits$lower/(limits$upper-limits$lower)))<1e-12)
contrast_plot=function(climate=FALSE) {
  dd=if(climate) filter(cl,metric=='standardized_climate_change_rate') else
    filter(cl,metric!='standardized_climate_change_rate')
  bounds=filter(limits,panel==if(climate) 'Climate' else 'CCA')
  dd=dd |> mutate(label_y=conf_high+.045*bounds$span,fold_y=conf_low-.055*bounds$span)
  context=dd |> filter(is.na(kind));lag=dd |> filter(!is.na(kind))
  p=ggplot(dd,aes(metric,estimate,group=site,fill=site))+
    geom_hline(yintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_errorbar(data=context,aes(ymin=conf_low,ymax=conf_high,alpha=error_alpha,color=site),
      position=pd,width=.10,linewidth=1.3,show.legend=FALSE)+
    geom_errorbar(data=lag,aes(ymin=conf_low,ymax=conf_high,alpha=error_alpha,color=kind),
      position=pd,width=.10,linewidth=1.3,show.legend=FALSE)+
    geom_point(data=context,aes(color=site),position=pd,shape=21,size=3.8,stroke=1.1,show.legend=FALSE)+
    geom_point(data=lag,aes(color=kind),position=pd,shape=21,size=3.8,stroke=1.1)+
    geom_text(aes(y=label_y,label=label,color=site),position=pd,size=5.7,show.legend=FALSE)+
    geom_text(aes(y=fold_y,label=fold_label,color=site),position=pd,vjust=1,size=5.5,show.legend=FALSE)+
    scale_fill_manual(name='Park',values=site_colors)+
    scale_color_manual(name='Lag change',values=c(site_colors,response_colors),
      breaks=c('Observed','Pace','Direction'),labels=c('Observed','Pace corrected','Direction corrected'))+
    guides(color=guide_legend(override.aes=list(fill='white',alpha=1,size=4)),
      fill=guide_legend(override.aes=list(color='grey50',shape=21,size=4)))+
    scale_alpha_identity(guide='none')+
    scale_x_discrete(labels=c(standardized_climate_change_rate='Climate-change\nrate',
      observed_turnover_rate='Community\nturnover rate',lag_rate_per_century='Observed',
      pace_corrected_lag_rate_per_century='Pace corrected',
      direction_corrected_lag_rate_per_century='Direction corrected'),expand=expansion(add=.55))+
    scale_y_continuous(position=if(climate) 'left' else 'right',expand=expansion(mult=0))+
    coord_cartesian(ylim=c(bounds$lower,bounds$upper),expand=FALSE,clip='off')+
    labs(x=NULL,y='Anthropocene − Holocene')+base_theme
  if(!climate) {
    y= bounds$lower-.155*(bounds$upper-bounds$lower)
    p=p+annotate('segment',x=1.65,xend=4.35,y=y,yend=y,color='grey45',linewidth=.55)+
      annotate('text',x=3,y=y-.06*(bounds$upper-bounds$lower),label='Lag change',size=7)+
      theme(plot.margin=margin(10,14,76,14))
  } else p=p+theme(plot.margin=margin(10,14,76,14))
  p
}
# Each pair is an actual transition/plot; corrected medians were calculated from
# draw-level geometry by stage 09b, never as a difference between two medians.
pair_keys=c('era','site','lake','plot_id','offset','age_hi','age_lo')
pairs=combined |> filter(era=='Anthropocene' | offset==0,
    metric %in% c('lag_rate_per_century',tracking_corrected_response_names())) |>
  select(all_of(pair_keys),metric,estimate) |>
  pivot_wider(names_from=metric,values_from=estimate) |>
  pivot_longer(all_of(tracking_corrected_response_names()),names_to='metric',values_to='corrected_rate') |>
  mutate(correction=unname(metric_kind[metric]))
d=pairs |> filter(is.finite(lag_rate_per_century),is.finite(corrected_rate))
scatter_stats=list()
scatter=function(era_name) {
  ds=filter(d,era==era_name)
  observed=raw |> filter(metric=='lag_rate_per_century',era==era_name)
  mt=means |> filter(metric=='lag_rate_per_century',era==era_name)
  lim=range(c(ds$corrected_rate,ds$lag_rate_per_century,mt$conf_low,mt$conf_high,0))
  lim=lim+c(-1,1)*diff(lim)*.055
  stats=ds |> group_by(correction) |> group_modify(function(g,key) {
    test=cor.test(g$lag_rate_per_century,g$corrected_rate,method='spearman',
      alternative='two.sided',exact=FALSE)
    tibble(n_pairs=nrow(g),rho=unname(test$estimate),p_value=test$p.value)
  }) |> ungroup() |> mutate(era=era_name,
    p_text=if_else(p_value<.001,sprintf('%.1e',p_value),sprintf('%.3f',p_value)),
    label=sprintf('\u03c1 = %.2f, p = %s',rho,p_text),
    label_x=lim[1]+.04*diff(lim),
    label_y=lim[2]-(.055+.11*(match(correction,c('Direction','Pace'))-1))*diff(lim))
  scatter_stats[[era_name]] <<- stats
  p=ggplot(ds,aes(lag_rate_per_century,corrected_rate))+
    geom_hline(yintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_vline(xintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_abline(intercept=0,slope=1,linetype='dashed',color='grey50',linewidth=.6)+
    geom_point(aes(fill=site,color=correction,shape=correction),
      size=if(era_name=='Holocene') 2.1 else 1.7,alpha=.35,stroke=.5,show.legend=FALSE)+
    geom_smooth(aes(color=correction,group=correction),method='lm',formula=y~x,
      se=FALSE,linewidth=1.15,show.legend=FALSE)+
    geom_label(data=stats,aes(x=label_x,y=label_y,label=label,color=correction),inherit.aes=FALSE,
      hjust=0,vjust=1,size=6.1,fill='white',linewidth=0,
      label.padding=grid::unit(.10,'lines'),show.legend=FALSE)+
    scale_fill_manual(values=site_colors,guide='none')+
    scale_color_manual(values=response_colors,guide='none')+
    scale_shape_manual(values=c(Direction=21,Pace=24),guide='none')+
    coord_cartesian(xlim=lim,ylim=lim,expand=FALSE)+
    labs(x='Observed lag-change rate',y='Corrected lag-change rate')+base_theme+
    theme(panel.grid.major.x=element_line(color='grey92',linewidth=.4),
      plot.margin=margin(0,14,12,14))
  den=observed |> group_by(site) |> group_modify(function(g,key) {
    z=density(g$estimate,n=512,from=lim[1],to=lim[2])
    tibble(value=z$x,density=z$y)
  }) |> ungroup()
  peak=max(den$density)
  mt=mt |> mutate(error_y=peak*if_else(site=='MORA',.28,.095),
    cap_lo=error_y-peak*.022,cap_hi=error_y+peak*.022,
    mean_label=sprintf('%+.3f',estimate),label_x=conf_high+.018*diff(lim))
  top=ggplot(den,aes(value,density,color=site,fill=site))+
    geom_hline(yintercept=0,color='grey50',linewidth=.55)+
    geom_area(alpha=.23,position='identity')+geom_line(linewidth=.85)+
    geom_vline(xintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_segment(data=mt,aes(x=conf_low,xend=conf_high,y=error_y,yend=error_y,color=site),
      inherit.aes=FALSE,linewidth=1.3)+
    geom_segment(data=mt,aes(x=conf_low,xend=conf_low,y=cap_lo,yend=cap_hi,color=site),
      inherit.aes=FALSE,linewidth=1.1)+
    geom_segment(data=mt,aes(x=conf_high,xend=conf_high,y=cap_lo,yend=cap_hi,color=site),
      inherit.aes=FALSE,linewidth=1.1)+
    geom_point(data=mt,aes(x=estimate,y=error_y,color=site),inherit.aes=FALSE,
      shape=21,fill='white',size=3.5,stroke=.9)+
    geom_text(data=mt,aes(x=label_x,y=error_y,label=mean_label,color=site),
      inherit.aes=FALSE,hjust=0,vjust=.5,size=5.5,fontface='bold')+
    scale_color_manual(values=site_colors,guide='none')+scale_fill_manual(values=site_colors,guide='none')+
    scale_x_continuous(limits=lim,expand=expansion(mult=0))+
    scale_y_continuous(limits=c(0,NA),expand=expansion(mult=c(0,.08)))+
    labs(title=era_name)+theme_void(base_size=22)+theme(legend.position='none',
      plot.title=element_text(size=26,face='bold'),plot.margin=margin(10,14,0,14))
  wrap_plots(top,p,ncol=1,heights=c(.23,1),guides='auto')
}
first_row=wrap_plots(contrast_plot(TRUE),contrast_plot(FALSE),nrow=1,widths=c(1,4),guides='auto')
second_row=wrap_plots(scatter('Holocene'),scatter('Anthropocene'),nrow=1,guides='auto')
figure=wrap_plots(first_row,second_row,ncol=1,heights=c(1,1.35),guides='collect') &
  theme(legend.position='bottom',plot.background=element_rect(fill='white',color=NA))
if(render_figures) {
  stem=here('plot/fig_tracking_era_distributions')
  ggsave(paste0(stem,'.pdf'),figure,width=19,height=15,device=cairo_pdf,bg='white')
  ggsave(paste0(stem,'.png'),figure,width=19,height=15,dpi=300,bg='white')
}
cat('Manuscript figure verified: offset 0; 20 MA1 means, ten covariance-based contrasts;',
  nrow(raw),'untransformed input values.\n')
# END R/stages/10b_tracking_manuscript_figure.R

# ============================================================================
# BEGIN R/stages/05a_cca_figure.R
# ============================================================================
# =============================================================================
# 05a_cca_figure.R - the main CCA figure: observed vs predicted trajectories
# =============================================================================
# Panel A: the pooled ordination, showing for each site x era BOTH trajectories
#          through time -
#            observed  (solid, filled points)  = WA scores, from composition
#            predicted (dashed, open points)   = LC scores, from climate
#          Arrows run in the direction of time. Where the two paths diverge, the
#          forest is not where climate says it should be; where they run
#          parallel, it is moving as climate asks while holding its offset.
# Panel B: the biplot inset within A, with climate arrows and species scores.
# Panel C: marginal climate-variable effects on constrained inertia; shared
#          climate variance is reported but is not plotted as a separate bar.
# Panel D: species contributions to constrained inertia, with occurrence shading.
#
# Holocene points are site x frozen CC/S-era centroids of the complete 1,000-year
# site-date path; Anthropocene is one point per site per survey. Sources
# R/stages/05_cca_model.R for the model.
# =============================================================================

library(here)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

# Species selection is inherited from the model. Consolidation removes Taxus
# brevifolia and Acer circinatum under the understory rule; Pinus ponderosa is
# retained following the 2026-10-08 reversal of its former manual exclusion.
# 05_cca_model.R defaults extra_exclude to character(0) and cca_suffix to "".
source(here("R/stages/05_cca_model.R"), local = TRUE)
library(ggrepel)
library(patchwork)
source(here("R/helpers/figure_style.R"), local = TRUE)

# The reviewed frozen CC/S-era centroid display is the sole main trajectory
# product. Both publication formats are written when rendering is enabled.
holocene_display_mode = "era_centroid"
cca_figure_stem = "fig_cca_trajectories"
write_cca_png = TRUE

# Inactive retained alternative: the moving-window trajectory branch below is
# available for sensitivity work but is not the selected publication display.
# Its run machinery uses 1,000-yr bins x 10 offsets x age draws and defines
# HOLO_BIN, OFFSETS, N_DRAWS and make_runs(). Sourced rather than reimplemented
# so this figure and the tracking metrics cannot disagree about what a bin is.
HOLO_BIN = 1000
OFFSETS = seq(0, HOLO_BIN - 100, by = 100)
source(here("R/helpers/paleo_runs.R"), local = TRUE)

# A bin_mid is kept only if it is occupied in at least this fraction of the age
# DRAWS. Each bin_mid belongs to exactly one offset, so the denominator is
# N_DRAWS, not the number of runs. Without it the
# oldest and youngest ends of each path sprout ghost bins that exist in one draw
# out of a hundred - a single sample's age tail, drawn as if it were a time step.
min_draw_frac = 0.5

# Species LABELLED in the inset biplot: those whose arrow reaches at least this
# percent of the longest species arrow. Purely a legibility rule - shorter arrows
# sit on the origin where a label cannot be placed. All species are still drawn,
# and panel B shows all of them, so nothing is hidden.
inset_sp_min_pct = 25

base_theme = theme_paleoaces(base_size = PAPER_BASE_SIZE) +
  theme(legend.title = element_blank(), legend.position = "bottom",
        panel.grid.minor = element_blank())

imp    = summary(cca_model)$cont$importance[2, ] * 100
ax_lab = paste0(c("CCA1", "CCA2"), " ", round(imp[1:2], 1), "%")

# Full names for the configured constraints. Their shared derivation is defined
# in R/helpers/climate_variables.R; their active selection and labels live in config.R.
clim_full = CLIMATE_VARIABLE_LABELS[CCA_VARIABLES]
full_name = function(x) unname(ifelse(x %in% names(clim_full), clim_full[x], x))

# -----------------------------------------------------------------------------
# Trajectory points: observed (WA) and predicted (LC) centroids through time
# -----------------------------------------------------------------------------
# Anthropocene: identical valid pairs at BOTH dates, prepared in 05_cca_model.R.
# The full legacy calibration cloud remains in the model/background display.
past_pred = predict(cca_model, newdata = env_past_paired,     type = "lc",
                    scaling = cca_scaling, hill = cca_hill)
past_proj = predict(cca_model, newdata = species_past_paired, type = "wa",
                    scaling = cca_scaling, hill = cca_hill)

anth_pts = bind_rows(
  tibble(plot_id = rownames(species_past_paired), t = "legacy",
         o1 = past_proj[, 1], o2 = past_proj[, 2],
         p1 = past_pred[, 1], p2 = past_pred[, 2]),
  tibble(plot_id = rownames(species_present_final), t = "resurvey",
         o1 = projected_present[, 1], o2 = projected_present[, 2],
         p1 = predicted_present[, 1], p2 = predicted_present[, 2])
) %>%
  left_join(site_lookup, by = "plot_id") %>%
  group_by(site, era = "anthropocene", t) %>%
  summarize(across(c(o1, o2, p1, p2), mean), n = n(), .groups = "drop") %>%
  mutate(order = if_else(t == "legacy", 1, 2), lab = t)
stopifnot(identical(rownames(species_past_paired), rownames(species_present_final)),
          all(is.finite(unlist(select(anth_pts, o1, o2, p1, p2)))))
# Persist the exact paired site means so report claims and Figure 3 are auditable.
write_csv(anth_pts, here("output/cca_trajectory_anthropocene_centroids.csv"))

# Holocene: the 1,000-yr MOVING WINDOW, median across runs.
#
# TWO NESTED AVERAGES, in this order and not the other:
#   1. WITHIN a run - mean POSITION of the samples in the bin. Positions, never
#      pooled assemblages: pooling takes the union of species in the bin, which
#      grows with the number of samples in it (rho up to 0.79) and manufactures
#      compositional change out of sampling effort. Averaging positions has no
#      such dependence.
#   2. ACROSS runs - MEDIAN of those per-run means. Median not mean, because a
#      run whose age draw empties a bin makes that bin's mean jump.
#
# The offsets are POOLED rather than averaged pointwise: each offset produces
# bins at different times, so there is nothing to average pointwise. Ordered by
# bin_mid they ARE the 1,000-yr window slid in 100-yr steps.
#
# The spread across runs is not drawn in this inactive alternative. It is
# quantified by the maintained tracking realization tables and audit figures.
runs = make_runs(bin_width = HOLO_BIN, offsets = OFFSETS)

holo_pos = comparison_df %>%
  filter(era == "holocene") %>%
  select(plot_id, site, o1 = projected_CCA1, o2 = projected_CCA2,
         p1 = predicted_CCA1, p2 = predicted_CCA2)

holo_all = runs %>%
  inner_join(holo_pos, by = "plot_id") %>%
  group_by(site, run_id, bin_mid) %>%
  summarize(across(c(o1, o2, p1, p2), mean), n = n(), .groups = "drop") %>%
  group_by(site, bin_mid) %>%
  summarize(across(c(o1, o2, p1, p2), median), n = median(n),
            n_draws = n(), .groups = "drop") %>%
  mutate(draw_frac = n_draws / N_DRAWS)

# ⚠ THE PATH IS THINNED FOR DISPLAY, NOT DRAWN AT EVERY 100-YR PHASE STEP -
# a DISPLAY decision, and the only place in the analysis where one bin phase is
# privileged over the other four. Why:
#
# Consecutive moving-window points share 9 of their 10 centuries, so 90% of each
# step is the same samples. In a time series that is fine - it is a smoother. In
# a 2-D trajectory it is not: it draws five times more path length than there is
# independent information, and the wander between overlapping windows is mostly
# sampling noise. MORA's median bin holds 7 samples, so exchanging one sample
# moves the point substantially, and the pooled path became an unreadable
# tangle. NOCA (median 35 per bin) was far smoother - i.e. the tangle scales with
# thinness of sampling, which is the signature of noise, not of signal.
#
# What this does and does not cost:
#   costs    the phase of the drawn path is arbitrary (offset 0 of 10).
#   does NOT cost anything in the numbers. The tracking stage computes lag,
#            tracking ratio, and angle per run over all 10 offsets before
#            summarization. Only this inactive display branch fixes a phase.
#   keeps    the age draws. Every point is still the median over N_DRAWS
#            chronologies; it is the bin PHASE that is fixed here, not the age.
#
# Set traj_step = 100 to draw the full moving window instead.
#
# ⚠ SET TO 2000 (Billur, 2026-08-13), so the drawn points coincide with the
# 2000-yr time labels - every vertex is dated, and the path drops from 15 (MORA)
# / 23 (NOCA) points to 4 / 6.
#
# What this does and does not mean:
#   EVERY POINT IS STILL A 1,000-YR BIN MEAN. traj_step selects WHICH bins are
#   drawn; it does not widen them. A vertex at 2250 cal BP is the mean position
#   over its stated 1,000-year window - not a 2,000-yr average.
#   THE PATH THEREFORE SKIPS EVERY OTHER PRIMARY BIN. A segment between two vertices
#   spans 2000 yr, and whatever the composition did in between is not drawn. For
#   a trajectory that is the point - it is a summary of direction - but it means
#   the line must NOT be read as "nothing happened in between".
#   NOTHING IN THE NUMBERS CHANGES. The tracking stage computes all three metrics over EVERY
#   adjacent 1,000-yr bin pair, across all 10 offsets and all age draws. This
#   parameter touches only what this one panel draws.
if (!exists("traj_step")) traj_step = 2000
traj_phase = 0                                  # which of OFFSETS is drawn

holo_pts = if (holocene_display_mode == "trajectory") {
  holo_all %>%
    filter(draw_frac >= min_draw_frac) %>%
    filter(traj_step == 100 |
             (bin_mid - HOLO_BIN / 2 - traj_phase) %% traj_step == 0) %>%
    mutate(era = "holocene", order = -bin_mid, lab = NA_character_)
} else {
  # Selected display: one observed WA and one predicted LC centroid per site x
  # frozen CC/S era. Centroids are calculated from the complete site-date path,
  # then ordered from CC1 to S4 so the original trajectory machinery draws the
  # observed and predicted paths separately with time-direction arrows.
  era_grid_path = here("output/holocene_era_grid.csv")
  if (!file.exists(era_grid_path))
    stop("Missing output/holocene_era_grid.csv; run R/stages/13_holocene_climate_fire_eras.R first.")
  era_grid = read_csv(era_grid_path, show_col_types = FALSE)
  era_levels = c("CC1", "S1", "CC2", "S2", "CC3", "S3", "CC4", "S4")
  if (!identical(unique(era_grid$era_id), era_levels))
    stop("Unexpected Holocene era sequence in holocene_era_grid.csv.")

  era_centroid_audit = holo_all %>%
    filter(draw_frac >= min_draw_frac) %>%
    left_join(select(era_grid, t, era_id, era_class),
              by = c("bin_mid" = "t")) %>%
    filter(!is.na(era_id)) %>%
    group_by(site, era_id, era_class) %>%
    summarize(across(c(o1, o2, p1, p2), mean),
              n_dates = n_distinct(bin_mid), n = median(n), .groups = "drop") %>%
    mutate(era_id = factor(era_id, levels = era_levels),
           era = "holocene", order = match(era_id, era_levels),
           lab = as.character(era_id), bin_mid = NA_real_,
           n_draws = NA_integer_, draw_frac = NA_real_) %>%
    arrange(site, order)

  if (n_distinct(era_centroid_audit$site) != 2L ||
      any(table(era_centroid_audit$site) != length(era_levels)) ||
      anyDuplicated(era_centroid_audit[c("site", "era_id")]))
    stop("Holocene era-centroid construction failed.")

  write_csv(era_centroid_audit %>%
              transmute(site, era_id = as.character(era_id), era_class,
                        observed_CCA1 = o1, observed_CCA2 = o2,
                        predicted_CCA1 = p1, predicted_CCA2 = p2,
                        n_dates, median_samples = n, order),
            here("output/cca_trajectory_era_centroids.csv"))
  era_centroid_audit
}

# Labels at even millennia. With 1,000-year windows and 100-year phases, a bin
# midpoint need not fall exactly on the target; the nearest point within half a
# bin is labelled instead.
if (holocene_display_mode == "trajectory") {
  holo_pts = holo_pts %>%
    group_by(site) %>%
    group_modify(function(g, k) {
      targets = seq(0, 11000, by = 2000)
      hit = purrr::map_int(targets, function(t) {
        i = which.min(abs(g$bin_mid - t))
        if (length(i) && abs(g$bin_mid[i] - t) <= HOLO_BIN / 2) i else NA_integer_
      })
      g$lab[na.omit(hit)] = paste0(targets[!is.na(hit)] / 1000, " ka")
      g
    }) %>%
    ungroup()
}

traj = bind_rows(anth_pts %>% select(-t),
                 holo_pts %>% select(site, era, o1, o2, p1, p2, n, order, lab)) %>%
  mutate(grp = interaction(site, era)) %>%
  arrange(grp, order)

# Long form, so observed vs predicted gets a real legend rather than a caption.
traj_long = bind_rows(
  traj %>% transmute(site, era, grp, order, lab, n, type = "observed",  x = o1, y = o2),
  traj %>% transmute(site, era, grp, order, lab, n, type = "predicted", x = p1, y = p2)
) %>%
  mutate(type = factor(type, levels = c("observed", "predicted"))) %>%
  arrange(grp, type, order)

# EDIT SERIES-LABEL POSITIONS HERE. Each row controls exactly one direct label.
# `anchor_lab` is the trajectory vertex used as the starting position; NA uses
# the mean of that path. `nx_frac` and `ny_frac` are horizontal/vertical offsets
# expressed as fractions of the complete trajectory range: positive = right/up,
# negative = left/down. These labels are drawn without repel so changes here are
# deterministic and easy to tune by eye.
series_label_positions = tribble(
  ~site,  ~era,            ~type,        ~anchor_lab, ~nx_frac, ~ny_frac,
  "MORA", "holocene",     "observed",   "CC4",          0.000,   -0.070,
  "MORA", "holocene",     "predicted",  NA_character_,   0.100,   -0.080,
  "MORA", "anthropocene", "observed",   "legacy",       0.100,    0.080,
  "MORA", "anthropocene", "predicted",  NA_character_,  -0.100,   -0.170,
  "NOCA", "holocene",     "observed",   "CC1",          0.000,    0.070,
  "NOCA", "holocene",     "predicted",  NA_character_,  -0.120,    0.120,
  "NOCA", "anthropocene", "observed",   "resurvey",     0.080,   -0.070,
  "NOCA", "anthropocene", "predicted",  "legacy",       0.100,    0.070)

series_centers = traj_long %>%
  group_by(grp, site, era, type) %>%
  summarize(center_x = mean(x), center_y = mean(y), .groups = "drop")
series_anchors = traj_long %>%
  filter(!is.na(lab)) %>%
  select(site, era, type, anchor_lab = lab, anchor_x = x, anchor_y = y)

series_lab = series_label_positions %>%
  mutate(type = factor(type, levels = levels(traj_long$type))) %>%
  left_join(series_centers, by = c("site", "era", "type")) %>%
  left_join(series_anchors, by = c("site", "era", "type", "anchor_lab")) %>%
  mutate(
    x = if_else(is.na(anchor_lab), center_x, anchor_x),
    y = if_else(is.na(anchor_lab), center_y, anchor_y),
    lab = paste0(site, " ",
      if_else(era == "holocene", "Holocene", "Anthropocene"), "\n",
      str_to_title(as.character(type))),
    nx = nx_frac * diff(range(traj_long$x)),
    ny = ny_frac * diff(range(traj_long$y))
  )

expected_series_labels = as.vector(outer(
  c("MORA", "NOCA"),
  c("Holocene\nObserved", "Holocene\nPredicted",
    "Anthropocene\nObserved", "Anthropocene\nPredicted"),
  paste))
stopifnot(nrow(series_lab) == 8L,
          setequal(series_lab$lab, expected_series_labels),
          !anyDuplicated(series_lab[c("site", "era", "type")]),
          all(is.finite(series_lab$x)), all(is.finite(series_lab$y)),
          all(is.finite(series_lab$nx)), all(is.finite(series_lab$ny)))

# Arrowheads every arrow_every-th step. With few, widely spaced points every
# segment should carry its own head; at traj_step = 100 a head on every step
# would be a solid line of arrowheads.
arrow_every = if (traj_step >= 1000) 1 else if (traj_step >= 500) 2 else 5

steps = traj_long %>%
  group_by(grp, type) %>%
  mutate(xend = lead(x), yend = lead(y), step = row_number()) %>%
  ungroup() %>%
  filter(!is.na(xend))

step_heads = steps %>%
  filter(era == "anthropocene" | step %% arrow_every == 0)

# Labels: every second bin on the observed Holocene path, both ends of every
# observed path, and the two ends of the predicted Holocene paths (which run far
# from their observed counterparts, so they need anchoring in time). The
# Anthropocene predicted path is left unlabelled - it has two points sitting
# right beside the observed ones, so labelling it just prints each year twice.
# Observed paths get EVERY bin labelled; predicted paths only their two ends,
# nudged below the vertex so the text does not sit on the point it marks.
lab_pts = traj_long %>%
  group_by(grp, type) %>%
  mutate(is_end = row_number() %in% c(1, n())) %>%
  ungroup()
if (holocene_display_mode == "trajectory") {
  lab_pts = lab_pts %>%
    filter(type == "observed" | (type == "predicted" & era == "holocene" & is_end)) %>%
    # Holocene labels are pre-thinned to the millennia above; everything else
    # (both Anthropocene points, and the ends of the predicted Holocene paths)
    # keeps whatever label it has.
    filter(!is.na(lab) | (era == "holocene" & type == "predicted" & is_end)) %>%
    # The two ends of a predicted Holocene path rarely fall on a millennium, so
    # they get their own age rather than an empty label - they run far from their
    # observed counterparts and need anchoring in time. order = -bin_mid.
    mutate(lab = if_else(is.na(lab), sprintf("%.1f ka", -order / 1000), lab),
           ny = if_else(type == "predicted", -0.03 * diff(range(traj_long$y)), 0))
} else {
  # Label the observed CC/S centroids. Predicted centroids remain visible through
  # the original observed/predicted alpha legend without duplicating every label.
  lab_pts = lab_pts %>%
    filter(type == "observed", !is.na(lab)) %>%
    mutate(ny = 0)
}


# -----------------------------------------------------------------------------
# Inset: the plain biplot - climate constraint arrows + species scores
# -----------------------------------------------------------------------------
env_bp = as_tibble(scores(cca_model, display = "bp", choices = 1:2,
                          scaling = cca_scaling, hill = cca_hill), rownames = "variable")
sp_bp  = as_tibble(scores(cca_model, display = "species", choices = 1:2,
                          scaling = cca_scaling, hill = cca_hill), rownames = "species")

# Climate and species labels go in ONE repel layer, or they only avoid their own
# kind and collide with each other. Every label gets a leader line
# (min.segment.length = 0), so species with near-zero loadings - Abies amabilis
# sits almost exactly on the origin - are pulled out to where they can be read
# instead of piling up on the axis crossing.
# Which species get a LABEL in the inset is a legibility question, not an
# importance one: a species sitting near the origin cannot be labelled without
# the text landing on the axis crossing. The criterion is therefore arrow length
# relative to the longest arrow - explicitly NOT a contribution measure. (They
# are unrelated here: Spearman(arrow length, goodness) = -0.04, and Pinus
# contorta has the longest arrow but one of the lowest goodness values.)
# Every species is still DRAWN; only the label is withheld.
sp_contrib = sp_bp %>%
  mutate(arrow_len = sqrt(CCA1^2 + CCA2^2),
         arrow_pct = 100 * arrow_len / max(arrow_len)) %>%
  arrange(desc(arrow_pct))

sp_inset   = sp_contrib %>% filter(arrow_pct >= inset_sp_min_pct)
sp_dropped = sp_contrib %>% filter(arrow_pct <  inset_sp_min_pct)

# Climate labels are nudged OUTWARD along their own arrow before repel runs.
# Without it repel can park a label on the far side of the origin from the arrow
# it names - "Mean summer temperature" was landing to the left while its arrow
# pointed right - because the four arrow tips sit close together under scaling 1.
# ARROW SCALING. The constraint arrows were drawn at a FIXED x2, which worked
# while the species cloud was compact. It is not: Pinus albicaulis sits at
# (3.57, 4.39) - kept deliberately, see 05_cca_model.R - and it stretches this
# panel so far that the four climate arrows collapse onto the origin, which is
# the one thing this panel exists to show. The multiplier is therefore tied to
# the species extent, so the arrows fill a fixed FRACTION of the panel whatever
# the species set does. Direction and relative length are untouched - only the
# common scale factor changes, which is standard biplot practice and carries no
# interpretation (arrow length is comparable BETWEEN arrows, never to the species).
arrow_mult = 0.62 * max(sqrt(sp_bp$CCA1^2 + sp_bp$CCA2^2)) /
                    max(sqrt(env_bp$CCA1^2 + env_bp$CCA2^2))
cat("\nbiplot arrow multiplier: ", round(arrow_mult, 2),
    " (was a fixed 2; rescaled because the species extent is ",
    round(max(sqrt(sp_bp$CCA1^2 + sp_bp$CCA2^2)), 2), ")\n", sep = "")

inset_labs = bind_rows(
  env_bp %>% mutate(r = sqrt(CCA1^2 + CCA2^2)) %>%
    transmute(x = CCA1 * arrow_mult, y = CCA2 * arrow_mult, label = full_name(variable),
              col = "black", fface = "bold", sz = 2.4,
              # nudge outward along the arrow, in the SAME units the arrows are
              # now drawn in - it was tied to the old fixed x2 and would drop the
              # labels near the origin once the arrows were rescaled
              nx = CCA1 / r * 0.5 * max(r) * arrow_mult,
              ny = CCA2 / r * 0.5 * max(r) * arrow_mult),
  sp_inset %>% transmute(x = CCA1, y = CCA2, label = species,
                         col = "grey30", fface = "italic", sz = 2.15,
                         nx = 0, ny = 0)
)
# Text sizes are tied to the inset's PHYSICAL size, not to the data: the box was
# halved above, and at the old 2.8/2.6 the four climate labels collided and
# "Callitropsis nootkatensis" ran off the right edge. Adjust these together with
# the inset_element() extents below, never one without the other.

p_inset = ggplot() +
  geom_hline(yintercept = 0, color = "grey88", linewidth = 0.3) +
  geom_vline(xintercept = 0, color = "grey88", linewidth = 0.3) +
  geom_segment(data = sp_bp, aes(0, 0, xend = CCA1, yend = CCA2),
               color = "grey70", linewidth = 0.3) +
  geom_point(data = sp_bp, aes(CCA1, CCA2), color = "grey55", size = 0.7) +
  geom_segment(data = env_bp, aes(0, 0, xend = CCA1 * arrow_mult, yend = CCA2 * arrow_mult),
               arrow = arrow(length = unit(0.22, "cm")), color = "black", linewidth = 0.9) +
  geom_text_repel(data = inset_labs,
                  aes(x, y, label = label, color = col, fontface = fface, size = sz),
                  nudge_x = inset_labs$nx, nudge_y = inset_labs$ny,
                  segment.size = 0.2, segment.color = "grey60", segment.alpha = 0.8,
                  box.padding = 0.3, point.padding = 0.2,
                  # high pull, low push: labels stay anchored to what they name.
                  # Summer and winter temperature point within 19 deg of each
                  # other, so without a strong pull repel throws one across the
                  # origin, away from the arrow it belongs to.
                  force = 1.5, force_pull = 8,
                  min.segment.length = 0, max.overlaps = Inf,
                  max.iter = 200000, seed = 11) +
  scale_color_identity() +
  scale_size_identity() +
  scale_discrete_identity(aesthetics = "fontface") +
  scale_x_continuous(expand = expansion(mult = 0.30)) +
  scale_y_continuous(expand = expansion(mult = 0.20)) +
  # Back to an INSET (Billur, 2026-08-13), now at the TOP RIGHT of panel A - the
  # corner the trajectories leave empty. Compact styling: no axes, since an inset
  # this size cannot carry readable ones, and the arrow directions are what it is
  # for. It keeps the rescaled arrows (see arrow_mult above), without which the
  # four constraints collapse onto the origin at this size.
  # No title: the arrows and species names say what it is, and a header inside a
  # box this small costs more room than it earns.
  labs(tag = "B.", x = NULL, y = NULL) +
  theme_void(base_size = 9) +
  theme(panel.background = element_rect(fill = alpha("white", 0.93), color = "grey70",
                                        linewidth = 0.4),
        plot.margin = margin(4, 6, 4, 6),
        plot.tag = element_text(face = "bold", size = PAPER_PANEL_TAG_SIZE),
        plot.tag.position = "topleft",
        legend.position = "none")

# -----------------------------------------------------------------------------
# Panel A: trajectories
# -----------------------------------------------------------------------------
# NO `site` column, so facet_wrap draws the SAME calibration cloud in every panel.
# Deliberate: an identical background in both facets is what makes the two panels
# visually comparable. Splitting it per site would also be informative (the two
# sites' plots occupy different parts of the space) but would change what the grey
# means between panels, which is the wrong trade for a headline figure.
calib_proj = predict(cca_model, newdata = species_past_final, type = "wa",
                     scaling = cca_scaling, hill = cca_hill)
calib = tibble(o1 = calib_proj[, 1], o2 = calib_proj[, 2])
stopifnot(nrow(calib) == nrow(species_past_final), all(is.finite(as.matrix(calib))))

# Observed vs predicted is carried by OPACITY, not line type: at these path
# lengths a dashed line reads as a broken line rather than as a second series.
alpha_type = c(observed = 1, predicted = 0.18)

# ZOOM. The trajectories occupy 20% of the area the calibration cloud forces the
# axes to cover (CCA1 -1.22 to 2.69 against paths at -0.43 to 0.79), so four
# fifths of the panel was empty. coord_cartesian CLIPS the view without dropping
# any data - the cloud is cropped, not filtered, so nothing is silently removed
# from the model. How many plots fall outside is printed and captioned.
zpad = 0.12
zx = range(traj_long$x) + c(-1, 1) * zpad * diff(range(traj_long$x))
zy = range(traj_long$y) + c(-1, 1) * zpad * diff(range(traj_long$y))

# HEADROOM FOR THE INSET. The biplot sits at the top right of panel A, so that
# corner has to be empty - otherwise it lands on the MORA Holocene path, whose
# oldest point is the closest thing to it. Reserved by extending the view rather
# than by shrinking the inset, so the inset stays readable. Checked below.
zx[2] = zx[2] + 0.30 * diff(zx)
# Extra display space keeps the refitted ponderosa model's era labels clear of B.
zy[2] = zy[2] + 0.35 * diff(zy)

n_out = sum(calib$o1 < zx[1] | calib$o1 > zx[2] | calib$o2 < zy[1] | calib$o2 > zy[2])

# The inset occupies the top-right corner in NORMALISED panel coordinates. Assert
# no trajectory point falls inside it, so it cannot silently cover the data.
INSET_BOX = c(left = 0.45, bottom = 0.54, right = 1.00, top = 1.00)

# ⚠ CHECK THE LABELS, NOT JUST THE POINTS. The first version of this test looked
# at trajectory vertices only and passed cleanly while the inset's bottom-left
# corner sat on MORA's "6 ka" label - a label is offset from its point and repel
# moves it further, so a vertex outside the box is no guarantee its text is.
# lab_pts is checked with a margin to stand in for that displacement.
LAB_MARGIN = 0.04
inset_hits = function(df, margin = 0) df %>%
  mutate(nx = (x - zx[1]) / diff(zx), ny = (y - zy[1]) / diff(zy)) %>%
  filter(nx > INSET_BOX["left"] - margin, ny > INSET_BOX["bottom"] - margin)

hidden     = inset_hits(traj_long)
hidden_lab = inset_hits(lab_pts, LAB_MARGIN)
hidden_series = inset_hits(series_lab, LAB_MARGIN)
if (nrow(hidden) || nrow(hidden_lab) || nrow(hidden_series))
  warning("inset would cover ", nrow(hidden), " trajectory point(s) and ",
          nrow(hidden_lab), " time label(s) and ", nrow(hidden_series),
          " series-label anchor(s): ",
          paste(unique(c(hidden$grp, hidden_lab$lab, hidden_series$lab)),
                collapse = ", "),
          " - raise INSET_BOX['bottom'] or widen the headroom above")
cat("\ninset check: ", nrow(hidden), " trajectory points and ", nrow(hidden_lab),
    " time labels and ", nrow(hidden_series),
    " series-label anchors fall under the inset box\n", sep = "")

# BOTH VIEWS ARE DRAWN, from ONE definition (Billur, 2026-08-13). They answer
# different questions and neither replaces the other:
#
#   A  ALL TOGETHER, one panel, coloured by site x era - the two sites in a single
#      space, so their positions can be compared directly. This is the original
#      layout. It is the honest view of "where is MORA relative to NOCA", and it
#      is the one that gets crowded.
#   B  FACETED BY SITE, coloured by era - each site's paths get their own panel
#      and cannot overlap the other's. Legible, at the cost of no longer showing
#      the two sites in one space.
#
# The colour mapping differs BY DESIGN and each panel carries its own legend: in A
# colour must encode site AND era (4 series in one space); in B site is the facet,
# so panel B uses its era legend. Panel A keeps the same MORA blue and NOCA
# orange across eras; endpoint shapes and labels identify the modern comparison.
# Built by one function so the two panels
# cannot drift apart in anything except the mapping.
traj_panel = function(colour_var, pal, tag, facet = FALSE, title = NULL,
                      subtitle = NULL, caption = NULL) {
  cv = sym(colour_var)
  p = ggplot() +
    geom_hline(yintercept = 0, color = "grey90") +
    geom_vline(xintercept = 0, color = "grey90") +
    geom_point(data = calib, aes(o1, o2), color = "grey80", size = 0.5, alpha = 0.3) +
    # Points first, arrows second: the arrowheads must sit ON TOP of the vertex
    # circles, or a white-filled point masks the head of the arrow arriving at it.
    # At traj_step = 100 a circle on every Holocene point beads the whole path, so
    # vertices are drawn only for the Anthropocene pair.
    geom_point(data = if (traj_step >= 500) traj_long
                      else traj_long %>% filter(era == "anthropocene"),
               aes(x, y, color = !!cv, alpha = type),
               shape = 21, fill = "white", size = 1.9, stroke = 0.7,
               show.legend = FALSE) +
    geom_segment(data = steps,
                 aes(x, y, xend = xend, yend = yend, color = !!cv, alpha = type,
                     group = interaction(grp, type)),
                 linewidth = 0.6, lineend = "round", show.legend = FALSE) +
    geom_segment(data = step_heads,
                 aes(x, y, xend = xend, yend = yend, color = !!cv, alpha = type),
                 arrow = arrow(length = unit(0.16, "cm"), type = "closed"),
                 linewidth = 0.6, lineend = "butt", show.legend = TRUE) +
    # Predicted labels share the predicted-path transparency. Every text layer
    # stays out of the guide so the alpha legend contains arrows, never "a" glyphs.
    geom_text_repel(data = lab_pts,
                    aes(x, y, label = lab, color = !!cv, alpha = type),
                    size = 3.0, nudge_y = lab_pts$ny,
                    # high pull keeps each time label beside its own vertex; the
                    # tightly-spaced predicted paths otherwise fling labels away
                    force = 1.5, force_pull = 6, box.padding = 0.16, point.padding = 0.1,
                    segment.size = 0.2, segment.alpha = 0.6, min.segment.length = 0.2,
                    max.overlaps = Inf, max.iter = 100000, seed = 3,
                    show.legend = FALSE) +
    geom_text(data = series_lab,
              aes(x + nx, y + ny, label = lab, color = !!cv, alpha = type),
              size = 3.85, fontface = "bold", lineheight = 0.82,
              show.legend = FALSE) +
    coord_cartesian(xlim = zx, ylim = zy) +
    scale_color_manual(values = pal) +
    scale_alpha_manual(values = alpha_type,
                       labels = c(observed = "Observed", predicted = "Predicted")) +
    labs(x = ax_lab[1], y = ax_lab[2], tag = tag, title = title,
         subtitle = subtitle, caption = caption) +
    guides(color = "none",
           alpha = guide_legend(order = 1, nrow = 1, title = NULL,
                                override.aes = list(color = "grey25",
                                  linewidth = 1.1))) +
    base_theme +
    theme(plot.margin = margin(6, 6, 6, 6),
          plot.title = element_text(face = "bold", size = 12),
          plot.subtitle = element_text(size = 9, color = "grey35"),
          strip.text = element_text(face = "bold", size = 12),
          plot.caption = element_text(hjust = 0, colour = "grey40", size = 8),
          legend.text = element_text(size = 13),
          legend.key.width = unit(2.2, "cm"),
          legend.key.height = unit(.65, "cm"))
  if (facet) p = p + facet_wrap(~ site)
  p
}

# No caption on the figure - it belongs in the paper's legend, so it is printed
# with the rest of the caption material at the end instead. Do NOT lose it: the
# panel is a crop, and a reader who is not told that will read the grey cloud as
# the whole calibration set.
zoom_note = paste0("Zoomed to the trajectories: ", n_out, " of ", nrow(calib),
                   " calibration plots fall outside this view (cropped, not removed).")

pA = traj_panel("grp", color_site_era, "A.", facet = FALSE)

# The facet-by-site version is NOT drawn (Billur, 2026-08-13): both sites in one
# space is the comparison the study is about, and at 2000-yr points that panel is
# no longer crowded enough to need splitting. traj_panel() still takes
# facet = TRUE, so it is one call away if it is ever wanted again.
# Extents come from INSET_BOX, the same vector the overlap check above uses, so
# the assertion can never test a box different from the one drawn. unname() -
# inset_element takes bare numerics and a named vector is a silent trap.
pA_inset = pA + inset_element(p_inset,
                              left   = unname(INSET_BOX["left"]),
                              bottom = unname(INSET_BOX["bottom"]),
                              right  = unname(INSET_BOX["right"]),
                              top    = unname(INSET_BOX["top"]),
                              align_to = "panel")

# -----------------------------------------------------------------------------
# Panels C and D: contributions to the constrained inertia
# -----------------------------------------------------------------------------
# Loadings are NOT repeated here - the inset already shows them, as the direction
# and length of each arrow. This panel shows the other thing: how the constrained
# inertia is divided up.
#
# Both blocks are pieces of the SAME total constrained inertia, but they behave
# completely differently:
#
#   species  inertcomp(display="species")[, "CCA"] / sum(CCA$eig)  -> sums to 100%
#            Species are columns of the RESPONSE, so the constrained inertia
#            decomposes exactly across them. A true contribution.
#
#   climate  marginal ChiSquare from anova(by="margin") / sum(CCA$eig) -> sums to 27%
#            Constraints are correlated PREDICTORS, so their explanatory parts
#            overlap. The missing 73% is shared and cannot be attributed to any
#            one variable (VIF 22-39; r = 0.90 temperatures, 0.95 precipitations).
#            It is reported in the caption and console, not plotted as a bar.
#
# NOT goodness()/inertcomp(proportional=TRUE): those divide by each species' OWN
# inertia, giving a per-species FIT that does not partition (sums to 1.77 here)
# and is not comparable with the climate numbers.
tot_constrained = sum(cca_model$CCA$eig)

sp_inertia = inertcomp(cca_model, display = "species")
sp_share   = tibble(variable = rownames(sp_inertia),
                    share_pct = 100 * sp_inertia[, "CCA"] / tot_constrained)

set.seed(1)
clim_marg  = anova(cca_model, by = "margin", permutations = 499)
nterm      = nrow(clim_marg) - 1
clim_share = tibble(variable = full_name(rownames(clim_marg)[seq_len(nterm)]),
                    share_pct = 100 * clim_marg$ChiSquare[seq_len(nterm)] / tot_constrained,
                    p_value   = clim_marg$`Pr(>F)`[seq_len(nterm)])

shared_pct = 100 - sum(clim_share$share_pct)   # reported, not plotted

# Species prevalence: percentage of the CALIBRATION plots (the "past" plots the
# CCA was actually fitted on) in which the species occurs. Independent of bar
# length - a species can be common yet contribute little constrained inertia, or
# rare and contribute a lot - so the colour is not re-encoding the bar.
sp_prev = tibble(variable  = colnames(species_past_final),
                 n_plots   = colSums(species_past_final),
                 prev_pct  = 100 * colSums(species_past_final) / nrow(species_past_final))
n_calib = nrow(species_past_final)

# Neutral grey -> near-black ramp. Grey rather than a hue because panel A already
# spends blue on MORA and orange on NOCA; a coloured ramp here reads as a site.
# Five stops across a wide lightness span so adjacent species separate; light end
# #b2b2ad clears 2:1 against the panel surface so the rarest stay visible.
# The ramp is stretched over the observed prevalence range rather than 0-100.
# The retained species span that current range, so a fixed 0-100 scale would
# compress their colors into the pale half. Legend breaks remain real percentages.
prev_ramp = c("#b2b2ad", "#8e8e88", "#6b6b65", "#484843", "#1f1f1c")

sp_names = sp_bp$species
ital_lab = function(x) parse(text = ifelse(x %in% sp_names,
                                           paste0("italic('", x, "')"), paste0("'", x, "'")))

# Two stacked plots rather than facets, so each block gets a plain horizontal
# title and a height proportional to its number of bars. facet_wrap cannot do
# space = "free", and facet_grid rows put the strip on its side.
# NOTE the two blocks share a denominator (the constrained inertia, 0.4596) but
# NOT a numerator, so "share" is only accurate for the species:
#   species  inertia_j^CCA / sum_j inertia_j^CCA          -> an exact partition
#            "the fraction of the climate-explained compositional variation that
#             is this species' own variation"             (sums to 100%)
#   climate  [I(full) - I(full without k)] / I(full)      -> a unique effect
#            "the fraction of the climate-explained variation that disappears if
#             this variable is dropped"                   (sums to 27%)
# Verified: sum(inertcomp CCA) == sum(CCA$eig) exactly, and the marginal
# ChiSquare equals the drop in constrained inertia on refitting without the term.
# The axis is therefore labelled "% of constrained inertia" - a ratio TO it,
# which is true of both - and each block carries its own one-line definition.
bar_block = function(df, title, subtitle, show_axis, tag = NULL, fill_prev = FALSE) {
  p = ggplot(df, aes(reorder(variable, share_pct), share_pct)) +
    (if (fill_prev) geom_col(aes(fill = prev_pct), width = 0.7)
     else           geom_col(width = 0.7, fill = "grey45")) +
    geom_text(aes(label = sprintf("%.1f", share_pct)), hjust = -0.2, size = 3.1,
              color = "grey25") +
    coord_flip(clip = "off") +
    scale_x_discrete(labels = ital_lab) +
    scale_y_continuous(limits = c(0, max(contrib_all$share_pct) * 1.12),
                       expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, tag = tag,
         y = if (show_axis) "% of constrained inertia" else NULL,
         title = title, subtitle = subtitle) +
    base_theme +
    theme(plot.title = element_text(face = "bold", size = 12, hjust = 0),
          plot.subtitle = element_text(size = 9, color = "grey35", hjust = 0),
          panel.grid.major.y = element_blank(),
          axis.text.x  = if (show_axis) element_text() else element_blank(),
          axis.ticks.x = if (show_axis) element_line() else element_blank())

  if (fill_prev) {
    p + scale_fill_gradientn(
          colours = prev_ramp, limits = range(sp_prev$prev_pct),
          breaks = scales::pretty_breaks(5),
          guide = guide_colorbar(title.position = "top", title.hjust = 0)) +
      labs(fill = paste0("Occurrence: % of the ", n_calib,
                         " calibration plots holding the species")) +
      theme(legend.position  = "bottom",
            legend.title     = element_text(size = 9),
            legend.direction = "horizontal",
            legend.key.height = unit(0.3, "cm"),
            legend.key.width  = unit(1.5, "cm"))
  } else {
    p + theme(legend.position = "none")
  }
}

contrib_all = bind_rows(clim_share %>% select(variable, share_pct),
                        sp_share   %>% select(variable, share_pct))

pB = bar_block(clim_share, "Climate", NULL, show_axis = FALSE, tag = "C.") /
     bar_block(sp_share %>% left_join(sp_prev, by = "variable"), "Species", NULL,
               show_axis = TRUE, tag = "D.", fill_prev = TRUE) +
  plot_layout(heights = c(nrow(clim_share), nrow(sp_share)))

# Four labelled visual components: A trajectories, B biplot inset, and C/D the
# climate/species constrained-inertia blocks.
fig = pA_inset + pB +
  plot_layout(widths = c(1.6, 1)) &
  theme(plot.tag = element_text(size = 16, face = "bold"))

if (render_figures) {
  pdf(here("plot", paste0(cca_figure_stem, ".pdf")), height = 8.5, width = 15)
  print(fig)
  dev.off()
  ggsave(here("plot", paste0(cca_figure_stem, ".png")), fig,
         height = 8.5, width = 15, dpi = 300, bg = "white")
}

# The caption is deliberately not drawn on the figure. Everything a caption would
# need is printed here instead.
cat("\n=== CAPTION MATERIAL (figure carries no caption) ===\n")
cat(zoom_note, "\n", sep = "")
if (holocene_display_mode == "trajectory") {
  cat("Panel A: points every ", traj_step, " yr, each one a ", HOLO_BIN,
      "-yr bin mean (median over ", N_DRAWS, " age draws).\n", sep = "")
} else {
  cat("Panel A: one WA and one LC centroid per site x frozen CC/S era,",
      " connected separately from CC1 through S4 with time-direction arrows;",
      " Anthropocene legacy-to-resurvey trajectories are unchanged.\n")
}
cat("Observed = WA scores (alpha ", alpha_type["observed"],
    "); predicted = LC scores (alpha ", alpha_type["predicted"], ").\n", sep = "")
cat("Ordination scaling: ", cca_scaling, " (hill = ", cca_hill, ")\n", sep = "")
cat("Total constrained inertia: ", round(tot_constrained, 4),
    " (", round(100 * tot_constrained / cca_model$tot.chi, 1), "% of total)\n", sep = "")

cat("\nSpecies: share of constrained inertia (inertcomp), and arrow length",
    " (inset label threshold ", inset_sp_min_pct, "% of longest):\n", sep = "")
print(as.data.frame(sp_contrib %>%
  left_join(sp_share, by = c("species" = "variable")) %>%
  left_join(sp_prev,  by = c("species" = "variable")) %>%
  transmute(species, share_pct = round(share_pct, 1),
            n_plots, prev_pct = round(prev_pct, 1),
            arrow_len = round(arrow_len, 2), arrow_pct = round(arrow_pct, 1),
            labelled = arrow_pct >= inset_sp_min_pct)), row.names = FALSE)
cat("  species shares sum to", round(sum(sp_share$share_pct), 1), "% - they partition\n")

# Interset correlations are no longer drawn (the inset carries direction, as
# arrow angle), but they are still the right thing to quote in text.
cat("\nClimate: marginal share of constrained inertia, plus interset correlations",
    "\n(scaling-free; reported here, not plotted):\n")
print(as.data.frame(clim_share %>%
  left_join(as_tibble(intersetcor(cca_model)[, 1:2], rownames = "variable") %>%
              mutate(variable = full_name(variable)), by = "variable") %>%
  mutate(across(where(is.numeric), \(x) round(x, 3)))), row.names = FALSE)
cat("  climate shares sum to", round(sum(clim_share$share_pct), 1),
    "% - the remaining", round(100 - sum(clim_share$share_pct), 1),
    "% is shared between\n  the collinear constraints and cannot be attributed",
    "(VIF 22-39; r = 0.90 temperatures, 0.95 precipitations).\n")

if (holocene_display_mode == "trajectory") {
  cat("\nTrajectory points per group. The Holocene path is a ", HOLO_BIN,
      "-yr window at 100-yr steps\n(", length(OFFSETS), " bin offsets x ", N_DRAWS,
      " age draws = ", length(OFFSETS) * N_DRAWS, " runs; median across runs), so",
      " `n samples per bin`\nis the median bin occupancy, not a total:\n", sep = "")
  trajectory_audit = traj %>% group_by(site, era) %>%
    summarize(points = n(),
              span = if (first(era) == "holocene")
                       sprintf("%.1f - %.1f ka", max(-order) / 1000,
                               min(-order) / 1000)
                     else "legacy -> resurvey",
              n_per_bin_min = min(n), n_per_bin_median = median(n),
              n_per_bin_max = max(n), .groups = "drop")
} else {
  cat("\nTrajectory points per group. Holocene entries are site x CC/S-era",
      " centroids connected chronologically from CC1 through S4:\n")
  trajectory_audit = traj %>% group_by(site, era) %>%
    summarize(points = n(),
              span = if_else(first(era) == "holocene",
                             "CC1 -> S4", "legacy -> resurvey"),
              n_per_bin_min = min(n), n_per_bin_median = median(n),
              n_per_bin_max = max(n), .groups = "drop")
}
print(as.data.frame(trajectory_audit), row.names = FALSE)

# Bins that exist in too few age draws to be a time step. Reported, not hidden:
# they are the ends of the record, where a single sample's age tail reaches into
# a bin no other draw occupies.
ghost = holo_all %>% filter(draw_frac < min_draw_frac)
cat("\nHolocene bins DROPPED (occupied in < ", 100 * min_draw_frac,
    "% of age draws): ", nrow(ghost), " of ", nrow(holo_all), "\n", sep = "")
if (nrow(ghost))
  print(as.data.frame(ghost %>% group_by(site) %>%
    summarize(n_bins = n(), ages = sprintf("%.2f - %.2f ka", min(bin_mid) / 1000,
                                           max(bin_mid) / 1000),
              max_draw_frac = round(max(draw_frac), 2), .groups = "drop")),
    row.names = FALSE)
if (render_figures) {
  cat("\nWritten: plot/", cca_figure_stem, ".pdf and .png\n", sep = "")
} else {
  cat("\nFigure rendering skipped; trajectory data and audits were refreshed.\n")
}
# END R/stages/05a_cca_figure.R

# ============================================================================
# BEGIN R/stages/09a_tracking_example_and_visualizations.R
# ============================================================================
# Worked geometry example and descriptive lake-level tracking visualizations.
# Run after stages 13 and 09; read their canonical tables and write diagnostic PDFs.
# Rscript R/stages/09a_tracking_example_and_visualizations.R
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures',TRUE))
r = read_csv(here('output/cca_tracking_holocene_lake_realizations.csv'),show_col_types=FALSE)
b = read_csv(here('output/cca_tracking_holocene_lake_by_offset.csv'),show_col_types=FALSE)
interval = b |> filter(lake=='PantherPotholes',offset==0) |>
  mutate(distance=abs((age_hi+age_lo)/2-3000)) |> arrange(distance) |> slice(1)
draws = r |> filter(lake=='PantherPotholes',offset==0,
  age_hi==interval$age_hi,age_lo==interval$age_lo)
example = draws |> filter(pace_counterfactual_valid,direction_counterfactual_valid) |>
  arrange(draw) |> slice(1)
if(nrow(example)!=1L) stop('No valid canonical worked-example realization')
points = tibble(label=c('O1','O2','P1','P2','Pace corrected','Direction corrected'),
  CCA1=c(example$o1,example$o1_2,example$p1,example$p1_2,example$pace_corrected_CCA1,example$direction_corrected_CCA1),
  CCA2=c(example$o2,example$o2_2,example$p2,example$p2_2,example$pace_corrected_CCA2,example$direction_corrected_CCA2))
vectors = tibble(type=c('Observed','Predicted','Pace corrected','Direction corrected'),
  x=c(example$o1,example$p1,example$o1,example$o1),y=c(example$o2,example$p2,example$o2,example$o2),
  xend=c(example$o1_2,example$p1_2,example$pace_corrected_CCA1,example$direction_corrected_CCA1),
  yend=c(example$o2_2,example$p2_2,example$pace_corrected_CCA2,example$direction_corrected_CCA2))
a = ggplot(points,aes(CCA1,CCA2)) + geom_segment(data=vectors,
  aes(x=x,y=y,xend=xend,yend=yend,color=type),inherit.aes=FALSE,
  arrow=grid::arrow(length=grid::unit(2,'mm'))) + geom_point() +
  geom_text(aes(label=label),vjust=-.7,size=3) + coord_equal() +
  labs(title='A. Actual and corrected movement',color=NULL) + theme_minimal(base_size=10)
lag = tibble(endpoint=c('Initial','Actual final','Pace corrected','Direction corrected'),
  lag=c(example$lag_t1,example$lag_t2,example$lag_t2_pace_corrected,example$lag_t2_direction_corrected))
p = ggplot(lag,aes(endpoint,lag)) + geom_col(fill='#4477AA') +
  geom_text(aes(label=sprintf('%.3f',lag)),vjust=-.3,size=3) +
  labs(title='B. Distance to actual predicted position',x=NULL,y='Lag (CCA units)') +
  theme_minimal(base_size=10) + theme(axis.text.x=element_text(angle=20,hjust=1))
metrics = tracking_response_names()
values = example |> select(all_of(metrics)) |> pivot_longer(everything(),names_to='metric',values_to='value')
q = ggplot(values,aes(x=1,y=value)) + geom_point(size=2) +
  geom_text(aes(label=sprintf('%.3f',value)),nudge_x=.2,size=3) +
  facet_wrap(~metric,scales='free_y',ncol=2) + labs(title='C. Focused quantities for this draw',x=NULL,y=NULL) +
  theme_minimal(base_size=9) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())
uncertainty = draws |> select(draw,lag_rate_per_century,pace_effect_on_lag_per_century,
  direction_effect_on_lag_per_century) |> pivot_longer(-draw,names_to='metric',values_to='value')
s = ggplot(uncertainty,aes(value)) + geom_histogram(bins=15,fill='#228833',color='white',na.rm=TRUE) +
  facet_wrap(~metric,scales='free',ncol=1) + labs(title='D. Valid chronology-draw distributions',
    x='CCA units per century',y='Draws') + theme_minimal(base_size=9)
figure = (a+p)/(q+s) + plot_annotation(title=paste0('Panther Potholes: ',example$age_hi,' to ',example$age_lo,' cal BP'),
  subtitle=paste0('Offset 0; geometry draw ',example$draw,'; ',nrow(draws),' of 100 draws support this actual transition.'),
  caption='Both corrections start at O1. Effects compare with the actual final lag and are nonadditive. Climate bins contain ten native slices.\nChronology distributions are conditional on valid realizations; draws and offsets are not ecological replicates.')
if(render_figures) ggsave(here('plot/test_figures/fig_method_worked_example.pdf'),figure,width=12,height=11)

# Descriptive temporal panels and paired-plot boxplots. Response lines reuse
# maintained reporting estimates and their aligned transition predictors,
# following the same half-open mapping and complete-offset support rule.
# This stage never modifies or exports scientific tables.
# Regional climate bands reuse Figure 2's frozen catalog and subdivisions.
# These annotations do not classify lakes or change any tracking estimates.
climate_era_rects=read_csv(here('output/holocene_era_catalog.csv'),show_col_types=FALSE)
climate_subphases=read_csv(here('output/holocene_era_climate_change_subphases.csv'),show_col_types=FALSE)
climate_era_colors=c(`climate change`='#D3D3D6',`relative stability`='#EEEEF0')
stopifnot(nrow(climate_era_rects)>0L,!anyDuplicated(climate_era_rects$era_id),
 all(climate_era_rects$era_class %in% names(climate_era_colors)),
 all(is.finite(climate_era_rects$older_cal_bp)),all(is.finite(climate_era_rects$younger_cal_bp)),
 all(climate_era_rects$older_cal_bp>climate_era_rects$younger_cal_bp),
 all(head(climate_era_rects$younger_cal_bp,-1)==tail(climate_era_rects$older_cal_bp,-1)))
phase_check=climate_subphases |> left_join(climate_era_rects |>
 filter(era_class=='climate change') |>
 select(parent_era_id=era_id,parent_older=older_cal_bp,parent_younger=younger_cal_bp),
 by='parent_era_id')
stopifnot(!anyDuplicated(climate_subphases$subphase_id),
 all(is.finite(phase_check$older_cal_bp)),all(is.finite(phase_check$younger_cal_bp)),
 all(is.finite(phase_check$parent_older)),all(is.finite(phase_check$parent_younger)),
 all(phase_check$older_cal_bp>phase_check$younger_cal_bp),
 all(phase_check$older_cal_bp<=phase_check$parent_older),
 all(phase_check$younger_cal_bp>=phase_check$parent_younger))
climate_period_labels=bind_rows(
 climate_subphases |> transmute(label=subphase_id,older_cal_bp,younger_cal_bp),
 climate_era_rects |> filter(era_class=='relative stability') |>
 transmute(label=era_id,older_cal_bp,younger_cal_bp)) |>
 mutate(midpoint=(older_cal_bp+younger_cal_bp)/2) |> arrange(desc(older_cal_bp))
climate_internal_boundaries=climate_subphases |> group_by(parent_era_id) |>
 filter(older_cal_bp<max(older_cal_bp)) |> ungroup() |> transmute(cal_bp=older_cal_bp)
bin_width_years=unique(b$climate_dt_years)
stopifnot(length(bin_width_years)==1L,all(b$vegetation_dt_years==bin_width_years))
offsets=seq(0,bin_width_years-100,100)
n_offsets=length(offsets)
lake_order=c('JayBath','LogWallow','ReflectionPond','PantherPotholes')
lake_labels=c('Jay Bath (MORA)','Log Wallow (MORA)','Reflection Pond (MORA)','Panther Potholes (NOCA)')
predictors=c('standardized_climate_change_rate','fire_activity')
thin=b |> pivot_longer(all_of(c(metrics,predictors)),names_to='metric',values_to='value') |>
 mutate(lake=factor(lake,levels=lake_order,labels=lake_labels)) |>
 arrange(metric,lake,offset,interval_mid_cal_bp) |> group_by(metric,lake,offset) |>
 mutate(segment=cumsum(row_number()==1L |
   coalesce(interval_mid_cal_bp-lag(interval_mid_cal_bp)>bin_width_years,TRUE) |
   !is.finite(value) | !coalesce(is.finite(lag(value)),FALSE))) |> ungroup()
response_grid=read_csv(here('output/cca_tracking_holocene_lake_timeseries.csv'),show_col_types=FALSE) |>
 filter(metric %in% metrics) |> select(site,lake,t,metric,estimate,n_offsets,n_valid_offsets)
predictor_grid=lake_reporting_context(b,response_grid,bin_width_years) |>
 distinct(site,lake,t,n_valid_offsets,
   standardized_climate_change_rate=climate_rate,fire_activity) |>
 pivot_longer(all_of(predictors),names_to='metric',values_to='estimate') |>
 mutate(n_offsets=n_valid_offsets) |> filter(is.finite(estimate))
stopifnot(!anyDuplicated(predictor_grid[c('site','lake','t','metric')]))
thick=bind_rows(response_grid,predictor_grid) |>
 mutate(lake=factor(lake,levels=lake_order,labels=lake_labels)) |>
 arrange(metric,lake,t) |> group_by(metric,lake) |>
 mutate(segment=cumsum(row_number()==1L | coalesce(t-lag(t)>100,TRUE))) |> ungroup()
stopifnot(all(thick$n_offsets==n_offsets),all(thick$n_valid_offsets==n_offsets))
modern=read_csv(here('output/cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE) |>
 mutate(site=factor(site,levels=c('MORA','NOCA')))
# FireActivity is a charcoal-frequency measure and is unavailable for modern
# plots. Their binary burned assignments remain available in the model input.
modern_long=modern |> pivot_longer(all_of(c(metrics,'standardized_climate_change_rate')),
 names_to='metric',values_to='value')
rates=c('lag_rate_per_century','observed_turnover_rate',
 'pace_effect_on_lag_per_century','direction_effect_on_lag_per_century')
palette=c(lag_rate_per_century='#2563eb',observed_turnover_rate='#059669',
 pace_effect_on_lag_per_century='#d42d75',direction_effect_on_lag_per_century='#c97710',
 magnitude_tracking_ratio='#5b56b8',angle_degrees='#157d91',
 standardized_climate_change_rate='#665641',fire_activity='#b63c35')
rate_labels=c('Lag-change rate','Observed turnover','Pace effect','Direction effect')
common=theme_minimal(base_size=12,base_family='sans')+
 theme(plot.title=element_text(size=20,face='bold',color='#152536'),
  plot.subtitle=element_text(size=12,color='#526273',margin=margin(b=12)),
  plot.caption=element_text(size=10,color='#526273',hjust=0,margin=margin(t=12)),
  panel.grid.minor=element_blank(),panel.grid.major=element_line(color='#e4e8ee',linewidth=.3),
  strip.text=element_text(face='bold',size=11,color='#233647'),
  strip.background=element_rect(fill='#f0f3f7',color=NA),
  strip.placement='outside',strip.text.y.left=element_text(angle=0,size=10),
  strip.background.y=element_blank(),panel.spacing=grid::unit(.8,'lines'),
  legend.position='bottom',legend.title=element_blank(),legend.text=element_text(size=11),
  plot.background=element_rect(fill='white',color=NA),plot.margin=margin(8,8,8,8))
oldest_age=(ceiling(max(c(thin$interval_mid_cal_bp,thick$t))/500)+1)*500
x_scale=scale_x_reverse(limits=c(oldest_age,0),breaks=seq(0,oldest_age,2500),
 labels=scales::label_comma(),expand=expansion(mult=c(.015,.015)))
# Four lake columns share a time axis and per-row scales. The final column
# compares independent modern plots at MORA/NOCA and has its own labeled scales.
# Undefined responses are removed independently by the plotting layers.
tracking_panels=function(display_metrics,rows,row_labels,title,subtitle,rate_legend=FALSE) {
  assign_rows=function(d) d |> filter(metric %in% display_metrics) |>
    mutate(display_row=factor(unname(rows[metric]),levels=row_labels))
  left_thin=assign_rows(thin);left_thick=assign_rows(thick)
  modern_values=assign_rows(modern_long) |>
    mutate(era='Anthropocene',metric=factor(metric,levels=display_metrics))
  baseline=tibble(display_row=factor(row_labels,levels=row_labels),y=0)
  if('magnitude_tracking_ratio' %in% names(rows))
    baseline$y[baseline$display_row==rows['magnitude_tracking_ratio']]=1
  if('angle_degrees' %in% names(rows))
    baseline$y[baseline$display_row==rows['angle_degrees']]=90
  legend_breaks=if(rate_legend) rates else display_metrics
  legend_labels=if(rate_legend) rate_labels else display_metrics
  # Reserve label space above the top-row curves, shared across the lakes.
  top_range=range(c(left_thin$value[left_thin$display_row==row_labels[1]],
    left_thick$estimate[left_thick$display_row==row_labels[1]],baseline$y[1]),finite=TRUE)
  label_span=diff(top_range)
  if(label_span==0) label_span=1
  era_labels=climate_period_labels |> mutate(display_row=factor(row_labels[1],levels=row_labels),
    label_ceiling=max(top_range)+.18*label_span)
  left=ggplot()+
    geom_blank(data=era_labels,aes(x=midpoint,y=label_ceiling),inherit.aes=FALSE)+
    geom_rect(data=climate_era_rects,
      aes(xmin=younger_cal_bp,xmax=older_cal_bp,ymin=-Inf,ymax=Inf,fill=era_class),
      inherit.aes=FALSE,alpha=.38,color=NA,show.legend=FALSE)+
    geom_vline(data=climate_internal_boundaries,aes(xintercept=cal_bp),
      inherit.aes=FALSE,color='#aeb3bd',linewidth=.25,linetype='dotted',show.legend=FALSE)+
    geom_text(data=era_labels,aes(x=midpoint,y=Inf,label=label),inherit.aes=FALSE,
      color='#3f4855',size=2.7,fontface='bold',angle=90,hjust=1.15,vjust=.5,show.legend=FALSE)+
    geom_hline(data=baseline,aes(yintercept=y),color='#8796a5',linewidth=.35,linetype='dashed')+
    geom_line(data=left_thin,aes(interval_mid_cal_bp,value,color=metric,
      group=interaction(metric,offset,segment)),linewidth=.35,alpha=.27,na.rm=TRUE)+
    geom_line(data=left_thick,aes(t,estimate,color=metric,
      group=interaction(metric,segment)),linewidth=1.05)+
    facet_grid(display_row~lake,scales='free_y',switch='y',drop=FALSE)+x_scale+
    scale_fill_manual(values=climate_era_colors,guide='none')+
    scale_color_manual(values=palette,breaks=legend_breaks,labels=legend_labels,
      guide=if(rate_legend) guide_legend(override.aes=list(alpha=1,linewidth=1.2),nrow=1) else 'none')+
    labs(x='Transition midpoint / reporting age (cal BP)',y=NULL)+common
  right=ggplot(modern_values,aes(site,value,color=metric,fill=metric))+
    geom_hline(data=baseline,aes(yintercept=y),inherit.aes=FALSE,
      color='#8796a5',linewidth=.35,linetype='dashed')+
    geom_boxplot(position=position_dodge(width=.8),width=.65,alpha=.3,
      linewidth=.4,outlier.size=.6,outlier.alpha=.45,na.rm=TRUE)+
    facet_grid(display_row~era,scales='free_y',drop=FALSE)+
    scale_color_manual(values=palette,guide='none')+scale_fill_manual(values=palette,guide='none')+
    labs(x='Paired plots',y=NULL)+common+
    theme(strip.text.y=element_blank(),strip.background.y=element_blank(),
      axis.text.x=element_text(size=11))
  # Retain the modern fire row without inventing continuous charcoal activity.
  missing_fire=tibble(display_row=factor(unname(rows['fire_activity']),levels=row_labels),
    era='Anthropocene',site=factor('MORA',levels=c('MORA','NOCA')),value=.5)
  right=right+geom_blank(data=missing_fire,aes(x=site,y=value),inherit.aes=FALSE)+
    geom_rect(data=missing_fire,aes(xmin=-Inf,xmax=Inf,ymin=-Inf,ymax=Inf),
      inherit.aes=FALSE,fill='white',color=NA)+
    geom_text(data=missing_fire,aes(x=1.5,y=.25),inherit.aes=FALSE,
      label='Continuous fire activity\nunavailable for modern plots',
      color=unname(palette['fire_activity']),size=3.1,lineheight=1.2)
  caption=paste0('Thin: individual offsets. Thick: medians across all ',n_offsets,
    ' offsets with complete finite support. Response medians reuse the maintained reporting grid.\n',
    'The four Holocene columns share scales by row; the Anthropocene column uses its own labeled y-scales. ',
    'Boxes show finite values from ',sum(modern$site=='MORA'),' MORA / ',
    sum(modern$site=='NOCA'),' NOCA paired plots.\n',
    'Climate is the standardized physical climate-change rate. MORA lakes share regional fire exposure; ',
    'modern fire is binary burned, not continuous charcoal activity.\n',
    'Regional climate periods: darker gray = climate change (CC); lighter gray = relative stability (S). ',
    'CC1a, CC1b and CC1c subdivide CC1; blank margins are outside the classified domain.')
  combined=(left+right)+plot_layout(widths=c(4,1.5),guides='collect')+
    plot_annotation(title=title,subtitle=subtitle,caption=caption,
      theme=common)
  # Remove the annotation's numerical axis after assembling aligned facets.
  # A null device avoids opening an unsolicited Rplots.pdf during layout.
  if(grDevices::dev.cur()==1L) {
    grDevices::pdf(file=NULL)
    on.exit(grDevices::dev.off(),add=TRUE)
  }
  combined_grob=patchworkGrob(combined)
  fire_row=match(unname(rows['fire_activity']),row_labels)
  axis_group=which(grepl('^axis-l.*-2$',combined_grob$layout$name))
  stopifnot(length(axis_group)==1L)
  fire_axis=which(combined_grob$grobs[[axis_group]]$layout$name==paste0('axis-l-',fire_row))
  stopifnot(length(fire_axis)==1L)
  combined_grob$grobs[[axis_group]]$grobs[[fire_axis]]=grid::nullGrob()
  combined_grob
}
rate_rows=c('Tracking responses\n(CCA units / century)',
 'Climate-change rate\n(calibration SD / century)','Fire activity\n(normalized frequency)')
rate_map=setNames(c(rep(rate_rows[1],length(rates)),rate_rows[2:3]),c(rates,predictors))
p_rates=tracking_panels(c(rates,predictors),rate_map,rate_rows,
 'Tracking responses, climate and fire',
 'Four Holocene lake columns with established climate periods; Anthropocene paired-plot boxplots',
 rate_legend=TRUE)
# Only magnitude ratio is displayed here: the rate ratio duplicates it for
# equal Holocene elapsed times. Both ratios remain in both model input tables.
other=c('magnitude_tracking_ratio','angle_degrees',predictors)
other_rows=c('Magnitude ratio\n(unitless)','Movement angle\n(degrees)',rate_rows[2:3])
p_other=tracking_panels(other,setNames(other_rows,other),other_rows,
 'Tracking magnitude ratio, angle, climate and fire',
 'One row per variable with established climate periods; duplicate Holocene rate-ratio display omitted')
if(render_figures) {
  ggsave(here('plot/test_figures/fig_tracking_offset_rates.pdf'),p_rates,width=20,height=10)
  ggsave(here('plot/test_figures/fig_tracking_offset_ratios_angles.pdf'),p_other,width=20,height=12)
}
# END R/stages/09a_tracking_example_and_visualizations.R

# ============================================================================
# BEGIN R/stages/12a_fire_event_detection_worked_example.R
# ============================================================================
# =============================================================================
# 12a_fire_event_detection_worked_example.R
# Auditable, step-by-step display of accepted charcoal-event detection.
# This stage explains individual-event selection; it does not classify the
# later centered 1,000-year high-fire periods.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(patchwork)
})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

series_path = here("output/holocene_fire_source_series.csv")
events_path = here("output/holocene_fire_source_events.csv")
settings_path = here("output/holocene_fire_source_settings.csv")
if (!all(file.exists(c(series_path, events_path, settings_path)))) {
  stop("Run R/stages/12_walsh_fire_reproduction.R first.")
}

series = read_csv(series_path, show_col_types = FALSE)
events = read_csv(events_path, show_col_types = FALSE)
settings = read_csv(settings_path, show_col_types = FALSE)

required_series = c(
  "site", "lake", "age_cal_yr_BP", "char_interpolated",
  "background_char", "peak_component", "positive_threshold",
  "minimum_count_p", "candidate_before_count_screen",
  "rejected_by_count_screen", "is_significant")
if (!all(required_series %in% names(series))) {
  stop("The source-series audit lacks event-detection columns; rerun stage 12.")
}

lake_order = c("Sunrise Lake", "Shadow Lake", "Little Sunrise Lake",
               "PantherPotholes")
lake_labels = c(PantherPotholes = "Panther Potholes")
lake_colors = c(
  `Sunrise Lake` = "#4477AA",
  `Shadow Lake` = "#228833",
  `Little Sunrise Lake` = "#AA3377",
  PantherPotholes = "#CC6677")

if (nrow(settings) != 4L || any(settings$engine != "tapas"))
  stop("The worked example requires the harmonized four-core tapas settings.")

lake_counts = series |>
  group_by(site, lake) |>
  summarise(
    interpolated_grid_rows = n(),
    candidate_events = sum(candidate_before_count_screen, na.rm = TRUE),
    rejected_by_count_screen = sum(rejected_by_count_screen, na.rm = TRUE),
    accepted_events = sum(is_significant, na.rm = TRUE),
    younger_cal_bp = min(age_cal_yr_BP),
    older_cal_bp = max(age_cal_yr_BP), .groups = "drop")

published = tribble(
  ~lake, ~published_episode_total,
  "Sunrise Lake", 24L,
  "Shadow Lake", 18L,
  "Little Sunrise Lake", 16L,
  "PantherPotholes", NA_integer_)

audit = settings |>
  left_join(lake_counts, by = c("site", "lake")) |>
  left_join(published, by = "lake") |>
  mutate(
    local_noise_method = "Gaussian-mixture noise distribution",
    background_method = "robust LOWESS",
    consecutive_rule = "collapse adjacent exceedances",
    count_screen_detail = "pass/fail retained; individual p not returned by tapas",
    analytical_interpretation = if_else(site == "MORA",
      "regional MORA core evidence", "local Panther Potholes evidence")) |>
  arrange(match(lake, lake_order))

write_csv(audit, here("output/fire_event_detection_lake_audit.csv"))

theme_method = theme_bw(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(color = "grey30", size = 10.5),
        legend.position = "top")

# Page 1: common algorithm and all source-specific choices.
steps = tibble(
  x = 1:6,
  label = c("1\nInterpolate\nCHAR", "2\nEstimate robust\nLOWESS background",
            "3\nCalculate\npositive residual",
            "4\nExceed local\nnoise threshold",
            "5\nPass 75-year\ncount screen",
            "6\nAccepted\nfire event"))
p_flow = ggplot(steps, aes(x, 1, label = label)) +
  geom_segment(data = tibble(x = 1:5),
    aes(x = x + .32, xend = x + .68, y = 1, yend = 1),
    arrow = arrow(length = unit(.12, "inches")), linewidth = .55,
    inherit.aes = FALSE) +
  geom_label(fill = "grey96", color = "grey15", linewidth = .4,
             size = 4.1, lineheight = .95) +
  coord_cartesian(xlim = c(.6, 6.4), ylim = c(.65, 1.35), clip = "off") +
  labs(title = "How an individual charcoal peak becomes an accepted fire event",
       subtitle = paste("The detection settings differ among cores; the later",
                        "1,000-year high-fire classification is a separate step.")) +
  theme_void(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 17, hjust = .5),
        plot.subtitle = element_text(size = 11, hjust = .5, color = "grey30"))

table_data = audit |>
  transmute(
    lake = recode(lake, !!!lake_labels),
    Engine = str_wrap(engine, 16),
    Chronology = str_wrap(chronology, 18),
    `Interpolation\n(years)` = as.character(interpolation_years),
    `Background\n(years)` = as.character(smoothing_years),
    `Noise\npercentile` = scales::percent(threshold_probability, accuracy = 1),
    `Candidates` = as.character(candidate_events),
    `Count-screen\nrejected` = as.character(rejected_by_count_screen),
    `Accepted` = as.character(accepted_events)) |>
  mutate(lake = factor(lake,
    levels = recode(lake_order, !!!lake_labels))) |>
  pivot_longer(-lake, names_to = "field", values_to = "value") |>
  mutate(field = factor(field, levels = unique(field)))

p_table = ggplot(table_data, aes(field, lake)) +
  geom_tile(aes(fill = lake), alpha = .10, color = "white", linewidth = 1) +
  geom_text(aes(label = value), size = 3.35, lineheight = .9) +
  scale_fill_manual(values = setNames(unname(lake_colors),
    recode(names(lake_colors), !!!lake_labels))) +
  scale_x_discrete(position = "top") +
  scale_y_discrete(limits = rev) +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank(), legend.position = "none",
        axis.text.x = element_text(face = "bold", color = "grey15", size = 10),
        axis.text.y = element_text(face = "bold", color = "grey15", size = 10.5),
        plot.margin = margin(10, 10, 10, 10))

p_note = ggplot() +
  annotate("label", x = .5, y = .62, size = 4.0, lineheight = 1.05,
    linewidth = .35, fill = "grey97", color = "grey20",
    label = paste0(
      "Accepted event = one distinct positive residual excursion above the local noise threshold that survives the count screen.\n",
      "All four primary catalogs use tapas; each record retains its publication-specific temporal and threshold settings.\n",
      "Accepted events are inferred charcoal episodes, not exact known ignition dates and not yet high-fire periods.")) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  theme_void()

overview = p_flow / p_table / p_note +
  plot_layout(heights = c(.9, 1.25, .55))

make_lake_panel = function(lake_name) {
  dd = series |> filter(lake == lake_name) |> arrange(age_cal_yr_BP)
  ss = audit |> filter(lake == lake_name)
  display_lake = recode(lake_name, !!!lake_labels)
  col = lake_colors[[lake_name]]

  accepted = dd |> filter(is_significant)
  rejected = dd |> filter(rejected_by_count_screen)
  p2 = ggplot(dd, aes(age_cal_yr_BP, peak_component)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = .4) +
    geom_line(color = col, linewidth = .55) +
    geom_line(aes(y = positive_threshold), color = "grey15",
              linetype = "dashed", linewidth = .65) +
    geom_point(data = accepted, shape = 21, fill = col, color = "black",
               size = 2.0, stroke = .35) +
    geom_point(data = rejected, shape = 4, color = "#B2182B",
               size = 2.8, stroke = 1.0) +
    scale_x_reverse() +
    labs(title = paste0(display_lake, ": local ",
      scales::percent(ss$threshold_probability, accuracy = 1),
      " noise threshold"),
      x = "cal BP", y = "Peak CHAR residual") +
    theme_method + theme(legend.position = "none")

  settings_text = sprintf(
    "Interpolation %g yr | background %g yr\n%d accepted events | %d rejected peaks",
    ss$interpolation_years, ss$smoothing_years,
    ss$accepted_events, ss$rejected_by_count_screen)
  p2 + labs(subtitle = settings_text)
}

lake_panels = purrr::map(lake_order, make_lake_panel)
lake_page = wrap_plots(lake_panels, ncol = 2) +
  plot_annotation(
    title = "Fire-event detection across the four lake records",
    subtitle = "Dashed = threshold; filled circle = accepted; red X = rejected by count screen",
    theme = theme(plot.title = element_text(face = "bold", size = 18),
                  plot.subtitle = element_text(size = 11, color = "grey25")))
comparison_path = here("output/walsh_charanalysis_software_comparison.csv")
if (!file.exists(comparison_path)) stop("Missing Walsh software audit.")
comparison = read_csv(comparison_path, show_col_types = FALSE) |>
  select(lake, published_total_episodes, official_r_episodes, tapas_episodes) |>
  pivot_longer(-lake, names_to = "catalog", values_to = "accepted_events") |>
  mutate(catalog = recode(catalog,
    published_total_episodes = "Walsh reported",
    official_r_episodes = "CharAnalysis R 2.0.3 audit",
    tapas_episodes = "PaleoACES tapas primary"))
p_audit = ggplot(comparison,
    aes(lake, accepted_events, fill = catalog)) +
  geom_col(position = position_dodge(.82), width = .75) +
  geom_text(aes(label = accepted_events),
    position = position_dodge(.82), vjust = -.25, size = 4) +
  scale_fill_manual(values = c("Walsh reported" = "grey65",
    "CharAnalysis R 2.0.3 audit" = "#4477AA",
    "PaleoACES tapas primary" = "#AA3377")) +
  labs(title = "Walsh publication totals, official audit, and harmonized primary catalog",
    x = NULL, y = "Accepted events", fill = NULL) +
  theme_method + theme(axis.text.x = element_text(angle = 15, hjust = 1))
p_audit_note = ggplot() +
  annotate("label", x = .5, y = .5, size = 4.2, lineheight = 1.08,
    label = paste(
      "The magenta tapas catalog is authoritative downstream.",
      "The official CharAnalysis run remains a reproducibility audit;",
      "neither implementation is tuned to force the published totals."),
    fill = "grey97", color = "grey20") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) + theme_void()
audit_page = p_audit / p_audit_note + plot_layout(heights = c(3, 1))
pages = list(overview, lake_page, audit_page)

pdf_path = here("plot/test_figures/fig_fire_event_detection_workflow.pdf")
if (render_figures) {
  grDevices::pdf(pdf_path, width = 14, height = 9, onefile = TRUE)
  purrr::walk(pages, print)
  grDevices::dev.off()
  cat("Written three-page fire-event workflow with all four lake records on one page.\n")
}
# END R/stages/12a_fire_event_detection_worked_example.R

# ============================================================================
# BEGIN R/stages/13a_climate_change_figure.R
# ============================================================================
# =============================================================================
# 13a_climate_change_figure.R
# =============================================================================
# Two-panel display of standardized Holocene and Anthropocene climate change.
# This figure reads authoritative outputs and does not recalculate eras.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(patchwork); library(grid)
})
source(here("R/helpers/figure_style.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

required = c(
  climate = here("output/holocene_era_climate_directional_cells.csv"),
  eras = here("output/holocene_era_catalog.csv"),
  subphases = here("output/holocene_era_climate_change_subphases.csv"),
  fire = here("output/holocene_era_high_fire_periods.csv"),
  fire_frequency = here("output/holocene_era_fire_site_frequency.csv"),
  thresholds = here("output/holocene_era_climate_variable_thresholds.csv"),
  anthropocene = here("output/cca_tracking_anthropocene_plot_calculations.csv"),
  regional_phases = here("output/holocene_era_climate_regional_phase_changes.csv"))
if (!all(file.exists(required))) stop(
  "Run R/stages/09_tracking_metrics.R and R/stages/13_holocene_climate_fire_eras.R first.")

climate = read_csv(required[["climate"]], show_col_types = FALSE)
eras = read_csv(required[["eras"]], show_col_types = FALSE)
subphases = read_csv(required[["subphases"]], show_col_types = FALSE)
fire = read_csv(required[["fire"]], show_col_types = FALSE)
fire_frequency = read_csv(required[["fire_frequency"]], show_col_types = FALSE)
anthropocene = read_csv(required[["anthropocene"]], show_col_types = FALSE)
regional_phases = read_csv(required[["regional_phases"]], show_col_types = FALSE)
thresholds = read_csv(required[["thresholds"]], show_col_types = FALSE)

variables = c("MSpT", "MWT", "SP", "WP")
variable_labels = c(MSpT = "Spring temperature", MWT = "Winter temperature",
  SP = "Summer precipitation", WP = "Winter precipitation")
# Paul Tol-inspired, color-vision-deficiency-safe colors. Temperature and
# precipitation remain distinguishable in grayscale through their luminance as
# well as hue; era backgrounds are deliberately much lighter than the data.
variable_colors = c(MSpT = "#EE6677", MWT = "#4477AA",
                    SP = "#CCBB44", WP = "#228833")
# The aligned MORA/NOCA lanes carry the site distinction. High-fire observations
# use the same restrained red as burned/high-fire groups in every main figure.
site_colors = PAPER_SITE_COLORS
era_colors = c(`climate change` = "#D3D3D6",
               `relative stability` = "#EEEEF0")
time_limits = c(10500, 0)
time_breaks = c(10000, 8000, 6000, 4000, 2000, 0)

stopifnot(
  setequal(unique(climate$variable), variables),
  identical(range(climate$t), c(1300, 9500)),
  identical(eras$era_id, c("CC1", "S1", "CC2", "S2", "CC3", "S3", "CC4", "S4")),
  all(c(paste0(variables, "_z_change")) %in% names(anthropocene)))

era_rects = eras |>
  transmute(xmin = younger_cal_bp, xmax = older_cal_bp,
    era_id, era_class, midpoint = (younger_cal_bp + older_cal_bp) / 2)

era_background = function(alpha = .38) {
  geom_rect(data = era_rects,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf,
        fill = era_class), inherit.aes = FALSE, alpha = alpha,
    color = NA, show.legend = FALSE)
}
time_axis = function() scale_x_reverse(limits = time_limits,
  breaks = time_breaks, labels = scales::label_number(big.mark = ","),
  expand = expansion(mult = c(.005, .005)))

# A1. Equal-site regional median change. The points identify cells that passed
# both the 50%-of-maximum magnitude rule and the >=8/10 phase-direction rule.
yrange = range(climate$regional_score, na.rm = TRUE)
# Era identifiers, interval arrows, and driver descriptions occupy distinct
# lanes. All CC/S identifiers share one baseline; the short CC1b description
# alone is lifted to prevent collision with the adjacent multi-line boxes.
era_id_y = yrange[2] + diff(yrange) * .30
arrow_y = yrange[2] + diff(yrange) * .18
description_y = yrange[2] + diff(yrange) * .095

# Raw physical-rate comparison. Holocene changes span exactly 1,000 years, so
# division by ten expresses them per century. We first form the equal-site raw
# change within each offset, then take the regional median across offsets at
# each date. The maximum-absolute regional median retains its sign.
holocene_raw_grid = regional_phases |>
  mutate(equal_site_raw_change =
      (signed_change_MORA + signed_change_NOCA) / 2,
    raw_rate_per_century = equal_site_raw_change / 10) |>
  group_by(variable, unit, t) |>
  summarise(raw_rate_per_century = median(raw_rate_per_century),
    n_offsets = n_distinct(offset), .groups = "drop")
holocene_max = holocene_raw_grid |>
  group_by(variable, unit) |>
  slice_max(abs(raw_rate_per_century), n = 1, with_ties = FALSE) |>
  ungroup() |>
  transmute(variable, raw_unit = unit,
    holocene_max_signed_rate_per_century = raw_rate_per_century,
    holocene_max_absolute_rate_per_century = abs(raw_rate_per_century),
    holocene_peak_cal_bp = t,
    holocene_peak_direction = if_else(raw_rate_per_century > 0,
      "increasing", "decreasing"), holocene_offsets = n_offsets)

anthro_raw = anthropocene |>
  select(plot_id, site, all_of(paste0(variables, "_rate_per_century"))) |>
  pivot_longer(ends_with("_rate_per_century"), names_to = "variable",
    values_to = "raw_rate_per_century") |>
  mutate(variable = str_remove(variable, "_rate_per_century$"))
anthro_site = anthro_raw |>
  group_by(variable, site) |>
  summarise(anthropocene_median_rate_per_century =
      median(raw_rate_per_century, na.rm = TRUE),
    anthropocene_n_plots = n_distinct(plot_id), .groups = "drop") |>
  pivot_wider(names_from = site,
    values_from = c(anthropocene_median_rate_per_century,
      anthropocene_n_plots), names_sep = "_")
anthro_all = anthro_raw |>
  group_by(variable) |>
  summarise(anthropocene_median_rate_per_century_all =
      median(raw_rate_per_century, na.rm = TRUE),
    anthropocene_n_plots_all = n_distinct(plot_id), .groups = "drop")

rate_comparison = holocene_max |>
  left_join(anthro_site, by = "variable") |>
  left_join(anthro_all, by = "variable") |>
  mutate(variable_label = unname(variable_labels[variable]),
    rate_unit = if_else(raw_unit == "deg C", "deg C / century",
      "mm / century")) |>
  arrange(match(variable, variables))
stopifnot(nrow(rate_comparison) == 4L,
  all(rate_comparison$holocene_offsets == 10L))
write_csv(rate_comparison,
  here("output/holocene_anthropocene_raw_climate_rate_comparison.csv"))

# Climate-change subphase arrows share a top annotation lane. CC1a--c are
# derived from the internal driver-count trough; the shorter CC eras remain
# unsplit. Stable-era labels use the same lane between these arrows.
phase_annotations = subphases |>
  mutate(midpoint = (older_cal_bp + younger_cal_bp) / 2,
    description = annotation_label,
    id_y = era_id_y,
    arrow_y = arrow_y,
    description_y = description_y + if_else(
      phase_role == "transition", diff(yrange) * .105, 0))
# Split the multi-line descriptions so each phrase can use the color of the
# climate variable it describes. "Transition" remains neutral because it is a
# phase role rather than a climate variable.
description_phrases = phase_annotations |>
  select(subphase_id, midpoint, description_y, phase_role,
    active_driver_labels) |>
  mutate(phrase = if_else(phase_role == "transition",
    paste("transition", active_driver_labels, sep = ";"),
    active_driver_labels)) |>
  separate_longer_delim(phrase, delim = ";") |>
  group_by(subphase_id) |>
  mutate(line_number = row_number(), n_lines = n(),
    phrase_y = description_y +
      ((n_lines + 1) / 2 - line_number) * diff(yrange) * .027,
    phrase_variable = case_when(
      str_detect(phrase, "^spring ") ~ "MSpT",
      str_detect(phrase, "^winter (warming|cooling)") ~ "MWT",
      str_detect(phrase, "^summer ") ~ "SP",
      str_detect(phrase, "^winter (wetting|drying)") ~ "WP",
      TRUE ~ "context")) |>
  ungroup()
stable_annotations = era_rects |>
  filter(era_class == "relative stability") |>
  mutate(id_y = era_id_y)

# Stability-range keys sit in the older incomplete-coverage margin near 10 ka.
# Each vertical bracket connects the exact negative and positive threshold used
# for that variable; the text is rotated so the four ranges remain legible
# without covering the climate trajectories or era annotations.
stability_callouts = thresholds |>
  filter(variable %in% variables) |>
  arrange(match(variable, variables)) |>
  mutate(x = c(10465, 10295, 10125, 9955),
    ymin = -threshold_standardized_change,
    ymax = threshold_standardized_change,
    cap_left = x - 27, cap_right = x + 27,
    label = sprintf("%s  [%+.3f, %+.3f]",
      variable, ymin, ymax))
stopifnot(nrow(stability_callouts) == 4L)

p_climate = ggplot(climate,
    aes(t, regional_score, color = variable, group = variable)) +
  era_background() +
  geom_hline(yintercept = 0, color = "grey45", linewidth = .4) +
  geom_line(linewidth = 1.0) +
  geom_point(data = filter(climate, qualifies), size = 2.8) +
  geom_segment(data = stability_callouts,
    aes(x = x, xend = x, y = ymin, yend = ymax, color = variable),
    inherit.aes = FALSE, linewidth = .85, show.legend = FALSE) +
  geom_segment(data = stability_callouts,
    aes(x = cap_left, xend = cap_right, y = ymin, yend = ymin,
      color = variable), inherit.aes = FALSE, linewidth = .85,
    show.legend = FALSE) +
  geom_segment(data = stability_callouts,
    aes(x = cap_left, xend = cap_right, y = ymax, yend = ymax,
      color = variable), inherit.aes = FALSE, linewidth = .85,
    show.legend = FALSE) +
  geom_text(data = stability_callouts,
    aes(x = x - 48, y = 0, label = label, color = variable),
    inherit.aes = FALSE, angle = 90, size = 3.2, fontface = "bold",
    show.legend = FALSE) +
  geom_segment(data = phase_annotations,
    aes(x = older_cal_bp, xend = younger_cal_bp,
      y = arrow_y, yend = arrow_y),
    inherit.aes = FALSE, color = "grey25", linewidth = 1.05,
    arrow = arrow(type = "closed", length = unit(.065, "in")),
    show.legend = FALSE) +
  geom_label(data = phase_annotations,
    aes(midpoint, description_y, label = description),
    inherit.aes = FALSE, color = "transparent", fill = "white", linewidth = 0,
    size = 3.05, lineheight = .93, label.padding = unit(.09, "lines"),
    show.legend = FALSE) +
  geom_text(data = description_phrases,
    aes(midpoint, phrase_y, label = phrase, color = phrase_variable),
    inherit.aes = FALSE, size = 3.05, lineheight = .93,
    show.legend = FALSE) +
  geom_text(data = phase_annotations,
    aes(midpoint, id_y, label = subphase_id), inherit.aes = FALSE,
    color = "grey15", fontface = "bold", size = 4.1,
    show.legend = FALSE) +
  geom_text(data = stable_annotations,
    aes(midpoint, id_y, label = era_id), inherit.aes = FALSE,
    fontface = "bold", size = 4.1) +
  time_axis() +
  scale_y_continuous(expand = expansion(mult = c(.07, .16))) +
  scale_fill_manual(values = era_colors, guide = "none") +
  scale_color_manual(values = c(variable_colors, context = "grey25"),
    labels = variable_labels, name = NULL) +
  labs(tag = "A.", title = "Holocene climate change", x = NULL,
       y = "Signed standardized change") +
  theme_paleoaces(base_size = 14) +
  theme(panel.grid.minor = element_blank(),
        axis.text.x = element_blank(), axis.ticks.x = element_blank(),
        legend.position = "none",
        plot.title = element_text(face = "bold", size = 17),
        axis.title.y = element_text(size = 15),
        axis.text.y = element_text(size = 13.5))

# A2. The fire-frequency ratio exposes the actual classification rule. A value
# of 1 is the site-specific robust threshold; values above 1 are high fire.
# This threshold normalization is dimensionless and avoids comparing raw
# charcoal magnitudes between the regional MORA and local NOCA records.
fire_ratio = fire_frequency |>
  filter(between(cal_bp, time_limits[2], time_limits[1]),
    is.finite(normalized_frequency), is.finite(high_fire_threshold),
    high_fire_threshold > 0) |>
  mutate(site = factor(site, levels = c("MORA", "NOCA")),
    high_fire_ratio = normalized_frequency / high_fire_threshold)
stopifnot(nrow(fire_ratio) > 0,
  all(fire_ratio$high_fire == (fire_ratio$high_fire_ratio > 1)))
write_csv(fire_ratio,
  here("output/holocene_era_fire_threshold_ratio.csv"))

p_fire = ggplot(fire_ratio, aes(cal_bp, high_fire_ratio, group = site)) +
  era_background(.28) +
  geom_hline(yintercept = 1, color = "grey45", linetype = "dashed",
    linewidth = .55) +
  geom_line(color = "grey20", linewidth = .8) +
  geom_segment(data = filter(fire_ratio, high_fire),
    aes(xend = cal_bp, y = 1, yend = high_fire_ratio),
    color = PAPER_FIRE_RED, linewidth = 2.2, alpha = .55) +
  geom_point(data = filter(fire_ratio, high_fire), color = PAPER_FIRE_RED,
    size = 1.35) +
  facet_grid(rows = vars(site), scales = "fixed") +
  time_axis() +
  scale_fill_manual(values = era_colors, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(.05, .10))) +
  labs(tag = "B.", x = "cal BP", y = "Fire-frequency ratio\n(high fire > 1)") +
  theme_paleoaces(base_size = 13) +
  theme(panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey94", color = "grey65"),
    strip.text.y = element_text(face = "bold", size = 12),
    axis.text.y = element_text(size = 11),
    axis.text.x = element_text(size = 13),
    axis.title = element_text(size = 14.5))

# Put the numerical comparison directly beside the Holocene trajectories. This
# behaves like a compact figure annotation rather than a separate table panel.
# H max is the signed Holocene maximum; its age is shown in parentheses. MORA
# and NOCA are the plot-level Anthropocene medians. All columns use raw rates
# per century, with temperature and precipitation units stated in the rows.
rate_callout = rate_comparison |>
  mutate(
    y = seq(3.65, .80, length.out = n()),
    variable_callout = case_when(
      variable == "MSpT" ~ "Spring temp\n(deg C)",
      variable == "MWT" ~ "Winter temp\n(deg C)",
      variable == "SP" ~ "Summer precip\n(mm)",
      variable == "WP" ~ "Winter precip\n(mm)"),
    holocene_callout = sprintf("%+.2f\n(%.1f ka)",
      holocene_max_signed_rate_per_century, holocene_peak_cal_bp / 1000),
    mora_callout = sprintf("%+.2f",
      anthropocene_median_rate_per_century_MORA),
    noca_callout = sprintf("%+.2f",
      anthropocene_median_rate_per_century_NOCA))

p_rate_callout = ggplot(rate_callout) +
  annotate("rect", xmin = -.48, xmax = 4.85, ymin = .25, ymax = 5.25,
    fill = "grey98", color = "grey72", linewidth = .45) +
  annotate("rect", xmin = -.47, xmax = 4.84, ymin = 4.18, ymax = 5.24,
    fill = "grey93", color = NA) +
  annotate("segment", x = -.25, xend = 4.62, y = 4.18, yend = 4.18,
    color = "grey72", linewidth = .4) +
  annotate("text", x = -.25, y = 4.94, label = "Raw rates per century",
    hjust = 0, fontface = "bold", size = 5.15) +
  annotate("text", x = c(2.25, 3.85), y = 4.63,
    label = c("Holocene", "Anthropocene"), fontface = "bold",
    color = "grey25", size = 3.85) +
  annotate("text", x = c(2.25, 3.35, 4.35), y = 4.30,
    label = c("Maximum\nregional median", "MORA", "NOCA"),
    fontface = "bold", lineheight = .88, size = c(3.25, 3.65, 3.65)) +
  geom_point(aes(-.20, y, color = variable), size = 3.2,
    show.legend = FALSE) +
  geom_text(aes(.02, y, label = variable_callout, color = variable),
    hjust = 0, lineheight = .90, size = 3.85, show.legend = FALSE) +
  geom_text(aes(2.25, y, label = holocene_callout),
    lineheight = .90, size = 3.80) +
  geom_text(aes(3.35, y, label = mora_callout), size = 3.80) +
  geom_text(aes(4.35, y, label = noca_callout), size = 3.80) +
  scale_color_manual(values = variable_colors) +
  coord_cartesian(xlim = c(-.5, 4.9), ylim = c(.2, 5.3), clip = "off") +
  theme_void() +
  theme(plot.margin = margin(8, 6, 8, 4))

# The callout shares the main plotting row. A spacer below it preserves exact
# horizontal alignment between the Holocene time series and the fire lanes.
top_row = p_climate + p_rate_callout +
  plot_layout(widths = c(5.2, 1.95))
bottom_row = p_fire + plot_spacer() +
  plot_layout(widths = c(5.2, 1.95))
figure = top_row / bottom_row +
  plot_layout(heights = c(4.5, 1.45))
if (render_figures) {
  ggsave(here("plot/fig_standardized_climate_change_eras_fire.pdf"), figure,
    width = 16.2, height = 9.5)
  ggsave(here("plot/fig_standardized_climate_change_eras_fire.png"), figure,
    width = 16.2, height = 9.5, dpi = 300, bg = "white")
}
cat("Written fire-threshold ratio and raw-rate comparison CSV",
    if (render_figures) ", plus the climate/fire figure.\n" else ".\n", sep = "")
# END R/stages/13a_climate_change_figure.R

# ============================================================================
# BEGIN R/stages/13b_fire_method_worked_example.R
# ============================================================================
# =============================================================================
# 13b_fire_method_worked_example.R
# Step-by-step worked example of the frozen Holocene high-fire method.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(patchwork)
})
source(here("R/helpers/figure_style.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

paths = c(
  events = here("output/holocene_fire_source_events.csv"),
  core = here("output/holocene_era_fire_core_frequency.csv"),
  site = here("output/holocene_era_fire_site_frequency.csv"))
if (!all(file.exists(paths))) stop(
  "Run the Walsh reconstruction and Holocene climate/fire stages first.")

events = read_csv(paths[["events"]], show_col_types = FALSE)
core = read_csv(paths[["core"]], show_col_types = FALSE)
site_grid = read_csv(paths[["site"]], show_col_types = FALSE)

EXAMPLE_AGE = 2300
WINDOW_YOUNGER = EXAMPLE_AGE - 500
WINDOW_OLDER = EXAMPLE_AGE + 500
LAKE_LEVELS = c("Little Sunrise Lake", "Shadow Lake", "Sunrise Lake",
                "PantherPotholes")
site_colors = PAPER_SITE_COLORS
fire_colors = c(`High fire` = "#9E2A2B", `Not high fire` = "grey55")

example_core = core %>%
  filter(cal_bp == EXAMPLE_AGE) %>%
  mutate(lake = factor(lake, levels = LAKE_LEVELS)) %>%
  arrange(lake)
example_site = site_grid %>%
  filter(cal_bp == EXAMPLE_AGE) %>%
  mutate(
    fire_frequency_ratio = normalized_frequency / high_fire_threshold,
    decision = if_else(high_fire, "High fire", "Not high fire"))
example_events = events %>%
  filter(age_cal_yr_BP >= WINDOW_YOUNGER,
         age_cal_yr_BP < WINDOW_OLDER) %>%
  mutate(lake = factor(lake, levels = LAKE_LEVELS))

# Independently verify the half-open centered-window event counts.
count_check = example_events %>% count(site, lake, name = "count_from_events")
example_core = example_core %>%
  left_join(count_check, by = c("site", "lake")) %>%
  mutate(count_from_events = coalesce(count_from_events, 0L))
if (nrow(example_core) != 4L || nrow(example_site) != 2L ||
    any(example_core$accepted_event_count != example_core$count_from_events) ||
    !identical(example_site$high_fire[match(c("MORA", "NOCA"),
      example_site$site)], c(TRUE, FALSE))) {
  stop("The 2,300 cal BP worked-example arithmetic is not reproducible")
}

audit = example_core %>%
  transmute(
    example_cal_bp = EXAMPLE_AGE,
    window_younger_cal_bp = WINDOW_YOUNGER,
    window_older_cal_bp = WINDOW_OLDER,
    site, lake = as.character(lake), accepted_event_count,
    frequency_per_1000_years = peak_frequency_per_1000yr,
    core_max_frequency,
    normalized_core_frequency = normalized_frequency) %>%
  left_join(example_site %>%
      select(site, covered_cores,
             normalized_site_frequency = normalized_frequency,
             threshold_median, threshold_robust_sd, high_fire_threshold,
             fire_frequency_ratio, high_fire, decision),
    by = "site")
write_csv(audit, here("output/holocene_fire_method_worked_example.csv"))

theme_method = theme_bw(base_size = 11.5) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(size = 10.2, color = "grey30"),
        legend.position = "none")

# 1. Show the accepted events inside the centered 1,000-year window.
p1 = ggplot(events %>%
    filter(between(age_cal_yr_BP, 1300, 3300)) %>%
    mutate(lake = factor(lake, levels = LAKE_LEVELS)),
    aes(age_cal_yr_BP, lake, color = site)) +
  annotate("rect", xmin = WINDOW_YOUNGER, xmax = WINDOW_OLDER,
           ymin = -Inf, ymax = Inf, fill = "grey80", alpha = .35) +
  geom_point(size = 2.0, alpha = .85) +
  geom_vline(xintercept = EXAMPLE_AGE, linetype = "dashed",
             color = "grey25", linewidth = .6) +
  scale_x_reverse(breaks = seq(3200, 1400, -400)) +
  scale_color_manual(values = site_colors) +
  labs(title = "1  Select accepted events",
       subtitle = "Centered 1,000-year window: [1,800, 2,800) cal BP",
       x = "cal BP", y = NULL) +
  theme_method

# 2. Count events and divide by each core's maximum frequency.
p2_data = example_core %>%
  mutate(
    lake_short = recode(as.character(lake),
      `Little Sunrise Lake` = "Little Sunrise",
      `Shadow Lake` = "Shadow", `Sunrise Lake` = "Sunrise",
      PantherPotholes = "Panther Potholes"),
    count_label = sprintf("%d / max %.0f = %.3f",
      accepted_event_count, core_max_frequency, normalized_frequency))
p2 = ggplot(p2_data,
    aes(reorder(lake_short, normalized_frequency), normalized_frequency,
        fill = site)) +
  geom_col(width = .68, alpha = .78) +
  geom_text(aes(label = count_label), hjust = -.08, size = 3.35) +
  coord_flip(clip = "off") +
  scale_fill_manual(values = site_colors) +
  scale_y_continuous(limits = c(0, 1.38), breaks = seq(0, 1, .25),
    expand = expansion(mult = c(0, .02))) +
  labs(title = "2  Normalize frequency within each core",
       subtitle = "normalized core frequency = 1,000-year count / core maximum",
       x = NULL, y = "Normalized core frequency") +
  theme_method

# 3. MORA is an equal-core mean; NOCA is the local Panther Potholes series.
p3_points = example_core %>%
  mutate(site = factor(site, levels = c("MORA", "NOCA")))
p3 = ggplot(example_site %>%
    mutate(site = factor(site, levels = c("MORA", "NOCA"))),
    aes(site, normalized_frequency, fill = site)) +
  geom_col(width = .55, alpha = .72) +
  geom_point(data = p3_points,
    aes(site, normalized_frequency), position = position_jitter(width = .10),
    shape = 21, fill = "white", color = "grey20", size = 3.0,
    inherit.aes = FALSE) +
  geom_text(aes(label = sprintf("%.3f", normalized_frequency)),
    vjust = -1.0, fontface = "bold", size = 4.0) +
  scale_fill_manual(values = site_colors) +
  scale_y_continuous(limits = c(0, 1.08),
    expand = expansion(mult = c(0, .02))) +
  labs(title = "3  Form the site frequency",
       subtitle = "MORA = equal mean of covered cores; NOCA = local record",
       x = NULL, y = "Normalized site frequency") +
  theme_method

# 4. Thresholds come from the complete site series, not the example date.
p4 = ggplot(site_grid %>%
    filter(between(cal_bp, 0, 10500), is.finite(normalized_frequency)),
    aes(cal_bp, normalized_frequency, color = site)) +
  geom_line(linewidth = .75) +
  geom_line(aes(y = high_fire_threshold), color = "grey25",
            linetype = "dashed", linewidth = .6) +
  geom_point(data = example_site, size = 3.3) +
  facet_grid(rows = vars(site)) +
  scale_x_reverse(breaks = seq(10000, 0, -2000)) +
  scale_color_manual(values = site_colors) +
  labs(title = "4  Calculate a robust site threshold",
       subtitle = "threshold = temporal median + 1.4826 × MAD",
       x = "cal BP", y = "Normalized site frequency") +
  theme_method +
  theme(strip.text.y = element_text(face = "bold"))

# 5. The threshold-normalized ratio has the exact cutoff 1.
p5 = ggplot(example_site,
    aes(reorder(site, fire_frequency_ratio), fire_frequency_ratio,
        fill = decision)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey25") +
  geom_col(width = .58, alpha = .82) +
  geom_text(aes(label = sprintf("%.2f\n%s", fire_frequency_ratio, decision)),
    vjust = -.35, fontface = "bold", size = 4.0) +
  scale_fill_manual(values = fire_colors) +
  scale_y_continuous(limits = c(0, 1.75), breaks = seq(0, 1.5, .5),
    expand = expansion(mult = c(0, .02))) +
  labs(title = "5  Classify the example date",
       subtitle = "fire-frequency ratio = site frequency / site threshold",
       x = NULL, y = "Fire-frequency ratio") +
  theme_method

# 6. Print the actual arithmetic and distinguish classification/corroboration.
mora = example_site %>% filter(site == "MORA")
noca = example_site %>% filter(site == "NOCA")
p6 = ggplot() +
  annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1,
           fill = "grey97", color = "grey70") +
  annotate("text", x = .04, y = .90, hjust = 0, fontface = "bold", size = 4.4,
    label = "6  Interpret without changing the rule") +
  annotate("text", x = .04, y = .68, hjust = 0, size = 3.55,
    label = sprintf(
      "MORA: mean(1.000, 1.000, 0.667) = %.3f\nthreshold = %.3f + %.3f = %.3f\nratio = %.2f  ->  HIGH FIRE",
      mora$normalized_frequency, mora$threshold_median,
      mora$threshold_robust_sd, mora$high_fire_threshold,
      mora$fire_frequency_ratio)) +
  annotate("text", x = .04, y = .36, hjust = 0, size = 3.55,
    label = sprintf(
      "NOCA: Panther Potholes = %.3f\nthreshold = %.3f + %.3f = %.3f\nratio = %.2f  ->  not high fire",
      noca$normalized_frequency, noca$threshold_median,
      noca$threshold_robust_sd, noca$high_fire_threshold,
      noca$fire_frequency_ratio)) +
  annotate("text", x = .04, y = .08, hjust = 0, size = 3.15,
    color = "grey30",
    label = paste("Peak strength and background CHAR can corroborate,",
                  "but cannot create a high-fire classification.")) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  theme_void()

figure = (p1 | p2) / (p3 | p4) / (p5 | p6) +
  plot_layout(heights = c(1, 1, .95)) +
  plot_annotation(
    title = "Worked example: Holocene high-fire classification at 2,300 cal BP",
    theme = theme(plot.title = element_text(face = "bold", size = 18,
                                             hjust = .5)))

if (render_figures) {
  ggsave(here("plot/test_figures/fig_holocene_fire_method_worked_example.pdf"), figure,
         width = 14, height = 11, units = "in", bg = "white")
  cat("Written Holocene fire worked example for 2,300 cal BP.\n")
}
# END R/stages/13b_fire_method_worked_example.R

# BEGIN R/helpers/tracking_metrics.R — calculation excerpts; see helper for full functions
# Endpoint geometry and lag/turnover rates
coords = c("o1", "o2", "o1_2", "o2_2", "p1", "p2", "p1_2", "p2_2")
ox = x$o1_2-x$o1; oy = x$o2_2-x$o2
px = x$p1_2-x$p1; py = x$p2_2-x$p2
a = sqrt(ox^2+oy^2); b = sqrt(px^2+py^2)
x$finite_endpoints = rowSums(!is.finite(as.matrix(x[coords]))) == 0L
observed_direction = x$finite_endpoints & is.finite(a) & a > epsilon
predicted_direction = x$finite_endpoints & is.finite(b) & b > epsilon
x$observed_vegetation_displacement = a
x$predicted_vegetation_displacement = b
x$observed_turnover_rate = a/x$vegetation_dt_years*100
x$predicted_vegetation_change_rate = b/x$climate_dt_years*100
x$lag_t1 = sqrt((x$o1-x$p1)^2+(x$o2-x$p2)^2)
x$lag_t2 = sqrt((x$o1_2-x$p1_2)^2+(x$o2_2-x$p2_2)^2)
x$change_in_lag = x$lag_t2-x$lag_t1
x$lag_rate_per_century = x$change_in_lag/x$climate_dt_years*100

# Tracking ratios and turnover angle
x$magnitude_tracking_ratio = ifelse(predicted_direction, a/b, NA_real_)
x$rate_tracking_ratio = ifelse(predicted_direction,
  x$observed_turnover_rate/x$predicted_vegetation_change_rate, NA_real_)
x$angle_degrees = acos(safe_cosine_2d(ox, oy, px, py, epsilon))*180/pi

# Guarded cosine used internally for the angle
a = sqrt(ax^2 + ay^2); b = sqrt(bx^2 + by^2)
ok = is.finite(a) & is.finite(b) & a > epsilon & b > epsilon
result = rep(NA_real_, n)
result[ok] = pmax(-1, pmin(1, (ax[ok]*bx[ok] + ay[ok]*by[ok])/(a[ok]*b[ok])))

# Pace and direction counterfactual effects
# Only divide by a direction's magnitude when that direction is defined.
x$pace_corrected_CCA1 = x$pace_corrected_CCA2 = rep(NA_real_, nrow(x))
x$direction_corrected_CCA1 = x$direction_corrected_CCA2 = rep(NA_real_, nrow(x))
i = observed_direction
x$pace_corrected_CCA1[i] = x$o1[i]+b[i]*ox[i]/a[i]
x$pace_corrected_CCA2[i] = x$o2[i]+b[i]*oy[i]/a[i]
i = predicted_direction
x$direction_corrected_CCA1[i] = x$o1[i]+a[i]*px[i]/b[i]
x$direction_corrected_CCA2[i] = x$o2[i]+a[i]*py[i]/b[i]
x$lag_t2_pace_corrected = sqrt((x$pace_corrected_CCA1-x$p1_2)^2+
  (x$pace_corrected_CCA2-x$p2_2)^2)
x$lag_t2_direction_corrected = sqrt((x$direction_corrected_CCA1-x$p1_2)^2+
  (x$direction_corrected_CCA2-x$p2_2)^2)
x$pace_effect_on_lag = x$lag_t2-x$lag_t2_pace_corrected
x$direction_effect_on_lag = x$lag_t2-x$lag_t2_direction_corrected
x$pace_effect_on_lag_per_century = x$pace_effect_on_lag/x$climate_dt_years*100
x$direction_effect_on_lag_per_century = x$direction_effect_on_lag/x$climate_dt_years*100

# Corrected lag-change rates for the additional GLS responses
x$pace_corrected_lag_rate_per_century = ifelse(x$pace_counterfactual_valid,
  (x$lag_t2_pace_corrected-x$lag_t1)*100/x$climate_dt_years, NA_real_)
x$direction_corrected_lag_rate_per_century = ifelse(x$direction_counterfactual_valid,
  (x$lag_t2_direction_corrected-x$lag_t1)*100/x$climate_dt_years, NA_real_)

# Physical seasonal climate changes and standardized rate
z_change_cols = character(0)
z_rate_cols = character(0)
for (v in vars) {
  s = scaling$sd[match(v, scaling$variable)]
  delta = x[[paste0(v, "_2")]] - x[[v]]
  x[[paste0(v, "_change")]] = delta
  x[[paste0(v, "_rate_per_century")]] = delta / x$climate_dt_years * 100
  x[[paste0(v, "_z_change")]] = delta / s
  x[[paste0(v, "_z_rate_per_century")]] = delta / s / x$climate_dt_years * 100
  z_change_cols = c(z_change_cols, paste0(v, "_z_change"))
  z_rate_cols = c(z_rate_cols, paste0(v, "_z_rate_per_century"))
}
x$standardized_climate_displacement = sqrt(rowSums(x[z_change_cols]^2))
x$standardized_climate_change_rate = sqrt(rowSums(x[z_rate_cols]^2))

# END R/helpers/tracking_metrics.R
