# =============================================================================
# 10_cca.R - the pooled CCA and everything derived from it. NO FIGURES.
# =============================================================================
# This file defines the ordination without rendering figures and is sourced by
# the downstream analysis and figure stages.
#
# THE MODEL: one pooled CCA trained on matched MORA + NOCA "past" plots, constrained
# by MSpT + MWT + SP + WP. "present" and "paleo" samples are projected into it -
# they do not calibrate it. Because there is a single ordination, positions and
# lengths are directly comparable across both sites and both eras.
#
# Defines:
#   cca_model                          the pooled CCA
#   species_past_final, env_past_final  the calibration matrices
#   predicted_present / projected_present, predicted_paleo / projected_paleo
#   comparison_df   per-sample predicted (LC) + observed (WA) positions, all eras
#   env, species_complete, site_lookup, keep_species
#   cca_sample_eligibility / cca_pair_eligibility  exclusion reasons and membership
#   cca_eligibility_counts / cca_exclusion_summary  report tables, before fitting
#   species_past_paired / env_past_paired  legacy endpoints of valid modern pairs
#   color_mt, color_site_era, color_era_pp
#
library(here)
library(tidyverse)
library(vegan)
conflicted::conflicts_prefer(dplyr::select, dplyr::filter, dplyr::lag, .quiet = TRUE)
source(here("R/helpers/config.R"), local = TRUE)

# Run configuration ----------------------------------------------------------
# EVERY knob for this model is here, and every one is `if (!exists())`, so a
# calling script can set any of them before source()-ing to run a variant
# without editing this file:
#
#   count.thr = 10; source(here("R/pipeline/10_cca.R"))
#
# Taxus brevifolia and Acer circinatum are removed by the documented understory
# rule in R/pipeline/09_species_occurrences.R. The former manual exclusion
# of Pinus ponderosa was reversed on 2026-10-08; it now follows the ordinary
# frequency rule below. There is one active model and no extra exclusion by default.
if (!exists("extra_exclude")) extra_exclude = character(0)
if (!exists("cca_suffix"))    cca_suffix    = ""

# SPECIES INCLUSION THRESHOLD --------------------------------------------------
# A species is dropped only if it occurs in fewer than count.thr plots in EVERY
# site x period group - so a species common in one group survives even if it is
# rare in the others. Set it here, not in the consolidation script, because the
# whole point is to be able to sweep it:
#
#   for (thr in c(10, 15, 20, 25, 30)) { count.thr = thr; source(...); ... }
#
# The evidence for choosing it - plots per species per site x period - is printed
# and plotted by R/pipeline/09_species_occurrences.R. On the consolidated species
# set after the 2026 NOCA correction and the BAK487/BEAV6061 exclusions:
# 10 and 15 -> 15 species, 20 -> 13, 25 -> 11, and 30 -> 10.
#
# SET TO 20 by Billur, 2026-08-13. History: 25 (inherited) -> 10 -> 20.
#
# 10 was chosen as the low end of a plateau (10 and 15 give the identical
# 15-species set) and to add calibration plots. It was reverted to 20 because
# the resulting ordination was unsatisfactory. After the corrected NOCA trees,
# the TWO species that 10 admits and 20 does not are:
#
#                     MORA_paleo  MORA_past  MORA_present  NOCA_paleo  NOCA_past  NOCA_present
#   Alnus rubra            0         15           16            0          11          18
#   Acer macrophyllum      0          0            4            0          17          19
#
# Both are zero in both paleo columns. They exist only in the survey
# plots, so they widen the CALIBRATION while contributing nothing whatever to the
# Holocene arm - they add unconstrained variance to the axes the Holocene
# samples are projected onto. (Pinus albicaulis is NOT among them; it survives at
# 20. An earlier archived plan listed it as a fourth species gained at 10,
# which was wrong.) The 2026 NOCA tree correction raised Abies grandis from 19
# to 22 NOCA-present plots, so it now legitimately survives threshold 20.
#
# Historical threshold comparison: constrained inertia rose from 13.4% to 16.3%.
# These are historical diagnostics, not the current fit's summary. That is NOT
# the justification and must not be quoted as one: it rises mechanically as
# species are removed, because there is less total inertia left to explain. The
# justification is the one above - which species, and whether they exist in both
# arms.
#
# ⚠⚠ DO NOT RAISE count.thr TO 21 OR ABOVE WITHOUT READING THIS.
# Pinus albicaulis survives at exactly 20, by ONE PLOT: its largest group count is
# NOCA past = 20, and a species is kept only while some group reaches count.thr.
# It is KEPT DELIBERATELY (Billur, 2026-08-13) because whitebark pine is a listed
# species - ESA-threatened, IUCN endangered - so its presence/absence is of
# interest in its own right, independent of what it does to the ordination.
# At count.thr = 21 it disappears silently. No other retained species is anywhere
# near the edge: the next-lowest max group count is Picea engelmannii at 26, then
# a jump to 68. So count.thr = 20 is now pinned by this decision as well as by
# the axis-interpretability argument above.
if (!exists("count.thr")) count.thr = CCA_COUNT_THRESHOLD

# ⚠ WHAT KEEPING IT COSTS - to be reported, not fixed:
# The following numbers record the historical threshold decision; current
# coordinates and inertia must be read from the rebuilt model/report.
#   occurrences  MORA 0 paleo / 0 past / 2 present | NOCA 0 paleo / 20 past / 7 present
#   position     CCA1 3.57, CCA2 4.39 - the extreme of BOTH axes; the next most
#                extreme are Abies lasiocarpa (1.80) and Pinus contorta (2.75)
#   share        14.9% of the constrained inertia, the largest of any species
# It is not detected in either paleo record and is concentrated at NOCA
# (27 survey-date occurrences vs 2 at MORA). Its position affects the CCA1-CCA2
# plane in which distances are measured. These features are not exclusion rules:
# Pinus ponderosa's former exclusion for similar reasons was reversed on
# 2026-10-08. Both species now follow the same frequency-selection rule.

# ORDINATION SCALING -----------------------------------------------------------
# "sites" (vegan scaling 1): SITE scores are scaled by the eigenvalues, species
# scores are left unscaled. Chosen because every quantity in this analysis is a
# distance or a displacement between SAMPLE positions, and scaling 1 is the
# scaling in which Euclidean distance among samples represents their chi-square
# distance. Under "none"/"species" (0/2) sites are in standard coordinates, where
# each axis carries equal metric weight regardless of its eigenvalue - so CCA2
# would count as much per unit of displacement as CCA1 despite different inertia.
#
# Nothing is lost on the species side: with scaling 1 the species scores are
# left unscaled, i.e. bit-identical to scaling 0, and species rank order and sign
# along each axis are identical under these positive scalings. Two-axis angles
# are not invariant to unequal axis scaling; all metrics use the selected scaling.
#
# Set cca_scaling = "sites" with hill = TRUE to express site scores in SD units
# of species turnover instead (gradient lengths CCA1 3.28 SD, CCA2 3.96 SD).
if (!exists("cca_scaling")) cca_scaling = "sites"
if (!exists("cca_hill"))    cca_hill    = FALSE

color_mt       = c("MORA" = "#648FFF", "NOCA" = "#FE6100")
color_site_era = c("MORA.anthropocene" = "#648FFF", "NOCA.anthropocene" = "#FE6100",
                   "MORA.holocene"     = "#648FFF", "NOCA.holocene"     = "#FE6100")
color_era_pp   = c("anthropocene" = "#DC267F", "holocene" = "#785EF0")

# -----------------------------------------------------------------------------
# CCA ELIGIBILITY POLICY: resolve absence BEFORE fitting or projecting
# -----------------------------------------------------------------------------
# Species selection remains here, with the configured >= count.thr rule.
# An all-zero retained-taxon row has no observed WA position (0/0), including
# genuine recorded absence. Never assign it the ordination origin or keep its
# climate prediction in a paired WA/LC comparison.
#
# The preparation section below applies this policy after climate and species
# matrices exist, but BEFORE cca(). It distinguishes cleaned recorded absence,
# consolidation exclusions, frequency exclusions, and unavailable climate.
# Legacy calibration and modern comparisons use the SAME valid matched plot IDs
# at both dates (decision 2026-10-08); paleo WA and LC use the SAME samples.
# Recorded loss at resurvey is absence of the study's recorded tree taxa, not
# proof of biological extinction. A zero macrofossil sample is non-detection.
# Counts are unique plots/samples, not species records, age draws or time bins.
cca_classify_samples = function(cleaned, consolidated, selected_taxa,
                                calibration_taxa, climate, variables, excluded = NULL) {
  # `excluded`: site and plot_id of plots left out of the whole analysis (the
  # MORA plots burned between the surveys); classified first, at both dates.
  excluded_keys = if (is.null(excluded)) character(0) else paste(excluded$site, excluded$plot_id)
  keys = c("site", "era", "period", "plot_id")
  if (anyDuplicated(climate[keys])) stop("Duplicate climate sample keys in CCA eligibility.")
  for (x in list(cleaned, consolidated)) {
    if (anyNA(x[c(keys, "species", "occurrence")]) ||
        any(!x$occurrence %in% 0:1)) stop("CCA eligibility requires identified binary occurrence records.")
  }
  count_taxa = function(x, name, taxa = unique(x$species)) {
    x %>% filter(occurrence == 1, species %in% taxa) %>%
      group_by(across(all_of(keys))) %>%
      summarize(!!name := n_distinct(species), .groups = "drop")
  }
  out = bind_rows(cleaned %>% distinct(across(all_of(keys))),
                  climate %>% distinct(across(all_of(keys)))) %>% distinct() %>%
    left_join(cleaned %>% distinct(across(all_of(keys))) %>%
                mutate(has_occurrence_record = TRUE), by = keys) %>%
    left_join(count_taxa(cleaned, "cleaned_taxa"), by = keys) %>%
    left_join(count_taxa(consolidated, "consolidated_taxa"), by = keys) %>%
    left_join(count_taxa(consolidated, "selected_taxa", selected_taxa), by = keys) %>%
    left_join(count_taxa(consolidated, "calibration_taxa", calibration_taxa), by = keys) %>%
    left_join(climate %>% select(all_of(c(keys, variables))) %>%
                mutate(climate_complete = if_all(all_of(variables), is.finite)) %>%
                select(all_of(keys), climate_complete), by = keys) %>%
    mutate(across(ends_with("_taxa"), ~ replace_na(.x, 0L)),
           has_occurrence_record = replace_na(has_occurrence_record, FALSE),
           climate_complete = replace_na(climate_complete, FALSE))
  legacy = out %>% filter(period == "past") %>%
    select(site, plot_id, legacy_cleaned_taxa = cleaned_taxa)
  out %>% left_join(legacy, by = c("site", "plot_id")) %>%
    mutate(
      reason_code = case_when(
        era == "anthropocene" & paste(site, plot_id) %in% excluded_keys ~ "burned",
        !has_occurrence_record ~ "missing_occurrence",
        cleaned_taxa == 0 ~ "no_recorded_taxa",
        consolidated_taxa == 0 ~ "consolidation",
        selected_taxa == 0 ~ "species_selection",
        calibration_taxa == 0 ~ "no_calibration_taxa",
        !climate_complete ~ "climate",
        TRUE ~ "included"),
      reason = case_when(
        reason_code == "burned" ~ "Burned between the surveys (left out of the analysis)",
        reason_code == "missing_occurrence" ~ "No cleaned occurrence record",
        reason_code == "no_recorded_taxa" & period == "past" ~ "No tree taxa recorded at legacy",
        reason_code == "no_recorded_taxa" & period == "present" &
          coalesce(legacy_cleaned_taxa, 0L) > 0 ~ "Loss of all recorded tree-taxon presence at resurvey",
        reason_code == "no_recorded_taxa" & period == "present" ~ "No tree taxa recorded at resurvey",
        reason_code == "no_recorded_taxa" ~ "No tree taxa detected in paleo sample",
        reason_code == "consolidation" ~ "Only taxa excluded during consolidation",
        reason_code == "species_selection" ~ "Only taxa excluded by CCA species selection",
        reason_code == "no_calibration_taxa" ~ "Only taxa absent from legacy calibration",
        reason_code == "climate" ~ "Missing or nonfinite CCA climate constraints",
        TRUE ~ "Included"),
      eligible = reason_code == "included") %>%
    arrange(era, site, plot_id, period)
}

cca_pair_samples = function(samples) {
  past = samples %>% filter(period == "past") %>%
    select(site, plot_id, legacy_eligible = eligible,
           legacy_reason_code = reason_code, legacy_reason = reason)
  present = samples %>% filter(period == "present") %>%
    select(site, plot_id, resurvey_eligible = eligible,
           resurvey_reason_code = reason_code, resurvey_reason = reason)
  full_join(past, present, by = c("site", "plot_id")) %>%
    mutate(
      calibration_included = coalesce(legacy_eligible & resurvey_eligible, FALSE),
      comparison_included = coalesce(legacy_eligible & resurvey_eligible, FALSE),
      # One primary reason per excluded pair: legacy first, then resurvey.
      # The sample audit keeps BOTH dates' local reasons and taxon counts.
      exclusion_period = case_when(is.na(legacy_eligible) | !legacy_eligible ~ "past",
                                    is.na(resurvey_eligible) | !resurvey_eligible ~ "present",
                                    TRUE ~ NA_character_),
      reason_code = case_when(is.na(legacy_eligible) | is.na(resurvey_eligible) ~ "missing_period",
                              !legacy_eligible ~ legacy_reason_code,
                              !resurvey_eligible ~ resurvey_reason_code,
                              TRUE ~ "included"),
      reason = case_when(is.na(legacy_eligible) ~ "No matched legacy observation",
                         is.na(resurvey_eligible) ~ "No matched resurvey observation",
                         !legacy_eligible ~ legacy_reason,
                         !resurvey_eligible ~ resurvey_reason,
                         TRUE ~ "Included")) %>% arrange(site, plot_id)
}

# -----------------------------------------------------------------------------
# Occurrence data
# -----------------------------------------------------------------------------
# ONE input, already consolidated. R/pipeline/09_species_occurrences.R binds the
# three cleaned sources and applies every cross-site taxonomic decision - the
# understory removal, the Populus/Picea/Abies harmonisation, the non-taxa drops -
# with the evidence for each written out beside it. Run that script if any of
# those decisions changes; do NOT re-derive them here, and do not re-run the
# cleaning scripts, which have side effects.
#
# The ad-hoc filter that used to live on this line
#     filter(!species %in% c("unknown", "Abies sp.", "Salix sp."))
# is now part of that script, where it is justified rather than asserted.
occ_consolidated = read_csv(out("occ_consolidated.csv"), show_col_types = FALSE) %>%
  select(period, plot_id, species, occurrence, site, era)
# The MORA plots burned between the two surveys leave the whole analysis here,
# before species selection (Bills, 11 Nov 2026). There are two, too few for a
# MORA fire comparison, and in the shared Anthropocene fire term they tied the
# burned effect to MORA's level. They keep their own exclusion reason below, so
# the plot-selection figure counts them.
burned_mora = read_csv(out("MORA_plot_info_fire.csv"), show_col_types = FALSE) %>%
  filter(burnt) %>% transmute(site = "MORA", plot_id)
occ_consolidated = occ_consolidated %>%
  filter(!(era == "anthropocene" & paste(site, plot_id) %in% paste(burned_mora$site, burned_mora$plot_id)))
occ = occ_consolidated

# Species selection: drop species occurring in fewer than count.thr plots in
# every site x period, plus any run-specific exclusions.
#
# TSUGA HETEROPHYLLA IS NOW KEPT (decided 2026-08-13). It had been dropped by
# hand since the earliest version of this analysis. Three reasons for reversing:
#
# 1. The exclusion was never justified. The original model had the bare
#    line with no comment; a historical species-count diagnostic also
#    recorded that its exclusion was undocumented. The "range truncation, see
#    HilleRisLambers et al. 2015 Appendix B" note that used to sit here was
#    reconstructed after the fact, not carried over from the original author.
#
# 2. That citation does not single it out. HilleRisLambers et al. 2015 says
#    elevational range limits were estimated "for three species (Abies amabilis,
#    Callitropsis nootkatensis, Tsuga mertensiana), but not for the three species
#    whose ranges extend to elevations below the lowest elevation of the park
#    (Pseudotsuga menziesii, Thuja plicata, Tsuga heterophylla)". It names THREE
#    truncated species; this script dropped one and kept the other two, which are
#    among the most abundant in the dataset. That is not a defensible reading.
#
# 3. The data do not support it. At MORA (lowest plot 541 m) the species sitting
#    on the lower bound are Abies amabilis, Tsuga heterophylla, Pseudotsuga
#    menziesii AND Thuja plicata - truncation is a property of where the plots
#    stop, not of this species. Its MORA median (1091 m) is HIGHER than Thuja
#    plicata's (907) and Pseudotsuga's (1040), so it is mid-gradient, not edge-
#    clinging. It is also one of the best-represented taxa in the whole study:
#    281/283 MORA survey plots, 91/108 NOCA, and present in BOTH paleo records
#    (MORA 54, NOCA 179 samples).
#
# The paper's concern is estimating where a range EDGE lies, which needs the
# whole range sampled. This analysis ordinates composition, where a species whose
# range continues past the sampled window is ordinary rather than disqualifying.
#
occ_summary = occ %>%
  filter(occurrence == 1) %>%
  group_by(site, period, species) %>%
  summarize(count = n(), .groups = "drop") %>%
  pivot_wider(names_from = c("site", "period"), values_from = "count", values_fill = 0)

# count.thr is set in the run-configuration block at the top of this file.
# NOCA_paleo belongs here and was missing: the condition dates from when
# PantherPotholes had no macrofossil data, so a species common ONLY in NOCA's
# Holocene record would have been dropped. Verified that adding it changes
# nothing today - both versions drop the same species - so this is a latent bug
# made correct by construction, not a change to the current model.
takeoutsp = occ_summary %>%
  filter(MORA_past < count.thr & MORA_present < count.thr &
           NOCA_past < count.thr & NOCA_present < count.thr &
           MORA_paleo < count.thr & NOCA_paleo < count.thr) %>%
  pull(species) %>% unique()
takeoutsp = c(takeoutsp, extra_exclude)
occ = occ %>% filter(!species %in% takeoutsp)

# -----------------------------------------------------------------------------
# Fire and climate
# -----------------------------------------------------------------------------
NOCA_plot_info_fire = read_csv(out("NOCA_plot_info_fire.csv"), show_col_types = FALSE)
MORA_plot_info_fire = read_csv(out("MORA_plot_info_fire.csv"), show_col_types = FALSE)

# Paleo fire now exists for BOTH sites - NOCA's came from Neotoma dataset 52210
# (see report/details/03_chronology_sources_NOCA.md), so the site is read from the lake instead of being
# hardcoded to "MORA" as it was while PantherPotholes had no charcoal.
# The two sites' fire evidence is not the same KIND (MORA = in-core Dunwiddie
# percentages plus a REGIONAL Walsh proxy from three other lakes; NOCA = in-core
# macrocharcoal from its own core) - that is a reporting caveat, not a data fix.
paleo_info_fire = read_csv(out("paleo_fire.csv"), show_col_types = FALSE) %>%
  mutate(burnt = fire_peak_magnitude > 0,
         site  = if_else(lake == "PantherPotholes", "NOCA", "MORA"),
         era   = "holocene")

fire_summary = bind_rows(
  NOCA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "NOCA"),
  MORA_plot_info_fire %>% select(plot_id, burnt) %>% mutate(site = "MORA")
) %>%
  mutate(era = "anthropocene") %>%
  bind_rows(paleo_info_fire %>% select(plot_id, burnt, site, era))

# -----------------------------------------------------------------------------
# Anthropocene climate: raw monthly -> CCA variables -> one value per survey window
# -----------------------------------------------------------------------------
# Replaces the retired climate summary, which carried a FIXED 1981-86
# "past" climatology that
# post-dated MORA's survey by ~8 yr and NOCA's by ~2 - unequally, between the two
# sites the whole study differences against each other.
#
# 04_modern_climate.R / 04_modern_climate.R now write RAW MONTHLY tasmin/tasmax/pr
# for each plot over that site's own survey window (max survey year and the five
# before it). derive_climate_vars() turns them into the CCA variables and is the
# SAME function 07_paleo_climate.R uses, so a season cannot mean one thing in
# the Holocene arm and another in the Anthropocene arm.
source(here("R/helpers/climate_variables.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
plot_years = read_plot_years()

climate_monthly = bind_rows(
  read_csv(out("MORA_climate.csv"), show_col_types = FALSE),
  read_csv(out("NOCA_climate.csv"), show_col_types = FALSE)
) %>% restrict_modern_months(plot_years)

# site is folded into the grouping key because derive_climate_vars() groups by
# unit x period, and "past" means a different set of years at the two sites.
climate_annual = climate_monthly %>%
  transmute(unit = plot_id, period = paste(site, period, sep = "."),
            variable, time = year, month, value) %>%
  derive_climate_vars(winter_shift = TRUE) %>%
  restrict_modern_seasons(plot_years) %>%
  # winter_shift moves each December into the FOLLOWING winter, so the last
  # December of a window opens a trailing year that holds nothing else. Restricting
  # to the plot-specific season-years removes it. Dropping
  # rows where every CCA variable is NA removes it, and removes the lead-in year
  # for the same reason, without hardcoding the windows a third time.
  filter(if_any(all_of(CCA_VARIABLES), ~ !is.na(.x)))

# Average the surviving years of each window. n_* records HOW MANY complete
# season-years each variable actually got. The missing January 1979 removes that
# first winter, leaving 10 complete legacy MWT/WP years; spring and summer retain
# all 11 years. These counts stay visible rather than being silently assumed.
climate_summary = climate_annual %>%
  group_by(unit, period) %>%
  # both statistics in ONE across(): a second across() referring to MWT would read
  # the mean the first one had just created, and every count would come out as 1.
  summarize(across(all_of(union(CCA_VARIABLES, CLIMATE_DISPLAY_VARIABLES)),
                   list(v = ~ mean(.x, na.rm = TRUE), n = ~ sum(!is.na(.x))),
                   .names = "{.fn}|{.col}"),
            .groups = "drop") %>%
  rename_with(~ sub("^v\\|", "",   .x), starts_with("v|")) %>%
  rename_with(~ sub("^n\\|", "n_", .x), starts_with("n|")) %>%
  separate_wider_delim(period, ".", names = c("site", "period")) %>%
  rename(plot_id = unit) %>%
  mutate(era = "anthropocene")

if (any(as.matrix(climate_summary %>% filter(period == "present") %>%
      select(starts_with("n_"))) != 6L))
  stop("Every modern CCA climate constraint requires six complete season-years.")

cat("\nAnthropocene climate - complete season-years per window:\n")
print(as.data.frame(climate_summary %>% group_by(site, period) %>%
  summarize(plots = n(), across(starts_with("n_"), max), .groups = "drop")))

paleo_climate_summary = read_csv(out("paleo_env.csv"), show_col_types = FALSE)

env = bind_rows(
  climate_summary %>% select(site, era, period, plot_id, all_of(CCA_VARIABLES)),
  paleo_climate_summary %>% select(site, era, period, plot_id, all_of(CCA_VARIABLES))
) %>%
  left_join(fire_summary, by = c("plot_id", "site", "era"))

# The fire join must not multiply rows. paleo_fire's plot_id is built from the
# AGE, so core depths whose Bacon ages round to the same year collide - three
# ReflectionPond depths at 3641 cal BP did, and tripled that sample in the CCA
# until 08_fire_records.R was made to collapse them the way the vegetation is.
stopifnot(!any(duplicated(env %>% select(plot_id, site, era, period))))

site_lookup = env %>% distinct(plot_id, site)

# -----------------------------------------------------------------------------
# Species x plot matrices
# -----------------------------------------------------------------------------
all_combinations = expand_grid(
  plot_id = unique(occ$plot_id),
  period  = unique(occ$period),
  species = unique(occ$species)
)
species_complete = all_combinations %>%
  left_join(occ, by = c("plot_id", "period", "species")) %>%
  mutate(occurrence = replace_na(occurrence, 0)) %>%
  select(plot_id, period, species, occurrence)

make_wide = function(per) {
  species_complete %>%
    filter(period == per) %>%
    group_by(plot_id, species) %>%
    summarize(occurrence = as.integer(sum(occurrence) > 0), .groups = "drop") %>%
    pivot_wider(names_from = species, values_from = occurrence, values_fill = 0) %>%
    column_to_rownames("plot_id")
}
# This filter is where 30 paleo samples used to vanish without trace: before the
# the corrected paleo-climate download they had a climate ROW whose values were all NA, so a
# row-count check passed while a complete-case filter quietly removed them. It should
# now drop NOTHING - so it says what it drops instead of doing it silently.
make_env = function(per) {
  e = env %>%
    filter(period == per) %>%
    select(plot_id, all_of(CCA_VARIABLES)) %>%
    distinct() %>%
    column_to_rownames("plot_id")
  ok = rowSums(!is.finite(as.matrix(e))) == 0L
  if (any(!ok))
    message("make_env('", per, "'): DROPPED ", sum(!ok), " of ", nrow(e),
            " plots with missing/nonfinite climate - ",
            paste(head(rownames(e)[!ok], 5), collapse = ", "),
            if (sum(!ok) > 5) ", ..." else "")
  e[ok, , drop = FALSE]
}

species_past  = make_wide("past");    env_past  = make_env("past")
species_present = make_wide("present"); env_present = make_env("present")
species_paleo = make_wide("paleo");   env_paleo = make_env("paleo")

# -----------------------------------------------------------------------------
# Prepare eligible calibration, paired modern comparisons and paleo projections
# -----------------------------------------------------------------------------
# Determine candidate model taxa from eligible legacy rows, then restrict the
# fitted calibration to plots with eligible observations at BOTH dates.
# The whole cleaned universe is kept for the exclusion audit, including plots
# that disappear entirely from the consolidated occurrence table.
common_past = intersect(rownames(species_past), rownames(env_past))
common_past = common_past[rowSums(species_past[common_past, , drop = FALSE]) > 0]
keep_species = colnames(species_past)[colSums(species_past[common_past, , drop = FALSE]) > 0]

cleaned_occ = bind_rows(
  read_csv(out("MORA_occ.csv"), show_col_types = FALSE) %>%
    mutate(site = "MORA", era = "anthropocene"),
  read_csv(out("NOCA_occ.csv"), show_col_types = FALSE) %>%
    mutate(site = "NOCA", era = "anthropocene"),
  read_csv(out("paleo_occ.csv"), show_col_types = FALSE)
) %>% select(site, era, period, plot_id, species, occurrence)

# Recheck eligibility if pairing leaves a taxon absent from calibration. Such a
# taxon cannot supply WA projections in this fitted model. The frequency rule
# itself still uses the existing site-by-period counts above.
repeat {
  cca_sample_eligibility = cca_classify_samples(
    cleaned_occ, occ_consolidated, unique(occ$species), keep_species,
    env, CCA_VARIABLES, excluded = burned_mora)
  cca_pair_eligibility = cca_pair_samples(cca_sample_eligibility)
  present_pairs = cca_pair_eligibility %>% filter(comparison_included) %>% pull(plot_id)
  present_pairs = rownames(species_present)[rownames(species_present) %in% present_pairs]
  if (!length(present_pairs)) stop("CCA calibration requires eligible matched plots at both dates.")
  paired_species = species_past[present_pairs, keep_species, drop = FALSE]
  fitted_taxa = colnames(paired_species)[colSums(paired_species) > 0]
  if (identical(fitted_taxa, keep_species)) break
  keep_species = fitted_taxa
}
common_paleo = cca_sample_eligibility %>%
  filter(period == "paleo", eligible) %>% pull(plot_id)
common_paleo = rownames(species_paleo)[rownames(species_paleo) %in% common_paleo]
stopifnot(setequal(common_past, cca_sample_eligibility %>%
                    filter(period == "past", eligible) %>% pull(plot_id)),
          !anyDuplicated(present_pairs), !anyDuplicated(common_paleo))

# Fit on exactly the matched legacy endpoints used by BOTH observed and
# predicted comparisons. No other eligible legacy plots enter the CCA fit or
# its climate-SD reference.
species_past_final = species_past[present_pairs, keep_species, drop = FALSE]
env_past_final = env_past[present_pairs, CCA_VARIABLES, drop = FALSE]
species_past_paired = species_past_final
env_past_paired = env_past_final
species_present_final = species_present[present_pairs, keep_species, drop = FALSE]
env_present_final = env_present[present_pairs, CCA_VARIABLES, drop = FALSE]
species_paleo = species_paleo[common_paleo, keep_species, drop = FALSE]
env_paleo = env_paleo[common_paleo, CCA_VARIABLES, drop = FALSE]

cca_sample_eligibility = cca_sample_eligibility %>%
  left_join(cca_pair_eligibility %>%
              select(site, plot_id, pair_included = comparison_included,
                     pair_exclusion_period = exclusion_period,
                     pair_reason = reason), by = c("site", "plot_id")) %>%
  mutate(calibration_included = period == "past" & coalesce(pair_included, FALSE),
         comparison_included = if_else(period == "paleo", eligible,
                                       coalesce(pair_included, FALSE)),
         comparison_reason = if_else(period == "paleo", reason, pair_reason))

cca_eligibility_units = bind_rows(
  cca_pair_eligibility %>%
    transmute(era = "anthropocene", site, use = "Legacy calibration", plot_id,
              exclusion_period, reason_code, reason, included = calibration_included),
  cca_pair_eligibility %>%
    transmute(era = "anthropocene", site, use = "Modern paired comparison",
              plot_id, exclusion_period, reason_code, reason,
              included = comparison_included),
  cca_sample_eligibility %>% filter(period == "paleo") %>%
    transmute(era, site, use = "Paleo projection", plot_id,
              exclusion_period = period, reason_code, reason, included = eligible))
cca_eligibility_counts = cca_eligibility_units %>%
  group_by(era, site, use) %>%
  summarize(input_units = n(), excluded_units = sum(!included),
            included_units = sum(included), .groups = "drop")
cca_exclusion_summary = cca_eligibility_units %>% filter(!included) %>%
  count(era, site, use, exclusion_period, reason_code, reason, name = "excluded_units")
cat("\nCCA eligibility BEFORE fitting/projection (unique plots or paleo samples):\n")
print(as.data.frame(cca_eligibility_counts), row.names = FALSE)
cat("\nExclusion reasons (each plot/sample counted once within each use):\n")
print(as.data.frame(cca_exclusion_summary %>% select(-reason_code)), row.names = FALSE)
# Every primary model invocation regenerates these tables. Threshold variants
# retain their own in-memory audit and cannot overwrite the primary report.
if (count.thr == CCA_COUNT_THRESHOLD && !length(extra_exclude) && !nzchar(cca_suffix)) {
  write_csv(cca_sample_eligibility, out("cca_sample_eligibility.csv"))
  write_csv(cca_pair_eligibility, out("cca_pair_eligibility.csv"))
  write_csv(cca_eligibility_counts, out("cca_eligibility_counts.csv"))
  write_csv(cca_exclusion_summary, out("cca_exclusion_summary.csv"))
}

# -----------------------------------------------------------------------------
# Fit the pooled CCA ONLY after resolving and reporting eligibility
# -----------------------------------------------------------------------------
# report-snippet: cca-fit
# The CCA is fitted once, on the legacy survey only.
#   species_past_final: one row per calibration plot (605), one column per tree
#     species (14), the counts of each species in the plot.
#   env_past_final: the same 605 plots, two columns, MSpT (mean spring
#     temperature) and SP (summer precipitation) of the plot's legacy climate
#     window.
# The formula reads "species ~ MSpT + SP". vegan::cca finds the two axes,
# each a weighted sum of MSpT and SP, along which species composition changes
# most. With two climate variables there are exactly two axes. All later
# positions (plots at both surveys, lake samples) live in this 2-D space.
cca_formula = reformulate(CCA_VARIABLES, response = "species_past_final")
cca_model = cca(cca_formula, data = env_past_final)
# end-snippet: cca-fit


# Projection helper. Rows are matched by plot_id, not by position: the former
# model reused the `valid_plots` logical built from the PAST
# matrices to subset the PRESENT matrices, which is correct only while the two
# intersections happen to come out in the same order.
project_period = function(sp, en, era_label) {
  cc = intersect(rownames(sp), rownames(en))
  sp = sp[cc, keep_species, drop = FALSE]
  en = en[cc, CCA_VARIABLES, drop = FALSE]
  pred = predict(cca_model, newdata = en, type = "lc", scaling = cca_scaling, hill = cca_hill)
  proj = predict(cca_model, newdata = sp, type = "wa", scaling = cca_scaling, hill = cca_hill)
  list(plot_id = cc, pred = pred, proj = proj, era = era_label)
}

# All projection inputs are already eligible: never filter WA and LC separately.
# report-snippet: cca-projection
# Two positions for every community, both on the fitted axes:
#   type = "lc" (linear combination): where its CLIMATE alone puts it, the
#     predicted position. It uses only MSpT and SP.
#   type = "wa" (weighted average): where its SPECIES put it, the observed
#     position, the average of the species' scores weighted by their counts.
# The lag M of a community is the distance between the two.
predicted_present = predict(cca_model, newdata = env_present_final, type = "lc", scaling = cca_scaling, hill = cca_hill)
projected_present = predict(cca_model, newdata = species_present_final,
                            type = "wa", scaling = cca_scaling, hill = cca_hill)

predicted_paleo = predict(cca_model, newdata = env_paleo[, CCA_VARIABLES, drop = FALSE],
                          type = "lc", scaling = cca_scaling, hill = cca_hill)
projected_paleo = predict(cca_model, newdata = species_paleo[, keep_species, drop = FALSE],
                          type = "wa", scaling = cca_scaling, hill = cca_hill)
# end-snippet: cca-projection
stopifnot(identical(rownames(predicted_present), rownames(projected_present)),
          identical(rownames(predicted_paleo), rownames(projected_paleo)),
          all(is.finite(predicted_present)), all(is.finite(projected_present)),
          all(is.finite(predicted_paleo)), all(is.finite(projected_paleo)))

# -----------------------------------------------------------------------------
# Scores and plotting frames shared by the maintained figure stages
# -----------------------------------------------------------------------------
past_sites     = scores(cca_model, display = "sites",   choices = 1:2, scaling = cca_scaling, hill = cca_hill)
species_scores = scores(cca_model, display = "species", choices = 1:2, scaling = cca_scaling, hill = cca_hill)
env_scores     = scores(cca_model, display = "bp",      choices = 1:2, scaling = cca_scaling, hill = cca_hill)

species_contribution = sqrt(species_scores[, 1]^2 + species_scores[, 2]^2)
top_species = names(sort(species_contribution, decreasing = TRUE))

site_fire_info_past = env %>% filter(period == "past") %>%
  select(plot_id, site, burnt) %>% filter(plot_id %in% rownames(species_past_final))
site_fire_info_present = env %>% filter(period == "present") %>%
  select(plot_id, site, burnt) %>% filter(plot_id %in% rownames(species_present_final))
site_fire_info_paleo = env %>% filter(period == "paleo") %>%
  select(plot_id, site, burnt) %>% filter(plot_id %in% rownames(species_paleo))

sites_df = as_tibble(past_sites, rownames = "plot_id") %>%
  left_join(site_fire_info_past, by = "plot_id")
species_df = as_tibble(species_scores, rownames = "species") %>%
  filter(species %in% top_species)
env_df = as_tibble(env_scores, rownames = "variable")

# -----------------------------------------------------------------------------
# comparison_df - predicted (LC) vs observed (WA) position of every sample
# -----------------------------------------------------------------------------
comparison_df = bind_rows(
  tibble(plot_id = rownames(species_present_final),
         predicted_CCA1 = predicted_present[, 1], predicted_CCA2 = predicted_present[, 2],
         projected_CCA1 = projected_present[, 1], projected_CCA2 = projected_present[, 2]) %>%
    left_join(site_fire_info_present, by = "plot_id") %>%
    mutate(era = "anthropocene"),
  tibble(plot_id = rownames(species_paleo),
         predicted_CCA1 = predicted_paleo[, 1], predicted_CCA2 = predicted_paleo[, 2],
         projected_CCA1 = projected_paleo[, 1], projected_CCA2 = projected_paleo[, 2]) %>%
    left_join(site_fire_info_paleo, by = "plot_id") %>%
    mutate(era = "holocene")
) %>%
  {cat("\ncomparison_df: ", nrow(.), " of ",
       nrow(species_present_final) + nrow(species_paleo),
       " eligible samples positioned; exclusions are in cca_exclusion_summary.\n",
       sep = ""); .}

# Publish the fit for the climate-era, tracking and figure steps.
# Diagnostic alternative calibrations (count.thr, extra_exclude, cca_suffix) never overwrite it.
if (count.thr == CCA_COUNT_THRESHOLD && !length(extra_exclude) && !nzchar(cca_suffix)) {
  source(here('R/helpers/cca_reference.R'), local = TRUE)
  export_cca_reference(environment())
  # Summary, axes, permutation tests and contributions for the report.
  source(here('R/helpers/cca_report.R'), local = TRUE)
  cca_report_tables(environment())
  # Step 0: screening of the constraint sets and the display rotation.
  # Rule: a two-variable CCA has exactly two constrained axes.
  # Rule: the Anthropocene plot pairs of config.R (MORA 328, NOCA 277).
  stopifnot(nrow(species_past_final) == sum(ANTHROPOCENE_PAIRS), length(cca_model$CCA$eig) == 2L,
    sum(rownames(species_past_final) %in% burned_mora$plot_id) == 0L)
  cca_screening_tables(environment())
  cca_rotation_table(environment())
}
