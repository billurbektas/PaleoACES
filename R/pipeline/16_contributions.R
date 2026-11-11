# 15 Species contributions (PLAN.md section 5, Step 6): which species led the
# climate-aligned movement (contrib_climate), and which widened or narrowed the
# climate-community lag (contrib_lag, Bills 11 Nov 2026), per lake-period and
# per plot pair; then the group means per species, park and period type. Seasonal-climate contributions to the predicted movement are
# kept as a descriptive table.

# =============================================================================
# 1. Contributions per lake-period and per plot pair
# =============================================================================
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan)})
source(here('R/helpers/century_tracking.R'), local = TRUE)
source(here('R/helpers/lake_periods.R'), local = TRUE)
source(here('R/helpers/cca_transition_contributions.R'), local = TRUE)
bundle = century_prepare(); primary = readRDS(out('chronology_reconstruction/primary.rds'))
basis = contribution_reference(bundle$reference)
units = read_csv(out('cca_tracking_lake_period_calculations.csv'), show_col_types = FALSE)
both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE)
plots = read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE) |>
  lake_period_responses()

weights = century_species_weights(primary, bundle)
first = weights[paste(units$lake, units$age_start), , drop = FALSE]
last = weights[paste(units$lake, units$age_end), , drop = FALSE]
stopifnot(!anyNA(first), !anyNA(last))
context = units |> transmute(era = 'Holocene', period_type, site, lake, plot_id = NA_character_, period,
  series = paste('H', site, lake, sep = '_'), unit_index, age_start, age_end, duration_yr,
  vegetation_dt_years, burned = NA)
# contrib_lag is per century of the lag rate's interval (duration_yr), so that
# the species values and the climate part add up to the lag rate.
holocene = step6_species_contributions(context, first, last, basis$positions, units, units$vegetation_dt_years,
  units$duration_yr)
holocene_lag = step6_lag_decomposition(context, holocene, units, units$duration_yr)

occ = read_csv(out('occ_consolidated.csv'), show_col_types = FALSE)
ids = select(plots, site, plot_id)
first = contribution_weights(contribution_species_matrix(occ, ids, 'past', bundle$reference$retained_species))
last = contribution_weights(contribution_species_matrix(occ, ids, 'present', bundle$reference$retained_species))
context = plots |> transmute(era = 'Anthropocene', period_type = 'Anthropocene', site, lake = NA_character_, plot_id,
  period = 'Anthropocene', series = paste('A', site, plot_id, sep = '_'), unit_index = 1L,
  age_start = NA_real_, age_end = NA_real_, duration_yr = climate_dt_years, vegetation_dt_years, burned)
# Plot contributions are per century of the vegetation interval, like turnover.
# Their contrib_lag is per century of the climate interval, as their lag rate is.
modern = step6_species_contributions(context, first, last, basis$positions, plots, plots$vegetation_dt_years,
  plots$climate_dt_years)
modern_lag = step6_lag_decomposition(context, modern, plots, plots$climate_dt_years)
species = bind_rows(holocene, modern)
# The unit lag rates must be those of the era models (Rule: one lag rate per unit).
lag_parts = bind_rows(holocene_lag, modern_lag)
check = both |> transmute(key = if_else(period_type == 'Anthropocene', paste(site, plot_id), paste(site, lake, period)),
  lag_rate) |> inner_join(lag_parts |> transmute(key = if_else(era == 'Anthropocene', paste(site, plot_id),
    paste(site, lake, period)), lag_rate_parts = lag_rate), by = 'key')
stopifnot(nrow(check) == nrow(lag_parts), max(abs(check$lag_rate - check$lag_rate_parts)) < 1e-9)

climate = bind_rows(
  century_climate_contributions(units |> transmute(era = 'Holocene', period_type, site, lake, period, unit_index, age_start, age_end), units, bundle$reference),
  century_climate_contributions(plots |> transmute(era = 'Anthropocene', period_type = 'Anthropocene', site, plot_id), plots, bundle$reference))

results_dir = out('cca_transition_contributions'); dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
write_csv(species, file.path(results_dir, 'species_contributions.csv'))
write_csv(lag_parts, file.path(results_dir, 'lag_decomposition.csv'))
write_csv(climate, file.path(results_dir, 'climate_contributions.csv'))
write_csv(holocene |> select(site, lake, period, period_type, age_start, age_end, duration_yr, species,
  weight_t1, weight_t2, contrib_climate, contrib_lag), file.path(results_dir, 'species_lake_periods.csv'))
cat('Species contributions:', nrow(units), 'lake-periods and', nrow(plots), 'plot pairs x',
  ncol(first), 'species; vectors sum to dWA in every row.\n')

# =============================================================================
# 2. Group means per species, park and period type
# =============================================================================
# Plain means with t-intervals (Bills, 9 Nov 2026): no model of any kind for
# the species. Contrasts between period types are Welch differences of means.
source(here('R/helpers/tracking_model_reporting.R'), local = TRUE)
models_dir = out('species_contribution_models'); dir.create(models_dir, recursive = TRUE, showWarnings = FALSE)
presence = species |> group_by(species, site, period_type) |>
  summarise(present = any(weight_t1 > 0 | weight_t2 > 0), .groups = 'drop')
# contrib_climate exists only where both positions moved (epsilon rule).
# contrib_lag exists in every unit: where the community did not move, every
# species value is zero, and the means plus the climate part still give the
# mean lag rate.
long = species |> pivot_longer(c(contrib_climate, contrib_lag), names_to = 'measure', values_to = 'contribution') |>
  filter(is.finite(contribution))
# report-snippet: species-means
# For one species in one park and period type, x holds its contribution in
# every lake-period (or plot pair). The result is the plain mean with a 95%
# t-interval: mean plus or minus t(0.975, n - 1) times the standard error
# sd / sqrt(n). With a single value the interval is undefined.
group_mean = function(x) {
  n = length(x); m = mean(x); se = if (n > 1) sd(x) / sqrt(n) else NA_real_
  q = if (n > 1) qt(.975, n - 1) else NA_real_
  tibble(n, estimate = m, std_error = se, conf_low = m - q * se, conf_high = m + q * se,
    interval_defined = n > 1 && is.finite(se) && se > 0)
}
# end-snippet: species-means
# The means and Welch contrasts of one table of contributions (per century, or
# not divided by time below).
summarise_species = function(long) {
  means = long |> group_by(measure, species, site, period_type) |>
    reframe(group_mean(contribution)) |>
    left_join(presence, by = c('species', 'site', 'period_type')) |>
    mutate(period_type = factor(period_type, levels = ERA_PERIOD_TYPES)) |> arrange(measure, species, site, period_type)
  pairs = list(c('Anthropocene', 'Holocene-C'), c('Anthropocene', 'Holocene-S'), c('Holocene-C', 'Holocene-S'))
  contrasts = long |> group_by(measure, species, site) |> group_modify(function(d, key) bind_rows(lapply(pairs, function(p) {
    x = d$contribution[d$period_type == p[1]]; y = d$contribution[d$period_type == p[2]]
    test = if (length(x) > 1 && length(y) > 1 && (var(x) > 0 || var(y) > 0)) t.test(x, y) else NULL
    tibble(contrast = paste(p, collapse = ' - '), estimate = mean(x) - mean(y),
      conf_low = if (is.null(test)) NA_real_ else test$conf.int[1], conf_high = if (is.null(test)) NA_real_ else test$conf.int[2],
      df = if (is.null(test)) NA_real_ else unname(test$parameter), p_value = if (is.null(test)) NA_real_ else test$p.value)
  }))) |> ungroup() |>
    # Multiple comparisons (Bills, 10 Nov 2026): Holm-adjusted p-values within one
    # family per measure and park, all species and their three period-type
    # contrasts together. Contrasts without a test (constant groups) are not counted.
    group_by(measure, site) |>
    mutate(p_adjusted = p.adjust(p_value, 'holm'),
      adjustment = paste('Holm across', sum(!is.na(p_value)), 'species contrasts of the measure in the park')) |>
    ungroup()
  list(means = means, contrasts = contrasts)
}
per_century = summarise_species(long)
means = per_century$means; contrasts = per_century$contrasts
# Totals, not divided by time (Bills, 11 Nov 2026; appendix Fig. S17): the
# species' movement along the predicted direction (parallel_contribution) and
# its part of the change in mismatch (lag_projection) over the whole lake-period
# or plot pair. The per-century values above are these times 100 / dt. Same
# means, intervals and Holm families, in their own files.
long_total = species |> transmute(species, site, period_type,
    contrib_climate = if_else(is.finite(contrib_climate), parallel_contribution, NA_real_),
    contrib_lag = lag_projection) |>
  pivot_longer(c(contrib_climate, contrib_lag), names_to = 'measure', values_to = 'contribution') |>
  filter(is.finite(contribution))
totals = summarise_species(long_total)
status = means |> group_by(measure, species, site) |>
  summarise(n = sum(n), all_intervals_defined = all(interval_defined),
    constant_groups = paste(period_type[!interval_defined], collapse = ';'), .groups = 'drop')
# NOCA burned and unburned plots (supplement table, not the figure).
burned = long |> filter(period_type == 'Anthropocene', site == 'NOCA') |>
  group_by(measure, species, burned) |> reframe(group_mean(contribution))
tables = list(species_means = means, species_contrasts = contrasts, species_mean_status = status,
  noca_burned_species_means = burned, species_means_total = totals$means, species_contrasts_total = totals$contrasts)
unlink(list.files(models_dir, full.names = TRUE))
for (name in names(tables)) write_csv(tables[[name]], file.path(models_dir, paste0(name, '.csv')))
cat('Species means:', nrow(means), 'species x park x period type x measure groups;',
  sum(!means$interval_defined), 'without a defined interval (constant or single values).\n')
