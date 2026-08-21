# PaleoACES

PaleoACES compares climate-predicted and observed forest composition through
Anthropocene resurveys and Holocene paleoecological records at Mount Rainier
(MORA) and North Cascades (NOCA). The pooled CCA is calibrated on legacy survey
plots; modern resurveys and dated paleo samples are projected into that shared
ordination.

See **[WORKFLOW.md](WORKFLOW.md)** for the executable script order, direct inputs
and outputs, cache behavior, commands, validation tests, and the scientific
decisions those tests support.

## Quick start

```bash
# Standard cached rebuild
Rscript R/00_workflow.R

# Rebuild without network access, using existing climate products
Rscript R/00_workflow.R --offline

# Rebuild every analytical table without writing or deleting PDF/PNG files
Rscript R/00_workflow.R --offline --skip-figures
```

The fresh validated chronology run used R 4.6.1. Raw inputs live under `data/`
and generated tables under `output/`. The root `plot/` directory is reserved for
the four main-paper figure stems, each written as PDF and PNG; all diagnostic,
audit, sensitivity, and worked-example figures are PDF-only under
`plot/test_figures/`. Scripts under `R/archive/` are historical references and
are not sourced by the workflow.

## Modern vegetation

| Component | MORA | NOCA |
|---|---|---|
| Legacy adults | `data/raw/MORA_Cascade Legacy Data_Original1978.xlsx`, `rawsizedata` | `data/NOCA/AGEEDATA_NEW.xlsx`, `TREE` adult height classes |
| Legacy regeneration | Original 1978 `Rainier Veg`, size class 1 | Agee `TREE`, `DEN_0-3` proxy |
| Resurvey adults | `MORA_TreeData_Resurvey_Cleaned.csv` | JHRL `Tree Data`, patched by `2026_corrected_trees_for_Billur.xlsx` |
| Resurvey regeneration | `MORA_Seedlings_Resurvey_Cleaned.csv` | JHRL `Seedlings` |
| Cleaners | `R/000_MORA_cleaning.R` | `R/000_NOCA_cleaning.R` |

Presence is adult **or** regeneration presence. The NOCA correction is an
authoritative patch: it replaces affected source/target plot rows before the
corrected stems are appended. Its per-plot provenance is written to
`output/NOCA_tree_correction_audit.csv`; the before/after species comparison for
all 307 retained plots is in `output/NOCA_tree_composition_audit.csv`.

Unsupported identification labels are discarded before occurrence and stage
construction. The verified NOCA baseline is 307 plots, 1,790 rows, and 31
identified taxa; no unsupported label reaches an analytical output.

Two otherwise paired plots are excluded at study level following Rachel
Wilson's notes: `BAK487` is an old clearcut removed from Wilson's final analysis,
and `BEAV6061` has an uncertain historical location whose resurvey landed in an
avalanche chute. Their provenance is in `output/NOCA_study_exclusions.csv`.

## Fire

- MORA Anthropocene fire retains the 100 m LandTrendr disturbance method.
- NOCA applies the Wilson et al. (2024) natural/prescribed-fire method to the
  307 retained PaleoACES plots: 32 burned and 275 unburned. The published table is
  a regression reference, not the analysis universe.
- `output/NOCA_fire_Wilson2024_comparison.csv` reports the 305 shared plots, two
  PaleoACES-only plots (`THOR223`, `BAK494`, both unburned), and 64 Wilson-reference-only
  plots without forcing the universes to match. Of those 64, 58 are unburned;
  the six published burned plots outside PaleoACES are `HIBR2082`, `STE2011`,
  `STE2019`, `STE2023`, `STE2024`, and `STE2033`.
- **All 305 plots common to the two retained/reference universes have identical
  fire assignments; there is no common-plot discrepancy.** The received spatial-join file omits three
  published-unburned rows (`COPP6040`, `THOR221`, `THOR225`); they are retained
  as explicit comparison reasons rather than silently inferred as spatial hits.
- MORA paleo fire comes from charcoal/charred-needle records; NOCA paleo fire
  comes from the Neotoma macrocharcoal series. Both feed `paleo_fire.csv`.

## Climate and model

- MORA and NOCA survey plots use CHELSA V2.1 monthly climate. Cache chunks are
  reused only when plot IDs, coordinates, variable, year, and values validate.
- Paleo samples use the native CHELSA-TraCE21k pond series matched to their own
  ages. Raw TraCE21k is the default; the V2.1-anchored correction is retained as
  a documented sensitivity.
- The active CCA constraints are spring temperature (`MSpT`), winter temperature
  (`MWT`), summer precipitation (`SP`), and winter precipitation (`WP`). They are
  interpreted respectively as seasonal correlates of growing-degree-day energy,
  freezing exposure, summer dryness/fire-weather exposure, and snowpack. Their
  directions matter: warmer `MWT` generally implies fewer freezing degree days,
  and greater `SP` implies less summer dryness. They are not direct GDD, FDD,
  soil-moisture, fire, or snowpack measurements. Species must occur in at
  least one site-period group of 20 or more plots/samples to be retained.
- `output/occ_consolidated.csv` is the only occurrence input to
  `R/05_cca_model.R`; taxonomic decisions are centralized upstream.
- The verified consolidated baseline is 13,672 rows, 21 taxa, and 1,601 samples.
  The CCA retains 13 species, calibrates on 620 legacy plots, and positions 1,514
  of 1,583 modern and paleo samples.
- Tracking outputs distinguish observed WA displacement, climate-predicted
  vegetation displacement from LC scores, and actual change in the four climate
  constraints. The historical `d_climate` label is retained only as an output
  alias for LC-predicted vegetation displacement; it is not a physical climate
  rate. Actual climate rates retain signed °C/century and mm/century components
  plus a pooled-legacy-SD standardized multivariate rate.
- The active tracking visualization is the single-page
  `plot/fig_tracking_comparison.pdf`; retired offset, metric-exploration,
  five-page boxplot, and four-panel storyline figures are no longer generated.
- Panels A–C compare lag rate per century, tracking ratio
  (observed/predicted), and angle; the raw
  lag boxplot has been removed. MORA and NOCA are fixed-scale facets; the main x-axis is Holocene
  versus Anthropocene, with fire status dodged inside each era. The two burned
  MORA pairs (`JAME-295`, `OHAN-013`) are omitted from this descriptive tracking
  comparison. NOCA Anthropocene is instead split into 254 unburned and 23
  burned paired plots. The separately ranged Holocene details retain the same
  fixed site facets and compare Holocene climate change with Holocene climate
  stability. Each state is split into high-fire and no-high-fire site-dates.
  All boxes retain one fixed physical width, including groups with only one box.
  White fill keeps median lines visible; neutral versus dark-red
  outlines distinguish no-fire from burned/high-fire observations. All axes are
  raw-linear. Medians and valid counts are
  annotated; direction-invalid observations are omitted only from angle.
  These correlated site-date and paired-plot distributions are descriptive
  rather than inferential replicates.
- Panel D is centered at 75% of the unchanged A–C row width and places angle on
  the x-axis and tracking ratio on the y-axis. All 589
  direction-valid included observations appear faintly in the background:
  site is shape, while dark red is reserved for fire evidence. Four directly
  labelled Holocene/Anthropocene medians, two additional NOCA Anthropocene
  burned/unburned medians, and eight smaller site × climate-state × fire-status
  medians are drawn on top. One common repel layer prevents those three label
  classes from overlapping. Overall labels read `Holocene/Anthropocene median`;
  climate-state labels list the exact numbered eras represented in that plotted
  group, such as `Climate stability (S2, S3, S4)`, and burn-status labels state
  their full Anthropocene context.
  Median fill is signed raw lag on one
  symmetric linear blue–neutral–vermillion scale centered at zero and labelled
  simply `Lag`.
  Reference lines mark angle 90° and tracking ratio 1. The 153 stationary
  Anthropocene observations—78 MORA and 75 NOCA—have undefined angle and are
  labelled but not assigned a false 0° value. They remain in the non-angle
  boxplots. No IQRs, arrows, or fitted trends appear.
- `plot/fig_standardized_climate_change_eras_fire.pdf` is the authoritative
  literature-blind Holocene interpretation figure. For each of `MSpT`, `MWT`,
  `SP`, and `WP`, signed 1,000-year changes are divided by the pooled legacy CCA
  calibration SD. MORA's three lakes are averaged first, then MORA and NOCA
  receive equal weight. A variable qualifies when its absolute median regional
  change reaches 50% of that variable's maximum and at least eight of ten bin
  phases support the regional direction. Site trajectories remain auditable but
  do not veto the regional classification. Any qualifying variable creates a
  climate-change cell; all others are relative stability. Only directly
  adjacent cells are merged. The complete-phase domain is 9.6–1.3 ka and yields
  CC1 9.6–7.2, S1 7.2–6.8, CC2 6.8–6.2, S2 6.2–5.4, CC3 5.4–4.9, S3 4.9–2.2,
  CC4 2.2–1.7, and S4 1.7–1.3 ka. The four-variable Euclidean composite is
  shown unthresholded because it is unsigned and cannot select eras or direction.
  A descriptive, literature-blind driver-trough rule subdivides CC1 into CC1a
  9.6–8.6 ka (spring cooling, winter warming, summer drying), CC1b 8.6–8.2 ka
  (transition dominated by winter wetting), and CC1c 8.2–7.2 ka (spring
  warming, winter warming, summer wetting). A driver must occupy at least 60%
  of a subphase to name it; the parent CC/S sequence remains unchanged.
  Four variable-colored brackets in the incomplete-coverage margin show the
  exact standardized stability ranges read from the threshold table: MSpT
  ±0.086, MWT ±0.110, SP ±0.088, and WP ±0.056 (rounded for display).
- Holocene tracking uses the same 1,000-year support as the primary climate
  classification: ten offsets and all 100 Bacon draws. MORA's three lake
  records are pooled to the site level before interval metrics are calculated;
  Panther Potholes represents NOCA. Nonlinear metrics are calculated within
  every site × offset × draw × interval realization before draw-first and
  offset-second summaries. Grid mapping is half-open (`age_lo <= t < age_hi`)
  so adjacent intervals cannot duplicate boundary dates. The previous 500-year
  analysis remains in explicitly suffixed `_500yr` sensitivity tables and is
  compared in a descriptive resolution audit.
- Lag is `lag_t2 - lag_t1`, where endpoint lag is the Euclidean WA–LC mismatch.
  Positive lag opens the mismatch and negative lag closes it. Lag per century
  divides that signed change by the climate interval: 1,000 years in the
  Holocene, 30.5 years for MORA Anthropocene, and 28.5 for NOCA Anthropocene.
- Anthropocene climate rates are annualized short-window contrasts. MORA
  compares mean 1979–1989 climate with 2010–2019 over the 30.5-year midpoint
  interval; NOCA compares 1979–1989 with 2010–2015 over 28.5 midpoint years.
  Figure 2 contrasts their median plot-level rates with the maximum-absolute
  Holocene equal-site regional median after ten-offset aggregation. The MORA
  precipitation contrast retains the documented caveat of a possible post-2010
  CHELSA inhomogeneity.
- `plot/test_figures/fig_walsh_charanalysis_reproduction.pdf` is an audit with official
  CharAnalysis R 2.0.3, separate from the authoritative all-`tapas` catalog. With the
  documented Walsh settings it identifies 15 Sunrise, 16 Shadow, and 14 Little
  Sunrise episodes, versus the published totals 24, 18, and 16. The calculated
  values and discrepancies are retained rather than tuned away. The audit does
  not overwrite `fire_walsh.csv`, `paleo_fire.csv`, or CCA fire flags.
- The authoritative event catalog applies one reusable `tapas` detector to all
  four cores while retaining publication-specific temporal settings. Current
  accepted totals are 17 Sunrise, 14 Shadow, 13 Little Sunrise, and 66 Panther
  Potholes. The four interpolation/background/threshold combinations are
  48/800/95%, 47/1,000/95%, 42/500/95%, and 12/500/99%, respectively. All use
  unlogged CHAR, robust LOWESS, local thresholds, a 75-year count window, and
  `p <= 0.05`. NOCA 12.5-year interpolation is a publication-resolution
  sensitivity only.
- High-fire periods are independently selected from centered 1,000-year
  accepted-event frequency. Each core is normalized to its own maximum; MORA is
  an equal-core mean where at least two records are covered, while Panther
  Potholes is local NOCA evidence. A site's frequency must exceed its median plus
  `1.4826 × MAD`; every contiguous above-threshold run is retained without gap
  bridging or a second duration filter. Peak strength and background CHAR are
  plotted only as corroboration and cannot create a high-fire period. Literature
  remains a reference and does not enter either classification.
- `plot/test_figures/fig_holocene_fire_method_worked_example.pdf` walks through those steps
  with the actual 2,300 cal-BP data: accepted-event counting, within-core
  normalization, regional MORA versus local NOCA aggregation, robust site
  thresholds, threshold-normalized ratios, and the final classifications.
- `plot/test_figures/fig_fire_event_detection_workflow.pdf` documents the preceding event-
  detection stage in six pages: a four-core settings comparison, one page per
  lake showing interpolated CHAR, robust LOWESS background, residual/noise
  threshold, count screening, and accepted-event ages, and a separate MORA
  `tapas`/CharAnalysis/publication comparison.
- The selected CCA trajectory display uses one observed WA centroid and one
  predicted LC centroid per site × CC1–S4 era. Separate observed and predicted
  paths run chronologically from CC1 through S4 with arrows. The complete
  original `fig_cca_trajectories` architecture is retained: pooled trajectory
  Panel A, biplot inset B,
  Anthropocene legacy-to-resurvey arrows, climate/species biplot inset and arrows,
  climate contribution Panel C, species contribution Panel D, axes,
  `scaling = "sites"` (vegan scaling 1),
  and the unchanged Hill setting. Site × era series are labelled directly,
  all eight observed/predicted site × era paths are named on tightly spaced two-line
  annotations with one explicit, editable anchor and offset per series; color
  has no legend, and the remaining enlarged arrow-only legend distinguishes
  observed from lighter predicted paths and annotations. The NOCA Holocene
  observed annotation is anchored above CC1; the MORA Holocene observed
  annotation is anchored below CC4. Individual Holocene dates and the pooled
  full-Holocene-centroid alternative are no longer active displays.

### CCA community-direction analysis

The final descriptive stage pairs predicted and observed direction associations
within each measurement unit and target. For every taxon and raw climate arrow,
the **target-alignment discrepancy** is `predicted cosine - observed cosine`.
For a taxon, the predicted cosine compares LC movement with the vector from
initial LC to the fixed species score; the observed cosine compares WA movement
with the vector from initial WA to that same score. Climate targets use the
common raw biplot arrow. Zero means equal target-specific cosines, not complete
movement-vector agreement. A positive value means stronger predicted target
alignment, including cases where predicted movement is less strongly opposed
to the target; a negative value means stronger observed target alignment. The
absolute magnitude gives the strength of this target-specific discrepancy. The
retained direct cosine and unsigned LC–WA angle separately measure overall
movement-vector agreement and deviation. These are descriptive directional
differences, not taxon dominance or causal effects. All 607 modern plot pairs
and all 15,270 primary Holocene age-draw × offset × interval realizations are
evaluated before summarizing. Holocene values follow the established
draw-within-offset, half-open 100-year-grid, then across-offset hierarchy before
joining climate-change/stability and high-fire status; modern values retain all
site × burned groups, including the two burned MORA plots.

Every vector uses the exact current `scaling = "sites"` (vegan scaling 1),
Hill-off, CCA1–CCA2 coordinate system; display arrow multipliers never enter the
calculation. Cosines are clamped to [-1, 1] and set to `NA` below the existing
`1e-8` tolerance. The paired contrast is `NA` unless both component cosines are
valid; the valid predicted component remains recorded for the 153 modern plots
with near-zero observed movement. Outputs use descriptive boxplots, medians, and
quartiles without ranking. They are not confidence intervals or causal,
prevalence, dominance, contribution, or numbered-era inference.

## Documentation index

| Document | Authority and scope |
|---|---|
| [WORKFLOW.md](WORKFLOW.md) | Operational authority: order, dependencies, inputs, outputs, caching, commands, and tests. |
| [SCIENTIFIC_DECISIONS.md](SCIENTIFIC_DECISIONS.md) | Current scientific rationale, quantitative baselines, caveats, and unresolved sensitivities. |
| [FIGURE_CAPTIONS.md](FIGURE_CAPTIONS.md) | Separate concise method summaries, figure previews, and publication-ready captions for Figures 2–5. |
| [cca_tracking_metrics.pdf](cca_tracking_metrics.pdf) | Working mathematical specification for CCA tracking metrics. |
| [Holocene_period_choices_MORA_NOCA_summary.pdf](Holocene_period_choices_MORA_NOCA_summary.pdf) | Literature/context reference retained outside the literature-blind era classification. |
| [CLAUDE.md](CLAUDE.md) | Short redirect; the former plan is archived and non-authoritative. |
| [Cores/CONTROL_POINTS.md](Cores/CONTROL_POINTS.md) | Master age-control table and Bacon interpretation. |
| [Cores/SOURCES_MORA.md](Cores/SOURCES_MORA.md) | MORA core chronology provenance. |
| [data/NOCA/NOCA_paleo/SOURCES.md](data/NOCA/NOCA_paleo/SOURCES.md) | Panther Potholes vegetation, chronology, and macrocharcoal provenance. |
| [data/SOURCES_SURVEY_YEARS.md](data/SOURCES_SURVEY_YEARS.md) | Survey-date and modern climate-window provenance. |
| [R/000_NOCA_cleaning_guide.md](R/000_NOCA_cleaning_guide.md) | NOCA tree-patch, exclusions, paired-universe, and output guide. |
| [R/README_occurrence_consolidation.md](R/README_occurrence_consolidation.md) | Taxonomic harmonization, understory, and species-threshold rationale. |
| [data/MORA/README_data_raw.md](data/MORA/README_data_raw.md) | Reference-only description of the upstream MORA raw-data package. |
| [data/README_outputs_MORA_AT.md](data/README_outputs_MORA_AT.md) | Reference-only description of upstream MORAcleaning products. |

Same-directory self-contained HTML companions are generated with
`Rscript R/render_docs.R`. The vendored Wilson README and documents under
`docs/archive/` are preserved as external/historical records and are not rendered
or treated as current authority.

## Principal outputs

| Output | Contents |
|---|---|
| `MORA_occ.csv`, `NOCA_occ.csv`, `paleo_occ.csv` | Standardized plot/sample × species occurrences |
| `NOCA_tree_correction_audit.csv` | Corrected rows, action, inclusion, and exclusion reason |
| `NOCA_tree_composition_audit.csv` | Unpatched versus corrected present composition; 50 modeled plots change |
| `NOCA_study_exclusions.csv` | Study-level exclusion reasons and source notes for `BAK487` and `BEAV6061` |
| `NOCA_coordinate_collision_audit.csv` | Raw/normalized coordinates and unresolved-retained status for the sole exact collision, `CARI449`/`CARI450` |
| `*_plot_info_fire.csv` | Modeling plot coordinates and fire classification |
| `NOCA_fire_assignment_audit.csv` | NOCA fire years, basis, and assignment provenance |
| `NOCA_fire_Wilson2024_comparison.csv` | PaleoACES versus publication universe and assignments |
| `MORA_climate.csv`, `NOCA_climate.csv`, `paleo_env.csv` | Climate inputs used by the CCA |
| `occ_consolidated.csv` | Harmonized occurrence table used by the model |
| `cca_tracking_anthropocene_*.csv` | Plot-level tracking metrics and descriptive MORA/NOCA summaries |
| `cca_tracking_holocene_*.csv` | Primary 1,000-year realization, draw-within-offset, and full 100-year-grid tracking series; `_500yr` files are sensitivity outputs |
| `cca_tracking_climate_scaling.csv` | Fixed pooled-legacy means, SDs, units, and sample sizes used for standardized climate rates |
| `cca_tracking_visualization_points.csv` | Common Holocene site-date and Anthropocene plot source, plus compatibility aggregates; the active figure recalculates its summaries only from raw rows |
| `cca_tracking_holocene_era_coverage.csv` | Complete-ten-offset site-date coverage for every MORA/NOCA × CC/S combination, including explicit missing slots |
| `cca_tracking_interval_resolution_audit.csv` | Descriptive support, distribution, and matched-date comparison of primary 1,000-year and sensitivity 500-year tracking |
| `cca_tracking_comparison_summary.csv` | Independently calculated counts, medians, quartiles, and whiskers for fire-stratified main boxes, macro eras, NOCA Anthropocene fire status, and Holocene climate state × fire status across the four displayed metrics |
| `cca_tracking_anthropocene_fire_scope_audit.csv` | All 607 modern pairs with burned status, inclusion decision, and explicit exclusion of the two burned MORA pairs |
| `cca_tracking_comparison_spec.csv` | Auditable fixed-site facets, explicit era/state × fire grouping, raw-linear lag/rate/ratio/angle contracts, 589-point background, four macro medians, eight climate-state/fire medians, two NOCA fire-status medians, stationary-angle annotation, reference lines, symmetric raw-lag fill limits, and panel-width fractions |
| `cca_direction_anthropocene_realizations.csv`, `cca_direction_holocene_realizations.csv.gz` | All 10,319 modern and 259,590 primary Holocene unit × taxon/climate paired rows, with predicted and observed cosines, predicted-minus-observed contrasts, direct movement angle/cosine, and explicit validity flags |
| `cca_direction_holocene_by_offset.csv.gz`, `cca_direction_holocene_timeseries.csv` | 2,635 draw-within-offset and 2,329 complete-ten-offset site-date directional-difference summaries using the tracking stage's half-open mapping |
| `cca_direction_group_summaries.csv`, `cca_direction_scope_audit.csv` | All 204 descriptive site × climate/fire or site × burned summaries, support/NA counts, geometry settings, and upstream hashes; no rankings |
| `holocene_era_climate_*.csv` | Lake/site/phase signed changes, pooled-calibration standardization, regional phase scores, 50%-maximum thresholds, directional cells, and unthresholded composite |
| `holocene_era_grid.csv`, `holocene_era_catalog.csv`, `holocene_era_driver_subintervals.csv`, `holocene_era_climate_change_subphases.csv` | Exhaustive complete-domain CC/S cells, eight merged eras, every variable/direction interval, and auditable driver-trough subdivisions |
| `walsh_charanalysis_*.csv` | Pinned official-engine inputs, settings, series, events, FRIs, package/source hashes, publication regression, and comparison with the separate primary `tapas` catalog |
| `holocene_fire_source_*.csv`, `holocene_fire_tapas_manifest.csv` | Authoritative all-`tapas` source series, accepted events, settings, coverage, package version, and hashes; the official Walsh engine remains a separate audit |
| `fire_event_detection_lake_audit.csv` | Four-core comparison of engine, chronology, interpolation, background smoother, local threshold, candidates, count-screen rejections, and accepted events |
| `holocene_era_fire_*.csv` | Normalized core/site frequency, robust thresholds, all retained high-fire runs, and strength/background corroboration |
| `holocene_era_fire_threshold_ratio.csv` | Display audit for normalized site fire frequency divided by its frozen robust threshold; values above 1 retain the existing high-fire classification |
| `holocene_fire_method_worked_example.csv` | Exact core- and site-level arithmetic used in the 2,300 cal-BP fire worked example |
| `offset_timeseries*.csv` | Backward-compatible LC-predicted vegetation, observed vegetation, and offset data; no offset figures are generated |
| `plot/fig_tracking_comparison.*` | Main-paper PDF/PNG with equal-width fixed-site-facet boxplot/detail panels A–C (lag rate, ratio, angle) and a centered 75%-width panel-D angle × tracking-ratio scatter; pooled state labels list their exact represented CC/S eras |
| `holocene_anthropocene_raw_climate_rate_comparison.csv` | Raw physical-rate comparison: maximum-absolute Holocene equal-site regional median after ten-offset aggregation and annualized Anthropocene plot-rate medians for the exact MORA/NOCA windows, all per century |
| `plot/fig_standardized_climate_change_eras_fire.*` | Main-paper PDF/PNG of signed Holocene climate change, readable variable-specific stability brackets near 10 ka, raw-rate comparison, and threshold-normalized MORA/NOCA fire-frequency ratios |
| `plot/test_figures/fig_holocene_climate_period_method_worked_example.pdf` | PDF-only worked example for the 50% threshold, phase support, any-variable union, no-gap rule, composite role, and independent fire rule |
| `plot/test_figures/fig_holocene_fire_method_worked_example.pdf` | PDF-only six-step worked example of accepted-event counting, core normalization, site aggregation, robust thresholding, and high-fire classification |
| `plot/test_figures/fig_walsh_charanalysis_reproduction.pdf` | PDF-only three-page official Walsh reconstruction and publication discrepancy audit |
| `plot/test_figures/fig_fire_event_detection_workflow.pdf` | PDF-only six-page all-core explanation of how charcoal residual candidates become accepted fire events, plus the separate MORA software/publication audit |
| `plot/fig_cca_trajectories.*` | Main-paper PDF/PNG with A. pooled trajectories, B. biplot inset, C. climate contributions, D. species contributions, eight independently positioned two-line path names, transparent predicted paths/annotations, and an arrow-only observed/predicted legend |
| `cca_trajectory_era_centroids.csv` | Site × CC1–S4 observed WA and predicted LC centroids used by the selected trajectories |
| `plot/fig_cca_direction_differences.*` | Main-paper PDF/PNG with A. Climate and B. Species median heatmaps of target-alignment discrepancy (predicted minus observed); display labels use climate stability, species names are italicized, and neutral era labels highlight only high fire/burned status in red within MORA/NOCA facets |
| `plot/test_figures/fig_cca_direction_differences_audit.pdf` | Three-page complete taxon/climate boxplot audit retaining individual valid units, distributions, and explicit two-unit groups |
| `bacon_run_manifest.csv` | Seed, versions, settings/control/output hashes, the historical whole-script hash used for five chronology runs, and a separately checked chronology-code fingerprint; the recorded post-run revision is limited to PDF location and PNG persistence |
