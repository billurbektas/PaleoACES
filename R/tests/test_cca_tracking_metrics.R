# Independent geometry and integration checks for the canonical tracking data.
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/holocene_climate_fire_era_functions.R'),local=TRUE)
equal = function(a,b) stopifnot(isTRUE(all.equal(a,b,tolerance=1e-10,check.attributes=FALSE)))
fail = function(expr) stopifnot(inherits(tryCatch({force(expr);NULL},error=identity),'error'))
x = tibble(o1=1,o2=1,o1_2=1,o2_2=3,p1=0,p2=0,p1_2=4,p2_2=0,
  vegetation_dt_years=20,climate_dt_years=40)
m = calculate_tracking_metrics(x)
equal(m$lag_t1,sqrt(2));equal(m$lag_t2,sqrt(18));equal(m$angle_degrees,90)
equal(m$magnitude_tracking_ratio,.5);equal(m$rate_tracking_ratio,1)
equal(m$observed_turnover_rate,10);equal(m$predicted_vegetation_change_rate,10)
equal(m$pace_corrected_CCA1,1);equal(m$pace_corrected_CCA2,5)
equal(m$direction_corrected_CCA1,3);equal(m$direction_corrected_CCA2,1)
equal(m$pace_effect_on_lag,sqrt(18)-sqrt(34))
equal(m$direction_effect_on_lag,sqrt(18)-sqrt(2))
equal(m$pace_effect_on_lag_per_century,(sqrt(18)-sqrt(34))*2.5)
stopifnot(m$pace_effect_on_lag<0,m$direction_effect_on_lag>0)
stopifnot(abs(m$pace_effect_on_lag+m$direction_effect_on_lag-m$change_in_lag)>1e-6)
# Equality, opposite direction and both stationary source directions.
z=x;z$o1=z$o2=z$p1=z$p2=0;z$o1_2=z$p1_2=1;z$o2_2=z$p2_2=0
p=calculate_tracking_metrics(z);equal(p$lag_t2,0);equal(p$pace_effect_on_lag,0);equal(p$direction_effect_on_lag,0)
z$o1_2=-1;equal(calculate_tracking_metrics(z)$angle_degrees,180)
z=x;z$o1_2=z$o1;z$o2_2=z$o2;p=calculate_tracking_metrics(z)
stopifnot(is.na(p$angle_degrees),is.na(p$pace_effect_on_lag),p$direction_counterfactual_valid)
equal(p$direction_effect_on_lag,0);equal(p$observed_turnover_rate,0)
z=x;z$p1_2=z$p1;z$p2_2=z$p2;p=calculate_tracking_metrics(z)
stopifnot(is.na(p$angle_degrees),is.na(p$magnitude_tracking_ratio),is.na(p$direction_effect_on_lag))
equal(p$pace_corrected_CCA1,1);equal(p$pace_corrected_CCA2,1)
z$o1_2=z$o1;z$o2_2=z$o2;p=calculate_tracking_metrics(z)
stopifnot(is.na(p$pace_effect_on_lag),is.na(p$direction_effect_on_lag));equal(p$change_in_lag,0)
z=x;z$p1_2=NA_real_;p=calculate_tracking_metrics(z)
stopifnot(!p$finite_endpoints,is.na(p$lag_t2));equal(p$observed_turnover_rate,10)
fail(calculate_tracking_metrics(mutate(x,climate_dt_years=0)))
fail(validate_tracking_width(350));equal(validate_tracking_width(500),500L)
# Guarded cosine can be shared without exporting an additional response metric.
equal(safe_cosine_2d(c(1,-1,0),c(0,0,0),1,0),c(1,-1,NA_real_))
stopifnot(!any(c('lag','d_offset','cosine_similarity','tracking_error') %in% names(m)))

# Full-coverage zero is distinct from absent coverage, including interval edges.
continuous=tibble(site='NOCA',lake='PantherPotholes',age_cal_yr_BP=c(0,4000),background_z=0)
events=tibble(site='NOCA',lake='PantherPotholes',age_cal_yr_BP=c(1000,2000),peak_magnitude=1)
intervals=tibble(site='NOCA',offset=0,age_lo=c(0,1000,2000,4000),age_hi=c(1000,2000,3000,5000))
high=tibble(site='NOCA',cal_bp=(intervals$age_hi+intervals$age_lo)/2,high_fire=c(FALSE,TRUE,TRUE,FALSE))
f=transition_fire(intervals,events,continuous,1000,high_fire=high)
equal(f$fire_panther_accepted_event_count,c(0L,1L,1L,NA_integer_))
equal(f$fire_activity[1],0);stopifnot(is.na(f$fire_activity[4]),!f$fire_coverage_valid[4],is.na(f$high_fire[4]),identical(f$high_fire[1],FALSE))
equal(f$fire_window_years,rep(1000L,4));equal(f$fire_reference_window_years,rep(1000L,4))
f500=transition_fire(tibble(site='NOCA',offset=0,age_lo=1000,age_hi=1500),events,continuous,500)
equal(f500$fire_window_years,500);equal(f500$fire_panther_frequency_per_1000yr,2)
equal(f500$fire_panther_core_max_frequency,2);equal(f500$fire_activity,1)
# A missing MORA core cannot be treated as a zero-fire contributing record.
mora_cont=bind_rows(lapply(c('Sunrise Lake','Shadow Lake','Little Sunrise Lake'),function(lake)
  tibble(site='MORA',lake=lake,age_cal_yr_BP=c(0,if(lake=='Sunrise Lake') 4000 else 2000),background_z=0)))
mora_events=tibble(site='MORA',lake=c('Sunrise Lake','Shadow Lake','Little Sunrise Lake'),age_cal_yr_BP=1000,peak_magnitude=1)
fm=transition_fire(tibble(site='MORA',offset=0,age_lo=c(0,2000),age_hi=c(1000,3000)),mora_events,mora_cont,1000)
equal(fm$fire_activity[1],0);stopifnot(is.na(fm$fire_activity[2]),fm$fire_covered_cores[2]==1)

# Exact external contracts; these expected names do not come from the producer.
responses=c('lag_rate_per_century','observed_turnover_rate','magnitude_tracking_ratio',
  'rate_tracking_ratio','angle_degrees','pace_effect_on_lag_per_century',
  'direction_effect_on_lag_per_century')
group_keys=c('site','lake','offset','age_hi','age_lo')
holocene_columns=c(group_keys,'interval_mid_cal_bp','vegetation_dt_years','climate_dt_years',
  'standardized_climate_change_rate','fire_activity','fire_coverage_valid','high_fire',responses,
  'n_draws_present','n_draws_nmin2','n_samples_t1_median','n_samples_t2_median')
modern_columns=c('site','plot_id','vegetation_t1_year','vegetation_t2_year',
  'climate_t1_midyear','climate_t2_midyear','vegetation_dt_years','climate_dt_years',
  'standardized_climate_change_rate','burned',responses,'angle_valid',
  'pace_counterfactual_valid','direction_counterfactual_valid','tracking_ratio_valid')
uncertainty_contract=c(group_keys,'metric','sampling_rule','median','q025','q975',
  'n_expected_draws','n_present_draws','n_eligible_draws','n_valid_draws','n_undefined_draws')
read_tracking=function(stem) read_csv(here('output',paste0('cca_tracking_',stem,'.csv')),show_col_types=FALSE)
r=read_tracking('holocene_lake_realizations');b=read_tracking('holocene_lake_by_offset')
a=read_tracking('anthropocene_plot_model_input');ac=read_tracking('anthropocene_plot_calculations')
u=read_tracking('holocene_lake_uncertainty');report=read_tracking('holocene_lake_timeseries')
keys=c('site','lake','draw','offset','age_hi','age_lo')
stopifnot(identical(names(b),holocene_columns),identical(names(a),modern_columns),
  identical(names(u),uncertainty_contract),nrow(b)==273L,nrow(a)==607L,nrow(u)==3822L,
  !anyDuplicated(r[keys]),!anyDuplicated(b[group_keys]),
  !anyDuplicated(u[c(group_keys,'metric','sampling_rule')]),
  all(r$age_hi-r$age_lo==1000),all(r$n_climate_slices==10),all(r$n_climate_slices_2==10),
  setequal(r$draw,1:100),setequal(r$offset,seq(0,900,100)),
  !anyDuplicated(a$plot_id),!anyNA(a$burned),sum(a$site=='MORA' & a$burned)==2L,
  sum(ac$small_observed_movement)==142L,
  all(is.na(ac$pace_effect_on_lag[ac$small_observed_movement])),
  all(ac$direction_effect_on_lag[ac$small_observed_movement]==0))
for(v in names(a)) equal(a[[v]],ac[[v]])
equal(r$magnitude_tracking_ratio,r$rate_tracking_ratio)
validate_tracking_products(b,u,a)
# Changed regression keys must stop execution with diagnostics, never be filled.
err=tryCatch(validate_tracking_products(b[-1,],u,a),error=identity)
stopifnot(inherits(err,'error'),grepl('Changed keys',conditionMessage(err)),
  grepl('removed',conditionMessage(err)),grepl('no exports replaced',conditionMessage(err)))
err=tryCatch(validate_tracking_products(b,u[-1,],a),error=identity)
stopifnot(inherits(err,'error'),grepl('expected 3822 rows',conditionMessage(err)),
  grepl('removed',conditionMessage(err)))
fail(lake_reporting_grid(mutate(u,offset=if_else(offset==0,1000,offset))))

# Independent geometry using norms and atan2(cross,dot), including actual MORA
# lake endpoints. Historical pooled MORA scores are not a reference for this.
for(d in list(r,ac)) {
  ox=d$o1_2-d$o1;oy=d$o2_2-d$o2;px=d$p1_2-d$p1;py=d$p2_2-d$p2
  no=sqrt(ox^2+oy^2);np=sqrt(px^2+py^2)
  l1=sqrt((d$o1-d$p1)^2+(d$o2-d$p2)^2)
  l2=sqrt((d$o1_2-d$p1_2)^2+(d$o2_2-d$p2_2)^2)
  angle=atan2(abs(ox*py-oy*px),ox*px+oy*py)*180/pi
  angle[no<=1e-8 | np<=1e-8]=NA_real_
  pace_lag=sqrt((d$o1+np*ox/no-d$p1_2)^2+(d$o2+np*oy/no-d$p2_2)^2)
  pace_lag[no<=1e-8]=NA_real_
  direction_lag=sqrt((d$o1+no*px/np-d$p1_2)^2+(d$o2+no*py/np-d$p2_2)^2)
  direction_lag[np<=1e-8]=NA_real_
  magnitude_ratio=ifelse(np>1e-8,no/np,NA_real_)
  expected=list(lag_rate_per_century=(l2-l1)*100/d$climate_dt_years,
    observed_turnover_rate=no*100/d$vegetation_dt_years,
    magnitude_tracking_ratio=magnitude_ratio,
    rate_tracking_ratio=magnitude_ratio*d$climate_dt_years/d$vegetation_dt_years,
    angle_degrees=angle,pace_effect_on_lag_per_century=(l2-pace_lag)*100/d$climate_dt_years,
    direction_effect_on_lag_per_century=(l2-direction_lag)*100/d$climate_dt_years)
  for(v in responses) equal(d[[v]],expected[[v]])
}

# Base R reconstruction of every response distribution and sampling rule.
key_for=function(d,cols) do.call(paste,c(d[cols],sep='::'))
groups=split(seq_len(nrow(r)),key_for(r,group_keys))
finite_distribution=function(v) {
  v=v[is.finite(v)]
  if(!length(v)) return(c(median=NA_real_,q025=NA_real_,q975=NA_real_))
  c(median=median(v),q025=unname(quantile(v,.025)),q975=unname(quantile(v,.975)))
}
manual=u
for(i in seq_len(nrow(u))) {
  idx=groups[[key_for(u[i,],group_keys)]]
  eligible=if(u$sampling_rule[i]=='all') idx else idx[r$n_min[idx]>=2]
  values=r[[u$metric[i]]][eligible]
  for(v in c('median','q025','q975')) manual[[v]][i]=finite_distribution(values)[v]
  manual$n_expected_draws[i]=100L;manual$n_present_draws[i]=length(idx)
  manual$n_eligible_draws[i]=length(eligible);manual$n_valid_draws[i]=sum(is.finite(values))
  manual$n_undefined_draws[i]=length(eligible)-sum(is.finite(values))
}
for(v in names(u)) equal(u[[v]],manual[[v]])
for(i in seq_len(nrow(b))) {
  idx=groups[[key_for(b[i,],group_keys)]]
  equal(b$n_draws_present[i],length(idx));equal(b$n_draws_nmin2[i],sum(r$n_min[idx]>=2))
  equal(b$n_samples_t1_median[i],median(r$n_samples[idx]))
  equal(b$n_samples_t2_median[i],median(r$n_samples_2[idx]))
  for(v in responses) equal(b[[v]][i],finite_distribution(r[[v]][idx])['median'])
}
stopifnot(any(b$n_draws_present<10),any(u$n_eligible_draws==0),
  all(is.na(u$median[u$n_eligible_draws==0])),all(u$n_valid_draws[u$n_eligible_draws==0]==0))

# Map independently reconstructed distributions to reporting dates, then
# require all configured offsets independently for each response.
all_dist=manual[manual$sampling_rule=='all',]
cells=do.call(rbind,lapply(seq_len(nrow(all_dist)),function(i) {
  d=all_dist[i,];d[rep(1,(d$age_hi-d$age_lo)/100),] |>
    mutate(t=seq(d$age_lo,d$age_hi-100,100))
}))
report_keys=c('site','lake','t','metric')
report_groups=split(seq_len(nrow(cells)),key_for(cells,report_keys))
expected_report=bind_rows(lapply(report_groups,function(idx) {
  d=cells[idx,]
  if(length(unique(d$offset))!=10L || sum(is.finite(d$median))!=10L) return(NULL)
  cbind(d[1,report_keys],data.frame(estimate=median(d$median),
    age_q025=median(d$q025),age_q975=median(d$q975),phase_min=min(d$median),
    phase_max=max(d$median),n_offsets=10L,n_valid_offsets=10L,
    min_present_draws=min(d$n_present_draws)))
}))
stopifnot(setequal(key_for(report,report_keys),key_for(expected_report,report_keys)),
  !anyDuplicated(report[report_keys]),setequal(report$metric,responses),
  all(report$reporting_only),all(report$bin_width_years==1000),nrow(report)==1657L)
expected_report=expected_report[match(key_for(report,report_keys),key_for(expected_report,report_keys)),]
for(v in names(expected_report)) equal(report[[v]],expected_report[[v]])
equal(report$unit,ifelse(report$metric=='angle_degrees','degrees',
  ifelse(report$metric %in% c('magnitude_tracking_ratio','rate_tracking_ratio'),'unitless','CCA_units_per_century')))
reflection=report |> filter(lake=='ReflectionPond',t==5900)
stopifnot(setequal(reflection$metric,setdiff(responses,c('angle_degrees','pace_effect_on_lag_per_century'))))

# Reconstruct the plotting context directly, without a reporting-grid model CSV.
context=lake_reporting_context(b,report,1000)
for(i in seq_len(nrow(context))) {
  d=context[i,]
  selected=b[b$site==d$site & b$lake==d$lake & b$age_lo<=d$t & b$age_hi>d$t,]
  selected=selected[is.finite(selected[[d$metric]]),]
  stopifnot(!anyDuplicated(selected$offset),setequal(selected$offset,seq(0,900,100)))
  equal(d$estimate,median(selected[[d$metric]]))
  equal(d$climate_rate,median(selected$standardized_climate_change_rate))
  covered=all(selected$fire_coverage_valid & is.finite(selected$fire_activity))
  equal(d$fire_activity,if(covered) median(selected$fire_activity) else NA_real_)
}

# Shifted intervals, response-specific eligibility, covered zero fire and
# insufficient fire coverage. Missing exposure must not delete valid responses.
sb=tibble(site='test',lake='test',offset=c(0,100,200),age_hi=c(450,550,350),
  age_lo=c(150,250,50),standardized_climate_change_rate=c(1,2,6),
  fire_activity=c(0,.3,NA_real_),fire_coverage_valid=c(TRUE,TRUE,FALSE))
for(metric in responses) sb[[metric]]=c(10,20,40)
sb$angle_degrees[3]=NA_real_;sb$pace_effect_on_lag_per_century[3]=NA_real_
su=sb |> select(all_of(group_keys),all_of(responses)) |>
  pivot_longer(all_of(responses),names_to='metric',values_to='median') |>
  mutate(sampling_rule='all',q025=median,q975=median,n_present_draws=2L)
sg=lake_reporting_grid(su,300)
sc=lake_reporting_context(sb,sg,300)
stopifnot(nrow(sc)==5L,all(sc$t==300),all(sc$n_valid_offsets==3L),
  all(is.na(sc$fire_activity)))
equal(sc$climate_rate,rep(2,5))
sb$fire_activity=0;sb$fire_coverage_valid=TRUE
zero_context=lake_reporting_context(sb,sg,300)
equal(zero_context$fire_activity,rep(0,5))
fail(lake_reporting_context(sb,mutate(sg,estimate=estimate+1),300))
# Sparse support and an empty sensitivity group are retained explicitly.
stationary=calculate_tracking_metrics(mutate(x,o1_2=o1,o2_2=o2))
synthetic=bind_rows(mutate(stationary,draw=1L),mutate(m,draw=2L)) |>
  mutate(site='test',lake='test',offset=0,age_hi=1500,age_lo=500,n_min=1L)
ss=lake_uncertainty(synthetic,100)
stopifnot(nrow(ss)==14L,all(ss$n_present_draws==2L),all(ss$n_expected_draws==100L))
pace=ss |> filter(metric=='pace_effect_on_lag_per_century',sampling_rule=='all')
equal(pace$n_eligible_draws,2L);equal(pace$n_valid_draws,1L);equal(pace$n_undefined_draws,1L)
lag=ss |> filter(metric=='lag_rate_per_century',sampling_rule=='all')
equal(lag$n_valid_draws,2L)
empty=ss |> filter(sampling_rule=='nmin2')
stopifnot(all(empty$n_eligible_draws==0),all(empty$n_valid_draws==0),
  all(empty$n_undefined_draws==0),all(is.na(empty$median)),all(is.na(empty$q025)),all(is.na(empty$q975)))
# Odd multiples of the native resolution have 50-year endpoint midpoints;
# reporting still obeys the exact half-open interval without rounding endpoints.
odd=ss |> mutate(age_lo=50,age_hi=350) |>
  tidyr::crossing(placement=c(0,100,200)) |> mutate(offset=placement) |> select(-placement)
odd_grid=lake_reporting_grid(odd,300)
stopifnot(setequal(odd_grid$t,c(100,200,300)),all(odd_grid$n_valid_offsets==3))

# Primary normalization references and MORA history are identical at shared intervals.
source('R/helpers/paleo_runs.R',local=TRUE)
ref=readRDS(here('output/cca_calibration_reference.rds'))
scale=read_csv(here('output/cca_tracking_climate_scaling.csv'),show_col_types=FALSE)
equal(scale$sd,ref$climate_scaling$sd)
shared=r |> filter(site=='MORA') |> distinct(offset,age_hi,age_lo,fire_activity,fire_history_id)
stopifnot(!anyDuplicated(shared[c('offset','age_hi','age_lo')]))
# Width affects bin support in one implementation; do not generate sensitivity output files.
ponds=read_csv(here('output/chelsa_paleo_ponds.csv'),show_col_types=FALSE)
source(here('R/helpers/climate_variables.R'),local=TRUE)
env=ponds |> transmute(unit=lake,period=site,variable,time=slice,month,value=value_raw) |>
  derive_climate_vars(winter_shift=FALSE) |> rename(lake=unit,site=period) |> mutate(age=1950-time*100)
# Verify each endpoint against that lake's complete native climate window.
for(endpoint in c('age_hi','age_lo')) {
  endpoints=r |> distinct(site,lake,offset,across(all_of(endpoint)),across(all_of(
    if(endpoint=='age_hi') CCA_CLIMATE_VARS else paste0(CCA_CLIMATE_VARS,'_2'))))
  for(i in seq_len(nrow(endpoints))) {
    e=endpoints[i,];mid=e[[endpoint]]
    native=env |> filter(site==e$site,lake==e$lake,age>=mid-500,age<mid+500)
    stopifnot(nrow(native)==10)
    for(v in CCA_CLIMATE_VARS) equal(e[[paste0(v,if(endpoint=='age_lo') '_2' else '')]],mean(native[[v]]))
  }
}
small=build_lake_tracking(ref,paleo_age_draws(allow_rebuild=FALSE) |> filter(draw<=2),env,500)$realizations
stopifnot(all(small$vegetation_dt_years==500),all(small$n_climate_slices==5),
  setequal(small$offset,seq(0,400,100)),all(small$age_hi-small$age_lo==500))

# Compact, fixed migration reference; no old analysis implementation is retained.
fixture=read_csv(here('R/tests/fixtures/cca_noca_tracking_baseline.csv'),show_col_types=FALSE)
actual=inner_join(fixture |> select(all_of(setdiff(keys,'lake'))),r,by=setdiff(keys,'lake'))
stopifnot(nrow(actual)==nrow(fixture))
for(v in names(fixture)) equal(actual[[v]],fixture[[v]])
cat('PASS: independent geometry, compact contracts, all response/sampling distributions, response-specific reporting, aligned plotting predictors, fire support, interval configuration and NOCA regression.\n')
