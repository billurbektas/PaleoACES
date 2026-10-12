# Semantic validation of the refactored paleo vegetation and fire stages.
#
# The former test compared sample IDs to a one-time pre-split snapshot. Because
# sample IDs contain posterior median ages, a legitimate seeded Bacon refit made
# that historical snapshot fail. This gate now checks the intended scientific
# content and cross-stage contracts; chronology file identity is handled by
# test_bacon_provenance.R.

library(here)
suppressMessages({library(dplyr); library(readr)})

fails = character(0)
note = function(ok, what, detail = "") {
  cat(sprintf("  [%s] %s%s\n", if (ok) "OK  " else "FAIL", what,
              if (nzchar(detail)) paste0(" - ", detail) else ""))
  if (!ok) fails <<- c(fails, what)
}

cat("\n=== paleo_occ.csv ===\n")
occ = read_csv(here("output/paleo_occ.csv"), show_col_types = FALSE)
samples = occ %>% distinct(lake, plot_id)
expected_samples = c(JayBath = 48L, LogWallow = 40L,
                     PantherPotholes = 870L, ReflectionPond = 31L)
got_samples = table(samples$lake)

note(identical(names(occ), c("period", "plot_id", "species", "occurrence",
                             "site", "era", "lake")), "columns")
note(!anyDuplicated(occ[c("plot_id","species")]), "unique original sample x taxon records")
note(nrow(samples) == 989L, "sample count", as.character(nrow(samples)))
note(identical(as.integer(got_samples[names(expected_samples)]),
               unname(expected_samples)), "samples per lake",
     paste(sprintf("%s=%d", names(expected_samples), got_samples[names(expected_samples)]),
           collapse = ", "))
note(dplyr::n_distinct(occ$species) == 12L, "species count",
     as.character(dplyr::n_distinct(occ$species)))
note(all(occ$period == "paleo" & occ$era == "holocene"),
     "paleo period and era labels")
note(all(ifelse(occ$lake == "PantherPotholes", occ$site == "NOCA",
                occ$site == "MORA")), "lake-to-site mapping")
note(all(startsWith(occ$plot_id,paste0(occ$lake,':'))), 'Source-based sample identities')
note(all(occ$occurrence %in% c(0, 1)), "occurrence in {0,1}")
note(!anyNA(occ), "no NA")
bad = grep("unknown|sp\\.$|^Abies sp|^Salix sp", unique(occ$species),
           value = TRUE, ignore.case = TRUE)
note(length(bad) == 0L, "no unsupported identification labels",
     paste(bad, collapse = ", "))

cat("\n=== vegetation, depth, and fire contracts ===\n")
depths = read_csv(here("output/paleo_sample_depths.csv"), show_col_types = FALSE)
fire = read_csv(here("output/paleo_fire.csv"), show_col_types = FALSE)
noca_peaks = read_csv(here("output/fire_noca_peaks.csv"), show_col_types = FALSE)
note(setequal(samples$plot_id, depths$plot_id),
     "every vegetation sample has a depth mapping")
note(setequal(samples$plot_id, fire$plot_id),
     "one fire row for every vegetation sample")
note(!anyDuplicated(fire$plot_id), "unique paleo fire plot IDs")
fire_sites = ifelse(fire$lake == "PantherPotholes", "NOCA", "MORA")
note(setequal(unique(fire_sites), c("MORA", "NOCA")),
     "both paleo sites represented")
note(any(fire_sites == "NOCA" & fire$fire_peak_magnitude > 0),
     "NOCA in-core macrocharcoal peaks included")
note(sum(noca_peaks$is_significant) == 66L,
     "NOCA primary source-faithful significant-peak count",
     as.character(sum(noca_peaks$is_significant)))
note(sum(noca_peaks$is_significant & noca_peaks$age_cal_yr_BP > 8200 &
           noca_peaks$age_cal_yr_BP <= 9200) == 6L,
     "NOCA 9.2-8.2 ka significant-peak count")
note(all(noca_peaks$interpolation_interval == 12L &
           noca_peaks$smoothing_window == 500L &
           noca_peaks$threshold_probability == .99),
     "NOCA primary 12-year/500-year/99% settings")

cat("\n=== cross-arm species check (informational) ===\n")
survey = bind_rows(
  read_csv(here("output/MORA_occ.csv"), show_col_types = FALSE) %>% select(species),
  read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE) %>% select(species)
)
dropped = setdiff(unique(occ$species), unique(survey$species))
cat("paleo species absent from survey species list: ",
    if (length(dropped)) paste(dropped, collapse = ", ") else "none", "\n", sep = "")

cat("\n")
if (length(fails)) {
  cat("FAILED (", length(fails), "): ", paste(fails, collapse = "; "), "\n", sep = "")
  quit(save = "no", status = 1)
}
cat("Paleo vegetation/fire semantic checks passed; chronology identity is covered by the Bacon manifest.\n")
