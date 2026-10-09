# Assembly and selection only: the response calculations remain in stage 09.
tracking_model_data_columns = function() c(
  'era','site','lake','plot_id','offset','age_hi','age_lo','interval_mid_cal_bp',
  'vegetation_t1_year','vegetation_t2_year','climate_t1_midyear','climate_t2_midyear',
  'vegetation_dt_years','climate_dt_years','metric','estimate','response_valid',
  'standardized_climate_change_rate','fire_activity','fire_coverage_valid','high_fire','burned',
  'n_draws_present','n_draws_nmin2','n_samples_t1_median','n_samples_t2_median',
  'longitude','latitude')

combine_tracking_model_data = function(by_offset,modern,lake_coordinates,plot_coordinates) {
  if(!identical(names(by_offset),holocene_model_columns()) ||
     !identical(names(modern),anthropocene_model_columns()))
    stop('Unexpected canonical tracking input schema')
  if(anyDuplicated(by_offset[tracking_transition_keys()]) ||
     anyDuplicated(modern[c('site','plot_id')]) ||
     anyDuplicated(lake_coordinates[c('site','lake')]))
    stop('Duplicate transition, plot or lake-coordinate identity')
  # Normalize only the join key; preserve the original exported plot spelling.
  locations=plot_coordinates |> mutate(coordinate_plot_key=toupper(plot_id)) |>
    select(site,coordinate_plot_key,longitude,latitude)
  if(anyDuplicated(locations[c('site','coordinate_plot_key')]) ||
     anyDuplicated(paste(modern$site,toupper(modern$plot_id))))
    stop('Ambiguous normalized coordinate/plot identity')
  h=by_offset |> left_join(lake_coordinates,by=c('site','lake'),relationship='many-to-one') |>
    mutate(era='Holocene',plot_id=NA_character_,vegetation_t1_year=NA_real_,
      vegetation_t2_year=NA_real_,climate_t1_midyear=NA_real_,climate_t2_midyear=NA_real_,
      burned=NA)
  a=modern |> mutate(coordinate_plot_key=toupper(plot_id)) |>
    left_join(locations,by=c('site','coordinate_plot_key'),relationship='one-to-one') |>
    mutate(era='Anthropocene',lake=NA_character_,offset=NA_real_,age_hi=NA_real_,
      age_lo=NA_real_,interval_mid_cal_bp=NA_real_,fire_activity=NA_real_,
      fire_coverage_valid=NA,high_fire=NA,n_draws_present=NA_integer_,
      n_draws_nmin2=NA_integer_,n_samples_t1_median=NA_real_,n_samples_t2_median=NA_real_)
  combined=bind_rows(h,a) |>
    pivot_longer(all_of(tracking_response_names()),names_to='metric',values_to='estimate') |>
    mutate(response_valid=is.finite(estimate)) |>
    select(all_of(tracking_model_data_columns())) |>
    arrange(match(era,c('Holocene','Anthropocene')),site,lake,offset,desc(age_hi),
      plot_id,match(metric,tracking_response_names()))
  validate_tracking_model_data(combined)
  if(nrow(combined)!=(nrow(by_offset)+nrow(modern))*length(tracking_response_names()))
    stop('Assembly lost or duplicated source observations')
  combined
}

validate_tracking_model_data = function(x) {
  if(!identical(names(x),tracking_model_data_columns()) ||
     anyNA(x$era) || any(!x$era %in% c('Holocene','Anthropocene')) ||
     anyNA(x$site) || any(!x$site %in% c('MORA','NOCA')) ||
     !setequal(x$metric,tracking_response_names()) ||
     !identical(x$response_valid,is.finite(x$estimate)))
    stop('Invalid combined model schema, categories or response validity')
  h=x[x$era=='Holocene',]; a=x[x$era=='Anthropocene',]
  hkeys=c(tracking_transition_keys(),'metric')
  if(!nrow(h) || !nrow(a) || anyDuplicated(h[hkeys]) ||
     anyDuplicated(a[c('site','plot_id','metric')]) ||
     anyNA(h$offset) || anyNA(h$lake) || anyNA(a$plot_id) ||
     nrow(h)!=nrow(unique(h[tracking_transition_keys()]))*length(tracking_response_names()) ||
     nrow(a)!=nrow(unique(a[c('site','plot_id')]))*length(tracking_response_names()))
    stop('Missing or duplicate era-specific observation identities')
  w=unique(h$climate_dt_years)
  if(length(w)!=1L) stop('Combined input must contain one Holocene interval width')
  w=validate_tracking_width(w)
  if(!setequal(h$offset,seq(0,w-100,100)) ||
     any(!is.finite(h$age_hi)) || any(!is.finite(h$age_lo)) ||
     any(h$age_hi-h$age_lo!=w) || any(h$vegetation_dt_years!=w) ||
     any(h$interval_mid_cal_bp!=(h$age_hi+h$age_lo)/2) ||
     any(!is.finite(x$vegetation_dt_years) | x$vegetation_dt_years<=0) ||
     any(!is.finite(x$climate_dt_years) | x$climate_dt_years<=0))
    stop('Invalid offset configuration, transition endpoints or elapsed times')
  if(any(!is.finite(x$longitude) | abs(x$longitude)>180) ||
     any(!is.finite(x$latitude) | abs(x$latitude)>90))
    stop('Missing or invalid WGS84 coordinates')
  if(any(!is.na(h$plot_id)) || any(!is.na(h$burned)) ||
     any(!is.na(as.matrix(h[c('vegetation_t1_year','vegetation_t2_year',
       'climate_t1_midyear','climate_t2_midyear')])) ) ||
     any(!is.na(as.matrix(a[c('lake','offset','age_hi','age_lo','interval_mid_cal_bp',
       'fire_activity','fire_coverage_valid','high_fire','n_draws_present','n_draws_nmin2',
       'n_samples_t1_median','n_samples_t2_median')]))))
    stop('Inapplicable era-specific fields must be NA')
  if(any(!is.finite(as.matrix(a[c('vegetation_t1_year','vegetation_t2_year',
       'climate_t1_midyear','climate_t2_midyear')]))) || anyNA(a$burned) ||
     any(a$vegetation_dt_years!=a$vegetation_t2_year-a$vegetation_t1_year) ||
     any(a$climate_dt_years!=a$climate_t2_midyear-a$climate_t1_midyear) ||
     anyNA(h$fire_coverage_valid) ||
     any(!h$fire_coverage_valid & (!is.na(h$fire_activity) | !is.na(h$high_fire))) ||
     any(!is.finite(h$n_draws_present) | h$n_draws_present<1 | h$n_draws_present>100) ||
     any(!is.finite(h$n_draws_nmin2) | h$n_draws_nmin2<0 | h$n_draws_nmin2>h$n_draws_present))
    stop('Invalid survey dates, fire missingness or chronology support')
  invisible(w)
}

# Modern pairs occur once in the CSV and are reused in each offset sensitivity.
# Filtering concerns only the selected response; preserve actual gaps in time.
tracking_offset_model_input = function(combined,metric,offset) {
  w=validate_tracking_model_data(combined)
  if(!metric %in% tracking_response_names() || !offset %in% seq(0,w-100,100))
    stop('Unknown response or configured offset')
  selected=combined |> filter(.data$metric==.env$metric,
    era=='Anthropocene' | .data$offset==.env$offset)
  d=selected |> filter(response_valid)
  d$era=factor(d$era,levels=c('Holocene','Anthropocene'))
  d$site=factor(d$site,levels=c('MORA','NOCA'))
  if(any(table(d$era,d$site)<2L)) stop('Each era/site group needs two finite responses')
  h=d$era=='Holocene'
  coordinate=(d$interval_mid_cal_bp-offset)/w
  if(any(abs(coordinate[h]-round(coordinate[h]))>1e-8))
    stop('Transition midpoint does not map to an integer time step')
  d$era_site=interaction(d$era,d$site,drop=TRUE)
  d$series=ifelse(h,paste('H',d$site,d$lake,sep='_'),paste('A',d$site,d$plot_id,sep='_'))
  d$time_index=ifelse(h,as.integer(round(coordinate)),0L)
  if(anyDuplicated(d[c('series','time_index')]) || any(table(d$series[!h])!=1L))
    stop('Duplicate series/time point or repeated modern pair within one fit')
  d=d[order(d$series,d$time_index),,drop=FALSE]
  list(data=as.data.frame(d),excluded=selected |> filter(!response_valid),step_years=w)
}

# A lake sensitivity compares one Holocene series with its own park's modern
# pairs. Keep the existing time indices and response-specific exclusions.
tracking_lake_model_input = function(combined,metric,lake,offset=0) {
  selected=tracking_offset_model_input(combined,metric,offset)
  d=selected$data
  park=unique(d$site[d$era=='Holocene' & !is.na(d$lake) & d$lake==lake])
  if(length(park)!=1L) stop('Unknown lake or absent finite lake response: ',lake)
  keep=function(x) x$site==park &
    (x$era=='Anthropocene' | (!is.na(x$lake) & x$lake==lake))
  d=droplevels(d[keep(d),,drop=FALSE])
  if(any(table(d$era)<2L)) stop('Each lake/modern comparison needs two finite responses per era')
  list(data=d,excluded=selected$excluded[keep(selected$excluded),,drop=FALSE],
    step_years=selected$step_years,site=as.character(park),lake=lake)
}
