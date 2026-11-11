# Export the existing primary fit and its exact prepared inputs, without changing
# calibration, projections, axes, species selection or Figure 4 calculations.
export_cca_reference = function(e) {
  source(here::here('R/helpers/tracking_metrics.R'), local = TRUE)
  scaling = make_climate_scaling(e$env_past_final)
  past_wa = predict(e$cca_model, newdata=e$species_past_paired, type='wa',
    scaling=e$cca_scaling, hill=e$cca_hill)
  past_lc = predict(e$cca_model, newdata=e$env_past_paired, type='lc',
    scaling=e$cca_scaling, hill=e$cca_hill)
  past = tibble::tibble(plot_id=rownames(e$species_past_paired),
    o1=past_wa[,1], o2=past_wa[,2], p1=past_lc[,1], p2=past_lc[,2]) |>
    dplyr::bind_cols(tibble::as_tibble(e$env_past_paired)[CCA_CLIMATE_VARS])
  present = tibble::tibble(plot_id=rownames(e$species_present_final),
    o1_2=e$projected_present[,1], o2_2=e$projected_present[,2],
    p1_2=e$predicted_present[,1], p2_2=e$predicted_present[,2]) |>
    dplyr::bind_cols(tibble::as_tibble(e$env_present_final)[CCA_CLIMATE_VARS] |>
      dplyr::rename_with(~paste0(.x,'_2')))
  modern = tibble::tibble(plot_id=e$present_pairs) |>
    dplyr::left_join(past,by='plot_id') |>
    dplyr::left_join(present,by='plot_id') |>
    dplyr::left_join(e$site_lookup,by='plot_id') |>
    dplyr::left_join(e$read_plot_years(),by=c('site','plot_id'))
  inputs = out(c('occ_consolidated.csv','MORA_climate.csv',
    'NOCA_climate.csv','paleo_env.csv','modern_plot_years.csv'))
  inputs = inputs[file.exists(inputs)]
  # vegan prediction evaluates the formula response after deserialization.
  # Give the exported copy a portable formula environment, keeping the fit intact.
  portable = new.env(parent=baseenv())
  portable$species_past_final = e$species_past_final
  portable$env_past_final = e$env_past_final
  model_copy = e$cca_model
  attr(model_copy$terms,'.Environment') = portable
  attr(model_copy$terminfo$terms,'.Environment') = portable
  reference = list(model=model_copy,
    legacy_species=e$species_past_final, legacy_climate=e$env_past_final,
    calibration_plot_ids=rownames(e$species_past_final), retained_species=e$keep_species,
    species_scores=e$species_scores, climate_scores=e$env_scores,
    climate_variables=CCA_CLIMATE_VARS, climate_labels=e$CLIMATE_VARIABLE_LABELS,
    climate_units=e$CLIMATE_VARIABLE_UNITS, climate_scaling=scaling,
    scaling=e$cca_scaling, hill=e$cca_hill, axes=1:2,
    comparison=e$comparison_df, modern_endpoints=modern,
    provenance=list(input_md5=tools::md5sum(inputs),
      model_source_md5=tools::md5sum(here::here(c('R/pipeline/10_cca.R',
        'R/helpers/config.R','R/helpers/climate_variables.R','R/helpers/survey_years.R',
        'R/helpers/cca_reference.R','R/helpers/tracking_metrics.R'))),
      R_version=as.character(getRversion()), vegan_version=as.character(utils::packageVersion('vegan'))))
  stopifnot(nrow(reference$legacy_species)==sum(ANTHROPOCENE_PAIRS), length(reference$retained_species)==14L,
    identical(rownames(reference$legacy_species),rownames(reference$legacy_climate)),
    nrow(modern)==sum(ANTHROPOCENE_PAIRS), !anyDuplicated(modern$plot_id))
  # The CSV also carries the display-only seasonal variables, standardized on the
  # same legacy calibration plots; the CCA constraints' rows equal `scaling`.
  calibration_climate = e$climate_summary[e$climate_summary$period == 'past' &
    e$climate_summary$plot_id %in% rownames(e$species_past_final), ]
  stopifnot(nrow(calibration_climate) == nrow(e$species_past_final))
  display_scaling = make_climate_scaling(calibration_climate,
    union(CCA_CLIMATE_VARS, CLIMATE_DISPLAY_VARIABLES))
  check = display_scaling[match(scaling$variable, display_scaling$variable), names(scaling)]
  if (!isTRUE(all.equal(as.data.frame(check), as.data.frame(scaling), check.attributes = FALSE)))
    stop('Display climate scaling disagrees with the CCA calibration scaling')
  readr::write_csv(display_scaling,out('cca_tracking_climate_scaling.csv'))
  saveRDS(reference,out('cca_calibration_reference.rds'))
  invisible(reference)
}
