# One combined model input, assembled after the canonical tracking calculations.
# Rscript R/stages/11_tracking_model_data.R [--bin-width-years=500]
suppressPackageStartupMessages({library(here);library(tidyverse)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
width_arg=grep('^--bin-width-years=',commandArgs(trailingOnly=TRUE),value=TRUE)
if(length(width_arg)>1L) stop('Specify one bin width')
width=validate_tracking_width(if(length(width_arg))
  as.numeric(sub('^--bin-width-years=','',width_arg)) else 1000L)
suffix=if(width==1000L) '' else paste0('_',width,'yr')
b=read_csv(here('output',paste0('cca_tracking_holocene_lake_by_offset',suffix,'.csv')),
  show_col_types=FALSE)
a=read_csv(here('output/cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE)
hc=read_csv(here('output',paste0('cca_tracking_holocene_lake_realizations',suffix,'.csv')),
  show_col_types=FALSE)
ac=read_csv(here('output/cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
if(any(b$climate_dt_years!=width)) stop('Requested width and source table disagree')
lake_locations=read_csv(here('output/chelsa_paleo_ponds.csv'),show_col_types=FALSE) |>
  distinct(site,lake,longitude=lon,latitude=lat)
plot_locations=bind_rows(
  read_csv(here('output/MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='MORA',plot_id,longitude,latitude),
  read_csv(here('output/NOCA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='NOCA',plot_id,longitude,latitude))
combined=combine_tracking_model_data(b,a,lake_locations,plot_locations,hc,ac)
write_csv(combined,here('output',paste0('cca_tracking_era_by_offset',suffix,'.csv')))
if(width==1000L) {
  schema=read_csv(here('output/cca_tracking_schema.csv'),show_col_types=FALSE) |>
    filter(!dataset %in% c('cca_tracking_era_comparison','cca_tracking_era_by_offset'))
  schema=bind_rows(schema,tracking_schema(list(cca_tracking_era_by_offset=combined)))
  write_csv(schema,here('output/cca_tracking_schema.csv'))
}
cat('Combined model input:',nrow(combined),'rows;',ncol(combined),'columns;',
  nrow(b),'Holocene transitions and',nrow(a),'modern pairs, each with',
  length(tracking_combined_response_names()),'responses.\n')
