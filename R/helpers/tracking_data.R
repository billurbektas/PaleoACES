# Compact interfaces for the native-century reconstruction.
source(here::here('R/helpers/century_tracking.R'),local=TRUE)
tracking_response_names=function() century_response_names()[1:7]
tracking_transition_keys=function() c('site','lake','age_hi','age_lo')
holocene_model_columns=century_holocene_columns
anthropocene_model_columns=function() c('site','plot_id','vegetation_t1_year','vegetation_t2_year',
  'climate_t1_midyear','climate_t2_midyear','vegetation_dt_years','climate_dt_years',
  'standardized_climate_change_rate','burned',tracking_response_names(),
  'angle_valid','pace_counterfactual_valid','direction_counterfactual_valid','tracking_ratio_valid')
tracking_schema=century_schema
