# =============================================================================
# test_paleo_climate_age_match.R - does every sample have climate, at its OWN age?
# =============================================================================
# The single most important paleo check, and the one that would have caught the
# original bug: MORA climate was downloaded only to 6000 cal BP while the MORA
# cores reach 6841, so 30 samples silently carried no climate and were dropped by
# the CCA without anything announcing it.
#
# TWO FAILURE MODES, and they are different:
#
#   1. COVERAGE - a sample has no climate row at all. Loud once you look, silent
#      if you do not: the CCA's intersect() just drops those samples.
#   2. MISMATCH - a sample HAS climate, but from the wrong time. A sample at
#      6841 cal BP silently assigned the 6000 cal BP slice looks perfectly
#      healthy in every table, and injects an 841-yr error into a 500-yr bin.
#
# Check 2 is only possible if paleo_env.csv records WHICH slice each sample was
# matched to. R/stages/000_PALEO_e_climate.R must therefore carry `slice` and
# `slice_age_calBP` through; see docs/WORKFLOW.md. Without those columns this
# script can only test coverage, and says so.
#
# Run after R/stages/000_PALEO_e_climate.R. Exits non-zero on any failure.
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(readr)})
source(here("R/helpers/config.R"), local = TRUE)

TOL_YR = 50   # half a TraCE21k slice: the worst a correct nearest-slice join can do

fails = character(0)
note = function(ok, what, detail = "") {
  cat(sprintf("  [%s] %s%s\n", if (ok) "OK  " else "FAIL", what,
              if (nzchar(detail)) paste0(" - ", detail) else ""))
  if (!ok) fails <<- c(fails, what)
}
age_of = function(x) as.numeric(regmatches(x, regexpr("-?[0-9.]+(?=_BP$)", x, perl = TRUE)))

occ = read_csv(here("output/paleo_occ.csv"), show_col_types = FALSE)
env = read_csv(here("output/paleo_env.csv"), show_col_types = FALSE)

samples = occ %>% distinct(lake, site, plot_id) %>% mutate(age = age_of(plot_id))
climate = env %>% distinct(plot_id, .keep_all = TRUE)

cat("=== 1. COVERAGE: does every vegetation sample have USABLE climate? ===\n")
# A row is not coverage. Checked 2026-08-12 against the pre-Step-2 data: all 963
# samples had a climate ROW and 30 of them had NA in every CCA variable. A
# row-count check passes that; the CCA still drops them.

ccavars_all = intersect(c("MWT", "MST", "WP", "SpP", "MAT", "AP", "MSpT", "SP"),
                        names(env))
climate = climate %>%
  mutate(usable = if (length(ccavars_all))
    rowSums(is.na(across(all_of(ccavars_all)))) == 0 else TRUE)

miss = anti_join(samples, climate, by = "plot_id")
note(nrow(miss) == 0, "every sample has a climate row",
     sprintf("%d of %d missing", nrow(miss), nrow(samples)))

empty = samples %>%
  inner_join(climate %>% select(plot_id, usable), by = "plot_id") %>%
  filter(!usable)
note(nrow(empty) == 0, "every climate row is non-NA",
     sprintf("%d row(s) present but all-NA", nrow(empty)))

no_climate = bind_rows(miss %>% mutate(why = "no row"),
                       empty %>% mutate(why = "row, but NA"))
if (nrow(no_climate)) {
  cat("\n  samples WITHOUT usable climate, by lake:\n")
  print(as.data.frame(no_climate %>% group_by(lake, why) %>%
    summarise(n = n(), age_min = min(age), age_max = max(age), .groups = "drop")))
  cat("\n  -> dropped by complete-case filtering / intersect() in 05_cca_model.R,\n")
  cat("     with nothing printed. Their ages tell you WHICH end of the record\n")
  cat("     the download failed to reach.\n")
}

orphan = anti_join(climate, samples, by = "plot_id")
note(nrow(orphan) == 0, "no climate rows without a sample",
     sprintf("%d orphan(s)", nrow(orphan)))

cat("\n  usable coverage per lake:\n")
print(as.data.frame(
  samples %>%
    left_join(climate %>% select(plot_id, usable), by = "plot_id") %>%
    mutate(usable = !is.na(usable) & usable) %>%
    group_by(lake) %>%
    summarise(n = n(), with_climate = sum(usable),
              pct = round(100 * mean(usable), 1),
              sample_age_range = sprintf("%.0f - %.0f", min(age), max(age)),
              uncovered_ages = if (all(usable)) "-" else
                sprintf("%.0f - %.0f", min(age[!usable]), max(age[!usable])),
              .groups = "drop")))

cat("\n=== 2. AGE MATCH: is the climate from the sample's own time? ===\n")

if (all(c("slice", "slice_age_calBP") %in% names(env))) {
  m = samples %>%
    inner_join(env %>% distinct(plot_id, slice, slice_age_calBP), by = "plot_id") %>%
    mutate(age_error = slice_age_calBP - age)

  note(all(abs(m$age_error) <= TOL_YR), sprintf("all within +/-%d yr", TOL_YR),
       sprintf("max |error| = %.0f yr", max(abs(m$age_error))))
  note(!any(is.na(m$slice)), "every sample matched to a slice")

  cat("\n  age error by lake (assigned slice age minus sample age, yr):\n")
  print(as.data.frame(
    m %>% group_by(lake) %>%
      summarise(n = n(), mean = round(mean(age_error), 1),
                min = round(min(age_error), 1), max = round(max(age_error), 1),
                n_over_tol = sum(abs(age_error) > TOL_YR), .groups = "drop")))

  worst = m %>% arrange(desc(abs(age_error))) %>% head(10)
  if (any(abs(worst$age_error) > TOL_YR)) {
    cat("\n  worst offenders:\n")
    print(as.data.frame(worst %>% select(lake, plot_id, age, slice,
                                         slice_age_calBP, age_error)),
          row.names = FALSE)
  }

  # a sample beyond the ends of the slice series gets clamped to the first or
  # last slice, which looks fine but is extrapolation, not matching
  edge = m %>% filter(slice %in% range(m$slice, na.rm = TRUE), abs(age_error) > TOL_YR)
  note(nrow(edge) == 0, "no samples clamped to the first/last slice",
       sprintf("%d clamped - these are EXTRAPOLATED, not matched", nrow(edge)))

} else {
  cat("  paleo_env.csv has no `slice` / `slice_age_calBP` columns, so the age\n")
  cat("  match CANNOT be verified - only coverage was checked above.\n")
  cat("  A sample can carry climate from the wrong millennium and look healthy.\n")
  note(FALSE, "age-match provenance columns present",
       "add `slice` and `slice_age_calBP` in R/stages/000_PALEO_e_climate.R")
}

cat("\n=== 3. the CCA variables are actually usable ===\n")
ccavars = intersect(CCA_VARIABLES, names(env))
if (length(ccavars)) {
  na_counts = sapply(env[ccavars], function(x) sum(is.na(x)))
  note(all(na_counts == 0), "no NA in the CCA variables",
       paste(sprintf("%s:%d", names(na_counts), na_counts), collapse = " "))
  cat("\n  ranges:\n")
  print(as.data.frame(t(sapply(env[ccavars], function(x)
    c(min = min(x, na.rm = TRUE), max = max(x, na.rm = TRUE))))), digits = 4)
} else {
  cat("  none of the configured CCA variables are present yet\n")
}

cat("\n")
if (length(fails)) {
  cat("FAILED (", length(fails), "): ", paste(fails, collapse = "; "), "\n", sep = "")
  quit(save = "no", status = 1)
}
cat("Climate and vegetation ages match.\n")
