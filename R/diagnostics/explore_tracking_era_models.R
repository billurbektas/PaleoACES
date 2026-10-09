# Exploratory era/site GLS models. Nothing here is anchored or workflow-owned.
# Run manually; the default fits only lag_rate_per_century:
#   Rscript R/diagnostics/explore_tracking_era_models.R
#   Rscript R/diagnostics/explore_tracking_era_models.R --offset=0
#   Rscript R/diagnostics/explore_tracking_era_models.R --metric=observed_turnover_rate
#
# Default: the requested across-offset, 100-year reporting-grid comparison.
# --offset=N: actual non-overlapping 1,000-year transitions in one offset,
# retaining all supported transitions without a majority-draw threshold.
# These are different observation sets; their AICs are not model-selection
# comparisons. AR(1) step length is 100 vs 1,000 years, respectively.
# Neither fit propagates chronology uncertainty or includes lake random effects.
# Reporting dates overlap; AR(1) is an exploratory covariance approximation.
# Modern time_index=0 is a dummy coordinate for singleton plot series. Modern
# t stays NA and resurvey_year retains the actual calendar year.
#
# All results stay in output/exploratory/tracking_era_models/<metric>/<input>/.
# No canonical CSVs, figures, review registrations or workflow calls are edited.
# nlme: https://stat.ethz.ch/R-manual/R-devel/library/nlme/html/corAR1.html
# emmeans: https://rvlenth.github.io/emmeans/articles/models.html#group-k---gls-and-lme-models
suppressPackageStartupMessages({
  library(here)
  library(nlme)
  library(emmeans)
  library(ggplot2)
  library(patchwork)
})
source(here('R/helpers/tracking_data.R'),local=TRUE)

args = commandArgs(trailingOnly=TRUE)
if(any(!grepl('^--(metric|offset)=',args))) stop('Use --metric=NAME and/or --offset=N')
argument = function(name,default) {
  prefix = paste0('--',name,'=')
  found = args[startsWith(args,prefix)]
  if(length(found)>1L) stop('Specify ',name,' once')
  if(length(found)) substring(found,nchar(prefix)+1L) else default
}
response_metric = argument('metric','lag_rate_per_century')
if(!response_metric %in% tracking_response_names()) stop('Unknown tracking response: ',response_metric)
offset_arg = argument('offset','')
input_path = here('output/cca_tracking_era_comparison.csv')
comparison = read.csv(input_path,stringsAsFactors=FALSE)
if(!identical(names(comparison),era_comparison_columns())) stop('Unexpected era-comparison schema')
d = comparison[comparison$metric==response_metric,,drop=FALSE]
source_paths = input_path
input_kind = 'reporting_grid'
ar1_step_years = 100L

if(nzchar(offset_arg)) {
  offset = suppressWarnings(as.numeric(offset_arg))
  source_paths = c(source_paths,here('output/cca_tracking_holocene_lake_by_offset.csv'))
  transitions = read.csv(source_paths[2],stringsAsFactors=FALSE)
  width = unique(transitions$climate_dt_years)
  if(length(width)!=1L || !is.finite(offset) || !offset %in% seq(0,width-100,100))
    stop('Offset must be one configured bin placement: ',paste(sort(unique(transitions$offset)),collapse=', '))
  transitions = transitions[transitions$offset==offset,,drop=FALSE]
  locations = unique(comparison[comparison$era=='Holocene',c('site','lake','longitude','latitude')])
  location_key = function(x) paste(x$site,x$lake,sep='::')
  if(anyDuplicated(location_key(locations))) stop('Ambiguous lake coordinates')
  matched = match(location_key(transitions),location_key(locations))
  if(anyNA(matched)) stop('Missing transition lake location')
  h = data.frame(era='Holocene',site=transitions$site,lake=transitions$lake,
    plot_id=NA_character_,t=transitions$interval_mid_cal_bp,resurvey_year=NA_real_,
    metric=response_metric,estimate=transitions[[response_metric]],
    climate_rate=transitions$standardized_climate_change_rate,climate_rate_offset_sd=NA_real_,
    fire_activity=transitions$fire_activity,fire_activity_offset_sd=NA_real_,burned=NA,
    longitude=locations$longitude[matched],latitude=locations$latitude[matched],n_valid_offsets=1L)
  d = rbind(h,d[d$era=='Anthropocene',,drop=FALSE])
  input_kind = paste0('offset_',offset)
  ar1_step_years = as.integer(width)
}

# Filter just the chosen response: undefined angle/pace values do not affect
# other responses. Modern fire assignments are retained; no draw-support
# threshold is imposed.
selected_rows = nrow(d)
excluded = d[!is.finite(d$estimate),,drop=FALSE]
d = d[is.finite(d$estimate),,drop=FALSE]
d$era = factor(d$era,levels=c('Holocene','Anthropocene'))
d$site = factor(d$site,levels=c('MORA','NOCA'))
if(anyNA(d$era) || anyNA(d$site) || any(table(d$era,d$site)<2L))
  stop('The four era/site groups need at least two finite responses each')
holocene = d$era=='Holocene'
if(any(!is.finite(d$t[holocene])) || any(!is.finite(d$resurvey_year[!holocene])) ||
   any(!is.na(d$t[!holocene]))) stop('Invalid era-specific age or survey year')
d$era_site = interaction(d$era,d$site,drop=TRUE)
d$series = ifelse(holocene,paste('H',d$site,d$lake,sep='_'),paste('A',d$site,d$plot_id,sep='_'))
time_coordinate = if(input_kind=='reporting_grid') d$t/100 else (d$t-offset)/ar1_step_years
if(any(abs(time_coordinate[holocene]-round(time_coordinate[holocene]))>1e-8))
  stop('AR(1) requires integer time coordinates; ages were not rounded')
d$time_index = ifelse(holocene,as.integer(round(time_coordinate)),0L)
if(anyDuplicated(d[c('series','time_index')])) stop('Duplicate series/time observation')
if(any(table(d$series[!holocene])!=1L)) stop('Each modern plot must contribute one observation')
d = d[order(d$series,d$time_index),,drop=FALSE]
rownames(d) = NULL

# First trial: Gaussian GLS, common Holocene AR(1), four residual variances.
# Climate/fire predictors are retained in the audit input but not added to this
# initial mean formula. REML is retained exactly as in the requested example.
m1 = gls(estimate ~ era * site,data=d,
  correlation=corAR1(form=~time_index | series),
  weights=varIdent(form=~1 | era_site),method='REML',na.action=na.fail,
  control=glsControl(msMaxIter=200))
era_means = emmeans(m1,~era | site,data=d,mode='satterthwaite')
era_contrasts = contrast(era_means,method=list('Anthropocene - Holocene'=c(-1,1)))
mean_table = as.data.frame(summary(era_means,infer=c(TRUE,FALSE)))
contrast_table = as.data.frame(summary(era_contrasts,infer=c(TRUE,TRUE),adjust='none'))
rho = unname(coef(m1$modelStruct$corStruct,unconstrained=FALSE))
sd_ratios = coef(m1$modelStruct$varStruct,unconstrained=FALSE,allCoef=TRUE)
variance_table = data.frame(era_site=names(sd_ratios),residual_sd=m1$sigma*unname(sd_ratios),
  ar1_phi=rho,ar1_step_years=ar1_step_years)
group_counts = do.call(rbind,lapply(split(d,d$era_site),function(x)
  data.frame(era=as.character(x$era[1]),site=as.character(x$site[1]),
    n_rows=nrow(x),n_series=length(unique(x$series)))))
coefficient_table = data.frame(term=rownames(summary(m1)$tTable),summary(m1)$tTable,row.names=NULL)
residual_data = d
residual_data$fitted = as.numeric(fitted(m1))
residual_data$residual = as.numeric(residuals(m1,type='response'))
residual_data$normalized_residual = as.numeric(residuals(m1,type='normalized'))

# Residual lag products use actual integer time differences within Holocene
# series, avoiding correlations between modern plots or across missing dates.
h_res = residual_data[residual_data$era=='Holocene',,drop=FALSE]
h_res$segment = ave(h_res$time_index,h_res$series,
  FUN=function(x) cumsum(c(TRUE,diff(x)>1)))
lag_products = lapply(0:10,function(k) {
  j = match(paste(h_res$series,h_res$time_index+k),paste(h_res$series,h_res$time_index))
  keep = !is.na(j)
  data.frame(lag=k,lag_years=k*ar1_step_years,n_pairs=sum(keep),
    covariance=if(any(keep)) mean(h_res$normalized_residual[keep]*h_res$normalized_residual[j[keep]]) else NA_real_)
})
residual_acf = do.call(rbind,lag_products)
residual_acf$acf = residual_acf$covariance/residual_acf$covariance[1]

out = here('output/exploratory/tracking_era_models',response_metric,input_kind)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write_result = function(x,name) write.csv(x,file.path(out,paste0(name,'.csv')),row.names=FALSE,na='NA')
write_result(d,'model_input')
write_result(excluded,'excluded_responses')
write_result(group_counts,'group_counts')
write_result(coefficient_table,'coefficients')
write_result(mean_table,'era_means')
write_result(contrast_table,'era_contrasts')
write_result(variance_table,'covariance_parameters')
write_result(residual_data,'residuals')
write_result(residual_acf,'holocene_residual_acf')
metadata = list(status='EXPLORATORY_UNANCHORED',metric=response_metric,input_kind=input_kind,
  formula='estimate ~ era * site',method='REML',ar1_step_years=ar1_step_years,
  selected_rows=selected_rows,excluded_response_rows=nrow(excluded),
  source_md5=tools::md5sum(source_paths),script_md5=tools::md5sum(here('R/diagnostics/explore_tracking_era_models.R')),
  package_versions=sapply(c('nlme','emmeans'),function(x) as.character(packageVersion(x))))
saveRDS(list(model=m1,data=d,means=era_means,contrasts=era_contrasts,metadata=metadata),file.path(out,'model_bundle.rds'))
notes = c('EXPLORATORY / UNANCHORED: model specification and contrasts remain provisional.',
  paste('Input:',input_kind,'| Response:',response_metric,'| AR(1) step:',ar1_step_years,'years'),
  'Modern time_index=0 is an internal singleton-series coordinate; modern t remains NA.',
  'Reporting dates overlap; AR(1) does not establish independence of the underlying transitions.',
  paste('Holocene normalized residual lag-1 product:',round(residual_acf$acf[residual_acf$lag==1],3),
    '(diagnostic summary, not a calibrated significance test).'),
  'Only four Holocene lake series are available, including one NOCA lake; GLS has no lake random intercept.',
  'Fits use point response summaries and do not propagate chronology/draw uncertainty.',
  'Within-park contrasts are Anthropocene minus Holocene, with unadjusted exploratory confidence intervals/tests.',
  'Reporting-grid and per-offset fits use different observations and AR step lengths; do not compare their AICs.',
  'These results are separate from the anchored analysis, workflow, scientific decisions and Analysis Review.')
writeLines(c(notes,'',capture.output(group_counts),'',capture.output(summary(m1)),
  '',capture.output(summary(era_means,infer=c(TRUE,FALSE))),
  '',capture.output(summary(era_contrasts,infer=c(TRUE,TRUE),adjust='none')),
  '',capture.output(sessionInfo())),file.path(out,'model_summary.txt'))

# Quick checks of residual shape, variance groups and temporal dependence.
theme_diagnostics = theme_minimal(base_size=11)+theme(legend.position='bottom')
p1 = ggplot(residual_data,aes(fitted,normalized_residual,color=era_site))+
  geom_hline(yintercept=0,color='grey60')+geom_point(alpha=.55,size=1)+
  labs(title='Normalized residuals versus fitted',x='Fitted response',y='Normalized residual',color=NULL)+theme_diagnostics
p2 = ggplot(residual_data,aes(sample=normalized_residual))+
  stat_qq(size=.7,alpha=.6)+stat_qq_line(color='#2563eb')+facet_wrap(~era_site,scales='free')+
  labs(title='Residual Q-Q plots by era/site',x='Normal theoretical quantile',y='Normalized residual')+theme_diagnostics
p3 = ggplot(h_res,aes(t,normalized_residual))+geom_hline(yintercept=0,color='grey60')+
  geom_line(aes(group=interaction(series,segment)))+geom_point(size=.7)+
  facet_wrap(~lake,ncol=2)+scale_x_reverse()+
  labs(title='Holocene normalized residual series',x='Age (cal BP)',y='Normalized residual')+theme_diagnostics
p4 = ggplot(residual_acf[residual_acf$lag>0 & residual_acf$n_pairs>0,],aes(lag_years,acf))+
  geom_hline(yintercept=0,color='grey60')+geom_segment(aes(xend=lag_years,yend=0),color='#2563eb')+
  geom_point(color='#2563eb')+labs(title='Holocene residual lag products',
    subtitle='Matched time differences; no modern singleton pairs',x='Time separation (years)',y='Normalized lag product')+theme_diagnostics
diagnostics = (p1+p2)/(p3+p4)+plot_annotation(
  title=paste('EXPLORATORY:',response_metric,'|',input_kind),
  subtitle='Gaussian GLS: era × site, AR(1), separate era/site variances',
  caption='Provisional covariance and distribution choices. Reporting dates overlap; chronology uncertainty is not propagated.')
ggsave(file.path(out,'model_diagnostics.pdf'),diagnostics,width=14,height=11)
cat(paste(notes[1:2],collapse='\n'),'\n')
print(group_counts)
print(contrast_table)
cat('AR(1) phi:',rho,'per',ar1_step_years,'years.\nResults:',out,'\n')
