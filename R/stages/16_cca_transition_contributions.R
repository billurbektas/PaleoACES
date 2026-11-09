# Fixed-CCA species rates and seasonal climate displacement contributions.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here);library(tidyverse);library(vegan)})
source(here('R/helpers/century_tracking.R'),local=TRUE)
source(here('R/helpers/cca_transition_contributions.R'),local=TRUE)
bundle=century_prepare();primary=readRDS(out('chronology_reconstruction/primary.rds'))
h=century_species_contributions(primary,bundle)
a=read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'),show_col_types=FALSE)
basis=contribution_reference(bundle$reference)
occ=read_csv(out('occ_consolidated.csv'),show_col_types=FALSE)
ids=select(a,site,plot_id)
first=contribution_weights(contribution_species_matrix(occ,ids,'past',bundle$reference$retained_species))
last=contribution_weights(contribution_species_matrix(occ,ids,'present',bundle$reference$retained_species))
contribution_close((last-first)%*%basis$positions,as.matrix(a[c('delta_observed_CCA1','delta_observed_CCA2')]),
  'Modern species-vector conservation')
modern=contribution_species(century_contribution_context(a,'Anthropocene'),first,last,basis$positions,a)
modern$contribution_rate=modern$parallel_contribution*100/modern$vegetation_dt_years
species=bind_rows(h,modern)
climate=bind_rows(century_climate_contributions(century_contribution_context(primary$calculations,'Holocene'),
  primary$calculations,bundle$reference),century_climate_contributions(century_contribution_context(a,'Anthropocene'),a,bundle$reference))
results_dir=out('cca_transition_contributions');dir.create(results_dir,recursive=TRUE,showWarnings=FALSE)
write_csv(species,file.path(results_dir,'species_primary.csv'));write_csv(climate,file.path(results_dir,'climate_primary.csv'))
write_csv(century_schema(list(species_primary=species,climate_primary=climate)),file.path(results_dir,'schema.csv'))
writeLines(c('One primary reconstructed transition or modern pair per component.',
  'Species signed parallel contributions: CCA distance per century; raw vectors and weights also retained.',
  'Climate signed parallel contributions: CCA displacement, without dividing by elapsed time.',
  'Species reference is delta LC; climate reference is delta WA. Undefined directions remain NA.',
  'Additivity is verified for each primary or whole-draw transition before any summaries.'),file.path(results_dir,'calculation_notes.txt'))
if(isTRUE(getOption('paleoaces.render_figures',TRUE))) for(type in c('species','climate')) {
  data=if(type=='species') species |> mutate(component=species,value=contribution_rate) else
    climate |> mutate(component=variable,value=parallel_contribution)
  p=ggplot(data,aes(value,component,fill=era))+geom_vline(xintercept=0,linetype='dashed',color='grey60')+
    geom_boxplot(outlier.shape=NA,position=position_dodge(width=.8))+
    facet_wrap(~site)+scale_fill_manual(values=c(Holocene='#785EF0',Anthropocene='#DC267F'))+
    labs(x=if(type=='species') 'Parallel species contribution (CCA distance per century)' else
      'Parallel climate contribution (CCA displacement)',y=NULL,fill='Era',
      caption=paste0('One value per primary Holocene lake transition (MORA: ',sum(primary$calculations$site=='MORA'),
        '; NOCA: ',sum(primary$calculations$site=='NOCA'),') or modern plot pair (MORA: ',sum(a$site=='MORA'),
        '; NOCA: ',sum(a$site=='NOCA'),').\n',
        'Boxes show variation among actual transitions/plots, not offsets or Bacon chronologies. Undefined directions are omitted; zeros remain.\n',
        if(type=='species') 'Species contributions are projected along climate-predicted movement and divided by each transition duration, in centuries.' else
          'Climate-variable contributions are projected along observed community movement; displacements use actual endpoints and are not divided by duration.'))+
    theme_minimal(base_size=18)+theme(legend.position='bottom',axis.text.y=element_text(size=16),
      plot.caption=element_text(size=14,hjust=0))
  if(type=='species') {
    # Keep all finite values in the box statistics; zoom to displayed whiskers.
    boxes=ggplot_build(p)$data[[2]]
    limit=max(max(abs(c(boxes$xmin,boxes$xmax)),na.rm=TRUE)*1.08,1e-5)
    p=p+coord_cartesian(xlim=c(-limit,limit))+
      labs(caption=paste0(p$labels$caption,'\nAxis zooms to visible boxes and whiskers; hidden outliers remain in all calculations.'))
  }
  ggsave(fig('supplementary', paste0('fig_cca_transition_',type,'_boxplots.pdf')),p,
    width=16,height=if(type=='species') 10 else 6,device=cairo_pdf)
}
