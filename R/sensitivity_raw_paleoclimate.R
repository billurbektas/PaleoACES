# Sensitivity run on the raw paleoclimate (Appendix S4; Bills, 11 Nov 2026).
#
#   Rscript R/sensitivity_raw_paleoclimate.R
#
# The main run uses the CHELSA-TraCE21k paleoclimate bias-corrected onto CHELSA
# V2.1 (R/pipeline/07_climate_products.R, Appendix S2). This run sets
# PALEO_USE_BIAS_CORRECTED = FALSE and reruns stages 08 to 16 on the raw
# TraCE21k into output_raw_paleoclimate/. Until 11 Nov 2026 the raw run was the
# main analysis, so this run must reproduce it. The main output/ and report/ are
# never written: steps 01 to 07 and the caches the run reads are copied in first,
# no figure is drawn, and every file under output/, report/figures/ and
# report/tables/ is checked byte for byte at the end.
#
# Each run draws its climate periods from its own series, so the periods, and
# with them the lake-periods, can differ. Lake-periods are compared where both
# runs have the same lake, period type and ends; the rest are counted. The
# script writes, to output_raw_paleoclimate/comparison/, the climate periods of
# both runs, the lag, pace and direction effect of the shared lake-periods with
# the number that keep their sign, every era response of the shared
# lake-periods with the correlation between the runs in each park (Fig. S19),
# the era contrasts of all responses (Table S4.1) and the Holocene
# explanatory-model slopes (Table S4.2, Fig. S20) of both runs side by side.
suppressPackageStartupMessages({library(here); library(tidyverse)})
main = here('output')
root = here('output_raw_paleoclimate')

# Regenerate the run's own folder from scratch. It holds only this run's outputs and copies.
stopifnot(normalizePath(root, mustWork = FALSE) != normalizePath(main))
unlink(root, recursive = TRUE)
dir.create(file.path(root, 'cache'), recursive = TRUE, showWarnings = FALSE)
# Inputs from the main run: the results of steps 01 to 07, the paleo climate
# chunks and Bacon age draws, and the CCA permutation cache (keyed on the fit,
# which the paleoclimate does not enter, so it is reused only if the fit matches).
for (step in list.files(main, pattern = '^0[1-7]_')) file.copy(file.path(main, step), root, recursive = TRUE)
file.copy(file.path(main, 'cache', c('chelsa_paleo', 'age_draws.rds')), file.path(root, 'cache'), recursive = TRUE)
dir.create(file.path(root, '11_cca'), showWarnings = FALSE)
file.copy(file.path(main, '11_cca', 'cca_anova_cache.rds'), file.path(root, '11_cca'))

fingerprint = function() {
  files = c(list.files(main, recursive = TRUE, full.names = TRUE),
    list.files(here('report', c('figures', 'tables')), recursive = TRUE, full.names = TRUE))
  tools::md5sum(files)
}
before = fingerprint()

options(paleoaces.offline = TRUE, paleoaces.run_age_models = FALSE, paleoaces.presentation = FALSE,
  paleoaces.render_figures = FALSE, paleoaces.bias_corrected = FALSE, paleoaces.output_root = root,
  device = function(...) grDevices::pdf(file = tempfile(fileext = '.pdf'), ...))
for (stage in list.files(here('R/pipeline'), pattern = '^(0[8-9]|1[0-6])_.*[.]R$')) {
  cat('\n', strrep('=', 78), '\n', stage, ' (raw paleoclimate)\n', strrep('=', 78), '\n', sep = '')
  sys.source(here('R/pipeline', stage), envir = new.env(parent = globalenv()))
}
options(paleoaces.bias_corrected = NULL, paleoaces.output_root = NULL)

# Rule: the sensitivity run leaves the main outputs, figures and report tables untouched.
after = fingerprint()
stopifnot(identical(names(before), names(after)), identical(unname(before), unname(after)))
# The raw series must have reached the climate the samples are projected with.
corrected_env = read_csv(file.path(main, '08_paleo_climate', 'paleo_env.csv'), show_col_types = FALSE)
raw_env = read_csv(file.path(root, '08_paleo_climate', 'paleo_env.csv'), show_col_types = FALSE)
stopifnot(identical(raw_env$plot_id, corrected_env$plot_id), !isTRUE(all.equal(raw_env$MSpT, corrected_env$MSpT)))
dir.create(file.path(root, 'comparison'), showWarnings = FALSE)

# Climate periods of both runs.
periods = function(path, run) read_csv(file.path(path, '12_climate_eras', 'holocene_periods.csv'),
  show_col_types = FALSE) |> mutate(run = run, .before = 1)
periods_both = bind_rows(periods(main, 'corrected'), periods(root, 'raw'))
write_csv(periods_both, file.path(root, 'comparison', 'climate_periods_corrected_vs_raw.csv'))

# Lake-periods shared by both runs: same lake, period type and ends.
keys = c('site', 'lake', 'period_type', 'age_start', 'age_end', 'duration_yr')
lake_period_rows = function(path) read_csv(file.path(path, '13_tracking', 'cca_tracking_both_eras.csv'),
  show_col_types = FALSE) |> filter(period_type != 'Anthropocene')
corrected_lp = lake_period_rows(main); raw_lp = lake_period_rows(root)
shared = inner_join(corrected_lp |> select(all_of(keys), period_corrected = period),
  raw_lp |> select(all_of(keys), period_raw = period), by = keys, relationship = 'one-to-one')
matching = tibble(run = c('corrected', 'raw'), lake_periods = c(nrow(corrected_lp), nrow(raw_lp)),
  shared = nrow(shared), only_this_run = lake_periods - shared)
write_csv(matching, file.path(root, 'comparison', 'lake_period_matching.csv'))

responses = c('lag', 'pace_effect', 'direction_effect')
side_by_side = shared |>
  left_join(corrected_lp |> select(all_of(keys), all_of(responses)) |> rename_with(~ paste0(.x, '_corrected'), all_of(responses)),
    by = keys, relationship = 'one-to-one') |>
  left_join(raw_lp |> select(all_of(keys), all_of(responses)) |> rename_with(~ paste0(.x, '_raw'), all_of(responses)),
    by = keys, relationship = 'one-to-one')
for (r in responses) side_by_side[[paste0(r, '_same_sign')]] =
  sign(side_by_side[[paste0(r, '_corrected')]]) == sign(side_by_side[[paste0(r, '_raw')]])
side_by_side = side_by_side |>
  select(site, lake, period_corrected, period_raw, period_type, age_start, age_end, duration_yr,
    unlist(map(responses, ~ paste0(.x, c('_corrected', '_raw', '_same_sign'))))) |>
  arrange(site, lake, desc(age_start))
# A pace or direction effect is undefined where a position did not move (PLAN.md
# 4.7); such a lake-period is counted as undefined, not as keeping its sign.
sign_counts = map_dfr(responses, function(r) side_by_side |>
  transmute(site, same = .data[[paste0(r, '_same_sign')]]) |>
  group_by(site) |> group_modify(\(x, key) tibble(lake_periods = nrow(x),
    defined_in_both = sum(!is.na(x$same)), keep_sign = sum(x$same, na.rm = TRUE),
    change_sign = sum(!x$same, na.rm = TRUE))) |> ungroup() |>
  bind_rows(tibble(site = 'both parks', lake_periods = nrow(side_by_side),
    defined_in_both = sum(!is.na(side_by_side[[paste0(r, '_same_sign')]])),
    keep_sign = sum(side_by_side[[paste0(r, '_same_sign')]], na.rm = TRUE),
    change_sign = sum(!side_by_side[[paste0(r, '_same_sign')]], na.rm = TRUE))) |>
  mutate(response = r, .before = 1))
write_csv(side_by_side, file.path(root, 'comparison', 'lake_periods_corrected_vs_raw.csv'))
write_csv(sign_counts, file.path(root, 'comparison', 'sign_counts.csv'))

# Every era response of the shared lake-periods in both runs (Fig. S19).
source(here('R/helpers/tracking_model_reporting.R'), local = TRUE)
long = function(x, run) x |> select(all_of(keys), all_of(names(ERA_RESPONSES))) |>
  pivot_longer(all_of(names(ERA_RESPONSES)), names_to = 'response', values_to = run)
responses_both = inner_join(long(corrected_lp, 'corrected'), long(raw_lp, 'raw'), by = c(keys, 'response'),
  relationship = 'one-to-one')
# Rule: every response of every shared lake-period in both runs.
stopifnot(nrow(responses_both) == nrow(shared) * length(ERA_RESPONSES))
write_csv(responses_both, file.path(root, 'comparison', 'lake_period_responses_corrected_vs_raw.csv'))
# How closely the raw values follow the corrected ones across the shared
# lake-periods of a park (Pearson r, printed in Fig. S19). Lake-periods without
# a pace or direction effect (a position that did not move) are left out.
correlations = responses_both |> filter(is.finite(raw), is.finite(corrected)) |>
  group_by(response, site) |> summarise(lake_periods = n(), r = cor(corrected, raw), .groups = 'drop')
write_csv(correlations, file.path(root, 'comparison', 'lake_period_correlations_corrected_vs_raw.csv'))
# The era contrasts of all responses in both runs (Table S4.1).
era_contrasts = function(path) read_csv(file.path(path, '14_era_models', 'era_comparison', 'era_contrasts.csv'),
  show_col_types = FALSE) |> select(response, site, contrast, estimate, conf_low, conf_high, p_adjusted)
contrasts_both = inner_join(era_contrasts(main), era_contrasts(root), by = c('response', 'site', 'contrast'),
  suffix = c('_corrected', '_raw'), relationship = 'one-to-one')
stopifnot(nrow(contrasts_both) == nrow(era_contrasts(main)))
write_csv(contrasts_both, file.path(root, 'comparison', 'era_contrasts_corrected_vs_raw.csv'))
# The Holocene explanatory-model slopes in both runs (Table S4.2, Fig. S20). The
# Anthropocene models hold no paleoclimate and are the same in both runs.
slopes = function(path) read_csv(file.path(path, '15_predictor_models', 'community_predictor_models',
  'model_coefficients.csv'), show_col_types = FALSE) |> filter(era == 'Holocene', term != '(Intercept)') |>
  select(response = metric, term, estimate, conf_low, conf_high, p_value)
slopes_both = inner_join(slopes(main), slopes(root), by = c('response', 'term'), suffix = c('_corrected', '_raw'),
  relationship = 'one-to-one')
stopifnot(nrow(slopes_both) == nrow(slopes(main)))
write_csv(slopes_both, file.path(root, 'comparison', 'explanatory_slopes_corrected_vs_raw.csv'))
print(as.data.frame(matching))
print(as.data.frame(sign_counts))
cat('\nRaw-paleoclimate sensitivity run done: output_raw_paleoclimate/; main output/ and report/ unchanged.\n')
