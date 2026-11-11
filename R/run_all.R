# PaleoACES: run the whole analysis, in order.
#
#   Rscript R/run_all.R                 full rebuild (downloads only missing climate chunks)
#   Rscript R/run_all.R --offline       rebuild from the cached climate in output/cache/
#   Rscript R/run_all.R --age-models    also refit the four Bacon chronologies (slow)
#   Rscript R/run_all.R --presentation  also draw the presentation figures
#   Optional: --skip-figures, --skip-tests
#
# 1. R/pipeline/01-16   data preparation and analysis; writes output/<step>/ only
# 2. R/figures/         main and supplementary figures, from output/ only
# 3. R/worked_examples.R  step-by-step method illustrations
# 4. R/tests/           scientific regression checks
# 5. report/            the report is built separately: Rscript R/build_report.R
#
# Every output path is declared in R/helpers/paths.R.

suppressPackageStartupMessages(library(here))

args = commandArgs(trailingOnly = TRUE)
known = c("--offline", "--age-models", "--presentation", "--skip-figures", "--skip-tests")
if (length(setdiff(args, known))) stop("Unknown option(s): ", paste(setdiff(args, known), collapse = ", "))
flag = function(x) x %in% args

options(paleoaces.offline = flag("--offline"),
        paleoaces.run_age_models = flag("--age-models"),
        paleoaces.presentation = flag("--presentation"),
        paleoaces.render_figures = !flag("--skip-figures"),
        device = function(...) grDevices::pdf(file = tempfile(fileext = ".pdf"), ...))

run = function(path) {
  cat("\n", strrep("=", 78), "\n", path, "\n", strrep("=", 78), "\n", sep = "")
  sys.source(here(path), envir = new.env(parent = globalenv()))
}

# 1. Pipeline -------------------------------------------------------------------
for (step in sort(list.files(here("R/pipeline"), pattern = "^[0-9]{2}_.*[.]R$"))) run(file.path("R/pipeline", step))

# 2. Figures --------------------------------------------------------------------
if (!flag("--skip-figures")) {
  for (f in sort(list.files(here("R/figures"), pattern = "^supp_.*[.]R$"))) run(file.path("R/figures", f))
  for (f in sort(list.files(here("R/figures"), pattern = "^main_fig[0-9]_.*[.]R$"))) run(file.path("R/figures", f))
  # 3. Worked examples ------------------------------------------------------------
  run("R/worked_examples.R")
}

# 4. Tests ----------------------------------------------------------------------
if (!flag("--skip-tests"))
  for (t in sort(list.files(here("R/tests"), pattern = "^test_.*[.]R$"))) run(file.path("R/tests", t))

cat("\nPaleoACES run completed.\n")
