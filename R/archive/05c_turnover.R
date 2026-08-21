# Turnover: forest community change vs climate change per time step -----------------
# Reuses the pooled CCA built in 05_cca_paleo.R.
#   Forest community turnover = displacement of the OBSERVED (species/WA) CCA position.
#   Climate turnover    = displacement of the PREDICTED (climate/LC) CCA position.
# Both live in the same pooled-CCA space, so they are directly comparable.
#   Anthropocene: past -> present, matched by plot (resurvey).
#   Paleo:        consecutive samples within each lake (t vs t+1).
# (Distances use CCA1-CCA2; see note on 3D at the bottom of this file.)
source(here("R/05_cca_model.R"))

# --- Anthropocene: past (training) vs present, matched by plot ---------------
tp        = rownames(species_past_final)
past_obs  = predict(cca_model, newdata = species_past_final, type = "wa")
past_pred = predict(cca_model, newdata = env_past_final,     type = "lc")
past_tab  = tibble(plot_id = tp,
                   obs1 = past_obs[, 1],  obs2 = past_obs[, 2],
                   pred1 = past_pred[, 1], pred2 = past_pred[, 2])
present_tab = tibble(plot_id = rownames(projected_present),
                     obs1 = projected_present[, 1], obs2 = projected_present[, 2],
                     pred1 = predicted_present[, 1], pred2 = predicted_present[, 2])
site_lookup = env %>% filter(period == "past") %>% distinct(plot_id, site)

anthro_turn = inner_join(past_tab, present_tab, by = "plot_id", suffix = c("_a", "_b")) %>%
  left_join(site_lookup, by = "plot_id") %>%
  transmute(site, era = "anthropocene",
            veg_turnover  = sqrt((obs1_b - obs1_a)^2  + (obs2_b - obs2_a)^2),
            clim_turnover = sqrt((pred1_b - pred1_a)^2 + (pred2_b - pred2_a)^2)) %>%
  filter(!is.nan(veg_turnover), !is.nan(clim_turnover))

# --- Paleo: consecutive samples within each lake ----------------------------
paleo_turn = comparison_df %>%
  filter(era == "holocene", !is.nan(projected_CCA1)) %>%
  mutate(lake = str_match(plot_id, "^(.*)_-?\\d+_BP$")[, 2],
         year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[, 2])) %>%
  arrange(site, lake, year) %>%
  group_by(site, lake) %>%
  mutate(veg_turnover  = sqrt((projected_CCA1 - lag(projected_CCA1))^2 +
                              (projected_CCA2 - lag(projected_CCA2))^2),
         clim_turnover = sqrt((predicted_CCA1 - lag(predicted_CCA1))^2 +
                              (predicted_CCA2 - lag(predicted_CCA2))^2)) %>%
  ungroup() %>%
  filter(!is.na(veg_turnover)) %>%
  transmute(site, era = "holocene", veg_turnover, clim_turnover)

turnover = bind_rows(anthro_turn, paleo_turn)

# --- Figure: forest community vs climate turnover ---------------------------------
tmax = max(c(turnover$veg_turnover, turnover$clim_turnover), na.rm = TRUE)

p_turn = ggplot(turnover, aes(x = clim_turnover, y = veg_turnover, color = site)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(aes(shape = era), alpha = 0.4, size = 1.3) +
  geom_smooth(aes(linetype = era), method = "lm", se = FALSE) +
  scale_color_manual(values = color_mt) +
  coord_equal(xlim = c(0, tmax), ylim = c(0, tmax)) +
  labs(x = "Climate turnover (predicted CCA displacement)",
       y = "Forest community turnover (observed CCA displacement)",
       color = "Site", shape = "Era", linetype = "Era",
       title = "Forest community vs climate turnover per step",
       subtitle = "Dashed = 1:1 (perfect tracking); below the line = forest community under-tracked climate") +
  theme_minimal()
print(p_turn)

pdf(file = here(paste0("plot/turnover_veg_vs_climate", cca_suffix, ".pdf")), height = 7, width = 8)
print(p_turn)
dev.off()

# Summary
turnover %>% group_by(site, era) %>%
  summarize(n = n(),
            med_veg = round(median(veg_turnover), 2),
            med_clim = round(median(clim_turnover), 2),
            med_ratio = round(median(veg_turnover / clim_turnover), 2), .groups = "drop") %>%
  print()

# NOTE on 3D: comparison_df already carries CCA3 (predicted_CCA3 / projected_CCA3)
# and predict()/cca scores give a 3rd axis, so every distance above can include
# (... + (.._CCA3 diff)^2) to become 3D. Kept 2D here for consistency with the
# other figures.
