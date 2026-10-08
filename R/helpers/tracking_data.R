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

# Every metric has its own denominator of configured whole chronology draws.
summarize_draw_metrics = function(x, metrics, n_draws=100L) {
  x |> pivot_longer(all_of(metrics),names_to='metric',values_to='value') |>
    group_by(site,lake,offset,age_hi,age_lo,metric) |> summarize(
      n_valid_draws=sum(is.finite(value)),n_missing_draws=n_draws-n_valid_draws,
      n_undefined_draws=n()-n_valid_draws,
      mean=safe_stat(value,mean),sd=safe_stat(value,sd),median=safe_stat(value,median),
      q025=safe_stat(value,quantile,probs=.025,names=FALSE),
      q25=safe_stat(value,quantile,probs=.25,names=FALSE),
      q75=safe_stat(value,quantile,probs=.75,names=FALSE),
      q975=safe_stat(value,quantile,probs=.975,names=FALSE),.groups='drop') |>
    pivot_wider(names_from=metric,values_from=c(n_valid_draws,n_missing_draws,
      n_undefined_draws,mean,sd,median,q025,q25,q75,q975),names_glue='{metric}_{.value}')
}

lake_offset_summary = function(x,n_draws=100L) {
  keys = c('site','lake','offset','age_hi','age_lo')
  positions = c('o1','o2','o1_2','o2_2','pace_corrected_CCA1','pace_corrected_CCA2',
    'direction_corrected_CCA1','direction_corrected_CCA2')
  metrics = c(tracking_metric_names(),positions)
  fixed = c('bin_width_years','vegetation_dt_years','climate_dt_years','p1','p2','p1_2','p2_2',
    'n_climate_slices','n_climate_slices_2',CCA_CLIMATE_VARS,paste0(CCA_CLIMATE_VARS,'_2'),
    climate_metric_names(),grep('^(fire_|high_fire|interval_mid)',names(x),value=TRUE))
  fixed = x |> distinct(across(all_of(c(keys,fixed))))
  if (anyDuplicated(fixed[keys])) stop('Predictors vary across draws for a fixed interval')
  support = x |> group_by(across(all_of(keys))) |> summarize(
    n_present_draws=n_distinct(draw),n_absent_draws=n_draws-n_present_draws,
    n_samples_t1_min=min(n_samples),n_samples_t1_median=median(n_samples),n_samples_t1_max=max(n_samples),
    n_samples_t2_min=min(n_samples_2),n_samples_t2_median=median(n_samples_2),n_samples_t2_max=max(n_samples_2),
    n_nmin2_draws=sum(n_min>=2),.groups='drop')
  all = summarize_draw_metrics(x,metrics,n_draws)
  sensitivity = summarize_draw_metrics(filter(x,n_min>=2),metrics,n_draws) |>
    rename_with(~paste0(.x,'_nmin2'),-all_of(keys))
  result = fixed |> left_join(support,by=keys) |> left_join(all,by=keys) |>
    left_join(sensitivity,by=keys) |>
    mutate(n_expected_draws=n_draws,n_valid_draws=lag_rate_per_century_n_valid_draws,
      n_missing_draws=lag_rate_per_century_n_missing_draws)
  # A group with no eligible sensitivity realization has zero valid draws.
  result |> mutate(across(ends_with('n_valid_draws_nmin2'),~replace_na(.x,0L)),
    across(ends_with('n_missing_draws_nmin2'),~replace_na(.x,n_draws)),
    across(ends_with('n_undefined_draws_nmin2'),~replace_na(.x,0L))) |>
    arrange(site,lake,offset,desc(age_hi))
}

lake_reporting_grid = function(by_offset,bin_width_years=1000L) {
  offsets = seq(0,validate_tracking_width(bin_width_years)-100,100)
  metrics = tracking_metric_names()
  cells = by_offset |> mutate(t=purrr::map2(age_lo,age_hi,
    ~seq(ceiling(.x/100)*100,.y-100,100))) |> unnest(t)
  purrr::map_dfr(metrics,function(m) cells |> group_by(site,lake,t) |> summarize(
    metric=m,estimate=safe_stat(.data[[paste0(m,'_median')]],median),
    age_q025=safe_stat(.data[[paste0(m,'_q025')]],median),
    age_q975=safe_stat(.data[[paste0(m,'_q975')]],median),
    phase_min=safe_stat(.data[[paste0(m,'_median')]],min),
    phase_max=safe_stat(.data[[paste0(m,'_median')]],max),
    n_offsets=n_distinct(offset),n_valid_offsets=sum(is.finite(.data[[paste0(m,'_median')]])),
    min_present_draws=min(n_present_draws),.groups='drop')) |>
    filter(n_offsets==length(offsets)) |> mutate(unit=metric_unit(metric),
      bin_width_years=bin_width_years,reporting_only=TRUE)
}

# Machine-readable schema for every generated column, including wide statistics.
tracking_schema = function(tables) purrr::imap_dfr(tables,function(tbl,dataset) {
  purrr::map_dfr(names(tbl),function(column) {
    base = sub('_nmin2$','',column)
    stat = sub('^.*_(n_valid_draws|n_missing_draws|n_undefined_draws|mean|sd|median|q025|q25|q75|q975)$','\\1',base)
    metric = sub('_(n_valid_draws|n_missing_draws|n_undefined_draws|mean|sd|median|q025|q25|q75|q975)$','',base)
    u = metric_unit(metric)
    description = gsub('_',' ',column)
    if(metric %in% c('o1','o2','o1_2','o2_2','p1','p2','p1_2','p2_2') ||
       grepl('^(pace|direction)_corrected_CCA',metric) || grepl('^delta_(observed|predicted)_CCA',metric)) u='CCA_units'
    if(metric %in% c(CCA_CLIMATE_VARS,paste0(CCA_CLIMATE_VARS,'_2'))) u=unname(CLIMATE_VARIABLE_UNITS[sub('_2$','',metric)])
    if(grepl('^n_|draws|samples|cores|event_count',column)) u='count'
    if(grepl('core_max_frequency|frequency_per_1000yr',column)) u='events_per_1000yr'
    if(grepl('coverage_fraction|normalized_activity|^fire_activity$',column)) u='unitless'
    if(column %in% c('age_hi','age_lo','t','interval_mid_cal_bp','youngest_endpoint','oldest_endpoint') || grepl('cal_bp$',column)) u='cal_years_BP'
    if(column %in% c('offset','bin_width_years','vegetation_dt_years','climate_dt_years','climate_n_years') || grepl('window_years$',column)) u='years'
    if(grepl('^(vegetation_t[12]_year|climate_[t12]+_midyear|climate_start|climate_end)$',column)) u='calendar_year'
    if(is.logical(tbl[[column]])) u='boolean'
    if(is.character(tbl[[column]])) u='identifier_or_category'
    if(metric!=base) description=paste(stat,'of',metric,'across valid chronology realizations')
    if(grepl('_n_valid_draws',column)) description='Number of finite response draws among the configured whole chronology draws'
    if(grepl('_n_missing_draws',column)) description='Configured draw count minus finite response draws; includes absent and undefined realizations'
    if(grepl('_n_undefined_draws',column)) description='Present eligible realizations with a mathematically undefined response'
    if(grepl('_nmin2$',column)) description=paste(description,'restricted to at least two samples in both bins')
    if(column=='n_valid_draws') description='Valid draws for primary lag_rate_per_century response'
    if(column=='n_missing_draws') description='100 minus n_valid_draws for primary lag response'
    if(column=='fire_activity') description='Equal-core mean within-core normalized event frequency; shared among MORA vegetation lakes'
    if(is.na(u)) u='count_or_dimensionless'
    tibble(dataset=dataset,column=column,type=class(tbl[[column]])[1],unit=u,definition=description)
  })
})
