# Offline regression checks for Wilson-style fire assignments on PaleoACES plots.
suppressPackageStartupMessages({library(here); library(dplyr); library(readr)})

fire = read_csv(here("output/NOCA_plot_info_fire.csv"), show_col_types = FALSE)
occ = read_csv(here("output/NOCA_occ.csv"), show_col_types = FALSE)
cmp = read_csv(here("output/NOCA_fire_Wilson2024_comparison.csv"), show_col_types = FALSE)

stopifnot(
  nrow(fire) == 307L,
  !anyDuplicated(fire$plot_id),
  setequal(fire$plot_id, occ$plot_id),
  sum(fire$burnt) == 32L,
  sum(!fire$burnt) == 275L,
  identical(as.integer(table(cmp$universe_status)[c("shared", "PaleoACES_only", "Wilson_only")]),
            c(305L, 2L, 64L)),
  !any(cmp$assignment_discrepancy %in% TRUE, na.rm = TRUE),
  setequal(cmp$plot_id[cmp$universe_status == "PaleoACES_only"],
           c("THOR223", "BAK494")),
  setequal(cmp$plot_id[cmp$universe_status == "Wilson_only" & cmp$wilson_burnt],
           c("HIBR2082", "STE2011", "STE2019", "STE2023", "STE2024", "STE2033")),
  all(c("BAK487", "BEAV6061") %in%
        cmp$plot_id[cmp$universe_status == "Wilson_only"])
)
cat("NOCA fire checks passed: 307 plots; 32 burned; no discrepancy on 305 shared plots.\n")
