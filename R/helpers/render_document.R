# Shared Markdown-to-HTML rendering, including the source fingerprint.
render_document = function(src) {
  out = sub("[.]md$", ".html", src)
  rmarkdown::render(input = src,
    output_format = rmarkdown::html_document(self_contained = TRUE, toc = TRUE,
      toc_float = TRUE, theme = "flatly", highlight = "textmate"),
    output_file = basename(out), output_dir = dirname(out),
    knit_root_dir = dirname(src), quiet = TRUE, envir = new.env(parent = globalenv()))
  html = readLines(out, warn = FALSE, encoding = "UTF-8")
  html = stringr::str_replace_all(html,
    'href="(?!https?://|mailto:)([^"]+)[.]md([#?][^"]*)?"', 'href="\\1.html\\2"')
  html = append(html, paste0("<!-- paleoaces-source-md5: ", unname(tools::md5sum(src)), " -->"), after = 1L)
  writeLines(html, out, useBytes = TRUE)
  invisible(out)
}
