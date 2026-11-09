# Manuscript Figure 4 and separate corrected-lag contrasts at primary reconstruction.
# Read maintained model input/results; no refitting, transforms or geometry calculations.
# Rscript R/figures/main_fig4_era_contrasts.R
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
metrics=c('standardized_climate_change_rate','observed_turnover_rate','lag_rate_per_century',
  tracking_correction_effect_response_names())
combined=read_csv(out('cca_tracking_era_model_input.csv'),show_col_types=FALSE)
validate_tracking_model_data(combined)
raw=map_dfr(metrics,function(metric) tracking_primary_model_input(combined,metric)$data)
read_results=function(metric,filename) {
  read_csv(file.path(out('era_comparison'),metric,filename),show_col_types=FALSE)
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
  stop('Missing, duplicate or inconsistent primary model results and raw inputs')
ratios=means |> select(all_of(keys),estimate) |>
  pivot_wider(names_from=era,values_from=estimate) |>
  left_join(contrasts |> select(metric,site,contrast_estimate=estimate),
    by=c('metric','site'),relationship='one-to-one')
if(any(abs(ratios$Anthropocene-ratios$Holocene-ratios$contrast_estimate)>1e-8))
  stop('Displayed contrast disagrees with the difference between fitted means')
ratios=ratios |> transmute(metric,site,ratio=Anthropocene/Holocene)
site_colors=c(MORA='#648FFF',NOCA='#FE6100')
response_colors=c(Observed='#40AB9D',Direction='#8B85F1',Pace='#DE85F0')
metric_kind=c(lag_rate_per_century='Observed',pace_effect_on_lag_per_century='Pace',
  direction_effect_on_lag_per_century='Direction')
cl=contrasts |> left_join(ratios,by=c('metric','site'),relationship='one-to-one') |>
  mutate(metric=factor(metric,levels=metrics),site=factor(site,levels=names(site_colors)),
    kind=unname(metric_kind[as.character(metric)]),
    error_alpha=if_else(p_value<.05,1,.20),
    point_label_alpha=if_else(site=='NOCA' & p_value>=.05,.20,1),
    label=sprintf('%+.2f%s',estimate,if_else(p_value<.05,' *','')),
    fold_label=if_else(is.finite(ratio),sprintf('%.1f\u00d7',ratio),'undefined'))
base_theme=theme_minimal(base_size=27)+theme(panel.grid.minor=element_blank(),
  panel.grid.major.x=element_blank(),axis.text=element_text(size=24,color='grey20'),
  axis.title=element_text(size=27),legend.title=element_text(size=26),
  legend.text=element_text(size=25),plot.margin=margin(10,14,12,14))
pd=position_dodge(width=.64)
# Align the primary climate and CCA zero baselines despite their different units.
contrast_limits=function(data) {
  limits=data |> mutate(panel=if_else(metric=='standardized_climate_change_rate','Climate','CCA')) |>
    group_by(panel) |> summarise(lo=min(c(conf_low,0)),hi=max(c(conf_high,0)),.groups='drop') |>
    mutate(span=pmax(hi-lo,1e-6),upper=hi+.25*span,lower=lo-.25*span)
  zero_fraction=max(-limits$lower/(limits$upper-limits$lower))
  limits=limits |> mutate(lower=-upper*zero_fraction/(1-zero_fraction))
  stopifnot(diff(range(-limits$lower/(limits$upper-limits$lower)))<1e-12)
  limits
}
primary_metrics=metrics[1:3]
primary_limits=contrast_limits(filter(cl,metric %in% primary_metrics))
corrected_metrics=tracking_correction_effect_response_names()
corrected_limits=contrast_limits(filter(cl,metric %in% corrected_metrics))
contrast_plot=function(response_metrics,bounds,correction_labels=FALSE) {
  dd=filter(cl,metric %in% response_metrics)
  dd=dd |> mutate(label_y=conf_high+.085*bounds$span,fold_y=conf_low-.055*bounds$span)
  # Keep enlarged fold labels clear of the zero reference line.
  if(correction_labels) dd=dd |> mutate(fold_y=if_else(
    fold_y>=0 & fold_y<.10*bounds$span,-.035*bounds$span,fold_y))
  axis_labels=dd |> distinct(metric,kind) |>
    mutate(axis_label=recode(as.character(metric),
      standardized_climate_change_rate='Standardized climate change\nper century',
      observed_turnover_rate='Community turnover rate\n(CCA distance per century)',
      lag_rate_per_century='Observed lag change\n(CCA distance per century)',
      pace_effect_on_lag_per_century='Pace correction effect',
      direction_effect_on_lag_per_century='Direction correction effect'),
      axis_color=if(correction_labels) kind else 'Axis',
      axis_y=bounds$lower-.025*(bounds$upper-bounds$lower))
  p=ggplot(dd,aes(metric,estimate,group=site))+
    geom_hline(yintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_errorbar(aes(ymin=conf_low,ymax=conf_high,alpha=error_alpha,color=site),
      position=pd,width=.10,linewidth=1.3,show.legend=FALSE)+
    geom_point(aes(color=site,fill=site,alpha=point_label_alpha),position=pd,shape=21,size=1.8,stroke=.5,
      show.legend=if(correction_labels) c(fill=TRUE,color=FALSE,alpha=FALSE) else FALSE)+
    geom_text(aes(y=label_y,label=label,color=site,alpha=point_label_alpha),
      position=pd,size=9,show.legend=FALSE)+
    geom_text(aes(y=fold_y,label=fold_label,color=site,alpha=point_label_alpha),
      position=pd,vjust=1,size=8.6,show.legend=FALSE)+
    geom_text(data=axis_labels,aes(x=metric,y=axis_y,label=axis_label,color=axis_color),
      inherit.aes=FALSE,vjust=1,size=8.2,lineheight=1.05,show.legend=FALSE)+
    scale_color_manual(values=c(site_colors,response_colors,Axis='grey20'),guide='none')+
    scale_fill_manual(name='Park',values=site_colors,guide=if(correction_labels)
      guide_legend(override.aes=list(alpha=1)) else 'none')+
    scale_alpha_identity(guide='none')+
    scale_x_discrete(expand=expansion(add=.55))+
    scale_y_continuous(position='left',expand=expansion(mult=0))+
    coord_cartesian(ylim=c(bounds$lower,bounds$upper),expand=FALSE,clip='off')+
    labs(x=NULL,y=if(correction_labels)
      'Difference between\nAnthropocene vs. Holocene\n(CCA distance per century)' else
      'Difference between\nAnthropocene vs. Holocene')+base_theme+
    theme(axis.text.x=element_blank())
  p+theme(plot.margin=margin(10,14,if(correction_labels) 58 else 86,14))
}
# Joint correction comparisons use complete pace/direction pairs only.
# The existing independent-response models remain the source for the top row.
joint_out=out('era_comparison/joint_correction_effects')
paired_input=tracking_joint_correction_input(combined)$data
joint_means=read_csv(file.path(joint_out,'model_group_means.csv'),show_col_types=FALSE)
joint_contrasts=read_csv(file.path(joint_out,'correction_contrasts.csv'),show_col_types=FALSE)
displayed_means=read_csv(file.path(joint_out,'displayed_mean_zero_tests.csv'),show_col_types=FALSE)
joint_check=full_join(joint_means,count(paired_input,era,site,correction,name='n_raw'),
  by=c('era','site','correction'),relationship='one-to-one')
if(nrow(joint_check)!=8L || anyNA(joint_check[c('n','n_raw')]) ||
   any(joint_check$n!=joint_check$n_raw) || nrow(joint_contrasts)!=4L ||
   anyDuplicated(joint_contrasts[c('era','site')])) stop('Inconsistent joint correction results')
correction_colors=c(Observed=response_colors[['Observed']],Pace=response_colors[['Pace']],
  Direction=response_colors[['Direction']])
violin_panel=function(era_name) {
  distributions=bind_rows(paired_input,
    raw |> filter(metric=='lag_rate_per_century') |> mutate(correction='Observed')) |>
    filter(era==era_name) |> mutate(correction=factor(correction,levels=names(correction_colors)),
      park_x=match(site,c('MORA','NOCA')))
  comparisons=joint_contrasts |> filter(era==era_name) |> mutate(park_x=match(site,c('MORA','NOCA')))
  mt=displayed_means |> filter(era==era_name) |>
    mutate(correction=factor(correction,levels=names(correction_colors)),park_x=match(site,c('MORA','NOCA')))
  violin_limits=range(c(distributions$estimate,mt$conf_low,mt$conf_high,0))
  span=diff(violin_limits)
  mt=mt |> mutate(mean_label=sprintf('%+.3f %s',estimate,coalesce(zero_significance,'')),
    label_y=conf_high+c(.065,.155,.245)[as.integer(correction)]*span,
    model_alpha=if_else(zero_significant,1,.25))
  peaks=distributions |> group_by(site) |> summarise(peak=max(estimate),.groups='drop')
  brackets=comparisons |> filter(significant) |> left_join(peaks,by='site',relationship='one-to-one') |>
    mutate(bracket_y=pmax(peak,max(mt$label_y))+.07*span,
      label_y=bracket_y+.06*span,
      label=sprintf('%+.3f %s\np = %.3g',estimate,significance,p_adjusted))
  upper=max(c(violin_limits[2],mt$label_y,brackets$label_y+.11*span))+.06*span
  ggplot(distributions,aes(park_x,estimate,group=interaction(site,correction)))+
    geom_hline(yintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_violin(aes(fill=correction),position=position_dodge(width=.8),width=.78,
      alpha=.32,color='grey50',linewidth=.6,scale='width',trim=TRUE)+
    geom_errorbar(data=mt,aes(ymin=conf_low,ymax=conf_high,color=correction,alpha=model_alpha),
      position=position_dodge(width=.8),width=.10,linewidth=1.3,show.legend=FALSE)+
    geom_point(data=mt,aes(color=correction,fill=correction,alpha=model_alpha),
      position=position_dodge(width=.8),shape=21,size=1.8,stroke=.5,show.legend=FALSE)+
    geom_text(data=mt,aes(y=label_y,label=mean_label,color=correction,alpha=model_alpha),
      position=position_dodge(width=.8),size=9,show.legend=FALSE)+
    geom_segment(data=brackets,aes(x=park_x,xend=park_x+.8/3,y=bracket_y,yend=bracket_y),
      inherit.aes=FALSE,color='grey40',linewidth=.8)+
    geom_segment(data=brackets,aes(x=park_x,xend=park_x,y=bracket_y,yend=bracket_y-.025*span),
      inherit.aes=FALSE,color='grey40',linewidth=.8)+
    geom_segment(data=brackets,aes(x=park_x+.8/3,xend=park_x+.8/3,y=bracket_y,yend=bracket_y-.025*span),
      inherit.aes=FALSE,color='grey40',linewidth=.8)+
    geom_text(data=brackets,aes(x=park_x+.4/3,y=label_y,label=label),inherit.aes=FALSE,
      size=8.5,lineheight=1.05,vjust=0,color='grey20')+
    scale_x_continuous(breaks=1:2,labels=c('MORA','NOCA'),limits=c(.5,2.5))+
    scale_fill_manual(name=NULL,values=correction_colors,
      labels=c('Observed lag-change rate','Pace correction effect rate','Direction correction effect rate'),
      guide=guide_legend(override.aes=list(alpha=1)))+
    scale_color_manual(values=correction_colors,guide='none')+
    scale_alpha_identity(guide='none')+
    coord_cartesian(ylim=c(violin_limits[1]-.06*span,upper))+
    labs(x=NULL,y='CCA distance per century',title=era_name)+base_theme+
    theme(plot.title=element_text(size=30,face='bold'),plot.margin=margin(12,14,12,14))
}
first_row=wrap_plots(
  contrast_plot(primary_metrics[1],filter(primary_limits,panel=='Climate'))+labs(tag='A'),
  contrast_plot(primary_metrics[2:3],filter(primary_limits,panel=='CCA'))+labs(tag='B'),
  nrow=1,widths=c(1.2,2),guides='auto')
second_row=wrap_plots(violin_panel('Holocene')+labs(tag='C'),
  violin_panel('Anthropocene')+labs(tag='D'),nrow=1,guides='auto')
figure=wrap_plots(first_row,second_row,ncol=1,heights=c(1,.85),guides='collect') &
  theme(legend.position='bottom',plot.background=element_rect(fill='white',color=NA),
    plot.tag=element_text(size=32,face='bold'),plot.tag.position='topleft')
corrected_figure=contrast_plot(corrected_metrics,corrected_limits,correction_labels=TRUE)+
  theme(legend.position='bottom',plot.background=element_rect(fill='white',color=NA))
if(render_figures) {
  stem=fig('main', 'fig_tracking_era_distributions')
  ggsave(paste0(stem,'.pdf'),figure,width=19,height=14.5,device=cairo_pdf,bg='white')
  ggsave(paste0(stem,'.png'),figure,width=19,height=14.5,dpi=300,bg='white')
  ggsave(tracking_model_figure('fig_tracking_correction_effect_contrasts.pdf'),
    corrected_figure,width=12,height=7.5,device=cairo_pdf,bg='white')
}
cat('Manuscript figure verified: primary reconstruction; 20 fitted means, ten covariance-based contrasts;',
  nrow(raw),'separate-model input values; joint correction panels:',nrow(paired_input)/2,
  'paired units, eight fitted means and four correction contrasts; panels A–D.\n')
