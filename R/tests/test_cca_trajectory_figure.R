# Offline gate for the selected publication CCA trajectory architecture.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse)})
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))

centroid_path = out("figures/cca_trajectory_era_centroids.csv")
figure_files = c(fig("main", "fig_cca_trajectories.pdf"), fig("main", "fig_cca_trajectories.png"))
stopifnot(file.exists(centroid_path))
if (render_figures)
  stopifnot(all(file.exists(figure_files)), all(file.info(figure_files)$size > 5000))

centroids = read_csv(centroid_path, show_col_types = FALSE)
modern = read_csv(out("figures/cca_trajectory_anthropocene_centroids.csv"), show_col_types = FALSE)
tracking_pairs = read_csv(out("cca_tracking_anthropocene_plot_calculations.csv"), show_col_types = FALSE)
stopifnot(nrow(modern) == 4L, !anyDuplicated(modern[c("site", "t")]),
          all(is.finite(unlist(select(modern, o1, o2, p1, p2)))))
# Independent means of the actual tracking endpoints must reproduce Figure 3;
# balanced counts alone could conceal a different pair membership.
for (site_name in c("MORA", "NOCA")) for (survey in c("legacy", "resurvey")) {
  x = tracking_pairs %>% filter(site == site_name)
  row = modern %>% filter(site == site_name, t == survey)
  fields = if (survey == "legacy") c("o1", "o2", "p1", "p2") else
    c("o1_2", "o2_2", "p1_2", "p2_2")
  stopifnot(nrow(row) == 1L, row$n == nrow(x),
            max(abs(as.numeric(row[c("o1", "o2", "p1", "p2")]) -
                      vapply(x[fields], mean, numeric(1)))) < 1e-12)
}
eras = c("CC1", "S1", "CC2", "S2", "CC3", "S3", "CC4", "S4")
stopifnot(
  setequal(centroids$site, c("MORA", "NOCA")),
  all(centroids$era_id %in% eras),
  setequal(centroids$era_id, eras),
  !anyDuplicated(centroids[c("site", "era_id")]),
  all(centroids$n_dates > 0L),
  all(is.finite(unlist(select(centroids, ends_with(c("CCA1", "CCA2"))))))
)

# Independently verify equal-lake weighting and original primary century means.
positions=read_csv(out('cca_tracking_holocene_century_positions.csv'),show_col_types=FALSE)
catalog=read_csv(out('holocene_era_catalog.csv'),show_col_types=FALSE)
for(i in seq_len(nrow(centroids))) {
  row=centroids[i,];period=catalog[catalog$era_id==row$era_id,]
  x=positions |> filter(site==row$site,century_cal_bp>=period$younger_cal_bp,
    century_cal_bp<period$older_cal_bp)
  lakes=split(x,x$lake)
  expected=colMeans(do.call(rbind,lapply(lakes,function(z) colMeans(as.matrix(z[c('o1','o2','p1','p2')])))))
  actual=as.numeric(row[c('observed_CCA1','observed_CCA2','predicted_CCA1','predicted_CCA2')])
  stopifnot(row$n_lakes==length(lakes),max(abs(actual-expected))<1e-12)
}

# Independently verify the information transferred from the former bar panels.
labels=read_csv(out("figures/cca_figure_biplot_annotations.csv"),show_col_types=FALSE)
sp=read_csv(out("cca_species_contributions.csv"),show_col_types=FALSE)
cl=read_csv(out("cca_climate_contributions.csv"),show_col_types=FALSE)
stopifnot(nrow(labels)==18L,!anyDuplicated(labels$name),all(is.finite(labels$share_pct)),
  setequal(labels$name, c(sp$species,cl$variable)))
ls=labels |> filter(component=='Species') |> arrange(name)
sp=arrange(sp,species)
stopifnot(max(abs(ls$share_pct-sp$percent_constrained_inertia))<1e-10,
  max(abs(ls$occurrence_pct-sp$prevalence_percent))<1e-10,
  abs(sum(ls$share_pct)-100)<1e-8,
  identical(ls$label,sprintf('%s (%.1f%%)',sp$species,sp$prevalence_percent)))
lc=labels |> filter(component=='Climate') |> arrange(name)
cl=arrange(cl,variable)
stopifnot(max(abs(lc$share_pct-cl$unique_percent_constrained))<1e-10)
# Full-opacity path colors are actual lighter RGB values, not alpha blending.
display=read_csv(out('figures/cca_figure_trajectory_display.csv'),show_col_types=FALSE)
stopifnot(all(display$display_alpha==1),all(nchar(display$display_color)==7L))
for(site_name in c('MORA','NOCA')) {
  observed=unique(display$display_color[display$site==site_name & display$type=='observed'])
  predicted=unique(display$display_color[display$site==site_name & display$type=='predicted'])
  stopifnot(length(observed)==1L,length(predicted)==1L,
    all(col2rgb(predicted)>=col2rgb(observed)),any(col2rgb(predicted)>col2rgb(observed)))
}
if(render_figures && nzchar(Sys.which('pdftotext'))) {
  text=paste(system2('pdftotext',c(figure_files[1],'-'),stdout=TRUE),collapse=' ')
  text=str_squish(text)
  stopifnot(all(vapply(sp$species,function(name) str_detect(text,fixed(name)),logical(1))),
    str_detect(text,fixed('A.')),str_detect(text,fixed('B.')),
    !str_detect(text,fixed('C.')),!str_detect(text,fixed('D.')),
    str_detect(text,fixed('Constrained inertia (%)')))
}


pdf_pages = function(path) {
  if (!nzchar(Sys.which("pdfinfo"))) return(NA_integer_)
  x = system2("pdfinfo", path, stdout = TRUE, stderr = TRUE)
  as.integer(sub("^Pages:\\s*", "", grep("^Pages:", x, value = TRUE)[1]))
}
if (render_figures && nzchar(Sys.which("pdfinfo")))
  stopifnot(pdf_pages(figure_files[1]) == 1L)

cat("PASS: publication CCA figure uses primary equal-lake period centroids and side-by-side A/B architecture with complete inertia/occurrence annotations",
    if (render_figures) ", including PDF/PNG outputs.\n" else ".\n", sep = "")
