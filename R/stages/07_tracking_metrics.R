# Canonical century reconstruction and tracking: one producer, no model fits.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/century_tracking.R'),local=TRUE)
if(any(grepl('^--(bin-width|offset|reconstruction-audit|century-reconstruction)',commandArgs(trailingOnly=TRUE))))
  stop('Ecological phase/width and support-audit options are retired')
bundle=century_prepare();primary=century_reconstruct(bundle)
hc=primary$calculations
h=hc |> select(all_of(century_holocene_columns()))
# Modern calculations are protected and already contain their distinct elapsed times.
a=read_csv(out('cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE)
ac=read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
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
century_support=bundle$grid |> left_join(occupancy,by=c('site','lake','century_cal_bp')) |>
  mutate(n_occupied_draws=coalesce(n_occupied_draws,0L),n_expected_draws=HOLOCENE_RECONSTRUCTION_DRAWS,
    occupancy_proportion=n_occupied_draws/n_expected_draws,
    occupied_primary=paste(lake,century_cal_bp) %in% paste(positions$lake,positions$century_cal_bp))
support=h |> group_by(site,lake) |> summarise(n_occupied_centuries=n()+1L,n_transitions=n(),
  n_gaps_over_100=sum(vegetation_dt_years>100),duration_min=min(vegetation_dt_years),
  duration_median=median(vegetation_dt_years),duration_max=max(vegetation_dt_years),
  n_fire_coverage_losses=sum(!fire_coverage_valid),.groups='drop')
tables=list(cca_tracking_holocene_century_positions=positions,
  cca_tracking_holocene_century_support=century_support,
  cca_tracking_holocene_century_draws=centroids,cca_tracking_holocene_lake_transitions=h,
  cca_tracking_holocene_lake_calculations=hc,cca_tracking_holocene_lake_support=support,
  cca_tracking_holocene_sample_projections=bundle$samples,
  cca_tracking_holocene_sample_assignments=primary$assignments,
  cca_tracking_holocene_fire_provenance=primary$fire$core,
  cca_tracking_holocene_fire_events=primary$fire$events,
  cca_tracking_holocene_posterior_rows=bundle$cache$posterior_rows)
for(name in names(tables)) write_csv(tables[[name]],out(paste0(name,'.csv')))
write_csv(century_schema(c(tables,list(cca_tracking_anthropocene_plot_model_input=a,
  cca_tracking_anthropocene_plot_calculations=ac))),out('cca_tracking_schema.csv'))
saveRDS(primary,out('chronology_reconstruction/primary.rds'))
cat('Primary native-century tracking:',nrow(h),'actual transitions; no interpolation or offsets.\n')
