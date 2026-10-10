# Offline documentation gate: local links, complete companions, and source hashes.
suppressPackageStartupMessages({library(here); library(stringr)})
source(here("R/helpers/documentation_config.R"), local = TRUE)

failures = character(0)
fail = function(x) failures <<- c(failures, x)

extract_links = function(text) {
  matches = str_match_all(text, "\\[[^]]+\\]\\(([^)]+)\\)")
  unique(unlist(lapply(matches, function(x) if (nrow(x)) x[, 2] else character())))
}

extract_inline_paths = function(text) {
  matches = str_match_all(text, "`([^`\\n]+)`")
  paths = unique(unlist(lapply(matches, function(x) if (nrow(x)) x[, 2] else character())))
  paths[str_detect(paths, "^(R|output|plot|data|Cores)/") &
          str_detect(paths, "\\.(R|csv|pdf|png|rda|xlsx|json|md)$") &
          !str_detect(paths, "[\\*\\{\\},[:space:]]")]
}

docs_to_check = PALEOACES_DOCS
report_pending = isTRUE(getOption("paleoaces.report_pending", FALSE))
pending_tables = character()
if (report_pending) {
  registry = jsonlite::fromJSON(here("docs/report/artifacts.json"), simplifyVector = FALSE)
  pending_tables = normalizePath(here("docs/assets/analysis/tables",
    paste0(names(registry$tables), ".csv")), mustWork = FALSE)
}
# During a report rebuild the new report is validated in staging before publication.
# Its prior assets may have been deliberately removed; all other documentation
# still passes this prepublication gate. The workflow checks every pair afterward.
if (isTRUE(getOption("paleoaces.report_pending", FALSE)))
  docs_to_check = setdiff(docs_to_check, "docs/ANALYSIS_REVIEW.md")
for (rel in docs_to_check) {
  src = here(rel)
  html = sub("\\.md$", ".html", src)
  if (!file.exists(src)) { fail(paste("missing Markdown", rel)); next }
  if (!file.exists(html)) { fail(paste("missing HTML companion", sub("\\.md$", ".html", rel))); next }

  html_text = paste(readLines(html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expected_hash = unname(tools::md5sum(src))
  if (!str_detect(html_text, fixed(paste0("paleoaces-source-md5: ", expected_hash))))
    fail(paste("stale HTML companion", rel))
  if (str_detect(html_text, 'href="(?!https?://|mailto:)[^"]+\\.md([#?][^"]*)?"'))
    fail(paste("HTML link was not adjusted from .md", rel))

  md = readLines(src, warn = FALSE, encoding = "UTF-8")
  for (target in extract_links(md)) {
    target = sub("[[:space:]]+['\"].*$", "", target)
    target = sub("^<|>$", "", target)
    if (grepl("^(https?://|mailto:|#)", target)) next
    target = sub("#.*$", "", target)
    if (!nzchar(target)) next
    resolved = normalizePath(file.path(dirname(src), target), mustWork = FALSE)
    # For a not-yet-generated file, normalize its existing parent as well;
    # normalizePath(..., mustWork=FALSE) alone can leave a literal data/../docs.
    resolved = file.path(normalizePath(dirname(resolved), mustWork = FALSE), basename(resolved))
    # Registered report tables are validated in staging and checked again after
    # publication. This permits rebuilding a deliberately removed derived CSV.
    if (!file.exists(resolved) && !resolved %in% pending_tables)
      fail(paste(rel, "has broken local link", target))
  }

  for (target in extract_inline_paths(md)) {
    if (!file.exists(here(target)))
      fail(paste(rel, "names missing project path", target))
  }
}

# The landing page and workflow reach the complete maintained index.
index_text = readLines(here("docs/INDEX.md"), warn = FALSE)
index_targets = extract_links(index_text)
index_paths = unique(vapply(index_targets, function(x)
  normalizePath(file.path(here("docs"), x), mustWork = FALSE), character(1)))
required = setdiff(PALEOACES_DOCS, "docs/INDEX.md")
absent = required[!normalizePath(here(required), mustWork = FALSE) %in% index_paths]
if (length(absent)) fail(paste("Documentation index does not link", paste(absent, collapse = ", ")))
for (index in c("README.md", "docs/WORKFLOW.md")) {
  targets = extract_links(readLines(here(index), warn = FALSE))
  resolved = vapply(targets, function(x)
    normalizePath(file.path(dirname(here(index)), x), mustWork = FALSE), character(1))
  if (!normalizePath(here("docs/INDEX.md")) %in% resolved)
    fail(paste(index, "does not link the documentation index"))
}

decisions_text = paste(readLines(here("docs/SCIENTIFIC_DECISIONS.md"), warn = FALSE,
                                 encoding = "UTF-8"), collapse = "\n")
remaining_questions = c(
  "## Remaining scientific questions",
  "Raw versus V2.1-anchored TraCE21k climate",
  "Legacy-calibration versus full-record climate SDs",
  "Anthropocene precipitation continuity",
  "CARI449",
  "CARI450",
  "Own-origin versus common-origin taxon target geometry"
)
if (!all(vapply(remaining_questions,
                function(x) str_detect(decisions_text, fixed(x)), logical(1))))
  fail("docs/SCIENTIFIC_DECISIONS.md lacks the complete remaining-questions register")
if (str_locate(decisions_text, fixed("## Remaining scientific questions"))[1] >
    str_locate(decisions_text, fixed("## Inference limits"))[1])
  fail("Remaining scientific questions must precede inference limits")

active_text = paste(unlist(lapply(here(PALEOACES_AUTHORITY_DOCS), readLines,
                                  warn = FALSE, encoding = "UTF-8")), collapse = "\n")
banned = c(
  "R/000_PALEO_cleaning.R",
  "NOCA Neotoma pollen",
  "unresolved_stems",
  "one unresolved stem",
  "1,806 rows",
  "all 640 plots",
  "ClimateNA",
  "2,800 cal BP",
  "shared-break",
  "shared multivariate piecewise",
  "`C1`",
  "11_holocene_regime_detection.R",
  "11a_holocene_climate_500yr_trends.R",
  "11b_holocene_climate_shift_thresholds.R",
  "12_holocene_regime_correspondence.R",
  "holocene_regime_functions.R",
  "fig_holocene_regime_detection",
  "fig_holocene_climate_500yr_trends",
  "fig_holocene_climate_shift_thresholds",
  "fig_holocene_regime_literature_correspondence",
  "lake–500-year-interval",
  "R/10_holocene_period_diagnostics.R",
  "R/11_holocene_climate_periods_1000yr.R",
  "R/13_holocene_climate_fire_correspondence.R",
  "R/holocene_period_functions.R",
  "fig_holocene_period_diagnostics",
  "fig_holocene_climate_periods_1000yr",
  "fig_holocene_1000yr_climate_fire_correspondence",
  "site-divergent",
  "25%-of-maximum",
  "25% of that variable",
  "post hoc correspondence stage",
  "fig_holocene_climate_fire_eras",
  "table_holocene_anthropocene_raw_climate_rates",
  "R/09d_tracking_storyline_raw.R",
  "fig_tracking_storyline_raw",
  "cca_tracking_storyline_raw_spec.csv",
  "cca_tracking_storyline_display_audit.csv",
  "R/09c_tracking_metric_boxplots.R",
  "R/09d_tracking_storyline_summary.R",
  "fig_tracking_metric_boxplots",
  "fig_tracking_storyline_summary",
  "cca_tracking_boxplot_summary.csv",
  "cca_tracking_holocene_fire_context.csv",
  "cca_tracking_storyline_summary.csv",
  "cca_tracking_storyline_summary_spec.csv",
  "Change in endpoint lag",
  "tapas result is retained as a software-method sensitivity only",
  "MORA uses official CharAnalysis",
  "five-page all-core explanation",
  "14 numbered-era medians"
)
present = banned[vapply(banned, function(x) grepl(x, active_text, fixed = TRUE), logical(1))]
if (length(present)) fail(paste("stale active terminology:", paste(present, collapse = ", ")))

# Active script comments must point to maintained authorities, rather than
# retired assistant planning documents.
active_scripts = list.files(here("R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
active_scripts = active_scripts[!grepl("/(archive|vendor)/", active_scripts)]
script_comments = lapply(active_scripts, function(path) {
  grep("^[[:space:]]*#", readLines(path, warn = FALSE, encoding = "UTF-8"),
       value = TRUE)
})
stale_script_refs = vapply(script_comments, function(comments) {
  any(grepl("CLAUDE\\.md", comments))
}, logical(1))
if (any(stale_script_refs))
  fail(paste("active script comments cite retired assistant plan:",
             paste(basename(active_scripts[stale_script_refs]), collapse = ", ")))

stale_action_phrases = c(
  "planned quantities",
  "planned descriptive group",
  "# Check:",
  "# To take out",
  "README section 8"
)
all_active_comments = unlist(script_comments)
present_action_phrases = stale_action_phrases[
  vapply(stale_action_phrases,
         function(x) any(grepl(x, all_active_comments, fixed = TRUE)), logical(1))]
if (length(present_action_phrases))
  fail(paste("stale active-script action/reference comments:",
             paste(present_action_phrases, collapse = ", ")))

for (i in seq_along(active_scripts)) {
  comment_paths = unique(unlist(str_extract_all(script_comments[[i]], "R/[A-Za-z0-9_./-]+\\.R")))
  missing = comment_paths[!file.exists(here(comment_paths))]
  if (length(missing)) fail(paste(basename(active_scripts[i]), "names missing R paths:", paste(missing, collapse = ", ")))
}

if (length(failures)) {
  cat("Documentation failures:\n- ", paste(unique(failures), collapse = "\n- "), "\n", sep = "")
  quit(save = "no", status = 1)
}
cat("Documentation checks passed for ", length(docs_to_check),
    " maintained Markdown/HTML pairs.\n", sep = "")
