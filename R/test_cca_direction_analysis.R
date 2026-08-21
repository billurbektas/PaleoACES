# Regression gate for the descriptive community-direction analysis.
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(vegan)
})
source(here("R/config.R"))
source(here("R/tracking_metrics.R"))

near = function(x, y, tolerance = 1e-12) {
  isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance = tolerance,
                   check.attributes = FALSE))
}

# Pure cosine behavior, including every undefined-vector route.
synthetic = bind_rows(
  safe_cosine_2d(1, 0, 2, 0),
  safe_cosine_2d(1, 0, -2, 0),
  safe_cosine_2d(1, 0, 0, 2),
  safe_cosine_2d(1e-9, 0, 1, 0),
  safe_cosine_2d(1, 0, 1e-9, 0),
  safe_cosine_2d(Inf, 0, 1, 0)
)
stopifnot(
  near(synthetic$association[1:3], c(1, -1, 0)),
  all(is.na(synthetic$association[4:6])),
  synthetic$small_movement[4],
  synthetic$small_target_vector[5],
  synthetic$nonfinite_input[6],
  identical(synthetic$association_valid, is.finite(synthetic$association))
)

paths = here("output", c(
  "cca_direction_anthropocene_realizations.csv",
  "cca_direction_holocene_realizations.csv.gz",
  "cca_direction_holocene_by_offset.csv.gz",
  "cca_direction_holocene_timeseries.csv",
  "cca_direction_group_summaries.csv",
  "cca_direction_scope_audit.csv"
))
if (!all(file.exists(paths)))
  stop("Missing direction-analysis output(s): ",
       paste(paths[!file.exists(paths)], collapse = ", "))

anth = read_csv(paths[1], show_col_types = FALSE)
holo = read_csv(paths[2], show_col_types = FALSE)
by_offset = read_csv(paths[3], show_col_types = FALSE)
timeseries = read_csv(paths[4], show_col_types = FALSE)
summaries = read_csv(paths[5], show_col_types = FALSE)
scope = read_csv(paths[6], show_col_types = FALSE)

expected_targets = c("taxon" = 13L, "climate" = 4L)
stopifnot(
  nrow(anth) == 10319L,
  nrow(holo) == 259590L,
  nrow(by_offset) == 2635L,
  nrow(timeseries) == 2329L,
  nrow(summaries) == 204L,
  identical(as.integer(table(anth$target_type)[names(expected_targets)] /
                         607L), unname(expected_targets)),
  identical(as.integer(table(holo$target_type)[names(expected_targets)] /
                         15270L), unname(expected_targets)),
  n_distinct(anth$plot_id) == 607L,
  n_distinct(holo$run_id) == 1000L
)

all_associations = c(anth$predicted_association, anth$observed_association,
                     holo$predicted_association, holo$observed_association)
all_differences = c(anth$directional_difference, holo$directional_difference)
stopifnot(
  all(all_associations[is.finite(all_associations)] >= -1),
  all(all_associations[is.finite(all_associations)] <= 1),
  !any(is.infinite(all_associations)),
  all(all_differences[is.finite(all_differences)] >= -2),
  all(all_differences[is.finite(all_differences)] <= 2),
  !any(is.infinite(all_differences)),
  identical(anth$predicted_association_valid,
            is.finite(anth$predicted_association)),
  identical(anth$observed_association_valid,
            is.finite(anth$observed_association)),
  identical(holo$predicted_association_valid,
            is.finite(holo$predicted_association)),
  identical(holo$observed_association_valid,
            is.finite(holo$observed_association)),
  identical(anth$contrast_valid, is.finite(anth$directional_difference)),
  identical(holo$contrast_valid, is.finite(holo$directional_difference)),
  near(anth$directional_difference[anth$contrast_valid],
       anth$predicted_association[anth$contrast_valid] -
         anth$observed_association[anth$contrast_valid]),
  near(holo$directional_difference[holo$contrast_valid],
       holo$predicted_association[holo$contrast_valid] -
         holo$observed_association[holo$contrast_valid]),
  near(anth$absolute_directional_difference[anth$contrast_valid],
       abs(anth$directional_difference[anth$contrast_valid])),
  near(holo$absolute_directional_difference[holo$contrast_valid],
       abs(holo$directional_difference[holo$contrast_valid])),
  all(anth$direct_movement_cosine[is.finite(anth$direct_movement_cosine)] >= -1),
  all(anth$direct_movement_cosine[is.finite(anth$direct_movement_cosine)] <= 1),
  all(holo$direct_angle_degrees[is.finite(holo$direct_angle_degrees)] >= 0),
  all(holo$direct_angle_degrees[is.finite(holo$direct_angle_degrees)] <= 180)
)

# The 153 unchanged modern assemblages have undefined observed direction but
# retain every independently valid predicted association.
stationary = anth |>
  filter(observed_small_movement) |>
  distinct(site, plot_id)
stopifnot(nrow(stationary) == 153L,
          !any(holo$observed_small_movement),
          !any(holo$predicted_small_movement),
          !any(anth$predicted_small_movement))
predicted_stationary = anth |>
  semi_join(stationary, by = c("site", "plot_id"))
stopifnot(nrow(predicted_stationary) == 153L * 17L,
          all(predicted_stationary$predicted_association_valid),
          !any(predicted_stationary$observed_association_valid),
          !any(predicted_stationary$contrast_valid),
          all(is.na(predicted_stationary$directional_difference)))

# Every implemented descriptive group is present, including the two n=2 groups.
anth_support = anth |>
  distinct(site, plot_id, burned) |>
  count(site, burned, name = "n")
expected_anth_support = tribble(
  ~site, ~burned, ~n,
  "MORA", FALSE, 328L,
  "MORA", TRUE,    2L,
  "NOCA", FALSE, 254L,
  "NOCA", TRUE,   23L)
stopifnot(identical(anth_support, expected_anth_support))

holo_support = timeseries |>
  distinct(site, t, climate_state, high_fire) |>
  count(site, climate_state, high_fire, name = "n")
expected_holo_support = tribble(
  ~site, ~climate_state, ~high_fire, ~n,
  "MORA", "climate change",     FALSE,  7L,
  "MORA", "climate change",     TRUE,   8L,
  "MORA", "relative stability", FALSE, 31L,
  "MORA", "relative stability", TRUE,   8L,
  "NOCA", "climate change",     FALSE, 28L,
  "NOCA", "climate change",     TRUE,  12L,
  "NOCA", "relative stability", FALSE, 41L,
  "NOCA", "relative stability", TRUE,   2L)
stopifnot(identical(holo_support, expected_holo_support),
          all(timeseries$n_offsets == 10L))

# Every group summary retains signed predicted-minus-observed contrasts without
# ranking or top-taxon fields.
rank_fields = c("rank", "rank_basis", "association_rank", "top_three_taxon")
stopifnot(
  !any(rank_fields %in% names(summaries)),
  setequal(unique(summaries$target_type), c("taxon", "climate")),
  all(c("predicted_median", "observed_median", "difference_median",
        "difference_q25", "difference_q75", "direct_angle_median") %in%
      names(summaries))
)

# Independently reconstruct one fitted-geometry association.
source(here("R/05_cca_model.R"))
tracking_anth = read_csv(here("output/cca_tracking_anthropocene_plot.csv"),
                         show_col_types = FALSE)
example = slice(tracking_anth, 1)
sp = scores(cca_model, display = "species", choices = 1:2,
            scaling = cca_scaling, hill = cca_hill)
taxon = rownames(sp)[1]
manual_predicted = safe_cosine_2d(
  example$delta_predicted_CCA1, example$delta_predicted_CCA2,
  sp[taxon, 1] - example$p1, sp[taxon, 2] - example$p2)
manual_observed = safe_cosine_2d(
  example$delta_observed_CCA1, example$delta_observed_CCA2,
  sp[taxon, 1] - example$o1, sp[taxon, 2] - example$o2)
recorded = anth |>
  filter(plot_id == str_to_upper(example$plot_id),
         target_type == "taxon", target == taxon)
stopifnot(nrow(recorded) == 1L,
          near(recorded$predicted_association, manual_predicted$association),
          near(recorded$observed_association, manual_observed$association),
          near(recorded$directional_difference,
               manual_predicted$association - manual_observed$association),
          identical(cca_scaling, "sites"), !cca_hill)

# No forbidden inference fields and every upstream hash remained unchanged.
banned_fields = c("prevalence", "dominance", "driver", "era_id")
stopifnot(!any(banned_fields %in% names(anth)),
          !any(banned_fields %in% names(holo)),
          !any(banned_fields %in% names(summaries)),
          all(filter(scope, category == "upstream_input")$unchanged))

if (isTRUE(getOption("paleoaces.render_figures", TRUE))) {
  figures = here(c(
    "plot/fig_cca_direction_differences.pdf",
    "plot/fig_cca_direction_differences.png",
    "plot/test_figures/fig_cca_direction_differences_audit.pdf"
  ))
  stopifnot(all(file.exists(figures)), all(file.info(figures)$size > 1000))
}

cat("PASS: paired community-direction differences, hierarchy, groups, and scope.\n")
