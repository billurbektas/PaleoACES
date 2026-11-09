# 06 Paleo samples: original macrofossil sample identities, presences and the
# median Bacon age of each sample. Ages never determine sample identity.
# Uses only the stored chronologies (step 05); CCA eligibility is decided in step 10.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse)})
source(here('R/helpers/century_tracking.R'),local=TRUE)
original=reconstruction_read_original_samples()
samples=original$samples
# The seeded 1,000-draw cache is shared with the tracking reconstruction (step 12).
draws=reconstruction_original_age_draws(samples,out('age_draws.rds'),
  HOLOCENE_RECONSTRUCTION_DRAWS,HOLOCENE_RECONSTRUCTION_SEED)
samples$median_age_cal_bp=NA_real_
for(core in unique(samples$lake)) {
  use=which(samples$lake==core)
  samples$median_age_cal_bp[use]=apply(century_posterior_ages(draws,core,samples$depth_cm[use]),2,median)
}
metadata=samples |> transmute(site,lake,plot_id=sample_id,sample_id,
  source_sample_id,depth=depth_cm,median_age=median_age_cal_bp,n_depths=1L)
occ=original$occurrence |> left_join(metadata |> select(site,lake,sample_id),
  by='sample_id',relationship='many-to-one') |>
  transmute(period='paleo',plot_id=sample_id,species,occurrence,site,era='holocene',lake)
stopifnot(!anyDuplicated(metadata$plot_id),!anyDuplicated(occ[c('plot_id','species')]))
write_csv(occ,out('paleo_occ.csv'))
write_csv(metadata,out('paleo_sample_depths.csv'))
# Fire preparation keeps its source-category measurements and detector ages.
source(here('R/helpers/paleo_ages.R'),local=TRUE)
long=readxl::read_excel(here('data/PALEO/DunwiddieMacrofossils.xlsx'),sheet='MacrofossilData') |>
  transmute(site=Location,depth=Depth,Percentage,species=case_when(
    Species %in% c('Needle Concentration (per CC)','Needle Concentration (Per CC)')~'needle_concentration',
    Species=='Charcoal Fragments'~'charcoal_fragments',Species=='Charred Needles'~'charred_needles',
    TRUE~Species)) |> left_join(age_depth,by=c('site','depth'),relationship='many-to-one')
write_csv(long,out('paleo_macrofossil_long.csv'))
cat('Original macrofossil samples:',nrow(metadata),'\n')
