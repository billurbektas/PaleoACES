# Species explanatory GLS mirrors community models; modern species: site + burned only.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
x=read_csv(here('output/cca_transition_contributions/species_primary.csv'),show_col_types=FALSE)
entries=exclusions=list()
for(species in sort(unique(x$species))) for(era in c('Holocene','Anthropocene')) {
  input=reconstruction_explanatory_input(x[x$era==era,],species,era,species=TRUE)
  e=reconstruction_select(input$data,input$fixed,families=if(era=='Holocene') c('Independent','MA1','CAR1') else 'Independent')
  e$metric=species;e$era=era;e$specification=if(era=='Holocene') 'site_climate_fire' else 'site_burned'
  name=paste(species,era,sep=':');entries[[name]]=e;exclusions[[name]]=input$excluded
}
out=tracking_primary_results('species')
tables=reconstruction_export(entries,out,bind_rows(exclusions))
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
  ggsave(tracking_model_figure('fig_species_contribution_model_coefficients.pdf'),
    reconstruction_coefficient_plot(tables$model_coefficients)+facet_grid(metric~term,scales='free_x'),width=22,height=22,device=cairo_pdf)
  ggsave(tracking_model_figure('fig_species_contribution_model_residuals.pdf'),
    reconstruction_residual_plot(tables$transition_predictions),width=22,height=24,device=cairo_pdf)
}
if(!isTRUE(getOption('paleoaces.primary_only',FALSE))) {
  sensitivity_out=tracking_bacon_results('species')
  sensitivity=reconstruction_sensitivity(century_prepare(),entries,'species',sensitivity_out)
  source(here('R/helpers/chronology_exports.R'),local=TRUE)
  export_chronology_records(sensitivity_out,'species')
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) ggsave(
    tracking_model_figure('fig_species_contribution_chronology_sensitivity.pdf',role='bacon'),
    reconstruction_sensitivity_plot(sensitivity),width=22,height=14,device=cairo_pdf)
}
