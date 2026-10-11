# Worked geometry example and descriptive lake-level tracking visualizations.
# Run after stages 13 and 09; read their canonical tables and write diagnostic PDFs.
# Rscript R/stages/09_tracking_example_and_visualizations.R
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

# Descriptive temporal panels and paired-plot boxplots. Response lines reuse
# maintained reporting estimates and their aligned transition predictors,
# following the same half-open mapping and complete-offset support rule.
# This stage never modifies or exports scientific tables.
# Regional climate bands reuse Figure 2's frozen catalog and subdivisions.
# These annotations do not classify lakes or change any tracking estimates.
climate_era_rects=read_csv(here('output/holocene_era_catalog.csv'),show_col_types=FALSE)
climate_subphases=read_csv(here('output/holocene_era_climate_change_subphases.csv'),show_col_types=FALSE)
climate_era_colors=c(`climate change`='#D3D3D6',`relative stability`='#EEEEF0')
stopifnot(nrow(climate_era_rects)>0L,!anyDuplicated(climate_era_rects$era_id),
 all(climate_era_rects$era_class %in% names(climate_era_colors)),
 all(is.finite(climate_era_rects$older_cal_bp)),all(is.finite(climate_era_rects$younger_cal_bp)),
 all(climate_era_rects$older_cal_bp>climate_era_rects$younger_cal_bp),
 all(head(climate_era_rects$younger_cal_bp,-1)==tail(climate_era_rects$older_cal_bp,-1)))
phase_check=climate_subphases |> left_join(climate_era_rects |>
 filter(era_class=='climate change') |>
 select(parent_era_id=era_id,parent_older=older_cal_bp,parent_younger=younger_cal_bp),
 by='parent_era_id')
stopifnot(!anyDuplicated(climate_subphases$subphase_id),
 all(is.finite(phase_check$older_cal_bp)),all(is.finite(phase_check$younger_cal_bp)),
 all(is.finite(phase_check$parent_older)),all(is.finite(phase_check$parent_younger)),
 all(phase_check$older_cal_bp>phase_check$younger_cal_bp),
 all(phase_check$older_cal_bp<=phase_check$parent_older),
 all(phase_check$younger_cal_bp>=phase_check$parent_younger))
climate_period_labels=bind_rows(
 climate_subphases |> transmute(label=subphase_id,older_cal_bp,younger_cal_bp),
 climate_era_rects |> filter(era_class=='relative stability') |>
 transmute(label=era_id,older_cal_bp,younger_cal_bp)) |>
 mutate(midpoint=(older_cal_bp+younger_cal_bp)/2) |> arrange(desc(older_cal_bp))
climate_internal_boundaries=climate_subphases |> group_by(parent_era_id) |>
 filter(older_cal_bp<max(older_cal_bp)) |> ungroup() |> transmute(cal_bp=older_cal_bp)
bin_width_years=unique(b$climate_dt_years)
stopifnot(length(bin_width_years)==1L,all(b$vegetation_dt_years==bin_width_years))
offsets=seq(0,bin_width_years-100,100)
n_offsets=length(offsets)
lake_order=c('JayBath','LogWallow','ReflectionPond','PantherPotholes')
lake_labels=c('Jay Bath (MORA)','Log Wallow (MORA)','Reflection Pond (MORA)','Panther Potholes (NOCA)')
predictors=c('standardized_climate_change_rate','fire_activity')
thin=b |> pivot_longer(all_of(c(metrics,predictors)),names_to='metric',values_to='value') |>
 mutate(lake=factor(lake,levels=lake_order,labels=lake_labels)) |>
 arrange(metric,lake,offset,interval_mid_cal_bp) |> group_by(metric,lake,offset) |>
 mutate(segment=cumsum(row_number()==1L |
   coalesce(interval_mid_cal_bp-lag(interval_mid_cal_bp)>bin_width_years,TRUE) |
   !is.finite(value) | !coalesce(is.finite(lag(value)),FALSE))) |> ungroup()
response_grid=read_csv(here('output/cca_tracking_holocene_lake_timeseries.csv'),show_col_types=FALSE) |>
 filter(metric %in% metrics) |> select(site,lake,t,metric,estimate,n_offsets,n_valid_offsets)
predictor_grid=lake_reporting_context(b,response_grid,bin_width_years) |>
 distinct(site,lake,t,n_valid_offsets,
   standardized_climate_change_rate=climate_rate,fire_activity) |>
 pivot_longer(all_of(predictors),names_to='metric',values_to='estimate') |>
 mutate(n_offsets=n_valid_offsets) |> filter(is.finite(estimate))
stopifnot(!anyDuplicated(predictor_grid[c('site','lake','t','metric')]))
thick=bind_rows(response_grid,predictor_grid) |>
 mutate(lake=factor(lake,levels=lake_order,labels=lake_labels)) |>
 arrange(metric,lake,t) |> group_by(metric,lake) |>
 mutate(segment=cumsum(row_number()==1L | coalesce(t-lag(t)>100,TRUE))) |> ungroup()
stopifnot(all(thick$n_offsets==n_offsets),all(thick$n_valid_offsets==n_offsets))
modern=read_csv(here('output/cca_tracking_anthropocene_plot_model_input.csv'),show_col_types=FALSE) |>
 mutate(site=factor(site,levels=c('MORA','NOCA')))
# FireActivity is a charcoal-frequency measure and is unavailable for modern
# plots. Their binary burned assignments remain available in the model input.
modern_long=modern |> pivot_longer(all_of(c(metrics,'standardized_climate_change_rate')),
 names_to='metric',values_to='value')
rates=c('lag_rate_per_century','observed_turnover_rate',
 'pace_effect_on_lag_per_century','direction_effect_on_lag_per_century')
palette=c(lag_rate_per_century='#2563eb',observed_turnover_rate='#059669',
 pace_effect_on_lag_per_century='#d42d75',direction_effect_on_lag_per_century='#c97710',
 magnitude_tracking_ratio='#5b56b8',angle_degrees='#157d91',
 standardized_climate_change_rate='#665641',fire_activity='#b63c35')
rate_labels=c('Lag-change rate','Observed turnover','Pace effect','Direction effect')
common=theme_minimal(base_size=12,base_family='sans')+
 theme(plot.title=element_text(size=20,face='bold',color='#152536'),
  plot.subtitle=element_text(size=12,color='#526273',margin=margin(b=12)),
  plot.caption=element_text(size=10,color='#526273',hjust=0,margin=margin(t=12)),
  panel.grid.minor=element_blank(),panel.grid.major=element_line(color='#e4e8ee',linewidth=.3),
  strip.text=element_text(face='bold',size=11,color='#233647'),
  strip.background=element_rect(fill='#f0f3f7',color=NA),
  strip.placement='outside',strip.text.y.left=element_text(angle=0,size=10),
  strip.background.y=element_blank(),panel.spacing=grid::unit(.8,'lines'),
  legend.position='bottom',legend.title=element_blank(),legend.text=element_text(size=11),
  plot.background=element_rect(fill='white',color=NA),plot.margin=margin(8,8,8,8))
oldest_age=(ceiling(max(c(thin$interval_mid_cal_bp,thick$t))/500)+1)*500
x_scale=scale_x_reverse(limits=c(oldest_age,0),breaks=seq(0,oldest_age,2500),
 labels=scales::label_comma(),expand=expansion(mult=c(.015,.015)))
# Four lake columns share a time axis and per-row scales. The final column
# compares independent modern plots at MORA/NOCA and has its own labeled scales.
# Undefined responses are removed independently by the plotting layers.
tracking_panels=function(display_metrics,rows,row_labels,title,subtitle,rate_legend=FALSE) {
  assign_rows=function(d) d |> filter(metric %in% display_metrics) |>
    mutate(display_row=factor(unname(rows[metric]),levels=row_labels))
  left_thin=assign_rows(thin);left_thick=assign_rows(thick)
  modern_values=assign_rows(modern_long) |>
    mutate(era='Anthropocene',metric=factor(metric,levels=display_metrics))
  baseline=tibble(display_row=factor(row_labels,levels=row_labels),y=0)
  if('magnitude_tracking_ratio' %in% names(rows))
    baseline$y[baseline$display_row==rows['magnitude_tracking_ratio']]=1
  if('angle_degrees' %in% names(rows))
    baseline$y[baseline$display_row==rows['angle_degrees']]=90
  legend_breaks=if(rate_legend) rates else display_metrics
  legend_labels=if(rate_legend) rate_labels else display_metrics
  # Reserve label space above the top-row curves, shared across the lakes.
  top_range=range(c(left_thin$value[left_thin$display_row==row_labels[1]],
    left_thick$estimate[left_thick$display_row==row_labels[1]],baseline$y[1]),finite=TRUE)
  label_span=diff(top_range)
  if(label_span==0) label_span=1
  era_labels=climate_period_labels |> mutate(display_row=factor(row_labels[1],levels=row_labels),
    label_ceiling=max(top_range)+.18*label_span)
  left=ggplot()+
    geom_blank(data=era_labels,aes(x=midpoint,y=label_ceiling),inherit.aes=FALSE)+
    geom_rect(data=climate_era_rects,
      aes(xmin=younger_cal_bp,xmax=older_cal_bp,ymin=-Inf,ymax=Inf,fill=era_class),
      inherit.aes=FALSE,alpha=.38,color=NA,show.legend=FALSE)+
    geom_vline(data=climate_internal_boundaries,aes(xintercept=cal_bp),
      inherit.aes=FALSE,color='#aeb3bd',linewidth=.25,linetype='dotted',show.legend=FALSE)+
    geom_text(data=era_labels,aes(x=midpoint,y=Inf,label=label),inherit.aes=FALSE,
      color='#3f4855',size=2.7,fontface='bold',angle=90,hjust=1.15,vjust=.5,show.legend=FALSE)+
    geom_hline(data=baseline,aes(yintercept=y),color='#8796a5',linewidth=.35,linetype='dashed')+
    geom_line(data=left_thin,aes(interval_mid_cal_bp,value,color=metric,
      group=interaction(metric,offset,segment)),linewidth=.35,alpha=.27,na.rm=TRUE)+
    geom_line(data=left_thick,aes(t,estimate,color=metric,
      group=interaction(metric,segment)),linewidth=1.05)+
    facet_grid(display_row~lake,scales='free_y',switch='y',drop=FALSE)+x_scale+
    scale_fill_manual(values=climate_era_colors,guide='none')+
    scale_color_manual(values=palette,breaks=legend_breaks,labels=legend_labels,
      guide=if(rate_legend) guide_legend(override.aes=list(alpha=1,linewidth=1.2),nrow=1) else 'none')+
    labs(x='Transition midpoint / reporting age (cal BP)',y=NULL)+common
  right=ggplot(modern_values,aes(site,value,color=metric,fill=metric))+
    geom_hline(data=baseline,aes(yintercept=y),inherit.aes=FALSE,
      color='#8796a5',linewidth=.35,linetype='dashed')+
    geom_boxplot(position=position_dodge(width=.8),width=.65,alpha=.3,
      linewidth=.4,outlier.size=.6,outlier.alpha=.45,na.rm=TRUE)+
    facet_grid(display_row~era,scales='free_y',drop=FALSE)+
    scale_color_manual(values=palette,guide='none')+scale_fill_manual(values=palette,guide='none')+
    labs(x='Paired plots',y=NULL)+common+
    theme(strip.text.y=element_blank(),strip.background.y=element_blank(),
      axis.text.x=element_text(size=11))
  # Retain the modern fire row without inventing continuous charcoal activity.
  missing_fire=tibble(display_row=factor(unname(rows['fire_activity']),levels=row_labels),
    era='Anthropocene',site=factor('MORA',levels=c('MORA','NOCA')),value=.5)
  right=right+geom_blank(data=missing_fire,aes(x=site,y=value),inherit.aes=FALSE)+
    geom_rect(data=missing_fire,aes(xmin=-Inf,xmax=Inf,ymin=-Inf,ymax=Inf),
      inherit.aes=FALSE,fill='white',color=NA)+
    geom_text(data=missing_fire,aes(x=1.5,y=.25),inherit.aes=FALSE,
      label='Continuous fire activity\nunavailable for modern plots',
      color=unname(palette['fire_activity']),size=3.1,lineheight=1.2)
  caption=paste0('Thin: individual offsets. Thick: medians across all ',n_offsets,
    ' offsets with complete finite support. Response medians reuse the maintained reporting grid.\n',
    'The four Holocene columns share scales by row; the Anthropocene column uses its own labeled y-scales. ',
    'Boxes show finite values from ',sum(modern$site=='MORA'),' MORA / ',
    sum(modern$site=='NOCA'),' NOCA paired plots.\n',
    'Climate is the standardized physical climate-change rate. MORA lakes share regional fire exposure; ',
    'modern fire is binary burned, not continuous charcoal activity.\n',
    'Regional climate periods: darker gray = climate change (CC); lighter gray = relative stability (S). ',
    'CC1a, CC1b and CC1c subdivide CC1; blank margins are outside the classified domain.')
  combined=(left+right)+plot_layout(widths=c(4,1.5),guides='collect')+
    plot_annotation(title=title,subtitle=subtitle,caption=caption,
      theme=common)
  # Remove the annotation's numerical axis after assembling aligned facets.
  # A null device avoids opening an unsolicited Rplots.pdf during layout.
  if(grDevices::dev.cur()==1L) {
    grDevices::pdf(file=NULL)
    on.exit(grDevices::dev.off(),add=TRUE)
  }
  combined_grob=patchworkGrob(combined)
  fire_row=match(unname(rows['fire_activity']),row_labels)
  axis_group=which(grepl('^axis-l.*-2$',combined_grob$layout$name))
  stopifnot(length(axis_group)==1L)
  fire_axis=which(combined_grob$grobs[[axis_group]]$layout$name==paste0('axis-l-',fire_row))
  stopifnot(length(fire_axis)==1L)
  combined_grob$grobs[[axis_group]]$grobs[[fire_axis]]=grid::nullGrob()
  combined_grob
}
rate_rows=c('Tracking responses\n(CCA units / century)',
 'Climate-change rate\n(calibration SD / century)','Fire activity\n(normalized frequency)')
rate_map=setNames(c(rep(rate_rows[1],length(rates)),rate_rows[2:3]),c(rates,predictors))
p_rates=tracking_panels(c(rates,predictors),rate_map,rate_rows,
 'Tracking responses, climate and fire',
 'Four Holocene lake columns with established climate periods; Anthropocene paired-plot boxplots',
 rate_legend=TRUE)
# Only magnitude ratio is displayed here: the rate ratio duplicates it for
# equal Holocene elapsed times. Both ratios remain in both model input tables.
other=c('magnitude_tracking_ratio','angle_degrees',predictors)
other_rows=c('Magnitude ratio\n(unitless)','Movement angle\n(degrees)',rate_rows[2:3])
p_other=tracking_panels(other,setNames(other_rows,other),other_rows,
 'Tracking magnitude ratio, angle, climate and fire',
 'One row per variable with established climate periods; duplicate Holocene rate-ratio display omitted')
if(render_figures) {
  ggsave(here('plot/test_figures/fig_tracking_offset_rates.pdf'),p_rates,width=20,height=10)
  ggsave(here('plot/test_figures/fig_tracking_offset_ratios_angles.pdf'),p_other,width=20,height=12)
}
