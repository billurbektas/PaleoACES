# Model result folders, separated by inferential role (see R/helpers/paths.R).
tracking_model_figure=function(name,role='primary')
  fig('models',if(role=='lake') file.path('lake_checks',name) else name)
tracking_pdf_pages=function(plots,path,width=12,height=8) {
  grDevices::cairo_pdf(path,width=width,height=height,onefile=TRUE)
  on.exit(grDevices::dev.off(),add=TRUE)
  for(plot in plots) print(plot)
}
