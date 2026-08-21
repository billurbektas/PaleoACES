common_species = as.character(common_species)
env_scale = 
  env %>% 
  mutate(across(PAS:CMI, ~as.numeric(scale(.))))

X_past = env_scale %>% filter(era == "past")%>% select(-era) %>% column_to_rownames("site")
Y_past = comm_past %>%
  rownames_to_column("sample") %>%
  mutate(sample = str_remove(sample, "past_")) %>%
  column_to_rownames("sample")
Y_past = as.matrix(Y_past[,])


model = sjSDM(Y = Y_past, 
              env = linear(data = X_past, 
                           formula = ~ MAT + CMI + PAS + I(MAT^2) + I(CMI^2) + I(PAS^2)),
              biotic = bioticStruct(diag = TRUE),
              #family=binomial("probit"),
              se = TRUE,
              verbose = FALSE)
Rsquared(model) #0.2662897
plot(model)
an = anova(model, verbose = FALSE)
mcfadden_r2 = an$species$R2_McFadden$Full

# GET response curves -----
# Get species names
species_names = colnames(Y)

# Create prediction data for each environmental variable
pred_data = list()
env_vars = c("MAT", "CMI", "PAS")

for(var in env_vars) {
  # Create sequence across variable range
  var_seq = seq(min(X[[var]]), max(X[[var]]), length.out = 100)
  
  # Hold other variables at their means
  pred_df = X[1:100, ]  # Template dataframe
  pred_df[[var]] = var_seq
  
  for(other_var in setdiff(env_vars, var)) {
    pred_df[[other_var]] = mean(X[[other_var]])
  }
  
  pred_data[[var]] = pred_df
}

# Response curves per species
response_curves = map(pred_data, ~predict(model, newdata = .))

# Convert to long format for plotting
curve_data = map2_dfr(response_curves, names(response_curves), function(preds, var_name) {
  pred_df = pred_data[[var_name]]
  
  as_tibble(preds) %>%
    set_names(species_names) %>%
    mutate(env_value = pred_df[[var_name]]) %>%
    pivot_longer(cols = all_of(species_names), 
                 names_to = "species", 
                 values_to = "response") %>%
    mutate(variable = var_name)
})




# Plot response curves
ggplot(curve_data, aes(x = env_value, y = response, color = species)) +
  geom_line(size = 1) +
  facet_grid(variable~., scales = "free") +
  labs(x = "Environmental variable (scaled)", 
       y = "Predicted probability") +
  theme_minimal() +
  theme(strip.text = element_text(size = 8))

# Evaluate the niches ----
X_present = env_scale %>% filter(era == "present") %>% select(-era) %>% column_to_rownames("site")
mess_values <- calculate_mess(as.matrix(X_present), as.matrix(X_past))
names(mess_values)<-rownames(X_present)
outside_range_values = names(mess_values[mess_values<0])
paleo_matches %in% outside_range_values


# GET predictions for observed vs predicted plots ----
X_present = env_scale %>% filter(era == "present") %>% select(-era) %>% column_to_rownames("site")
Y_present = comm_present %>%
  rownames_to_column("sample") %>%
  mutate(sample = str_remove(sample, "present_")) %>%
  column_to_rownames("sample")
Y_present = as.matrix(Y_present[,as.character(common_species)])

# Paleo
closest_matches=left_join(closest_matches %>% st_drop_geometry() %>% rename(Location = matched_to), predicted_ages)

# Holocene_1000
plot_holocene_1000 = predicted_ages %>%
  filter(Predicted_Age<1400 & Predicted_Age>600)%>%
  pull(plot)

Y_holocene_1000=
  as.matrix(comm_paleo[plot_holocene_1000,common_species])

X_holocene_1000 = env_scale %>% 
  filter(era == "holocene_1000") %>% 
  filter(site %in% paleo_matches)%>%
  left_join(closest_matches %>% select(id, plot) %>% rename(site = id))%>%
  filter(plot %in% plot_holocene_1000)%>%
  select(-site, -era)%>%
  column_to_rownames("plot")
X_holocene_1000 = X_holocene_1000[plot_holocene_1000, ]
  
plot_holocene_6000 = 
  predicted_ages %>%
  filter(Predicted_Age<6400 & Predicted_Age>5600)%>%
  pull(plot)

Y_holocene_6000=
  as.matrix(comm_paleo[plot_holocene_6000, common_species])

X_holocene_6000 = env_scale %>% 
  filter(era == "holocene_6000") %>% 
  filter(site %in% paleo_matches)%>%
  left_join(closest_matches %>% select(id, plot) %>% rename(site = id))%>%
  filter(plot %in% plot_holocene_6000)%>%
  select(-site, -era)%>%
  column_to_rownames("plot")
X_holocene_6000 = X_holocene_6000[plot_holocene_6000, ]

# Marginal predictions (no biotic information)
pred_present_marginal = predict(model, newdata = X_present)
pred_past_marginal = predict(model, newdata = X_past)
pred_holocene_1000_marginal = predict(model, newdata = X_holocene_1000)
pred_holocene_6000_marginal = predict(model, newdata = X_holocene_6000)

# Conditional predictions for each species
pred_present_conditional = matrix(NA, nrow = nrow(Y_present), ncol = ncol(Y_present))
pred_past_conditional = matrix(NA, nrow = nrow(Y_past), ncol = ncol(Y_past))
pred_holocene_1000_conditional = matrix(NA, nrow = nrow(Y_holocene_1000), ncol = ncol(Y_holocene_1000))
pred_holocene_6000_conditional = matrix(NA, nrow = nrow(Y_holocene_6000), ncol = ncol(Y_holocene_6000))
colnames(pred_present_conditional) = colnames(pred_past_conditional) = species_names
colnames(pred_holocene_1000_conditional) = colnames(pred_holocene_6000_conditional) = species_names

for(sp in species_names) {
  sp_index = which(species_names == sp)
  
  # Present conditional predictions
  conditional_Y_present = Y_present
  conditional_Y_present[, sp_index] = NA
  pred_present_conditional[, sp_index] = predict(model, newdata = X_present, Y = conditional_Y_present)
  
  # Past conditional predictions
  conditional_Y_past = Y_past
  conditional_Y_past[, sp_index] = NA
  pred_past_conditional[, sp_index] = predict(model, newdata = X_past, Y = conditional_Y_past)
  
  # Holocene 1000 conditional predictions
  conditional_Y_holocene_1000 = Y_holocene_1000
  conditional_Y_holocene_1000[, sp_index] = NA
  pred_holocene_1000_conditional[, sp_index] = predict(model, newdata = X_holocene_1000, Y = conditional_Y_holocene_1000)
  
  # Holocene 6000 conditional predictions
  conditional_Y_holocene_6000 = Y_holocene_6000
  conditional_Y_holocene_6000[, sp_index] = NA
  pred_holocene_6000_conditional[, sp_index] = predict(model, newdata = X_holocene_6000, Y = conditional_Y_holocene_6000)
}

# Create comparison data for plotting
comparison_data = tibble()

for(i in 1:ncol(Y_past)) {
  species_name = colnames(Y_past)[i]
  r2_value = mcfadden_r2[i]
  
  # Past data - marginal
  past_data_marginal = tibble(
    observed = Y_past[,i],
    predicted = pred_past_marginal[,i],
    species = species_name,
    period = "past",
    prediction_type = "Marginal",
    r2 = r2_value
  )
  
  # Past data - conditional
  past_data_conditional = tibble(
    observed = Y_past[,i],
    predicted = pred_past_conditional[,i],
    species = species_name,
    period = "past",
    prediction_type = "Conditional",
    r2 = r2_value
  )
  
  # Present data - marginal
  present_data_marginal = tibble(
    observed = Y_present[,i],
    predicted = pred_present_marginal[,i],
    species = species_name,
    period = "present",
    prediction_type = "Marginal",
    r2 = r2_value
  )
  
  # Present data - conditional
  present_data_conditional = tibble(
    observed = Y_present[,i],
    predicted = pred_present_conditional[,i],
    species = species_name,
    period = "present",
    prediction_type = "Conditional",
    r2 = r2_value
  )
  
  # Holocene 1000 data - marginal
  holocene_1000_data_marginal = tibble(
    observed = Y_holocene_1000[,i],
    predicted = pred_holocene_1000_marginal[,i],
    species = species_name,
    period = "holocene_1000",
    prediction_type = "Marginal",
    r2 = r2_value
  )
  
  # Holocene 1000 data - conditional
  holocene_1000_data_conditional = tibble(
    observed = Y_holocene_1000[,i],
    predicted = pred_holocene_1000_conditional[,i],
    species = species_name,
    period = "holocene_1000",
    prediction_type = "Conditional",
    r2 = r2_value
  )
  
  # Holocene 6000 data - marginal
  holocene_6000_data_marginal = tibble(
    observed = Y_holocene_6000[,i],
    predicted = pred_holocene_6000_marginal[,i],
    species = species_name,
    period = "holocene_6000",
    prediction_type = "Marginal",
    r2 = r2_value
  )
  
  # Holocene 6000 data - conditional
  holocene_6000_data_conditional = tibble(
    observed = Y_holocene_6000[,i],
    predicted = pred_holocene_6000_conditional[,i],
    species = species_name,
    period = "holocene_6000",
    prediction_type = "Conditional",
    r2 = r2_value
  )
  
  comparison_data = bind_rows(comparison_data, past_data_marginal, past_data_conditional,
                              present_data_marginal, present_data_conditional,
                              holocene_1000_data_marginal, holocene_1000_data_conditional,
                              holocene_6000_data_marginal, holocene_6000_data_conditional)
}

# Create the plot per species
ggplot(comparison_data, aes(x = observed, y = predicted, color = period)) +
  geom_jitter(alpha = 0.6, width = 0.1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "black") +
  stat_smooth(aes(linetype = prediction_type), method = "lm", se = FALSE, size = 1, fullrange = TRUE) +
  facet_wrap(~paste0(species, "\nR² = ", round(r2, 3)), scales = "free") +
  labs(x = "Observed", 
       y = "Predicted",
       color = "Period",
       linetype = "Prediction type") +
  theme_minimal() +
  xlim(0,1)+ylim(0,1)+
  theme(strip.text = element_text(size = 8)) +
  scale_color_manual(values = c("past" = "blue", "present" = "orange", 
                                "holocene_1000" = "green", "holocene_6000" = "purple")) +
  scale_linetype_manual(values = c("Marginal" = "dashed", "Conditional" = "solid"))

rmse_results = comparison_data %>%
  group_by(species, period, prediction_type) %>%
  summarise(
    rmse = sqrt(mean((observed - predicted)^2)),
    n = n(),
    .groups = "drop"
  )%>%
  mutate(period = factor(period, levels = c("holocene_6000","holocene_1000", "past", "present"
                        )))%>%
  mutate(prediction_type = factor(prediction_type, levels = c("Marginal", "Conditional")))

ggplot(rmse_results, aes(period, rmse))+
  geom_violin()+
  stat_summary(fun = "mean", shape = 22)+
  geom_jitter(aes(color = species, fill = as.factor(n)), 
              width = 0.3,
              size = 3, shape = 21, stroke = 1)+
  facet_grid(.~prediction_type)+
  theme_bw()+
  scale_fill_manual(values = c("grey50", "grey30", "black"))+
  labs(fill = "Number of sites", x = "")
