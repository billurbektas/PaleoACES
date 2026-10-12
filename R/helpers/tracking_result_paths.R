# Model results are separated by inferential role. Canonical input/calculation
# tables remain at their existing locations under output/.
tracking_primary_results=function(kind) here::here('output/tracking_analysis/primary',
  switch(kind,era='era_comparison',community='community_predictor_models',species='species_contribution_models'))
tracking_bacon_results=function(kind) here::here('output/tracking_analysis/sensitivity/bacon_chronologies',kind)
tracking_lake_results=function(kind='era') here::here('output/tracking_analysis/sensitivity/lake_checks',
  if(kind=='era') 'era_comparisons' else 'random_intercepts')
tracking_model_figure=function(name,role='primary') {
  directory=switch(role,primary='primary_models',bacon='sensitivity/bacon_chronologies',lake='sensitivity/lake_checks')
  path=here::here('plot/test_figures',directory,name)
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE);path
}
tracking_pdf_pages=function(plots,path,width=12,height=8) {
  grDevices::cairo_pdf(path,width=width,height=height,onefile=TRUE)
  on.exit(grDevices::dev.off(),add=TRUE)
  for(plot in plots) print(plot)
}
tracking_result_guide=function() {
  root=here::here('output/tracking_analysis')
  dir.create(root,recursive=TRUE,showWarnings=FALSE)
  writeLines(c('TRACKING ANALYSIS RESULTS',
    'primary/era_comparison/<response>: combined-era primary MA(1) fits, means and contrasts.',
    'primary/community_predictor_models: primary within-era community models.',
    'primary/species_contribution_models: primary species models.',
    'sensitivity/bacon_chronologies/community: all 1,000 community reconstructions and fit outcomes.',
    'sensitivity/bacon_chronologies/species: all 1,000 species reconstructions and fit outcomes.',
    'sensitivity/lake_checks/era_comparisons/<response>: individual-lake comparisons.',
    'sensitivity/lake_checks/random_intercepts: lake random-intercept diagnostic.',
    '', 'Primary intervals condition on median-age reconstruction; Bacon summaries are sensitivity results.',
    'MA(1) is primary for Holocene-containing fits; Independent/CAR1 are comparisons only.',
    'Modern-only models use independent residuals. Failed/unestimable models remain recorded.',
    '', 'PDFs: plot/test_figures/primary_models/ and plot/test_figures/sensitivity/.',
    'Each combined-era and lake PDF has five clearly labeled response pages:',
    '1 observed lag; 2 community turnover; 3 climate change; 4 pace-corrected lag; 5 direction-corrected lag.'),
    file.path(root,'README.txt'))
}
