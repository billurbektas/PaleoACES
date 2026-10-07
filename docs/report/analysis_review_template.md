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

The source-year audit identifies 95 supplied plot names, including 48 analyzed
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
These exclusions apply to both dates. The cleaned NOCA universe has 305 pairs;
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
and Taxus brevifolia are removed for stratum compatibility; Pinus ponderosa is
excluded by the documented analysis choice.

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

## CCA sample eligibility and exclusions

[05_cca_model.R](../R/stages/05_cca_model.R) resolves eligibility **before fitting
or projecting**. An observation with no retained taxa has no observed WA
position. It is excluded from both observed and climate-predicted comparisons.
Modern endpoints use the same eligible pairs at both dates; Holocene WA and LC
positions also use identical samples. All eligible legacy plots remain available
for calibration.

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

One pooled legacy CCA relates composition to the four climate variables.
Observed **weighted-average (WA)** scores describe composition; predicted
**linear-combination (LC)** scores describe the position expected from climate.
Modern resurveys and paleo samples enter the existing ordination without
recalibrating it.

{{cca_summary}}

{{cca_axes}}

{{cca_counts}}

CCA1–CCA2 and site scaling (1), with Hill scaling off, define all distances and
angles. Display arrow multipliers do not enter calculations. Binary presence
still carries CCA's row and taxon weighting. The displayed axes represent only
part of total community inertia, and correlated climate variables prevent
adding their marginal contributions as independent shares. Projections are
descriptive scores rather than independently validated forecasts.

{{cca_diagnostics}}

## Tracking calculations and resolution sensitivity

Observed movement is the change in WA position; climate-predicted movement is
the change in LC position. Endpoint lag is the distance between LC and WA.
**Δlag is final lag minus initial lag**: positive values mean the mismatch opens.
The tracking ratio compares observed and predicted movement rates; the angle
compares their directions and is undefined when either movement is stationary.

Primary Holocene calculations pool MORA's lakes before calculating nonlinear
metrics for consecutive **1,000-year intervals**. Each core contributes 100
chronology draws, and ten 100-year offsets assess sensitivity to interval
placement. Draws are summarized within offset before offsets are combined.
These realizations are not additional ecological replicates. One-sample bins
remain flagged, with an existing minimum-two-sample sensitivity.

The workflow runs the **500-year sensitivity** first, then the primary analysis.
The table compares their resolution and descriptive estimates.

{{resolution_audit}}

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
ordination. Modern arrows use exactly the same eligible pairs at both endpoints,
while the broader legacy calibration remains the fitting reference.

{{modern_centroids}}

{{era_centroids}}

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

## Tracking comparisons

Prepared tracking summaries are assigned to climate eras and fire contexts.
Coverage is explicit: the primary analysis supports 54 MORA and 83 NOCA
site-dates across all ten offsets. Group summaries describe the supported data;
chronology draws, offsets and overlapping dates are not independent replication.

{{era_coverage}}

{{tracking_summary}}

Figure 4 omits the two burned MORA pairs from its descriptive comparison and
retains 603 modern pairs across the displayed groups. All 137 supported Holocene
site-dates remain. Its scatter has 589 direction-valid observations; stationary
modern compositions remain in the non-angle summaries. Quartiles and offset/draw
spread describe variation, not inferential confidence intervals.

{{figure_4}}

### Effects of the 2026-10-07 survey-date decision

The comparison below isolates the update from the preserved pre-update analysis.
Legacy occurrences and climate, the 618-plot CCA fit, its 13 taxa, and all Holocene
results are unchanged. Latest-visit selection removes earlier-only presence from
seven cleaned MORA plots; one loss is a taxon already excluded during
consolidation, so six modeled observed positions change. Modern climate changes for all 330 MORA plots and the 50 NOCA plots surveyed in
2014. Climate elapsed time changes for 319 MORA plots and those same 50 NOCA
plots; 2017 MORA resurveys retain the former 30.5-year midpoint interval.
The 225 NOCA plots surveyed in 2015 retain their former 2010–2015 window.
Figures 2–5 and the tracking/direction summaries use the updated inputs.

{{latest_visit_composition_effects}}

{{survey_decision_effects}}

## Direction discrepancies and support

For each taxon, predicted alignment compares LC movement with the vector from
its initial LC position toward the species score. Observed alignment uses the
corresponding vector from its initial WA position. Climate targets use the
common environmental biplot directions. The **target-alignment discrepancy**
is predicted minus observed cosine: positive values mean stronger predicted
alignment, including movement that is less opposed to a target.

Equal target alignment does not imply equal movement vectors. Each taxon
comparison uses its trajectory's own origin, so starting-position differences
can contribute to the discrepancy. Cosines are missing for movements below the
existing 1e-8 tolerance. The stage retains all 605 modern pairs, including the
two burned MORA plots, and 15,270 primary Holocene realizations.

{{direction_support}}

MORA burned has only two plots and NOCA relative-stability/high-fire has only
two dates. These groups remain visible, but do not support precise or causal
claims. Directional alignment does not directly measure taxon gain, dominance
or climate causation.

{{direction_diagnostics}}

{{figure_5}}

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
