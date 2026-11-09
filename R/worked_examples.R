# Worked examples: step-by-step illustrations of four methods, drawn from the
# finished pipeline outputs. Nothing here feeds the analysis. Run after the
# pipeline (R/run_all.R does this last).
#   1. Accepted charcoal-event detection (Fig. S7)
#   2. Climate eras: phases, thresholds and era construction
#   3. High-fire periods from centered event frequencies
#   4. Tracking geometry: movement, lag, ratio and angle

# =============================================================================
# 1. Accepted charcoal-event detection
# =============================================================================
local({
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(patchwork)
})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

series_path = out("holocene_fire_source_series.csv")
events_path = out("holocene_fire_source_events.csv")
settings_path = out("holocene_fire_source_settings.csv")
if (!all(file.exists(c(series_path, events_path, settings_path)))) {
  stop("Run R/pipeline/08_fire_records.R first.")
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

write_csv(audit, out("worked_examples/fire_event_detection_lake_audit.csv"))

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
comparison_path = out("walsh_charanalysis_software_comparison.csv")
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

pdf_path = fig("worked_examples", "fig_fire_event_detection_workflow.pdf")
if (render_figures) {
  grDevices::pdf(pdf_path, width = 14, height = 9, onefile = TRUE)
  purrr::walk(pages, print)
  grDevices::dev.off()
  cat("Written three-page fire-event workflow with all four lake records on one page.\n")
}
})

# =============================================================================
# 2. Climate eras: from signed changes to numbered eras
# =============================================================================
local({
source(here::here('R/helpers/config.R'), local = TRUE)
# Rebuild the era classification in memory; its tables are rewritten unchanged.
sys.source(here::here('R/pipeline/11_climate_eras_high_fire.R'), envir = environment())

# =============================================================================
# SINGLE-PAGE INTEGRATED FIGURE
# =============================================================================
site_cols = PAPER_SITE_COLORS
variable_cols = c(MSpT = "#D73027", MWT = "#4575B4",
                  SP = "#E6AB02", WP = "#1B9E77")
direction_cols = c(increasing = "#C84335", decreasing = "#2675B8",
                   `not qualifying` = "grey88")
era_cols = c(`climate change` = "#B85C38", `relative stability` = "#D9E2E8")
fire_cols = site_cols
time_scale = function() scale_x_reverse(limits = c(11000, -100),
  breaks = c(10000, 8000, 6000, 4000, 2000, 0),
  labels = scales::label_number(big.mark = ","))
shade_incomplete = function() list(
  annotate("rect", xmin = 9600, xmax = 11000, ymin = -Inf, ymax = Inf,
    fill = "grey80", alpha = .22),
  annotate("rect", xmin = -100, xmax = 1300, ymin = -Inf, ymax = Inf,
    fill = "grey80", alpha = .22))

threshold_lines = climate$thresholds |>
  select(variable, threshold_standardized_change) |>
  crossing(sign = c(-1, 1)) |>
  mutate(y = sign * threshold_standardized_change)
p1 = ggplot(climate$variable_cells,
  aes(t, regional_score, color = variable)) +
  shade_incomplete() + geom_hline(yintercept = 0, color = "grey65") +
  geom_hline(data = threshold_lines, aes(yintercept = y),
    inherit.aes = FALSE, linetype = 2, color = "grey35") +
  geom_line(linewidth = .7) +
  geom_point(data = filter(climate$variable_cells, qualifies), size = 1.5) +
  facet_wrap(~variable, nrow = 1) + time_scale() +
  scale_color_manual(values = variable_cols) + theme_bw(base_size = 9) +
  theme(legend.position = "none", panel.grid.minor = element_blank()) +
  labs(title = "A. Signed 1,000-year climate change",
    subtitle = "Regional median in pooled legacy-calibration SD units; dashed = 50% of each variable's maximum",
    x = NULL, y = "Signed standardized change")

bands = climate$variable_cells |>
  mutate(display = if_else(qualifies, direction, "not qualifying"))
p2 = ggplot(bands, aes(t, variable, fill = display)) +
  shade_incomplete() + geom_tile(width = 100, height = .82) + time_scale() +
  scale_fill_manual(values = direction_cols) + theme_bw(base_size = 9) +
  theme(panel.grid = element_blank(), legend.position = "bottom") +
  labs(title = "B. Variable-specific directional cells",
    subtitle = "Direction comes from the regional score; no MORA-NOCA agreement veto",
    x = NULL, y = NULL, fill = NULL)

era_plot = climate$era_grid |>
  mutate(y = "Unified era")
p3 = ggplot(era_plot, aes(t, y, fill = era_class)) +
  shade_incomplete() + geom_tile(width = 100, height = .8) +
  geom_text(data = era_catalog, aes(x = (older_cal_bp + younger_cal_bp) / 2,
    y = "Unified era", label = era_id), inherit.aes = FALSE, size = 3) +
  time_scale() + scale_fill_manual(values = era_cols) + theme_bw(base_size = 9) +
  theme(panel.grid = element_blank(), legend.position = "bottom") +
  labs(title = "C. Any-variable union", subtitle =
    "Any qualifying variable creates climate change; contiguous cells only; gray margins lack all ten phases",
    x = NULL, y = NULL, fill = NULL)

composite_long = composite$grid |>
  select(t, MORA, NOCA, Regional = regional_composite) |>
  pivot_longer(-t, names_to = "series", values_to = "magnitude")
p4 = ggplot(composite_long, aes(t, magnitude, color = series)) +
  shade_incomplete() + geom_line(linewidth = .75) + time_scale() +
  scale_color_manual(values = c(site_cols, Regional = "black")) +
  theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(),
    legend.position = "bottom") +
  labs(title = "D. Unthresholded four-variable composite",
    subtitle = "Euclidean magnitude is contextual and non-directional; it cannot define an era",
    x = NULL, y = "Climate displacement (calibration SD units)", color = NULL)

p5 = ggplot(filter(fire$site_grid, between(cal_bp, -100, 11000)),
  aes(cal_bp, normalized_frequency, color = site)) +
  geom_line(linewidth = .8, na.rm = TRUE) +
  geom_line(aes(y = high_fire_threshold), linetype = 2, linewidth = .55) +
  time_scale() + scale_color_manual(values = fire_cols) + theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom") +
  labs(title = "E. Independent centered 1,000-year fire-event frequency",
    subtitle = "Each core is normalized to its own maximum; MORA is an equal-core mean where >=2 cores are covered",
    x = NULL, y = "Normalized accepted-event frequency", color = NULL)

fire_band = fire$site_grid |>
  filter(is.finite(normalized_frequency), between(cal_bp, -100, 11000)) |>
  mutate(state = if_else(high_fire, "high fire", "not high fire"))
markers = fire$corroboration_site |>
  filter(corroborates, between(cal_bp, -100, 11000)) |>
  mutate(marker = recode(stream,
    peak_strength_percentile_sum = "peak strength",
    background_char_z = "background CHAR"))
p6 = ggplot(fire_band, aes(cal_bp, site, fill = state)) +
  geom_tile(width = 100, height = .72) +
  geom_point(data = markers, aes(cal_bp, site, shape = marker),
    inherit.aes = FALSE, size = 1.7, color = "black") +
  time_scale() +
  scale_fill_manual(values = c(`high fire` = "#B22222",
    `not high fire` = "grey90")) +
  scale_shape_manual(values = c(`peak strength` = 17, `background CHAR` = 18)) +
  theme_bw(base_size = 9) + theme(panel.grid = element_blank(),
    legend.position = "bottom") +
  labs(title = "F. High-fire periods and corroboration",
    subtitle = "Frequency alone selects periods; symbols show independent strength/background support",
    x = "cal BP (older to younger)", y = NULL, fill = NULL, shape = NULL)

# =============================================================================
# REVISED WORKED EXAMPLE
# =============================================================================
example_variable = if ("MWT" %in% CCA_VARIABLES) "MWT" else CCA_VARIABLES[1]
example_phase = climate$regional_phases |>
  filter(variable == example_variable, between(t, 6500, 10000))
example_grid = climate$variable_cells |>
  filter(between(t, 6500, 10000))
w1 = ggplot(example_phase, aes(t, regional_score, group = factor(offset),
  color = factor(offset))) +
  geom_hline(yintercept = 0, color = "grey65") + geom_line(alpha = .55) +
  time_scale() + scale_color_viridis_d(option = "turbo") + theme_bw() +
  labs(title = "1. Ten phases expose placement sensitivity",
    subtitle = paste0("Example: ", tolower(CLIMATE_VARIABLE_LABELS[[example_variable]]), "; direction is evaluated regionally"),
    x = NULL, y = "Regional standardized change", color = "Offset")
w2 = ggplot(example_grid, aes(t, regional_score, color = variable)) +
  geom_hline(data = threshold_lines, aes(yintercept = y), inherit.aes = FALSE,
    linetype = 2, color = "grey35") + geom_hline(yintercept = 0,
    color = "grey65") + geom_line() +
  geom_point(data = filter(example_grid, qualifies), size = 2) +
  facet_wrap(~variable, nrow = 1) + time_scale() +
  scale_color_manual(values = variable_cols) + theme_bw() +
  theme(legend.position = "none") +
  labs(title = "2. Apply each variable's 50%-of-maximum threshold",
    subtitle = "A filled cell also needs >=8/10 phases in the regional direction",
    x = NULL, y = "Median regional change")
w3 = p2 + labs(title = "3. Keep direction, then take the any-variable union",
  subtitle = "One qualifying variable is sufficient; below-threshold gaps remain stable")
w4 = p3 + labs(title = "4. Merge only adjacent cells and number CC/S eras",
  subtitle = "No site-direction veto, transition state, forward extension, or gap bridging")
w5 = p4 + labs(title = "5. Composite magnitude is a visual cross-check",
  subtitle = "It is unsigned and unthresholded, so it never selects direction or eras")
w6 = (p5 + labs(title = "6a. Fire is classified independently",
    subtitle = "High fire = normalized site frequency > median + 1.4826 x MAD")) /
  (p6 + labs(title = "6b. Every contiguous run is retained",
    subtitle = "Frequency selects periods; strength/background are corroboration only")) +
  plot_layout(heights = c(1.2, .8))
worked = w1 / w2 / w3 / w4 / w5 / w6 +
  plot_layout(heights = c(1.1, 1.4, 1.1, .8, 1.0, 1.8)) +
  plot_annotation(title = "Worked example: unified Holocene climate eras and fire periods")
if (render_figures) {
  ggsave(fig("worked_examples", "fig_holocene_climate_period_method_worked_example.pdf"),
    worked, width = 15, height = 20)
}

})

# =============================================================================
# 3. High-fire periods
# =============================================================================
local({
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(patchwork)
})
source(here("R/helpers/figure_style.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

paths = c(
  events = out("holocene_fire_source_events.csv"),
  core = out("holocene_era_fire_core_frequency.csv"),
  site = out("holocene_era_fire_site_frequency.csv"))
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
write_csv(audit, out("worked_examples/holocene_fire_method_worked_example.csv"))

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
  ggsave(fig("worked_examples", "fig_holocene_fire_method_worked_example.pdf"), figure,
         width = 14, height = 11, units = "in", bg = "white")
  cat("Written Holocene fire worked example for 2,300 cal BP.\n")
}
})

# =============================================================================
# 4. Tracking geometry
# =============================================================================
local({
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures',TRUE))
r=read_csv(out('cca_tracking_holocene_lake_calculations.csv'),show_col_types=FALSE)
b=read_csv(out('cca_tracking_holocene_lake_transitions.csv'),show_col_types=FALSE)
example=r |> filter(lake=='PantherPotholes',pace_counterfactual_valid,direction_counterfactual_valid) |>
  mutate(distance=abs(interval_mid_cal_bp-3000)) |> arrange(distance) |> slice(1)
if(nrow(example)!=1L) stop('No valid primary worked example')
points = tibble(label=c('O1','O2','P1','P2','Pace corrected','Direction corrected'),
  CCA1=c(example$o1,example$o1_2,example$p1,example$p1_2,example$pace_corrected_CCA1,example$direction_corrected_CCA1),
  CCA2=c(example$o2,example$o2_2,example$p2,example$p2_2,example$pace_corrected_CCA2,example$direction_corrected_CCA2))
vectors = tibble(type=c('Observed','Predicted','Pace corrected','Direction corrected'),
  x=c(example$o1,example$p1,example$o1,example$o1),y=c(example$o2,example$p2,example$o2,example$o2),
  xend=c(example$o1_2,example$p1_2,example$pace_corrected_CCA1,example$direction_corrected_CCA1),
  yend=c(example$o2_2,example$p2_2,example$pace_corrected_CCA2,example$direction_corrected_CCA2))
a = ggplot(points,aes(CCA1,CCA2)) + geom_segment(data=vectors,
  aes(x=x,y=y,xend=xend,yend=yend,color=type),inherit.aes=FALSE,
  arrow=grid::arrow(length=grid::unit(2,'mm'))) + geom_point() +
  geom_text(aes(label=label),vjust=-.7,size=3) + coord_equal() +
  labs(title='A. Actual and corrected movement',color=NULL) + theme_minimal(base_size=14)
lag = tibble(endpoint=c('Initial','Actual final','Pace corrected','Direction corrected'),
  lag=c(example$lag_t1,example$lag_t2,example$lag_t2_pace_corrected,example$lag_t2_direction_corrected))
p = ggplot(lag,aes(endpoint,lag)) + geom_col(fill='#4477AA') +
  geom_text(aes(label=sprintf('%.3f',lag)),vjust=-.3,size=3) +
  labs(title='B. Distance to actual predicted position',x=NULL,y='Lag (CCA distance)') +
  theme_minimal(base_size=14) + theme(axis.text.x=element_text(angle=20,hjust=1))
metrics = tracking_response_names()
values = example |> select(all_of(metrics)) |> pivot_longer(everything(),names_to='metric',values_to='value')
q = ggplot(values,aes(x=1,y=value)) + geom_point(size=2) +
  geom_text(aes(label=sprintf('%.3f',value)),nudge_x=.2,size=3) +
  facet_wrap(~metric,scales='free_y',ncol=2) + labs(title='C. Focused quantities for this transition',x=NULL,y=NULL) +
  theme_minimal(base_size=9) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())
support=tibble(endpoint=c('Older century','Younger century'),n_samples=c(example$n_samples_t1,example$n_samples_t2))
s=ggplot(support,aes(endpoint,n_samples))+geom_col(fill='grey70')+
  labs(title='D. Actual endpoint sampling',x=NULL,y='Original macrofossil samples')+theme_minimal(base_size=16)
figure=(a+p)/(q+s)+plot_annotation(title=paste0('Panther Potholes: ',example$age_hi,' to ',example$age_lo,' cal BP'),
  subtitle=paste('Primary median-age reconstruction; elapsed time:',example$vegetation_dt_years,'years'),
  caption='Sample WA positions are averaged within native centuries. No vegetation interpolation. Corrections start at O1.')
if(render_figures) ggsave(fig('worked_examples', 'fig_method_worked_example.pdf'),figure,width=14,height=12)
})
