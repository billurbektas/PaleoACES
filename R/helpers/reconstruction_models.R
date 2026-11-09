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
# report-snippet: gls-covariance
reconstruction_correlation = function(type) switch(type,
  Independent=NULL,MA1=nlme::corARMA(p=0,q=1,form=~time_index | series),
  CAR1=nlme::corCAR1(form=~time_centuries | series),stop('Unknown covariance family'))
# end-snippet: gls-covariance
reconstruction_fit = function(d,fixed,type,variance='site') {
  X=model.matrix(fixed,d)
  if(nrow(X)<=ncol(X) || qr(X)$rank<ncol(X)) stop('rank_deficient')
  if(!is.finite(var(d$estimate)) || var(d$estimate)==0) stop('constant_response')
  if(any(table(droplevels(d$site))<2L)) stop('insufficient_site_observations')
  # With a group intercept and varIdent, a constant group permits its residual
  # variance to approach zero and the likelihood is unbounded. Keep observations
  # and report this structural limitation instead of a spurious optimizer fit.
  groups=if(is.null(variance)) rep('within_site',nrow(d)) else if(variance=='era_site') d$era_site else d[[variance]]
  if(any(vapply(split(d$estimate,groups),function(y) length(y)>1L && var(y)==0,logical(1))))
    stop('constant_variance_group: no finite heteroscedastic Gaussian optimum')
# report-snippet: gls-fit
  fit=nlme::gls(fixed,data=d,correlation=reconstruction_correlation(type),
    weights=if(is.null(variance)) NULL else nlme::varIdent(form=as.formula(paste('~1 |',variance))),method='REML',
    na.action=na.fail,control=nlme::glsControl(msMaxIter=300))
# end-snippet: gls-fit
  # Store evaluable model/covariance calls for emmeans covariance derivatives.
  fit$call$model=fixed
  fit$call$weights=if(is.null(variance)) NULL else substitute(nlme::varIdent(form=F),list(F=as.formula(paste('~1 |',variance))))
  fit$call$correlation=switch(type,Independent=NULL,
    MA1=quote(nlme::corARMA(p=0,q=1,form=~time_index | series)),
    CAR1=quote(nlme::corCAR1(form=~time_centuries | series)))
  fit

}
reconstruction_covariance_status = function(fit) {
  if(is.null(fit$apVar) && length(fit$modelStruct)==0L) return('not_applicable_no_covariance_parameters')
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
reconstruction_explanatory_input = function(x,metric,era='Holocene',species=FALSE,extended=FALSE,within_site=NULL,fixed_override=NULL) {
  d=if(species) x[x$species==metric,] else x
  if(!is.null(within_site)) d=d[d$site==within_site,]
  if(species) d$estimate=d$contribution_rate else if(metric %in% names(d)) d$estimate=d[[metric]]
  d$metric=metric;d$era=era
  d$climate_rate=d$standardized_climate_change_rate
  d$site=factor(d$site,levels=c('MORA','NOCA'))
# report-snippet: predictor-formulas
  if(era=='Holocene') {
    if('burned' %in% names(d)) d$burned=factor(rep(NA_character_,nrow(d)),levels=c('Unburned','Burned'))
    d$series=paste('H',d$site,d$lake,sep='_')
    d$time_index=d$transition_index;d$time_centuries=-d$interval_mid_cal_bp/100
    fixed=estimate~site+climate_rate+fire_activity
  } else {
    d$series=paste('A',d$site,d$plot_id,sep='_');d$time_index=0L;d$time_centuries=0
    d$burned=factor(d$burned,levels=c(FALSE,TRUE),labels=c('Unburned','Burned'))
    fixed=if(extended) estimate~site+elevation+climate_rate+burned else estimate~site+burned
  }
# end-snippet: predictor-formulas
  if(!is.null(within_site)) fixed=update(fixed,~ . - site)
  if(!is.null(fixed_override)) fixed=fixed_override
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
    if(!is.null(e$site)) selection[[name]]$site=e$site
    if(is.null(e$fit)) {
      text=c(text,paste(name,'PRIMARY FIT FAILED'),capture.output(print(e$audit)), '');next
    }
    coefficients[[name]]=reconstruction_coefficients(e$fit,e$metric,e$era,e$selected) |>
      dplyr::mutate(specification=e$specification)
    predictions[[name]]=reconstruction_predictions(e$fit,e$data) |>
      dplyr::mutate(model_type=e$selected,specification=e$specification)
    performance[[name]]=tibble::tibble(metric=e$metric,era=e$era,model_type=e$selected,
      specification=e$specification,n=nrow(e$data),R2=reconstruction_r2(e$data$estimate,fitted(e$fit)))
    if(!is.null(e$site)) {coefficients[[name]]$site=e$site;performance[[name]]$site=e$site}
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

