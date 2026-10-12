# Assemble one primary transition/plot x response input, with no bin phases.
tracking_corrected_response_names=function() century_response_names()[8:9]
tracking_correction_effect_response_names=function() c('pace_effect_on_lag_per_century','direction_effect_on_lag_per_century')
tracking_combined_response_names=century_response_names
tracking_model_available_names=function() c(century_response_names(),'standardized_climate_change_rate')
combine_tracking_model_data=function(h,modern,lake_coordinates,plot_coordinates,hc,ac) {
  corrected=add_corrected_lag_rates(ac) |> dplyr::select(site,plot_id,dplyr::all_of(tracking_corrected_response_names()))
  a=modern |> dplyr::left_join(corrected,by=c('site','plot_id'),relationship='one-to-one') |>
    dplyr::mutate(join_id=toupper(plot_id)) |>
    dplyr::left_join(plot_coordinates |> dplyr::mutate(join_id=toupper(plot_id)) |>
      dplyr::select(-plot_id),by=c('site','join_id'),relationship='one-to-one') |>
    dplyr::mutate(era='Anthropocene',lake=NA_character_,transition_id=paste(site,plot_id,sep=':'),
      transition_index=0L,time_centuries=0,age_hi=NA_real_,age_lo=NA_real_,interval_mid_cal_bp=NA_real_,
      fire_activity=NA_real_,fire_coverage_valid=NA,n_samples_t1=NA_integer_,n_samples_t2=NA_integer_)
  h=h |> dplyr::left_join(lake_coordinates,by=c('site','lake'),relationship='many-to-one') |>
    dplyr::mutate(era='Holocene',plot_id=NA_character_,burned=NA,
      time_centuries=-interval_mid_cal_bp/100,vegetation_t1_year=NA_real_,vegetation_t2_year=NA_real_,
      climate_t1_midyear=NA_real_,climate_t2_midyear=NA_real_)
  out=dplyr::bind_rows(h,a) |>
    tidyr::pivot_longer(dplyr::all_of(century_response_names()),names_to='metric',values_to='estimate') |>
    dplyr::mutate(response_valid=is.finite(estimate),
      series=ifelse(era=='Holocene',paste('H',site,lake,sep='_'),paste('A',site,plot_id,sep='_')),
      time_index=transition_index,climate_rate=standardized_climate_change_rate) |>
    dplyr::select(era,site,lake,plot_id,transition_id,transition_index,age_hi,age_lo,interval_mid_cal_bp,
      vegetation_t1_year,vegetation_t2_year,climate_t1_midyear,climate_t2_midyear,
      vegetation_dt_years,climate_dt_years,metric,estimate,response_valid,
      standardized_climate_change_rate,fire_activity,fire_coverage_valid,burned,
      n_samples_t1,n_samples_t2,longitude,latitude,series,time_index,time_centuries,climate_rate)
  validate_tracking_model_data(out);out
}
validate_tracking_model_data=function(x) {
  h=x[x$era=='Holocene',];a=x[x$era=='Anthropocene',]
  stopifnot(!'offset' %in% names(x),!anyDuplicated(x[c('era','transition_id','metric')]),
    nrow(dplyr::distinct(a,site,plot_id))==607L,
    all(h$vegetation_dt_years==h$age_hi-h$age_lo),all(h$climate_dt_years==h$vegetation_dt_years),
    identical(x$response_valid,is.finite(x$estimate)),all(is.na(h$fire_activity[!h$fire_coverage_valid])),
    all(is.finite(x$longitude)),all(is.finite(x$latitude)))
  invisible(TRUE)
}
tracking_primary_model_input=function(combined,metric) {
  x=if(metric=='standardized_climate_change_rate') {
    combined[combined$metric=='lag_rate_per_century',] |> dplyr::mutate(metric=.env$metric,
      estimate=standardized_climate_change_rate,response_valid=is.finite(standardized_climate_change_rate))
  } else combined[combined$metric==metric,]
  excluded=x[!is.finite(x$estimate),];excluded$exclusion=rep('undefined_response',nrow(excluded))
  x=x[is.finite(x$estimate),]
  x$era=factor(x$era,levels=c('Holocene','Anthropocene'))
  x$site=factor(x$site,levels=c('MORA','NOCA'))
  x$era_site=interaction(x$era,x$site,drop=TRUE)
  x=x[order(x$series,x$time_index),]
  list(data=x,excluded=excluded)
}
