# One combined model input, assembled after the canonical tracking calculations.
# Rscript R/stages/11_tracking_model_data.R
suppressPackageStartupMessages({library(here);library(tidyverse)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_result_paths.R'),local=TRUE)
tracking_result_guide()
h=read_csv(here('output/cca_tracking_holocene_lake_transitions.csv'),show_col_types=FALSE)
a=read_csv(here('output/cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE)
hc=read_csv(here('output/cca_tracking_holocene_lake_calculations.csv'),show_col_types=FALSE)
ac=read_csv(here('output/cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
lake_locations=read_csv(here('output/chelsa_paleo_ponds.csv'),show_col_types=FALSE) |>
  distinct(site,lake,longitude=lon,latitude=lat)
plot_locations=bind_rows(
  read_csv(here('output/MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='MORA',plot_id,longitude,latitude),
  read_csv(here('output/NOCA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='NOCA',plot_id,longitude,latitude))
combined=combine_tracking_model_data(h,a,lake_locations,plot_locations,hc,ac)
write_csv(combined,here('output/cca_tracking_era_model_input.csv'))
schema=read_csv(here('output/cca_tracking_schema.csv'),show_col_types=FALSE) |>
  filter(dataset!='cca_tracking_era_model_input')
write_csv(bind_rows(schema,tracking_schema(list(cca_tracking_era_model_input=combined))),
  here('output/cca_tracking_schema.csv'))
cat('Primary combined model input:',nrow(h),'Holocene transitions and',nrow(a),'modern pairs.\n')
