# Labels shared by primary model figures.
source(here::here('R/helpers/tracking_result_paths.R'),local=TRUE)
# Labels for model diagnostics, keyed by the PLAN.md response names.
tracking_model_response_label=function(metric) unname(c(lag_rate='Lag rate',lag='Lag',turnover_rate='Turnover rate',displacement='Displacement',
  climate_change='Climate change',pace_effect_total='Pace contribution (total)',direction_effect_total='Direction contribution (total)',
  climate_rate='Climate change rate',pace_effect='Pace contribution',direction_effect='Direction contribution')[metric])
# Period types of the era models (PLAN.md section 2), in model order.
ERA_PERIOD_TYPES=c('Holocene-S','Holocene-C','Anthropocene')
# The era-model responses (PLAN.md Step 5a), with their axis labels and units.
ERA_RESPONSES=c(climate_rate='Standardized climate change rate per century',
  climate_change='Standardized climate change (calibration SD)',
  turnover_rate='Turnover rate (CCA distance per century)',displacement='Displacement (CCA distance)',
  lag_rate='Lag rate (CCA distance per century)',
  lag='Lag (CCA distance)',
  pace_effect='Pace contribution (CCA distance per century)',direction_effect='Direction contribution (CCA distance per century)',
  pace_effect_total='Pace contribution (CCA distance)',direction_effect_total='Direction contribution (CCA distance)')
