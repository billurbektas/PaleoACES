# Species GLS by park; modern MORA: intercept only, NOCA: unburned baseline + burned contrast.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(nlme);library(patchwork)})
source(here('R/helpers/reconstruction_models.R'),local=TRUE)
source(here('R/helpers/tracking_predictor_models.R'),local=TRUE)
x=read_csv(out('cca_transition_contributions/species_primary.csv'),show_col_types=FALSE)
entries=exclusions=list()
for(species in sort(unique(x$species))) for(era in c('Holocene','Anthropocene')) for(site in c('MORA','NOCA')) {
  input=reconstruction_explanatory_input(x[x$era==era,],species,era,species=TRUE,within_site=site,
    fixed_override=if(era=='Anthropocene' && site=='MORA') estimate~1 else NULL)
  e=reconstruction_select(input$data,input$fixed,variance=NULL,families=if(era=='Holocene') c('Independent','MA1','CAR1') else 'Independent')
  e$metric=species;e$era=era;e$site=site;e$specification=if(era=='Holocene') 'within_site_climate_fire' else
    if(site=='MORA') 'within_site_intercept' else 'within_site_burned'
  name=paste(species,era,site,sep=':');entries[[name]]=e;exclusions[[name]]=input$excluded
}
results_dir=tracking_primary_results('species')
tables=reconstruction_export(entries,results_dir,bind_rows(exclusions))
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) {
  coefficient_pages=tracking_species_coefficient_pages(tables$model_coefficients,
    tables$covariance_comparison,x)
  tracking_pdf_pages(coefficient_pages$plots,
    tracking_model_figure('fig_species_contribution_model_coefficients.pdf'),width=14,height=10)
  write_csv(coefficient_pages$status,file.path(results_dir,'figure_coefficient_availability.csv'))
  write_csv(coefficient_pages$contribution_summary,file.path(results_dir,'figure_mean_contributions.csv'))
  residual_pages=lapply(c('Holocene','Anthropocene'),function(era_name) lapply(c('MORA','NOCA'),function(park)
    reconstruction_residual_plot(tables$transition_predictions |> filter(era==era_name,site==park))+
      plot_annotation(title=paste(era_name,park)))) |> unlist(recursive=FALSE)
  tracking_pdf_pages(residual_pages,tracking_model_figure('fig_species_contribution_model_residuals.pdf'),width=18,height=18)
}
