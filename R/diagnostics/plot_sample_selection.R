# Show which plots and core samples reach CCA, starting with the supplied data.
# This reads preparation results; it does not change observations or fit a model.
suppressPackageStartupMessages({
  library(here); library(readr); library(readxl); library(dplyr)
  library(ggplot2); library(patchwork)
})
source(here("R/helpers/figure_style.R"), local = TRUE)
source(here("R/helpers/survey_years.R"), local = TRUE)
read_table = function(path) read_csv(here(path), show_col_types = FALSE)
unique_values = function(x) sort(unique(x[!is.na(x)]))
samples = read_table("output/cca_sample_eligibility.csv")
pairs = read_table("output/cca_pair_eligibility.csv")
prepared = read_plot_years()
original_records = bind_rows(
  read_table("output/MORA_occ.csv") |> mutate(site = "MORA"),
  read_table("output/NOCA_occ.csv") |> mutate(site = "NOCA"))
counts = list(); choices = list()
add_count = function(site, period, step, label, remaining, removed = 0L,
                     combined = 0L, explanation = "") {
  stopifnot(remaining >= 0, removed >= 0, combined >= 0)
  counts[[length(counts) + 1L]] <<- tibble(site, period, step, label,
    remaining = as.integer(remaining), removed = as.integer(removed),
    combined = as.integer(combined), explanation)
  remaining
}
add_choice = function(site, choice, number, unit, plots_removed, explanation) {
  choices[[length(choices) + 1L]] <<- tibble(site, choice, number = as.integer(number),
    unit, plots_removed = as.integer(plots_removed), explanation)
}
reason_count = function(x, code) sum(x$reason_code == code)
site_pairs = function(site_name) pairs |> filter(site == site_name)

# MORA: starting surveys are separate lists, connected by the plot-name table.
mora_library = read_table("data/MORA/MORA_plot_lib.csv")
legacy_veg = read_excel(here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx"),
  sheet = "Rainier Veg")
legacy_trees = read_excel(here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx"),
  sheet = "rawsizedata")
legacy_ids = union(unique_values(legacy_veg$Plotno), unique_values(legacy_trees$Plotno))
trees = read_table("data/MORA/MORA_TreeData_Resurvey_Cleaned.csv")
seeds = read_table("data/MORA/MORA_Seedlings_Resurvey_Cleaned.csv")
source_keys = function(x) ifelse(is.na(x$Plot_ID),
  paste0("unassigned:", normalize_mora_visit(x$Plot.ID)), as.character(x$Plot_ID))
resurvey_ids = union(unique_values(source_keys(trees)), unique_values(source_keys(seeds)))
matched_library = mora_library |> filter(Plotno %in% legacy_ids,
  as.character(Plot_ID) %in% resurvey_ids)
mora = site_pairs("MORA")
stopifnot(setequal(matched_library$plot_id, mora$plot_id),
  setequal(mora$plot_id, prepared$plot_id[prepared$site == "MORA"]))
mn = nrow(mora)
add_count("MORA", "Modern", 1, "Starting legacy plots", length(legacy_ids))
add_count("MORA", "Modern", 2, "Starting resurvey plots", length(resurvey_ids))
add_count("MORA", "Modern", 2.5, "Legacy plots with a matched resurvey", mn,
  length(legacy_ids) - mn)
add_count("MORA", "Modern", 3, "Matched legacy and resurvey plots", mn,
  length(resurvey_ids) - mn,
  explanation = sprintf("%d legacy plots and %d resurvey plots have no entry in the paired-plot list; the latter include the practice plot PRAC-1.",
    length(legacy_ids) - mn, length(resurvey_ids) - mn))
visit_rows = read_table("output/MORA_resurvey_record_audit.csv")
visits = read_table("output/MORA_resurvey_visit_audit.csv")
repeated = visits |> filter(stage == "adult") |> group_by(plot_id) |>
  summarise(years = n_distinct(assigned_year), .groups = "drop") |> filter(years > 1)
discarded_adults = sum(!visit_rows$selected & visit_rows$stage == "adult")
discarded_seedlings = sum(!visit_rows$selected & visit_rows$stage == "seedling")
add_count("MORA", "Modern", 4, "Keep the latest adult visit", mn,
  explanation = sprintf("%d plots have visits in multiple years; discard %d earlier adult records and %d earlier seedling records, without removing plots.",
    nrow(repeated), discarded_adults, discarded_seedlings))
add_choice("MORA", "Assign seedling dates from adult visits",
  sum(visit_rows$year_corrected), "seedling records", 0,
  "Correct years before selecting visits; supplied files are preserved.")
add_choice("MORA", "Keep the latest adult visit", nrow(repeated), "plots", 0,
  sprintf("Earlier records removed: %d adult and %d seedling records. Visits tied within the same year remain pooled.",
    discarded_adults, discarded_seedlings))
add_count("MORA", "Modern", 5, "Combine adults, seedlings and study tree species", mn,
  explanation = "No matched plot disappears when the two vegetation stages are combined or the species lists are aligned.")

# NOCA: reproduce the plot-list restrictions, then reconcile the source IDs
# with the cleaner's explicit reasons. Renamed records are not lost plots.
registered = read_table("data/NOCA/NOCA_plots_fromWilson.csv") |>
  transmute(plot_id = toupper(`2015.Plot.Name`), legacy_id = `1980.Plot.Name`,
    latitude = Latitude, longitude = Longitude)
stopifnot(!anyDuplicated(registered$plot_id))
noca_legacy = read_excel(here("data/NOCA/AGEEDATA_NEW.xlsx"), sheet = "TREE")
noca_legacy_ids = unique_values(noca_legacy$PLOT)
tracking = read_table("output/NOCA_plot_tracking.csv")
extra = registered$plot_id %in% c("SUPP2026", "ROSS4001REF", "SUPP5127")
regular = registered[!extra, ]
gps_removed = sum(is.na(regular$latitude))
located = regular |> filter(!is.na(latitude))
unsupported = unique_values(tracking$plot_id[tracking$reason == "no species recorded"])
supported = located |> filter(!plot_id %in% unsupported)
matched = supported |> filter(legacy_id %in% noca_legacy_ids)
empty_both = unique_values(tracking$plot_id[tracking$reason == "empty in both periods"])
study_removed = read_table("output/NOCA_study_exclusions.csv")
kept = setdiff(matched$plot_id, union(empty_both, study_removed$plot_id))
noca = site_pairs("NOCA")
stopifnot(setequal(kept, noca$plot_id),
  setequal(kept, prepared$plot_id[prepared$site == "NOCA"]),
  length(unsupported) == sum(located$plot_id %in% unsupported),
  all(empty_both %in% matched$plot_id), all(study_removed$plot_id %in% matched$plot_id))
nn = nrow(noca)
add_count("NOCA", "Modern", 1, "Starting legacy plots", length(noca_legacy_ids))
add_count("NOCA", "Modern", 2, "Starting registered resurvey plots", nrow(registered),
  explanation = "Wilson's plot list defines the starting resurvey plots; corrected tree names are applied to this list.")
add_count("NOCA", "Modern", 2.5, "Legacy plots with usable matched locations",
  n_distinct(matched$legacy_id), length(noca_legacy_ids) - n_distinct(matched$legacy_id))
add_count("NOCA", "Modern", 3, "Remove supplementary and reference plots", nrow(regular), sum(extra),
  explanation = paste(registered$plot_id[extra], collapse = "; "))
add_count("NOCA", "Modern", 4, "Require usable GPS coordinates", nrow(located), gps_removed)
add_count("NOCA", "Modern", 5, "Require usable tree identifications", nrow(supported), length(unsupported),
  explanation = "The two removed plots have only unsupported tree identifications.")
add_count("NOCA", "Modern", 6, "Match a legacy tree survey", nrow(matched), nrow(supported) - nrow(matched),
  explanation = sprintf("%d legacy plots also have no usable matched location. Counts for the two starting surveys must not be added.",
    length(noca_legacy_ids) - n_distinct(matched$legacy_id)))
add_count("NOCA", "Modern", 7, "Remove plots empty at both dates",
  nrow(matched) - length(empty_both), length(empty_both))
add_count("NOCA", "Modern", 8, "Apply the agreed plot exclusions", nn, nrow(study_removed),
  explanation = "One old clearcut, one uncertain resurvey location, and two unresolved GPS problems.")
corrected = read_table("output/NOCA_tree_correction_audit.csv")
clearcuts = sum(grepl("clearcut", study_removed$exclusion_reason, fixed = TRUE))
relocations = sum(grepl("location uncertain", study_removed$exclusion_reason, fixed = TRUE))
gps_problems = sum(grepl("GPS problem", study_removed$exclusion_reason, fixed = TRUE))
stopifnot(clearcuts + relocations + gps_problems == nrow(study_removed))
add_choice("NOCA", "Apply corrected tree records", nrow(corrected), "plots", 0,
  "Their exclusions, where applicable, are counted under GPS or missing legacy surveys; renaming and splitting source labels is not plot loss.")

# Apply the existing CCA reasons, checking legacy first so no pair is lost twice.
modern_info = list()
for (site_name in c("MORA", "NOCA")) {
  x = site_pairs(site_name)
  legacy = samples |> filter(site == site_name, period == "past")
  removed_legacy = x |> filter(!comparison_included, exclusion_period == "past")
  removed_resurvey = x |> filter(!comparison_included, exclusion_period == "present")
  stopifnot(setequal(legacy$plot_id, x$plot_id),
    identical(x$calibration_included, x$comparison_included),
    all(x$reason_code %in% c("included", "no_recorded_taxa", "consolidation",
      "species_selection", "no_calibration_taxa", "climate")))
  eligible_n = sum(legacy$eligible)
  fit_n = sum(x$calibration_included); paired_n = sum(x$comparison_included)
  stopifnot(nrow(x) - nrow(removed_legacy) == eligible_n,
    eligible_n - nrow(removed_resurvey) == paired_n, fit_n == paired_n)
  add_count(site_name, "Modern", 9, "Eligible legacy plots", eligible_n,
    nrow(removed_legacy), explanation = "Each legacy plot must contain a retained tree species and complete climate data.")
  add_count(site_name, "Modern", 10, "CCA calibration and comparisons at both dates", paired_n,
    nrow(removed_resurvey), explanation = "Fit the CCA on these matched legacy plots; use the same plots for observed and predicted positions at both dates.")
  add_choice(site_name, "Complete climate at both dates",
    sum(samples$site == site_name & samples$period != "paleo" & !samples$climate_complete),
    "incomplete observations", sum(x$reason_code == "climate"),
    "Missing climate excludes both observed and predicted positions; the current modern data have complete climate.")
  modern_info[[site_name]] = list(start = nrow(x), eligible = eligible_n, fit = fit_n, paired = paired_n,
    legacy = removed_legacy, resurvey = removed_resurvey)
}

# Plot areas describe the retained adult-tree surveys; they do not exclude plots.
# Use plot-level legacy metadata, rather than conflicting species-row entries.
# The author confirmed 500 m2 resurvey adult-tree plots at both sites on 2026-10-08.
mora_areas = read_excel(here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx"),
  sheet = "Site info") |> select(Plotno, legacy_area_m2 = Plotarea) |> distinct()
noca_areas = read_excel(here("data/NOCA/AGEEDATA_NEW.xlsx"), sheet = "OVERVIEW") |>
  select(legacy_id = PLOT, legacy_area_m2 = `PLOT(M2)`) |> distinct()
stopifnot(!anyDuplicated(mora_areas$Plotno), !anyDuplicated(noca_areas$legacy_id),
  !anyDuplicated(mora_library$plot_id))
retained_areas = bind_rows(
  mora |> filter(calibration_included) |> select(site, plot_id) |>
    left_join(mora_library |> select(plot_id, Plotno), by = "plot_id") |>
    left_join(mora_areas, by = "Plotno") |> select(site, plot_id, legacy_area_m2),
  noca |> filter(calibration_included) |> select(site, plot_id) |>
    left_join(registered |> select(plot_id, legacy_id), by = "plot_id") |>
    left_join(noca_areas, by = "legacy_id") |> select(site, plot_id, legacy_area_m2)) |>
  mutate(resurvey_area_m2 = 500)
stopifnot(nrow(retained_areas) == sum(pairs$calibration_included),
  !anyDuplicated(paste(retained_areas$site, retained_areas$plot_id)),
  all(is.na(retained_areas$legacy_area_m2) | retained_areas$legacy_area_m2 > 0))
plot_sizes = retained_areas |> count(site, legacy_area_m2, resurvey_area_m2, name = "plots")

# Core depths sharing one modeled age are combined, rather than excluded.
depths = read_table("output/paleo_sample_depths.csv")
raw_mora = read_excel(here("data/PALEO/DunwiddieMacrofossils.xlsx"), sheet = "MacrofossilData") |>
  distinct(Location, Depth)
raw_noca = read_table("data/NOCA/NOCA_paleo/dataset52207_site13042.csv")
noca_columns = setdiff(names(raw_noca), c("name", "group", "element", "units", "context"))
paleo_info = list()
for (site_name in c("MORA", "NOCA")) {
  d = depths |> filter(if (site_name == "MORA") lake != "PantherPotholes" else lake == "PantherPotholes")
  x = samples |> filter(site == site_name, period == "paleo")
  raw_n = if (site_name == "MORA") nrow(raw_mora) else length(noca_columns)
  stopifnot(raw_n == nrow(d), setequal(d$plot_id, x$plot_id))
  if (site_name == "MORA") stopifnot(setequal(paste(raw_mora$Location, raw_mora$Depth), paste(d$lake, d$depth)))
  merged = raw_n - nrow(x); final_n = sum(x$eligible)
  add_count(site_name, "Holocene", 1, "Starting core sample depths", raw_n)
  add_count(site_name, "Holocene", 2, "Combine depths with the same modeled age", nrow(x), combined = merged)
  remaining = nrow(x)
  for (code in c("missing_occurrence", "no_recorded_taxa", "consolidation", "species_selection", "no_calibration_taxa", "climate")) {
    n = reason_count(x, code)
    label = c(missing_occurrence = "No prepared vegetation record", no_recorded_taxa = "No study tree species detected",
      consolidation = "Only species removed from the study", species_selection = "Only species below the CCA cutoff",
      no_calibration_taxa = "Only species absent from the legacy CCA", climate = "Missing climate values")[[code]]
    remaining = remaining - n
    add_count(site_name, "Holocene", match(code, c("missing_occurrence", "no_recorded_taxa", "consolidation", "species_selection", "no_calibration_taxa", "climate")) + 2L,
      label, remaining, n)
  }
  stopifnot(remaining == final_n)
  paleo_info[[site_name]] = list(raw = raw_n, combined = merged,
    dated = nrow(x), final = final_n, excluded = x |> filter(!eligible))
}
dir.create(here("output/report"), recursive = TRUE, showWarnings = FALSE)
write_csv(bind_rows(counts), here("output/report/sample_selection_counts.csv"))
write_csv(bind_rows(choices), here("output/report/sample_selection_choices.csv"))
write_csv(plot_sizes, here("output/report/sample_selection_plot_sizes.csv"))

# The display follows the count branches. Its labels use everyday descriptions.
draw_flow = function(site_name, title, nodes, arrows, notes, ymax) {
  col = PAPER_SITE_COLORS[[site_name]]
  ggplot() +
    geom_segment(data = arrows, aes(x, y, xend = xend, yend = yend),
      linewidth = .6, colour = "grey45", arrow = grid::arrow(length = grid::unit(2.4, "mm"))) +
    geom_rect(data = nodes, aes(xmin = x - 33, xmax = x + 33, ymin = y - height / 2, ymax = y + height / 2),
      fill = adjustcolor(col, alpha.f = .12), colour = col, linewidth = .7) +
    geom_text(data = nodes, aes(x, y, label = label), size = 5.8, lineheight = .97) +
    geom_text(data = notes, aes(x, y, label = label), hjust = 0, size = 5.1, lineheight = 1.02) +
    coord_cartesian(xlim = c(0, 169), ylim = c(-8, ymax), clip = "off") +
    labs(title = title) + theme_void() +
    theme(plot.title = element_text(size = 23, face = "bold", colour = col,
      margin = margin(b = 9)), plot.margin = margin(9, 12, 9, 12))
}
node = function(x, y, label, height = 16) tibble(x, y, label, height)
edge = function(x, y, xend, yend) tibble(x, y, xend, yend)
note = function(x, y, label) tibble(x, y, label)
explain = function(x, period_label) {
  if (!nrow(x)) return(paste0(period_label, ":\n0 plots removed"))
  labels = c(no_recorded_taxa = "no study trees recorded", consolidation = "only species removed from the study",
    species_selection = "only species below the CCA cutoff", no_calibration_taxa = "only species absent from the legacy CCA", climate = "missing climate values")
  lines = vapply(unique(x$reason_code), function(code) {
    description = labels[[code]]
    if (code == "consolidation") {
      failed = x |> filter(reason_code == code) |>
        transmute(site, plot_id, period = exclusion_period)
      names = original_records |> inner_join(failed, by = c("site", "plot_id", "period")) |>
        filter(occurrence == 1) |> pull(species) |> unique()
      if (length(names) == 1L) description = paste("only", names)
    }
    paste0("\u2212", sum(x$reason_code == code), " ", description)
  }, character(1))
  paste(c(paste0(period_label, ":"), lines), collapse = "\n")
}
mi = modern_info$MORA; ni = modern_info$NOCA
m_nodes = bind_rows(node(35, 144, sprintf("Starting legacy data\n%d plots", length(legacy_ids))),
  node(125, 144, sprintf("Starting resurvey data\n%d plots", length(resurvey_ids))),
  node(35, 117, sprintf("Matched surveys\n%d plots", mn)),
  node(35, 89, sprintf("Latest adult visit\n%d plots", mn)),
  node(35, 61, sprintf("Study tree records\n%d plots", mn)),
  node(35, 33, sprintf("Eligible legacy plots\n%d plots", mi$eligible)),
  node(35, 5, sprintf("CCA fit and comparisons\n%d matched plots", mi$fit)))
m_edges = bind_rows(edge(35,136,35,125), edge(125,136,69,121),
  edge(35,109,35,97), edge(35,81,35,69), edge(35,53,35,41), edge(35,25,35,13))
m_notes = bind_rows(note(75,117,sprintf("\u2212%d legacy plots and \u2212%d resurveys\nwithout a match in the plot-name table\n(includes the practice plot PRAC-1)", length(legacy_ids)-mn,length(resurvey_ids)-mn)),
  note(75,89,sprintf("%d plots visited in multiple years\n%d adult + %d seedling records removed\n0 plots removed",nrow(repeated),discarded_adults,discarded_seedlings)),
  note(75,61,"Adults and seedlings combined;\ntree names matched and species lists aligned\n0 plots removed at this step"),
  note(75,33,explain(mi$legacy,"Legacy date")), note(75,5,explain(mi$resurvey,"Resurvey date")))
n_nodes = bind_rows(node(35,144,sprintf("Starting legacy data\n%d plots",length(noca_legacy_ids))),
  node(125,144,sprintf("Starting resurvey list\n%d plots",nrow(registered))),
  node(35,111,sprintf("Usable matched locations\n%d legacy plots\n\u2212%d with no matched\nGPS information", n_distinct(matched$legacy_id),length(noca_legacy_ids)-n_distinct(matched$legacy_id)),26),
  node(125,122,sprintf("Usable mapped plots: %d\n\u2212%d supplementary / reference\n\u2212%d missing GPS",nrow(located),sum(extra),gps_removed),20),
  node(125,100,sprintf("Usable tree names: %d plots\n\u2212%d only unsupported names",nrow(supported),length(unsupported)),16),
  node(35,82,sprintf("Matched surveys\n%d plots",nrow(matched))),
  node(35,56,sprintf("Plots after cleaning\n%d plots",nn)),
  node(35,30,sprintf("Eligible legacy plots\n%d plots",ni$eligible)),
  node(35,4,sprintf("CCA fit and comparisons\n%d matched plots",ni$fit)))
n_edges = bind_rows(edge(35,136,35,124),edge(125,136,125,132),edge(125,112,125,108),
  edge(35,98,35,90),edge(125,92,69,86),edge(35,74,35,64),edge(35,48,35,38),edge(35,22,35,12))
n_notes = bind_rows(note(75,79,sprintf("\u2212%d resurveys without\na legacy tree survey",nrow(supported)-nrow(matched))),
  note(75,56,sprintf("\u2212%d no trees at either date\n\u2212%d old clearcut; \u2212%d uncertain location\n\u2212%d unresolved GPS problems",length(empty_both),clearcuts,relocations,gps_problems)),
  note(75,30,explain(ni$legacy,"Legacy date")),note(75,4,explain(ni$resurvey,"Resurvey date")))
modern_mora = draw_flow("MORA","MORA \u00b7 modern plots",m_nodes,m_edges,m_notes,156)
modern_noca = draw_flow("NOCA","NOCA \u00b7 modern plots",n_nodes,n_edges,n_notes,156)
plot_size_panel = function(site_name, usual_area) {
  x = retained_areas |> filter(site == site_name)
  usual_n = sum(x$legacy_area_m2 == usual_area, na.rm = TRUE)
  other = x$legacy_area_m2[!is.na(x$legacy_area_m2) & x$legacy_area_m2 != usual_area]
  missing_n = sum(is.na(x$legacy_area_m2))
  area_labels = format(unique_values(other), big.mark = ",", trim = TRUE)
  areas_text = if (length(area_labels) > 1)
    paste0(paste(head(area_labels, -1), collapse = ", "), " or ", tail(area_labels, 1)) else
    paste(area_labels, collapse = "")
  lines = c(sprintf("Legacy: %d of %d plots = %s m\u00b2", usual_n, nrow(x), usual_area),
    if (length(other)) sprintf("%d plots = %s m\u00b2", length(other), areas_text),
    if (missing_n) sprintf("%d legacy plots: area not recorded", missing_n),
    sprintf("Resurvey: all %d plots = 500 m\u00b2", nrow(x)))
  col = PAPER_SITE_COLORS[[site_name]]
  ggplot() +
    annotate("rect", xmin = 0, xmax = 169, ymin = 0, ymax = 1,
      fill = adjustcolor(col, alpha.f = .12), colour = col, linewidth = .7) +
    annotate("text", x = 5, y = .5, label = paste(lines, collapse = "\n"),
      hjust = 0, size = 5.8, lineheight = 1.18) +
    coord_cartesian(xlim = c(0, 169), ylim = c(0, 1), clip = "off") +
    labs(title = paste0(site_name, " \u00b7 retained adult-tree plot sizes")) + theme_void() +
    theme(plot.title = element_text(size = 23, face = "bold", colour = col,
      margin = margin(b = 9)), plot.margin = margin(9, 12, 9, 12))
}
paleo_plot = function(site_name) {
  p = paleo_info[[site_name]]
  nodes = bind_rows(node(35,62,sprintf("Starting core records\n%d sample depths",p$raw)),
    node(35,36,sprintf("Samples with distinct ages\n%d samples",p$dated)),
    node(35,10,sprintf("Samples projected into CCA\n%d samples",p$final)))
  exclusions = p$excluded
  lines = if (!nrow(exclusions)) "0 samples excluded" else {
    labels = c(no_recorded_taxa="no study tree species detected",consolidation="only species removed from the study",species_selection="only species below the CCA cutoff",no_calibration_taxa="only species absent from the legacy CCA",climate="missing climate values",missing_occurrence="no prepared vegetation record")
    paste(vapply(unique(exclusions$reason_code),function(code) paste0("\u2212",reason_count(exclusions,code)," ",labels[[code]]),character(1)),collapse="\n")
  }
  notes = bind_rows(note(75,36,sprintf("%d sample depths combined\nwith other depths at the same modeled age\nThese are combined, not excluded",p$combined)),
    note(75,10,paste0(lines,"\nNo further losses to other species rules\nor climate matching")))
  draw_flow(site_name,paste0(site_name," \u00b7 Holocene samples"),nodes,
    bind_rows(edge(35,54,35,44),edge(35,28,35,18)),notes,75)
}
caption = paste(
  "The two starting surveys are separate lists; their exclusions must not be added. Legacy and resurvey exclusions are checked before fitting the CCA on matched plots.",
  "CCA keeps a species if it occurs in at least 20 plots or samples in any one site and period. Adult and seedling records supply presence together.",
  sprintf("Other preparation choices: %d MORA seedling record years assigned from adult visits; corrected NOCA tree records applied at %d plots. All current CCA climate values are complete.",sum(visit_rows$year_corrected),nrow(corrected)),
  "Fire assignments remove no plots before CCA. Figure 4 later excludes the two burned MORA plots; they remain in CCA and Figure 3.",sep="\n")
figure = (modern_mora + modern_noca) /
  (plot_size_panel("MORA", 500) + plot_size_panel("NOCA", 100)) /
  (paleo_plot("MORA") + paleo_plot("NOCA")) +
  plot_layout(heights = c(2.1,.65,1)) +
  plot_annotation(title = "From starting data to the CCA", caption = caption,
    theme = theme(plot.title = element_text(size=28,face="bold"),
      plot.caption = element_text(size=14,hjust=0,lineheight=1.15),plot.margin=margin(14,14,14,14)))
if (isTRUE(getOption("paleoaces.render_figures", TRUE))) {
  ggsave(here("plot/test_figures/plots_to_cca.pdf"),figure,width=18,height=18,device=cairo_pdf)
}
cat("Plot selection summary: modern CCA fits ",mi$fit," MORA + ",ni$fit,
  " NOCA; paired comparisons ",mi$paired," + ",ni$paired,
  "; Holocene projections ",paleo_info$MORA$final," + ",paleo_info$NOCA$final,".\n",sep="")
