# Figs. S20 and S21 (Appendix S4; Bills, 25 Nov 2026): the analysis with the
# Holocene climate corrected in two steps (the main analysis, TraCE21k to
# CHELSAcruts to V2.1) and without correction (raw TraCE21k), in the same panels
# as Figs. S25 and S26 of Appendix S5 (R/helpers/sensitivity_figures.R). Both read
# the comparison written by R/sensitivity_paleoclimate.R. Its one-step run (step 2
# alone) stays in the comparison tables but is not drawn (Bills, 25 Nov 2026).
#   S20  rates, lag and contributions by period type (Figure 5)
#   S21  associations with climate and fire: model slopes (Figure 6)
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/sensitivity_figures.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

comparison_dir = here('output_paleoclimate_sensitivity', 'comparison')
if (!file.exists(file.path(comparison_dir, 'model_coefficients.csv'))) {
  cat('Figs. S20 and S21 skipped: run Rscript R/sensitivity_paleoclimate.R first.\n')
} else {
  read = function(f) read_csv(file.path(comparison_dir, f), show_col_types = FALSE)
  # The main analysis keeps the purple of Appendix S5, where it is the same run.
  # Colours checked for colour-blind separation and contrast (dataviz validator,
  # 25 Nov 2026), away from the park blue and red; a symbol per version as a second cue.
  RUN_LABELS = c(two_step = 'Two-step correction (main analysis)', raw = 'No correction')
  RUN_COLORS = c(two_step = '#7B3FA0', raw = '#8A7A00')
  RUN_SHAPES = c(two_step = 21, raw = 22)
  as_run = function(d) d |> filter(run %in% names(RUN_LABELS)) |> mutate(version = factor(run, names(RUN_LABELS)))
  save_figure = function(plot, name, width, height) if (render_figures)
    ggsave(fig('supplementary', name), plot, width = width, height = height, device = cairo_pdf)

  save_figure(sensitivity_era_means_figure(as_run(read('era_means.csv')), RUN_LABELS, RUN_COLORS, RUN_SHAPES),
    'figS20_paleoclimate_era_means.pdf', 14, 24)
  save_figure(sensitivity_slopes_figure(as_run(read('model_coefficients.csv')), RUN_LABELS, RUN_COLORS, RUN_SHAPES),
    'figS21_paleoclimate_slopes.pdf', 16, 13)
  cat('Figs. S20 and S21: the analysis with and without correction of the Holocene climate drawn.\n')
}
