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
  mutate(species = str_to_sentence(species))

NOCA_present = 
  read_excel("data/NOCA/NOCA_vegetation_fromJHRL.xlsx", sheet = "Tree Data") %>%
  rename(plot_id = `Plot ID`, 
         present_species_abv = species_abv
  )%>%
  select(plot_id, present_species_abv, DBH)%>%
  left_join(NOCA_present_splib, by = "present_species_abv")%>%
  mutate(plot_id = toupper(plot_id))

# Track present plots with no species data
takeout_plots_present = 
  NOCA_present %>%
  filter(is.na(species))%>%
  pull(plot_id)%>%
  unique()

takeout_plots_present =
  NOCA_present %>%
  filter(plot_id %in% takeout_plots_present)%>%
  group_by(plot_id)%>%
  mutate(n = sum(is.na(species)/n()))%>%
  filter(n == 1)%>%
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

NOCA_present = NOCA_present %>% filter(!plot_id %in% takeout_plots_present)

# Get all present plots from NOCA_plots (includes plots with no trees)
all_present_plots_raw = NOCA_plots %>% filter(!plot_id %in% takeout_plots_present) %>% pull(plot_id)%>% unique()
present_plots_with_trees = NOCA_present %>% 
  filter(!is.na(species)) %>% 
  pull(plot_id) %>% 
  unique()
present_empty_plots = setdiff(all_present_plots_raw, present_plots_with_trees)

NOCA_present_occ = NOCA_present %>% select(plot_id, species)
NOCA_present_occ = NOCA_present_occ %>% group_by(plot_id, species)%>% summarize(count = n())%>% mutate(occurence = 1)

cat("There are", length(unique(NOCA_present_occ$plot_id)), "plots in the present data.")

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

NOCA_past = 
  NOCA_past %>%
  mutate(`DEN_0-3` = ifelse(is.na(`DEN_0-3`), 0, `DEN_0-3`),
         `DEN_3-10` = ifelse(is.na(`DEN_3-10`), 0, `DEN_3-10`),
         `DEN >10` = ifelse(is.na(`DEN >10`), 0, `DEN >10`)
  )%>%
  mutate(count = `DEN_0-3` + `DEN_3-10` + `DEN >10`)

# Check if there are any species with no taxonomic names assigned. 
no_info_sp = NOCA_past %>% filter(is.na(species)) %>% pull(past_species_abv)%>% unique()
if(length(no_info_sp)>0) {cat(, " are the species abb. with no species name info.")}

NOCA_plot_info = NOCA_past %>% select(plot_id, Latitude, Longitude, elevation) %>% distinct()%>%
  mutate(Longitude=ifelse(Longitude>0, -Longitude, Longitude))

NOCA_past_occ = NOCA_past %>% select(plot_id, species, count) %>%
  filter(count >0)%>%
  mutate(occurence = 1)

# Identify plots with zero trees in past (empty plots)
past_empty_plots = NOCA_past %>% 
  group_by(plot_id) %>% 
  summarize(total_count = sum(count, na.rm = TRUE)) %>%
  filter(total_count == 0) %>%
  pull(plot_id)

# Identify plots with trees in past but empty now
past_plots_with_trees = unique(NOCA_past_occ$plot_id)
plots_trees_past_empty_now = intersect(past_plots_with_trees, present_empty_plots)

# Identify plots empty in both periods
plots_empty_both_periods = intersect(present_empty_plots, past_empty_plots)

# Check if any duplicates
if(length(NOCA_past_occ %>% group_by(plot_id, species)%>% summarize(count = n()) %>% filter(count >1) %>% pull(count))>1) {prin("There are duplicates.")}

# Merge past and present occurences ----
# Use all plots from raw data, including empty plots
all_past_plots_raw = unique(NOCA_past$plot_id)

# This now correctly includes empty present plots
plots_to_keep = unique(intersect(all_present_plots_raw, all_past_plots_raw))

# Remove plots that are empty in both periods from final dataset
plots_to_keep = setdiff(plots_to_keep, plots_empty_both_periods)

# Identify special cases within the plots to keep
plots_empty_past_present_now = intersect(past_empty_plots, intersect(present_plots_with_trees, plots_to_keep))
plots_trees_past_empty_now = intersect(past_plots_with_trees, intersect(present_empty_plots, plots_to_keep))
plots_with_data_both_periods = intersect(past_plots_with_trees, intersect(present_plots_with_trees, plots_to_keep))

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
removed_present = setdiff(all_present_plots_raw, c(plots_to_keep, plots_empty_both_periods))
removed_past = setdiff(all_past_plots_raw, c(plots_to_keep, plots_empty_both_periods))

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
pdf(file = "plot/NOCA_cleaning.pdf", height = 8, width = 10)
print(p1)
print(p2)
print(p3)
dev.off()

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

# Write all outputs ----
# To take out: "CARI449" "CARI450" they have the same coordinates!
write_csv(NOCA_present_occ, file = here("output/NOCA_present_occ.csv"))
write_csv(NOCA_past_occ, file = here("output/NOCA_past_occ.csv"))
write_csv(NOCA_plot_info, file = here("output/NOCA_plot_info.csv"))
write_csv(NOCA_occ, file = here("output/NOCA_occ.csv"))
write_csv(plot_tracking, file = here("output/NOCA_plot_tracking.csv"))