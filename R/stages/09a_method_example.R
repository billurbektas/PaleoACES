# Worked geometry and chronology example from canonical lake-level realizations.
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/tracking_data.R'),local=TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures',TRUE))
r = read_csv(here('output/cca_tracking_holocene_lake_realizations.csv'),show_col_types=FALSE)
b = read_csv(here('output/cca_tracking_holocene_lake_by_offset.csv'),show_col_types=FALSE)
interval = b |> filter(lake=='PantherPotholes',offset==0) |>
  mutate(distance=abs((age_hi+age_lo)/2-3000)) |> arrange(distance) |> slice(1)
draws = r |> filter(lake=='PantherPotholes',offset==0,
  age_hi==interval$age_hi,age_lo==interval$age_lo)
example = draws |> filter(pace_counterfactual_valid,direction_counterfactual_valid) |>
  arrange(draw) |> slice(1)
if(nrow(example)!=1L) stop('No valid canonical worked-example realization')
points = tibble(label=c('O1','O2','P1','P2','Pace corrected','Direction corrected'),
  CCA1=c(example$o1,example$o1_2,example$p1,example$p1_2,example$pace_corrected_CCA1,example$direction_corrected_CCA1),
  CCA2=c(example$o2,example$o2_2,example$p2,example$p2_2,example$pace_corrected_CCA2,example$direction_corrected_CCA2))
vectors = tibble(type=c('Observed','Predicted','Pace corrected','Direction corrected'),
  x=c(example$o1,example$p1,example$o1,example$o1),y=c(example$o2,example$p2,example$o2,example$o2),
  xend=c(example$o1_2,example$p1_2,example$pace_corrected_CCA1,example$direction_corrected_CCA1),
  yend=c(example$o2_2,example$p2_2,example$pace_corrected_CCA2,example$direction_corrected_CCA2))
a = ggplot(points,aes(CCA1,CCA2)) + geom_segment(data=vectors,
  aes(x=x,y=y,xend=xend,yend=yend,color=type),inherit.aes=FALSE,
  arrow=grid::arrow(length=grid::unit(2,'mm'))) + geom_point() +
  geom_text(aes(label=label),vjust=-.7,size=3) + coord_equal() +
  labs(title='A. Actual and corrected movement',color=NULL) + theme_minimal(base_size=10)
lag = tibble(endpoint=c('Initial','Actual final','Pace corrected','Direction corrected'),
  lag=c(example$lag_t1,example$lag_t2,example$lag_t2_pace_corrected,example$lag_t2_direction_corrected))
p = ggplot(lag,aes(endpoint,lag)) + geom_col(fill='#4477AA') +
  geom_text(aes(label=sprintf('%.3f',lag)),vjust=-.3,size=3) +
  labs(title='B. Distance to actual predicted position',x=NULL,y='Lag (CCA units)') +
  theme_minimal(base_size=10) + theme(axis.text.x=element_text(angle=20,hjust=1))
metrics = tracking_response_names()
values = example |> select(all_of(metrics)) |> pivot_longer(everything(),names_to='metric',values_to='value')
q = ggplot(values,aes(x=1,y=value)) + geom_point(size=2) +
  geom_text(aes(label=sprintf('%.3f',value)),nudge_x=.2,size=3) +
  facet_wrap(~metric,scales='free_y',ncol=2) + labs(title='C. Focused quantities for this draw',x=NULL,y=NULL) +
  theme_minimal(base_size=9) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank())
uncertainty = draws |> select(draw,lag_rate_per_century,pace_effect_on_lag_per_century,
  direction_effect_on_lag_per_century) |> pivot_longer(-draw,names_to='metric',values_to='value')
s = ggplot(uncertainty,aes(value)) + geom_histogram(bins=15,fill='#228833',color='white',na.rm=TRUE) +
  facet_wrap(~metric,scales='free',ncol=1) + labs(title='D. Valid chronology-draw distributions',
    x='CCA units per century',y='Draws') + theme_minimal(base_size=9)
figure = (a+p)/(q+s) + plot_annotation(title=paste0('Panther Potholes: ',example$age_hi,' to ',example$age_lo,' cal BP'),
  subtitle=paste0('Offset 0; geometry draw ',example$draw,'; ',nrow(draws),' of 100 draws support this actual transition.'),
  caption='Both corrections start at O1. Effects compare with the actual final lag and are nonadditive. Climate bins contain ten native slices.\nChronology distributions are conditional on valid realizations; draws and offsets are not ecological replicates.')
if(render_figures) ggsave(here('plot/test_figures/fig_method_worked_example.pdf'),figure,width=12,height=11)
