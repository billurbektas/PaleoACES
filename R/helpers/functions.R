# Function to calculate colonization and extinction for each plot
calculate_turnover = function(mora_occ) {
  
  cat("Calculating species turnover by plot...\n")
  
  # Create presence/absence matrix for each period
  past_species = mora_occ %>%
    filter(period == "past", occurrence == 1) %>%
    select(plot_id, species) %>%
    mutate(past_present = 1)
  
  present_species = mora_occ %>%
    filter(period == "present", occurrence == 1) %>%
    select(plot_id, species) %>%
    mutate(present_present = 1)
  
  # Get all plot-species combinations
  all_plots = unique(mora_occ$plot_id)
  all_species = unique(mora_occ$species)
  
  # Full join to get all combinations and classify changes
  turnover_data = expand_grid(plot_id = all_plots, species = all_species) %>%
    left_join(past_species, by = c("plot_id", "species")) %>%
    left_join(present_species, by = c("plot_id", "species")) %>%
    mutate(
      past_present = ifelse(is.na(past_present), 0, past_present),
      present_present = ifelse(is.na(present_present), 0, present_present),
      change_type = case_when(
        past_present == 1 & present_present == 1 ~ "persistent",
        past_present == 1 & present_present == 0 ~ "extinct", 
        past_present == 0 & present_present == 1 ~ "colonized",
        past_present == 0 & present_present == 0 ~ "absent"
      )
    ) %>%
    filter(change_type != "absent")  # Remove species never present in either period
  
  # Summarize by plot
  plot_turnover = turnover_data %>%
    count(plot_id, change_type) %>%
    pivot_wider(names_from = change_type, values_from = n, values_fill = 0) %>%
    mutate(
      total_past = persistent + extinct,
      total_present = persistent + colonized,
      net_change = colonized - extinct,
      turnover_rate = (colonized + extinct) / (total_past + colonized), # Jaccard-style turnover
      richness_change = total_present - total_past
    )
  
  # Species-level summary
  species_turnover = turnover_data %>%
    count(species, change_type) %>%
    pivot_wider(names_from = change_type, values_from = n, values_fill = 0) %>%
    mutate(
      total_occurrences = persistent + extinct + colonized,
      colonization_rate = colonized / total_occurrences,
      extinction_rate = extinct / total_occurrences
    )
  
  cat("Turnover analysis complete!\n")
  cat("- Plots analyzed:", nrow(plot_turnover), "\n")
  cat("- Species analyzed:", nrow(species_turnover), "\n\n")
  
  return(list(
    plot_turnover = plot_turnover,
    species_turnover = species_turnover,
    turnover_data = turnover_data
  ))
}

# Visualization 1: Turnover Heatmap
create_turnover_heatmap = function(turnover_data) {
  
  # Create matrix for heatmap
  heatmap_data = turnover_data %>%
    filter(change_type %in% c("colonized", "extinct")) %>%
    mutate(
      plot_rank = dense_rank(plot_id),
      species_rank = dense_rank(species)
    )
  
  p = heatmap_data %>%
    ggplot(aes(x = reorder(species, species_rank), y = reorder(plot_id, plot_rank), 
               fill = change_type)) +
    geom_tile(color = "white", linewidth = 0.1) +
    scale_fill_manual(values = c("colonized" = "#2E8B57", "extinct" = "#DC143C"),
                      name = "Change Type",
                      labels = c("Colonized", "Extinct")) +
    labs(
      title = "Species Turnover Heatmap", 
      subtitle = "Green = colonization, Red = extinction",
      x = "Species",
      y = "Plot ID"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 1, size = 6),
      axis.text.y = element_text(size = 3),
      plot.title = element_text(size = 14, face = "bold"),
      panel.grid = element_blank()
    )
  
  return(p)
}

# Visualization 2: Alluvial diagram showing species flow
create_alluvial_plot = function(turnover_data, top_n_species = 20) {
  
  # Get most common species for cleaner visualization
  top_species = turnover_data %>%
    count(species, sort = TRUE) %>%
    slice_head(n = top_n_species) %>%
    pull(species)
  
  alluvial_data = turnover_data %>%
    filter(species %in% top_species) %>%
    mutate(
      past_status = ifelse(past_present == 1, "Present", "Absent"),
      present_status = ifelse(present_present == 1, "Present", "Absent")
    ) %>%
    count(species, past_status, present_status, change_type) %>%
    filter(!(past_status == "Absent" & present_status == "Absent"))
  
  p = alluvial_data %>%
    ggplot(aes(axis1 = past_status, axis2 = present_status, y = n)) +
    geom_alluvium(aes(fill = change_type), alpha = 0.7) +
    geom_stratum(alpha = 0.8, color = "white") +
    geom_text(stat = "stratum", aes(label = after_stat(stratum)), size = 3) +
    scale_fill_manual(values = c("persistent" = "#4A90E2", 
                                 "colonized" = "#2E8B57", 
                                 "extinct" = "#DC143C"),
                      name = "Change Type") +
    scale_x_discrete(limits = c("Past (1975)", "Present"), expand = c(0.1, 0.1)) +
    labs(
      title = paste0("Species Flow Between Time Periods (Top ", top_n_species, " Species)"),
      subtitle = "Flow width = number of plot occurrences",
      y = "Number of Plot Occurrences"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      axis.title.x = element_blank(),
      panel.grid = element_blank()
    )
  
  return(p)
}

# Summary statistics function
print_turnover_summary = function(turnover_results) {
  
  plot_turnover = turnover_results$plot_turnover
  species_turnover = turnover_results$species_turnover
  
  cat("=== SPECIES TURNOVER SUMMARY ===\n\n")
  
  # Plot-level summary
  cat("PLOT-LEVEL CHANGES:\n")
  cat("- Total plots analyzed:", nrow(plot_turnover), "\n")
  cat("- Mean extinctions per plot:", round(mean(plot_turnover$extinct), 2), "\n")
  cat("- Mean colonizations per plot:", round(mean(plot_turnover$colonized), 2), "\n")
  cat("- Mean net change per plot:", round(mean(plot_turnover$net_change), 2), "\n")
  cat("- Mean turnover rate:", round(mean(plot_turnover$turnover_rate), 3), "\n")
  
  cat("\nPlots with highest net colonization:\n")
  print(plot_turnover %>% 
          arrange(desc(net_change)) %>% 
          select(plot_id, extinct, colonized, net_change) %>% 
          head(5))
  
  cat("\nPlots with highest net extinction:\n")
  print(plot_turnover %>% 
          arrange(net_change) %>% 
          select(plot_id, extinct, colonized, net_change) %>% 
          head(5))
  
  # Species-level summary  
  cat("\nSPECIES-LEVEL CHANGES:\n")
  cat("- Total species analyzed:", nrow(species_turnover), "\n")
  
  cat("\nMost colonizing species:\n")
  print(species_turnover %>% 
          filter(colonized > 0) %>%
          arrange(desc(colonized)) %>% 
          select(species, colonized, persistent, extinct) %>% 
          head(5))
  
  cat("\nMost extinction-prone species:\n") 
  print(species_turnover %>%
          filter(extinct > 0) %>%
          arrange(desc(extinct)) %>% 
          select(species, extinct, persistent, colonized) %>% 
          head(5))
}
