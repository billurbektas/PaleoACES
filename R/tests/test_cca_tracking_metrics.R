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
f=transition_fire(intervals,events,continuous,1000)
equal(f$fire_panther_accepted_event_count,c(0L,1L,1L,NA_integer_))
equal(f$fire_activity[1],0);stopifnot(is.na(f$fire_activity[4]),!f$fire_coverage_valid[4])
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

r=read_csv(here('output/cca_tracking_holocene_lake_realizations.csv'),show_col_types=FALSE)
b=read_csv(here('output/cca_tracking_holocene_lake_by_offset.csv'),show_col_types=FALSE)
a=read_csv(here('output/cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE)
keys=c('site','lake','draw','offset','age_hi','age_lo');group_keys=setdiff(keys,'draw')
stopifnot(!anyDuplicated(r[keys]),!anyDuplicated(b[group_keys]),
  all(r$age_hi-r$age_lo==1000),all(r$n_climate_slices==10),all(r$n_climate_slices_2==10),
  setequal(r$draw,1:100),setequal(r$offset,seq(0,900,100)),nrow(a)==607L,
  !anyDuplicated(a$plot_id),!anyNA(a$burned),sum(a$small_observed_movement)==142L,
  all(is.na(a$pace_effect_on_lag[a$small_observed_movement])),
  all(a$direction_effect_on_lag[a$small_observed_movement]==0),
  all(b$n_valid_draws+b$n_missing_draws==100),all(b$n_present_draws+b$n_absent_draws==100))
equal(r$magnitude_tracking_ratio,r$rate_tracking_ratio)
# Reconstruct distributions with base R, independently of the producer's summary helper.
distribution = function(v) {
  v=v[is.finite(v)]
  c(n_valid_draws=length(v),n_missing_draws=100-length(v),
    mean=if(length(v)) mean(v) else NA_real_,sd=if(length(v)>1) sd(v) else NA_real_,
    median=if(length(v)) median(v) else NA_real_,
    setNames(if(length(v)) quantile(v,c(.025,.25,.75,.975),names=FALSE) else rep(NA_real_,4),
      c('q025','q25','q75','q975')))
}
for(sensitivity in c(FALSE,TRUE)) for(metric in tracking_metric_names()) {
  raw=if(sensitivity) filter(r,n_min>=2) else r
  manual=raw |> group_by(across(all_of(group_keys))) |>
    summarize(stats=list(distribution(.data[[metric]])),.groups='drop') |> unnest_wider(stats) |>
    rename_with(~paste0(.x,'_audit'),-all_of(group_keys))
  cmp=left_join(b,manual,by=group_keys)
  for(stat in names(distribution(numeric()))) {
    expected=cmp[[paste0(stat,'_audit')]]
    if(stat=='n_valid_draws') expected=replace_na(expected,0)
    if(stat=='n_missing_draws') expected=replace_na(expected,100)
    equal(cmp[[paste0(metric,'_',stat,if(sensitivity) '_nmin2' else '')]],expected)
  }
}
stopifnot(any(b$n_present_draws<10))
# One present stationary response, one moving response and 98 absent draws.
stationary=calculate_tracking_metrics(mutate(x,o1_2=o1,o2_2=o2))
synthetic=bind_rows(mutate(stationary,draw=1L),mutate(m,draw=2L)) |>
  mutate(site='test',lake='test',offset=0,age_hi=1500,age_lo=500)
ss=summarize_draw_metrics(synthetic,'pace_effect_on_lag',100)
equal(ss$pace_effect_on_lag_n_valid_draws,1)
equal(ss$pace_effect_on_lag_n_missing_draws,99)
equal(ss$pace_effect_on_lag_n_undefined_draws,1)
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
cat('PASS: focused geometry, counterfactuals, lake climate, fire support/normalization, full draw distributions, interval configuration and migration reference.\n')
