# Covariance comparison and selected MA1 results: one transition offset per fit.
# Default: observed and two corrected lag rates, turnover and physical climate rate.
# --metric=NAME selects one response; no response transformation is applied.
# Rscript R/stages/12_tracking_era_models.R [--metric=observed_turnover_rate]
# Optional later width experiments: --bin-width-years=N; never run automatically.
# Same fixed effects and variance groups for AR1, MA1 and independent residuals.
suppressPackageStartupMessages({
  library(here);library(tidyverse);library(nlme);library(emmeans);library(patchwork)
})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
argument=function(name,default) {
  prefix=paste0('--',name,'=')
  found=commandArgs(trailingOnly=TRUE)
  found=found[startsWith(found,prefix)]
  if(length(found)>1L) stop('Specify ',name,' once')
  if(length(found)) substring(found,nchar(prefix)+1L) else default
}
response_metrics=trimws(strsplit(argument('metric',paste(tracking_model_response_names(),collapse=',')),
  ',',fixed=TRUE)[[1]])
if(!length(response_metrics) || any(!response_metrics %in% tracking_model_available_names()) ||
   anyDuplicated(response_metrics)) stop('Specify distinct known responses with --metric')
width=validate_tracking_width(as.numeric(argument('bin-width-years','1000')))
suffix=if(width==1000L) '' else paste0('_',width,'yr')
input_path=here('output',paste0('cca_tracking_era_by_offset',suffix,'.csv'))
combined=read_csv(input_path,show_col_types=FALSE)
if(validate_tracking_model_data(combined)!=width) stop('Requested interval width differs from input')
offsets=seq(0,width-100,100)
model_types=c('AR1','MA1','Independent')
selected_model_type=tracking_selected_model_type()

for(response_metric in response_metrics) {
  response_label=tracking_model_response_label(response_metric)
  response_unit=tracking_model_response_unit(response_metric)

  fit_offset=function(offset,model_type) {
    selected=tracking_offset_model_input(combined,response_metric,offset)
    d=selected$data
    correlation=switch(model_type,
      AR1=corAR1(form=~time_index | series),
      MA1=corARMA(p=0,q=1,form=~time_index | series),
      Independent=NULL,stop('Unknown covariance model'))
    warnings=character()
    fit=withCallingHandlers(
      gls(estimate ~ era * site,data=d,correlation=correlation,
        weights=varIdent(form=~1 | era_site),method='REML',na.action=na.fail,
        control=glsControl(msMaxIter=200)),
      warning=function(w) {warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
    summary_fit=summary(fit)
    tt=summary_fit$tTable
    df=fit$dims$N-fit$dims$p
    ci=qt(.975,df)*tt[,'Std.Error']
    parameters=if(is.null(fit$modelStruct$corStruct)) numeric() else
      unname(coef(fit$modelStruct$corStruct,unconstrained=FALSE))
    if(length(parameters)!=as.integer(model_type!='Independent') ||
       any(!is.finite(parameters)) || any(!is.finite(tt)) || !is.finite(as.numeric(logLik(fit))))
      stop('Invalid fitted numerical results')
    parameter=if(length(parameters)) parameters else NA_real_
    coefficients=tibble(metric=response_metric,offset,model_type,term=rownames(tt),
      estimate=tt[,'Value'],std_error=tt[,'Std.Error'],df,
      t_value=tt[,'t-value'],p_value=tt[,'p-value'],
      conf_low=tt[,'Value']-ci,conf_high=tt[,'Value']+ci,
      n_holocene=sum(d$era=='Holocene'),n_anthropocene=sum(d$era=='Anthropocene'),
      correlation_parameter=parameter,converged=TRUE)
    residuals=d
    residuals$fitted=as.numeric(fitted(fit))
    residuals$normalized_residual=as.numeric(stats::residuals(fit,type='normalized'))
    h=residuals[residuals$era=='Holocene',]
    scale=mean(h$normalized_residual^2)
    lag_products=map_dfr(1:3,function(lag) {
      j=match(paste(h$series,h$time_index+lag),paste(h$series,h$time_index))
      keep=!is.na(j)
      tibble(lag,lag_years=lag*width,n_pairs=sum(keep),
        lag_product=if(any(keep) && scale>0)
          mean(h$normalized_residual[keep]*h$normalized_residual[j[keep]])/scale else NA_real_)
    })
    means=emmeans(fit,~era | site,data=d,mode='satterthwaite')
    mt=as.data.frame(summary(means,infer=c(TRUE,FALSE)))
    mean_table=tibble(metric=response_metric,offset,model_type,site=as.character(mt$site),
      era=as.character(mt$era),estimate=mt$emmean,std_error=mt$SE,df=mt$df,
      conf_low=mt$lower.CL,conf_high=mt$upper.CL,
      n=vapply(seq_len(nrow(mt)),function(i) sum(d$site==mt$site[i] & d$era==mt$era[i]),integer(1)))
    contrasts=contrast(means,method=list('Anthropocene - Holocene'=c(-1,1)))
    ct=as.data.frame(summary(contrasts,infer=c(TRUE,TRUE),adjust='none'))
    contrast_table=tibble(metric=response_metric,offset,model_type,site=as.character(ct$site),
      contrast=as.character(ct$contrast),estimate=ct$estimate,std_error=ct$SE,df=ct$df,
      t_value=ct$t.ratio,p_value=ct$p.value,conf_low=ct$lower.CL,conf_high=ct$upper.CL,
      n_holocene=vapply(as.character(ct$site),function(s) sum(d$era=='Holocene' & d$site==s),integer(1)),
      n_anthropocene=vapply(as.character(ct$site),function(s) sum(d$era=='Anthropocene' & d$site==s),integer(1)))
    counts=as.data.frame(table(d$era,d$site))
    names(counts)=c('era','site','n')
    variance=coef(fit$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
    block=c(paste0('OFFSET ',offset,' | MODEL ',model_type),
      paste('Selected rows:',nrow(d)+nrow(selected$excluded),
        '| Finite rows:',nrow(d),'| Undefined selected responses:',nrow(selected$excluded)),
      if(model_type=='Independent') 'Temporal correlation: none; era/site residual variances retained' else
        paste('Correlation parameter:',format(parameter,digits=8),
          if(model_type=='AR1') '(phi; lag-1 correlation)' else
            paste0('(theta; lag-1 correlation = ',format(parameter/(1+parameter^2),digits=8),')')),
      paste('Warnings:',if(length(warnings)) paste(unique(warnings),collapse='; ') else 'none'),
      capture.output(print(counts)),capture.output(print(summary_fit)),
      'Era means within each park:',capture.output(summary(means,infer=c(TRUE,FALSE))),
      'Anthropocene - Holocene within each park (unadjusted exploratory contrasts):',
      capture.output(summary(contrasts,infer=c(TRUE,TRUE),adjust='none')),
      'Residual SDs:',capture.output(print(fit$sigma*variance)),
      'Holocene normalized residual lag products (diagnostic, not significance tests):',
      capture.output(print(lag_products)),
      if(nrow(selected$excluded)) c('Undefined response identities:',
        capture.output(print(selected$excluded[c('era','site','lake','plot_id','age_hi','age_lo')]))),
      '')
    list(fit=fit,data=d,coefficients=coefficients,means=mean_table,contrasts=contrast_table,residuals=residuals,
      lag_products=lag_products,text=block,offset=offset,model_type=model_type)
  }

  # Calculate every fit before replacing results. A failed fit stops with its key;
  # it never changes observation selection or silently omits an offset/model type.
  fits=list()
  for(offset in offsets) for(model_type in model_types) {
    cat('Fitting',response_metric,'| offset',offset,'|',model_type,'\n')
    fits[[paste(offset,model_type,sep='_')]]=tryCatch(fit_offset(offset,model_type),
      error=function(e) stop('Offset ',offset,' / ',model_type,': ',conditionMessage(e),call.=FALSE))
  }
  coefficients=bind_rows(purrr::map(fits,'coefficients'))
  contrasts=bind_rows(purrr::map(fits,'contrasts'))
  group_means=tracking_selected_model_results(bind_rows(purrr::map(fits,'means')))
  if(nrow(group_means)!=length(offsets)*4L ||
     anyDuplicated(group_means[c('metric','offset','model_type','site','era')]) ||
     any(!is.finite(as.matrix(group_means[c('estimate','std_error','df','conf_low','conf_high')]))))
    stop('Missing, duplicate or undefined selected-model group means')
  if(anyDuplicated(coefficients[c('metric','offset','model_type','term')]) ||
     nrow(coefficients)!=length(offsets)*length(model_types)*4L)
    stop('Missing or duplicate fitted coefficients')
  if(anyDuplicated(contrasts[c('metric','offset','model_type','site')]) ||
     nrow(contrasts)!=length(offsets)*length(model_types)*2L ||
     any(!is.finite(contrasts$estimate) | !is.finite(contrasts$std_error)))
    stop('Missing, duplicate or undefined park contrasts')
  # AIC comparisons require identical observations and fixed effects within an
  # offset. Different offsets remain sensitivity fits with different input rows.
  for(offset in offsets) {
    group=fits[paste(offset,model_types,sep='_')]
    if(!all(vapply(group,function(x) identical(x$data,group[[1]]$data),logical(1))))
      stop('Covariance models use different observations at offset ',offset)
  }
  fit_overview=map_dfr(fits,function(x) tibble(metric=response_metric,offset=x$offset,
    model_type=x$model_type,n_holocene=sum(x$data$era=='Holocene'),
    n_anthropocene=sum(x$data$era=='Anthropocene'),n=nrow(x$data),method=x$fit$method,
    n_parameters=attr(logLik(x$fit),'df'),log_likelihood=as.numeric(logLik(x$fit)),AIC=AIC(x$fit),
    correlation_parameter=x$coefficients$correlation_parameter[1],converged=TRUE)) |>
    group_by(offset) |> mutate(delta_AIC=AIC-min(AIC),
      akaike_weight=exp(-delta_AIC/2)/sum(exp(-delta_AIC/2)),aic_rank=min_rank(AIC)) |>
    ungroup() |> select(metric,offset,model_type,n_holocene,n_anthropocene,n,method,
      n_parameters,log_likelihood,AIC,delta_AIC,akaike_weight,aic_rank,correlation_parameter,converged)
  notes=c('MA1 covariance selected by the author on 2026-10-09; model development and inference remain exploratory.',
    paste('Response:',response_metric,'| Holocene interval / time step:',width,'years'),
    paste('Response units:',response_unit,'| Transformation: none'),
    'Fixed effects: estimate ~ era * site; REML; separate residual SDs by era/site.',
    'Reference categories: Holocene and MORA. Coefficient units follow the selected response.',
    'AR1: corAR1(~ time_index | series). MA1: corARMA(p=0, q=1, ~ time_index | series).',
    'Independent: correlation=NULL; the same era/site residual SDs and fixed effects are retained.',
    'MA1 correlates only observations one actual time step apart within a series; gaps are retained.',
    'For MA1, theta is not the lag-1 correlation: rho(1) = theta/(1 + theta^2); rho(k)=0 for k>1.',
    'Each fit uses one offset and all original modern pairs with a finite selected response.',
    'Modern pairs are singleton series; their internal time index is 0 and their actual dates are retained.',
    'Offsets are sensitivity realizations; the same modern data are reused, so fits are not independent.',
    'Holocene responses are finite chronology-draw medians within actual transitions, without offset aggregation.',
    'Corrected lag rates use (corrected final lag - initial lag)*100/climate elapsed years within each draw before summarizing.',
    'Pace correction remains magnitude-based. Its undefined directions exclude only the pace-corrected response.',
    'No chronology uncertainty propagation, lake random intercept, climate/fire fixed effects or support threshold.',
    'Adjacent Holocene transitions share endpoints; only four lakes and two fire histories are available.',
    'AIC comparisons are meaningful between covariance types within the same offset, not across offsets.',
    'Delta AIC is measured from the minimum within each offset; Akaike weights are relative to these three candidates only.',
    'Boxplots show within-offset delta AIC and summarize offset sensitivity, not independent samples; raw AIC remains in the CSV.',
    'REML is retained because these covariance comparisons use identical fixed effects and observations within each offset.',
    'The comparison retains all candidates; reported coefficients, contrasts and residuals use the author-selected MA1.',
    'The MA1 reporting specification is applied to every requested response; covariance comparisons and diagnostics are response-specific.',
    'Group means and era contrasts use emmeans with Satterthwaite degrees of freedom; contrast SEs use the fitted covariance of the means.',
    'Coefficient intervals and park contrasts are unadjusted exploratory intervals/tests.',
    paste('Input:',basename(input_path),'| MD5:',unname(tools::md5sum(input_path))),
    paste('Script MD5:',unname(tools::md5sum(here('R/stages/12_tracking_era_models.R')))),
    paste('Packages:',paste(sapply(c('nlme','emmeans'),function(p)
      paste(p,as.character(packageVersion(p)))),collapse='; ')))
  out=here('output/exploratory/tracking_offset_models',paste0(response_metric,suffix))
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  write_csv(coefficients,file.path(out,'model_coefficients.csv'))
  write_csv(contrasts,file.path(out,'model_contrasts.csv'))
  write_csv(fit_overview,file.path(out,'model_comparison.csv'))
  write_csv(group_means,file.path(out,'model_group_means.csv'))
  writeLines(c(notes,'','Fit overview:',capture.output(print(as.data.frame(fit_overview),
    digits=8,row.names=FALSE)), '',
    unlist(purrr::map(fits,'text')),capture.output(sessionInfo())),file.path(out,'model_results.txt'))

  # Only the selected covariance is presented after the comparison figure.
  model_colors=tracking_model_colors()
  plot_coefficients=tracking_selected_model_results(coefficients)
  plot_contrasts=tracking_selected_model_results(contrasts)
  selected_fits=fits[vapply(fits,function(x) x$model_type==selected_model_type,logical(1))]
  means_plot=tracking_model_group_means_plot(group_means,plot_contrasts,response_metric,offsets)
  coef_plot=ggplot(plot_coefficients,aes(offset,estimate))+
    geom_hline(yintercept=0,color='grey65',linetype='dashed')+
    geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=20,
      color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_line(color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_point(color=unname(model_colors[selected_model_type]),size=2.8)+
    facet_wrap(~term,scales='free_y',ncol=2)+
    scale_x_continuous(breaks=offsets)+
    labs(title=paste('MA(1) coefficients:',response_label),
      subtitle=paste(length(offsets),'offsets; era × site; REML and separate era/site residual variances'),
      x='Bin offset (years)',y='Coefficient estimate',
      caption='Points: coefficients; bars: unadjusted 95% t intervals. Reference: Holocene / MORA.\nOffsets reuse the same modern pairs and are sensitivity fits, not independent replicates.')+
    tracking_model_plot_theme()+theme(
      axis.text.x=element_text(angle=45,hjust=1))
  contrast_plot=ggplot(plot_contrasts,aes(offset,estimate))+
    geom_hline(yintercept=0,color='grey65',linetype='dashed')+
    geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=20,
      color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_line(color=unname(model_colors[selected_model_type]),linewidth=.6)+
    geom_point(color=unname(model_colors[selected_model_type]),size=2.8)+
    facet_wrap(~site,scales='free_y',nrow=1)+
    scale_x_continuous(breaks=offsets)+
    labs(title=paste('MA(1) era contrasts:',response_label),
      subtitle='Anthropocene minus Holocene within each park; selected MA(1) at every offset',
      x='Bin offset (years)',y='Anthropocene - Holocene',
      caption='Points: model-based era contrasts; bars: unadjusted 95% intervals with Satterthwaite degrees of freedom.\nPositive estimates indicate higher Anthropocene responses. Parks have separate y-scales. Offsets reuse modern pairs and are sensitivity fits.')+
    tracking_model_plot_theme()+theme(
      axis.text.x=element_text(angle=45,hjust=1))

  # Pair each offset's three comparisons. Deterministic point displacement keeps
  # identical-offset pairs visible without treating them as independent samples.
  aic_data=fit_overview |> mutate(model_index=match(model_type,model_types),
    point_x=model_index+(match(offset,offsets)-(length(offsets)+1)/2)/
      max(1,length(offsets)-1)*.24)
  aic_plot=ggplot(aic_data,
    aes(model_index,delta_AIC,group=model_type,fill=model_type))+
    geom_hline(yintercept=0,color='grey55',linetype='dashed')+
    geom_boxplot(width=.48,alpha=.2,outlier.shape=NA,color='grey45')+
    geom_line(aes(x=point_x,group=offset),color='grey65',alpha=.6,linewidth=.4)+
    geom_point(aes(x=point_x,color=model_type),size=2.4)+
    scale_x_continuous(breaks=seq_along(model_types),labels=c('AR(1)','MA(1)','No temporal\nautocorrelation'))+
    scale_color_manual(values=model_colors)+scale_fill_manual(values=model_colors)+
    labs(title=paste('Within-offset covariance comparison:',response_label),
      subtitle=paste(length(offsets),'offsets; same observations, fixed effects, REML and era/site residual variances within each offset'),
      x=NULL,y='AIC - minimum AIC within offset (lower is better)',
      caption='Zero identifies the lowest AIC within each offset. Boxes summarize offsets; dots are fits; grey lines connect the same offset.\nOffsets reuse modern plots and are sensitivity fits, not independent replicates. Raw AIC values remain in model_comparison.csv.\nMA(1) is the requested reporting structure. Assess covariance support separately for each response using this comparison.')+
    theme_minimal(base_size=12)+theme(legend.position='none',panel.grid.minor=element_blank(),
      plot.title=element_text(size=17,face='bold'),plot.subtitle=element_text(size=11),
      plot.caption=element_text(size=10,hjust=0))
  group_colors=c(Holocene.MORA='#059669',Anthropocene.MORA='#2563eb',
    Holocene.NOCA='#c97710',Anthropocene.NOCA='#d42d75')
  residual_panels=list()
  for(x in selected_fits) {
    tag=paste('Offset',x$offset,'|',x$model_type)
    common=theme_minimal(base_size=8)+theme(legend.position='none',
      plot.title=element_text(size=9,face='bold'),plot.subtitle=element_text(size=7))
    p1=ggplot(x$residuals,aes(fitted,normalized_residual,color=era_site))+
      geom_hline(yintercept=0,color='grey65')+geom_point(alpha=.35,size=.5)+
      scale_color_manual(values=group_colors)+
      labs(title=tag,subtitle='Normalized residuals versus fitted',x='Fitted',y='Normalized residual')+common
    qq=x$residuals[order(x$residuals$normalized_residual),]
    qq$theoretical=qnorm(ppoints(nrow(qq)))
    p2=ggplot(qq,aes(theoretical,normalized_residual,color=era_site))+
      geom_abline(intercept=0,slope=1,color='grey50')+geom_point(alpha=.4,size=.5)+
      scale_color_manual(values=group_colors)+
      labs(title=tag,subtitle='Normal Q-Q; pooled normalized residuals',x='Normal quantile',y='Normalized residual')+common
    p3=ggplot(x$lag_products,aes(lag,lag_product))+
      geom_hline(yintercept=0,color='grey65')+
      geom_segment(aes(xend=lag,yend=0),color=unname(model_colors[x$model_type]))+
      geom_point(color=unname(model_colors[x$model_type]),size=1)+
      geom_text(aes(label=paste0('n=',n_pairs)),vjust=-.7,size=2)+
      scale_x_continuous(breaks=1:3)+
      labs(title=tag,subtitle='Holocene residual lag products',x=paste0('Lag (',width,'-year steps)'),y='Lag product')+common
    residual_panels=c(residual_panels,list(p1,p2,p3))
  }
  residual_plot=wrap_plots(residual_panels,ncol=3)+plot_annotation(
    title=paste('MA(1) offset-model residual checks:',response_label),
    subtitle='One row per offset: scatter / Q-Q / Holocene lag products for the selected MA(1)',
    caption='Colors: Holocene MORA green, Holocene NOCA orange, Anthropocene MORA blue, Anthropocene NOCA pink.\nHolocene lag products match actual within-lake time gaps; labels give pair counts. Modern singletons are excluded. No formal lag tests or confidence bands.\nMA(1) selected; distribution and inference remain exploratory. Chronology uncertainty is not propagated.',
    theme=theme(plot.title=element_text(size=18,face='bold'),plot.subtitle=element_text(size=11),
      plot.caption=element_text(size=10,hjust=0)))
  figure_stem=paste0(response_metric,suffix)
  if(render_figures) {
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_group_means_',figure_stem,'.pdf')),
      means_plot,width=14,height=11)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_coefficients_',figure_stem,'.pdf')),
      coef_plot,width=13,height=9)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_contrasts_',figure_stem,'.pdf')),
      contrast_plot,width=13,height=7)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_residuals_',figure_stem,'.pdf')),
      residual_plot,width=12,height=2.6*length(offsets)+1.5,limitsize=FALSE)
    ggsave(here('plot/test_figures',paste0('fig_tracking_model_aic_',figure_stem,'.pdf')),
      aic_plot,width=13,height=7)
  }
  cat('Saved',length(fits),'comparison fits; MA1 reported;',nrow(coefficients),'coefficient rows and',
    nrow(contrasts),'park contrasts in',out,'\n')
}
