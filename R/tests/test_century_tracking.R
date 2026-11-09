# Independent native-century reconstruction, geometry and contribution checks.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/century_tracking.R'),local=TRUE)
source(here('R/helpers/cca_transition_contributions.R'),local=TRUE)
close=function(x,y,tolerance=1e-9) {
  stopifnot(identical(unname(is.na(x)),unname(is.na(y))),length(x)==length(y))
  valid=is.finite(x)&is.finite(y)
  stopifnot(!any(abs(x[valid]-y[valid])>tolerance*pmax(1,abs(y[valid]))))
}
b=century_prepare();primary=readRDS(out('chronology_reconstruction/primary.rds'))
s=b$samples
raw_mora=readxl::read_excel(here('data/PALEO/DunwiddieMacrofossils.xlsx'),sheet='MacrofossilData')
stopifnot(nrow(distinct(raw_mora,Location,Depth))==sum(s$site=='MORA'),
  !anyDuplicated(s$sample_id),all(table(b$cache$draws$sample_id)==1000L))
for(core in unique(s$lake)) {
  meta=b$cache$depth_evaluation[b$cache$depth_evaluation$lake==core,]
  rows=b$cache$posterior_rows[b$cache$posterior_rows$lake==core,]
  raw=as.matrix(read.table(here(unique(rows$source))));raw=raw[,-ncol(raw),drop=FALSE]
  stopifnot(!anyDuplicated(rows$posterior_row),identical(rows$draw,1:1000))
  for(i in seq_len(nrow(meta))) {
    v=meta[i,];k=v$section_index
    before=if(k==1L) rep(0,nrow(raw)) else rowSums(raw[,2:k,drop=FALSE])
    ages=raw[,1]+v$thickness_cm*before+
      (v$slump_adjusted_depth_cm-v$section_start_cm)*raw[,k+1]
    close(median(ages),s$median_age_cal_bp[match(v$sample_id,s$sample_id)])
    close(ages[rows$posterior_row],b$cache$draws$age_cal_bp[b$cache$draws$sample_id==v$sample_id])
  }
}
use=s[s$eligible,];use$century=floor(use$median_age_cal_bp/100)*100+50
pos=primary$positions
for(i in seq_len(nrow(pos))) {
  ids=which(use$lake==pos$lake[i]&use$century==pos$century_cal_bp[i])
  stopifnot(length(ids)==pos$n_samples[i])
  close(c(pos$o1[i],pos$o2[i]),colMeans(as.matrix(use[ids,c('observed_CCA1','observed_CCA2')])))
}
for(core in unique(pos$lake)) {
  dates=sort(pos$century_cal_bp[pos$lake==core],decreasing=TRUE)
  x=primary$calculations[primary$calculations$lake==core,]
  close(x$age_hi,head(dates,-1));close(x$age_lo,tail(dates,-1))
  stopifnot(identical(x$transition_index,seq_len(nrow(x))))
}
h=primary$calculations
for(x in list(h,read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE))) {
  ox=x$o1_2-x$o1;oy=x$o2_2-x$o2;px=x$p1_2-x$p1;py=x$p2_2-x$p2
  no=sqrt(ox^2+oy^2);np=sqrt(px^2+py^2)
  l1=sqrt((x$o1-x$p1)^2+(x$o2-x$p2)^2);l2=sqrt((x$o1_2-x$p1_2)^2+(x$o2_2-x$p2_2)^2)
  angle=atan2(abs(ox*py-oy*px),ox*px+oy*py)*180/pi;angle[no<=1e-8|np<=1e-8]=NA_real_
  pace=sqrt((x$o1+np*ox/no-x$p1_2)^2+(x$o2+np*oy/no-x$p2_2)^2);pace[no<=1e-8]=NA_real_
  direction=sqrt((x$o1+no*px/np-x$p1_2)^2+(x$o2+no*py/np-x$p2_2)^2);direction[np<=1e-8]=NA_real_
  close(x$lag_rate_per_century,(l2-l1)*100/x$climate_dt_years)
  close(x$observed_turnover_rate,no*100/x$vegetation_dt_years)
  close(x$magnitude_tracking_ratio,ifelse(np>1e-8,no/np,NA_real_))
  close(x$rate_tracking_ratio,ifelse(np>1e-8,no/np*x$climate_dt_years/x$vegetation_dt_years,NA_real_))
  close(x$angle_degrees,angle)
  close(x$pace_effect_on_lag_per_century,(l2-pace)*100/x$climate_dt_years)
  close(x$direction_effect_on_lag_per_century,(l2-direction)*100/x$climate_dt_years)
  z=sapply(b$reference$climate_variables,function(v)
    (x[[paste0(v,'_2')]]-x[[v]])/b$reference$climate_scaling$sd[match(v,b$reference$climate_scaling$variable)])
  close(x$standardized_climate_change_rate,sqrt(rowSums(z^2))*100/x$climate_dt_years)
}
for(draw in c(NA_integer_,1L,257L,800L,1000L)) {
  x=century_reconstruct(b,draw)
  species=century_species_contributions(x,b)
  climate=century_climate_contributions(century_contribution_context(x$calculations,'Holocene'),x$calculations,b$reference)
  lc_coef=sweep(coef(b$reference$model)[b$reference$climate_variables,1:2,drop=FALSE],2,
    sqrt(b$reference$model$CCA$eig[1:2]),'*')
  for(v in b$reference$climate_variables) {
    rows=climate[climate$variable==v,]
    expected=outer(x$calculations[[paste0(v,'_2')]]-x$calculations[[v]],lc_coef[v,])
    close(as.vector(as.matrix(rows[c('contribution_CCA1','contribution_CCA2')])),as.vector(expected))
  }
  sum_vectors=rowsum(as.matrix(species[c('contribution_CCA1','contribution_CCA2')]),
    rep(seq_len(nrow(x$calculations)),each=14),reorder=FALSE)
  close(as.vector(sum_vectors),as.vector(as.matrix(x$calculations[c('delta_observed_CCA1','delta_observed_CCA2')])))
  close(species$contribution_rate,species$parallel_contribution*100/species$vegetation_dt_years)
  for(i in seq_len(nrow(x$fire$core))) {
    core=x$fire$core[i,];events=x$fire$events
    count=if(core$fully_covered) sum(events$site==core$site&events$lake==core$fire_core&
      events$age_cal_yr_BP>=core$age_lo&events$age_cal_yr_BP<core$age_hi) else NA_integer_
    close(core$accepted_event_count,count);close(core$frequency_per_century,count*100/core$duration_years)
  }
}
# Boundary cells, sparse sample support and unequal-duration transitions.
grid=tibble(site='MORA',lake='X',century_cal_bp=c(50,150,250,350),lower_cal_bp=c(0,100,200,300),upper_cal_bp=c(100,200,300,400))
samples=tibble(sample_id=c('a','b','c'),eligible=TRUE,observed_CCA1=c(0,2,4),observed_CCA2=0)
ages=tibble(site='MORA',lake='X',sample_id=c('a','b','c'),draw=1L,age_cal_bp=c(0,100,400))
assigned=reconstruction_century_assignments(ages,samples,grid)
close(assigned$century_cal_bp,c(50,150,NA_real_))
stopifnot(sum(s$eligible)==nrow(use),any(h$vegetation_dt_years>100),
  all(is.na(h$fire_activity[!h$fire_coverage_valid])))
cat('Independent original ages, whole draws, native centroids, geometry, climate, fire and species checks passed.\n')
