---
title: "PaleoACES analysis review"
---

{{build_status}}

This review follows the sequential analysis from inputs to manuscript Figures 2–5. It connects prepared data, diagnostic evidence, and result tables for scientific review. [Scientific decisions](SCIENTIFIC_DECISIONS.md) records authoritative rationale and unresolved choices; [figure captions](FIGURE_CAPTIONS.md) remains the publication-caption authority. The [workflow](WORKFLOW.md), [documentation index](INDEX.md), [repository inventory](REPOSITORY_INVENTORY.md), and [output inventory](OUTPUTS.md) provide operational detail. The [combined reading copy](review/00_main_analysis_review.R) contains the 25 analysis stages in workflow order, without test scripts; its concatenated form does not reproduce the driver's conditional branches or isolated environments.

## Study design and inputs

Legacy forest surveys calibrate one pooled MORA/NOCA CCA. Resurveys and four dated plant-macrofossil records are projected into that same ordination. MORA pools Jay Bath, Log Wallow, and Reflection Pond for site-level Holocene metrics; Panther Potholes represents NOCA. MORA charcoal event records come from Sunrise, Shadow, and Little Sunrise lakes, whereas NOCA charcoal comes from the Panther Potholes core. Their spatial support and chronology precision differ.

The [MORA source package](../data/MORA/README_data_raw.md), [NOCA paleo sources](../data/NOCA/NOCA_paleo/SOURCES.md), [MORA chronology sources](../Cores/SOURCES_MORA.md), and [survey-year provenance](../data/SOURCES_SURVEY_YEARS.md) identify source materials. The [input inventory](REPOSITORY_INVENTORY.md#raw-duplicates-and-authority) identifies authoritative copies while retaining raw duplicates.

![Analysis dependencies](assets/analysis/dependencies.png)

{{cleaning_summary}}

## Vegetation preparation

Presence means adult **or** regeneration presence. MORA uses the original legacy workbook and cleaned resurvey tree/seedling files. NOCA applies the received 2026 corrected-tree workbook as an authoritative patch before occurrence construction; unsupported identification labels are discarded. `BAK487` (old clearcut) and `BEAV6061` (uncertain relocation into an avalanche chute) are excluded at study level. The corrected NOCA cleaning universe is 307 plots, while the model requires valid retained taxa and matched climate at both times. The [cleaning guide](methods/000_NOCA_cleaning_guide.md) explains the patch and paired-universe decisions.

{{correction_summary}}

{{vegetation_diagnostics}}

## Taxonomy and species selection

The [consolidation guide](methods/README_occurrence_consolidation.md) is authoritative for Populus/Picea/Abies harmonization and understory removal. Acer circinatum and Taxus brevifolia are removed for stratum compatibility; Pinus ponderosa is excluded by the documented analytical decision. A species survives the CCA threshold when it occurs in at least one site-period group of 20 or more plots/samples. This is a cross-group retention rule. Pinus albicaulis sits exactly on the threshold and is deliberately retained; raising it would change the scientific analysis. Threshold choice rests on taxon relevance and axis interpretation, rather than a mechanical increase in constrained inertia.

{{cca_taxa}}

{{taxonomy_diagnostics}}

The occupancy figure retains the former **500-year sensitivity**. It makes site confounding and sparse bins visible; the primary Holocene tracking and climate-era support remains 1,000 years.

## Chronology and uncertainty

The four primary Bacon models use pinned control points, settings, and seeded stored posteriors. The [master controls](../Cores/CONTROL_POINTS.md) explains ages, slumps and units. Tracking carries 100 whole-chronology draws per core, keeping within-core temporal dependence. The Pb210 error sensitivity contrasts published activity-error values with assumed ±10-year age errors; it does not authorize replacing the primary chronology.

{{bacon_manifest}}

{{chronology_diagnostics}}

Report rebuilding validates the stored manifest and hashes controls, posteriors and ages before and after executing only the existing figure section. It executes no control generation or MCMC. The MORA published fire chronologies and NOCA core chronology do not provide equivalent timing uncertainty; alignment does not imply equally precise cross-site event timing.

## Climate preparation

Modern plots use CHELSA V2.1 native monthly caches. Paleo records use native CHELSA-TraCE21k series at four pond coordinates, matched to each sample's age; raw TraCE21k is primary and V2.1 anchoring remains a sensitivity. The common seasonal derivation uses mean temperature `(tasmin + tasmax)/2`, and seasonal precipitation sums. Spring is March–May, summer is June–August, winter is December–February. Modern December belongs to the following winter; paleo slice December stays in its own climatology. All three seasonal months are required. Temperature is °C and precipitation is mm per season.

MORA compares **1979–1989 with 2010–2019**, over **30.5 midpoint years**; NOCA compares **1979–1989 with 2010–2015**, over **28.5 midpoint years**. These are annualized short-window contrasts. Missing January 1979 reduces complete legacy winters to ten, while spring/summer retain eleven years. Vegetation rate denominators use plot resurvey years, so climate windows and vegetation intervals must remain distinct. The possible post-2010 CHELSA precipitation inhomogeneity remains unresolved.

{{climate_windows}}

{{climate_diagnostics}}

The full climate diagnostic's page 1 and pace tables retain 500-year sensitivity assumptions. This report uses its **page 2 correlations** for redundancy review, and the authoritative Figure 2 rate table for primary physical-rate comparisons.

{{raw_climate_rates}}

## CCA calibration and geometry

One pooled legacy CCA is constrained by MSpT, MWT, SP, and WP. Modern resurveys and paleo observations are projected without recalibrating that fit. These variables are seasonal correlates of growing energy, freezing exposure, summer dryness and snowpack; they are not direct GDD, FDD, soil-moisture or snowpack measurements.

{{cca_summary}}

{{cca_axes}}

{{cca_counts}}

Samples holding none of the retained taxa have no WA position and are counted separately from modeled samples. Downstream calculations use `scaling = "sites"` (vegan scaling 1), Hill off and CCA1–CCA2. Display arrow multipliers never enter vector metrics. Correlated constraints prevent interpreting marginal contributions as additive shares of explained inertia.

{{cca_diagnostics}}

## Climate eras and fire evidence

Climate eras are constructed independently of vegetation, fire, archaeology and literature. Signed 1,000-year changes are divided by pooled legacy CCA calibration SDs, MORA lakes are averaged first, and MORA/NOCA receive equal regional weight. Each variable qualifies at 50% of its own maximum absolute regional median, with at least eight of ten phases supporting its direction. Any qualifying variable creates a climate-change cell; directly adjacent cells merge. The unsigned four-variable composite is displayed as context. Complete phase support spans 9.6–1.3 ka. Driver subphases refine CC1 without changing parent CC/S boundaries.

{{era_catalog}}

All four charcoal records use the common tapas detector with core-specific interpolation, background and local threshold settings, unlogged CHAR, robust LOWESS, a 75-year count window and `p <= 0.05`. Primary accepted totals are 17 Sunrise, 14 Shadow, 13 Little Sunrise and 66 Panther Potholes; NOCA's 12.5-year interpolation sensitivity yields 72. The official CharAnalysis R audit is kept separate and retains its Walsh publication discrepancy.

{{fire_settings}}

{{event_audit}}

{{walsh_audit}}

High-fire periods use centered 1,000-year accepted-event frequency, within-core normalization, equal-core MORA averaging where at least two cores are covered, and local NOCA evidence. A site's frequency must exceed its median plus `1.4826 × MAD`. Above-threshold runs are retained without gap bridging or a duration filter. Five MORA and six NOCA periods result; peak strength and background CHAR are corroboration only.

{{fire_diagnostics}}

{{figure_2}}

## Community trajectories

The selected display uses one observed WA and one predicted LC centroid per site × CC1–S4 era, connected chronologically as separate trajectories. It keeps the pooled ordination, modern paired arrows, biplot inset and climate/species contribution panels. Era centroids summarize positioned observations; they do not create an additional CCA or make absent early MORA tracking dates valid.

{{era_centroids}}

{{figure_3}}

## Tracking metrics and resolution sensitivity

Observed movement is WA displacement; climate-predicted vegetation movement is LC displacement. Endpoint lag is `||LC − WA||`, and signed lag change is lag at t2 minus lag at t1. Positive values mean mismatch opens. Tracking ratio is observed/predicted displacement (or rate when denominators coincide); angle is undefined for stationary movement. Physical climate rates separately retain signed °C/century and mm/century components and a legacy-SD standardized multivariate rate.

Primary Holocene metrics pool MORA's lakes before computing nonlinear metrics for each site × offset × draw × consecutive 1,000-year interval. Summaries aggregate draws within offset first, then phase sensitivity. Half-open grid mapping prevents boundary duplication. Ten-offset coverage yields 54 MORA and 83 NOCA site-dates. Draws and offsets are sensitivity realizations, not ecological replicates. One-sample bins remain flagged and have a separate nmin2 sensitivity.

{{tracking_diagnostics}}

{{resolution_audit}}

{{era_coverage}}

{{tracking_summary}}

Figure 4 retains 605 modern pairs after explicitly omitting the two burned MORA pairs from this descriptive comparison. All 137 supported Holocene site-dates remain. The scatter includes 589 direction-valid observations; 153 stationary modern observations remain in non-angle summaries. Fixed site facets and raw linear scales support descriptive comparisons; phase/draw spread and quartiles are not inferential uncertainty intervals.

{{figure_4}}

## Direction discrepancies and support

For a taxon, predicted alignment is `cos(ΔLC, species − LC₁)` and observed alignment is `cos(ΔWA, species − WA₁)`. Each starts from its own initial position toward the same fixed species score. Climate targets use the common raw environmental biplot direction. The paired **target-alignment discrepancy** is predicted minus observed cosine. Positive values mean stronger predicted target alignment, including being less opposed to a target; zero means equal target-specific cosines. Direct LC–WA cosine and angle separately measure movement-vector agreement.

Cosines use the same fitted geometry, are clamped to [−1, 1], and are missing below the existing `1e-8` movement tolerance. A paired discrepancy is valid only when both components are valid. All 607 modern pairs and 15,270 primary Holocene realizations enter this stage, including the two burned MORA plots. The outputs contain 10,319 modern target contrasts, 259,590 Holocene contrasts, 2,329 supported site-date contrasts and 204 group summaries.

{{direction_support}}

MORA burned has only two plots and NOCA stable/high-fire has only two dates. Small groups remain visible for support review. These descriptive contrasts do not establish taxon dominance, causal attribution, prevalence, significance or numbered-era inference. The own-origin geometry means starting-position differences can contribute to the contrast; a common-origin sensitivity remains an open scientific choice.

{{direction_diagnostics}}

{{figure_5}}

## Limitations, questions and validation

The unresolved-question register below is generated from [SCIENTIFIC_DECISIONS.md](SCIENTIFIC_DECISIONS.md#remaining-scientific-questions); that source remains authoritative.

{{questions}}

Chronology precision differs among records, paleo occupancy retains site confounding, and MORA/NOCA fire proxies have different spatial support. Climate and fire classifications are independent and aligned descriptively. Overlapping bins, dates, draws and phases are correlated. Product geography, resolution and continuity can affect contrasts. These limitations remain part of interpretation.

{{validation}}

## Diagnostic inventory and artifact provenance

Every diagnostic's purpose, producing script, interpretation and complete PDF is recorded here. Inline previews retain their original PDF page numbers; all main figures preserve manuscript numbering. The older CHELSAcruts comparison appears only in the historical-reference row and is excluded from the current-results narrative.

{{diagnostic_inventory}}

{{provenance}}

To regenerate the complete analysis and report from validated native caches:

```bash
Rscript R/workflow.R --offline --report
```

The report is published only after generation and validation succeed. Invalid offline caches cause an explicit failure before network access. A plain Git checkout can read this review, its self-contained HTML, previews, curated tables and linked PDFs without local raw data; rerunning the analysis requires the documented local research inputs and installed packages.
