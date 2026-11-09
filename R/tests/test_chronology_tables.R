# Supplementary Tables S1.1 and S1.2 must match what Bacon actually ran with.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(readr)})
source(here("R/helpers/chronology_tables.R"), local = TRUE)

# 1. The written tables are current: rebuilding from the Bacon files gives the same cells.
for (kind in names(CHRONOLOGY_TABLE_PATHS)) {
  path = out(CHRONOLOGY_TABLE_PATHS[[kind]])
  if (!file.exists(path)) stop("Missing ", CHRONOLOGY_TABLE_PATHS[[kind]],
    ". Run: Rscript R/stages/000_PALEO_b_vegetation.R")
  written = read_csv(path, col_types = cols(.default = col_character()))
  rebuilt = if (kind == "controls") chronology_controls_table() else bacon_parameters_table()
  if (!identical(as.data.frame(written), as.data.frame(rebuilt)))
    stop(CHRONOLOGY_TABLE_PATHS[[kind]], " is stale. Run: Rscript R/stages/000_PALEO_b_vegetation.R")
}

# 2. Every Bacon control appears exactly once, with its entered depth, age, error and cc.
s11 = read_csv(out(CHRONOLOGY_TABLE_PATHS[["controls"]]), col_types = cols(.default = col_character()))
controls = do.call(rbind, lapply(names(CHRONOLOGY_TABLE_CORES), function(core)
  cbind(core = core, read_csv(here("Cores", core, paste0(core, ".csv")), col_types = "cdddd"))))
stopifnot(nrow(s11) == nrow(controls), nrow(s11) == 40L,
  identical(sort(table(s11$Core)), sort(table(unname(CHRONOLOGY_TABLE_CORES[controls$core])))),
  all(!is.na(as.matrix(s11))), all(nzchar(as.matrix(s11))))
for (i in seq_len(nrow(controls))) {
  x = controls[i, ]
  row = s11[s11$Core == CHRONOLOGY_TABLE_CORES[[x$core]] & s11$`Depth (cm)` == chronology_number(x$Depth), ]
  stopifnot(nrow(row) >= 1L)
  hit = startsWith(row$`Age entered ± error`, paste0(chronology_number(x$Age), " ± ", chronology_number(x$Error), " ")) |
    startsWith(row$`Age entered ± error`, paste0(chronology_number(x$Age), "; error entered = ", chronology_number(x$Error)))
  if (sum(hit) != 1L) stop("Table S1.1 does not carry Bacon control ", x$core, " ", x$ID)
  stopifnot(startsWith(row$`Bacon treatment`[hit], paste0("cc = ", x$cc)))
}

# 3. Table S1.2 describes the runs on disk: MORA cores share their priors, and
#    the posterior files hold the ssize the table reports.
s12 = read_csv(out(CHRONOLOGY_TABLE_PATHS[["parameters"]]), col_types = cols(.default = col_character()))
for (core in names(CHRONOLOGY_TABLE_CORES)) {
  settings = read_bacon_settings_file(core)
  for (name in c("acc.mean", "acc.shape", "mem.mean", "mem.strength"))
    stopifnot(as.numeric(settings[[name]]) == CORE_ARGS[[core]][[name]])
  bacon_out = Sys.glob(here("Cores", core, paste0(core, "_*.out")))
  stopifnot(length(bacon_out) == 1L)
  column = if (CHRONOLOGY_TABLE_SITES[[core]] == "MORA") "MORA" else "Panther Potholes"
  ssize = as.numeric(gsub(",", "", s12[[column]][s12$`rbacon argument` == "ssize"]))
  if (length(readLines(bacon_out)) != ssize) stop("Table S1.2 ssize disagrees with ", basename(bacon_out))
}
stopifnot(nrow(s12) == 11L, !anyDuplicated(s12$`rbacon argument`))

cat("Chronology tables S1.1 (40 controls) and S1.2 (11 rbacon arguments) match the Bacon runs.\n")
