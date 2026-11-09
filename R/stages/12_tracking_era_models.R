# Primary combined-era GLS: compare covariance candidates on identical rows.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(emmeans);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
combined=read_csv(out('cca_tracking_era_model_input.csv'),show_col_types=FALSE)
validate_tracking_model_data(combined)
figure_pages=list()
for(metric in tracking_model_response_names()) {
  selected=tracking_primary_model_input(combined,metric)
  entry=reconstruction_select(selected$data,estimate~era*site,variance='era_site')
  if(is.null(entry$fit)) stop('All combined-era covariance fits failed: ',metric)
  entry$metric=metric;entry$era='Combined';entry$specification='era_by_site'
  results_dir=file.path(out('era_comparison'),metric)
  tables=reconstruction_export(list(primary=entry),results_dir,selected$excluded)
  means=emmeans(entry$fit,~era | site,data=entry$data,mode='satterthwaite')
  mt=as.data.frame(summary(means,infer=c(TRUE,FALSE)))
  group_means=as_tibble(mt) |> transmute(metric=metric,model_type=entry$selected,site,era,
    estimate=emmean,std_error=SE,df,conf_low=lower.CL,conf_high=upper.CL,
    n=map2_int(as.character(site),as.character(era),~sum(entry$data$site==.x & entry$data$era==.y)))
  ct=as.data.frame(summary(contrast(means,method=list('Anthropocene - Holocene'=c(-1,1))),
    infer=c(TRUE,TRUE),adjust='none'))
  contrasts=as_tibble(ct) |> transmute(metric=metric,model_type=entry$selected,site,contrast,
    estimate,std_error=SE,df,p_value=p.value,conf_low=lower.CL,conf_high=upper.CL)
  write_csv(group_means,file.path(results_dir,'model_group_means.csv'))
  write_csv(contrasts,file.path(results_dir,'model_contrasts.csv'))
  cat(capture.output(print(group_means)),capture.output(print(contrasts)),sep='\n',
    file=file.path(results_dir,'model_results.txt'),append=TRUE)
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
    theme=reconstruction_model_theme()
    gp=ggplot(group_means,aes(era,estimate,color=site,group=site))+
      geom_line()+geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.1)+geom_point(size=3)+
      facet_wrap(~site)+scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'))+
      labs(x=NULL,y=tracking_model_response_unit(metric),title=tracking_model_response_label(metric))+theme
    cp=ggplot(contrasts,aes(site,estimate,color=site))+geom_hline(yintercept=0,linetype='dashed',color='grey60')+
      geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.12)+geom_point(size=3)+
      scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'))+
      labs(x=NULL,y='Anthropocene - Holocene',title=tracking_model_response_label(metric))+theme
    ap=ggplot(entry$audit,aes(model_type,delta_AIC,fill=selected))+geom_col(width=.55)+
      geom_hline(yintercept=2,linetype='dashed',color='grey50')+
      scale_fill_manual(values=c('TRUE'='#648FFF','FALSE'='grey80'),guide='none')+
      labs(x='Residual covariance',y='Delta REML AIC',
        subtitle='MA(1) is primary. Independent and CAR1 are comparisons only.\nAll candidates use identical observations and fixed effects.')+theme
    figures=list(group_means=gp,coefficients=reconstruction_coefficient_plot(tables$model_coefficients)+
      labs(title=tracking_model_response_label(metric),subtitle='Primary MA(1): era × site')+
      theme(legend.position='none',axis.text.y=element_blank(),axis.ticks.y=element_blank()),
      contrasts=cp,residuals=reconstruction_residual_plot(tables$transition_predictions),aic=ap)
    for(name in names(figures)) figure_pages[[name]]=c(figure_pages[[name]],list(figures[[name]]))
  }
}
for(name in names(figure_pages)) tracking_pdf_pages(figure_pages[[name]],
  tracking_model_figure(paste0('fig_tracking_model_',name,'.pdf')),
  width=12,height=if(name=='residuals') 10 else if(name=='coefficients') 12 else 6)

# Additional joint correction model; the five separate response models above
# keep their own valid observations and are not replaced by this paired fit.
paired=tracking_joint_correction_input(combined)
d=paired$data
joint_out=out('era_comparison/joint_correction_effects')
dir.create(joint_out,recursive=TRUE,showWarnings=FALSE)
write_csv(d,file.path(joint_out,'model_input.csv'))
captured=reconstruction_capture(function() {
  fit=gls(estimate~era*site*correction,data=d,correlation=corPairedMA1(),
    weights=varIdent(form=~1 | era_site_correction),method='REML',na.action=na.fail,
    control=glsControl(msMaxIter=500))
  fit$call$model=estimate~era*site*correction
  fit$call$correlation=quote(corPairedMA1())
  fit$call$weights=quote(nlme::varIdent(form=~1 | era_site_correction))
  fit
})
fit=captured$fit
valid=!is.null(fit) && all(is.finite(coef(fit))) && all(is.finite(vcov(fit)))
parameters=if(valid) coef(fit$modelStruct$corStruct,unconstrained=FALSE) else rep(NA_real_,5)
audit=tibble(model_type='Paired_MA1',n=nrow(d),n_paired_units=nrow(d)/2,
  row_signature=object_fingerprint(d),method='REML',converged=valid,
  AIC=if(valid) AIC(fit) else NA_real_,n_covariance_parameters=5L,
  n_parameters=if(valid) attr(logLik(fit),'df') else NA_integer_,
  correlation_parameter=parameters[1],boundary=any(abs(parameters)>1-1e-4,na.rm=TRUE),
  covariance_status=if(valid) reconstruction_covariance_status(fit) else 'fit_failed',
  warnings=paste(captured$warnings,collapse='; '),fit_error=captured$error,
  selected=valid,selection_policy='Paired corrections with primary MA(1) temporal covariance')
entry=list(fit=fit,data=d,selected='Paired_MA1',audit=audit,
  metric='joint_correction_effect_rate',era='Combined',specification='era_site_correction',
  fixed=estimate~era*site*correction,variance='era_site_correction')
joint_tables=reconstruction_export(list(joint=entry),joint_out,paired$excluded)
if(!valid) stop('Joint correction GLS failed; see joint_correction_effects/model_results.txt')

em=emmeans(fit,~correction | era*site,data=d,mode='satterthwaite')
mt=as_tibble(as.data.frame(summary(em,infer=c(TRUE,TRUE),adjust='none'))) |>
  transmute(era,site,correction,model_type='Paired_MA1',estimate=emmean,std_error=SE,df,
    conf_low=lower.CL,conf_high=upper.CL,p_zero=p.value) |>
  left_join(count(d,era,site,correction,name='n'),by=c('era','site','correction'),relationship='one-to-one')
correction_em=contrast(em,method=list('Direction - Pace'=c(-1,1)))
contrast_table=function(x,family) {
  as_tibble(as.data.frame(summary(x,infer=c(TRUE,TRUE),adjust='none'))) |>
    rename(std_error=SE,p_value=p.value,conf_low=lower.CL,conf_high=upper.CL) |>
    mutate(model_type='Paired_MA1',p_adjusted=p.adjust(p_value,method='holm'),
      adjustment=paste('Holm across',n(),family),
      interval_type='Unadjusted conditional 95% confidence interval',
      significant=p_adjusted<.05,
      significance=case_when(p_adjusted<.001~'***',p_adjusted<.01~'**',p_adjusted<.05~'*',TRUE~''))
}
ct=contrast_table(correction_em,'within-era/park correction comparisons')
era_em=emmeans(fit,~era | site*correction,data=d,mode='satterthwaite')
era_ct=contrast_table(contrast(era_em,method=list('Anthropocene - Holocene'=c(-1,1))),
  'within-park/correction era comparisons')
interaction_ct=contrast_table(contrast(correction_em,
  method=list('Anthropocene - Holocene correction difference'=c(-1,1)),by='site'),
  'park-specific correction-by-era interactions')
for(name in c('model_group_means','correction_contrasts','era_contrasts','correction_by_era_contrasts'))
  write_csv(switch(name,model_group_means=mt,correction_contrasts=ct,era_contrasts=era_ct,
    correction_by_era_contrasts=interaction_ct),file.path(joint_out,paste0(name,'.csv')))
observed_means=read_csv(out('era_comparison/lag_rate_per_century/model_group_means.csv'),
  show_col_types=FALSE) |> mutate(correction='Observed',p_zero=2*pt(-abs(estimate/std_error),df))
zero_tests=bind_rows(mt,observed_means) |>
  mutate(zero_test='Fitted mean = 0; unadjusted, two-sided Satterthwaite t test',
    zero_significant=p_zero<.05,
    zero_significance=case_when(p_zero<.001~'***',p_zero<.01~'**',p_zero<.05~'*',TRUE~''))
write_csv(zero_tests,file.path(joint_out,'displayed_mean_zero_tests.csv'))
write_csv(tibble(parameter=names(parameters),estimate=unname(parameters)),
  file.path(joint_out,'correlation_parameters.csv'))
cat('\nJoint correction-effect analysis: pace and direction only, paired on the same transitions.\n',
  'Fixed effects: estimate ~ era * site * correction.\n',
  'Residual SDs: era x site x correction. Temporal MA(1) uses preserved transition indices.\n',
  'Paired correction correlations vary by era x site; modern plots are singleton temporal series.\n',
  'Primary-only analysis; no additional Bacon fits. Joint means refer to complete correction pairs.\n',
  'Contrasts are Direction effect minus Pace effect. Positive effects mean reduced lag after correction. Holm-adjusted p-values use separate stated families.\n',
  'Displayed mean stars test zero using unadjusted two-sided Satterthwaite t tests.\n',
  capture.output(print(count(d,era,site,correction))),
  capture.output(print(mt)),capture.output(print(ct)),capture.output(print(era_ct)),
  capture.output(print(interaction_ct)),sep='\n',file=file.path(joint_out,'model_results.txt'),append=TRUE)
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
  predictions=joint_tables$transition_predictions |>
    mutate(metric=as.character(correction))
  tracking_pdf_pages(list(reconstruction_residual_plot(predictions)+
    plot_annotation(title='Joint pace/direction correction-effect GLS: paired outcomes, temporal MA(1)')),
    tracking_model_figure('fig_tracking_joint_correction_residuals.pdf'),width=12,height=10)
}
cat('Joint correction GLS:',nrow(d)/2,'paired units;',audit$covariance_status,'covariance uncertainty.\n')
