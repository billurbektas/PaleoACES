# Fixed-CCA transition contributions and species models

[Stage 16](../../R/stages/16_cca_transition_contributions.R) calculates contributions before
[stage 17](../../R/stages/17_species_contribution_models.R) fits species explanatory GLS.
Both belong to the active workflow. The fixed CCA uses 607 legacy plots, 14 retained taxa,
CCA1–CCA2, site scaling and Hill = FALSE; it is neither recalibrated nor used to rerun Bacon.

## Original samples and primary transitions

Each original sample is projected separately. Its unrounded full-posterior median age assigns
it to one native CHELSA century. Within a century, sample WA coordinates are averaged.
Consecutive occupied centuries define actual-duration transitions, including gaps.
There is no vegetation interpolation, bin offset, occupancy cutoff or averaged assemblage
projection. Modern plot pairs retain their existing WA/LC endpoints and elapsed times.

## Species-vector identity

For sample relative species weights q and fixed site-scaled species positions V,
WA(q) = (q − calibration column masses) V. Normalize each sample separately before
averaging endpoint weights. The calibration centering term cancels between endpoints:

`delta WA = sum_species [(mean q_t2 − mean q_t1) × V_species]`.

The species vector is delta q times its fixed coordinates, with no extra eigenvalue multiplier.
Its signed parallel contribution is its dot product with the unit delta-LC vector.
The contribution rate multiplies this displacement by 100 / vegetation elapsed years.
Positive contributions move along the climate-predicted direction; negative values move against it.
Raw CCA1/CCA2 vectors and relative-weight changes remain in the audit records.

Reference vectors at or below the existing 1e-8 direction tolerance are undefined.
Missing contributions remain NA; genuine zero vectors/contributions remain zero.
Every transition is checked numerically for vector conservation under vegan scaling.
Perpendicular contributions are retired.

## Seasonal climate decomposition

Change each raw seasonal variable separately from its initial to final value, holding the
others at their initial values. Subtract initial LC to obtain its vector. The four vectors
sum exactly to delta LC. Project each along delta WA; these values retain **CCA displacement**
units, without dividing by elapsed years. They are algebraic attributions, not causal effects.
No climate-variable statistical models are fitted.

## Primary records, boxplots and GLS

Separate `species_primary.csv` and `climate_primary.csv` files are written under
`output/cca_transition_contributions/`. Each primary Holocene transition and each modern
pair enters once per component. Species and climate variables remain on the boxplot y-axis.
Species x values are parallel contribution rates (CCA distance per century); climate x values
are parallel displacements. PDFs are directly under `plot/test_figures/`.

Holocene species models use contribution_rate ~ site + climate_rate + fire_activity,
site-specific residual variances and primary MA(1) covariance, matching community models.
Independent and CAR1 are comparison diagnostics only.
Modern species use contribution_rate ~ site + burned only, with independent residuals and
site-specific variances. There is no modern species elevation model. Constant responses,
rank deficiency and failures are reported without dropping zeros or changing specifications.

## Complete-chronology sensitivity

Each of 1,000 complete Bacon chronologies reconstructs its own occupied centuries and pairs.
Species contributions are calculated before fitting that draw's explanatory models. Models
retain the primary MA(1) covariance family and reestimate its parameters. The primary
species input is not a median of draw contributions. Draw-specific records and fitted models
remain in resumable chronology checkpoints; coefficient and fit-status tables are exported.

Assess coefficient signs, magnitudes and confidence-interval conclusion consistency using
explicit valid-fit denominators. Sensitivity quantiles are not conventional confidence intervals
or posterior probabilities. No averaging of primary estimates, pooled p-values or uncertainty
reduction by the number of reconstructions is performed. Primary model intervals condition on
the primary reconstruction. MORA fire chronologies remain fixed; NOCA events and vegetation
share the same chronology draw. Original CCA/model uncertainty is not resampled.
