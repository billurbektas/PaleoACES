# Worked geometry example and exploratory lake-level tracking visualizations.
# Run after stage 09; this stage reads canonical tables and writes diagnostic PDFs.
# Rscript R/stages/09a_tracking_example_and_visualizations.R
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

# Exploratory offset trajectories. The seven responses are medians across finite
# chronology draws in each lake/offset transition. Use existing reporting-grid
# estimates for thick lines; no smoothing, refitting or new metric aggregation.
bin_width_years=unique(b$climate_dt_years)
stopifnot(length(bin_width_years)==1L,all(b$vegetation_dt_years==bin_width_years))
n_offsets=bin_width_years/100L
lake_order=c('JayBath','LogWallow','ReflectionPond','PantherPotholes')
lake_labels=c('Jay Bath (MORA)','Log Wallow (MORA)','Reflection Pond (MORA)','Panther Potholes (NOCA)')
thin=b |> pivot_longer(all_of(metrics),names_to='metric',values_to='value') |>
 mutate(lake=factor(lake,levels=lake_order,labels=lake_labels)) |>
 arrange(metric,lake,offset,interval_mid_cal_bp) |>
 group_by(metric,lake,offset) |>
 # Break a line at a missing transition or an undefined response.
 mutate(segment=cumsum(row_number()==1L |
   coalesce(interval_mid_cal_bp-lag(interval_mid_cal_bp)>bin_width_years,TRUE) |
   !is.finite(value) | !coalesce(is.finite(lag(value)),FALSE))) |> ungroup()
# These are the already maintained median-of-offset-median estimates.
thick=read_csv(here('output/cca_tracking_holocene_lake_timeseries.csv'),show_col_types=FALSE) |>
 filter(metric %in% metrics) |> mutate(lake=factor(lake,levels=lake_order,labels=lake_labels)) |>
 arrange(metric,lake,t) |> group_by(metric,lake) |>
 mutate(segment=cumsum(row_number()==1L | coalesce(t-lag(t)>100,TRUE))) |> ungroup()
stopifnot(all(thick$bin_width_years==bin_width_years),
 all(thick$n_offsets==n_offsets),all(thick$n_valid_offsets==n_offsets))
common=theme_minimal(base_size=13,base_family='sans')+
 theme(plot.title=element_text(size=20,face='bold',color='#152536'),
  plot.subtitle=element_text(size=12,color='#526273',margin=margin(b=12)),
  plot.caption=element_text(size=10,color='#526273',hjust=0,margin=margin(t=12)),
  panel.grid.minor=element_blank(),panel.grid.major=element_line(color='#e4e8ee',linewidth=.3),
  strip.text=element_text(face='bold',size=12,color='#233647'),
  strip.background=element_rect(fill='#f0f3f7',color=NA),
  panel.spacing=grid::unit(1.2,'lines'),
  legend.position='bottom',legend.title=element_blank(),
  legend.text=element_text(size=12),plot.background=element_rect(fill='white',color=NA),
  plot.margin=margin(16,20,16,16))
oldest_age=(ceiling(max(c(thin$interval_mid_cal_bp,thick$t))/500)+1)*500
x_scale=scale_x_reverse(limits=c(oldest_age,0),breaks=seq(0,oldest_age,2500),
 labels=scales::label_comma(),expand=expansion(mult=c(.015,.015)))
line_caption=paste0("Thin: each offset's chronology-draw median at actual transition midpoints.  Thick: existing reporting median across all ",
 n_offsets,' offsets.\nGaps remain gaps; the offsets are alternative bin placements, not independent ecological replicates.')
rates=c('lag_rate_per_century','observed_turnover_rate',
 'pace_effect_on_lag_per_century','direction_effect_on_lag_per_century')
colors=c(lag_rate_per_century='#2563eb',observed_turnover_rate='#059669',
 pace_effect_on_lag_per_century='#d42d75',direction_effect_on_lag_per_century='#c97710')
labels=c('Lag-change rate','Observed turnover','Pace effect','Direction effect')
p_rates=ggplot()+
 geom_hline(yintercept=0,color='#8796a5',linewidth=.4,linetype='dashed')+
 geom_line(data=filter(thin,metric %in% rates),
  aes(interval_mid_cal_bp,value,color=metric,group=interaction(metric,offset,segment)),
  linewidth=.35,alpha=.27,na.rm=TRUE)+
 geom_line(data=filter(thick,metric %in% rates),
  aes(t,estimate,color=metric,group=interaction(metric,segment)),linewidth=1.15)+
 facet_wrap(~lake,ncol=2)+x_scale+
 scale_color_manual(values=colors,breaks=rates,labels=labels)+
 guides(color=guide_legend(override.aes=list(alpha=1,linewidth=1.3),nrow=1))+
 labs(title='Holocene tracking responses: alternative offsets',
  subtitle='Four responses on the same CCA-unit scale; each lake uses its own vegetation and climate record',
  x='Transition midpoint / reporting age (cal BP)',y='CCA units per century',caption=line_caption)+common
other=c('magnitude_tracking_ratio','rate_tracking_ratio','angle_degrees')
row_labels=c('Magnitude ratio\n(unitless)','Rate ratio\n(unitless)','Movement angle\n(degrees)')
row_map=function(d) d |> filter(metric %in% other) |>
 mutate(response=factor(metric,levels=other,labels=row_labels))
reference=expand_grid(lake=factor(lake_labels,levels=lake_labels),
 response=factor(row_labels,levels=row_labels)) |>
 mutate(baseline=if_else(response==row_labels[3],90,1))
p_other=ggplot()+
 geom_hline(data=reference,aes(yintercept=baseline),color='#8796a5',linewidth=.4,linetype='dashed')+
 geom_line(data=row_map(thin),aes(interval_mid_cal_bp,value,color=metric,
  group=interaction(offset,segment)),linewidth=.4,alpha=.32,na.rm=TRUE)+
 geom_line(data=row_map(thick),aes(t,estimate,color=metric,group=segment),linewidth=1.2)+
 facet_grid(response~lake,scales='free_y',switch='y')+x_scale+
 scale_color_manual(values=c(magnitude_tracking_ratio='#5b56b8',
 rate_tracking_ratio='#8b46a3',angle_degrees='#157d91'),guide='none')+
 labs(title='Tracking ratios and movement angle',
  subtitle=paste0('Separate response scales; the magnitude and rate ratios coincide because both Holocene elapsed times are ',
   format(bin_width_years,big.mark=','),' years'),
  x='Transition midpoint / reporting age (cal BP)',y=NULL,
  caption=paste0(line_caption,'\nDashed reference: tracking ratio = 1; angle = 90°. Ratios retain their full observed range.'))+
 common+theme(strip.placement='outside',strip.text.y.left=element_text(angle=0,size=11),
  strip.background.y=element_blank(),axis.text.x=element_text(size=10))
if(render_figures) {
  ggsave(here('plot/test_figures/fig_tracking_offset_rates.pdf'),
    p_rates,width=15,height=9.5)
  ggsave(here('plot/test_figures/fig_tracking_offset_ratios_angles.pdf'),
    p_other,width=17,height=10)
}
