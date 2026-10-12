# Tracking reconstruction validation

The active analysis uses original sample identities and unrounded full-posterior median
Bacon ages. Native 100-year CHELSA cells define reconstructed sample-WA centroids;
consecutive occupied cells define variable-duration transitions. There is no interpolation,
phase aggregation or occupancy exclusion cutoff.

Independent offline checks reconstruct sample ages from raw accumulation rows, sample
centroids from individual projections, endpoint climate/rates, whole-duration per-core fire
exposure, species vectors and their conservation. Model checks verify unchanged indices,
identical comparison rows, the prescribed primary MA(1) covariance and separate AIC recommendations, fitted means/contrasts,
predictions and descriptive R². All 1,000 community and species chronology outcomes are audited.

The fitted CCA and 607 modern pairs remain fixed. Stored chronology inputs and descriptive
CC/S/high-fire products are preserved. Chronology-reconstruction sensitivity is reported
separately from primary conditional confidence intervals; it is not a pooled model interval.

The earlier 1,000-year calculations and support audit are preserved as Git checkpoints,
not active analyses. See [workflow](../WORKFLOW.md), [scientific decisions](../SCIENTIFIC_DECISIONS.md),
[contribution methods](README_cca_transition_contributions.md), and the
[figure migration manifest](TRACKING_FIGURE_MIGRATION.csv).

The [figure input audit](TRACKING_FIGURE_INPUT_AUDIT.csv) identifies the source, observational
unit and PDF page for 49 figure panels. Primary contribution boxes contain actual transitions
and plot pairs, while Bacon ranges summarize complete chronology reconstructions separately.
MA(1) is primary for all Holocene-containing models; Independent and CAR1 remain comparisons.
