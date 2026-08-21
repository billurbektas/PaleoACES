# =============================================================================
# 06_lag_common.R - shared setup for the displacement-based lag metric
# =============================================================================
# Rationale: displacement_analysis_ideas.html
#
# Replaces the position-based lag (|obs - pred| at one moment, which has no zero,
# no direction, and carries a composition-dependent species-score bias) with a
# displacement-based metric: the change in OBSERVED position over an interval,
# projected onto the change in PREDICTED position over the same interval.
#
#   response = obs(t2) - obs(t1)     what the forest did
#   demand   = pred(t2) - pred(t1)   what climate asked for
#
# Differencing cancels most of the species-score bias, because that bias is a
# property of the standing composition and changes little between t1 and t2.
#
# This script defines objects only - no printing, no files, no plots:
#   cca_model  pooled CCA (MORA + NOCA past plots, one ordination)
#   pos        Step 1: one row per (site, era, unit, time), obs + pred positions
#   turn       Steps 2-3: one row per interval, decomposed
#   turn_all   as turn, but before the clim_len filter (for reporting drop rates)
#   drop_report  fraction of intervals dropped per site x era
#
# The ordination itself comes from R/05_cca_model.R, sourced below.
# Sourced by 06a_diagnostics.R, 06b_displacements.R, 06c_figures.R.
# =============================================================================

# Species set. Matches R/05d_synthesis.R, which produced the current main
# figures. Set before source()-ing to change it; must be set BEFORE the
# source() below, because 05_cca_model.R reads these.
if (!exists("extra_exclude")) extra_exclude = c("Taxus brevifolia", "Acer circinatum", "Pinus ponderosa")
if (!exists("cca_suffix"))    cca_suffix    = "_subset"

library(here)
source(here("R/05_cca_model.R"))

# Holocene binning (R-Ratepol, Mottl et al. 2021): bins of bin_width yr, with
# n_shift moving-window offsets rather than one set of fixed edges. Each shift
# yields its own internally non-overlapping set of intervals; statistics are
# fitted per shift and summarized across shifts, never pooled (pooling would
# reuse the same samples n_shift times).
if (!exists("bin_width")) bin_width = 100
if (!exists("n_shift"))   n_shift   = 5

# Survey years. dt is the SURVEY interval - the time the forest actually had to
# respond. Sourced as follows:
#   MORA past    ~1975  - Metadata sheet of MORA_Cascade Legacy Data_Original1978.xlsx:
#                         "These data were collected ~ 1975 by NPS". The "1978"
#                         in the filename is not the survey date.
#   MORA present  2015  - Master2018.xlsx "Plots" sheet Year: 2014 (57 plots),
#                         2015 (180), 2016 (48), 2017 (14). 2015 is the mode.
#   NOCA past    ~1980  - NOCA_plots_fromWilson.csv names the legacy column
#                         "1980.Plot.Name". The Agee legacy data (AGEEDATA_NEW.xlsx)
#                         carries no survey-year field.
#   NOCA present  2015  - NOCA_plots_fromWilson.csv Resurvey.Year: 2014 (69),
#                         2015 (309).
# NOTE 1983 was used for NOCA past in the older scripts (giving dt = 32). No
# source for it was found; 1980 is what the data actually says. Revert here if
# there is a provenance for 1983.
#
# NOTE the climate normals are 1981-1986 ("past", centre 1983.5) and 2010-2019
# ("present", centre 2014.5), i.e. 31 yr at BOTH sites. So the demand is measured
# over a 31 yr climate window while the response spans 40 yr at MORA and 35 at
# NOCA. That mismatch is in the data, not fixable by choice of dt. dt does not
# enter achieved / sideways / shortfall / tracking slope at all - only rates.
anthro_years = tibble(
  site      = c("MORA", "NOCA"),
  year_past = c(1975, 1980),
  year_pres = c(2015, 2015)
)

# -----------------------------------------------------------------------------
# Observed (WA) and predicted (LC) positions, from the pooled model
# -----------------------------------------------------------------------------
as_scores = function(pid, pred, proj, era_label, period_label) {
  tibble(plot_id = pid, era = era_label, period = period_label,
         obs1 = proj[, 1], obs2 = proj[, 2],
         pred1 = pred[, 1], pred2 = pred[, 2]) %>%
    filter(!is.nan(obs1), !is.nan(obs2), !is.na(pred1), !is.na(pred2))
}

scores_past = as_scores(
  rownames(species_past_final),
  predict(cca_model, newdata = env_past_final,     type = "lc",
          scaling = cca_scaling, hill = cca_hill),
  predict(cca_model, newdata = species_past_final, type = "wa",
          scaling = cca_scaling, hill = cca_hill),
  "anthropocene", "past")
scores_pres  = as_scores(rownames(species_present_final), predicted_present, projected_present,
                         "anthropocene", "present")
scores_paleo = as_scores(rownames(species_paleo), predicted_paleo, projected_paleo,
                         "holocene", "paleo")

# -----------------------------------------------------------------------------
# STEP 1 - positions: one row per (site, era, unit, time)
# -----------------------------------------------------------------------------
# site_lookup comes from 05_cca_model.R.

# Anthropocene: unit = plot_id, two time points, same plot resurveyed.
pos_anthro = bind_rows(scores_past, scores_pres) %>%
  left_join(site_lookup, by = "plot_id") %>%
  left_join(anthro_years, by = "site") %>%
  transmute(site, era, unit = plot_id, shift = 0L,
            time = if_else(period == "past", year_past, year_pres),
            obs1, obs2, pred1, pred2) %>%
  filter(!is.na(site), !is.na(time))

# Holocene: unit = lake. Positions are averaged within moving-window bins.
paleo_samples = scores_paleo %>%
  left_join(site_lookup, by = "plot_id") %>%
  mutate(lake = str_match(plot_id, "^(.*)_-?\\d+_BP$")[, 2],
         year = as.numeric(str_match(plot_id, "_(-?\\d+)_BP$")[, 2])) %>%
  filter(!is.na(lake), !is.na(year))

# R-Ratepol moving-window binning: n_shift sets of bins, each offset by
# bin_width / n_shift. Bin time is the mean sample age in the bin, not the bin
# centre, so an unevenly sampled bin is placed where its samples actually are.
bin_paleo = function(df, width, n_sh) {
  map_dfr(seq_len(n_sh) - 1L, function(s) {
    offset = s * width / n_sh
    df %>%
      mutate(bin_id = floor((year - offset) / width)) %>%
      group_by(site, lake, bin_id) %>%
      summarize(time  = mean(year),
                n_samples = n(),
                across(c(obs1, obs2, pred1, pred2), mean),
                .groups = "drop") %>%
      mutate(shift = s)
  })
}

pos_holo = bin_paleo(paleo_samples, bin_width, n_shift) %>%
  transmute(site, era = "holocene", unit = lake, shift = as.integer(shift),
            time, n_samples, obs1, obs2, pred1, pred2)

pos = bind_rows(pos_anthro, pos_holo) %>%
  arrange(site, era, unit, shift, time)

# -----------------------------------------------------------------------------
# STEP 2 - displacement vectors
# -----------------------------------------------------------------------------
# One dt per interval, used for BOTH response and demand. Time runs forward:
# calendar years increase for the Anthropocene, cal yr BP decreases toward the
# present for the Holocene, so Holocene intervals are ordered on descending BP.
make_intervals = function(df, time_forward) {
  df %>%
    arrange(site, era, unit, shift, if (time_forward) time else desc(time)) %>%
    group_by(site, era, unit, shift) %>%
    mutate(
      obs1_t1 = lag(obs1), obs2_t1 = lag(obs2),
      pred1_t1 = lag(pred1), pred2_t1 = lag(pred2),
      time_t1 = lag(time)
    ) %>%
    ungroup() %>%
    filter(!is.na(time_t1)) %>%
    transmute(
      site, era, unit, shift,
      time_t1, time_t2 = time,
      dt = if (time_forward) time - time_t1 else time_t1 - time,
      vdx = obs1  - obs1_t1,    # response
      vdy = obs2  - obs2_t1,
      cdx = pred1 - pred1_t1,   # demand
      cdy = pred2 - pred2_t1
    )
}

turn_all = bind_rows(
  make_intervals(filter(pos, era == "anthropocene"), time_forward = TRUE),
  make_intervals(filter(pos, era == "holocene"),     time_forward = FALSE)
) %>%
  filter(dt > 0) %>%
  mutate(grp = interaction(site, era))

# -----------------------------------------------------------------------------
# STEP 3 - decomposition
# -----------------------------------------------------------------------------
# achieved  : response projected onto the demand direction (signed; < 0 = moved
#             opposite to what climate asked)
# sideways  : perpendicular component (2D cross product / |demand|). Sign is
#             counter-clockwise relative to the demand direction. Comparable
#             across groups here because there is ONE pooled ordination.
# shortfall : demand length - achieved. Signed: + = behind, - = overshoot.
decompose = function(df) {
  df %>%
    mutate(
      clim_len  = sqrt(cdx^2 + cdy^2),
      veg_len   = sqrt(vdx^2 + vdy^2),
      achieved  = (vdx * cdx + vdy * cdy) / clim_len,
      sideways  = (vdx * cdy - vdy * cdx) / clim_len,
      shortfall = clim_len - achieved,
      along_n   = achieved / clim_len,
      across_n  = sideways / clim_len
    )
}

turn_all = decompose(turn_all)

# Pythagoras check: the two components are perpendicular by construction.
stopifnot(with(turn_all,
               all(abs(achieved^2 + sideways^2 - veg_len^2) < 1e-8 * pmax(1, veg_len^2),
                   na.rm = TRUE)))

# -----------------------------------------------------------------------------
# STEP 3 (cont.) - filter intervals whose demand is indistinguishable from zero
# -----------------------------------------------------------------------------
# along_n and across_n divide by clim_len, so near-static intervals produce
# arbitrarily large ratios. Threshold: 10th percentile of clim_len within
# site x era. Documented and reported; matters most in the Holocene, where many
# centuries have near-static climate.
clim_len_thr = turn_all %>%
  group_by(site, era) %>%
  summarize(thr = quantile(clim_len, 0.10, na.rm = TRUE), .groups = "drop")

turn_all = turn_all %>% left_join(clim_len_thr, by = c("site", "era"))
turn     = turn_all %>% filter(clim_len > thr)

drop_report = turn_all %>%
  group_by(site, era) %>%
  summarize(n_intervals = n(),
            n_dropped   = sum(clim_len <= thr),
            frac_dropped = round(mean(clim_len <= thr), 3),
            clim_len_thr = round(first(thr), 4),
            .groups = "drop")
