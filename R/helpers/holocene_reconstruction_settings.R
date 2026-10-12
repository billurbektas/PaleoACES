# New ecological reconstruction settings. The descriptive CC/S and high-fire
# analyses retain their existing 1,000-year settings independently.
HOLOCENE_RECONSTRUCTION_DRAWS = 1000L
HOLOCENE_RECONSTRUCTION_SEED = 42L
HOLOCENE_SUPPORT_SCENARIOS = c(0, .10, .25, .50, .75, .90, 1)

# Deliberately unset until the reconstruction-support audit has been reviewed.
# Zero is an explicit no-cutoff choice; NULL is a pending decision.
HOLOCENE_SUPPORT_POLICY = list(century_occupancy = NULL, species_joint_occupancy = NULL)

require_holocene_support_policy = function(policy = HOLOCENE_SUPPORT_POLICY) {
  keys = c('century_occupancy', 'species_joint_occupancy')
  valid = function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 && x <= 1
  if (!all(keys %in% names(policy)) || !all(vapply(policy[keys], valid, logical(1))))
    stop('Century reconstruction is awaiting separate occupancy and species joint-support ',
         'decisions. Run --reconstruction-audit and review its diagnostics first; ',
         'no support cutoff has been authorized.', call. = FALSE)
  invisible(policy)
}
