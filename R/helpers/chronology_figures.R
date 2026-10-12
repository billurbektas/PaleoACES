# Chronology ranges are sensitivity summaries, separate from the primary result.
# Each complete draw contributes at most one transition-average value per date.
# Mapping an actual transition span does not interpolate vegetation observations.
chronology_temporal_ranges=function(bundle,out) {
  grid=bundle$grid |> dplyr::select(site,lake,century_cal_bp)
  fields=c('lag_rate_per_century','observed_turnover_rate','standardized_climate_change_rate','fire_activity')
  values=lapply(fields,function(x) matrix(NA_real_,nrow(grid),HOLOCENE_RECONSTRUCTION_DRAWS))
  names(values)=fields
  present=matrix(FALSE,nrow(grid),HOLOCENE_RECONSTRUCTION_DRAWS)
  signature=NULL
  for(draw in seq_len(HOLOCENE_RECONSTRUCTION_DRAWS)) {
    saved=readRDS(file.path(out,'chronology_batches',sprintf('draw_%04d.rds',draw)))
    if(draw==1L) signature=saved$signature else if(!identical(signature,saved$signature))
      stop('Mixed chronology fingerprints in temporal range figure')
    x=saved$calculations
    if(saved$draw!=draw || any(x$draw!=draw)) stop('Chronology identity mismatch')
    for(lake in unique(grid$lake)) {
      g=which(grid$lake==lake);z=x[x$lake==lake,];z=z[order(z$age_lo),]
      if(!nrow(z)) next
      index=findInterval(grid$century_cal_bp[g],z$age_lo)
      valid=index>0L
      valid[valid]=grid$century_cal_bp[g[valid]]<z$age_hi[index[valid]]
      target=g[valid];source=index[valid]
      present[target,draw]=TRUE
      for(field in fields) values[[field]][target,draw]=z[[field]][source]
    }
  }
  ranges=purrr::imap_dfr(values,function(x,metric) {
    n=rowSums(is.finite(x))
    q=t(vapply(seq_len(nrow(x)),function(i) {
      v=x[i,is.finite(x[i,])]
      if(length(v)) stats::quantile(v,c(.025,.25,.5,.75,.975),names=FALSE) else rep(NA_real_,5L)
    },numeric(5)))
    dplyr::bind_cols(grid,tibble::tibble(metric,n_expected_draws=HOLOCENE_RECONSTRUCTION_DRAWS,
      n_draws_with_transition=rowSums(present),n_valid_draws=n,n_undefined_or_uncovered=rowSums(present)-n,
      q025=q[,1],q25=q[,2],median=q[,3],q75=q[,4],q975=q[,5]))
  })
  readr::write_csv(ranges,file.path(out,'chronology_temporal_ranges.csv'))
  ranges
}
chronology_temporal_range_plot=function(ranges,primary) {
  labels=c(lag_rate_per_century='Observed lag-change rate\n(CCA distance\nper century)',
    observed_turnover_rate='Community turnover rate\n(CCA distance\nper century)',
    standardized_climate_change_rate='Standardized climate\nchange per century',
    fire_activity='Fire exposure\n(events per century\nper eligible core)',
    support='Available complete\nchronologies')
  fields=names(labels)[names(labels)!='support']
  colors=c(lag_rate_per_century='#3466FF',observed_turnover_rate='#00A27A',
    standardized_climate_change_rate='#6F604C',fire_activity='#C83F34')
  r=ranges |> dplyr::mutate(metric=factor(metric,levels=names(labels)),
    lake=factor(lake,levels=c('JayBath','LogWallow','ReflectionPond','PantherPotholes')))
  p=primary |> dplyr::select(lake,age_hi,age_lo,dplyr::all_of(fields)) |>
    tidyr::pivot_longer(dplyr::all_of(fields),names_to='metric',values_to='value') |>
    dplyr::mutate(metric=factor(metric,levels=names(labels)),lake=factor(lake,levels=levels(r$lake)))
  support=dplyr::bind_rows(
    r |> dplyr::filter(metric=='lag_rate_per_century') |>
      dplyr::transmute(lake,century_cal_bp,metric=factor('support',levels=names(labels)),
        availability='Transition available',n=n_draws_with_transition),
    r |> dplyr::filter(metric=='fire_activity') |>
      dplyr::transmute(lake,century_cal_bp,metric=factor('support',levels=names(labels)),
        availability='Fire exposure available',n=n_valid_draws))
  ggplot2::ggplot(r,ggplot2::aes(century_cal_bp,median))+
    ggplot2::geom_ribbon(ggplot2::aes(ymin=q025,ymax=q975,fill=metric),alpha=.13,na.rm=TRUE)+
    ggplot2::geom_ribbon(ggplot2::aes(ymin=q25,ymax=q75,fill=metric),alpha=.27,na.rm=TRUE)+
    ggplot2::geom_line(ggplot2::aes(color=metric),linetype='dotted',linewidth=.5,na.rm=TRUE)+
    ggplot2::geom_segment(data=p,ggplot2::aes(x=age_lo,xend=age_hi,y=value,yend=value,color=metric),
      inherit.aes=FALSE,linewidth=.85,na.rm=TRUE)+
    ggplot2::geom_line(data=support,ggplot2::aes(x=century_cal_bp,y=n,linetype=availability),
      inherit.aes=FALSE,color='grey30',linewidth=.65)+
    ggplot2::scale_fill_manual(values=colors,guide='none')+
    ggplot2::scale_color_manual(values=colors,guide='none')+
    ggplot2::scale_linetype_manual(values=c('Transition available'='solid','Fire exposure available'='dashed'))+
    ggplot2::facet_grid(metric~lake,scales='free_y',switch='y',
      labeller=ggplot2::labeller(metric=ggplot2::as_labeller(labels)))+
    ggplot2::scale_x_reverse()+
    ggplot2::labs(x='Native CHELSA century (cal BP)',y=NULL,linetype=NULL,
      title='Bacon chronology-reconstruction ranges',
      subtitle='Solid spans: primary reconstruction; dotted curves: draw median; dark/light bands: 50% / 95% draw ranges',
      caption='Each draw constructs its own occupied centuries and transitions. Ranges summarize transition-average values covering each date.\nThese are chronology sensitivity ranges, not model confidence intervals; vegetation is not interpolated. No support cutoff is applied.')+
    ggplot2::theme_minimal(base_size=17)+ggplot2::theme(panel.grid.minor=ggplot2::element_blank(),
      strip.text=ggplot2::element_text(size=16,face='bold'),
      strip.text.y.left=ggplot2::element_text(angle=0,size=15,hjust=1),
      strip.placement='outside',legend.position='bottom')
}
