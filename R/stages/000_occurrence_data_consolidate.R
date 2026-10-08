# =============================================================================
# 000_occurrence_data_consolidate.R
# -----------------------------------------------------------------------------
# ONE place where every cross-site, cross-era taxonomic decision is applied.
#
#   reads   output/MORA_occ.csv   (000_MORA_cleaning.R)
#           output/NOCA_occ.csv   (000_NOCA_cleaning.R)
#           output/paleo_occ.csv  (000_PALEO_b_vegetation.R)
#   writes  output/occ_consolidated.csv   <- the ONLY occurrence input to 05_cca_model.R
#
# Nothing upstream is re-run. The three cleaning scripts keep producing exactly
# what they produce now; this script is a pure transformation on their outputs,
# so a decision here can be changed and re-applied in seconds.
#
# Full prose rationale, with the quotes and the evidence tables:
#   docs/methods/README_occurrence_consolidation.md
#
# =============================================================================
# WHY THERE IS AN UNDERSTORY PROBLEM AT ALL
# =============================================================================
# This study is about OVERSTORY (tree-stratum) communities. Both legacy surveys
# recorded a tree stratum AND a separate understory/shrub stratum, and each site
# put a group of tall shrubs / small trees in the UNDERSTORY one. Both resurveys
# then measured that same group as trees. Left alone, the group produces large
# false colonisations - species that appear to arrive between the surveys purely
# because the second survey counted them and the first did not:
#
#        species              MORA past  MORA present   NOCA past  NOCA present
#        Acer circinatum          0          46             2          19
#        Taxus brevifolia         0          54             6           8
#
# Both were among the 13 species entering the CCA, so this was not cosmetic.
#
# =============================================================================
# HOW "UNDERSTORY" WAS IDENTIFIED  -- from the RAW SURVEY RECORDS, and nothing else
# =============================================================================
# NOT from MORA_spp_lib.csv. That file's `canopy_type` calls ACCI / ACGL / ALSI /
# TABR / SOOC / PREM "overstory_full", which CONTRADICTS the 1978 workbook's own
# metadata (below). The raw workbooks and the legacy publication overrule it.
#
# --- MORA 1978: the workbook states the rule itself -------------------------
# "MORA_Cascade Legacy Data_Original1978.xlsx", sheet `Metadata`, verbatim:
#
#   "Four letter species codes. For trees, these numbers represent stem counts;
#    for understory plants these numbers represent percent cover"
#   "For trees; size class 1 (i.e. ABAM1) = established seedlings (10-140 cm),
#    2 = saplings (dbh 0-20 cm), 3 = poles (20-50), 4 = standards (>50)."
#
# So in sheet `Rainier Veg` a column carrying a TRAILING DIGIT (ABAM1..ABAM4) is
# a tree measured in size classes, and a BARE four-letter column (ACCI, TABR) is
# an understory plant measured as percent cover. The operational test is then:
#
#   MORA measured species X as a tree  <=>  X has size-class columns in
#                                           `Rainier Veg`  OR  X has >0 stems in
#                                           `rawsizedata`
#
# Result (re-derivable; VERIFY_AGAINST_RAW below re-runs it):
#
#   code  size-class cols  bare cover col  rawsizedata stems  verdict
#   ACCI       no               yes               -          UNDERSTORY
#   ACGL       no               yes               -          UNDERSTORY
#   ALSI       no               yes               -          UNDERSTORY
#   TABR       no               yes               0          UNDERSTORY  <- code exists, ZERO stems
#   SOOC       no               yes               -          UNDERSTORY
#   PREM       no               yes               -          UNDERSTORY
#   SASC       no               yes               -          UNDERSTORY
#   CONU       no               yes               -          UNDERSTORY
#   ALRU       no               yes             108          TREE  <- cover AND stems: a real tree
#   PIAL       no               yes               2          TREE
#   POTR      yes               no                6          TREE
#   PISI      yes               no                2          TREE
#   ABPR      yes               no              393          TREE
#
# --- NOCA 1983: two strata in the workbook, and the paper says so ------------
# `AGEEDATA_NEW.xlsx` has SEPARATE `TREE` and `SHRUB` worksheets. Agee & Kertis
# (1987, Can. J. Bot. 65:1520-1530), Methods, verbatim:
#
#   "A dimensioned plot of varying size was used to determine tree density of
#    each species by height class (0-3, 3-10, and > 10 m)."
#
# so `DEN_0-3` / `DEN_3-10` / `DEN >10` are HEIGHT classes in metres and the
# `TREE` sheet is the tree stratum. The test is which sheet holds the species:
#
#   code   legacy SHRUB plots   legacy TREE plots   verdict
#   ACCI          87                   2            UNDERSTORY
#   SOSI          58                   1            UNDERSTORY
#   ALSI          28                   1            UNDERSTORY
#   ACGL          18                   5            UNDERSTORY
#   COST          13                   0            UNDERSTORY
#   PREM           9                   4            UNDERSTORY
#   SARA           8                   0            UNDERSTORY
#   ALRU           2                  23            TREE
#
# Agee & Kertis Table 3 (the published tree list) likewise omits Acer circinatum,
# Alnus sinuata and Sorbus sitchensis, and names Sorbus sitchensis among the
# "dominant shrubs".
#
# --- The rule that follows, and the trap it avoids ---------------------------
# DROP a species if EITHER legacy survey POSITIVELY recorded it in its
# understory/shrub stratum instead of its tree stratum.
#
# ABSENCE from one site's legacy is NOT evidence of understory status - it is a
# real absence. Betula papyrifera, Acer macrophyllum, Pinus ponderosa, Larix
# lyallii and Populus balsamifera have no column at all at MORA and are tree-
# stratum species at NOCA; they are KEPT. Conflating "not recorded" with
# "recorded as understory" would delete genuine species.
#
# The two criteria are independent (a workbook legend at one site, a separate
# worksheet plus a published methods statement at the other) and they agree
# wherever both have evidence - which is why this is a finding and not a choice.
# =============================================================================

library(tidyverse)
library(here)
library(readxl)
source(here("R/helpers/config.R"), local = TRUE)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

VERIFY_AGAINST_RAW = TRUE   # re-derive the two tables above from the raw workbooks

# -----------------------------------------------------------------------------
# THE DECISIONS
# -----------------------------------------------------------------------------

# (1) UNDERSTORY - removed from BOTH sites and BOTH eras.
# Every name a taxon appears under anywhere in the three inputs is listed, so a
# synonym cannot slip through. Confirmed 2026-08-13.
UNDERSTORY = c(
  "Acer circinatum",                    # MORA bare cover col; NOCA SHRUB 87 vs TREE 2
  "Acer glabrum",                       # MORA bare cover col; NOCA SHRUB 18 vs TREE 5
  "Alnus alnobetula subsp. sinuata",    # MORA bare cover col (ALSI); NOCA SHRUB 28 vs TREE 1
  "Alnus sinuata", "Alnus viridis", "Alnus crispa",   # same taxon, other spellings
  "Taxus brevifolia",                   # MORA bare cover col AND zero stems in rawsizedata
  "Sorbus sitchensis",                  # MORA bare cover col (SOOC); NOCA SHRUB 58 vs TREE 1
  "Cornus nuttallii",                   # MORA bare cover col (CONU)
  "Cornus sericea", "Cornus stolonifera",  # NOCA SHRUB 13 vs TREE 0; absent at MORA
  "Sambucus racemosa",                  # NOCA SHRUB 8 vs TREE 0; absent at MORA
  "Prunus emarginata",                  # MORA bare cover col; NOCA SHRUB 9 vs TREE 4
  "Salix sp.", "Salix scouleriana", "Salix barclayi",  # MORA bare cover col (SASC)
  "Corylus cornuta"                     # NOCA shrub; 1 plot
)

# (2) NON-TAXA - carry no ecological information, removed everywhere.
#     "Abies sp." is dropped rather than lumped (decided 2026-08-13): its code
#     ABPE sits at 622 and 658 m, where subalpine fir is implausible - NOCA's
#     ABLA plots have a median elevation of 1658 m - and the resurvey Plant List
#     annotates it "Should be some sort of abies ... No existing Abies spp.
#     starting with Pe." An identification nobody can make should not be forced.
NON_TAXA = c("unknown", "Abies sp.", "Unknown tree.")

# (2b) FORMER ANALYSIS EXCLUSION REVERSED - decided 2026-10-08.
# Pinus ponderosa is a valid tree taxon and is retained here. Its former manual
# exclusion was not justified by identification evidence or a general selection
# rule. Site concentration, absence from the Holocene records and an extreme
# ordination position are not exclusion criteria. It now follows the same >=20
# species-selection rule as other tree taxa in 05_cca_model.R.
# The former rationale and the author's reversal are recorded in
# docs/methods/README_occurrence_consolidation.md and SCIENTIFIC_DECISIONS.md.

# (3) TAXONOMIC HARMONISATION.
# Each entry says WHICH SITE and WHICH PERIOD it applies to, because two of the
# three are wrong to apply globally.
RENAMES = tribble(
  ~site,   ~period,     ~from,                 ~to,                    ~why,
  # --- Populus: one taxon recorded under two names ---------------------------
  # Agee & Kertis 1987 Table 3 lists "Populus trichocarpa"; the legacy code is
  # POTR. The resurvey's POAI -> "Populus balsamifera" rests only on the Plant
  # List note "some unknown tree; from Rachel: POPBAL most likely". Applied at
  # both sites so one taxon has one name. Removes a false extinction (NOCA 8->0)
  # and a false colonisation (NOCA 0->2, MORA 0->3).
  "NOCA",  NA,          "Populus balsamifera", "Populus trichocarpa",  "one taxon, two names; Agee 1987 Table 3 uses trichocarpa",
  "MORA",  NA,          "Populus balsamifera", "Populus trichocarpa",  "same taxon as NOCA; see the MORA caveat printed below",

  # --- Picea sitchensis: not a recordable taxon in 1983 ----------------------
  # The AGEEDATA `SPECIES` codebook has 494 entries and exactly one Picea:
  # PIEN. Agee & Kertis Table 3 has no P. sitchensis. So "0 -> 7" cannot be a
  # colonisation - the 1983 crew had no code for it. The 7 resurvey plots are at
  # 966-1691 m (median 1569), far above Sitka spruce's coastal range, and three
  # of them recorded PIEN in 1983 at exactly the elevations Engelmann occupies.
  # NOCA PRESENT ONLY: at MORA, PISI has its own tree size classes (PISI2,
  # PISI4) and stems in rawsizedata, so it is a legitimate species there.
  "NOCA",  "present",   "Picea sitchensis",    "Picea engelmannii",    "no legacy code existed; 966-1691 m is outside Sitka spruce's range",

  # --- Abies procera: NOCA only ---------------------------------------------
  # At MORA this is a real, abundant species - 68 past / 50 present survey plots
  # and 43 Holocene macrofossil samples - so lumping it there would destroy a
  # genuine taxon. At NOCA it is 3 resurvey plots (1402-1564 m), absent from the
  # legacy, and outside the species' main range north of Snoqualmie Pass.
  "NOCA",  NA,          "Abies procera",       "Abies lasiocarpa",     "NOCA ONLY - A. procera is genuine at MORA (68/50 plots, 43 paleo samples)"
)

# -----------------------------------------------------------------------------
# Load the three cleaned sources
# -----------------------------------------------------------------------------
occ = bind_rows(
  read_csv(here("output/MORA_occ.csv"), show_col_types = FALSE) %>%
    transmute(site = "MORA", era = "anthropocene", period, plot_id, species, occurrence),
  read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE) %>%
    transmute(site = "NOCA", era = "anthropocene", period, plot_id, species, occurrence),
  read_csv(here("output/paleo_occ.csv"), show_col_types = FALSE) %>%
    transmute(site, era, period, plot_id, species, occurrence)
)

before = occ %>% filter(occurrence == 1) %>%
  count(site, period, species, name = "n_before")

# -----------------------------------------------------------------------------
# Apply (3) renames -> (2) non-taxa -> (1) understory, in that order
# -----------------------------------------------------------------------------
# One function, so the stage-resolved table below cannot drift from the main one.
# Renames run FIRST, so a name being dropped is dropped under every alias.
apply_decisions = function(x, verbose = FALSE) {
  for (i in seq_len(nrow(RENAMES))) {
    r = RENAMES[i, ]
    hit = x$species == r$from & x$site == r$site &
          (is.na(r$period) | x$period == r$period)
    if (verbose) {
      cat(sprintf("rename  %-4s %-8s %-20s -> %-20s (%s)\n",
                  r$site, coalesce(r$period, "both"), r$from, r$to,
                  if (any(hit)) paste(sum(hit), "records") else "NO RECORDS - check"))
    }
    x$species[hit] = r$to
  }
  x = x %>% filter(!species %in% NON_TAXA, !species %in% UNDERSTORY)
  x
}

occ = apply_decisions(occ, verbose = TRUE)

# A rename can leave two rows for one plot x species (e.g. a plot holding both
# Picea sitchensis and Picea engelmannii). Presence is presence.
occ = occ %>%
  group_by(site, era, period, plot_id, species) %>%
  summarize(occurrence = as.integer(any(occurrence == 1)), .groups = "drop")

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
after = occ %>% filter(occurrence == 1) %>% count(site, period, species, name = "n_after")
delta = full_join(before, after, by = c("site", "period", "species")) %>%
  mutate(across(c(n_before, n_after), ~ replace_na(.x, 0L))) %>%
  filter(n_before != n_after)

cat("\n--- species x site x period records that changed ---\n")
print(as.data.frame(delta %>% arrange(site, period, species)), row.names = FALSE)

cat("\n--- surviving species, plots per site x period ---\n")
print(as.data.frame(occ %>% filter(occurrence == 1) %>%
  count(species, site, period) %>%
  pivot_wider(names_from = c(site, period), values_from = n, values_fill = 0) %>%
  arrange(species)), row.names = FALSE)

# MORA legacy Populus - FIXED UPSTREAM 2026-08-13, verify it stayed fixed.
# MORA_spp_lib.csv's only Populus row is `past_code = "absent_past"`, asserting
# Populus was not recorded in 1978. It was: `rawsizedata` holds POTR in 4 plots.
# With no past_code == "POTR" row the past join returned NA and those plots were
# discarded, so MORA read "Populus 0 past / 3 present" - a false colonisation.
# 000_MORA_cleaning.R now patches past_code IN MEMORY (the CSV is untouched), and
# 3 of the 4 plots come through; the 4th is not in MORA_plot_lib, i.e. not a
# survey-resurvey plot, so dropping it is correct.
mora_pop = occ %>% filter(site == "MORA", species == "Populus trichocarpa", occurrence == 1) %>% count(period)
cat("\nMORA Populus trichocarpa (was 0 past / 3 present before the upstream fix):\n")
print(as.data.frame(mora_pop), row.names = FALSE)
if (!"past" %in% mora_pop$period)
  warning("MORA legacy Populus is missing again - check the POTR past_code patch ",
          "in 000_MORA_cleaning.R")

# ⚠ Juniperus communis is a prostrate shrub and survives here because it occurs
# ONLY in the NOCA Holocene macrofossils, where no legacy survey stratum exists
# to test it against. It is far below count.thr so it never enters the CCA.
cat("\nNOTE - Juniperus communis (NOCA paleo only, 8 samples) is a shrub but has\n",
    "  no survey-stratum evidence either way; kept, and it never reaches the CCA.\n", sep = "")

write_csv(occ, here("output/occ_consolidated.csv"))
cat("\nWrote output/occ_consolidated.csv:", nrow(occ), "rows,",
    n_distinct(occ$species), "species,", n_distinct(occ$plot_id), "samples\n")

# =============================================================================
# SPECIES COUNTS - the evidence for choosing count.thr
# =============================================================================
# Absorbed from the removed historical species-count diagnostic, which built this from the UNCONSOLIDATED
# tables and so counted species that no longer exist and split taxa that are now
# merged. The threshold must be chosen on the data the CCA will actually see.
#
# NOTHING IS FILTERED OR DECIDED HERE. This block reports the RAW EVIDENCE - how
# many plots each species occupies in each site x period. The threshold itself
# lives at the top of 05_cca_model.R as `count.thr`, so it can be swept:
#
#   for (thr in c(10, 15, 20, 25, 30)) { count.thr = thr; source("R/stages/05_cca_model.R") }
#
# The rule there: a species is DROPPED only if it is below the threshold in EVERY
# site x period group - so a species common in one group survives even if it is
# rare everywhere else. That is why max_group below is the number to compare a
# candidate threshold against.
counts = occ %>%
  filter(occurrence == 1) %>%
  distinct(site, period, species, plot_id) %>%
  count(site, period, species, name = "n") %>%
  pivot_wider(names_from = c(site, period), values_from = n, values_fill = 0)

grp = setdiff(names(counts), "species")
counts = counts %>%
  mutate(max_group = do.call(pmax, c(across(all_of(grp)), na.rm = TRUE))) %>%
  arrange(desc(max_group))

cat("\n=== plots (or paleo samples) per species, by site x period ===\n")
cat("    max_group = the largest count in any one group. A candidate count.thr\n",
    "    is compared against THIS, because 05_cca_model.R drops a species only\n",
    "    if it is below the cut-off in every group. Set the threshold there.\n", sep = "")
print(as.data.frame(counts), row.names = FALSE)

# --- figure -----------------------------------------------------------------
color_era = c("paleo" = "#44AA99", "past" = "#88CCEE", "present" = "#CC6677")
cnt_long = occ %>%
  filter(occurrence == 1) %>%
  distinct(site, period, species, plot_id) %>%
  count(site, period, species, name = "n") %>%
  mutate(species = factor(species, levels = rev(counts$species)),
         period  = factor(period, levels = c("paleo", "past", "present")))

p_counts = ggplot(cnt_long, aes(species, n, fill = period)) +
  geom_col(position = position_dodge(preserve = "single"), width = 0.75) +
  geom_hline(yintercept = CCA_COUNT_THRESHOLD, linetype = "dashed",
             colour = "#B03A2E", linewidth = 0.5) +
  scale_fill_manual(values = color_era,
                    labels = c(paleo = "Holocene", past = "Legacy", present = "Resurvey")) +
  facet_wrap(~ site, scales = "free_x") +
  coord_flip() +
  labs(x = NULL, y = "Number of plots (Holocene: number of samples)", fill = "Period",
       title = "Species occurrence after consolidation",
       subtitle = paste0("Dashed line: selection threshold of ", CCA_COUNT_THRESHOLD, " plots or samples.\n",
                         "A species is retained if it reaches the threshold in any site and period.\n",
                         "Understory and unresolved taxa are removed; ponderosa pine is retained.")) +
  theme_minimal(base_size = 16) +
  theme(plot.title = element_text(size = 18, face = "bold"),
        plot.subtitle = element_text(size = 14),
        axis.text = element_text(size = 14),
        strip.text = element_text(size = 16, face = "bold"),
        legend.text = element_text(size = 14),
        panel.grid.major.y = element_blank(),
        legend.position = "top")

if (render_figures) {
  ggsave(here("plot/test_figures/species_counts_consolidated.pdf"), p_counts,
         width = 11, height = 8)
  cat("\nWrote plot/test_figures/species_counts_consolidated.pdf\n")
}

# =============================================================================
# ADULT vs SEEDLING / REGENERATION
# =============================================================================
# Absorbed from the removed historical stage diagnostic, which had to source() BOTH
# cleaning scripts to reach their in-memory raw objects - and so rewrote
# MORA_occ.csv, NOCA_occ.csv and two PDFs every time it ran. The cleaning scripts
# now write MORA_occ_stage.csv / NOCA_occ_stage.csv, so this reads files and has
# no side effects.
#
# Presence-based (number of plots a species occupies at each stage) because the
# raw counts are in incompatible units across the four datasets.
#
# ⚠ REGENERATION IS NOT MEASURED THE SAME WAY IN THE TWO ERAS AT NOCA:
#     NOCA past    regeneration = legacy 0-3 m HEIGHT class (Agee & Kertis 1987)
#                  adult        = 3-10 m and >10 m height classes
#     NOCA present regeneration = JHRL Seedlings tallies (10-140 cm)
#                  adult        = Tree Data stems (DBH, i.e. >1.4 m)
#     MORA both    regeneration = 10-140 cm;  adult = DBH / tree records
# So NOCA's "past regeneration" spans a taller band (to 3 m) than every other
# regeneration cell (to 1.4 m). ADULTS are comparable throughout; REGENERATION is
# a proxy and the past-vs-present regeneration contrast at NOCA is confounded by
# the band width. This is stated on the figure, not buried here.
SEED = "Seedling / regeneration"; ADULT = "Adult"

stage = bind_rows(
  read_csv(here("output/MORA_occ_stage.csv"), show_col_types = FALSE) %>% mutate(site = "MORA"),
  read_csv(here("output/NOCA_occ_stage.csv"), show_col_types = FALSE) %>% mutate(site = "NOCA")
) %>%
  # MORA writes "adult"/"seedling", NOCA writes "Adult"/"Seedling / regeneration"
  mutate(stage = if_else(str_starts(str_to_lower(stage), "a"), ADULT, SEED),
         era = "anthropocene") %>%
  apply_decisions() %>%
  distinct(site, period, plot_id, species, stage)

# the stage table must not contain a species the consolidated table dropped
stopifnot(all(stage$species %in% occ$species))

stage_counts = stage %>% count(site, period, species, stage, name = "n_plots")

sp_ord = stage_counts %>% group_by(species) %>%
  summarize(t = sum(n_plots), .groups = "drop") %>% arrange(t) %>% pull(species)

stage_counts = stage_counts %>%
  mutate(species = factor(species, levels = sp_ord),
         period  = factor(period,  levels = c("past", "present")),
         site    = factor(site,    levels = c("MORA", "NOCA")),
         stage   = factor(stage,   levels = c(ADULT, SEED)))

p_stage = ggplot(stage_counts, aes(species, n_plots, fill = period)) +
  geom_col(position = position_dodge(preserve = "single"), width = 0.75) +
  facet_grid(site ~ stage) +
  coord_flip() +
  scale_fill_manual(values = c(past = "#88CCEE", present = "#CC6677"),
                    labels = c(past = "Legacy", present = "Resurvey"), name = "Period") +
  labs(x = NULL, y = "Number of plots",
       title = "Adults and regeneration: legacy versus resurvey",
       subtitle = "Plots per species at each vegetation stage.\nConsolidated tree taxa; understory taxa excluded.",
       caption = paste0("NOCA adults: >3 m in legacy surveys; >1.4 m in resurveys.\n",
                        "NOCA regeneration: 0-3 m in legacy surveys; 10-140 cm in resurveys. MORA: 10-140 cm at both dates.\n",
                        "The NOCA legacy versus resurvey regeneration comparison therefore uses different height bands.")) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "top",
        panel.grid.major.y = element_blank(),
        axis.text = element_text(size = 14),
        axis.text.y = element_text(size = 14, face = "italic"),
        strip.text = element_text(size = 16, face = "bold"),
        legend.text = element_text(size = 14),
        plot.title = element_text(size = 18, face = "bold"),
        plot.subtitle = element_text(size = 14),
        plot.caption = element_text(size = 12, hjust = 0, colour = "grey35"))

if (render_figures) {
  ggsave(here("plot/test_figures/stage_adult_seedling_past_present.pdf"), p_stage,
         width = 12, height = 12)
}

cat("\n=== adult vs regeneration, plot occupancy ===\n")
print(as.data.frame(stage_counts %>% group_by(site, period, stage) %>%
  summarize(species = n(), plot_occurrences = sum(n_plots), .groups = "drop")), row.names = FALSE)
if (render_figures)
  cat("\nWrote plot/test_figures/stage_adult_seedling_past_present.pdf\n")

# =============================================================================
# VERIFICATION - re-derive the classification from the raw workbooks
# =============================================================================
# The lists above are written out explicitly so they can be read and argued
# with. This block re-derives the evidence from the raw files and stops if the
# data no longer supports it, so the two cannot drift apart.
if (VERIFY_AGAINST_RAW) {
  cat("\n--- verifying the understory classification against the raw workbooks ---\n")

  f    = here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx")
  veg  = read_excel(f, sheet = "Rainier Veg")
  size = read_excel(f, sheet = "rawsizedata")

  tree_cols = unique(substr(grep("^[A-Z]{4}[1-4]$", names(veg), value = TRUE), 1, 4))
  bare_cols = setdiff(grep("^[A-Z]{4}$", names(veg), value = TRUE), "SiteName")
  stems = size %>% mutate(n = rowSums(across(DBH0:`>DBH120`), na.rm = TRUE)) %>%
    group_by(Species) %>% summarize(stems = sum(n), .groups = "drop")

  mora_is_tree = function(code) {
    s = stems$stems[stems$Species == code]
    code %in% tree_cols || (length(s) == 1 && s > 0)
  }
  # every MORA code we call understory must be a bare cover column AND not a tree
  mora_understory_codes = c("ACCI","ACGL","ALSI","TABR","SOOC","PREM","SASC","CONU")
  for (cd in mora_understory_codes) {
    stopifnot(cd %in% bare_cols)     # recorded as understory percent cover
    stopifnot(!mora_is_tree(cd))     # and never measured as a tree
  }
  # and the ones we keep must be trees
  for (cd in c("ALRU","PIAL","POTR","PISI","ABPR")) stopifnot(mora_is_tree(cd))
  cat("  MORA: 8 understory codes confirmed cover-only; 5 kept codes confirmed trees\n")

  A  = here("data/NOCA/AGEEDATA_NEW.xlsx")
  tr = read_excel(A, sheet = "TREE")
  sh = read_excel(A, sheet = "SHRUB") %>% select(PLOT, starts_with("SPEC")) %>%
    pivot_longer(-PLOT, values_to = "code") %>% filter(!is.na(code))
  nplots = function(tbl, cd, col) length(unique(tbl[[1]][tbl[[col]] == cd]))
  shrub_n = function(cd) n_distinct(sh$PLOT[sh$code == cd])
  tree_n  = function(cd) n_distinct(tr$PLOT[tr$SPEC == cd])
  for (cd in c("ACCI","SOSI","ALSI","ACGL","COST","PREM","SARA")) {
    stopifnot(shrub_n(cd) > tree_n(cd))   # predominantly the shrub stratum
  }
  stopifnot(tree_n("ALRU") > shrub_n("ALRU"))   # Alnus rubra is the tree-stratum control
  cat("  NOCA: 7 understory codes confirmed SHRUB-dominant; ALRU confirmed TREE-dominant\n")

  # the legacy codebook really has no Sitka spruce
  sp = read_excel(A, sheet = "SPECIES")
  stopifnot(!"PISI" %in% sp$CODE)
  stopifnot("PIEN" %in% sp$CODE)
  cat("  NOCA: legacy codebook has PIEN and no PISI - confirmed\n")

  cat("  all checks passed\n")
}
