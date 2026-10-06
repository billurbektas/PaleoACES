# =============================================================================
# 12_walsh_fire_reproduction.R
# =============================================================================
# Assemble the authoritative all-tapas four-core source catalog, then run the
# official CharAnalysis R 2.0.3 Walsh reproduction as a separate audit. This
# stage never overwrites fire_walsh.csv, paleo_fire.csv, or CCA fire assignments.

suppressPackageStartupMessages({
  library(here); library(tidyverse); library(readxl); library(CharAnalysis)
  library(tapas); library(patchwork)
})
source(here("R/helpers/walsh_fire_functions.R"))
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

FROZEN_FIRE_PATHS = here("output", c("fire_walsh.csv", "paleo_fire.csv"))
if (!all(file.exists(FROZEN_FIRE_PATHS))) stop("Active paleo-fire outputs are missing.")
frozen_fire_before = unname(tools::md5sum(FROZEN_FIRE_PATHS))

EXPECTED_CHAR_VERSION = "2.0.3"
if (as.character(packageVersion("CharAnalysis")) != EXPECTED_CHAR_VERSION)
  stop("Official Walsh audit requires CharAnalysis ", EXPECTED_CHAR_VERSION,
       "; installed version is ", packageVersion("CharAnalysis"), ".")

INPUT_DIR = here("output/walsh_charanalysis_inputs")
dir.create(INPUT_DIR, recursive = TRUE, showWarnings = FALSE)
settings = tribble(
  ~lake, ~site_id, ~input, ~interpolation_years, ~smoothing_years,
  "Sunrise Lake", "Sunrise", "data/PALEO/char_sunrise_lake.xlsx", 48, 800,
  "Shadow Lake", "Shadow", "data/PALEO/char_shadow_lake.xlsx", 47, 1000,
  "Little Sunrise Lake", "LittleSunrise", "data/PALEO/char_little_sunrise.xlsx", 42, 500) |>
  mutate(input = here(input), transform = "none", background_method = "robust LOWESS",
         peak_component = "residual", threshold_type = "local",
         threshold_method = "Gaussian mixture noise distribution",
         final_threshold_probability = .95, minimum_count_probability = .05,
         minimum_count_window_years = 75, frequency_smoother_years = 1000)

results = vector("list", nrow(settings))
input_audit = vector("list", nrow(settings))
raw_results = vector("list", nrow(settings))

# CharAnalysis 2.0.3 draws its complete internal diagnostic suite as a side
# effect of fitting. Capture those plots on a temporary device so an accidental
# root-level plot/archive/root_graphics/Rplots.pdf is not created; the maintained audit figure below is
# built explicitly from the returned numerical objects.
capture_internal_graphics = function(expression) {
  temporary_plot = tempfile("charanalysis_internal_", fileext = ".pdf")
  grDevices::pdf(temporary_plot)
  on.exit({
    grDevices::dev.off()
    unlink(temporary_plot)
  }, add = TRUE)
  force(expression)
}

for (i in seq_len(nrow(settings))) {
  s = settings[i, ]
  dat = walsh_input_data(s$input)
  inp = write_charanalysis_inputs(dat, s$site_id, s$interpolation_years,
                                  s$smoothing_years, INPUT_DIR)
  out = capture_internal_graphics(CharAnalysis(inp$params))
  raw_results[[i]] = out
  results[[i]] = extract_charanalysis_result(out, s$lake)
  input_audit[[i]] = tibble(lake = s$lake, data_file = inp$data,
    parameter_file = inp$params, input_rows = nrow(dat),
    data_md5 = unname(tools::md5sum(inp$data)),
    parameter_md5 = unname(tools::md5sum(inp$params)))
}

mora_series = map_dfr(results, "series")
mora_events = map_dfr(results, "events")
mora_fri = map_dfr(results, "fri")
input_audit = bind_rows(input_audit)

# Published totals are a regression reference, not a target to force by tuning.
published = tribble(
  ~lake, ~published_total_episodes,
  "Shadow Lake", 18L,
  "Sunrise Lake", 24L,
  "Little Sunrise Lake", 16L)
regression = mora_events |> count(lake, name = "official_r_episodes") |>
  full_join(published, by = "lake") |>
  mutate(difference = official_r_episodes - published_total_episodes,
    exact_match = difference == 0,
    interpretation = if_else(exact_match,
      "official R result matches reported total",
      "official R 2.0.3 result retained; discrepancy from Walsh reported total"))

tapas_counts = read_csv(here("output/fire_walsh.csv"), show_col_types = FALSE) |>
  filter(is_significant) |> count(lake, name = "tapas_episodes")
software_comparison = regression |> left_join(tapas_counts, by = "lake") |>
  mutate(tapas_minus_official_r = tapas_episodes - official_r_episodes,
         tapas_status = "primary harmonized source catalog")

# The downstream source catalog is all-tapas. Official CharAnalysis objects
# above remain a publication-reproduction audit and never replace these events.
active_paths = here("output", c(
  "fire_mora_tapas_series.csv", "fire_mora_tapas_events.csv",
  "fire_mora_tapas_settings.csv", "fire_noca_tapas_series.csv",
  "fire_noca_tapas_events.csv", "fire_noca_tapas_settings.csv"))
if (!all(file.exists(active_paths)))
  stop("Run R/stages/000_FIRE_cleaning.R and R/stages/000_PALEO_c_fire.R first.")
all_continuous = bind_rows(
  read_csv(active_paths[1], show_col_types = FALSE),
  read_csv(active_paths[4], show_col_types = FALSE))
all_events = bind_rows(
  read_csv(active_paths[2], show_col_types = FALSE),
  read_csv(active_paths[5], show_col_types = FALSE))
tapas_settings = bind_rows(
  read_csv(active_paths[3], show_col_types = FALSE),
  read_csv(active_paths[6], show_col_types = FALSE))
if (n_distinct(all_events$lake) != 4L ||
    anyDuplicated(all_events[c("lake", "age_cal_yr_BP")]) ||
    !all(unique(tapas_settings$engine) == "tapas"))
  stop("The harmonized all-tapas source catalog is incomplete or duplicated.")
coverage = all_continuous |> group_by(site, lake) |>
  summarise(younger_cal_bp = min(age_cal_yr_BP),
            older_cal_bp = max(age_cal_yr_BP), .groups = "drop")

write_csv(settings, here("output/walsh_charanalysis_settings.csv"))
write_csv(input_audit, here("output/walsh_charanalysis_input_audit.csv"))
write_csv(mora_series, here("output/walsh_charanalysis_series.csv"))
write_csv(mora_events, here("output/walsh_charanalysis_events.csv"))
write_csv(mora_fri, here("output/walsh_charanalysis_fri.csv"))
write_csv(regression, here("output/walsh_charanalysis_table3_audit.csv"))
write_csv(software_comparison, here("output/walsh_charanalysis_software_comparison.csv"))
write_csv(tapas_settings, here("output/holocene_fire_source_settings.csv"))
write_csv(all_continuous, here("output/holocene_fire_source_series.csv"))
write_csv(all_events, here("output/holocene_fire_source_events.csv"))
write_csv(coverage, here("output/holocene_fire_source_coverage.csv"))

pkg_desc = system.file("DESCRIPTION", package = "CharAnalysis")
manifest_paths = c(settings$input, input_audit$data_file, input_audit$parameter_file,
  here("output/walsh_charanalysis_series.csv"),
  here("output/walsh_charanalysis_events.csv"),
  here("output/walsh_charanalysis_table3_audit.csv"))
manifest = tibble(
  engine = "official CharAnalysis R", version = EXPECTED_CHAR_VERSION,
  release_source = "CRAN CharAnalysis 2.0.3",
  package_description_md5 = unname(tools::md5sum(pkg_desc)),
  file = normalizePath(manifest_paths), md5 = unname(tools::md5sum(manifest_paths)),
  active_fire_pipeline_modified = FALSE)
write_csv(manifest, here("output/walsh_charanalysis_manifest.csv"))
tapas_desc = system.file("DESCRIPTION", package = "tapas")
tapas_manifest_paths = c(active_paths,
  here("output/holocene_fire_source_settings.csv"),
  here("output/holocene_fire_source_series.csv"),
  here("output/holocene_fire_source_events.csv"))
tapas_manifest = tibble(
  engine = "tapas", version = as.character(packageVersion("tapas")),
  analytical_role = "primary harmonized fire-event detector",
  package_description_md5 = unname(tools::md5sum(tapas_desc)),
  file = normalizePath(tapas_manifest_paths),
  md5 = unname(tools::md5sum(tapas_manifest_paths)))
write_csv(tapas_manifest, here("output/holocene_fire_tapas_manifest.csv"))
frozen_fire_after = unname(tools::md5sum(FROZEN_FIRE_PATHS))
if (!identical(frozen_fire_before, frozen_fire_after))
  stop("Walsh reproduction modified an active paleo-fire output.")
write_csv(tibble(file = normalizePath(FROZEN_FIRE_PATHS),
  md5_before = frozen_fire_before, md5_after = frozen_fire_after,
  unchanged = frozen_fire_before == frozen_fire_after),
  here("output/walsh_active_fire_hash_audit.csv"))

lake_cols = c("Sunrise Lake" = "#3B82A0", "Shadow Lake" = "#7B5EA7",
              "Little Sunrise Lake" = "#C47A31", PantherPotholes = "#D95F43")
p1 = ggplot(mora_series, aes(age_cal_yr_BP, char_interpolated, color = lake)) +
  geom_line(linewidth = .35) + geom_line(aes(y = background_char), linewidth = .8) +
  geom_point(data = mora_events, aes(y = peak_magnitude), shape = 4, size = 2) +
  facet_wrap(~lake, ncol = 1, scales = "free_y") + scale_x_reverse() +
  scale_color_manual(values = lake_cols) + theme_bw() +
  labs(title = "Official CharAnalysis reconstruction of Walsh MORA records",
       subtitle = "Thin: interpolated CHAR; bold: background; X: accepted peak magnitude",
       x = "cal BP", y = "Within-record CHAR units", color = NULL)
p2 = ggplot(mora_series, aes(age_cal_yr_BP, fire_frequency_per_1000yr,
                             color = lake)) +
  geom_line() + facet_wrap(~lake, ncol = 1, scales = "free_y") +
  scale_x_reverse() + scale_color_manual(values = lake_cols) + theme_bw() +
  labs(title = "Walsh-style smoothed fire frequency", x = "cal BP",
       y = "Fire episodes per 1,000 years", color = NULL)
p3 = regression |> pivot_longer(c(published_total_episodes, official_r_episodes),
  names_to = "source", values_to = "episodes") |>
  ggplot(aes(lake, episodes, fill = source)) + geom_col(position = "dodge") +
  geom_text(aes(label = episodes), position = position_dodge(.9), vjust = -.2) +
  theme_bw() + labs(title = "Walsh reported totals versus official R 2.0.3",
    subtitle = "Discrepancies are retained, not tuned away", x = NULL, y = "Episodes")
pages = list(p1, p2, p3)
if (render_figures) {
  pdf(here("plot/test_figures/fig_walsh_charanalysis_reproduction.pdf"), width = 13,
      height = 9, onefile = TRUE); walk(pages, print); dev.off()
}

cat("Official CharAnalysis episode counts:\n")
print(as.data.frame(regression))
cat("Wrote source series and accepted events for the independent era stage.\n")
