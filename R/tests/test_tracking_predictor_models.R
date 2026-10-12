# Independent GLS algebra, selection, predictions and chronology-result audit.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
close=function(x,y,tol=1e-8) stopifnot(length(x)==length(y),
  all(abs(as.numeric(x)-as.numeric(y))<=tol*pmax(1,abs(as.numeric(y)))))
paths=c(tracking_primary_results('community'),tracking_primary_results('species'))
for(out in paths) {
  entries=readRDS(file.path(out,'primary_fits.rds'))
  for(e in entries) {
    a=e$audit
    stopifnot(length(unique(a$row_signature))==1L,all(a$method=='REML'))
    eligible=a[a$converged & is.finite(a$delta_AIC)&a$delta_AIC<=2,]
    recommendation=if(nrow(eligible)) eligible$model_type[order(eligible$n_covariance_parameters,eligible$AIC)][1] else NA_character_
    stopifnot(identical(a$aic_recommended,!is.na(recommendation)&a$model_type==recommendation))
    primary=if('MA1' %in% a$model_type) 'MA1' else 'Independent'
    if(!any(a$converged&a$model_type==primary)) {stopifnot(is.null(e$fit),all(!a$selected));next}
    stopifnot(e$selected==primary,sum(a$selected)==1L,all(a$primary_family==primary))
    d=e$data;fit=e$fit
    X=model.matrix(formula(fit),d);X=X[,names(coef(fit)),drop=FALSE]
    # Independently construct residual covariance blocks from fitted parameters.
    ratios=coef(fit$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
    variance_group=all.vars(formula(fit$modelStruct$varStruct))[1]
    sd=fit$sigma*unname(ratios[as.character(d[[variance_group]])])
    V=diag(sd^2)
    phi=if(is.null(fit$modelStruct$corStruct)) NA_real_ else
      as.numeric(coef(fit$modelStruct$corStruct,unconstrained=FALSE))
    for(indices in split(seq_len(nrow(d)),d$series)) {
      if(e$selected=='Independent') R=diag(length(indices)) else if(e$selected=='MA1') {
        lag=abs(outer(d$time_index[indices],d$time_index[indices],'-'))
        R=ifelse(lag==0,1,ifelse(lag==1,phi/(1+phi^2),0))
      } else R=phi^abs(outer(d$time_centuries[indices],d$time_centuries[indices],'-'))
      V[indices,indices]=R*outer(sd[indices],sd[indices])
    }
    ViX=solve(V,X)
    cov=solve(crossprod(X,ViX));beta=cov%*%crossprod(X,solve(V,d$estimate))
    close(coef(fit),beta,1e-6);close(vcov(fit),cov,1e-6)
    pred=reconstruction_predictions(fit,d)
    close(pred$predicted,X%*%coef(fit))
    close(pred$prediction_se,sqrt(rowSums((X%*%cov)*X)),1e-6)
    close(reconstruction_r2(d$estimate,pred$predicted),
      1-sum((d$estimate-pred$predicted)^2)/sum((d$estimate-mean(d$estimate))^2))
    if(e$era=='Holocene') stopifnot(all(d$time_index==d$transition_index),
      all(d$time_centuries==-d$interval_mid_cal_bp/100))
  }
  chronology_out=tracking_bacon_results(if(basename(out)=='community_predictor_models') 'community' else 'species')
  status=read_csv(file.path(chronology_out,'chronology_status.csv'),show_col_types=FALSE)
  co=read_csv(file.path(chronology_out,'chronology_coefficients.csv'),show_col_types=FALSE)
  summary=read_csv(file.path(chronology_out,'chronology_summary.csv'),show_col_types=FALSE)
  n_metrics=if(basename(out)=='community_predictor_models') 3L else 14L
  stopifnot(nrow(status)==1000*n_metrics,!anyDuplicated(status[c('draw','metric')]),
    all(table(status$metric)==1000),!anyDuplicated(co[c('draw','metric','term')]))
  for(i in seq_len(nrow(summary))) {
    row=summary[i,];x=co[co$metric==row$metric & co$term==row$term,]
    stopifnot(row$n_expected==1000,row$n_successful_fits==nrow(x),
      row$n_valid_intervals==sum(is.finite(x$conf_low)&is.finite(x$conf_high)))
    close(row$median,median(x$estimate));close(c(row$q025,row$q975),quantile(x$estimate,c(.025,.975)))
    close(row$sign_agreement,mean(sign(x$estimate)==sign(row$primary_estimate)))
  }
}
# Filtering must preserve original transition-neighbor gaps.
d=tibble(estimate=c(1,NA,2,3),site=factor(c('MORA','MORA','NOCA','NOCA'),levels=c('MORA','NOCA')),
  standardized_climate_change_rate=c(1,2,3,4),fire_activity=c(2,4,1,3),lake=c('A','A','B','B'),
  transition_index=c(1,2,1,2),interval_mid_cal_bp=c(300,200,500,350))
selected=reconstruction_explanatory_input(d,'estimate')
stopifnot(identical(selected$data$time_index,c(1,1,2)),nrow(selected$excluded)==1L)
cat('Independent GLS covariance algebra, model selection, prediction/R2 and all chronology outcomes passed.\n')
