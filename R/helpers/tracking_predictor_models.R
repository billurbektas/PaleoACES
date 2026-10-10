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

# Equal mixture of reconstruction-specific coefficient distributions. This is
# bin-placement sensitivity, conditional on each estimated GLS covariance;
# chronology draws are not refitted and offsets are never independent replicates.
tracking_reconstruction_ensemble = function(entries,offsets,bin_width_years=1000L,
    samples_per_offset=50000L,seed=20261011L) {
  width=validate_tracking_width(bin_width_years)
  if(!identical(as.numeric(offsets),as.numeric(seq(0,width-100,100))) ||
     length(entries)!=length(offsets) || any(vapply(entries,is.null,logical(1))))
    stop('Reconstruction ensemble requires every configured offset fit')
  if(length(samples_per_offset)!=1L || !is.finite(samples_per_offset) ||
     samples_per_offset<2 || samples_per_offset!=as.integer(samples_per_offset))
    stop('samples_per_offset must be an integer of at least two')
  actual=vapply(entries,function(e) e$performance$offset,numeric(1))
  if(anyDuplicated(actual) || !setequal(actual,offsets))
    stop('Missing or duplicate reconstruction offset')
  entries=entries[match(offsets,actual)]
  metric=unique(vapply(entries,function(e) e$performance$metric,character(1)))
  if(length(metric)!=1L) stop('Mix one response at a time')
  terms=names(coef(entries[[1]]$fit)); k=length(terms); n_offsets=length(offsets)
  if(!setequal(terms,c('(Intercept)','siteNOCA','climate_rate','fire_activity')))
    stop('Unexpected explanatory GLS coefficients')
  phase_keys=function(d) paste(d$site,d$lake,d$time_index,sep='|')
  baseline=phase_keys(entries[[1]]$data)
  components=vector('list',n_offsets); audits=vector('list',n_offsets)
  for(i in seq_along(entries)) {
    e=entries[[i]]; p=e$performance; d=e$data; fit=e$fit
    beta=coef(fit); V=vcov(fit)
    if(!inherits(fit,'gls') || nrow(p)!=1L || !isTRUE(p$converged) ||
       p$era!='Holocene' || p$model_type!='Holocene_MA1' || fit$method!='REML' ||
       any(d$offset!=offsets[i]) || any(d$climate_dt_years!=width) ||
       any(d$vegetation_dt_years!=width) || !setequal(names(beta),terms) ||
       !setequal(rownames(V),terms) || !setequal(colnames(V),terms))
      stop('Incompatible or unconverged ensemble fit at offset ',offsets[i])
    beta=beta[terms]; V=V[terms,terms,drop=FALSE]
    if(any(!is.finite(beta)) || any(!is.finite(V)) ||
       !isTRUE(all.equal(V,t(V),tolerance=1e-12)) ||
       inherits(try(chol(V),silent=TRUE),'try-error'))
      stop('Invalid fixed-effect covariance at offset ',offsets[i])
    components[[i]]=list(offset=offsets[i],weight=1/n_offsets,beta=beta,vcov=V)
    current=phase_keys(d)
    if(anyDuplicated(current)) stop('Duplicate phase-aligned transition identity')
    sigma_site=fit$sigma*coef(fit$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
    park_cor=function(park) {
      z=d[d$site==park,,drop=FALSE]
      if(nrow(z)<2L || sd(z$climate_rate)==0 || sd(z$estimate)==0) NA_real_
      else cor(z$climate_rate,z$estimate)
    }
    audits[[i]]=p |> mutate(bin_width_years=width,offset_weight=1/n_offsets,
      n_shared_phases_offset0=length(intersect(current,baseline)),
      n_phases_only_in_offset=length(setdiff(current,baseline)),
      n_phases_only_in_offset0=length(setdiff(baseline,current)),
      min_draws_present=min(d$n_draws_present),median_draws_present=median(d$n_draws_present),
      climate_coefficient=unname(beta['climate_rate']),fire_coefficient=unname(beta['fire_activity']),
      residual_sd_MORA=unname(sigma_site['MORA']),residual_sd_NOCA=unname(sigma_site['NOCA']),
      climate_response_cor_MORA=park_cor('MORA'),climate_response_cor_NOCA=park_cor('NOCA'),
      fixed_vcov_positive_definite=TRUE,
      offset800_direction_review=width==1000L && offsets[i]==800L &&
        metric=='direction_corrected_lag_rate_per_century',
      included_in_ensemble=TRUE)
  }
  # Preserve the caller's RNG, including its absence; use a recorded generator.
  had_seed=exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  if(had_seed) old_seed=get('.Random.seed',envir=.GlobalEnv)
  old_kind=RNGkind()
  on.exit({do.call(RNGkind,as.list(old_kind))
    if(had_seed) assign('.Random.seed',old_seed,envir=.GlobalEnv) else
      if(exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)) rm('.Random.seed',envir=.GlobalEnv)})
  RNGkind('Mersenne-Twister','Inversion','Rejection');set.seed(seed)
  # BEGIN RECONSTRUCTION ENSEMBLE SAMPLING
  # Each component retains coef(fit) and the full vcov(fit).
  draws=lapply(components,function(component) {
    z=matrix(rnorm(samples_per_offset*k),nrow=samples_per_offset,ncol=k)
    sweep(z %*% chol(component$vcov),2,component$beta,'+')
  })
  mixture=do.call(rbind,draws);colnames(mixture)=terms
  betas=do.call(rbind,lapply(components,`[[`,'beta'))
  estimate=colMeans(betas) # exact equal-weight mean, not a Monte Carlo mean
  within=Reduce(`+`,lapply(components,`[[`,'vcov'))/n_offsets
  centered=sweep(betas,2,estimate,'-')
  between=crossprod(centered)/n_offsets
  bounds=apply(mixture,2,quantile,probs=c(.025,.975),names=FALSE)
  # END RECONSTRUCTION ENSEMBLE SAMPLING
  positive=colSums(betas>0);negative=colSums(betas<0);zero=colSums(betas==0)
  dominant=ifelse(positive>negative & positive>zero,'positive',
    ifelse(negative>positive & negative>zero,'negative',
      ifelse(zero>positive & zero>negative,'zero','mixed')))
  label='reconstruction-ensemble uncertainty'
  summary=tibble(metric,term=terms,ensemble_estimate=unname(estimate),
    ensemble_lower=bounds[1,],ensemble_upper=bounds[2,],
    offset_estimate_min=apply(betas,2,min),offset_estimate_max=apply(betas,2,max),
    n_positive_offsets=unname(positive),n_negative_offsets=unname(negative),
    n_zero_offsets=unname(zero),dominant_sign=unname(dominant),
    sign_consistency=pmax(positive,negative,zero)/n_offsets,n_offsets,
    interval_type=label)
  covariance=map_dfr(components,function(component) {
    expand_grid(term_row=terms,term_col=terms) |> mutate(metric=.env$metric,
      offset=component$offset,offset_weight=component$weight,
      covariance=map2_dbl(term_row,term_col,~component$vcov[.x,.y])) |>
      select(metric,offset,offset_weight,term_row,term_col,covariance)
  })
  list(summary=summary,offset_audit=bind_rows(audits),offset_vcov=covariance,
    components=components,within_covariance=within,between_covariance=between,
    ensemble_covariance=within+between,
    settings=list(bin_width_years=width,n_offsets=n_offsets,samples_per_offset=samples_per_offset,
      total_samples=n_offsets*samples_per_offset,seed=seed,
      distribution='joint multivariate normal: fitted beta and full vcov',
      rng_kind=c('Mersenne-Twister','Inversion','Rejection'),interval_type=label,
      chronology_uncertainty_propagated=FALSE),draws=draws)
}

tracking_reconstruction_ensemble_plot = function(summary) {
  labels=tracking_predictor_labels()
  palette=c(lag_rate_per_century='#43AA9C',pace_corrected_lag_rate_per_century='#DE85F0',
    direction_corrected_lag_rate_per_century='#8B85F1')
  data=summary |> filter(term!='(Intercept)') |>
    mutate(response=factor(unname(labels[metric]),levels=rev(unname(labels))),
      predictor=factor(term,levels=c('siteNOCA','climate_rate','fire_activity'),
        labels=c('NOCA versus MORA','Climate-change rate','Fire activity')))
  ggplot(data,aes(ensemble_estimate,response,color=metric))+
    geom_vline(xintercept=0,color='grey65',linetype='dashed')+
    geom_errorbar(aes(xmin=ensemble_lower,xmax=ensemble_upper),
      orientation='y',width=.15,linewidth=.85)+geom_point(size=3)+
    facet_wrap(~predictor,scales='free_x',nrow=1)+scale_color_manual(values=palette,guide='none')+
    labs(title='Holocene reconstruction-ensemble coefficients',
      subtitle=paste('Equal weights across',unique(summary$n_offsets),
        'bin offsets; bars: 2.5–97.5% reconstruction-ensemble uncertainty'),
      x='Ensemble-averaged coefficient (original predictor scales)',y=NULL,
      caption='Conditional GLS coefficient uncertainty and bin-placement sensitivity; Bacon chronology uncertainty is not propagated.')+
    theme_bw(base_size=18)+theme(panel.grid.minor=element_blank(),
      strip.background=element_rect(fill='#f0f2f5',color=NA),strip.text=element_text(size=18,face='bold'),
      axis.text=element_text(size=16),plot.title=element_text(size=23,face='bold'),
      plot.subtitle=element_text(size=16),plot.caption=element_text(size=13,hjust=0),
      plot.margin=margin(12,15,12,12))
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
