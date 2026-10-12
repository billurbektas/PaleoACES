# Offline gate for the official Walsh source-method reproduction.
suppressPackageStartupMessages({library(here); library(tidyverse)})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))
source(here("R/helpers/walsh_fire_functions.R"), local = TRUE)
stopifnot(requireNamespace("CharAnalysis", quietly = TRUE),
          as.character(packageVersion("CharAnalysis")) == "2.0.3")

audit = read_csv(here("output/walsh_charanalysis_table3_audit.csv"),
                 show_col_types = FALSE)
expected_official = c("Little Sunrise Lake" = 14L, "Shadow Lake" = 16L,
                      "Sunrise Lake" = 15L)
stopifnot(setequal(audit$lake, names(expected_official)),
          all(setNames(audit$official_r_episodes, audit$lake)[names(expected_official)] ==
                expected_official),
          all(!audit$exact_match),
          setequal(audit$published_total_episodes, c(16L, 18L, 24L)))

settings = read_csv(here("output/walsh_charanalysis_settings.csv"),
                    show_col_types = FALSE)
stopifnot(nrow(settings) == 3L,
  identical(settings$interpolation_years[match("Sunrise Lake", settings$lake)], 48),
  identical(settings$smoothing_years[match("Shadow Lake", settings$lake)], 1000),
  all(settings$final_threshold_probability == .95),
  all(settings$minimum_count_probability == .05),
  all(settings$minimum_count_window_years == 75))

events = read_csv(here("output/holocene_fire_source_events.csv"),
                  show_col_types = FALSE)
expected_primary = c("Little Sunrise Lake" = 13L, "Shadow Lake" = 14L,
                     "Sunrise Lake" = 17L, "PantherPotholes" = 66L)
primary_counts = events |> count(lake) |> deframe()
stopifnot(all(primary_counts[names(expected_primary)] == expected_primary))
primary_settings = read_csv(here("output/holocene_fire_source_settings.csv"),
                            show_col_types = FALSE)
stopifnot(nrow(primary_settings) == 4L,
  all(primary_settings$engine == "tapas"),
  identical(primary_settings$interpolation_years,
            c(48, 47, 42, 12)),
  identical(primary_settings$smoothing_years,
            c(800, 1000, 500, 500)),
  identical(primary_settings$threshold_probability,
            c(.95, .95, .95, .99)),
  all(primary_settings$minimum_count_probability == .05),
  all(primary_settings$minimum_count_window_years == 75))
series = read_csv(here("output/holocene_fire_source_series.csv"),
                  show_col_types = FALSE)
stopifnot(setequal(unique(series$lake), c("Sunrise Lake", "Shadow Lake",
  "Little Sunrise Lake", "PantherPotholes")),
  all(c("positive_threshold", "minimum_count_p",
    "candidate_before_count_screen", "rejected_by_count_screen",
    "is_significant") %in% names(series)))

detection = read_csv(here("output/fire_event_detection_lake_audit.csv"),
                     show_col_types = FALSE)
expected_detection = tribble(
  ~lake, ~interpolation_years, ~smoothing_years, ~threshold_probability,
  ~candidate_events, ~rejected_by_count_screen, ~accepted_events,
  "Sunrise Lake", 48, 800, .95, 26L, 9L, 17L,
  "Shadow Lake", 47, 1000, .95, 17L, 3L, 14L,
  "Little Sunrise Lake", 42, 500, .95, 20L, 7L, 13L,
  "PantherPotholes", 12, 500, .99, 66L, 0L, 66L)
stopifnot(isTRUE(all.equal(
  detection |>
    select(all_of(names(expected_detection))) |>
    arrange(match(lake, expected_detection$lake)),
  expected_detection, check.attributes = FALSE)),
  all(detection$candidate_events ==
      detection$accepted_events + detection$rejected_by_count_screen),
  all(detection$minimum_count_probability == .05),
  all(detection$minimum_count_window_years == 75))

hashes = read_csv(here("output/walsh_active_fire_hash_audit.csv"),
                  show_col_types = FALSE)
stopifnot(all(hashes$unchanged))
manifest = read_csv(here("output/holocene_fire_tapas_manifest.csv"),
                    show_col_types = FALSE)
stopifnot(nrow(manifest) >= 9L, all(manifest$engine == "tapas"),
          all(manifest$analytical_role ==
                "primary harmonized fire-event detector"),
          all(nzchar(manifest$md5)))
sensitivity = read_csv(here("output/fire_noca_tapas_sensitivity.csv"),
                       show_col_types = FALSE)
stopifnot(sensitivity$n_sig[
  sensitivity$setting == "publication12.5_smooth500_q99"] == 72L)
required = c("plot/test_figures/fig_walsh_charanalysis_reproduction.pdf",
  "plot/test_figures/worked_examples/fig_fire_event_detection_workflow.pdf")
if (render_figures) {
  sizes = file.info(here(required))$size
  stopifnot(all(file.exists(here(required))),
            all(sizes > 3000))
}
cat("PASS: all-tapas primary catalogs and separate official Walsh audit",
    if (render_figures) ", including detector/audit figures.\n" else ".\n", sep = "")
