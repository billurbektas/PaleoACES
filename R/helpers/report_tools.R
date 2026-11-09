# Helpers for the report (README.Rmd and report/details/*.Rmd).
# Figures are shown from report/figures/; tables are read from output/ and
# also saved under report/tables/; code is quoted verbatim from the scripts.
source(here::here('R/helpers/config.R'), local = TRUE)
options(knitr.kable.NA = '—')

# PNG previews of PDF pages, rendered once per build into report/figures/png/.
show_figure = function(pdf, page = 1L, width = '100%', dpi = 110L) {
  pdf = here::here(pdf)
  if (!file.exists(pdf)) stop('Missing figure: ', pdf, '. Run Rscript R/run_all.R first.')
  pngs = vapply(page, function(p) {
    stem = paste0(tools::file_path_sans_ext(basename(pdf)), if (p > 1L) paste0('-p', p) else '')
    png = here::here('report/figures/png', paste0(stem, '.png'))
    dir.create(dirname(png), recursive = TRUE, showWarnings = FALSE)
    if (!file.exists(png) || file.mtime(png) < file.mtime(pdf)) {
      status = system2('pdftoppm', c('-png', '-singlefile', '-r', dpi, '-f', p, '-l', p,
        shQuote(pdf), shQuote(sub('[.]png$', '', png))))
      if (status != 0L) stop('pdftoppm failed for ', pdf, ' page ', p)
    }
    relative_to_document(png)
  }, character(1))
  knitr::include_graphics(pngs, error = FALSE)
}

# Number of pages of a figure PDF.
pdf_pages = function(pdf) {
  info = system2('pdfinfo', shQuote(here::here(pdf)), stdout = TRUE)
  as.integer(sub('^Pages:\\s+', '', grep('^Pages:', info, value = TRUE)))
}

# Path of a report file relative to the document being knitted.
relative_to_document = function(path) {
  doc_dir = normalizePath(knitr::opts_knit$get('output.dir') %||% getwd())
  path = normalizePath(path)
  up = 0L; d = doc_dir
  while (!startsWith(path, paste0(d, '/'))) { d = dirname(d); up = up + 1L }
  paste0(strrep('../', up), substring(path, nchar(d) + 2L))
}
`%||%` = function(a, b) if (is.null(a)) b else a

# Link to a repository file from the document being knitted.
repo_link = function(path, label = path) sprintf('[%s](%s)', label, relative_to_document(here::here(path)))

# Show a table and save it as report/tables/<name>.csv (linked under the table).
show_table = function(x, name, caption = NULL, digits = 3, ...) {
  path = here::here('report/tables', paste0(name, '.csv'))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = '')
  knitr::asis_output(paste(c(
    if (!is.null(caption)) paste0('\n', caption, '\n'),
    knitr::kable(x, digits = digits, format = 'pipe', ...),
    '', paste0('<sub>Table file: ', repo_link(file.path('report/tables', paste0(name, '.csv')),
      paste0(name, '.csv')), '</sub>'), ''), collapse = '\n'))
}

read_output = function(name, ...) readr::read_csv(out(name), show_col_types = FALSE, ...)

# Verbatim code between `# report-snippet: <name>` and `# end-snippet: <name>`.
code_snippet = function(file, name) {
  x = readLines(here::here(file), warn = FALSE)
  start = which(trimws(x) == paste0('# report-snippet: ', name))
  end = which(trimws(x) == paste0('# end-snippet: ', name))
  if (length(start) != 1L || length(end) != 1L || end <= start)
    stop('Snippet "', name, '" not found exactly once in ', file)
  code = x[(start + 1L):(end - 1L)]
  knitr::asis_output(paste0('\n```r\n# ', file, '\n', paste(code, collapse = '\n'), '\n```\n'))
}

details_link = function(page, label = 'Details') {
  sprintf('**%s →** %s', label, repo_link(file.path('report/details', paste0(page, '.md')), page))
}
