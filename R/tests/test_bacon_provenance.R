# The stored Bacon chronologies are exactly what the current age-model script and
# settings produced: every control, posterior and age file matches the run
# manifest, and the script and settings are unchanged since the run. Any edit to
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
if (!all(manifest$age_model_script_md5 == md5_now("R/pipeline/05_age_depth_models.R")))
  stop("R/pipeline/05_age_depth_models.R changed since the Bacon run. Run: Rscript R/run_all.R --age-models")
if (!all(manifest$bacon_settings_md5 == md5_now("R/helpers/bacon_settings.R")))
  stop("R/helpers/bacon_settings.R changed since the Bacon run. Run: Rscript R/run_all.R --age-models")
cat("Bacon provenance checks passed for four primary models and the +-10-year 210Pb sensitivity.\n")
