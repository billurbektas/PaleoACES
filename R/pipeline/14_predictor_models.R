# 14 Explanatory models (PLAN.md section 5, Step 5).
# Holocene: within the lake-periods, does more climate change or more fire go
# with a larger lag, and with better or worse pace and direction?
# Anthropocene counterpart: burned against unburned plots, by park.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(nlme)})
source(here('R/helpers/reconstruction_models.R'), local = TRUE)

both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE)
responses = c('lag_rate', 'pace_effect', 'direction_effect')
results_dir = out('community_predictor_models')
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

holocene_rows = function(response) {
  d = both |> filter(period_type != 'Anthropocene') |> mutate(estimate = .data[[response]])
  keep = is.finite(d$estimate) & d$fire_coverage_valid %in% TRUE & is.finite(d$fire_activity)
  list(data = d[keep, ] |> mutate(site = factor(site, levels = c('MORA', 'NOCA'))) |> arrange(lake, unit_index),
    excluded = d[!keep, ] |> mutate(response = response, exclusion = if_else(!is.finite(estimate),
      'undefined_response', 'no_fire_coverage')))
}
anthropocene_rows = function(response) {
  d = both |> filter(period_type == 'Anthropocene') |> mutate(estimate = .data[[response]])
  keep = is.finite(d$estimate)
  list(data = d[keep, ] |> mutate(site = factor(site, levels = c('MORA', 'NOCA')),
      burned = factor(burned, levels = c(FALSE, TRUE), labels = c('Unburned', 'Burned'))),
    excluded = d[!keep, ] |> mutate(response = response, exclusion = 'undefined_response'))
}

fits = coefficients = performance = exclusions = lines = residuals = list()
for (response in responses) {
  h = holocene_rows(response); d = h$data
# report-snippet: holocene-explanatory-model
  # AR(1) on the lake-period order within lake, fixed a priori (PLAN.md row 7).
  # varFixed gives single-scoop ends less weight; varIdent lets the parks keep
  # different residual spread.
  captured = reconstruction_capture(function() gls(estimate ~ site + climate_rate + fire_activity,
    correlation = corAR1(form = ~ unit_index | lake),
    weights = varComb(varIdent(form = ~ 1 | site), varFixed(~ endpoint_var)),
    data = d, method = 'REML', control = glsControl(msMaxIter = 500)))
# end-snippet: holocene-explanatory-model
  if (is.null(captured$fit)) stop('Holocene explanatory GLS failed: ', response, ': ', captured$error)
  fit = captured$fit
  variance = coef(fit$modelStruct$varStruct, unconstrained = FALSE)
  coefficients[[paste(response, 'Holocene')]] = reconstruction_coefficients(fit, response, 'Holocene', 'AR1')
  performance[[paste(response, 'Holocene')]] = tibble(response, era = 'Holocene', model = 'site + climate_rate + fire_activity',
    n = nrow(d), n_MORA = sum(d$site == 'MORA'), n_NOCA = sum(d$site == 'NOCA'),
    R2 = reconstruction_r2(d$estimate, fitted(fit)),
    AR1_phi = as.numeric(coef(fit$modelStruct$corStruct, unconstrained = FALSE)),
    sd_ratio_NOCA_to_MORA = unname(variance[grepl('NOCA', names(variance))]),
    warnings = paste(captured$warnings, collapse = '; '))
  exclusions[[paste(response, 'Holocene')]] = h$excluded

  # Partial effects for Figure 6A: per park, over that park's own range of the
  # focal predictor, the other predictor at the park's mean.
  beta = coef(fit); V = vcov(fit); tq = qt(.975, fit$dims$N - fit$dims$p)
  design = function(site, climate, fire) cbind(1, site == 'NOCA', climate, fire)
  for (focal in c('climate_rate', 'fire_activity')) {
    other = setdiff(c('climate_rate', 'fire_activity'), focal)
    for (park in c('MORA', 'NOCA')) {
      dp = d[d$site == park, ]
      grid = seq(min(dp[[focal]]), max(dp[[focal]]), length.out = 50)
      held = mean(dp[[other]])
      X = if (focal == 'climate_rate') design(park, grid, held) else design(park, held, grid)
      fitv = as.numeric(X %*% beta); se = sqrt(rowSums((X %*% V) * X))
      lines[[paste(response, focal, park)]] = tibble(response, predictor = focal, site = park,
        x = grid, held_at = held, fit = fitv, conf_low = fitv - tq * se, conf_high = fitv + tq * se)
      Xi = if (focal == 'climate_rate') design(park, dp$climate_rate, held) else design(park, held, dp$fire_activity)
      residuals[[paste(response, focal, park)]] = dp |> transmute(response, predictor = focal, site = park,
        lake, period, period_type, unit_index, x = .data[[focal]],
        partial_residual = as.numeric(Xi %*% beta) + (estimate - as.numeric(fitted(fit))[d$site == park]))
    }
  }
  fits[[paste(response, 'Holocene')]] = fit

  a = anthropocene_rows(response); da = a$data
# report-snippet: anthropocene-explanatory-model
  captured = reconstruction_capture(function() gls(estimate ~ site + burned,
    weights = varIdent(form = ~ 1 | site), data = da, method = 'REML'))
# end-snippet: anthropocene-explanatory-model
  if (is.null(captured$fit)) stop('Anthropocene explanatory GLS failed: ', response, ': ', captured$error)
  fit = captured$fit
  variance = coef(fit$modelStruct$varStruct, unconstrained = FALSE)
  coefficients[[paste(response, 'Anthropocene')]] = reconstruction_coefficients(fit, response, 'Anthropocene', 'Independent')
  performance[[paste(response, 'Anthropocene')]] = tibble(response, era = 'Anthropocene', model = 'site + burned',
    n = nrow(da), n_MORA = sum(da$site == 'MORA'), n_NOCA = sum(da$site == 'NOCA'),
    R2 = reconstruction_r2(da$estimate, fitted(fit)), AR1_phi = NA_real_,
    sd_ratio_NOCA_to_MORA = unname(variance[grepl('NOCA', names(variance))]),
    warnings = paste(captured$warnings, collapse = '; '))
  # Fitted means for Figure 6B: MORA unburned, NOCA unburned, NOCA burned.
  groups = tibble(site = factor(c('MORA', 'NOCA', 'NOCA'), levels = c('MORA', 'NOCA')),
    burned = factor(c('Unburned', 'Unburned', 'Burned'), levels = c('Unburned', 'Burned')))
  X = model.matrix(~ site + burned, groups); Va = vcov(fit); ta = qt(.975, fit$dims$N - fit$dims$p)
  m = as.numeric(X %*% coef(fit)); se = sqrt(rowSums((X %*% Va) * X))
  lines[[paste(response, 'burned')]] = groups |> mutate(response, predictor = 'burned', site = as.character(site),
    burned = as.character(burned), fit = m, conf_low = m - ta * se, conf_high = m + ta * se,
    n = vapply(seq_len(3), function(i) sum(da$site == groups$site[i] & da$burned == groups$burned[i]), integer(1)))
  exclusions[[paste(response, 'Anthropocene')]] = a$excluded
  fits[[paste(response, 'Anthropocene')]] = fit
}

tables = list(model_coefficients = bind_rows(coefficients), model_performance = bind_rows(performance),
  partial_effects = bind_rows(lines), partial_residuals = bind_rows(residuals),
  model_exclusions = bind_rows(exclusions) |> select(response, period_type, site, lake, plot_id, period, exclusion))
for (name in names(tables)) write_csv(tables[[name]], file.path(results_dir, paste0(name, '.csv')))
saveRDS(fits, file.path(results_dir, 'primary_fits.rds'))
writeLines(c('Step 5 explanatory GLS. Intervals are conditional 95% confidence intervals.',
  'R2 = 1 - SSE/SST, descriptive. Variance ratio: residual SD of NOCA relative to MORA.',
  unlist(lapply(names(fits), function(n) c('', n, capture.output(print(summary(fits[[n]]))))))),
  file.path(results_dir, 'model_results.txt'))
print(as.data.frame(tables$model_performance |> select(-warnings)), digits = 3)
