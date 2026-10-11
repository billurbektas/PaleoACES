# PaleoACES scientific decisions

This document records current analytical choices and their limits. Execution
order and file dependencies are authoritative in [WORKFLOW.md](WORKFLOW.md).

## Study universes and vegetation

- Modern vegetation is paired within plot. MORA has 330 modeled pairs and NOCA
  has 277 after excluding `BAK487` (old clearcut), `BEAV6061` (uncertain
  relocation into an avalanche chute), and `CARI449`/`CARI450` (GPS problem).
- The corrected NOCA workbook is authoritative for its 2,366 received stem
  rows. Unsupported labels are discarded before occurrence construction. The
  verified cleaned result is 305 plots, 1,775 rows, and 31 identified taxa.
- NOCA fire comparisons use Wilson et al. as a regression reference, not as the
  PaleoACES universe. All 303 common plots have the same assignment. The active
  PaleoACES result is 32 burned and 273 unburned plots.
- Presence is adult or regeneration presence. Species are retained when present
  in at least one site-period group of 20 plots or samples. The consolidated
  table has 13,701 rows, 22 taxa, and 1,599 samples.

Both CARI plots are excluded at both dates before CCA and climate preparation.
Rachel's notes and the coordinate CSV provide no verified replacement location.
Their shared normalized location conflicts with elevations of 622 and 1,149 m;
the author elected to exclude them for a GPS problem. This is an upstream study
exclusion, separate from all-zero CCA eligibility. See the
[GPS source review and decision](review/NOCA_GPS_EXCLUSION.md).

<a id="ponderosa-reinstatement"></a>

## Ponderosa pine exclusion reversed — decided 2026-10-08

**Decision:** retain *Pinus ponderosa* in consolidation and let it follow the same
≥20 site × period occurrence rule as other tree taxa. The author rejected its
former manual exclusion as insufficiently justified. Its 26 NOCA legacy
occurrences satisfy the existing threshold; the threshold itself is unchanged.

**Before:** ponderosa was removed because it was concentrated at NOCA, absent
from both Holocene records and extreme in a historical CCA. **After:** those
features are treated as ecological and ordination characteristics, rather than
reasons to remove a valid taxon. Grand fir and whitebark pine are also retained
without detections in either Holocene record. Rachel's species review does not
flag ponderosa and says unmentioned species did not look especially suspicious;
the available notes contain no recommendation from her to exclude it.

The manual exclusion is removed in `R/stages/000_occurrence_data_consolidate.R`.
Reinstatement initially produced 14 taxa and 619 legacy calibration plots, with 607 modern
pairs (330 MORA, 277 NOCA). STE2044 returns to calibration and paired comparison;
HB2064 returns to paired comparison. The 907 included Holocene samples, their
chronologies, and the raw climate records are unchanged, but refitting the shared
CCA changes modern and Holocene positions, tracking metrics and direction
summaries. Figures 2 and 3 and the report are regenerated. Other cleaning choices,
CCA constraints, scaling and age-model settings are unchanged.

[Former rationale, source evidence and reversal](review/README_occurrence_consolidation.md#ponderosa-reinstatement)
record the history. The increase in explained inertia under the former exclusion
was not a valid selection criterion; reinstatement changed it from 16.57% to 15.69%
before the matched-calibration decision below.

## CCA sample eligibility and paired comparisons

**Matched calibration — decided 2026-10-08:** fit the CCA on the legacy
observations of exactly the same plots retained for both-date comparisons.
Previously, the model used all 619 eligible legacy plots while comparisons used
607 pairs. It now uses **607 legacy plots: 330 MORA and 277 NOCA**, with the same
IDs for modern observed and predicted endpoints. The author selected one shared
plot set for calibration and comparisons. This removes 12 legacy observations
whose resurveys cannot enter CCA: nine have no recorded tree presence, and three
hold only taxa excluded by species selection. Their received records are kept.
Species selection still uses the existing ≥20 site × period rule; all 14 taxa
remain. The model and its climate-SD reference are refitted on those 607 plots,
and modern and Holocene projections, tracking results, direction summaries and
Figures 2 and 3 are recalculated. Chronologies, climate inputs and fire settings are
unchanged. Climate-explained inertia changes from 15.69% to 15.33% after this
restriction; current axes and tracking summaries are in the analysis review.

The species-frequency exclusion remains in `R/stages/05_cca_model.R`. Its
eligibility section reports all cases before fitting or projection, using
the cleaned occurrences, consolidated occurrences, selected taxa and valid
climate constraints. All-zero retained-taxon rows have no observed WA position;
they are excluded from both observed and climate-predicted comparisons.

- Legacy calibration, modern comparisons and Figure 3's two endpoints use
  exactly the same 330 MORA and 277 NOCA pairs. A usable legacy observation is
  excluded from fitting when its resurvey fails eligibility.
- Of NOCA's 305 cleaned pairs, legacy eligibility excludes 6 with no recorded
  tree taxa and 11 holding only taxa excluded by CCA selection. Among the
  remaining 288 plots, resurvey eligibility excludes 9 with loss of all recorded
  tree-taxon presence and 2 holding only selection-excluded
  taxa. MORA's additional resurvey exclusion holds only selection-excluded taxa.
- Holocene projections retain 117 MORA and 790 NOCA samples. The 56 excluded
  NOCA samples have no tree taxa detected in the prepared macrofossil data.
  Observed and predicted Holocene positions use exactly the same samples.
- Recorded resurvey absence is limited to the sampled tree taxa and strata;
  it does not establish biological extinction. Paleo non-detection does not
  establish absence of forest. Taxon-filter exclusions are reported separately.
  The cleaned data preserve all these observations, while CCA tracking describes
  composition among observations with retained taxa.
- Modern pair reasons are counted once, against the first failing endpoint
  (legacy first). The sample audit retains both local reasons. Calibration and
  comparison counts overlap and must not be summed. Paleo counts precede
  chronology draws and binning. Missing/nonfinite climate and unmatched survey
  endpoints receive explicit reasons if encountered.

Generated totals, reasons and linked per-observation audits are in the
[analysis review](ANALYSIS_REVIEW.md#plots-and-samples-included-in-cca).
Figure 3's previously unequal endpoint membership is corrected by this decision.

## Adult resurvey dates and plot-specific climate — decided 2026-10-07

**Decision.** Keep historical climate at **1979–1989**. For every modern plot,
use its adult resurvey year **Y** and average **Y−5 through Y, inclusive**.
The six years represent the interannual climate dynamics experienced before and
during the survey. A 2014 visit uses 2009–2014, including December 2008 for winter
2009. All modern constraints require six complete season-years.

**Before:** shared modern windows were 2010–2019 at MORA and 2010–2015 at NOCA;
MORA modern presence pooled visits and used the minimum tree/seedling year.
**After:** MORA seedling dates are assigned to their corresponding adult visit
before selection; the latest adult year and matching seedlings are retained
for the 13 multi-year plots. Same-year records keep their existing pooling.
NOCA retains Wilson's plot-specific adult dates. The received CSVs are preserved;
corrections are applied in the cleaner and audited row by row.

**Source discrepancy.** Original and cleaned MORA CSVs disagree with Master2019
and dated plot notes for **95 supplied plot names, including 48 baseline
analyzed pairs**. The 95 comprise 94 standardized IDs and the unassigned practice
plot `PRAC-1`. Seedling and understory discrepancies overlap but are audited
separately. The inconsistency already exists in the upstream original CSVs;
`01_CleanMORA.R` passes their Year columns unchanged. The earlier CSV export
process is unavailable, so its cause is unknown. Understory is evidence for
dates, not an input to tree presence. Original visit names and verified mappings
resolve mislabeled repeat visits, especially RAMP-505/RAMP-506, before filtering.

Climate intervals are calculated per plot from **1984** to **Y−2.5**; vegetation
intervals use 1977.5 (MORA) or 1983 (NOCA) to Y. These dates feed climate summaries,
CCA projections, community trajectories and tracking results.
For this survey-date decision, the CCA settings, species rule, legacy
calibration and Holocene results were unchanged. The later ponderosa
reinstatement on 2026-10-08 refits the shared CCA as recorded above.

[Date evidence and rationale](../data/SOURCES_SURVEY_YEARS.md),
[95-plot discrepancy table](../data/MORA/resurvey_year_source_discrepancies.csv),
[13 latest visits](assets/analysis/tables/mora_repeat_visits.csv),
[seedling visit mapping](../data/MORA/resurvey_seedling_visit_mapping.csv) and
[measured effects](ANALYSIS_REVIEW.md#effects-of-the-2026-10-07-survey-date-decision)
record the adopted treatment. The chronology decisions below remain settled.

## Chronology and the previously discussed ²¹⁰Pb uncertainty

The Panther Potholes ²¹⁰Pb error units were discussed and documented before the
2026-10-06 audit. The detailed record is in the [NOCA paleo source notes](../data/NOCA/NOCA_paleo/SOURCES.md)
and the [control-point register](../Cores/CONTROL_POINTS.md).
The audit confirms a known inherited limitation; retaining the primary values
is an explicit reproduction decision.

- **Known units issue.** Prichard (2009), Table 1c, reports the five errors
  3.47, 1.15, 0.72, 0.74, and 0.77 in DPM/g, on ²¹⁰Pb activity. They are
  numerically identical to the values in Gavin's age-error column. Activity
  uncertainty cannot be interpreted directly as uncertainty in years.
- **Primary decision.** Keep Gavin's control values and chronology settings
  to reproduce the published chronology. This preserves provenance without
  treating the inherited activity errors as justified CRS age uncertainties.
- **Existing sensitivity.** `PantherPotholes_pb210err` substitutes one flat
  **±10-year assumed age error** for the five controls. It remains a sensitivity,
  labelled **assumed**, rather than a corrected or recovered laboratory error.
  The source notes record earlier comparisons with proportional and ±15/±20-year
  assumptions; those historical runs were not repeated by the audit.
- **Reason for the constant.** The earlier comparisons addressed how assumed
  errors affect the near-surface uncertainty envelope. The constant retained
  the simplest explicit assumption for that question. Those comparisons do
  not determine the true CRS age uncertainty or remove the units limitation.
- **Effect and interpretation.** The documented comparisons widened the typical
  top-35-cm 95% age range from approximately 7 years to 30–46 years, with modest
  deeper changes. The audit's comparison of stored primary and ±10-year tables
  found maximum differences below 35 cm of 15 years in median age and 24/28 years
  in the lower/upper 95% bounds. Describe deeper chronologies as similar, rather
  than identical; these are age-table comparisons, not proof that every downstream
  uncertainty summary is insensitive. See the [stored comparison](review/PB210_STORED_SENSITIVITY_COMPARISON.csv)
  and [control-point register](../Cores/CONTROL_POINTS.md#sensitivity-variant-pantherpotholes_pb210err).
- **Remaining evidence gap.** Supported ²¹⁰Pb and the laboratory information
  needed for CRS uncertainty propagation are unavailable in Table 1c. The
  earlier discussion identified the Flett Research report or Prichard's thesis
  as possible sources. Recovering and validating age uncertainties would require
  a separate decision before replacing controls or refitting the chronology.
- **Adopted uncertainty interpretation (2026-10-06).** Retain the current
  chronology controls, Bacon settings and stored posteriors for this analysis.
  Tephra age-bracket half-widths and
  maximum-age assumptions are not verified statistical standard deviations.
  The age draws describe uncertainty conditional on the adopted controls and
  model; they do not establish that all dating uncertainty is represented.
  Retention does not justify describing assumed errors as "correct" or
  "harmless". Source-supported replacements would require a separate future
  decision before refitting; no refit or new sensitivity is authorized now.

### MORA basal-lahar reconsideration (2026-10-06)

**Decision: retain Reflection Pond's existing `Basal_lahar` control at 90 cm,
6180 ± 400 cal BP (`cc = 0`), and the current chronology.** The author reconsidered
the later geological evidence and elected to keep the current analysis unchanged.

The original choice follows Dunwiddie (1986), pp.59–60, and Crandell (1971), p.63.
Pringle (2008) subsequently describes the deposit beneath Reflection Lakes as
formerly interpreted as Paradise and reinterpreted as an older lahar. Vallance
and Sisson's **2022** USGS report, printed p.60, distinguishes the Reflection Lakes
lahar (**7250–7000 cal BP**) from Paradise (approximately **5700 cal BP**).
These sources support reconsideration of the regional identification. The exact
core-to-deposit correlation and a lahar contact at the coded 90 cm depth remain
unverified; Dunwiddie's Figure 5 does not explicitly identify that contact.

The current Bacon input treats this control as an ordinary age/error row, not
an enforced one-sided maximum. Its ±400 is an adopted bracket half-width, not
a published statistical standard deviation. These limitations remain explicit
while the retained choice is settled for the current analysis. Any future
replacement requires validated correlation, depth and probability assumptions.
The detailed evidence and publication links are in the
[MORA source reconsideration](../Cores/SOURCES_MORA.md#basal-lahar-reconsideration-2026-10-06).

## Climate and CCA

- Modern plots use CHELSA V2.1. Paleo samples use native CHELSA-TraCE21k pond
  climate matched to sample age. Raw TraCE21k is current; stationary V2.1-anchor
  correction remains an unresolved sensitivity.
- The active constraints are spring temperature (`MSpT`), winter temperature
  (`MWT`), summer precipitation (`SP`), and winter precipitation (`WP`). They are
  seasonal correlates of growing energy, freezing exposure, summer dryness, and
  snowpack—not direct GDD, FDD, fire, soil-moisture, or snowpack measurements.
- The pooled CCA is calibrated on 607 matched legacy plots and 14 retained species.
  Vegan site/scaling 1 is retained because downstream metrics use Euclidean
  sample-score distances. The model positions 1,514 of 1,599 modern and paleo
  samples.
- Climate constraints are collinear. Their marginal contributions must not be
  interpreted as additive shares of constrained inertia.
- Binary presence retains CCA's chi-square row and taxon weighting; it does not
  make plots or taxa equally weighted. The CCA1–CCA2 plane represents only part
  of total community inertia. The current axis percentages are reported in the
  [analysis review](ANALYSIS_REVIEW.md#cca-calibration-and-geometry).
- Resurvey and paleo observations do not fit the ordination, but their species
  counts influence the cross-group retention rule. This is a descriptive
  calibration/projection design, not an independent predictive validation.
- Being inside each climate variable's legacy range does not establish support
  within the joint multivariate calibration domain. LC positions are
  climate-predicted ordination scores, not independently validated forecasts.

<a id="lake-tracking-metrics"></a>

## Lake-level tracking responses — decided 2026-10-08

The statistical observation is **lake × actual consecutive transition** for
JayBath, LogWallow, ReflectionPond and PantherPotholes, or an individual paired
modern plot. One maintained helper calculates the same response definitions for
both eras. The existing pooled 607-plot, 14-taxon CCA and Figure 3 are unchanged.
The former site-pooled tracking analyses and Figures 4/5 are retired; their
historical code and figures remain in Git. The tracking calculation stage fits
no response models; provisional offset GLS trials are documented below.

Let $O_1,O_2$ be observed WA endpoints and $P_1,P_2$ climate-predicted LC endpoints
in scaling-1, Hill-off CCA1–CCA2 space. Define $\Delta O=O_2-O_1$,
$\Delta P=P_2-P_1$, $a=\|\Delta O\|$ and $b=\|\Delta P\|$.

| Quantity | Definition | Units / interpretation |
|---|---|---|
| `lag_t1`, `lag_t2` | $L_i=\|O_i-P_i\|$ | CCA units |
| `change_in_lag` | $L_2-L_1$ | Positive: mismatch grows; negative: closes |
| `lag_rate_per_century` | $100(L_2-L_1)/\Delta t_C$ | Primary response; CCA units/century |
| `observed_turnover_rate` | $100a/\Delta t_V$ | CCA units/century |
| `predicted_vegetation_change_rate` | $100b/\Delta t_C$ | Supporting community-space rate; not physical climate speed |
| `magnitude_tracking_ratio` | $a/b$ | Unitless displacement ratio |
| `rate_tracking_ratio` | $(a/\Delta t_V)/(b/\Delta t_C)$ | Unitless rate ratio; equals magnitude ratio only when durations match |
| `angle_degrees` | $\arccos[(\Delta O\cdot\Delta P)/(ab)]$ | Degrees, 0–180 |
| `pace_effect_on_lag` | $L_2-\|O_{pace}-P_2\|$ | CCA units |
| `direction_effect_on_lag` | $L_2-\|O_{direction}-P_2\|$ | CCA units |

The two corrected endpoints begin at the **actual observed** initial position:

$$O_{pace}=O_1+b\,\Delta O/a,\qquad
O_{direction}=O_1+a\,\Delta P/b.$$

Positive counterfactual effects mean the correction would reduce final lag;
negative effects mean it would increase it. They are **nonadditive descriptive
counterfactuals**, not a causal attribution or exact decomposition. The pace
correction imposes predicted displacement magnitude. With unequal modern
elapsed times it does not impose equality of the two annualized turnover rates.
Their `_per_century` fields divide by $\Delta t_C$, consistently with lag rate.

Movement tolerance is `1e-8`. Angle needs both directions; a stationary observed
movement invalidates pace correction but leaves a zero direction effect when
predicted direction exists. A stationary predicted movement invalidates direction
correction and ratios; pace correction can still yield the initial observed
position. If both movements are stationary, both corrections are undefined.
Valid lag and turnover values are retained; finite-endpoint, stationary,
ratio, angle and counterfactual flags distinguish these cases. Obsolete exported
alignment, perpendicular/error metrics and compatibility aliases are removed.

### Physical climate and continuous fire predictors

`standardized_climate_change_rate` is the physical **ClimateRate** predictor:
$100\sqrt{\sum_v[(X_{v2}-X_{v1})/SD_v]^2}/\Delta t_C$, using spring/winter
temperature and summer/winter precipitation. SDs come from the unchanged 607
legacy calibration plots. Raw and standardized signed component changes and
rates remain auditable. Each vegetation lake uses its own climate record.
Every endpoint bin must contain all native 100-year climate slices; incomplete
edge bins remain excluded, with excluded realization counts in the support table.

`fire_activity` is continuous **FireActivity**. Count accepted charcoal events in
`[age_lo, age_hi)` and express frequency per 1,000 years. For each core, divide
by its maximum frequency among **fully covered windows of the same duration**
and the same half-open convention across the entire available core record.
The primary 1,000-year denominators are 3 events/1,000 years for each MORA core
and 11 for Panther Potholes. Alternative interval widths recompute their own
comparable reference; they never reuse the 1,000-year denominator blindly.

A fully covered zero-event interval has zero activity. Uncovered intervals have
missing counts/activity and `high_fire=NA`, not zero or `FALSE`. Coverage fractions, bounds, event counts,
frequencies, denominators and source identities are exported per core. MORA
requires at least two covered, normalizable Sunrise/Shadow/Little Sunrise cores
and combines them with equal core weights. **All three MORA vegetation lakes
share this one regional exposure**; they are three vegetation responses, not
three independent fire measurements. NOCA uses Panther Potholes alone.
Existing 1,000-year high-fire classifications are descriptive annotations at
the actual transition midpoint, with their window width recorded.
Modern fire is binary, retaining all 607 original plot assignments.

### Chronology support, configurable intervals and future inference

The default width is 1,000 years, with ten offsets 0–900 by 100 and 100 whole
Bacon chronology draws. A single `bin_width_years` parameter accepts positive
multiples of 100 and controls vegetation/climate bins, elapsed time, required
slice count, offsets and fire normalization windows together. Alternative widths
write suffixed outputs; they are not run automatically. Figure 3 and the frozen
climate-era/high-fire definitions continue to use their existing 1,000-year framework.

Nonlinear responses precede summarization across draws. Keep all supported
realizations without a majority-draw cutoff. The 23-column Holocene model input
contains independently calculated finite-draw medians for the seven responses,
fixed predictors, both elapsed times and sampling support. `n_draws_present`
counts transition presence before mathematical validity; `n_draws_nmin2` counts
present draws with at least two samples in both endpoint bins.

The separate 15-column long uncertainty table retains each response under `all`
and `nmin2` for every actual transition. Counts distinguish 100 expected draws,
present transitions, sampling-eligible draws, finite responses and undefined
responses (eligible minus valid). Absent draws are expected minus present.
Median and 2.5%/97.5% quantiles are conditional on valid realizations and are
chronology-related uncertainty, not model confidence intervals. Empty eligible
or valid groups receive `NA` statistics; their summary rows do not add observations
or draws. A transition with only a handful of valid draws is retained with
visibly limited support. Detailed geometry stays in calculation records.

The 21-column Anthropocene model input preserves all paired plot identities,
survey and climate-window midyears, both elapsed times, binary fire assignments,
the seven responses and four validity flags. Detailed modern endpoints, seasonal
changes and assignment provenance remain in a separate calculations CSV. For an
MORA resurvey in 2015, vegetation elapsed time is 2015−1977.5 = 37.5 years while
climate elapsed time is 2012.5−1984 = 28.5 years. Consequently magnitude and rate
tracking ratios are both retained and are not interchangeable.

The descriptive 100-year grid contains only the seven agreed responses. For each
response separately, summarize finite draws within each actual transition and
offset, map the transition onto dates using `[age_lo, age_hi)`, and summarize
the offset medians. A lake/date/response requires a finite median from every
configured offset. Complete-offset eligibility for angle or a counterfactual
cannot remove valid lag, turnover or tracking-ratio values. At Reflection Pond,
5,900 cal BP, angle and pace effect have finite medians in nine of ten offsets;
only those two reporting values are excluded. Their transition-level model and
uncertainty records remain available. No matching coverage across lakes is required.

Both maintained tracking visualizations annotate every Holocene row with the
regional climate-era bands already used in Figure 2. They read the frozen
stage-13 era catalog and climate-change subphases: darker gray denotes CC,
lighter gray denotes relative stability, and CC1a–CC1c retain their existing
internal boundaries. These shared regional annotations do not classify lakes
individually or enter the model tables as predictors. The plotting stage
preserves response estimates and leaves dates outside the classified
9,600–1,300 cal-BP domain unshaded. Modern boxplots retain their existing layout.

### Native 100-year sampling diagnostic before CCA

`R/stages/000_occurrence_data_consolidate.R` also produces
`plot/test_figures/fig_holocene_sampling_fire_100yr.pdf`, shown immediately before
CCA calibration in the Analysis Review. Count each prepared macrofossil ID once
at its median age across the 100 existing cached draws, on native climate cells
`[center − 50, center + 50)`. Separate lake lines share one sample-count scale.
These counts include CCA-ineligible samples and do not create 100-year vegetation
responses or propagate chronology uncertainty.

Fire values in this diagnostic are raw accepted detections from fully covered
100-year cells. MORA sums the covered regional cores, requiring at least two;
NOCA uses Panther Potholes. Covered zero-event cells remain zero, inadequate
coverage is missing and breaks the line. MORA totals can use two or three cores,
and overlapping detections are not deduplicated. Different source resolutions
also prevent interpreting these raw park totals as comparable fire intensity.
The figure leaves normalized 1,000-year `fire_activity`, high-fire periods,
tracking calculations and fitted models unchanged. Counts are not interpolated.

### Combined transition input and provisional offset models

Stage 09b assembles `cca_tracking_era_by_offset.csv` from the canonical lake
transition and modern plot tables and detailed calculation records. Its [28-column contract](OUTPUTS.md#canonical-tracking-schemas)
retains one response per actual observation, both elapsed times, known survey
and climate dates, physical climate rate, original fire exposure, lake support
and WGS84 coordinates. Modern pairs appear once per response with an absent
offset; each offset fit reuses them. Response validity is determined separately
by finite estimates. Holocene estimates remain chronology-draw medians within
actual transitions, without aggregation across offsets or reporting dates.
The long layout and reuse of modern pairs do not create independent replicates.
The 16-column reporting-grid comparison and its model trials are retired.
Descriptive tracking plots still reconstruct their aligned predictor medians
from source transitions using the existing response-specific reporting rule.

Stage 10 runs the same provisional Gaussian GLS separately at all ten offsets
for observed lag-change rate, observed community turnover, raw physical
climate-change rate and the two corrected lag-change rates. It fits `estimate ~ era * site` with REML and era/site
residual variances, trying AR1, MA1 and independent residuals. One combined coefficient
CSV flags offset and `model_type`. A separate contrast CSV holds Anthropocene
minus Holocene within MORA and within NOCA: 60 contrasts per response with unadjusted 95%
intervals and Satterthwaite degrees of freedom. Positive contrasts indicate a
higher Anthropocene response. One TXT holds all fit summaries, park contrasts
and fit comparisons. The AIC PDF compares all three covariance candidates.
Following the author’s 2026-10-09 decision, group-mean, coefficient, contrast
and residual PDFs present MA1 only. Distribution and inference remain exploratory.

Holocene time indices are spaced by the actual interval width; missing
transitions keep their original gaps. Modern pairs are independent singleton
series with an internal dummy index of zero and their actual calendar dates
retained. MA1 uses `corARMA(p=0,q=1)`: residual correlation is zero beyond one
time step within a series. Its fitted moving-average parameter is not directly
the neighboring residual correlation: rho(1) = theta / (1 + theta²).
[The official nlme documentation](https://stat.ethz.ch/R-manual/R-devel/library/nlme/html/corARMA.html)
defines its integer time covariate and series grouping. AR1 permits correlations
at longer lags. The independent candidate uses `correlation=NULL` while
retaining era/site residual variances. AIC comparisons between these three
covariance choices use identical observations and fixed effects within an
offset. REML is retained for this covariance comparison; likelihood comparisons
under REML require the same fixed effects, as described in the
[official nlme comparison documentation](https://stat.ethz.ch/R-manual/R-devel/library/nlme/html/anova.gls.html).

The 30-row comparison CSV records likelihoods, parameter counts, AIC, ΔAIC,
relative Akaike weights and ranks. ΔAIC is measured from the lowest AIC within
each offset. Weights are relative to these three candidates, not probabilities
that one is the true model. The figure shows only paired within-offset ΔAIC
boxplots; raw AIC values remain in the CSV. Offsets have different observations
and are sensitivity fits, so raw AIC cannot select covariance choices across
offsets. Selection is an explicit scientific decision, not an automatic rule.

**MA(1) selected for the reported lag-change analyses (2026-10-09).** The author
chose MA1 after reviewing the within-offset comparison. MA1 is competitive:
it minimizes AIC at five offsets, independent residuals at four and AR1 at one.
All three candidates are within two AIC units at nine of ten offsets. These
small differences do not uniquely identify a covariance structure. MA1 permits
dependence between immediately neighboring transitions that share endpoints
and has zero correlation beyond one actual time step. The choice is recorded
in `R/helpers/tracking_model_reporting.R` and applied consistently to offset
and lake figures. All covariance-comparison fits remain in the numerical audit.

These fits retain all finite selected responses without a draw-support cutoff.
They do not propagate chronology uncertainty, add a lake random intercept or
include climate/fire fixed effects. The residual page shows normalized scatter,
Q-Q and Holocene lag products for the selected MA1 covariance. Lag products match
actual time gaps, exclude modern singleton series, and report pair counts;
they are descriptive diagnostics without formal significance tests.

Stage 10a maintains the offset-0 lake sensitivity authorized on 2026-10-09.
Each Holocene lake is compared separately with its own park's modern plot
pairs with `estimate ~ era`, REML and era-specific residual
variances. Its figures show MA1 only: four fits, eight coefficients and four
contrasts. The AR1 fits remain in the calculation audit. A constant park factor is omitted within these individual fits.
The three MORA comparisons reuse the same 330 modern plots; their estimates
are overlapping sensitivity results, not independent park replicates.
All finite responses remain eligible and actual within-lake time gaps remain.
Reflection Pond and Panther Potholes MA1 fits have parameters near -1;
fits with an absolute parameter above 0.98 are retained and explicitly flagged
in tables and figures. This diagnostic flag does not select a covariance model.
The review shows offset 0 only. There is no automatic lake fit at additional offsets, no averaged lake result,
and no comparison of AICs across different lake inputs. MA(2) is not maintained.

The GLS models support estimated marginal means through `emmeans`, using
Satterthwaite degrees of freedom. Within-park era means and their contrasts
are already included in stage 10's TXT. The contrast is Anthropocene mean minus
Holocene mean; its SE uses the fitted covariance of those means. Group-mean
and contrast intervals are model-based intervals, not chronology quantiles.
The author requested integration of the group-mean display on 2026-10-09.
The maintained MA1 figure shows two park columns, with offset-specific Holocene
means, one Anthropocene mean per park, and offset-specific differences in aligned rows.
Rows use separate scales; parks share a scale within a row. Each response exports
40 MA1 group means with 95% Satterthwaite intervals and observation counts.
The differences retain covariance between the fitted means. Modern means are
constant across offsets because the same modern pairs are reused. On 2026-10-09
the author requested that the modern mean appear only once per park in each
response figure. Its displayed interval comes from offset 0; fitted uncertainty
can vary slightly across offsets and remains in the full tables and contrasts.
Offsets remain sensitivity realizations and are not averaged into a new model.

**Observed-turnover exercise (2026-10-09).** The author requested the same
model exercise for `observed_turnover_rate`: observed CCA movement magnitude
per century using vegetation elapsed time. Stages 10/10a include both tracking
responses by default, preserving separate output folders and response-specific
finite-value selection. Turnover gets the same three-candidate covariance
comparison, MA1 group means/coefficients/contrasts/residuals, and offset-0 lake
sensitivity. All 30 offset fits and eight lake fits converge without warnings.
Independent residuals minimize turnover AIC at all ten offsets; MA1 is within
two AIC units everywhere. This comparison is response-specific and does not
inherit the evidence for the lag-rate MA1 decision. MA1 is retained as the
requested working reporting specification. Jay Bath’s turnover MA1 lake fit
approaches +1 and is explicitly flagged without removing it.

Turnover is nonnegative. Gaussian GLS is the requested initial exercise,
without a new distribution choice or response transformation. Some Holocene
mean intervals extend below zero; intervals are not truncated. The eventual
turnover distribution and covariance choice remain subjects for model development.

**Untransformed climate-rate exercise (2026-10-09).** The author requested the
same offset models and outputs for `standardized_climate_change_rate`, explicitly
without logging. Stages 10/10a now run this third response by default. The response
is the existing standardized physical climate-change rate in calibration SD per
century; it is not predicted CCA displacement. One copy of each actual transition
or modern plot is selected from the repeated fixed fields in the combined CSV.
Conflicting copies stop selection. Climate validity is checked independently of
tracking-response validity, and the seven-response CSV contracts are unchanged.

The same raw-scale Gaussian GLS, `era * site`, REML and era/site residual variances
are compared under AR1, MA1 and independent residuals for each of ten offsets.
All 30 offset fits and eight offset-0 lake fits converge without warnings. AIC
minima favor independent residuals at four offsets, MA1 at three and AR1 at three;
MA1 remains the requested reporting specification, with delta AIC up to 2.65.
Each response exports its own coefficients, means, contrasts, comparisons,
complete TXT and diagnostic PDFs. Panther Potholes' MA1 climate lake parameter
approaches +1 and is retained with the existing boundary flag.

This extension selects no transformation or new distribution. Per-century units
do not equalize temporal averaging between 1,000-year Holocene transitions and
shorter modern intervals. Modern spatial dependence and chronology uncertainty
are not addressed by this initial GLS. The same modern observations are reused
across offsets and MORA lake sensitivities; these runs are not independent
replicates. Continuous fire activity is outside this response-model extension.

**Corrected lag-rate model extension and manuscript Figure 4 (2026-10-10).**
The author anchored the contrast/scatter preview and requested the same model
exercise for pace- and direction-corrected lag changes. The new responses are
`pace_corrected_lag_rate_per_century` and
`direction_corrected_lag_rate_per_century`: `(corrected final lag - initial lag)`
multiplied by `100 / climate_dt_years`. They retain the original counterfactual
geometry, tolerance and elapsed time. Stage 09b derives them from the detailed
calculation records within each chronology draw, then takes finite-draw medians.
Subtracting an effect median from an observed-rate median is not equivalent.
The canonical 23/21-column tables and seven-response uncertainty/reporting
contracts remain unchanged; two response names are added as rows to the
28-column combined input, now 7,920 rows. MA1 remains the working covariance,
with the same coefficients, means, contrasts and residual diagnostics across
all ten offsets and the existing offset-0 lake sensitivity. The three covariance
candidates remain in the numerical comparison audit. Corrected rates are signed,
descriptive changes, not corrected lag levels or causal contributions.

All 607 modern pairs have defined direction corrections. Pace is undefined
for 142 stationary modern plots (76 MORA, 66 NOCA); its model uses 254 MORA and
211 NOCA pairs. Exclusions are response-specific; other responses retain their
observations. Original time gaps, lake identities and finite-draw medians remain.
The same scale conventions and model limitations apply to all five responses.

Stage 10b shows three offset-0 MA1 era contrasts in the first row of Figure 4:
standardized climate change per century, community turnover rate and observed
lag change. MORA and NOCA appear side by side, with blue/orange dots, error bars
and numeric annotations. Response labels have no additional color. Climate and
community/lag rates use separate scales with aligned zeros and left-side y-axes.
CCA axes specify CCA distance per century. Pace- and direction-corrected lag
contrasts are retained in a separate PDF registered in the Analysis Review,
with pink/purple correction labels and the same model results. Both figures use
larger fonts. Stars mark unadjusted contrast `p < 0.05`; nonsignificant error bars
are faint, as are nonsignificant NOCA dots and numeric annotations, without an
opacity legend. Point ratios of fitted Anthropocene to
Holocene means are printed below bars without ratio uncertainty. Lag ratios
may be negative on sign reversal or unstable near a zero denominator; these
labels support description, while the absolute contrast retains its model
interval. They are not multiplicative inference for signed lag rates.

The second row has separate-era scatter panels of observed versus corrected
lag-change rates, pooling parks. Correlation lines are descriptive linear fits.
Spearman rho and nominal p values do not adjust for lake/temporal dependence or
mathematical coupling between observed and corrected responses. Only observed
lag rates have top densities; each input appears once, with the original MA1
park/era means and 95% intervals beside the scatter border. Each scatter panel
has grey interpretation labels below/above the diagonal and on the 1:1 reference,
with equal x/y distance scales. No corrected density,
figure caption, overall title or count subtitle is drawn. Scatter axes identify
observed lag-change rate and lag-change rate after correction without unit
suffixes; both remain in CCA distance per century. Definitions and limitations
are maintained in the review. The figures reuse results,
validates 20 means and ten contrasts, and preserves calibration, chronology and
Figures 2/3 without refitting or response transformations.

The 273 primary transition rows span ten alternative bin placements. **Offsets
are sensitivity realizations, not independent ecological replicates.** The
intended primary statistical approach is to analyze non-overlapping transitions
separately within each offset, considering lake identity and temporal dependence
during later model development. Adjacent transitions share endpoint information.
Chronology draws and overlapping reporting dates are also not independent
replicates. MA1 is chosen for the reported results; final model inclusion,
distribution and uncertainty treatment remain future decisions.
Approximately 5–6 majority-supported transitions per MORA lake per offset and
9–10 for Panther Potholes imply limited support for a later three-way interaction;
four lakes and shared fire histories must not be treated as abundant independent
replication. Covariance comparisons remain available; no final distribution,
lake random effect, power analysis or contribution attribution is selected here. See [output schemas](OUTPUTS.md#canonical-tracking-schemas).

## Unified 1,000-year climate eras

- `R/stages/13_holocene_climate_fire_eras.R` is the sole Holocene era authority. It
  derives adjacent complete 1,000-year changes from the four native pond
  trajectories and uses ten 100-year bin phases. Fixed climate windows contain
  no Bacon chronology draws; phase spread is placement sensitivity, not
  ecological replication or full paleoclimate uncertainty.
- Signed changes in `MSpT`, `MWT`, `SP`, and `WP` are divided by the pooled
  legacy CCA calibration SDs. MORA's three lakes are averaged first; the MORA
  and NOCA site trajectories then receive equal regional weight.
- **Standardization sensitivity to discuss later.** The active denominator
  remains each variable's SD across the 607 matched MORA/NOCA legacy calibration
  plots. This fixed, model-calibration reference is independent of the
  Holocene and Anthropocene records being evaluated. A future sensitivity could
  instead calculate one SD per variable across all available climate values,
  which would answer a dataset-relative rather than calibration-relative
  question and would be influenced by temporal/site coverage and extremes.
  Under the current variable-specific 50%-of-own-maximum rule, any fixed
  positive SD for a variable cancels algebraically; therefore this alternative
  would not change qualifying dates, directional phase support, or CC/S
  boundaries. It would change displayed standardized magnitudes and stability
  ranges, relative cross-variable visual weighting, the unthresholded
  multivariate composite, and standardized multivariate climate rates. Raw
  physical-unit rates would remain unchanged. This is recorded for later
  discussion and does not alter the active analysis.
- Each variable's operational cutoff is 50% of its own maximum absolute median
  regional change. Direction is the sign of that regional median and at least
  eight of ten regional phases must support it. MORA/NOCA site agreement is
  retained in the audit table but is not a veto.
- A 100-year cell is `climate change` whenever any of the four variables
  qualifies; otherwise it is `relative stability`. Only directly contiguous
  cells are merged. There is no site-divergence class, transition state,
  forward extension, or gap bridging.
- Complete ten-phase support currently spans 9.6–1.3 ka. The resulting sequence
  is CC1 9.6–7.2, S1 7.2–6.8, CC2 6.8–6.2, S2 6.2–5.4, CC3 5.4–4.9, S3
  4.9–2.2, CC4 2.2–1.7, and S4 1.7–1.3 ka. Driver subintervals preserve the
  actual variable and physical direction; the numbered era names are neutral.
- A CC era is subdivided only when an internal minimum-active-driver run lasts
  at least 300 years and is flanked by multi-driver cells. Drivers name a
  subphase only when active in at least 60% of its 100-year cells. This detects
  CC1a 9.6–8.6 ka (spring cooling, winter warming, summer drying), CC1b
  8.6–8.2 ka (winter-wetting transition), and CC1c 8.2–7.2 ka (spring warming,
  winter warming, summer wetting). It does not split CC2–CC4 and does not alter
  the authoritative parent CC/S boundaries.
- The composite `sqrt(sum((delta variable / legacy calibration SD)^2))` is
  retained as an unthresholded context curve. It is unsigned and cannot select
  an era or determine warming/cooling/wetting/drying. The 50% cutoff is an
  operational effect-size rule, not a significance test.
- The authoritative figure reads the stability bands from the threshold table
  and brackets them in the incomplete-coverage margin. Rounded standardized
  ranges are MSpT ±0.086, MWT ±0.110, SP ±0.088, and WP ±0.056; these are the
  same cutoffs used by the classifier, not hand-entered graphical thresholds.
- The raw-rate comparison uses physical units per century. For Holocene climate,
  MORA and NOCA raw 1,000-year changes receive equal weight within each offset,
  are divided by ten, summarized by the median across offsets at each date, and
  then selected as the maximum-absolute regional median while retaining sign and
  age. Anthropocene entries are annualized short-window contrasts: MORA compares
  1979–1989 with each adult year Y−5 through Y, using plot-specific midpoint
  intervals of 27.5–32.5 years at MORA and 27.5–28.5 years at NOCA. The table shows site-specific medians
  of plot-level physical rates; standardized scores are not used. The MORA
  precipitation contrast carries the possible post-2010 CHELSA inhomogeneity
  caveat documented in `data/SOURCES_SURVEY_YEARS.md`.
- Climate classification does not read fire, literature, archaeology,
  vegetation, or tracking. The maintained literature table remains a
  non-authoritative reference. Frozen CC/S labels are joined afterward to
  complete-offset site-date tracking rows for descriptive plots; this join
  cannot alter climate boundaries.

## Harmonized tapas detection, Walsh audit, and high-fire evidence

- One reusable `tapas` detector is authoritative for Sunrise, Shadow, Little
  Sunrise, and Panther Potholes. Published temporal/threshold settings are still
  record-specific: MORA uses 48/800/95%, 47/1,000/95%, and 42/500/95%; NOCA
  uses the active 12/500/99% setting. Every record uses untransformed CHAR,
  robust LOWESS, residual peaks, a local Gaussian-mixture threshold, a 75-year
  count window, `p <= 0.05`, and collapsed adjacent exceedances. The current
  accepted totals are 17, 14, 13, and 66, respectively. A 12.5-year NOCA
  interpolation yields 72 events and is retained as publication-resolution
  sensitivity, not as the primary chronology grid.
- `R/stages/12_walsh_fire_reproduction.R` additionally runs official CharAnalysis R
  2.0.3 against the three Walsh MORA workbooks. This is a software/publication
  audit only; it is isolated from the authoritative all-`tapas` catalog and
  hash-checks `fire_walsh.csv` and `paleo_fire.csv` before/after.
- Official R 2.0.3 yields 15 Sunrise, 16 Shadow, and 14 Little Sunrise episodes.
  Walsh reports 24, 18, and 16. These discrepancies are an explicit software/
  implementation audit; thresholds were not modified to force agreement.
- `R/stages/12a_fire_event_detection_worked_example.R` separates individual-event
  detection from the later high-fire-period rule. Its three-page figure shows the
  common chain—interpolation, robust LOWESS background, positive residual,
  local Gaussian-mixture threshold, 75-year count screen, accepted event—for
  every core, with all four residual/threshold plots together on one page.
  It also shows the source differences: MORA uses 42–48-year
  interpolation, lake-specific 500–1,000-year backgrounds, and 95% thresholds;
  Panther Potholes uses 12-year interpolation, a 500-year background, and a 99%
  threshold. Current candidate/rejected/accepted counts are Sunrise 26/9/17,
  Shadow 17/3/14, Little Sunrise 20/7/13, and Panther Potholes 66/0/66. Its last
  page keeps the separate MORA `tapas`/CharAnalysis/publication comparison.
  The official audit does not change CCA fire flags.
- The harmonized source stage supplies source series and accepted events but does not select
  PaleoACES high-fire periods. The unified stage calculates centered 1,000-year
  accepted-event frequency, normalizes each core by its own maximum, and equally
  averages MORA cores wherever at least two are covered. Panther Potholes is
  interpreted locally under the active 12-year/500-year/99% settings and has 66
  accepted peaks.
- High fire requires the normalized site frequency to exceed its temporal median
  plus `1.4826 × MAD`. Every contiguous above-threshold run is retained without
  gap bridging or an extra duration filter. Current outputs contain five MORA
  and six NOCA runs.
- The climate/fire display expresses this frozen rule as a dimensionless
  fire-frequency ratio: normalized site frequency divided by its site-specific
  threshold. The dashed line at 1 is the exact high-fire cutoff. This is a
  display transformation, not a new fire index or permission to compare raw
  MORA and NOCA charcoal magnitudes.
- Within-core peak-strength percentiles and standardized background CHAR are
  corroborating markers only. They cannot independently create a high-fire
  period, and raw charcoal magnitudes are never compared between sites.
- `R/stages/13b_fire_method_worked_example.R` exposes the complete arithmetic at
  2,300 cal BP. The centered `[1,800, 2,800)` window contains 3 Little Sunrise,
  2 Shadow, 3 Sunrise, and 7 Panther Potholes accepted events. Core-normalized
  frequencies are 1.000, 0.667, 1.000, and 0.636; consequently the equal-core
  MORA frequency exceeds its site threshold (ratio 1.46), whereas the local
  NOCA frequency does not (ratio 0.94). This date illustrates the frozen rule;
  it was not used to choose the threshold or tune the classifications.

## Preserved Figure 3 era-centroid trajectories

- The primary CCA fit is unchanged. The selected display uses the exact current
  `scaling = "sites"` (vegan scaling 1), Hill-off, CCA1–CCA2 geometry and the
  complete original `fig_cca_trajectories` architecture. Holocene
  observations are assembled into one observed WA and one predicted LC centroid
  per site × CC1–S4 era. The two paths are connected separately and
  chronologically from CC1 through S4 with arrows. All eight site × era ×
  observed/predicted paths are directly named with independently positioned,
  tightly spaced two-line unboxed text;
  predicted paths and annotations are lighter, and an enlarged arrow-only
  legend distinguishes observed from predicted. The NOCA Holocene observed
  label is anchored above CC1 and the MORA equivalent below CC4. The publication
  panels are A. trajectories, B. the
  climate/species biplot inset, C. climate contributions, and D. species
  contributions. Individual Holocene dates, the pooled full-record centroid,
  and the duplicate era-centroid compatibility render are not active displays.
### Within-era lag predictor models (2026-10-11)

The author requested a separate stage 10c for observed, pace-corrected and
direction-corrected lag-change rates. Each Holocene offset uses
`site + climate_rate + fire_activity`, REML, MA(1) within lake and separate
park residual variances. Responses retain their original CCA distance per
century scales, independently filtered mathematical validity and existing
chronology-draw medians. No interaction, transformation, draw-support cutoff
or aggregation of observations across offsets is added. MORA lakes remain separate vegetation
responses to the same regional fire exposure; adjacent transitions share
endpoints and offsets are sensitivity realizations.

At offset 0 only, each response receives a random lake-intercept LME sensitivity
on identical observations. All three lake SD estimates are effectively zero
(approximately 1.8–3.8×10⁻⁷), with coefficient changes below 3.3×10⁻⁷.
Observed lag has a non-positive-definite approximate covariance and failed
variance intervals. The corrected fits return covariance matrices but lake-SD
intervals from zero to infinity. These are uninformative variance-boundary
results, not optimizer failures or evidence of no ecological lake differences.
The main specification remains GLS; no random-effect fit is repeated at other offsets.

Temporal predictions use each fit's actual interval predictors. Supported
intervals alone are mapped onto 100-year display dates via `[age_lo, age_hi)`;
the dates repeat interval predictions and do not add measurements or independent
samples. There is no extrapolation or offset median. Predicted lag-change rates
are not integrated into an absolute lag trajectory. CC/S grey bands reuse the
frozen regional catalog solely as context. R² is explicitly descriptive,
unweighted and in sample (`1 - SSE/SST`); negative values are retained because
GLS optimizes a different, covariance-weighted objective. No claim of model
significance or validated predictive performance follows from this R².

The initial modern model is `site + burned`, with REML, independent residuals
and site residual variances. The author also requested
`site + elevation + climate_rate + burned` for all three lag responses.
Elevation remains in meters and is joined from native sources by normalized
site/plot identity. All 607 paired plots have elevation. Corrected pace alone
has 465 finite responses. The burn term is additive and common across parks;
only two MORA plots are burned, so the effect is chiefly supported by NOCA.
Binary modern burning is not treated as comparable to Holocene charcoal activity.
Different fixed-effect specifications are not compared by REML AIC.

The author chose independent modern residuals first, with a spatial diagnostic.
Stage 10c checks normalized residual Moran I separately within each park using
UTM 10N coordinates, symmetric row-standardized eight-neighbor graphs and 999
fixed-seed permutations. Several fits show positive spatial residual association,
including observed lag in both parks. The nominal permutation tests are
exploratory and do not adjust for multiple checks or covariance-estimation
uncertainty. This result motivates a later spatial sensitivity; it does not
silently replace the specified independent models. Coefficient intervals remain
provisional given spatial pattern, response diagnostics and limited lake/fire support.

The [workflow](WORKFLOW.md#within-era-predictor-models),
[output contracts](OUTPUTS.md#within-era-predictor-model-records) and
[Analysis Review](ANALYSIS_REVIEW.md#within-era-climate-fire-and-elevation-predictor-models)
identify maintained code, coefficients across offsets, joint offset-0/modern
figures, residual diagnostics and full results.

### Holocene reconstruction-ensemble coefficients (2026-10-11)

The author requested equal-weight integration of the existing explanatory GLS
results after their separate fits, then requested exclusion of offset 800 from
the ensemble for all three responses. The ensemble now uses nine 1,000-year
bin offsets (0–700 and 900), each weighted 1/9. All ten individual-offset fits
and sensitivity diagnostics remain unchanged; offset 800 has zero ensemble weight
and an explicit exclusion flag and reason in the audit.
The fixed/covariance specifications, response medians, predictor calculations
and valid-transition selection remain unchanged. For each response, every
included offset contributes 50,000 samples to a 450,000-sample mixture from a joint multivariate-normal approximation
using its fitted coefficients and full fixed-effect variance–covariance matrix.
The exact mean of offset coefficients is the ensemble point estimate; 2.5 and
97.5 percentiles of the equally weighted mixture define
**reconstruction-ensemble uncertainty**. These are not conventional confidence
intervals or a newly fitted common-effect model. There are no pooled p-values,
independent-offset assumptions, AIC/R² weights or √9 uncertainty reduction.

Only bin placement is integrated as reconstruction uncertainty. Existing
conditional GLS coefficient uncertainty remains in each component; Bacon
chronology uncertainty is not propagated by fitting the chronology draws.
The offset range and sign counts remain visible. Sign consistency is a
descriptive proportion of offsets, not a probability that the effect exists.
Temporal coverage and sample support vary among offsets; equal weights express
equal plausibility of the nine included origins rather than equivalent coverage or replicates.

Every configured offset must have a converged, compatible GLS fit and a finite
positive-definite fixed-effect covariance. Missing or failed fits stop ensemble
generation rather than silently changing weights. Residual covariance status,
MA1 boundary estimates, lake/park support and differences in phase-aligned
transition coverage are audited separately for all ten fits. The two pace-corrected boundary
fits remain included. The unusual direction-corrected offset 800 is retained
in individual-offset diagnostics and excluded from the ensemble at the author's request.
It reflects climate-direction rotation around 3,800 BP and opposing
park relationships under a shared slope; its negative descriptive R² remains
visible. The compact coefficient figure and results table supplement rather
than replace the individual-offset sensitivity diagnostics.

## Remaining scientific questions

CCA sample eligibility, balanced observed/predicted exclusions and paired
Figure 3 endpoints are resolved and require no further decision. The survey-year
and climate-window choices are also settled. The four
questions below remain; the SD-reference and target-origin alternatives are
optional sensitivities. The CARI449/CARI450 GPS exclusion is resolved. Unequal modern climate-window lengths are an accepted trade-off;
the precipitation-continuity concern is separate from that settled choice.

The chronology controls and adopted uncertainty assumptions were reconsidered
and retained on 2026-10-06. They no longer require a decision for the current
analysis. Conditional uncertainty, assumed errors and the unverified basal-lahar
correlation remain interpretation limits documented above and in the MORA source
notes; any future chronology revision is separate work.

| Question | Current choice | Consequence | Evidence needed to resolve it |
|---|---|---|---|
| Raw versus V2.1-anchored TraCE21k climate | The active Holocene analysis uses raw TraCE21k values; the V2.1 anchoring diagnostic is not authoritative. | Absolute Holocene climate levels and cross-product comparisons may retain product bias, although the active within-series change calculations are internally consistent. | A validated overlap-period comparison showing whether anchoring reduces bias without introducing a discontinuity or changing the intended anomaly interpretation. |
| Legacy-calibration versus full-record climate SDs | Changes are divided by SDs from the 607 matched legacy CCA calibration plots. | The reference is tied to the fitted model. A full-record SD would change displayed standardized magnitudes, cross-variable weighting, the unthresholded composite, and standardized climate rates, but not CC/S boundaries under the current variable-specific 50%-of-own-maximum rule. | A prespecified full-record sensitivity with explicit temporal/site weighting and a scientific choice between calibration-relative and dataset-relative effect sizes. |
| Anthropocene precipitation continuity | Historical climate remains 1979–1989; modern climate uses adult Y−5 through Y at both sites (2026-10-07 decision). The MORA precipitation contrast is flagged. | The apparent post-2010 MORA precipitation shift may partly reflect CHELSA inhomogeneity rather than climate. | Independent station/reanalysis validation and a documented decision on whether post-2010 MORA precipitation is usable. The agreed years are not a pending decision. |
| Own-origin versus common-origin taxon target geometry | Deferred: the target-alignment analysis is retired. Existing CCA scores and reference matrices are preserved for future contribution analysis. | The two cosines answer alignment relative to each trajectory's own starting community; part of their difference can arise because LC₁ and WA₁ differ. | A prespecified common-origin sensitivity and an ecological decision about whether the estimand should condition on each starting state or hold the target vector fixed across observed and predicted movement. |

## Inference limits

- **Adult-tree plot areas (confirmed 2026-10-08):** the author confirmed that
  resurvey plots cover 500 m² at both MORA and NOCA. Legacy areas vary: the
  retained MORA plots have areas of 250, 375, 500 or 1,000 m²; recorded NOCA
  areas range from 25 to 400 m², with four retained plots lacking an area.
  Pairing matches plot identities; sampled areas can differ between dates.
  No area restriction is applied. MORA summaries use `Site info` → `Plotarea`
  in the original legacy workbook; `BACK-245` and `LONG-356` are recorded as
  500 m² there despite conflicting species-row entries in `rawsizedata`.
  NOCA summaries use `OVERVIEW` → `PLOT(M2)` in the Agee workbook. See the
  [retained plot-size counts](assets/analysis/tables/sample_selection_plot_sizes.csv).
- NOCA size classes differ between surveys: legacy regeneration spans 0–3 m
  and adults exceed 3 m; resurvey seedlings span 10–140 cm and trees exceed
  1.4 m. Neither stratum is an identical size-class measurement across dates.
- **Primary provenance for MORA survey dates:** the analysis-year choice is
  resolved. MORA vegetation rates use 1977.5 as the legacy reference and each
  plot's selected adult resurvey year; the modeled resurveys span 2014–2019.
  Historical climate remains 1979–1989; modern climate uses Y−5 through Y. The original Torres draft and primary
  legacy-date records are not filed in the repository, so their historical
  verification remains a provenance limitation, not an undecided analysis
  setting. See [survey-year sources](../data/SOURCES_SURVEY_YEARS.md).
- Climate and fire are classified independently and merely aligned in the
  integrated figure; neither evidence stream defines the other. Literature is
  not part of this stage and cannot change a boundary.
- Chronology precision is not equivalent among the published MORA cores and
  Panther Potholes. Cross-site fire timing must not be presented as equally
  uncertain.
- Paleo species occupancy remains partly site-confounded, and MORA/NOCA fire
  proxies are not equivalent. These limitations remain explicit in inference.
- MORA's mapped disturbance record covers 1987–2017, not the entire interval
  after the 1977.5 legacy reference. "Unburned" means no mapped fire evidence
  under that coverage, not verified absence of fire throughout the interval.
- Holocene fire categories use fixed median event chronologies; event-timing
  uncertainty is not propagated into the category assignments. The harmonized
  Gaussian-mixture detector also differs from Prichard's original noise
  description, so its published settings do not imply an exact reproduction of
  every original algorithmic detail.
- Overlapping dates, chronology draws and offsets are not independent
  ecological replicates. Some MORA lake transitions occur in only 1–2 draws;
  the modern MORA burned group contains two plots. These sparse supports need
  explicit treatment before fitting models.
- Native climate caches identify the reviewed local values, but cannot recover
  an immutable historical remote raster release on their own.

## Related maintained documentation

- [README](../README.md)
- [Workflow](WORKFLOW.md)
- [Tracking data validation](review/TRACKING_DATA_VALIDATION.md)
- [Holocene literature summary](references/Holocene_period_choices_MORA_NOCA_summary.pdf)
- [Bacon controls](../Cores/CONTROL_POINTS.md)
- [MORA chronology sources](../Cores/SOURCES_MORA.md)
- [NOCA paleo sources](../data/NOCA/NOCA_paleo/SOURCES.md)
- [Survey-year sources](../data/SOURCES_SURVEY_YEARS.md)
- [NOCA cleaning guide](review/000_NOCA_cleaning_guide.md)
- [Occurrence consolidation](review/README_occurrence_consolidation.md)
- [MORA raw-data reference](../data/MORA/README_data_raw.md)
- [MORA output reference](../data/README_outputs_MORA_AT.md)
