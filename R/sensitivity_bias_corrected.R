# Bias-corrected sensitivity run (Bills, 10 Nov 2026).
#
#   Rscript R/sensitivity_bias_corrected.R
#
# The primary run uses the raw CHELSA-TraCE21k paleoclimate. Its modern slice
# differs from the CHELSA V2.1 climate the CCA is calibrated on, by a fixed
# offset per lake and month for temperature and a fixed ratio for precipitation
# (output/07_paleo_climate/chelsa_paleo_bias_correction.csv). This run sets
# PALEO_USE_BIAS_CORRECTED = TRUE, which removes that offset, and reruns
# stages 07 to 15 into output_bias_corrected/. The primary output/ and report/
# are never written: steps 01 to 06 and the caches the run reads are copied
# in first, no figure is drawn, and every file under output/, report/figures/
# and report/tables/ is checked byte for byte at the end.
#
# The climate periods stay those of the primary run, because stage 11 defines
# them on the raw series whatever the switch says, so every lake-period exists
# in both runs. The script ends with one table of the lag, pace effect and
# direction effect of every lake-period from both runs side by side, and the
# number that keep their sign.
suppressPackageStartupMessages({library(here); library(tidyverse)})
primary = here('output')
root = here('output_bias_corrected')

# Regenerate the run's own folder from scratch. It holds only this run's outputs and copies.
stopifnot(normalizePath(root, mustWork = FALSE) != normalizePath(primary))
unlink(root, recursive = TRUE)
dir.create(file.path(root, 'cache'), recursive = TRUE, showWarnings = FALSE)
# Inputs from the primary run: the results of steps 01 to 06, the paleo climate
# chunks and Bacon age draws, and the CCA permutation cache (keyed on the fit,
# which the paleoclimate does not enter, so it is reused only if the fit matches).
for (step in list.files(primary, pattern = '^0[1-6]_')) file.copy(file.path(primary, step), root, recursive = TRUE)
file.copy(file.path(primary, 'cache', c('chelsa_paleo', 'age_draws.rds')), file.path(root, 'cache'), recursive = TRUE)
dir.create(file.path(root, '10_cca'), showWarnings = FALSE)
file.copy(file.path(primary, '10_cca', 'cca_anova_cache.rds'), file.path(root, '10_cca'))

fingerprint = function() {
  files = c(list.files(primary, recursive = TRUE, full.names = TRUE),
    list.files(here('report', c('figures', 'tables')), recursive = TRUE, full.names = TRUE))
  tools::md5sum(files)
}
before = fingerprint()

options(paleoaces.offline = TRUE, paleoaces.run_age_models = FALSE, paleoaces.presentation = FALSE,
  paleoaces.render_figures = FALSE, paleoaces.bias_corrected = TRUE, paleoaces.output_root = root,
  device = function(...) grDevices::pdf(file = tempfile(fileext = '.pdf'), ...))
for (stage in list.files(here('R/pipeline'), pattern = '^(0[7-9]|1[0-5])_.*[.]R$')) {
  cat('\n', strrep('=', 78), '\n', stage, ' (bias-corrected)\n', strrep('=', 78), '\n', sep = '')
  sys.source(here('R/pipeline', stage), envir = new.env(parent = globalenv()))
}
options(paleoaces.bias_corrected = NULL, paleoaces.output_root = NULL)

# Rule: the sensitivity run leaves the primary outputs, figures and report tables untouched.
after = fingerprint()
stopifnot(identical(names(before), names(after)), identical(unname(before), unname(after)))
# The correction must have reached the climate the samples are projected with.
raw_env = read_csv(file.path(primary, '07_paleo_climate', 'paleo_env.csv'), show_col_types = FALSE)
corrected_env = read_csv(file.path(root, '07_paleo_climate', 'paleo_env.csv'), show_col_types = FALSE)
stopifnot(identical(raw_env$plot_id, corrected_env$plot_id), !isTRUE(all.equal(raw_env$MSpT, corrected_env$MSpT)))

# Lake-periods of both runs side by side.
responses = c('lag', 'pace_effect', 'direction_effect')
lake_periods = function(path, run) read_csv(file.path(path, '12_tracking', 'cca_tracking_both_eras.csv'),
  show_col_types = FALSE) |> filter(period_type != 'Anthropocene') |>
  select(site, lake, period, period_type, age_start, age_end, duration_yr, all_of(responses)) |>
  rename_with(~ paste0(.x, '_', run), all_of(responses))
raw = lake_periods(primary, 'raw')
corrected = lake_periods(root, 'corrected')
# Rule: the same lake-periods in both runs (the periods are defined on the raw climate).
stopifnot(nrow(raw) == nrow(corrected), !anyDuplicated(raw[c('site', 'lake', 'period')]))
side_by_side = raw |> inner_join(corrected, by = c('site', 'lake', 'period', 'period_type', 'age_start', 'age_end',
  'duration_yr'), relationship = 'one-to-one')
stopifnot(nrow(side_by_side) == nrow(raw))
for (r in responses) side_by_side[[paste0(r, '_same_sign')]] =
  sign(side_by_side[[paste0(r, '_raw')]]) == sign(side_by_side[[paste0(r, '_corrected')]])
side_by_side = side_by_side |>
  select(site, lake, period, period_type, age_start, age_end, duration_yr,
    unlist(map(responses, ~ paste0(.x, c('_raw', '_corrected', '_same_sign'))))) |>
  arrange(site, lake, desc(age_start))
# A pace or direction effect is undefined where a position did not move (PLAN.md
# 4.7); such a lake-period is counted as undefined, not as keeping its sign.
sign_counts = map_dfr(responses, function(r) side_by_side |>
  transmute(site, raw = .data[[paste0(r, '_raw')]], corrected = .data[[paste0(r, '_corrected')]],
    same = .data[[paste0(r, '_same_sign')]]) |>
  group_by(site) |> group_modify(\(x, key) tibble(lake_periods = nrow(x),
    defined_in_both = sum(!is.na(x$same)), keep_sign = sum(x$same, na.rm = TRUE),
    change_sign = sum(!x$same, na.rm = TRUE))) |> ungroup() |>
  bind_rows(tibble(site = 'both parks', lake_periods = nrow(side_by_side),
    defined_in_both = sum(!is.na(side_by_side[[paste0(r, '_same_sign')]])),
    keep_sign = sum(side_by_side[[paste0(r, '_same_sign')]], na.rm = TRUE),
    change_sign = sum(!side_by_side[[paste0(r, '_same_sign')]], na.rm = TRUE))) |>
  mutate(response = r, .before = 1))
dir.create(file.path(root, 'comparison'), showWarnings = FALSE)
write_csv(side_by_side, file.path(root, 'comparison', 'lake_periods_raw_vs_corrected.csv'))
write_csv(sign_counts, file.path(root, 'comparison', 'sign_counts.csv'))
print(as.data.frame(sign_counts))
cat('\nBias-corrected sensitivity run done: output_bias_corrected/; primary output/ and report/ unchanged.\n')
