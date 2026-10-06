# Offline gate for the selected publication CCA trajectory architecture.
suppressPackageStartupMessages({library(here); library(tidyverse)})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

centroid_path = here("output/cca_trajectory_era_centroids.csv")
figure_files = here(c("plot/fig_cca_trajectories.pdf",
                      "plot/fig_cca_trajectories.png"))
stopifnot(file.exists(centroid_path))
if (render_figures)
  stopifnot(all(file.exists(figure_files)), all(file.info(figure_files)$size > 5000))

centroids = read_csv(centroid_path, show_col_types = FALSE)
eras = c("CC1", "S1", "CC2", "S2", "CC3", "S3", "CC4", "S4")
stopifnot(
  setequal(centroids$site, c("MORA", "NOCA")),
  all(table(centroids$site) == 8L),
  all(table(centroids$era_id) == 2L),
  identical(unique(centroids$era_id), eras),
  !anyDuplicated(centroids[c("site", "era_id")]),
  all(centroids$n_dates > 0L),
  all(is.finite(unlist(select(centroids, ends_with(c("CCA1", "CCA2"))))))
)

main_code = paste(readLines(here("R/stages/05a_cca_figure.R")), collapse = "\n")
stopifnot(
  str_detect(main_code, 'holocene_display_mode = "era_centroid"'),
  str_detect(main_code, 'cca_figure_stem = "fig_cca_trajectories"'),
  str_detect(main_code, "connected separately from CC1 through S4"),
  str_detect(main_code, "geom_segment\\(data = step_heads"),
  str_detect(main_code, "series_label_positions = tribble"),
  str_detect(main_code, "geom_text\\(data = series_lab"),
  !str_detect(main_code, "geom_text_repel\\(data = series_lab"),
  !str_detect(main_code, "geom_label_repel\\(data = series_lab"),
  str_detect(main_code, '"Holocene\\\\nObserved"'),
  str_detect(main_code, '"Anthropocene\\\\nPredicted"'),
  str_detect(main_code, "nrow\\(series_lab\\) == 8L"),
  str_detect(main_code, "setequal\\(series_lab\\$lab, expected_series_labels\\)"),
  str_detect(main_code, '"NOCA", "holocene",     "observed",   "CC1"'),
  str_detect(main_code, '"MORA", "holocene",     "observed",   "CC4"'),
  str_detect(main_code, '"NOCA", "anthropocene", "predicted",  "legacy"'),
  str_detect(main_code, '"NOCA", "anthropocene", "observed",   "resurvey"'),
  str_detect(main_code, '"MORA", "anthropocene", "observed",   "legacy"'),
  str_count(main_code,
    fixed("aes(x, y, label = lab, color = !!cv, alpha = type)")) == 1L,
  str_detect(main_code,
    "aes\\(x, y, label = lab, color = !!cv, alpha = type\\)"),
  str_detect(main_code,
    "aes\\(x \\+ nx, y \\+ ny, label = lab, color = !!cv, alpha = type\\)"),
  str_detect(main_code, "lineheight = 0\\.82"),
  all(str_detect(main_code, fixed(c('"A."', '"B."', '"C."', '"D."')))),
  str_detect(main_code, "show.legend = FALSE\\) \\+\\n    geom_segment\\(data = steps"),
  str_detect(main_code,
    "geom_segment\\(data = step_heads[\\s\\S]+show.legend = TRUE"),
  str_detect(main_code, "legend.key.width = unit\\(2.2"),
  str_count(main_code, "show.legend = FALSE") >= 4L,
  str_detect(main_code,
    "INSET_BOX = c\\(left = 0.45, bottom = 0.54, right = 1.00, top = 1.00\\)")
)

retired = here(c(
  "R/05b_cca_trajectory_alternatives.R",
  "output/cca_trajectory_alternatives_spec.csv",
  "plot/fig_cca_trajectories_era_centroids.pdf",
  "plot/fig_cca_trajectories_era_centroids.png",
  "plot/fig_cca_trajectories_full_holocene_sites.pdf",
  "plot/fig_cca_trajectories_full_holocene_sites.png"))
stopifnot(!any(file.exists(retired)))

pdf_pages = function(path) {
  if (!nzchar(Sys.which("pdfinfo"))) return(NA_integer_)
  x = system2("pdfinfo", path, stdout = TRUE, stderr = TRUE)
  as.integer(sub("^Pages:\\s*", "", grep("^Pages:", x, value = TRUE)[1]))
}
if (render_figures && nzchar(Sys.which("pdfinfo")))
  stopifnot(pdf_pages(figure_files[1]) == 1L)

cat("PASS: publication CCA figure uses eight named CC1-S4 WA/LC paths and A-D panels",
    if (render_figures) ", including PDF/PNG outputs.\n" else ".\n", sep = "")
