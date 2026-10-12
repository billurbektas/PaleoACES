# Modern-only covariates. Shared GLS lives in reconstruction_models.R.
tracking_modern_elevations = function(mora,noca,plots) {
  elevations=bind_rows(
    mora |> transmute(site='MORA',join_id=toupper(trimws(plot_id)),elevation,
      elevation_source='data/MORA_plots.rda: plot_info$elevation'),
    noca |> transmute(site='NOCA',join_id=toupper(trimws(`2015.Plot.Name`)),
      elevation=`2015.Elevation.m`,
      elevation_source='data/NOCA/NOCA_plots_fromWilson.csv: 2015.Elevation.m'))
  if(anyDuplicated(elevations[c('site','join_id')])) stop('Ambiguous elevation identity')
  result=plots |> mutate(join_id=toupper(trimws(plot_id))) |>
    left_join(elevations,by=c('site','join_id'),relationship='many-to-one')
  if(any(!is.finite(result$elevation))) stop('Missing elevation for plots: ',
    paste(result$plot_id[!is.finite(result$elevation)],collapse=', '))
  result |> select(-join_id)
}

# Manuscript effects are the fitted additive slopes and the NOCA-minus-MORA
# contrast. There are no separate park slopes without site interactions.
tracking_predictor_effect_panel=function(coefficients,performance,specification,title,tag,observed_only=FALSE) {
  metric_levels=c('lag_rate_per_century','pace_effect_on_lag_per_century',
    'direction_effect_on_lag_per_century')
  palette=setNames(c('#40AB9D','#DE85F0','#8B85F1'),metric_levels)
  response_labels=setNames(c('Observed lag-change rate','Pace correction effect','Direction correction effect'),metric_levels)
  if(observed_only) metric_levels='lag_rate_per_century'
  terms=switch(specification,Holocene=c('fire_activity','climate_rate','siteNOCA'),
    Anthropocene_basic=c('burnedBurned','siteNOCA'),
    Anthropocene_extended=c('burnedBurned','climate_rate','elevation','siteNOCA'))
  labels=c(siteNOCA='Site\nNOCA − MORA',
    climate_rate='Climate-change rate\n+1 standardized unit per century',
    fire_activity='Fire activity\n+1 event per century per core',
    burnedBurned='Fire\nBurned − unburned',elevation='Elevation\n+100 m')
  d=coefficients |> filter(.data$specification==.env$specification,term %in% terms,metric %in% metric_levels) |>
    mutate(metric=factor(metric,levels=metric_levels),
      display_multiplier=if_else(term=='elevation',100,1),
      across(c(estimate,std_error,conf_low,conf_high),~.x*display_multiplier),
      y=match(term,terms)+if(observed_only) 0 else c(.20,0,-.20)[as.integer(metric)],
      interval_alpha=if_else(p_value<.05,1,.45))
  if(nrow(d)!=length(metric_levels)*length(terms) || anyDuplicated(d[c('metric','term')]))
    stop('Missing or duplicate manuscript predictor coefficients')
  perf=performance |> filter(.data$specification==.env$specification,metric %in% metric_levels) |>
    arrange(match(metric,metric_levels))
  if(nrow(perf)!=length(metric_levels) || !identical(perf$metric,metric_levels))
    stop('Missing model R2 for predictor caption')
  caption=if(observed_only) paste0('Descriptive R²: ',sprintf('%.3f',perf$R2[1]),'.') else
    paste0('Descriptive R²: observed ',sprintf('%.3f',perf$R2[1]),
    '; pace ',sprintf('%.3f',perf$R2[2]),'; direction ',sprintf('%.3f',perf$R2[3]),'.')
  p=ggplot(d,aes(estimate,y,color=metric))+
    geom_vline(xintercept=0,linetype='dashed',color='grey55',linewidth=.6)+
    geom_errorbar(aes(xmin=conf_low,xmax=conf_high,alpha=interval_alpha),
      orientation='y',width=.10,linewidth=1.05,show.legend=FALSE)+
    geom_point(aes(alpha=interval_alpha),size=2.5,show.legend=TRUE)+
    scale_color_manual(values=palette[metric_levels],labels=response_labels[metric_levels],drop=FALSE,name=NULL,
      guide=guide_legend(override.aes=list(alpha=1,size=3)))+
    scale_alpha_identity(guide='none')+
    scale_y_continuous(breaks=seq_along(terms),labels=unname(labels[terms]),
      limits=c(.45,length(terms)+.55),expand=expansion(mult=0))+
    scale_x_continuous(expand=expansion(mult=.09))+
    labs(x=if(observed_only) 'Effect on observed lag-change rate\n(CCA distance per century)' else
      'Effect on response\n(CCA distance per century)',y=NULL,
      title=title,tag=tag,caption=caption)+
    theme_minimal(base_size=20)+
    theme(panel.grid.minor=element_blank(),panel.grid.major.y=element_blank(),
      axis.text=element_text(size=18,color='grey20'),axis.title=element_text(size=20),
      plot.title=element_text(size=24,face='bold'),plot.tag=element_text(size=26,face='bold'),
      plot.tag.position='topleft',legend.position='bottom',legend.text=element_text(size=18),
      plot.caption=element_text(size=14,hjust=0,margin=margin(t=15)),
      plot.margin=margin(12,18,12,12))
  list(plot=p,data=d)
}

# Species coefficients from separate park fits, including each park's intercept.
tracking_species_coefficient_pages=function(coefficients,comparison,contributions) {
  species=sort(unique(contributions$species))
  status=comparison |> filter(model_type==primary_family) |>
    select(era,metric,site,converged,fit_error,n)
  stopifnot(!anyDuplicated(status[c('era','metric','site')]),nrow(status)==4L*length(species))
  coverage=contributions |> group_by(era,species,site) |>
    summarise(present=any(weight_t1>0 | weight_t2>0,na.rm=TRUE),.groups='drop')
  status=status |> left_join(coverage,by=c('era','metric'='species','site')) |>
    mutate(reason=case_when(converged~'Estimated',
      !present~'Absent in this park; contribution is zero throughout',
      fit_error=='constant_response'~'Present but contribution is constant; no response variance',
      TRUE~fit_error))
  raw_summary=contributions |> group_by(era,species,site) |>
    summarise(n=sum(is.finite(contribution_rate)),
      mean_contribution=if(n>0) mean(contribution_rate[is.finite(contribution_rate)]) else NA_real_,
      median_contribution=if(n>0) median(contribution_rate[is.finite(contribution_rate)]) else NA_real_,.groups='drop')
  plots=lapply(c('Holocene','Anthropocene'),function(era_name) {
    h=era_name=='Holocene'
    terms=if(h) c('(Intercept)','climate_rate','fire_activity') else c('(Intercept)','burnedBurned')
    term_labels=if(h) c('Intercept','Climate-change rate\n+1 standardized unit\nper century',
      'Fire activity\n+1 event per century\nper core') else c('Intercept','NOCA fire effect\nBurned − unburned')
    state=filter(status,era==era_name)
    d=expand_grid(metric=species,site=c('MORA','NOCA'),term=terms) |>
      filter(.env$h | site!='MORA' | term!='burnedBurned') |>
      left_join(coefficients |> filter(era==era_name),by=c('metric','site','term')) |>
      left_join(select(state,metric,site,converged,reason),by=c('metric','site')) |>
      mutate(term=factor(term,levels=terms),y=match(metric,rev(species))+if_else(site=='MORA',.16,-.16),
        opacity=if_else(p_value<.05,1,.45))
    stopifnot(all(is.finite(d$estimate)==d$converged))
    means=raw_summary |> filter(era==era_name) |> transmute(metric=species,site,term='Mean',
      estimate=mean_contribution,y=match(species,rev(.env$species))+if_else(site=='MORA',.16,-.16))
    d$term=factor(d$term,levels=c('Mean',terms));means$term=factor(means$term,levels=c('Mean',terms))
    term_labels=c('Mean parallel\ncontribution\n(descriptive)',term_labels);terms=c('Mean',terms)
    why=character()
    for(park in c('MORA','NOCA')) {
      absent=state |> filter(site==park,!converged,!present)
      if(nrow(absent)) why=c(why,paste0('Absent in ',park,': ',paste(absent$metric,collapse=', '),'.'))
      other=state |> filter(site==park,!converged,present)
      if(nrow(other)) why=c(why,paste(park,other$metric,other$reason,sep=': '))
    }
    caption=c('Diamonds: arithmetic means of all finite primary contributions (the boxplot data); each transition/plot enters once, with no weighting.',
      'Means retain zeros and omit undefined directions; they have no model confidence intervals or significance fading.',
      'Circles: separate park GLS estimates; bars: conditional 95% confidence intervals. Faded estimates: unadjusted p ≥ 0.05.',
      'NE = not estimable in that park; absence in the other park does not prevent a fit. Each coefficient column has its own x-axis scale.',
      if(h) 'Intercept: expected contribution in that park at zero climate-change rate and zero fire activity; it is not the overall mean.' else
        'MORA intercept: mean across all eligible plots. NOCA intercept: unburned-plot mean; fire effect: burned minus unburned. No MORA fire term is fitted.',
      'Positive contributions align with climate-predicted movement; negative contributions oppose it. An intercept does not fix the sign of every observation.',why)
    p=ggplot(d,aes(estimate,y,color=site))+
      geom_vline(xintercept=0,color='grey65',linetype='dashed',linewidth=.5)+
      geom_errorbar(aes(xmin=conf_low,xmax=conf_high,alpha=opacity),orientation='y',
        width=.18,linewidth=.7,na.rm=TRUE,show.legend=FALSE)+
      geom_point(aes(alpha=opacity),size=1.8,na.rm=TRUE)+
      geom_point(data=means,shape=18,size=2.5,na.rm=TRUE,show.legend=FALSE)+
      geom_text(data=filter(d,!converged),aes(x=0,label='NE'),size=2.8,show.legend=FALSE)+
      facet_grid(~term,scales='free_x',labeller=labeller(term=setNames(term_labels,terms)))+
      scale_y_continuous(breaks=seq_along(species),labels=rev(species),expand=expansion(add=.5))+
      scale_color_manual(values=c(MORA='#648FFF',NOCA='#FE6100'),name=NULL,
        guide=guide_legend(override.aes=list(alpha=1,size=3)))+
      scale_alpha_identity(guide='none')+scale_x_continuous(n.breaks=4,expand=expansion(mult=.12))+
      labs(title=era_name,subtitle=if(h)
        'Within each park: contribution rate ~ climate-change rate + fire activity · MA(1)' else
        'MORA: contribution rate ~ 1 · NOCA: contribution rate ~ burned · Independent residuals',
        x=if(h) 'Contribution / coefficient (CCA distance per century; slopes per predictor unit)' else
          'Contribution / coefficient (CCA distance per century)',y=NULL,
        caption=paste(vapply(caption,function(s)paste(strwrap(s,width=155),collapse='\n'),character(1)),collapse='\n'))+
      theme_minimal(base_size=16)+theme(panel.grid.minor=element_blank(),legend.position='bottom',
        panel.grid.major.y=element_line(color='grey94'),axis.text.y=element_text(face='italic',size=16,color='grey20'),
        axis.text.x=element_text(size=13,color='grey20'),strip.text=element_text(size=14,face='bold'),
        panel.spacing.x=unit(1.2,'lines'),plot.title=element_text(size=23,face='bold'),
        plot.subtitle=element_text(size=14),plot.caption=element_text(size=10.5,hjust=0,lineheight=1.1,margin=margin(t=10)),
        plot.margin=margin(12,15,12,12))
    p
  })
  list(plots=plots,status=status,contribution_summary=raw_summary)
}
