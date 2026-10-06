---
title: "PaleoACES analysis review"
---

**Fresh validated analysis run. Report built 2026-10-05T13:54:11Z. Run identifier: `20261005T135004Z`. All included current figures and tables were regenerated in this run; chronology was redrawn from protected stored posteriors.

This review follows the sequential analysis from inputs to manuscript Figures 2–5. It connects prepared data, diagnostic evidence, and result tables for scientific review. [Scientific decisions](SCIENTIFIC_DECISIONS.md) records authoritative rationale and unresolved choices; [figure captions](FIGURE_CAPTIONS.md) remains the publication-caption authority. The [workflow](WORKFLOW.md), [documentation index](INDEX.md), [repository inventory](REPOSITORY_INVENTORY.md), and [output inventory](OUTPUTS.md) provide operational detail. The [combined reading copy](review/00_main_analysis_review.R) contains the 25 analysis stages in workflow order, without test scripts; its concatenated form does not reproduce the driver's conditional branches or isolated environments.

## Study design and inputs

Legacy forest surveys calibrate one pooled MORA/NOCA CCA. Resurveys and four dated plant-macrofossil records are projected into that same ordination. MORA pools Jay Bath, Log Wallow, and Reflection Pond for site-level Holocene metrics; Panther Potholes represents NOCA. MORA charcoal event records come from Sunrise, Shadow, and Little Sunrise lakes, whereas NOCA charcoal comes from the Panther Potholes core. Their spatial support and chronology precision differ.

The [MORA source package](../data/MORA/README_data_raw.md), [NOCA paleo sources](../data/NOCA/NOCA_paleo/SOURCES.md), [MORA chronology sources](../Cores/SOURCES_MORA.md), and [survey-year provenance](../data/SOURCES_SURVEY_YEARS.md) identify source materials. The [input inventory](REPOSITORY_INVENTORY.md#raw-duplicates-and-authority) identifies authoritative copies while retaining raw duplicates.

![Analysis dependencies](assets/analysis/dependencies.png)


| Prepared input | Rows | Plot/sample IDs | Taxa |
| --- | --- | --- | --- |
| MORA | 2502 | 331 | 23 |
| NOCA | 1790 | 307 | 31 |
| paleo | 9590 | 963 | 12 |
| consolidated | 13672 | 1601 | 21 |

[Full curated cleaning summary table](assets/analysis/tables/cleaning_summary.csv).


## Vegetation preparation

Presence means adult **or** regeneration presence. MORA uses the original legacy workbook and cleaned resurvey tree/seedling files. NOCA applies the received 2026 corrected-tree workbook as an authoritative patch before occurrence construction; unsupported identification labels are discarded. `BAK487` (old clearcut) and `BEAV6061` (uncertain relocation into an avalanche chute) are excluded at study level. The corrected NOCA cleaning universe is 307 plots, while the model requires valid retained taxa and matched climate at both times. The [cleaning guide](methods/000_NOCA_cleaning_guide.md) explains the patch and paired-universe decisions.


| Patch audit status | Affected plot IDs |
| --- | --- |
| excluded | 3 |
| included | 51 |

[Complete correction audit](assets/analysis/tables/correction_audit.csv), [study exclusions](assets/analysis/tables/study_exclusions.csv), and [unresolved coordinate collision](assets/analysis/tables/coordinate_collision.csv).


### Account for the corrected paired-plot cleaning universe.

The retained cleaning universe is broader than the final modeled pairs. Empty-period records and study exclusions remain explicit.

Producer: [000_NOCA_cleaning.R](../R/stages/000_NOCA_cleaning.R). [Complete PDF](../plot/test_figures/NOCA_cleaning.pdf); 3 page(s). Evidence status: **current**.

![Account for the corrected paired-plot cleaning universe. — PDF page 1](assets/analysis/noca_cleaning-p1.png)

### Show species counts before model taxon selection.

Counts reflect adult-or-regeneration presence in cleaned survey plots; they do not measure abundance.

Producer: [000_MORA_cleaning.R](../R/stages/000_MORA_cleaning.R). [Complete PDF](../plot/test_figures/MORA_dynamics.pdf); 3 page(s). Evidence status: **current**.

![Show species counts before model taxon selection. — PDF page 3](assets/analysis/mora_dynamics-p3.png)

### Compare corrected legacy and resurvey species counts.

Species differences describe cleaned surveys before cross-site harmonization and the CCA threshold.

Producer: [000_NOCA_cleaning.R](../R/stages/000_NOCA_cleaning.R). [Complete PDF](../plot/test_figures/NOCA_dynamics.pdf); 3 page(s). Evidence status: **current**.

![Compare corrected legacy and resurvey species counts. — PDF page 3](assets/analysis/noca_dynamics-p3.png)



## Taxonomy and species selection

The [consolidation guide](methods/README_occurrence_consolidation.md) is authoritative for Populus/Picea/Abies harmonization and understory removal. Acer circinatum and Taxus brevifolia are removed for stratum compatibility; Pinus ponderosa is excluded by the documented analytical decision. A species survives the CCA threshold when it occurs in at least one site-period group of 20 or more plots/samples. This is a cross-group retention rule. Pinus albicaulis sits exactly on the threshold and is deliberately retained; raising it would change the scientific analysis. Threshold choice rests on taxon relevance and axis interpretation, rather than a mechanical increase in constrained inertia.


| Taxon | MORA legacy | MORA resurvey | MORA paleo | NOCA legacy | NOCA resurvey | NOCA paleo | CCA retained |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Abies amabilis | 290 | 289 | 117 | 115 | 128 | 0 | TRUE |
| Abies lasiocarpa | 34 | 32 | 92 | 63 | 76 | 468 | TRUE |
| Abies procera | 68 | 50 | 43 | 0 | 0 | 0 | TRUE |
| Callitropsis nootkatensis | 106 | 101 | 78 | 37 | 44 | 38 | TRUE |
| Picea engelmannii | 12 | 9 | 5 | 26 | 22 | 12 | TRUE |
| Pinus contorta | 2 | 1 | 31 | 32 | 28 | 285 | TRUE |
| Pinus monticola | 42 | 15 | 90 | 28 | 25 | 489 | TRUE |
| Pseudotsuga menziesii | 181 | 147 | 40 | 158 | 147 | 594 | TRUE |
| Tsuga heterophylla | 281 | 283 | 54 | 90 | 123 | 179 | TRUE |
| Tsuga mertensiana | 88 | 77 | 108 | 89 | 76 | 39 | TRUE |
| Abies grandis | 8 | 8 | 0 | 11 | 22 | 0 | TRUE |
| Alnus rubra | 15 | 16 | 0 | 11 | 18 | 0 | FALSE |
| Picea sitchensis | 2 | 1 | 0 | 0 | 0 | 0 | FALSE |
| Populus trichocarpa | 3 | 3 | 0 | 8 | 3 | 0 | FALSE |
| Thuja plicata | 111 | 113 | 0 | 97 | 103 | 159 | TRUE |
| Acer macrophyllum | 0 | 4 | 0 | 17 | 19 | 0 | FALSE |
| Malus fusca | 0 | 1 | 0 | 0 | 0 | 0 | FALSE |
| Pinus albicaulis | 0 | 2 | 0 | 20 | 7 | 0 | TRUE |
| Juniperus communis | 0 | 0 | 0 | 0 | 0 | 8 | FALSE |
| Betula papyrifera | 0 | 0 | 0 | 4 | 6 | 0 | FALSE |
| Larix lyallii | 0 | 0 | 0 | 7 | 9 | 0 | FALSE |

[Full curated cca taxa table](assets/analysis/tables/cca_taxa.csv).


### Inspect consolidated occurrence counts in each site-period group.

Retention requires at least 20 plots or samples in one group. The threshold is not required in every group.

Producer: [000_occurrence_data_consolidate.R](../R/stages/000_occurrence_data_consolidate.R). [Complete PDF](../plot/test_figures/species_counts_consolidated.pdf); 1 page(s). Evidence status: **current**.

![Inspect consolidated occurrence counts in each site-period group. — PDF page 1](assets/analysis/species_counts-p1.png)

### Expose adult versus regeneration support for presence.

Adult and regeneration sources contribute to presence; stem counts and macrofossil percentages are not combined as abundance.

Producer: [000_occurrence_data_consolidate.R](../R/stages/000_occurrence_data_consolidate.R). [Complete PDF](../plot/test_figures/stage_adult_seedling_past_present.pdf); 1 page(s). Evidence status: **current**.

![Expose adult versus regeneration support for presence. — PDF page 1](assets/analysis/stage_comparison-p1.png)

### Inspect taxon site confounding and temporal occupancy.

This explicitly retains the 500-year occupancy sensitivity. Sparse sampling is shown; the primary tracking analysis uses 1,000 years.

Producer: [test_species_through_time.R](../R/diagnostics/test_species_through_time.R). [Complete PDF](../plot/test_figures/species_through_time.pdf); 1 page(s). Evidence status: **500-year sensitivity**.

![Inspect taxon site confounding and temporal occupancy. — PDF page 1](assets/analysis/occupancy-p1.png)



The occupancy figure retains the former **500-year sensitivity**. It makes site confounding and sparse bins visible; the primary Holocene tracking and climate-era support remains 1,000 years.

## Chronology and uncertainty

The four primary Bacon models use pinned control points, settings, and seeded stored posteriors. The [master controls](../Cores/CONTROL_POINTS.md) explains ages, slumps and units. Tracking carries 100 whole-chronology draws per core, keeping within-core temporal dependence. The Pb210 error sensitivity contrasts published activity-error values with assumed ±10-year age errors; it does not authorize replacing the primary chronology.


| Model | Role | Seed | rbacon | Posterior bytes | Chronology generation UTC |
| --- | --- | --- | --- | --- | --- |
| JayBath | primary | 42 | 3.5.2 | 991182 | 2026-08-18 14:28:51 UTC |
| LogWallow | primary | 42 | 3.5.2 | 644430 | 2026-08-18 14:28:51 UTC |
| ReflectionPond | primary | 42 | 3.5.2 | 580267 | 2026-08-18 14:28:51 UTC |
| PantherPotholes | primary | 42 | 3.5.2 | 13659110 | 2026-08-18 14:28:51 UTC |
| PantherPotholes_pb210err | configured +-10-year 210Pb sensitivity | 42 | 3.5.2 | 13657891 | 2026-08-18 14:28:51 UTC |

[Full curated bacon manifest table](assets/analysis/tables/bacon_manifest.csv).


### Inspect four fitted age-depth models and slump treatment.

A report rebuild executes only the existing figure section from stored validated posteriors. Chronology products and controls are hash-protected.

Producer: [000_PALEO_a_agedepth.R](../R/stages/000_PALEO_a_agedepth.R). [Complete PDF](../plot/test_figures/fig_bacon_agedepth_slump.pdf); 1 page(s). Evidence status: **current**.

![Inspect four fitted age-depth models and slump treatment. — PDF page 1](assets/analysis/chronology-p1.png)

### Compare published activity errors with assumed ±10-year age uncertainty.

The sensitivity concerns the upper 35–40 cm of Panther Potholes; uncertainty in published fire chronologies is not equivalent across sites.

Producer: [000_PALEO_a_agedepth.R](../R/stages/000_PALEO_a_agedepth.R). [Complete PDF](../plot/test_figures/fig_bacon_pb210_sensitivity.pdf); 1 page(s). Evidence status: **chronology sensitivity**.

![Compare published activity errors with assumed ±10-year age uncertainty. — PDF page 1](assets/analysis/pb210-p1.png)



Report rebuilding validates the stored manifest and hashes controls, posteriors and ages before and after executing only the existing figure section. It executes no control generation or MCMC. The MORA published fire chronologies and NOCA core chronology do not provide equivalent timing uncertainty; alignment does not imply equally precise cross-site event timing.

## Climate preparation

Modern plots use CHELSA V2.1 native monthly caches. Paleo records use native CHELSA-TraCE21k series at four pond coordinates, matched to each sample's age; raw TraCE21k is primary and V2.1 anchoring remains a sensitivity. The common seasonal derivation uses mean temperature `(tasmin + tasmax)/2`, and seasonal precipitation sums. Spring is March–May, summer is June–August, winter is December–February. Modern December belongs to the following winter; paleo slice December stays in its own climatology. All three seasonal months are required. Temperature is °C and precipitation is mm per season.

MORA compares **1979–1989 with 2010–2019**, over **30.5 midpoint years**; NOCA compares **1979–1989 with 2010–2015**, over **28.5 midpoint years**. These are annualized short-window contrasts. Missing January 1979 reduces complete legacy winters to ten, while spring/summer retain eleven years. Vegetation rate denominators use plot resurvey years, so climate windows and vegetation intervals must remain distinct. The possible post-2010 CHELSA precipitation inhomogeneity remains unresolved.


| Site | Period | Plots | Spring years | Winter years | Summer years | Winter precipitation years |
| --- | --- | --- | --- | --- | --- | --- |
| MORA | past | 331 | 11 | 10 | 11 | 10 |
| MORA | present | 331 | 10 | 10 | 10 | 10 |
| NOCA | past | 307 | 11 | 10 | 11 | 10 |
| NOCA | present | 307 | 6 | 6 | 6 | 6 |

[Full curated climate windows table](assets/analysis/tables/climate_windows.csv).


### Compare selected survey windows with the full 1979–2021 record.

Detrending does not resolve CHELSA product continuity. Apparent precipitation anomalies remain a scientific limitation.

Producer: [test_survey_year_anomaly.R](../R/diagnostics/test_survey_year_anomaly.R). [Complete PDF](../plot/test_figures/test_survey_year_anomaly.pdf); 1 page(s). Evidence status: **current**.

![Compare selected survey windows with the full 1979–2021 record. — PDF page 1](assets/analysis/survey_window-p1.png)

### Inspect redundancy among candidate climate variables.

Only page 2 (correlations) is inline. Page 1 and associated pace tables retain the former 500-year sensitivity and are not primary rate evidence.

Producer: [test_climate_change_variables.R](../R/diagnostics/test_climate_change_variables.R). [Complete PDF](../plot/test_figures/climate_holocene_timeseries.pdf); 2 page(s). Evidence status: **correlation diagnostic; full PDF includes 500-year sensitivity**.

![Inspect redundancy among candidate climate variables. — PDF page 2](assets/analysis/climate_correlation-p2.png)



The full climate diagnostic's page 1 and pace tables retain 500-year sensitivity assumptions. This report uses its **page 2 correlations** for redundancy review, and the authoritative Figure 2 rate table for primary physical-rate comparisons.


| Constraint | Units | Holocene regional signed maximum | Peak cal BP | MORA modern median | NOCA modern median |
| --- | --- | --- | --- | --- | --- |
| Spring temperature | deg C / century | 0.04175 | 7500 | 2.41 | 1.341 |
| Winter temperature | deg C / century | 0.05504 | 9500 | 1.833 | 1.411 |
| Summer precipitation | mm / century | -1.087 | 8900 | -152.4 | 105.7 |
| Winter precipitation | mm / century | 2.338 | 8100 | -732 | -424.2 |

[Full curated raw climate rates table](assets/analysis/tables/raw_climate_rates.csv).


## CCA calibration and geometry

One pooled legacy CCA is constrained by MSpT, MWT, SP, and WP. Modern resurveys and paleo observations are projected without recalibrating that fit. These variables are seasonal correlates of growing energy, freezing exposure, summer dryness and snowpack; they are not direct GDD, FDD, soil-moisture or snowpack measurements.


| Fitted model quantity | Value |
| --- | --- |
| calibration_plots | 620 |
| retained_species | 13 |
| count_threshold | 20 |
| scaling | sites |
| hill | FALSE |
| constraints | — |
| total_inertia | 3.04 |
| constrained_inertia | 0.5012 |
| constrained_percent | 16.48 |
| projection_candidates | 1583 |
| positioned_samples | 1514 |

[Full curated cca summary table](assets/analysis/tables/cca_summary.csv).



| Axis | Eigenvalue | % total inertia | % constrained inertia |
| --- | --- | --- | --- |
| CCA1 | 0.2826 | 9.296 | 56.4 |
| CCA2 | 0.1838 | 6.046 | 36.68 |
| CCA3 | 0.02905 | 0.9555 | 5.797 |
| CCA4 | 0.005645 | 0.1857 | 1.126 |

[Full curated cca axes table](assets/analysis/tables/cca_axes.csv).



| Site | Period | Prepared climate samples | Calibrated | Positioned projection |
| --- | --- | --- | --- | --- |
| MORA | paleo | 117 | — | 117 |
| MORA | past | 331 | 331 | — |
| MORA | present | 331 | — | 330 |
| NOCA | paleo | 846 | — | 790 |
| NOCA | past | 307 | 289 | — |
| NOCA | present | 307 | — | 277 |

[Full curated cca counts table](assets/analysis/tables/cca_counts.csv).


Samples holding none of the retained taxa have no WA position and are counted separately from modeled samples. Downstream calculations use `scaling = "sites"` (vegan scaling 1), Hill off and CCA1–CCA2. Display arrow multipliers never enter vector metrics. Correlated constraints prevent interpreting marginal contributions as additive shares of explained inertia.

### Compare scaling 1 and 2 of the same fitted CCA.

The primary geometry stays scaling="sites", Hill off, CCA1–CCA2. Raw target directions, without display multipliers, enter metrics.

Producer: [test_cca_scaling_comparison.R](../R/diagnostics/test_cca_scaling_comparison.R). [Complete PDF](../plot/test_figures/fig_cca_scaling_comparison.pdf); 1 page(s). Evidence status: **current**.

![Compare scaling 1 and 2 of the same fitted CCA. — PDF page 1](assets/analysis/scaling-p1.png)



## Climate eras and fire evidence

Climate eras are constructed independently of vegetation, fire, archaeology and literature. Signed 1,000-year changes are divided by pooled legacy CCA calibration SDs, MORA lakes are averaged first, and MORA/NOCA receive equal regional weight. Each variable qualifies at 50% of its own maximum absolute regional median, with at least eight of ten phases supporting its direction. Any qualifying variable creates a climate-change cell; directly adjacent cells merge. The unsigned four-variable composite is displayed as context. Complete phase support spans 9.6–1.3 ka. Driver subphases refine CC1 without changing parent CC/S boundaries.


| Era | Class | Older cal BP | Younger cal BP | Duration years |
| --- | --- | --- | --- | --- |
| CC1 | climate change | 9600 | 7200 | 2400 |
| S1 | relative stability | 7200 | 6800 | 400 |
| CC2 | climate change | 6800 | 6200 | 600 |
| S2 | relative stability | 6200 | 5400 | 800 |
| CC3 | climate change | 5400 | 4900 | 500 |
| S3 | relative stability | 4900 | 2200 | 2700 |
| CC4 | climate change | 2200 | 1700 | 500 |
| S4 | relative stability | 1700 | 1300 | 400 |

[Full curated era catalog table](assets/analysis/tables/era_catalog.csv).


All four charcoal records use the common tapas detector with core-specific interpolation, background and local threshold settings, unlogged CHAR, robust LOWESS, a 75-year count window and `p <= 0.05`. Primary accepted totals are 17 Sunrise, 14 Shadow, 13 Little Sunrise and 66 Panther Potholes; NOCA's 12.5-year interpolation sensitivity yields 72. The official CharAnalysis R audit is kept separate and retains its Walsh publication discrepancy.


| Lake | Engine | Interpolation years | Background years | Local threshold |
| --- | --- | --- | --- | --- |
| Sunrise Lake | tapas | 48 | 800 | 0.95 |
| Shadow Lake | tapas | 47 | 1000 | 0.95 |
| Little Sunrise Lake | tapas | 42 | 500 | 0.95 |
| PantherPotholes | tapas | 12 | 500 | 0.99 |

[Full curated fire settings table](assets/analysis/tables/fire_settings.csv).



| Lake | Candidates | Count rejected | Accepted |
| --- | --- | --- | --- |
| Sunrise Lake | 26 | 9 | 17 |
| Shadow Lake | 17 | 3 | 14 |
| Little Sunrise Lake | 20 | 7 | 13 |
| PantherPotholes | 66 | 0 | 66 |

[Full curated event audit table](assets/analysis/tables/event_audit.csv).



| Lake | Official R episodes | Published total | Difference |
| --- | --- | --- | --- |
| Little Sunrise Lake | 14 | 16 | -2 |
| Shadow Lake | 16 | 18 | -2 |
| Sunrise Lake | 15 | 24 | -9 |

[Full curated walsh audit table](assets/analysis/tables/walsh_audit.csv).


High-fire periods use centered 1,000-year accepted-event frequency, within-core normalization, equal-core MORA averaging where at least two cores are covered, and local NOCA evidence. A site's frequency must exceed its median plus `1.4826 × MAD`. Above-threshold runs are retained without gap bridging or a duration filter. Five MORA and six NOCA periods result; peak strength and background CHAR are corroboration only.

### Audit NOCA modern fire assignment against Wilson reference plots.

The 305 shared plots agree. The cleaned 307-plot universe is retained; the reference is not substituted for it.

Producer: [01_get_fire_info.R](../R/stages/01_get_fire_info.R). [Complete PDF](../plot/test_figures/NOCA_fire_map_Wilson2024_PaleoACES.pdf); 1 page(s). Evidence status: **current**.

![Audit NOCA modern fire assignment against Wilson reference plots. — PDF page 1](assets/analysis/fire_map-p1.png)

### Follow interpolation, background, local noise threshold, and count screening.

Pages 1, 2, and 5 show common settings, Sunrise, and Panther Potholes. Core-specific temporal settings remain explicit; accepted events precede high-fire classification.

Producer: [12a_fire_event_detection_worked_example.R](../R/stages/12a_fire_event_detection_worked_example.R). [Complete PDF](../plot/test_figures/fig_fire_event_detection_workflow.pdf); 6 page(s). Evidence status: **current**.

![Follow interpolation, background, local noise threshold, and count screening. — PDF page 1](assets/analysis/fire_detection-p1.png)

![Follow interpolation, background, local noise threshold, and count screening. — PDF page 2](assets/analysis/fire_detection-p2.png)

![Follow interpolation, background, local noise threshold, and count screening. — PDF page 5](assets/analysis/fire_detection-p5.png)

### Compare official CharAnalysis results with published Walsh totals.

The discrepancy is retained without tuning; this software audit does not overwrite the primary all-tapas event catalog.

Producer: [12_walsh_fire_reproduction.R](../R/stages/12_walsh_fire_reproduction.R). [Complete PDF](../plot/test_figures/fig_walsh_charanalysis_reproduction.pdf); 3 page(s). Evidence status: **current**.

![Compare official CharAnalysis results with published Walsh totals. — PDF page 3](assets/analysis/walsh_audit-p3.png)

### Expose signed changes, phase support, and era construction.

Any qualifying variable creates a climate-change cell. Only adjacent cells merge; the unsigned composite is context.

Producer: [13_holocene_climate_fire_eras.R](../R/stages/13_holocene_climate_fire_eras.R). [Complete PDF](../plot/test_figures/fig_holocene_climate_period_method_worked_example.pdf); 1 page(s). Evidence status: **current**.

![Expose signed changes, phase support, and era construction. — PDF page 1](assets/analysis/climate_era_example-p1.png)

### Work through centered event frequencies at 2,300 cal BP.

Within-core normalization and site-specific robust thresholds yield MORA high fire and NOCA no high fire for the worked date.

Producer: [13b_fire_method_worked_example.R](../R/stages/13b_fire_method_worked_example.R). [Complete PDF](../plot/test_figures/fig_holocene_fire_method_worked_example.pdf); 1 page(s). Evidence status: **current**.

![Work through centered event frequencies at 2,300 cal BP. — PDF page 1](assets/analysis/high_fire_example-p1.png)



### Figure 2. Climate eras, climate rates and high-fire periods

![Figure 2. fig standardized climate change eras fire](assets/analysis/figure-2.png)

[Full PDF](../plot/fig_standardized_climate_change_eras_fire.pdf). Producer: [13a_climate_change_figure.R](../R/stages/13a_climate_change_figure.R). [Authoritative method and publication caption](FIGURE_CAPTIONS.md).


## Community trajectories

The selected display uses one observed WA and one predicted LC centroid per site × CC1–S4 era, connected chronologically as separate trajectories. It keeps the pooled ordination, modern paired arrows, biplot inset and climate/species contribution panels. Era centroids summarize positioned observations; they do not create an additional CCA or make absent early MORA tracking dates valid.


| Site | Era | Positioned dates | Observed CCA1 | Observed CCA2 | Predicted CCA1 | Predicted CCA2 |
| --- | --- | --- | --- | --- | --- | --- |
| MORA | CC1 | 3 | 0.2177 | 0.4251 | -0.2569 | -0.8382 |
| MORA | S1 | 4 | 0.3393 | 0.4944 | -0.1385 | -0.8394 |
| MORA | CC2 | 6 | 0.4011 | 0.4898 | -0.08158 | -0.8413 |
| MORA | S2 | 8 | 0.5932 | 0.3929 | -0.0596 | -0.8428 |
| MORA | CC3 | 5 | 0.6436 | 0.3549 | -0.09415 | -0.8192 |
| MORA | S3 | 27 | 0.6922 | 0.01626 | -0.1653 | -0.8747 |
| MORA | CC4 | 5 | 0.6598 | -0.3078 | -0.1766 | -0.9058 |
| MORA | S4 | 4 | 0.6699 | -0.2147 | -0.2148 | -0.8608 |
| NOCA | CC1 | 24 | -0.01311 | 1.463 | -0.2249 | 0.3867 |
| NOCA | S1 | 4 | -0.04453 | 1.086 | -0.31 | 0.2867 |
| NOCA | CC2 | 6 | -0.02969 | 1.123 | -0.2567 | 0.2854 |
| NOCA | S2 | 8 | 0.05325 | 0.9584 | -0.2325 | 0.2705 |
| NOCA | CC3 | 5 | -0.005052 | 0.7695 | -0.2617 | 0.2675 |
| NOCA | S3 | 27 | -0.1045 | 0.7231 | -0.2613 | 0.237 |
| NOCA | CC4 | 5 | -0.1987 | 0.4834 | -0.2561 | 0.265 |
| NOCA | S4 | 4 | -0.2825 | 0.296 | -0.2711 | 0.2907 |

[Full curated era centroids table](assets/analysis/tables/era_centroids.csv).


### Figure 3. Observed and climate-predicted community trajectories

![Figure 3. fig cca trajectories](assets/analysis/figure-3.png)

[Full PDF](../plot/fig_cca_trajectories.pdf). Producer: [05a_cca_figure.R](../R/stages/05a_cca_figure.R). [Authoritative method and publication caption](FIGURE_CAPTIONS.md).


## Tracking metrics and resolution sensitivity

Observed movement is WA displacement; climate-predicted vegetation movement is LC displacement. Endpoint lag is `||LC − WA||`, and signed lag change is lag at t2 minus lag at t1. Positive values mean mismatch opens. Tracking ratio is observed/predicted displacement (or rate when denominators coincide); angle is undefined for stationary movement. Physical climate rates separately retain signed °C/century and mm/century components and a legacy-SD standardized multivariate rate.

Primary Holocene metrics pool MORA's lakes before computing nonlinear metrics for each site × offset × draw × consecutive 1,000-year interval. Summaries aggregate draws within offset first, then phase sensitivity. Half-open grid mapping prevents boundary duplication. Ten-offset coverage yields 54 MORA and 83 NOCA site-dates. Draws and offsets are sensitivity realizations, not ecological replicates. One-sample bins remain flagged and have a separate nmin2 sensitivity.

### Work through WA/LC movement, lag, ratio, and angle.

Lag change is endpoint mismatch at t2 minus t1; a stationary observed movement has no defined direction.

Producer: [09a_method_example.R](../R/stages/09a_method_example.R). [Complete PDF](../plot/test_figures/fig_method_worked_example.pdf); 1 page(s). Evidence status: **current**.

![Work through WA/LC movement, lag, ratio, and angle. — PDF page 1](assets/analysis/tracking_example-p1.png)




| Site | Metric | Resolution | Dates | Median | Median samples/bin |
| --- | --- | --- | --- | --- | --- |
| MORA | angle_degrees | 1000 years (primary) | 54 | 37.22 | 11.5 |
| NOCA | angle_degrees | 1000 years (primary) | 83 | 80.47 | 57.5 |
| MORA | angle_degrees | 500 years (sensitivity) | 64 | 76.56 | 6 |
| NOCA | angle_degrees | 500 years (sensitivity) | 98 | 91.39 | 30 |

[Full curated resolution audit table](assets/analysis/tables/resolution_audit.csv).



| Site | Era | Supported dates | Coverage |
| --- | --- | --- | --- |
| MORA | CC1 | 0 | insufficient complete-offset support |
| MORA | S1 | 0 | insufficient complete-offset support |
| MORA | CC2 | 5 | complete ten-offset support |
| MORA | S2 | 8 | complete ten-offset support |
| MORA | CC3 | 5 | complete ten-offset support |
| MORA | S3 | 27 | complete ten-offset support |
| MORA | CC4 | 5 | complete ten-offset support |
| MORA | S4 | 4 | complete ten-offset support |
| NOCA | CC1 | 24 | complete ten-offset support |
| NOCA | S1 | 4 | complete ten-offset support |
| NOCA | CC2 | 6 | complete ten-offset support |
| NOCA | S2 | 8 | complete ten-offset support |
| NOCA | CC3 | 5 | complete ten-offset support |
| NOCA | S3 | 27 | complete ten-offset support |
| NOCA | CC4 | 5 | complete ten-offset support |
| NOCA | S4 | 4 | complete ten-offset support |

[Full curated era coverage table](assets/analysis/tables/era_coverage.csv).



| Site | Era | Fire | Metric | Total | Valid | Median | Q25 | Q75 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MORA | Holocene | No fire | angle_degrees | 38 | 38 | 37.57 | 34.88 | 65.84 |
| MORA | Holocene | Fire | angle_degrees | 16 | 16 | 34.8 | 28.14 | 42.51 |
| MORA | Anthropocene | No fire | angle_degrees | 328 | 250 | 100.6 | 30.41 | 157.1 |
| NOCA | Holocene | No fire | angle_degrees | 69 | 69 | 88.88 | 50.09 | 134 |
| NOCA | Holocene | Fire | angle_degrees | 14 | 14 | 68.95 | 30.73 | 80.47 |
| NOCA | Anthropocene | No fire | angle_degrees | 254 | 190 | 93.71 | 41.81 | 146.3 |
| NOCA | Anthropocene | Fire | angle_degrees | 23 | 12 | 31.52 | 13.45 | 85.19 |

[Full curated tracking summary table](assets/analysis/tables/tracking_summary.csv).


Figure 4 retains 605 modern pairs after explicitly omitting the two burned MORA pairs from this descriptive comparison. All 137 supported Holocene site-dates remain. The scatter includes 589 direction-valid observations; 153 stationary modern observations remain in non-angle summaries. Fixed site facets and raw linear scales support descriptive comparisons; phase/draw spread and quartiles are not inferential uncertainty intervals.

### Figure 4. Vegetation tracking across eras and fire contexts

![Figure 4. fig tracking comparison](assets/analysis/figure-4.png)

[Full PDF](../plot/fig_tracking_comparison.pdf). Producer: [09c_tracking_comparison.R](../R/stages/09c_tracking_comparison.R). [Authoritative method and publication caption](FIGURE_CAPTIONS.md).


## Direction discrepancies and support

For a taxon, predicted alignment is `cos(ΔLC, species − LC₁)` and observed alignment is `cos(ΔWA, species − WA₁)`. Each starts from its own initial position toward the same fixed species score. Climate targets use the common raw environmental biplot direction. The paired **target-alignment discrepancy** is predicted minus observed cosine. Positive values mean stronger predicted target alignment, including being less opposed to a target; zero means equal target-specific cosines. Direct LC–WA cosine and angle separately measure movement-vector agreement.

Cosines use the same fitted geometry, are clamped to [−1, 1], and are missing below the existing `1e-8` movement tolerance. A paired discrepancy is valid only when both components are valid. All 607 modern pairs and 15,270 primary Holocene realizations enter this stage, including the two burned MORA plots. The outputs contain 10,319 modern target contrasts, 259,590 Holocene contrasts, 2,329 supported site-date contrasts and 204 group summaries.


| Period | Site | Climate state | Burned/high fire | Units | Min valid targets | Max valid targets |
| --- | --- | --- | --- | --- | --- | --- |
| Anthropocene | MORA | — | FALSE | 328 | 248 | 250 |
| Anthropocene | MORA | — | TRUE | 2 | 2 | 2 |
| Anthropocene | NOCA | — | FALSE | 254 | 179 | 190 |
| Anthropocene | NOCA | — | TRUE | 23 | 11 | 12 |
| Holocene | MORA | climate change | FALSE | 7 | 7 | 7 |
| Holocene | MORA | climate change | TRUE | 8 | 8 | 8 |
| Holocene | MORA | relative stability | FALSE | 31 | 31 | 31 |
| Holocene | MORA | relative stability | TRUE | 8 | 8 | 8 |
| Holocene | NOCA | climate change | FALSE | 28 | 28 | 28 |
| Holocene | NOCA | climate change | TRUE | 12 | 12 | 12 |
| Holocene | NOCA | relative stability | FALSE | 41 | 41 | 41 |
| Holocene | NOCA | relative stability | TRUE | 2 | 2 | 2 |

[Full direction summaries](assets/analysis/tables/direction_summary.csv) and [group support](assets/analysis/tables/direction_support.csv).


MORA burned has only two plots and NOCA stable/high-fire has only two dates. Small groups remain visible for support review. These descriptive contrasts do not establish taxon dominance, causal attribution, prevalence, significance or numbered-era inference. The own-origin geometry means starting-position differences can contribute to the contrast; a common-origin sensitivity remains an open scientific choice.

### Inspect distributions and support beneath the Figure 5 heatmap.

The paired target discrepancy uses each trajectory's own origin. Quartiles are descriptive; small groups are retained rather than interpreted as precise estimates.

Producer: [14_cca_direction_analysis.R](../R/stages/14_cca_direction_analysis.R). [Complete PDF](../plot/test_figures/fig_cca_direction_differences_audit.pdf); 3 page(s). Evidence status: **current**.

![Inspect distributions and support beneath the Figure 5 heatmap. — PDF page 1](assets/analysis/direction_audit-p1.png)

![Inspect distributions and support beneath the Figure 5 heatmap. — PDF page 2](assets/analysis/direction_audit-p2.png)



### Figure 5. Predicted-minus-observed target-alignment discrepancies

![Figure 5. fig cca direction differences](assets/analysis/figure-5.png)

[Full PDF](../plot/fig_cca_direction_differences.pdf). Producer: [14_cca_direction_analysis.R](../R/stages/14_cca_direction_analysis.R). [Authoritative method and publication caption](FIGURE_CAPTIONS.md).


## Limitations, questions and validation

The unresolved-question register below is generated from [SCIENTIFIC_DECISIONS.md](SCIENTIFIC_DECISIONS.md#remaining-scientific-questions); that source remains authoritative.

| Question | Current choice | Consequence | Evidence needed to resolve it |
|---|---|---|---|
| Raw versus V2.1-anchored TraCE21k climate | The active Holocene analysis uses raw TraCE21k values; the V2.1 anchoring diagnostic is not authoritative. | Absolute Holocene climate levels and cross-product comparisons may retain product bias, although the active within-series change calculations are internally consistent. | A validated overlap-period comparison showing whether anchoring reduces bias without introducing a discontinuity or changing the intended anomaly interpretation. |
| Legacy-calibration versus full-record climate SDs | Changes are divided by SDs from the 620 pooled legacy CCA calibration plots. | The reference is tied to the fitted model. A full-record SD would change displayed standardized magnitudes, cross-variable weighting, the unthresholded composite, and standardized climate rates, but not CC/S boundaries under the current variable-specific 50%-of-own-maximum rule. | A prespecified full-record sensitivity with explicit temporal/site weighting and a scientific choice between calibration-relative and dataset-relative effect sizes. |
| Anthropocene precipitation windows and CHELSA continuity | The exact MORA and NOCA windows remain 1979–1989 to 2010–2019 and 1979–1989 to 2010–2015, respectively; the MORA precipitation contrast is flagged. | Site contrasts use unequal resurvey windows, and the apparent post-2010 MORA precipitation shift may partly reflect CHELSA inhomogeneity rather than climate. | Independent station/reanalysis validation, alternate endpoint-window sensitivities, and a documented decision on whether post-2010 MORA precipitation is usable. |
| Primary provenance for MORA survey dates | The current plot-year and climate-window conventions are retained, but the cited primary MORA survey-date source is not available in the repository. | Exact modern rate denominators are operationally fixed but not fully traceable to a primary source package. | The original survey metadata or publication supplement linking plots to legacy/resurvey years and confirming the aggregation windows. |
| `CARI449`/`CARI450` coordinate collision | Both plots remain in the 307-plot universe. Their raw longitudes have opposite signs but normalize to the same coordinate; elevations remain 622 and 1,149 m. | Climate extraction assigns the same horizontal location to two strongly separated elevations, and silently excluding or moving either plot would alter the validated universe. | Primary field/GPS records or source-author confirmation identifying the correct longitude/latitude for each plot or supporting a documented exclusion. |
| Own-origin versus common-origin taxon target geometry | The primary target-alignment analysis uses LC₁→species for predicted movement and WA₁→species for observed movement. | The two cosines answer alignment relative to each trajectory's own starting community; part of their difference can arise because LC₁ and WA₁ differ. | A prespecified common-origin sensitivity and an ecological decision about whether the estimand should condition on each starting state or hold the target vector fixed across observed and predicted movement. |

Chronology precision differs among records, paleo occupancy retains site confounding, and MORA/NOCA fire proxies have different spatial support. Climate and fire classifications are independent and aligned descriptively. Overlapping bins, dates, draws and phases are correlated. Product geography, resolution and continuity can affect contrasts. These limitations remain part of interpretation.

All 16 automatic gates passed; protected chronology validated before and after redraw. The report builder checked source availability, PDF page selections, artifact hashes and local links. The chronology manifest was validated, and the four main stems/PDF-only diagnostic contract were checked.

For validation commands and contracts, see [workflow checks](WORKFLOW.md#tests-and-decisions) and the [baseline log](reorganization/baseline-gates.log).


## Diagnostic inventory and artifact provenance

Every diagnostic's purpose, producing script, interpretation and complete PDF is recorded here. Inline previews retain their original PDF page numbers; all main figures preserve manuscript numbering. The older CHELSAcruts comparison appears only in the historical-reference row and is excluded from the current-results narrative.


| Full diagnostic PDF | Purpose | Producer | Inline PDF pages | Interpretation | Status |
| --- | --- | --- | --- | --- | --- |
| [NOCA_cleaning.pdf](../plot/test_figures/NOCA_cleaning.pdf) | Account for the corrected paired-plot cleaning universe. | [000_NOCA_cleaning.R](../R/stages/000_NOCA_cleaning.R) | 1 | The retained cleaning universe is broader than the final modeled pairs. Empty-period records and study exclusions remain explicit. | current |
| [MORA_dynamics.pdf](../plot/test_figures/MORA_dynamics.pdf) | Show species counts before model taxon selection. | [000_MORA_cleaning.R](../R/stages/000_MORA_cleaning.R) | 3 | Counts reflect adult-or-regeneration presence in cleaned survey plots; they do not measure abundance. | current |
| [NOCA_dynamics.pdf](../plot/test_figures/NOCA_dynamics.pdf) | Compare corrected legacy and resurvey species counts. | [000_NOCA_cleaning.R](../R/stages/000_NOCA_cleaning.R) | 3 | Species differences describe cleaned surveys before cross-site harmonization and the CCA threshold. | current |
| [species_counts_consolidated.pdf](../plot/test_figures/species_counts_consolidated.pdf) | Inspect consolidated occurrence counts in each site-period group. | [000_occurrence_data_consolidate.R](../R/stages/000_occurrence_data_consolidate.R) | 1 | Retention requires at least 20 plots or samples in one group. The threshold is not required in every group. | current |
| [stage_adult_seedling_past_present.pdf](../plot/test_figures/stage_adult_seedling_past_present.pdf) | Expose adult versus regeneration support for presence. | [000_occurrence_data_consolidate.R](../R/stages/000_occurrence_data_consolidate.R) | 1 | Adult and regeneration sources contribute to presence; stem counts and macrofossil percentages are not combined as abundance. | current |
| [species_through_time.pdf](../plot/test_figures/species_through_time.pdf) | Inspect taxon site confounding and temporal occupancy. | [test_species_through_time.R](../R/diagnostics/test_species_through_time.R) | 1 | This explicitly retains the 500-year occupancy sensitivity. Sparse sampling is shown; the primary tracking analysis uses 1,000 years. | 500-year sensitivity |
| [fig_bacon_agedepth_slump.pdf](../plot/test_figures/fig_bacon_agedepth_slump.pdf) | Inspect four fitted age-depth models and slump treatment. | [000_PALEO_a_agedepth.R](../R/stages/000_PALEO_a_agedepth.R) | 1 | A report rebuild executes only the existing figure section from stored validated posteriors. Chronology products and controls are hash-protected. | current |
| [fig_bacon_pb210_sensitivity.pdf](../plot/test_figures/fig_bacon_pb210_sensitivity.pdf) | Compare published activity errors with assumed ±10-year age uncertainty. | [000_PALEO_a_agedepth.R](../R/stages/000_PALEO_a_agedepth.R) | 1 | The sensitivity concerns the upper 35–40 cm of Panther Potholes; uncertainty in published fire chronologies is not equivalent across sites. | chronology sensitivity |
| [test_survey_year_anomaly.pdf](../plot/test_figures/test_survey_year_anomaly.pdf) | Compare selected survey windows with the full 1979–2021 record. | [test_survey_year_anomaly.R](../R/diagnostics/test_survey_year_anomaly.R) | 1 | Detrending does not resolve CHELSA product continuity. Apparent precipitation anomalies remain a scientific limitation. | current |
| [climate_holocene_timeseries.pdf](../plot/test_figures/climate_holocene_timeseries.pdf) | Inspect redundancy among candidate climate variables. | [test_climate_change_variables.R](../R/diagnostics/test_climate_change_variables.R) | 2 | Only page 2 (correlations) is inline. Page 1 and associated pace tables retain the former 500-year sensitivity and are not primary rate evidence. | correlation diagnostic; full PDF includes 500-year sensitivity |
| [fig_cca_scaling_comparison.pdf](../plot/test_figures/fig_cca_scaling_comparison.pdf) | Compare scaling 1 and 2 of the same fitted CCA. | [test_cca_scaling_comparison.R](../R/diagnostics/test_cca_scaling_comparison.R) | 1 | The primary geometry stays scaling="sites", Hill off, CCA1–CCA2. Raw target directions, without display multipliers, enter metrics. | current |
| [NOCA_fire_map_Wilson2024_PaleoACES.pdf](../plot/test_figures/NOCA_fire_map_Wilson2024_PaleoACES.pdf) | Audit NOCA modern fire assignment against Wilson reference plots. | [01_get_fire_info.R](../R/stages/01_get_fire_info.R) | 1 | The 305 shared plots agree. The cleaned 307-plot universe is retained; the reference is not substituted for it. | current |
| [fig_fire_event_detection_workflow.pdf](../plot/test_figures/fig_fire_event_detection_workflow.pdf) | Follow interpolation, background, local noise threshold, and count screening. | [12a_fire_event_detection_worked_example.R](../R/stages/12a_fire_event_detection_worked_example.R) | 1, 2, 5 | Pages 1, 2, and 5 show common settings, Sunrise, and Panther Potholes. Core-specific temporal settings remain explicit; accepted events precede high-fire classification. | current |
| [fig_walsh_charanalysis_reproduction.pdf](../plot/test_figures/fig_walsh_charanalysis_reproduction.pdf) | Compare official CharAnalysis results with published Walsh totals. | [12_walsh_fire_reproduction.R](../R/stages/12_walsh_fire_reproduction.R) | 3 | The discrepancy is retained without tuning; this software audit does not overwrite the primary all-tapas event catalog. | current |
| [fig_holocene_climate_period_method_worked_example.pdf](../plot/test_figures/fig_holocene_climate_period_method_worked_example.pdf) | Expose signed changes, phase support, and era construction. | [13_holocene_climate_fire_eras.R](../R/stages/13_holocene_climate_fire_eras.R) | 1 | Any qualifying variable creates a climate-change cell. Only adjacent cells merge; the unsigned composite is context. | current |
| [fig_holocene_fire_method_worked_example.pdf](../plot/test_figures/fig_holocene_fire_method_worked_example.pdf) | Work through centered event frequencies at 2,300 cal BP. | [13b_fire_method_worked_example.R](../R/stages/13b_fire_method_worked_example.R) | 1 | Within-core normalization and site-specific robust thresholds yield MORA high fire and NOCA no high fire for the worked date. | current |
| [fig_method_worked_example.pdf](../plot/test_figures/fig_method_worked_example.pdf) | Work through WA/LC movement, lag, ratio, and angle. | [09a_method_example.R](../R/stages/09a_method_example.R) | 1 | Lag change is endpoint mismatch at t2 minus t1; a stationary observed movement has no defined direction. | current |
| [fig_cca_direction_differences_audit.pdf](../plot/test_figures/fig_cca_direction_differences_audit.pdf) | Inspect distributions and support beneath the Figure 5 heatmap. | [14_cca_direction_analysis.R](../R/stages/14_cca_direction_analysis.R) | 1, 2 | The paired target discrepancy uses each trajectory's own origin. Quartiles are descriptive; small groups are retained rather than interpreted as precise estimates. | current |
| [test_chelsa_cruts_vs_present.pdf](../plot/test_figures/test_chelsa_cruts_vs_present.pdf) | Retain the older product-comparison reference outside current results. | [test_chelsa_cruts_vs_present.R](../R/diagnostics/test_chelsa_cruts_vs_present.R) | Full PDF only | This historical comparison used older product/window assumptions. It is excluded from current evidence and never refreshed by --report. | historical reference |



[Artifact ledger](assets/analysis/artifacts.csv) records producer/source/output SHA-256 hashes, selected PDF pages, build mode and provenance status. [Input fingerprints](assets/analysis/inputs.csv), [source fingerprints](assets/analysis/sources.csv), [result fingerprints](assets/analysis/results.csv), and [build metadata](assets/analysis/build.json) preserve the evidence snapshot without publishing raw research files. Original paths and relocation hashes are in the [relocation map](reorganization/relocation_map.csv). Each fresh producer output is checked against this workflow run; the builder accepts no missing or stale current output. The historical CHELSA comparison is separately labeled and stored chronology provenance remains unchanged.


To regenerate the complete analysis and report from validated native caches:

```bash
Rscript R/workflow.R --offline --report
```

The report is published only after generation and validation succeed. Invalid offline caches cause an explicit failure before network access. A plain Git checkout can read this review, its self-contained HTML, previews, curated tables and linked PDFs without local raw data; rerunning the analysis requires the documented local research inputs and installed packages.
