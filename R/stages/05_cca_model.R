# =============================================================================
# 05_cca_model.R - the pooled CCA and everything derived from it. NO FIGURES.
# =============================================================================
# Split out of R/archive/05_cca_paleo.R, which
# mixed the model with ~700 lines of figures and so could not be sourced without
# writing a dozen PDFs. This file is the single definition of the ordination and
# is sourced by everything downstream.
#
# THE MODEL: one pooled CCA trained on the MORA + NOCA "past" plots, constrained
# by MSpT + MWT + SP + WP. "present" and "paleo" samples are projected into it -
# they do not calibrate it. Because there is a single ordination, positions and
# lengths are directly comparable across both sites and both eras.
#
# Defines:
#   cca_model                          the pooled CCA
#   species_past_final, env_past_final  the calibration matrices
#   predicted_present / projected_present, predicted_paleo / projected_paleo
#   comparison_df   per-sample predicted (LC) + observed (WA) positions, all eras
#   lag_std         comparison_df + the OLD position-based metric and clim_dist
#   env, species_complete, site_lookup, keep_species
#   color_mt, color_site_era, color_era_pp
#
# Note on the old metric: euclidean_dist_2D / lag_per_climdist in comparison_df
# and lag_std are the SUPERSEDED position-based lag. They remain computable only
# for historical or interactive compatibility; no maintained workflow output
# consumes them. Current work uses the vector metric specification calculated by
# R/stages/09_tracking_metrics.R. The earlier framing is preserved in
# R/archive/06_lag_common.R.
# =============================================================================

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
#   count.thr = 10; source(here("R/stages/05_cca_model.R"))
#
# There is no longer a separate "_subset" run: Taxus brevifolia and Acer
# circinatum are removed on evidence in R/stages/000_occurrence_data_consolidate.R
# (understory stratum) and Pinus ponderosa by the analysis exclusion there, so
# extra_exclude is empty by default and the full model IS the model.
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
# and plotted by R/stages/000_occurrence_data_consolidate.R. On the consolidated species
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
# It is absent from both paleo records, so no Holocene sample can be projected
# onto the gradient it defines, and it is effectively single-site (27 NOCA plots
# vs 2 at MORA) and declining within that site (20 -> 7). It therefore stretches
# the CCA1-CCA2 plane in which every distance in this study is measured. This is
# the same profile that had Pinus ponderosa moved to ANALYSIS_EXCLUDE (CCA1 3.51,
# single-site, absent from the Holocene) - the difference is a deliberate choice
# to keep this one, not a difference in the evidence.

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
                   "MORA.holocene"     = "#394e82", "NOCA.holocene"     = "#8C3B00")
color_era_pp   = c("anthropocene" = "#DC267F", "holocene" = "#785EF0")

# -----------------------------------------------------------------------------
# Occurrence data
# -----------------------------------------------------------------------------
# ONE input, already consolidated. R/stages/000_occurrence_data_consolidate.R binds the
# three cleaned sources and applies every cross-site taxonomic decision - the
# understory removal, the Populus/Picea/Abies harmonisation, the non-taxa drops -
# with the evidence for each written out beside it. Run that script if any of
# those decisions changes; do NOT re-derive them here, and do not re-run the
# cleaning scripts, which have side effects.
#
# The ad-hoc filter that used to live on this line
#     filter(!species %in% c("unknown", "Abies sp.", "Salix sp."))
# is now part of that script, where it is justified rather than asserted.
occ = read_csv(here("output/occ_consolidated.csv"), show_col_types = FALSE) %>%
  select(period, plot_id, species, occurrence, site, era)

# Species selection: drop species occurring in fewer than count.thr plots in
# every site x period, plus any run-specific exclusions.
#
# TSUGA HETEROPHYLLA IS NOW KEPT (decided 2026-08-13). It had been dropped by
# hand since the earliest version of this analysis. Three reasons for reversing:
#
# 1. The exclusion was never justified. R/archive/05_cca_paleo.R has the bare
#    line with no comment; a removed historical species-count diagnostic also
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
NOCA_plot_info_fire = read_csv(here("output/NOCA_plot_info_fire.csv"), show_col_types = FALSE)
MORA_plot_info_fire = read_csv(here("output/MORA_plot_info_fire.csv"), show_col_types = FALSE)

# Paleo fire now exists for BOTH sites - NOCA's came from Neotoma dataset 52210
# (see data/NOCA/NOCA_paleo/SOURCES.md), so the site is read from the lake instead of being
# hardcoded to "MORA" as it was while PantherPotholes had no charcoal.
# The two sites' fire evidence is not the same KIND (MORA = in-core Dunwiddie
# percentages plus a REGIONAL Walsh proxy from three other lakes; NOCA = in-core
# macrocharcoal from its own core) - that is a reporting caveat, not a data fix.
paleo_info_fire = read_csv(here("output/paleo_fire.csv"), show_col_types = FALSE) %>%
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
# Replaces output/archive/legacy/climate_summary.csv, which came from the archived
# 02_get_climate_data.R and carried a FIXED 1981-86 "past" climatology that
# post-dated MORA's survey by ~8 yr and NOCA's by ~2 - unequally, between the two
# sites the whole study differences against each other.
#
# 000_MORA_climate.R / 000_NOCA_climate.R now write RAW MONTHLY tasmin/tasmax/pr
# for each plot over that site's own survey window (max survey year and the five
# before it). derive_climate_vars() turns them into the CCA variables and is the
# SAME function 000_PALEO_e_climate.R uses, so a season cannot mean one thing in
# the Holocene arm and another in the Anthropocene arm.
source(here("R/helpers/climate_variables.R"), local = TRUE)

climate_monthly = bind_rows(
  read_csv(here("output/MORA_climate.csv"), show_col_types = FALSE),
  read_csv(here("output/NOCA_climate.csv"), show_col_types = FALSE)
)

# site is folded into the grouping key because derive_climate_vars() groups by
# unit x period, and "past" means a different set of years at the two sites.
climate_annual = climate_monthly %>%
  transmute(unit = plot_id, period = paste(site, period, sep = "."),
            variable, time = year, month, value) %>%
  derive_climate_vars(winter_shift = TRUE) %>%
  # winter_shift moves each December into the FOLLOWING winter, so the last
  # December of a window opens a trailing year that holds nothing else. Dropping
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
  summarize(across(all_of(CCA_VARIABLES),
                   list(v = ~ mean(.x, na.rm = TRUE), n = ~ sum(!is.na(.x))),
                   .names = "{.fn}|{.col}"),
            .groups = "drop") %>%
  rename_with(~ sub("^v\\|", "",   .x), starts_with("v|")) %>%
  rename_with(~ sub("^n\\|", "n_", .x), starts_with("n|")) %>%
  separate_wider_delim(period, ".", names = c("site", "period")) %>%
  rename(plot_id = unit) %>%
  mutate(era = "anthropocene")

cat("\nAnthropocene climate - complete season-years per window:\n")
print(as.data.frame(climate_summary %>% group_by(site, period) %>%
  summarize(plots = n(), across(starts_with("n_"), max), .groups = "drop")))

paleo_climate_summary = read_csv(here("output/paleo_env.csv"), show_col_types = FALSE)

env = bind_rows(
  climate_summary %>% select(site, era, period, plot_id, all_of(CCA_VARIABLES)),
  paleo_climate_summary %>% select(site, era, period, plot_id, all_of(CCA_VARIABLES))
) %>%
  left_join(fire_summary, by = c("plot_id", "site", "era"))

# The fire join must not multiply rows. paleo_fire's plot_id is built from the
# AGE, so core depths whose Bacon ages round to the same year collide - three
# ReflectionPond depths at 3641 cal BP did, and tripled that sample in the CCA
# until 000_PALEO_c_fire.R was made to collapse them the way the vegetation is.
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
  ok = complete.cases(e)
  if (any(!ok))
    message("make_env('", per, "'): DROPPED ", sum(!ok), " of ", nrow(e),
            " plots with incomplete climate - ",
            paste(head(rownames(e)[!ok], 5), collapse = ", "),
            if (sum(!ok) > 5) ", ..." else "")
  e[ok, , drop = FALSE]
}

species_past  = make_wide("past");    env_past  = make_env("past")
species_present = make_wide("present"); env_present = make_env("present")
species_paleo = make_wide("paleo");   env_paleo = make_env("paleo")

# -----------------------------------------------------------------------------
# Fit the pooled CCA
# -----------------------------------------------------------------------------
# Training set: past plots with both species and climate, holding >= 1 species.
common_past = intersect(rownames(species_past), rownames(env_past))
common_past = common_past[rowSums(species_past[common_past, , drop = FALSE]) > 0]

species_past_final = species_past[common_past, , drop = FALSE]
species_past_final = species_past_final[, colSums(species_past_final) > 0, drop = FALSE]
keep_species       = colnames(species_past_final)
env_past_final     = env_past[common_past, CCA_VARIABLES, drop = FALSE]

cca_formula = reformulate(CCA_VARIABLES, response = "species_past_final")
cca_model = cca(cca_formula, data = env_past_final)

# Projection helper. Rows are matched by plot_id, not by position: the former
# R/archive/05_cca_paleo.R:145 reused the `valid_plots` logical built from the PAST
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

# Anthropocene resurvey: keep only plots present at BOTH times, so past->present
# is a matched pair (this is what the positional subset achieved implicitly).
present_pairs = intersect(intersect(rownames(species_present), rownames(env_present)),
                          common_past)
species_present_final = species_present[present_pairs, , drop = FALSE]
env_present_final     = env_present[present_pairs, CCA_VARIABLES, drop = FALSE]

predicted_present = predict(cca_model, newdata = env_present_final, type = "lc", scaling = cca_scaling, hill = cca_hill)
projected_present = predict(cca_model, newdata = species_present_final[, keep_species, drop = FALSE],
                            type = "wa", scaling = cca_scaling, hill = cca_hill)

common_paleo  = intersect(rownames(species_paleo), rownames(env_paleo))
species_paleo = species_paleo[common_paleo, , drop = FALSE]
env_paleo     = env_paleo[common_paleo, , drop = FALSE]

predicted_paleo = predict(cca_model, newdata = env_paleo[, CCA_VARIABLES, drop = FALSE],
                          type = "lc", scaling = cca_scaling, hill = cca_hill)
projected_paleo = predict(cca_model, newdata = species_paleo[, keep_species, drop = FALSE],
                          type = "wa", scaling = cca_scaling, hill = cca_hill)

# -----------------------------------------------------------------------------
# Scores and plotting frames (used by the archived figures and by 06c)
# -----------------------------------------------------------------------------
past_sites     = scores(cca_model, display = "sites",   choices = 1:3, scaling = cca_scaling, hill = cca_hill)
species_scores = scores(cca_model, display = "species", choices = 1:3, scaling = cca_scaling, hill = cca_hill)
env_scores     = scores(cca_model, display = "bp",      choices = 1:3, scaling = cca_scaling, hill = cca_hill)

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
         predicted_CCA3 = predicted_present[, 3],
         projected_CCA1 = projected_present[, 1], projected_CCA2 = projected_present[, 2],
         projected_CCA3 = projected_present[, 3]) %>%
    left_join(site_fire_info_present, by = "plot_id") %>%
    filter(!is.nan(projected_CCA1)) %>%
    mutate(era = "anthropocene"),
  tibble(plot_id = rownames(species_paleo),
         predicted_CCA1 = predicted_paleo[, 1], predicted_CCA2 = predicted_paleo[, 2],
         predicted_CCA3 = predicted_paleo[, 3],
         projected_CCA1 = projected_paleo[, 1], projected_CCA2 = projected_paleo[, 2],
         projected_CCA3 = projected_paleo[, 3]) %>%
    left_join(site_fire_info_paleo, by = "plot_id") %>%
    filter(!is.nan(projected_CCA1)) %>%
    mutate(era = "holocene")
) %>%
  # OLD position-based metric - superseded, kept for the S2 comparison only.
  # filter(!is.nan(projected_CCA1)) above removes samples holding NONE of the
  # keep_species: a WA score is a species-weighted average, so an all-zero row has
  # no position. That is correct, but it must not be invisible - a paleo sample
  # whose taxa are all absent from the modern survey list disappears here.
  {cat("\ncomparison_df: ", nrow(.), " of ",
       nrow(species_present_final) + nrow(species_paleo),
       " samples positioned (rest hold none of the ", length(keep_species),
       " retained species)\n", sep = ""); .} %>%
  mutate(diff_CCA1 = abs(projected_CCA1 - predicted_CCA1),
         diff_CCA2 = abs(projected_CCA2 - predicted_CCA2),
         diff_CCA3 = abs(projected_CCA3 - predicted_CCA3),
         euclidean_dist_2D = sqrt(diff_CCA1^2 + diff_CCA2^2),
         euclidean_dist_3D = sqrt(diff_CCA1^2 + diff_CCA2^2 + diff_CCA3^2))

# -----------------------------------------------------------------------------
# lag_std - old metric standardized by climatic distance. Retained for
# historical or interactive compatibility; no maintained output consumes it.
# -----------------------------------------------------------------------------
past_lc = predict(cca_model, newdata = env_past_final, type = "lc", scaling = cca_scaling, hill = cca_hill)
past_lc_centroid = tibble(plot_id = rownames(species_past_final),
                          lc1 = past_lc[, 1], lc2 = past_lc[, 2]) %>%
  left_join(env %>% filter(period == "past") %>% distinct(plot_id, site), by = "plot_id") %>%
  group_by(site) %>%
  summarize(c1 = mean(lc1), c2 = mean(lc2), .groups = "drop")

lag_std = comparison_df %>%
  left_join(past_lc_centroid, by = "site") %>%
  mutate(clim_dist = sqrt((predicted_CCA1 - c1)^2 + (predicted_CCA2 - c2)^2),
         lag_per_climdist = euclidean_dist_2D / clim_dist,
         bp_year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[, 2])) %>%
  filter(!is.na(clim_dist), clim_dist > 0)
