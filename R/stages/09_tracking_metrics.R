# Canonical lake-level and paired-plot tracking datasets. No figure/model fits.
# Rscript R/stages/09_tracking_metrics.R [--bin-width-years=500]
# Nondefault widths write only suffixed Holocene products.
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)
source(here('R/helpers/tracking_data.R'),local=TRUE)
N_DRAWS = 100; DRAW_SEED = 42
source(here('R/helpers/paleo_runs.R'),local=TRUE)
source(here('R/helpers/climate_variables.R'),local=TRUE)
source(here('R/helpers/holocene_climate_fire_era_functions.R'),local=TRUE)
width_arg = grep('^--bin-width-years=',commandArgs(trailingOnly=TRUE),value=TRUE)
if (length(width_arg)>1L) stop('Specify one bin width')
bin_width_years = validate_tracking_width(if(length(width_arg))
  as.numeric(sub('^--bin-width-years=','',width_arg)) else 1000L)
suffix = if (bin_width_years==1000L) '' else paste0('_',bin_width_years,'yr')
output_path = function(stem) here('output',paste0(stem,suffix,'.csv'))
required = here('output',c('cca_calibration_reference.rds','chelsa_paleo_ponds.csv',
  'paleo_age_draws.rds','holocene_fire_source_events.csv','holocene_fire_source_series.csv',
  'holocene_era_fire_core_frequency.csv','holocene_era_fire_site_frequency.csv'))
if (!all(file.exists(required))) stop('Run CCA reference and climate/fire stages first')
reference = readRDS(required[1])
if (!identical(reference$scaling,'sites') || reference$hill ||
    nrow(reference$legacy_species)!=607L || length(reference$retained_species)!=14L)
  stop('Expected the unchanged primary 607-plot, 14-taxon CCA')
if (any(tools::md5sum(names(reference$provenance$input_md5)) != reference$provenance$input_md5) ||
    any(tools::md5sum(names(reference$provenance$model_source_md5)) != reference$provenance$model_source_md5))
  stop('CCA reference is stale; rerun the unchanged calibration stage')
# Cache-only chronology access: never regenerate draws or mutate Bacon products.
draws = paleo_age_draws(allow_rebuild=FALSE)
ponds = read_csv(required[2],show_col_types=FALSE)
env_slice = ponds |> transmute(unit=lake,period=site,variable,time=slice,month,
  value=if(PALEO_USE_BIAS_CORRECTED) value_corrected else value_raw) |>
  derive_climate_vars(winter_shift=FALSE) |> rename(lake=unit,site=period,slice=time) |>
  mutate(age=1950-slice*100)
built = build_lake_tracking(reference,draws,env_slice,bin_width_years)
realizations = built$realizations
events = read_csv(required[4],show_col_types=FALSE)
continuous = read_csv(required[5],show_col_types=FALSE)
fire = transition_fire(realizations,events,continuous,bin_width_years,
  core_reference=if(bin_width_years==1000L) read_csv(required[6],show_col_types=FALSE) else NULL,
  high_fire=read_csv(required[7],show_col_types=FALSE))
realizations = realizations |> left_join(fire,by=c('site','offset','age_hi','age_lo'),relationship='many-to-one')
keys = c('site','lake','draw','offset','age_hi','age_lo')
if (anyDuplicated(realizations[keys])) stop('Duplicate lake realization key')
uncertainty = lake_uncertainty(realizations,N_DRAWS)
by_offset = lake_offset_summary(realizations,uncertainty)
timeseries = lake_reporting_grid(uncertainty,bin_width_years)
sample_support = built$samples |> distinct(site,lake,plot_id) |> count(site,lake,name='n_eligible_samples')
excluded = built$raw |> group_by(site,lake,offset) |> summarize(
  n_observed_realizations=n(),n_incomplete_climate_realizations=sum(!climate_complete),.groups='drop')
support = realizations |> group_by(site,lake,offset) |> summarize(
  n_realizations=n(),n_nmin2_realizations=sum(n_min>=2),
  youngest_endpoint=min(age_lo),oldest_endpoint=max(age_hi),
  endpoint_samples_min=min(c(n_samples,n_samples_2)),
  endpoint_samples_median=median(c(n_samples,n_samples_2)),
  endpoint_samples_max=max(c(n_samples,n_samples_2)),.groups='drop') |>
  left_join(by_offset |> group_by(site,lake,offset) |> summarize(
    n_transitions=n(),n_transitions_nmin2=sum(n_draws_nmin2>0),
    n_transitions_full_draw_support=sum(n_draws_present==N_DRAWS),
    n_transitions_majority_draw_support=sum(n_draws_present>=N_DRAWS/2),
    n_transitions_nmin2_majority_support=sum(n_draws_nmin2>=N_DRAWS/2),
    present_draws_min=min(n_draws_present),present_draws_median=median(n_draws_present),
    n_fire_missing_transitions=sum(!is.finite(fire_activity)),.groups='drop'),by=c('site','lake','offset')) |>
  left_join(sample_support,by=c('site','lake')) |> left_join(excluded,by=c('site','lake','offset')) |>
  mutate(bin_width_years=bin_width_years,n_expected_draws=N_DRAWS)
if (bin_width_years==1000L) {
  modern_fire = bind_rows(
    read_csv(here('output/MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
      transmute(site='MORA',plot_id=str_to_upper(plot_id),burned=burnt,
        fire_assignment_source='MORA mapped disturbance 1987-2017'),
    read_csv(here('output/NOCA_fire_assignment_audit.csv'),show_col_types=FALSE) |>
      transmute(site='NOCA',plot_id=str_to_upper(plot_id),burned=burnt,
        fire_assignment_source=assignment_source))
  if (anyDuplicated(modern_fire[c('site','plot_id')])) stop('Duplicate plot fire assignment')
  anth = reference$modern_endpoints |> calculate_tracking_metrics() |>
    add_climate_change_metrics(reference$climate_scaling) |>
    mutate(fire_plot_key=str_to_upper(plot_id)) |>
    left_join(modern_fire |> rename(fire_plot_key=plot_id),
      by=c('site','fire_plot_key'),relationship='many-to-one') |> select(-fire_plot_key)
  if (anyNA(anth$burned)) stop('Missing modern plot fire assignment')
  anth_model = anth |> select(all_of(anthropocene_model_columns()))
}
# Validate calculated products and regression keys before replacing any exports.
tryCatch(validate_tracking_products(by_offset,uncertainty,
  if(bin_width_years==1000L) anth_model else NULL,bin_width_years),error=function(e) {
  stop(conditionMessage(e),'\nObserved/excluded realization diagnostics:\n',
    paste(capture.output(print(excluded,n=40)),collapse='\n'),call.=FALSE)
})
tables = list(cca_tracking_holocene_lake_realizations=realizations,
  cca_tracking_holocene_lake_by_offset=by_offset,
  cca_tracking_holocene_lake_uncertainty=uncertainty,
  cca_tracking_holocene_lake_timeseries=timeseries,
  cca_tracking_holocene_lake_support=support)
for(stem in names(tables)) write_csv(tables[[stem]],output_path(stem))
if(bin_width_years==1000L) {
  tables$cca_tracking_anthropocene_plot_model_input = anth_model
  tables$cca_tracking_anthropocene_plot_calculations = anth
  write_csv(anth_model,here('output/cca_tracking_anthropocene_plot_model_input.csv'))
  write_csv(anth,here('output/cca_tracking_anthropocene_plot_calculations.csv'))
  write_csv(tracking_schema(tables),here('output/cca_tracking_schema.csv'))
  source(here('R/helpers/survey_decision_effects.R'),local=TRUE)
  export_survey_decision_effects(anth)
}
cat('Tracking completed:',nrow(realizations),'lake realizations;',nrow(by_offset),
  'actual lake/offset transitions;',nrow(uncertainty),'uncertainty rows; width',
  bin_width_years,'years.\n')
