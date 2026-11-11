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
# Fit statistics of a GLS for the model tables of the report (Bills, 11 Nov
# 2026): the residual df are those of every t-test and interval of the model.
# The fits are REML, so the log-likelihood and AIC compare covariance
# structures with the same fixed effects only.
reconstruction_fit_statistics = function(fit) tibble::tibble(coefficients=fit$dims$p,
  df_residual=fit$dims$N-fit$dims$p,sigma=fit$sigma,log_lik_REML=as.numeric(logLik(fit)),AIC=AIC(fit))
reconstruction_model_theme = function() ggplot2::theme_minimal(base_size=17)+
  ggplot2::theme(panel.grid.minor=ggplot2::element_blank(),
    strip.text=ggplot2::element_text(size=17,face='bold'),legend.position='bottom')
reconstruction_residual_plot = function(x, ncol = 3) {
  # One facet per response with a one-line title, so the panels keep their
  # height. The era models have no continuous predictor, so the fitted values
  # take one value per period type and park: the residuals are shown by group
  # instead of against fitted values, which shows the same and reads better.
  x$metric = factor(reconstruction_metric_label(x$metric), levels = unique(reconstruction_metric_label(x$metric)))
  x$era = factor(x$era, levels = c('Holocene-S', 'Holocene-C', 'Anthropocene'))
  qq=ggplot2::ggplot(x,ggplot2::aes(sample=normalized_residual))+
    ggplot2::stat_qq(alpha=.4,size=1.3)+ggplot2::stat_qq_line(color='grey35')+
    ggplot2::facet_wrap(~metric,scales='free',ncol=ncol)+
    ggplot2::labs(title='Normal quantile plots',x='Normal quantile',y='Normalized residual')+
    reconstruction_model_theme()
  park_colors=c(MORA='#294EFF',NOCA='#D94000')
  by_group=ggplot2::ggplot(x,ggplot2::aes(era,normalized_residual,color=site))+
    ggplot2::geom_hline(yintercept=0,color='grey60')+
    ggplot2::geom_point(alpha=.3,size=1,position=ggplot2::position_jitterdodge(jitter.width=.18,dodge.width=.7,seed=1))+
    ggplot2::geom_boxplot(fill=NA,outlier.shape=NA,width=.5,linewidth=.6,position=ggplot2::position_dodge(width=.7))+
    ggplot2::facet_wrap(~metric,scales='free_y',ncol=ncol)+
    ggplot2::scale_color_manual(values=park_colors,name=NULL)+
    ggplot2::labs(title='Normalized residuals by period type and park',x=NULL,y='Normalized residual')+
    reconstruction_model_theme()+ggplot2::theme(legend.position='bottom')
  patchwork::wrap_plots(qq,by_group,ncol=1)
}
