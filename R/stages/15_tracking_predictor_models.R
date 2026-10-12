# Primary explanatory GLS and whole-chronology community sensitivity.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_predictor_models.R'),local=TRUE)
metrics=c('lag_rate_per_century',tracking_corrected_response_names())
h=read_csv(here('output/cca_tracking_holocene_lake_calculations.csv'),show_col_types=FALSE)
a=read_csv(here('output/cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE) |>
  add_corrected_lag_rates()
combined=read_csv(here('output/cca_tracking_era_model_input.csv'),show_col_types=FALSE)
locations=combined |> filter(era=='Anthropocene') |> distinct(site,plot_id,longitude,latitude)
a=left_join(a,locations,by=c('site','plot_id'),relationship='one-to-one')
elevation_env=new.env(parent=emptyenv());load(here('data/MORA_plots.rda'),envir=elevation_env)
elevations=tracking_modern_elevations(elevation_env$plot_info,
  read_csv(here('data/NOCA/NOCA_plots_fromWilson.csv'),show_col_types=FALSE),locations)
a=left_join(a,elevations |> select(site,plot_id,elevation,elevation_source),by=c('site','plot_id'),relationship='one-to-one')
entries=exclusions=random=list()
for(metric in metrics) for(spec in c('Holocene','Anthropocene_basic','Anthropocene_extended')) {
  era=if(spec=='Holocene') 'Holocene' else 'Anthropocene'
  input=reconstruction_explanatory_input(if(era=='Holocene') h else a,metric,era,extended=spec=='Anthropocene_extended')
  entry=reconstruction_select(input$data,input$fixed,families=if(era=='Holocene')
    c('Independent','MA1','CAR1') else 'Independent')
  entry$metric=metric;entry$era=era;entry$specification=spec
  if(is.null(entry$fit)) stop('Primary community explanatory fit failed: ',metric,' / ',spec)
  name=paste(metric,spec,sep=':');entries[[name]]=entry;exclusions[[name]]=input$excluded
  if(era=='Holocene') random[[metric]]=reconstruction_lake_random(entry,metric)
}
out=tracking_primary_results('community')
tables=reconstruction_export(entries,out,bind_rows(exclusions))
lake_out=tracking_lake_results('random')
dir.create(lake_out,recursive=TRUE,showWarnings=FALSE)
write_csv(bind_rows(lapply(random,`[[`,'summary')),file.path(lake_out,'lake_random_intercept_sensitivity.csv'))
saveRDS(random,file.path(lake_out,'lake_random_intercept_fits.rds'))
write_csv(elevations,file.path(out,'anthropocene_elevations.csv'))
cat('Random-lake-intercept sensitivity:',capture.output(print(bind_rows(lapply(random,`[[`,'summary')))),
  sep='\n',file=file.path(lake_out,'model_results.txt'))
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
  co=tables$model_coefficients;pr=tables$transition_predictions
  specification_labels=c(Holocene='Holocene',Anthropocene_basic='Anthropocene: basic',
    Anthropocene_extended='Anthropocene: extended')
  co$model_type=recode(co$specification,Holocene='Site + climate + fire',
    Anthropocene_basic='Site + burned',Anthropocene_extended='Site + elevation + climate + burned')
  ggsave(tracking_model_figure('fig_tracking_predictor_era_coefficients.pdf'),
    reconstruction_coefficient_plot(co),width=16,height=14,device=cairo_pdf)
  performance=tables$model_performance |> mutate(specification=unname(specification_labels[specification]))
  r2=ggplot(performance,aes(specification,R2,fill=era))+geom_col(width=.6)+
    facet_wrap(~metric,labeller=labeller(metric=reconstruction_metric_label))+
    labs(x=NULL,y='Descriptive R2')+reconstruction_model_theme()+
    theme(axis.text.x=element_text(angle=25,hjust=1))
  ggsave(tracking_model_figure('fig_tracking_predictor_R2.pdf'),r2,width=15,height=7,device=cairo_pdf)
  # Each model has its own residual distribution: never pool basic and extended
  # modern fits into a single era panel.
  diagnostic_predictions=pr |> mutate(era=unname(specification_labels[specification]))
  ggsave(tracking_model_figure('fig_tracking_predictor_residuals.pdf'),
    reconstruction_residual_plot(diagnostic_predictions),width=16,height=18,device=cairo_pdf)
  catalog=read_csv(here('output/holocene_era_catalog.csv'),show_col_types=FALSE)
  hp=pr |> filter(era=='Holocene') |> arrange(metric,lake,transition_index) |>
    group_by(metric,lake) |> mutate(next_predicted=lead(predicted),
      joins_next=lead(transition_index)==transition_index+1L & lead(age_hi)==age_lo) |> ungroup()
  # Actual spans; gaps from exclusions remain blank instead of being bridged.
  prediction=ggplot(hp,aes(interval_mid_cal_bp,predicted))+
    geom_rect(data=catalog,aes(xmin=younger_cal_bp,xmax=older_cal_bp,ymin=-Inf,ymax=Inf,
      fill=era_class),inherit.aes=FALSE,alpha=.35)+
    scale_fill_manual(values=c('climate change'='#D3D3D6','relative stability'='#EEEEF0'),guide='none')+
    geom_rect(aes(xmin=age_lo,xmax=age_hi,ymin=conf_low,ymax=conf_high),
      fill='#648FFF',alpha=.18,inherit.aes=FALSE)+
    geom_segment(aes(x=age_lo,xend=age_hi,yend=predicted),color='#648FFF',linewidth=1)+
    geom_segment(data=hp |> filter(joins_next),aes(x=age_lo,xend=age_lo,yend=next_predicted),
      color='#648FFF',linewidth=1)+
    facet_grid(metric~lake,scales='free_y',labeller=labeller(metric=reconstruction_metric_label))+
    scale_x_reverse()+
    labs(x='Transition age (cal BP)',y='Lag-change rate (CCA distance per century)',
      caption='Joined fitted values over actual transition intervals; shaded bands: conditional 95% mean-confidence intervals. Excluded transitions remain gaps.')+
    reconstruction_model_theme()
  ggsave(tracking_model_figure('fig_tracking_predictor_holocene_predictions.pdf'),prediction,width=19,height=12,device=cairo_pdf)
}
if(!isTRUE(getOption('paleoaces.primary_only',FALSE))) {
  sensitivity_out=tracking_bacon_results('community')
  sensitivity=reconstruction_sensitivity(century_prepare(),entries,'community',sensitivity_out)
  source(here('R/helpers/chronology_exports.R'),local=TRUE)
  export_chronology_records(sensitivity_out,'community')
  source(here('R/helpers/chronology_figures.R'),local=TRUE)
  temporal_ranges=chronology_temporal_ranges(century_prepare(),sensitivity_out)
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) ggsave(
    tracking_model_figure('fig_tracking_bacon_chronology_ranges.pdf',role='bacon'),
    chronology_temporal_range_plot(temporal_ranges,h),width=20,height=17,device=cairo_pdf)
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) ggsave(
    tracking_model_figure('fig_tracking_predictor_chronology_sensitivity.pdf',role='bacon'),
    reconstruction_sensitivity_plot(sensitivity),width=16,height=9,device=cairo_pdf)
}
