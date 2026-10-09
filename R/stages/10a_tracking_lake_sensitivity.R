# Maintained sensitivity: offset 0, one Holocene lake versus its park's modern pairs.
# Rscript R/stages/10a_tracking_lake_sensitivity.R
# Optional manual runs: --metric=NAME --offset=N --bin-width-years=N.
suppressPackageStartupMessages({
  library(here);library(tidyverse);library(nlme);library(emmeans)
})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
argument=function(name,default) {
  prefix=paste0('--',name,'=')
  found=commandArgs(trailingOnly=TRUE)
  found=found[startsWith(found,prefix)]
  if(length(found)>1L) stop('Specify ',name,' once')
  if(length(found)) substring(found,nchar(prefix)+1L) else default
}
response_metric=argument('metric','lag_rate_per_century')
width=validate_tracking_width(as.numeric(argument('bin-width-years','1000')))
offset=as.numeric(argument('offset','0'))
suffix=if(width==1000L) '' else paste0('_',width,'yr')
input_path=here('output',paste0('cca_tracking_era_by_offset',suffix,'.csv'))
combined=read_csv(input_path,show_col_types=FALSE)
if(validate_tracking_model_data(combined)!=width) stop('Requested width differs from input')
lakes=combined |> filter(era=='Holocene') |> distinct(site,lake) |> arrange(site,lake)
model_types=c('AR1','MA1')
selected_model_type=tracking_selected_model_type()

fit_lake=function(lake,model_type) {
  selected=tracking_lake_model_input(combined,response_metric,lake,offset)
  d=selected$data
  correlation=if(model_type=='AR1') corAR1(form=~time_index | series) else
    corARMA(p=0,q=1,form=~time_index | series)
  warnings=character()
  fit=withCallingHandlers(
    gls(estimate ~ era,data=d,correlation=correlation,
      weights=varIdent(form=~1 | era),method='REML',na.action=na.fail,
      control=glsControl(msMaxIter=200)),
    warning=function(w) {warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
  tt=summary(fit)$tTable
  df=fit$dims$N-fit$dims$p
  ci=qt(.975,df)*tt[,'Std.Error']
  parameter=unname(coef(fit$modelStruct$corStruct,unconstrained=FALSE))
  boundary=abs(parameter)>.98
  means=emmeans(fit,~era,data=d,mode='satterthwaite')
  ct=as.data.frame(summary(contrast(means,
    method=list('Anthropocene - Holocene'=c(-1,1))),infer=c(TRUE,TRUE),adjust='none'))
  if(length(parameter)!=1L || any(!is.finite(tt)) ||
     any(!is.finite(ct$estimate) | !is.finite(ct$SE) | !is.finite(ct$df)) ||
     !is.finite(as.numeric(logLik(fit)))) stop('Invalid lake fit or contrast')
  coefficients=tibble(metric=response_metric,offset,site=selected$site,lake,model_type,
    term=rownames(tt),estimate=tt[,'Value'],std_error=tt[,'Std.Error'],df,
    t_value=tt[,'t-value'],p_value=tt[,'p-value'],
    conf_low=tt[,'Value']-ci,conf_high=tt[,'Value']+ci,
    n_holocene=sum(d$era=='Holocene'),n_anthropocene=sum(d$era=='Anthropocene'),
    correlation_parameter=parameter,near_correlation_boundary=boundary,converged=TRUE)
  contrasts=tibble(metric=response_metric,offset,site=selected$site,lake,model_type,
    contrast=as.character(ct$contrast),estimate=ct$estimate,std_error=ct$SE,df=ct$df,
    t_value=ct$t.ratio,p_value=ct$p.value,conf_low=ct$lower.CL,conf_high=ct$upper.CL,
    n_holocene=sum(d$era=='Holocene'),n_anthropocene=sum(d$era=='Anthropocene'),
    correlation_parameter=parameter,near_correlation_boundary=boundary,converged=TRUE)
  block=c(paste('LAKE',lake,'| PARK',selected$site,'| OFFSET',offset,'| MODEL',model_type),
    paste('Holocene transitions:',sum(d$era=='Holocene'),'| Modern pairs:',sum(d$era=='Anthropocene'),
      '| Undefined selected responses:',nrow(selected$excluded)),
    paste('Correlation parameter:',format(parameter,digits=8),
      if(model_type=='AR1') '(phi)' else paste0('(theta; rho(1) = ',
        format(parameter/(1+parameter^2),digits=8),')')),
    paste('Near correlation boundary (absolute parameter > 0.98):',boundary),
    paste('Warnings:',if(length(warnings)) paste(unique(warnings),collapse='; ') else 'none'),
    capture.output(print(summary(fit))),
    'Era means:',capture.output(summary(means,infer=c(TRUE,FALSE))),
    'Anthropocene - Holocene:',capture.output(print(ct)),
    if(nrow(selected$excluded)) c('Undefined response identities:',
      capture.output(print(selected$excluded[c('era','site','lake','plot_id','age_hi','age_lo')]))),'')
  list(coefficients=coefficients,contrasts=contrasts,text=block)
}

# A failed fit stops with its key before replacing the sensitivity products.
fits=list()
for(lake in lakes$lake) for(model_type in model_types) {
  cat('Lake sensitivity:',lake,'| offset',offset,'|',model_type,'\n')
  fits[[paste(lake,model_type,sep='_')]]=tryCatch(fit_lake(lake,model_type),
    error=function(e) stop('Lake ',lake,' / ',model_type,': ',conditionMessage(e),call.=FALSE))
}
coefficients=bind_rows(map(fits,'coefficients'))
contrasts=bind_rows(map(fits,'contrasts'))
if(nrow(coefficients)!=nrow(lakes)*length(model_types)*2L ||
   anyDuplicated(coefficients[c('metric','offset','site','lake','model_type','term')]) ||
   nrow(contrasts)!=nrow(lakes)*length(model_types) ||
   anyDuplicated(contrasts[c('metric','offset','site','lake','model_type')]))
  stop('Missing or duplicate lake sensitivity results')
out=here('output/exploratory/tracking_lake_sensitivity',paste0(response_metric,suffix),paste0('offset_',offset))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write_csv(coefficients,file.path(out,'model_coefficients.csv'))
write_csv(contrasts,file.path(out,'model_contrasts.csv'))
notes=c('Lake sensitivity; MA1 selected by the author on 2026-10-09; inference remains exploratory.',
  paste('Response:',response_metric,'| Offset:',offset,'| Holocene interval:',width,'years'),
  'Each fit compares one Holocene lake with all finite modern responses from the same park.',
  'Constant site is removed: estimate ~ era; REML; separate residual variances by era.',
  'AR1 or MA1 correlation retains actual within-lake gaps; modern pairs are singleton series.',
  'Comparison records retain AR1 and MA1; reported lake coefficients and contrasts use only the selected MA1.',
  'MORA lake fits reuse the same modern plots; they are not independent comparisons.',
  'Near-boundary fits are retained and flagged when the absolute correlation parameter exceeds 0.98.',
  'No chronology propagation, support cutoff, lake random effect or climate/fire fixed effects.',
  'No pooled averaging of lake fits and no AIC comparisons between different lake inputs.',
  paste('Input MD5:',unname(tools::md5sum(input_path))),
  paste('Script MD5:',unname(tools::md5sum(here('R/stages/10a_tracking_lake_sensitivity.R')))))
writeLines(c(notes,'',unlist(map(fits,'text')),capture.output(sessionInfo())),file.path(out,'model_results.txt'))

lake_labels=c(JayBath='Jay Bath',LogWallow='Log Wallow',ReflectionPond='Reflection Pond',
  PantherPotholes='Panther Potholes')
counts=contrasts |> distinct(lake,site,n_holocene,n_anthropocene)
counts$label=paste0(unname(lake_labels[counts$lake]),' (',counts$site,')\n',
  counts$n_holocene,' Holocene / ',counts$n_anthropocene,' modern')
plot_coefficients=tracking_selected_model_results(coefficients) |>
  left_join(counts |> select(lake,label),by='lake',relationship='many-to-one')
plot_contrasts=tracking_selected_model_results(contrasts) |>
  left_join(counts |> select(lake,label),by='lake',relationship='many-to-one')
plot_coefficients$label=factor(plot_coefficients$label,levels=rev(counts$label))
plot_contrasts$label=factor(plot_contrasts$label,levels=rev(counts$label))
plot_coefficients$term=factor(plot_coefficients$term,levels=c('(Intercept)','eraAnthropocene'),
  labels=c('Holocene mean (intercept)','Anthropocene - Holocene (era coefficient)'))
colors=tracking_model_colors()
base_plot=function(tbl) ggplot(tbl,aes(estimate,label))+
  geom_vline(xintercept=0,linetype='dashed',color='grey60')+
  geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.2,
    color=unname(colors[selected_model_type]),linewidth=.6)+
  geom_point(aes(shape=near_correlation_boundary),color=unname(colors[selected_model_type]),size=2.8)+
  scale_shape_manual(values=c('FALSE'=16,'TRUE'=17),labels=c('FALSE'='No','TRUE'='Yes'))+
  tracking_model_plot_theme()
coef_plot=base_plot(plot_coefficients)+facet_wrap(~term,scales='free_x',nrow=1)+
  labs(title=paste('MA(1) lake sensitivity coefficients:',response_metric),
    subtitle=paste('Offset',offset,'; each lake compared with modern pairs from its own park'),
    x='Coefficient estimate',y=NULL,shape='Near boundary',
    caption='Bars: unadjusted 95% t intervals. Coefficient panels use separate x-scales.\nTriangles flag absolute correlation parameters > 0.98. MORA fits reuse modern plots. MA(1) selected; inference remains exploratory.')
contrast_plot=base_plot(plot_contrasts)+
  labs(title=paste('MA(1) lake sensitivity era contrasts:',response_metric),
    subtitle=paste('Offset',offset,'; Anthropocene minus Holocene within each lake/park comparison'),
    x='Anthropocene - Holocene',y=NULL,shape='Near boundary',
    caption='Bars: unadjusted 95% intervals with Satterthwaite degrees of freedom.\nTriangles flag absolute correlation parameters > 0.98. Only 6-10 Holocene transitions support primary fits; inference remains exploratory.')
if(render_figures) {
  stem=paste0(response_metric,suffix,'_offset_',offset)
  ggsave(here('plot/test_figures',paste0('fig_tracking_lake_coefficients_',stem,'.pdf')),coef_plot,width=14,height=7.5)
  ggsave(here('plot/test_figures',paste0('fig_tracking_lake_contrasts_',stem,'.pdf')),contrast_plot,width=12,height=7)
}
cat('Saved',length(fits),'lake sensitivity fits in',out,'\n')
