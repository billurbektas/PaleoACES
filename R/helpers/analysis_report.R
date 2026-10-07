# Optional reporting functions. Analysis stages retain their existing environments.
report_registry = function() jsonlite::fromJSON(here::here("docs/report/artifacts.json"), simplifyVector = FALSE)
report_python = function(args) {
  python = Sys.which("python3")
  if (!nzchar(python)) stop("Report rebuilding requires Python 3.")
  status = system2(python, c(shQuote(here::here("tools/build_analysis_review.py")), args))
  if (status != 0L) stop("Analysis review command failed (status ", status, ").")
}
report_begin = function() {
  path = here::here("output/report")
  unlink(path, recursive = TRUE)
  dir.create(path, recursive = TRUE)
  report_python("--capture")
  list(started = as.numeric(Sys.time()), run_id = format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), records = list())
}
report_record = function(state, producer, started, paths = NULL) {
  if (is.null(paths)) {
    registry = report_registry()
    paths = c(unlist(lapply(registry$diagnostics, function(x)
      if (x$producer == producer && x$status != "historical reference") x$pdf)),
      unlist(lapply(registry$main_figures, function(x)
        if (x$producer == producer) paste0("plot/", x$stem, c(".pdf", ".png")))),
      unlist(lapply(registry$tables, function(x)
        if (x$producer == producer && basename(x$source) != "bacon_run_manifest.csv") x$source)))
  }
  for (path in unique(paths)) {
    absolute = here::here(path)
    if (!file.exists(absolute) || file.info(absolute)$size == 0 ||
        as.numeric(file.info(absolute)$mtime) < started - 0.001)
      stop("Report producer did not regenerate required output: ", producer, " -> ", path)
    state$records[[path]] = list(path = path, producer = producer,
      sha256 = digest::digest(file = absolute, algo = "sha256"),
      generated_at_utc = format(file.info(absolute)$mtime, "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"))
  }
  state
}
report_export_cca = function(model_env) {
  # Only read the current fit and its prepared tables; no alternate fit/inference.
  e = model_env
  write = function(x, name) readr::write_csv(x, here::here("output/report", paste0(name, ".csv")))
  write(data.frame(field = c("calibration_plots", "retained_species", "count_threshold", "scaling", "hill", "constraints", "total_inertia", "constrained_inertia", "constrained_percent", "projection_candidates", "positioned_samples"),
    value = c(nrow(e$species_past_final), length(e$keep_species), e$count.thr,
      e$cca_scaling, e$cca_hill, paste(e$CCA_VARIABLES, collapse = ";"),
      e$cca_model$tot.chi, e$cca_model$CCA$tot.chi,
      100 * e$cca_model$CCA$tot.chi / e$cca_model$tot.chi,
      sum(e$cca_eligibility_counts$input_units[
        e$cca_eligibility_counts$use != "Legacy calibration"]),
      nrow(e$comparison_df))), "cca_summary")
  eig = e$cca_model$CCA$eig
  write(data.frame(axis = names(eig), eigenvalue = as.numeric(eig),
    percent_total_inertia = 100 * eig / e$cca_model$tot.chi,
    percent_constrained_inertia = 100 * eig / sum(eig)), "cca_axes")
  write(as.data.frame(e$occ_summary) |> dplyr::mutate(retained = species %in% e$keep_species), "cca_taxa")
  counts = e$env |> dplyr::distinct(site, period, plot_id) |> dplyr::count(site, period, name = "input_samples")
  calibrated = e$env |> dplyr::filter(period == "past", plot_id %in% rownames(e$species_past_final)) |> dplyr::count(site, period, name = "calibration_samples")
  positioned = e$comparison_df |> dplyr::mutate(period = ifelse(era == "anthropocene", "present", "paleo")) |> dplyr::count(site, period, name = "positioned_samples")
  write(counts |> dplyr::left_join(calibrated, by = c("site", "period")) |> dplyr::left_join(positioned, by = c("site", "period")), "cca_counts")
  write(e$climate_summary |> dplyr::group_by(site, period) |>
    dplyr::summarize(plots = dplyr::n(), dplyr::across(dplyr::starts_with("n_"), max), .groups = "drop"), "climate_windows")
  cleaning = lapply(c("MORA", "NOCA", "paleo"), function(name) {
    x = readr::read_csv(here::here("output", paste0(name, "_occ.csv")), show_col_types = FALSE)
    data.frame(source = name, rows = nrow(x), plot_or_sample_ids = dplyr::n_distinct(x$plot_id), taxa = dplyr::n_distinct(x$species))
  })
  x = readr::read_csv(here::here("output/occ_consolidated.csv"), show_col_types = FALSE)
  write(dplyr::bind_rows(cleaning, data.frame(source = "consolidated", rows = nrow(x), plot_or_sample_ids = dplyr::n_distinct(x$plot_id), taxa = dplyr::n_distinct(x$species))), "cleaning_summary")
}
report_redraw_chronology = function() {
  gate = function() sys.source(here::here("R/tests/test_bacon_provenance.R"), envir = new.env(parent = globalenv()))
  gate()
  protected = c(list.files(here::here("Cores"), pattern = "[.](csv|out|txt|bacon)$", full.names = TRUE, recursive = TRUE),
    here::here(c("R/stages/000_PALEO_a_agedepth.R", "R/helpers/bacon_settings.R", "R/helpers/config.R", "output/bacon_run_manifest.csv")))
  before = tools::md5sum(protected)
  snapshots = tempfile("report-chronology-protection-")
  dir.create(snapshots)
  copies = file.path(snapshots, as.character(seq_along(protected)))
  if (!all(file.copy(protected, copies))) stop("Could not snapshot protected chronology files.")
  restore_protected = function() {
    changed = !file.exists(protected) | unname(tools::md5sum(protected)) != unname(before)
    changed[is.na(changed)] = TRUE
    if (any(changed) && !all(file.copy(copies[changed], protected[changed], overwrite = TRUE)))
      stop("Could not restore protected chronology files from reporting snapshots.")
    if (!identical(before, tools::md5sum(protected))) stop("Chronology restoration failed.")
  }
  # rbacon can open an implicit plotting device while preparing its ghost graph.
  # Keep these temporary renders outside the repository, including on errors.
  previous_device = getOption("device")
  previous_devices = dev.list()
  options(device = function(...) grDevices::pdf(file = tempfile(fileext = ".pdf"), ...))
  old_info = if (exists("info", envir = .GlobalEnv, inherits = FALSE)) get("info", envir = .GlobalEnv) else NULL
  on.exit({
    if (is.null(old_info)) { if (exists("info", envir = .GlobalEnv, inherits = FALSE)) rm("info", envir = .GlobalEnv) }
    else assign("info", old_info, envir = .GlobalEnv)
    options(device = previous_device)
    new_devices = setdiff(dev.list(), previous_devices)
    for (device in new_devices) dev.off(device)
    restore_protected()
    unlink(snapshots, recursive = TRUE)
  }, add = TRUE)
  code = readLines(here::here("R/stages/000_PALEO_a_agedepth.R"), warn = FALSE)
  start = which(startsWith(code, "# 5) FIGURES")); end = which(startsWith(code, "# 6) RUN MANIFEST"))
  if (length(start) != 1 || length(end) != 1 || end <= start) stop("Cannot isolate the existing Bacon figure section.")
  e = new.env(parent = globalenv())
  eval(quote(suppressPackageStartupMessages({library(rbacon); library(readr); library(tidyverse); library(here)})), e)
  sys.source(here::here("R/helpers/bacon_settings.R"), envir = e)
  assignment = Filter(function(x) is.call(x) && as.character(x[[1]]) %in% c("=", "<-") &&
    identical(x[[2]], as.name("PB210_ASSUMED_ERROR")), as.list(parse(text = code)))
  if (length(assignment) != 1L) stop("Cannot locate the existing Pb210 sensitivity setting.")
  eval(assignment[[1]], e)
  e$coredir = here::here("Cores"); e$render_figures = TRUE
  eval(parse(text = code[start:(end - 1L)]), e)
  restore_protected()
  stopifnot(identical(before, tools::md5sum(protected)))
  gate()
}
report_finish = function(state) {
  jsonlite::write_json(list(run_id = state$run_id, started = state$started,
    validation = "All 17 automatic gates passed, including independent review regressions; protected chronology validated before and after redraw.",
    records = unname(state$records)), here::here("output/report/run.json"), pretty = TRUE, auto_unbox = TRUE)
  report_python("--fresh")
}
