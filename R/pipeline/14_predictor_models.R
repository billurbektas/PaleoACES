# Primary explanatory GLS.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_predictor_models.R'),local=TRUE)
metrics=c('lag_rate_per_century',tracking_correction_effect_response_names())
h=read_csv(out('cca_tracking_holocene_lake_calculations.csv'),show_col_types=FALSE)
a=read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
combined=read_csv(out('cca_tracking_era_model_input.csv'),show_col_types=FALSE)
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
results_dir=tracking_primary_results('community')
tables=reconstruction_export(entries,results_dir,bind_rows(exclusions))
lake_out=tracking_lake_results('random')
dir.create(lake_out,recursive=TRUE,showWarnings=FALSE)
write_csv(bind_rows(lapply(random,`[[`,'summary')),file.path(lake_out,'lake_random_intercept_sensitivity.csv'))
saveRDS(random,file.path(lake_out,'lake_random_intercept_fits.rds'))
write_csv(elevations,file.path(results_dir,'anthropocene_elevations.csv'))
cat('Random-lake-intercept sensitivity:',capture.output(print(bind_rows(lapply(random,`[[`,'summary')))),
  sep='\n',file=file.path(lake_out,'model_results.txt'))
