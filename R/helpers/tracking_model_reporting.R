# Covariance selected by the author on 2026-10-09; comparison fits remain audits.
tracking_selected_model_type = function() 'MA1'

# Responses requested for the maintained exploratory workflow. Other responses
# remain available through an explicit --metric=NAME standalone run.
tracking_model_response_names = function() c('lag_rate_per_century','observed_turnover_rate')

tracking_model_response_label = function(metric) switch(metric,
  lag_rate_per_century='Lag-change rate',observed_turnover_rate='Observed community turnover',metric)

tracking_selected_model_results = function(x) {
  selected=x[x$model_type==tracking_selected_model_type(),,drop=FALSE]
  if(!nrow(selected)) stop('No results for the selected tracking covariance')
  selected
}

tracking_model_colors = function() c(AR1='#2563eb',MA1='#d42d75',Independent='#64748b')

# Shared presentation for offset coefficients, park contrasts and lake sensitivity.
tracking_model_plot_theme = function(base_size=12) {
  ggplot2::theme_minimal(base_size=base_size)+ggplot2::theme(
    legend.position='bottom',panel.grid.minor=ggplot2::element_blank(),
    plot.title=ggplot2::element_text(face='bold'),
    plot.caption=ggplot2::element_text(hjust=0,size=10))
}
