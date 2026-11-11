# 13 Era models (PLAN.md section 5, Step 5a): Holocene stability periods,
# Holocene climate-change periods and the Anthropocene compared within each
# park, for climate change rate, climate change, turnover rate, displacement,
# lag rate, lag, pace effect and direction effect, each per century and as a
# total. Climate change, displacement, lag and the effect totals are not divided
# by time (Bills, 10 Nov 2026). The Holocene is never pooled into one value and
# the parks are never pooled (standing rule). The joint pace and direction model
# was removed (Bills, 11 Nov 2026): the two effects are compared between the
# period types in their own era models only.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(nlme); library(patchwork)})
source(here('R/helpers/reconstruction_models.R'), local = TRUE)

both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE) |>
  mutate(period_type = factor(period_type, levels = ERA_PERIOD_TYPES), site = factor(site, levels = c('MORA', 'NOCA')),
    period_type_site = interaction(period_type, site, drop = TRUE, sep = ' ')) |>
  arrange(series, unit_index)
results_dir = out('era_comparison')
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
groups = expand_grid(site = factor(c('MORA', 'NOCA'), levels = c('MORA', 'NOCA')),
  period_type = factor(ERA_PERIOD_TYPES, levels = ERA_PERIOD_TYPES))

# Linear combinations of the fixed effects, with conditional 95% intervals and
# residual degrees of freedom, as in the Step 5 models.
linear = function(fit, L) {
  L = L[, names(coef(fit)), drop = FALSE]
  est = as.numeric(L %*% coef(fit)); se = sqrt(rowSums((L %*% vcov(fit)) * L))
  df = fit$dims$N - fit$dims$p; q = qt(.975, df)
  tibble(estimate = est, std_error = se, df, conf_low = est - q * se, conf_high = est + q * se,
    p_value = 2 * pt(-abs(est / se), df))
}
contrast_rows = function(X, labels, pairs) {
  L = t(vapply(pairs, function(p) X[labels == p[1], ] - X[labels == p[2], ], numeric(ncol(X))))
  colnames(L) = colnames(X); L
}
CONTRASTS = list(c('Anthropocene', 'Holocene-C'), c('Anthropocene', 'Holocene-S'), c('Holocene-C', 'Holocene-S'))
# Multiple comparisons (Bills, 10 Nov 2026): Holm-adjusted p-values within each
# family of group contrasts. The intervals stay unadjusted 95% intervals.
holm = function(x, family) x |> mutate(p_adjusted = p.adjust(p_value, 'holm'), adjustment = paste('Holm across', n(), family))

means = contrasts = folds = summary_rows = coefficient_rows = predictions = list(); fits = list()
for (response in names(ERA_RESPONSES)) {
  d = both |> mutate(estimate = .data[[response]]) |> filter(is.finite(estimate))
  # Rule (standing rule, PLAN.md section 4): all six period type x park groups are present.
  stopifnot(nlevels(droplevels(d$period_type_site)) == 6L)
# report-snippet: era-model
  # One model per response (climate change rate, climate change, turnover rate,
  # displacement, lag rate, lag, pace effect, direction effect and their totals).
  # Climate change, displacement, lag and the effect totals are totals between
  # the two ends, the others per century.
  # Each row is a Holocene lake-period or an
  # Anthropocene plot pair; `estimate` is its value of the response.
  # Mean part, period_type * site: one mean for each period type (Holocene-S,
  # Holocene-C, Anthropocene) in each park. The era means, the contrasts
  # (Anthropocene minus each Holocene type) and the folds come from these.
  # gls (generalized least squares, nlme) is a regression whose errors may be
  # correlated and unequal:
  #   correlation: consecutive lake-periods of one lake are correlated, AR(1)
  #     along the unit order within each series (a lake; each Anthropocene plot
  #     is a series of one unit);
  #   weights: each period type in each park has its own spread (varIdent), and
  #     ends that rest on few samples are noisier, in proportion to
  #     endpoint_var = 1/n_start + 1/n_end (varFixed).
  captured = reconstruction_capture(function() gls(estimate ~ period_type * site,
    correlation = corAR1(form = ~ unit_index | series),
    weights = varComb(varIdent(form = ~ 1 | period_type_site), varFixed(~ endpoint_var)),
    data = d, method = 'REML', control = glsControl(msMaxIter = 500)))
# end-snippet: era-model
  if (is.null(captured$fit)) stop('Era model failed: ', response, ': ', captured$error)
  fit = captured$fit; fits[[response]] = fit
  X = model.matrix(~ period_type * site, groups)
  m = bind_cols(groups, linear(fit, X)) |>
    mutate(response, n = map2_int(as.character(site), as.character(period_type),
      ~ sum(d$site == .x & d$period_type == .y)), .before = 1)
  means[[response]] = m
  for (park in c('MORA', 'NOCA')) {
    Xp = X[groups$site == park, , drop = FALSE]; labels = as.character(groups$period_type[groups$site == park])
    contrasts[[paste(response, park)]] = tibble(response, site = park,
      contrast = vapply(CONTRASTS, paste, character(1), collapse = ' - ')) |>
      bind_cols(linear(fit, contrast_rows(Xp, labels, CONTRASTS)))
    # Folds for the positive responses (PLAN.md Step 5a; absolute lag added by
    # Bills) and, at Bills's request, for the signed lag rate, whose near-zero
    # Holocene means make that fold unstable (said in the caption).
    if (response %in% c('climate_rate', 'turnover_rate', 'lag_rate')) {
      mp = m[m$site == park, ]
      folds[[paste(response, park)]] = tibble(response, site = park,
        against = c('Holocene-C', 'Holocene-S'),
        fold = mp$estimate[mp$period_type == 'Anthropocene'] / mp$estimate[match(c('Holocene-C', 'Holocene-S'), mp$period_type)],
        quoted_as_speed = against == 'Holocene-C' & response != 'lag_rate')
    }
  }
  variance = coef(fit$modelStruct$varStruct, unconstrained = FALSE)
  summary_rows[[response]] = tibble(response, n = nrow(d), reconstruction_fit_statistics(fit),
    AR1_phi = as.numeric(coef(fit$modelStruct$corStruct, unconstrained = FALSE)),
    variance_parameters = paste(sprintf('%s=%.3f', names(variance), variance), collapse = ';'),
    R2 = reconstruction_r2(d$estimate, fitted(fit)), warnings = paste(captured$warnings, collapse = '; '))
  coefficient_rows[[response]] = reconstruction_coefficients(fit, response, 'Combined', 'AR1')
  predictions[[response]] = d |> transmute(metric = response, era = as.character(period_type), site,
    series, unit_index, estimate, predicted = as.numeric(fitted(fit)),
    normalized_residual = as.numeric(residuals(fit, type = 'normalized')))
}
durations = both |> group_by(period_type, site) |>
  summarise(n = n(), duration_min = min(duration_yr), duration_max = max(duration_yr), .groups = 'drop')
# Displacement and lag are totals over a lake-period, so they grow with its
# duration. This table (Bills, 10 Nov 2026) shows by how much, per park, in the
# three duration classes the lake-periods fall into. Plain means, no model.
duration_classes = both |> filter(period_type != 'Anthropocene') |>
  # The lake-periods last 200 to 900 years or 1,900 years and more, with nothing in
  # between (the top class was 'over 2,000 years' until the slice dating fix of
  # 11 Nov 2026 made one MORA lake-period 1,900 years long).
  mutate(duration_class = case_when(duration_yr >= 200 & duration_yr <= 400 ~ '200 to 400 years',
    duration_yr >= 500 & duration_yr <= 900 ~ '500 to 900 years', duration_yr >= 1000 ~ '1,000 years or more',
    TRUE ~ 'other durations')) |>
  group_by(site, duration_class) |>
  summarise(lake_periods = n(), stability = sum(period_type == 'Holocene-S'),
    climate_change = sum(period_type == 'Holocene-C'), duration_min = min(duration_yr),
    duration_max = max(duration_yr), mean_displacement = mean(displacement),
    mean_absolute_lag = mean(abs(lag)), mean_lag = mean(lag), .groups = 'drop')
# One family per response: its three period-type contrasts in each park.
era_contrasts = bind_rows(contrasts) |> group_by(response) |>
  group_modify(\(x, key) holm(x, 'period-type contrasts of the response (3 per park)')) |> ungroup() |>
  relocate(response)
tables = list(era_means = bind_rows(means), era_contrasts = era_contrasts, era_folds = bind_rows(folds),
  era_model_summary = bind_rows(summary_rows), era_coefficients = bind_rows(coefficient_rows),
  era_predictions = bind_rows(predictions), era_durations = durations, era_duration_classes = duration_classes)
for (name in names(tables)) write_csv(tables[[name]], file.path(results_dir, paste0(name, '.csv')))
saveRDS(fits, file.path(results_dir, 'primary_fits.rds'))
writeLines(c('Step 5a era models: estimate ~ period_type * site, AR(1) within series, endpoint weights.',
  'Intervals are conditional 95% confidence intervals with residual degrees of freedom.',
  unlist(lapply(names(fits), function(n) c('', n, capture.output(print(summary(fits[[n]]))))))),
  file.path(results_dir, 'model_results.txt'))
print(as.data.frame(tables$era_folds), digits = 3)

if (isTRUE(getOption('paleoaces.render_figures', TRUE))) {
  # Fig. S16 of the README (Bills, 11 Nov 2026: model checks shown with the
  # results): residuals of the era models.
  ggsave(fig('supplementary', 'figS16_era_model_residuals.pdf'), reconstruction_residual_plot(tables$era_predictions),
    width = 14, height = 12, device = cairo_pdf)
}
cat('Era models:', length(fits), 'responses.\n')
