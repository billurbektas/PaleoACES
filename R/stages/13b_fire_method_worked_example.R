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
