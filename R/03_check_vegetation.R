# Check MORA vegetation data ----
plots_past = MORA_occ %>% filter(period == "past") %>% pull(plot_id) %>% unique()
if(all(plots_past %in% plot_info$plot_id)){
  cat("All the past survey plots are in the plot idendifier table.")
}else{
  cat("Not all the past plots are in the plot identifier table.")
  print(plots_past[!plots_past %in% plots$id])
}

plots_present = MORA_occ %>% filter(period == "present") %>% pull(plot_id) %>% unique()
if(all(plots_present %in% plot_info$plot_id)){
  cat("All the present survey plots are in the plot idendifier table.")
}else{
  cat("Not all the present plots are in the plot identifier table.")
  print(plots_present[!plots_present %in% plots$id])
}

if(all(plots_past %in% plots_present)){
  cat("All the past survey plots are revisited in present plots.")
}else{
  cat("Not all the past plots are revisited in present plots.")
  print(plots_past[!plots_past %in% plots_present])
}

species_present = MORA_occ %>% filter(period == "present") %>% pull(species) %>% unique()
species_past = MORA_occ %>% filter(period == "past") %>% pull(species) %>% unique()

cat("There are ", length(plots_past), "sites and ", length(species_past), "species in the past surveys.")
cat("There are ", length(plots_present), "sites and ", length(species_present), "species in the present surveys.")

cat("The common species between the two surveys are:", intersect(species_present, species_past))
cat("The different species between the two surveys are:", setdiff(species_present, species_past))
cat("Species that were present in the past surveys but absent in present surveys:", species_past[!species_past %in% species_present])

# Check NOCA vegetation data ----
plots_past = NOCA_occ %>% filter(period == "past") %>% pull(plot_id) %>% unique()
if(all(plots_past %in% NOCA_plot_info$plot_id)){
  cat("All the past survey plots are in the plot idendifier table.")
}else{
  cat("Not all the past plots are in the plot identifier table.")
  print(plots_past[!plots_past %in% NOCA_plot_info$id])
}

plots_present = NOCA_occ %>% filter(period == "present") %>% pull(plot_id) %>% unique()
if(all(plots_present %in% NOCA_plot_info$plot_id)){
  cat("All the present survey plots are in the plot idendifier table.")
}else{
  cat("Not all the present plots are in the plot identifier table.")
  print(plots_present[!plots_present %in% NOCA_plot_info$id])
}

if(all(plots_past %in% plots_present)){
  cat("All the past survey plots are revisited in present plots.")
}else{
  cat("Not all the past plots are revisited in present plots.")
  print(plots_past[!plots_past %in% plots_present])
}

species_present = NOCA_occ %>% filter(period == "present") %>% pull(species) %>% unique()
species_past = NOCA_occ %>% filter(period == "past") %>% pull(species) %>% unique()

cat("There are ", length(plots_past), "sites and ", length(species_past), "species in the past surveys.")
cat("There are ", length(plots_present), "sites and ", length(species_present), "species in the present surveys.")

cat("The common species between the two surveys are:", intersect(species_present, species_past))
cat("The different species between the two surveys are:", setdiff(species_present, species_past))
cat("Species that were present in the past surveys but absent in present surveys:", species_past[!species_past %in% species_present])
