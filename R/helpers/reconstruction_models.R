# Shared GLS helpers for the lake-period models: warning capture, coefficient
# tables with conditional intervals, descriptive R2 and residual diagnostics.
source(here::here('R/helpers/config.R'),local=TRUE)
source(here::here('R/helpers/tracking_data.R'),local=TRUE)
source(here::here('R/helpers/tracking_model_reporting.R'),local=TRUE)
reconstruction_metric_label=function(values) {
  labels=tracking_model_response_label(values)
  labels[is.na(labels)]=values[is.na(labels)]
  labels
}
reconstruction_capture = function(call) {
  warnings=character()
  fit=withCallingHandlers(tryCatch(call(),error=function(e)e),warning=function(w) {
    warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
  list(fit=if(inherits(fit,'error')) NULL else fit,
    error=if(inherits(fit,'error')) conditionMessage(fit) else NA_character_,warnings=unique(warnings))
}
reconstruction_coefficients = function(fit,metric,era,model_type,draw=NA_integer_) {
  tt=summary(fit)$tTable
  df=if(inherits(fit,'lme')) tt[,'DF'] else rep(fit$dims$N-fit$dims$p,nrow(tt))
  margin=qt(.975,df)*tt[,'Std.Error']
  tibble::tibble(metric,era,model_type,draw,term=rownames(tt),estimate=tt[,'Value'],
    std_error=tt[,'Std.Error'],df,p_value=tt[,'p-value'],
    conf_low=tt[,'Value']-margin,conf_high=tt[,'Value']+margin)
}
reconstruction_r2 = function(y,p) {
  denominator=sum((y-mean(y))^2)
  if(denominator>0) 1-sum((y-p)^2)/denominator else NA_real_
}
reconstruction_model_theme = function() ggplot2::theme_minimal(base_size=17)+
  ggplot2::theme(panel.grid.minor=ggplot2::element_blank(),
    strip.text=ggplot2::element_text(size=17,face='bold'),legend.position='bottom')
reconstruction_residual_plot = function(x) {
  qq=ggplot2::ggplot(x,ggplot2::aes(sample=normalized_residual))+
    ggplot2::stat_qq(alpha=.45,size=1.1)+ggplot2::stat_qq_line(color='grey35')+
    ggplot2::facet_wrap(~metric+era,scales='free',labeller=ggplot2::labeller(metric=reconstruction_metric_label))+
    ggplot2::labs(x='Normal quantile',y='Normalized residual')+
    reconstruction_model_theme()
  rv=ggplot2::ggplot(x,ggplot2::aes(predicted,normalized_residual,color=site))+
    ggplot2::geom_hline(yintercept=0,color='grey60')+ggplot2::geom_point(alpha=.45,size=1.1)+
    ggplot2::facet_wrap(~metric+era,scales='free',labeller=ggplot2::labeller(metric=reconstruction_metric_label))+
    ggplot2::labs(x='Fitted value',y='Normalized residual')+
    ggplot2::scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'))+reconstruction_model_theme()
  patchwork::wrap_plots(qq,rv,ncol=1)
}
