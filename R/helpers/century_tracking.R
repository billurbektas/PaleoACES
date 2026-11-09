# One reconstruction implementation for primary median ages and whole Bacon draws.
# Definitions only; metric geometry remains in tracking_metrics.R.
if(!requireNamespace("vegan",quietly=TRUE)) stop("vegan is required")
source(here::here('R/helpers/config.R'), local=TRUE)
source(here::here('R/helpers/holocene_reconstruction_settings.R'), local=TRUE)
source(here::here('R/helpers/holocene_reconstruction.R'), local=TRUE)
source(here::here('R/helpers/tracking_metrics.R'), local=TRUE)

century_response_names = function() c('lag_rate_per_century','observed_turnover_rate',
  'magnitude_tracking_ratio','rate_tracking_ratio','angle_degrees',
  'pace_effect_on_lag_per_century','direction_effect_on_lag_per_century',
  'pace_corrected_lag_rate_per_century','direction_corrected_lag_rate_per_century')

century_posterior_cache = new.env(parent=emptyenv())

century_posterior_ages = function(cache, core, depths, posterior_rows=NULL) {
  meta=cache$depth_evaluation[cache$depth_evaluation$lake==core,]
  path=unique(cache$posterior_rows$source[cache$posterior_rows$lake==core])
  if(!exists(path,envir=century_posterior_cache,inherits=FALSE))
    assign(path,as.matrix(read.table(here::here(path))),envir=century_posterior_cache)
  raw=get(path,envir=century_posterior_cache,inherits=FALSE)
  raw=raw[if(is.null(posterior_rows)) seq_len(nrow(raw)) else posterior_rows,
    -ncol(raw),drop=FALSE]
  source(here::here('R/helpers/bacon_settings.R'),local=TRUE)
  adjusted=depths
  slump=CORE_ARGS[[core]]$slump
  if(length(slump)) for(i in seq(1,length(slump),by=2))
    adjusted=adjusted-pmin(pmax(depths-slump[i],0),slump[i+1]-slump[i])
  thick=unique(meta$thickness_cm)
  origin=unique(meta$section_start_cm-(meta$section_index-1)*thick)
  if(length(thick)!=1L || length(origin)!=1L) stop('Ambiguous Bacon section geometry')
  section=floor((adjusted-origin)/thick)+1L
  if(any(section<1L | section+1L>ncol(raw))) stop('Depth outside stored chronology')
  vapply(seq_along(depths),function(i) {
    k=section[i]
    prior=if(k==1L) rep(0,nrow(raw)) else rowSums(raw[,2:k,drop=FALSE])
    raw[,1]+thick*prior+(adjusted[i]-(origin+(k-1)*thick))*raw[,k+1]
  },numeric(nrow(raw)))
}

century_prepare = function() {
  dir.create(out('chronology_reconstruction'),recursive=TRUE,showWarnings=FALSE)
  dependencies=c(here::here(c('R/helpers/century_tracking.R','R/helpers/holocene_reconstruction.R',
    'R/helpers/holocene_reconstruction_settings.R','R/helpers/bacon_settings.R',
    'data/PALEO/DunwiddieMacrofossils.xlsx','data/NOCA/NOCA_paleo/dataset52207_site13042.csv')),
    out(c('cca_calibration_reference.rds','chelsa_paleo_ponds.csv',
    'holocene_fire_source_events.csv','holocene_fire_source_series.csv')))
  signature=object_fingerprint(unname(tools::md5sum(dependencies)))
  prepared_path=out('chronology_reconstruction/prepared.rds')
  if(file.exists(prepared_path)) {
    saved=readRDS(prepared_path)
    if(identical(saved$signature,signature) && identical(unname(tools::md5sum(names(saved$cache$source_md5))),unname(saved$cache$source_md5))) return(saved)
  }
  reference=readRDS(out('cca_calibration_reference.rds'))
  projected=reconstruction_project_samples(reconstruction_read_original_samples(),reference)
  cache_path=out('age_draws.rds')
  cache=reconstruction_original_age_draws(projected$samples,cache_path,
    HOLOCENE_RECONSTRUCTION_DRAWS,HOLOCENE_RECONSTRUCTION_SEED)
  samples=projected$samples
  samples$median_age_cal_bp=NA_real_
  for(core in unique(samples$lake)) {
    use=which(samples$lake==core)
    samples$median_age_cal_bp[use]=apply(century_posterior_ages(cache,core,samples$depth_cm[use]),2,median)
  }
  ponds=readr::read_csv(out('chelsa_paleo_ponds.csv'),show_col_types=FALSE)
  source(here::here('R/helpers/climate_variables.R'),local=TRUE)
  climate=ponds |> dplyr::transmute(unit=lake,period=site,variable,time=slice,month,
    value=if(PALEO_USE_BIAS_CORRECTED) value_corrected else value_raw) |>
    derive_climate_vars(winter_shift=FALSE) |>
    dplyr::rename(lake=unit,site=period,slice=time) |>
    dplyr::mutate(century_cal_bp=1950-slice*100)
  lc=predict(reference$model,newdata=climate,type='lc',scaling='sites',hill=FALSE)[,1:2,drop=FALSE]
  climate$p1=lc[,1];climate$p2=lc[,2]
  events=readr::read_csv(out('holocene_fire_source_events.csv'),show_col_types=FALSE)
  series=readr::read_csv(out('holocene_fire_source_series.csv'),show_col_types=FALSE)
  coverage=series |> dplyr::group_by(site,lake) |> dplyr::summarise(
    younger_cal_bp=min(age_cal_yr_BP),older_cal_bp=max(age_cal_yr_BP),
    regular=dplyr::n()>1L && all(is.finite(char_interpolated)) &&
      max(abs(diff(sort(age_cal_yr_BP))-median(diff(sort(age_cal_yr_BP)))))<1e-6,.groups='drop')
  if(!all(coverage$regular)) stop('Incomplete accepted-event source coverage')
  noca_path=list.files(here::here('Cores/PantherPotholes'),pattern='_ages[.]txt$',full.names=TRUE)
  if(length(noca_path)!=1L) stop('Ambiguous detector reference age curve')
  noca=read.table(noca_path,header=TRUE)
  names(noca)[1]='depth'
  # Accepted events are on the detector calendar grid. Invert its age-depth
  # reference once, then use fixed inferred depths under every chronology.
  inverse=function(age) {
    if(any(diff(noca$median)<0) || any(age<min(noca$median) | age>max(noca$median)))
      stop('Nonmonotone or out-of-range detector age-depth inversion')
    vapply(age,function(a) {
      exact=which(noca$median==a)
      if(length(exact)>1L) stop('Accepted event lies on an ambiguous reference plateau')
      if(length(exact)) return(noca$depth[exact])
      lo=max(which(noca$median<a));hi=min(which(noca$median>a))
      noca$depth[lo]+(a-noca$median[lo])*(noca$depth[hi]-noca$depth[lo])/(noca$median[hi]-noca$median[lo])
    },numeric(1))
  }
  ev=events$site=='NOCA' & events$lake=='PantherPotholes'
  events$source_event_id=paste(events$site,events$lake,seq_len(nrow(events)),sep=':')
  events$event_depth_cm=NA_real_; events$event_depth_cm[ev]=inverse(events$age_cal_yr_BP[ev])
  cv=coverage$site=='NOCA' & coverage$lake=='PantherPotholes'
  coverage$younger_depth_cm=coverage$older_depth_cm=NA_real_
  coverage$younger_depth_cm[cv]=inverse(coverage$younger_cal_bp[cv])
  coverage$older_depth_cm[cv]=inverse(coverage$older_cal_bp[cv])
  result=list(reference=reference,samples=samples,species_matrix=projected$species_matrix,
    cache=cache,grid=reconstruction_native_grid(ponds),climate=climate,
    events=events,coverage=coverage,max_wa_error=projected$max_wa_error,signature=signature)
  depths=c(events$event_depth_cm[ev],coverage$younger_depth_cm[cv],coverage$older_depth_cm[cv])
  fire_ages=century_posterior_ages(cache,'PantherPotholes',depths)
  rows=cache$posterior_rows$posterior_row[cache$posterior_rows$lake=='PantherPotholes']
  result$noca_fire_primary=apply(fire_ages,2,median)
  result$noca_fire_draws=fire_ages[rows,,drop=FALSE]
  saveRDS(result,prepared_path)
  result
}

century_fire = function(intervals,bundle,draw=NA_integer_) {
  events=bundle$events;coverage=bundle$coverage
  ev=events$site=='NOCA' & events$lake=='PantherPotholes'
  cv=coverage$site=='NOCA' & coverage$lake=='PantherPotholes'
  dates=if(is.na(draw)) bundle$noca_fire_primary else bundle$noca_fire_draws[draw,]
  events$age_cal_yr_BP[ev]=dates[seq_len(sum(ev))]
  coverage$younger_cal_bp[cv]=dates[sum(ev)+1L]
  coverage$older_cal_bp[cv]=dates[sum(ev)+2L]
  core=intervals |> dplyr::distinct(site,age_hi,age_lo) |>
    dplyr::left_join(coverage,by='site',relationship='many-to-many') |>
    dplyr::rename(fire_core=lake) |>
    dplyr::mutate(duration_years=age_hi-age_lo,
      fully_covered=age_lo>=younger_cal_bp & age_hi<=older_cal_bp,
      coverage_fraction=pmax(0,pmin(age_hi,older_cal_bp)-pmax(age_lo,younger_cal_bp))/duration_years,
      accepted_event_count=NA_integer_)
  for(i in seq_len(nrow(core))) if(core$fully_covered[i]) core$accepted_event_count[i]=sum(
    events$site==core$site[i] & events$lake==core$fire_core[i] &
      events$age_cal_yr_BP>=core$age_lo[i] & events$age_cal_yr_BP<core$age_hi[i])
  core$frequency_per_century=core$accepted_event_count*100/core$duration_years
  regional=core |> dplyr::group_by(site,age_hi,age_lo) |> dplyr::summarise(
    fire_covered_cores=sum(fully_covered),fire_required_cores=ifelse(dplyr::first(site)=='MORA',2L,1L),
    fire_coverage_valid=fire_covered_cores>=fire_required_cores,
    fire_activity=if(fire_coverage_valid) mean(frequency_per_century[fully_covered]) else NA_real_,
    fire_source_ids=paste(sort(fire_core[fully_covered]),collapse=';'),.groups='drop')
  list(core=core,regional=regional,events=events)
}

century_reconstruct = function(bundle,draw=NA_integer_) {
  ages=if(is.na(draw)) bundle$samples |> dplyr::transmute(site,lake,sample_id,draw=NA_integer_,
    age_cal_bp=median_age_cal_bp) else bundle$cache$draws[bundle$cache$draws$draw==draw,]
  assigned=reconstruction_century_assignments(ages,bundle$samples,bundle$grid)
  inside=assigned[is.finite(assigned$century_cal_bp),]
  positions=inside |> dplyr::group_by(site,lake,century_cal_bp) |> dplyr::summarise(
    o1=mean(observed_CCA1),o2=mean(observed_CCA2),n_samples=dplyr::n(),.groups='drop') |>
    dplyr::left_join(bundle$climate,by=c('site','lake','century_cal_bp'),relationship='one-to-one') |>
    dplyr::arrange(site,lake,dplyr::desc(century_cal_bp))
  if(any(!is.finite(as.matrix(positions[c('o1','o2','p1','p2',bundle$reference$climate_variables)]))))
    stop('Occupied century lacks native endpoint climate')
  pairs=positions |> dplyr::group_by(site,lake) |>
    dplyr::mutate(transition_index=dplyr::row_number(),age_hi=century_cal_bp,
      age_lo=dplyr::lead(century_cal_bp),o1_2=dplyr::lead(o1),o2_2=dplyr::lead(o2),
      p1_2=dplyr::lead(p1),p2_2=dplyr::lead(p2),n_samples_t1=n_samples,
      n_samples_t2=dplyr::lead(n_samples),
      dplyr::across(dplyr::all_of(bundle$reference$climate_variables),dplyr::lead,.names='{.col}_2')) |>
    dplyr::ungroup() |> dplyr::filter(is.finite(age_lo)) |>
    dplyr::mutate(interval_mid_cal_bp=(age_hi+age_lo)/2,
      vegetation_dt_years=age_hi-age_lo,climate_dt_years=age_hi-age_lo,
      transition_id=paste(lake,age_hi,age_lo,sep=':'),draw=draw) |>
    calculate_tracking_metrics() |> add_climate_change_metrics(bundle$reference$climate_scaling) |>
    add_corrected_lag_rates()
  fire=century_fire(pairs,bundle,draw)
  pairs=pairs |> dplyr::left_join(fire$regional,by=c('site','age_hi','age_lo'),relationship='many-to-one')
  list(positions=positions,calculations=pairs,assignments=assigned,fire=fire)
}

century_holocene_columns = function() c('site','lake','transition_id','transition_index',
  'age_hi','age_lo','interval_mid_cal_bp','vegetation_dt_years','climate_dt_years',
  'standardized_climate_change_rate','fire_activity','fire_coverage_valid',
  century_response_names(),'n_samples_t1','n_samples_t2')

century_schema = function(tables) purrr::imap_dfr(tables,function(x,name) tibble::tibble(
  dataset=name,column=names(x),storage_type=vapply(x,function(v) class(v)[1],character(1)),
  unit=vapply(names(x),function(n) if(grepl('ratio|proportion',n)) 'unitless' else
    if(n=='fire_activity' || n=='frequency_per_century') 'events per century per eligible core' else
    if(n %in% c('standardized_climate_change_rate','climate_rate')) 'standardized climate distance per century' else
    if(grepl('rate|per_century',n)) 'CCA distance per century' else
    if(grepl('cal_bp|age_hi|age_lo',n)) 'cal BP' else if(grepl('_years',n)) 'years' else
    if(n=='angle_degrees') 'degrees' else if(grepl('^(o[12]|p[12])(_2)?$|CCA[12]|^lag_t|displacement',n)) 'CCA distance' else
    if(grepl('^n_|count$|^draw$|transition_index|time_index',n)) 'count / index' else NA_character_,character(1))))
