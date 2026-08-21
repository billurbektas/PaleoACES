# PaleoACES scientific decisions

This document records current analytical choices and their limits. Execution
order and file dependencies are authoritative in [WORKFLOW.md](WORKFLOW.md).

## Study universes and vegetation

- Modern vegetation is paired within plot. MORA has 330 modeled pairs and NOCA
  has 277 after excluding `BAK487` (old clearcut) and `BEAV6061` (uncertain
  relocation into an avalanche chute).
- The corrected NOCA workbook is authoritative for its 2,366 received stem
  rows. Unsupported labels are discarded before occurrence construction. The
  verified cleaned result is 307 plots, 1,790 rows, and 31 identified taxa.
- NOCA fire comparisons use Wilson et al. as a regression reference, not as the
  PaleoACES universe. All 305 common plots have the same assignment. The active
  PaleoACES result is 32 burned and 275 unburned plots.
- Presence is adult or regeneration presence. Species are retained when present
  in at least one site-period group of 20 plots or samples. The consolidated
  table has 13,672 rows, 21 taxa, and 1,601 samples.

## Climate and CCA

- Modern plots use CHELSA V2.1. Paleo samples use native CHELSA-TraCE21k pond
  climate matched to sample age. Raw TraCE21k is current; stationary V2.1-anchor
  correction remains an unresolved sensitivity.
- The active constraints are spring temperature (`MSpT`), winter temperature
  (`MWT`), summer precipitation (`SP`), and winter precipitation (`WP`). They are
  seasonal correlates of growing energy, freezing exposure, summer dryness, and
  snowpack—not direct GDD, FDD, fire, soil-moisture, or snowpack measurements.
- The pooled CCA is calibrated on 620 legacy plots and 13 retained species.
  Vegan site/scaling 1 is retained because downstream metrics use Euclidean
  sample-score distances. The model positions 1,514 of 1,583 modern and paleo
  samples.
- Climate constraints are collinear. Their marginal contributions must not be
  interpreted as additive shares of constrained inertia.

## Vegetation tracking

- Observed vegetation movement is the CCA1–CCA2 displacement of WA scores.
  Expected vegetation movement is the displacement of climate-predicted LC
  scores. The compatibility alias `d_climate` means the latter, not physical
  climate change.
- Actual climate change retains signed physical changes/rates for all four
  constraints. Its combined standardized magnitude is the Euclidean norm after
  scaling by pooled legacy-calibration SDs.
- Anthropocene vegetation rates use each plot's resurvey year: MORA relative to
  1977.5 and NOCA relative to 1983. Climate-predicted and physical-climate rates
  use 30.5-year MORA and 28.5-year NOCA window-midpoint intervals.
- Primary Holocene tracking uses consecutive 1,000-year bins, ten 100-year
  offsets, and all 100 whole-chronology Bacon draws. Metrics are calculated for
  every MORA/NOCA site × offset × draw × interval realization before summarizing
  draws within offset and then offset-phase sensitivity. MORA vegetation and
  climate are pooled across its three lake records at the site level before
  interval metrics; Panther Potholes represents NOCA.
- Offset-specific intervals are mapped to the 100-year reporting grid as
  half-open intervals (`age_lo <= t < age_hi`). This prevents internal boundary
  dates from being assigned twice. Strict ten-offset coverage yields 54 MORA
  dates from 6.6–1.3 ka and 83 NOCA dates from 9.5–1.3 ka.
- The former 500-year framework is retained only in explicit `_500yr`
  sensitivity tables. A resolution audit reports support and matched-date
  differences without requiring the two resolutions to agree. The 1,000-year
  analysis is primary because it matches climate/fire support and improves
  vegetation-bin density; the material resolution sensitivity remains part of
  interpretation. Neither draws nor offsets are ecological replicates.
- The magnitude ratio and the tracking ratio (observed/predicted) are
  algebraically identical for valid
  Holocene realizations because both rates use the same interval denominator.
  This is an implementation invariant, not an independent ecological result.
- One-sample bins remain visible through `n_min` and `sparse_bin`; parallel
  `nmin2` realization tables provide the prespecified sampling-density
  sensitivity.
- Endpoint lag is `||LC-WA||`; the displayed signed lag is `lag_t2-lag_t1`.
  Positive values mean mismatch opened and negative values mean it closed.
  Lag per century uses the climate interval denominator: 1,000 years for
  Holocene, 30.5 years for MORA Anthropocene, and 28.5 years for NOCA.
- The integrated tracking figure uses MORA/NOCA site-date summaries, not
  individual lakes. Every boxplot has fixed-scale MORA and NOCA facets, with
  Holocene/Anthropocene or Holocene climate-state groups on the x-axis and fire
  status explicitly dodged within each group. The two burned MORA pairs are
  omitted and recorded in a scope audit; the NOCA Anthropocene boxes retain and
  distinguish 254 unburned and 23 burned pairs. The Holocene details compare
  Holocene climate change and Holocene climate stability, then split each state
  by high-fire status. Every box retains the same physical width even when its
  category contains only one fire group. All boxes are white so the median remains visible; neutral
  and dark-red outlines represent no-fire and burned/high-fire observations.
  Lag per century, ratio, and angle are shown; raw lag is retained as scatter
  fill but no longer has a boxplot. All axes are linear; the detail positions are not directly
  comparable with their main panels because each detail has an independent
  Holocene y-range.
- Its single unfaceted angle × ratio scatter places all 589 included
  direction-valid observations faintly behind four macro-era medians, two
  additional NOCA burned/unburned medians, and eight smaller site × climate
  state × fire-status medians. A single shared repel layer keeps labels from
  overlapping; each label names its macro era or full climate/fire context, and
  each pooled climate-state label lists the exact numbered eras represented in
  that site × state × fire group.
  The scatter is centered at 75% of the unchanged A–C row width to avoid giving
  this descriptive panel disproportionate visual weight.
  Site is shape; fire evidence is the only
  categorical red encoding. The 153 stationary Anthropocene plots (78 MORA, 75 NOCA)
  remain in non-angle summaries; their counts are labelled rather than assigning
  a false 0° direction. Median-point fill is signed raw lag on one symmetric
  blue–neutral–vermillion scale centered at zero and labelled `Lag`. All 137
  Holocene site-dates and all 607 modern source pairs enter the scope audit;
  605 modern pairs remain after the explicit MORA fire exclusion.

## Unified 1,000-year climate eras

- `R/13_holocene_climate_fire_eras.R` is the sole Holocene era authority. It
  derives adjacent complete 1,000-year changes from the four native pond
  trajectories and uses ten 100-year bin phases. Fixed climate windows contain
  no Bacon chronology draws; phase spread is placement sensitivity, not
  ecological replication or full paleoclimate uncertainty.
- Signed changes in `MSpT`, `MWT`, `SP`, and `WP` are divided by the pooled
  legacy CCA calibration SDs. MORA's three lakes are averaged first; the MORA
  and NOCA site trajectories then receive equal regional weight.
- **Standardization sensitivity to discuss later.** The active denominator
  remains each variable's SD across the 620 pooled MORA/NOCA legacy calibration
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
  1979–1989 with 2010–2019 over 30.5 midpoint years, and NOCA compares 1979–1989
  with 2010–2015 over 28.5 midpoint years. The table shows site-specific medians
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
- `R/12_walsh_fire_reproduction.R` additionally runs official CharAnalysis R
  2.0.3 against the three Walsh MORA workbooks. This is a software/publication
  audit only; it is isolated from the authoritative all-`tapas` catalog and
  hash-checks `fire_walsh.csv` and `paleo_fire.csv` before/after.
- Official R 2.0.3 yields 15 Sunrise, 16 Shadow, and 14 Little Sunrise episodes.
  Walsh reports 24, 18, and 16. These discrepancies are an explicit software/
  implementation audit; thresholds were not modified to force agreement.
- `R/12a_fire_event_detection_worked_example.R` separates individual-event
  detection from the later high-fire-period rule. Its six-page audit shows the
  common chain—interpolation, robust LOWESS background, positive residual,
  local Gaussian-mixture threshold, 75-year count screen, accepted event—for
  every core. It also exposes the source differences: MORA uses 42–48-year
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
- `R/13b_fire_method_worked_example.R` exposes the complete arithmetic at
  2,300 cal BP. The centered `[1,800, 2,800)` window contains 3 Little Sunrise,
  2 Shadow, 3 Sunrise, and 7 Panther Potholes accepted events. Core-normalized
  frequencies are 1.000, 0.667, 1.000, and 0.636; consequently the equal-core
  MORA frequency exceeds its site threshold (ratio 1.46), whereas the local
  NOCA frequency does not (ratio 0.94). This date illustrates the frozen rule;
  it was not used to choose the threshold or tune the classifications.

## Selected era-centroid trajectories and community-direction analysis

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
- The implemented direction analysis pairs, within every measurement unit and
  target, taxon alignment with predicted LC movement,
  `cos(delta LC, species score - LC_t1)`, with taxon alignment with observed WA
  movement, `cos(delta WA, species score - WA_t1)`. Thus each taxon cosine uses
  its own initial origin—LC for predicted and WA for observed—toward the same
  fixed species score. The same pairing uses each raw environmental biplot
  arrow. Its primary result, termed the
  **target-alignment discrepancy**, is `predicted cosine - observed cosine`.
  Zero means equal target-specific cosines, not complete movement-vector
  agreement. Positive values mean stronger predicted target alignment,
  including being less strongly opposed to the target; negative values mean
  stronger observed target alignment. The absolute magnitude measures
  target-specific discrepancy strength. The retained direct cosine and unsigned
  angle separately measure overall movement-vector agreement and deviation.
- The compact main display contains only A. Climate and B. Species. It uses
  `climate stability` as the reader-facing form of the analytical
  `relative stability` class, preserves the common group axis across both rows,
  italicizes species, and reserves red for high-fire/burned status. Holocene and
  Anthropocene labels remain neutral.
- LC, WA, species, and environmental scores must come from the same fitted
  scaling-1/Hill-off CCA1–CCA2 coordinates. Vectors are formed before unit
  normalization; raw biplot directions are used without display multipliers;
  dot-product cosines are clamped to [-1, 1] and become `NA` below `1e-8`.
  Nonlinear realization values precede draw/offset summaries. Translation,
  rotation, reflection, and a common arrow multiplier must leave results
  unchanged; unequal axis scaling intentionally does not and is forbidden.
- The stage retains 10,319 paired target contrasts from all 607 Anthropocene
  pairs and 259,590 from all 15,270 primary Holocene realizations. Its
  draw-within-offset and complete-ten-offset hierarchy yields 2,329 site-date
  contrasts and 204 final group summaries. The 153 near-zero observed modern
  movements have `NA` paired contrasts, while their independently valid
  predicted associations remain available for audit.
- Summaries are Holocene site × climate change/stability × high-fire status and
  Anthropocene site × burned status. All groups remain visible, including MORA
  burned (2 plots) and NOCA stable/high-fire (2 dates). Taxa and climate arrows
  are shown as descriptive predicted-minus-observed target-alignment
  discrepancies without ranking.
  No prevalence model, dominance claim, contribution decomposition, causal
  attribution, significance test, or numbered-era inference is authorized.

## Remaining scientific questions

| Question | Current choice | Consequence | Evidence needed to resolve it |
|---|---|---|---|
| Raw versus V2.1-anchored TraCE21k climate | The active Holocene analysis uses raw TraCE21k values; the V2.1 anchoring diagnostic is not authoritative. | Absolute Holocene climate levels and cross-product comparisons may retain product bias, although the active within-series change calculations are internally consistent. | A validated overlap-period comparison showing whether anchoring reduces bias without introducing a discontinuity or changing the intended anomaly interpretation. |
| Legacy-calibration versus full-record climate SDs | Changes are divided by SDs from the 620 pooled legacy CCA calibration plots. | The reference is tied to the fitted model. A full-record SD would change displayed standardized magnitudes, cross-variable weighting, the unthresholded composite, and standardized climate rates, but not CC/S boundaries under the current variable-specific 50%-of-own-maximum rule. | A prespecified full-record sensitivity with explicit temporal/site weighting and a scientific choice between calibration-relative and dataset-relative effect sizes. |
| Anthropocene precipitation windows and CHELSA continuity | The exact MORA and NOCA windows remain 1979–1989 to 2010–2019 and 1979–1989 to 2010–2015, respectively; the MORA precipitation contrast is flagged. | Site contrasts use unequal resurvey windows, and the apparent post-2010 MORA precipitation shift may partly reflect CHELSA inhomogeneity rather than climate. | Independent station/reanalysis validation, alternate endpoint-window sensitivities, and a documented decision on whether post-2010 MORA precipitation is usable. |
| Primary provenance for MORA survey dates | The current plot-year and climate-window conventions are retained, but the cited primary MORA survey-date source is not available in the repository. | Exact modern rate denominators are operationally fixed but not fully traceable to a primary source package. | The original survey metadata or publication supplement linking plots to legacy/resurvey years and confirming the aggregation windows. |
| `CARI449`/`CARI450` coordinate collision | Both plots remain in the 307-plot universe. Their raw longitudes have opposite signs but normalize to the same coordinate; elevations remain 622 and 1,149 m. | Climate extraction assigns the same horizontal location to two strongly separated elevations, and silently excluding or moving either plot would alter the validated universe. | Primary field/GPS records or source-author confirmation identifying the correct longitude/latitude for each plot or supporting a documented exclusion. |
| Own-origin versus common-origin taxon target geometry | The primary target-alignment analysis uses LC₁→species for predicted movement and WA₁→species for observed movement. | The two cosines answer alignment relative to each trajectory's own starting community; part of their difference can arise because LC₁ and WA₁ differ. | A prespecified common-origin sensitivity and an ecological decision about whether the estimand should condition on each starting state or hold the target vector fixed across observed and predicted movement. |

## Inference limits

- Climate and fire are classified independently and merely aligned in the
  integrated figure; neither evidence stream defines the other. Literature is
  not part of this stage and cannot change a boundary.
- Chronology precision is not equivalent among the published MORA cores and
  Panther Potholes. Cross-site fire timing must not be presented as equally
  uncertain.
- Paleo species occupancy remains partly site-confounded, and MORA/NOCA fire
  proxies are not equivalent. These limitations remain explicit in inference.

## Related maintained documentation

- [README](README.md)
- [Workflow](WORKFLOW.md)
- [Figure methods and captions](FIGURE_CAPTIONS.md)
- [Tracking metric specification](cca_tracking_metrics.pdf)
- [Holocene literature summary](Holocene_period_choices_MORA_NOCA_summary.pdf)
- [Bacon controls](Cores/CONTROL_POINTS.md)
- [MORA chronology sources](Cores/SOURCES_MORA.md)
- [NOCA paleo sources](data/NOCA/NOCA_paleo/SOURCES.md)
- [Survey-year sources](data/SOURCES_SURVEY_YEARS.md)
- [NOCA cleaning guide](R/000_NOCA_cleaning_guide.md)
- [Occurrence consolidation](R/README_occurrence_consolidation.md)
- [MORA raw-data reference](data/MORA/README_data_raw.md)
- [MORA output reference](data/README_outputs_MORA_AT.md)
- [Claude redirect](CLAUDE.md)
