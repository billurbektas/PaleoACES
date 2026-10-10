# Era-specific predictor models for observed and two corrected lag-change rates.
# Rscript R/stages/10c_tracking_predictor_models.R
# --bin-width-years=N uses separately suffixed inputs/outputs; default 1000 only.
# --ensemble-only adds reconstruction summaries from stored fits without refitting.
# Holocene: each offset, MA1 within lake, site residual variances; offset-0
# random-intercept sensitivity. Modern: independent plot residuals, site variances,
# both site + burned and site + elevation + climate_rate + burned; spatial checks.
suppressPackageStartupMessages({
  library(here);library(tidyverse);library(nlme);library(patchwork)
})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_predictor_models.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
args=commandArgs(trailingOnly=TRUE)
width_arg=args[startsWith(args,'--bin-width-years=')]
if(length(width_arg)>1L) stop('Specify --bin-width-years=N once')
width=validate_tracking_width(if(length(width_arg)) as.numeric(sub('--bin-width-years=','',width_arg,fixed=TRUE)) else 1000)
suffix=if(width==1000L) '' else paste0('_',width,'yr')
input_path=here('output',paste0('cca_tracking_era_by_offset',suffix,'.csv'))
combined=read_csv(input_path,show_col_types=FALSE)
if(validate_tracking_model_data(combined)!=width) stop('Requested width differs from input')
offsets=seq(0,width-100,100)
# Author-requested ensemble exclusion; all ten primary offset fits stay unchanged.
ensemble_excluded_offsets=if(width==1000L) 800L else numeric()
metrics=tracking_predictor_responses()
labels=tracking_predictor_labels()
out=here('output/exploratory',paste0('tracking_predictor_models',suffix))
export_ensembles=function(ensembles) {
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  summary=bind_rows(map(ensembles,'summary'))
  audit=bind_rows(map(ensembles,'offset_audit'))
  covariance=bind_rows(map(ensembles,'offset_vcov'))
  if(nrow(summary)!=length(metrics)*4L || nrow(audit)!=length(metrics)*length(offsets) ||
     nrow(covariance)!=length(metrics)*length(offsets)*16L ||
     anyDuplicated(summary[c('metric','term')]) || anyDuplicated(audit[c('metric','offset')]))
    stop('Missing or duplicate reconstruction-ensemble results')
  write_csv(summary,file.path(out,'holocene_ensemble_coefficients.csv'))
  write_csv(audit,file.path(out,'holocene_ensemble_offset_audit.csv'))
  write_csv(covariance,file.path(out,'holocene_ensemble_offset_vcov.csv'))
  saveRDS(list(responses=ensembles,input_md5=unname(tools::md5sum(input_path))),
    file.path(out,'holocene_ensemble_components.rds'))
  notes=c('Holocene reconstruction-ensemble averaging; existing explanatory GLS fits are unchanged.',
    paste(length(offsets)-length(ensemble_excluded_offsets),
      'included offsets, equally weighted; 50,000 joint coefficient samples per included offset and response.'),
    paste('Excluded ensemble offsets:',if(length(ensemble_excluded_offsets))
      paste(ensemble_excluded_offsets,collapse=', ') else 'none'),
    'All configured offset fits and full covariance matrices remain in the audit; excluded offsets receive zero ensemble weight.',
    'Component distribution: multivariate normal centered on fitted coefficients, with the full fitted fixed-effect vcov.',
    'Point estimates are exact means of offset coefficients. Bounds are 2.5 and 97.5 percentiles of the equal mixture.',
    'Intervals are reconstruction-ensemble uncertainty, not conventional confidence intervals. No pooled p-values.',
    'No independence assumption for offsets and no division of uncertainty by sqrt(number of offsets).',
    'Bacon chronology uncertainty is not propagated: transition responses remain their existing chronology-draw medians.',
    'Transition support and temporal coverage differ among offsets; phase-key comparisons align site/lake/time_index with offset 0.',
    'An aligned phase key identifies shifted alternative intervals, not identical ages or independent observations.',
    'All configured fits are required; failed fits or invalid fixed-effect covariance stop the ensemble rather than changing weights.',
    'MA1 boundary fits are retained; offset 800 is excluded from the primary ensemble for all responses at the author\'s request, and its unchanged fit remains flagged in the audit.',
    'Sign consistency is the largest positive/negative/zero coefficient count divided by the number of offsets; it is not a probability or significance test.',
    if(width==1000L) 'Offset 800: direction correction is sensitive to climate-vector rotation around 3,800 BP; the shared slope and site weights amplify the difference.',
    paste('Input MD5:',unname(tools::md5sum(input_path))),
    paste('Seeds by response:',paste(map_int(ensembles,~.x$settings$seed),collapse=', ')))
  writeLines(c(notes,'','Ensemble coefficients:',capture.output(print(as.data.frame(summary))),
    'Offset support, covariance and convergence audit:',capture.output(print(as.data.frame(audit)))),
    file.path(out,'holocene_ensemble_results.txt'))
  if(render_figures) {
    dir.create(here('plot/test_figures'),recursive=TRUE,showWarnings=FALSE)
    ggsave(here('plot/test_figures',paste0('fig_tracking_predictor_ensemble_coefficients',suffix,'.pdf')),
      tracking_reconstruction_ensemble_plot(summary),width=17,height=6.5,device=cairo_pdf,bg='white')
  }
  invisible(summary)
}
ensembles=list()
if('--ensemble-only' %in% args) {
  stored=readRDS(file.path(out,'model_fits.rds'))
  if(stored$width!=width || stored$input_md5!=unname(tools::md5sum(input_path)))
    stop('Stored fits do not match the configured width and current canonical input')
  for(i in seq_along(metrics)) {
    metric=metrics[i]
    ensembles[[metric]]=tracking_reconstruction_ensemble(
      stored$fits[paste(metric,offsets,sep='_')],offsets,width,seed=20261011L+i-1L,
      excluded_offsets=ensemble_excluded_offsets)
    ensembles[[metric]]$draws=NULL
  }
  export_ensembles(ensembles)
  cat('Reconstruction ensemble completed from unchanged stored fits:',out,'\n')
  quit(save='no',status=0)
}
elevation_env=new.env(parent=emptyenv())
load(here('data/MORA_plots.rda'),envir=elevation_env)
elevations=tracking_modern_elevations(elevation_env$plot_info,
  read_csv(here('data/NOCA/NOCA_plots_fromWilson.csv'),show_col_types=FALSE),
  combined |> filter(era=='Anthropocene') |> distinct(site,plot_id))
fits=list(); sensitivities=list(); blocks=list(); exclusions=list()
run_fit=function(metric,era,offset,model_type) {
  selected=tracking_predictor_input(combined,metric,era,if(is.na(offset)) 0 else offset)
  d=selected$data
  if(era=='Anthropocene') d=d |> left_join(elevations,by=c('site','plot_id'),relationship='one-to-one')
  fit_function=switch(model_type,Holocene_MA1=fit_tracking_holocene_predictors,
    Anthropocene_basic=fit_tracking_anthropocene_predictors,
    Anthropocene_extended=fit_tracking_anthropocene_extended_predictors)
  captured=tracking_capture_fit(function() fit_function(d))
  key=paste(metric,era,offset,model_type,sep=' | ')
  if(is.null(captured$fit)) stop(key,': ',captured$error)
  fit=captured$fit
  coefficients=tracking_predictor_coefficients(fit,metric,era,offset,model_type)
  predictions=tracking_predictor_predictions(fit,d,metric,era,offset,model_type)
  theta=if(era=='Holocene') unname(coef(fit$modelStruct$corStruct,unconstrained=FALSE)) else NA_real_
  performance=tibble(metric,era,offset,model_type,n=nrow(d),n_MORA=sum(d$site=='MORA'),
    n_NOCA=sum(d$site=='NOCA'),n_excluded=nrow(selected$excluded),
    R2=tracking_descriptive_r2(d$estimate,predictions$predicted_lag_rate),
    theta,lag1_residual_correlation=theta/(1+theta^2),
    near_correlation_boundary=if(is.na(theta)) FALSE else abs(theta)>.98,
    covariance_status=tracking_covariance_status(fit),converged=TRUE,
    warnings=if(length(captured$warnings)) paste(captured$warnings,collapse='; ') else 'none')
  exclusions[[key]] <<- selected$excluded |> mutate(metric=.env$metric,
    era=.env$era,offset=.env$offset,model_type=.env$model_type)
  blocks[[key]] <<- c(key,paste('Input rows:',nrow(d),'| Excluded:',nrow(selected$excluded)),
    paste('Warnings:',performance$warnings),paste('Covariance uncertainty:',performance$covariance_status),
    capture.output(print(summary(fit))),
    'Residual SDs:',capture.output(print(fit$sigma*coef(fit$modelStruct$varStruct,
      unconstrained=FALSE,allCoef=TRUE))),
    paste('Descriptive in-sample R2 = 1 - SSE/SST:',format(performance$R2,digits=8)),
    'Unadjusted coefficient intervals:',capture.output(print(as.data.frame(coefficients))),
    'Input group support:',capture.output(print(d |> count(site,burned))), '')
  list(fit=fit,data=d,coefficients=coefficients,predictions=predictions,performance=performance)
}
# Complete all main fits before replacing exports. Sensitivity failures are
# recorded explicitly and never change the primary GLS specification or data.
for(metric in metrics) {
  for(offset in offsets) {
    cat('Holocene predictors:',metric,'| offset',offset,'\n')
    key=paste(metric,offset,sep='_')
    fits[[key]]=run_fit(metric,'Holocene',offset,'Holocene_MA1')
    if(offset==0) {
      sensitivity=tracking_lake_intercept_sensitivity(fits[[key]]$fit,fits[[key]]$data,metric)
      sensitivities[[metric]]=sensitivity
      blocks[[paste0(metric,'_lake_sensitivity')]]=c(
        paste('OFFSET-0 RANDOM LAKE INTERCEPT SENSITIVITY:',metric),
        capture.output(print(as.data.frame(sensitivity$summary))),
        if(!is.null(sensitivity$captured$fit)) c(capture.output(summary(sensitivity$captured$fit)),
          capture.output(VarCorr(sensitivity$captured$fit))), '')
    }
  }
  # Integrate this response's selected reconstructions immediately after its Holocene
  # fits. The sampler restores RNG state and never changes a fit or its data.
  ensembles[[metric]]=tracking_reconstruction_ensemble(
    fits[paste(metric,offsets,sep='_')],offsets,width,
    seed=20261011L+match(metric,metrics)-1L,excluded_offsets=ensemble_excluded_offsets)
  ensembles[[metric]]$draws=NULL
  for(type in c('Anthropocene_basic','Anthropocene_extended')) {
    cat('Anthropocene predictors:',metric,'|',type,'\n')
    fits[[paste(metric,type,sep='_')]]=run_fit(metric,'Anthropocene',NA_real_,type)
  }
}
coefficients=bind_rows(map(fits,'coefficients'))
performance=bind_rows(map(fits,'performance'))
predictions=bind_rows(map(fits,'predictions'))
lake_sensitivity=bind_rows(map(sensitivities,'summary'))
holocene_predictions=tracking_prediction_reporting_grid(predictions |> filter(era=='Holocene'))
spatial=map(fits[vapply(fits,function(x) x$performance$era=='Anthropocene',logical(1))],
  ~tracking_spatial_residual_check(.x$predictions))
spatial_checks=bind_rows(map(spatial,'checks'))
spatial_locations=bind_rows(map(spatial,'locations'))
all_exclusions=bind_rows(exclusions)
if(nrow(coefficients)!=length(metrics)*(length(offsets)*4L+3L+5L) ||
   nrow(performance)!=length(metrics)*(length(offsets)+2L) ||
   anyDuplicated(coefficients[c('metric','era','offset','model_type','term')]) ||
   anyDuplicated(performance[c('metric','era','offset','model_type')]) ||
   nrow(lake_sensitivity)!=length(metrics)) stop('Missing or duplicate predictor model results')

dir.create(out,recursive=TRUE,showWarnings=FALSE)
export_ensembles(ensembles)
tables=list(model_coefficients=coefficients,model_performance=performance,
  lake_random_intercept_sensitivity=lake_sensitivity,transition_predictions=predictions,
  holocene_prediction_timeseries=holocene_predictions,model_exclusions=all_exclusions,
  anthropocene_spatial_checks=spatial_checks,anthropocene_elevations=elevations)
iwalk(tables,~write_csv(.x,file.path(out,paste0(.y,'.csv'))))
saveRDS(list(fits=fits,sensitivities=sensitivities,width=width,input_md5=unname(tools::md5sum(input_path))),
  file.path(out,'model_fits.rds'))
notes=c('Exploratory era-specific predictor models; no response transformations.',
  'Responses: observed, pace-corrected and direction-corrected lag-change rates (CCA distance per century).',
  'Holocene: estimate ~ site + climate_rate + fire_activity; REML; MA1 within each lake; site residual SDs.',
  'Each offset uses actual transition medians over valid chronology draws; offsets are sensitivities, not replicates.',
  'Observed and corrected responses have independent validity selection. No draw-support threshold is imposed.',
  'Climate rate is physical seasonal change standardized by pooled legacy calibration SDs per century.',
  'Fire activity is unitless same-window normalized accepted event frequency. MORA lakes share regional fire exposure.',
  'Missing fire coverage excludes that transition from the predictor model, never converts it to zero.',
  'Temporal indices retain actual gaps. MA1 theta gives rho(1)=theta/(1+theta^2), with rho(k)=0 for k>1.',
  'Offset-0 LME: random intercept by lake, same rows and fixed/correlation/variance structure; actual apVar/interval outcomes reported.',
  'A returned covariance matrix does not establish reliable random variance estimation when its estimate is essentially zero.',
  'Predictions are fixed-effect fitted lag-change rates, not cumulative lag levels or newly observed vegetation.',
  '100-year prediction displays repeat supported transition predictions on [age_lo, age_hi); gaps are not filled or extrapolated.',
  'Prediction intervals in the CSV are fixed-effect mean intervals conditional on estimated residual covariance; no chronology propagation.',
  'R2 is descriptive, unweighted, in-sample 1-SSE/SST; it can be negative and does not assess independent validation or model significance.',
  'Modern basic: estimate ~ site + burned; extended: estimate ~ site + elevation + climate_rate + burned.',
  'Both modern models use REML, independent residuals and separate site SDs; no temporal or spatial covariance is fitted.',
  'Elevation is in meters, joined by normalized site/plot identity to original sources; modern inputs are used once per response/model.',
  'Modern references: MORA and Unburned; burned coefficient assumes the same additive effect in both parks.',
  'Only two burned MORA plots: the burn association is mostly supported by NOCA; no site-by-burn interaction is fitted.',
  'Spatial checks: within-park Moran I of normalized residuals, UTM 10N symmetric 8-nearest-neighbor graph, 999 permutations.',
  'Spatial p values are exploratory, conditional on estimated models; no multiplicity correction or automatic covariance change.',
  'Different fixed-effect models are not ranked using REML AIC. Coefficient intervals/tests are unadjusted.',
  'Only four Holocene lakes and two fire histories; site and fire effects are not independent lake-level exposures.',
  paste('Input MD5:',unname(tools::md5sum(input_path))),
  paste('Elevation MD5s:',paste(tools::md5sum(here(c('data/MORA_plots.rda',
    'data/NOCA/NOCA_plots_fromWilson.csv'))),collapse=', ')))
writeLines(c(notes,'','Performance:',capture.output(print(as.data.frame(performance))),
  'Spatial diagnostics:',capture.output(print(as.data.frame(spatial_checks))),
  unlist(blocks),capture.output(sessionInfo())),file.path(out,'model_results.txt'))

if(render_figures) {
  plot_dir=here('plot/test_figures');dir.create(plot_dir,recursive=TRUE,showWarnings=FALSE)
  save_plot=function(name,p,w,h) ggsave(file.path(plot_dir,paste0('fig_tracking_predictor_',name,suffix,'.pdf')),
    p,width=w,height=h,device=cairo_pdf,bg='white')
  common=theme_bw(base_size=17)+theme(panel.grid.minor=element_blank(),
    strip.background=element_rect(fill='#f0f2f5',color=NA),strip.text=element_text(size=16,face='bold'),
    axis.text=element_text(size=14),plot.title=element_text(size=21,face='bold'),
    legend.position='bottom',plot.margin=margin(12,15,12,12))
  palette=c(lag_rate_per_century='#43AA9C',pace_corrected_lag_rate_per_century='#DE85F0',
    direction_corrected_lag_rate_per_century='#8B85F1')
  response_factor=function(x) factor(unname(labels[x]),levels=unname(labels))
  cf=coefficients |> mutate(response=response_factor(metric),term=factor(term,
    levels=c('(Intercept)','siteNOCA','climate_rate','fire_activity','elevation','burnedBurned')))
  offset_summary=bind_rows(cf |> filter(era=='Holocene') |> mutate(term=as.character(term)),
    performance |> filter(era=='Holocene') |> transmute(metric,offset,estimate=R2,
      conf_low=NA_real_,conf_high=NA_real_,response=response_factor(metric),term='R²')) |>
    mutate(term=factor(term,levels=c('(Intercept)','siteNOCA','climate_rate','fire_activity','R²')))
  pc=ggplot(offset_summary,aes(offset,estimate,color=metric))+
    geom_hline(yintercept=0,color='grey60',linetype='dashed')+
    geom_errorbar(data=offset_summary |> filter(term!='R²'),
      aes(ymin=conf_low,ymax=conf_high),width=18,linewidth=.6)+
    geom_line(linewidth=.65)+geom_point(size=2.2)+
    facet_wrap(vars(response,term),scales='free_y',ncol=5)+
    scale_color_manual(values=palette,guide='none')+scale_x_continuous(breaks=offsets)+
    labs(title='Holocene offsets: predictor coefficients and R²',x='Bin offset (years)',
      y='Coefficient estimate / descriptive R²')+
    common+theme(axis.text.x=element_text(angle=45,hjust=1))
  save_plot('offset_coefficients',pc,22,13)
  both=cf |> filter(era=='Anthropocene' | offset==0) |>
    mutate(specification=factor(model_type,levels=c('Holocene_MA1','Anthropocene_basic','Anthropocene_extended'),
      labels=c('Holocene · offset 0','Anthropocene · site + burned','Anthropocene · extended')),
      term=droplevels(term))
  joint=ggplot(both,aes(estimate,term,color=metric))+
    geom_vline(xintercept=0,color='grey65',linetype='dashed')+
    geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.18,linewidth=.75)+
    geom_point(size=2.6)+facet_wrap(vars(response,specification),scales='free',ncol=3)+
    scale_color_manual(values=palette,guide='none')+
    labs(title='Predictor coefficients: Holocene offset 0 and Anthropocene',
      x='Coefficient estimate (original predictor scales)',y=NULL)+common
  save_plot('era_coefficients_offset_0',joint,19,13)
  eras=read_csv(here('output/holocene_era_catalog.csv'),show_col_types=FALSE)
  subphases=read_csv(here('output/holocene_era_climate_change_subphases.csv'),show_col_types=FALSE)
  period_labels=bind_rows(subphases |> transmute(label=subphase_id,older_cal_bp,younger_cal_bp),
    eras |> filter(era_class=='relative stability') |> transmute(label=era_id,older_cal_bp,younger_cal_bp)) |>
    mutate(midpoint=(older_cal_bp+younger_cal_bp)/2)
  lakes=c('JayBath','LogWallow','ReflectionPond','PantherPotholes')
  grid=holocene_predictions |> mutate(response=response_factor(metric),lake=factor(lake,levels=lakes))
  # Follow each offset from older to younger intervals. Duplicate a shared
  # boundary to draw a vertical jump; a missing interval starts a new path.
  # Horizontal sections retain the interval's fitted rate without interpolation.
  trajectories=predictions |> filter(era=='Holocene') |>
    mutate(response=response_factor(metric),lake=factor(lake,levels=lakes)) |>
    arrange(metric,site,lake,offset,desc(age_hi)) |>
    group_by(metric,site,lake,offset) |>
    mutate(path_segment=cumsum(row_number()==1L | age_hi!=lag(age_lo))) |>
    ungroup() |> mutate(path_age=map2(age_hi,age_lo,~c(.x,.y))) |> unnest(path_age)
  periods=ggplot(grid,aes(t,predicted_lag_rate))+
    geom_rect(data=eras,aes(xmin=younger_cal_bp,xmax=older_cal_bp,ymin=-Inf,ymax=Inf,fill=era_class),
      inherit.aes=FALSE,alpha=.55,color=NA)+
    geom_text(data=period_labels,aes(x=midpoint,y=Inf,label=label),inherit.aes=FALSE,
      size=3.5,angle=90,hjust=1.1,vjust=.5,color='grey35')+
    geom_hline(yintercept=0,color='grey50',linetype='dashed',linewidth=.4)+
    geom_path(data=trajectories,
      aes(x=path_age,y=predicted_lag_rate,color=factor(offset),
        group=interaction(metric,site,lake,offset,path_segment)),
      linewidth=.65,alpha=.8)+
    facet_grid(response~lake,scales='free_y')+scale_x_reverse(breaks=seq(0,10000,2000))+
    scale_fill_manual(values=c(`climate change`='#D3D3D6',`relative stability`='#EEEEF0'),guide='none')+
    scale_color_viridis_d(name='Offset (years)',option='D',end=.85)+
    labs(title='Predicted Holocene lag-change rates within supported intervals',
      x='Age (cal BP)',y='Lag-change rate (CCA distance per century)')+common
  save_plot('holocene_predictions',periods,20,13)
  r2=ggplot(performance |> filter(era=='Holocene') |> mutate(response=response_factor(metric)),
    aes(offset,R2,color=metric))+
    geom_hline(yintercept=0,color='grey60',linetype='dashed')+geom_line(linewidth=.8)+geom_point(size=3)+
    facet_wrap(~response,nrow=1)+scale_color_manual(values=palette,guide='none')+
    scale_x_continuous(breaks=offsets)+labs(title='Holocene predictor models: descriptive in-sample R²',
      x='Bin offset (years)',y='R² = 1 − SSE/SST')+common+theme(axis.text.x=element_text(angle=45,hjust=1))
  modern_r2=ggplot(performance |> filter(era=='Anthropocene') |> mutate(response=response_factor(metric),
    specification=factor(model_type,levels=c('Anthropocene_basic','Anthropocene_extended'),
      labels=c('Site + burned','Extended'))),aes(specification,R2,color=metric))+
    geom_hline(yintercept=0,color='grey60',linetype='dashed')+geom_point(size=3)+
    facet_wrap(~response,nrow=1)+scale_color_manual(values=palette,guide='none')+
    labs(x='Anthropocene specification',y='R² = 1 − SSE/SST')+common
  save_plot('R2',r2/modern_r2+plot_layout(heights=c(2,1)),17,10)
  # One diagnostic PDF: each response has Holocene QQ/residual panels by offset,
  # followed by modern basic and extended diagnostics with park-specific QQs.
  cairo_pdf(file.path(plot_dir,paste0('fig_tracking_predictor_residuals',suffix,'.pdf')),width=17,height=10)
  for(metric in metrics) {
    h=predictions |> filter(era=='Holocene',.data$metric==.env$metric)
    qq=ggplot(h,aes(sample=normalized_residual))+stat_qq(size=1.1,alpha=.65)+stat_qq_line(color='grey45')+
      facet_wrap(~offset,ncol=5)+labs(title=paste(labels[metric],'· Holocene normalized residuals'),
        x='Normal theoretical quantile',y='Normalized residual')+common
    rv=ggplot(h,aes(predicted_lag_rate,normalized_residual,color=site))+
      geom_hline(yintercept=0,color='grey55',linetype='dashed')+geom_point(size=1.7,alpha=.65)+
      facet_wrap(~offset,ncol=5)+scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'))+
      labs(x='Fitted lag-change rate',y='Normalized residual')+common
    print(qq);print(rv)
    a=predictions |> filter(era=='Anthropocene',.data$metric==.env$metric)
    aq=ggplot(a,aes(sample=normalized_residual))+stat_qq(size=1.1,alpha=.5)+stat_qq_line(color='grey45')+
      facet_grid(model_type~site)+labs(title=paste(labels[metric],'· modern models'),
        x='Normal theoretical quantile',y='Normalized residual')+common
    ar=ggplot(a,aes(predicted_lag_rate,normalized_residual,color=site))+
      geom_hline(yintercept=0,color='grey55',linetype='dashed')+geom_point(size=1.2,alpha=.4)+
      facet_wrap(~model_type,nrow=1)+scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'))+
      labs(x='Fitted lag-change rate',y='Normalized residual')+common
    print(aq+ar+plot_layout(widths=c(1,1)))
  }
  dev.off()
  maps=spatial_locations |> mutate(response=response_factor(metric),
    panel=paste(response,sub('Anthropocene_','',model_type),sep=' · '))
  map_plot=ggplot(maps,aes(easting_m/1000,northing_m/1000,color=normalized_residual))+
    geom_point(size=1.5,alpha=.75)+facet_wrap(vars(panel,site),ncol=4,scales='free')+
    scale_color_gradient2(low='#2874A6',mid='white',high='#BB3D40',midpoint=0)+
    labs(title='Anthropocene normalized residuals in space',x='UTM 10N easting (km)',y='UTM 10N northing (km)',
      color='Normalized\nresidual')+common
  save_plot('spatial_residuals',map_plot,20,13)
}
cat('Predictor model outputs:',out,'\n')
