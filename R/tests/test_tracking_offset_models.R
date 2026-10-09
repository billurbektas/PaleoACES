# Offline combined-input and covariance checks for the provisional model stage.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
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

coeff=read_csv(here('output/exploratory/tracking_offset_models/lag_rate_per_century/model_coefficients.csv'),
  show_col_types=FALSE)
stopifnot(nrow(coeff)==80L,setequal(coeff$model_type,c('AR1','MA1')),
  setequal(coeff$offset,seq(0,900,100)),all(coeff$converged),
  !anyDuplicated(coeff[c('metric','offset','model_type','term')]))
equal(coeff$t_value,coeff$estimate/coeff$std_error)
equal(coeff$p_value,2*pt(-abs(coeff$t_value),df=coeff$df))
equal(coeff$conf_low,coeff$estimate-qt(.975,coeff$df)*coeff$std_error)
equal(coeff$conf_high,coeff$estimate+qt(.975,coeff$df)*coeff$std_error)
for(offset in seq(0,900,100)) {
  d=tracking_offset_model_input(c,'lag_rate_per_century',offset)$data
  co=coeff[coeff$offset==offset,]
  stopifnot(all(co$n_holocene==sum(d$era=='Holocene')),all(co$n_anthropocene==607L),
    all(co$df==nrow(d)-4L))
}
contrasts=read_csv(here('output/exploratory/tracking_offset_models/lag_rate_per_century/model_contrasts.csv'),
  show_col_types=FALSE)
stopifnot(nrow(contrasts)==40L,!anyDuplicated(contrasts[c('metric','offset','model_type','site')]),
  all(contrasts$contrast=='Anthropocene - Holocene'))
equal(contrasts$t_value,contrasts$estimate/contrasts$std_error)
equal(contrasts$p_value,2*pt(-abs(contrasts$t_value),df=contrasts$df))
equal(contrasts$conf_low,contrasts$estimate-qt(.975,contrasts$df)*contrasts$std_error)
equal(contrasts$conf_high,contrasts$estimate+qt(.975,contrasts$df)*contrasts$std_error)
for(i in seq_len(nrow(contrasts))) {
  ct=contrasts[i,];co=coeff[coeff$offset==ct$offset & coeff$model_type==ct$model_type,]
  expected=co$estimate[co$term=='eraAnthropocene']
  if(ct$site=='NOCA') expected=expected+co$estimate[co$term=='eraAnthropocene:siteNOCA']
  equal(ct$estimate,expected)
  d=tracking_offset_model_input(c,'lag_rate_per_century',ct$offset)$data
  equal(ct$n_holocene,sum(d$era=='Holocene' & d$site==ct$site))
  equal(ct$n_anthropocene,sum(d$era=='Anthropocene' & d$site==ct$site))
}
for(stem in c('coefficients','contrasts','residuals')) {
  pdf=here('plot/test_figures',paste0('fig_tracking_model_',stem,'_lag_rate_per_century.pdf'))
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
    stopifnot(file.exists(pdf))
    info=system2('pdfinfo',shQuote(pdf),stdout=TRUE)
    stopifnot(as.integer(sub('^Pages:\\s*','',grep('^Pages:',info,value=TRUE)))==1L)
  }
}
stopifnot(!file.exists(here('R/diagnostics/explore_tracking_era_models.R')),
  !file.exists(here('output/cca_tracking_era_comparison.csv')),
  !dir.exists(here('output/exploratory/tracking_era_models')))
cat('PASS: combined input, all offsets/responses, original dates/fire/coordinates, preserved gaps, AR1/MA1 covariance, 80 coefficients, 40 correctly signed park contrasts and retired modeling artifacts.\n')
