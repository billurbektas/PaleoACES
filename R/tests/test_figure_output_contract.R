# Publication figure-output contract: four main PDF/PNG stems, PDF-only audits.
suppressPackageStartupMessages(library(here))

main_stems = c(
  "fig_standardized_climate_change_eras_fire",
  "fig_tracking_comparison",
  "fig_cca_trajectories",
  "fig_cca_direction_differences")
expected_root = sort(as.vector(outer(main_stems, c("pdf", "png"), paste, sep = ".")))
actual_root = sort(list.files(here("plot"), pattern = "\\.(pdf|png)$",
                              recursive = FALSE))
stopifnot(identical(actual_root, expected_root))

test_png = list.files(here("plot/test_figures"), pattern = "\\.png$",
                      recursive = TRUE, full.names = TRUE)
stopifnot(!length(test_png))

main_files = here("plot", expected_root)
stopifnot(all(file.exists(main_files)), all(file.info(main_files)$size > 5000))

retired = here(c("R/05b_cca_trajectory_alternatives.R",
  "output/cca_trajectory_alternatives_spec.csv",
  "plot/fig_cca_trajectories_era_centroids.pdf",
  "plot/fig_cca_trajectories_era_centroids.png"))
stopifnot(!any(file.exists(retired)))

if (nzchar(Sys.which("pdfinfo"))) {
  pages = vapply(here("plot", paste0(main_stems, ".pdf")), function(path) {
    x = system2("pdfinfo", path, stdout = TRUE, stderr = TRUE)
    as.integer(sub("^Pages:\\s*", "", grep("^Pages:", x, value = TRUE)[1]))
  }, integer(1))
  stopifnot(all(pages == 1L))
}

cat("Figure output contract passed: four main PDF/PNG stems and PDF-only audits.\n")

