---
title: "PaleoACES analysis review"
---

{{build_status}}

PaleoACES asks how observed forest composition moves relative to the composition
predicted by climate, comparing modern forest resurveys with four Holocene
records. This review follows the [workflow](WORKFLOW.md), showing preparation,
methods, diagnostics and manuscript figures. [Scientific decisions](SCIENTIFIC_DECISIONS.md)
records the adopted choices.

## Study design and inputs

Mount Rainier (MORA) and North Cascades (NOCA) share one CCA calibrated on legacy
forest plots. Resurveys and dated plant-macrofossil samples are projected into
that ordination. MORA's Holocene vegetation comes from Jay Bath, Log Wallow and
Reflection Pond; NOCA's comes from Panther Potholes. MORA fire evidence comes
from Sunrise, Shadow and Little Sunrise lakes, while NOCA charcoal comes from
Panther Potholes. Vegetation and fire therefore have different spatial support.

The [input inventory](REPOSITORY_INVENTORY.md#raw-duplicates-and-authority),
[MORA data notes](../data/MORA/README_data_raw.md), [NOCA paleo notes](../data/NOCA/NOCA_paleo/SOURCES.md)
and [chronology sources](../Cores/SOURCES_MORA.md) identify the source materials.

![Analysis flow, associated scripts and manuscript figures](assets/analysis/dependencies.png)

The arrows show dependencies. The table below gives the exact execution order,
including figure production; figure numbers retain their manuscript meaning.
The [combined script](review/00_main_analysis_review.R) contains these stages
verbatim for reading. Run the workflow for an analysis rebuild.

{{workflow_scripts}}

{{cleaning_summary}}

## Modern vegetation preparation

Presence means an adult **or** regeneration record. MORA uses the original legacy
workbook and cleaned resurvey tree and seedling files. NOCA applies the received
corrected-tree workbook before building occurrences; unsupported identification
labels are discarded. Both cleaners retain matched survey plots.

**MORA's adult resurvey date is authoritative (decision 2026-10-07).** Seedling
records are assigned to their corresponding adult visit before presence is
constructed. For the 13 plots visited in multiple years, only the latest adult
visit and its matching seedlings are retained; visits tied within a year remain
pooled. This replaces pooling across years and using the earliest tree/seedling
year. The received CSVs are preserved.

The source-year comparison identifies 95 supplied plot names, including 48 analyzed
pairs. That total includes `PRAC-1`, a practice plot without a standardized ID;
94 have standardized IDs. Conflicting years already occur in the original CSVs
and pass unchanged through their upstream cleaner. The earlier export process
is unknown. The [95-plot source table](assets/analysis/tables/year_source_discrepancies.csv)
records the conflicting years, adult dates, treatment and evidence locations;
[survey-year notes](../data/SOURCES_SURVEY_YEARS.md) give the rationale.

{{mora_repeat_visits}}


NOCA excludes `BAK487` for its old clearcut, `BEAV6061` for uncertain relocation,
and `CARI449`/`CARI450` for GPS problems. The latter share coordinates despite
conflicting elevations, and Rachel's notes supply no verified correction.
These exclusions apply to both dates. The cleaned NOCA data contain 305 pairs;
CCA eligibility is assessed later. The [cleaning guide](review/000_NOCA_cleaning_guide.md)
and [GPS source note](review/NOCA_GPS_EXCLUSION.md) explain the decisions.

{{correction_summary}}

{{vegetation_diagnostics}}

## Modern fire assignments

Mapped disturbance records identify fire exposure for the paired modern plots.
NOCA has 32 burned and 273 unburned plots, with matching assignments on all 303
plots shared with Wilson's reference. MORA's mapped record covers 1987–2017,
so no mapped fire does not establish that a plot remained unburned throughout
the full survey interval.

{{modern_fire_diagnostics}}

## Modern climate preparation

CHELSA V2.1 monthly values supply spring temperature (MSpT), winter temperature
(MWT), summer precipitation (SP) and winter precipitation (WP). Temperature is
the midpoint of monthly minima and maxima, then averaged over the season;
precipitation is summed. These are seasonal climate proxies, not direct measures
of growing degree days, soil moisture or snowpack.

Spring is March–May, summer June–August and winter December–February. Modern
December belongs to the following winter. All three months are required;
temperatures are in °C and precipitation in mm per season.

**Climate-year selection.** Historical climate remains **1979–1989** at both
sites. Each modern plot uses its adult resurvey year **Y** and the five preceding
years: **Y−5 through Y, inclusive**. We average these six years to represent the
interannual climate dynamics that the community experienced before and during
the survey. A 2014 resurvey therefore uses 2009–2014, with December 2008 included
in winter 2009. Every modern constraint requires six complete season-years.

Climate rates use the interval from the historical midpoint **1984** to the
plot-specific modern midpoint **Y−2.5**: **27.5–32.5 years at MORA** and
**27.5–28.5 years at NOCA**. Vegetation rates use the selected adult year and
legacy references of 1977.5 (MORA) or 1983 (NOCA). Missing January 1979 leaves ten
complete legacy winters; spring and summer retain eleven years. The historical
window choice remains settled, and possible MORA precipitation inhomogeneity
remains a limitation.

{{climate_windows}}

The following cohorts and diagnostic use the final paired comparison plots.
The annual lines show those same plots; separate colored bands show each cohort's
window without hiding overlapping windows. MORA is blue and NOCA orange.

{{survey_climate_windows}}

{{modern_climate_diagnostics}}

## Chronology and uncertainty

The existing stored Bacon models are retained. Each primary original sample receives
its **unrounded median age over all stored posterior rows**, not the median of a
selected draw subset. Original sample identities do not depend on estimated ages.

The sensitivity uses 1,000 reproducibly selected complete posterior chronologies per
lake. One selected posterior row supplies all sample and NOCA fire-event ages within
that lake. No MCMC or CCA recalibration is performed. MORA regional charcoal chronologies
remain fixed. Primary confidence intervals are conditional on the primary reconstruction;
separate refits examine changes in coefficient direction, magnitude and statistical support.

{{chronology_diagnostics}}

## Paleo vegetation and fire preparation

Taxonomic categories are harmonized within original samples. Separate depths and
Neotoma sample IDs remain separate even when their posterior median ages coincide.
Samples with no retained taxa remain in the exclusion audit and have no WA position.
Accepted charcoal-event detection and its descriptive products remain unchanged.
The ecological exposure uses whole vegetation-transition durations and coherent NOCA redating.

## Paleo climate preparation

CHELSA-TraCE21k supplies climate at the four pond locations. Each vegetation
sample is matched to the available climate slice nearest its own age, within
the 50-year tolerance. The seasonal variables and units match the modern
analysis; December remains within its paleo climatology slice.

Raw TraCE21k is the current input. A V2.1-based correction is planned as a
sensitivity and has not been applied. The comparison at the end of this review
shows the available recent overlap and its different averaging windows.

{{paleo_climate_diagnostics}}

Only the correlation page is shown here. The full climate diagnostic also
contains older **500-year sensitivity** calculations; those are separate from
primary climate-rate results.

## Accepted fire events

The accepted-event catalog uses the shared tapas detector with core-specific
interpolation, background smoothing and local thresholds. All cores use
unlogged charcoal accumulation, robust LOWESS background, a local Gaussian-mixture
threshold and a 75-year count screen with p ≤ 0.05. Accepted totals are 17
Sunrise, 14 Shadow, 13 Little Sunrise and 66 Panther Potholes. The existing
12.5-year NOCA interpolation sensitivity yields 72 events.

{{fire_settings}}

{{event_audit}}

The official CharAnalysis comparison is separate from the primary catalog.
Its discrepancy with Walsh's publication is retained without threshold tuning.

{{walsh_audit}}

{{fire_audit_diagnostics}}

{{fire_detection_diagnostics}}

## Taxonomy and species selection

[Consolidation](review/README_occurrence_consolidation.md) aligns Populus,
Picea and Abies identifications across surveys and macrofossils. Acer circinatum
and Taxus brevifolia are removed for stratum compatibility. Pinus ponderosa's
manual exclusion was [reversed on 2026-10-08](SCIENTIFIC_DECISIONS.md#ponderosa-reinstatement);
it is now retained and follows the ordinary frequency rule below.

CCA retains a taxon when it occurs in **at least 20 plots or samples in any one
site × period group**. The rule does not require 20 in every group. Pinus
albicaulis reaches exactly 20 and remains included. Selection rests on taxon
relevance and ordination interpretation; increased explained inertia alone is
not its justification. The existing selected taxa and matched-legacy calibration are frozen during this migration;
new paleo identities affect projection records and diagnostics, not calibration.

{{cca_taxa}}

NOCA size classes differ between dates: legacy regeneration spans 0–3 m and
adults exceed 3 m; resurvey seedlings span 10–140 cm and trees exceed 1.4 m.
These strata are not identical measurements across surveys.

{{taxonomy_diagnostics}}

The occupancy display uses original samples placed on the native 100-year grid.

## Plots and samples included in CCA

The following diagram starts with the supplied survey lists and core sample
depths. It shows losses during matching and cleaning, then the species and
climate checks required for CCA. The starting legacy and resurvey counts are
separate; their exclusions must not be added together. Original sample identities are retained when median ages coincide.

{{selection_diagnostics}}

The [counts at each step](assets/analysis/tables/sample_selection_counts.csv)
and [choices affecting records](assets/analysis/tables/sample_selection_choices.csv)
are available as tables.

The diagram also shows the [legacy adult-tree plot sizes](assets/analysis/tables/sample_selection_plot_sizes.csv)
among the plots retained for CCA. Adult-tree resurvey plots cover **500 m² at both
sites**. Legacy areas vary, so matching plot identities does not mean that the
sampled areas were equal. Plot size currently does not determine eligibility.

Choices such as correcting tree records and keeping the latest adult visit
change the observations without necessarily removing plots. They are shown
alongside the count changes. All current CCA climate values are complete.
The two burned MORA plots remain in CCA and in the canonical 607-plot tracking table.

[04_cca_model.R](../R/stages/04_cca_model.R) resolves eligibility **before fitting
or projecting**. An observation with no retained taxa has no observed WA
position. It is excluded from both observed and climate-predicted comparisons.
Modern endpoints use the same eligible pairs at both dates; Holocene WA and LC
positions also use identical samples. The CCA is fitted on the legacy observations
of these same matched plots; a plot excluded at resurvey is also excluded from
calibration. The diagram's final modern counts therefore serve both fitting and
comparison.

{{cca_eligibility_counts}}

Exclusion reasons are separated below. Each modern pair is counted once,
against its first failing endpoint, with legacy checked first. Calibration and
paired-comparison counts overlap and must not be added together. Holocene
counts are samples before age draws or temporal binning.

{{cca_exclusion_summary}}

“Loss of all recorded tree-taxon presence at resurvey” describes absence in the
sampled taxa and strata, not proven biological extinction. “No tree taxa detected
in paleo sample” describes macrofossil non-detection. Cases holding only taxa
removed during consolidation or CCA selection are listed separately. Missing
climate and unmatched endpoints are also classified if encountered.

The [sample table](assets/analysis/tables/cca_sample_eligibility.csv) and
[paired-plot table](assets/analysis/tables/cca_pair_eligibility.csv) retain the
individual reasons. The cleaned data retain these observations even when they
cannot enter CCA tracking.

## Holocene sampling support on native climate intervals

The pre-CCA diagnostic places every original macrofossil sample once at its unrounded
full-posterior median Bacon age, including samples subsequently excluded from WA projection.
Macrofossil lakes remain distinguished with the same MORA/NOCA count scale. Fire panels
show accepted-event totals by park; MORA regional cores are combined, not plotted as separate
vegetation lakes. Covered zero-event cells remain zero and missing coverage breaks the line.
These descriptive counts use native climate intervals and are not transition-model observations.

{{sampling_support_diagnostics}}

## CCA calibration and geometry

One pooled legacy CCA relates composition to the four climate variables, using
the same matched plots used in both-date comparisons (330 MORA and 277 NOCA).
This matched calibration was selected on 2026-10-08; the former fit used 619
eligible legacy plots. The ≥20 species-selection rule and 14 taxa are unchanged.
Observed **weighted-average (WA)** scores describe composition; predicted
**linear-combination (LC)** scores describe the position expected from climate.
Modern resurveys and paleo samples enter the existing ordination without
recalibrating it.

{{cca_summary}}

{{cca_counts}}

CCA1–CCA2 and site scaling (1), with Hill scaling off, define all distances and
angles. Display arrow multipliers do not enter calculations. Binary presence
still carries CCA's row and taxon weighting. The displayed axes represent only
part of total community inertia, and correlated climate variables prevent
adding their marginal contributions as independent shares. Projections are
descriptive scores rather than independently validated forecasts.

{{cca_diagnostics}}

### CCA model, contributions and tests

The model below is fitted to the **607 matched legacy plots and 14 retained
tree species**. Species values are binary presence, combining adults and
regeneration. The climate rows use those same plots in the same order.
`MSpT` is spring temperature, `MWT` winter temperature, `SP` summer precipitation
and `WP` winter precipitation. The fitting and resurvey-projection lines are
copied from [04_cca_model.R](../R/stages/04_cca_model.R), with the current scaling
settings shown explicitly.

The [calibration reference bundle](assets/analysis/cca_calibration_reference.rds)
preserves the fitted CCA, calibration matrices and identities, species and
climate scores, scaling, prepared endpoints and provenance for future work.

{{cca_model_code}}

**Fitted model output.** Inertia measures variation in community composition;
the constrained part is the variation explained by these climate variables.

{{cca_model_output}}

{{cca_axes}}

**Permutation ANOVA.** The overall test assesses the four climate variables
together. Axis tests assess each axis after accounting for preceding axes.
All reported tests use **9,999 permutations**, with seed `20261008`.
Unrestricted permutations shuffle plots across the whole calibration set;
within-park permutations shuffle plots within MORA and NOCA separately.
Neither design accounts for finer spatial dependence among plots. These are
tests of association, rather than predictive validation. See the
[vegan ANOVA methods](https://vegandevs.github.io/vegan/reference/anova.cca.html).

{{cca_anova}}

{{cca_axis_interpretation}}

[Complete ANOVA output](assets/analysis/cca_anova_output.txt) includes residual
degrees of freedom and all overall, axis and climate-variable tests.
These calculations are reproduced by [the reporting functions](../R/helpers/analysis_report.R).

**Species contributions.** Each percentage is a species' contribution to the
total climate-explained inertia, across all four constrained axes. These
contributions sum to 100% and match the species bars in Figure 3. The score
columns describe position on CCA1–CCA2; distance from the origin is a different
quantity from contribution. See [vegan's inertia decomposition](https://vegandevs.github.io/vegan/reference/goodness.cca.html).

{{cca_species_contributions}}

**Climate contributions and tests.** Each percentage is the inertia lost when
that variable is removed while the other three remain, divided by the full
model's climate-explained inertia. These are the unique effects shown in Figure 3;
they do not sum to 100% because the predictors are correlated. Their tests use
`anova(..., by = "margin")`. VIF describes predictor overlap: larger values mean
stronger collinearity, limiting separate interpretation of climate variables.

{{cca_climate_contributions}}

{{cca_climate_interpretation}}

The existing tracking calculations use CCA1–CCA2. These tests describe the
fitted model; they do not change the selected axes or the analysis settings.

## Climate eras and high-fire periods

Climate eras are defined independently of vegetation, fire and literature.
Signed 1,000-year changes are divided by legacy-calibration standard deviations;
MORA lakes are averaged first, then MORA and NOCA receive equal regional weight.
A variable qualifies at 50% of its own maximum absolute regional median, with
at least eight of ten offsets supporting its direction. Any qualifying variable
marks climate change; adjacent cells merge into eras. The unsigned four-variable
composite provides context, rather than defining a boundary. Complete offset
support spans 9.6–1.3 ka.

{{era_catalog}}

High-fire periods are defined independently from centered 1,000-year event
frequencies. Each core is normalized by its own maximum; MORA averages covered
cores equally and requires at least two. A site's frequency must exceed its
median plus 1.4826 × MAD. Above-threshold periods are retained without bridging
coverage gaps. Five MORA and six NOCA high-fire periods result. These categories
use fixed median event chronologies, without propagating event-timing uncertainty.

{{fire_eras_diagnostics}}

## Tracking calculations

One primary reconstructed series is built for each lake. Original samples are projected
through the fixed CCA before sample WA coordinates are averaged within their own native
CHELSA cells, `[lower, upper)`. Occupied cell centers currently end in 50 cal BP.
Consecutive occupied centuries are connected, including gaps; vegetation is never interpolated.
Both endpoint climate records belong to that lake. All Holocene rates use the actual elapsed
time, `age_hi - age_lo`, and response validity is handled independently.

Primary support counts describe actual endpoint samples. Chronology occupancy is diagnostic,
with no authorized occupancy or joint-support exclusion threshold. The physical climate-rate
index uses changes in MSpT, MWT, SP and WP divided by their fixed pooled legacy SDs, then
combined by Euclidean norm and multiplied by 100/elapsed years. It is separate from LC movement.

Fire exposure counts accepted events over `[age_lo, age_hi)`. Each fully covered core contributes
`events × 100 / elapsed years`. MORA averages at least two fully covered regional cores equally;
NOCA requires complete Panther Potholes coverage. Covered zeros remain zero and inadequate
coverage remains NA. The unit is events per century per eligible core. This differs from the
unchanged normalized 1,000-year fire measure used in descriptive climate/fire-period comparisons.

{{lake_support}}

{{tracking_metrics_code}}

{{latest_visit_composition_effects}}

{{survey_decision_effects}}

## Community trajectories

Figure 3 retains its layout and modern paths. Holocene period centroids first average primary
occupied centuries within lake/period, then average available lakes equally. Period membership
uses the unchanged CC/S catalog boundaries. Missing lake/period coverage is not manufactured.
The fitted species/climate panels remain based on the unchanged CCA.

{{modern_centroids}}

{{era_centroids}}

{{figure_3}}

## Tracking example and actual-transition displays

The worked example uses one primary actual transition. Temporal displays show actual transition
midpoints and spans with matching climate and fire exposure. Both tracking ratios remain in the
tables; their identical Holocene values need only one display. Modern fire activity is unavailable
as a continuous charcoal measure; original binary burned assignments remain available.

{{tracking_diagnostics}}

{{raw_climate_rates}}

{{figure_2}}

## Primary models and residual covariance comparisons

Primary, Bacon sensitivity and lake-check results use separate folders. Metric-specific figures
are consolidated into multipage PDFs by purpose, with one labeled response per page.

{{tracking_result_guide}}

### Residual covariance comparison

Combined-era models use `estimate ~ era * site` and separate residual variances by era/site.
Modern plots are singleton series. Applicable Holocene models compare independent residuals,
neighboring-transition MA(1), and continuous-time AR(1). Transition indices are assigned before
exclusions; gaps are not renumbered. Continuous-time correlation uses actual midpoints in centuries.
Compare REML AIC only on identical rows and fixed effects. **MA(1) is the primary covariance
for every model containing Holocene observations**, as explicitly retained by the user.
Independent and CAR1 are comparison diagnostics only; AIC recommendations never replace
MA(1). Failed fits and boundary/covariance warnings remain in the result tables.
Modern-only models retain independent residuals.

{{predictor_model_code}}

### Observed lag change

{{tracking_covariance_diagnostics}}
{{tracking_groups_diagnostics}}
{{tracking_models_diagnostics}}
{{tracking_model_checks_diagnostics}}
{{tracking_model_results}}
{{tracking_lake_diagnostics}}
{{tracking_lake_results}}

### Community turnover

{{turnover_covariance_diagnostics}}
{{turnover_groups_diagnostics}}
{{turnover_models_diagnostics}}
{{turnover_model_checks_diagnostics}}
{{turnover_model_results}}
{{turnover_lake_diagnostics}}
{{turnover_lake_results}}

### Standardized climate-change rate

{{climate_covariance_diagnostics}}
{{climate_groups_diagnostics}}
{{climate_models_diagnostics}}
{{climate_model_checks_diagnostics}}
{{climate_model_results}}
{{climate_lake_diagnostics}}
{{climate_lake_results}}

### Corrected lag-change rates

{{pace_covariance_diagnostics}}
{{pace_groups_diagnostics}}
{{pace_models_diagnostics}}
{{pace_checks_diagnostics}}
{{pace_model_results}}
{{pace_lake_diagnostics}}
{{pace_lake_results}}
{{direction_covariance_diagnostics}}
{{direction_groups_diagnostics}}
{{direction_models_diagnostics}}
{{direction_checks_diagnostics}}
{{direction_model_results}}
{{direction_lake_diagnostics}}
{{direction_lake_results}}

## Manuscript comparison from the primary reconstruction

Raw distributions, fitted means and era contrasts refer to the primary reconstruction and selected
models. Corrected-lag contrasts remain a separate figure. Scatterplots retain separate era scales,
Spearman coefficients and p-values, and the gray 1:1 reference. Significance styling uses conditional
model contrasts. Signed lag ratios are descriptive annotations and can be unstable near a zero mean.

{{figure_4}}
{{tracking_corrected_contrasts_diagnostics}}

## Within-era climate, fire and elevation predictor models

Primary Holocene explanatory models fit observed and the two corrected lag-change rates against
`site + climate_rate + fire_activity`, with site-specific residual variances and selected covariance.
Primary Anthropocene basic models use `site + burned`; extended community models also include
`elevation + climate_rate`. Responses remain untransformed. Modern-only models retain independent residuals.

The lake random-intercept sensitivity uses the same primary observations and selected covariance.
Its actual variance, coefficient changes and covariance-interval status are reported below; the older
near-zero variance result is not assumed to recur.

{{predictor_random_sensitivity}}
{{predictor_predictions_diagnostics}}
{{predictor_focal_performance}}
{{predictor_performance_diagnostics}}
{{predictor_era_diagnostics}}
{{predictor_residuals_diagnostics}}
{{predictor_model_results}}

### Whole-chronology reconstruction sensitivity

Each of 1,000 complete chronologies constructs its own occupied cells, transitions and endpoint
climate/fire exposures. The same explanatory model is refitted, retaining the primary MA(1)
covariance family while reestimating covariance parameters. Combined-era models, lake comparisons,
random-intercept diagnostics and standalone modern models are primary-only.

Sensitivity quantiles describe the distribution of reconstruction-specific coefficient estimates;
they are not conventional confidence intervals or posterior probabilities. The primary coefficient
and its conditional confidence interval remain the reported primary result. There is no averaging
of primary coefficients, pooling of p-values, R² weighting or uncertainty reduction by √1,000.
Successful-fit and valid-interval denominators, sign agreement, magnitude ranges, interval-conclusion
agreement, transition counts/durations, coverage losses and failures are retained explicitly.

The temporal-range figure shows 50% and 95% ranges across complete Bacon reconstructions,
with the primary reconstruction retained as solid transition spans. Each draw's own
transition-average rate or fire exposure is mapped only over that transition's actual duration.
Vegetation is not interpolated. The bottom panels show transition and valid fire-exposure availability;
finite-draw denominators and all quantiles are retained in the
[temporal range audit](assets/analysis/tables/chronology_temporal_ranges.csv).

{{chronology_summary}}
{{predictor_chronology_diagnostics}}

## Species and seasonal climate contributions

Species vectors use changes in mean normalized sample weights and fixed species coordinates.
They sum exactly to delta WA before projections and rates. Species parallel contributions are
signed along delta LC and expressed per century. Seasonal climate-variable vectors are one-variable
LC perturbations; their sum equals delta LC, and their projections along delta WA retain displacement
units. Undefined directions stay NA. Perpendicular contributions remain retired.

Boxplots use one primary transition per species/variable and one modern pair, without flattening
chronology reconstructions into observations. The same conservation checks run within each draw.
These distributions describe differences among actual transitions, rather than uncertainty across
offsets or Bacon draws. Climate displacements retain their actual, variable-duration endpoints.

{{contributions_diagnostics}}

Stage 17 fits Holocene species rates with `site + climate_rate + fire_activity`, using the shared
covariance comparison. Anthropocene species use `site + burned` only. Constant or rank-deficient
models and numerical failures are reported explicitly; zeros are retained. A constant response
within a variance group can produce no finite heteroscedastic Gaussian optimum.

{{species_selection}}
{{species_models_diagnostics}}
{{species_chronology_diagnostics}}
{{predictor_tables}}

## Limitations and remaining questions

The chronology controls, survey windows, GPS exclusions and paired CCA
eligibility are settled for this analysis. Their interpretation limits remain:
conditional dating uncertainty, differing fire-proxy support, unequal survey
size classes, site-confounded paleo occupancy, overlapping temporal samples
and possible climate-product discontinuities.

The remaining questions below come from the
[scientific decision register](SCIENTIFIC_DECISIONS.md#remaining-scientific-questions).
They distinguish planned or optional sensitivities from decisions already made.

{{questions}}

{{validation}}

## Diagnostic PDFs

The selected pages above show the relevant evidence; these links open the full
figures. The older CHELSAcruts comparison is a historical reference, outside the
current-results analysis.

{{diagnostic_inventory}}

## TraCE21k–V2.1 comparison and planned sensitivity

[Climate-product comparison PDF (two pages)](review/chelsa_trace_v21/TraCE21k_vs_V21_1980_1990.pdf).

![Monthly climate comparison: TraCE21k 1900–1990 versus V2.1 1980–1990 at the same pond locations — PDF page 1](review/chelsa_trace_v21/monthly_comparison-p1.png)

This supplementary snapshot was prepared on 2026-10-07 from existing native caches at the same four pond locations. It compares the final TraCE21k slice's **1900–1990 climatology** with **V2.1 monthly averages for 1980–1990**. MORA averages its three ponds equally; NOCA uses Panther Potholes. The averaging periods differ, so the comparison describes climate levels and seasonality rather than matched annual changes or an isolated estimate of model bias.

**Planned sensitivity — not yet performed:** Apply temperature offsets and precipitation correction factors to TraCE21k, then compare climate-change metrics, climate-predicted vegetation trajectories, Δlag and main conclusions with the current raw-TraCE21k results. Document the correction reference and factors explicitly. The current analysis remains unchanged; this comparison does not apply a correction or constitute the sensitivity analysis.
