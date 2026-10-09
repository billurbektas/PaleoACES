# Offline combined-input and covariance checks for the provisional model stage.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
stopifnot(identical(tracking_model_response_names(),c('lag_rate_per_century','observed_turnover_rate',
  'standardized_climate_change_rate')),
  tracking_model_response_unit('standardized_climate_change_rate')=='Calibration SD / century')
equal=function(a,b) stopifnot(isTRUE(all.equal(a,b,tolerance=1e-9,check.attributes=FALSE)))
fail=function(x) stopifnot(inherits(tryCatch({force(x);NULL},error=identity),'error'))
read_tracking=function(stem) read_csv(here('output',paste0('cca_tracking_',stem,'.csv')),show_col_types=FALSE)
b=read_tracking('holocene_lake_by_offset');a=read_tracking('anthropocene_plot_model_input')
c=read_tracking('era_by_offset')
contract=c('era','site','lake','plot_id','offset','age_hi','age_lo','interval_mid_cal_bp',
  'vegetation_t1_year','vegetation_t2_year','climate_t1_midyear','climate_t2_midyear',
  'vegetation_dt_years','climate_dt_years','metric','estimate','response_valid',
  'standardized_climate_change_rate','fire_activity','fire_coverage_valid','high_fire','burned',
  'n_draws_present','n_draws_nmin2','n_samples_t1_median','n_samples_t2_median','longitude','latitude')
stopifnot(identical(names(c),contract),nrow(c)==(nrow(b)+nrow(a))*7L)
validate_tracking_model_data(c)
key=function(x,fields) do.call(paste,c(as.data.frame(x[fields]),sep='::'))
h=c |> filter(era=='Holocene');modern=c |> filter(era=='Anthropocene')
for(metric in tracking_response_names()) {
  hm=h[h$metric==metric,];am=modern[modern$metric==metric,]
  hm=hm[match(key(b,tracking_transition_keys()),key(hm,tracking_transition_keys())),]
  am=am[match(key(a,c('site','plot_id')),key(am,c('site','plot_id'))),]
  equal(hm$estimate,b[[metric]]);equal(am$estimate,a[[metric]])
  for(name in c('interval_mid_cal_bp','vegetation_dt_years','climate_dt_years',
    'standardized_climate_change_rate','fire_activity','fire_coverage_valid','high_fire',
    'n_draws_present','n_draws_nmin2','n_samples_t1_median','n_samples_t2_median'))
    equal(hm[[name]],b[[name]])
  for(name in c('vegetation_t1_year','vegetation_t2_year','climate_t1_midyear',
    'climate_t2_midyear','vegetation_dt_years','climate_dt_years',
    'standardized_climate_change_rate','burned')) equal(am[[name]],a[[name]])
  for(offset in seq(0,900,100)) {
    d=tracking_offset_model_input(c,metric,offset)$data
    expected_h=b[b$offset==offset & is.finite(b[[metric]]),]
    expected_a=a[is.finite(a[[metric]]),]
    stopifnot(sum(d$era=='Holocene')==nrow(expected_h),
      sum(d$era=='Anthropocene')==nrow(expected_a),
      all(is.na(d$offset[d$era=='Anthropocene'])),
      all(d$time_index[d$era=='Holocene']==
        (d$interval_mid_cal_bp[d$era=='Holocene']-offset)/1000))
  }
}
for(offset in seq(0,900,100)) {
  d=tracking_offset_model_input(c,'standardized_climate_change_rate',offset)$data
  dh=d[d$era=='Holocene',];da=d[d$era=='Anthropocene',]
  bh=b[b$offset==offset,]
  dh=dh[match(key(bh,tracking_transition_keys()),key(dh,tracking_transition_keys())),]
  da=da[match(key(a,c('site','plot_id')),key(da,c('site','plot_id'))),]
  stopifnot(nrow(d)==nrow(bh)+nrow(a),all(d$metric=='standardized_climate_change_rate'),
    !anyDuplicated(d[c('series','time_index')]),all(d$response_valid))
  equal(dh$estimate,bh$standardized_climate_change_rate)
  equal(da$estimate,a$standardized_climate_change_rate)
}
# Undefined tracking responses cannot filter a finite climate observation.
undefined_tracking=c
index=undefined_tracking$era=='Anthropocene' & undefined_tracking$plot_id==a$plot_id[1] &
  undefined_tracking$metric=='lag_rate_per_century'
index[is.na(index)]=FALSE
undefined_tracking$estimate[index]=NA_real_;undefined_tracking$response_valid[index]=FALSE
climate=tracking_offset_model_input(undefined_tracking,'standardized_climate_change_rate',0)
stopifnot(nrow(climate$data)==nrow(b[b$offset==0,])+nrow(a),!nrow(climate$excluded))
# A missing physical rate excludes just that climate response, with its identity.
missing_climate=c
index=missing_climate$era=='Anthropocene' & missing_climate$plot_id==a$plot_id[1]
index[is.na(index)]=FALSE
missing_climate$standardized_climate_change_rate[index]=NA_real_
climate=tracking_offset_model_input(missing_climate,'standardized_climate_change_rate',0)
stopifnot(sum(climate$data$era=='Anthropocene')==nrow(a)-1L,nrow(climate$excluded)==1L,
  climate$excluded$plot_id==a$plot_id[1])
conflicting_climate=c
index=which(conflicting_climate$era=='Anthropocene')[1]
conflicting_climate$standardized_climate_change_rate[index]=
  conflicting_climate$standardized_climate_change_rate[index]+1
fail(tracking_offset_model_input(conflicting_climate,'standardized_climate_change_rate',0))
lake_locations=read_csv(here('output/chelsa_paleo_ponds.csv'),show_col_types=FALSE) |>
  distinct(site,lake,longitude=lon,latitude=lat)
plot_locations=bind_rows(
  read_csv(here('output/MORA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='MORA',plot_id=toupper(plot_id),longitude,latitude),
  read_csv(here('output/NOCA_plot_info_fire.csv'),show_col_types=FALSE) |>
    transmute(site='NOCA',plot_id=toupper(plot_id),longitude,latitude))
lh=lake_locations[match(key(h,c('site','lake')),key(lake_locations,c('site','lake'))),]
ap=plot_locations[match(paste(modern$site,toupper(modern$plot_id)),
  paste(plot_locations$site,plot_locations$plot_id)),]
equal(h$longitude,lh$longitude);equal(h$latitude,lh$latitude)
equal(modern$longitude,ap$longitude);equal(modern$latitude,ap$latitude)
stopifnot('EAGl-120' %in% modern$plot_id,
  sum(!modern$response_valid[modern$metric=='angle_degrees'])==142L)
fail(combine_tracking_model_data(b,a,lake_locations,plot_locations[-1,]))
fail(combine_tracking_model_data(b,a,lake_locations,bind_rows(plot_locations,plot_locations[1,])))
fail(validate_tracking_model_data(c[-1,]))
schema=read_tracking('schema') |> filter(dataset=='cca_tracking_era_by_offset')
stopifnot(identical(schema$column,contract),schema$unit[schema$column=='estimate']=='metric_dependent')

# Dropping a whole transition preserves time gaps rather than renumbering rows.
gap=c |> filter(!(era=='Holocene' & lake=='PantherPotholes' & offset==0 & interval_mid_cal_bp==5000))
g=tracking_offset_model_input(gap,'lag_rate_per_century',0)$data
stopifnot(identical(g$time_index[g$era=='Holocene' & g$lake=='PantherPotholes'],
  c(1L,2L,3L,4L,6L,7L,8L,9L,10L)))
toy=data.frame(series='lake',time_index=c(0L,1L,3L))
ma=corMatrix(Initialize(corARMA(value=.4,p=0,q=1,form=~time_index | series),data=toy))
ar=corMatrix(Initialize(corAR1(value=.4,form=~time_index | series),data=toy))
if(is.list(ma)) ma=ma[[1]];if(is.list(ar)) ar=ar[[1]]
equal(ma[1,2],.4/(1+.4^2));equal(ma[1,3],0);equal(ma[2,3],0)
equal(ar[1,3],.4^3);equal(ar[2,3],.4^2)

for(metric in tracking_model_response_names()) {
coeff=read_csv(here('output/exploratory/tracking_offset_models',metric,'model_coefficients.csv'),
  show_col_types=FALSE)
stopifnot(nrow(coeff)==120L,setequal(coeff$model_type,c('AR1','MA1','Independent')),
  setequal(coeff$offset,seq(0,900,100)),all(coeff$converged),
  !anyDuplicated(coeff[c('metric','offset','model_type','term')]),
  all(is.na(coeff$correlation_parameter[coeff$model_type=='Independent'])),
  all(is.finite(coeff$correlation_parameter[coeff$model_type!='Independent'])))
equal(coeff$t_value,coeff$estimate/coeff$std_error)
equal(coeff$p_value,2*pt(-abs(coeff$t_value),df=coeff$df))
equal(coeff$conf_low,coeff$estimate-qt(.975,coeff$df)*coeff$std_error)
equal(coeff$conf_high,coeff$estimate+qt(.975,coeff$df)*coeff$std_error)
stopifnot(tracking_selected_model_type()=='MA1',
  nrow(tracking_selected_model_results(coeff))==40L)
for(offset in seq(0,900,100)) {
  d=tracking_offset_model_input(c,metric,offset)$data
  co=coeff[coeff$offset==offset,]
  stopifnot(all(co$n_holocene==sum(d$era=='Holocene')),all(co$n_anthropocene==607L),
    all(co$df==nrow(d)-4L))
  # Independent residuals with constant variance within each saturated era/site
  # cell have the same point estimates as ordinary cell means / lm coefficients.
  independent=co[co$model_type=='Independent',]
  reference=coef(lm(estimate ~ era * site,data=d))
  equal(independent$estimate,unname(reference[independent$term]))
}
contrasts=read_csv(here('output/exploratory/tracking_offset_models',metric,'model_contrasts.csv'),
  show_col_types=FALSE)
stopifnot(nrow(contrasts)==60L,!anyDuplicated(contrasts[c('metric','offset','model_type','site')]),
  all(contrasts$contrast=='Anthropocene - Holocene'))
equal(contrasts$t_value,contrasts$estimate/contrasts$std_error)
equal(contrasts$p_value,2*pt(-abs(contrasts$t_value),df=contrasts$df))
equal(contrasts$conf_low,contrasts$estimate-qt(.975,contrasts$df)*contrasts$std_error)
equal(contrasts$conf_high,contrasts$estimate+qt(.975,contrasts$df)*contrasts$std_error)
stopifnot(nrow(tracking_selected_model_results(contrasts))==20L)
for(i in seq_len(nrow(contrasts))) {
  ct=contrasts[i,];co=coeff[coeff$offset==ct$offset & coeff$model_type==ct$model_type,]
  expected=co$estimate[co$term=='eraAnthropocene']
  if(ct$site=='NOCA') expected=expected+co$estimate[co$term=='eraAnthropocene:siteNOCA']
  equal(ct$estimate,expected)
  d=tracking_offset_model_input(c,metric,ct$offset)$data
  equal(ct$n_holocene,sum(d$era=='Holocene' & d$site==ct$site))
  equal(ct$n_anthropocene,sum(d$era=='Anthropocene' & d$site==ct$site))
}
# Reconstruct penalized likelihoods, paired comparisons and relative weights.
comparison=read_csv(here('output/exploratory/tracking_offset_models',metric,'model_comparison.csv'),
  show_col_types=FALSE)
stopifnot(nrow(comparison)==30L,
  !anyDuplicated(comparison[c('metric','offset','model_type')]),
  setequal(comparison$model_type,c('AR1','MA1','Independent')),
  all(comparison$method=='REML'),all(comparison$converged),
  all(is.finite(comparison$log_likelihood)),all(is.finite(comparison$AIC)),
  all(comparison$n_parameters==ifelse(comparison$model_type=='Independent',8L,9L)))
equal(comparison$AIC,-2*comparison$log_likelihood+2*comparison$n_parameters)
for(offset in seq(0,900,100)) {
  d=tracking_offset_model_input(c,metric,offset)$data
  x=comparison[comparison$offset==offset,]
  stopifnot(nrow(x)==3L,setequal(x$model_type,c('AR1','MA1','Independent')),
    all(x$n==nrow(d)),all(x$n_holocene==sum(d$era=='Holocene')),
    all(x$n_anthropocene==607L))
  equal(x$delta_AIC,x$AIC-min(x$AIC))
  w=exp(-(x$AIC-min(x$AIC))/2)
  equal(x$akaike_weight,w/sum(w));equal(sum(x$akaike_weight),1)
  equal(x$aic_rank,rank(x$AIC,ties.method='min'))
  # A separate explicit NULL-correlation fit checks the new covariance candidate,
  # its exported likelihood and parameter count without relying on table arithmetic.
  ref=gls(estimate ~ era * site,data=d,correlation=NULL,
    weights=varIdent(form=~1 | era_site),method='REML',na.action=na.fail,
    control=glsControl(msMaxIter=200))
  stopifnot(is.null(ref$modelStruct$corStruct),attr(logLik(ref),'df')==8L)
  equal(x$log_likelihood[x$model_type=='Independent'],as.numeric(logLik(ref)))
  equal(x$AIC[x$model_type=='Independent'],AIC(ref))
  ct=contrasts[contrasts$offset==offset & contrasts$model_type=='Independent',]
  for(site in ct$site) {
    cell=d[d$site==site,]
    equal(ct$estimate[ct$site==site],
      mean(cell$estimate[cell$era=='Anthropocene'])-mean(cell$estimate[cell$era=='Holocene']))
  }
}
# Group means are reported only for MA1, with no averaging across offsets.
group_means=read_csv(here('output/exploratory/tracking_offset_models',metric,'model_group_means.csv'),show_col_types=FALSE)
stopifnot(identical(names(group_means),c('metric','offset','model_type','site','era',
  'estimate','std_error','df','conf_low','conf_high','n')),
  nrow(group_means)==40L,all(group_means$metric==metric),all(group_means$model_type=='MA1'),
  !anyDuplicated(group_means[c('offset','site','era')]),all(group_means$df>0))
equal(group_means$conf_low,group_means$estimate-qt(.975,group_means$df)*group_means$std_error)
equal(group_means$conf_high,group_means$estimate+qt(.975,group_means$df)*group_means$std_error)
for(offset in seq(0,900,100)) {
  d=tracking_offset_model_input(c,metric,offset)$data
  gm=group_means[group_means$offset==offset,]
  co=coeff[coeff$offset==offset & coeff$model_type=='MA1',]
  for(i in seq_len(nrow(gm))) {
    terms=c('(Intercept)',if(gm$era[i]=='Anthropocene') 'eraAnthropocene',
      if(gm$site[i]=='NOCA') 'siteNOCA',
      if(gm$site[i]=='NOCA' && gm$era[i]=='Anthropocene') 'eraAnthropocene:siteNOCA')
    equal(gm$estimate[i],sum(co$estimate[co$term %in% terms]))
    equal(gm$n[i],sum(d$era==gm$era[i] & d$site==gm$site[i]))
  }
  ct=contrasts[contrasts$offset==offset & contrasts$model_type=='MA1',]
  for(site in ct$site) equal(ct$estimate[ct$site==site],
    gm$estimate[gm$site==site & gm$era=='Anthropocene']-
      gm$estimate[gm$site==site & gm$era=='Holocene'])
}
# Check the means and differences against X V X' from an independent MA1 fit.
# Contrast variance must retain covariance between the two fitted means.
d=tracking_offset_model_input(c,metric,0)$data
ref=gls(estimate ~ era * site,data=d,correlation=corARMA(p=0,q=1,form=~time_index | series),
  weights=varIdent(form=~1 | era_site),method='REML',na.action=na.fail,
  control=glsControl(msMaxIter=200))
gm=group_means[group_means$offset==0,]
grid=data.frame(era=factor(gm$era,levels=levels(d$era)),site=factor(gm$site,levels=levels(d$site)))
X=model.matrix(~era * site,grid);V=vcov(ref)
equal(gm$std_error,sqrt(diag(X %*% V %*% t(X))))
ct=contrasts[contrasts$offset==0 & contrasts$model_type=='MA1',]
for(site in ct$site) {
  L=X[gm$site==site & gm$era=='Anthropocene',]-X[gm$site==site & gm$era=='Holocene',]
  equal(ct$std_error[ct$site==site],sqrt(as.numeric(L %*% V %*% L)))
}
for(stem in c('coefficients','contrasts','residuals','aic','group_means')) {
  pdf=here('plot/test_figures',paste0('fig_tracking_model_',stem,'_',metric,'.pdf'))
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
    stopifnot(file.exists(pdf))
    info=system2('pdfinfo',shQuote(pdf),stdout=TRUE)
    stopifnot(as.integer(sub('^Pages:\\s*','',grep('^Pages:',info,value=TRUE)))==1L)
  }
}
stopifnot(!file.exists(here('R/diagnostics/explore_tracking_era_models.R')),
  !file.exists(here('output/cca_tracking_era_comparison.csv')),
  !dir.exists(here('output/exploratory/tracking_era_models')))

# Lake sensitivity is exactly the offset-0 comparison, using its own park's
# modern plots. Independently match selections to canonical source records.
lake_out=here('output/exploratory/tracking_lake_sensitivity',metric,'offset_0')
lc=read_csv(file.path(lake_out,'model_coefficients.csv'),show_col_types=FALSE)
lt=read_csv(file.path(lake_out,'model_contrasts.csv'),show_col_types=FALSE)
stopifnot(nrow(tracking_selected_model_results(lc))==8L,
  nrow(tracking_selected_model_results(lt))==4L)
stopifnot(nrow(lc)==16L,nrow(lt)==8L,all(lc$offset==0),all(lt$offset==0),
  setequal(lc$model_type,c('AR1','MA1')),all(lc$converged),all(lt$converged),
  !anyDuplicated(lc[c('site','lake','model_type','term')]),
  !anyDuplicated(lt[c('site','lake','model_type')]))
for(lake in unique(b$lake)) {
  selected=tracking_lake_model_input(c,metric,lake,0)$data
  bh=b[b$lake==lake & b$offset==0 & is.finite(b[[metric]]),]
  park=unique(bh$site)
  ma=a[a$site==park & is.finite(a[[metric]]),]
  stopifnot(all(selected$site==park),all(selected$lake[selected$era=='Holocene']==lake),
    setequal(selected$plot_id[selected$era=='Anthropocene'],ma$plot_id),
    setequal(key(selected[selected$era=='Holocene',],tracking_transition_keys()),
      key(bh,tracking_transition_keys())))
  for(type in c('AR1','MA1')) {
    co=lc[lc$lake==lake & lc$model_type==type,]
    ct=lt[lt$lake==lake & lt$model_type==type,]
    equal(ct$estimate,co$estimate[co$term=='eraAnthropocene'])
    equal(co$estimate[co$term=='(Intercept)']+ct$estimate,mean(ma[[metric]]))
    stopifnot(all(co$n_holocene==nrow(bh)),all(co$n_anthropocene==nrow(ma)),
      all(ct$n_holocene==nrow(bh)),all(ct$n_anthropocene==nrow(ma)),
      all(co$df==nrow(selected)-2L))
  }
}
for(x in list(lc,lt)) {
  equal(x$t_value,x$estimate/x$std_error)
  equal(x$p_value,2*pt(-abs(x$t_value),df=x$df))
  equal(x$conf_low,x$estimate-qt(.975,x$df)*x$std_error)
  equal(x$conf_high,x$estimate+qt(.975,x$df)*x$std_error)
  stopifnot(identical(x$near_correlation_boundary,abs(x$correlation_parameter)>.98))
}
flagged=lt |> filter(near_correlation_boundary)
expected_boundary=switch(metric,lag_rate_per_century=c('ReflectionPond','PantherPotholes'),
  observed_turnover_rate='JayBath',standardized_climate_change_rate='PantherPotholes')
stopifnot(nrow(flagged)==length(expected_boundary),all(flagged$model_type=='MA1'),
  setequal(flagged$lake,expected_boundary))
fail(tracking_lake_model_input(c,metric,'UnknownLake',0))
lgap=c |> filter(!(era=='Holocene' & lake=='LogWallow' & offset==0 & interval_mid_cal_bp==2000))
lg=tracking_lake_model_input(lgap,metric,'LogWallow',0)$data
stopifnot(identical(lg$time_index[lg$era=='Holocene'],c(1L,3L,4L,5L,6L,7L)))
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) for(stem in c('coefficients','contrasts')) {
  pdf=here('plot/test_figures',paste0('fig_tracking_lake_',stem,'_',metric,'_offset_0.pdf'))
  info=system2('pdfinfo',shQuote(pdf),stdout=TRUE)
  stopifnot(as.integer(sub('^Pages:\\s*','',grep('^Pages:',info,value=TRUE)))==1L)
}
cat('PASS:',metric,'comparison fits, selected MA1 group means / covariance-based contrasts and offset-0 lake sensitivity.\n')
}
cat('PASS: all three requested responses use actual transitions and original modern identities, dates, fire and coordinates; reporting does not pool offsets.\n')
cat('PASS: raw physical climate rates match canonical source values without duplicate observations, transformations or tracking-validity filtering.\n')
cat('PASS: per response, 120 coefficients, 60 contrasts, 30 AIC comparisons, 40 MA1 group means, 16 lake coefficients and 8 lake contrasts; all intervals, signs, counts and retained time gaps verified.\n')
