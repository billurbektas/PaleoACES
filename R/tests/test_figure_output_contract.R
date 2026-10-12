# Publication figure-output contract: three manuscript PDFs, two PNG versions, PDF-only audits.
suppressPackageStartupMessages(library(here))

main_stems = c(
  "fig_standardized_climate_change_eras_fire",
  "fig_cca_trajectories",
  "fig_tracking_era_distributions")
expected_root = sort(c(paste0(main_stems,'.pdf'),paste0(main_stems[-1],'.png')))
actual_root = sort(list.files(here("plot"), pattern = "\\.(pdf|png)$",
                              recursive = FALSE))
stopifnot(identical(actual_root, expected_root))

test_png = list.files(here("plot/test_figures"), pattern = "\\.png$",
                      recursive = TRUE, full.names = TRUE)
stopifnot(!length(test_png))

main_files = here("plot", expected_root)
stopifnot(all(file.exists(main_files)), all(file.info(main_files)$size > 5000))
corrected_contrasts = here("plot/test_figures/primary_models/fig_tracking_corrected_lag_contrasts.pdf")
stopifnot(file.exists(corrected_contrasts), file.info(corrected_contrasts)$size > 5000)
sampling_support = here("plot/test_figures/fig_holocene_sampling_fire_100yr.pdf")
stopifnot(file.exists(sampling_support), file.info(sampling_support)$size > 5000)
consolidated=here('plot/test_figures',c(
  paste0('primary_models/fig_tracking_model_',c('group_means','coefficients','contrasts','residuals','aic'),'.pdf'),
  paste0('sensitivity/lake_checks/fig_tracking_lake_',c('coefficients','contrasts'),'.pdf')))
stopifnot(all(file.exists(consolidated)),all(file.info(consolidated)$size>5000))
obsolete_metric_pdfs=list.files(here('plot/test_figures'),
  pattern='^fig_tracking_(model|lake)_(group_means|coefficients|contrasts|residuals|aic)_.+[.]pdf$',full.names=TRUE)
stopifnot(!length(obsolete_metric_pdfs))

retired = here(c("R/05b_cca_trajectory_alternatives.R",
  "output/cca_trajectory_alternatives_spec.csv",
  "plot/fig_cca_trajectories_era_centroids.pdf",
  "plot/fig_cca_trajectories_era_centroids.png"))
stopifnot(!any(file.exists(retired)))

if (nzchar(Sys.which("pdfinfo"))) {
  pages = vapply(c(here("plot", paste0(main_stems, ".pdf")), corrected_contrasts, sampling_support), function(path) {
    x = system2("pdfinfo", path, stdout = TRUE, stderr = TRUE)
    as.integer(sub("^Pages:\\s*", "", grep("^Pages:", x, value = TRUE)[1]))
  }, integer(1))
  stopifnot(all(pages == 1L))
  consolidated_pages=vapply(consolidated,function(path) {
    x=system2('pdfinfo',path,stdout=TRUE,stderr=TRUE)
    as.integer(sub('^Pages:\\s*','',grep('^Pages:',x,value=TRUE)[1]))
  },integer(1))
  stopifnot(all(consolidated_pages==5L))
}

cat("Figure output contract passed: three manuscript PDFs, two PNG versions and PDF-only audits.\n")
