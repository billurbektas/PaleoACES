# Labels shared by primary model figures.
source(here::here('R/helpers/tracking_result_paths.R'),local=TRUE)
tracking_model_response_names=function() c('lag_rate_per_century','observed_turnover_rate',
  'standardized_climate_change_rate','pace_corrected_lag_rate_per_century','direction_corrected_lag_rate_per_century')
tracking_model_response_label=function(metric) unname(c(lag_rate_per_century='Observed lag change',
  observed_turnover_rate='Community turnover rate',standardized_climate_change_rate='Standardized climate change per century',
  pace_corrected_lag_rate_per_century='Pace-corrected lag change',direction_corrected_lag_rate_per_century='Direction-corrected lag change')[metric])
tracking_model_response_unit=function(metric) if(metric=='standardized_climate_change_rate')
  'Standardized climate change per century' else 'CCA distance per century'
