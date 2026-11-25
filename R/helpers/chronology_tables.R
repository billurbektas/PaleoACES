# =============================================================================
# chronology_tables.R - supplementary Tables S2 and S3 (age-depth models)
# =============================================================================
# Builds the two Appendix S1 tables from what Bacon actually used, so the
# manuscript cannot drift from the models:
#   Table S2  chronological controls  <- Cores/<core>/<core>.csv (Bacon inputs)
#   Table S3  rbacon parameters       <- Cores/<core>/<core>_settings.txt and
#                                          CORE_ARGS (R/helpers/bacon_settings.R)
# Every number comes from those files. Only the descriptive wording (control
# names, sources, how each uncertainty was obtained) lives here, keyed by the
# Bacon control ID; any error value quoted in that wording is filled in from the
# control file. A control without wording, or wording without a control, stops.
#
# Reads only; writes only via write_chronology_tables(). Called by
# R/pipeline/06_paleo_samples.R; checked by R/tests/test_chronology_tables.R.
# =============================================================================
source(here::here('R/helpers/config.R'), local = TRUE)
source(here::here("R/helpers/bacon_settings.R"), local = TRUE)

CHRONOLOGY_TABLE_CORES = c(JayBath = "Jay Bath", LogWallow = "Log Wallow",
  ReflectionPond = "Reflection Pond", PantherPotholes = "Panther Potholes")
CHRONOLOGY_TABLE_SITES = c(JayBath = "MORA", LogWallow = "MORA",
  ReflectionPond = "MORA", PantherPotholes = "NOCA")
CHRONOLOGY_TABLE_PATHS = c(
  controls = "table_S1_1_chronological_controls.csv",
  parameters = "table_S1_2_rbacon_parameters.csv")

# Wording per Bacon control ID. `group` is MORA (shared by its three cores) or
# NOCA. "{error}" is replaced by the error entered in the Bacon control file.
# Radiocarbon rows (cc = 1) of MORA share one entry and keep their lab number.
chronology_control_wording = function() tibble::tribble(
  ~group, ~id,               ~control,                              ~age_source,                                        ~uncertainty_source,
  "MORA", "Surface",         "Core surface",                        "Coring date, 1981–1982",                      "Assumed ±{error} yr to account for uncertainty in recovery of the sediment–water interface",
  "MORA", "Tephra_W",        "MSH-W tephra",                        "Yamaguchi 1983; Walsh et al. 2017",                "Assumed ±{error} yr around the tree-ring-dated eruption age; no published statistical age error",
  "MORA", "Tephra_C",        "MR-C tephra",                         "Mullineaux 1974; Walsh et al. 2017",               "Assumed ±{error} yr; no published statistical age error",
  "MORA", "Tephra_Y",        "MSH-Y tephra, upper boundary",        "Mullineaux 1974; Walsh et al. 2017",               "±{error} yr derived approximately from radiocarbon dates bracketing the eruption age (bracket half-width ≈103 yr; Mullineaux 1996)",
  "MORA", "Tephra_Y_alt",    "MSH-Y tephra, lower boundary",        "Mullineaux 1974; Walsh et al. 2017",               "Same uncertainty as upper boundary; both depths represent the same instantaneous tephra deposit",
  "MORA", "Tephra_F",        "MR-F tephra",                         "Mullineaux 1974; Walsh et al. 2017",               "Assumed ±{error} yr; no published statistical age error",
  "MORA", "Basal_date_mean", "Basal sediment, mean of QL-1704 and QL-1728", "Dunwiddie 1986; P. Dunwiddie, pers. comm.",   "Larger of the two laboratory errors (±{error} yr), allowing for transfer of the Jay Bath and Log Wallow basal age to Reflection Pond",
  "MORA", "<radiocarbon>",   "{id}",                                "Dunwiddie 1986",                                   "Published laboratory error",
  "NOCA", "CoreTop",         "Core surface",                        "Gavin 2021 Neotoma chronology; coring year 1999",  "±{error} yr retained from the archived chronology",
  "NOCA", "Pb210_7",         "²¹⁰Pb CRS age",        "Prichard et al. 2009; Gavin 2021",                 "Value of the archived chronology; {error} is numerically the published ²¹⁰Pb activity uncertainty in DPM g⁻¹, not a verified age error in years",
  "NOCA", "Pb210_14",        "²¹⁰Pb CRS age",        "Prichard et al. 2009; Gavin 2021",                 "Value of the archived chronology; {error} is numerically the published ²¹⁰Pb activity uncertainty in DPM g⁻¹, not a verified age error in years",
  "NOCA", "Pb210_21",        "²¹⁰Pb CRS age",        "Prichard et al. 2009; Gavin 2021",                 "Value of the archived chronology; {error} is numerically the published ²¹⁰Pb activity uncertainty in DPM g⁻¹, not a verified age error in years",
  "NOCA", "Pb210_28",        "²¹⁰Pb CRS age",        "Prichard et al. 2009; Gavin 2021",                 "Value of the archived chronology; {error} is numerically the published ²¹⁰Pb activity uncertainty in DPM g⁻¹, not a verified age error in years",
  "NOCA", "Pb210_35",        "²¹⁰Pb CRS age",        "Prichard et al. 2009; Gavin 2021",                 "Value of the archived chronology; {error} is numerically the published ²¹⁰Pb activity uncertainty in DPM g⁻¹, not a verified age error in years",
  "NOCA", "Beta-172005",     "Beta-172005, conifer seed",           "Prichard et al. 2009",                             "Published laboratory error",
  "NOCA", "Tephra_MSH_P",    "MSH-P tephra",                        "Gavin 2021 Neotoma chronology",                    "Age and ±{error}-yr uncertainty retained from the archived chronology",
  "NOCA", "Beta-169623",     "Beta-169623, seed",                   "Prichard et al. 2009",                             "Published laboratory error",
  "NOCA", "Beta-169624",     "Beta-169624, pollen cone",            "Prichard et al. 2009",                             "Published laboratory error",
  "NOCA", "Tephra_MSH_Y",    "MSH-Y tephra",                        "Gavin 2021 Neotoma chronology",                    "Age and ±{error}-yr uncertainty retained from the archived chronology",
  "NOCA", "Beta-169207",     "Beta-169207, pollen cone",            "Prichard et al. 2009",                             "Published laboratory error",
  "NOCA", "Tephra_Mazama",   "Mazama tephra",                       "Gavin 2021 Neotoma chronology; Egan et al. 2015",  "Age and ±{error}-yr uncertainty retained from the archived chronology",
  "NOCA", "Beta-169208",     "Beta-169208, seed",                   "Prichard et al. 2009",                             "Published laboratory error",
  "NOCA", "Beta-169625",     "Beta-169625, Pinus contorta needles", "Prichard et al. 2009",                             "Published laboratory error")

# A control uses its own wording when it has one; any other MORA radiocarbon
# date (cc = 1) uses the shared Dunwiddie lab-date wording.
chronology_wording_key = function(x, group, ids)
  ifelse(x$ID %in% ids, x$ID, ifelse(group == "MORA" & x$cc == 1, "<radiocarbon>", x$ID))

# Numbers as printed in the manuscript: shortest form, typographic minus.
chronology_number = function(x) gsub("-", "−", format(x, trim = TRUE,
  drop0trailing = TRUE, scientific = FALSE, big.mark = ""), fixed = TRUE)
chronology_fill = function(template, id, error)
  gsub("{id}", id, gsub("{error}", error, template, fixed = TRUE), fixed = TRUE)

# A Bacon _settings.txt as a named character vector ("value #name" per line).
# hiatus.max appears twice in rbacon's file; the first occurrence is kept.
read_bacon_settings_file = function(core) {
  lines = readLines(here::here("Cores", core, paste0(core, "_settings.txt")), warn = FALSE)
  value = trimws(sub("#.*$", "", lines))
  name = trimws(sub("^[^#]*#", "", lines))
  keep = !duplicated(name)
  stats::setNames(value[keep], name[keep])
}

# A core's Bacon dates file. rbacon 4 rewrites it with the header
# labID,age,error,depth,cc when it runs (rbacon 3 kept ID,Age,Error,Depth,cc);
# the values are unchanged, so both headers read the same.
read_bacon_controls = function(core) {
  x = readr::read_csv(here::here("Cores", core, paste0(core, ".csv")), col_types = "cdddd")
  rbacon4 = c(labID = "ID", age = "Age", error = "Error", depth = "Depth")
  names(x) = ifelse(names(x) %in% names(rbacon4), rbacon4[names(x)], names(x))
  # Rule: the five Bacon control columns, in Bacon's order.
  stopifnot(identical(names(x), c("ID", "Age", "Error", "Depth", "cc")))
  x
}

chronology_controls_table = function(cores = names(CHRONOLOGY_TABLE_CORES)) {
  wording = chronology_control_wording()
  rows = lapply(cores, function(core) {
    x = read_bacon_controls(core)
    settings = read_bacon_settings_file(core)
    group = CHRONOLOGY_TABLE_SITES[[core]]
    w = wording[wording$group == group, ]
    key = chronology_wording_key(x, group, w$id)
    unmatched = setdiff(key, w$id)
    if (length(unmatched)) stop("Table S2 has no wording for ", core, " control(s): ",
      paste(unmatched, collapse = ", "), ". Add them to chronology_control_wording().")
    w = w[match(key, w$id), ]
    error = chronology_number(x$Error)
    lead210 = startsWith(x$ID, "Pb210_")
    age = ifelse(lead210, paste0(chronology_number(x$Age), "; error entered = ", error),
      paste0(chronology_number(x$Age), " ± ", error,
        ifelse(x$cc == 1, " ¹⁴C yr BP", " cal yr BP")))
    tibble::tibble(
      Site = group, Core = CHRONOLOGY_TABLE_CORES[[core]],
      `Chronological control` = mapply(chronology_fill, w$control, x$ID, error, USE.NAMES = FALSE),
      `Depth (cm)` = chronology_number(x$Depth),
      `Age entered ± error` = age,
      `Bacon treatment` = ifelse(x$cc == 1, paste0("cc = 1, ", settings[["cc1"]]), "cc = 0"),
      `Age source` = w$age_source,
      `Uncertainty source` = mapply(chronology_fill, w$uncertainty_source, x$ID, error, USE.NAMES = FALSE),
      depth_sort = x$Depth)
  })
  out = dplyr::bind_rows(rows)
  out = out[order(match(out$Core, CHRONOLOGY_TABLE_CORES), out$depth_sort), ]
  out$depth_sort = NULL
  # Wording for IDs that no longer exist in any control file is stale.
  used = unique(unlist(lapply(cores, function(core) {
    x = read_bacon_controls(core)
    group = CHRONOLOGY_TABLE_SITES[[core]]
    chronology_wording_key(x, group, wording$id[wording$group == group])
  })))
  stale = setdiff(wording$id, used)
  if (length(stale)) stop("Table S2 wording without a Bacon control: ", paste(stale, collapse = ", "))
  out
}

# Values Bacon ran with: the stored _settings.txt where rbacon records the
# argument, otherwise CORE_ARGS, otherwise the installed rbacon default.
bacon_run_value = function(core, name) {
  settings = read_bacon_settings_file(core)
  if (name %in% names(settings)) return(settings[[name]])
  if (!is.null(CORE_ARGS[[core]][[name]])) return(as.character(CORE_ARGS[[core]][[name]]))
  as.character(formals(rbacon::Bacon)[[name]])
}
bacon_shared_value = function(cores, name) {
  v = unique(vapply(cores, bacon_run_value, character(1), name = name))
  if (length(v) != 1L) stop("MORA cores differ in ", name, "; Table S3 assumes one value")
  v
}

bacon_parameters_table = function() {
  mora = c("JayBath", "LogWallow", "ReflectionPond"); pp = "PantherPotholes"
  num = function(x) format(as.numeric(x), big.mark = ",", trim = TRUE, scientific = FALSE)
  pair = function(core, a, b) paste(CORE_ARGS[[core]]$slump[c(a, b)], collapse = "–")
  shared = function(name) bacon_shared_value(mora, name)
  cc1_mora = shared("cc1")
  normal_t = function(cores) paste(if (bacon_shared_value(cores, "normal") == "0") "FALSE" else "TRUE",
    bacon_shared_value(cores, "t.a"), bacon_shared_value(cores, "t.b"), sep = ", ")
  pp_slump = CORE_ARGS[[pp]]$slump
  pp_pairs = vapply(seq(1, length(pp_slump), 2), function(i) paste(pp_slump[i:(i + 1)], collapse = "–"), character(1))
  manual_dmax = mora[vapply(mora, function(core) !is.null(CORE_ARGS[[core]]$d.max), logical(1))]
  auto_dmax = setdiff(mora, manual_dmax)
  # Rule: every MORA value that the Rationale column calls the rbacon default is
  # the default of the installed rbacon.
  defaults = c("thick", "acc.shape", "mem.mean", "mem.strength", "normal", "t.a", "t.b", "ssize")
  is_default = vapply(defaults, function(name) {
    d = formals(rbacon::Bacon)[[name]]
    v = shared(name)
    if (is.logical(d)) as.logical(as.numeric(v)) == d else as.numeric(v) == as.numeric(d)
  }, logical(1))
  if (!all(is_default)) stop("Table S3 calls these MORA values the rbacon default, but they are not: ",
    paste(defaults[!is_default], collapse = ", "))
  archived = "the value of the archived chronology"
  d_max_mora = paste0(paste0(CHRONOLOGY_TABLE_CORES[manual_dmax], ": ",
      vapply(manual_dmax, function(core) CORE_ARGS[[core]]$d.max, numeric(1)), " cm", collapse = "; "),
    if (length(auto_dmax)) paste0("; no manual extension for ",
      paste(CHRONOLOGY_TABLE_CORES[auto_dmax], collapse = " or ")) else "")
  tibble::tribble(
    ~`rbacon argument`, ~`What it controls`, ~MORA, ~`Panther Potholes`, ~Rationale,
    "cc, cc1", "Determines whether a date requires radiocarbon calibration and which calibration curve is used",
      paste0("cc=1, cc1=\"", cc1_mora, "\" for ¹⁴C dates; cc=0 for calendar-age controls"),
      if (bacon_run_value(pp, "cc1") == cc1_mora) "Same" else paste0("cc1=\"", bacon_run_value(pp, "cc1"), "\""),
      paste0("We calibrated the ¹⁴C dates with ", cc1_mora, ", the curve for Northern Hemisphere terrestrial samples, ",
        "and entered the other controls as calendar ages."),
    "thick", "Thickness of the sediment sections for which accumulation rates are estimated",
      paste(shared("thick"), "cm"), paste(bacon_run_value(pp, "thick"), "cm"),
      paste0("rbacon default; at Panther Potholes, also ", archived, "."),
    "acc.mean", "Mean of the prior distribution for accumulation time, in yr cm⁻¹",
      shared("acc.mean"), bacon_run_value(pp, "acc.mean"),
      paste0("The MORA cores accumulated more slowly. At Panther Potholes, ", archived,
        ", close to the accumulation of about 12.8 yr cm⁻¹ reported for this core."),
    "acc.shape", "Shape of the gamma prior around acc.mean; larger values impose a more concentrated accumulation prior",
      shared("acc.shape"), bacon_run_value(pp, "acc.shape"),
      paste0("rbacon default (MORA); ", sub("^the ", "", archived), " (Panther Potholes)."),
    "mem.mean", "Prior mean dependence between accumulation rates in adjacent sediment sections",
      shared("mem.mean"), bacon_run_value(pp, "mem.mean"),
      paste0("rbacon default (MORA); ", sub("^the ", "", archived), " (Panther Potholes)."),
    "mem.strength", "Strength of the prior around mem.mean; larger values impose the assumed memory more strongly",
      shared("mem.strength"), bacon_run_value(pp, "mem.strength"),
      paste0("rbacon default (MORA); ", sub("^the ", "", archived), " (Panther Potholes)."),
    "slump", "Depth intervals treated as effectively instantaneous accumulation rather than gradual sedimentation",
      paste(paste0(CHRONOLOGY_TABLE_CORES[mora], ": ", vapply(mora, pair, character(1), a = 1, b = 2), " cm"), collapse = "; "),
      paste0(paste(utils::head(pp_pairs, -1), collapse = ", "), ", and ", utils::tail(pp_pairs, 1), " cm"),
      "Treats each thick tephra layer as one instantaneous deposit, so that the model does not read its thickness as a long period of accumulation.",
    "normal, t.a, t.b", "Distribution used to accommodate chronological-control scatter and potential outlying dates",
      normal_t(mora), normal_t(pp),
      paste0("rbacon default (MORA); ", sub("^the ", "", archived), " (Panther Potholes)."),
    "ssize", "Number of MCMC iterations retained for the posterior",
      num(shared("ssize")), num(bacon_run_value(pp, "ssize")),
      "rbacon default (MORA). Panther Potholes needed more iterations for the chain to mix and to reproduce the archived chronology.",
    "prob", "Posterior interval reported for the chronology",
      shared("prob"), bacon_run_value(pp, "prob"),
      paste0("We summarize ages with ", 100 * as.numeric(shared("prob")), "% posterior intervals."),
    "d.max", "Maximum core depth included in the model",
      d_max_mora, paste(bacon_run_value(pp, "d.max"), "cm"),
      paste0("We extended Jay Bath to ", CORE_ARGS$JayBath$d.max, " cm to keep its deepest macrofossil sample. ",
        "At Panther Potholes, the extent of the archived chronology."))
}

write_chronology_tables = function() {
  readr::write_csv(chronology_controls_table(), out(CHRONOLOGY_TABLE_PATHS[["controls"]]))
  readr::write_csv(bacon_parameters_table(), out(CHRONOLOGY_TABLE_PATHS[["parameters"]]))
  invisible(out(CHRONOLOGY_TABLE_PATHS))
}
