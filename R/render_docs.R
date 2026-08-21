# Render maintained Markdown documents to same-directory self-contained HTML.
suppressPackageStartupMessages({
  library(here)
  library(rmarkdown)
  library(stringr)
})
source(here("R/documentation_config.R"))

missing = PALEOACES_DOCS[!file.exists(here(PALEOACES_DOCS))]
if (length(missing)) stop("Missing maintained Markdown: ", paste(missing, collapse = ", "))

for (rel in PALEOACES_DOCS) {
  src = here(rel)
  out = sub("\\.md$", ".html", src)
  rmarkdown::render(
    input = src,
    output_format = html_document(
      self_contained = TRUE,
      toc = TRUE,
      toc_float = TRUE,
      theme = "flatly",
      highlight = "textmate"
    ),
    output_file = basename(out),
    output_dir = dirname(out),
    knit_root_dir = dirname(src),
    quiet = TRUE,
    envir = new.env(parent = globalenv())
  )

  html = readLines(out, warn = FALSE, encoding = "UTF-8")
  html = str_replace_all(
    html,
    'href="(?!https?://|mailto:)([^"]+)\\.md([#?][^"]*)?"',
    'href="\\1.html\\2"'
  )
  source_md5 = unname(tools::md5sum(src))
  html = append(html, paste0("<!-- paleoaces-source-md5: ", source_md5, " -->"), after = 1L)
  writeLines(html, out, useBytes = TRUE)
  cat("rendered ", rel, " -> ", sub("\\.md$", ".html", rel), "\n", sep = "")
}
