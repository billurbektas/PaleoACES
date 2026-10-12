# Current settings; presence and climate tables are prepared above in 04_cca_model.R.
CCA_VARIABLES = c("MSpT", "MWT", "SP", "WP")
cca_scaling = "sites"
cca_hill = FALSE

# Matched legacy observations used to calibrate the CCA.
species_past_final = species_past[present_pairs, keep_species, drop = FALSE]
env_past_final = env_past[present_pairs, CCA_VARIABLES, drop = FALSE]

cca_formula = reformulate(CCA_VARIABLES, response = "species_past_final")
reference_path=here('output/cca_calibration_reference.rds')
if(file.exists(reference_path) && count.thr==CCA_COUNT_THRESHOLD && !length(extra_exclude) && !nzchar(cca_suffix)) {
  frozen=readRDS(reference_path)
  if(!isTRUE(all.equal(species_past_final,frozen$legacy_species,tolerance=0)) ||
     !isTRUE(all.equal(env_past_final,frozen$legacy_climate,tolerance=0)) ||
     !identical(keep_species,frozen$retained_species))
    stop('Fixed CCA calibration inputs changed; do not recalibrate during reconstruction migration')
  cca_model=frozen$model
} else cca_model=cca(cca_formula,data=env_past_final)

# Resurvey positions: climate-predicted (LC) and observed (WA).
predicted_present = predict(cca_model, newdata = env_present_final, type = "lc", scaling = cca_scaling, hill = cca_hill)
projected_present = predict(cca_model, newdata = species_present_final,
                            type = "wa", scaling = cca_scaling, hill = cca_hill)
