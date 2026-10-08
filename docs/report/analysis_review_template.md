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
earlier discussion. This report uses stored chronologies; no model is refitted.

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

## Worked examples and climate/fire display

The metric example below shows how displacement, lag, ratio and angle follow
from WA and LC endpoints. The fire-detection examples distinguish individual
events from the subsequent classification of high-fire periods.

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
pooled CCA. Its five tables contain endpoints, all focused responses, own-lake
physical climate and interval-aligned fire predictors. The wide lake/offset
actual-transition table is the prospective model input. Full supported data:
[lake/offset table](assets/analysis/tables/lake_by_offset.csv),
[607 modern pairs](assets/analysis/tables/modern_model_input.csv), and
[column definitions and units](assets/analysis/tables/tracking_schema.csv).

{{lake_support}}

No majority-draw cutoff is imposed. `n_valid_draws,n_missing_draws` refer to the
primary lag response out of 100 draws; each response has its own counts.
Presence/absence counts distinguish missing transitions from undefined geometry.
Statistics describe valid draws conditional on the transition's support;
minimum-two-samples sensitivity statistics are marked `_nmin2`.
There are approximately 5–6 majority-supported transitions per MORA lake per
offset and 9–10 for Panther Potholes. Four lakes and two fire histories provide
limited independent support for a later three-way interaction. No models,
distributions or temporal-correlation structures are fitted or selected here.

Each MORA vegetation lake uses its own climate but shares regional fire exposure.
Numerators and core maxima use fully covered windows of identical duration and
matching half-open interval conventions. Covered zero-event intervals have zero
activity; absent coverage remains missing. Full-window denominators match the
existing 1,000-year references. [Scientific definitions](SCIENTIFIC_DECISIONS.md#lake-tracking-metrics)
explain the formulas, units, stationary cases and nonadditive counterfactuals.
[NOCA migration validation](review/NOCA_TRACKING_MIGRATION_CHECK.csv) records the
full 9,200-realization comparison before legacy outputs were removed.
The [tracking validation report](review/TRACKING_DATA_VALIDATION.md) gives the
schemas, exclusion counts, independent checks and limits for later modeling.

### Maintained tracking calculation code

The following code is copied automatically from
[tracking_metrics.R](../R/helpers/tracking_metrics.R); the generated R reading
copy includes the same definitions. The helper is the calculation authority.

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
