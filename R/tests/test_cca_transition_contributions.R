# Offline, independent numerical gate for the standalone contribution products.
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/cca_transition_contributions.R'),local=TRUE)
source(here('R/helpers/config.R'),local=TRUE)
root=here('output/cca_transition_contributions')
read_product=function(name) read_csv(file.path(root,paste0(name,'.csv')),show_col_types=FALSE)
reference=readRDS(here('output/cca_calibration_reference.rds'))
h=read_csv(here('output/cca_tracking_holocene_lake_realizations.csv'),show_col_types=FALSE)
a=read_csv(here('output/cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
species=read_product('species_realizations');climate=read_product('climate_realizations')
validation=read_product('transition_validation')
stopifnot(!any(grepl('per_century|rate',c(names(species),names(climate),names(validation)))))
provenance=jsonlite::read_json(file.path(root,'provenance.json'),simplifyVector=TRUE)
stopifnot(provenance$scaling=='sites',!provenance$hill,provenance$n_draws==100,
  provenance$contribution_unit=='CCA units',!provenance$annualized,
  provenance$bin_width_years==1000,identical(as.numeric(provenance$offsets),seq(0,900,100)))
for(group in c('input_md5','source_md5')) {
  recorded=unlist(provenance[[group]])
  stopifnot(identical(unname(recorded),unname(tools::md5sum(names(recorded)))))
}
close=function(actual,expected,tol=1e-10) {
  actual=as.vector(actual);expected=as.vector(expected)
  stopifnot(length(actual)==length(expected),identical(is.na(actual),is.na(expected)),
    all(is.finite(actual[!is.na(actual)])),all(is.finite(expected[!is.na(expected)])))
  if(any(!is.na(actual))) stopifnot(max(abs(actual-expected),na.rm=TRUE)<tol)
}
keys=function(x) ifelse(x$era=='Holocene',paste('H',x$site,x$lake,x$draw,x$offset,x$age_hi,x$age_lo,sep='|'),
  paste('A',x$site,x$plot_id,sep='|'))
context=bind_rows(h |> transmute(era='Holocene',site,lake,draw,offset,age_hi,age_lo,plot_id=NA_character_),
  a |> transmute(era='Anthropocene',site,plot_id,lake=NA_character_,draw=NA_integer_,
    offset=NA_real_,age_hi=NA_real_,age_lo=NA_real_))
endpoint=bind_rows(h,a);context_keys=keys(context)
modern_index=match(a$plot_id,reference$modern_endpoints$plot_id)
stopifnot(!anyNA(modern_index))
for(field in c('vegetation_t1_year','vegetation_t2_year','climate_t1_midyear',
  'climate_t2_midyear','vegetation_dt_years','climate_dt_years'))
  close(a[[field]],reference$modern_endpoints[[field]][modern_index])
close(a$vegetation_dt_years,a$vegetation_t2_year-a$vegetation_t1_year)
close(a$climate_dt_years,a$climate_t2_midyear-a$climate_t1_midyear)
stopifnot(!anyDuplicated(context_keys),nrow(species)==nrow(endpoint)*14L,
  nrow(climate)==nrow(endpoint)*4L,nrow(validation)==nrow(endpoint),
  !anyDuplicated(paste(keys(species),species$species)),
  !anyDuplicated(paste(keys(climate),climate$variable)),
  all(is.na(species$offset[species$era=='Anthropocene'])),
  all(is.na(climate$draw[climate$era=='Anthropocene'])),
  setequal(species$offset[species$era=='Holocene'],seq(0,900,100)),
  all(validation$species_sum_abs_error<1e-10),all(validation$climate_sum_abs_error<1e-10))
# Independent occurrence-matrix construction (not the producer helper).
occ=read_csv(here('output/occ_consolidated.csv'),show_col_types=FALSE)
taxa=reference$retained_species
manual_matrix=function(ids,period) {
  rows=occ[occ$period==period & occ$plot_id %in% ids & occ$species %in% taxa,]
  m=matrix(0,length(ids),length(taxa),dimnames=list(ids,taxa))
  for(i in seq_len(nrow(rows))) m[rows$plot_id[i],rows$species[i]]=max(m[rows$plot_id[i],rows$species[i]],rows$occurrence[i])
  stopifnot(all(rowSums(m)>0));m
}
paleo_ids=reference$comparison |> filter(era=='holocene') |> select(site,plot_id)
pm=manual_matrix(paleo_ids$plot_id,'paleo');pq=pm/rowSums(pm)
legacy=manual_matrix(a$plot_id,'past');modern=manual_matrix(a$plot_id,'present')
close(as.numeric(legacy),as.numeric(as.matrix(reference$legacy_species[a$plot_id,,drop=FALSE])))
v=reference$model$CCA$v[taxa,1:2,drop=FALSE]
close(as.numeric(read_product('species_basis')[c('CCA1','CCA2')] |> as.matrix()),as.numeric(v))
one_species=diag(length(taxa));colnames(one_species)=taxa
single=predict(reference$model,newdata=one_species,type='wa',scaling='sites',hill=FALSE)[,1:2]
close(as.numeric(single),as.numeric(v),tol=1e-12)
# Independently average each sample's weights AND vegan WA over each draw/bin.
# This tests every endpoint and catches pooling species before normalization.
sample_wa=predict(reference$model,newdata=pm,type='wa',scaling='sites',hill=FALSE)[,1:2]
qcols=paste0('q',seq_along(taxa))
sample_table=bind_cols(paleo_ids,as_tibble(pq,.name_repair='minimal') |> setNames(qcols)) |>
  mutate(sample_CCA1=sample_wa[,1],sample_CCA2=sample_wa[,2])
draws=readRDS(here('output/paleo_age_draws.rds'))
stopifnot(draws$n_draws==100,draws$seed==42)
draw_table=draws$draws |> inner_join(sample_table,by='plot_id',relationship='many-to-one')
bins=map_dfr(seq(0,900,100),function(offset) {
  draw_table |> mutate(offset=.env$offset,bin_mid=1000*floor((age-offset)/1000)+offset+500) |>
    group_by(site,lake,draw,offset,bin_mid) |> summarize(
      across(all_of(c(qcols,'sample_CCA1','sample_CCA2')),mean),n_samples=n(),.groups='drop')
})
bin_keys=paste(bins$site,bins$lake,bins$draw,bins$offset,bins$bin_mid)
initial=match(paste(h$site,h$lake,h$draw,h$offset,h$age_hi),bin_keys)
final=match(paste(h$site,h$lake,h$draw,h$offset,h$age_lo),bin_keys)
stopifnot(!anyNA(initial),!anyNA(final))
close(bins$n_samples[initial],h$n_samples);close(bins$n_samples[final],h$n_samples_2)
close(bins$sample_CCA1[initial],h$o1);close(bins$sample_CCA2[initial],h$o2)
close(bins$sample_CCA1[final],h$o1_2);close(bins$sample_CCA2[final],h$o2_2)
q1=rbind(as.matrix(bins[initial,qcols]),legacy/rowSums(legacy))
q2=rbind(as.matrix(bins[final,qcols]),modern/rowSums(modern))
group=match(keys(species),context_keys);taxon=match(species$species,taxa)
expected_first=q1[cbind(group,taxon)];expected_last=q2[cbind(group,taxon)]
close(species$weight_t1,expected_first);close(species$weight_t2,expected_last)
close(species$weight_change,expected_last-expected_first)
close(species$contribution_CCA1,(expected_last-expected_first)*v[taxon,1])
close(species$contribution_CCA2,(expected_last-expected_first)*v[taxon,2])
cat('All species weights, sample-mean bins and species vectors reconstructed independently.\n')
# Independent raw climate-source join for every lake/offset endpoint.
ponds=read_csv(here('output/chelsa_paleo_ponds.csv'),show_col_types=FALSE)
monthly=ponds |> mutate(age=1950-slice*100,value=if(PALEO_USE_BIAS_CORRECTED) value_corrected else value_raw)
native=monthly |> group_by(site,lake,age) |> summarize(
  MSpT=mean(value[variable %in% c('tasmin','tasmax') & month %in% 3:5]),
  MWT=mean(value[variable %in% c('tasmin','tasmax') & month %in% c(12,1,2)]),
  SP=sum(value[variable=='pr' & month %in% 6:8]),WP=sum(value[variable=='pr' & month %in% c(12,1,2)]),
  complete=sum(variable %in% c('tasmin','tasmax') & month %in% 3:5)==6L &
    sum(variable %in% c('tasmin','tasmax') & month %in% c(12,1,2))==6L &
    sum(variable=='pr' & month %in% 6:8)==3L &
    sum(variable=='pr' & month %in% c(12,1,2))==3L,.groups='drop')
stopifnot(all(native$complete))
climate_bins=map_dfr(seq(0,900,100),function(offset) native |>
  mutate(offset=.env$offset,bin_mid=1000*floor((age-offset)/1000)+offset+500) |>
  group_by(site,lake,offset,bin_mid) |> summarize(across(all_of(reference$climate_variables),mean),n=n(),.groups='drop') |>
  filter(n==10))
climate_keys=paste(climate_bins$site,climate_bins$lake,climate_bins$offset,climate_bins$bin_mid)
for(age in c('age_hi','age_lo')) {
  index=match(paste(h$site,h$lake,h$offset,h[[age]]),climate_keys);stopifnot(!anyNA(index))
  for(variable in reference$climate_variables) close(climate_bins[[variable]][index],
    h[[paste0(variable,if(age=='age_lo') '_2' else '')]],tol=1e-9)
}
# A separate algebraic route: raw Delta variable times coefficient * sqrt(lambda).
vars=reference$climate_variables
lc_basis=sweep(coef(reference$model)[vars,1:2,drop=FALSE],2,sqrt(reference$model$CCA$eig[1:2]),'*')
climate_group=match(keys(climate),context_keys);variable_index=match(climate$variable,vars)
delta=as.matrix(endpoint[paste0(vars,'_2')])-as.matrix(endpoint[vars])
expected_delta=delta[cbind(climate_group,variable_index)]
close(climate$value_change,expected_delta)
close(climate$contribution_CCA1,expected_delta*lc_basis[variable_index,1])
close(climate$contribution_CCA2,expected_delta*lc_basis[variable_index,2])
close(as.numeric(delta%*%lc_basis),as.numeric(as.matrix(endpoint[c('delta_predicted_CCA1','delta_predicted_CCA2')])))
# Independent trigonometric projections and direction validity, every component.
for(type in c('species','climate')) {
  data=if(type=='species') species else climate
  index=match(keys(data),context_keys)
  rx=if(type=='species') endpoint$delta_predicted_CCA1[index] else endpoint$delta_observed_CCA1[index]
  ry=if(type=='species') endpoint$delta_predicted_CCA2[index] else endpoint$delta_observed_CCA2[index]
  valid=sqrt(rx^2+ry^2)>1e-8;angle=atan2(ry,rx)
  px=data$contribution_CCA1;py=data$contribution_CCA2
  parallel=px*cos(angle)+py*sin(angle)
  parallel[!valid]=NA_real_
  stopifnot(identical(data$reference_direction_valid,valid))
  close(data$parallel_contribution,parallel)
}
cat('All lake-specific climate endpoints, one-variable LC vectors, raw displacements and signed projections independently verified.\n')
# Independently rebuild chronology distributions and hierarchical summaries.
finite_mean=function(x) if(any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_
for(type in c('species','climate')) {
  data=if(type=='species') species else climate
  component=if(type=='species') 'species' else 'variable'
  measures=c('contribution_CCA1','contribution_CCA2',
    'parallel_contribution',if(type=='species') 'weight_change')
  values=data |> filter(era=='Holocene') |>
    select(site,lake,offset,age_hi,age_lo,draw,n_samples_t1,n_samples_t2,all_of(c(component,measures))) |>
    pivot_longer(all_of(measures),names_to='measure',values_to='value')
  u=read_product(paste0(type,'_holocene_uncertainty'))
  o=read_product(paste0(type,'_holocene_offset_summary'))
  e=read_product(paste0(type,'_era_site_summary'))
  for(rule in c('all','nmin2')) {
    z=values |> mutate(eligible=if(rule=='all') TRUE else n_samples_t1>=2 & n_samples_t2>=2,
      value=if_else(eligible,value,NA_real_))
    grouping=c('site','lake','offset','age_hi','age_lo',component,'measure')
    independently=z |> group_by(across(all_of(grouping))) |> summarize(
      n_present_draws=n_distinct(draw),n_eligible_draws=sum(eligible),n_valid_draws=sum(is.finite(value)),
      mean=finite_mean(value),sd=if(sum(is.finite(value))>1) sd(value[is.finite(value)]) else NA_real_,
      median=if(any(is.finite(value))) median(value[is.finite(value)]) else NA_real_,
      q025=if(any(is.finite(value))) quantile(value[is.finite(value)],.025,names=FALSE) else NA_real_,
      q975=if(any(is.finite(value))) quantile(value[is.finite(value)],.975,names=FALSE) else NA_real_,.groups='drop')
    make_key=function(x,fields) do.call(paste,c(x[fields],sep='|'))
    actual=u |> filter(sampling_rule==rule)
    index=match(make_key(independently,grouping),make_key(actual,grouping))
    stopifnot(!anyNA(index),nrow(independently)==nrow(actual),!anyDuplicated(index))
    for(field in c('mean','sd','median','q025','q975','n_present_draws','n_eligible_draws','n_valid_draws'))
      close(actual[[field]][index],independently[[field]])
    close(actual$n_missing_draws,100-actual$n_present_draws)
    close(actual$n_undefined_draws,actual$n_eligible_draws-actual$n_valid_draws)
    trajectory=z |> group_by(site,lake,offset,draw,across(all_of(c(component,'measure')))) |>
      summarize(n_valid=sum(is.finite(value)),value=finite_mean(value),.groups='drop')
    offsets=trajectory |> group_by(site,lake,offset,across(all_of(c(component,'measure')))) |>
      summarize(median=if(any(is.finite(value))) median(value[is.finite(value)]) else NA_real_,
        n_valid_draws=sum(is.finite(value)),min_valid_transitions=min(n_valid),max_valid_transitions=max(n_valid),.groups='drop')
    grouping=c('site','lake','offset',component,'measure');actual=o |> filter(sampling_rule==rule)
    index=match(make_key(offsets,grouping),make_key(actual,grouping));stopifnot(!anyNA(index))
    for(field in c('median','n_valid_draws','min_valid_transitions','max_valid_transitions')) close(actual[[field]][index],offsets[[field]])
    park=trajectory |> group_by(site,offset,draw,across(all_of(c(component,'measure')))) |>
      summarize(n_valid_lakes=sum(is.finite(value)),value=finite_mean(value),.groups='drop') |>
      group_by(site,offset,across(all_of(c(component,'measure')))) |>
      summarize(estimate=if(any(is.finite(value))) median(value[is.finite(value)]) else NA_real_,
        min_valid_lakes=min(n_valid_lakes),max_valid_lakes=max(n_valid_lakes),.groups='drop')
    grouping=c('site','offset',component,'measure');actual=e |> filter(era=='Holocene',sampling_rule==rule)
    index=match(make_key(park,grouping),make_key(actual,grouping));stopifnot(!anyNA(index))
    for(field in c('estimate','min_valid_lakes','max_valid_lakes')) close(actual[[field]][index],park[[field]])
  }
  modern=data |> filter(era=='Anthropocene') |> select(site,plot_id,all_of(c(component,measures))) |>
    pivot_longer(all_of(measures),names_to='measure',values_to='value') |>
    group_by(site,across(all_of(c(component,'measure')))) |>
    summarize(estimate=finite_mean(value),n_valid_plots=sum(is.finite(value)),.groups='drop')
  grouping=c('site',component,'measure');actual=e |> filter(era=='Anthropocene')
  index=match(make_key(modern,grouping),make_key(actual,grouping));stopifnot(!anyNA(index))
  close(actual$estimate[index],modern$estimate);close(actual$n_valid_plots[index],modern$n_valid_plots)
  # Independently reconstruct every boxplot observation. Each Holocene record
  # is a transition median, not an individual draw or a park trajectory mean.
  box=read_product(paste0(type,'_boxplot_values'))
  projection_measures='parallel_contribution'
  expected_h=values |> filter(measure %in% projection_measures) |>
    group_by(site,lake,offset,age_hi,age_lo,across(all_of(c(component,'measure')))) |>
    summarize(n_present_draws=n_distinct(draw),n_valid_draws=sum(is.finite(value)),
      value=if(any(is.finite(value))) median(value[is.finite(value)]) else NA_real_,.groups='drop')
  grouping=c('site','lake','offset','age_hi','age_lo',component,'measure')
  actual=box |> filter(era=='Holocene')
  index=match(make_key(expected_h,grouping),make_key(actual,grouping))
  stopifnot(!anyNA(index),!anyDuplicated(index),nrow(expected_h)==nrow(actual),
    all(actual$n_expected_draws==100),all(is.na(actual$plot_id)))
  for(field in c('value','n_present_draws','n_valid_draws')) close(actual[[field]][index],expected_h[[field]])
  close(actual$n_undefined_draws,actual$n_present_draws-actual$n_valid_draws)
  expected_a=data |> filter(era=='Anthropocene') |>
    select(site,plot_id,all_of(c(component,projection_measures))) |>
    pivot_longer(all_of(projection_measures),names_to='measure',values_to='value')
  grouping=c('site','plot_id',component,'measure');actual=box |> filter(era=='Anthropocene')
  index=match(make_key(expected_a,grouping),make_key(actual,grouping))
  stopifnot(!anyNA(index),!anyDuplicated(index),nrow(expected_a)==nrow(actual),
    all(is.na(actual$offset)),all(is.na(actual$n_present_draws)))
  close(actual$value[index],expected_a$value)
  # A single figure contains all offset-specific transition points and each
  # modern plot once. No second median collapses the offset-specific values.
  plotted=contribution_boxplot(box,type,reference)$data
  plotted_h=plotted |> filter(era=='Holocene')
  plotted_a=plotted |> filter(era=='Anthropocene')
  h_keys=c('site','lake','offset','age_hi','age_lo',component,'measure')
  expected_finite_h=expected_h |> filter(is.finite(value))
  index=match(make_key(expected_finite_h,h_keys),make_key(plotted_h,h_keys))
  stopifnot(!anyNA(index),!anyDuplicated(index),nrow(plotted_h)==nrow(expected_finite_h),
    setequal(plotted_h$offset,seq(0,900,100)),
    nrow(plotted_a)==sum(is.finite(expected_a$value)),
    !anyDuplicated(make_key(plotted_a,grouping)))
  close(plotted_h$value[index],expected_finite_h$value)
  expected_finite_a=expected_a |> filter(is.finite(value))
  index=match(make_key(expected_finite_a,grouping),make_key(plotted_a,grouping))
  stopifnot(!anyNA(index))
  close(plotted_a$value[index],expected_finite_a$value)
}
cat('Every Bacon distribution, draw-support count, per-offset summary and era/park descriptive estimate reconstructed from detailed records.\n')
# Geometry edge cases: off-reference movement, opposite movement, zero component, stationary
# and tiny reference. No undefined reference is silently set to zero.
p=contribution_project(c(2,0,-2,0,1,1),c(0,3,0,0,1,1),
  c(1,1,1,1,0,1e-9),rep(0,6))
close(p$parallel,c(2,0,-2,0,NA_real_,NA_real_))
stopifnot(identical(p$valid,c(TRUE,TRUE,TRUE,TRUE,FALSE,FALSE)))
first=matrix(c(1,0),nrow=1,dimnames=list(NULL,c('a','b')))
last=matrix(c(0,1),nrow=1,dimnames=list(NULL,c('a','b')))
positions=matrix(c(2,0,0,3),nrow=2,byrow=TRUE,dimnames=list(c('a','b'),c('CCA1','CCA2')))
toy_context=tibble(era='Anthropocene',site='MORA',plot_id='toy',vegetation_dt_years=50,climate_dt_years=20)
toy_endpoint=tibble(delta_predicted_CCA1=1,delta_predicted_CCA2=0)
toy=contribution_species(toy_context,first,last,positions,toy_endpoint)
close(toy$parallel_contribution,c(-2,0))
# Elapsed times are audit context only, even when vegetation/climate times differ.
changed_context=toy_context |> mutate(vegetation_dt_years=150,climate_dt_years=1000)
changed=contribution_species(changed_context,first,last,positions,toy_endpoint)
for(field in contribution_measure_names('species')) close(toy[[field]],changed[[field]])
climate_context=contribution_context(a[1:2,],'Anthropocene')
base_climate=contribution_climate(climate_context,a[1:2,],reference)
changed_context=climate_context |> mutate(vegetation_dt_years=1000,climate_dt_years=10)
changed=contribution_climate(changed_context,a[1:2,],reference)
for(field in contribution_measure_names('climate')) close(base_climate[[field]],changed[[field]])
toy_endpoint$delta_predicted_CCA1=0
toy=contribution_species(toy_context,first,last,positions,toy_endpoint)
stopifnot(all(is.na(toy$parallel_contribution)))
close(toy$contribution_CCA1,c(-2,0))
# Sparse draws, response-specific undefined values, empty nmin2 groups and
# counts computed BEFORE averaging a trajectory.
toy=tibble(era='Holocene',site='MORA',lake='toy',plot_id=NA_character_,draw=c(1,7,1,7),offset=0,
  age_hi=c(1500,1500,2500,2500),age_lo=c(500,500,1500,1500),species='a',
  n_samples_t1=c(1,1,2,2),n_samples_t2=c(1,1,2,2),
  contribution_CCA1=c(1,2,4,6),contribution_CCA2=0,
  parallel_contribution=c(NA_real_,2,4,6),weight_change=0)
toy_summary=contribution_summaries(toy,'species')
empty=toy_summary$uncertainty |> filter(age_hi==1500,sampling_rule=='nmin2')
stopifnot(all(empty$n_present_draws==2L),all(empty$n_missing_draws==98L),
  all(empty$n_eligible_draws==0L),all(empty$n_valid_draws==0L),all(empty$n_undefined_draws==0L),
  all(is.na(empty$median)),all(is.na(empty$q025)),all(is.na(empty$q975)))
sparse=toy_summary$uncertainty |> filter(age_hi==1500,sampling_rule=='all',measure=='parallel_contribution')
stopifnot(sparse$n_valid_draws==1L,sparse$n_undefined_draws==1L,sparse$median==2)
trajectory=toy_summary$offset_summary |> filter(sampling_rule=='all',measure=='parallel_contribution')
stopifnot(trajectory$min_valid_transitions==1L,trajectory$max_valid_transitions==2L,trajectory$median==4)
cat('Boxplot inputs reconstructed independently; elapsed-time invariance verified for both contribution types.\n')
cat('Edge cases passed: scaling, signs, unequal elapsed times, stationary directions, zero components, sparse draws and empty sensitivity groups.\n')
cat('Standalone fixed-CCA contribution acceptance checks passed.\n')
