# Offline gate for the integrated, harmonized-fire tracking figure.
suppressPackageStartupMessages({library(here); library(tidyverse)})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

data_paths = here(c(
  "output/cca_tracking_holocene_timeseries.csv",
  "output/cca_tracking_anthropocene_plot.csv",
  "output/cca_tracking_visualization_points.csv",
  "output/cca_tracking_interval_resolution_audit.csv",
  "output/cca_tracking_comparison_summary.csv",
  "output/cca_tracking_comparison_spec.csv",
  "output/cca_tracking_anthropocene_fire_scope_audit.csv",
  "output/holocene_era_fire_site_frequency.csv"))
figure_paths = here(c("plot/fig_tracking_comparison.pdf",
                      "plot/fig_tracking_comparison.png"))
stopifnot(all(file.exists(data_paths)))

timeseries = read_csv(data_paths[1], show_col_types = FALSE)
anth = read_csv(data_paths[2], show_col_types = FALSE)
points = read_csv(data_paths[3], show_col_types = FALSE)
resolution = read_csv(data_paths[4], show_col_types = FALSE)
recorded = read_csv(data_paths[5], show_col_types = FALSE)
spec = read_csv(data_paths[6], show_col_types = FALSE)
scope = read_csv(data_paths[7], show_col_types = FALSE)
fire = read_csv(data_paths[8], show_col_types = FALSE)

dates = timeseries |> distinct(site, t) |> count(site, name = "n")
stopifnot(identical(dates,
  tibble(site = c("MORA", "NOCA"), n = c(54L, 83L))),
  all(timeseries$n_offsets == 10L), nrow(anth) == 605L)

holo = points |> filter(point_class == "holocene_site_interval") |>
  left_join(fire |> select(site, t = cal_bp, high_fire), by = c("site", "t")) |>
  mutate(macro_era = "Holocene",
    climate_state = if_else(climate_era_class == "climate change",
      "Holocene climate change", "Holocene climate stability"),
    fire_class = if_else(high_fire, "Fire", "No fire"))
modern_all = points |> filter(point_class == "anthropocene_plot") |>
  mutate(plot_id = str_to_upper(plot_id)) |>
  inner_join(scope |> mutate(plot_id = str_to_upper(plot_id)),
             by = c("site", "plot_id"))
modern = modern_all |> filter(included) |>
  mutate(macro_era = "Anthropocene",
    fire_status = if_else(burnt, "Burned", "Unburned"),
    fire_class = if_else(burnt, "Fire", "No fire"))
raw = bind_rows(holo, modern)

stopifnot(nrow(holo) == 137L, !anyNA(holo$high_fire),
  nrow(modern_all) == 605L, nrow(modern) == 603L,
  sum(!scope$included) == 2L,
  setequal(scope$plot_id[!scope$included], c("JAME-295", "OHAN-013")),
  sum(modern$site == "NOCA" & modern$burnt) == 23L)

state_counts = holo |> count(site, climate_state, fire_class) |>
  arrange(site, climate_state, fire_class)
expected_states = tribble(
  ~site, ~climate_state, ~fire_class, ~n,
  "MORA", "Holocene climate change", "Fire", 8L,
  "MORA", "Holocene climate change", "No fire", 7L,
  "MORA", "Holocene climate stability", "Fire", 8L,
  "MORA", "Holocene climate stability", "No fire", 31L,
  "NOCA", "Holocene climate change", "Fire", 12L,
  "NOCA", "Holocene climate change", "No fire", 28L,
  "NOCA", "Holocene climate stability", "Fire", 2L,
  "NOCA", "Holocene climate stability", "No fire", 41L) |>
  arrange(site, climate_state, fire_class)
stopifnot(identical(state_counts, expected_states))

metrics = c("lag", "lag_rate_per_century", "rate_tracking_ratio",
            "angle_degrees")
safe = function(x, f, ...) {
  x = x[is.finite(x)]; if (length(x)) f(x, ...) else NA_real_
}
summarize_check = function(data, groups, level) data |>
  select(all_of(groups), all_of(metrics)) |>
  pivot_longer(all_of(metrics), names_to = "metric", values_to = "value") |>
  group_by(across(all_of(c(groups, "metric")))) |>
  summarise(summary_level = level, n_total = n(),
    n_valid = sum(is.finite(value)), median = safe(value, median),
    q25 = safe(value, quantile, .25, names = FALSE),
    q75 = safe(value, quantile, .75, names = FALSE),
    whisker_low = if (any(is.finite(value)))
      boxplot.stats(value[is.finite(value)])$stats[1] else NA_real_,
    whisker_high = if (any(is.finite(value)))
      boxplot.stats(value[is.finite(value)])$stats[5] else NA_real_,
    .groups = "drop")

manual = bind_rows(
  summarize_check(raw, c("site", "macro_era", "fire_class"),
                  "macro era x fire"),
  summarize_check(holo, c("site", "climate_state", "fire_class"),
                  "Holocene climate state x fire"),
  summarize_check(raw, c("site", "macro_era"), "macro era"),
  summarize_check(filter(modern, site == "NOCA"),
                  c("site", "fire_status"),
                  "NOCA Anthropocene fire status"))
keys = c("summary_level", "site", "metric", "macro_era", "fire_class",
         "climate_state", "fire_status")
cmp = full_join(manual, recorded, by = keys, suffix = c("_manual", "_recorded"))
same = function(a, b) (is.na(a) & is.na(b)) |
  (!is.na(a) & !is.na(b) & abs(a - b) < 1e-9)
stopifnot(nrow(manual) == 84L, nrow(recorded) == 84L, nrow(cmp) == 84L,
  all(cmp$n_total_manual == cmp$n_total_recorded),
  all(cmp$n_valid_manual == cmp$n_valid_recorded))
for (nm in c("median", "q25", "q75", "whisker_low", "whisker_high"))
  stopifnot(all(same(cmp[[paste0(nm, "_manual")]],
                     cmp[[paste0(nm, "_recorded")]])))

stationary = modern |> filter(observed_vegetation_displacement <= 1e-8)
stopifnot(nrow(stationary) == 153L, all(is.na(stationary$angle_degrees)),
  identical(stationary |> count(site),
    tibble(site = c("MORA", "NOCA"), n = c(78L, 75L))))
background = raw |> filter(is.finite(angle_degrees),
                            is.finite(rate_tracking_ratio))
box_spec = filter(spec, record_type == "box")
scatter_spec = filter(spec, record_type == "scatter")
stopifnot(nrow(box_spec) == 6L,
  setequal(box_spec$metric,
    c("lag_rate_per_century", "rate_tracking_ratio", "angle_degrees")),
  !"lag" %in% box_spec$metric,
  all(box_spec$x_scale == "raw_linear"), all(box_spec$y_scale == "raw_linear"),
  setequal(box_spec$panel, c("A", "B", "C")),
  all(str_detect(box_spec$element, "fixed site facets")),
  all(str_detect(box_spec$grouping_contract, "interaction")),
  all(box_spec$box_width_contract ==
        "width=0.55;position_dodge2(preserve=single)"),
  all(box_spec$panel_width_fraction == 1),
  nrow(scatter_spec) == 1L,
  scatter_spec$panel == "D",
  scatter_spec$x_reference == 90, scatter_spec$y_reference == 1,
  scatter_spec$n_background == nrow(background),
  scatter_spec$n_background == 587L,
  scatter_spec$n_macro == 4L, scatter_spec$n_detail == 8L,
  scatter_spec$n_noca_fire == 2L,
  scatter_spec$n_stationary_angle_undefined == 153L,
  scatter_spec$metric == "angle_degrees x rate_tracking_ratio",
  scatter_spec$grouping_contract ==
    "site=shape;lag=fill;fire=categorical outline;era=label",
  scatter_spec$box_metrics ==
    "lag_rate_per_century;rate_tracking_ratio;angle_degrees",
  scatter_spec$fire_box_fill ==
    "white; fire distinguished by dark-red outline",
  scatter_spec$panel_width_fraction == 0.75,
  scatter_spec$layout_contract == "centered with symmetric side spacers",
  str_detect(scatter_spec$label_contract, "one shared repel layer"),
  str_detect(scatter_spec$label_contract, "exact represented CC/S eras"),
  scatter_spec$x_scale == "raw_linear", scatter_spec$y_scale == "raw_linear")

figure_code = paste(readLines(here("R/stages/09c_tracking_comparison.R")),
  collapse = "\n")
stopifnot(
  str_detect(figure_code, 'BOX_METRICS = METRICS\\[names\\(METRICS\\) != "lag"\\]'),
  str_count(figure_code,
    fixed('"Tracking ratio (observed/predicted)"')) == 2L,
  !str_detect(figure_code, fixed('"Rate tracking ratio"')),
  str_detect(figure_code, 'fire_fill = c\\(`No fire` = "white", Fire = "white"\\)'),
  str_detect(figure_code, 'paste0\\(as.character\\(macro_era\\), "\\\\nmedian"\\)'),
  str_detect(figure_code, '"Holocene\\\\n"'),
  str_detect(figure_code, "era_sets = state"),
  str_detect(figure_code, "unique\\(climate_era_id\\)"),
  str_detect(figure_code, 'paste0\\("Climate change \\("'),
  str_detect(figure_code, 'paste0\\("Climate stability \\("'),
  str_detect(figure_code, '"Anthropocene\\\\n"'),
  str_detect(figure_code, "geom_text_repel\\(data = scatter_labels"),
  str_detect(figure_code, "SCATTER_WIDTH_FRACTION = 0\\.75"),
  str_detect(figure_code,
    "plot_layout\\(widths = c\\(scatter_side_fraction, SCATTER_WIDTH_FRACTION"),
  str_detect(figure_code, "figure = panel_a / panel_b_row"),
  str_detect(figure_code,
    'position_dodge2\\(width = \\.68, preserve = "single"'),
  all(str_detect(figure_code,
    fixed(c('"A."', '"B."', '"C."', '"D."')))))

stopifnot(setequal(resolution$resolution,
  c("1000 years (primary)", "500 years (sensitivity)",
    "1000 minus 500 years")))

pdf_pages = function(path) {
  if (nzchar(Sys.which("pdfinfo"))) {
    z = system2("pdfinfo", path, stdout = TRUE, stderr = TRUE)
    return(as.integer(sub("^Pages:\\s*", "", grep("^Pages:", z, value = TRUE)[1])))
  }
  if (requireNamespace("pdftools", quietly = TRUE))
    return(pdftools::pdf_info(path)$pages)
  NA_integer_
}
if (render_figures)
  stopifnot(all(file.exists(figure_paths)),
            all(file.info(figure_paths)$size > 5000),
            pdf_pages(figure_paths[1]) == 1L)
cat("PASS: harmonized-fire tracking data",
    if (render_figures) ", boxes, and one unfaceted angle-by-ratio scatter.\n" else ".\n",
    sep = "")
