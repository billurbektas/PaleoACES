# Offline provenance gate for the seeded Bacon chronology products.
suppressPackageStartupMessages({
  library(here)
  library(readr)
})

source(here("R/config.R"))
source(here("R/bacon_settings.R"))

manifest_path = here("output/bacon_run_manifest.csv")
if (!file.exists(manifest_path)) {
  stop("Missing Bacon manifest. Run: Rscript R/00_workflow.R --age-models")
}
manifest = read_csv(manifest_path, show_col_types = FALSE)
expected = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes",
             "PantherPotholes_pb210err")
stopifnot(
  nrow(manifest) == length(expected),
  setequal(manifest$model, expected),
  all(manifest$seed == 42L),
  all(manifest$role[manifest$model != "PantherPotholes_pb210err"] == "primary"),
  identical(manifest$role[manifest$model == "PantherPotholes_pb210err"],
            "configured +-10-year 210Pb sensitivity"),
  !any(grepl("pbconst(15|20)", manifest$model))
)

md5_now = function(path) unname(tools::md5sum(here(path)))
age_model_code_md5 = function(path = here("R/000_PALEO_a_agedepth.R")) {
  code = readLines(path, warn = FALSE, encoding = "UTF-8")
  figure_header = which(startsWith(code, "# 5) FIGURES"))
  stopifnot(length(figure_header) == 1L)
  fingerprint_file = tempfile(fileext = ".R")
  on.exit(unlink(fingerprint_file), add = TRUE)
  writeLines(code[seq_len(figure_header - 2L)], fingerprint_file,
             useBytes = TRUE)
  unname(tools::md5sum(fingerprint_file))
}
for (i in seq_len(nrow(manifest))) {
  row = manifest[i, ]
  stopifnot(
    file.exists(here(row$control_file)),
    file.exists(here(row$posterior_file)),
    file.exists(here(row$ages_file)),
    identical(md5_now(row$control_file), row$control_md5),
    identical(md5_now(row$posterior_file), row$posterior_md5),
    identical(md5_now(row$ages_file), row$ages_md5),
    identical(as.numeric(file.info(here(row$posterior_file))$size),
              as.numeric(row$posterior_bytes)),
    identical(as.numeric(file.info(here(row$ages_file))$size),
              as.numeric(row$ages_bytes)),
    identical(object_fingerprint(CORE_ARGS[[row$model]]), row$settings_fingerprint)
  )
}

stopifnot(
  all(manifest$age_model_code_md5 == age_model_code_md5()),
  all(manifest$bacon_settings_md5 == md5_now("R/bacon_settings.R")),
  all(manifest$rbacon_version == as.character(packageVersion("rbacon")))
)
if (!all(manifest$age_model_script_md5 ==
         md5_now("R/000_PALEO_a_agedepth.R"))) {
  stopifnot(all(manifest$post_run_script_revision ==
    "figure-output-only: PDF moved to plot/test_figures; persistent PNG removed"))
}
cat("Bacon provenance checks passed for four primary models and the +-10-year 210Pb sensitivity.\n")
