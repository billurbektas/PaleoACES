# Pure assembly helpers. All tracking geometry lives in tracking_metrics.R.
validate_tracking_width = function(bin_width_years) {
  if (length(bin_width_years)!=1L || !is.finite(bin_width_years) ||
      bin_width_years<=0 || bin_width_years %% 100 != 0)
    stop('bin_width_years must be a positive multiple of 100')
  as.integer(bin_width_years)
}

# Counts and denominator use the same fully covered windows and [lower,upper)
# convention. The reference covers the entire available core, not the subset
# selected by a vegetation lake or a chronology draw.
transition_fire = function(intervals, events, continuous, bin_width_years,
                           core_reference=NULL, high_fire=NULL) {
  w = validate_tracking_width(bin_width_years)
  keys = c('site','offset','age_hi','age_lo')
  intervals = intervals |> distinct(across(all_of(keys)))
  if (any(intervals$age_hi-intervals$age_lo != w)) stop('Fire/transition width mismatch')
  computed = calculate_fire_frequency(events, continuous, w, 100L)
  if (!is.null(core_reference)) {
    a = computed$core |> arrange(site,lake,cal_bp)
    b = core_reference |> arrange(site,lake,cal_bp)
    fields = c('site','lake','cal_bp','window_years','accepted_event_count',
      'core_max_frequency','normalized_frequency')
    if (!isTRUE(all.equal(as.data.frame(a[fields]),as.data.frame(b[fields]),
                         tolerance=1e-12,check.attributes=FALSE)))
      stop('Existing fire normalization differs from comparable full windows')
  }
  core_ids = c('Sunrise Lake'='sunrise','Shadow Lake'='shadow',
    'Little Sunrise Lake'='little_sunrise','PantherPotholes'='panther')
  reference = computed$core |> distinct(site,lake,window_years,core_max_frequency)
  exposure = intervals |>
    left_join(computed$coverage |> rename(fire_core=lake),by='site',relationship='many-to-many') |>
    left_join(reference |> rename(fire_core=lake),by=c('site','fire_core')) |>
    mutate(coverage_fraction=pmax(0,pmin(age_hi,older_cal_bp)-pmax(age_lo,younger_cal_bp))/w,
      fully_covered=coverage_fraction==1, normalization_valid=is.finite(core_max_frequency) & core_max_frequency>0)
  exposure$accepted_event_count = vapply(seq_len(nrow(exposure)),function(i) {
    if (!exposure$fully_covered[i]) return(NA_integer_)
    sum(events$site==exposure$site[i] & events$lake==exposure$fire_core[i] &
      events$age_cal_yr_BP>=exposure$age_lo[i] & events$age_cal_yr_BP<exposure$age_hi[i])
  },integer(1))
  exposure = exposure |> mutate(frequency_per_1000yr=accepted_event_count/w*1000,
    normalized_activity=if_else(fully_covered & normalization_valid,
      frequency_per_1000yr/core_max_frequency,NA_real_),
    core_id=unname(core_ids[fire_core]))
  regional = exposure |> group_by(across(all_of(keys))) |> summarize(
    fire_covered_cores=sum(fully_covered),
    fire_normalized_cores=sum(is.finite(normalized_activity)),
    fire_required_cores=if_else(first(site)=='MORA',2L,1L),
    fire_coverage_valid=fire_covered_cores>=fire_required_cores,
    fire_normalization_valid=fire_normalized_cores>=fire_required_cores,
    fire_activity=if (fire_coverage_valid && fire_normalization_valid)
      mean(normalized_activity[is.finite(normalized_activity)]) else NA_real_,
    fire_source_ids=paste(sort(fire_core),collapse=';'),
    fire_covered_source_ids=paste(sort(fire_core[fully_covered]),collapse=';'),
    .groups='drop') |> mutate(fire_window_years=w,
      fire_reference_window_years=w, fire_history_id=if_else(site=='MORA',
        'MORA_regional_Sunrise_Shadow_LittleSunrise','NOCA_PantherPotholes'),
      fire_shared_regional_history=site=='MORA', high_fire_window_years=1000L,
      interval_mid_cal_bp=(age_hi+age_lo)/2)
  core = exposure |> select(all_of(keys),core_id,fire_core,younger_cal_bp,older_cal_bp,
    coverage_fraction,fully_covered,normalization_valid,accepted_event_count,
    frequency_per_1000yr,core_max_frequency,normalized_activity) |>
    pivot_wider(names_from=core_id,values_from=c(fire_core,younger_cal_bp,older_cal_bp,
      coverage_fraction,fully_covered,normalization_valid,accepted_event_count,
      frequency_per_1000yr,core_max_frequency,normalized_activity),names_glue='fire_{core_id}_{.value}')
  regional = left_join(regional,core,by=keys)
  if (!is.null(high_fire)) regional = regional |>
    left_join(high_fire |> select(site,interval_mid_cal_bp=cal_bp,high_fire),
      by=c('site','interval_mid_cal_bp')) |>
    mutate(high_fire=if_else(fire_coverage_valid,high_fire,NA))
  regional
}

build_lake_tracking = function(reference, draws, env_slice, bin_width_years=1000L) {
  w = validate_tracking_width(bin_width_years)
  offsets = seq(0,w-100,100)
  obs = reference$comparison |> filter(era=='holocene') |>
    select(plot_id,site,o1=projected_CCA1,o2=projected_CCA2)
  samples = draws |> inner_join(obs,by='plot_id',relationship='many-to-one')
  runs = make_runs(draws=samples,bin_width=w,offsets=offsets)
  obs_bins = runs |> group_by(site,lake,draw,offset,bin_mid) |>
    summarize(o1=mean(o1),o2=mean(o2),n_samples=n(),.groups='drop')
  climates = expand_grid(offset=offsets,env_slice) |>
    mutate(bin_mid=floor((age-offset)/w)*w+offset+w/2) |>
    group_by(site,lake,offset,bin_mid) |>
    summarize(across(all_of(CCA_CLIMATE_VARS),mean),n_climate_slices=n(),.groups='drop') |>
    filter(n_climate_slices==w/100)
  if (!nrow(climates)) stop('No complete climate bins support this interval width')
  lc = predict(reference$model,newdata=as.data.frame(climates[CCA_CLIMATE_VARS]),
    type='lc',scaling=reference$scaling,hill=reference$hill)
  climates = climates |> mutate(p1=lc[,1],p2=lc[,2])
  # Form observed adjacent pairs first, so excluded edge pairs are auditable.
  raw = obs_bins |> arrange(site,lake,draw,offset,desc(bin_mid)) |>
    group_by(site,lake,draw,offset) |>
    mutate(across(c(o1,o2,n_samples,bin_mid),~lead(.x),.names='{.col}_2')) |>
    ungroup() |> filter(bin_mid-bin_mid_2==w) |>
    rename(age_hi=bin_mid,age_lo=bin_mid_2)
  joined = raw |>
    left_join(climates |> rename(age_hi=bin_mid),by=c('site','lake','offset','age_hi')) |>
    left_join(climates |> rename(age_lo=bin_mid) |>
      rename_with(~paste0(.x,'_2'),-all_of(c('site','lake','offset','age_lo'))),
      by=c('site','lake','offset','age_lo')) |>
    mutate(climate_complete=!is.na(n_climate_slices) & !is.na(n_climate_slices_2))
  realizations = joined |> filter(climate_complete) |>
    mutate(run_id=paste0('d',draw,'_o',offset),bin_width_years=w,
      vegetation_dt_years=w,climate_dt_years=w,n_min=pmin(n_samples,n_samples_2),
      sparse_bin=n_min<2L) |>
    calculate_tracking_metrics() |> add_climate_change_metrics(reference$climate_scaling)
  list(realizations=realizations,raw=joined,samples=samples,climates=climates)
}

# One ordered response contract for model inputs, uncertainty and reporting.
tracking_response_names = function() c(
  'lag_rate_per_century','observed_turnover_rate','magnitude_tracking_ratio',
  'rate_tracking_ratio','angle_degrees','pace_effect_on_lag_per_century',
  'direction_effect_on_lag_per_century')
tracking_transition_keys = function() c('site','lake','offset','age_hi','age_lo')
holocene_model_columns = function() c(tracking_transition_keys(),'interval_mid_cal_bp',
  'vegetation_dt_years','climate_dt_years','standardized_climate_change_rate',
  'fire_activity','fire_coverage_valid','high_fire',tracking_response_names(),
  'n_draws_present','n_draws_nmin2','n_samples_t1_median','n_samples_t2_median')
anthropocene_model_columns = function() c('site','plot_id',
  'vegetation_t1_year','vegetation_t2_year','climate_t1_midyear','climate_t2_midyear',
  'vegetation_dt_years','climate_dt_years','standardized_climate_change_rate','burned',
  tracking_response_names(),'angle_valid','pace_counterfactual_valid',
  'direction_counterfactual_valid','tracking_ratio_valid')
uncertainty_columns = function() c(tracking_transition_keys(),'metric','sampling_rule',
  'median','q025','q975','n_expected_draws','n_present_draws','n_eligible_draws',
  'n_valid_draws','n_undefined_draws')

# Presence is counted before response validity. No draw is fabricated or dropped
# when a response is undefined; empty sensitivity groups retain their counts.
lake_uncertainty = function(x,n_draws=100L) {
  keys = tracking_transition_keys()
  if (anyDuplicated(x[c(keys,'draw')])) stop('Duplicate transition/draw key')
  presence = x |> group_by(across(all_of(keys))) |>
    summarize(n_present_draws=n_distinct(draw),.groups='drop')
  values = x |> select(all_of(c(keys,'draw','n_min',tracking_response_names()))) |>
    pivot_longer(all_of(tracking_response_names()),names_to='metric',values_to='value')
  bind_rows(mutate(values,sampling_rule='all',eligible=TRUE),
    mutate(values,sampling_rule='nmin2',eligible=n_min>=2)) |>
    group_by(across(all_of(c(keys,'metric','sampling_rule')))) |> summarize(
      median=safe_stat(value[eligible],median),
      q025=safe_stat(value[eligible],quantile,probs=.025,names=FALSE),
      q975=safe_stat(value[eligible],quantile,probs=.975,names=FALSE),
      n_eligible_draws=sum(eligible),n_valid_draws=sum(eligible & is.finite(value)),
      .groups='drop') |> left_join(presence,by=keys) |>
    mutate(n_expected_draws=n_draws,n_undefined_draws=n_eligible_draws-n_valid_draws) |>
    select(all_of(uncertainty_columns())) |> arrange(site,lake,offset,desc(age_hi),
      match(metric,tracking_response_names()),sampling_rule)
}

lake_offset_summary = function(x,uncertainty) {
  keys = tracking_transition_keys()
  fixed = x |> distinct(across(all_of(c(keys,'interval_mid_cal_bp',
    'vegetation_dt_years','climate_dt_years','standardized_climate_change_rate',
    'fire_activity','fire_coverage_valid','high_fire'))))
  if (anyDuplicated(fixed[keys])) stop('Predictors vary across draws for a fixed interval')
  support = x |> group_by(across(all_of(keys))) |> summarize(
    n_draws_present=n_distinct(draw),n_draws_nmin2=sum(n_min>=2),
    n_samples_t1_median=median(n_samples),n_samples_t2_median=median(n_samples_2),.groups='drop')
  responses = uncertainty |> filter(sampling_rule=='all') |>
    select(all_of(keys),metric,median) |> pivot_wider(names_from=metric,values_from=median)
  fixed |> left_join(responses,by=keys) |> left_join(support,by=keys) |>
    select(all_of(holocene_model_columns())) |> arrange(site,lake,offset,desc(age_hi))
}

# Reporting eligibility is assessed independently for each response, requiring
# one finite offset median from every configured placement. Shared endpoints
# and reporting dates do not turn offsets into independent observations.
lake_reporting_grid = function(uncertainty,bin_width_years=1000L) {
  offsets = seq(0,validate_tracking_width(bin_width_years)-100,100)
  cells = uncertainty |> filter(sampling_rule=='all') |>
    mutate(t=purrr::map2(age_lo,age_hi,
      ~seq(ceiling(.x/100)*100,ceiling(.y/100)*100-100,100))) |> unnest(t)
  if (any(!cells$offset %in% offsets)) stop('Unconfigured reporting offset')
  if (anyDuplicated(cells[c('site','lake','offset','t','metric')]))
    stop('Overlapping transitions within an offset')
  cells |> group_by(site,lake,t,metric) |> summarize(
    estimate=safe_stat(median,stats::median),age_q025=safe_stat(q025,stats::median),
    age_q975=safe_stat(q975,stats::median),phase_min=safe_stat(median,min),
    phase_max=safe_stat(median,max),n_offsets=n_distinct(offset),
    n_valid_offsets=sum(is.finite(median)),min_present_draws=min(n_present_draws),.groups='drop') |>
    filter(n_offsets==length(offsets),n_valid_offsets==length(offsets)) |>
    mutate(unit=metric_unit(metric),bin_width_years=bin_width_years,reporting_only=TRUE) |>
    arrange(match(metric,tracking_response_names()),site,lake,t)
}

# Attach fixed predictors using exactly the response's temporally aligned
# offsets. Preserve the reporting eligibility rule and unavailable fire values.
lake_reporting_context = function(by_offset,reporting,bin_width_years=1000L) {
  w = validate_tracking_width(bin_width_years)
  offsets = seq(0,w-100,100)
  keys = c('site','lake','t','metric')
  if(anyDuplicated(by_offset[tracking_transition_keys()]) ||
     anyDuplicated(reporting[keys]) || any(!by_offset$offset %in% offsets) ||
     any(by_offset$age_hi-by_offset$age_lo!=w))
    stop('Invalid transition keys or interval configuration for reporting predictors')
  cells = by_offset |> select(all_of(tracking_transition_keys()),
    offset_climate_rate=standardized_climate_change_rate,
    offset_fire_activity=fire_activity,fire_coverage_valid,
    all_of(tracking_response_names())) |>
    pivot_longer(all_of(tracking_response_names()),names_to='metric',values_to='response') |>
    mutate(t=purrr::map2(age_lo,age_hi,
      ~seq(ceiling(.x/100)*100,ceiling(.y/100)*100-100,100))) |> unnest(t) |>
    inner_join(reporting |> select(all_of(keys)),by=keys,relationship='many-to-one') |>
    filter(is.finite(response))
  if(anyDuplicated(cells[c(keys,'offset')]))
    stop('Overlapping transitions within an aligned response/offset')
  strict_median = function(x) if(length(x) && all(is.finite(x))) median(x) else NA_real_
  context = cells |> group_by(across(all_of(keys))) |> summarize(
    aligned_estimate=median(response),aligned_offsets=n_distinct(offset),
    climate_rate=strict_median(offset_climate_rate),
    fire_activity=if(all(fire_coverage_valid %in% TRUE)) strict_median(offset_fire_activity) else NA_real_,
    .groups='drop')
  joined = reporting |> left_join(context,by=keys,relationship='one-to-one')
  if(anyNA(joined$aligned_offsets) ||
     any(joined$aligned_offsets!=joined$n_valid_offsets) ||
     any(joined$aligned_offsets!=length(offsets)) ||
     !isTRUE(all.equal(joined$estimate,joined$aligned_estimate,
       tolerance=1e-12,check.attributes=FALSE)))
    stop('Reporting responses and aligned predictor offsets disagree')
  joined |> select(-aligned_estimate,-aligned_offsets)
}

# Regression expectations diagnose changes; they never shape the observations.
check_tracking_keys = function(actual,expected,keys,label) {
  added = anti_join(actual |> select(all_of(keys)),expected,by=keys)
  removed = anti_join(expected,actual,by=keys)
  if (nrow(actual)!=nrow(expected) || nrow(added) || nrow(removed)) {
    detail = paste(capture.output(print(bind_rows(mutate(added,status='added'),
      mutate(removed,status='removed')),n=20)),collapse='\n')
    stop(label,': expected ',nrow(expected),' rows; calculated ',nrow(actual),
      '. Changed keys (first 20):\n',detail,
      '\nReview input changes, chronology support and incomplete-climate exclusions; no exports replaced.')
  }
}
validate_tracking_products = function(model,uncertainty,anthropocene=NULL,bin_width_years=1000L) {
  keys = tracking_transition_keys()
  if (bin_width_years==1000L) {
    check_tracking_keys(model,read_csv(here('R/tests/fixtures/cca_tracking_holocene_transition_keys.csv'),
      show_col_types=FALSE),keys,'Primary Holocene transition regression')
    if (!is.null(anthropocene)) check_tracking_keys(anthropocene,
      read_csv(here('R/tests/fixtures/cca_tracking_anthropocene_pair_keys.csv'),show_col_types=FALSE),
      c('site','plot_id'),'Anthropocene pair regression')
  }
  expected_uncertainty = tidyr::crossing(model |> select(all_of(keys)),
    metric=tracking_response_names(),sampling_rule=c('all','nmin2'))
  check_tracking_keys(uncertainty,expected_uncertainty,c(keys,'metric','sampling_rule'),
    'Holocene response/sampling distribution regression')
  stopifnot(identical(names(model),holocene_model_columns()),
    identical(names(uncertainty),uncertainty_columns()),
    !anyDuplicated(model[keys]),!anyDuplicated(uncertainty[c(keys,'metric','sampling_rule')]),
    all(model$age_hi-model$age_lo==bin_width_years),
    all(model$vegetation_dt_years==bin_width_years),all(model$climate_dt_years==bin_width_years),
    all(model$n_draws_nmin2>=0),all(model$n_draws_nmin2<=model$n_draws_present),
    all(model$n_draws_present>0),all(model$n_draws_present<=100L),
    all(uncertainty$n_expected_draws==100L),all(uncertainty$n_valid_draws>=0),
    all(uncertainty$n_valid_draws+uncertainty$n_undefined_draws==uncertainty$n_eligible_draws),
    all(uncertainty$n_valid_draws<=uncertainty$n_eligible_draws),
    all(uncertainty$n_eligible_draws<=uncertainty$n_present_draws),
    all(uncertainty$n_present_draws<=uncertainty$n_expected_draws),
    nrow(uncertainty)==nrow(model)*length(tracking_response_names())*2L,
    setequal(uncertainty$metric,tracking_response_names()),
    setequal(uncertainty$sampling_rule,c('all','nmin2')))
  support = uncertainty |> left_join(model |> select(all_of(keys),n_draws_present,n_draws_nmin2),
    by=keys,relationship='many-to-one')
  stopifnot(!anyNA(support$n_draws_present),
    all(support$n_present_draws==support$n_draws_present),
    all(support$n_eligible_draws==if_else(support$sampling_rule=='all',
      support$n_draws_present,support$n_draws_nmin2)),
    all(is.na(support$median[support$n_valid_draws==0])),
    all(is.na(support$q025[support$n_valid_draws==0])),
    all(is.na(support$q975[support$n_valid_draws==0])))
  missing_fire = is.na(model$fire_coverage_valid) | !model$fire_coverage_valid
  stopifnot(all(is.na(model$fire_activity[missing_fire])),all(is.na(model$high_fire[missing_fire])))
  if (!is.null(anthropocene)) stopifnot(identical(names(anthropocene),anthropocene_model_columns()),
    !anyDuplicated(anthropocene[c('site','plot_id')]),!anyNA(anthropocene$burned))
  invisible(TRUE)
}

# Machine-readable dictionary for compact contracts and detailed audit records.
tracking_schema = function(tables) purrr::imap_dfr(tables,function(tbl,dataset) {
  purrr::map_dfr(names(tbl),function(column) {
    u = metric_unit(column); description = gsub('_',' ',column)
    if(column %in% c('o1','o2','o1_2','o2_2','p1','p2','p1_2','p2_2') ||
       grepl('^(pace|direction)_corrected_CCA',column) || grepl('^delta_(observed|predicted)_CCA',column)) u='CCA_units'
    if(column %in% c(CCA_CLIMATE_VARS,paste0(CCA_CLIMATE_VARS,'_2'))) u=unname(CLIMATE_VARIABLE_UNITS[sub('_2$','',column)])
    if(grepl('^n_|draws|samples|cores|event_count',column)) u='count'
    if(grepl('core_max_frequency|frequency_per_1000yr',column)) u='events_per_1000yr'
    if(grepl('coverage_fraction|normalized_activity|^fire_activity$',column)) u='unitless'
    if(column %in% c('longitude','latitude')) u='decimal_degrees_WGS84'
    if(column %in% c('age_hi','age_lo','t','interval_mid_cal_bp','youngest_endpoint','oldest_endpoint') || grepl('cal_bp$',column)) u='cal_years_BP'
    if(column %in% c('offset','bin_width_years','vegetation_dt_years','climate_dt_years','climate_n_years') || grepl('window_years$',column)) u='years'
    if(grepl('^(vegetation_t[12]_year|climate_[t12]+_midyear|climate_start|climate_end)$',column)) u='calendar_year'
    if(is.logical(tbl[[column]])) u='boolean'
    if(is.character(tbl[[column]])) u='identifier_or_category'
    if(grepl('_uncertainty$',dataset) && column %in% c('median','q025','q975')) {
      u='metric_dependent'; description=paste(column,'across finite eligible draws; units follow metric')
    }
    if(column=='estimate' && 'metric' %in% names(tbl)) {
      u='metric_dependent'; description='Response value; units follow metric'
    }
    definitions = c(n_draws_present='Distinct chronology draws containing the transition before response-validity filtering',
      n_draws_nmin2='Present chronology draws with at least two samples in both endpoint bins',
      n_present_draws='Distinct chronology draws containing the transition, independent of metric validity',
      n_eligible_draws='Present draws satisfying the sampling rule',
      n_valid_draws='Eligible draws with a finite metric value',
      n_undefined_draws='Eligible draws minus finite metric draws',
      n_expected_draws='Configured whole chronology draws: 100',
      sampling_rule='all or nmin2; nmin2 requires at least two samples in each endpoint bin',
      fire_activity='Equal-core normalized frequency; MORA vegetation lakes share the regional history',
      high_fire='Descriptive site classification at the transition midpoint using the original 1000-year window; NA for inadequate coverage',
      longitude='WGS84 longitude in decimal degrees, from the lake climate location or cleaned plot location',
      latitude='WGS84 latitude in decimal degrees, from the lake climate location or cleaned plot location',
      n_valid_offsets='Number of finite aligned offset response medians')
    if(column %in% names(definitions)) description=unname(definitions[column])
    if(dataset=='cca_tracking_era_by_offset') {
      model_definitions=c(era='Holocene or Anthropocene',
        lake='Holocene vegetation lake; NA for Anthropocene',
        plot_id='Original Anthropocene paired-plot identifier; NA for Holocene',
        offset='Actual Holocene bin placement in years; NA for modern pairs stored once per response',
        estimate='Median across finite chronology draws within one Holocene transition/offset, or original modern plot response; no aggregation across offsets',
        response_valid='TRUE exactly when this row has a finite response estimate',
        burned='Original modern binary fire assignment; NA for Holocene',
        fire_activity='Original transition-specific normalized activity; NA for insufficient coverage or Anthropocene')
      if(column %in% names(model_definitions)) description=unname(model_definitions[column])
    }
    if(is.na(u)) u='count_or_dimensionless'
    tibble(dataset=dataset,column=column,type=class(tbl[[column]])[1],unit=u,definition=description)
  })
})
