# Every file under output/ is declared in R/helpers/paths.R, every declared output
# exists after a run, and every local link and image in the report resolves.
suppressPackageStartupMessages(library(here))
source(here('R/helpers/config.R'), local = TRUE)

# 1. Nothing undeclared under output/.
steps = unique(OUTPUT_REGISTRY$step)
top = list.files(here('output'))
stopifnot(all(top %in% steps))
for (step in setdiff(top, 'cache')) {
  inside = list.files(here('output', step))
  names = if (step %in% OUTPUT_REGISTRY$name) file.path(step, inside) else inside
  bad = names[vapply(names, function(n) inherits(try(output_step(n), silent = TRUE), 'try-error'), logical(1))]
  if (length(bad)) stop('Undeclared output in output/', step, ': ', paste(bad, collapse = ', '))
}

# 2. Every declared file or folder exists (prefix entries need at least one match).
missing = character()
for (i in seq_len(nrow(OUTPUT_REGISTRY))) {
  r = OUTPUT_REGISTRY[i, ]
  if (r$step %in% c('figures', 'worked_examples', 'report') && r$name == r$step) next
  ok = if (grepl('^[(]prefix[)]', r$description))
    length(list.files(here('output', r$step), pattern = paste0('^', r$name))) > 0L else file.exists(out(r$name))
  if (!ok) missing = c(missing, file.path(r$step, r$name))
}
if (length(missing)) stop('Declared outputs not written: ', paste(missing, collapse = ', '))

# 3. The report's local links resolve (when the report has been built).
docs = c(here('README.md'), list.files(here('report'), pattern = '[.]md$', recursive = TRUE, full.names = TRUE))
docs = docs[!grepl('/manuscript/', docs)]
broken = character()
for (doc in docs) {
  text = paste(readLines(doc, warn = FALSE), collapse = '\n')
  links = c(regmatches(text, gregexpr('\\]\\(([^)[:space:]]+)\\)', text))[[1]],
            regmatches(text, gregexpr('src="[^"]+"', text))[[1]])
  links = sub('^src="', '', sub('"$', '', sub('^\\]\\(', '', sub('\\)$', '', links))))
  links = sub('#.*$', '', links[!grepl('^(https?:|mailto:|#)', links)])
  links = links[nzchar(links)]
  gone = links[!file.exists(file.path(dirname(doc), links))]
  if (length(gone)) broken = c(broken, paste0(sub(paste0(here(), '/'), '', doc), ': ', gone))
}
if (length(broken)) stop('Broken report links:\n', paste(broken, collapse = '\n'))
cat('Pipeline outputs: all', length(top), 'output folders declared; report links resolve.\n')
