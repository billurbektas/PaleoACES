# 14 Explanatory models (PLAN.md section 5, Step 5).
# Holocene: within the lake-periods, does more climate change or more fire go
# with a larger lag, and with better or worse pace and direction?
# Anthropocene counterpart: burned against unburned plots, by park.
# Each response is modelled per century and as a total not divided by time
# (Bills, 10 Nov 2026).
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(nlme)})
source(here('R/helpers/reconstruction_models.R'), local = TRUE)

both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE)
# The per-century responses go with the climate change rate, the totals with
# the climate change between the two ends. Fire activity is a frequency
# (accepted events per century per core) for both: a total count would grow
# with the length of the lake-period.
climate_term = c(lag_rate = 'climate_rate', pace_effect = 'climate_rate', direction_effect = 'climate_rate',
  lag = 'climate_change', pace_effect_total = 'climate_change', direction_effect_total = 'climate_change')
responses = names(climate_term)
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
  h = holocene_rows(response); d = h$data; climate = climate_term[[response]]
# report-snippet: holocene-explanatory-model
  # Holocene lake-periods only. Does the response go with more climate change
  # or more fire? Fitted twice: per century (lag rate, pace effect, direction
  # effect) with climate = climate_rate, the climate change rate, and as totals
  # not divided by time (lag, pace and direction effect totals) with
  # climate = climate_change, the climate change between the two ends.
  #   site: a separate level for each park;
  #   climate: the slope per unit of climate change (rate or total);
  #   fire_activity: the slope per accepted fire event per century per core.
  # Consecutive lake-periods of a lake are correlated (AR(1) within lake).
  # varIdent lets the parks keep a different spread, and varFixed gives ends
  # resting on single samples less weight (endpoint_var = 1/n_start + 1/n_end).
  model = reformulate(c('site', climate, 'fire_activity'), response = 'estimate')
  captured = reconstruction_capture(function() gls(model,
    correlation = corAR1(form = ~ unit_index | lake),
    weights = varComb(varIdent(form = ~ 1 | site), varFixed(~ endpoint_var)),
    data = d, method = 'REML', control = glsControl(msMaxIter = 500)))
# end-snippet: holocene-explanatory-model
  if (is.null(captured$fit)) stop('Holocene explanatory GLS failed: ', response, ': ', captured$error)
  fit = captured$fit
  variance = coef(fit$modelStruct$varStruct, unconstrained = FALSE)
  coefficients[[paste(response, 'Holocene')]] = reconstruction_coefficients(fit, response, 'Holocene', 'AR1')
  performance[[paste(response, 'Holocene')]] = tibble(response, era = 'Holocene',
    model = paste('site +', climate, '+ fire_activity'),
    n = nrow(d), n_MORA = sum(d$site == 'MORA'), n_NOCA = sum(d$site == 'NOCA'),
    R2 = reconstruction_r2(d$estimate, fitted(fit)),
    AR1_phi = as.numeric(coef(fit$modelStruct$corStruct, unconstrained = FALSE)),
    sd_ratio_NOCA_to_MORA = unname(variance[grepl('NOCA', names(variance))]),
    warnings = paste(captured$warnings, collapse = '; '))
  exclusions[[paste(response, 'Holocene')]] = h$excluded

  # Partial effects for Figure 7A: per park, over that park's own range of the
  # focal predictor, the other predictor at the park's mean.
  beta = coef(fit); V = vcov(fit); tq = qt(.975, fit$dims$N - fit$dims$p)
  design = function(site, climate, fire) cbind(1, site == 'NOCA', climate, fire)
  for (focal in c(climate, 'fire_activity')) {
    other = setdiff(c(climate, 'fire_activity'), focal)
    for (park in c('MORA', 'NOCA')) {
      dp = d[d$site == park, ]
      grid = seq(min(dp[[focal]]), max(dp[[focal]]), length.out = 50)
      held = mean(dp[[other]])
      X = if (focal == climate) design(park, grid, held) else design(park, held, grid)
      fitv = as.numeric(X %*% beta); se = sqrt(rowSums((X %*% V) * X))
      lines[[paste(response, focal, park)]] = tibble(response, predictor = focal, site = park,
        x = grid, held_at = held, fit = fitv, conf_low = fitv - tq * se, conf_high = fitv + tq * se)
      Xi = if (focal == climate) design(park, dp[[climate]], held) else design(park, held, dp$fire_activity)
      residuals[[paste(response, focal, park)]] = dp |> transmute(response, predictor = focal, site = park,
        lake, period, period_type, unit_index, x = .data[[focal]],
        partial_residual = as.numeric(Xi %*% beta) + (estimate - as.numeric(fitted(fit))[d$site == park]))
    }
  }
  fits[[paste(response, 'Holocene')]] = fit

  a = anthropocene_rows(response); da = a$data
# report-snippet: anthropocene-explanatory-model
  # Anthropocene plot pairs only: the same responses against site and burned
  # (whether the plot burned between the two surveys). Plots are independent,
  # each park keeps its own spread.
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
  # Fitted means for Figure 7B: MORA unburned, NOCA unburned, NOCA burned.
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
