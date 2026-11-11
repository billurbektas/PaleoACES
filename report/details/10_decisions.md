# PaleoACES scientific decisions

> **Documents:** Every analytical decision, with its date and reasoning, and the remaining scientific questions.  
> **Originally:** `docs/SCIENTIFIC_DECISIONS.md` (moved into the report on 2026-11-09)

This document records current analytical choices and their limits. Execution
order and file dependencies are authoritative in [WORKFLOW.md](11_outputs_and_workflow.md).

## Study universes and vegetation

- Modern vegetation is paired within plot. MORA has 328 modeled pairs (330 until
  11 Nov 2026, when the two plots burned between the surveys, JAME-295 and
  OHAN-013, were left out of the analysis) and NOCA has 277 after excluding `BAK487` (old clearcut), `BEAV6061` (uncertain
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
[GPS source review and decision](01_vegetation_noca_gps_exclusion.md).

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

The manual exclusion is removed in `R/pipeline/09_species_occurrences.R`.
Reinstatement initially produced 14 taxa and 619 legacy calibration plots, with 607 modern
pairs (330 MORA, 277 NOCA). STE2044 returns to calibration and paired comparison;
HB2064 returns to paired comparison. The 907 included Holocene samples, their
chronologies, and the raw climate records are unchanged, but refitting the shared
CCA changes modern and Holocene positions, tracking metrics and direction
summaries. Figures 2 and 3 and the report are regenerated. Other cleaning choices,
CCA constraints, scaling and age-model settings are unchanged.

[Former rationale, source evidence and reversal](05_species_occurrence_consolidation.md#ponderosa-reinstatement)
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

The species-frequency exclusion remains in `R/pipeline/10_cca.R`. Its
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
[report](../../README.md#1-modern-vegetation).
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

[Date evidence and rationale](01_vegetation_survey_years.md),
[95-plot discrepancy table](../../data/MORA/resurvey_year_source_discrepancies.csv),
[13 latest visits](../tables/mora_repeat_visits.csv),
[seedling visit mapping](../../data/MORA/resurvey_seedling_visit_mapping.csv) and
[measured effects](../../README.md#2-climate)
record the adopted treatment. The chronology decisions below remain settled.

## Chronology and the previously discussed ²¹⁰Pb uncertainty

The Panther Potholes ²¹⁰Pb error units were discussed and documented before the
2026-10-06 audit. The detailed record is in the [NOCA paleo source notes](03_chronology_sources_NOCA.md)
and the [control-point register](03_chronology_control_points.md).
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
  uncertainty summary is insensitive. See the [stored comparison](assets/pb210_stored_sensitivity_comparison.csv)
  and [control-point register](03_chronology_control_points.md#sensitivity-variant-pantherpotholes_pb210err).
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

### Reflection Pond basal date (2026-11-09)

**Decision: replace Reflection Pond's `Basal_lahar` control with `Basal_date_mean`,
6015 ± 110 ¹⁴C yr BP at 90 cm, `cc = 1` (IntCal20).** This supersedes the
2026-10-06 retention below.

6015 is the mean of the two measured basal dates on the same lahar surface, Jay Bath
QL-1704 (6050 ± 110) and Log Wallow QL-1728 (5980 ± 60), as Dunwiddie advised
(pers. comm.: "This should be the same basal date as the other two sites. I suggest
using 6015 (average of my two dates) for all three sites."). The two dates agree
(Ward & Wilson T = 0.31). It is a radiocarbon age, so it is calibrated (`cc = 1`).
The error is the larger laboratory error rather than the error of the mean (±63),
because the mean's error omits the transfer of the date to an undated pond.
Jay Bath and Log Wallow keep their own measured dates.

The Crandell (1971) control was replaced because its 5,800–6,600 bracket is
radiocarbon-era (upper bound = Mazama, "about 6,600 years ago", ~7,630 cal BP today),
both measured basal dates on the lahar were older than its supposed maximum, and it
compressed the pre-4900 BP part of the core well below the 300–370 yr per sample
that Dunwiddie (1986) reports. Detail:
[MORA sources](03_chronology_sources_MORA.md#reflection-pond-basal-date-2026-11-09).

### MORA basal-lahar reconsideration (2026-10-06)

**Decision (superseded 2026-11-09, above): retain Reflection Pond's existing `Basal_lahar` control at 90 cm,
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
[MORA source reconsideration](03_chronology_sources_MORA.md#basal-lahar-reconsideration-2026-10-06).

## Climate and CCA

- Modern plots use CHELSA V2.1. Paleo samples use native CHELSA-TraCE21k pond
  climate matched to sample age. Raw TraCE21k is current; stationary V2.1-anchor
  correction remains an unresolved sensitivity.
- The active constraints are spring temperature (`MSpT`) and summer
  precipitation (`SP`), decided 2026-11-09 (below). They are seasonal climate
  correlates, not direct growing-degree, drought, fire or snowpack measurements.
- The pooled CCA is calibrated on 605 matched legacy plots (607 until 11 Nov 2026) and 14 retained species.
  Vegan site/scaling 1 is retained because downstream metrics use Euclidean
  sample-score distances. The model positions 1,514 of 1,599 modern and paleo
  samples.
- Climate constraints are collinear. Their marginal contributions must not be
  interpreted as additive shares of constrained inertia.
- Binary presence retains CCA's chi-square row and taxon weighting; it does not
  make plots or taxa equally weighted. The CCA1–CCA2 plane represents only part
  of total community inertia. The current axis percentages are reported in the
  [report](../../README.md#4-canonical-correspondence-analysis).
- Resurvey and paleo observations do not fit the ordination, but their species
  counts influence the cross-group retention rule. This is a descriptive
  calibration/projection design, not an independent predictive validation.
- Being inside each climate variable's legacy range does not establish support
  within the joint multivariate calibration domain. LC positions are
  climate-predicted ordination scores, not independently validated forecasts.

### CCA constraints: spring temperature and summer precipitation — decided 2026-11-09

- **Before:** four constraints, `MSpT`, `MWT`, `SP` and `WP`. The two temperatures
  had variance inflation factors of 29.5 (`MSpT`) and 26.4 (`MWT`): they load on
  the same direction and their separate coefficients (opposite-signed on CCA2)
  were not identifiable. Precipitation showed the same pattern to a lesser degree.
- **Rule for choosing constraints:** screen candidates by their correlations in
  both eras (Fig. S4) and by their variance inflation in the fitted CCA; keep one
  temperature and one precipitation variable.
- **Choice:** `MSpT` + `SP`. Spring temperature is the temperature variable that
  changes most through the Holocene; summer precipitation represents summer
  dryness. With these two the VIF is 1.08, the constrained inertia 12.8% of the
  total (13.3% with four), and both terms are significant in unrestricted and
  within-park permutation tests. `MWT` + `SP` fitted almost identically (13.0%);
  the median Holocene lag at MORA depends on which season's temperature is used,
  which is reported as a limitation, not hidden.
- **Climate eras** are classified from the CCA constraints, so they follow the
  change: the former CC1 (9600–7200 cal BP), previously split by a one-driver
  trough into CC1a–c, is now CC1, a stability era S1 (8600–8200) and CC2. All
  later boundaries are unchanged; eras are renumbered CC1–CC5 and S1–S5.
- **Display rotation:** figures in the CCA plane are rotated rigidly by the
  varimax angle (Kaiser 1958; −23.4°) so that the temperature and precipitation
  arrows lie along the two axes (`R/helpers/cca_display_rotation.R`). A rigid
  rotation preserves every distance and angle, so no tracking metric, model or
  table changes; the rotated axes are labelled as such because they are not
  ordered by eigenvalue and are slightly correlated.

<a id="lake-tracking-metrics"></a>

## Lake-level tracking responses — revised 2026-10-12

*Superseded on 2026-11-09 by the lake-period remodelling below. Kept as history.*

The ecological analysis uses one primary series per lake on native 100-year CHELSA
cells. Each original macrofossil sample receives its unrounded median age over all
stored Bacon posterior rows. Separate original samples remain separate when ages coincide.
Sample WA positions are calculated before averaging within occupied cells. Consecutive
occupied cells are connected, including gaps, with no vegetation interpolation and no
occupancy or species joint-support cutoff.

Both endpoint climate records are from the same lake and corresponding native cells.
Holocene vegetation and climate elapsed times equal the actual endpoint-age difference.
Keep both magnitude and rate tracking ratios: modern time denominators can differ.
Pace correction remains magnitude-based. All seven agreed responses and two corrected
lag-change rates retain their geometry and signs; each has its own mathematical validity.

### Physical climate and transition fire exposure

Climate rate is the Euclidean norm of seasonal changes divided by their fixed pooled
legacy SDs, multiplied by 100/elapsed years. It is not climate-predicted CCA displacement.
Fire counts accepted events over the whole transition `[age_lo, age_hi)`. Fully covered
cores contribute events × 100/duration, averaged equally. MORA requires two covered
regional cores; NOCA requires Panther Potholes coverage. Covered zeros remain zero,
inadequate coverage is NA, and identical MORA intervals share exposure. No normalization
by core maxima applies to ecological models.

NOCA accepted event identities remain fixed. Their depths are inferred from the detector
reference curve and dated using the same complete chronology as vegetation; coverage is
redated coherently. MORA published regional charcoal chronologies remain fixed.
Descriptive climate/fire period classifications retain their separate normalized 1,000-year method.

### Primary models and chronology-reconstruction sensitivity

Combined-era models retain era × site and separate residual variances by era/site.
Holocene explanatory lag models use site + climate_rate + fire_activity; modern basic
models use site + burned and extended community models additionally use elevation + climate_rate.
Responses remain untransformed. Applicable primary models compare independent, neighboring MA1
and continuous-time AR1 residual covariance on identical rows. Indices precede exclusions;
CAR1 uses actual midpoints in centuries. The user explicitly retained MA(1) as the primary
covariance for every model containing Holocene observations. Independent and CAR1 are
comparison diagnostics only. AIC recommendations are recorded separately and never replace
the primary MA(1) fit. A failed MA(1) fit is reported, without an automatic fallback.

Bacon model sensitivity is on hold for **both community and species** models. Normal workflow
runs and standalone stages 15/17 do not run it; retained code can be enabled later using
`--bacon-sensitivity` or `options(paleoaces.run_bacon_sensitivity=TRUE)`. Saved checkpoints and
historical outputs are preserved, but are not presented as current results. An interrupted
community update is incomplete and must be resumed and validated before its results are used.
Primary coefficients and intervals condition on the median-age reconstruction; they do not
additionally propagate chronology uncertainty. Stored posteriors and primary reconstruction
remain unchanged. Lake checks remain active.

### Species contributions and models

Mean normalized sample weights reconstruct mean WA exactly under the fixed species-score scaling.
Species vectors sum to delta WA for each primary/draw transition. Signed parallel contributions
along delta LC are annualized per century. Stationary directions are undefined; legitimate
zero components remain zero. Climate-variable vectors sum to delta LC and their projections
along delta WA retain displacement units. Perpendicular contributions remain retired.
Stage 17 fits species separately within MORA and NOCA. Holocene models use
`contribution_rate ~ climate_rate + fire_activity` with primary MA(1). Modern MORA uses
`contribution_rate ~ 1`; modern NOCA uses `contribution_rate ~ burned` with unburned as
the reference. Both modern models use independent residuals. Each park fit has its own residual
variance, without a site coefficient or between-park variance ratio. When resumed, chronology sensitivity
also fits each species within each park. Absence from the other park no longer blocks a fit.
Absent or otherwise constant responses, rank deficiency and failures remain explicit; zeros
are retained. Holocene intercepts are expected contributions at zero climate/fire predictors.
The Anthropocene MORA intercept estimates the overall mean contribution; the NOCA intercept
estimates the unburned mean and its fire coefficient is burned minus unburned. MORA has no fire term.
Neither an intercept nor a mean fixes the sign of every observation.
The coefficient figure also shows descriptive arithmetic means of finite primary parallel
contribution rates (one equally weighted transition/plot per value), using the species boxplot
data. Mean diamonds have no model intervals or significance fading. Undefined directions are
omitted and zeros retained; missing predictors do not exclude otherwise valid descriptive values.

### Native sampling support and manuscript displays

The pre-CCA sample-count diagnostic places each original sample once at its unrounded median
age, distinguishes macrofossil lakes on a shared count scale, and shows shared regional MORA
fire totals. Primary model figures use actual transitions and selected fits; chronology results
are separate sensitivity diagnostics. Former ecological phase tables, ensembles and figures
are retired. The previous 1,000-year calculation checkpoint and support audit remain in Git history.

Manuscript Figure 4 labels its sections A–D: climate contrasts, community/observed-lag
contrasts, Holocene lag/effect distributions, and Anthropocene lag/effect distributions. Bottom panels
use park on the x-axis and observed/pace/direction colors (green/pink/purple).
Small filled means and capped conditional 95% intervals match the top-panel style;
mean annotations use three decimals and stars from unadjusted two-sided tests against zero.
Non-significant mean points, intervals and annotations are transparent without an alpha legend.

The additional paired correction GLS is `estimate ~ era * site * correction`, with pace
and direction only. It retains MA(1) on original transition indices and models correlation
between the two corrections in each era/park group; residual SDs vary by era/park/correction.
Only complete correction pairs enter. Existing separate response models retain their own
observations. Observed distributions and means are displayed from the observed-response
model; correction-effect distributions and means come from the paired model. Mean tests against
zero are distinct from correction comparisons. Direction-minus-pace comparisons are
Holm-adjusted across four era/park cells, with unadjusted conditional 95% intervals;
correction-by-era interaction tests use a separate Holm family of two parks. Significant
correction comparisons receive brackets, differences, stars and adjusted p-values.
The joint fit is primary-only; no additional chronology fits are added.

The correction responses are `pace_effect_on_lag_per_century` and
`direction_effect_on_lag_per_century`: observed final lag minus the respective corrected final
lag, multiplied by 100 / elapsed climate years. Positive effects mean the correction reduces
lag; negative effects mean it increases lag. These replace corrected lag-change rates in all
combined-era, paired-correction, lake and community explanatory fits. The auxiliary corrected
rates remain in calculation records for auditing, not as fitted responses. Panel C/D axes read
"CCA distance per century"; legends identify observed lag-change rate and the two correction
effect rates.

## Community explanatory coefficient figure

The main coefficient figure uses the existing Holocene `site + climate_rate + fire_activity`
and Anthropocene `site + burned` models. Separate era panels show the NOCA-minus-MORA site
contrast and shared predictor slopes; additive models do not estimate park-specific fire
or climate slopes. No intercept is displayed. The main figure shows observed lag-change rate in green,
pace correction effect in pink and direction correction effect in purple, with conditional
intervals and response-specific descriptive R² in each era caption. Negative descriptive
R² values are not truncated.
The extended Anthropocene `site + elevation + climate_rate + burned` coefficients appear
in a separate appendix figure. Elevation is displayed per 100 m there; the underlying
fit and coefficient table retain the original metre unit.

## Unified 1,000-year climate eras

- `R/pipeline/11_climate_eras_high_fire.R` is the sole Holocene era authority. It
  derives adjacent complete 1,000-year changes of the CCA constraints from the
  four native pond trajectories and uses ten 100-year bin phases. Fixed climate windows contain
  no Bacon chronology draws; phase spread is placement sensitivity, not
  ecological replication or full paleoclimate uncertainty.
- Signed changes in `MSpT`, `MWT`, `SP`, and `WP` are divided by the pooled
  legacy CCA calibration SDs. MORA's three lakes are averaged first; the MORA
  and NOCA site trajectories then receive equal regional weight.
- **Standardization sensitivity to discuss later.** The active denominator
  remains each variable's SD across the 605 matched MORA/NOCA legacy calibration
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
  caveat documented in `report/details/01_vegetation_survey_years.md`.
- Climate classification does not read fire, literature, archaeology,
  vegetation, or tracking. The maintained literature table remains a
  non-authoritative reference. Frozen CC/S labels are joined afterward to
  primary actual-transition figures for descriptive context; this join
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
- `R/pipeline/08_fire_records.R` additionally runs official CharAnalysis R
  2.0.3 against the three Walsh MORA workbooks. This is a software/publication
  audit only; it is isolated from the authoritative all-`tapas` catalog and
  hash-checks `fire_walsh.csv` and `paleo_fire.csv` before/after.
- Official R 2.0.3 yields 15 Sunrise, 16 Shadow, and 14 Little Sunrise episodes.
  Walsh reports 24, 18, and 16. These discrepancies are an explicit software/
  implementation audit; thresholds were not modified to force agreement.
- `R/worked_examples.R` separates individual-event
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
- `R/worked_examples.R` exposes the complete arithmetic at
  2,300 cal BP. The centered `[1,800, 2,800)` window contains 3 Little Sunrise,
  2 Shadow, 3 Sunrise, and 7 Panther Potholes accepted events. Core-normalized
  frequencies are 1.000, 0.667, 1.000, and 0.636; consequently the equal-core
  MORA frequency exceeds its site threshold (ratio 1.46), whereas the local
  NOCA frequency does not (ratio 0.94). This date illustrates the frozen rule;
  it was not used to choose the threshold or tune the classifications.

## Figure 3 era-centroid trajectories

The figure uses two side-by-side panels: A, the full species/climate biplot; B, the zoomed
trajectory projections. All 14 species are labeled with calibration occurrence percentages.
Arrow and annotation colors encode species shares or unique climate effects as percentages
of total constrained inertia across all constrained axes. Exact contribution values remain
in the review tables. The former inset and contribution bars are combined in panel A.
Predicted paths and labels have opaque lighter park colors; the path-type legend remains
grey. All time and direct path annotations are placed jointly to reduce overlap.

Primary occupied centuries are averaged within
lake/CC-S period, then available lakes are weighted equally within park/period. Boundaries
come from the unchanged descriptive catalog. Missing lake/period observations are not filled.
Modern paths retain the same 607 paired plots and original endpoints.

## Lake-period remodelling, decided 2026-11-09

The Holocene side of the analysis was remodelled on lake-periods (Bills, 9 November 2026). The
reason is that consecutive sampled centuries differ mostly by sampling noise: one scoop of sediment
against the next moves a position by about 0.3 CCA units, while the ecological drift is 0.01 to 0.04
units per century. The decisions below replace the century-transition models of the sections
"Lake-level tracking responses", "Community explanatory coefficient figure" and "Figure 3 era-centroid
trajectories", which are kept as history.

| Point | Decision |
|---|---|
| Unit of analysis | One lake within one climate period (a lake-period), compared from its oldest to its youngest sampled century. A lake needs samples in at least two centuries of a period. The centuries in between enter no model. |
| Periods | The climate periods of `R/pipeline/11_climate_eras_high_fire.R`, drawn from MSpT and SP with unchanged rules, named C (climate change) and S (stability), never CC. Sub-periods count as periods where a C period is split. |
| Endpoints and climate | One sampled century per end, the centroid of its samples' WA positions. Each lake's own climate cell for the predicted positions and the climate change rate. Park-average climate for the period boundaries and Figure 2. |
| Responses | Lag rate, turnover rate, pace effect, direction effect and the standardized climate change rate, computed once per lake-period with the existing tracking geometry. Where the observed or the predicted position did not move, pace, direction and species contributions are undefined, in both eras. |
| Fire | Accepted events between t1 and t2, per century, per covered charcoal core, one value per park, not rescaled within park. |
| Holocene explanatory model | response ~ site + climate_rate + fire_activity, AR(1) on the lake-period order within lake fixed a priori, residual variance per park times the endpoint sampling variance (1/n_start + 1/n_end). No lake random intercept, no period label, no interactions. |
| Era models | response ~ period_type * site with period types Holocene-S, Holocene-C and Anthropocene, the same AR(1) and endpoint weights, residual variance per period type and park. The Holocene is never pooled across C and S, and the parks are never pooled. Folds of climate change rate and turnover rate against each Holocene type. The joint pace and direction model uses the same AR(1) and weights. |
| Species | Two measures per lake-period and plot pair: the projection of each species' vector on the predicted movement and on the gap at the start. Plain means with t-intervals per species, park and period type, no species model (Bills, during the run). |
| Removed | The comparison of independent, MA(1) and CAR(1) residuals, the individual-lake era checks, the lake random-intercept sensitivity, the Anthropocene model with elevation and the species slope models. |
| Display rotation | Every CCA-space figure is rotated by the closed-form varimax angle, axis 1 spring temperature to the right, axis 2 summer precipitation upward. All tables stay unrotated, and the pipeline asserts that no metric changes under the rotation. |
| Lag (10 Nov) | A sixth era-model response, the lag M at t2 minus M at t1, not divided by time (Bills). |
| Displacement (10 Nov) | A seventh era-model response, `displacement`: the observed community movement from t1 to t2 in CCA space (`observed_vegetation_displacement`), not divided by time, fitted with the same era model as the lag (Bills). A supplement table gives the mean displacement, the mean absolute lag and the mean lag of the lake-periods per park in three duration classes (200 to 400, 500 to 900, over 2,000 years). |
| Climate change (10 Nov) | An eighth era-model response, `climate_change`: the distance between the climates at the two ends in standardized climate space (`standardized_climate_displacement`, calibration SD), not divided by time, the total behind the climate change rate (Bills). |
| Pace and direction totals (10 Nov) | `pace_effect_total` and `direction_effect_total`, the pace and direction effects not divided by time (`pace_effect_on_lag`, `direction_effect_on_lag`), undefined where the per-century effects are, fitted with the same era model. Figure 5 shows each effect as a total and a rate in two rows, the totals on one y scale and the rates on another (Bills). |
| Explanatory models not divided by time (10 Nov) | The Step 5 models are also fitted on `lag`, `pace_effect_total` and `direction_effect_total`, with the climate change between the two ends (`climate_change`) in place of the climate change rate. Fire activity stays a frequency (events per century per core), since a count would grow with the length of the lake-period. The Anthropocene counterparts use `site + burned`. Figure 6 shows the per-century models on top and the totals below (Bills). |
| Multiple comparisons (10 Nov) | Every group comparison is Holm-adjusted within its family (Bills): the era contrasts within each response (three period-type contrasts in each of two parks, six tests), the species contrasts within each measure and park (all species and their three period-type contrasts), and, as before, the joint pace and direction contrasts. Stars and statements of significance use the adjusted p. Intervals stay unadjusted 95% intervals. The explanatory models have one group contrast each (site, burned minus unburned) and need no adjustment. |
| Species measure contrib_lag (11 Nov) | `contrib_gap` (projection on the mismatch at the start) is replaced by `contrib_lag` (Bills). With g1 and g2 the mismatch WA − LC at the two ends and m = (g1 + g2) / (|g1| + |g2|), each species' vector projected on m is its part of the lag rate, and −dLC·m is the climate's part. They add up exactly to the lag rate, and swapping the surveys reverses every value. `contrib_gap` came out positive also with the surveys swapped (MORA 0.445 forward, 0.621 swapped; NOCA 1.59 and 0.90), a lean towards the predicted position that is not a time trend. `contrib_lag` is per century of the lag-rate interval and includes the units where the community did not move. Figure 7B shows it. |
| Wording and Figure 7 species (11 Nov) | "Climate-community lag" replaces "community-climate lag" in every figure and text (Bills). Figure 7 orders the species by the maximum elevation of the plots where they occur, shades their names by it in four grey steps (breaks at 1,500, 1,700 and 1,900 m), and sets in bold the species absent from the Holocene record of both parks (Abies grandis, Pinus albicaulis, Pinus ponderosa) (Bills). |
| Burned MORA plots (11 Nov) | The two MORA plots burned between the surveys (JAME-295 and OHAN-013, 2003 fire, from `MORA_plot_info_fire.csv`) leave the whole analysis, before species selection and the CCA fit (Bills). Two plots cannot carry a MORA fire comparison, and in the shared Anthropocene fire term `site + burned` they tied the burned effect to MORA's level. The analysis now has 605 plot pairs (MORA 328, NOCA 277), set once in `ANTHROPOCENE_PAIRS` (R/helpers/config.R). The cleaned vegetation tables and Figures S1 and S8 still describe them as raw data. Figure S2 shows them as their own exclusion step. |
| NOCA legacy plot area (10 Nov) | A descriptive supplement table of the 277 NOCA plot pairs by legacy plot area: plots, mean richness of the retained CCA taxa at both surveys, and plain means with t-intervals of turnover rate, lag and lag rate. No model changes (Bills). |
| Bias-corrected sensitivity (10 Nov) | `R/sensitivity_bias_corrected.R` reruns stages 07 to 15 with `PALEO_USE_BIAS_CORRECTED = TRUE` into `output_bias_corrected/`, never writing `output/` or `report/`, and tabulates the lag, pace effect and direction effect of every lake-period from both runs with the number that keep their sign. The primary run stays on the raw TraCE21k paleoclimate (Bills). |
| Figures 4 and 5 (10 Nov) | Fitted means and 95% intervals of the three period types per park, each mean printed beside its point. Climate change rate and turnover on log axes with an arrow for the fold against Holocene-C. Lag, lag rate, pace and direction on linear axes with connectors from the Anthropocene to each Holocene type, a star only where that contrast is significant, never on a single mean. Figure 5 holds pace and direction only, on one y scale, with "narrows the lag" and "widens the lag" along the axis (a positive effect means the community's own pace or direction widened the lag). Figure 4 has six panels in three rows (Bills): climate change and its rate, observed community turnover (the displacement) and its rate, the lag and the lag rate, each total on the left and its rate on the right, legend at the bottom. |
| Figure 2 (10 Nov) | Raw units, period rates on the running mean with leader lines, the largest century step marked with a cross and its rate, driver words as directions only, Anthropocene rates with park names in park colours (Bills). |
| Appendix (10 Nov) | Figure A4 (pace and direction against the lag rate) removed. The four-variable figures list all four variables in a two-row legend. The tracking values over time are shown per lake-period, not per century step (Bills). |

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
| Legacy-calibration versus full-record climate SDs | Changes are divided by SDs from the 605 matched legacy CCA calibration plots. | The reference is tied to the fitted model. A full-record SD would change displayed standardized magnitudes, cross-variable weighting, the unthresholded composite, and standardized climate rates, but not CC/S boundaries under the current variable-specific 50%-of-own-maximum rule. | A prespecified full-record sensitivity with explicit temporal/site weighting and a scientific choice between calibration-relative and dataset-relative effect sizes. |
| Anthropocene precipitation continuity | Historical climate remains 1979–1989; modern climate uses adult Y−5 through Y at both sites (2026-10-07 decision). The MORA precipitation contrast is flagged. | The apparent post-2010 MORA precipitation shift may partly reflect CHELSA inhomogeneity rather than climate. | Independent station/reanalysis validation and a documented decision on whether post-2010 MORA precipitation is usable. The agreed years are not a pending decision. |
| MORA fire record location | The MORA fire values come from the Sunrise Ridge cores, while the vegetation lakes lie elsewhere in the park. | A MORA fire slope may reflect regional fire rather than fire at the lakes. | Charcoal from the vegetation lakes themselves. |
| Fire scales of the two parks | One fire slope for both parks, in events per century per covered core. MORA values span 0.10 to 0.33 and NOCA 0.33 to 0.89, partly because Panther Potholes is read at 12 years and the Sunrise Ridge cores at 42 to 48 years. | The fire slope comes from the narrow range within each park. | Records at comparable resolution, or a resolution-corrected event rate. |
| Rates over different time spans | Holocene rates span 200 to 2,600 years and Anthropocene rates about 29 years. | Longer windows give lower rates, so the folds overstate the speed difference by an unknown amount. | A rate measure that is independent of the window length, or Holocene windows of about 30 years, which the sampling does not allow. |
| Choice of MSpT and SP | Argued on mechanism: spring temperature for snowmelt timing and the start of the growing season, summer precipitation for drying stress. | Winter temperature and winter precipitation still add explained inertia (permutation test in Step 0), through the seasonal contrasts that made the four-variable fit collinear. | The screening table of Step 0 is the evidence. A mechanism-based argument stays necessary. |
| Own-origin versus common-origin taxon target geometry | Deferred: the target-alignment analysis is retired. Existing CCA scores and reference matrices are preserved; the parallel contribution decomposition does not implement that separate target-origin sensitivity. | The two cosines answer alignment relative to each trajectory's own starting community; part of their difference can arise because LC₁ and WA₁ differ. | A prespecified common-origin sensitivity and an ecological decision about whether the estimand should condition on each starting state or hold the target vector fixed across observed and predicted movement. |

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
  [retained plot-size counts](../tables/sample_selection_plot_sizes.csv).
- NOCA size classes differ between surveys: legacy regeneration spans 0–3 m
  and adults exceed 3 m; resurvey seedlings span 10–140 cm and trees exceed
  1.4 m. Neither stratum is an identical size-class measurement across dates.
- **Primary provenance for MORA survey dates:** the analysis-year choice is
  resolved. MORA vegetation rates use 1977.5 as the legacy reference and each
  plot's selected adult resurvey year; the modeled resurveys span 2014–2019.
  Historical climate remains 1979–1989; modern climate uses Y−5 through Y. The original Torres draft and primary
  legacy-date records are not filed in the repository, so their historical
  verification remains a provenance limitation, not an undecided analysis
  setting. See [survey-year sources](01_vegetation_survey_years.md).
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
- Descriptive Holocene fire categories retain fixed event chronologies. Ecological
  Panther Potholes exposure is redated coherently with vegetation in each
  chronology sensitivity reconstruction; MORA regional event dates remain fixed. The harmonized
  Gaussian-mixture detector also differs from Prichard's original noise
  description, so its published settings do not imply an exact reproduction of
  every original algorithmic detail.
- Adjacent ecological transitions share endpoint information. The 1,000
  chronology reconstructions are sensitivity analyses, not independent
  ecological replicates. The descriptive climate-period offsets remain separate.
  The modern MORA burned group contains two plots, so its estimate has limited
  support.
- Native climate caches identify the reviewed local values, but cannot recover
  an immutable historical remote raster release on their own.

## Related maintained documentation

- [README](../../README.md)
- [Workflow](11_outputs_and_workflow.md)
- [Tracking data validation](07_tracking.md)
- [Holocene literature summary](../references/Holocene_period_choices_MORA_NOCA_summary.pdf)
- [Bacon controls](03_chronology_control_points.md)
- [MORA chronology sources](03_chronology_sources_MORA.md)
- [NOCA paleo sources](03_chronology_sources_NOCA.md)
- [Survey-year sources](01_vegetation_survey_years.md)
- [NOCA cleaning guide](01_vegetation_noca_cleaning_guide.md)
- [Occurrence consolidation](05_species_occurrence_consolidation.md)
- [MORA raw-data reference](01_vegetation_raw_data_MORA.md)
- [MORA output reference](01_vegetation_MORA_AT_outputs.md)
