# Standalone fixed-CCA transition contributions

Run `Rscript R/stages/16_cca_transition_contributions.R`, then
`Rscript R/tests/test_cca_transition_contributions.R`, from the repository root.
The script is deliberately outside the active workflow. It reads the existing
CCA reference, occurrence records, whole Bacon draws and canonical calculation
tables; it writes only new files in `output/cca_transition_contributions/` and
two named PDFs directly in `plot/test_figures/`. It does not refit the CCA,
regenerate chronology, download climate, fit statistical models or replace
other analysis outputs. All ten 1,000-year offsets, including 800, retain their
identities in the calculations and sensitivity summaries, without R² weights.
The descriptive boxplots combine their offset-specific transition points.

The maintained calculation code is in
[cca_transition_contributions.R](../../R/helpers/cca_transition_contributions.R).
The executable is
[16_cca_transition_contributions.R](../../R/stages/16_cca_transition_contributions.R),
and independent checks are in
[test_cca_transition_contributions.R](../../R/tests/test_cca_transition_contributions.R).

## Fixed calibration and observational units

The analysis uses the unchanged 607-plot, 14-taxon pooled CCA, including
ponderosa pine, with CCA1–CCA2, `scaling = "sites"` and `hill = FALSE`.
For Anthropocene observations, one transition is one of the 607 paired plots.
For Holocene observations, a realization is one lake × actual adjacent
1,000-year transition × whole Bacon draw × bin offset. Calculations use the
26,168 existing valid lake realizations and all 100 configured draws. Missing
transitions are not created. Lake coverage is not forced to match.

`age_hi` and `age_lo` are older and younger **bin midpoints** in cal BP.
The endpoint bins are `[midpoint − 500, midpoint + 500)`. Their means are based
on observed samples and complete native climate slices; there is no temporal
interpolation. Modern `lake`, `draw`, `offset` and cal-BP fields are `NA`.
The exact modern endpoints, seasonal climate windows and elapsed times are
retained in the unmodified canonical calculation table, joined by `site` and
`plot_id`.

## Species displacement decomposition

Let $q_{ij}=x_{ij}/\sum_j x_{ij}$ be the relative weight of retained species
$j$ in sample $i$. Here $x_{ij}$ is binary presence/absence, so a present
species has weight equal to the reciprocal of that sample's retained-taxon
richness. These are not abundance or macrofossil-count proportions.

Let $s_j$ be its fixed two-axis species position and $c_j$ the calibration
column mass. Vegan's WA prediction, with the selected site scaling and Hill
off, is

\[
WA_i=\sum_j(q_{ij}-c_j)s_j.
\]

The inverse square-root-eigenvalue factor in raw WA prediction cancels the
square-root-eigenvalue factor in site scaling. The species positions therefore
receive **no additional eigenvalue multiplier**. This is verified against the
installed vegan implementation, the saved species scores and one-species
predictions. See vegan's maintained
[WA prediction implementation](https://github.com/vegandevs/vegan/blob/master/R/predict.cca.R)
and [score scaling implementation](https://github.com/vegandevs/vegan/blob/master/R/scores.cca.R).

For each Holocene bin, first normalize every sample separately and then average
its relative weights: $\bar q_j=\operatorname{mean}_i q_{ij}$.
Linearity means this exactly preserves the existing mean of sample-level WA
positions. Normalizing pooled bin occurrences would give a different weighting
and is not used.

The species contribution to a transition is

\[
V_j=(\bar q_{2j}-\bar q_{1j})s_j,
\qquad \sum_j V_j=\Delta WA.
\]

The calibration-centering constant cancels between endpoints. Modern plots use
their individual endpoint weights in the same equation. `weight_t1`,
`weight_t2` and `weight_change` remain in the detailed records. A weight change
can reflect changes in other taxa through the relative-weight denominator;
it does not always indicate that the focal taxon was gained or lost.

## Climate-variable displacement decomposition

For each of `MSpT`, `MWT`, `SP` and `WP`, change only that variable from its
initial to final endpoint value, holding the other three at their initial
values. Its vector is

\[
C_k=LC(E_1+\Delta E_k e_k)-LC(E_1),
\qquad \sum_{k=1}^4 C_k=\Delta LC.
\]

The existing fixed CCA has additive, continuous, full-rank constraints, so this
identity holds. It is independently verified using each raw-variable change
times its fitted coefficient and the square-root-eigenvalue site-scaling
factor. Biplot arrows and the standardized physical climate-change-rate
predictor are not substituted for this LC decomposition. Raw endpoint values,
physical units and changes are exported for interpretation. These vectors are
an algebraic attribution within the fitted CCA, rather than causal effects of
independent climate variables.

## Signed projections of raw displacement

For reference vector $r=(r_1,r_2)$, define the unit direction

\[
u=\frac{r}{\|r\|}.
\]

The signed parallel contribution is the scalar $V\cdot u$.
Positive values mean movement along the reference direction; negative values
mean movement against it. Raw CCA1 and CCA2 coordinates are retained as the
underlying two-axis geometry for verifying vector additivity.

Species use **ΔLC** as their reference; climate variables use **ΔWA**.
All coordinate vectors and signed projections are **raw displacement in CCA
units**. They are not divided by elapsed years or multiplied by 100. Both
elapsed times remain contextual information only: changing either duration
without changing the endpoints leaves every contribution unchanged.

These distributions compare movement over each era's actual transition windows,
not movement rates. Holocene transitions span 1,000 years, while modern survey
and climate windows are shorter and can differ. Relative species weights remain
unitless; seasonal endpoint values retain their original physical units.

Reference magnitudes at or below `1e-8` have undefined directions. The parallel
contribution becomes `NA` and `reference_direction_valid = FALSE`, while raw
vectors and weight changes remain available. A zero
contributor projected onto a valid reference gives zero. A stationary observed
community makes climate-variable projections undefined, but does not remove
species vectors or valid projections onto ΔLC.

## Long-format products

All paths below are relative to `output/cca_transition_contributions/`.

| File | Unit and role |
| --- | --- |
| `species_realizations.csv` | 374,850 transition/realization × species rows, combining both eras. Endpoint weights, changes, raw CCA vectors, signed parallel contributions and direction validity. |
| `climate_realizations.csv` | 107,100 transition/realization × seasonal variable rows, combining both eras. Physical endpoint values and changes, raw CCA vectors, signed parallel contributions and direction validity. |
| `species_holocene_uncertainty.csv` | 30,576 lake × offset × actual transition × species × measure × sampling-rule distributions. |
| `climate_holocene_uncertainty.csv` | 6,552 corresponding seasonal-variable distributions. |
| `species_holocene_offset_summary.csv` | 4,480 lake × offset × species × measure × sampling-rule trajectory summaries, preserving whole draws. |
| `climate_holocene_offset_summary.csv` | 960 corresponding seasonal-variable summaries. |
| `species_era_site_summary.csv`, `climate_era_site_summary.csv` | Descriptive park-level trajectory/plot means and chronology support; separate from the boxplot observations. |
| `species_boxplot_values.csv` | 12,320 transition/plot × species rows: actual Holocene transition medians and individual modern values, retaining undefined entries and draw support. |
| `climate_boxplot_values.csv` | 3,520 corresponding transition/plot × seasonal-variable rows. |
| `transition_validation.csv` | One row for each of the 26,775 original transitions/realizations: raw-vector and projection sum errors, and independent reference-direction flags. |
| `species_basis.csv`, `climate_basis.csv` | Fixed species positions and column masses; raw-variable LC coefficients after the selected site scaling. |
| `reference_source_audit.csv`, `provenance.json` | Original/current source checksums, fixed settings, input checksums and installed versions. |
| `schema.csv`, `validation.txt` | Column names, types and units; numerical validation and support results. |

Shared identification columns are `era`, `site`, `lake`, `plot_id`, `draw`,
`offset`, `age_hi`, `age_lo` and `interval_mid_cal_bp`. The detailed records
include both elapsed times and both endpoint sample counts. Modern endpoint
sample counts equal one plot at each survey, not numbers of tree records.

Three displacement measures are `contribution_CCA1`, `contribution_CCA2`
and `parallel_contribution`, all in CCA units.
Species summaries also retain unitless `weight_change`. There are no rate
columns or annualized calculations in this standalone analysis.

## Bacon uncertainty, sampling support and offset sensitivity

All vectors and direction-dependent projections are calculated **within each
realization before aggregation**. For each actual transition and offset, the
uncertainty tables report mean, SD, median and 2.5/97.5 percentiles separately
for each component and measure. `sampling_rule = all` includes every present
realization; `nmin2` requires at least two samples in both endpoint bins.

Counts distinguish the 100 expected draws, present draws, eligible draws,
mathematically valid draws and undefined eligible draws. `n_missing_draws`
equals expected minus present; `n_undefined_draws` equals eligible minus valid.
Empty eligible/valid distributions retain their support counts and `NA`
statistics. No majority-draw threshold or synthetic draw is introduced.

Trajectory summaries first average finite contributions across a lake's
supported, non-overlapping transitions within each draw and offset, then
summarize those draw-specific means. Counts retain the minimum and maximum
number of supported transitions. Each offset remains a separate sensitivity
result; results are not pooled as independent observations or divided by √10.
Lake coverage differs and the distributions are conditional on valid
realizations. These are Bacon chronology and bin-placement sensitivities,
not statistical model confidence intervals. CCA calibration and climate-model
uncertainty are not propagated.

## Horizontal boxplots

Species and climate variables stay on the **y-axis**, with raw signed CCA
parallel contributions on the **x-axis**. MORA/NOCA form two columns,
with the two eras in side-by-side boxes.
Each analysis has one single-page PDF in
`plot/test_figures/`:

- [Species boxplots](../../plot/test_figures/fig_cca_transition_species_boxplots.pdf).
- [Climate-variable boxplots](../../plot/test_figures/fig_cca_transition_climate_boxplots.pdf).

Matching previews, `species_boxplot.png` and
`climate_boxplot.png`, are saved beside the calculation tables in
`output/cca_transition_contributions/`, preserving the existing PDF-only
diagnostic figure contract. The previous heatmaps are retired.

For each species or climate variable, a Holocene point is the median across
finite Bacon draws of **one lake transition within one offset**. All 273
lake-transition records across the ten offsets supply the descriptive
Holocene distributions, without taking another median across offsets or
separating them into different pages. Every modern plot contributes once per
species or climate variable, giving 607 plot points before excluding undefined
projections. These are the same values retained in `*_boxplot_values.csv`.

Chronology draws are summarized independently for each measure; an undefined
parallel contribution does not remove a valid coordinate contribution.
The plotted Holocene distributions combine overlapping bin placements for
visual description. Offsets remain alternative reconstructions, not independent
ecological replicates; the boxplots do not add a statistical model or treat
these points as independent observations for inference.

The exported `*_boxplot_values.csv` files retain `NA` observations and Holocene
present, valid and undefined draw counts. Plotting omits undefined values but
retains defined zeros. With the current inputs, each species distribution uses
all 273 Holocene transitions and 607 modern pairs; each climate-variable
distribution uses 272 Holocene transitions and 465 modern pairs. One Holocene
transition and 142 modern pairs have undefined observed directions, so their
climate projections remain `NA` in the calculation and plotting tables.
Boxes show the median and interquartile range, whiskers
extend to values within 1.5 × IQR, and points beyond the whiskers are shown.
These are descriptive distributions, not confidence intervals. Lakes with
more supported transitions contribute more transition observations; this
choice is explicit rather than an equal-lake summary.

Raw-contribution x limits stay fixed across parks and eras within each PDF. Species and climate figures have their own limits.
The separate `*_era_site_summary.csv` tables still average finite transitions
within each lake/draw/offset, then equally weight available lake means within
park/draw/offset and take the median across draws. Modern park summaries are
means across valid plots. These numerical summaries do not supply the boxplot
observations.

Component medians need not add up after aggregation; exact additivity is
verified at the original transition/draw level. These contributions decompose
displacement, not changes in lag or counterfactual pace/direction effects.
Adjacent transitions share endpoints, and lake histories, chronology draws and
alternative offsets do not create independent ecological replicates.

## Numerical verification and provenance

The producer checks the preserved calibration and sample identities, WA
endpoints, climate LC endpoints, every species and climate vector sum,
parallel contribution sums. An independent test rebuilds occurrences,
sample-normalized bin weights, sample-mean WA, lake-specific raw climate bins,
direct-coefficient climate vectors, trigonometric projections, all uncertainty
distributions, support counts, park summaries and every boxplot observation. Synthetic cases test
stationary/tiny references, zero components, signs, invariance to elapsed times,
sparse draws and empty sensitivity groups.

For the current inputs, maximum raw-vector sum errors are approximately
`1.82e-15` for species and `8.60e-16` for climate variables, well below the
`1e-10` acceptance tolerance. All 607 modern pairs and 26,168 Holocene
realizations are retained. Climate-variable projections are undefined for
142 stationary modern pairs and 257 Holocene realizations; their coordinate
vectors remain available. Species references are valid for every current
transition.

The reference's original tracking-helper checksum predates metric-only edits;
that helper supplied the calibration scaling table rather than fitting the
CCA. The difference is recorded, its stored means/SDs/sample sizes are verified
against the frozen legacy climate matrix, and all fitting sources and inputs
must match. The reference bundle is never rewritten.
