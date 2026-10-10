# Manuscript Figure 4: offset-0 MA1 contrasts and corrected-lag scatter panels.
# Read maintained model input/results; no refitting, transforms or geometry calculations.
# Rscript R/stages/10b_tracking_manuscript_figure.R
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
metrics=c('standardized_climate_change_rate','observed_turnover_rate','lag_rate_per_century',
  tracking_corrected_response_names())
combined=read_csv(here('output/cca_tracking_era_by_offset.csv'),show_col_types=FALSE)
if(validate_tracking_model_data(combined)!=1000L)
  stop('The primary manuscript figure requires the 1,000-year analysis')
raw=map_dfr(metrics,function(metric) tracking_offset_model_input(combined,metric,0)$data)
read_results=function(metric,filename) {
  read_csv(here('output/exploratory/tracking_offset_models',metric,filename),show_col_types=FALSE) |>
    filter(offset==0,model_type==tracking_selected_model_type())
}
means=map_dfr(metrics,read_results,filename='model_group_means.csv')
contrasts=map_dfr(metrics,read_results,filename='model_contrasts.csv')
keys=c('metric','site','era')
counts=raw |> count(across(all_of(keys)),name='n_raw')
check=full_join(means,counts,by=keys,relationship='one-to-one')
if(nrow(means)!=20L || anyDuplicated(means[keys]) ||
   nrow(contrasts)!=10L || anyDuplicated(contrasts[c('metric','site')]) ||
   nrow(check)!=20L || anyNA(check[c('n','n_raw')]) || any(check$n!=check$n_raw) ||
   any(!is.finite(as.matrix(means[c('estimate','conf_low','conf_high')]))) ||
   any(!is.finite(as.matrix(contrasts[c('estimate','conf_low','conf_high','p_value')]))) ||
   any(contrasts$p_value<0 | contrasts$p_value>1))
  stop('Missing, duplicate or inconsistent offset-0 model results and raw inputs')
ratios=means |> select(all_of(keys),estimate) |>
  pivot_wider(names_from=era,values_from=estimate) |>
  left_join(contrasts |> select(metric,site,contrast_estimate=estimate),
    by=c('metric','site'),relationship='one-to-one')
if(any(abs(ratios$Anthropocene-ratios$Holocene-ratios$contrast_estimate)>1e-8))
  stop('Displayed contrast disagrees with the difference between fitted means')
ratios=ratios |> transmute(metric,site,ratio=Anthropocene/Holocene)
site_colors=c(MORA='#648FFF',NOCA='#FE6100')
response_colors=c(Observed='#40AB9D',Direction='#8B85F1',Pace='#DE85F0')
metric_kind=c(lag_rate_per_century='Observed',pace_corrected_lag_rate_per_century='Pace',
  direction_corrected_lag_rate_per_century='Direction')
cl=contrasts |> left_join(ratios,by=c('metric','site'),relationship='one-to-one') |>
  mutate(metric=factor(metric,levels=metrics),site=factor(site,levels=names(site_colors)),
    kind=unname(metric_kind[as.character(metric)]),
    error_alpha=if_else(p_value<.05,1,.20),
    label=sprintf('%+.2f%s',estimate,if_else(p_value<.05,' *','')),
    fold_label=if_else(is.finite(ratio),sprintf('%.1f\u00d7',ratio),'undefined'))
base_theme=theme_minimal(base_size=22)+theme(panel.grid.minor=element_blank(),
  panel.grid.major.x=element_blank(),axis.text=element_text(size=20,color='grey20'),
  axis.title=element_text(size=23),legend.title=element_text(size=22),
  legend.text=element_text(size=21),plot.margin=margin(10,14,12,14))
pd=position_dodge(width=.64)
# Use two unit scales, but align zero at the same physical height in both panels.
limits=cl |> mutate(panel=if_else(metric=='standardized_climate_change_rate','Climate','CCA')) |>
  group_by(panel) |> summarise(lo=min(c(conf_low,0)),hi=max(c(conf_high,0)),.groups='drop') |>
  mutate(span=pmax(hi-lo,1e-6),upper=hi+.22*span,lower=lo-.22*span)
zero_fraction=max(-limits$lower/(limits$upper-limits$lower))
limits=limits |> mutate(lower=-upper*zero_fraction/(1-zero_fraction))
stopifnot(diff(range(-limits$lower/(limits$upper-limits$lower)))<1e-12)
contrast_plot=function(climate=FALSE) {
  dd=if(climate) filter(cl,metric=='standardized_climate_change_rate') else
    filter(cl,metric!='standardized_climate_change_rate')
  bounds=filter(limits,panel==if(climate) 'Climate' else 'CCA')
  dd=dd |> mutate(label_y=conf_high+.045*bounds$span,fold_y=conf_low-.055*bounds$span)
  axis_labels=dd |> distinct(metric,kind) |>
    mutate(axis_label=recode(as.character(metric),
      standardized_climate_change_rate='Climate-change\nrate',
      observed_turnover_rate='Community\nturnover rate',lag_rate_per_century='Observed',
      pace_corrected_lag_rate_per_century='Pace corrected',
      direction_corrected_lag_rate_per_century='Direction corrected'),
      axis_color=if_else(is.na(kind),'Axis',kind),
      axis_y=bounds$lower-.025*(bounds$upper-bounds$lower))
  p=ggplot(dd,aes(metric,estimate,group=site))+
    geom_hline(yintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_errorbar(aes(ymin=conf_low,ymax=conf_high,alpha=error_alpha),color='grey45',
      position=pd,width=.10,linewidth=1.3,show.legend=FALSE)+
    geom_point(position=pd,shape=21,size=3.8,stroke=1.1,
      color='grey40',fill='grey70',show.legend=FALSE)+
    geom_text(aes(y=label_y,label=label,color=site),position=pd,size=5.7,show.legend=FALSE)+
    geom_text(aes(y=fold_y,label=fold_label,color=site),position=pd,vjust=1,size=5.5,show.legend=FALSE)+
    geom_text(data=axis_labels,aes(x=metric,y=axis_y,label=axis_label,color=axis_color),
      inherit.aes=FALSE,vjust=1,size=7,lineheight=1.05,show.legend=FALSE)+
    scale_color_manual(values=c(site_colors,response_colors,Axis='grey20'),guide='none')+
    scale_alpha_identity(guide='none')+
    scale_x_discrete(labels=c(standardized_climate_change_rate='Climate-change\nrate',
      observed_turnover_rate='Community\nturnover rate',lag_rate_per_century='Observed',
      pace_corrected_lag_rate_per_century='Pace corrected',
      direction_corrected_lag_rate_per_century='Direction corrected'),expand=expansion(add=.55))+
    scale_y_continuous(position='left',expand=expansion(mult=0))+
    coord_cartesian(ylim=c(bounds$lower,bounds$upper),expand=FALSE,clip='off')+
    labs(x=NULL,y='Anthropocene − Holocene')+base_theme+
    theme(axis.text.x=element_blank())
  if(!climate) {
    y= bounds$lower-.155*(bounds$upper-bounds$lower)
    p=p+annotate('segment',x=1.65,xend=4.35,y=y,yend=y,color='grey45',linewidth=.55)+
      annotate('text',x=3,y=y-.06*(bounds$upper-bounds$lower),label='Lag change',size=7)+
      theme(plot.margin=margin(10,14,104,14))
  } else p=p+theme(plot.margin=margin(10,14,104,14))
  p
}
# Each pair is an actual transition/plot; corrected medians were calculated from
# draw-level geometry by stage 09b, never as a difference between two medians.
pair_keys=c('era','site','lake','plot_id','offset','age_hi','age_lo')
pairs=combined |> filter(era=='Anthropocene' | offset==0,
    metric %in% c('lag_rate_per_century',tracking_corrected_response_names())) |>
  select(all_of(pair_keys),metric,estimate) |>
  pivot_wider(names_from=metric,values_from=estimate) |>
  pivot_longer(all_of(tracking_corrected_response_names()),names_to='metric',values_to='corrected_rate') |>
  mutate(correction=unname(metric_kind[metric]))
d=pairs |> filter(is.finite(lag_rate_per_century),is.finite(corrected_rate))
scatter_stats=list()
scatter=function(era_name) {
  ds=filter(d,era==era_name)
  observed=raw |> filter(metric=='lag_rate_per_century',era==era_name)
  mt=means |> filter(metric=='lag_rate_per_century',era==era_name)
  lim=range(c(ds$corrected_rate,ds$lag_rate_per_century,mt$conf_low,mt$conf_high,0))
  lim=lim+c(-1,1)*diff(lim)*.055
  stats=ds |> group_by(correction) |> group_modify(function(g,key) {
    test=cor.test(g$lag_rate_per_century,g$corrected_rate,method='spearman',
      alternative='two.sided',exact=FALSE)
    tibble(n_pairs=nrow(g),rho=unname(test$estimate),p_value=test$p.value)
  }) |> ungroup() |> mutate(era=era_name,
    p_text=if_else(p_value<.001,sprintf('%.1e',p_value),sprintf('%.3f',p_value)),
    label=sprintf('\u03c1 = %.2f, p = %s',rho,p_text),
    label_x=lim[1]+.04*diff(lim),
    label_y=lim[2]-(.055+.11*(match(correction,c('Direction','Pace'))-1))*diff(lim))
  scatter_stats[[era_name]] <<- stats
  p=ggplot(ds,aes(lag_rate_per_century,corrected_rate))+
    geom_hline(yintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_vline(xintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_abline(intercept=0,slope=1,linetype='dashed',color='grey50',linewidth=.6)+
    geom_point(aes(fill=site,color=correction,shape=correction),
      size=if(era_name=='Holocene') 2.1 else 1.7,alpha=.35,stroke=.5,
      show.legend=c(fill=TRUE,color=TRUE,shape=FALSE))+
    geom_smooth(aes(color=correction,group=correction),method='lm',formula=y~x,
      se=FALSE,linewidth=1.15,show.legend=FALSE)+
    geom_label(data=stats,aes(x=label_x,y=label_y,label=label,color=correction),inherit.aes=FALSE,
      hjust=0,vjust=1,size=6.1,fill='white',linewidth=0,
      label.padding=grid::unit(.10,'lines'),show.legend=FALSE)+
    scale_fill_manual(name='Park',values=site_colors)+
    scale_color_manual(name='Lag change',values=response_colors,
      breaks=c('Pace','Direction'),labels=c('Pace corrected','Direction corrected'))+
    scale_shape_manual(values=c(Direction=21,Pace=24),guide='none')+
    guides(color=guide_legend(override.aes=list(fill='white',alpha=1,size=4)),
      fill=guide_legend(override.aes=list(color='grey50',shape=21,alpha=1,size=4)))+
    coord_cartesian(xlim=lim,ylim=lim,expand=FALSE)+
    labs(x='Observed lag-change rate',y='Corrected lag-change rate')+base_theme+
    theme(panel.grid.major.x=element_line(color='grey92',linewidth=.4),
      plot.margin=margin(0,14,12,14))
  den=observed |> group_by(site) |> group_modify(function(g,key) {
    z=density(g$estimate,n=512,from=lim[1],to=lim[2])
    tibble(value=z$x,density=z$y)
  }) |> ungroup()
  peak=max(den$density)
  mt=mt |> mutate(error_y=peak*if_else(site=='MORA',.28,.095),
    cap_lo=error_y-peak*.022,cap_hi=error_y+peak*.022,
    mean_label=sprintf('%+.3f',estimate),label_x=conf_high+.018*diff(lim))
  top=ggplot(den,aes(value,density,color=site,fill=site))+
    geom_hline(yintercept=0,color='grey50',linewidth=.55)+
    geom_area(alpha=.23,position='identity')+geom_line(linewidth=.85)+
    geom_vline(xintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_segment(data=mt,aes(x=conf_low,xend=conf_high,y=error_y,yend=error_y,color=site),
      inherit.aes=FALSE,linewidth=1.3)+
    geom_segment(data=mt,aes(x=conf_low,xend=conf_low,y=cap_lo,yend=cap_hi,color=site),
      inherit.aes=FALSE,linewidth=1.1)+
    geom_segment(data=mt,aes(x=conf_high,xend=conf_high,y=cap_lo,yend=cap_hi,color=site),
      inherit.aes=FALSE,linewidth=1.1)+
    geom_point(data=mt,aes(x=estimate,y=error_y,color=site),inherit.aes=FALSE,
      shape=21,fill='white',size=3.5,stroke=.9)+
    geom_text(data=mt,aes(x=label_x,y=error_y,label=mean_label,color=site),
      inherit.aes=FALSE,hjust=0,vjust=.5,size=5.5,fontface='bold')+
    scale_color_manual(values=site_colors,guide='none')+scale_fill_manual(values=site_colors,guide='none')+
    scale_x_continuous(limits=lim,expand=expansion(mult=0))+
    scale_y_continuous(limits=c(0,NA),expand=expansion(mult=c(0,.08)))+
    labs(title=era_name)+theme_void(base_size=22)+theme(legend.position='none',
      plot.title=element_text(size=26,face='bold'),plot.margin=margin(10,14,0,14))
  wrap_plots(top,p,ncol=1,heights=c(.23,1),guides='auto')
}
first_row=wrap_plots(contrast_plot(TRUE),contrast_plot(FALSE),nrow=1,widths=c(1,4),guides='auto')
second_row=wrap_plots(scatter('Holocene'),scatter('Anthropocene'),nrow=1,guides='auto')
figure=wrap_plots(first_row,second_row,ncol=1,heights=c(1,1.35),guides='collect') &
  theme(legend.position='bottom',plot.background=element_rect(fill='white',color=NA))
if(render_figures) {
  stem=here('plot/fig_tracking_era_distributions')
  ggsave(paste0(stem,'.pdf'),figure,width=19,height=15,device=cairo_pdf,bg='white')
  ggsave(paste0(stem,'.png'),figure,width=19,height=15,dpi=300,bg='white')
}
cat('Manuscript figure verified: offset 0; 20 MA1 means, ten covariance-based contrasts;',
  nrow(raw),'untransformed input values.\n')
