# STANDALONE: fixed-CCA species and climate-variable displacement contributions.
# Rscript R/stages/11_cca_transition_contributions.R
# Not called by R/workflow.R. Reads existing reference, tracking and chronology;
# writes only its own output/cca_transition_contributions/ and figure directory.
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/cca_transition_contributions.R'),local=TRUE)
N_DRAWS=100;DRAW_SEED=42
source(here('R/helpers/paleo_runs.R'),local=TRUE)
paths=here('output',c('cca_calibration_reference.rds','occ_consolidated.csv',
  'cca_tracking_holocene_lake_realizations.csv','cca_tracking_anthropocene_plot_calculations.csv',
  'paleo_age_draws.rds'))
if(!all(file.exists(paths))) stop('Missing fixed CCA, canonical tracking or chronology inputs')
input_md5=tools::md5sum(paths)
reference=readRDS(paths[1])
source_audit=tibble(path=names(reference$provenance$model_source_md5),
  recorded_md5=unname(reference$provenance$model_source_md5),
  current_md5=unname(tools::md5sum(names(reference$provenance$model_source_md5)))) |>
  mutate(matches=recorded_md5==current_md5,
    required_match=basename(path)!='tracking_metrics.R')
# The tracking helper supplied calibration SDs to the bundle, not the CCA fit.
# Its later metric-only edits do not invalidate a frozen fit; verify its stored
# scaling numerically and retain the checksum difference explicitly in the audit.
if(any(tools::md5sum(names(reference$provenance$input_md5))!=reference$provenance$input_md5) ||
   any(source_audit$required_match & !source_audit$matches))
  stop('Frozen CCA reference provenance does not match current inputs/sources')
for(variable in reference$climate_variables) {
  recorded=reference$climate_scaling |> filter(.data$variable==.env$variable)
  contribution_close(c(recorded$mean,recorded$sd,recorded$n_calibration),
    c(mean(reference$legacy_climate[[variable]]),sd(reference$legacy_climate[[variable]]),607),
    paste('Frozen legacy climate scaling:',variable))
}
if(as.character(packageVersion('vegan'))!=reference$provenance$vegan_version)
  stop('Installed vegan version differs from the fixed CCA reference')
basis=contribution_reference(reference)
occurrence=read_csv(paths[2],show_col_types=FALSE)
holocene=read_csv(paths[3],show_col_types=FALSE)
modern=read_csv(paths[4],show_col_types=FALSE)
if(any(holocene$bin_width_years!=1000L) || any(holocene$climate_dt_years!=1000) ||
   any(holocene$vegetation_dt_years!=1000) || any(!holocene$draw %in% 1:N_DRAWS) ||
   any(holocene$n_climate_slices!=10L | holocene$n_climate_slices_2!=10L) ||
   any(!holocene$climate_complete) ||
   !setequal(holocene$offset,seq(0,900,100)) || nrow(modern)!=607L ||
   anyDuplicated(modern[c('site','plot_id')])) stop('Unexpected primary tracking input configuration')
draws=paleo_age_draws(allow_rebuild=FALSE)
modern_ids=modern |> select(site,plot_id)
paleo_ids=reference$comparison |> filter(era=='holocene') |> select(site,plot_id)
legacy=contribution_species_matrix(occurrence,modern_ids,'past',reference$retained_species)
present=contribution_species_matrix(occurrence,modern_ids,'present',reference$retained_species)
paleo=contribution_species_matrix(occurrence,paleo_ids,'paleo',reference$retained_species)
contribution_close(legacy,as.matrix(reference$legacy_species[modern_ids$plot_id,,drop=FALSE]),
  'Original matched calibration occurrences')
wa=function(x) stats::predict(reference$model,newdata=x,type='wa',scaling='sites',hill=FALSE)[,1:2,drop=FALSE]
sample_weights=contribution_weights(paleo)
sample_wa=wa(paleo)
sample_target=as.matrix(reference$comparison[match(paleo_ids$plot_id,reference$comparison$plot_id),
  c('projected_CCA1','projected_CCA2')])
sample_error=contribution_close(sample_wa,sample_target,'All original Holocene sample WA positions')
weight_error=contribution_close(sweep(sample_weights,2,reference$model$colsum,'-')%*%basis$positions,
  sample_wa,'Sample-level relative-weight WA reconstruction')
contribution_close(wa(legacy),as.matrix(modern[c('o1','o2')]),'Original modern initial WA')
contribution_close(wa(present),as.matrix(modern[c('o1_2','o2_2')]),'Original modern final WA')
bin_weights=contribution_bin_weights(draws,paleo_ids,sample_weights,holocene)
bin_first=sweep(bin_weights$first%*%basis$positions,2,basis$centroid,'-')
bin_last=sweep(bin_weights$last%*%basis$positions,2,basis$centroid,'-')
bin_first_error=contribution_close(bin_first,as.matrix(holocene[c('o1','o2')]),
  'Holocene mean of sample-level initial WA positions')
bin_last_error=contribution_close(bin_last,as.matrix(holocene[c('o1_2','o2_2')]),
  'Holocene mean of sample-level final WA positions')
first=rbind(bin_weights$first,contribution_weights(legacy))
last=rbind(bin_weights$last,contribution_weights(present))
context=bind_rows(contribution_context(holocene,'Holocene'),contribution_context(modern,'Anthropocene'))
fields=c('o1','o2','o1_2','o2_2','p1','p2','p1_2','p2_2',
  reference$climate_variables,paste0(reference$climate_variables,'_2'),
  'delta_observed_CCA1','delta_observed_CCA2','delta_predicted_CCA1','delta_predicted_CCA2')
endpoints=bind_rows(holocene |> select(all_of(fields)),modern |> select(all_of(fields)))
contribution_close(as.matrix(endpoints[c('o1_2','o2_2')])-as.matrix(endpoints[c('o1','o2')]),
  as.matrix(endpoints[c('delta_observed_CCA1','delta_observed_CCA2')]),'Stored Delta WA identity')
contribution_close(as.matrix(endpoints[c('p1_2','p2_2')])-as.matrix(endpoints[c('p1','p2')]),
  as.matrix(endpoints[c('delta_predicted_CCA1','delta_predicted_CCA2')]),'Stored Delta LC identity')
cat('Calculating species vectors for',nrow(context),'actual transitions, before any aggregation.\n')
species=contribution_species(context,first,last,basis$positions,endpoints)
cat('Calculating four one-variable LC perturbations per transition.\n')
climate=contribution_climate(context,endpoints,reference)
validation=contribution_validate(species,climate,context,endpoints,basis$positions,first,last)
# Independent LC reconstruction via the fitted raw-variable coefficients.
# This is not a biplot-vector attribution or an SD-standardized predictor norm.
vars=reference$climate_variables
climate_change=as.matrix(endpoints[paste0(vars,'_2')])-as.matrix(endpoints[vars])
lc_coefficients=sweep(coef(reference$model)[vars,1:2,drop=FALSE],2,sqrt(reference$model$CCA$eig[1:2]),'*')
lc_error=contribution_close(climate_change%*%lc_coefficients,
  as.matrix(endpoints[c('delta_predicted_CCA1','delta_predicted_CCA2')]),
  'Independent fitted-coefficient Delta LC reconstruction')
for(variable in vars) {
  rows=climate |> filter(.data$variable==.env$variable)
  expected=outer(climate_change[,match(variable,vars)],lc_coefficients[variable,])
  contribution_close(as.matrix(rows[c('contribution_CCA1','contribution_CCA2')]),expected,
    paste('Independent one-variable contribution:',variable))
}
cat('Summarizing whole-draw uncertainty separately within each offset.\n')
species_summary=contribution_summaries(species,'species',N_DRAWS)
climate_summary=contribution_summaries(climate,'climate',N_DRAWS)
for(summary in list(species_summary$uncertainty,climate_summary$uncertainty)) {
  if(any(summary$n_valid_draws>summary$n_eligible_draws) ||
     any(summary$n_eligible_draws>summary$n_present_draws) ||
     any(summary$n_present_draws>N_DRAWS) ||
     any(summary$n_undefined_draws!=summary$n_eligible_draws-summary$n_valid_draws))
    stop('Incoherent chronology/response support')
}
if(!identical(input_md5,tools::md5sum(paths))) stop('An input changed during the standalone calculation')
out=here('output/cca_transition_contributions')
plot_dir=here('plot/test_figures/cca_transition_contributions')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
dir.create(plot_dir,recursive=TRUE,showWarnings=FALSE)
tables=list(species_realizations=species,climate_realizations=climate,
  species_holocene_uncertainty=species_summary$uncertainty,
  climate_holocene_uncertainty=climate_summary$uncertainty,
  species_holocene_offset_summary=species_summary$offset_summary,
  climate_holocene_offset_summary=climate_summary$offset_summary,
  species_era_site_summary=species_summary$era_site,
  climate_era_site_summary=climate_summary$era_site,transition_validation=validation,
  reference_source_audit=source_audit,
  species_basis=tibble(species=rownames(basis$positions),CCA1=basis$positions[,1],CCA2=basis$positions[,2],
    calibration_column_mass=reference$model$colsum[rownames(basis$positions)]),
  climate_basis=tibble(variable=vars,physical_unit=unname(reference$climate_units[vars]),
    CCA1_per_physical_unit=lc_coefficients[,1],CCA2_per_physical_unit=lc_coefficients[,2]))
iwalk(tables,~write_csv(.x,file.path(out,paste0(.y,'.csv'))))
schema=imap_dfr(tables,function(data,name) tibble(table=paste0(name,'.csv'),column=names(data),
  storage_type=map_chr(data,~class(.x)[1]),
  unit=case_when(grepl('_per_century$',names(data))~'CCA units per century',
    names(data) %in% c('weight_t1','weight_t2','weight_change','calibration_column_mass')~'unitless relative species weight',
    names(data) %in% c('contribution_CCA1','contribution_CCA2','CCA1','CCA2')~'CCA units',
    names(data) %in% c('age_hi','age_lo','interval_mid_cal_bp')~'cal BP',
    names(data) %in% c('vegetation_dt_years','climate_dt_years','offset')~'years',
    names(data) %in% c('value_t1','value_t2','value_change')~'physical_unit column',
    names(data) %in% c('mean','sd','median','q025','q975','estimate')~'measure-dependent; weight_change unitless, otherwise CCA units per century',
    TRUE~NA_character_)))
write_csv(schema,file.path(out,'schema.csv'))
provenance=list(scaling='sites',hill=FALSE,axes=1:2,n_draws=N_DRAWS,draw_seed=DRAW_SEED,
  bin_width_years=1000L,offsets=seq(0,900,100),direction_epsilon=CCA_CONTRIBUTION_EPSILON,
  numerical_tolerance=CCA_CONTRIBUTION_TOLERANCE,
  input_md5=as.list(input_md5),source_md5=as.list(tools::md5sum(here(c(
    'R/stages/11_cca_transition_contributions.R','R/helpers/cca_transition_contributions.R')))),
  R_version=as.character(getRversion()),vegan_version=as.character(packageVersion('vegan')))
jsonlite::write_json(provenance,file.path(out,'provenance.json'),pretty=TRUE,auto_unbox=TRUE)
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
  for(type in c('species','climate')) {
    summary=if(type=='species') species_summary$era_site else climate_summary$era_site
    pdf_path=file.path(plot_dir,paste0(type,'_heatmaps_by_offset.pdf'))
    cairo_pdf(pdf_path,width=16,height=if(type=='species') 9 else 6)
    tryCatch(for(offset in seq(0,900,100)) print(contribution_heatmap(summary,type,offset,reference)),
      finally=dev.off())
    # Existing figure contract keeps diagnostic plot directories PDF-only.
    ggsave(file.path(out,paste0(type,'_heatmap_offset_0.png')),
      contribution_heatmap(summary,type,0,reference),width=16,height=if(type=='species') 9 else 6,dpi=140,bg='white')
  }
}
notes=c('Standalone fixed-CCA displacement contribution analysis. No additional statistical models.',
  'All ten offsets, including 800, are retained separately. No R2 weights or offset exclusion.',
  'Species: mean of sample-level relative weights in each Holocene bin; Delta q times fixed species positions.',
  'Climate: change one raw seasonal variable at a time, hold other variables at their initial values, subtract initial LC.',
  'Species rates use vegetation elapsed time; climate rates use climate elapsed time.',
  'Parallel is signed along the reference movement; perpendicular is signed along its +90-degree rotation.',
  'Species reference is Delta LC; climate-variable reference is Delta WA. Undefined directions stay NA.',
  'Holocene uncertainty is calculated after realization-level contributions, with all and nmin2 sampling rules.',
  'Trajectory summaries first average supported transitions within lake/draw/offset, then equal-weight available lakes within park/draw/offset.',
  'Heatmap Holocene estimates are medians across these whole-draw park means; modern estimates are means across valid plots.',
  'Offset origins, adjacent shared endpoints, chronology draws and unequal lake coverage are not independent replicates.',
  'Component medians need not sum after aggregation; additivity is verified for every original transition/draw.',
  'Bacon percentile summaries are conditional on valid transitions; CCA and climate-model uncertainty are not propagated.',
  paste('Calibration WA maximum error:',basis$calibration_error),
  paste('Paleo sample WA maximum error:',sample_error,'| relative-weight reconstruction:',weight_error),
  paste('Holocene endpoint maximum errors:',bin_first_error,bin_last_error),
  paste('Independent LC coefficient reconstruction maximum error:',lc_error),
  paste('Transitions:',nrow(context),'| Holocene:',nrow(holocene),'| modern:',nrow(modern)),
  'Maximum per-realization sum/projection errors:',capture.output(print(as.data.frame(validation |>
    summarize(across(ends_with('error'),~max(.x,na.rm=TRUE)))))),
  'Direction support:',capture.output(print(validation |> count(era,climate_direction_valid,observed_direction_valid))),
  'Table rows:',capture.output(print(tibble(table=names(tables),rows=map_int(tables,nrow)))),
  capture.output(sessionInfo()))
writeLines(notes,file.path(out,'validation.txt'))
cat('Standalone contributions completed:',nrow(species),'species records and',nrow(climate),
  'climate-variable records. Existing analyses and outputs were not written.\n')
