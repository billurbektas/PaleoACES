# Figure 5: site, climate and fire effects on lag-change rates by era, plus the
# appendix predictor figures (extended Anthropocene coefficients, R2, residuals,
# Holocene predictions). Reads the saved predictor-model tables; no refitting.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_predictor_models.R'),local=TRUE)
results_dir=tracking_primary_results('community')
tables=lapply(c(model_coefficients='model_coefficients',model_performance='model_performance',
  transition_predictions='transition_predictions'),
  function(name) read_csv(file.path(results_dir,paste0(name,'.csv')),show_col_types=FALSE))

co=tables$model_coefficients;pr=tables$transition_predictions
specification_labels=c(Holocene='Holocene',Anthropocene_basic='Anthropocene: basic',
  Anthropocene_extended='Anthropocene: extended')
holocene_effects=tracking_predictor_effect_panel(co,tables$model_performance,
  'Holocene','Holocene','A.')
modern_effects=tracking_predictor_effect_panel(co,tables$model_performance,
  'Anthropocene_basic','Anthropocene','B.')
effects_figure=wrap_plots(holocene_effects$plot,modern_effects$plot,nrow=1,guides='collect')+
  plot_annotation(caption=paste(
    'Points: GLS coefficients; bars: conditional 95% confidence intervals. Faded estimates have p ≥ 0.05.',
    'Fire and climate slopes are shared by MORA and NOCA; the site coefficient is NOCA − MORA.',
    'Holocene: site + climate rate + fire activity, MA(1). Anthropocene: site + burned, independent residuals.',
    'Correction effect = observed final lag − corrected final lag, per century; positive means the correction reduces lag.',
    'R² = 1 − SSE/SST; descriptive and may be negative for GLS.',sep='\n'),
    theme=theme(plot.caption=element_text(size=14,hjust=0,margin=margin(t=12)))) &
  theme(legend.position='bottom')
ggsave(fig('main', 'fig_tracking_predictor_era_coefficients.pdf'),effects_figure,
  width=19,height=9,device=cairo_pdf,bg='white')
ggsave(fig('main', 'fig_tracking_predictor_era_coefficients.png'),effects_figure,
  width=19,height=9,dpi=300,bg='white')
extended_effects=tracking_predictor_effect_panel(co,tables$model_performance,
  'Anthropocene_extended','Anthropocene: extended model',NULL)
ggsave(tracking_model_figure('fig_tracking_predictor_extended_coefficients.pdf'),
  extended_effects$plot+labs(subtitle='Site + elevation + climate-change rate + burned',
    x='Effect on response (CCA distance per century)'),
  width=12,height=9,device=cairo_pdf,bg='white')
write_csv(bind_rows(holocene_effects$data,modern_effects$data),file.path(results_dir,'figure_main_coefficients.csv'))
write_csv(extended_effects$data,file.path(results_dir,'figure_appendix_coefficients.csv'))
performance=tables$model_performance |> mutate(specification=unname(specification_labels[specification]))
r2=ggplot(performance,aes(specification,R2,fill=era))+geom_col(width=.6)+
  facet_wrap(~metric,labeller=labeller(metric=reconstruction_metric_label))+
  labs(x=NULL,y='Descriptive R2')+reconstruction_model_theme()+
  theme(axis.text.x=element_text(angle=25,hjust=1))
ggsave(tracking_model_figure('fig_tracking_predictor_R2.pdf'),r2,width=15,height=7,device=cairo_pdf)
# Each model has its own residual distribution: never pool basic and extended
# modern fits into a single era panel.
diagnostic_predictions=pr |> mutate(era=unname(specification_labels[specification]))
ggsave(tracking_model_figure('fig_tracking_predictor_residuals.pdf'),
  reconstruction_residual_plot(diagnostic_predictions),width=16,height=18,device=cairo_pdf)
catalog=read_csv(out('holocene_era_catalog.csv'),show_col_types=FALSE)
hp=pr |> filter(era=='Holocene') |> arrange(metric,lake,transition_index) |>
  group_by(metric,lake) |> mutate(next_predicted=lead(predicted),
    joins_next=lead(transition_index)==transition_index+1L & lead(age_hi)==age_lo) |> ungroup()
# Actual spans; gaps from exclusions remain blank instead of being bridged.
prediction=ggplot(hp,aes(interval_mid_cal_bp,predicted))+
  geom_rect(data=catalog,aes(xmin=younger_cal_bp,xmax=older_cal_bp,ymin=-Inf,ymax=Inf,
    fill=era_class),inherit.aes=FALSE,alpha=.35)+
  scale_fill_manual(values=c('climate change'='#D3D3D6','relative stability'='#EEEEF0'),guide='none')+
  geom_rect(aes(xmin=age_lo,xmax=age_hi,ymin=conf_low,ymax=conf_high),
    fill='#648FFF',alpha=.18,inherit.aes=FALSE)+
  geom_segment(aes(x=age_lo,xend=age_hi,yend=predicted),color='#648FFF',linewidth=1)+
  geom_segment(data=hp |> filter(joins_next),aes(x=age_lo,xend=age_lo,yend=next_predicted),
    color='#648FFF',linewidth=1)+
  facet_grid(metric~lake,scales='free_y',labeller=labeller(metric=reconstruction_metric_label))+
  scale_x_reverse()+
  labs(x='Transition age (cal BP)',y='Lag change / correction effect (CCA distance per century)',
    caption='Joined fitted values over actual transition intervals; shaded bands: conditional 95% mean-confidence intervals. Excluded transitions remain gaps.')+
  reconstruction_model_theme()
ggsave(tracking_model_figure('fig_tracking_predictor_holocene_predictions.pdf'),prediction,width=19,height=12,device=cairo_pdf)
