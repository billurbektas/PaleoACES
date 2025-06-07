# Some checks on the data ----
plots_past = rownames(past_cleaned)
if(all(plots_past %in% plots$id)){
  cat("All the past survey plots are in the plot idendifier table.")
}else{
  cat("Not all the past plots are in the plot identifier table.")
  print(plots_past[!plots_past %in% plots$id])
}

plots_present = rownames(present_cleaned)
if(all(plots_present %in% plots$id)){
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

cat("There are ", nrow(past_cleaned), "sites and ", ncol(past_cleaned), "species in the past surveys.")
cat("There are ", nrow(present_cleaned), "sites and ", ncol(present_cleaned), "species in the present surveys.")

present_species = colnames(present_cleaned)
past_species = colnames(past_cleaned)

cat("The common species between the two surveys are:", intersect(present_species, past_species))
cat("The different species between the two surveys are:", setdiff(present_species, past_species))
cat("Species that were present in the past surveys but absent in present surveys:", past_species[!past_species %in% present_species])

# Prepare the PA and env matrices ----
rownames(past_cleaned) <- paste0("past_", rownames(past_cleaned))
rownames(present_cleaned) <- paste0("present_", rownames(past_cleaned))

env = 
  bind_rows(clim_mora %>%
              select(id1, MAP_past, MAT_past) %>%
              mutate(id1 = paste0("past_", id1))%>%
              rename(MAT = MAT_past, MAP = MAP_past)%>%
              column_to_rownames("id1"),
            clim_mora %>%
              select(id1, MAP_present, MAT_present)%>%
              mutate(id1 = paste0("present_", id1))%>%
              rename(MAT = MAT_present, MAP = MAP_present)%>%
              column_to_rownames("id1")
            )
  
  
comm = bind_rows(past_cleaned, present_cleaned)%>%
  mutate(across(everything(), ~replace_na(., 0)))


# Clean paleo data ----
# JayBath = (latitude 46?46' N, longitude 121?46' W)
# Log Wallow = (latitude 46?46' N, longitude 121?45'W)
# Reclection Pond = (latitude 46?46' N, longitude 121?43' W
takeoutsp = c("Carex Achenes Lenticular", "Carex Achenes Trigonous", "Charcoal Fragments", "Isoetes Megaspores", "Needle Concentration (per CC)",
              "Nuphar Polysepalum Seeds", "Potamogeton Species Achenes","Ranunculus CF Aquatilis Achenes", "Charred Needles","Sparganium Seeds",
              "Phyllodoce Seeds", "Phyllodoce Leaves", "Needle Concentration (Per CC)"
              
              )
paleo_species = 
  paleo_surveys %>%
  select(Species)%>%
  distinct()%>%
  mutate(species_cleaned = case_when(Species == "Abies Amabilis" ~ "Abies amabilis",
                                     Species == "Abies Lasiocarpa" ~ "Abies lasiocarpa",
                                     Species == "Abies Procera" ~ "Abies procera",
                                     Species %in% c("Pinus Contorta","Pinus Contorta Fascicles", "Pinus Contorta Fascilcles", "Pinus Contorta Needle Fragments") ~ "Pinus contorta",
                                     Species %in% c("Pinus Monticola Fascicles", "Pinus Monticola Needle Fragments", "Pinus Montocola Needle Fragments") ~ "Pinus monticola",
                                     Species == "Pseudotsuga Menziesii" ~ "Pseudotsuga menziesii",
                                     Species == "Tsuga Heterophylla" ~ "Tsuga heterophylla",
                                     Species %in% c("Tsuga Mertensiana", "Tsuga Mertinsiana") ~ "Tsuga mertensiana",
                                     Species == "Juncus Seeds" ~ "Juncus",
                                     Species == "Abies-Type Seeds" ~ "Abies",
                                     Species == "Picea Engelmannii" ~ "Picea engelmannii",
                                     Species %in% c("Chamaecyparis Seeds", "Chamaecyparis") ~ "Chamaecyparis",
                                     Species == "Tsuga-Type Seeds" ~ "Tsuga",
                                     .default = NA
                                     ))

paleo_cleaned = 
paleo_surveys %>%
  left_join(paleo_species)%>%
  mutate(plot = paste0(Location, "_", Depth))%>%
  filter(!is.na(species_cleaned))

plot_ages = 
  paleo_cleaned %>%
  select(Location, plot, Depth)%>%
  distinct()

paleo_cleaned =
  paleo_cleaned %>%
  group_by(plot, species_cleaned)%>%
  summarize(Percentage = sum(Percentage))%>%
  mutate(Percentage = ifelse(Percentage >0, 1, 0))%>%
  distinct()%>%
  pivot_wider(names_from = species_cleaned, values_from = Percentage, values_fill = 0)%>%
  column_to_rownames("plot")

# Fit models forcing through origin
# Create spline models with origin constraint
spline_models = paleo_age %>%
  group_by(Location) %>%
  group_split() %>%
  map(~{
    loc_name <- first(.x$Location)
    
    # Add origin point (0,0)
    augmented_data <- bind_rows(
      .x,
      tibble(
        Depth = 0,
        Age = 0,
        Location = loc_name
      )
    ) %>%
      arrange(Depth)
    
    smooth.spline(augmented_data$Depth, augmented_data$Age, df = 5, spar = 0.3)
  }) %>%
  set_names(unique(paleo_age$Location))

# Create prediction dataframe for plotting
pred_df = map_dfr(unique(paleo_age$Location), ~{
  loc = .x
  depth_range = paleo_age %>% 
    filter(Location == loc) %>% 
    pull(Depth) %>% 
    range()
  
  depth_seq <- seq(0, max(depth_range), length.out = 100)
  
  pred_values <- predict(spline_models[[loc]], depth_seq)
  
  tibble(
    Depth = depth_seq,
    Age_pred = pred_values$y,
    Location = loc
  )
})

# For the new dataset: predict ages for paleo_plots
predicted_ages =
  plot_ages %>%
  rowwise() %>%
  filter(Location %in% names(spline_models)) %>%
  mutate(
    Predicted_Age = predict(spline_models[[Location]], Depth)$y
  ) %>%
  ungroup()

pdf(file = here("plot/depth_age_model.pdf"), width = 8, height = 6)
ggplot() +
  geom_line(data = paleo_age, aes(x = Depth, y = Age, color = Location, group = Location)) +
  geom_point(data = paleo_age, aes(x = Depth, y = Age, color = Location)) +
  geom_line(data = pred_df, aes(x = Depth, y = Age_pred, color = Location), 
            linetype = "dashed") +
  geom_point(data = predicted_ages, aes(x = Depth, y = Predicted_Age, color = Location), 
             shape = 8, size = 2) +
  scale_x_reverse() +
  scale_y_reverse() +
  labs(x = "Depth", y = "Age", title = "Depth-Age Model (Spline Through Origin)") +
  theme_minimal() +
  theme(panel.grid.major = element_line(color = "gray90"),
        panel.grid.minor = element_line(color = "gray95"))
dev.off()

paleo_species = unique(paleo_species$species_cleaned)

intersect(paleo_species, past_species)
setdiff(paleo_species, past_species)

paleo_plots = 
  predicted_ages %>%
  mutate(lat = case_when(Location == "JayBath" ~ 46.7667,
                         Location == "LogWallow" ~ 46.7667,
                         Location == "ReflectionPond" ~ 46.7667))%>%
  mutate(lon = case_when(Location == "JayBath" ~ -121.7667,
                         Location == "LogWallow" ~ -121.75,
                         Location == "ReflectionPond" ~ -121.7167))
  


harmonize_species = function(matrix1, matrix2) {
  # Identify all unique species across both matrices
  all_species = union(colnames(matrix1), colnames(matrix2))
  
  # For each matrix, add missing species columns and convert FALSE to 0
  harmonized1 = matrix1 %>%
    as_tibble(rownames = "site") %>%
    # Add any missing species columns with 0
    add_column(!!!setNames(
      lapply(setdiff(all_species, colnames(matrix1)), function(x) 0), 
      setdiff(all_species, colnames(matrix1))
    )) %>%
    # Convert all FALSE values to 0
    mutate(across(everything(), ~ifelse(. == FALSE, 0, .))) %>%
    # Convert back to matrix format with rownames
    column_to_rownames("site")
  
  harmonized2 = matrix2 %>%
    as_tibble(rownames = "site") %>%
    # Add any missing species columns with 0
    add_column(!!!setNames(
      lapply(setdiff(all_species, colnames(matrix2)), function(x) 0), 
      setdiff(all_species, colnames(matrix2))
    )) %>%
    # Convert all FALSE values to 0
    mutate(across(everything(), ~ifelse(. == FALSE, 0, .))) %>%
    # Convert back to matrix format with rownames
    column_to_rownames("site")
  
  return(list(matrix1 = harmonized1, matrix2 = harmonized2))
}

result = harmonize_species(paleo_cleaned, comm)
comm_paleo = result$matrix1 
comm_anth = result$matrix2

# Get rownames of your matrix 'comm'
row_names = rownames(comm_anth)

# Identify past and present rows
past_rows = grep("^past_", row_names, value = FALSE)
present_rows = grep("^present_past_", row_names, value = FALSE)

# Create separate matrices
comm_past = comm[past_rows, ]
comm_present = comm[present_rows, ]

# Clean up rownames by removing prefixes
rownames(comm_past) = gsub("^past_", "", rownames(comm_past))
rownames(comm_present) = gsub("^present_past_", "", rownames(comm_present))

# Verify the results
cat("Original matrix dimensions:", dim(comm), "\n")
cat("Past matrix dimensions:", dim(comm_past), "\n")
cat("Present matrix dimensions:", dim(comm_present), "\n")
cat("\nFirst few past rownames:", head(rownames(comm_past)), "\n")
cat("First few present rownames:", head(rownames(comm_present)), "\n")

summ = 
bind_rows(
comm_past %>%
  summarize_all(sum)%>%
  mutate(era = "past"),
comm_present %>%
  summarize_all(sum)%>%
  mutate(era = "present"),
comm_paleo %>%
  summarize_all(sum)%>%
  mutate(era = "paleo")
)%>%
  pivot_longer(cols = -era)%>%
  left_join(
    comm_paleo %>%
      summarize_all(sum) %>%
      pivot_longer(everything(), names_to = "name", values_to = "paleo_count"),
    by = "name"
  ) %>%
arrange((paleo_count), name, era)%>%
  mutate(name = factor(name, levels = unique(name)))
  
common_species = summ %>%
  filter(value>0)%>%
  group_by(name) %>%
  summarize(n_eras = n_distinct(era)) %>%
  filter(n_eras == length(unique(summ$era))) %>%
  pull(name)
print(common_species)

pdf(file = "plot/changes_sp.pdf", height = 8, width = 6)
ggplot(summ, aes(value, name, fill = era, group = interaction(era, name)))+
  geom_col(position = position_dodge(width = 0.9))+
  theme_bw()+
  scale_fill_manual(values = color_era)+
  theme(legend.position = "bottom", legend.title = element_blank())+
  xlab("Number of plots present")+
  ylab("")

dev.off()

jaccard =
  bind_rows(
  comm_past %>% 
    as.data.frame() %>%
    rownames_to_column("site") %>%
    mutate(era = "past"),
  comm_present %>% 
    as.data.frame() %>%
    rownames_to_column("site") %>%
    mutate(era = "present")
) %>%
  pivot_longer(cols = -c(site, era), names_to = "species", values_to = "presence") %>%
  pivot_wider(names_from = era, values_from = presence) %>%
  filter(!is.na(past) & !is.na(present)) %>%  # Keep only sites with both past and present data
  group_by(site) %>%
  summarise(
    intersection = sum(past == 1 & present == 1, na.rm = TRUE),
    union = sum(past == 1 | present == 1, na.rm = TRUE),
    jaccard_similarity = ifelse(union == 0, 0, intersection / union),
    jaccard_dissimilarity = 1 - jaccard_similarity,
    .groups = "drop"
  )

paleo_jaccard = comm_paleo %>%
  as.data.frame() %>%
  rownames_to_column("sample") %>%
  # Extract site and age from sample names
  mutate(
    site = str_extract(sample, "^[^_]+"),
    age = as.numeric(str_extract(sample, "\\d+$"))
  ) %>%
  group_by(site) %>%
  nest() %>%
  # Calculate Jaccard dissimilarity for each site
  mutate(
    jaccard_results = map(data, function(site_data) {
      # Find the oldest sample (maximum age)
      oldest_age <- max(site_data$age)
      oldest_sample <- site_data %>% filter(age == oldest_age)
      
      # Calculate dissimilarity from oldest to each time step
      site_data %>%
        mutate(
          jaccard_dissimilarity = map_dbl(1:nrow(site_data), function(i) {
            current_sample <- site_data[i, ]
            # Create comparison matrix (oldest vs current)
            comparison_data <- bind_rows(
              oldest_sample %>% select(-c(sample, age)),
              current_sample %>% select(-c(sample, age))
            )
            
            # Calculate Jaccard manually
            oldest_vec <- as.logical(comparison_data[1, ])
            current_vec <- as.logical(comparison_data[2, ])
            
            intersection <- sum(oldest_vec & current_vec, na.rm = TRUE)
            union <- sum(oldest_vec | current_vec, na.rm = TRUE)
            
            jaccard_similarity <- ifelse(union == 0, 0, intersection / union)
            jaccard_dissimilarity <- 1 - jaccard_similarity
            
            return(jaccard_dissimilarity)
          })
        ) %>%
        select(sample, age, jaccard_dissimilarity)
    })
  ) %>%
  select(-data) %>%
  unnest(jaccard_results) %>%
  group_by(site) %>%
  filter(age != max(age)) %>%
  ungroup() %>%
  arrange(site, age)%>%
  rename(Location = site,
         plot = sample,
         Depth = age
         )%>%
  left_join(predicted_ages)

jaccard =
  jaccard %>%
  mutate(Predicted_Age = -2017)

# Clean data: remove Depth = 0 and ensure values are in (0,1)
df_beta <- paleo_jaccard %>%
  #filter(Depth != 0) %>%
  mutate(jaccard_dissimilarity = ifelse(jaccard_dissimilarity == 0, 0.0001,
                                        ifelse(jaccard_dissimilarity == 1, 0.9999,
                                               jaccard_dissimilarity)))
aic_results <- df_beta %>%
  split(.$Location) %>%
  map_df(~ {
    ks <- 2:10
    data.frame(
      Location = unique(.x$Location),
      k = ks,
      AIC = sapply(ks, function(k) AIC(betareg(jaccard_dissimilarity ~ ns(Predicted_Age, k), data = .x)))
    )
  })%>%
  group_by(Location)%>%
  mutate(min_AIC = min(AIC))%>%
  filter(min_AIC == AIC)%>%
  select(Location, k)

# Fit beta regression per location using the optimal k
models <- pmap(aic_results, function(Location, k) {
  data_loc <- df_beta %>% filter(Location == !!Location)
  model <- betareg(jaccard_dissimilarity ~ ns(Predicted_Age, k), data = data_loc)
  list(Location = Location, model = model)
}) %>% set_names(map_chr(., "Location"))


# Generate predictions from models
df_pred <- map_dfr(models, function(m) {
  pred_range <- seq(min(df_beta$Predicted_Age), -3000, length.out = 300)
  new_data <- data.frame(Predicted_Age = pred_range)
  
  # Predict with standard errors
  preds <- predict(m$model, newdata = new_data, se.fit = TRUE)
  
  tibble(
    Location = m$Location,
    Predicted_Age = pred_range,
    fit = preds$fit,
    se = preds$se.fit,
    lower = preds$fit - 1.96 * preds$se.fit,
    upper = preds$fit + 1.96 * preds$se.fit
  )
})

pred_at_1000 <- map_dfr(models, function(m) {
  tibble(
    Location = m$Location,
    Predicted_Age = 1000,
    pred = round(predict(m$model, newdata = data.frame(Predicted_Age = 1000)), 2)
  )
})

# Extract model performance metrics
model_summary <- map_dfr(models, function(m) {
  model <- m$model
  location <- m$Location
  k <- m$k
  
  tibble(
    Location = location,
    Degrees_of_Freedom = k,
    Pseudo_R2 = round(summary(model)$pseudo.r.squared, 3),
    LogLik = round(logLik(model)[1], 2),
    AIC = round(AIC(model), 2),
    BIC = round(BIC(model), 2)
  )
})

gt(model_summary)

pdf(file = "plot/jaccard_ages.pdf", height = 6, width = 8)
ggplot(paleo_jaccard %>% filter(Depth != 0), aes(Predicted_Age, jaccard_dissimilarity)) +
  geom_vline(xintercept = 0, color = "grey40", linetype = "dashed") +
  geom_vline(xintercept = 1000, color = "grey80", linetype = "dashed") +
  geom_point(alpha = 0.2, aes(color = Location, fill = Location)) +
  geom_line(alpha = 0.2, aes(color = Location, fill = Location)) +
  geom_line(data = df_pred, aes(y = pred, color = Location), size = 1.1) +
  geom_text(data = pred_at_1000, 
            aes(x = Predicted_Age, y = pred, label = pred, color = Location), 
            vjust = -1, fontface = "bold", size = 3, show.legend = FALSE) +  
  geom_point(data = pred_at_1000, 
            aes(x = Predicted_Age, y = pred, label = pred, color = Location),
            size = 3) + 
  scale_x_reverse() +
  scale_color_manual(values = color_site) +
  scale_fill_manual(values = color_site) +
  ylim(0, 1) +
  xlim(6000, -3000) +
  theme_bw() +
  geom_violin(data = jaccard, aes(x = -2015, y = jaccard_dissimilarity), 
              color = color_era[3], fill = color_era[3], alpha = 0.3, width = 300) +
  stat_summary(data = jaccard, aes(x = -2015, y = jaccard_dissimilarity), 
               fun = mean, geom = "point", color = color_era[3], size = 3, shape = 16) +
  stat_summary(data = jaccard, aes(x = -2015, y = jaccard_dissimilarity, label = round(..y.., 2)), 
               fun = mean, geom = "text", color = color_era[3], size = 3, 
               hjust = -0.5) +
  annotate("text", x = 1000, y = 1, label = "Holocene", 
           color = color_era[1], fontface = "bold") +
  annotate("text", x = -1000, y = 1, label = "Anthropocene", 
           color = color_era[3], fontface = "bold") +
  annotate("text", x = -1000, y = 0.95, label = "Past vs. Present", 
           color = color_era[3], fontface = "bold") +
  xlab("Age") + ylab("Jaccard dissimilarity between communities") +
  theme(legend.position = "bottom", legend.title = element_blank())

dev.off()
