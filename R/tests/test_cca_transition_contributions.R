# Independent contribution gate (PLAN.md Step 6): original sample weights, CCA
# scaling, every endpoint, vector and projection on the lake-periods and plot
# pairs, both measures, rate conversion and undefined directions.
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/cca_transition_contributions.R'),local=TRUE)
source(here('R/helpers/config.R'),local=TRUE)
read_output=function(name) read_csv(out(paste0(name,'.csv')),show_col_types=FALSE)
reference=readRDS(out('cca_calibration_reference.rds'))
h=read_output('cca_tracking_lake_period_calculations')
source(here('R/helpers/lake_periods.R'),local=TRUE)
a=read_output('cca_tracking_anthropocene_plot_calculations') |> lake_period_responses()
species=read_output('cca_transition_contributions/species_contributions')
climate=read_output('cca_transition_contributions/climate_contributions')
assigned=read_output('cca_tracking_holocene_sample_assignments')
occ=read_output('occ_consolidated');taxa=reference$retained_species
close=function(x,y,tol=1e-10) {
 x=as.vector(x);y=as.vector(y)
 stopifnot(length(x)==length(y),identical(is.na(x),is.na(y)))
 finite=!is.na(x)
 stopifnot(all(is.finite(x[finite])),all(is.finite(y[finite])),
   all(abs(x[finite]-y[finite])<=tol*pmax(1,abs(y[finite]))))
}
key=function(x) ifelse(x$era=='Holocene',paste('H',x$site,x$lake,x$age_start,x$age_end,sep='|'),
 paste('A',x$site,x$plot_id,sep='|'))
endpoint=bind_rows(h |> mutate(era='Holocene',plot_id=NA_character_),
 a |> mutate(era='Anthropocene',lake=NA_character_))
stopifnot(!anyDuplicated(key(endpoint)),nrow(a)==607L,
 nrow(species)==nrow(endpoint)*length(taxa),nrow(climate)==nrow(endpoint)*length(CCA_VARIABLES),
 !anyDuplicated(paste(key(species),species$species)),
 !anyDuplicated(paste(key(climate),climate$variable)),
 !any(c('offset','perpendicular_contribution') %in% c(names(species),names(climate))),
 !'contrib_climate' %in% names(climate))
# Build binary occurrence matrices independently of the contribution producer.
manual=function(ids,period) {
 rows=occ[occ$period==period & occ$plot_id %in% ids & occ$species %in% taxa,]
 m=matrix(0,length(ids),length(taxa),dimnames=list(ids,taxa))
 for(i in seq_len(nrow(rows))) m[rows$plot_id[i],rows$species[i]]=max(m[rows$plot_id[i],rows$species[i]],rows$occurrence[i])
 stopifnot(all(rowSums(m)>0));m
}
assigned=assigned[is.finite(assigned$century_cal_bp),]
ids=unique(assigned$sample_id);m=manual(ids,'paleo');q=m/rowSums(m)
v=reference$model$CCA$v[taxa,1:2,drop=FALSE]
wa=predict(reference$model,newdata=m,type='wa',scaling='sites',hill=FALSE)[,1:2,drop=FALSE]
close(assigned$observed_CCA1,wa[assigned$sample_id,1]);close(assigned$observed_CCA2,wa[assigned$sample_id,2])
# Average normalized sample weights, rather than normalizing an averaged assemblage.
endpoint_weights=function(lake,age) {
 sample_ids=assigned$sample_id[assigned$lake==lake & assigned$century_cal_bp==age]
 stopifnot(length(sample_ids)>0);colMeans(q[sample_ids,,drop=FALSE])
}
first=t(vapply(seq_len(nrow(h)),function(i) endpoint_weights(h$lake[i],h$age_start[i]),numeric(length(taxa))))
last=t(vapply(seq_len(nrow(h)),function(i) endpoint_weights(h$lake[i],h$age_end[i]),numeric(length(taxa))))
legacy=manual(a$plot_id,'past');modern=manual(a$plot_id,'present')
close(legacy,as.matrix(reference$legacy_species[a$plot_id,taxa,drop=FALSE]))
first=rbind(first,legacy/rowSums(legacy));last=rbind(last,modern/rowSums(modern))
group=match(key(species),key(endpoint));taxon=match(species$species,taxa)
stopifnot(!anyNA(group),!anyNA(taxon))
initial=first[cbind(group,taxon)];final=last[cbind(group,taxon)]
close(species$weight_t1,initial);close(species$weight_t2,final)
close(species$weight_change,final-initial)
close(species$contribution_CCA1,(final-initial)*v[taxon,1])
close(species$contribution_CCA2,(final-initial)*v[taxon,2])
close((last-first)%*%v,as.matrix(endpoint[c('delta_observed_CCA1','delta_observed_CCA2')]))
# A separate LC route: physical variable change times regression coefficients
# and the CCA eigenvalue scaling, without calling predict.cca.
vars=reference$climate_variables
basis=sweep(coef(reference$model)[vars,1:2,drop=FALSE],2,sqrt(reference$model$CCA$eig[1:2]),'*')
group=match(key(climate),key(endpoint));variable=match(climate$variable,vars)
stopifnot(!anyNA(group),!anyNA(variable))
delta=as.matrix(endpoint[paste0(vars,'_2')])-as.matrix(endpoint[vars])
change=delta[cbind(group,variable)]
close(climate$value_change,change)
close(climate$contribution_CCA1,change*basis[variable,1])
close(climate$contribution_CCA2,change*basis[variable,2])
close(delta%*%basis,as.matrix(endpoint[c('delta_predicted_CCA1','delta_predicted_CCA2')]))
# Trigonometric projection is independent of the producer's dot-product code.
for(type in c('species','climate')) {
 x=if(type=='species') species else climate
 index=match(key(x),key(endpoint));prefix=if(type=='species') 'predicted' else 'observed'
 rx=endpoint[[paste0('delta_',prefix,'_CCA1')]][index]
 ry=endpoint[[paste0('delta_',prefix,'_CCA2')]][index]
 valid=sqrt(rx^2+ry^2)>CCA_CONTRIBUTION_EPSILON
 projected=x$contribution_CCA1*cos(atan2(ry,rx))+x$contribution_CCA2*sin(atan2(ry,rx))
 projected[!valid]=NA_real_
 stopifnot(identical(x$reference_direction_valid,valid))
 close(x$parallel_contribution,projected)
 if(type=='species') {
  defined=endpoint$direction_defined[index]
  close(x$contrib_climate,ifelse(defined,projected*100/endpoint$vegetation_dt_years[index],NA_real_))
  # The gap measure: projection on LC_t1 - WA_t1.
  gx=(endpoint$p1-endpoint$o1)[index];gy=(endpoint$p2-endpoint$o2)[index]
  gap=x$contribution_CCA1*cos(atan2(gy,gx))+x$contribution_CCA2*sin(atan2(gy,gx))
  gap[sqrt(gx^2+gy^2)<=CCA_CONTRIBUTION_EPSILON]=NA_real_
  close(x$contrib_gap,ifelse(defined,gap*100/endpoint$vegetation_dt_years[index],NA_real_))
 }
}
# Zero components remain zero; undefined reference directions remain NA.
p=contribution_project(c(2,0,-2,0,1,1),c(0,3,0,0,1,1),c(1,1,1,1,0,1e-9),rep(0,6))
close(p$parallel,c(2,0,-2,0,NA_real_,NA_real_))
stopifnot(identical(p$valid,c(TRUE,TRUE,TRUE,TRUE,FALSE,FALSE)))
context=century_contribution_context(a[1:2,],'Anthropocene')
x=contribution_climate(context,a[1:2,],reference)
y=contribution_climate(context |> mutate(vegetation_dt_years=1000,climate_dt_years=10),a[1:2,],reference)
for(field in c('contribution_CCA1','contribution_CCA2','parallel_contribution')) close(x[[field]],y[[field]])
cat('All primary species weights, vector conservation/scaling, climate vectors, projections and rate units independently verified.\n')
