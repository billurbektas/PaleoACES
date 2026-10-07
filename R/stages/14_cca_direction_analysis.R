# =============================================================================
# 14_cca_direction_analysis.R - predicted/observed CCA direction differences
# =============================================================================
# Descriptive direction analysis in the fitted scaling-1, Hill-off CCA1-CCA2
# geometry. For taxa, predicted movement is compared with the vector from its
# initial LC position to the fixed species score, whereas observed movement is
# compared with the vector from its initial WA position to that same score.
# Climate arrows use the common biplot-vector origin. Predicted and observed
# cosines are paired within every plot or Holocene draw x offset x interval
# realization, and their predicted-minus-observed target-alignment discrepancy
# is calculated before any aggregation. The contrast is descriptive, not
# abundance, dominance, prevalence, contribution, driver attribution, or causal
# inference; zero is equality of target-specific cosines, not complete vector
# agreement.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(vegan)
  library(patchwork)
})
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/tracking_metrics.R"), local = TRUE)
source(here("R/helpers/figure_style.R"), local = TRUE)
source(here("R/stages/05_cca_model.R"), local = TRUE)

render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))
DIRECTION_EPSILON = TRACKING_EPSILON

input_paths = here("output", c(
  "cca_tracking_anthropocene_plot.csv",
  "cca_tracking_holocene_realizations.csv",
  "MORA_plot_info_fire.csv",
  "NOCA_fire_assignment_audit.csv",
  "holocene_era_grid.csv",
  "holocene_era_fire_site_frequency.csv"
))
if (!all(file.exists(input_paths)))
  stop("Missing direction-analysis input(s): ",
       paste(input_paths[!file.exists(input_paths)], collapse = ", "))
input_hash_before = unname(tools::md5sum(input_paths))

if (!identical(cca_scaling, "sites") || isTRUE(cca_hill))
  stop("Direction analysis requires scaling='sites' and hill=FALSE.")

species_matrix = scores(cca_model, display = "species", choices = 1:2,
                        scaling = cca_scaling, hill = cca_hill)
climate_matrix = scores(cca_model, display = "bp", choices = 1:2,
                        scaling = cca_scaling, hill = cca_hill)
if (nrow(species_matrix) != 13L ||
    !setequal(rownames(climate_matrix), CCA_CLIMATE_VARS))
  stop("Expected 13 retained taxa and the four configured climate arrows.")

targets = bind_rows(
  as_tibble(species_matrix[, 1:2, drop = FALSE], rownames = "target") |>
    transmute(target_type = "taxon", target,
              target_label = target,
              target_x = CCA1, target_y = CCA2),
  as_tibble(climate_matrix[, 1:2, drop = FALSE], rownames = "target") |>
    transmute(target_type = "climate", target,
              target_label = unname(CLIMATE_VARIABLE_LABELS[target]),
              target_x = CCA1, target_y = CCA2)
)

build_direction_contrasts = function(x, keys) {
  expanded = x |>
    transmute(across(all_of(keys)),
              predicted_origin_x = p1, predicted_origin_y = p2,
              observed_origin_x = o1, observed_origin_y = o2,
              predicted_movement_x = delta_predicted_CCA1,
              predicted_movement_y = delta_predicted_CCA2,
              observed_movement_x = delta_observed_CCA1,
              observed_movement_y = delta_observed_CCA2) |>
    cross_join(targets) |>
    mutate(
      predicted_target_x = if_else(target_type == "taxon",
                                   target_x - predicted_origin_x, target_x),
      predicted_target_y = if_else(target_type == "taxon",
                                   target_y - predicted_origin_y, target_y),
      observed_target_x = if_else(target_type == "taxon",
                                  target_x - observed_origin_x, target_x),
      observed_target_y = if_else(target_type == "taxon",
                                  target_y - observed_origin_y, target_y)
    )
  predicted = safe_cosine_2d(
    expanded$predicted_movement_x, expanded$predicted_movement_y,
    expanded$predicted_target_x, expanded$predicted_target_y,
    epsilon = DIRECTION_EPSILON
  ) |>
    rename_with(~ paste0("predicted_", .x))
  observed = safe_cosine_2d(
    expanded$observed_movement_x, expanded$observed_movement_y,
    expanded$observed_target_x, expanded$observed_target_y,
    epsilon = DIRECTION_EPSILON
  ) |>
    rename_with(~ paste0("observed_", .x))
  direct = safe_cosine_2d(
    expanded$predicted_movement_x, expanded$predicted_movement_y,
    expanded$observed_movement_x, expanded$observed_movement_y,
    epsilon = DIRECTION_EPSILON
  )

  bind_cols(expanded, predicted, observed) |>
    mutate(
      directional_difference = predicted_association - observed_association,
      absolute_directional_difference = abs(directional_difference),
      contrast_valid = predicted_association_valid & observed_association_valid,
      direct_movement_cosine = direct$association,
      direct_angle_degrees = acos(direct_movement_cosine) * 180 / pi,
      direct_direction_valid = direct$association_valid
    ) |>
    select(all_of(keys), target_type, target, target_label,
           predicted_association, observed_association,
           directional_difference, absolute_directional_difference,
           direct_movement_cosine, direct_angle_degrees,
           predicted_movement_magnitude, observed_movement_magnitude,
           predicted_target_magnitude, observed_target_magnitude,
           predicted_nonfinite_input, observed_nonfinite_input,
           predicted_small_movement, observed_small_movement,
           predicted_small_target_vector, observed_small_target_vector,
           predicted_association_valid, observed_association_valid,
           contrast_valid, direct_direction_valid)
}

# Anthropocene ---------------------------------------------------------------
anth = read_csv(input_paths[1], show_col_types = FALSE)
modern_fire = bind_rows(
  read_csv(input_paths[3], show_col_types = FALSE) |>
    transmute(site = "MORA", plot_id = str_to_upper(plot_id), burned = burnt),
  read_csv(input_paths[4], show_col_types = FALSE) |>
    transmute(site = "NOCA", plot_id = str_to_upper(plot_id), burned = burnt)
) |>
  distinct(site, plot_id, .keep_all = TRUE)
anth = anth |>
  mutate(plot_id = str_to_upper(plot_id)) |>
  left_join(modern_fire, by = c("site", "plot_id"))
if (nrow(anth) != 605L || anyNA(anth$burned) ||
    !identical(as.integer(table(anth$site)[c("MORA", "NOCA")]),
               c(330L, 275L)))
  stop("Anthropocene direction scope must contain all 605 fire-classified pairs.")

anth_keys = c("site", "plot_id", "burned")
anth_direction = build_direction_contrasts(anth, anth_keys) |>
  mutate(period = "Anthropocene", .before = site)
if (nrow(anth_direction) != 10285L)
  stop("Unexpected Anthropocene paired direction-row count.")
write_csv(anth_direction,
          here("output/cca_direction_anthropocene_realizations.csv"))

# Holocene realization values ------------------------------------------------
holo = read_csv(input_paths[2], show_col_types = FALSE)
if (nrow(holo) != 15270L ||
    !setequal(unique(holo$offset), seq(0, 900, 100)) ||
    !setequal(unique(holo$draw), seq_len(100)))
  stop("Holocene direction analysis requires the primary 15,270 realizations.")

holo_keys = c("site", "run_id", "draw", "offset", "age_hi", "age_lo",
              "n_min", "sparse_bin")
holo_direction = build_direction_contrasts(holo, holo_keys) |>
  mutate(period = "Holocene", .before = site)
if (nrow(holo_direction) != 259590L)
  stop("Unexpected Holocene paired direction-row count.")
write_csv(holo_direction,
          here("output/cca_direction_holocene_realizations.csv.gz"))

# Draws are summarized inside each offset and actual interval before phase
# offsets or the frozen climate/fire classifications are combined.
holo_by_offset = holo_direction |>
  group_by(site, offset, age_hi, age_lo,
           target_type, target, target_label) |>
  summarize(
    n_total = n(),
    n_valid = sum(contrast_valid),
    n_missing = n_total - n_valid,
    n_sparse = sum(sparse_bin),
    difference_median = safe_stat(directional_difference, stats::median),
    difference_q025 = safe_stat(directional_difference, stats::quantile,
                                probs = .025, names = FALSE),
    difference_q25 = safe_stat(directional_difference, stats::quantile,
                               probs = .25, names = FALSE),
    difference_q75 = safe_stat(directional_difference, stats::quantile,
                               probs = .75, names = FALSE),
    difference_q975 = safe_stat(directional_difference, stats::quantile,
                                probs = .975, names = FALSE),
    direct_cosine_median = safe_stat(direct_movement_cosine, stats::median),
    direct_angle_median = safe_stat(direct_angle_degrees, stats::median),
    .groups = "drop"
  )
if (nrow(holo_by_offset) != 2635L)
  stop("Expected 2,635 Holocene paired draw-within-offset summaries.")
write_csv(holo_by_offset,
          here("output/cca_direction_holocene_by_offset.csv.gz"))

# Match the tracking stage's half-open interval mapping: age_lo <= t < age_hi.
grid = tibble(t = seq(floor(min(holo$age_lo) / 100) * 100,
                      ceiling(max(holo$age_hi) / 100) * 100, by = 100))
holo_grid = holo_by_offset |>
  inner_join(grid, by = join_by(y$t >= x$age_lo, y$t < x$age_hi))
if (anyDuplicated(holo_grid |>
    select(site, offset, target_type, target, t)))
  stop("Direction interval mapping duplicated a site-offset-target date.")

holo_timeseries_all = holo_grid |>
  group_by(site, t, target_type, target, target_label) |>
  summarize(
    difference_estimate = safe_stat(difference_median, stats::median),
    draw_difference_q025 = safe_stat(difference_q025, stats::median),
    draw_difference_q975 = safe_stat(difference_q975, stats::median),
    phase_difference_min = safe_stat(difference_median, base::min),
    phase_difference_q25 = safe_stat(difference_median, stats::quantile,
                                     probs = .25, names = FALSE),
    phase_difference_q75 = safe_stat(difference_median, stats::quantile,
                                     probs = .75, names = FALSE),
    phase_difference_max = safe_stat(difference_median, base::max),
    direct_cosine_estimate = safe_stat(direct_cosine_median, stats::median),
    direct_angle_estimate = safe_stat(direct_angle_median, stats::median),
    n_offsets = n_distinct(offset),
    n_draws_min = min(n_total),
    n_valid_draws_min = min(n_valid),
    n_sparse_draws = sum(n_sparse),
    .groups = "drop"
  ) |>
  filter(n_offsets == 10L)

era_grid = read_csv(input_paths[5], show_col_types = FALSE) |>
  transmute(t, climate_state = era_class)
fire_grid = read_csv(input_paths[6], show_col_types = FALSE) |>
  transmute(site, t = cal_bp, high_fire)
holo_timeseries = holo_timeseries_all |>
  inner_join(era_grid, by = "t") |>
  left_join(fire_grid, by = c("site", "t"))
if (nrow(holo_timeseries) != 2329L || anyNA(holo_timeseries$high_fire) ||
    !setequal(holo_timeseries$climate_state,
              c("climate change", "relative stability")))
  stop("Expected 2,329 completely classified Holocene site-date contrasts.")
write_csv(holo_timeseries,
          here("output/cca_direction_holocene_timeseries.csv"))

# Descriptive group summaries ------------------------------------------------
anth_group = anth_direction |>
  group_by(site, burned, target_type, target, target_label) |>
  summarize(
    n_units = n_distinct(plot_id), n_total = n(),
    n_valid = sum(contrast_valid), n_missing = n_total - n_valid,
    predicted_median = safe_stat(predicted_association, stats::median),
    observed_median = safe_stat(observed_association, stats::median),
    difference_median = safe_stat(directional_difference, stats::median),
    difference_q025 = safe_stat(directional_difference, stats::quantile,
                                probs = .025, names = FALSE),
    difference_q25 = safe_stat(directional_difference, stats::quantile,
                               probs = .25, names = FALSE),
    difference_q75 = safe_stat(directional_difference, stats::quantile,
                               probs = .75, names = FALSE),
    difference_q975 = safe_stat(directional_difference, stats::quantile,
                                probs = .975, names = FALSE),
    direct_cosine_median = safe_stat(direct_movement_cosine, stats::median),
    direct_angle_median = safe_stat(direct_angle_degrees, stats::median),
    .groups = "drop"
  ) |>
  mutate(period = "Anthropocene", climate_state = NA_character_,
         high_fire = NA,
         draw_difference_q025_typical = NA_real_,
         draw_difference_q975_typical = NA_real_,
         phase_difference_min = NA_real_, phase_difference_max = NA_real_) |>
  select(period, site, climate_state, high_fire, burned,
         target_type, target, target_label, everything())

holo_group = holo_timeseries |>
  group_by(site, climate_state, high_fire, target_type, target, target_label) |>
  summarize(
    n_units = n_distinct(t), n_total = n(),
    n_valid = sum(is.finite(difference_estimate)), n_missing = n_total - n_valid,
    predicted_median = NA_real_, observed_median = NA_real_,
    difference_median = safe_stat(difference_estimate, stats::median),
    difference_q025 = safe_stat(difference_estimate, stats::quantile,
                                probs = .025, names = FALSE),
    difference_q25 = safe_stat(difference_estimate, stats::quantile,
                               probs = .25, names = FALSE),
    difference_q75 = safe_stat(difference_estimate, stats::quantile,
                               probs = .75, names = FALSE),
    difference_q975 = safe_stat(difference_estimate, stats::quantile,
                                probs = .975, names = FALSE),
    direct_cosine_median = safe_stat(direct_cosine_estimate, stats::median),
    direct_angle_median = safe_stat(direct_angle_estimate, stats::median),
    draw_difference_q025_typical = safe_stat(draw_difference_q025, stats::median),
    draw_difference_q975_typical = safe_stat(draw_difference_q975, stats::median),
    phase_difference_min = safe_stat(phase_difference_min, base::min),
    phase_difference_max = safe_stat(phase_difference_max, base::max),
    .groups = "drop"
  ) |>
  mutate(period = "Holocene", burned = NA) |>
  select(period, site, climate_state, high_fire, burned,
         target_type, target, target_label, everything())

group_summaries = bind_rows(anth_group, holo_group) |>
  arrange(period, site, climate_state, high_fire, burned, target_type, target)
if (nrow(group_summaries) != 204L)
  stop("Expected 204 descriptive group-summary rows.")
write_csv(group_summaries,
          here("output/cca_direction_group_summaries.csv"))
legacy_ranking = here("output/cca_direction_group_rankings.csv")
if (file.exists(legacy_ranking))
  unlink(legacy_ranking)

# Figures --------------------------------------------------------------------
group_palette = c(
  "Change / high fire" = PAPER_FIRE_RED,
  "Change / no high fire" = "grey55",
  "Stability / high fire" = PAPER_FIRE_RED,
  "Stability / no high fire" = "grey72",
  "Burned" = PAPER_FIRE_RED,
  "Unburned" = "grey55"
)

add_group_labels = function(x) {
  x |>
    mutate(
      comparison_group = if_else(
        period == "Holocene",
        paste(
          if_else(climate_state == "climate change", "Change", "Stability"),
          if_else(high_fire, "high fire", "no high fire"), sep = " / "),
        if_else(burned, "Burned", "Unburned")
      ),
      comparison_group = factor(comparison_group,
        levels = names(group_palette))
    )
}

make_difference_boxplot = function(x, title, unit_text) {
  x = add_group_labels(x) |>
    mutate(target_label = factor(target_label,
      levels = sort(unique(as.character(target_label)))))
  ggplot(x, aes(target_label, directional_difference,
                fill = comparison_group, color = comparison_group)) +
    geom_hline(yintercept = 0, color = "grey35", linewidth = .4) +
    geom_boxplot(position = position_dodge2(width = .82, preserve = "single"),
                 width = .72, outlier.shape = NA, alpha = .72,
                 linewidth = .38, na.rm = TRUE) +
    geom_point(position = position_jitterdodge(
                 jitter.width = .16, jitter.height = 0, dodge.width = .82),
               alpha = .16, size = .4, na.rm = TRUE) +
    facet_grid(. ~ site) +
    scale_y_continuous(limits = c(-2, 2), breaks = seq(-2, 2, 1)) +
    scale_fill_manual(values = group_palette, drop = TRUE,
                      name = "Group") +
    scale_color_manual(values = group_palette, drop = TRUE,
                       name = "Group") +
    labs(title = title,
         subtitle = paste0("Boxplots describe ", unit_text,
           "; points are individual valid units and are not confidence intervals."),
         x = NULL,
         y = "Target-alignment discrepancy\n(predicted cosine - observed cosine)") +
    theme_bw(base_size = 10.5) +
    theme(panel.grid = element_blank(), strip.text = element_text(face = "bold"),
          axis.text.x = element_text(angle = 42, hjust = 1, vjust = 1,
                                     size = 8.5),
          legend.position = "bottom")
}

add_heatmap_groups = function(x) {
  x |>
    mutate(
      comparison_group = case_when(
        period == "Holocene" & climate_state == "climate change" & high_fire ~
          "Holocene: climate change, high fire",
        period == "Holocene" & climate_state == "climate change" ~
          "Holocene: climate change",
        period == "Holocene" & climate_state == "relative stability" & high_fire ~
          "Holocene: climate stability, high fire",
        period == "Holocene" ~ "Holocene: climate stability",
        period == "Anthropocene" & burned ~ "Anthropocene: burned",
        TRUE ~ "Anthropocene: unburned"
      ),
      group_order = case_when(
        period == "Holocene" & climate_state == "climate change" & high_fire ~ 1L,
        period == "Holocene" & climate_state == "climate change" & !high_fire ~ 2L,
        period == "Holocene" & climate_state == "relative stability" & high_fire ~ 3L,
        period == "Holocene" ~ 4L,
        period == "Anthropocene" & burned ~ 5L,
        TRUE ~ 6L
      ),
      group_label = comparison_group
    ) |>
    arrange(group_order, site)
}

make_difference_heatmap = function(x, title, italic_targets = FALSE) {
  target_levels = if (all(x$target_type == "taxon")) {
    targets |>
      filter(target_type == "taxon") |>
      pull(target_label)
  } else {
    targets |>
      filter(target_type == "climate") |>
      pull(target_label)
  }
  x = add_heatmap_groups(x) |>
    mutate(
      target_label = factor(target_label, levels = rev(target_levels))
    )
  x$group_label = factor(x$group_label,
                         levels = unique(x$group_label))

  ggplot(x, aes(group_label, target_label, fill = difference_median)) +
    geom_tile(color = "white", linewidth = .65) +
    facet_wrap(vars(site), nrow = 1) +
    scale_fill_gradient2(
      low = PAPER_SIGNED_COLORS[["low"]],
      mid = PAPER_SIGNED_COLORS[["mid"]],
      high = PAPER_SIGNED_COLORS[["high"]],
      midpoint = 0, limits = c(-2, 2), breaks = seq(-2, 2, 1),
      na.value = "grey80",
      name = "Target-alignment discrepancy\n(predicted - observed)",
      guide = guide_colorbar(
        barwidth = grid::unit(8, "cm"),
        barheight = grid::unit(.65, "cm"),
        frame.colour = "grey35",
        ticks.colour = "white"
      )
    ) +
    labs(title = title, x = NULL, y = NULL) +
    theme_paleoaces(base_size = 13) +
    theme(
      panel.grid = element_blank(),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.text.y = element_text(size = 14,
                                 face = if (italic_targets) "italic" else "plain"),
      strip.text = element_text(face = "bold", size = 14),
      legend.position = "bottom",
      plot.title = element_text(face = "bold", size = 16),
      plot.margin = margin(6, 8, 3, 8)
    )
}

make_common_group_axis = function(x) {
  axis_data = add_heatmap_groups(x) |>
    distinct(site, group_order, group_label, period, climate_state,
             high_fire, burned) |>
    mutate(
      group_label = factor(group_label,
        levels = unique(group_label[order(group_order)])),
      condition_label = case_when(
        period != "Holocene" ~ "",
        climate_state == "relative stability" ~ "climate stability",
        TRUE ~ climate_state),
      disturbance_label = case_when(
        period == "Holocene" & high_fire ~ "high fire",
        period == "Anthropocene" & burned ~ "burned",
        period == "Anthropocene" ~ "unburned",
        TRUE ~ ""
      )
    )

  ggplot(axis_data, aes(group_label)) +
    geom_text(aes(y = 1.86, label = period),
              color = "grey15", fontface = "bold", size = 4.15) +
    geom_text(aes(y = 1.52, label = condition_label),
              color = "grey20", size = 4.15) +
    geom_text(aes(y = 1.18, label = disturbance_label,
              color = disturbance_label %in% c("high fire", "burned")),
              fontface = "bold", size = 4.15) +
    facet_wrap(vars(site), nrow = 1) +
    scale_color_manual(
      values = c("TRUE" = PAPER_FIRE_RED, "FALSE" = "grey35"),
      guide = "none"
    ) +
    scale_y_continuous(limits = c(1.05, 2.00)) +
    labs(x = NULL, y = NULL) +
    theme_paleoaces(base_size = 13) +
    theme(
      panel.grid = element_blank(),
      panel.border = element_blank(),
      axis.text = element_blank(),
      axis.ticks = element_blank(),
      strip.text = element_blank(),
      strip.background = element_blank(),
      plot.margin = margin(0, 5.5, 0, 5.5)
    )
}

anth_plot = anth_direction |>
  mutate(period = "Anthropocene", climate_state = NA_character_, high_fire = NA)
holo_plot = holo_timeseries |>
  mutate(period = "Holocene",
         burned = NA,
         directional_difference = difference_estimate)

common_group_axis = make_common_group_axis(group_summaries)

main_figure =
  make_difference_heatmap(
    filter(group_summaries, target_type == "climate"),
    "A. Climate") /
  make_difference_heatmap(
    filter(group_summaries, target_type == "taxon"),
    "B. Species", italic_targets = TRUE) /
  common_group_axis +
  plot_layout(heights = c(.46, 1.38, .25), guides = "collect") &
  theme(legend.position = "bottom",
        legend.title = element_text(size = 14.5),
        legend.text = element_text(size = 13.5),
        legend.key.width = grid::unit(9, "cm"),
        legend.key.height = grid::unit(.75, "cm"))

audit_pages = list(
  make_difference_boxplot(filter(holo_plot, target_type == "taxon"),
    "Holocene taxon-direction audit (NOCA stability/high-fire has n = 2 dates)",
    "site-date estimates after the full chronology hierarchy"),
  make_difference_boxplot(filter(anth_plot, target_type == "taxon"),
    "Anthropocene taxon-direction audit (MORA burned has n = 2 plots)",
    "paired ecological plots"),
  make_difference_boxplot(bind_rows(
      filter(holo_plot, target_type == "climate")),
    "Holocene climate-arrow direction-difference audit",
    "hierarchically summarized site-dates") /
  make_difference_boxplot(filter(anth_plot, target_type == "climate"),
    "Anthropocene climate-arrow direction-difference audit",
    "paired ecological plots")
)

if (render_figures) {
  ggsave(here("plot/fig_cca_direction_differences.pdf"), main_figure,
         width = 18, height = 10.5)
  ggsave(here("plot/fig_cca_direction_differences.png"), main_figure,
         width = 18, height = 10.5, dpi = 300, bg = "white")
  audit_pdf = here("plot/test_figures/fig_cca_direction_differences_audit.pdf")
  pdf(audit_pdf, width = 14, height = 22, onefile = TRUE)
  walk(audit_pages, print)
  dev.off()
  legacy_figures = here(c(
    "plot/fig_cca_direction_associations.pdf",
    "plot/fig_cca_direction_associations.png",
    "plot/test_figures/fig_cca_direction_associations_audit.pdf",
    paste0("plot/test_figures/fig_cca_direction_associations_audit_page",
           1:3, ".png")
  ))
  unlink(legacy_figures[file.exists(legacy_figures)])
}

# Scope and immutability audit ------------------------------------------------
input_hash_after = unname(tools::md5sum(input_paths))
if (!identical(input_hash_before, input_hash_after))
  stop("Direction stage modified an upstream analytical input.")
relative_inputs = sub(paste0(here(), "/"), "", input_paths, fixed = TRUE)
scope_audit = bind_rows(
  tibble(
    category = "setting",
    item = c("cca_scaling", "cca_hill", "axes", "epsilon",
             "contrast_definition",
             "taxa", "climate_variables", "anthropocene_pairs",
             "holocene_realizations", "anthropocene_contrast_rows",
             "holocene_contrast_rows", "holocene_offset_rows",
             "holocene_site_date_rows", "group_summary_rows",
             "anthropocene_small_observed_movements"),
    value = as.character(c(
      cca_scaling, cca_hill, "CCA1;CCA2", DIRECTION_EPSILON,
      "predicted_association - observed_association",
      nrow(species_matrix), nrow(climate_matrix), nrow(anth), nrow(holo),
      nrow(anth_direction), nrow(holo_direction), nrow(holo_by_offset),
      nrow(holo_timeseries), nrow(group_summaries),
      n_distinct(anth_direction$plot_id[
        anth_direction$observed_small_movement])
    )),
    md5_before = NA_character_, md5_after = NA_character_, unchanged = NA
  ),
  tibble(category = "upstream_input", item = relative_inputs, value = NA_character_,
         md5_before = input_hash_before, md5_after = input_hash_after,
         unchanged = input_hash_before == input_hash_after)
)
write_csv(scope_audit, here("output/cca_direction_scope_audit.csv"))

cat("Community-direction difference analysis written: ",
    format(nrow(anth_direction), big.mark = ","), " Anthropocene and ",
    format(nrow(holo_direction), big.mark = ","),
    " Holocene paired contrast rows; 204 descriptive group summaries.",
    if (render_figures) " Figures rendered.\n" else " Figure rendering skipped.\n",
    sep = "")
