# 12 Tracking: native-century Holocene positions, tracking metrics for both eras,
# the lake-periods and the combined era-model input (both_eras). No model fits.

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
# Rule (PLAN.md Step 0.5): the display rotation changes no metric. Rotate every
# endpoint with the figure rotation, recompute, and compare.
source(here('R/helpers/cca_display_rotation.R'),local=TRUE)
rotation=cca_display_rotation(scores(bundle$reference$model,display='bp',choices=1:2,scaling='sites',hill=FALSE))
rotation_check=function(x) {
  r=x
  for(p in list(c('o1','o2'),c('o1_2','o2_2'),c('p1','p2'),c('p1_2','p2_2'))) r=rotate_columns(r,rotation,p[1],p[2])
  r=calculate_tracking_metrics(r)
  m=c('lag_t1','lag_t2','change_in_lag','lag_rate_per_century','observed_turnover_rate',
    'pace_effect_on_lag_per_century','direction_effect_on_lag_per_century','angle_degrees')
  max(abs(as.matrix(r[m])-as.matrix(x[m])),na.rm=TRUE)
}
stopifnot(rotation_check(hc)<1e-9,rotation_check(ac)<1e-9)
write_csv(ac,out('cca_tracking_anthropocene_plot_calculations.csv'))
write_csv(a,out('cca_tracking_anthropocene_plot_model_input.csv'))
stopifnot(nrow(a)==sum(ANTHROPOCENE_PAIRS),!anyDuplicated(a[c('site','plot_id')]),nrow(ac)==sum(ANTHROPOCENE_PAIRS),
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

# Lake-periods (Steps 1 to 4): one row per lake within one climate period, from
# its oldest to its youngest sampled century, and the combined era-model input.
source(here('R/helpers/lake_periods.R'),local=TRUE)
periods=read_csv(out('holocene_periods.csv'),show_col_types=FALSE)
candidates=lake_period_candidates(primary$positions,periods)
units=build_lake_periods(primary$positions,periods,bundle$reference$climate_scaling,
  function(intervals) century_fire(intervals,bundle))
both_eras=build_both_eras(units,ac)
write_csv(candidates,out('cca_tracking_lake_period_candidates.csv'))
write_csv(units |> select(all_of(lake_period_table_columns())),out('cca_tracking_lake_periods.csv'))
write_csv(units,out('cca_tracking_lake_period_calculations.csv'))
write_csv(both_eras,out('cca_tracking_both_eras.csv'))
cat('Lake-periods:',nrow(candidates),'on paper,',nrow(units),'after the two-century rule.\n')
cat('Primary native-century tracking:',nrow(h),'actual transitions; no interpolation or offsets.\n')
