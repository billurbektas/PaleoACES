# Sensitivity runs on the paleoclimate correction (Appendix S4; Bills, 11 Nov 2026).
#
#   Rscript R/sensitivity_paleoclimate.R
#
# The main run uses the CHELSA-TraCE21k paleoclimate corrected onto CHELSA V2.1
# in two steps, TraCE21k to CHELSAcruts and CHELSAcruts to V2.1
# (R/pipeline/07_climate_products.R, Appendix S2). This script reruns stages 08
# to 16 twice into output_paleoclimate_sensitivity/: with the one-step
# correction (CHELSAcruts to V2.1 only) and on the raw TraCE21k. The raw run must
# reproduce the main run of the analysis until 11 Nov 2026, the one-step run the
# main run of the branch's first commit. The main output/ and report/ are never
# written: steps 01 to 07 and the caches the runs read are copied in first, no
# figure is drawn, and every file under output/, report/figures/ and
# report/tables/ is checked byte for byte at the end.
#
# Each run draws its climate periods from its own series, so the lake-periods
# can differ. They are compared where all three runs have the same lake, period
# type and ends; the rest are counted. The script writes, to
# output_paleoclimate_sensitivity/comparison/, the climate periods of the three
# runs, every era response of the shared lake-periods with the correlation of
# each corrected run with the raw one in each park (Fig. S16), the shared
# lake-periods whose lag, pace and direction effect keep their sign, the era
# contrasts of all responses and the Holocene explanatory-model slopes (Fig. S17)
# of the three runs side by side. Appendix S4 shows the two figures and quotes
# the counts from these tables (Bills, 11 Nov 2026: no comparison tables).
suppressPackageStartupMessages({library(here); library(tidyverse)})
main = here('output')
base = here('output_paleoclimate_sensitivity')
runs = c(one_step = 'one_step', raw = 'none')

# Regenerate the folder from scratch. It holds only these runs' outputs and copies.
stopifnot(normalizePath(base, mustWork = FALSE) != normalizePath(main))
unlink(base, recursive = TRUE)
fingerprint = function() {
  files = c(list.files(main, recursive = TRUE, full.names = TRUE),
    list.files(here('report', c('figures', 'tables')), recursive = TRUE, full.names = TRUE))
  tools::md5sum(files)
}
before = fingerprint()
for (run in names(runs)) {
  root = file.path(base, run)
  dir.create(file.path(root, 'cache'), recursive = TRUE, showWarnings = FALSE)
  # Inputs from the main run: the results of steps 01 to 07, the paleo climate
  # chunks and Bacon age draws, and the CCA permutation cache (keyed on the fit,
  # which the paleoclimate does not enter, so it is reused only if the fit matches).
  for (step in list.files(main, pattern = '^0[1-7]_')) file.copy(file.path(main, step), root, recursive = TRUE)
  file.copy(file.path(main, 'cache', c('chelsa_paleo', 'age_draws.rds')), file.path(root, 'cache'), recursive = TRUE)
  dir.create(file.path(root, '11_cca'), showWarnings = FALSE)
  file.copy(file.path(main, '11_cca', 'cca_anova_cache.rds'), file.path(root, '11_cca'))
  options(paleoaces.offline = TRUE, paleoaces.run_age_models = FALSE, paleoaces.presentation = FALSE,
    paleoaces.render_figures = FALSE, paleoaces.paleo_correction = runs[[run]], paleoaces.output_root = root,
    device = function(...) grDevices::pdf(file = tempfile(fileext = '.pdf'), ...))
  for (stage in list.files(here('R/pipeline'), pattern = '^(0[8-9]|1[0-6])_.*[.]R$')) {
    cat('\n', strrep('=', 78), '\n', stage, ' (', run, ' paleoclimate)\n', strrep('=', 78), '\n', sep = '')
    sys.source(here('R/pipeline', stage), envir = new.env(parent = globalenv()))
  }
  options(paleoaces.paleo_correction = NULL, paleoaces.output_root = NULL)
}
# Rule: the sensitivity runs leave the main outputs, figures and report tables untouched.
after = fingerprint()
stopifnot(identical(names(before), names(after)), identical(unname(before), unname(after)))
paths = c(two_step = main, one_step = file.path(base, 'one_step'), raw = file.path(base, 'raw'))
# Each run's own series must have reached the climate the samples are projected with.
env = lapply(paths, function(p) read_csv(file.path(p, '08_paleo_climate', 'paleo_env.csv'), show_col_types = FALSE))
stopifnot(identical(env$two_step$plot_id, env$raw$plot_id), identical(env$one_step$plot_id, env$raw$plot_id),
  !isTRUE(all.equal(env$two_step$MSpT, env$raw$MSpT)), !isTRUE(all.equal(env$one_step$MSpT, env$raw$MSpT)),
  !isTRUE(all.equal(env$two_step$MSpT, env$one_step$MSpT)))
comparison = file.path(base, 'comparison')
dir.create(comparison, showWarnings = FALSE)

# Climate periods of the three runs.
periods = imap_dfr(paths, \(p, run) read_csv(file.path(p, '12_climate_eras', 'holocene_periods.csv'),
  show_col_types = FALSE) |> mutate(run = run, .before = 1))
write_csv(periods, file.path(comparison, 'climate_periods.csv'))

# Lake-periods shared by all three runs: same lake, period type and ends.
keys = c('site', 'lake', 'period_type', 'age_start', 'age_end', 'duration_yr')
lake_periods = lapply(paths, function(p) read_csv(file.path(p, '13_tracking', 'cca_tracking_both_eras.csv'),
  show_col_types = FALSE) |> filter(period_type != 'Anthropocene'))
shared = reduce(lapply(lake_periods, \(x) select(x, all_of(keys))), inner_join, by = keys)
write_csv(tibble(run = names(paths), lake_periods = map_int(lake_periods, nrow), shared_by_all = nrow(shared)),
  file.path(comparison, 'lake_period_matching.csv'))

# Every era response of the shared lake-periods in the three runs (Fig. S16).
source(here('R/helpers/tracking_model_reporting.R'), local = TRUE)
responses = imap(lake_periods, \(x, run) x |> semi_join(shared, by = keys) |>
  select(all_of(keys), period, all_of(names(ERA_RESPONSES))) |>
  pivot_longer(all_of(names(ERA_RESPONSES)), names_to = 'response', values_to = run))
responses = reduce(map(responses, \(x) select(x, -period)), inner_join, by = c(keys, 'response'))
# Rule: every response of every shared lake-period in all three runs.
stopifnot(nrow(responses) == nrow(shared) * length(ERA_RESPONSES))
write_csv(responses, file.path(comparison, 'lake_period_responses.csv'))
# How closely each corrected run follows the raw one across the shared lake-periods
# of a park (Pearson r, printed in Fig. S16). Lake-periods without a pace or
# direction effect (a position that did not move) are left out.
correlations = responses |> pivot_longer(c(two_step, one_step), names_to = 'run', values_to = 'corrected') |>
  filter(is.finite(raw), is.finite(corrected)) |>
  group_by(response, site, run) |> summarise(lake_periods = n(), r = cor(raw, corrected), .groups = 'drop')
write_csv(correlations, file.path(comparison, 'lake_period_correlations.csv'))
# Shared lake-periods whose lag, pace and direction effect keep the sign of the
# main run in each sensitivity run. Undefined effects are counted as undefined.
sign_counts = map_dfr(c('one_step', 'raw'), function(other) map_dfr(c('lag', 'pace_effect_total', 'direction_effect_total'),
  function(r) responses |> filter(response == r) |> mutate(same = sign(two_step) == sign(.data[[other]])) |>
    group_by(site) |> summarise(lake_periods = n(), defined_in_both = sum(!is.na(same)),
      keep_sign = sum(same, na.rm = TRUE), change_sign = sum(!same, na.rm = TRUE), .groups = 'drop') |>
    mutate(against = other, response = r, .before = 1)))
write_csv(sign_counts, file.path(comparison, 'sign_counts.csv'))

# The era contrasts and the Holocene explanatory-model slopes (Fig. S17) of
# the three runs. The Anthropocene models hold no
# paleoclimate and are the same in all runs.
wide = function(read, by) reduce(imap(paths, \(p, run) read(p) |> rename_with(~ paste0(.x, '_', run), -all_of(by))),
  inner_join, by = by)
contrasts = wide(\(p) read_csv(file.path(p, '14_era_models', 'era_comparison', 'era_contrasts.csv'), show_col_types = FALSE) |>
  select(response, site, contrast, estimate, conf_low, conf_high, p_adjusted), c('response', 'site', 'contrast'))
slopes = wide(\(p) read_csv(file.path(p, '15_predictor_models', 'community_predictor_models', 'model_coefficients.csv'),
  show_col_types = FALSE) |> filter(era == 'Holocene', term != '(Intercept)') |>
  select(response = metric, term, estimate, conf_low, conf_high, p_value), c('response', 'term'))
stopifnot(nrow(contrasts) == 60, nrow(slopes) == 18)
write_csv(contrasts, file.path(comparison, 'era_contrasts.csv'))
write_csv(slopes, file.path(comparison, 'explanatory_slopes.csv'))
print(read_csv(file.path(comparison, 'lake_period_matching.csv'), show_col_types = FALSE))
print(as.data.frame(sign_counts))
cat('\nPaleoclimate sensitivity runs done: output_paleoclimate_sensitivity/; main output/ and report/ unchanged.\n')
