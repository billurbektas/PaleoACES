# Primary combined-era GLS: compare covariance candidates on identical rows.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(emmeans);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
combined=read_csv(here('output/cca_tracking_era_model_input.csv'),show_col_types=FALSE)
validate_tracking_model_data(combined)
figure_pages=list()
for(metric in tracking_model_response_names()) {
  selected=tracking_primary_model_input(combined,metric)
  entry=reconstruction_select(selected$data,estimate~era*site,variance='era_site')
  if(is.null(entry$fit)) stop('All combined-era covariance fits failed: ',metric)
  entry$metric=metric;entry$era='Combined';entry$specification='era_by_site'
  out=here('output/tracking_analysis/primary/era_comparison',metric)
  tables=reconstruction_export(list(primary=entry),out,selected$excluded)
  means=emmeans(entry$fit,~era | site,data=entry$data,mode='satterthwaite')
  mt=as.data.frame(summary(means,infer=c(TRUE,FALSE)))
  group_means=as_tibble(mt) |> transmute(metric=metric,model_type=entry$selected,site,era,
    estimate=emmean,std_error=SE,df,conf_low=lower.CL,conf_high=upper.CL,
    n=map2_int(as.character(site),as.character(era),~sum(entry$data$site==.x & entry$data$era==.y)))
  ct=as.data.frame(summary(contrast(means,method=list('Anthropocene - Holocene'=c(-1,1))),
    infer=c(TRUE,TRUE),adjust='none'))
  contrasts=as_tibble(ct) |> transmute(metric=metric,model_type=entry$selected,site,contrast,
    estimate,std_error=SE,df,p_value=p.value,conf_low=lower.CL,conf_high=upper.CL)
  write_csv(group_means,file.path(out,'model_group_means.csv'))
  write_csv(contrasts,file.path(out,'model_contrasts.csv'))
  cat(capture.output(print(group_means)),capture.output(print(contrasts)),sep='\n',
    file=file.path(out,'model_results.txt'),append=TRUE)
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
