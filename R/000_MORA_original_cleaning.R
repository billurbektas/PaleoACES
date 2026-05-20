# Clean MORA Cascade Legacy Data (Original 1978) ----
library(tidyverse)
library(readxl)
library(here)

# Read the original 1978 data ----
file_path = here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx")
MORA_raw = read_excel(file_path, sheet = "Rainier Veg")
head(MORA_raw)

# Get only columns with size classes (ending in a digit) ----
MORA_trees = MORA_raw %>%
  select(SiteName, Plotno, matches("\\d$")) %>%
  pivot_longer(cols = -c(SiteName, Plotno),
               names_to = "species_code",
               values_to = "value") %>%
  mutate(size_class = str_extract(species_code, "\\d$"),
         species_code = str_remove(species_code, "\\d$"),
         value_clean = case_when(value == 0.1 ~ 0,
                                 value == 0.2 ~ 1,
                                 .default = value))

head(MORA_trees)

MORA_tree_counts =
  MORA_trees %>%
  filter(size_class !=1)%>% #we do not want to seedlings for now
  group_by(SiteName, Plotno, species_code)%>%
  summarize(count_po = sum(value, na.rm = TRUE),
            count_po_clean = sum(value_clean, na.rm = TRUE))

# Read raw size data ----
MORA_raw_size = read_excel(file_path, sheet = "rawsizedata")

head(MORA_raw_size)

# Sum DBH counts per plot and species ----
# Big trees columns are DBH in cm, convert to presence/absence first
MORA_size_summary = MORA_raw_size %>%
  #mutate(across(starts_with("bigtree"), ~ ifelse(!is.na(.), 1, 0))) %>% # we discovered that big trees are already counted in dbh>120
  rowwise() %>%
  mutate(count_dbh = sum(c_across(DBH0:`>DBH120`), na.rm = TRUE))%>%
         #count_bigtrees = count_no_bigtrees + sum(c_across(bigtree1:bigtree7), na.rm = TRUE)) %>%
  ungroup() %>%
  select(Plotno, Species, count_dbh)%>%
  rename(species_code = Species)%>%
  group_by(Plotno, species_code)%>%
  summarize(count_dbh = sum(count_dbh, na.rm = TRUE))

MORA_all_trees = 
  left_join(MORA_size_summary, MORA_tree_counts, by = c("Plotno", "species_code"))%>%
  mutate(is_different_count = (count_po != count_dbh),
         is_different_count_clean = (count_po_clean != count_dbh),
         is_different_po = (count_po != count_po_clean))%>%
  mutate(count_diff = count_dbh - count_po_clean)

# Identify mismatches where one source has 0 but the other doesn't ----
MORA_zero_mismatches = MORA_all_trees %>%
  filter((count_dbh == 0 & count_po_clean > 0) | (count_dbh > 0 & count_po_clean == 0)) %>%
  mutate(mismatch_type = case_when(
    count_dbh == 0 & count_po_clean > 0 ~ "missing_in_dbh",
    count_dbh > 0 & count_po_clean == 0 ~ "missing_in_po"
  ))

MORA_zero_mismatches
