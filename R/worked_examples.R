# Worked examples: step-by-step illustrations of four methods, drawn from the
# finished pipeline outputs. Nothing here feeds the analysis. Run after the
# pipeline (R/run_all.R does this last).
#   1. Accepted charcoal-event detection (Fig. S7)
#   2. Climate eras: phases, thresholds and era construction
#   3. Tracking geometry: movement, lag, ratio and angle
# The high-fire-period example was removed with the high-fire classification
# (Bills, 11 Nov 2026).

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
       subtitle = paste("The detection settings differ among cores; the events are then",
                        "counted per 1,000 years for Figure 2C.")) +
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
      "Accepted events are inferred charcoal episodes, not exact known ignition dates.")) +
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
sys.source(here::here('R/pipeline/11_climate_eras_fire_frequency.R'), envir = environment())

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
worked = w1 / w2 / w3 / w4 / w5 +
  plot_layout(heights = c(1.1, 1.4, 1.1, .8, 1.0)) +
  plot_annotation(title = "Worked example: unified Holocene climate eras")
if (render_figures) {
  ggsave(fig("worked_examples", "fig_holocene_climate_period_method_worked_example.pdf"),
    worked, width = 15, height = 16.5)
}

})

# =============================================================================
# 3. Tracking geometry
# =============================================================================
local({
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures',TRUE))
# The worked example is one lake-period (PLAN.md Steps 1 to 4), drawn on the
# display-rotated axes like every CCA-space figure (PLAN.md Step 0.4).
r=read_csv(out('cca_tracking_lake_period_calculations.csv'),show_col_types=FALSE)
example=r |> filter(lake=='PantherPotholes',direction_defined) |>
  mutate(distance=abs((age_start+age_end)/2-3000)) |> arrange(distance) |> slice(1)
if(nrow(example)!=1L) stop('No valid lake-period worked example')
source(here('R/helpers/cca_display_rotation.R'),local=TRUE)
reference=readRDS(out('cca_calibration_reference.rds'))
rotation=cca_display_rotation(vegan::scores(reference$model,display='bp',choices=1:2,scaling='sites',hill=FALSE))
for(pair in list(c('o1','o2'),c('o1_2','o2_2'),c('p1','p2'),c('p1_2','p2_2'),
  c('pace_corrected_CCA1','pace_corrected_CCA2'),c('direction_corrected_CCA1','direction_corrected_CCA2')))
  example=rotate_columns(example,rotation,pair[1],pair[2])
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
  labs(title=sprintf('A. Actual and corrected movement (Panther Potholes %s, %g to %g cal BP)',example$period,example$age_start,example$age_end),
    x='Spring temperature (rotated axis 1)',y='Summer precipitation (rotated axis 2)',color=NULL) + theme_minimal(base_size=14)
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
  facet_wrap(~metric,scales='free_y',ncol=2) + labs(title='C. Focused quantities for this lake-period',x=NULL,y=NULL) +
  theme_minimal(base_size=9) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())
support=tibble(endpoint=c('Oldest century (t1)','Youngest century (t2)'),n_samples=c(example$n_start,example$n_end))
s=ggplot(support,aes(endpoint,n_samples))+geom_col(fill='grey70')+
  labs(title='D. Actual endpoint sampling',x=NULL,y='Original macrofossil samples')+theme_minimal(base_size=16)
figure=(a+p)/(q+s)+plot_annotation(title=paste0('Panther Potholes lake-period ',example$period,': ',example$age_start,' to ',example$age_end,' cal BP'),
  subtitle=paste('Elapsed time between the two sampled centuries:',example$duration_yr,'years'),
  caption='Sample WA positions are averaged within each sampled century. Axes rotated for display; all quantities are rotation-invariant. Corrections start at O1.')
if(render_figures) ggsave(fig('worked_examples', 'fig_method_worked_example.pdf'),figure,width=14,height=12)
})
