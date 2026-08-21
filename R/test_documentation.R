# Offline documentation gate: local links, complete companions, and source hashes.
suppressPackageStartupMessages({library(here); library(stringr)})
source(here("R/documentation_config.R"))

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

for (rel in PALEOACES_DOCS) {
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
    if (!file.exists(resolved)) fail(paste(rel, "has broken local link", target))
  }

  for (target in extract_inline_paths(md)) {
    if (!file.exists(here(target)))
      fail(paste(rel, "names missing project path", target))
  }
}

# Both navigation authorities must connect every maintained method/provenance doc.
for (index in c("README.md", "WORKFLOW.md")) {
  text = paste(readLines(here(index), warn = FALSE), collapse = "\n")
  required = setdiff(PALEOACES_DOCS, c("README.md", "WORKFLOW.md"))
  absent = required[!vapply(required, function(x) grepl(x, text, fixed = TRUE), logical(1))]
  if (length(absent)) fail(paste(index, "does not link", paste(absent, collapse = ", ")))
}

# The publication-caption document has one method summary, image, and formal
# caption for each empirical figure, ordered after conceptual Figure 1.
caption_path = here("FIGURE_CAPTIONS.md")
if (file.exists(caption_path)) {
  caption_text = paste(readLines(caption_path, warn = FALSE,
                                 encoding = "UTF-8"), collapse = "\n")
  caption_flat = str_squish(caption_text)
  heading_matches = str_match_all(
    caption_text, regex("^## Figure ([2-5]) —", multiline = TRUE))[[1]]
  if (!identical(heading_matches[, 2], as.character(2:5)))
    fail("FIGURE_CAPTIONS.md does not order Figures 2-5 exactly once")
  if (str_count(caption_text, fixed("**Method summary.**")) != 4L)
    fail("FIGURE_CAPTIONS.md must contain four separate method summaries")
  if (str_count(caption_text,
                fixed("**Publication-ready caption.**")) != 4L)
    fail("FIGURE_CAPTIONS.md must contain four publication-ready captions")
  if (str_count(caption_text, "!\\[Figure [2-5]\\.") != 4L)
    fail("FIGURE_CAPTIONS.md must embed four figure previews")
  expected_pdfs = c(
    "plot/fig_standardized_climate_change_eras_fire.pdf",
    "plot/fig_cca_trajectories.pdf",
    "plot/fig_tracking_comparison.pdf",
    "plot/fig_cca_direction_differences.pdf")
  if (!all(vapply(expected_pdfs, function(x) str_detect(caption_text, fixed(x)),
                  logical(1))))
    fail("FIGURE_CAPTIONS.md does not link every publication PDF")
  figure2_contract = c(
    "1979–1989 with 2010–2019",
    "1979–1989 with 2010–2015",
    "30.5 midpoint years",
    "28.5 midpoint years",
    "annualized short-window contrasts",
    "maximum-absolute Holocene regional median",
    "post-2010 CHELSA inhomogeneity"
  )
  if (!all(vapply(figure2_contract, function(x) str_detect(caption_flat, fixed(x)),
                  logical(1))))
    fail("FIGURE_CAPTIONS.md lacks exact Figure 2 window/rate semantics")
  figure5_contract = c(
    "initial LC position to the fixed taxon",
    "initial WA position",
    "equal target-specific cosines",
    "less strongly opposed",
    "stronger observed target alignment"
  )
  if (!all(vapply(figure5_contract, function(x) str_detect(caption_flat, fixed(x)),
                  logical(1))))
    fail("FIGURE_CAPTIONS.md lacks the precise Figure 5 own-origin geometry")
}

decisions_text = paste(readLines(here("SCIENTIFIC_DECISIONS.md"), warn = FALSE,
                                 encoding = "UTF-8"), collapse = "\n")
remaining_questions = c(
  "## Remaining scientific questions",
  "Raw versus V2.1-anchored TraCE21k climate",
  "Legacy-calibration versus full-record climate SDs",
  "Anthropocene precipitation windows and CHELSA continuity",
  "Primary provenance for MORA survey dates",
  "CARI449",
  "CARI450",
  "Own-origin versus common-origin taxon target geometry"
)
if (!all(vapply(remaining_questions,
                function(x) str_detect(decisions_text, fixed(x)), logical(1))))
  fail("SCIENTIFIC_DECISIONS.md lacks the complete remaining-questions register")
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
  "cca_tracking_holocene_lake_",
  "lake–1,000-year-interval",
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

# Active script comments must point to maintained authorities, not numbered
# sections in the archived CLAUDE plan.
active_scripts = list.files(here("R"), pattern = "\\.R$", full.names = TRUE)
script_comments = lapply(active_scripts, function(path) {
  grep("^[[:space:]]*#", readLines(path, warn = FALSE, encoding = "UTF-8"),
       value = TRUE)
})
stale_script_refs = vapply(script_comments, function(comments) {
  any(grepl("CLAUDE\\.md", comments))
}, logical(1))
if (any(stale_script_refs))
  fail(paste("active script comments cite archived CLAUDE plan:",
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

comment_paths = unique(unlist(str_extract_all(
  all_active_comments, "R/[A-Za-z0-9_./-]+\\.R"
)))
missing_comment_paths = comment_paths[
  !vapply(comment_paths, function(x) file.exists(here(x)), logical(1))]
if (length(missing_comment_paths))
  fail(paste("active script comments name missing R paths:",
             paste(missing_comment_paths, collapse = ", ")))

if (length(failures)) {
  cat("Documentation failures:\n- ", paste(unique(failures), collapse = "\n- "), "\n", sep = "")
  quit(save = "no", status = 1)
}
cat("Documentation checks passed for ", length(PALEOACES_DOCS),
    " maintained Markdown/HTML pairs.\n", sep = "")
