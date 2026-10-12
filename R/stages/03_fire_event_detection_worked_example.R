# =============================================================================
# 03_fire_event_detection_worked_example.R
# Auditable, step-by-step display of accepted charcoal-event detection.
# This stage explains individual-event selection; it does not classify the
# later centered 1,000-year high-fire periods.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(patchwork)
})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

series_path = here("output/holocene_fire_source_series.csv")
events_path = here("output/holocene_fire_source_events.csv")
settings_path = here("output/holocene_fire_source_settings.csv")
if (!all(file.exists(c(series_path, events_path, settings_path)))) {
  stop("Run R/stages/02_walsh_fire_reproduction.R first.")
}

series = read_csv(series_path, show_col_types = FALSE)
events = read_csv(events_path, show_col_types = FALSE)
settings = read_csv(settings_path, show_col_types = FALSE)

required_series = c(
  "site", "lake", "age_cal_yr_BP", "char_interpolated",
  "background_char", "peak_component", "positive_threshold",
  "minimum_count_p", "candidate_before_count_screen",
  "rejected_by_count_screen", "is_significant")
if (!all(required_series %in% names(series))) {
  stop("The source-series audit lacks event-detection columns; rerun stage 02.")
}

lake_order = c("Sunrise Lake", "Shadow Lake", "Little Sunrise Lake",
               "PantherPotholes")
lake_labels = c(PantherPotholes = "Panther Potholes")
lake_colors = c(
  `Sunrise Lake` = "#4477AA",
  `Shadow Lake` = "#228833",
  `Little Sunrise Lake` = "#AA3377",
  PantherPotholes = "#CC6677")

if (nrow(settings) != 4L || any(settings$engine != "tapas"))
  stop("The worked example requires the harmonized four-core tapas settings.")

lake_counts = series |>
  group_by(site, lake) |>
  summarise(
    interpolated_grid_rows = n(),
    candidate_events = sum(candidate_before_count_screen, na.rm = TRUE),
    rejected_by_count_screen = sum(rejected_by_count_screen, na.rm = TRUE),
    accepted_events = sum(is_significant, na.rm = TRUE),
    younger_cal_bp = min(age_cal_yr_BP),
    older_cal_bp = max(age_cal_yr_BP), .groups = "drop")

published = tribble(
  ~lake, ~published_episode_total,
  "Sunrise Lake", 24L,
  "Shadow Lake", 18L,
  "Little Sunrise Lake", 16L,
  "PantherPotholes", NA_integer_)

audit = settings |>
  left_join(lake_counts, by = c("site", "lake")) |>
  left_join(published, by = "lake") |>
  mutate(
    local_noise_method = "Gaussian-mixture noise distribution",
    background_method = "robust LOWESS",
    consecutive_rule = "collapse adjacent exceedances",
    count_screen_detail = "pass/fail retained; individual p not returned by tapas",
    analytical_interpretation = if_else(site == "MORA",
      "regional MORA core evidence", "local Panther Potholes evidence")) |>
  arrange(match(lake, lake_order))

write_csv(audit, here("output/fire_event_detection_lake_audit.csv"))

theme_method = theme_bw(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(color = "grey30", size = 10.5),
        legend.position = "top")

# Page 1: common algorithm and all source-specific choices.
steps = tibble(
  x = 1:6,
  label = c("1\nInterpolate\nCHAR", "2\nEstimate robust\nLOWESS background",
            "3\nCalculate\npositive residual",
            "4\nExceed local\nnoise threshold",
            "5\nPass 75-year\ncount screen",
            "6\nAccepted\nfire event"))
p_flow = ggplot(steps, aes(x, 1, label = label)) +
  geom_segment(data = tibble(x = 1:5),
    aes(x = x + .32, xend = x + .68, y = 1, yend = 1),
    arrow = arrow(length = unit(.12, "inches")), linewidth = .55,
    inherit.aes = FALSE) +
  geom_label(fill = "grey96", color = "grey15", linewidth = .4,
             size = 4.1, lineheight = .95) +
  coord_cartesian(xlim = c(.6, 6.4), ylim = c(.65, 1.35), clip = "off") +
  labs(title = "How an individual charcoal peak becomes an accepted fire event",
       subtitle = paste("The detection settings differ among cores; the later",
                        "1,000-year high-fire classification is a separate step.")) +
  theme_void(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 17, hjust = .5),
        plot.subtitle = element_text(size = 11, hjust = .5, color = "grey30"))

table_data = audit |>
  transmute(
    lake = recode(lake, !!!lake_labels),
    Engine = str_wrap(engine, 16),
    Chronology = str_wrap(chronology, 18),
    `Interpolation\n(years)` = as.character(interpolation_years),
    `Background\n(years)` = as.character(smoothing_years),
    `Noise\npercentile` = scales::percent(threshold_probability, accuracy = 1),
    `Candidates` = as.character(candidate_events),
    `Count-screen\nrejected` = as.character(rejected_by_count_screen),
    `Accepted` = as.character(accepted_events)) |>
  mutate(lake = factor(lake,
    levels = recode(lake_order, !!!lake_labels))) |>
  pivot_longer(-lake, names_to = "field", values_to = "value") |>
  mutate(field = factor(field, levels = unique(field)))

p_table = ggplot(table_data, aes(field, lake)) +
  geom_tile(aes(fill = lake), alpha = .10, color = "white", linewidth = 1) +
  geom_text(aes(label = value), size = 3.35, lineheight = .9) +
  scale_fill_manual(values = setNames(unname(lake_colors),
    recode(names(lake_colors), !!!lake_labels))) +
  scale_x_discrete(position = "top") +
  scale_y_discrete(limits = rev) +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank(), legend.position = "none",
        axis.text.x = element_text(face = "bold", color = "grey15", size = 10),
        axis.text.y = element_text(face = "bold", color = "grey15", size = 10.5),
        plot.margin = margin(10, 10, 10, 10))

p_note = ggplot() +
  annotate("label", x = .5, y = .62, size = 4.0, lineheight = 1.05,
    linewidth = .35, fill = "grey97", color = "grey20",
    label = paste0(
      "Accepted event = one distinct positive residual excursion above the local noise threshold that survives the count screen.\n",
      "All four primary catalogs use tapas; each record retains its publication-specific temporal and threshold settings.\n",
      "Accepted events are inferred charcoal episodes, not exact known ignition dates and not yet high-fire periods.")) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  theme_void()

overview = p_flow / p_table / p_note +
  plot_layout(heights = c(.9, 1.25, .55))

make_lake_panel = function(lake_name) {
  dd = series |> filter(lake == lake_name) |> arrange(age_cal_yr_BP)
  ss = audit |> filter(lake == lake_name)
  display_lake = recode(lake_name, !!!lake_labels)
  col = lake_colors[[lake_name]]

  accepted = dd |> filter(is_significant)
  rejected = dd |> filter(rejected_by_count_screen)
  p2 = ggplot(dd, aes(age_cal_yr_BP, peak_component)) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = .4) +
    geom_line(color = col, linewidth = .55) +
    geom_line(aes(y = positive_threshold), color = "grey15",
              linetype = "dashed", linewidth = .65) +
    geom_point(data = accepted, shape = 21, fill = col, color = "black",
               size = 2.0, stroke = .35) +
    geom_point(data = rejected, shape = 4, color = "#B2182B",
               size = 2.8, stroke = 1.0) +
    scale_x_reverse() +
    labs(title = paste0(display_lake, ": local ",
      scales::percent(ss$threshold_probability, accuracy = 1),
      " noise threshold"),
      x = "cal BP", y = "Peak CHAR residual") +
    theme_method + theme(legend.position = "none")

  settings_text = sprintf(
    "Interpolation %g yr | background %g yr\n%d accepted events | %d rejected peaks",
    ss$interpolation_years, ss$smoothing_years,
    ss$accepted_events, ss$rejected_by_count_screen)
  p2 + labs(subtitle = settings_text)
}

lake_panels = purrr::map(lake_order, make_lake_panel)
lake_page = wrap_plots(lake_panels, ncol = 2) +
  plot_annotation(
    title = "Fire-event detection across the four lake records",
    subtitle = "Dashed = threshold; filled circle = accepted; red X = rejected by count screen",
    theme = theme(plot.title = element_text(face = "bold", size = 18),
                  plot.subtitle = element_text(size = 11, color = "grey25")))
comparison_path = here("output/walsh_charanalysis_software_comparison.csv")
if (!file.exists(comparison_path)) stop("Missing Walsh software audit.")
comparison = read_csv(comparison_path, show_col_types = FALSE) |>
  select(lake, published_total_episodes, official_r_episodes, tapas_episodes) |>
  pivot_longer(-lake, names_to = "catalog", values_to = "accepted_events") |>
  mutate(catalog = recode(catalog,
    published_total_episodes = "Walsh reported",
    official_r_episodes = "CharAnalysis R 2.0.3 audit",
    tapas_episodes = "PaleoACES tapas primary"))
p_audit = ggplot(comparison,
    aes(lake, accepted_events, fill = catalog)) +
  geom_col(position = position_dodge(.82), width = .75) +
  geom_text(aes(label = accepted_events),
    position = position_dodge(.82), vjust = -.25, size = 4) +
  scale_fill_manual(values = c("Walsh reported" = "grey65",
    "CharAnalysis R 2.0.3 audit" = "#4477AA",
    "PaleoACES tapas primary" = "#AA3377")) +
  labs(title = "Walsh publication totals, official audit, and harmonized primary catalog",
    x = NULL, y = "Accepted events", fill = NULL) +
  theme_method + theme(axis.text.x = element_text(angle = 15, hjust = 1))
p_audit_note = ggplot() +
  annotate("label", x = .5, y = .5, size = 4.2, lineheight = 1.08,
    label = paste(
      "The magenta tapas catalog is authoritative downstream.",
      "The official CharAnalysis run remains a reproducibility audit;",
      "neither implementation is tuned to force the published totals."),
    fill = "grey97", color = "grey20") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) + theme_void()
audit_page = p_audit / p_audit_note + plot_layout(heights = c(3, 1))
pages = list(overview, lake_page, audit_page)

pdf_path = here("plot/test_figures/worked_examples/fig_fire_event_detection_workflow.pdf")
if (render_figures) {
  grDevices::pdf(pdf_path, width = 14, height = 9, onefile = TRUE)
  purrr::walk(pages, print)
  grDevices::dev.off()
  cat("Written three-page fire-event workflow with all four lake records on one page.\n")
}
