# LEGACY ONLY - not part of R/00_workflow.R. This diagnostic reads retired
# climate_timeseries and organized summary products that the active pipeline no
# longer creates. It is retained as a historical design reference.
# Holocene + Anthropocene climate trends, MORA & NOCA, ----------------------
# restricted to the FOUR variables used in the CCA (05_cca_paleo.R):
#   MWT = winter temperature, MST = summer temperature,
#   WP  = winter precipitation, SpP = spring precipitation.
#
# Holocene comes from the per-plot CHELSA-TraCE21k series (climate_timeseries.csv,
# -6000 -> 0 cal yr BP). Anthropocene comes from the full organized summaries
# (1981-2020, continuous - climate_timeseries drops 1987-2009). Both are already
# in the analysis units (temperature in C, precipitation in mm).
library(here)
library(tidyverse)

color_mt = c("MORA" = "#648FFF", "NOCA" = "#FE6100")
cca_vars = c("MWT", "MST", "WP", "SpP")

# --- Holocene: per-plot series, keep only the 4 CCA variables ----------------
holo = read_csv(here("output/climate_timeseries.csv"), show_col_types = FALSE) %>%
  filter(era == "holocene", variable %in% cca_vars) %>%
  select(site, plot_id, year, variable, value)

# --- Anthropocene: full 1981-2020 record from the organized summaries --------
anthro_t = read_csv(here("output/tasmin_summary_organized.csv"), show_col_types = FALSE) %>%
  transmute(site, plot_id, year, MWT = winter_mean, MST = mean_summer)
anthro_p = read_csv(here("output/precip_summary_organized.csv"), show_col_types = FALSE) %>%
  transmute(site, plot_id, year, WP = sum_winter, SpP = sum_spring)

anthro = full_join(anthro_t, anthro_p, by = c("site", "plot_id", "year")) %>%
  pivot_longer(all_of(cca_vars), names_to = "variable", values_to = "value")

# --- Combine, aggregate to site x era x variable x year (mean +/- sd) --------
trends = bind_rows(holo   %>% mutate(era = "holocene"),
                   anthro %>% mutate(era = "anthropocene")) %>%
  filter(!is.na(value)) %>%
  group_by(site, era, variable, year) %>%
  summarize(mean = mean(value), sd = sd(value), .groups = "drop") %>%
  mutate(
    variable = factor(variable, levels = cca_vars,
                      labels = c("Winter temperature (°C)", "Summer temperature (°C)",
                                 "Winter precipitation (mm)",   "Spring precipitation (mm)")),
    era = factor(era, levels = c("holocene", "anthropocene"),
                 labels = c("Holocene (cal yr BP)", "Anthropocene (CE)"))
  )

# --- Linear-trend summary (slopes), MORA/NOCA x Holocene/Anthropocene --------
# Slope of the across-plot mean vs year. Reported per millennium (Holocene) and
# per decade (Anthropocene) so the two eras are interpretable, plus the total
# fitted change over the observed span.
slopes = trends %>%
  mutate(era_key = ifelse(grepl("Holocene", era), "holocene", "anthropocene")) %>%
  group_by(site, era, era_key, variable) %>%
  group_modify(~ {
    m <- lm(mean ~ year, data = .x)
    tibble(slope_per_yr = coef(m)[["year"]],
           total_change = coef(m)[["year"]] * (max(.x$year) - min(.x$year)),
           p_value      = summary(m)$coefficients["year", "Pr(>|t|)"])
  }) %>%
  ungroup() %>%
  mutate(rate = ifelse(era_key == "holocene", slope_per_yr * 1000, slope_per_yr * 10),
         rate_unit = ifelse(era_key == "holocene", "per 1000 yr", "per decade"))

# --- Directional annotations (cooler / warmer / wetter / drier / ~ stable) ---
# A direction word is shown ONLY when the trend is statistically significant
# (p < 0.05) AND clears a magnitude floor (0.3 C for temperature, 40 mm for
# precipitation); otherwise "~ stable". This avoids labelling non-significant
# slopes (e.g. Anthropocene winter temperature) or significant-but-trivial ones
# (e.g. Holocene NOCA winter precip, +13 mm over 6 kyr) as a real trend.
temp_floor = 0.3; precip_floor = 40; alpha = 0.05
labels = slopes %>%
  mutate(
    is_temp = grepl("temperature", variable),
    floor   = ifelse(is_temp, temp_floor, precip_floor),
    word = case_when(
      p_value >= alpha | abs(total_change) < floor ~ "~ stable",
      is_temp  & total_change > 0 ~ "warmer",
      is_temp  & total_change < 0 ~ "cooler",
      !is_temp & total_change > 0 ~ "wetter",
      !is_temp & total_change < 0 ~ "drier"
    )
  )

# Position: left edge (x shared per era column), stacked near the top of each
# variable row (y shared across the two eras in a row). Extra y headroom is
# created because these label points widen the row's shared y-scale.
row_rng = trends %>% group_by(variable) %>%
  summarize(ymax = max(mean + sd), ymin = min(mean - sd), .groups = "drop") %>%
  mutate(rng = ymax - ymin)
col_rng = trends %>% group_by(era) %>%
  summarize(xmin = min(year), xmax = max(year), .groups = "drop")

labels = labels %>%
  left_join(row_rng, by = "variable") %>%
  left_join(col_rng, by = "era") %>%
  mutate(x = xmin + 0.02 * (xmax - xmin),
         y = ymax + ifelse(site == "MORA", 0.17, 0.06) * rng)

# --- Figure ------------------------------------------------------------------
# facet_grid(variable ~ era, scales = "free"): x is shared down each era column
# (Holocene -6000..0 | Anthropocene 1981..2020) and y is shared across both eras
# within each variable row, so modern values are on the same scale as Holocene.
p = ggplot(trends, aes(year, mean, color = site, fill = site)) +
  geom_ribbon(aes(ymin = mean - sd, ymax = mean + sd),
              alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.6, alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1, linetype = "dashed") +
  geom_text(data = labels, aes(x = x, y = y, label = word, color = site),
            hjust = 0, fontface = "bold", size = 4.2, show.legend = FALSE,
            inherit.aes = FALSE) +
  facet_grid(variable ~ era, scales = "free", switch = "y") +
  scale_color_manual(values = color_mt) +
  scale_fill_manual(values = color_mt) +
  labs(x = "Year", y = NULL, color = "Site", fill = "Site",
       title = "Holocene and Anthropocene climate trends (CCA variables)",
       subtitle = "Solid = across-plot mean; band = ±1 SD; dashed = linear trend; bold word = trend direction per site.") +
  theme_bw(base_size = 12) +
  theme(strip.background = element_blank(),
        strip.placement = "outside",
        strip.text.y.left = element_text(face = "bold", angle = 90),
        strip.text.x = element_text(face = "bold"),
        legend.position = "bottom",
        panel.grid.minor = element_blank())

ggsave(here("plot/test_figures/climate_trends_cca_vars.pdf"), p,
       width = 11, height = 9)

cat("Wrote plot/test_figures/climate_trends_cca_vars.pdf\n")

slopes_wide = slopes %>%
  transmute(variable, site, era_key,
            rate = round(rate, 3), rate_unit,
            total_change = round(total_change, 1),
            p_value = round(p_value, 4),
            significant = p_value < 0.05) %>%
  arrange(variable, site, factor(era_key, levels = c("holocene", "anthropocene")))

write_csv(slopes_wide, here("output/climate_trends_cca_vars_slopes.csv"))
cat("\nLinear trends (slope of across-plot mean):\n")
print(slopes_wide, n = Inf)
