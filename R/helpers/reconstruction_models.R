# Shared GLS fitting, covariance selection, reporting and chronology refits.
source(here::here('R/helpers/config.R'),local=TRUE)
source(here::here('R/helpers/tracking_data.R'),local=TRUE)
source(here::here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here::here('R/helpers/tracking_model_reporting.R'),local=TRUE)
reconstruction_metric_label=function(values) {
  labels=tracking_model_response_label(values)
  labels[is.na(labels)]=values[is.na(labels)]
  labels
}

# Strip execution environments from saved fits. Portable formula environments
# contain only the fitted data; numerical fit components are untouched.
reconstruction_portable = function(x,data=NULL) {
  env=new.env(parent=baseenv())
  if(!is.null(data)) env$d=data
  prune=function(value) {
    if(is.environment(value)) return(env)
    if(is.function(value)) return(value)
    if(is.list(value) || is.call(value) || is.pairlist(value))
      for(i in seq_along(value)) {
        if(is.list(value)) value[i]=list(prune(value[[i]])) else value[[i]]=prune(value[[i]])
      }
    attrs=attributes(value)
    if(length(attrs)) {
      for(name in names(attrs)) if(is.environment(attrs[[name]])) attrs[[name]]=env else
        if(inherits(attrs[[name]],'formula')) attrs[[name]]=prune(attrs[[name]])
      attributes(value)=attrs
    }
    value
  }
  prune(x)
}
reconstruction_store = function(x,path) {
  if(!is.null(x$fits)) x$fits=lapply(x$fits,function(fit) {
    data=tryCatch(get('d',envir=environment(formula(fit)),inherits=FALSE),error=function(e) NULL)
    reconstruction_portable(fit,data)
  })
  if(!is.null(x$fixed)) x=reconstruction_portable(x,x$data)
  if(is.list(x) && is.null(x$draw) && is.null(x$signature)) x=lapply(x,function(e)
    if(is.list(e) && !is.null(e$data)) reconstruction_portable(e,e$data) else e)
  saveRDS(x,path)
}

reconstruction_capture = function(call) {
  warnings=character()
  fit=withCallingHandlers(tryCatch(call(),error=function(e)e),warning=function(w) {
    warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
  list(fit=if(inherits(fit,'error')) NULL else fit,
    error=if(inherits(fit,'error')) conditionMessage(fit) else NA_character_,warnings=unique(warnings))
}
reconstruction_correlation = function(type) switch(type,
  Independent=NULL,MA1=nlme::corARMA(p=0,q=1,form=~time_index | series),
  CAR1=nlme::corCAR1(form=~time_centuries | series),stop('Unknown covariance family'))
reconstruction_fit = function(d,fixed,type,variance='site') {
  X=model.matrix(fixed,d)
  if(nrow(X)<=ncol(X) || qr(X)$rank<ncol(X)) stop('rank_deficient')
  if(!is.finite(var(d$estimate)) || var(d$estimate)==0) stop('constant_response')
  if(any(table(droplevels(d$site))<2L)) stop('insufficient_site_observations')
  # With a group intercept and varIdent, a constant group permits its residual
  # variance to approach zero and the likelihood is unbounded. Keep observations
  # and report this structural limitation instead of a spurious optimizer fit.
  groups=if(variance=='era_site') d$era_site else d[[variance]]
  if(any(vapply(split(d$estimate,groups),function(y) length(y)>1L && var(y)==0,logical(1))))
    stop('constant_variance_group: no finite heteroscedastic Gaussian optimum')
  fit=nlme::gls(fixed,data=d,correlation=reconstruction_correlation(type),
    weights=nlme::varIdent(form=as.formula(paste('~1 |',variance))),method='REML',
    na.action=na.fail,control=nlme::glsControl(msMaxIter=300))
  # Store evaluable model/covariance calls for emmeans covariance derivatives.
  fit$call$model=fixed
  fit$call$weights=substitute(nlme::varIdent(form=F),list(F=as.formula(paste('~1 |',variance))))
  fit$call$correlation=switch(type,Independent=NULL,
    MA1=quote(nlme::corARMA(p=0,q=1,form=~time_index | series)),
    CAR1=quote(nlme::corCAR1(form=~time_centuries | series)))
  fit

}
reconstruction_covariance_status = function(fit) {
  if(!is.matrix(fit$apVar)) return(as.character(fit$apVar))
  if(all(is.finite(fit$apVar)) && min(eigen(fit$apVar,symmetric=TRUE,only.values=TRUE)$values)>0)
    'positive_definite' else 'non_positive_definite'
}
reconstruction_select = function(d,fixed,variance='site',families=c('Independent','MA1','CAR1'),
    primary_family=if('MA1' %in% families) HOLOCENE_PRIMARY_COVARIANCE else families[1L]) {
  row_signature=object_fingerprint(d)
  captured=setNames(lapply(families,function(type) reconstruction_capture(function()
    reconstruction_fit(d,fixed,type,variance))),families)
  audit=purrr::imap_dfr(captured,function(x,type) {
    fit=x$fit
    phi=if(is.null(fit) || is.null(fit$modelStruct$corStruct)) NA_real_ else
      as.numeric(coef(fit$modelStruct$corStruct,unconstrained=FALSE))
    valid=!is.null(fit) && all(is.finite(coef(fit))) && all(is.finite(vcov(fit))) &&
      is.finite(as.numeric(logLik(fit)))
    tibble::tibble(model_type=type,n=nrow(d),row_signature,method='REML',
      converged=valid,AIC=if(valid) AIC(fit) else NA_real_,
      n_covariance_parameters=as.integer(type!='Independent'),
      n_parameters=if(valid) attr(logLik(fit),'df') else NA_integer_,
      correlation_parameter=phi,boundary=if(is.na(phi)) FALSE else
        if(type=='CAR1') phi<1e-4 || phi>1-1e-4 else abs(phi)>1-1e-4,
      covariance_status=if(valid) reconstruction_covariance_status(fit) else 'fit_failed',
      warnings=paste(x$warnings,collapse='; '),fit_error=x$error)
  })
  audit$delta_AIC=if(any(is.finite(audit$AIC))) audit$AIC-min(audit$AIC,na.rm=TRUE) else rep(NA_real_,nrow(audit))
  eligible=audit[audit$converged & is.finite(audit$delta_AIC) & audit$delta_AIC<=2,]
  recommendation=if(nrow(eligible)) eligible$model_type[order(eligible$n_covariance_parameters,eligible$AIC)][1] else NA_character_
  audit$aic_recommended=!is.na(recommendation) & audit$model_type==recommendation
  # MA1 is the user's primary scientific specification, regardless of the AIC
  # comparison. A failed primary fit never silently falls back to another family.
  selected=if(primary_family %in% audit$model_type[audit$converged]) primary_family else NA_character_
  audit$primary_family=primary_family
  audit$selection_policy=if(primary_family=='MA1') 'MA1 primary; other covariance families are comparisons only' else
    'Independent residuals for modern-only models'
  audit$selected=!is.na(selected) & audit$model_type==selected
  list(fit=if(is.na(selected)) NULL else captured[[selected]]$fit,
    data=d,selected=selected,audit=audit,candidates=captured,fixed=fixed,variance=variance)
}
reconstruction_coefficients = function(fit,metric,era,model_type,draw=NA_integer_) {
  tt=summary(fit)$tTable
  df=if(inherits(fit,'lme')) tt[,'DF'] else rep(fit$dims$N-fit$dims$p,nrow(tt))
  margin=qt(.975,df)*tt[,'Std.Error']
  tibble::tibble(metric,era,model_type,draw,term=rownames(tt),estimate=tt[,'Value'],
    std_error=tt[,'Std.Error'],df,p_value=tt[,'p-value'],
    conf_low=tt[,'Value']-margin,conf_high=tt[,'Value']+margin)
}
reconstruction_r2 = function(y,p) {
  denominator=sum((y-mean(y))^2)
  if(denominator>0) 1-sum((y-p)^2)/denominator else NA_real_
}
reconstruction_predictions = function(fit,d) {
  X=model.matrix(formula(fit),d);beta=coef(fit);X=X[,names(beta),drop=FALSE]
  se=sqrt(pmax(0,rowSums((X%*%vcov(fit))*X)))
  predicted=as.numeric(X%*%beta)
  if(max(abs(predicted-as.numeric(fitted(fit))))>1e-9) stop('Fixed prediction mismatch')
  d |> dplyr::mutate(predicted=predicted,prediction_se=se,
    conf_low=predicted-qt(.975,fit$dims$N-fit$dims$p)*se,
    conf_high=predicted+qt(.975,fit$dims$N-fit$dims$p)*se,
    normalized_residual=as.numeric(residuals(fit,type='normalized')),
    raw_residual=estimate-predicted)
}
reconstruction_explanatory_input = function(x,metric,era='Holocene',species=FALSE,extended=FALSE) {
  d=if(species) x[x$species==metric,] else x
  if(species) d$estimate=d$contribution_rate else if(metric %in% names(d)) d$estimate=d[[metric]]
  d$metric=metric;d$era=era
  d$climate_rate=d$standardized_climate_change_rate
  d$site=factor(d$site,levels=c('MORA','NOCA'))
  if(era=='Holocene') {
    d$series=paste('H',d$site,d$lake,sep='_')
    d$time_index=d$transition_index;d$time_centuries=-d$interval_mid_cal_bp/100
    fixed=estimate~site+climate_rate+fire_activity
  } else {
    d$series=paste('A',d$site,d$plot_id,sep='_');d$time_index=0L;d$time_centuries=0
    d$burned=factor(d$burned,levels=c(FALSE,TRUE),labels=c('Unburned','Burned'))
    fixed=if(extended) estimate~site+elevation+climate_rate+burned else estimate~site+burned
  }
  fields=all.vars(fixed)
  good=complete.cases(d[fields])
  for(n in fields) if(is.numeric(d[[n]])) good=good & is.finite(d[[n]])
  excluded=d[!good,];excluded$exclusion=as.character(ifelse(!is.finite(excluded$estimate),
    'undefined_response','missing_predictor_or_fire_coverage'))
  d=d[good,];d=d[order(d$series,d$time_index),]
  list(data=d,excluded=excluded,fixed=fixed)
}
reconstruction_lake_random = function(entry,metric) {
  x=reconstruction_capture(function() nlme::lme(fixed=entry$fixed,random=~1 | series,
    data=entry$data,correlation=reconstruction_correlation(entry$selected),
    weights=nlme::varIdent(form=~1 | site),method='REML',na.action=na.fail,
    control=nlme::lmeControl(msMaxIter=300)))
  fit=x$fit;interval_error=NA_character_
  ci=if(is.null(fit)) NULL else tryCatch(nlme::intervals(fit,which='var-cov'),
    error=function(e){interval_error <<- conditionMessage(e);NULL})
  sd=if(is.null(fit)) NA_real_ else as.numeric(nlme::VarCorr(fit)[1,'StdDev'])
  list(fit=fit,summary=tibble::tibble(metric,model_type=entry$selected,
    converged=!is.null(fit),random_intercept_sd=sd,random_intercept_variance=sd^2,
    max_abs_coefficient_difference=if(is.null(fit)) NA_real_ else max(abs(nlme::fixef(fit)-coef(entry$fit))),
    covariance_status=if(is.null(fit)) 'fit_failed' else reconstruction_covariance_status(fit),
    variance_interval_error=interval_error,variance_intervals_available=!is.null(ci),
    warnings=paste(x$warnings,collapse='; '),fit_error=x$error))
}
reconstruction_model_theme = function() ggplot2::theme_minimal(base_size=17)+
  ggplot2::theme(panel.grid.minor=ggplot2::element_blank(),
    strip.text=ggplot2::element_text(size=17,face='bold'),legend.position='bottom')
reconstruction_coefficient_plot = function(x) {
  x$group=paste(x$era,x$model_type)
  ggplot2::ggplot(x,ggplot2::aes(estimate,group,color=era))+
    ggplot2::geom_vline(xintercept=0,linetype='dashed',color='grey60')+
    ggplot2::geom_errorbar(ggplot2::aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.16)+
    ggplot2::geom_point(size=2.8)+ggplot2::facet_grid(term~metric,scales='free_x',
      labeller=ggplot2::labeller(metric=reconstruction_metric_label))+
    ggplot2::labs(x='Coefficient estimate and 95% confidence interval',y=NULL,color='Era')+
    reconstruction_model_theme()
}
reconstruction_residual_plot = function(x) {
  qq=ggplot2::ggplot(x,ggplot2::aes(sample=normalized_residual))+
    ggplot2::stat_qq(alpha=.45,size=1.1)+ggplot2::stat_qq_line(color='grey35')+
    ggplot2::facet_wrap(~metric+era,scales='free',labeller=ggplot2::labeller(metric=reconstruction_metric_label))+
    ggplot2::labs(x='Normal quantile',y='Normalized residual')+
    reconstruction_model_theme()
  rv=ggplot2::ggplot(x,ggplot2::aes(predicted,normalized_residual,color=site))+
    ggplot2::geom_hline(yintercept=0,color='grey60')+ggplot2::geom_point(alpha=.45,size=1.1)+
    ggplot2::facet_wrap(~metric+era,scales='free',labeller=ggplot2::labeller(metric=reconstruction_metric_label))+
    ggplot2::labs(x='Fitted value',y='Normalized residual')+
    ggplot2::scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'))+reconstruction_model_theme()
  patchwork::wrap_plots(qq,rv,ncol=1)
}
reconstruction_export = function(entries,out,exclusions=tibble::tibble()) {
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  coefficients=predictions=performance=selection=list();text=character()
  for(name in names(entries)) {
    e=entries[[name]]
    selection[[name]]=dplyr::mutate(e$audit,metric=e$metric,era=e$era,specification=e$specification)
    if(is.null(e$fit)) {
      text=c(text,paste(name,'PRIMARY FIT FAILED'),capture.output(print(e$audit)), '');next
    }
    coefficients[[name]]=reconstruction_coefficients(e$fit,e$metric,e$era,e$selected) |>
      dplyr::mutate(specification=e$specification)
    predictions[[name]]=reconstruction_predictions(e$fit,e$data) |>
      dplyr::mutate(model_type=e$selected,specification=e$specification)
    performance[[name]]=tibble::tibble(metric=e$metric,era=e$era,model_type=e$selected,
      specification=e$specification,n=nrow(e$data),R2=reconstruction_r2(e$data$estimate,fitted(e$fit)))
    text=c(text,name,paste('Primary covariance:',e$selected),capture.output(print(e$audit)),
      capture.output(print(summary(e$fit))),paste('Descriptive R2:',performance[[name]]$R2),'')
  }
  tables=list(model_coefficients=dplyr::bind_rows(coefficients),covariance_comparison=dplyr::bind_rows(selection),
    model_performance=dplyr::bind_rows(performance),transition_predictions=dplyr::bind_rows(predictions),
    model_exclusions=exclusions)
  for(name in names(tables)) readr::write_csv(tables[[name]],file.path(out,paste0(name,'.csv')))
  reconstruction_store(entries,file.path(out,'primary_fits.rds'))
  writeLines(c('Primary posterior-median-age reconstruction. Confidence intervals are conditional on this reconstruction.',
    'R2 = 1 - residual sum of squares / total sum of squares; descriptive, not a GLS variance decomposition.',text),
    file.path(out,'model_results.txt'))
  tables
}

reconstruction_sensitivity = function(bundle,primary_entries,kind,out) {
  source(here::here('R/helpers/cca_transition_contributions.R'),local=TRUE)
  dir.create(file.path(out,'chronology_batches'),recursive=TRUE,showWarnings=FALSE)
  holocene=primary_entries[vapply(primary_entries,function(x) x$era=='Holocene',logical(1))]
  signature=object_fingerprint(list(bundle=bundle$signature,rows=bundle$cache$posterior_rows,
    specs=lapply(holocene,function(e) list(metric=e$metric,type=e$selected,fixed=paste(deparse(e$fixed),collapse=""))),
    code=tools::md5sum(here::here(c('R/helpers/reconstruction_models.R','R/helpers/cca_transition_contributions.R',
      'R/helpers/tracking_metrics.R')))))
  batch=function(draw) {
    path=file.path(out,'chronology_batches',sprintf('draw_%04d.rds',draw))
    if(file.exists(path)) {saved=readRDS(path);if(identical(saved$signature,signature)) return(saved)}
    reconstructed=century_reconstruct(bundle,draw)
    values=if(kind=='species') century_species_contributions(reconstructed,bundle) else reconstructed$calculations
    coefficients=status=fits=exclusions=list()
    for(name in names(holocene)) {
      e=holocene[[name]];selected=reconstruction_explanatory_input(values,e$metric,species=kind=='species')
      d=selected$data;exclusions[[name]]=selected$excluded
      result=if(is.na(e$selected)) list(fit=NULL,error='primary_model_unestimable',warnings=character()) else
        reconstruction_capture(function() reconstruction_fit(d,selected$fixed,e$selected))
      fit=result$fit
      phi=if(is.null(fit) || is.null(fit$modelStruct$corStruct)) NA_real_ else
        as.numeric(coef(fit$modelStruct$corStruct,unconstrained=FALSE))
      status[[name]]=tibble::tibble(draw,metric=e$metric,model_type=e$selected,n=nrow(d),
        n_excluded=nrow(selected$excluded),converged=!is.null(fit),
        covariance_status=if(is.null(fit)) 'fit_failed' else reconstruction_covariance_status(fit),
        warnings=paste(result$warnings,collapse='; '),fit_error=result$error,
        R2=if(is.null(fit)) NA_real_ else reconstruction_r2(d$estimate,fitted(fit)),
        correlation_parameter=phi,
        boundary=if(is.na(phi)) FALSE else if(e$selected=='CAR1') phi<1e-4 || phi>1-1e-4 else abs(phi)>1-1e-4)
      if(!is.null(fit)) {
        coefficients[[name]]=reconstruction_coefficients(fit,e$metric,'Holocene',e$selected,draw)
        fits[[name]]=fit
      }
    }
    support=reconstructed$calculations |> dplyr::group_by(site,lake) |> dplyr::summarise(
      draw=.env$draw,n_occupied_centuries=dplyr::n()+1L,n_transitions=dplyr::n(),
      n_gaps_over_100=sum(vegetation_dt_years>100),duration_min=min(vegetation_dt_years),
      duration_median=median(vegetation_dt_years),duration_max=max(vegetation_dt_years),
      n_fire_coverage_losses=sum(!fire_coverage_valid),.groups='drop')
    saved=list(signature=signature,draw=draw,coefficients=dplyr::bind_rows(coefficients),
      status=dplyr::bind_rows(status),support=support,fits=fits,exclusions=dplyr::bind_rows(exclusions),
      calculations=if(kind=='community') reconstructed$calculations else NULL,
      species=if(kind=='species') values else NULL,fire_core=reconstructed$fire$core)
    reconstruction_store(saved,path);saved
  }
  # Processes run independent, deterministic whole chronologies. They share no
  # writers: every draw has its own fingerprinted checkpoint file.
  workers=4L
  collected=list()
  for(start in seq(1L,HOLOCENE_RECONSTRUCTION_DRAWS,by=20L)) {
    draws=seq(start,min(start+19L,HOLOCENE_RECONSTRUCTION_DRAWS))
    records=parallel::mclapply(draws,batch,mc.cores=workers,mc.set.seed=FALSE)
    if(any(vapply(records,inherits,logical(1),'try-error'))) stop('Chronology batch failed: ',start,'; ',paste(unique(vapply(records,function(x) if(inherits(x,'try-error')) as.character(x) else '',character(1))),collapse='; '))
    collected=c(collected,lapply(records,function(x) x[c('coefficients','status','support')]))
    cat(kind,'chronology sensitivity:',max(draws),'/',HOLOCENE_RECONSTRUCTION_DRAWS,'\n');flush.console()
  }
  co=dplyr::bind_rows(lapply(collected,`[[`,'coefficients'))
  status=dplyr::bind_rows(lapply(collected,`[[`,'status'))
  support=dplyr::bind_rows(lapply(collected,`[[`,'support'))
  if(nrow(status)!=length(holocene)*HOLOCENE_RECONSTRUCTION_DRAWS || anyDuplicated(status[c('draw','metric')]))
    stop('Missing or duplicate chronology fit outcomes')
  primary=purrr::map_dfr(holocene,function(e) if(is.null(e$fit)) tibble::tibble() else
    reconstruction_coefficients(e$fit,e$metric,e$era,e$selected)) |>
    dplyr::select(metric,term,primary_estimate=estimate,primary_conf_low=conf_low,primary_conf_high=conf_high)
  summary=co |> dplyr::left_join(primary,by=c('metric','term'),relationship='many-to-one') |>
    dplyr::group_by(metric,term) |> dplyr::summarise(n_expected=HOLOCENE_RECONSTRUCTION_DRAWS,
      n_successful_fits=dplyr::n(),n_valid_intervals=sum(is.finite(conf_low)&is.finite(conf_high)),
      primary_estimate=dplyr::first(primary_estimate),primary_conf_low=dplyr::first(primary_conf_low),
      primary_conf_high=dplyr::first(primary_conf_high),median=median(estimate),q025=quantile(estimate,.025),
      q975=quantile(estimate,.975),minimum=min(estimate),maximum=max(estimate),
      proportion_positive=mean(estimate>0),proportion_negative=mean(estimate<0),proportion_zero=mean(estimate==0),
      sign_agreement=mean(sign(estimate)==sign(primary_estimate)),
      proportion_interval_positive=mean((conf_low>0)[is.finite(conf_low)&is.finite(conf_high)]),
      proportion_interval_negative=mean((conf_high<0)[is.finite(conf_low)&is.finite(conf_high)]),
      proportion_interval_includes_zero=mean((conf_low<=0 & conf_high>=0)[is.finite(conf_low)&is.finite(conf_high)]),
      support_agreement=mean((ifelse(conf_low>0,1,ifelse(conf_high<0,-1,0))==
        ifelse(primary_conf_low>0,1,ifelse(primary_conf_high<0,-1,0)))[
          is.finite(conf_low)&is.finite(conf_high)]),.groups='drop')
  for(name in c('coefficients','status','support','summary')) readr::write_csv(
    switch(name,coefficients=co,status=status,support=support,summary=summary),
    file.path(out,paste0('chronology_',name,'.csv')))
  list(coefficients=co,status=status,support=support,summary=summary,signature=signature)
}
reconstruction_sensitivity_plot = function(x) {
  availability=x$status |> dplyr::group_by(metric) |> dplyr::summarise(
    successful=sum(converged),requested=dplyr::n(),.groups='drop')
  labels=setNames(paste0(reconstruction_metric_label(availability$metric),'\n',availability$successful,' / ',availability$requested,
    ' successful fits'),availability$metric)
  ggplot2::ggplot(x$coefficients,ggplot2::aes(estimate,term))+
    ggplot2::geom_blank(data=availability,ggplot2::aes(x=NA_real_,y='(Intercept)'),inherit.aes=FALSE)+
    ggplot2::geom_vline(xintercept=0,linetype='dashed',color='grey60')+
    ggplot2::geom_boxplot(fill='grey85',outlier.shape=NA,width=.5)+
    ggplot2::geom_errorbar(data=x$summary,ggplot2::aes(x=primary_estimate,xmin=primary_conf_low,xmax=primary_conf_high),
      orientation='y',width=.12,color='#2563eb')+
    ggplot2::geom_point(data=x$summary,ggplot2::aes(x=primary_estimate),color='#2563eb',size=2.5)+
    ggplot2::facet_wrap(~metric,scales='free_x',labeller=ggplot2::as_labeller(labels))+
    ggplot2::labs(x='Chronology-reconstruction sensitivity; blue: primary estimate and conditional 95% CI',y=NULL)+
    reconstruction_model_theme()
}
