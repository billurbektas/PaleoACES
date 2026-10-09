# Covariance selected by the author on 2026-10-09; comparison fits remain audits.
tracking_selected_model_type = function() 'MA1'

# Responses requested for the maintained exploratory workflow. Other responses
# remain available through an explicit --metric=NAME standalone run.
tracking_model_response_names = function() c('lag_rate_per_century','observed_turnover_rate',
  'standardized_climate_change_rate')

tracking_model_response_label = function(metric) switch(metric,
  lag_rate_per_century='Lag-change rate',observed_turnover_rate='Observed community turnover',
  standardized_climate_change_rate='Physical climate-change rate',metric)

tracking_model_response_unit = function(metric) switch(metric,
  lag_rate_per_century='CCA units / century',observed_turnover_rate='CCA units / century',
  standardized_climate_change_rate='Calibration SD / century','Response units')

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

# Show the shared modern mean once per park. Its interval comes from offset 0;
# retain each offset's own fitted uncertainty in the calculation tables/contrasts.
tracking_model_group_means_plot = function(group_means,contrasts,metric,offsets) {
  holocene=group_means[group_means$era=='Holocene',]
  modern=group_means[group_means$era=='Anthropocene' & group_means$offset==0,]
  if(nrow(modern)!=2L || anyDuplicated(modern$site))
    stop('Expected one offset-0 Anthropocene mean per park')
  color=unname(tracking_model_colors()[tracking_selected_model_type()])
  panel_plot=function(x,label,offset_axis=TRUE) {
    x$panel=label
    x$site=factor(x$site,levels=c('MORA','NOCA'))
    x$plot_x=if(offset_axis) x$offset else 0
    p=ggplot2::ggplot(x,ggplot2::aes(plot_x,estimate))+
      ggplot2::geom_hline(yintercept=0,color='grey65',linetype='dashed')+
      ggplot2::geom_errorbar(ggplot2::aes(ymin=conf_low,ymax=conf_high),
        width=if(offset_axis) 20 else .04,color=color,linewidth=.6)+
      ggplot2::geom_point(color=color,size=2.8)+
      ggplot2::facet_grid(panel ~ site,switch='y')+
      ggplot2::labs(x=if(offset_axis) 'Bin offset (years)' else NULL,
        y=tracking_model_response_unit(metric))+
      tracking_model_plot_theme()+ggplot2::theme(strip.placement='outside',
        strip.text.y.left=ggplot2::element_text(angle=0),
        axis.text.x=ggplot2::element_text(angle=if(offset_axis) 45 else 0,
          hjust=if(offset_axis) 1 else .5))
    if(offset_axis) p+ggplot2::geom_line(color=color,linewidth=.6)+
      ggplot2::scale_x_continuous(breaks=offsets) else
      p+ggplot2::scale_x_continuous(breaks=0,labels='Shared modern plots',limits=c(-.5,.5))
  }
  patchwork::wrap_plots(
    panel_plot(holocene,'Holocene fitted mean'),
    panel_plot(modern,'Anthropocene fitted mean',FALSE),
    panel_plot(contrasts,'Anthropocene - Holocene'),ncol=1,heights=c(1,.8,1))+
    patchwork::plot_annotation(
      title=paste('MA(1) fitted group means and contrasts:',tracking_model_response_label(metric)),
      subtitle=paste(length(offsets),'separate offset models; REML, era × site and era/site residual variances'),
      caption=paste('Anthropocene means appear once per park; their 95% intervals are from the offset 0 fit.',
        'Holocene means and contrasts retain all offsets. Bars: unadjusted 95% Satterthwaite intervals.',
        'Rows have separate y-scales; parks share scales within each row. Contrasts use each fit\'s covariance of the means.',
        'Offsets reuse modern plots and are sensitivity fits, not independent replicates. Chronology uncertainty is not propagated.',sep='\n'),
      theme=ggplot2::theme(plot.title=ggplot2::element_text(size=17,face='bold'),
        plot.subtitle=ggplot2::element_text(size=11),
        plot.caption=ggplot2::element_text(size=10,hjust=0)))
}
