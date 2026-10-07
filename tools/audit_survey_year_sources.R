# Reproduce the 2026-10-07 MORA source-year audit without changing received data.
# Rscript tools/audit_survey_year_sources.R [dissimilarityPNW-main] [baseline output]
suppressPackageStartupMessages({library(here); library(readr); library(readxl); library(dplyr)})
source(here("R/helpers/survey_years.R"), local = TRUE)
args = commandArgs(TRUE)
upstream = if (length(args)) args[1] else path.expand("~/Downloads/dissimilarityPNW-main")
baseline = if (length(args) > 1) args[2] else here("output")
original_dir = file.path(upstream, "Data/01_CommunityData/01_OriginalFiles")
clean_dir = file.path(upstream, "Data/01_CommunityData/02_CleanedFiles")
workbook = here("data/MORA/MORA_Cascade Legacy Data_Master2019.xlsx")
notes_path = here("data/MORA/MORA_PlotNames.csv")
notes = read_csv(notes_path, show_col_types = FALSE) %>% mutate(evidence_row = row_number() + 1L)
source_key = function(z) {
  z = normalize_mora_visit(z)
  z = gsub("-?FIELD", "", z)
  gsub("WHITR-", "WHIT-", z, fixed = TRUE)
}
notes = notes %>% mutate(key = source_key(`Plot ID`))
baseline_ids = read_csv(file.path(baseline, "cca_tracking_anthropocene_plot.csv"),
  show_col_types = FALSE) %>% filter(site == "MORA") %>% pull(plot_id)
pl = read_csv(here("data/MORA/MORA_plot_lib.csv"), show_col_types = FALSE)
adults = read_csv(here("data/MORA/MORA_TreeData_Resurvey_Cleaned.csv"), show_col_types = FALSE)
original_adults = read_csv(file.path(original_dir, "MORA_TreeData_Resurvey_Org.csv"), show_col_types = FALSE)
stopifnot(identical(original_adults$Year, adults$Year),
  identical(original_adults$`Order entered`, adults$Order.entered),
  identical(unname(tools::md5sum(file.path(clean_dir, "MORA_TreeData_Resurvey_Cleaned.csv"))),
    unname(tools::md5sum(here("data/MORA/MORA_TreeData_Resurvey_Cleaned.csv")))))
adult_years = adults %>% filter(!is.na(Plot_ID), !is.na(Year)) %>% group_by(Plot_ID) %>%
  summarise(adult_years = paste(sort(unique(Year)), collapse = ";"),
    selected_adult_year = max(Year), .groups = "drop")
sha = function(path) digest::digest(file = path, algo = "sha256")
evidence = list()
for (stage in c("Seedlings", "VegData")) {
  original = file.path(original_dir, paste0("MORA_", stage, "_Resurvey_Org.csv"))
  upstream_cleaned = file.path(clean_dir, paste0("MORA_", stage, "_Resurvey_Cleaned.csv"))
  local_cleaned = here("data/MORA", paste0("MORA_", stage, "_Resurvey_Cleaned.csv"))
  raw = read_csv(original, show_col_types = FALSE)
  clean = read_csv(local_cleaned, show_col_types = FALSE)
  stopifnot(sha(upstream_cleaned) == sha(local_cleaned), identical(raw$Year, clean$Year),
    identical(raw$`Order entered`, clean$Order.entered), nrow(raw) == nrow(clean))
  sheet = if (stage == "Seedlings") "Seedlings" else "Veg Data"
  master = read_excel(workbook, sheet = sheet) %>%
    mutate(key = source_key(`Plot ID`), evidence_row = row_number() + 1L)
  reference = master %>%
    group_by(key) %>% filter(n_distinct(Year) == 1L) %>%
    summarise(reference_year = first(Year),
      evidence = paste0("Master2019.xlsx: ", sheet, "!A", min(evidence_row),
        ",C", min(evidence_row)), .groups = "drop")
  # A nonunique workbook key is a repeat visit, not permission to substitute a
  # single dated-note year and call its earlier legitimate visit an error.
  fallback = notes %>% filter(!key %in% master$key) %>%
    group_by(key) %>% filter(n_distinct(Year) == 1L) %>%
    summarise(reference_year = first(Year),
      evidence = paste0("MORA_PlotNames.csv line ", min(evidence_row),
        ": ", first(Date)), .groups = "drop")
  reference = bind_rows(reference, fallback)
  differences = clean %>% mutate(key = source_key(Plot.ID), csv_line = row_number() + 1L) %>%
    left_join(reference, by = "key") %>%
    filter(!is.na(reference_year), Year != reference_year) %>%
    mutate(standardized_id_missing = is.na(Plot_ID), Plot_ID = coalesce(Plot_ID, Plot.ID)) %>%
    group_by(Plot_ID, Plot.ID, Year, reference_year, evidence, standardized_id_missing) %>%
    summarise(first_csv_line = min(csv_line), records = n(), .groups = "drop") %>%
    mutate(stage = if (stage == "Seedlings") "seedling" else "understory",
      original_evidence = paste0(basename(original), " line ", first_csv_line),
      cleaned_evidence = paste0(basename(local_cleaned), " line ", first_csv_line),
      original_sha256 = sha(original), cleaned_sha256 = sha(local_cleaned))
  evidence[[stage]] = differences
}
detail = bind_rows(evidence) %>% left_join(pl %>% select(Plot_ID, plot_id), by = "Plot_ID") %>%
  left_join(adult_years, by = "Plot_ID") %>%
  mutate(baseline_analyzed = plot_id %in% baseline_ids,
    treatment = case_when(is.na(plot_id) ~ "outside paired plot library; not used in active analysis",
      stage == "seedling" ~ "assign adult visit year; retain latest visit",
      TRUE ~ "understory not used in PaleoACES tree presence"),
    reference_sha256 = sha(workbook), dated_notes_sha256 = sha(notes_path))
join_unique = function(x) paste(sort(unique(x)), collapse = "; ")
curated = detail %>% group_by(Plot_ID) %>% summarise(
  plot_id = first(plot_id), baseline_analyzed = any(baseline_analyzed),
  standardized_id_missing = any(standardized_id_missing),
  stages = join_unique(stage),
  seedling_years = join_unique(paste0(Year[stage == "seedling"], " -> ",
    reference_year[stage == "seedling"])),
  understory_years = join_unique(paste0(Year[stage == "understory"], " -> ",
    reference_year[stage == "understory"])),
  original_visit_names = join_unique(Plot.ID),
  original_evidence = join_unique(original_evidence),
  cleaned_evidence = join_unique(cleaned_evidence), reference_evidence = join_unique(evidence),
  adult_years = first(adult_years), selected_adult_year = first(selected_adult_year),
  treatment = join_unique(treatment), .groups = "drop") %>% arrange(Plot_ID)
print(detail %>% group_by(stage) %>% summarise(supplied_ids = n_distinct(Plot_ID),
  analyzed_ids = n_distinct(Plot_ID[baseline_analyzed]), .groups = "drop"))
cat("Union:", nrow(curated), "; baseline analyzed:", sum(curated$baseline_analyzed), "\n")
stopifnot(nrow(curated) == 95L, sum(curated$baseline_analyzed) == 48L,
  n_distinct(detail$Plot_ID[detail$stage == "seedling"]) == 85L,
  n_distinct(detail$Plot_ID[detail$stage == "understory"]) == 93L)
write_csv(curated, here("data/MORA/resurvey_year_source_discrepancies.csv"))
write_csv(detail, here("output/MORA_resurvey_source_evidence.csv"))

# Attach dated source locations to the vetted mapping for repeat seedlings.
map_path = here("data/MORA/resurvey_seedling_visit_mapping.csv")
map = read_csv(map_path, show_col_types = FALSE) %>% select(Plot_ID, visit_name, source_year, adult_year)
dated = notes %>% mutate(visit_name = normalize_mora_visit(`Plot ID`)) %>%
  group_by(visit_name, adult_year = Year) %>% summarise(
    visit_date = join_unique(Date), dated_evidence = paste0("MORA_PlotNames.csv line ",
      min(evidence_row)), .groups = "drop")
map = map %>% left_join(dated, by = c("visit_name", "adult_year")) %>%
  mutate(evidence = paste0(dated_evidence, ": ", visit_date,
    "; adult TreeData Year; verified 2026-10-07"))
stopifnot(!anyNA(map$evidence))
write_csv(map, map_path)
cat("Verified: 95 affected supplied IDs, 48 baseline analyzed; original and cleaned CSV years identical.\n")
