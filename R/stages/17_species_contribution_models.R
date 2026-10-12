# Species GLS by park; modern MORA: intercept only, NOCA: unburned baseline + burned contrast.
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_predictor_models.R'),local=TRUE)
x=read_csv(here('output/cca_transition_contributions/species_primary.csv'),show_col_types=FALSE)
entries=exclusions=list()
for(species in sort(unique(x$species))) for(era in c('Holocene','Anthropocene')) for(site in c('MORA','NOCA')) {
  input=reconstruction_explanatory_input(x[x$era==era,],species,era,species=TRUE,within_site=site,
    fixed_override=if(era=='Anthropocene' && site=='MORA') estimate~1 else NULL)
  e=reconstruction_select(input$data,input$fixed,variance=NULL,families=if(era=='Holocene') c('Independent','MA1','CAR1') else 'Independent')
  e$metric=species;e$era=era;e$site=site;e$specification=if(era=='Holocene') 'within_site_climate_fire' else
    if(site=='MORA') 'within_site_intercept' else 'within_site_burned'
  name=paste(species,era,site,sep=':');entries[[name]]=e;exclusions[[name]]=input$excluded
}
out=tracking_primary_results('species')
tables=reconstruction_export(entries,out,bind_rows(exclusions))
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
  coefficient_pages=tracking_species_coefficient_pages(tables$model_coefficients,
    tables$covariance_comparison,x)
  tracking_pdf_pages(coefficient_pages$plots,
    tracking_model_figure('fig_species_contribution_model_coefficients.pdf'),width=14,height=10)
  write_csv(coefficient_pages$status,file.path(out,'figure_coefficient_availability.csv'))
  write_csv(coefficient_pages$contribution_summary,file.path(out,'figure_mean_contributions.csv'))
  residual_pages=lapply(c('Holocene','Anthropocene'),function(era_name) lapply(c('MORA','NOCA'),function(park)
    reconstruction_residual_plot(tables$transition_predictions |> filter(era==era_name,site==park))+
      plot_annotation(title=paste(era_name,park)))) |> unlist(recursive=FALSE)
  tracking_pdf_pages(residual_pages,tracking_model_figure('fig_species_contribution_model_residuals.pdf'),width=18,height=18)
}
if(isTRUE(getOption('paleoaces.run_bacon_sensitivity',FALSE)) &&
   !isTRUE(getOption('paleoaces.primary_only',FALSE))) {
  sensitivity_out=tracking_bacon_results('species')
  sensitivity=reconstruction_sensitivity(century_prepare(),entries,'species',sensitivity_out)
  source(here('R/helpers/chronology_exports.R'),local=TRUE)
  export_chronology_records(sensitivity_out,'species')
  if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
    pages=lapply(c('MORA','NOCA'),function(park) {
      one=lapply(sensitivity[c('coefficients','status','summary')],function(d) filter(d,site==park))
      reconstruction_sensitivity_plot(one)+plot_annotation(title=paste('Holocene',park))
    })
    tracking_pdf_pages(pages,tracking_model_figure('fig_species_contribution_chronology_sensitivity.pdf',role='bacon'),width=18,height=14)
  }
}
