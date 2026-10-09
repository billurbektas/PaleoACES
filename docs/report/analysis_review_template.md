---
title: "PaleoACES analysis review"
---

{{build_status}}

PaleoACES asks how observed forest composition moves relative to the composition
predicted by climate, comparing modern forest resurveys with four Holocene
records. This review follows the [workflow](WORKFLOW.md), showing preparation,
methods, diagnostics and manuscript figures. [Scientific decisions](SCIENTIFIC_DECISIONS.md)
records the adopted choices; [figure captions](FIGURE_CAPTIONS.md) provides the
publication text.

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
CCA eligibility is assessed later. The [cleaning guide](methods/000_NOCA_cleaning_guide.md)
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

The four Bacon models provide sample ages, allowing vegetation to be matched
to climate through time. The [control-point register](../Cores/CONTROL_POINTS.md)
explains radiocarbon dates, tephra ages, surface controls and instantaneous layers.
Tracking uses 100 whole-chronology draws per core, preserving temporal dependence
within each core.

**The chronology choices are retained for this analysis.** Some tephra errors
are assumed bracket half-widths, rather than verified statistical standard
deviations. Reflection Pond's basal-lahar control also retains an assumed age
error and an unverified core-to-deposit correlation. The draws describe
uncertainty conditional on these controls and the Bacon model; they do not
represent every source of dating uncertainty. The [MORA reconsideration](../Cores/SOURCES_MORA.md#basal-lahar-reconsideration-2026-10-06)
records the sources and reason for retaining the existing model.

Panther Potholes' primary chronology deliberately retains inherited Pb210
activity errors for reproduction. The existing **assumed ±10-year age-error
sensitivity** examines that limitation without replacing the primary chronology.
The deeper models are similar, not identical: the
[stored comparison](review/PB210_STORED_SENSITIVITY_COMPARISON.csv) finds maximum
differences below 35 cm of 15 years in median age and 24/28 years in the lower/upper
95% bounds. The [NOCA source notes](../data/NOCA/NOCA_paleo/SOURCES.md) preserve the
earlier discussion. This report uses stored chronologies; no chronology model is refitted.

{{chronology_diagnostics}}

## Paleo vegetation and fire preparation

Macrofossil records are harmonized into presence/absence observations while
retaining their lake, sample depth and modeled age. Macrofossil percentages and
survey stem counts are not combined as abundance. A sample without detected
tree taxa does not demonstrate an absence of forest.

Charcoal and charred-needle information is prepared separately from vegetation.
The MORA published charcoal chronologies and the Panther Potholes core do not
have equivalent timing precision or spatial support. Later fire classification
uses the accepted-event catalog described below.

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

## Taxonomy and species selection

[Consolidation](methods/README_occurrence_consolidation.md) aligns Populus,
Picea and Abies identifications across surveys and macrofossils. Acer circinatum
and Taxus brevifolia are removed for stratum compatibility. Pinus ponderosa's
manual exclusion was [reversed on 2026-10-08](SCIENTIFIC_DECISIONS.md#ponderosa-reinstatement);
it is now retained and follows the ordinary frequency rule below.

CCA retains a taxon when it occurs in **at least 20 plots or samples in any one
site × period group**. The rule does not require 20 in every group. Pinus
albicaulis reaches exactly 20 and remains included. Selection rests on taxon
relevance and ordination interpretation; increased explained inertia alone is
not its justification. Resurvey and paleo counts influence selection even
though those observations do not calibrate the CCA.

{{cca_taxa}}

NOCA size classes differ between dates: legacy regeneration spans 0–3 m and
adults exceed 3 m; resurvey seedlings span 10–140 cm and trees exceed 1.4 m.
These strata are not identical measurements across surveys.

{{taxonomy_diagnostics}}

The occupancy display is explicitly a **500-year sensitivity**. Primary
Holocene tracking uses 1,000-year intervals.

## Plots and samples included in CCA

The following diagram starts with the supplied survey lists and core sample
depths. It shows losses during matching and cleaning, then the species and
climate checks required for CCA. The starting legacy and resurvey counts are
separate; their exclusions must not be added together. Core depths sharing one
modeled age are combined, rather than excluded.

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

[05_cca_model.R](../R/stages/05_cca_model.R) resolves eligibility **before fitting
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

## Tracking calculations

Observed movement is the change in WA position; climate-predicted movement is
the change in LC position. Endpoint lag is the distance between LC and WA.
**Δlag is final lag minus initial lag**: positive values mean the mismatch opens.
The tracking ratio compares observed and predicted movement rates; the angle
compares their directions and is undefined when either movement is stationary.

Primary Holocene calculations treat each lake separately before calculating nonlinear
metrics for consecutive **1,000-year intervals**. Each core contributes 100
chronology draws, and ten 100-year offsets assess sensitivity to interval
placement. Draws are summarized within offset before offsets are combined.
These realizations are not additional ecological replicates. One-sample bins
remain flagged, with an existing minimum-two-sample sensitivity.

## Accepted fire events and climate eras

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

## Community trajectories

Figure 3 connects observed and predicted centroids for each site through the
CC1–S4 eras. These are separate WA and LC trajectories within the same fitted
ordination. Modern arrows use exactly the same eligible pairs at both endpoints;
their matched legacy observations also provide the CCA calibration.

{{modern_centroids}}

{{era_centroids}}

### CCA model, contributions and tests

The model below is fitted to the **607 matched legacy plots and 14 retained
tree species**. Species values are binary presence, combining adults and
regeneration. The climate rows use those same plots in the same order.
`MSpT` is spring temperature, `MWT` winter temperature, `SP` summer precipitation
and `WP` winter precipitation. The fitting and resurvey-projection lines are
copied from [05_cca_model.R](../R/stages/05_cca_model.R), with the current scaling
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

{{figure_3}}

## Tracking example, descriptive visualizations and climate/fire display

The metric example below shows how displacement, lag, ratio and angle follow
from WA and LC endpoints. The next two descriptive figures use four lake columns
with aligned cal-BP axes. Thin trajectories show offsets at actual transition
midpoints; thick response lines reuse the maintained complete-offset medians.
Climate/fire predictor medians are reconstructed from canonical transitions
with the same half-open intervals and complete-offset rule. The original model,
uncertainty and seven-response reporting CSVs are unchanged.
The rates figure has rows for tracking responses together, standardized climate
rate and fire activity. The other figure gives magnitude ratio, angle, climate
and fire one row each, omitting the duplicate Holocene rate-ratio display.
Both ratios remain in the model inputs and can differ for modern plots.

Both figures reuse the regional climate-period catalog and subdivisions shown
in Figure 2. Darker gray marks climate change (CC) and lighter gray relative
stability (S) across all Holocene rows. Top-row labels include CC1a, CC1b and
CC1c; dotted lines mark their internal boundaries. These are shared regional
annotations, with unshaded margins outside the classified 9,600–1,300 cal-BP
domain. Adding these bands does not change response values, predictors or
climate classifications. The modern boxplots have no climate-period bands.

A fifth column shows MORA/NOCA paired-plot boxplots with matching colors and
separate labeled y-scales. It uses all 607 pairs, retaining finite values per
response independently. Modern continuous fire activity is unavailable and is
annotated; binary burned assignments remain in the model input. MORA vegetation
lakes share regional fire exposure. Missing values break trajectories and sparse
supported transitions remain visible. Offsets are sensitivity placements,
not independent ecological replicates.
The fire-detection examples distinguish individual events from the subsequent
classification of high-fire periods.

{{tracking_diagnostics}}

{{fire_detection_diagnostics}}

Figure 2 aligns independently defined climate eras and high-fire periods.
Its rate comparison retains signed temperatures in °C/century and precipitation
in mm/century. Modern rates describe the agreed survey-window contrasts.

{{raw_climate_rates}}

{{figure_2}}

{{fire_eras_diagnostics}}

## Lake-level tracking datasets and support

The canonical tracking analysis calculates each lake independently in the same
pooled CCA. Stage 09 derives seven products from detailed records: two compact
source inputs, long chronology uncertainty, lake and modern calculation audits,
seven-response descriptive reporting and sampling/coverage diagnostics.
Stage 09b assembles the combined transition model input without recalculating responses.
The model inputs share exactly the same seven response names and definitions:
[273 lake/offset transitions, 23 columns](assets/analysis/tables/lake_by_offset.csv),
[607 modern pairs, 21 columns](assets/analysis/tables/modern_model_input.csv).
Separate records expose [chronology uncertainty, 15 columns](assets/analysis/tables/lake_uncertainty.csv),
[detailed modern calculations](assets/analysis/tables/modern_calculations.csv), and
[column definitions and units](assets/analysis/tables/tracking_schema.csv).

The [combined transition input, 28 columns](assets/analysis/tables/era_by_offset.csv)
contains 6,160 rows: seven responses for each of 273 actual lake/offset transitions
and 607 modern pairs. Modern observations are stored once per response, with
an absent offset; each model fit selects one Holocene offset and the same modern
pairs. No across-offset median or 100-year grid is used for modeling. Holocene
estimates remain finite-draw medians within actual transitions. Dates, both
elapsed times, predictors, sampling support and WGS84 identities are retained.
Undefined responses remain rows and are filtered separately using `response_valid`.
Missing charcoal exposure stays missing; modern fire remains binary burned.
The previous reporting-grid model input and model trials are retired.

{{lake_support}}

No majority-draw cutoff is imposed. `n_draws_present` counts existing transitions
before response validity; `n_draws_nmin2` counts present draws with at least two
samples in both endpoint bins. Model responses are independent finite-draw
medians. The uncertainty table records expected, present, eligible, valid and
undefined draws for each response under `all` and `nmin2`, retaining empty
sensitivity groups with missing statistics. Quantiles describe chronology
uncertainty conditional on valid realizations, not model confidence intervals.

The descriptive grid contains only seven responses and requires a finite median
from every offset separately for each lake/date/response. At Reflection Pond,
5,900 cal BP, angle and pace have nine valid offsets: only those two reporting
values are excluded, while the other five responses and all underlying transition
records remain available.

The 273 Holocene rows span ten alternative bin placements. Offsets are sensitivity
realizations, not independent ecological replicates. The intended primary
statistical approach is to analyze non-overlapping transitions separately within
each offset, considering lake identity and temporal dependence during later
model development. Adjacent transitions share endpoint information.
There are approximately 5–6 majority-supported transitions per MORA lake per
offset and 9–10 for Panther Potholes. Four lakes and two fire histories provide
limited independent support for a later three-way interaction. The covariance
comparison and chosen MA(1) results are shown below; distributions and
lake/chronology uncertainty treatment remain open.

Each MORA vegetation lake uses its own climate but shares regional fire exposure.
Numerators and core maxima use fully covered windows of identical duration and
matching half-open interval conventions. Covered zero-event intervals have zero
activity; inadequate coverage gives both `fire_activity=NA` and `high_fire=NA`. Full-window denominators match the
existing 1,000-year references. [Scientific definitions](SCIENTIFIC_DECISIONS.md#lake-tracking-metrics)
explain the formulas, units, stationary cases and nonadditive counterfactuals.
[NOCA migration validation](review/NOCA_TRACKING_MIGRATION_CHECK.csv) records the
full 9,200-realization comparison before legacy outputs were removed.
The [tracking validation report](review/TRACKING_DATA_VALIDATION.md) gives the
schemas, exclusion counts, independent checks and limits for later modeling.

### Tracking metric calculations

These calculation excerpts are generated directly from
[tracking_metrics.R](../R/helpers/tracking_metrics.R). The generated R reading
copy includes the same excerpts. `x` contains the observed and predicted
endpoints, seasonal climate values and their respective elapsed times.
`epsilon` is the movement tolerance (default `1e-8`), and `scaling` supplies the
fixed pooled-calibration SDs. In the cosine calculation, `ax,ay` and `bx,by`
are the observed and predicted displacement components.

{{tracking_metrics_code}}


### Effects of the 2026-10-07 survey-date decision

The comparison below isolates the survey-date update from its preserved
pre-update analysis. At that time, legacy occurrences and climate, the 618-plot
CCA fit, its 13 taxa, and all Holocene results were unchanged. The subsequent
2026-10-08 ponderosa reinstatement first refitted that model with 14 taxa and
619 legacy plots; matched calibration then restricted fitting to 607 plots.
These tables describe the earlier survey-date decision alone.
Latest-visit selection removes earlier-only presence from
seven cleaned MORA plots; one loss is a taxon already excluded during
consolidation, so six modeled observed positions change. Modern climate changes for all 330 MORA plots and the 50 NOCA plots surveyed in
2014. Climate elapsed time changes for 319 MORA plots and those same 50 NOCA
plots; 2017 MORA resurveys retain the former 30.5-year midpoint interval.
The 225 NOCA plots surveyed in 2015 retain their former 2010–2015 window.
Figures 2 and 3 and the lake/plot tracking datasets use the updated inputs.

{{latest_visit_composition_effects}}

{{survey_decision_effects}}

## Residual covariance comparison

[Stage 10](../R/stages/10_tracking_era_models.R) compares three Gaussian GLS
structures for lag-change rate, observed community turnover and untransformed
physical climate-change rate at each offset from 0 to 900 years. The shared
specifications below apply to all three responses. Within an
offset, all candidates use exactly the same actual 1,000-year Holocene
transitions and 607 modern pairs, the same `era * site` fixed effects, REML,
and separate residual variances for the four era/site groups. All 30 fits per
response converged. The following focused specifications show the three structures;
`d` is the finite-response dataset for one offset, prepared by
[tracking_offset_model_input()](../R/helpers/tracking_model_data.R).

### AR(1)

```r
m_ar1 <- nlme::gls(
  estimate ~ era * site, data = d,
  correlation = nlme::corAR1(form = ~ time_index | series),
  weights = nlme::varIdent(form = ~ 1 | era_site),
  method = "REML", na.action = na.fail,
  control = nlme::glsControl(msMaxIter = 200)
)
```

### MA(1)

```r
m_ma1 <- nlme::gls(
  estimate ~ era * site, data = d,
  correlation = nlme::corARMA(p = 0, q = 1, form = ~ time_index | series),
  weights = nlme::varIdent(form = ~ 1 | era_site),
  method = "REML", na.action = na.fail,
  control = nlme::glsControl(msMaxIter = 200)
)
```

### No temporal autocorrelation

```r
m_independent <- nlme::gls(
  estimate ~ era * site, data = d,
  correlation = NULL,
  weights = nlme::varIdent(form = ~ 1 | era_site),
  method = "REML", na.action = na.fail,
  control = nlme::glsControl(msMaxIter = 200)
)
```

The [30 fit comparisons](assets/analysis/tables/tracking_model_comparison.csv)
record restricted likelihoods, parameter counts, AIC, within-offset ΔAIC,
relative Akaike weights and ranks. ΔAIC is each candidate's AIC minus the
minimum for that same offset. Offsets are sensitivity realizations that reuse
modern plots; AICs are compared within an offset, where observations agree.
MA1 has the lowest AIC at five offsets, independent residuals at four and AR1
at one. All three candidates are within two AIC units at nine of ten offsets.

{{tracking_covariance_diagnostics}}

**We chose MA(1) for the reported lag-change analyses.** This is the author's
covariance decision following the comparison above. MA1 accommodates residual
dependence between immediately neighboring transitions, which share endpoint
information, while setting correlation beyond one actual time step to zero.
The small AIC differences provide limited separation between candidates;
this choice does not imply that AIC uniquely identified MA1. Missing time
steps retain their original indices, and modern plot pairs are singleton series.
The selected covariance is recorded in
[tracking_model_reporting.R](../R/helpers/tracking_model_reporting.R).

## Lag-change rate: MA(1) group means, coefficients and contrasts across offsets

The figures below show **MA(1) only**, fitted separately at each of the ten
alternative bin placements. They display 40 coefficients and 20 within-park
era contrasts. The full [coefficient](assets/analysis/tables/tracking_model_coefficients.csv)
and [contrast](assets/analysis/tables/tracking_model_contrasts.csv) calculation
records retain the comparison candidates; select `model_type == "MA1"` for
these reported results. The reference categories are Holocene and MORA.

Contrasts are Anthropocene minus Holocene within MORA and within NOCA.
Positive values indicate higher Anthropocene lag-change rates. Coefficient
bars are unadjusted 95% t intervals; contrast bars use Satterthwaite degrees
of freedom. Points and intervals use the same MA1 color in the offset and
lake figures. Offsets are alternative sensitivity fits, not independent
replicates, and are not pooled into one coefficient or contrast.

### Fitted group means and their differences

The [40 MA1 group means](assets/analysis/tables/tracking_model_group_means.csv)
retain era, park, offset, estimate, SE, degrees of freedom, interval bounds and
cell observation counts. The figure places MORA and NOCA in two columns and
uses three aligned rows: Holocene means across offsets, one Anthropocene mean
per park, and the offset-specific differences. Rows have separate y-scales;
parks share a scale within each row. The modern observations are reused unchanged,
so their means stay constant across offsets and appear only once. The displayed
modern interval comes from offset 0; each fit's interval remains in the table.
Contrasts retain each offset's covariance between fitted means; their intervals
are not obtained by subtracting mean bounds.

{{tracking_groups_diagnostics}}

### Coefficients and era contrasts

{{tracking_models_diagnostics}}

{{tracking_model_results}}

## Lag-change rate: MA(1) lake comparisons at offset 0

[Stage 10a](../R/stages/10a_tracking_lake_sensitivity.R) compares each Holocene
lake with modern pairs from its own park at **offset 0 only**. These figures
show four MA(1) fits: eight coefficients and four era contrasts. The formula
is `estimate ~ era`, with REML and era-specific residual variances, since
park is constant within each lake comparison. Original time gaps are retained.
The [coefficient](assets/analysis/tables/tracking_lake_coefficients.csv) and
[contrast](assets/analysis/tables/tracking_lake_contrasts.csv) records retain
AR1 sensitivity fits as an audit; the displayed results use MA1 only.

Reflection Pond and Panther Potholes MA1 fits approach the parameter boundary;
triangles identify absolute parameters above 0.98. These fits are retained.
MORA comparisons reuse the same 330 modern plots and are overlapping
sensitivities. Each lake provides only 6–10 Holocene transitions at offset 0.
MA(2) is outside the maintained workflow.

{{tracking_lake_diagnostics}}

{{tracking_lake_results}}

### MA(1) residual checks

{{tracking_model_checks_diagnostics}}

MA1 is the chosen covariance structure for these results. Distribution,
lake effects, response inclusion and chronology uncertainty treatment remain
subjects for later model development. These fits do not propagate chronology
uncertainty or add lake random intercepts or climate/fire fixed effects.

## Observed community turnover: the same model exercise

The second response is `observed_turnover_rate`, defined as observed CCA
movement magnitude multiplied by 100 and divided by **vegetation elapsed
time**. It is a nonnegative rate in CCA units per century. Both maintained
model stages include lag-change rate and turnover in their default responses; standalone
`--metric=observed_turnover_rate` selects just this exercise. No response
transformation, additional filtering or new data assembly is applied.

### Covariance comparison

The three GLS specifications above are refitted to turnover at every offset:
`estimate ~ era * site`, REML, AR1/MA1/independent residuals and separate era/site
variances. The [30 turnover comparisons](assets/analysis/tables/turnover_model_comparison.csv)
are evaluated within offset, independently of the lag-rate comparison.
**Independent residuals have the lowest AIC at all ten offsets.** MA1 remains
within two AIC units of the minimum at every offset. The requested MA1
exercise is retained for comparable reporting; the lag-rate decision does not
establish which covariance structure is best for turnover.

{{turnover_covariance_diagnostics}}

### MA(1) fitted groups and contrasts across offsets

The [40 fitted group means](assets/analysis/tables/turnover_model_group_means.csv)
and contrast figure use the same aligned three-row layout as lag rate.
Each mean is conditional on its own offset fit. The modern means stay constant
because the same plots are reused: approximately 0.930 CCA units/century at
MORA and 2.125 at NOCA. Each modern mean appears once per park with its offset-0
interval; Holocene means and contrasts retain all ten offsets.
The fitted Anthropocene-minus-Holocene contrasts are
positive at every offset in both parks. The full
[coefficient](assets/analysis/tables/turnover_model_coefficients.csv) and
[contrast](assets/analysis/tables/turnover_model_contrasts.csv) records retain
all comparison candidates; displayed results select `model_type == "MA1"`.

{{turnover_groups_diagnostics}}

{{turnover_models_diagnostics}}

{{turnover_model_results}}

### MA(1) lake comparisons at offset 0

The identical lake sensitivity compares each Holocene lake with its own park's
modern turnover responses, using `estimate ~ era`, REML, separate era residual
variances and actual time gaps. Only offset 0 and MA1 are displayed: eight
coefficients and four contrasts. The
[coefficient](assets/analysis/tables/turnover_lake_coefficients.csv) and
[contrast](assets/analysis/tables/turnover_lake_contrasts.csv) calculation
records also retain AR1 sensitivity fits. Jay Bath's MA1 parameter approaches
+1 and is retained with the same boundary flag used for lag rate. The three
MORA comparisons reuse the same modern plots and are overlapping sensitivities.

{{turnover_lake_diagnostics}}

{{turnover_lake_results}}

### MA(1) residual checks and interpretation

{{turnover_model_checks_diagnostics}}

This is the requested Gaussian GLS working exercise for a nonnegative response.
Some unbounded Holocene mean intervals extend below zero; they are shown in
full. Distribution choice remains open. Chronology uncertainty is not
propagated, offsets are not pooled and no lake random effects or climate/fire
fixed effects have been added. Covariance support and residual behavior must
be assessed separately for turnover before making its specification definitive.

## Physical climate-change rate: the same untransformed GLS exercise

The third response is `standardized_climate_change_rate`: the Euclidean magnitude
of changes in the four seasonal climate variables, scaled by the pooled legacy
calibration SDs and expressed per century. It measures physical climate change,
not climate-predicted CCA movement. The author requested the same GLS exercise
on its **original scale, without logging or any other transformation**.
Both maintained model stages include it by default; standalone
`--metric=standardized_climate_change_rate` selects this response.

The combined CSV already repeats this fixed climate field on each of the seven
tracking-response rows. The selector reduces those copies to one observation
per actual transition or modern plot, checking that their fixed fields agree.
It assigns the original climate rate to `estimate` and checks its own finite-value
eligibility, independently of tracking validity. The canonical CSV schemas and
seven tracking-response names remain unchanged.

```r
d <- tracking_offset_model_input(
  combined, metric = "standardized_climate_change_rate", offset = offset
)$data
# estimate is the original standardized climate-change rate.
# Fit the same three GLS structures shown above, without transforming estimate.
```

### Covariance comparison

All 30 climate offset fits converge without warnings. The same `estimate ~ era * site`,
REML, four era/site residual variances and actual time indices are used.
The [30 climate comparisons](assets/analysis/tables/climate_model_comparison.csv)
show minimum AIC for independent residuals at four offsets, MA1 at three and
AR1 at three. MA1's within-offset delta AIC ranges from 0 to approximately 2.65.
MA1 remains the requested reporting specification; this comparison is separate
from the lag-rate and turnover evidence.

{{climate_covariance_diagnostics}}

### MA(1) fitted groups, coefficients and contrasts across offsets

The [40 MA1 group means](assets/analysis/tables/climate_model_group_means.csv)
use the same two-park, three-row layout: offset-specific Holocene means, one
Anthropocene mean per park, and offset-specific differences, with separate row
scales. The modern interval displayed is from offset 0; all fitted intervals
remain in the table. Units are **calibration SD per century**.
Modern means remain constant across offsets: approximately 5.260 at MORA and
3.644 at NOCA. The Anthropocene-minus-Holocene contrasts are positive in both
parks at every offset. The full
[coefficient](assets/analysis/tables/climate_model_coefficients.csv) and
[contrast](assets/analysis/tables/climate_model_contrasts.csv) records retain
all covariance candidates; figures show MA1 only.

{{climate_groups_diagnostics}}

{{climate_models_diagnostics}}

{{climate_model_results}}

### MA(1) lake comparisons at offset 0

The same lake exercise uses each lake's climate transitions and its park's
modern plot climate rates, with `estimate ~ era`, REML, era-specific residual
variances and actual time gaps. All eight comparison fits converge without
warnings. The [coefficient](assets/analysis/tables/climate_lake_coefficients.csv)
and [contrast](assets/analysis/tables/climate_lake_contrasts.csv) records retain
AR1 and MA1; figures display four MA1 fits at offset 0. Panther Potholes has
an MA1 parameter near +1 and remains flagged. The three MORA comparisons reuse
the same modern plots and are overlapping sensitivities.

{{climate_lake_diagnostics}}

{{climate_lake_results}}

### MA(1) residual checks and interpretation

{{climate_model_checks_diagnostics}}

This is the requested raw-scale Gaussian GLS exercise. Per-century units do
not equalize the temporal averaging of 1,000-year Holocene transitions and
shorter modern climate intervals. Covariance comparison and residual checks
are response-specific. These models do not propagate chronology uncertainty,
model modern spatial dependence or add lake random effects. Offsets remain
separate sensitivity fits. Continuous fire activity is outside this extension.

## Manuscript comparison at offset 0

The manuscript figure uses **only offset 0**, with the same untransformed
climate-change, turnover and lag-rate inputs used in the maintained MA1 models.
Violins and dots display each actual input value. Holocene inputs are medians
over valid chronology draws within individual lake transitions; the figure
does not add reporting-grid dates or combine offsets. MORA contributes 20
Holocene transitions from three lakes and 330 modern pairs; NOCA contributes
10 Panther Potholes transitions and 277 modern pairs, for each response.

Connected open circles show fitted Holocene and Anthropocene means, with
95% confidence intervals. The annotation above each pair is its
**Anthropocene-minus-Holocene contrast and 95% interval**, read directly from
the offset-0 MA1 contrast table. The contrast interval uses covariance between
the means; it is not the difference between their confidence bounds. All
intervals use Satterthwaite degrees of freedom. Linear scales include all raw
values and are shared between parks within each response; narrow Holocene
distributions remain narrow on these common scales.
Grey violins and points show distributions; smaller mean circles, connecting
lines and intervals use grey. Labels name each response as a rate without
displaying units. A star identifies a contrast with unadjusted `p < 0.05`.

{{figure_4}}

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
