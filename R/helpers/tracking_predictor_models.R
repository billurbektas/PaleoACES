# Era-specific predictor models. Actual transitions and response validity remain
# in the canonical combined input; reporting dates never enter the model fit.
tracking_predictor_responses = function() c('lag_rate_per_century',
  tracking_corrected_response_names())
tracking_predictor_labels = function() c(lag_rate_per_century='Observed lag change',
  pace_corrected_lag_rate_per_century='Pace-corrected lag change',
  direction_corrected_lag_rate_per_century='Direction-corrected lag change')

tracking_predictor_input = function(combined,metric,era,offset=0) {
  selected=tracking_offset_model_input(combined,metric,offset)
  d=selected$data[selected$data$era==era,,drop=FALSE]
  d$climate_rate=d$standardized_climate_change_rate
  missing_response=selected$excluded |> filter(.data$era==.env$era) |>
    mutate(exclusion='undefined_response')
  eligible=if(era=='Holocene') is.finite(d$climate_rate) &
    !is.na(d$fire_coverage_valid) & d$fire_coverage_valid & is.finite(d$fire_activity) else
    !is.na(d$burned)
  missing_predictor=d[!eligible,,drop=FALSE]
  missing_predictor$exclusion=rep(if(era=='Holocene') 'missing_climate_or_fire_coverage' else
    'missing_burn_assignment',nrow(missing_predictor))
  d=d[eligible,,drop=FALSE]
  if(era=='Anthropocene') d$burned=factor(d$burned,levels=c(FALSE,TRUE),labels=c('Unburned','Burned'))
  if(any(table(d$site)<2L)) stop('Each site needs two eligible responses')
  formula=if(era=='Holocene') estimate~site+climate_rate+fire_activity else estimate~site+burned
  X=model.matrix(formula,d)
  if(qr(X)$rank!=ncol(X) || nrow(X)<=ncol(X)) stop('Rank deficient predictor model: ',era,' / ',metric,' / ',offset)
  list(data=d,excluded=bind_rows(missing_response,missing_predictor),step_years=selected$step_years)
}

# BEGIN PREDICTOR MODEL STRUCTURES
fit_tracking_holocene_predictors = function(d) {
  nlme::gls(estimate ~ site + climate_rate + fire_activity, data=d,
    correlation=nlme::corARMA(p=0,q=1,form=~time_index | series),
    weights=nlme::varIdent(form=~1 | site), method='REML', na.action=na.fail,
    control=nlme::glsControl(msMaxIter=200))
}
fit_tracking_holocene_lake_intercept = function(d) {
  nlme::lme(fixed=estimate ~ site + climate_rate + fire_activity,
    random=~1 | series, data=d,
    correlation=nlme::corARMA(p=0,q=1,form=~time_index | series),
    weights=nlme::varIdent(form=~1 | site), method='REML', na.action=na.fail,
    control=nlme::lmeControl(msMaxIter=200))
}
fit_tracking_anthropocene_predictors = function(d) {
  nlme::gls(estimate ~ site + burned, data=d,
    weights=nlme::varIdent(form=~1 | site), method='REML', na.action=na.fail,
    control=nlme::glsControl(msMaxIter=200))
}
fit_tracking_anthropocene_extended_predictors = function(d) {
  nlme::gls(estimate ~ site + elevation + climate_rate + burned, data=d,
    weights=nlme::varIdent(form=~1 | site), method='REML', na.action=na.fail,
    control=nlme::glsControl(msMaxIter=200))
}
# END PREDICTOR MODEL STRUCTURES

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

tracking_capture_fit = function(call) {
  warnings=character()
  fit=withCallingHandlers(tryCatch(call(),error=function(e)e),
    warning=function(w) {warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
  list(fit=if(inherits(fit,'error')) NULL else fit,
    error=if(inherits(fit,'error')) conditionMessage(fit) else NA_character_,
    warnings=unique(warnings))
}
tracking_covariance_status = function(fit) {
  if(!is.matrix(fit$apVar)) return(as.character(fit$apVar))
  if(all(is.finite(fit$apVar)) && min(eigen(fit$apVar,symmetric=TRUE,only.values=TRUE)$values)>0)
    'positive_definite' else 'non_positive_definite'
}
tracking_predictor_coefficients = function(fit,metric,era,offset,model_type) {
  tt=summary(fit)$tTable
  df=if(inherits(fit,'lme')) tt[,'DF'] else rep(fit$dims$N-fit$dims$p,nrow(tt))
  margin=qt(.975,df)*tt[,'Std.Error']
  if(any(!is.finite(tt)) || !is.finite(as.numeric(logLik(fit)))) stop('Nonfinite predictor fit')
  tibble(metric,era,offset,model_type,term=rownames(tt),estimate=tt[,'Value'],
    std_error=tt[,'Std.Error'],df,t_value=tt[,'t-value'],p_value=tt[,'p-value'],
    conf_low=tt[,'Value']-margin,conf_high=tt[,'Value']+margin)
}
tracking_descriptive_r2 = function(observed,predicted) {
  sst=sum((observed-mean(observed))^2)
  if(sst>0) 1-sum((observed-predicted)^2)/sst else NA_real_
}
tracking_predictor_predictions = function(fit,d,metric,era,offset,model_type) {
  X=model.matrix(formula(fit),d)
  beta=coef(fit)
  X=X[,names(beta),drop=FALSE]
  variance=vcov(fit)
  se=sqrt(pmax(0,rowSums((X %*% variance)*X)))
  predicted=as.numeric(X %*% beta)
  if(max(abs(predicted-as.numeric(fitted(fit))))>1e-9) stop('Prediction disagrees with fitted fixed effects')
  d |> mutate(metric=.env$metric,era=.env$era,offset=.env$offset,model_type=.env$model_type,
    burned=as.character(burned),predicted_lag_rate=predicted,prediction_se=se,
    conf_low=predicted-qt(.975,fit$dims$N-fit$dims$p)*se,
    conf_high=predicted+qt(.975,fit$dims$N-fit$dims$p)*se,
    normalized_residual=as.numeric(residuals(fit,type='normalized')),
    raw_residual=estimate-predicted) |>
    select(metric,era,offset,model_type,site,lake,plot_id,series,time_index,
      age_hi,age_lo,interval_mid_cal_bp,estimate,climate_rate,fire_activity,burned,
      longitude,latitude,n_draws_present,n_draws_nmin2,predicted_lag_rate,
      prediction_se,conf_low,conf_high,raw_residual,normalized_residual,
      any_of(c('elevation','elevation_source')))
}
tracking_prediction_reporting_grid = function(transitions) {
  # Repeat supported transition predictions for display only, never interpolate
  # vegetation/predictors or extrapolate an unsupported transition.
  if(any(transitions$era!='Holocene') ||
     anyDuplicated(transitions[c('metric','offset','site','lake','age_hi','age_lo')]))
    stop('Expected unique Holocene prediction transitions')
  transitions |> mutate(t=map2(age_lo,age_hi,~seq(.x,.y-100,by=100))) |>
    unnest(t) |> arrange(metric,site,lake,offset,t) |>
    group_by(metric,site,lake,offset) |>
    mutate(segment=cumsum(c(TRUE,diff(t)!=100))) |> ungroup()
}
tracking_lake_intercept_sensitivity = function(gls_fit,d,metric) {
  captured=tracking_capture_fit(function() fit_tracking_holocene_lake_intercept(d))
  fit=captured$fit
  intervals_error=NA_character_
  variance_intervals=NULL
  if(!is.null(fit)) variance_intervals=tryCatch(intervals(fit,which='var-cov'),
    error=function(e) {intervals_error <<- conditionMessage(e);NULL})
  sd_bounds=if(is.null(variance_intervals)) c(NA_real_,NA_real_) else
    as.numeric(unlist(variance_intervals$reStruct$series[1,c('lower','upper')]))
  random_sd=if(is.null(fit)) NA_real_ else as.numeric(VarCorr(fit)[1,'StdDev'])
  tibble(metric,offset=0,n=nrow(d),n_lakes=n_distinct(d$series),
    converged=!is.null(fit),random_intercept_sd=random_sd,random_intercept_variance=random_sd^2,
    random_sd_relative_to_residual=if(is.null(fit)) NA_real_ else random_sd/fit$sigma,
    max_abs_coefficient_difference=if(is.null(fit)) NA_real_ else max(abs(fixef(fit)-coef(gls_fit))),
    max_abs_fixed_prediction_difference=if(is.null(fit)) NA_real_ else
      max(abs(as.numeric(predict(fit,level=0))-as.numeric(fitted(gls_fit)))),
    covariance_status=if(is.null(fit)) 'fit_failed' else tracking_covariance_status(fit),
    random_sd_conf_low=sd_bounds[1],random_sd_conf_high=sd_bounds[2],
    variance_intervals_finite=all(is.finite(sd_bounds)),
    variance_interval_error=intervals_error,
    warnings=if(length(captured$warnings)) paste(captured$warnings,collapse='; ') else 'none',
    fit_error=captured$error) |> list(summary=_,captured=captured)
}

tracking_spatial_residual_check = function(d,k=8L,n_permutations=999L,seed=104729L) {
  # Separate graphs by park; symmetric k-nearest-neighbor edges in UTM 10N.
  # Permutations describe remaining spatial pattern, not fitted spatial covariance.
  if(anyDuplicated(d[c('site','plot_id')]) || any(!is.finite(d$longitude) | !is.finite(d$latitude)))
    stop('Spatial diagnostic requires unique plots and valid coordinates')
  coordinates=sf::st_as_sf(d,coords=c('longitude','latitude'),crs=4326) |> sf::st_transform(32610)
  xy=sf::st_coordinates(coordinates)
  d$easting_m=xy[,1]; d$northing_m=xy[,2]
  had_seed=exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  if(had_seed) old_seed=get('.Random.seed',envir=.GlobalEnv)
  on.exit(if(had_seed) assign('.Random.seed',old_seed,envir=.GlobalEnv) else
    if(exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)) rm('.Random.seed',envir=.GlobalEnv))
  set.seed(seed)
  checks=map_dfr(c('MORA','NOCA'),function(park) {
    group=d[d$site==park,,drop=FALSE]; n=nrow(group)
    if(n<=k) stop('Too few plots for spatial diagnostic')
    distances=as.matrix(dist(group[c('easting_m','northing_m')]))
    if(any(distances[upper.tri(distances)]==0)) stop('Coincident projected plots need a separate spatial policy')
    diag(distances)=Inf
    edges=matrix(FALSE,n,n)
    for(i in seq_len(n)) edges[i,order(distances[i,])[seq_len(k)]]=TRUE
    edges=edges | t(edges); W=edges/rowSums(edges)
    z=group$normalized_residual-mean(group$normalized_residual)
    statistic=function(v) sum(v*(W %*% v))/sum(v^2)
    observed=statistic(z); expected=-1/(n-1)
    simulations=replicate(n_permutations,statistic(sample(z)))
    p=(1+sum(abs(simulations-expected)>=abs(observed-expected)))/(1+n_permutations)
    tibble(metric=unique(group$metric),model_type=unique(group$model_type),site=park,n,k,n_permutations,seed,
      moran_I=observed,expected_I=expected,p_permutation_two_sided=p,
      median_edge_distance_m=median(distances[edges]),crs='EPSG:32610',
      weights=paste0('symmetric ',k,'-nearest-neighbor graph, row standardized'))
  })
  list(checks=checks,locations=d)
}
