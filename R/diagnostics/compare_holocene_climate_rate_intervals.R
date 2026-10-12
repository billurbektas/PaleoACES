# Standalone, climate-only audit. Does not run or modify the analytical workflow.
# Run: Rscript R/diagnostics/compare_holocene_climate_rate_intervals.R
# Uses existing CHELSA monthly records and the fixed pooled calibration SDs.
# No vegetation, chronologies, CCA projection, model fitting or interpolation.
suppressPackageStartupMessages({library(here);library(tidyverse);library(patchwork)})
source(here('R/helpers/config.R'),local=TRUE)
source(here('R/helpers/climate_variables.R'),local=TRUE)
source(here('R/helpers/tracking_metrics.R'),local=TRUE)

input_paths=here(c('output/chelsa_paleo_ponds.csv',
  'output/cca_tracking_climate_scaling.csv',
  'output/holocene_era_climate_lake_changes.csv'))
if(!all(file.exists(input_paths))) stop('Missing cached climate/scaling audit input')
input_md5=tools::md5sum(input_paths)
ponds=read_csv(input_paths[1],show_col_types=FALSE)
scaling=read_csv(input_paths[2],show_col_types=FALSE)
stopifnot(identical(scaling$variable,CCA_VARIABLES),all(scaling$n_calibration==607L),
  all(scaling$sd>0),all(ponds$cal_BP==1950-ponds$slice*100))

# Identical season definitions and raw/corrected flag to both old and new tracking.
# The native -50 BP slice (2000 CE) is outside this Holocene-only diagnostic.
all_levels=ponds |> transmute(unit=lake,period=site,variable,time=slice,month,
  value=if(PALEO_USE_BIAS_CORRECTED) value_corrected else value_raw) |>
  derive_climate_vars(winter_shift=FALSE) |>
  rename(lake=unit,site=period,slice=time) |>
  mutate(cal_bp=1950-slice*100) |>
  select(site,lake,cal_bp,all_of(CCA_VARIABLES))
levels=all_levels |> filter(cal_bp>=0) |> arrange(site,lake,desc(cal_bp))
stopifnot(!anyDuplicated(levels[c('site','lake','cal_bp')]),
  all(is.finite(as.matrix(levels[CCA_VARIABLES]))))
sd_vector=setNames(scaling$sd,scaling$variable)[CCA_VARIABLES]

rate_records=paired_records=list()
for(lake_name in unique(levels$lake)) {
  d=levels |> filter(lake==lake_name)
  stopifnot(all(diff(d$cal_bp)==-100),nrow(d)>20L)
  X=as.matrix(d[CCA_VARIABLES])
  Z=sweep(X,2,sd_vector,'/')
  endpoint=function(step,method) {
    i=seq_len(nrow(d)-step)
    x=d[i,c('site','lake',CCA_VARIABLES)]
    x[paste0(CCA_VARIABLES,'_2')]=d[i+step,CCA_VARIABLES]
    x$age_hi=d$cal_bp[i];x$age_lo=d$cal_bp[i+step]
    x$climate_dt_years=x$age_hi-x$age_lo
    x$interval_mid_cal_bp=(x$age_hi+x$age_lo)/2
    x$method=method;x$endpoint_representation='native century climate'
    x=add_climate_change_metrics(x,scaling)
    independent=sqrt(rowSums((sweep(X[i+step,,drop=FALSE]-X[i,,drop=FALSE],
      2,sd_vector,'/')/step)^2))
    stopifnot(max(abs(independent-x$standardized_climate_change_rate))<1e-12)
    x
  }
  fine=endpoint(1L,'100_year_endpoints')
  coarse=endpoint(10L,'1000_year_endpoints')

  # Matched comparison: each coarse interval contains exactly ten fine changes.
  # Compare the norm of the average signed vector with the average vector norm.
  # This isolates directional cancellation with identical endpoints and coverage.
  fine_vectors=diff(Z)
  for(i in seq_len(nrow(coarse))) {
    steps=fine_vectors[i:(i+9L),,drop=FALSE]
    signed_average=colMeans(steps)
    signed_coarse=(Z[i+10L,]-Z[i,])/10
    coarse_rate=sqrt(sum(signed_coarse^2))
    path_rate=mean(sqrt(rowSums(steps^2)))
    stopifnot(max(abs(signed_average-signed_coarse))<1e-12,
      path_rate+1e-12>=coarse_rate)
    paired_records[[length(paired_records)+1L]]=tibble(
      site=d$site[1],lake=lake_name,age_hi=coarse$age_hi[i],age_lo=coarse$age_lo[i],
      interval_mid_cal_bp=coarse$interval_mid_cal_bp[i],n_century_changes=10L,
      mean_100_year_rate=path_rate,endpoint_1000_year_rate=coarse_rate,
      net_to_path_fraction=if(path_rate>0) coarse_rate/path_rate else NA_real_,
      fine_to_coarse_ratio=if(coarse_rate>0) path_rate/coarse_rate else NA_real_)
  }

  # Historical smoothing: two adjacent means of ten century values each.
  # Moving the 20-cell window one century at a time covers every complete bin
  # placement without any ecological offsets, vegetation eligibility or models.
  averaged=map_dfr(seq_len(nrow(d)-19L),function(i) {
    old=i:(i+9L);young=(i+10L):(i+19L)
    x=tibble(site=d$site[1],lake=lake_name,
      age_hi=mean(d$cal_bp[old]),age_lo=mean(d$cal_bp[young]),
      climate_dt_years=1000,method='1000_year_bin_means',
      endpoint_representation='mean of ten native century values')
    for(v in CCA_VARIABLES) {
      x[[v]]=mean(d[[v]][old]);x[[paste0(v,'_2')]]=mean(d[[v]][young])
    }
    x$interval_mid_cal_bp=(x$age_hi+x$age_lo)/2
    add_climate_change_metrics(x,scaling)
  })
  rate_records[[lake_name]]=bind_rows(fine,coarse,averaged)
}
rates=bind_rows(rate_records)
paired=bind_rows(paired_records)

# Audit the reconstructed historical bin means against the independently stored
# descriptive climate table, which is read without changing its classifications.
historical=read_csv(input_paths[3],show_col_types=FALSE)
check=rates |> filter(method=='1000_year_bin_means') |>
  select(site,lake,age_hi,age_lo,all_of(CCA_VARIABLES),all_of(paste0(CCA_VARIABLES,'_2'))) |>
  pivot_longer(all_of(CCA_VARIABLES),names_to='variable',values_to='older_mean') |>
  rowwise() |> mutate(younger_mean=c_across(all_of(paste0(CCA_VARIABLES,'_2')))[
    match(variable,CCA_VARIABLES)]) |> ungroup() |>
  left_join(historical |> select(site,lake,age_hi,age_lo,variable,
    stored_older=older_bin_mean,stored_younger=younger_bin_mean),
    by=c('site','lake','age_hi','age_lo','variable'),relationship='one-to-one')
stopifnot(!anyNA(check$stored_older),max(abs(check$older_mean-check$stored_older))<1e-12,
  max(abs(check$younger_mean-check$stored_younger))<1e-12)

# All marginal summaries share the common midpoint domain of all three methods.
# Matched-window path/net comparisons above use their full 50–10950 BP domain.
domain=rates |> group_by(method) |> summarise(youngest=min(interval_mid_cal_bp),
  oldest=max(interval_mid_cal_bp),.groups='drop')
common_low=max(domain$youngest);common_high=min(domain$oldest)
comparison=rates |> filter(interval_mid_cal_bp>=common_low,interval_mid_cal_bp<=common_high)
summary=comparison |> group_by(site,lake,method) |> summarise(
  n_intervals=n(),midpoint_min=min(interval_mid_cal_bp),midpoint_max=max(interval_mid_cal_bp),
  mean_rate=mean(standardized_climate_change_rate),median_rate=median(standardized_climate_change_rate),
  p025=quantile(standardized_climate_change_rate,.025),
  p975=quantile(standardized_climate_change_rate,.975),
  max_rate=max(standardized_climate_change_rate),.groups='drop')
paired_summary=paired |> group_by(site,lake) |> summarise(
  n_matched_windows=n(),mean_fine_rate=mean(mean_100_year_rate),
  mean_coarse_rate=mean(endpoint_1000_year_rate),
  ratio_of_mean_rates=mean_fine_rate/mean_coarse_rate,
  median_paired_ratio=median(fine_to_coarse_ratio,na.rm=TRUE),
  median_net_to_path_fraction=median(net_to_path_fraction,na.rm=TRUE),.groups='drop')
component_records=map_dfr(CCA_VARIABLES,function(v) comparison |> transmute(site,lake,method,
  interval_mid_cal_bp,variable=v,physical_signed_rate=.data[[paste0(v,'_rate_per_century')]],
  standardized_signed_rate=.data[[paste0(v,'_z_rate_per_century')]]))
component_summary=component_records |> group_by(site,lake,method,variable) |> summarise(
  mean_absolute_standardized_rate=mean(abs(standardized_signed_rate)),
  mean_squared_standardized_rate=mean(standardized_signed_rate^2),.groups='drop') |>
  group_by(site,lake,method) |> mutate(
    share_of_squared_multivariate_rate=mean_squared_standardized_rate/sum(mean_squared_standardized_rate)) |>
  ungroup()
native_patterns=map_dfr(CCA_VARIABLES,function(v) rates |>
  filter(method=='100_year_endpoints') |> arrange(site,lake,desc(age_hi)) |>
  group_by(site,lake) |> group_modify(function(d,keys) {
    delta=d[[paste0(v,'_change')]]
    adjacent_old=head(delta,-1);adjacent_young=tail(delta,-1)
    nonzero=adjacent_old!=0 & adjacent_young!=0
    tibble(variable=v,n_changes=length(delta),n_nonzero_neighbor_pairs=sum(nonzero),
      n_sign_reversals=sum(adjacent_old[nonzero]*adjacent_young[nonzero]<0),
      sign_reversal_fraction=if(any(nonzero)) n_sign_reversals/sum(nonzero) else NA_real_,
      mean_absolute_100_year_change=mean(abs(delta)),physical_unit=unname(CLIMATE_VARIABLE_UNITS[v]))
  }) |> ungroup())

out=here('output/diagnostics/climate_rate_intervals')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write_csv(levels,file.path(out,'native_seasonal_climate.csv'))
write_csv(scaling,file.path(out,'standardization_reference.csv'))
write_csv(rates,file.path(out,'climate_rates.csv'))
write_csv(summary,file.path(out,'rate_summary_common_domain.csv'))
write_csv(paired,file.path(out,'matched_1000_year_windows.csv'))
write_csv(paired_summary,file.path(out,'matched_window_summary.csv'))
write_csv(component_records,file.path(out,'seasonal_component_rates.csv'))
write_csv(component_summary,file.path(out,'seasonal_component_summary.csv'))
write_csv(native_patterns,file.path(out,'native_change_patterns.csv'))

method_order=c('100_year_endpoints','1000_year_endpoints','1000_year_bin_means')
method_labels=c('100-year\nendpoints','1,000-year\nendpoints','1,000-year\nbin means')
palette=setNames(c('#648FFF','#FF7F00','#785EF0'),method_order)
rates$method=factor(rates$method,levels=method_order)
comparison$method=factor(comparison$method,levels=method_order)
component_summary$method=factor(component_summary$method,levels=method_order)
style=theme_minimal(base_size=18)+theme(panel.grid.minor=element_blank(),
  strip.text=element_text(face='bold',size=18),legend.position='bottom')
time_plot=ggplot(rates,aes(interval_mid_cal_bp,standardized_climate_change_rate,
  color=method,group=method))+geom_line(aes(linewidth=method),alpha=.85)+
  facet_wrap(~lake,nrow=1)+scale_x_reverse()+
  scale_color_manual(values=palette,labels=gsub('\n',' ',method_labels),name=NULL)+
  scale_linewidth_manual(values=c(.45,1,1),guide='none')+
  labs(x='Climate interval midpoint (cal BP)',y='Standardized climate\nchange per century',
    title='Same CHELSA series and calibration SDs; different temporal scales')+style
box_plot=ggplot(comparison,aes(method,standardized_climate_change_rate,color=method))+
  geom_boxplot(width=.55,outlier.size=.7)+facet_wrap(~lake,nrow=1)+
  scale_x_discrete(labels=method_labels)+scale_color_manual(values=palette,guide='none')+
  labs(x=NULL,y='Standardized climate\nchange per century',
    title=paste0('Rate distributions over the common midpoint range: ',common_low,'–',common_high,' cal BP'))+style+
  theme(axis.text.x=element_text(size=14))
variable_plot=ggplot(component_summary,aes(variable,mean_absolute_standardized_rate,
  fill=method))+geom_col(position=position_dodge(width=.8),width=.72)+
  facet_wrap(~lake,nrow=1)+scale_fill_manual(values=palette,guide='none')+
  scale_x_discrete(labels=c(MSpT='Spring\ntemp.',MWT='Winter\ntemp.',SP='Summer\nprecip.',WP='Winter\nprecip.'))+
  labs(x=NULL,y='Mean absolute seasonal\nchange per century',
    title='Seasonal components, using the same standardization')+style+
  theme(axis.text.x=element_text(size=14))
figure=(time_plot/box_plot/variable_plot)+plot_layout(heights=c(1.2,1,1))+
  plot_annotation(caption=paste(
    'All rates use the same four seasonal variables and pooled calibration SDs; units are standardized climate distance per century.',
    'Overlapping intervals are descriptive calculations, not independent replicates. Boxes summarize rates, not uncertainty.',
    'The 1,000-year bin-mean series reproduces the previous climate calculation; accepted CC/S classifications remain unchanged.',sep='\n'),
    theme=theme(plot.caption=element_text(size=14,hjust=0)))
figure_path=here('plot/test_figures/fig_climate_rate_100_vs_1000_years.pdf')
ggsave(figure_path,figure,width=20,height=14,device=cairo_pdf)

report=c('CLIMATE-ONLY TEMPORAL-SCALE DIAGNOSTIC',
  'Reproduce: Rscript R/diagnostics/compare_holocene_climate_rate_intervals.R',
  '',paste('Input climate:',if(PALEO_USE_BIAS_CORRECTED) 'value_corrected' else 'value_raw'),
  'Seasons: mean-extrema spring/winter temperature; summer/winter precipitation sums.',
  'Variables: MSpT, MWT, SP, WP; pooled 607-plot calibration SDs, unchanged.',
  'Rate = sqrt(sum(((younger - older) / calibration_SD)^2)) * 100 / elapsed_years.',
  'No vegetation, Bacon uncertainty, CCA projection, interpolation or statistical models.',
  '', 'Native -50 BP climate slice excluded as outside the Holocene; all nonnegative native cells retained.',
  paste('Common midpoint summary domain:',common_low,'to',common_high,'cal BP.'),
  '100-year endpoints: adjacent native century values.',
  '1,000-year endpoints: native values exactly 1,000 years apart.',
  '1,000-year bin means: changes between adjacent means of ten century values, centers 1,000 years apart.',
  '', 'Matched windows: ten signed century changes telescope to each 1,000-year endpoint change.',
  'Longer-interval net rate is the norm of the average signed changes; fine path rate is the average of their norms.',
  'The path rate cannot be less than the net rate; reversals/direction changes reduce the net rate.',
  'The previous bin-mean method additionally smooths each endpoint before differencing.',
  '', 'RATE SUMMARY (same midpoint domain)',capture.output(print(summary,n=Inf,width=Inf)),
  '', 'MATCHED 1,000-YEAR WINDOWS (same exact span)',capture.output(print(paired_summary,n=Inf,width=Inf)),
  '', 'SEASONAL COMPONENT SUMMARY',capture.output(print(component_summary,n=Inf,width=Inf)),
  '', 'NATIVE CENTURY CHANGE REVERSALS',capture.output(print(native_patterns,n=Inf,width=Inf)),
  '',paste('Native seasonal rows:',nrow(levels)),paste('Matched windows:',nrow(paired)),
  paste('Maximum historical bin-mean discrepancy:',max(abs(check$older_mean-check$stored_older),
    abs(check$younger_mean-check$stored_younger))),
  'Checks: regular native grid; independent endpoint norms; exact vector telescoping; triangle inequality;',
  'historical stored bin means reproduced; input fingerprints unchanged.',
  '',paste('Figure:',figure_path))
writeLines(report,file.path(out,'results.txt'))
write_csv(tibble(path=names(input_md5),md5=unname(input_md5)),file.path(out,'input_fingerprints.csv'))
stopifnot(identical(input_md5,tools::md5sum(input_paths)))
cat(paste(report,collapse='\n'),'\n')
