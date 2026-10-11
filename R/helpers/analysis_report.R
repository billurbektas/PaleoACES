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
        if (x$producer == producer && basename(x$source) != "bacon_run_manifest.csv") x$source)),
      unlist(lapply(registry$text_outputs, function(x)
        if (x$producer == producer) x$source)),
      unlist(lapply(registry$reference_bundles, function(x)
        if (x$producer == producer) x$source)))
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
report_cca_details = function(e, permutations = 9999L, seed = 20261008L) {
  # Reporting inference reads the existing fit. Preserve the caller's RNG state.
  rng_kind = RNGkind()
  had_seed = exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) rng_seed = get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit({
    do.call(RNGkind, as.list(rng_kind))
    if (had_seed) assign(".Random.seed", rng_seed, envir = .GlobalEnv) else
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  fit = e$cca_model
  write = function(x, name) readr::write_csv(x, here::here("output/report", paste0(name, ".csv")))
  stopifnot(identical(rownames(e$species_past_final), rownames(e$env_past_final)))
  legacy = e$cca_sample_eligibility |>
    dplyr::filter(period == "past", calibration_included)
  sites = factor(legacy$site[match(rownames(e$species_past_final), legacy$plot_id)])
  stopifnot(!anyNA(sites), !anyDuplicated(legacy$plot_id),
    length(sites) == nrow(e$species_past_final))
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(seed)
  designs = list(
    Unrestricted = permute::shuffleSet(length(sites), nset = permutations,
      control = permute::how(nperm = permutations)),
    `Within parks` = permute::shuffleSet(length(sites), nset = permutations,
      control = permute::how(nperm = permutations, blocks = sites)))
  tests = list(); printed = character()
  for (design in names(designs)) {
    if (design == "Within parks") stopifnot(all(vapply(seq_len(permutations),
      function(i) identical(sites[designs[[design]][i, ]], sites), logical(1))))
    for (test in c("Overall", "Axis", "Climate variable")) {
      cat("CCA report: ", design, ", ", test, " (", permutations, " permutations).\n", sep = "")
      by = switch(test, Overall = NULL, Axis = "axis", `Climate variable` = "margin")
      a = stats::anova(fit, by = by, permutations = designs[[design]],
        model = "reduced", cutoff = 1, parallel = 1)
      tests[[length(tests) + 1L]] = data.frame(design, test, component = rownames(a),
        df = a$Df, inertia = a$ChiSquare, pseudo_F = a$F, p_value = a$`Pr(>F)`,
        permutations, seed, vegan_version = as.character(utils::packageVersion("vegan")))
      printed = c(printed, paste(design, "—", test), capture.output(print(a)), "")
    }
  }
  anova_results = dplyr::bind_rows(tests)
  write(anova_results, "cca_anova_full")
  valid = anova_results |> dplyr::filter(!is.na(p_value))
  overview = valid |> dplyr::filter(design == "Unrestricted", test != "Climate variable") |>
    dplyr::select(test, component, df, inertia, pseudo_F, p_unrestricted = p_value) |>
    dplyr::left_join(valid |> dplyr::filter(design == "Within parks") |>
      dplyr::select(test, component, p_within_parks = p_value), by = c("test", "component"))
  write(overview, "cca_anova")
  total = fit$CCA$tot.chi
  sp = vegan::inertcomp(fit, display = "species")
  species_scores = vegan::scores(fit, display = "species", choices = 1:2,
    scaling = e$cca_scaling, hill = e$cca_hill)
  species = data.frame(species = rownames(sp),
    legacy_plots = as.numeric(colSums(e$species_past_final)[rownames(sp)]),
    constrained_inertia = sp[, "CCA"], percent_constrained_inertia = 100 * sp[, "CCA"] / total,
    CCA1 = species_scores[rownames(sp), 1], CCA2 = species_scores[rownames(sp), 2]) |>
    dplyr::mutate(prevalence_percent = 100 * legacy_plots / nrow(e$species_past_final)) |>
    dplyr::arrange(dplyr::desc(percent_constrained_inertia))
  stopifnot(abs(sum(species$constrained_inertia) - total) < 1e-12)
  write(species, "cca_species_contributions")
  bp = vegan::scores(fit, display = "bp", choices = 1:2,
    scaling = e$cca_scaling, hill = e$cca_hill)
  vif = vegan::vif.cca(fit)
  climate = valid |> dplyr::filter(design == "Unrestricted", test == "Climate variable") |>
    dplyr::transmute(variable = component,
      variable_label = unname(e$CLIMATE_VARIABLE_LABELS[variable]), df,
      marginal_inertia = inertia, unique_percent_constrained = 100 * inertia / total,
      pseudo_F, p_unrestricted = p_value) |>
    dplyr::left_join(valid |> dplyr::filter(design == "Within parks", test == "Climate variable") |>
      dplyr::select(variable = component, p_within_parks = p_value), by = "variable") |>
    dplyr::mutate(VIF = unname(vif[variable]), CCA1 = bp[variable, 1], CCA2 = bp[variable, 2])
  stopifnot(nrow(climate) == length(e$CCA_VARIABLES), !anyNA(climate))
  write(climate, "cca_climate_contributions")

  # Copy the fitting/projection statements from the active script verbatim.
  source = readLines(here::here("R/stages/04_cca_model.R"), warn = FALSE)
  extract = function(start, lines = 1L) {
    pos = which(startsWith(source, start))
    if (length(pos) != 1L) stop("Cannot identify CCA code statement: ", start)
    source[seq.int(pos, length.out = lines)]
  }
  value = function(x) paste(capture.output(dput(x)), collapse = "")
  code = c("# Current settings; presence and climate tables are prepared above in 04_cca_model.R.",
    paste0("CCA_VARIABLES = ", value(e$CCA_VARIABLES)),
    paste0("cca_scaling = ", value(e$cca_scaling)), paste0("cca_hill = ", value(e$cca_hill)),
    "", "# Matched legacy observations used to calibrate the CCA.",
    extract("species_past_final = "), extract("env_past_final = "), "",
    extract("cca_formula = "), extract("cca_model = "), "",
    "# Resurvey positions: climate-predicted (LC) and observed (WA).",
    extract("predicted_present = "), extract("projected_present = ", 2L))
  writeLines(code, here::here("output/report/cca_model_code.R"))
  writeLines(capture.output(print(fit)), here::here("output/report/cca_model_output.txt"))
  writeLines(printed, here::here("output/report/cca_anova_output.txt"))
}
report_export_cca = function(model_env) {
  # Read the current fit and its prepared tables; no alternate calibration.
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
  write(readr::read_csv(here::here("data/MORA/resurvey_year_source_discrepancies.csv"),
    show_col_types = FALSE), "year_source_discrepancies")
  visits = readr::read_csv(here::here("output/MORA_resurvey_visit_audit.csv"), show_col_types = FALSE)
  mapping = readr::read_csv(here::here("data/MORA/resurvey_seedling_visit_mapping.csv"), show_col_types = FALSE)
  write(mapping, "seedling_visit_mapping")
  repeat_visits = visits |> dplyr::filter(stage == "adult") |>
    dplyr::group_by(Plot_ID, plot_id) |> dplyr::filter(dplyr::n_distinct(assigned_year) > 1L) |>
    dplyr::summarise(adult_years = paste(sort(unique(assigned_year)), collapse = "; "),
      selected_year = unique(selected_year), adults_kept = sum(records[selected]),
      adults_discarded = sum(records[!selected]), .groups = "drop") |>
    dplyr::left_join(mapping |> dplyr::filter(adult_year == ave(adult_year, Plot_ID, FUN = max)) |>
      dplyr::distinct(Plot_ID, selected_year = adult_year, visit_date, evidence),
      by = c("Plot_ID", "selected_year"))
  if (nrow(repeat_visits) != 13L || anyNA(repeat_visits$visit_date))
    stop("The 13 repeat MORA plots require documented latest adult visits.")
  write(repeat_visits, "mora_repeat_visits")
  cleaning = lapply(c("MORA", "NOCA", "paleo"), function(name) {
    x = readr::read_csv(here::here("output", paste0(name, "_occ.csv")), show_col_types = FALSE)
    data.frame(source = name, rows = nrow(x), plot_or_sample_ids = dplyr::n_distinct(x$plot_id), taxa = dplyr::n_distinct(x$species))
  })
  x = readr::read_csv(here::here("output/occ_consolidated.csv"), show_col_types = FALSE)
  write(dplyr::bind_rows(cleaning, data.frame(source = "consolidated", rows = nrow(x), plot_or_sample_ids = dplyr::n_distinct(x$plot_id), taxa = dplyr::n_distinct(x$species))), "cleaning_summary")
  report_cca_details(e)
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
