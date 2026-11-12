# Build the report from the finished outputs. report/README.Rmd is knitted once and
# split into two documents with the same figures, tables and numbers:
#   README.md                      the repository page, with the code, the links to the
#                                  scripts and detail pages, and the main-text figures
#   report/appendix.md and         the supplementary appendix of the manuscript, without
#   report/PaleoACES_appendix.docx them (markers in the .Rmd say which text goes where)
# Also written: report/details/*.md, the PNG previews in report/figures/png/ and the
# tables in report/tables/. Run after R/run_all.R:
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
# One knitted document, two variants. `keep` is the variant to write: text marked for the
# other variant is removed, and the markers themselves are removed from what stays.
# In the appendix the links written by the helpers (<!-- link-only -->) go too.
report_variant = function(text, keep = c('readme', 'appendix')) {
  keep = match.arg(keep)
  count = function(pattern) lengths(regmatches(text, gregexpr(pattern, text, perl = TRUE)))
  for (name in c('readme', 'appendix', 'link'))   # every opening marker needs its closing marker
    if (count(sprintf('<!--\\s*%s-only\\s*-->', name)) != count(sprintf('<!--\\s*/%s-only\\s*-->', name)))
      stop('Unbalanced <!-- ', name, '-only --> markers in the knitted report.')
  cut = function(x, name) gsub(sprintf('(?s)<!--\\s*%s-only\\s*-->.*?<!--\\s*/%s-only\\s*-->', name, name), '', x, perl = TRUE)
  text = cut(text, setdiff(c('readme', 'appendix'), keep))
  if (keep == 'appendix') text = cut(text, 'link')
  text = gsub('<!--\\s*/?(readme|appendix|link)-only\\s*-->', '', text, perl = TRUE)
  text = gsub('[ \t]+\n', '\n', text, perl = TRUE)
  gsub('\n{3,}', '\n\n', text, perl = TRUE)
}
read_text = function(file) paste(readLines(file, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
write_text = function(text, file) { force(text); con = file(file, open = 'w', encoding = 'UTF-8'); on.exit(close(con)); writeLines(text, con) }

for (rmd in sort(list.files(here('report/details'), pattern = '[.]Rmd$', full.names = TRUE))) {
  render(rmd)
  md = sub('[.]Rmd$', '.md', rmd)
  write_text(report_variant(read_text(md), 'readme'), md)  # the detail pages belong to the repository page
}
# The source of both documents lives in report/; knitted to the repository README.md first.
render(here('report/README.Rmd'), toc = FALSE, output_dir = here())  # GitHub shows its own outline
knitted = read_text(here('README.md'))
write_text(report_variant(knitted, 'readme'), here('README.md'))
# The appendix: same knitted text without the README-only parts, written to report/.
appendix = report_variant(knitted, 'appendix')
appendix = sub('^\\s*PaleoACES\n=+\n', '', appendix, perl = TRUE)                    # the page title of the README
appendix = gsub('<img src="([^"]+)"[^>]*/>', '![](\\1)', appendix, perl = TRUE)      # images that Word can read
appendix = gsub('(\\]\\(|src=")report/', '\\1', appendix, perl = TRUE)                # paths relative to report/
if (grepl('](R/', appendix, fixed = TRUE) || grepl('```r', appendix, fixed = TRUE))
  stop('The appendix still holds a link to a script or a code block: mark it readme-only in report/README.Rmd.')
write_text(appendix, here('report/appendix.md'))
# Smaller tables in the Word appendix, so that the wide ones fit the page (Bills, 12 Nov 2026): pandoc's
# default reference document with the table-cell style (Compact, used only in tables here) at 7 pt and
# table-cell margins of 40 instead of 108 twips.
reference_docx = function() {
  dir = tempfile('reference'); dir.create(file.path(dir, 'x'), recursive = TRUE)
  default = file.path(dir, 'default.docx')
  system2(rmarkdown::pandoc_exec(), c('-o', shQuote(default), '--print-default-data-file', 'reference.docx'))
  unzip(default, exdir = file.path(dir, 'x'))
  styles = file.path(dir, 'x', 'word', 'styles.xml')
  x = read_text(styles)
  y = sub('(?s)(<w:style [^>]*w:styleId="Compact">.*?</w:pPr>)', '\\1<w:rPr><w:sz w:val="14" /><w:szCs w:val="14" /></w:rPr>',
    x, perl = TRUE)
  y = gsub('<w:(left|right) w:w="108" w:type="dxa" />', '<w:\\1 w:w="40" w:type="dxa" />', y, perl = TRUE)
  if (identical(x, y) || !grepl('(?s)w:styleId="Compact">.*?<w:sz w:val="14"', y, perl = TRUE))
    stop('The table style of the pandoc reference document has changed: update reference_docx() in R/build_report.R.')
  write_text(y, styles)
  reference = file.path(dir, 'reference.docx')
  owd = setwd(file.path(dir, 'x')); on.exit(setwd(owd))
  zip(reference, list.files(all.files = TRUE, recursive = TRUE, no.. = TRUE), flags = '-qX')
  reference
}
rmarkdown::pandoc_convert(here('report/appendix.md'), to = 'docx', from = 'gfm',
  output = here('report/PaleoACES_appendix.docx'),
  options = c('--toc', '--toc-depth=3', paste0('--reference-doc=', reference_docx())), wd = here('report'))
# A self-contained HTML copy of the appendix for sharing outside GitHub.
options(paleoaces.report_output_dir = here('report'))
rmarkdown::render(here('report/README.Rmd'), output_format = rmarkdown::html_document(toc = TRUE,
    toc_float = TRUE, self_contained = TRUE, theme = 'flatly'), output_file = 'PaleoACES_report.html',
  output_dir = here('report'), quiet = TRUE, knit_root_dir = here(), envir = new.env(parent = globalenv()))
html = here('report/PaleoACES_report.html')
write_text(report_variant(read_text(html), 'readme'), html)
# Previews of figures no longer shown anywhere are stale.
used = unlist(lapply(c(here('README.md'), list.files(here('report'), pattern = '[.]md$', recursive = TRUE, full.names = TRUE)),
  function(f) regmatches(readLines(f, warn = FALSE), gregexpr('figures/png/[^)"]+[.]png', readLines(f, warn = FALSE)))))
stale = setdiff(list.files(here('report/figures/png'), full.names = TRUE), here('report', unique(sub('^((\\.\\./)+|report/)', '', used))))
unlink(stale)
cat('Report written to README.md, appendix to report/appendix.md and report/PaleoACES_appendix.docx (',
  length(stale), ' stale previews removed)\n', sep = '')
