# Offline acceptance gate. Reconstruct GLS algebra, data selection, predictions,
# support and performance independently of the producer's summarizing functions.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_predictor_models.R'),local=TRUE)
root=here('output/exploratory/tracking_predictor_models')
x=read_csv(here('output/cca_tracking_era_by_offset.csv'),show_col_types=FALSE)
stored=readRDS(file.path(root,'model_fits.rds'))
cf=read_csv(file.path(root,'model_coefficients.csv'),show_col_types=FALSE)
pf=read_csv(file.path(root,'model_performance.csv'),show_col_types=FALSE)
pr=read_csv(file.path(root,'transition_predictions.csv'),show_col_types=FALSE)
grid=read_csv(file.path(root,'holocene_prediction_timeseries.csv'),show_col_types=FALSE)
sens=read_csv(file.path(root,'lake_random_intercept_sensitivity.csv'),show_col_types=FALSE)
exc=read_csv(file.path(root,'model_exclusions.csv'),show_col_types=FALSE)
spatial=read_csv(file.path(root,'anthropocene_spatial_checks.csv'),show_col_types=FALSE)
elevations=read_csv(file.path(root,'anthropocene_elevations.csv'),show_col_types=FALSE)
stopifnot(stored$width==1000L,stored$input_md5==unname(tools::md5sum(here('output/cca_tracking_era_by_offset.csv'))),
  length(stored$fits)==36L,nrow(cf)==144L,nrow(pf)==36L,nrow(sens)==3L,
  nrow(spatial)==12L,nrow(elevations)==607L,all(is.finite(elevations$elevation)),
  !anyDuplicated(cf[c('metric','era','offset','model_type','term')]),
  !anyDuplicated(pf[c('metric','era','offset','model_type')]),
  !anyDuplicated(grid[c('metric','offset','site','lake','t')]))
close=function(a,b,tol=1e-7) stopifnot(length(a)==length(b),
  all(is.finite(a)),all(is.finite(b)),max(abs(a-b))<tol)
# Trace every offset-specific predictor back to the original sources, without
# calling the climate-binning or fire-frequency calculation helpers.
source(here('R/helpers/config.R'),local=TRUE)
reference=readRDS(here('output/cca_calibration_reference.rds'))
variables=c('MSpT','MWT','SP','WP')
calibration_sd=vapply(as.data.frame(reference$legacy_climate)[variables],sd,numeric(1))
close(calibration_sd,reference$climate_scaling$sd[
  match(variables,reference$climate_scaling$variable)],tol=1e-12)
ponds=read_csv(here('output/chelsa_paleo_ponds.csv'),show_col_types=FALSE)
monthly=ponds |> transmute(site,lake,age=1950-slice*100,variable,month,
  value=if(PALEO_USE_BIAS_CORRECTED) value_corrected else value_raw)
stopifnot(!anyDuplicated(monthly[c('site','lake','age','variable','month')]),
  all(is.finite(monthly$value)))
# Mean-extrema temperatures use six values (three months x tasmin/tasmax).
# Seasonal precipitation is the sum of three monthly values.
native=monthly |> group_by(site,lake,age) |> summarize(
  MSpT=mean(value[variable %in% c('tasmin','tasmax') & month %in% 3:5]),
  MWT=mean(value[variable %in% c('tasmin','tasmax') & month %in% c(12,1,2)]),
  SP=sum(value[variable=='pr' & month %in% 6:8]),
  WP=sum(value[variable=='pr' & month %in% c(12,1,2)]),
  complete=sum(variable %in% c('tasmin','tasmax') & month %in% 3:5)==6L &
    sum(variable %in% c('tasmin','tasmax') & month %in% c(12,1,2))==6L &
    sum(variable=='pr' & month %in% 6:8)==3L &
    sum(variable=='pr' & month %in% c(12,1,2))==3L,.groups='drop')
stopifnot(all(native$complete))
events=read_csv(here('output/holocene_fire_source_events.csv'),show_col_types=FALSE)
continuous=read_csv(here('output/holocene_fire_source_series.csv'),show_col_types=FALSE)
fire_reference=read_csv(here('output/holocene_era_fire_core_frequency.csv'),show_col_types=FALSE)
cores=continuous |> group_by(site,lake) |> summarize(
  younger=min(age_cal_yr_BP),older=max(age_cal_yr_BP),.groups='drop') |>
  mutate(denominator=NA_real_)
stopifnot(all(fire_reference$window_years==1000L))
for(i in seq_len(nrow(cores))) {
  core=cores[i,]
  ages=events$age_cal_yr_BP[events$site==core$site & events$lake==core$lake]
  centers=seq(ceiling((core$younger+500)/100)*100,
    floor((core$older-500)/100)*100,by=100)
  counts=vapply(centers,function(t) sum(ages>=t-500 & ages<t+500),integer(1))
  recorded=fire_reference |> filter(site==core$site,lake==core$lake) |> arrange(cal_bp)
  close(recorded$cal_bp,centers);close(recorded$accepted_event_count,counts)
  close(recorded$core_max_frequency,rep(max(counts),length(counts)))
  close(recorded$normalized_frequency,counts/max(counts))
  cores$denominator[i]=max(counts) # events per 1,000 years in full reference windows
}
by_offset=read_csv(here('output/cca_tracking_holocene_lake_by_offset.csv'),show_col_types=FALSE)
audit=by_offset |> select(all_of(tracking_transition_keys()))
for(field in c(variables,paste0(variables,'_2'),'standardized_climate_change_rate','fire_activity'))
  audit[[field]]=rep(NA_real_,nrow(audit))
audit$fire_coverage_valid=rep(NA,nrow(audit))
for(i in seq_len(nrow(audit))) {
  row=audit[i,]
  stopifnot(row$age_hi-row$age_lo==1000L,
    (row$age_hi-row$offset-500) %% 1000==0,
    (row$age_lo-row$offset-500) %% 1000==0)
  endpoints=lapply(c(row$age_hi,row$age_lo),function(mid) {
    slices=native |> filter(site==row$site,lake==row$lake,age>=mid-500,age<mid+500)
    stopifnot(nrow(slices)==10L,all(diff(sort(slices$age))==100))
    vapply(slices[variables],mean,numeric(1))
  })
  for(j in seq_along(variables)) {
    audit[[variables[j]]][i]=endpoints[[1]][j]
    audit[[paste0(variables[j],'_2')]][i]=endpoints[[2]][j]
  }
  audit$standardized_climate_change_rate[i]=
    sqrt(sum(((endpoints[[2]]-endpoints[[1]])/calibration_sd)^2))*100/1000
  regional=cores[cores$site==row$site,]
  covered=regional$younger<=row$age_lo & regional$older>=row$age_hi
  audit$fire_coverage_valid[i]=sum(covered)>=if(row$site=='MORA') 2L else 1L
  activity=vapply(which(covered),function(j) {
    ages=events$age_cal_yr_BP[events$site==row$site & events$lake==regional$lake[j]]
    sum(ages>=row$age_lo & ages<row$age_hi)/regional$denominator[j]
  },numeric(1))
  audit$fire_activity[i]=if(audit$fire_coverage_valid[i]) mean(activity) else NA_real_
}
compare_predictors=function(data,fields) {
  expected=left_join(data |> select(all_of(tracking_transition_keys())),audit,
    by=tracking_transition_keys(),relationship='many-to-one')
  stopifnot(nrow(expected)==nrow(data),!anyNA(expected$standardized_climate_change_rate))
  for(field in fields) {
    stopifnot(identical(is.na(data[[field]]),is.na(expected[[field]])))
    valid=!is.na(expected[[field]])
    if(is.logical(expected[[field]])) stopifnot(all(data[[field]][valid]==expected[[field]][valid]))
    else if(any(valid)) close(data[[field]][valid],expected[[field]][valid],tol=1e-10)
  }
}
predictors=c('standardized_climate_change_rate','fire_activity','fire_coverage_valid')
compare_predictors(by_offset,predictors)
realizations=read_csv(here('output/cca_tracking_holocene_lake_realizations.csv'),show_col_types=FALSE)
compare_predictors(realizations,c(variables,paste0(variables,'_2'),predictors))
compare_predictors(x[x$era=='Holocene',],predictors)
cat('Source alignment passed:',nrow(audit),'lake/offset transitions; all monthly climate endpoints,',
  'accepted-event counts, full-window normalization references and combined-input predictors.\n')
same_model=function(table,metric,era,offset,type) {
  table |> filter(.data$metric==.env$metric,.data$era==.env$era,.data$model_type==.env$type,
    if(is.na(.env$offset)) is.na(.data$offset) else .data$offset==.env$offset)
}
for(entry in stored$fits) {
  d=entry$data; fit=entry$fit; metric=unique(d$metric);era=as.character(unique(d$era))
  info=entry$performance; offset=info$offset;type=info$model_type
  source=x |> filter(.data$era==.env$era,.data$metric==.env$metric,
    if(.env$era=='Holocene') .data$offset==.env$offset else TRUE)
  eligible=is.finite(source$estimate)
  if(era=='Holocene') eligible=eligible & is.finite(source$standardized_climate_change_rate) &
    source$fire_coverage_valid & is.finite(source$fire_activity) else eligible=eligible & !is.na(source$burned)
  ids=function(a) if(era=='Holocene') paste(a$site,a$lake,a$age_hi,a$age_lo) else paste(a$site,a$plot_id)
  stopifnot(setequal(ids(d),ids(source[eligible,])),nrow(d)==sum(eligible),
    info$n_excluded==sum(!eligible),fit$method=='REML')
  X=model.matrix(formula(fit),d); beta=coef(fit);X=X[,names(beta),drop=FALSE]
  sigma_site=fit$sigma*coef(fit$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
  sd=unname(sigma_site[as.character(d$site)])
  C=diag(nrow(d))
  if(era=='Holocene') {
    theta=coef(fit$modelStruct$corStruct,unconstrained=FALSE)
    rho=as.numeric(theta/(1+theta^2))
    neighbors=outer(d$series,d$series,'==') & abs(outer(d$time_index,d$time_index,'-'))==1
    C[neighbors]=rho
    close(d$time_index,(d$interval_mid_cal_bp-offset)/1000)
    stopifnot(all(d$climate_dt_years==1000),all(d$vegetation_dt_years==1000))
  } else stopifnot(is.null(fit$modelStruct$corStruct),all(table(d$series)==1L))
  # Independent generalized least-squares solution with reconstructed covariance.
  V=C*outer(sd,sd); invV=solve(V)
  expected_vcov=solve(crossprod(X,invV %*% X))
  expected_beta=as.numeric(expected_vcov %*% crossprod(X,invV %*% d$estimate))
  close(expected_beta,unname(beta),tol=2e-6)
  close(as.numeric(expected_vcov),as.numeric(vcov(fit)),tol=2e-6)
  predicted=as.numeric(X %*% beta);residual=d$estimate-predicted
  independent_r2=1-sum(residual^2)/sum((d$estimate-mean(d$estimate))^2)
  close(independent_r2,info$R2)
  c=same_model(cf,metric,era,offset,type);p=same_model(pr,metric,era,offset,type)
  p=p[match(ids(d),ids(p)),];c=c[match(names(beta),c$term),]
  close(c$estimate,unname(beta));close(c$std_error,sqrt(diag(expected_vcov)),tol=2e-6)
  close(c$conf_low,c$estimate-qt(.975,c$df)*c$std_error)
  close(c$conf_high,c$estimate+qt(.975,c$df)*c$std_error)
  close(p$predicted_lag_rate,predicted);close(p$raw_residual,residual)
  close(sum(p$normalized_residual^2),as.numeric(crossprod(residual,invV %*% residual)),tol=2e-5)
  close(p$prediction_se,sqrt(rowSums((X %*% expected_vcov)*X)),tol=2e-6)
  if(era=='Holocene') {
    compare_predictors(d,predictors)
    close(d$climate_rate,d$standardized_climate_change_rate,tol=1e-12)
    close(p$climate_rate,d$climate_rate,tol=1e-12)
    close(p$fire_activity,d$fire_activity,tol=1e-12)
    g=grid |> filter(.data$metric==.env$metric,.data$offset==.env$offset)
    stopifnot(nrow(g)==nrow(d)*10L,all(g$t>=g$age_lo),all(g$t<g$age_hi))
    # Half-open boundaries: one present source interval per displayed date.
    for(i in seq_len(nrow(g))) {
      j=which(d$site==g$site[i] & d$lake==g$lake[i] & d$age_lo<=g$t[i] & d$age_hi>g$t[i])
      stopifnot(length(j)==1L)
      close(g$predicted_lag_rate[i],predicted[j]);close(g$estimate[i],d$estimate[j])
      close(g$climate_rate[i],d$climate_rate[j]);close(g$fire_activity[i],d$fire_activity[j])
    }
  }
}
# Offset-0 lake sensitivity uses precisely the GLS input. Record actual failure
# states rather than asserting that every corrected-response apVar must fail.
for(metric in tracking_predictor_responses()) {
  s=stored$sensitivities[[metric]];b=stored$fits[[paste(metric,0,sep='_')]]
  row=sens[sens$metric==metric,];stopifnot(row$n==30L,row$n_lakes==4L,row$converged)
  close(row$max_abs_coefficient_difference,max(abs(fixef(s$captured$fit)-coef(b$fit))))
  stopifnot(row$random_intercept_sd<1e-5,
    row$covariance_status==tracking_covariance_status(s$captured$fit))
}
# Reconstruct the equal mixture independently from the unchanged offset fits.
ensemble_record=readRDS(file.path(root,'holocene_ensemble_components.rds'))
ensemble_table=read_csv(file.path(root,'holocene_ensemble_coefficients.csv'),show_col_types=FALSE)
ensemble_audit=read_csv(file.path(root,'holocene_ensemble_offset_audit.csv'),show_col_types=FALSE)
ensemble_vcov=read_csv(file.path(root,'holocene_ensemble_offset_vcov.csv'),show_col_types=FALSE)
stopifnot(ensemble_record$input_md5==stored$input_md5,nrow(ensemble_table)==12L,
  nrow(ensemble_audit)==30L,nrow(ensemble_vcov)==480L,
  !anyDuplicated(ensemble_table[c('metric','term')]),
  !anyDuplicated(ensemble_audit[c('metric','offset')]),
  !anyDuplicated(ensemble_vcov[c('metric','offset','term_row','term_col')]),
  all(ensemble_table$interval_type=='reconstruction-ensemble uncertainty'),
  !any(grepl('p_value|conf_low|conf_high',names(ensemble_table))),
  all(ensemble_audit$included_in_ensemble),all(ensemble_audit$converged),
  all(ensemble_audit$fixed_vcov_positive_definite),all(ensemble_audit$offset_weight==.1),
  sum(ensemble_audit$near_correlation_boundary)==2L,
  sum(ensemble_audit$offset800_direction_review)==1L)
for(metric in tracking_predictor_responses()) {
  entries=stored$fits[paste(metric,seq(0,900,100),sep='_')]
  record=ensemble_record$responses[[metric]]; settings=record$settings
  set.seed(73);before=.Random.seed;kind=RNGkind()
  simulated=tracking_reconstruction_ensemble(entries,seq(0,900,100),
    samples_per_offset=settings$samples_per_offset,seed=settings$seed)
  stopifnot(identical(.Random.seed,before),identical(RNGkind(),kind),
    settings$samples_per_offset==50000L,settings$total_samples==500000L,
    !settings$chronology_uncertainty_propagated,
    all(vapply(simulated$draws,nrow,integer(1))==50000L))
  terms=names(coef(entries[[1]]$fit))
  beta=sapply(entries,function(e) coef(e$fit)[terms])
  average=rowMeans(beta); centered=beta-average
  within=Reduce(`+`,lapply(entries,function(e) vcov(e$fit)[terms,terms]))/10
  between=tcrossprod(centered)/10
  close(as.numeric(record$within_covariance),as.numeric(within),tol=1e-12)
  close(as.numeric(record$between_covariance),as.numeric(between),tol=1e-12)
  close(as.numeric(record$ensemble_covariance),as.numeric(within+between),tol=1e-12)
  table=ensemble_table |> filter(.data$metric==.env$metric)
  table=table[match(terms,table$term),]
  close(table$ensemble_estimate,average,tol=1e-12)
  close(table$offset_estimate_min,apply(beta,1,min),tol=1e-12)
  close(table$offset_estimate_max,apply(beta,1,max),tol=1e-12)
  close(table$n_positive_offsets,rowSums(beta>0));close(table$n_negative_offsets,rowSums(beta<0))
  close(table$n_zero_offsets,rowSums(beta==0))
  close(table$sign_consistency,pmax(rowSums(beta>0),rowSums(beta<0),rowSums(beta==0))/10)
  joint=do.call(rbind,simulated$draws)
  bounds=apply(joint,2,quantile,probs=c(.025,.975),names=FALSE)
  close(table$ensemble_lower,bounds[1,],tol=1e-12)
  close(table$ensemble_upper,bounds[2,],tol=1e-12)
  scale=outer(sqrt(diag(within+between)),sqrt(diag(within+between)))
  stopifnot(max(abs(cov(joint)-(within+between))/scale)<.025)
  for(i in seq_along(entries)) {
    e=entries[[i]]; V=vcov(e$fit)[terms,terms]
    close(as.numeric(record$components[[i]]$vcov),as.numeric(V),tol=1e-12)
    # Joint sampling must preserve off-diagonal coefficient covariances.
    scale=outer(sqrt(diag(V)),sqrt(diag(V)))
    stopifnot(max(abs(cov(simulated$draws[[i]])-V)/scale)<.04)
    rows=ensemble_vcov |> filter(.data$metric==.env$metric,offset==e$performance$offset)
    close(rows$covariance,mapply(function(a,b) V[a,b],rows$term_row,rows$term_col),tol=1e-12)
    audit_row=ensemble_audit |> filter(.data$metric==.env$metric,offset==e$performance$offset)
    baseline=entries[[1]]$data
    keys=function(d) paste(d$site,d$lake,d$time_index)
    stopifnot(audit_row$n==nrow(e$data),audit_row$n_excluded==e$performance$n_excluded,
      audit_row$n_shared_phases_offset0==length(intersect(keys(e$data),keys(baseline))),
      audit_row$n_phases_only_in_offset==length(setdiff(keys(e$data),keys(baseline))),
      audit_row$n_phases_only_in_offset0==length(setdiff(keys(baseline),keys(e$data))))
  }
  # Exact normal-mixture quantiles provide an independent Monte Carlo check.
  se=sqrt(sapply(entries,function(e) diag(vcov(e$fit)[terms,terms])))
  for(j in seq_along(terms)) {
    cdf=function(z) mean(pnorm(z,mean=beta[j,],sd=se[j,]))
    interval=range(beta[j,]+rep(c(-10,10),each=10)*rep(se[j,],2))
    exact=vapply(c(.025,.975),function(p)
      uniroot(function(z) cdf(z)-p,interval=interval,tol=1e-12)$root,numeric(1))
    close(c(table$ensemble_lower[j],table$ensemble_upper[j]),exact,
      tol=.025*sqrt((within+between)[j,j]))
  }
}
# Identical reconstructions retain the original coefficient uncertainty: no
# artificial sqrt(10) precision gain. Missing/failed fits cannot change weights.
identical_entries=rep(list(stored$fits[['lag_rate_per_century_0']]),10)
for(i in seq_along(identical_entries)) {
  identical_entries[[i]]$performance$offset=(i-1L)*100
  identical_entries[[i]]$data$offset=(i-1L)*100
}
identical_ensemble=tracking_reconstruction_ensemble(identical_entries,seq(0,900,100),samples_per_offset=5000L)
V=vcov(identical_entries[[1]]$fit)
close(as.numeric(identical_ensemble$ensemble_covariance),as.numeric(V),tol=1e-12)
stopifnot(max(abs((identical_ensemble$summary$ensemble_upper-
  identical_ensemble$summary$ensemble_lower)/sqrt(diag(V))-2*qnorm(.975)))<.08)
before=.Random.seed;rm('.Random.seed',envir=.GlobalEnv)
invisible(tracking_reconstruction_ensemble(identical_entries,seq(0,900,100),samples_per_offset=2L))
stopifnot(!exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE))
assign('.Random.seed',before,envir=.GlobalEnv)
fail_ensemble=function(entries) stopifnot(inherits(tryCatch(
  tracking_reconstruction_ensemble(entries,seq(0,900,100),samples_per_offset=2L),error=identity),'error'))
fail_ensemble(identical_entries[-1])
failed=identical_entries;failed[[1]]$performance$converged=FALSE;fail_ensemble(failed)
bad_covariance=identical_entries;bad_covariance[[1]]$fit$varBeta[1,1]=-1;fail_ensemble(bad_covariance)
cat('Reconstruction ensemble passed: exact equal weights, full joint covariance, mixture quantiles,',
  'unshrunk uncertainty, complete fit/support audits, retained offset 800 and unchanged RNG.\n')
stopifnot(grepl('Non-positive',sens$covariance_status[sens$metric=='lag_rate_per_century']),
  !is.na(sens$variance_interval_error[sens$metric=='lag_rate_per_century']))
# Missing fire coverage and covered zero events are distinct, without changing
# response presence or silently importing values from another era/offset.
changed=x
key=changed$era=='Holocene' & changed$offset==0 & changed$lake=='JayBath' & changed$age_hi==7500
changed$fire_activity[key]=NA_real_;changed$high_fire[key]=NA;changed$fire_coverage_valid[key]=FALSE
s=tracking_predictor_input(changed,'lag_rate_per_century','Holocene',0)
stopifnot(nrow(s$data)==29L,nrow(s$excluded)==1L,
  s$excluded$exclusion=='missing_climate_or_fire_coverage')
changed$fire_activity[key]=0;changed$high_fire[key]=FALSE;changed$fire_coverage_valid[key]=TRUE
s=tracking_predictor_input(changed,'lag_rate_per_century','Holocene',0)
stopifnot(nrow(s$data)==30L,any(s$data$fire_activity==0))
# Contemporary pace validity is response-specific; no extra filtering of lags.
stopifnot(sum(exc$era=='Anthropocene' & exc$metric=='pace_corrected_lag_rate_per_century')==284L,
  !any(exc$era=='Anthropocene' & exc$metric=='lag_rate_per_century'),
  all(pf$n[pf$era=='Anthropocene' & pf$metric=='lag_rate_per_century']==607L),
  all(pf$n[pf$era=='Anthropocene' & pf$metric=='pace_corrected_lag_rate_per_century']==465L))
# Elevation identity normalization and provenance, including NOCA lowercase IDs.
e=new.env();load(here('data/MORA_plots.rda'),envir=e)
n=read_csv(here('data/NOCA/NOCA_plots_fromWilson.csv'),show_col_types=FALSE)
for(i in seq_len(nrow(elevations))) {
  row=elevations[i,]
  value=if(row$site=='MORA') e$plot_info$elevation[match(toupper(trimws(row$plot_id)),
    toupper(trimws(e$plot_info$plot_id)))] else n$`2015.Elevation.m`[match(toupper(trimws(row$plot_id)),
      toupper(trimws(n$`2015.Plot.Name`)))]
  close(row$elevation,value)
}
# Spatial graph and permutation checks are reproducible and preserve RNG state.
a=stored$fits[['lag_rate_per_century_Anthropocene_basic']]$predictions
set.seed(29);before=.Random.seed;check=tracking_spatial_residual_check(a)
stopifnot(identical(before,.Random.seed))
recorded=spatial |> filter(metric=='lag_rate_per_century',model_type=='Anthropocene_basic')
close(check$checks$moran_I,recorded$moran_I);close(check$checks$p_permutation_two_sided,recorded$p_permutation_two_sided)
stopifnot(all(spatial$n_permutations==999L),all(spatial$p_permutation_two_sided>=.001),
  all(spatial$p_permutation_two_sided<=1),all(spatial$crs=='EPSG:32610'))
if(isTRUE(getOption('paleoaces.render_figures',TRUE)))
for(stem in c('offset_coefficients','ensemble_coefficients','era_coefficients_offset_0','holocene_predictions','R2','residuals','spatial_residuals'))
  stopifnot(file.exists(here('plot/test_figures',paste0('fig_tracking_predictor_',stem,'.pdf'))))
cat('Predictor models passed: 36 GLS fits, three lake sensitivities, independent GLS algebra, exact support, elevation joins, temporal predictions, R2 and spatial diagnostics.\n')
