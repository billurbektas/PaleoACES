# Modern-only covariates. Shared GLS lives in reconstruction_models.R.
tracking_modern_elevations = function(mora,noca,plots) {
  elevations=bind_rows(
    mora |> transmute(site='MORA',join_id=toupper(trimws(plot_id)),elevation,
      elevation_source='data/MORA_plots.rda: plot_info$elevation'),
    noca |> transmute(site='NOCA',join_id=toupper(trimws(`2015.Plot.Name`)),
      elevation=`2015.Elevation.m`,
      elevation_source='data/NOCA/NOCA_plots_fromWilson.csv: 2015.Elevation.m'))
  if(anyDuplicated(elevations[c('site','join_id')])) stop('Ambiguous elevation identity')
  result=plots |> mutate(join_id=toupper(trimws(plot_id))) |>
    left_join(elevations,by=c('site','join_id'),relationship='many-to-one')
  if(any(!is.finite(result$elevation))) stop('Missing elevation for plots: ',
    paste(result$plot_id[!is.finite(result$elevation)],collapse=', '))
  result |> select(-join_id)
}
