# Independent GLS algebra for the lake-period models (PLAN.md Steps 5 and 5a):
# rebuild each residual covariance from the fitted parameters (AR(1) on the
# unit order within series, park or period-type variances, endpoint weights)
# and check the coefficients and their covariance against generalized least
# squares computed by hand. Also checks the paired AR(1) correlation matrix.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(nlme)})
source(here('R/helpers/reconstruction_models.R'), local = TRUE)
close = function(x, y, tol = 1e-6) stopifnot(length(x) == length(y),
  all(abs(as.numeric(x) - as.numeric(y)) <= tol * pmax(1, abs(as.numeric(y)))))
both = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE)

check_gls = function(fit, d, group, series, pair = NULL) {
  X = model.matrix(formula(fit), d)[, names(coef(fit)), drop = FALSE]
  ident = fit$modelStruct$varStruct[[1]]
  ratios = coef(ident, unconstrained = FALSE, allCoef = TRUE)
  sd = fit$sigma * unname(ratios[as.character(d[[group]])]) * sqrt(d$endpoint_var)
  pars = coef(fit$modelStruct$corStruct, unconstrained = FALSE)
  V = matrix(0, nrow(d), nrow(d))
  for (i in split(seq_len(nrow(d)), d[[series]])) {
    R = pars[1]^abs(outer(d$unit_index[i], d$unit_index[i], '-'))
    if (!is.null(pair)) R = R * ifelse(outer(d$correction[i], d$correction[i], '=='), 1, pars[[pair[i[1]]]])
    V[i, i] = R * outer(sd[i], sd[i])
  }
  ViX = solve(V, X); covariance = solve(crossprod(X, ViX))
  close(coef(fit), covariance %*% crossprod(X, solve(V, d$estimate)))
  close(vcov(fit), covariance)
}

# Step 5: Holocene explanatory models.
fits = readRDS(out('community_predictor_models/primary_fits.rds'))
for (response in c('lag_rate', 'pace_effect', 'direction_effect')) {
  d = both |> filter(period_type != 'Anthropocene', is.finite(.data[[response]])) |>
    mutate(estimate = .data[[response]], site = factor(site, levels = c('MORA', 'NOCA')))
  fit = fits[[paste(response, 'Holocene')]]
  stopifnot(identical(all.vars(formula(fit))[-1], c('site', 'climate_rate', 'fire_activity')),
    # nlme stores an AR(1) with gaps in the unit order as the equivalent ARMA(1, 0).
    inherits(fit$modelStruct$corStruct, c('corAR1', 'corARMA')),
    length(coef(fit$modelStruct$corStruct)) == 1L, fit$dims$N == nrow(d))
  check_gls(fit, d, 'site', 'lake')
}

# Step 5a: era models, all six period type x park groups.
fits = readRDS(out('era_comparison/primary_fits.rds'))
for (response in names(ERA_RESPONSES)) {
  d = both |> filter(is.finite(.data[[response]])) |>
    mutate(estimate = .data[[response]], period_type = factor(period_type, levels = ERA_PERIOD_TYPES),
      site = factor(site, levels = c('MORA', 'NOCA')),
      period_type_site = interaction(period_type, site, drop = TRUE, sep = ' '))
  fit = fits[[response]]
  stopifnot(fit$dims$N == nrow(d), nlevels(d$period_type_site) == 6L)
  check_gls(fit, d, 'period_type_site', 'series')
}

# Joint pace and direction model: paired AR(1).
fit = readRDS(out('era_comparison/joint_correction_effects/primary_fit.rds'))
d = tracking_joint_correction_input(both)
stopifnot(fit$dims$N == nrow(d), all(table(d$series, d$unit_index)[table(d$series, d$unit_index) > 0] == 2L))
check_gls(fit, d, 'period_type_site_correction', 'series',
  pair = paste(ifelse(d$period_type == 'Anthropocene', 'Anthropocene', 'Holocene'), d$site))

# The paired AR(1) correlation of a toy series, by hand.
toy = tibble(series = 'A', unit_index = c(1, 1, 3, 3), correction = factor(c('Pace', 'Direction', 'Pace', 'Direction'),
  levels = c('Pace', 'Direction')), period_type = 'Holocene-C', site = 'MORA')
R = nlme::corMatrix(nlme::Initialize(corPairedAR1(c('Holocene MORA', 'Anthropocene MORA'), c(.5, .3, .1)), toy))[[1]]
close(R, matrix(c(1, .3, .25, .075, .3, 1, .075, .25, .25, .075, 1, .3, .075, .25, .3, 1), 4), 1e-12)
cat('Lake-period GLS algebra (Step 5, Step 5a, joint pace and direction) and the paired AR(1) checks passed.\n')
