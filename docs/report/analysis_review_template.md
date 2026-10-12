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
contributions sum to 100% and determine the species arrow and annotation colors in Figure 3A. The score
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

Figure 3 places **A, the species/climate biplot**, beside **B, the trajectory projections**
in a wider, two-panel layout. Panel A labels all 14 taxa, including those near the origin.
Species names give occurrence percentages across the 607 calibration plots; arrow and
annotation colors encode each species' share of total constrained inertia. Climate arrow
and annotation colors encode unique marginal percentages of that same denominator.
A blue–purple–orange gradient uses the manuscript park colors as its endpoints; exact
inertia percentages remain in the tables rather than beside the arrows. Species shares sum to 100%; climate unique
effects do not partition the total because predictors share explanatory variation. The tables above retain all exact values from
the former contribution bars. Climate arrows retain their common display multiplier;
arrow length is not the inertia color statistic.

Panel B is zoomed to the trajectories, with the calibration cloud cropped only for display.
Observed paths retain park colors; predicted paths and annotations use lighter, fully opaque
versions of those colors. The observed/predicted arrow legend remains dark/light grey.
Jointly placed direct labels and time annotations use leader lines to reduce collisions.

Holocene period centroids first average primary
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

### Pace and direction correction effects

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

### Joint pace/direction correction model

The separate response models above remain intact. The additional joint model includes
**pace and direction correction effects only**, with all era × park × correction interactions:

```r
fit_joint = nlme::gls(
  estimate ~ era * site * correction,
  correlation = corPairedMA1(form = ~ time_index | series),
  weights = nlme::varIdent(form = ~ 1 | era_site_correction),
  data = paired_corrections,
  method = "REML"
)
```

`corPairedMA1()` is the validated shared correlation helper. Its temporal part is MA(1)
on the original transition indices; its outcome part allows the two corrections on the
same transition to correlate, separately by era/park. Their product defines the full
within-series correlation. Modern plots have two outcomes but one time point each.
Separate residual SDs apply to the eight era/park/correction groups. Stacking the two
corrections as independent observations would give incorrect contrast uncertainty.

Only transitions with both corrections defined enter: 185 Holocene transitions
(78 MORA, 107 NOCA) and 465 modern pairs (254 MORA, 211 NOCA), giving 1,300 response rows.
No values are imputed and temporal indices are not renumbered. These paired fitted means
can differ from separate-model means, which retain each response's own eligible records.
This joint model is primary-only. Convergence, boundary estimates and covariance uncertainty
are reported with the current fit below.

{{joint_correction_comparison_summary}}

Differences are **Direction − Pace**, in CCA distance per century. P-values are Holm-adjusted
across the four within-era/park comparisons; intervals are unadjusted conditional 95% intervals.
Current estimates and significance appear in the table above; they are refitted to correction
effects, not copied from the retired corrected-lag responses. Correction-by-era interaction
p-values use their own Holm family of two park comparisons. Positive effects mean the
correction reduces final lag; a positive Direction − Pace contrast means the direction
correction provides the larger reduction.

[Joint coefficients](assets/analysis/tables/joint_correction_model_coefficients.csv),
[fitted means](assets/analysis/tables/joint_correction_model_group_means.csv),
[correction comparisons](assets/analysis/tables/joint_correction_correction_contrasts.csv),
[era comparisons](assets/analysis/tables/joint_correction_era_contrasts.csv),
[correction-by-era interactions](assets/analysis/tables/joint_correction_correction_by_era_contrasts.csv),
[displayed mean tests against zero](assets/analysis/tables/joint_correction_displayed_mean_zero_tests.csv),
[matched input](assets/analysis/tables/joint_correction_model_input.csv), and
[excluded unmatched records](assets/analysis/tables/joint_correction_model_exclusions.csv).

{{joint_correction_results}}
{{joint_correction_diagnostics}}

## Manuscript comparison from the primary reconstruction

Figure 4 has four labeled sections: **A**, standardized climate era contrasts;
**B**, community-turnover and observed-lag era contrasts; **C**, Holocene lag distributions;
**D**, Anthropocene lag distributions. Panels C/D have MORA and NOCA on the x-axis and their
own era-specific scales. The y-axis is **CCA distance per century**. The legend identifies
**Observed lag-change rate** (green), **Pace correction effect rate** (pink), and
**Direction correction effect rate** (purple). Filled small dots and capped error bars show fitted means and conditional
95% Satterthwaite intervals. Large signed numerical annotations label the means to three decimals.

Observed violins and means use the existing observed-response model and all its eligible
records (211 Holocene transitions, 607 modern pairs). Correction-effect violins and means use the
new joint model's complete paired records; observed is **not** a third joint-model level.
Each input observation enters once within its displayed response.

Stars on mean labels test whether that mean differs from **zero**, using unadjusted two-sided
Satterthwaite t tests: * p < 0.05, ** p < 0.01, *** p < 0.001. Non-significant mean points,
intervals and labels are faded; transparency has no legend entry. Brackets compare
**direction minus pace**, and are shown only where their Holm-adjusted comparison is significant;
the bracket labels report the difference, stars and adjusted p-value. These are different tests:
a direction-effect mean can differ from zero even if its difference from pace is unsupported.

The correction-effect responses are existing geometric quantities:

- `pace_effect_on_lag_per_century = (observed final lag − pace-corrected final lag) × 100 / elapsed climate years`.
- `direction_effect_on_lag_per_century = (observed final lag − direction-corrected final lag) × 100 / elapsed climate years`.

Thus positive means indicate a lag reduction from the correction, negative means indicate a
lag increase, and zero indicates no effect. These are different from corrected lag-change
rates measured relative to initial lag. Both effects are independently verified from endpoints,
and undefined counterfactual directions remain excluded only for the affected response.

Correction-effect era contrasts from the separate models remain a separate figure.
The top-row climate, turnover and observed-lag contrasts retain their original definitions.
Signed fitted-mean ratios are descriptive and can be unstable near a zero mean.

{{figure_4}}
{{tracking_corrected_contrasts_diagnostics}}

## Within-era climate, fire and elevation predictor models

Primary Holocene explanatory models fit observed lag-change rate and the two correction-effect rates against
`site + climate_rate + fire_activity`, with site-specific residual variances and selected covariance.
Primary Anthropocene basic models use `site + burned`; extended community models also include
`elevation + climate_rate`. Responses remain untransformed. Modern-only models retain independent residuals.

The main coefficient figure compares **Holocene** and **Anthropocene** predictor effects on
**observed lag-change rate**, **pace correction effect** and **direction correction effect**,
shown in green, pink and purple respectively.
The site coefficient is **NOCA − MORA**. These additive models have shared climate/fire slopes
across parks, so the figure does not present duplicated slopes as separate park estimates.
Holocene fire is the effect of one additional event per century per eligible core;
Anthropocene fire is **burned − unburned**. The Anthropocene main figure uses `site + burned`.
Intercepts are omitted, and conditional 95% intervals accompany the coefficients.
Each era's caption gives each response model's descriptive R² (`1 − SSE/SST`); negative values
are retained because GLS minimizes a covariance-weighted criterion rather than ordinary SSE.
The eras have separate coefficient-axis scales. Coefficients refer to their stated predictor
increments, not standardized effect sizes.

{{figure_5}}

### Appendix: extended Anthropocene coefficients

The `site + elevation + climate_rate + burned` model remains fitted and reported as an
appendix analysis. Its separate figure omits intercepts and shows elevation effects per
100 m for readability, without changing the fitted model or its original coefficient table.
Its caption gives the three extended-model R² values.

{{predictor_appendix_diagnostics}}

### Model diagnostics and lake sensitivity

The lake random-intercept sensitivity uses the same primary observations and selected covariance.
Its actual variance, coefficient changes and covariance-interval status are reported below; the older
near-zero variance result is not assumed to recur.

{{predictor_random_sensitivity}}
{{predictor_predictions_diagnostics}}
{{predictor_focal_performance}}
{{predictor_performance_diagnostics}}
{{predictor_residuals_diagnostics}}
{{predictor_model_results}}

Bacon model sensitivity is **on hold for both community and species models** and omitted
from the active review. The code and saved checkpoints are retained for a later rerun;
normal workflow and standalone model-stage runs do not execute these sensitivities.
The reported coefficients and intervals condition on the primary median-age reconstruction;
they do not additionally propagate chronology uncertainty. Stored Bacon chronologies remain
unchanged and continue to supply the primary sample median ages.

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

Stage 17 fits species models **separately within MORA and NOCA**. Holocene species rates use
`climate_rate + fire_activity`, with primary MA(1) covariance and Independent/CAR1 comparisons.
Anthropocene MORA species use intercept-only models (`contribution_rate ~ 1`).
Anthropocene NOCA species use `contribution_rate ~ burned` with unburned as the reference.
Both modern specifications use independent residuals. Each fit estimates its own
residual variance; there is no site coefficient or between-park variance ratio within a park.
The retained sensitivity code uses the same park separation when Bacon model sensitivity is resumed.

The coefficient PDF has separate Holocene and Anthropocene pages, with all 14 species as
readable rows and coefficients (including the intercept) as columns. Blue MORA and orange NOCA
estimates are shown together. The first column adds arithmetic mean parallel contributions
from the same finite primary observations used in the species boxplots: each transition or
plot pair counts once, zeros remain, and undefined directions are omitted. These descriptive
diamonds have no model confidence intervals or significance fading; they may include responses
excluded from models because a predictor is missing. Each column has its own x-axis scale. Faded estimates
have unadjusted p ≥ 0.05. An `NE` marker denotes a model not estimable in that park, not a fitted
zero coefficient. Species present in only one park are estimated there independently of their
absence in the other park. Absent species still have zero responses throughout their park and
cannot be fitted; constant responses, rank deficiency and numerical failures are reported.

The Holocene intercept is the expected contribution at zero climate-change rate and zero fire
activity in the fitted park. The Anthropocene MORA intercept is the mean across all eligible
plots; the NOCA intercept is the unburned mean, and its fire coefficient is burned minus
unburned. No MORA fire term is fitted. The Holocene intercept remains conditional on zero predictor values. Neither
an intercept nor a mean implies that all observations share its sign. Positive contributions align with climate-predicted movement;
negative contributions oppose it. Captions explain park-specific absences.

{{species_selection}}
{{species_models_diagnostics}}
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
