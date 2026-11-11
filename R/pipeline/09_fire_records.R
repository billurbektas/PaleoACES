# 08 Fire records (Appendix S3): tapas event detection for the three MORA charcoal
# records and Panther Potholes, fire evidence per macrofossil sample, the
# four-lake accepted-event catalog, and the CharAnalysis reproduction of
# Walsh et al. (2017) (Table S3.2).

# =============================================================================
# 1. MORA charcoal records: tapas detection with Walsh settings
# =============================================================================
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({
  library(here); library(tidyverse); library(readxl); library(tapas)
})
source(here("R/helpers/fire_detection_functions.R"), local = TRUE)

settings = fire_source_settings() |> filter(site == "MORA")
results = pmap(settings, function(site, lake, input_source, chronology,
                                  interpolation_years, smoothing_years,
                                  threshold_probability) {
  run_tapas_fire_detection(
    prepare_mora_charcoal(here(input_source)), site, lake,
    interpolation_years, smoothing_years, threshold_probability,
    chronology, input_source)
})

fire_episodes_final = map_dfr(results, "peaks")
series = map_dfr(results, "series")
events = map_dfr(results, "events")
settings_audit = map_dfr(results, "settings")

if (nrow(events) == 0L || anyDuplicated(events[c("lake", "age_cal_yr_BP")]))
  stop("The harmonized MORA accepted-event catalog is empty or duplicated.")

write_csv(fire_episodes_final, out("fire_walsh.csv"))
write_csv(series, out("fire_mora_tapas_series.csv"))
write_csv(events, out("fire_mora_tapas_events.csv"))
write_csv(settings_audit, out("fire_mora_tapas_settings.csv"))

cat("Harmonized tapas MORA fire episodes:\n")
print(as.data.frame(fire_episodes_final |>
  group_by(lake, smoothing_window, interpolation_interval,
           threshold_probability) |>
  summarise(candidate_peaks = n(), accepted_events = sum(is_significant),
            older_cal_bp = max(age_cal_yr_BP),
            younger_cal_bp = min(age_cal_yr_BP), .groups = "drop")))

# =============================================================================
# 2. Panther Potholes detection and fire evidence per macrofossil sample
# =============================================================================
source(here::here('R/helpers/config.R'), local = TRUE)
library(readr)
library(tidyverse)
library(here)

macro_long = read_csv(out("paleo_macrofossil_long.csv"),
                      show_col_types = FALSE)
fire_walsh = read_csv(out("fire_walsh.csv"), show_col_types = FALSE)

paleo_fire =
  macro_long %>%
  filter(species %in% c("charred_needles", "needle_concentration", "charcoal_fragments"))%>%
  pivot_wider(names_from = species, values_from = Percentage)

stopifnot(nrow(paleo_fire) == 119)   # was `dim(paleo_fire) #119` in the original

paleo_prev_fire = paleo_fire %>%
  # join any fire that is BEFORE the paleo year (older in cal yr BP)
  left_join(fire_walsh, by = join_by(year <= age_cal_yr_BP),
            relationship = "many-to-many") %>%
  # filter to fires within 50 years and keep the nearest earlier event
  filter(is.na(age_cal_yr_BP) | (age_cal_yr_BP - year <= 50)) %>%
  group_by(site, depth, year) %>%
  slice_min(age_cal_yr_BP, with_ties = FALSE) %>%
  ungroup() %>%
  # tidy names and calculate years before
  rename(
    fire_event_year_BP  = age_cal_yr_BP,
    fire_lake           = lake,
    fire_peak_magnitude = peak_magnitude,
    fire_is_significant = is_significant
  ) %>%
  mutate(
    years_before_fire = fire_event_year_BP - year,
    has_fire_within_50yr = !is.na(fire_event_year_BP)
  ) %>%
  filter(!is.na(year))%>%
  filter(fire_is_significant)

paleo_fire =
  paleo_prev_fire %>%
  select(site, depth, year, charcoal_fragments, needle_concentration, charred_needles, fire_lake, fire_peak_magnitude, years_before_fire)%>%
  right_join(paleo_fire)%>%
  mutate(plot_id = paste0(site, ":depth:", as.character(depth)))%>%
  mutate(period = "paleo")%>%
  rename(lake = site)

paleo_fire =
  paleo_fire %>%
  mutate(charred_needles = ifelse(is.na(charred_needles), 0, charred_needles),
         fire_peak_magnitude = ifelse(is.na(fire_peak_magnitude), 0, fire_peak_magnitude),
         years_before_fire = ifelse(is.na(years_before_fire), 0, years_before_fire),
         fire_lake = ifelse(is.na(fire_lake), "no_fire_record", fire_lake)
         )

# Harmonize fire categories within each original sample; retain separate depths.
paleo_fire = paleo_fire %>%
  group_by(lake, period, plot_id, year) %>%
  summarize(depth               = mean(depth),
            charcoal_fragments  = mean(charcoal_fragments,  na.rm = TRUE),
            needle_concentration= mean(needle_concentration, na.rm = TRUE),
            charred_needles     = mean(charred_needles,     na.rm = TRUE),
            fire_peak_magnitude = max(fire_peak_magnitude),
            # the event that justifies `burnt` is the one with the largest peak
            fire_lake           = fire_lake[which.max(fire_peak_magnitude)],
            years_before_fire   = years_before_fire[which.max(fire_peak_magnitude)],
            .groups = "drop") %>%
  mutate(across(c(charcoal_fragments, needle_concentration, charred_needles),
                ~ ifelse(is.nan(.x), NA_real_, .x)))

# =============================================================================
# NOCA: Panther Potholes macrocharcoal (Neotoma dataset 52210)
# =============================================================================
# Charcoal is a SEPARATE Neotoma dataset from the macrofossils (52207), which is
# why it looked missing - 52207 holds only TRSH and LABO. See
# report/details/03_chronology_sources_NOCA.md.
#
# 870 samples, contiguous 1 cm, on exactly the same depths as the macrofossils, so
# fire and vegetation are measured on the SAME samples. Counts of 150-1000 um
# charcoal plus sample volume, so tapas can build concentration itself.
#
# AGES: ours, not Neotoma's. Matched on depth to 05_age_depth_models.R's Bacon run, exactly
# as the macrofossils are, so vegetation and fire share one chronology and one set
# of age draws. (They agree closely anyway: -50 to 10616 vs Neotoma's -49 to 10609.)
#
# ⚠ THE TWO SITES ARE NOT SAMPLED AT THE SAME RESOLUTION.
#   Panther Potholes   12 yr / sample
#   MORA Walsh lakes   42, 47, 48 yr / sample
# MORA retains each lake's published settings. NOCA is analyzed independently at
# its native median 12-year resolution, so its primary peak catalog is not
# artificially coarsened to the MORA grids. The sites' raw peak counts and
# magnitudes are never compared directly.
library(tapas)
source(here("R/helpers/paleo_ages.R"), local = TRUE)
source(here("R/helpers/fire_detection_functions.R"), local = TRUE)

NOCA_YRINTERP_PRIMARY = 12
NOCA_SMOOTH_PRIMARY   = 500
NOCA_THRESHOLD_PRIMARY = 0.99  # source setting used for reported fire-return intervals

ch = read_csv(here("data/NOCA/NOCA_paleo/neotoma_macrocharcoal_52210.csv"),
              show_col_types = FALSE)
pp_bacon = read_bacon_ages("PantherPotholes", coredir)

noca_char = prepare_noca_charcoal(ch, pp_bacon)

run_peaks = function(smoothing_yr, yrInterp, threshold_probability) {
  run_tapas_fire_detection(
    noca_char, "NOCA", "PantherPotholes", yrInterp, smoothing_yr,
    threshold_probability, "active PaleoACES Bacon median chronology",
    "data/NOCA/NOCA_paleo/neotoma_macrocharcoal_52210.csv")$peaks
}

cat("\n--- NOCA peak-detection sensitivity (n significant peaks) ---\n")
sens = tribble(
  ~setting, ~smoothing, ~yrInterp, ~threshold,
  "primary_native12_smooth500_q99", 500, 12, .99,
  "native12_smooth500_q95",         500, 12, .95,
  "native12_smooth500_q999",        500, 12, .999,
  "native12_smooth800_q99",         800, 12, .99,
  "native12_smooth1000_q99",       1000, 12, .99,
  "publication12.5_smooth500_q99",  500, 12.5, .99,
  "coarse45_smooth500_q99",         500, 45, .99)
sens$n_sig = pmap_int(sens[c("smoothing", "yrInterp", "threshold")],
  function(smoothing, yrInterp, threshold)
    sum(run_peaks(smoothing, yrInterp, threshold)$is_significant))
print(as.data.frame(sens))
cat("primary: smoothing =", NOCA_SMOOTH_PRIMARY, " yrInterp =", NOCA_YRINTERP_PRIMARY,
    " threshold =", NOCA_THRESHOLD_PRIMARY, "(native NOCA/source-faithful)\n")

noca_primary = run_tapas_fire_detection(
  noca_char, "NOCA", "PantherPotholes", NOCA_YRINTERP_PRIMARY,
  NOCA_SMOOTH_PRIMARY, NOCA_THRESHOLD_PRIMARY,
  "active PaleoACES Bacon median chronology",
  "data/NOCA/NOCA_paleo/neotoma_macrocharcoal_52210.csv")
noca_peaks = noca_primary$peaks
if (sum(noca_peaks$is_significant) != 66L ||
    sum(noca_peaks$is_significant & noca_peaks$age_cal_yr_BP > 8200 &
          noca_peaks$age_cal_yr_BP <= 9200) != 6L)
  stop("Primary NOCA source-faithful peak catalog changed unexpectedly.")
write_csv(noca_peaks, out("fire_noca_peaks.csv"))
write_csv(noca_primary$series, out("fire_noca_tapas_series.csv"))
write_csv(noca_primary$events, out("fire_noca_tapas_events.csv"))
write_csv(noca_primary$settings, out("fire_noca_tapas_settings.csv"))
write_csv(sens, out("fire_noca_tapas_sensitivity.csv"))

# Join to the NOCA samples with the SAME rule as MORA: the nearest significant peak
# in the 50 yr before the sample.
noca_samples = read_csv(out("paleo_occ.csv"), show_col_types = FALSE) %>%
  filter(lake == "PantherPotholes") %>%
  distinct(period, plot_id, lake, site) %>%
  left_join(read_csv(out('paleo_sample_depths.csv'),show_col_types=FALSE) |>
    select(plot_id,year=median_age),by='plot_id',relationship='one-to-one')

# The nearest significant peak in the 50 yr before each sample. NOTE the right_join
# back onto noca_samples: the filter drops samples that matched a peak but none
# within 50 yr, so without it those samples vanish from paleo_fire entirely rather
# than being recorded as "no fire". (The MORA block above does the same thing via
# its own right_join.)
noca_matched = noca_samples %>%
  left_join(noca_peaks %>% filter(is_significant) %>%
              select(age_cal_yr_BP, peak_magnitude),
            by = join_by(year <= age_cal_yr_BP), relationship = "many-to-many") %>%
  filter(!is.na(age_cal_yr_BP), age_cal_yr_BP - year <= 50) %>%
  group_by(plot_id) %>% slice_min(age_cal_yr_BP, with_ties = FALSE) %>% ungroup() %>%
  select(plot_id, age_cal_yr_BP, peak_magnitude)

noca_fire = noca_samples %>%
  left_join(noca_matched, by = "plot_id") %>%
  transmute(period, plot_id, lake, year,
            fire_lake = ifelse(is.na(age_cal_yr_BP), "no_fire_record", "PantherPotholes"),
            fire_peak_magnitude = ifelse(is.na(peak_magnitude), 0, peak_magnitude),
            years_before_fire = ifelse(is.na(age_cal_yr_BP), 0, age_cal_yr_BP - year))
stopifnot(nrow(noca_fire) == nrow(noca_samples))

paleo_fire = bind_rows(paleo_fire, noca_fire)

# ONE row per sample, and the same samples the vegetation has. Without this the
# left_join in 11_cca.R silently multiplies rows: a plot_id appearing twice
# here makes that paleo sample count twice in the CCA.
stopifnot(!any(duplicated(paleo_fire$plot_id)))
paleo_occ_ids = read_csv(out("paleo_occ.csv"), show_col_types = FALSE)$plot_id
stopifnot(setequal(paleo_fire$plot_id, unique(paleo_occ_ids)))

write_csv(paleo_fire, out("paleo_fire.csv"))

cat("\npaleo_fire.csv: ", nrow(paleo_fire), " rows across ",
    n_distinct(paleo_fire$lake), " lakes\n", sep = "")
print(as.data.frame(paleo_fire %>% group_by(lake) %>%
  summarise(n = n(), with_fire = sum(fire_peak_magnitude > 0), .groups = "drop")))
cat("\nNOTE: MORA rows carry Dunwiddie's charcoal_fragments / needle_concentration /\n",
    "charred_needles (percentages, in-core) and the Walsh REGIONAL peaks from three\n",
    "OTHER lakes. NOCA rows carry in-core macrocharcoal peaks from its own core.\n",
    "The fire evidence is not of the same kind at the two sites - say so.\n", sep = "")

# =============================================================================
# 3. Four-lake accepted-event catalog and CharAnalysis reproduction
# =============================================================================
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({
  library(here); library(tidyverse); library(readxl); library(CharAnalysis)
  library(tapas); library(patchwork)
})
source(here("R/helpers/walsh_fire_functions.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))


EXPECTED_CHAR_VERSION = "2.0.3"
if (as.character(packageVersion("CharAnalysis")) != EXPECTED_CHAR_VERSION)
  stop("Official Walsh audit requires CharAnalysis ", EXPECTED_CHAR_VERSION,
       "; installed version is ", packageVersion("CharAnalysis"), ".")

INPUT_DIR = out("walsh_charanalysis_inputs")
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
# root-level Rplots.pdf is not created; the maintained audit figure below is
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
  char_out = capture_internal_graphics(CharAnalysis(inp$params))
  raw_results[[i]] = char_out
  results[[i]] = extract_charanalysis_result(char_out, s$lake)
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

tapas_counts = read_csv(out("fire_walsh.csv"), show_col_types = FALSE) |>
  filter(is_significant) |> count(lake, name = "tapas_episodes")
software_comparison = regression |> left_join(tapas_counts, by = "lake") |>
  mutate(tapas_minus_official_r = tapas_episodes - official_r_episodes,
         tapas_status = "primary harmonized source catalog")

# The downstream source catalog is all-tapas. Official CharAnalysis objects
# above remain a publication-reproduction audit and never replace these events.
active_paths = out(c(
  "fire_mora_tapas_series.csv", "fire_mora_tapas_events.csv",
  "fire_mora_tapas_settings.csv", "fire_noca_tapas_series.csv",
  "fire_noca_tapas_events.csv", "fire_noca_tapas_settings.csv"))
if (!all(file.exists(active_paths)))
  stop("Run R/pipeline/09_fire_records.R and R/pipeline/09_fire_records.R first.")
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

write_csv(settings, out("walsh_charanalysis_settings.csv"))
write_csv(regression, out("walsh_charanalysis_table3_audit.csv"))
write_csv(software_comparison, out("walsh_charanalysis_software_comparison.csv"))
write_csv(tapas_settings, out("holocene_fire_source_settings.csv"))
write_csv(all_continuous, out("holocene_fire_source_series.csv"))
write_csv(all_events, out("holocene_fire_source_events.csv"))

tapas_desc = system.file("DESCRIPTION", package = "tapas")
tapas_manifest_paths = c(active_paths,
  out("holocene_fire_source_settings.csv"),
  out("holocene_fire_source_series.csv"),
  out("holocene_fire_source_events.csv"))
tapas_manifest = tibble(
  engine = "tapas", version = as.character(packageVersion("tapas")),
  analytical_role = "primary harmonized fire-event detector",
  package_description_md5 = unname(tools::md5sum(tapas_desc)),
  file = normalizePath(tapas_manifest_paths),
  md5 = unname(tools::md5sum(tapas_manifest_paths)))
write_csv(tapas_manifest, out("holocene_fire_tapas_manifest.csv"))

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
  pdf(fig("supplementary", "fig_walsh_charanalysis_reproduction.pdf"), width = 13,
      height = 9, onefile = TRUE); walk(pages, print); dev.off()
}

cat("Official CharAnalysis episode counts:\n")
print(as.data.frame(regression))
cat("Wrote source series and accepted events for the independent era stage.\n")
