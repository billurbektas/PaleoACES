# Independent GLS algebra, selection, predictions and chronology-result audit.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
close=function(x,y,tol=1e-8) stopifnot(length(x)==length(y),
  all(abs(as.numeric(x)-as.numeric(y))<=tol*pmax(1,abs(as.numeric(y)))))
paths=c(tracking_primary_results('community'),tracking_primary_results('species'))
for(out in paths) {
  entries=readRDS(file.path(out,'primary_fits.rds'))
  if(basename(out)=='species_contribution_models') {
    stopifnot(length(entries)==56L)
    for(e in entries) stopifnot(all(as.character(e$data$site)==e$site),
      !'site' %in% all.vars(e$fixed),is.null(e$variance))
    # Presence in just one park must no longer block that park's model.
    for(key in c('Abies amabilis:Holocene:MORA','Abies procera:Holocene:MORA',
                 'Thuja plicata:Holocene:NOCA','Abies procera:Anthropocene:MORA'))
      stopifnot(!is.null(entries[[key]]$fit))
    stopifnot(is.null(entries[['Abies procera:Anthropocene:NOCA']]$fit))
  }
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
    if(basename(out)=='species_contribution_models' && e$era=='Anthropocene' && e$site=='MORA') {
      stopifnot(identical(names(coef(fit)),'(Intercept)'),fit$dims$p==1L)
      close(coef(fit),mean(d$estimate))
      close(sqrt(vcov(fit)[1,1]),sd(d$estimate)/sqrt(nrow(d)))
    }
    if(basename(out)=='species_contribution_models' && e$era=='Anthropocene' && e$site=='NOCA') {
      stopifnot(identical(names(coef(fit)),c('(Intercept)','burnedBurned')),
        identical(levels(d$burned),c('Unburned','Burned')))
      unburned_mean=mean(d$estimate[d$burned=='Unburned'])
      close(coef(fit)[1],unburned_mean)
      close(coef(fit)[2],mean(d$estimate[d$burned=='Burned'])-unburned_mean)
    }
    X=model.matrix(formula(fit),d);X=X[,names(coef(fit)),drop=FALSE]
    # Independently construct residual covariance blocks from fitted parameters.
    if(is.null(fit$modelStruct$varStruct)) {
      sd=rep(fit$sigma,nrow(d))
      stopifnot(length(unique(d$site))==1L,!any(grepl('^site',names(coef(fit)))))
    } else {
      ratios=coef(fit$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
      variance_group=all.vars(formula(fit$modelStruct$varStruct))[1]
      sd=fit$sigma*unname(ratios[as.character(d[[variance_group]])])
    }
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
  if(!isTRUE(getOption('paleoaces.run_bacon_sensitivity',FALSE))) next # Both families are on hold.
  chronology_out=tracking_bacon_results(if(basename(out)=='community_predictor_models') 'community' else 'species')
  status=read_csv(file.path(chronology_out,'chronology_status.csv'),show_col_types=FALSE,
    col_types=cols(fit_error=col_character(),warnings=col_character()))
  co=read_csv(file.path(chronology_out,'chronology_coefficients.csv'),show_col_types=FALSE)
  summary=read_csv(file.path(chronology_out,'chronology_summary.csv'),show_col_types=FALSE)
  n_metrics=if(basename(out)=='community_predictor_models') 3L else 28L
  stopifnot(nrow(status)==1000*n_metrics,!anyDuplicated(status[intersect(c('draw','metric','site'),names(status))]),
    all(table(interaction(status[intersect(c('metric','site'),names(status))],drop=TRUE))==1000),
    !anyDuplicated(co[intersect(c('draw','metric','site','term'),names(co))]))
  for(i in seq_len(nrow(summary))) {
    row=summary[i,];x=co[co$metric==row$metric & co$term==row$term,]
    if('site' %in% names(row)) x=x[x$site==row$site,]
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
cat('Independent GLS covariance algebra, model selection, prediction/R2 and enabled chronology checks passed.\n')

# Independently verify the additional paired-correction GLS. Neither outcome
# may act as an independent replicate of the other on the same transition.
joint_out=here('output/tracking_analysis/primary/era_comparison/joint_correction_effects')
joint=readRDS(file.path(joint_out,'primary_fits.rds'))$joint
fit=joint$fit;d=joint$data
input=read_csv(here('output/cca_tracking_era_model_input.csv'),show_col_types=FALSE)
reselected=tracking_joint_correction_input(input)
stopifnot(nrow(d)==nrow(reselected$data),all(d$paired),
  !anyDuplicated(d[c('era','site','transition_id','correction')]),
  all(table(interaction(d$era,d$site,d$transition_id,drop=TRUE))==2L),
  all(is.finite(d$estimate)),joint$audit$converged,
  joint$audit$covariance_status=='positive_definite',joint$audit$warnings=='')
close(d$estimate,reselected$data$estimate)
stopifnot(identical(d$time_index,reselected$data$time_index))
stopifnot(all(d$time_index[d$era=='Holocene']==d$transition_index[d$era=='Holocene']))
X=model.matrix(formula(fit),d)[,names(coef(fit)),drop=FALSE]
pars=coef(fit$modelStruct$corStruct,unconstrained=FALSE)
ratios=coef(fit$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
sd=fit$sigma*unname(ratios[as.character(d$era_site_correction)])
V=matrix(0,nrow(d),nrow(d))
ViX=matrix(0,nrow(d),ncol(X));Viy=numeric(nrow(d))
blocks=split(seq_len(nrow(d)),d$series)
for(ii in blocks) {
  lag=abs(outer(d$time_index[ii],d$time_index[ii],'-'))
  temporal=ifelse(lag==0,1,ifelse(lag==1,pars[['MA1']]/(1+pars[['MA1']]^2),0))
  same=outer(as.character(d$correction[ii]),as.character(d$correction[ii]),'==')
  pair_rho=pars[[as.character(d$era_site[ii[1]])]]
  R=temporal*ifelse(same,1,pair_rho)
  stopifnot(min(eigen(R,symmetric=TRUE,only.values=TRUE)$values)>0)
  vb=R*outer(sd[ii],sd[ii]);V[ii,ii]=vb
  ViX[ii,]=solve(vb,X[ii,,drop=FALSE]);Viy[ii]=solve(vb,d$estimate[ii])
}
cov=solve(crossprod(X,ViX));beta=cov%*%crossprod(X,Viy)
close(coef(fit),beta,1e-6);close(vcov(fit),cov,1e-6)
mt=read_csv(file.path(joint_out,'model_group_means.csv'),show_col_types=FALSE)
ct=read_csv(file.path(joint_out,'correction_contrasts.csv'),show_col_types=FALSE)
grid=mt |> mutate(era=factor(era,levels=levels(d$era)),site=factor(site,levels=levels(d$site)),
  correction=factor(correction,levels=levels(d$correction)))
Xm=model.matrix(~era*site*correction,grid)[,names(coef(fit)),drop=FALSE]
close(mt$estimate,Xm%*%beta,1e-6)
close(mt$std_error,sqrt(rowSums((Xm%*%cov)*Xm)),1e-6)
for(i in seq_len(nrow(ct))) {
  ii=which(mt$era==ct$era[i] & mt$site==ct$site[i])
  L=Xm[ii[mt$correction[ii]=='Direction'],]-Xm[ii[mt$correction[ii]=='Pace'],]
  close(ct$estimate[i],sum(L*beta),1e-6)
  close(ct$std_error[i],sqrt(as.numeric(L%*%cov%*%L)),1e-6)
  close(c(ct$conf_low[i],ct$conf_high[i]),ct$estimate[i]+c(-1,1)*qt(.975,ct$df[i])*ct$std_error[i])
}
close(ct$p_adjusted,p.adjust(ct$p_value,method='holm'))
close(mt$conf_low,mt$estimate-qt(.975,mt$df)*mt$std_error)
close(mt$conf_high,mt$estimate+qt(.975,mt$df)*mt$std_error)
zero=read_csv(file.path(joint_out,'displayed_mean_zero_tests.csv'),show_col_types=FALSE)
stopifnot(nrow(zero)==12L,!anyDuplicated(zero[c('era','site','correction')]),
  identical(zero$zero_significant,zero$p_zero<.05),
  identical(zero$zero_significant,zero$conf_low>0 | zero$conf_high<0))
close(zero$p_zero,2*pt(-abs(zero$estimate/zero$std_error),zero$df))
# Independently reconstruct both correction effects from endpoints. Effects
# compare final observed and counterfactual lag, not change from initial lag.
for(era_name in c('Holocene','Anthropocene')) {
  path=if(era_name=='Holocene') 'output/cca_tracking_holocene_lake_calculations.csv' else
    'output/cca_tracking_anthropocene_plot_calculations.csv'
  x=read_csv(here(path),show_col_types=FALSE)
  a=sqrt((x$o1_2-x$o1)^2+(x$o2_2-x$o2)^2)
  b=sqrt((x$p1_2-x$p1)^2+(x$p2_2-x$p2)^2)
  final=sqrt((x$o1_2-x$p1_2)^2+(x$o2_2-x$p2_2)^2)
  for(kind in c('pace','direction')) {
    valid=x[[paste0(kind,'_counterfactual_valid')]]
    cx=if(kind=='pace') x$o1+b*(x$o1_2-x$o1)/a else x$o1+a*(x$p1_2-x$p1)/b
    cy=if(kind=='pace') x$o2+b*(x$o2_2-x$o2)/a else x$o2+a*(x$p2_2-x$p2)/b
    independent=(final-sqrt((cx-x$p1_2)^2+(cy-x$p2_2)^2))*100/x$climate_dt_years
    metric=paste0(kind,'_effect_on_lag_per_century')
    close(independent[valid],x[[metric]][valid],1e-12)
    modeled=input |> filter(era==era_name,metric==.env$metric)
    ids=if(era_name=='Holocene') x$transition_id else paste(x$site,x$plot_id,sep=':')
    close(modeled$estimate[match(ids[valid],modeled$transition_id)],independent[valid],1e-12)
  }
}
# Non-neighboring transitions are uncorrelated even if exclusions leave a gap.
toy=data.frame(time_index=c(1L,1L,3L,3L),series='lake',
  era=factor('Holocene',levels=c('Holocene','Anthropocene')),
  site=factor('MORA',levels=c('MORA','NOCA')),
  correction=factor(c('Pace','Direction','Pace','Direction'),levels=c('Pace','Direction')))
R=nlme::corMatrix(nlme::Initialize(corPairedMA1(c(.3,.4,.2,.1,-.2)),toy))[[1]]
close(R[1:2,3:4],rep(0,4));close(R[1,2],.4)
toy$time_index[3:4]=2L
R=nlme::corMatrix(nlme::Initialize(corPairedMA1(c(.3,.4,.2,.1,-.2)),toy))[[1]]
close(R[1,3],.3/(1+.3^2));close(R[1,4],.4*.3/(1+.3^2))
cat('Paired GLS covariance, matched rows, fitted means, correction contrasts and preserved time gaps passed.\n')
