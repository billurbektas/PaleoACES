# 12 Tracking: native-century Holocene reconstruction, tracking metrics for both
# eras, and the combined model input. No model fits.

# =============================================================================
# 1. Holocene century reconstruction and tracking metrics
# =============================================================================
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/century_tracking.R'),local=TRUE)
bundle=century_prepare();primary=century_reconstruct(bundle)
hc=primary$calculations
h=hc |> select(all_of(century_holocene_columns()))
# Anthropocene: legacy -> resurvey movement of every paired plot, from the CCA
# step's modern endpoints, with each plot's modern fire assignment.
source(here('R/helpers/tracking_data.R'),local=TRUE)
modern_fire=bind_rows(
  read_csv(out('MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='MORA',plot_id=str_to_upper(plot_id),burned=burnt,
      fire_assignment_source='MORA mapped disturbance 1987-2017'),
  read_csv(out('NOCA_fire_assignment_audit.csv'),show_col_types=FALSE) |>
    transmute(site='NOCA',plot_id=str_to_upper(plot_id),burned=burnt,
      fire_assignment_source=assignment_source))
if(anyDuplicated(modern_fire[c('site','plot_id')])) stop('Duplicate plot fire assignment')
ac=bundle$reference$modern_endpoints |> calculate_tracking_metrics() |>
  add_climate_change_metrics(bundle$reference$climate_scaling) |>
  mutate(fire_plot_key=str_to_upper(plot_id)) |>
  left_join(modern_fire |> rename(fire_plot_key=plot_id),by=c('site','fire_plot_key'),
    relationship='many-to-one') |> select(-fire_plot_key)
if(anyNA(ac$burned)) stop('Missing modern plot fire assignment')
a=ac |> select(all_of(anthropocene_model_columns()))
write_csv(ac,out('cca_tracking_anthropocene_plot_calculations.csv'))
write_csv(a,out('cca_tracking_anthropocene_plot_model_input.csv'))
stopifnot(nrow(a)==607L,!anyDuplicated(a[c('site','plot_id')]),nrow(ac)==607L,
  !anyDuplicated(h[c('site','lake','age_hi','age_lo')]),
  all(h$vegetation_dt_years==h$age_hi-h$age_lo),all(h$climate_dt_years==h$vegetation_dt_years),
  all(is.na(h$fire_activity[!h$fire_coverage_valid])))
# Occupancy is descriptive support, never a primary exclusion policy.
assignments=reconstruction_century_assignments(bundle$cache$draws,bundle$samples,bundle$grid)
centroids=assignments |> filter(is.finite(century_cal_bp)) |> group_by(site,lake,draw,century_cal_bp) |>
  summarise(observed_CCA1=mean(observed_CCA1),observed_CCA2=mean(observed_CCA2),n_samples=n(),.groups='drop')
occupancy=centroids |> count(site,lake,century_cal_bp,name='n_occupied_draws') |>
  mutate(n_expected_draws=HOLOCENE_RECONSTRUCTION_DRAWS,occupancy_proportion=n_occupied_draws/n_expected_draws)
positions=primary$positions |> left_join(occupancy,by=c('site','lake','century_cal_bp'),relationship='one-to-one') |>
  mutate(n_occupied_draws=coalesce(n_occupied_draws,0L),n_expected_draws=HOLOCENE_RECONSTRUCTION_DRAWS,
    occupancy_proportion=n_occupied_draws/n_expected_draws)
support=h |> group_by(site,lake) |> summarise(n_occupied_centuries=n()+1L,n_transitions=n(),
  n_gaps_over_100=sum(vegetation_dt_years>100),duration_min=min(vegetation_dt_years),
  duration_median=median(vegetation_dt_years),duration_max=max(vegetation_dt_years),
  n_fire_coverage_losses=sum(!fire_coverage_valid),.groups='drop')
tables=list(cca_tracking_holocene_century_positions=positions,
  cca_tracking_holocene_lake_transitions=h,
  cca_tracking_holocene_lake_calculations=hc,cca_tracking_holocene_lake_support=support,
  cca_tracking_holocene_sample_assignments=primary$assignments)
for(name in names(tables)) write_csv(tables[[name]],out(paste0(name,'.csv')))
write_csv(century_schema(c(tables,list(cca_tracking_anthropocene_plot_model_input=a,
  cca_tracking_anthropocene_plot_calculations=ac))),out('cca_tracking_schema.csv'))
saveRDS(primary,out('chronology_reconstruction/primary.rds'))
cat('Primary native-century tracking:',nrow(h),'actual transitions; no interpolation or offsets.\n')

# =============================================================================
# 2. Combined-era model input
# =============================================================================
suppressPackageStartupMessages({library(here);library(tidyverse)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_result_paths.R'),local=TRUE)
h=read_csv(out('cca_tracking_holocene_lake_transitions.csv'),show_col_types=FALSE)
a=read_csv(out('cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE)
hc=read_csv(out('cca_tracking_holocene_lake_calculations.csv'),show_col_types=FALSE)
ac=read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
lake_locations=read_csv(out('chelsa_paleo_ponds.csv'),show_col_types=FALSE) |>
  distinct(site,lake,longitude=lon,latitude=lat)
plot_locations=bind_rows(
  read_csv(out('MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='MORA',plot_id,longitude,latitude),
  read_csv(out('NOCA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='NOCA',plot_id,longitude,latitude))
combined=combine_tracking_model_data(h,a,lake_locations,plot_locations,hc,ac)
write_csv(combined,out('cca_tracking_era_model_input.csv'))
schema=read_csv(out('cca_tracking_schema.csv'),show_col_types=FALSE) |>
  filter(dataset!='cca_tracking_era_model_input')
write_csv(bind_rows(schema,tracking_schema(list(cca_tracking_era_model_input=combined))),
  out('cca_tracking_schema.csv'))
cat('Primary combined model input:',nrow(h),'Holocene transitions and',nrow(a),'modern pairs.\n')
