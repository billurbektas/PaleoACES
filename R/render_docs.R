# Render maintained Markdown to same-directory self-contained HTML.
suppressPackageStartupMessages({library(here); library(rmarkdown); library(stringr)})
source(here("R/helpers/documentation_config.R"))
source(here("R/helpers/render_document.R"))
args = commandArgs(trailingOnly = TRUE)
paths = if (length(args)) args else here(PALEOACES_DOCS)
missing = paths[!file.exists(paths)]
if (length(missing)) stop("Missing maintained Markdown: ", paste(missing, collapse = ", "))
for (src in paths) {
  render_document(normalizePath(src))
  cat("rendered ", src, "\n", sep = "")
}
