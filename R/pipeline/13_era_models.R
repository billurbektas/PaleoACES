# 13 Era models (PLAN.md section 5, Step 5a): Holocene stability periods,
# Holocene climate-change periods and the Anthropocene compared within each
# park, for climate change rate, turnover rate, lag rate, pace effect and
# direction effect, and the joint pace and direction model. The Holocene is
# never pooled into one value and the parks are never pooled (standing rule).
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

means = contrasts = folds = summary_rows = coefficient_rows = predictions = list(); fits = list()
for (response in names(ERA_RESPONSES)) {
  d = both |> mutate(estimate = .data[[response]]) |> filter(is.finite(estimate))
  # Rule (standing rule, PLAN.md section 4): all six period type x park groups are present.
  stopifnot(nlevels(droplevels(d$period_type_site)) == 6L)
# report-snippet: era-model
  # AR(1) on the unit order within each series, fixed a priori (PLAN.md row 7):
  # a lake for Holocene rows, a plot (one unit) for Anthropocene rows.
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
  summary_rows[[response]] = tibble(response, n = nrow(d),
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
tables = list(era_means = bind_rows(means), era_contrasts = bind_rows(contrasts), era_folds = bind_rows(folds),
  era_model_summary = bind_rows(summary_rows), era_coefficients = bind_rows(coefficient_rows),
  era_predictions = bind_rows(predictions), era_durations = durations)
for (name in names(tables)) write_csv(tables[[name]], file.path(results_dir, paste0(name, '.csv')))
saveRDS(fits, file.path(results_dir, 'primary_fits.rds'))
writeLines(c('Step 5a era models: estimate ~ period_type * site, AR(1) within series, endpoint weights.',
  'Intervals are conditional 95% confidence intervals with residual degrees of freedom.',
  unlist(lapply(names(fits), function(n) c('', n, capture.output(print(summary(fits[[n]]))))))),
  file.path(results_dir, 'model_results.txt'))
print(as.data.frame(tables$era_folds), digits = 3)

# Joint pace and direction model: the two corrections on the same units, with
# their within-unit correlation estimated for each era x park.
d = tracking_joint_correction_input(both)
joint_out = out('era_comparison/joint_correction_effects')
dir.create(joint_out, recursive = TRUE, showWarnings = FALSE)
captured = reconstruction_capture(function() {
# report-snippet: joint-correction-model
  gls(estimate ~ period_type * site * correction, data = d,
    correlation = corPairedAR1(sort(unique(d$pair_group))),
    weights = varComb(varIdent(form = ~ 1 | period_type_site_correction), varFixed(~ endpoint_var)),
    method = 'REML', na.action = na.fail, control = glsControl(msMaxIter = 500))
# end-snippet: joint-correction-model
})
fit = captured$fit
if (is.null(fit)) stop('Joint correction GLS failed: ', captured$error)
grid = expand_grid(site = factor(c('MORA', 'NOCA'), levels = c('MORA', 'NOCA')),
  period_type = factor(ERA_PERIOD_TYPES, levels = ERA_PERIOD_TYPES),
  correction = factor(c('Pace', 'Direction'), levels = c('Pace', 'Direction')))
X = model.matrix(~ period_type * site * correction, grid)
joint_means = bind_cols(grid, linear(fit, X)) |> mutate(n = pmap_int(list(as.character(site),
  as.character(period_type), as.character(correction)), function(s, p, k) sum(d$site == s & d$period_type == p & d$correction == k)))
holm = function(x, family) x |> mutate(p_adjusted = p.adjust(p_value, 'holm'), adjustment = paste('Holm across', n(), family))
key = paste(grid$site, grid$period_type, grid$correction)
correction_contrasts = holm(bind_rows(lapply(seq_len(nrow(groups)), function(i) {
  g = paste(groups$site[i], groups$period_type[i])
  L = X[key == paste(g, 'Direction'), , drop = FALSE] - X[key == paste(g, 'Pace'), , drop = FALSE]
  tibble(site = groups$site[i], period_type = groups$period_type[i], contrast = 'Direction - Pace') |> bind_cols(linear(fit, L))
})), 'within period type and park correction comparisons')
period_contrasts = holm(bind_rows(lapply(c('MORA', 'NOCA'), function(park) bind_rows(lapply(c('Pace', 'Direction'), function(k) {
  sel = grid$site == park & grid$correction == k
  tibble(site = park, correction = k, contrast = vapply(CONTRASTS, paste, character(1), collapse = ' - ')) |>
    bind_cols(linear(fit, contrast_rows(X[sel, , drop = FALSE], as.character(grid$period_type[sel]), CONTRASTS)))
})))), 'within park and correction period type comparisons')
parameters = coef(fit$modelStruct$corStruct, unconstrained = FALSE)
write_csv(d, file.path(joint_out, 'model_input.csv'))
write_csv(joint_means, file.path(joint_out, 'model_group_means.csv'))
write_csv(correction_contrasts, file.path(joint_out, 'correction_contrasts.csv'))
write_csv(period_contrasts, file.path(joint_out, 'period_type_contrasts.csv'))
write_csv(tibble(parameter = names(parameters), estimate = unname(parameters),
  warnings = paste(captured$warnings, collapse = '; ')), file.path(joint_out, 'correlation_parameters.csv'))
writeLines(c('Joint pace and direction GLS: estimate ~ period_type * site * correction, paired AR(1).',
  capture.output(print(summary(fit)))), file.path(joint_out, 'model_results.txt'))
saveRDS(fit, file.path(joint_out, 'primary_fit.rds'))

if (isTRUE(getOption('paleoaces.render_figures', TRUE))) {
  joint_predictions = d |> transmute(metric = as.character(correction), era = as.character(period_type), site,
    predicted = as.numeric(fitted(fit)), normalized_residual = as.numeric(residuals(fit, type = 'normalized')))
  tracking_pdf_pages(list(reconstruction_residual_plot(tables$era_predictions),
      reconstruction_residual_plot(joint_predictions)),
    tracking_model_figure('fig_tracking_model_residuals.pdf'), width = 14, height = 12)
}
cat('Era models:', length(fits), 'responses; joint model on', nrow(d) / 2, 'paired units.\n')
