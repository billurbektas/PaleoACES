# =============================================================================
# supp_species_through_time.R  -  STEP 4, the species half
# =============================================================================
# Look at the vegetation before modelling it. The matching climate diagnostic is
# R/figures/supp_climate_correlations.R; this is the companion.
#
#   reads   output/occ_consolidated.csv   (the consolidated species set)
#           output/paleo_env.csv          (ages, and n samples per bin)
#   writes  plot/test_figures/species_through_time.pdf
#           output/test_species_occupancy.csv
#
# THE QUESTION THIS ANSWERS. The CCA separates samples on composition. If a
# species is present in 100% of one site's samples and 0% of the other's, it will
# dominate that separation no matter what the climate does - and the ordination
# will look like it is reading climate when it is reading site identity. So:
# which species actually distinguish the sites, and do any of them CHANGE through
# the Holocene rather than just sitting at 0 or 1?
#
# ⚠ WHAT IS PLOTTED IS OCCUPANCY, NOT ABUNDANCE. The analysis is
# presence/absence throughout (macrofossil percentages are not commensurable with
# survey stem counts), so "occupancy" here is the fraction of samples in a bin
# that contain the species. A flat line at 1.0 means the species is in every
# sample - it carries no information for the ordination even though it is
# abundant.
#
# Native 100-year cells; primary unrounded median sample ages, no moving windows.
# =============================================================================

library(here)
library(tidyverse)
source(here("R/helpers/config.R"), local = TRUE)

HOLO_BIN = 100

occ = read_csv(out("occ_consolidated.csv"), show_col_types = FALSE)
env = read_csv(out("paleo_env.csv"), show_col_types = FALSE) %>%
  select(plot_id, lake, age)

# THE SPECIES THE CCA ACTUALLY USES. count.thr must match R/pipeline/11_cca.R.
# The rule there: a species is dropped only if it occurs in fewer than count.thr
# plots in EVERY site x period group, so one common group is enough to keep it.
COUNT_THR = CCA_COUNT_THRESHOLD

occ_summary = occ %>% filter(occurrence == 1) %>%
  count(site, period, species) %>%
  pivot_wider(names_from = c(site, period), values_from = n, values_fill = 0)
dropped = occ_summary %>%
  filter(if_all(-species, ~ .x < COUNT_THR)) %>% pull(species)
ALL_SP = readRDS(out('cca_calibration_reference.rds'))$retained_species

cat("count.thr = ", COUNT_THR, " -> ", length(ALL_SP), " species retained, ",
    length(dropped), " dropped:\n  ", paste(sort(dropped), collapse = ", "), "\n", sep = "")

occ = occ %>% filter(species %in% ALL_SP)


# -----------------------------------------------------------------------------
# PALEO - occupancy through time, per lake
# -----------------------------------------------------------------------------
paleo = occ %>% filter(era == "holocene") %>%
  left_join(env, by = "plot_id") %>%
  filter(!is.na(age))

# every sample x species combination, so absence is a real 0 and not a missing row
# occ is already restricted to ALL_SP above, so every species here is in
# SP_ORDER and factor() cannot produce an NA level (which would show up as a
# phantom grey "NA" entry in the legend).
grid = expand_grid(distinct(paleo, plot_id, lake, age, site),
                   species = ALL_SP)
pa = grid %>%
  left_join(paleo %>% filter(occurrence == 1) %>% distinct(plot_id, species) %>%
              mutate(present = 1L),
            by = c("plot_id", "species")) %>%
  mutate(present = replace_na(present, 0L))

binned=pa |> mutate(bin=floor(age/100)*100) |> group_by(site,lake,species,bin) |>
  summarize(occupancy=mean(present),n=n(),.groups='drop') |> mutate(mid=bin+50)

# ordered by overall occupancy so the legend runs common -> rare
SP_ORDER = occ %>% filter(occurrence == 1) %>% count(species) %>%
  arrange(desc(n)) %>% pull(species)
SP_ORDER = c(SP_ORDER, setdiff(ALL_SP, SP_ORDER))
PAL_N = length(SP_ORDER)

# how strongly each species separates the two sites in the Holocene - reported,
# no longer used to order the panels
sep = pa %>% group_by(species, site) %>% summarize(o = mean(present), .groups = "drop") %>%
  pivot_wider(names_from = site, values_from = o, values_fill = 0) %>%
  mutate(separation = abs(MORA - NOCA)) %>% arrange(desc(separation))

# Each original sample enters exactly one native century.
holo_line = binned %>%
  group_by(site, lake, species, mid) %>%
  summarize(occupancy = mean(occupancy), n = sum(n), .groups = "drop") %>%
  arrange(lake, species, desc(mid)) %>%
  mutate(species = factor(species, levels = SP_ORDER))

# -----------------------------------------------------------------------------
# ANTHROPOCENE, attached to the pond panels of its own SITE
# -----------------------------------------------------------------------------
# Each pond panel gets its site's survey change: the three MORA ponds carry the
# MORA past -> present, PantherPotholes carries NOCA's. Two x positions at
# negative cal BP, joined per species, so the segment's slope is the change.
ANTH_X = c(past = -1400, present = -3600)

# ⚠ The Anthropocene part of occ_consolidated.csv is presence-only (4,089
# rows against 25,600 possible plot x species x period combinations), so an
# absence is normally a MISSING ROW, not a zero. Taking mean(occurrence == 1)
# over the rows that exist would return ~1 for every species. The grid has to be
# completed first - exactly as it is for the paleo side above.
#
# EVERY plot surveyed in each period is used - no matching between periods. The
# sets are nearly identical anyway (MORA 331/331 shared; NOCA 305 shared, 1
# past-only, 3 present-only), so matching changed almost nothing, and using all
# of them means each panel shows what that survey actually recorded.
anth_grid = occ %>% filter(era == "anthropocene") %>%
  distinct(site, period, plot_id) %>%
  expand_grid(species = SP_ORDER)

anth_occ = anth_grid %>%
  left_join(occ %>% filter(era == "anthropocene", occurrence == 1) %>%
              distinct(plot_id, period, species) %>% mutate(present = 1L),
            by = c("plot_id", "period", "species")) %>%
  mutate(present = replace_na(present, 0L)) %>%
  group_by(site, period, species) %>%
  summarize(occupancy = mean(present), n_plots = n(), .groups = "drop")

lake_site = pa %>% distinct(lake, site)
anth_panel = lake_site %>%
  inner_join(anth_occ, by = "site", relationship = "many-to-many") %>%
  mutate(mid = ANTH_X[period], species = factor(species, levels = SP_ORDER)) %>%
  filter(!is.na(species))

# 21 species needs more than one brewer palette
PAL = setNames(c(RColorBrewer::brewer.pal(12, "Paired"),
                 RColorBrewer::brewer.pal(8, "Dark2"),
                 "#666666", "#000000", "#8DD3C7")[seq_len(PAL_N)], SP_ORDER)

dens = pa %>% distinct(lake, plot_id, age) %>% count(lake, age, name = "n")

stopifnot(!any(is.na(holo_line$species)), !any(is.na(anth_panel$species)))

p1 = ggplot() +
  geom_line(data = holo_line, aes(mid, occupancy, colour = species), linewidth = 0.7,
            alpha = 0.85) +
  geom_rug(data = dens, aes(x = age), sides = "b", alpha = 0.3, linewidth = 0.2,
           colour = "grey30", inherit.aes = FALSE) +
  geom_vline(xintercept = -600, linetype = "dotted", colour = "grey40") +
  geom_line(data = anth_panel, aes(mid, occupancy, colour = species, group = species),
            linewidth = 0.7, alpha = 0.85) +
  geom_point(data = anth_panel, aes(mid, occupancy, colour = species, shape = period),
             size = 1.9) +
  facet_wrap(~ lake, ncol = 2) +
  scale_x_reverse(breaks = c(9000, 6000, 3000, 0, ANTH_X),
                  labels = c("9000", "6000", "3000", "0", "past", "present")) +
  scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1)) +
  scale_colour_manual(values = PAL, name = "Species") +
  scale_shape_manual(values = c(past = 1, present = 16), name = "Survey") +
  labs(x = "cal BP  (time runs left to right)   |   Anthropocene survey",
       y = "occupancy - fraction of samples (Holocene) or plots (Anthropocene) containing the species",
       title = paste0("Species occupancy through time, by pond - the ", length(SP_ORDER),
                      " species the CCA uses (count.thr = ", COUNT_THR, ")"),
       subtitle = paste0("One line per species. Holocene = ", HOLO_BIN,
                         "-yr moving window at 100-yr steps. Right of the dotted line: the survey change for the SITE this pond belongs to\n",
                         "(the three MORA ponds share MORA's; PantherPotholes carries NOCA's), past and present joined so the segment's slope is the change."),
       caption = paste0("Presence/absence throughout. Ticks mark actual macrofossil samples - where sparse, the Holocene line is thin evidence. ",
                        "\nDropped below count.thr = ", COUNT_THR, ": ",
                        paste(sort(dropped), collapse = ", "), ".")) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "right", plot.title = element_text(face = "bold"),
        plot.caption = element_text(hjust = 0, colour = "grey35"),
        legend.text = element_text(face = "italic", size = 8),
        panel.grid.minor = element_blank())

pdf(fig("supplementary", "species_through_time.pdf"), width = 15, height = 9)
print(p1)
dev.off()

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
cat("\n=== which species SEPARATE the two sites in the Holocene? ===\n")
cat("   occupancy = fraction of that site's samples containing the species\n\n")
print(as.data.frame(sep %>% mutate(across(c(MORA, NOCA, separation), ~ round(100 * .x)))),
      row.names = FALSE)

cat("\n=== how much does each species VARY through time within a pond? ===\n")
cat("   a species pinned at 0 or 1 carries no temporal signal, however abundant\n\n")
vary = binned %>% group_by(species, lake) %>%
  summarize(mean_occ = mean(occupancy), sd_occ = sd(occupancy), .groups = "drop") %>%
  group_by(species) %>%
  summarize(max_sd_within_pond = round(max(sd_occ, na.rm = TRUE), 3),
            n_ponds_variable = sum(sd_occ > 0.15, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(max_sd_within_pond))
print(as.data.frame(vary), row.names = FALSE)

write_csv(sep %>% left_join(vary, by = "species"), out("report/test_species_occupancy.csv"))
cat("\nWrote plot/test_figures/species_through_time.pdf\n")
cat("Wrote output/test_species_occupancy.csv\n")
