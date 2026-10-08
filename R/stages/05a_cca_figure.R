# =============================================================================
# 05a_cca_figure.R - the main CCA figure: observed vs predicted trajectories
# =============================================================================
# Panel A: the pooled ordination, showing for each site x era BOTH trajectories
#          through time -
#            observed  (solid, filled points)  = WA scores, from composition
#            predicted (dashed, open points)   = LC scores, from climate
#          Arrows run in the direction of time. Where the two paths diverge, the
#          forest is not where climate says it should be; where they run
#          parallel, it is moving as climate asks while holding its offset.
# Panel B: the biplot inset within A, with climate arrows and species scores.
# Panel C: marginal climate-variable effects on constrained inertia; shared
#          climate variance is reported but is not plotted as a separate bar.
# Panel D: species contributions to constrained inertia, with occurrence shading.
#
# Holocene points are site x frozen CC/S-era centroids of the complete 1,000-year
# site-date path; Anthropocene is one point per site per survey. Sources
# R/stages/05_cca_model.R for the model.
# =============================================================================

library(here)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

# Species selection is inherited from the model. Consolidation removes Taxus
# brevifolia and Acer circinatum under the understory rule; Pinus ponderosa is
# retained following the 2026-10-08 reversal of its former manual exclusion.
# 05_cca_model.R defaults extra_exclude to character(0) and cca_suffix to "".
source(here("R/stages/05_cca_model.R"), local = TRUE)
library(ggrepel)
library(patchwork)
source(here("R/helpers/figure_style.R"), local = TRUE)

# The reviewed frozen CC/S-era centroid display is the sole main trajectory
# product. Both publication formats are written when rendering is enabled.
holocene_display_mode = "era_centroid"
cca_figure_stem = "fig_cca_trajectories"
write_cca_png = TRUE

# Inactive retained alternative: the moving-window trajectory branch below is
# available for sensitivity work but is not the selected publication display.
# Its run machinery uses 1,000-yr bins x 10 offsets x age draws and defines
# HOLO_BIN, OFFSETS, N_DRAWS and make_runs(). Sourced rather than reimplemented
# so this figure and the tracking metrics cannot disagree about what a bin is.
HOLO_BIN = 1000
OFFSETS = seq(0, HOLO_BIN - 100, by = 100)
source(here("R/helpers/paleo_runs.R"), local = TRUE)

# A bin_mid is kept only if it is occupied in at least this fraction of the age
# DRAWS. Each bin_mid belongs to exactly one offset, so the denominator is
# N_DRAWS, not the number of runs. Without it the
# oldest and youngest ends of each path sprout ghost bins that exist in one draw
# out of a hundred - a single sample's age tail, drawn as if it were a time step.
min_draw_frac = 0.5

# Species LABELLED in the inset biplot: those whose arrow reaches at least this
# percent of the longest species arrow. Purely a legibility rule - shorter arrows
# sit on the origin where a label cannot be placed. All species are still drawn,
# and panel B shows all of them, so nothing is hidden.
inset_sp_min_pct = 25

base_theme = theme_paleoaces(base_size = PAPER_BASE_SIZE) +
  theme(legend.title = element_blank(), legend.position = "bottom",
        panel.grid.minor = element_blank())

imp    = summary(cca_model)$cont$importance[2, ] * 100
ax_lab = paste0(c("CCA1", "CCA2"), " ", round(imp[1:2], 1), "%")

# Full names for the configured constraints. Their shared derivation is defined
# in R/helpers/climate_variables.R; their active selection and labels live in config.R.
clim_full = CLIMATE_VARIABLE_LABELS[CCA_VARIABLES]
full_name = function(x) unname(ifelse(x %in% names(clim_full), clim_full[x], x))

# -----------------------------------------------------------------------------
# Trajectory points: observed (WA) and predicted (LC) centroids through time
# -----------------------------------------------------------------------------
# Anthropocene: identical valid pairs at BOTH dates, prepared in 05_cca_model.R.
# The full legacy calibration cloud remains in the model/background display.
past_pred = predict(cca_model, newdata = env_past_paired,     type = "lc",
                    scaling = cca_scaling, hill = cca_hill)
past_proj = predict(cca_model, newdata = species_past_paired, type = "wa",
                    scaling = cca_scaling, hill = cca_hill)

anth_pts = bind_rows(
  tibble(plot_id = rownames(species_past_paired), t = "legacy",
         o1 = past_proj[, 1], o2 = past_proj[, 2],
         p1 = past_pred[, 1], p2 = past_pred[, 2]),
  tibble(plot_id = rownames(species_present_final), t = "resurvey",
         o1 = projected_present[, 1], o2 = projected_present[, 2],
         p1 = predicted_present[, 1], p2 = predicted_present[, 2])
) %>%
  left_join(site_lookup, by = "plot_id") %>%
  group_by(site, era = "anthropocene", t) %>%
  summarize(across(c(o1, o2, p1, p2), mean), n = n(), .groups = "drop") %>%
  mutate(order = if_else(t == "legacy", 1, 2), lab = t)
stopifnot(identical(rownames(species_past_paired), rownames(species_present_final)),
          all(is.finite(unlist(select(anth_pts, o1, o2, p1, p2)))))
# Persist the exact paired site means so report claims and Figure 3 are auditable.
write_csv(anth_pts, here("output/cca_trajectory_anthropocene_centroids.csv"))

# Holocene: the 1,000-yr MOVING WINDOW, median across runs.
#
# TWO NESTED AVERAGES, in this order and not the other:
#   1. WITHIN a run - mean POSITION of the samples in the bin. Positions, never
#      pooled assemblages: pooling takes the union of species in the bin, which
#      grows with the number of samples in it (rho up to 0.79) and manufactures
#      compositional change out of sampling effort. Averaging positions has no
#      such dependence.
#   2. ACROSS runs - MEDIAN of those per-run means. Median not mean, because a
#      run whose age draw empties a bin makes that bin's mean jump.
#
# The offsets are POOLED rather than averaged pointwise: each offset produces
# bins at different times, so there is nothing to average pointwise. Ordered by
# bin_mid they ARE the 1,000-yr window slid in 100-yr steps.
#
# The spread across runs is not drawn in this inactive alternative. It is
# quantified by the maintained tracking realization tables and audit figures.
runs = make_runs(bin_width = HOLO_BIN, offsets = OFFSETS)

holo_pos = comparison_df %>%
  filter(era == "holocene") %>%
  select(plot_id, site, o1 = projected_CCA1, o2 = projected_CCA2,
         p1 = predicted_CCA1, p2 = predicted_CCA2)

holo_all = runs %>%
  inner_join(holo_pos, by = "plot_id") %>%
  group_by(site, run_id, bin_mid) %>%
  summarize(across(c(o1, o2, p1, p2), mean), n = n(), .groups = "drop") %>%
  group_by(site, bin_mid) %>%
  summarize(across(c(o1, o2, p1, p2), median), n = median(n),
            n_draws = n(), .groups = "drop") %>%
  mutate(draw_frac = n_draws / N_DRAWS)

# ⚠ THE PATH IS THINNED FOR DISPLAY, NOT DRAWN AT EVERY 100-YR PHASE STEP -
# a DISPLAY decision, and the only place in the analysis where one bin phase is
# privileged over the other four. Why:
#
# Consecutive moving-window points share 9 of their 10 centuries, so 90% of each
# step is the same samples. In a time series that is fine - it is a smoother. In
# a 2-D trajectory it is not: it draws five times more path length than there is
# independent information, and the wander between overlapping windows is mostly
# sampling noise. MORA's median bin holds 7 samples, so exchanging one sample
# moves the point substantially, and the pooled path became an unreadable
# tangle. NOCA (median 35 per bin) was far smoother - i.e. the tangle scales with
# thinness of sampling, which is the signature of noise, not of signal.
#
# What this does and does not cost:
#   costs    the phase of the drawn path is arbitrary (offset 0 of 10).
#   does NOT cost anything in the numbers. The tracking stage computes lag,
#            tracking ratio, and angle per run over all 10 offsets before
#            summarization. Only this inactive display branch fixes a phase.
#   keeps    the age draws. Every point is still the median over N_DRAWS
#            chronologies; it is the bin PHASE that is fixed here, not the age.
#
# Set traj_step = 100 to draw the full moving window instead.
#
# ⚠ SET TO 2000 (Billur, 2026-08-13), so the drawn points coincide with the
# 2000-yr time labels - every vertex is dated, and the path drops from 15 (MORA)
# / 23 (NOCA) points to 4 / 6.
#
# What this does and does not mean:
#   EVERY POINT IS STILL A 1,000-YR BIN MEAN. traj_step selects WHICH bins are
#   drawn; it does not widen them. A vertex at 2250 cal BP is the mean position
#   over its stated 1,000-year window - not a 2,000-yr average.
#   THE PATH THEREFORE SKIPS EVERY OTHER PRIMARY BIN. A segment between two vertices
#   spans 2000 yr, and whatever the composition did in between is not drawn. For
#   a trajectory that is the point - it is a summary of direction - but it means
#   the line must NOT be read as "nothing happened in between".
#   NOTHING IN THE NUMBERS CHANGES. The tracking stage computes all three metrics over EVERY
#   adjacent 1,000-yr bin pair, across all 10 offsets and all age draws. This
#   parameter touches only what this one panel draws.
if (!exists("traj_step")) traj_step = 2000
traj_phase = 0                                  # which of OFFSETS is drawn

holo_pts = if (holocene_display_mode == "trajectory") {
  holo_all %>%
    filter(draw_frac >= min_draw_frac) %>%
    filter(traj_step == 100 |
             (bin_mid - HOLO_BIN / 2 - traj_phase) %% traj_step == 0) %>%
    mutate(era = "holocene", order = -bin_mid, lab = NA_character_)
} else {
  # Selected display: one observed WA and one predicted LC centroid per site x
  # frozen CC/S era. Centroids are calculated from the complete site-date path,
  # then ordered from CC1 to S4 so the original trajectory machinery draws the
  # observed and predicted paths separately with time-direction arrows.
  era_grid_path = here("output/holocene_era_grid.csv")
  if (!file.exists(era_grid_path))
    stop("Missing output/holocene_era_grid.csv; run R/stages/13_holocene_climate_fire_eras.R first.")
  era_grid = read_csv(era_grid_path, show_col_types = FALSE)
  era_levels = c("CC1", "S1", "CC2", "S2", "CC3", "S3", "CC4", "S4")
  if (!identical(unique(era_grid$era_id), era_levels))
    stop("Unexpected Holocene era sequence in holocene_era_grid.csv.")

  era_centroid_audit = holo_all %>%
    filter(draw_frac >= min_draw_frac) %>%
    left_join(select(era_grid, t, era_id, era_class),
              by = c("bin_mid" = "t")) %>%
    filter(!is.na(era_id)) %>%
    group_by(site, era_id, era_class) %>%
    summarize(across(c(o1, o2, p1, p2), mean),
              n_dates = n_distinct(bin_mid), n = median(n), .groups = "drop") %>%
    mutate(era_id = factor(era_id, levels = era_levels),
           era = "holocene", order = match(era_id, era_levels),
           lab = as.character(era_id), bin_mid = NA_real_,
           n_draws = NA_integer_, draw_frac = NA_real_) %>%
    arrange(site, order)

  if (n_distinct(era_centroid_audit$site) != 2L ||
      any(table(era_centroid_audit$site) != length(era_levels)) ||
      anyDuplicated(era_centroid_audit[c("site", "era_id")]))
    stop("Holocene era-centroid construction failed.")

  write_csv(era_centroid_audit %>%
              transmute(site, era_id = as.character(era_id), era_class,
                        observed_CCA1 = o1, observed_CCA2 = o2,
                        predicted_CCA1 = p1, predicted_CCA2 = p2,
                        n_dates, median_samples = n, order),
            here("output/cca_trajectory_era_centroids.csv"))
  era_centroid_audit
}

# Labels at even millennia. With 1,000-year windows and 100-year phases, a bin
# midpoint need not fall exactly on the target; the nearest point within half a
# bin is labelled instead.
if (holocene_display_mode == "trajectory") {
  holo_pts = holo_pts %>%
    group_by(site) %>%
    group_modify(function(g, k) {
      targets = seq(0, 11000, by = 2000)
      hit = purrr::map_int(targets, function(t) {
        i = which.min(abs(g$bin_mid - t))
        if (length(i) && abs(g$bin_mid[i] - t) <= HOLO_BIN / 2) i else NA_integer_
      })
      g$lab[na.omit(hit)] = paste0(targets[!is.na(hit)] / 1000, " ka")
      g
    }) %>%
    ungroup()
}

traj = bind_rows(anth_pts %>% select(-t),
                 holo_pts %>% select(site, era, o1, o2, p1, p2, n, order, lab)) %>%
  mutate(grp = interaction(site, era)) %>%
  arrange(grp, order)

# Long form, so observed vs predicted gets a real legend rather than a caption.
traj_long = bind_rows(
  traj %>% transmute(site, era, grp, order, lab, n, type = "observed",  x = o1, y = o2),
  traj %>% transmute(site, era, grp, order, lab, n, type = "predicted", x = p1, y = p2)
) %>%
  mutate(type = factor(type, levels = c("observed", "predicted"))) %>%
  arrange(grp, type, order)

# EDIT SERIES-LABEL POSITIONS HERE. Each row controls exactly one direct label.
# `anchor_lab` is the trajectory vertex used as the starting position; NA uses
# the mean of that path. `nx_frac` and `ny_frac` are horizontal/vertical offsets
# expressed as fractions of the complete trajectory range: positive = right/up,
# negative = left/down. These labels are drawn without repel so changes here are
# deterministic and easy to tune by eye.
series_label_positions = tribble(
  ~site,  ~era,            ~type,        ~anchor_lab, ~nx_frac, ~ny_frac,
  "MORA", "holocene",     "observed",   "CC4",          0.000,   -0.070,
  "MORA", "holocene",     "predicted",  NA_character_,   0.100,   -0.080,
  "MORA", "anthropocene", "observed",   "legacy",       0.100,    0.080,
  "MORA", "anthropocene", "predicted",  NA_character_,  -0.100,   -0.170,
  "NOCA", "holocene",     "observed",   "CC1",          0.000,    0.070,
  "NOCA", "holocene",     "predicted",  NA_character_,  -0.120,    0.120,
  "NOCA", "anthropocene", "observed",   "resurvey",     0.080,   -0.070,
  "NOCA", "anthropocene", "predicted",  "legacy",       0.100,    0.070)

series_centers = traj_long %>%
  group_by(grp, site, era, type) %>%
  summarize(center_x = mean(x), center_y = mean(y), .groups = "drop")
series_anchors = traj_long %>%
  filter(!is.na(lab)) %>%
  select(site, era, type, anchor_lab = lab, anchor_x = x, anchor_y = y)

series_lab = series_label_positions %>%
  mutate(type = factor(type, levels = levels(traj_long$type))) %>%
  left_join(series_centers, by = c("site", "era", "type")) %>%
  left_join(series_anchors, by = c("site", "era", "type", "anchor_lab")) %>%
  mutate(
    x = if_else(is.na(anchor_lab), center_x, anchor_x),
    y = if_else(is.na(anchor_lab), center_y, anchor_y),
    lab = paste0(site, " ",
      if_else(era == "holocene", "Holocene", "Anthropocene"), "\n",
      str_to_title(as.character(type))),
    nx = nx_frac * diff(range(traj_long$x)),
    ny = ny_frac * diff(range(traj_long$y))
  )

expected_series_labels = as.vector(outer(
  c("MORA", "NOCA"),
  c("Holocene\nObserved", "Holocene\nPredicted",
    "Anthropocene\nObserved", "Anthropocene\nPredicted"),
  paste))
stopifnot(nrow(series_lab) == 8L,
          setequal(series_lab$lab, expected_series_labels),
          !anyDuplicated(series_lab[c("site", "era", "type")]),
          all(is.finite(series_lab$x)), all(is.finite(series_lab$y)),
          all(is.finite(series_lab$nx)), all(is.finite(series_lab$ny)))

# Arrowheads every arrow_every-th step. With few, widely spaced points every
# segment should carry its own head; at traj_step = 100 a head on every step
# would be a solid line of arrowheads.
arrow_every = if (traj_step >= 1000) 1 else if (traj_step >= 500) 2 else 5

steps = traj_long %>%
  group_by(grp, type) %>%
  mutate(xend = lead(x), yend = lead(y), step = row_number()) %>%
  ungroup() %>%
  filter(!is.na(xend))

step_heads = steps %>%
  filter(era == "anthropocene" | step %% arrow_every == 0)

# Labels: every second bin on the observed Holocene path, both ends of every
# observed path, and the two ends of the predicted Holocene paths (which run far
# from their observed counterparts, so they need anchoring in time). The
# Anthropocene predicted path is left unlabelled - it has two points sitting
# right beside the observed ones, so labelling it just prints each year twice.
# Observed paths get EVERY bin labelled; predicted paths only their two ends,
# nudged below the vertex so the text does not sit on the point it marks.
lab_pts = traj_long %>%
  group_by(grp, type) %>%
  mutate(is_end = row_number() %in% c(1, n())) %>%
  ungroup()
if (holocene_display_mode == "trajectory") {
  lab_pts = lab_pts %>%
    filter(type == "observed" | (type == "predicted" & era == "holocene" & is_end)) %>%
    # Holocene labels are pre-thinned to the millennia above; everything else
    # (both Anthropocene points, and the ends of the predicted Holocene paths)
    # keeps whatever label it has.
    filter(!is.na(lab) | (era == "holocene" & type == "predicted" & is_end)) %>%
    # The two ends of a predicted Holocene path rarely fall on a millennium, so
    # they get their own age rather than an empty label - they run far from their
    # observed counterparts and need anchoring in time. order = -bin_mid.
    mutate(lab = if_else(is.na(lab), sprintf("%.1f ka", -order / 1000), lab),
           ny = if_else(type == "predicted", -0.03 * diff(range(traj_long$y)), 0))
} else {
  # Label the observed CC/S centroids. Predicted centroids remain visible through
  # the original observed/predicted alpha legend without duplicating every label.
  lab_pts = lab_pts %>%
    filter(type == "observed", !is.na(lab)) %>%
    mutate(ny = 0)
}


# -----------------------------------------------------------------------------
# Inset: the plain biplot - climate constraint arrows + species scores
# -----------------------------------------------------------------------------
env_bp = as_tibble(scores(cca_model, display = "bp", choices = 1:2,
                          scaling = cca_scaling, hill = cca_hill), rownames = "variable")
sp_bp  = as_tibble(scores(cca_model, display = "species", choices = 1:2,
                          scaling = cca_scaling, hill = cca_hill), rownames = "species")

# Climate and species labels go in ONE repel layer, or they only avoid their own
# kind and collide with each other. Every label gets a leader line
# (min.segment.length = 0), so species with near-zero loadings - Abies amabilis
# sits almost exactly on the origin - are pulled out to where they can be read
# instead of piling up on the axis crossing.
# Which species get a LABEL in the inset is a legibility question, not an
# importance one: a species sitting near the origin cannot be labelled without
# the text landing on the axis crossing. The criterion is therefore arrow length
# relative to the longest arrow - explicitly NOT a contribution measure. (They
# are unrelated here: Spearman(arrow length, goodness) = -0.04, and Pinus
# contorta has the longest arrow but one of the lowest goodness values.)
# Every species is still DRAWN; only the label is withheld.
sp_contrib = sp_bp %>%
  mutate(arrow_len = sqrt(CCA1^2 + CCA2^2),
         arrow_pct = 100 * arrow_len / max(arrow_len)) %>%
  arrange(desc(arrow_pct))

sp_inset   = sp_contrib %>% filter(arrow_pct >= inset_sp_min_pct)
sp_dropped = sp_contrib %>% filter(arrow_pct <  inset_sp_min_pct)

# Climate labels are nudged OUTWARD along their own arrow before repel runs.
# Without it repel can park a label on the far side of the origin from the arrow
# it names - "Mean summer temperature" was landing to the left while its arrow
# pointed right - because the four arrow tips sit close together under scaling 1.
# ARROW SCALING. The constraint arrows were drawn at a FIXED x2, which worked
# while the species cloud was compact. It is not: Pinus albicaulis sits at
# (3.57, 4.39) - kept deliberately, see 05_cca_model.R - and it stretches this
# panel so far that the four climate arrows collapse onto the origin, which is
# the one thing this panel exists to show. The multiplier is therefore tied to
# the species extent, so the arrows fill a fixed FRACTION of the panel whatever
# the species set does. Direction and relative length are untouched - only the
# common scale factor changes, which is standard biplot practice and carries no
# interpretation (arrow length is comparable BETWEEN arrows, never to the species).
arrow_mult = 0.62 * max(sqrt(sp_bp$CCA1^2 + sp_bp$CCA2^2)) /
                    max(sqrt(env_bp$CCA1^2 + env_bp$CCA2^2))
cat("\nbiplot arrow multiplier: ", round(arrow_mult, 2),
    " (was a fixed 2; rescaled because the species extent is ",
    round(max(sqrt(sp_bp$CCA1^2 + sp_bp$CCA2^2)), 2), ")\n", sep = "")

inset_labs = bind_rows(
  env_bp %>% mutate(r = sqrt(CCA1^2 + CCA2^2)) %>%
    transmute(x = CCA1 * arrow_mult, y = CCA2 * arrow_mult, label = full_name(variable),
              col = "black", fface = "bold", sz = 2.4,
              # nudge outward along the arrow, in the SAME units the arrows are
              # now drawn in - it was tied to the old fixed x2 and would drop the
              # labels near the origin once the arrows were rescaled
              nx = CCA1 / r * 0.5 * max(r) * arrow_mult,
              ny = CCA2 / r * 0.5 * max(r) * arrow_mult),
  sp_inset %>% transmute(x = CCA1, y = CCA2, label = species,
                         col = "grey30", fface = "italic", sz = 2.15,
                         nx = 0, ny = 0)
)
# Text sizes are tied to the inset's PHYSICAL size, not to the data: the box was
# halved above, and at the old 2.8/2.6 the four climate labels collided and
# "Callitropsis nootkatensis" ran off the right edge. Adjust these together with
# the inset_element() extents below, never one without the other.

p_inset = ggplot() +
  geom_hline(yintercept = 0, color = "grey88", linewidth = 0.3) +
  geom_vline(xintercept = 0, color = "grey88", linewidth = 0.3) +
  geom_segment(data = sp_bp, aes(0, 0, xend = CCA1, yend = CCA2),
               color = "grey70", linewidth = 0.3) +
  geom_point(data = sp_bp, aes(CCA1, CCA2), color = "grey55", size = 0.7) +
  geom_segment(data = env_bp, aes(0, 0, xend = CCA1 * arrow_mult, yend = CCA2 * arrow_mult),
               arrow = arrow(length = unit(0.22, "cm")), color = "black", linewidth = 0.9) +
  geom_text_repel(data = inset_labs,
                  aes(x, y, label = label, color = col, fontface = fface, size = sz),
                  nudge_x = inset_labs$nx, nudge_y = inset_labs$ny,
                  segment.size = 0.2, segment.color = "grey60", segment.alpha = 0.8,
                  box.padding = 0.3, point.padding = 0.2,
                  # high pull, low push: labels stay anchored to what they name.
                  # Summer and winter temperature point within 19 deg of each
                  # other, so without a strong pull repel throws one across the
                  # origin, away from the arrow it belongs to.
                  force = 1.5, force_pull = 8,
                  min.segment.length = 0, max.overlaps = Inf,
                  max.iter = 200000, seed = 11) +
  scale_color_identity() +
  scale_size_identity() +
  scale_discrete_identity(aesthetics = "fontface") +
  scale_x_continuous(expand = expansion(mult = 0.30)) +
  scale_y_continuous(expand = expansion(mult = 0.20)) +
  # Back to an INSET (Billur, 2026-08-13), now at the TOP RIGHT of panel A - the
  # corner the trajectories leave empty. Compact styling: no axes, since an inset
  # this size cannot carry readable ones, and the arrow directions are what it is
  # for. It keeps the rescaled arrows (see arrow_mult above), without which the
  # four constraints collapse onto the origin at this size.
  # No title: the arrows and species names say what it is, and a header inside a
  # box this small costs more room than it earns.
  labs(tag = "B.", x = NULL, y = NULL) +
  theme_void(base_size = 9) +
  theme(panel.background = element_rect(fill = alpha("white", 0.93), color = "grey70",
                                        linewidth = 0.4),
        plot.margin = margin(4, 6, 4, 6),
        plot.tag = element_text(face = "bold", size = PAPER_PANEL_TAG_SIZE),
        plot.tag.position = "topleft",
        legend.position = "none")

# -----------------------------------------------------------------------------
# Panel A: trajectories
# -----------------------------------------------------------------------------
# NO `site` column, so facet_wrap draws the SAME calibration cloud in every panel.
# Deliberate: an identical background in both facets is what makes the two panels
# visually comparable. Splitting it per site would also be informative (the two
# sites' plots occupy different parts of the space) but would change what the grey
# means between panels, which is the wrong trade for a headline figure.
calib_proj = predict(cca_model, newdata = species_past_final, type = "wa",
                     scaling = cca_scaling, hill = cca_hill)
calib = tibble(o1 = calib_proj[, 1], o2 = calib_proj[, 2])
stopifnot(nrow(calib) == nrow(species_past_final), all(is.finite(as.matrix(calib))))

# Observed vs predicted is carried by OPACITY, not line type: at these path
# lengths a dashed line reads as a broken line rather than as a second series.
alpha_type = c(observed = 1, predicted = 0.18)

# ZOOM. The trajectories occupy 20% of the area the calibration cloud forces the
# axes to cover (CCA1 -1.22 to 2.69 against paths at -0.43 to 0.79), so four
# fifths of the panel was empty. coord_cartesian CLIPS the view without dropping
# any data - the cloud is cropped, not filtered, so nothing is silently removed
# from the model. How many plots fall outside is printed and captioned.
zpad = 0.12
zx = range(traj_long$x) + c(-1, 1) * zpad * diff(range(traj_long$x))
zy = range(traj_long$y) + c(-1, 1) * zpad * diff(range(traj_long$y))

# HEADROOM FOR THE INSET. The biplot sits at the top right of panel A, so that
# corner has to be empty - otherwise it lands on the MORA Holocene path, whose
# oldest point is the closest thing to it. Reserved by extending the view rather
# than by shrinking the inset, so the inset stays readable. Checked below.
zx[2] = zx[2] + 0.30 * diff(zx)
# Extra display space keeps the refitted ponderosa model's era labels clear of B.
zy[2] = zy[2] + 0.35 * diff(zy)

n_out = sum(calib$o1 < zx[1] | calib$o1 > zx[2] | calib$o2 < zy[1] | calib$o2 > zy[2])

# The inset occupies the top-right corner in NORMALISED panel coordinates. Assert
# no trajectory point falls inside it, so it cannot silently cover the data.
INSET_BOX = c(left = 0.45, bottom = 0.54, right = 1.00, top = 1.00)

# ⚠ CHECK THE LABELS, NOT JUST THE POINTS. The first version of this test looked
# at trajectory vertices only and passed cleanly while the inset's bottom-left
# corner sat on MORA's "6 ka" label - a label is offset from its point and repel
# moves it further, so a vertex outside the box is no guarantee its text is.
# lab_pts is checked with a margin to stand in for that displacement.
LAB_MARGIN = 0.04
inset_hits = function(df, margin = 0) df %>%
  mutate(nx = (x - zx[1]) / diff(zx), ny = (y - zy[1]) / diff(zy)) %>%
  filter(nx > INSET_BOX["left"] - margin, ny > INSET_BOX["bottom"] - margin)

hidden     = inset_hits(traj_long)
hidden_lab = inset_hits(lab_pts, LAB_MARGIN)
hidden_series = inset_hits(series_lab, LAB_MARGIN)
if (nrow(hidden) || nrow(hidden_lab) || nrow(hidden_series))
  warning("inset would cover ", nrow(hidden), " trajectory point(s) and ",
          nrow(hidden_lab), " time label(s) and ", nrow(hidden_series),
          " series-label anchor(s): ",
          paste(unique(c(hidden$grp, hidden_lab$lab, hidden_series$lab)),
                collapse = ", "),
          " - raise INSET_BOX['bottom'] or widen the headroom above")
cat("\ninset check: ", nrow(hidden), " trajectory points and ", nrow(hidden_lab),
    " time labels and ", nrow(hidden_series),
    " series-label anchors fall under the inset box\n", sep = "")

# BOTH VIEWS ARE DRAWN, from ONE definition (Billur, 2026-08-13). They answer
# different questions and neither replaces the other:
#
#   A  ALL TOGETHER, one panel, coloured by site x era - the two sites in a single
#      space, so their positions can be compared directly. This is the original
#      layout. It is the honest view of "where is MORA relative to NOCA", and it
#      is the one that gets crowded.
#   B  FACETED BY SITE, coloured by era - each site's paths get their own panel
#      and cannot overlap the other's. Legible, at the cost of no longer showing
#      the two sites in one space.
#
# The colour mapping differs BY DESIGN and each panel carries its own legend: in A
# colour must encode site AND era (4 series in one space); in B site is the facet,
# so panel B uses its era legend. Panel A keeps the same MORA blue and NOCA
# orange across eras; endpoint shapes and labels identify the modern comparison.
# Built by one function so the two panels
# cannot drift apart in anything except the mapping.
traj_panel = function(colour_var, pal, tag, facet = FALSE, title = NULL,
                      subtitle = NULL, caption = NULL) {
  cv = sym(colour_var)
  p = ggplot() +
    geom_hline(yintercept = 0, color = "grey90") +
    geom_vline(xintercept = 0, color = "grey90") +
    geom_point(data = calib, aes(o1, o2), color = "grey80", size = 0.5, alpha = 0.3) +
    # Points first, arrows second: the arrowheads must sit ON TOP of the vertex
    # circles, or a white-filled point masks the head of the arrow arriving at it.
    # At traj_step = 100 a circle on every Holocene point beads the whole path, so
    # vertices are drawn only for the Anthropocene pair.
    geom_point(data = if (traj_step >= 500) traj_long
                      else traj_long %>% filter(era == "anthropocene"),
               aes(x, y, color = !!cv, alpha = type),
               shape = 21, fill = "white", size = 1.9, stroke = 0.7,
               show.legend = FALSE) +
    geom_segment(data = steps,
                 aes(x, y, xend = xend, yend = yend, color = !!cv, alpha = type,
                     group = interaction(grp, type)),
                 linewidth = 0.6, lineend = "round", show.legend = FALSE) +
    geom_segment(data = step_heads,
                 aes(x, y, xend = xend, yend = yend, color = !!cv, alpha = type),
                 arrow = arrow(length = unit(0.16, "cm"), type = "closed"),
                 linewidth = 0.6, lineend = "butt", show.legend = TRUE) +
    # Predicted labels share the predicted-path transparency. Every text layer
    # stays out of the guide so the alpha legend contains arrows, never "a" glyphs.
    geom_text_repel(data = lab_pts,
                    aes(x, y, label = lab, color = !!cv, alpha = type),
                    size = 3.0, nudge_y = lab_pts$ny,
                    # high pull keeps each time label beside its own vertex; the
                    # tightly-spaced predicted paths otherwise fling labels away
                    force = 1.5, force_pull = 6, box.padding = 0.16, point.padding = 0.1,
                    segment.size = 0.2, segment.alpha = 0.6, min.segment.length = 0.2,
                    max.overlaps = Inf, max.iter = 100000, seed = 3,
                    show.legend = FALSE) +
    geom_text(data = series_lab,
              aes(x + nx, y + ny, label = lab, color = !!cv, alpha = type),
              size = 3.85, fontface = "bold", lineheight = 0.82,
              show.legend = FALSE) +
    coord_cartesian(xlim = zx, ylim = zy) +
    scale_color_manual(values = pal) +
    scale_alpha_manual(values = alpha_type,
                       labels = c(observed = "Observed", predicted = "Predicted")) +
    labs(x = ax_lab[1], y = ax_lab[2], tag = tag, title = title,
         subtitle = subtitle, caption = caption) +
    guides(color = "none",
           alpha = guide_legend(order = 1, nrow = 1, title = NULL,
                                override.aes = list(color = "grey25",
                                  linewidth = 1.1))) +
    base_theme +
    theme(plot.margin = margin(6, 6, 6, 6),
          plot.title = element_text(face = "bold", size = 12),
          plot.subtitle = element_text(size = 9, color = "grey35"),
          strip.text = element_text(face = "bold", size = 12),
          plot.caption = element_text(hjust = 0, colour = "grey40", size = 8),
          legend.text = element_text(size = 13),
          legend.key.width = unit(2.2, "cm"),
          legend.key.height = unit(.65, "cm"))
  if (facet) p = p + facet_wrap(~ site)
  p
}

# No caption on the figure - it belongs in the paper's legend, so it is printed
# with the rest of the caption material at the end instead. Do NOT lose it: the
# panel is a crop, and a reader who is not told that will read the grey cloud as
# the whole calibration set.
zoom_note = paste0("Zoomed to the trajectories: ", n_out, " of ", nrow(calib),
                   " calibration plots fall outside this view (cropped, not removed).")

pA = traj_panel("grp", color_site_era, "A.", facet = FALSE)

# The facet-by-site version is NOT drawn (Billur, 2026-08-13): both sites in one
# space is the comparison the study is about, and at 2000-yr points that panel is
# no longer crowded enough to need splitting. traj_panel() still takes
# facet = TRUE, so it is one call away if it is ever wanted again.
# Extents come from INSET_BOX, the same vector the overlap check above uses, so
# the assertion can never test a box different from the one drawn. unname() -
# inset_element takes bare numerics and a named vector is a silent trap.
pA_inset = pA + inset_element(p_inset,
                              left   = unname(INSET_BOX["left"]),
                              bottom = unname(INSET_BOX["bottom"]),
                              right  = unname(INSET_BOX["right"]),
                              top    = unname(INSET_BOX["top"]),
                              align_to = "panel")

# -----------------------------------------------------------------------------
# Panels C and D: contributions to the constrained inertia
# -----------------------------------------------------------------------------
# Loadings are NOT repeated here - the inset already shows them, as the direction
# and length of each arrow. This panel shows the other thing: how the constrained
# inertia is divided up.
#
# Both blocks are pieces of the SAME total constrained inertia, but they behave
# completely differently:
#
#   species  inertcomp(display="species")[, "CCA"] / sum(CCA$eig)  -> sums to 100%
#            Species are columns of the RESPONSE, so the constrained inertia
#            decomposes exactly across them. A true contribution.
#
#   climate  marginal ChiSquare from anova(by="margin") / sum(CCA$eig) -> sums to 27%
#            Constraints are correlated PREDICTORS, so their explanatory parts
#            overlap. The missing 73% is shared and cannot be attributed to any
#            one variable (VIF 22-39; r = 0.90 temperatures, 0.95 precipitations).
#            It is reported in the caption and console, not plotted as a bar.
#
# NOT goodness()/inertcomp(proportional=TRUE): those divide by each species' OWN
# inertia, giving a per-species FIT that does not partition (sums to 1.77 here)
# and is not comparable with the climate numbers.
tot_constrained = sum(cca_model$CCA$eig)

sp_inertia = inertcomp(cca_model, display = "species")
sp_share   = tibble(variable = rownames(sp_inertia),
                    share_pct = 100 * sp_inertia[, "CCA"] / tot_constrained)

set.seed(1)
clim_marg  = anova(cca_model, by = "margin", permutations = 499)
nterm      = nrow(clim_marg) - 1
clim_share = tibble(variable = full_name(rownames(clim_marg)[seq_len(nterm)]),
                    share_pct = 100 * clim_marg$ChiSquare[seq_len(nterm)] / tot_constrained,
                    p_value   = clim_marg$`Pr(>F)`[seq_len(nterm)])

shared_pct = 100 - sum(clim_share$share_pct)   # reported, not plotted

# Species prevalence: percentage of the CALIBRATION plots (the "past" plots the
# CCA was actually fitted on) in which the species occurs. Independent of bar
# length - a species can be common yet contribute little constrained inertia, or
# rare and contribute a lot - so the colour is not re-encoding the bar.
sp_prev = tibble(variable  = colnames(species_past_final),
                 n_plots   = colSums(species_past_final),
                 prev_pct  = 100 * colSums(species_past_final) / nrow(species_past_final))
n_calib = nrow(species_past_final)

# Neutral grey -> near-black ramp. Grey rather than a hue because panel A already
# spends blue on MORA and orange on NOCA; a coloured ramp here reads as a site.
# Five stops across a wide lightness span so adjacent species separate; light end
# #b2b2ad clears 2:1 against the panel surface so the rarest stay visible.
# The ramp is stretched over the observed prevalence range rather than 0-100.
# The retained species span that current range, so a fixed 0-100 scale would
# compress their colors into the pale half. Legend breaks remain real percentages.
prev_ramp = c("#b2b2ad", "#8e8e88", "#6b6b65", "#484843", "#1f1f1c")

sp_names = sp_bp$species
ital_lab = function(x) parse(text = ifelse(x %in% sp_names,
                                           paste0("italic('", x, "')"), paste0("'", x, "'")))

# Two stacked plots rather than facets, so each block gets a plain horizontal
# title and a height proportional to its number of bars. facet_wrap cannot do
# space = "free", and facet_grid rows put the strip on its side.
# NOTE the two blocks share a denominator (the constrained inertia, 0.4596) but
# NOT a numerator, so "share" is only accurate for the species:
#   species  inertia_j^CCA / sum_j inertia_j^CCA          -> an exact partition
#            "the fraction of the climate-explained compositional variation that
#             is this species' own variation"             (sums to 100%)
#   climate  [I(full) - I(full without k)] / I(full)      -> a unique effect
#            "the fraction of the climate-explained variation that disappears if
#             this variable is dropped"                   (sums to 27%)
# Verified: sum(inertcomp CCA) == sum(CCA$eig) exactly, and the marginal
# ChiSquare equals the drop in constrained inertia on refitting without the term.
# The axis is therefore labelled "% of constrained inertia" - a ratio TO it,
# which is true of both - and each block carries its own one-line definition.
bar_block = function(df, title, subtitle, show_axis, tag = NULL, fill_prev = FALSE) {
  p = ggplot(df, aes(reorder(variable, share_pct), share_pct)) +
    (if (fill_prev) geom_col(aes(fill = prev_pct), width = 0.7)
     else           geom_col(width = 0.7, fill = "grey45")) +
    geom_text(aes(label = sprintf("%.1f", share_pct)), hjust = -0.2, size = 3.1,
              color = "grey25") +
    coord_flip(clip = "off") +
    scale_x_discrete(labels = ital_lab) +
    scale_y_continuous(limits = c(0, max(contrib_all$share_pct) * 1.12),
                       expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, tag = tag,
         y = if (show_axis) "% of constrained inertia" else NULL,
         title = title, subtitle = subtitle) +
    base_theme +
    theme(plot.title = element_text(face = "bold", size = 12, hjust = 0),
          plot.subtitle = element_text(size = 9, color = "grey35", hjust = 0),
          panel.grid.major.y = element_blank(),
          axis.text.x  = if (show_axis) element_text() else element_blank(),
          axis.ticks.x = if (show_axis) element_line() else element_blank())

  if (fill_prev) {
    p + scale_fill_gradientn(
          colours = prev_ramp, limits = range(sp_prev$prev_pct),
          breaks = scales::pretty_breaks(5),
          guide = guide_colorbar(title.position = "top", title.hjust = 0)) +
      labs(fill = paste0("Occurrence: % of the ", n_calib,
                         " calibration plots holding the species")) +
      theme(legend.position  = "bottom",
            legend.title     = element_text(size = 9),
            legend.direction = "horizontal",
            legend.key.height = unit(0.3, "cm"),
            legend.key.width  = unit(1.5, "cm"))
  } else {
    p + theme(legend.position = "none")
  }
}

contrib_all = bind_rows(clim_share %>% select(variable, share_pct),
                        sp_share   %>% select(variable, share_pct))

pB = bar_block(clim_share, "Climate", NULL, show_axis = FALSE, tag = "C.") /
     bar_block(sp_share %>% left_join(sp_prev, by = "variable"), "Species", NULL,
               show_axis = TRUE, tag = "D.", fill_prev = TRUE) +
  plot_layout(heights = c(nrow(clim_share), nrow(sp_share)))

# Four labelled visual components: A trajectories, B biplot inset, and C/D the
# climate/species constrained-inertia blocks.
fig = pA_inset + pB +
  plot_layout(widths = c(1.6, 1)) &
  theme(plot.tag = element_text(size = 16, face = "bold"))

if (render_figures) {
  pdf(here("plot", paste0(cca_figure_stem, ".pdf")), height = 8.5, width = 15)
  print(fig)
  dev.off()
  ggsave(here("plot", paste0(cca_figure_stem, ".png")), fig,
         height = 8.5, width = 15, dpi = 300, bg = "white")
}

# The caption is deliberately not drawn on the figure. Everything a caption would
# need is printed here instead.
cat("\n=== CAPTION MATERIAL (figure carries no caption) ===\n")
cat(zoom_note, "\n", sep = "")
if (holocene_display_mode == "trajectory") {
  cat("Panel A: points every ", traj_step, " yr, each one a ", HOLO_BIN,
      "-yr bin mean (median over ", N_DRAWS, " age draws).\n", sep = "")
} else {
  cat("Panel A: one WA and one LC centroid per site x frozen CC/S era,",
      " connected separately from CC1 through S4 with time-direction arrows;",
      " Anthropocene legacy-to-resurvey trajectories are unchanged.\n")
}
cat("Observed = WA scores (alpha ", alpha_type["observed"],
    "); predicted = LC scores (alpha ", alpha_type["predicted"], ").\n", sep = "")
cat("Ordination scaling: ", cca_scaling, " (hill = ", cca_hill, ")\n", sep = "")
cat("Total constrained inertia: ", round(tot_constrained, 4),
    " (", round(100 * tot_constrained / cca_model$tot.chi, 1), "% of total)\n", sep = "")

cat("\nSpecies: share of constrained inertia (inertcomp), and arrow length",
    " (inset label threshold ", inset_sp_min_pct, "% of longest):\n", sep = "")
print(as.data.frame(sp_contrib %>%
  left_join(sp_share, by = c("species" = "variable")) %>%
  left_join(sp_prev,  by = c("species" = "variable")) %>%
  transmute(species, share_pct = round(share_pct, 1),
            n_plots, prev_pct = round(prev_pct, 1),
            arrow_len = round(arrow_len, 2), arrow_pct = round(arrow_pct, 1),
            labelled = arrow_pct >= inset_sp_min_pct)), row.names = FALSE)
cat("  species shares sum to", round(sum(sp_share$share_pct), 1), "% - they partition\n")

# Interset correlations are no longer drawn (the inset carries direction, as
# arrow angle), but they are still the right thing to quote in text.
cat("\nClimate: marginal share of constrained inertia, plus interset correlations",
    "\n(scaling-free; reported here, not plotted):\n")
print(as.data.frame(clim_share %>%
  left_join(as_tibble(intersetcor(cca_model)[, 1:2], rownames = "variable") %>%
              mutate(variable = full_name(variable)), by = "variable") %>%
  mutate(across(where(is.numeric), \(x) round(x, 3)))), row.names = FALSE)
cat("  climate shares sum to", round(sum(clim_share$share_pct), 1),
    "% - the remaining", round(100 - sum(clim_share$share_pct), 1),
    "% is shared between\n  the collinear constraints and cannot be attributed",
    "(VIF 22-39; r = 0.90 temperatures, 0.95 precipitations).\n")

if (holocene_display_mode == "trajectory") {
  cat("\nTrajectory points per group. The Holocene path is a ", HOLO_BIN,
      "-yr window at 100-yr steps\n(", length(OFFSETS), " bin offsets x ", N_DRAWS,
      " age draws = ", length(OFFSETS) * N_DRAWS, " runs; median across runs), so",
      " `n samples per bin`\nis the median bin occupancy, not a total:\n", sep = "")
  trajectory_audit = traj %>% group_by(site, era) %>%
    summarize(points = n(),
              span = if (first(era) == "holocene")
                       sprintf("%.1f - %.1f ka", max(-order) / 1000,
                               min(-order) / 1000)
                     else "legacy -> resurvey",
              n_per_bin_min = min(n), n_per_bin_median = median(n),
              n_per_bin_max = max(n), .groups = "drop")
} else {
  cat("\nTrajectory points per group. Holocene entries are site x CC/S-era",
      " centroids connected chronologically from CC1 through S4:\n")
  trajectory_audit = traj %>% group_by(site, era) %>%
    summarize(points = n(),
              span = if_else(first(era) == "holocene",
                             "CC1 -> S4", "legacy -> resurvey"),
              n_per_bin_min = min(n), n_per_bin_median = median(n),
              n_per_bin_max = max(n), .groups = "drop")
}
print(as.data.frame(trajectory_audit), row.names = FALSE)

# Bins that exist in too few age draws to be a time step. Reported, not hidden:
# they are the ends of the record, where a single sample's age tail reaches into
# a bin no other draw occupies.
ghost = holo_all %>% filter(draw_frac < min_draw_frac)
cat("\nHolocene bins DROPPED (occupied in < ", 100 * min_draw_frac,
    "% of age draws): ", nrow(ghost), " of ", nrow(holo_all), "\n", sep = "")
if (nrow(ghost))
  print(as.data.frame(ghost %>% group_by(site) %>%
    summarize(n_bins = n(), ages = sprintf("%.2f - %.2f ka", min(bin_mid) / 1000,
                                           max(bin_mid) / 1000),
              max_draw_frac = round(max(draw_frac), 2), .groups = "drop")),
    row.names = FALSE)
if (render_figures) {
  cat("\nWritten: plot/", cca_figure_stem, ".pdf and .png\n", sep = "")
} else {
  cat("\nFigure rendering skipped; trajectory data and audits were refreshed.\n")
}
