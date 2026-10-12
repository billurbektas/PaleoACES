# Restore original macrofossil sample IDs; ages never determine sample identity.
suppressPackageStartupMessages({library(here);library(tidyverse)})
source(here('R/helpers/century_tracking.R'),local=TRUE)
bundle=century_prepare()
original=reconstruction_read_original_samples()
metadata=bundle$samples |> transmute(site,lake,plot_id=sample_id,sample_id,
  source_sample_id,depth=depth_cm,median_age=median_age_cal_bp,n_depths=1L,eligible,exclusion)
occ=original$occurrence |> left_join(metadata |> select(site,lake,sample_id),
  by='sample_id',relationship='many-to-one') |>
  transmute(period='paleo',plot_id=sample_id,species,occurrence,site,era='holocene',lake)
stopifnot(!anyDuplicated(metadata$plot_id),!anyDuplicated(occ[c('plot_id','species')]))
write_csv(occ,here('output/paleo_occ.csv'))
write_csv(metadata,here('output/paleo_sample_depths.csv'))
# Fire preparation keeps its source-category measurements and detector ages.
source(here('R/helpers/paleo_ages.R'),local=TRUE)
long=readxl::read_excel(here('data/PALEO/DunwiddieMacrofossils.xlsx'),sheet='MacrofossilData') |>
  transmute(site=Location,depth=Depth,Percentage,species=case_when(
    Species %in% c('Needle Concentration (per CC)','Needle Concentration (Per CC)')~'needle_concentration',
    Species=='Charcoal Fragments'~'charcoal_fragments',Species=='Charred Needles'~'charred_needles',
    TRUE~Species)) |> left_join(age_depth,by=c('site','depth'),relationship='many-to-one')
write_csv(long,here('output/paleo_macrofossil_long.csv'))
cat('Original macrofossil samples:',nrow(metadata),'; fixed-CCA eligible:',sum(metadata$eligible),'\n')
