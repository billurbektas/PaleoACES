# Labels shared by primary model figures.
source(here::here('R/helpers/tracking_result_paths.R'),local=TRUE)
# Labels for model diagnostics, keyed by the PLAN.md response names.
# The labels follow the wording of the report: the totals are 'not divided by
# time', and the displacement is the turnover not divided by time (24 Nov 2026).
tracking_model_response_label=function(metric) unname(c(lag_rate='Lag rate',lag='Lag (not divided by time)',turnover_rate='Turnover rate',
  displacement='Turnover (not divided by time)',climate_change='Climate change (not divided by time)',
  pace_effect_total='Pace contribution (not divided by time)',direction_effect_total='Direction contribution (not divided by time)',
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
