# =============================================================================
# 000_PALEO_c_fire.R - charcoal and charred needles per paleo sample
# =============================================================================
# Paleo fire preparation; see docs/WORKFLOW.md.
#
# RUN AFTER 000_PALEO_b_vegetation.R. It reads output/paleo_macrofossil_long.csv,
# which b writes: the harmonised MORA long table with Percentage and the three
# fire categories still present. They are only separable partway through b's
# harmonisation, so re-deriving them here would duplicate that logic and let the
# two drift apart.
#
# MORA uses the Dunwiddie charcoal/charred-needle records; NOCA uses the Neotoma
# macrocharcoal series added below. Both sites receive one fire row per sample.
#
# Output: output/paleo_fire.csv
# =============================================================================

library(readr)
library(tidyverse)
library(here)

macro_long = read_csv(here("output", "paleo_macrofossil_long.csv"),
                      show_col_types = FALSE)
fire_walsh = read_csv(here("output", "fire_walsh.csv"), show_col_types = FALSE)

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
  mutate(plot_id = paste0(site, "_", year, "_BP"))%>%
  mutate(period = "paleo")%>%
  rename(lake = site)

paleo_fire =
  paleo_fire %>%
  mutate(charred_needles = ifelse(is.na(charred_needles), 0, charred_needles),
         fire_peak_magnitude = ifelse(is.na(fire_peak_magnitude), 0, fire_peak_magnitude),
         years_before_fire = ifelse(is.na(years_before_fire), 0, years_before_fire),
         fire_lake = ifelse(is.na(fire_lake), "no_fire_record", fire_lake)
         )

# -----------------------------------------------------------------------------
# Collapse to ONE row per plot_id
# -----------------------------------------------------------------------------
# plot_id is built from the AGE, so several core DEPTHS whose Bacon ages round to
# the same year share one plot_id. At ReflectionPond, 47 / 49 / 64 cm all date to
# 3641 cal BP - the age-depth model is flat over that 17 cm because the core has
# no radiocarbon (see the Reflection Pond caveat in Cores/SOURCES_MORA.md).
#
# 000_PALEO_b_vegetation.R already collapses exactly this collision on the
# vegetation side ("present if present in any contributing row"), so paleo_occ has
# one row per sample while paleo_fire had three. Left unmerged, the left_join in
# 04_cca_model.R multiplies that sample's env row threefold and it is counted
# three times in the CCA.
#
# Two different rules, because the columns are two different kinds of thing:
#   fire_peak_magnitude  max  - a peak at ANY contributing depth means the sample
#                              is burnt; mirrors b's any(occurrence == 1)
#   the Dunwiddie percentages  mean - concentrations measured on depths that are
#                              contemporaneous within dating resolution, so the
#                              honest summary is their average, not the largest
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
# data/NOCA/NOCA_paleo/SOURCES.md.
#
# 870 samples, contiguous 1 cm, on exactly the same depths as the macrofossils, so
# fire and vegetation are measured on the SAME samples. Counts of 150-1000 um
# charcoal plus sample volume, so tapas can build concentration itself.
#
# AGES: ours, not Neotoma's. Matched on depth to 000_PALEO_a's Bacon run, exactly
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
write_csv(noca_peaks, here("output", "fire_noca_peaks.csv"))
write_csv(noca_primary$series, here("output/fire_noca_tapas_series.csv"))
write_csv(noca_primary$events, here("output/fire_noca_tapas_events.csv"))
write_csv(noca_primary$settings, here("output/fire_noca_tapas_settings.csv"))
write_csv(sens, here("output/fire_noca_tapas_sensitivity.csv"))

# Join to the NOCA samples with the SAME rule as MORA: the nearest significant peak
# in the 50 yr before the sample.
noca_samples = read_csv(here("output", "paleo_occ.csv"), show_col_types = FALSE) %>%
  filter(lake == "PantherPotholes") %>%
  distinct(period, plot_id, lake, site) %>%
  mutate(year = as.numeric(regmatches(plot_id,
                  regexpr("-?[0-9.]+(?=_BP$)", plot_id, perl = TRUE))))

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
# left_join in 04_cca_model.R silently multiplies rows: a plot_id appearing twice
# here makes that paleo sample count twice in the CCA.
stopifnot(!any(duplicated(paleo_fire$plot_id)))
paleo_occ_ids = read_csv(here("output", "paleo_occ.csv"), show_col_types = FALSE)$plot_id
stopifnot(setequal(paleo_fire$plot_id, unique(paleo_occ_ids)))

write_csv(paleo_fire, here("output", "paleo_fire.csv"))

cat("\npaleo_fire.csv: ", nrow(paleo_fire), " rows across ",
    n_distinct(paleo_fire$lake), " lakes\n", sep = "")
print(as.data.frame(paleo_fire %>% group_by(lake) %>%
  summarise(n = n(), with_fire = sum(fire_peak_magnitude > 0), .groups = "drop")))
cat("\nNOTE: MORA rows carry Dunwiddie's charcoal_fragments / needle_concentration /\n",
    "charred_needles (percentages, in-core) and the Walsh REGIONAL peaks from three\n",
    "OTHER lakes. NOCA rows carry in-core macrocharcoal peaks from its own core.\n",
    "The fire evidence is not of the same kind at the two sites - say so.\n", sep = "")
