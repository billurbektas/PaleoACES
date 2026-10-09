# Manuscript Figure 4: untransformed offset-0 inputs with MA1 means and contrasts.
# Reuse stage 10 results; no model refitting or response recalculation.
# Rscript R/stages/10b_tracking_manuscript_figure.R
suppressPackageStartupMessages({library(here);library(tidyverse)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_data.R'),local=TRUE)
source(here('R/helpers/tracking_model_reporting.R'),local=TRUE)
render_figures=isTRUE(getOption('paleoaces.render_figures',TRUE))
metrics=c('standardized_climate_change_rate','observed_turnover_rate','lag_rate_per_century')
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
if(nrow(means)!=12L || anyDuplicated(means[keys]) ||
   nrow(contrasts)!=6L || anyDuplicated(contrasts[c('metric','site')]) ||
   nrow(check)!=12L || anyNA(check[c('n','n_raw')]) || any(check$n!=check$n_raw) ||
   any(!is.finite(as.matrix(means[c('estimate','conf_low','conf_high')]))) ||
   any(!is.finite(as.matrix(contrasts[c('estimate','conf_low','conf_high','p_value')]))) ||
   any(contrasts$p_value<0 | contrasts$p_value>1))
  stop('Missing, duplicate or inconsistent offset-0 model results and raw inputs')
differences=means |> select(all_of(keys),estimate) |>
  pivot_wider(names_from=era,values_from=estimate) |>
  left_join(contrasts |> select(metric,site,contrast_estimate=estimate),
    by=c('metric','site'),relationship='one-to-one')
if(any(abs(differences$Anthropocene-differences$Holocene-differences$contrast_estimate)>1e-8))
  stop('Displayed contrast disagrees with the difference between fitted means')

# One shared linear scale per response across both parks, including every value.
ranges=bind_rows(raw |> select(metric,estimate),
  means |> transmute(metric,estimate=conf_low),means |> transmute(metric,estimate=conf_high)) |>
  group_by(metric) |> summarise(lo=min(estimate),hi=max(estimate),.groups='drop') |>
  mutate(span=pmax(hi-lo,1e-6),bracket_y=hi+.08*span,label_y=hi+.23*span,
    count_y=lo-.08*span,plot_top=hi+.35*span,plot_bottom=lo-.13*span)
annotations=contrasts |> left_join(ranges,by='metric',relationship='many-to-one') |>
  mutate(label=sprintf('A - H = %+.3f%s\n95%% CI [%+.3f, %+.3f]',
    estimate,if_else(p_value<.05,' *',''),conf_low,conf_high))
counts=counts |> left_join(ranges,by='metric',relationship='many-to-one')
panel_labels=c(
  standardized_climate_change_rate='A. Climate-change rate',
  observed_turnover_rate='B. Community turnover rate',
  lag_rate_per_century='C. Lag-change rate')
prepare=function(x) x |> mutate(metric=factor(metric,levels=metrics),
  site=factor(site,levels=c('MORA','NOCA')))
raw=prepare(raw);means=prepare(means);annotations=prepare(annotations)
counts=prepare(counts);ranges=ranges |> mutate(metric=factor(metric,levels=metrics))
mean_color='grey25'
figure=ggplot(raw,aes(era,estimate))+
  geom_hline(yintercept=0,color='grey70',linetype='dashed',linewidth=.6)+
  geom_violin(trim=TRUE,scale='width',width=.7,
    fill='grey85',color='grey50',linewidth=.65)+
  geom_point(color='grey50',position=position_jitter(width=.09,height=0,seed=20261009),
    size=1.4,alpha=.3)+
  geom_line(data=means,aes(group=site),color=mean_color,linewidth=1.1)+
  geom_errorbar(data=means,aes(ymin=conf_low,ymax=conf_high),width=.14,
    color=mean_color,linewidth=1.15)+
  geom_point(data=means,shape=21,fill='white',color=mean_color,size=2.8,stroke=.85)+
  geom_segment(data=annotations,aes(x=1,xend=2,y=bracket_y,yend=bracket_y),
    inherit.aes=FALSE,color='grey30',linewidth=.7)+
  geom_segment(data=annotations,aes(x=1,xend=1,y=bracket_y,yend=bracket_y-.025*span),
    inherit.aes=FALSE,color='grey30',linewidth=.7)+
  geom_segment(data=annotations,aes(x=2,xend=2,y=bracket_y,yend=bracket_y-.025*span),
    inherit.aes=FALSE,color='grey30',linewidth=.7)+
  geom_label(data=annotations,aes(x=1.5,y=label_y,label=label),inherit.aes=FALSE,
    size=5.6,lineheight=1.1,linewidth=0,label.padding=grid::unit(.12,'lines'))+
  geom_text(data=counts,aes(x=era,y=count_y,label=paste0('n = ',n_raw)),
    inherit.aes=FALSE,size=5.5)+
  geom_blank(data=ranges,aes(x=1,y=plot_top),inherit.aes=FALSE)+
  geom_blank(data=ranges,aes(x=1,y=plot_bottom),inherit.aes=FALSE)+
  facet_grid(metric ~ site,scales='free_y',switch='y',
    labeller=labeller(metric=as_labeller(panel_labels)))+
  scale_x_discrete(limits=c('Holocene','Anthropocene'),expand=expansion(add=.6))+
  scale_y_continuous(expand=expansion(mult=.01))+
  labs(title='Climate-change, community turnover and lag-change rates',
    subtitle='Offset 0 · Raw input distributions and MA(1) GLS estimates',x=NULL,y=NULL,
    caption=paste('Violins and dots: untransformed model inputs. Open circles and connecting lines: fitted era means; bars: 95% confidence intervals.',
      'A - H: Anthropocene minus Holocene, with its covariance-based 95% interval. All model intervals use Satterthwaite degrees of freedom.',
      'Holocene inputs are chronology-draw medians for actual lake transitions; Anthropocene inputs are individual paired plots.',
      '* p < 0.05 for the unadjusted Anthropocene-minus-Holocene contrast.',sep='\n'))+
  theme_minimal(base_size=18)+theme(legend.position='none',
    panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),
    panel.spacing=grid::unit(1.1,'lines'),strip.placement='outside',
    strip.text=element_text(size=20,face='bold'),
    strip.text.y.left=element_text(angle=0,size=18,lineheight=1.15),
    axis.text=element_text(size=17,color='grey20'),
    plot.title=element_text(size=26,face='bold'),plot.subtitle=element_text(size=18),
    plot.caption=element_text(size=14,hjust=0,lineheight=1.15),
    plot.title.position='plot',plot.caption.position='plot',
    plot.margin=margin(12,16,12,12))
if(render_figures) {
  stem=here('plot/fig_tracking_era_distributions')
  ggsave(paste0(stem,'.pdf'),figure,width=14,height=13)
  ggsave(paste0(stem,'.png'),figure,width=14,height=13,dpi=300)
}
cat('Manuscript figure verified: offset 0; 12 MA1 means, six covariance-based contrasts;',
  nrow(raw),'untransformed input values.\n')
