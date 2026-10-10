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
for(stem in c('offset_coefficients','era_coefficients_offset_0','holocene_predictions','R2','residuals','spatial_residuals'))
  stopifnot(file.exists(here('plot/test_figures',paste0('fig_tracking_predictor_',stem,'.pdf'))))
cat('Predictor models passed: 36 GLS fits, three lake sensitivities, independent GLS algebra, exact support, elevation joins, temporal predictions, R2 and spatial diagnostics.\n')
