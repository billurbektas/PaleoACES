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

[Former rationale, source evidence and reversal](methods/README_occurrence_consolidation.md#ponderosa-reinstatement)
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
historical code and figures remain in Git. No replacement figures or models
are fitted in this step.

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
missing counts/activity, not zero. Coverage fractions, bounds, event counts,
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
realizations without a majority-draw cutoff. `n_valid_draws` and
`n_missing_draws` refer to the primary lag response out of 100 configured draws;
every response also has its own counts. Missing draws include absent transitions
and undefined metrics, distinguished by presence/absence and undefined counts.
Means, SDs and quantiles are conditional on valid realizations. A transition with
only a handful of valid draws is retained with visibly limited support.

Minimum-two-samples-per-bin sensitivity summaries accompany the primary wide
table. Reporting grids are descriptive, require all configured offsets within
each lake and never require matching coverage across lakes. Overlapping dates,
offsets and chronology draws are not ecological replicates. Model inclusion,
uncertainty treatment and temporal correlation remain future decisions.
Approximately 5–6 majority-supported transitions per MORA lake per offset and
9–10 for Panther Potholes imply limited support for a later three-way interaction;
four lakes and shared fire histories must not be treated as abundant independent
replication. No distribution, LMM, AR(1), power analysis or contribution attribution
is selected or fitted here. See [output schemas](OUTPUTS.md#canonical-tracking-schemas).

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
- [Figure methods and captions](FIGURE_CAPTIONS.md)
- [Tracking data validation](review/TRACKING_DATA_VALIDATION.md)
- [Holocene literature summary](references/Holocene_period_choices_MORA_NOCA_summary.pdf)
- [Bacon controls](../Cores/CONTROL_POINTS.md)
- [MORA chronology sources](../Cores/SOURCES_MORA.md)
- [NOCA paleo sources](../data/NOCA/NOCA_paleo/SOURCES.md)
- [Survey-year sources](../data/SOURCES_SURVEY_YEARS.md)
- [NOCA cleaning guide](methods/000_NOCA_cleaning_guide.md)
- [Occurrence consolidation](methods/README_occurrence_consolidation.md)
- [MORA raw-data reference](../data/MORA/README_data_raw.md)
- [MORA output reference](../data/README_outputs_MORA_AT.md)
