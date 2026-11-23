# Figure 4 inputs (PLAN.md section 6): the Anthropocene arrows are the means of
# the plot-pair endpoints, the Holocene period centroids are equal-lake means of
# the sampled centuries in each period, the lakes missing from a period are
# named, and the display rotation is rigid.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan)})
source(here('R/helpers/cca_display_rotation.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))
if (render_figures) {
  files = c(fig('main', 'fig_cca_trajectories.pdf'), fig('main', 'fig_cca_trajectories.png'),
    fig('supplementary', 'figS14_cca_biplot_unrotated.pdf'))
  stopifnot(all(file.exists(files)), all(file.info(files)$size > 5000))
}
plots = read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE)
modern = read_csv(out('figures/cca_trajectory_anthropocene_centroids.csv'), show_col_types = FALSE)
for (park in c('MORA', 'NOCA')) {
  x = plots[plots$site == park, ]; row = modern[modern$site == park, ]
  fields = c('o1', 'o2', 'p1', 'p2', 'o1_2', 'o2_2', 'p1_2', 'p2_2')
  stopifnot(nrow(row) == 1L, row$n == nrow(x),
    max(abs(as.numeric(row[fields]) - vapply(x[fields], mean, numeric(1)))) < 1e-12)
}
periods = read_csv(out('holocene_periods.csv'), show_col_types = FALSE)
positions = read_csv(out('cca_tracking_holocene_century_positions.csv'), show_col_types = FALSE)
centroids = read_csv(out('figures/cca_trajectory_period_centroids.csv'), show_col_types = FALSE)
for (i in seq_len(nrow(centroids))) {
  p = periods[periods$period == centroids$period[i], ]
  inside = positions |> filter(site == centroids$site[i], century_cal_bp < p$older_cal_bp, century_cal_bp >= p$younger_cal_bp)
  lake_means = inside |> group_by(lake) |> summarise(o1 = mean(o1), p2 = mean(p2))
  stopifnot(centroids$n_lakes[i] == nrow(lake_means), abs(centroids$o1[i] - mean(lake_means$o1)) < 1e-12,
    abs(centroids$p2[i] - mean(lake_means$p2)) < 1e-12)
}
# Every period with samples is drawn, also one sampled at fewer lakes than the
# park has (Bills, 23 Nov 2026), and its missing lakes are named for the caption.
park_lakes = positions |> group_by(site) |> summarise(n = n_distinct(lake))
stopifnot(all(centroids$park_lakes == park_lakes$n[match(centroids$site, park_lakes$site)]),
  all(centroids$n_lakes + ifelse(is.na(centroids$missing_lakes), 0L, lengths(strsplit(centroids$missing_lakes, '; '))) ==
    centroids$park_lakes))
spans = read_csv(out('figures/cca_trajectory_holocene_spans.csv'), show_col_types = FALSE)
for (park in spans$site) {
  d = centroids[centroids$site == park, ]
  stopifnot(spans$first_period[spans$site == park] == d$period[which.min(d$order)],
    spans$last_period[spans$site == park] == d$period[which.max(d$order)])
}
# The display rotation preserves every distance between positions.
reference = readRDS(out('cca_calibration_reference.rds'))
rotation = cca_display_rotation(scores(reference$model, display = 'bp', choices = 1:2, scaling = 'sites', hill = FALSE))
xy = as.matrix(centroids[c('o1', 'o2')])
stopifnot(max(abs(dist(xy) - dist(xy %*% rotation$matrix))) < 1e-12,
  abs(abs(det(rotation$matrix)) - 1) < 1e-12)
cat('Figure 4 centroids, Anthropocene means and rigid display rotation checks passed.\n')
