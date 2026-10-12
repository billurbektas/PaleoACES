# Primary lake comparisons; use the parent combined-era selected covariance family.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(emmeans)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
combined=read_csv(here('output/cca_tracking_era_model_input.csv'),show_col_types=FALSE)
figure_pages=list()
for(metric in tracking_model_response_names()) {
  parent=readRDS(here('output/tracking_analysis/primary/era_comparison',metric,'primary_fits.rds'))$primary
  selected=tracking_primary_model_input(combined,metric)
  coefficients=contrasts=audits=text=list();fits=list()
  for(lake in unique(selected$data$lake[selected$data$era=='Holocene'])) {
    park=as.character(unique(selected$data$site[selected$data$lake==lake & !is.na(selected$data$lake)]))
    d=selected$data |> filter(site==park,era=='Anthropocene' | lake==.env$lake)
    d$era_site=interaction(d$era,d$site,drop=TRUE)
    e=reconstruction_select(d,estimate~era,variance='era',families=parent$selected)
    audits[[lake]]=mutate(e$audit,lake=lake,site=park,metric=metric)
    if(is.null(e$fit)) {text[[lake]]=paste(lake,'fit failed');next}
    coefficients[[lake]]=reconstruction_coefficients(e$fit,metric,'Combined',e$selected) |> mutate(lake=lake,site=park)
    mm=emmeans(e$fit,~era,data=d,mode='satterthwaite')
    ct=as_tibble(as.data.frame(summary(contrast(mm,method=list('Anthropocene - Holocene'=c(-1,1))),
      infer=c(TRUE,TRUE),adjust='none')))
    contrasts[[lake]]=ct |> transmute(metric=metric,lake=lake,site=park,model_type=e$selected,
      estimate,std_error=SE,df,p_value=p.value,conf_low=lower.CL,conf_high=upper.CL)
    fits[[lake]]=e;text[[lake]]=c(lake,capture.output(print(summary(e$fit))),capture.output(print(ct)))
  }
  out=here('output/tracking_analysis/sensitivity/lake_checks/era_comparisons',metric);dir.create(out,recursive=TRUE,showWarnings=FALSE)
  co=bind_rows(coefficients);ct=bind_rows(contrasts)
  write_csv(co,file.path(out,'model_coefficients.csv'));write_csv(ct,file.path(out,'model_contrasts.csv'))
  write_csv(bind_rows(audits),file.path(out,'covariance_comparison.csv'));saveRDS(fits,file.path(out,'primary_fits.rds'))
  writeLines(unlist(text),file.path(out,'model_results.txt'))
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) for(type in c('coefficients','contrasts')) {
    x=if(type=='coefficients') co else ct
    p=ggplot(x,aes(estimate,lake,color=site))+geom_vline(xintercept=0,linetype='dashed',color='grey60')+
      geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.12)+geom_point(size=3)+
      scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'))+
      labs(x=if(type=='contrasts') 'Anthropocene - Holocene' else 'Coefficient estimate',y=NULL)+reconstruction_model_theme()
    if(type=='coefficients') p=p+facet_wrap(~term,scales='free_x')
    p=p+labs(title=tracking_model_response_label(metric))
    figure_pages[[type]]=c(figure_pages[[type]],list(p))
  }
}
for(type in names(figure_pages)) tracking_pdf_pages(figure_pages[[type]],
  tracking_model_figure(paste0('fig_tracking_lake_',type,'.pdf'),role='lake'),width=12,height=7)
