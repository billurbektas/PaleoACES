# Build the report from the finished outputs: the repository README.md (the appendix,
# from report/README.Rmd),
# report/details/*.md, the PNG previews in report/figures/png/ and the tables in
# report/tables/. Run after R/run_all.R:
#   Rscript R/build_report.R
suppressPackageStartupMessages(library(here))
if (!nzchar(Sys.which('pdftoppm'))) stop('pdftoppm (poppler) is required to preview figures.')
unlink(here('report/tables'), recursive = TRUE)
render = function(rmd, toc = TRUE, output_dir = dirname(rmd)) {
  cat('Rendering', sub(paste0(here(), '/'), '', rmd), '\n')
  options(paleoaces.report_output_dir = output_dir)
  on.exit(options(paleoaces.report_output_dir = NULL), add = TRUE)
  rmarkdown::render(rmd, output_format = rmarkdown::github_document(html_preview = FALSE,
      toc = toc, toc_depth = 2), output_dir = output_dir, quiet = TRUE,
    knit_root_dir = here(), envir = new.env(parent = globalenv()))
}
for (rmd in sort(list.files(here('report/details'), pattern = '[.]Rmd$', full.names = TRUE))) render(rmd)
# The appendix source lives in report/; its output is the repository README.md.
render(here('report/README.Rmd'), toc = FALSE, output_dir = here())  # GitHub shows its own outline
# A self-contained HTML copy of the appendix for sharing outside GitHub.
options(paleoaces.report_output_dir = here('report'))
rmarkdown::render(here('report/README.Rmd'), output_format = rmarkdown::html_document(toc = TRUE,
    toc_float = TRUE, self_contained = TRUE, theme = 'flatly'), output_file = 'PaleoACES_report.html',
  output_dir = here('report'), quiet = TRUE, knit_root_dir = here(), envir = new.env(parent = globalenv()))
# Previews of figures no longer shown anywhere are stale.
used = unlist(lapply(c(here('README.md'), list.files(here('report'), pattern = '[.]md$', recursive = TRUE, full.names = TRUE)),
  function(f) regmatches(readLines(f, warn = FALSE), gregexpr('figures/png/[^)"]+[.]png', readLines(f, warn = FALSE)))))
stale = setdiff(list.files(here('report/figures/png'), full.names = TRUE), here('report', unique(sub('^((\\.\\./)+|report/)', '', used))))
unlink(stale)
cat('Report written to README.md (', length(stale), ' stale previews removed)\n', sep = '')
