# The stored Bacon chronologies are exactly what the current age-model script and
# settings produced: every control, posterior and age file matches the run
# manifest, and the code of the script and settings is unchanged since the run.
# An edit to the comments alone passes when the manifest holds the comment-free
# fingerprints of the run's files (`code_fingerprint()` in R/helpers/config.R;
# added on 23 Nov 2026 for the run of 9 Nov 2026, after the comments of the
# script were renumbered on 11 Nov). Any edit to the code of
# R/pipeline/05_age_depth_models.R or R/helpers/bacon_settings.R requires
# `Rscript R/run_all.R --age-models`.
suppressPackageStartupMessages({library(here); library(readr)})
source(here("R/helpers/config.R"), local = TRUE)
source(here("R/helpers/bacon_settings.R"), local = TRUE)

manifest_path = out("bacon_run_manifest.csv")
if (!file.exists(manifest_path)) stop("Missing Bacon manifest. Run: Rscript R/run_all.R --age-models")
manifest = read_csv(manifest_path, show_col_types = FALSE)
expected = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes", "PantherPotholes_pb210err")
stopifnot(
  nrow(manifest) == length(expected), setequal(manifest$model, expected),
  all(manifest$seed == 42L),
  all(manifest$role[manifest$model != "PantherPotholes_pb210err"] == "primary"),
  all(manifest$rbacon_version == as.character(packageVersion("rbacon"))))

md5_now = function(path) unname(tools::md5sum(here(path)))
for (i in seq_len(nrow(manifest))) {
  row = manifest[i, ]
  for (kind in c("control", "posterior", "ages"))
    if (!identical(md5_now(row[[paste0(kind, "_file")]]), row[[paste0(kind, "_md5")]]))
      stop(row$model, ": ", kind, " file differs from the run manifest.")
  stopifnot(identical(object_fingerprint(CORE_ARGS[[row$model]]), row$settings_fingerprint))
}
# Unchanged file, or (where the manifest holds it) unchanged code with edited comments.
unchanged = function(path, full_md5, code_md5) {
  if (all(full_md5 == md5_now(path))) return(TRUE)
  !is.null(code_md5) && all(!is.na(code_md5)) && all(code_md5 == code_fingerprint(here(path)))
}
if (!unchanged("R/pipeline/05_age_depth_models.R", manifest$age_model_script_md5, manifest$age_model_code_md5))
  stop("The code of R/pipeline/05_age_depth_models.R changed since the Bacon run. Run: Rscript R/run_all.R --age-models")
if (!unchanged("R/helpers/bacon_settings.R", manifest$bacon_settings_md5, manifest$bacon_settings_code_md5))
  stop("The code of R/helpers/bacon_settings.R changed since the Bacon run. Run: Rscript R/run_all.R --age-models")
cat("Bacon provenance checks passed for four primary models and the +-10-year 210Pb sensitivity.\n")
