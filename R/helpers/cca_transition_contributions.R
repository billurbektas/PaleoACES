# Pure helpers for the standalone fixed-CCA contribution analysis.
# No fitting, downloads, chronology regeneration or file writes.
CCA_CONTRIBUTION_EPSILON = 1e-8
CCA_CONTRIBUTION_TOLERANCE = 1e-10

contribution_close = function(actual,expected,label,tolerance=CCA_CONTRIBUTION_TOLERANCE) {
  if(!identical(dim(actual),dim(expected)) || length(actual)!=length(expected) ||
     any(!is.finite(actual)) || any(!is.finite(expected)))
    stop(label,': incompatible or nonfinite values')
  if(!length(actual)) return(invisible(0))
  error=max(abs(actual-expected))
  if(error>tolerance) stop(label,': maximum absolute error ',format(error,digits=16))
  invisible(error)
}

contribution_reference = function(reference) {
  model=reference$model;vars=reference$climate_variables
  if(!identical(reference$scaling,'sites') || !identical(reference$hill,FALSE) ||
     !identical(reference$axes,1:2) || !is.null(model$pCCA) ||
     nrow(reference$legacy_species)!=607L || length(reference$retained_species)!=14L ||
     !identical(attr(model$terms,'term.labels'),vars) || model$CCA$qrank!=length(vars))
    stop('Contributions require the fixed, additive, full-rank 607-plot / 14-taxon CCA1–CCA2 reference')
  if(!identical(rownames(reference$legacy_species),reference$calibration_plot_ids) ||
     !identical(colnames(reference$legacy_species),reference$retained_species))
    stop('Calibration matrix identities do not match the reference')
  positions=vegan::scores(model,display='species',choices=1:2,scaling='sites',hill=FALSE)
  positions=positions[reference$retained_species,,drop=FALSE]
  contribution_close(positions,reference$species_scores[reference$retained_species,1:2,drop=FALSE],
    'Frozen species scores')
  # predict.cca divides WA by sqrt(eigenvalue), then site scaling multiplies
  # it back. Thus WA(q) = (q - calibration column masses) %*% species positions.
  # Delta WA = sum_j Delta q_j * position_j, with NO additional eigenvalue factor.
  contribution_close(positions,model$CCA$v[reference$retained_species,1:2,drop=FALSE],
    'Site-scaling species basis')
  centroid=as.numeric(crossprod(model$colsum,positions))
  calibration=as.matrix(reference$legacy_species)
  weights=contribution_weights(calibration)
  observed=stats::predict(model,newdata=calibration,type='wa',scaling='sites',hill=FALSE)[,1:2,drop=FALSE]
  error=contribution_close(sweep(weights,2,model$colsum,'-') %*% positions,observed,
    'Calibration WA reconstructed from relative species weights')
  list(positions=positions,centroid=centroid,calibration_error=error)
}

contribution_weights = function(species_matrix) {
  x=as.matrix(species_matrix)
  if(any(!is.finite(x)) || any(x<0) || any(rowSums(x)<=0))
    stop('Species weights require finite nonnegative, nonempty community rows')
  x/rowSums(x)
}

contribution_species_matrix = function(occurrence,ids,period,species) {
  if(anyDuplicated(ids$plot_id) || anyNA(ids[c('site','plot_id')]) ||
     anyNA(occurrence[c('site','plot_id','period','species','occurrence')]) ||
     any(!occurrence$occurrence %in% 0:1)) stop('Invalid occurrence identities or binary values')
  selected=occurrence |>
    dplyr::filter(.data$period==.env$period,.data$species %in% .env$species) |>
    dplyr::inner_join(ids,by=c('site','plot_id'),relationship='many-to-one') |>
    dplyr::group_by(site,plot_id,species) |>
    dplyr::summarize(occurrence=as.integer(any(occurrence>0)),.groups='drop')
  if(!setequal(selected$plot_id,ids$plot_id)) stop('Missing eligible occurrence records: ',period)
  x=matrix(0,nrow(ids),length(species),dimnames=list(ids$plot_id,species))
  x[cbind(match(selected$plot_id,ids$plot_id),match(selected$species,species))]=selected$occurrence
  if(any(rowSums(x)==0)) stop('Eligible sample lacks retained species: ',period)
  x
}

contribution_bin_weights = function(draws,sample_ids,weights,realizations) {
  keys=c('site','lake','draw','offset','bin_mid')
  if(anyDuplicated(draws[c('lake','plot_id','draw')]) || any(!is.finite(draws$age)) ||
     !identical(rownames(weights),sample_ids$plot_id) ||
     any(realizations$age_hi-realizations$age_lo!=1000)) stop('Invalid chronology or bin-weight inputs')
  samples=draws |> dplyr::inner_join(sample_ids,by='plot_id',relationship='many-to-one')
  if(!setequal(samples$plot_id,sample_ids$plot_id)) stop('Chronology missing eligible paleo samples')
  runs=tidyr::expand_grid(offset=seq(0,900,100),samples) |>
    dplyr::mutate(bin_mid=floor((age-offset)/1000)*1000+offset+500)
  bins=runs |> dplyr::distinct(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::mutate(bin_id=dplyr::row_number())
  runs=runs |> dplyr::left_join(bins,by=keys,relationship='many-to-one')
  totals=rowsum(weights[match(runs$plot_id,rownames(weights)),,drop=FALSE],
    runs$bin_id,reorder=FALSE)
  totals=totals[match(bins$bin_id,as.integer(rownames(totals))),,drop=FALSE]
  bins$n_samples=tabulate(runs$bin_id,nbins=nrow(bins))
  # Average normalized sample weights, NEVER normalize pooled bin occurrences.
  means=totals/bins$n_samples
  bins=dplyr::bind_cols(bins,tibble::as_tibble(means,.name_repair='minimal'))
  endpoint=function(age_column) {
    d=realizations |> dplyr::select(site,lake,draw,offset,dplyr::all_of(age_column))
    names(d)[names(d)==age_column]='bin_mid'
    d=d |> dplyr::left_join(bins,by=keys,relationship='many-to-one')
    if(anyNA(d$bin_id)) stop('Missing observed endpoint bin')
    list(weights=as.matrix(d[colnames(weights)]),n_samples=d$n_samples)
  }
  first=endpoint('age_hi');last=endpoint('age_lo')
  contribution_close(first$n_samples,realizations$n_samples,'Initial bin sample counts',tolerance=.5)
  contribution_close(last$n_samples,realizations$n_samples_2,'Final bin sample counts',tolerance=.5)
  list(first=first$weights,last=last$weights,bins=bins)
}

contribution_context = function(x,era) {
  if(era=='Holocene') {
    x |> dplyr::transmute(era=.env$era,site,lake,plot_id=NA_character_,draw,offset,
      age_hi,age_lo,interval_mid_cal_bp=(age_hi+age_lo)/2,
      vegetation_dt_years,climate_dt_years,n_samples_t1=n_samples,n_samples_t2=n_samples_2)
  } else if(era=='Anthropocene') {
    x |> dplyr::transmute(era=.env$era,site,lake=NA_character_,plot_id,
      draw=NA_integer_,offset=NA_real_,age_hi=NA_real_,age_lo=NA_real_,interval_mid_cal_bp=NA_real_,
      vegetation_dt_years,climate_dt_years,n_samples_t1=1L,n_samples_t2=1L)
  } else stop('Unknown contribution era')
}

# Signed scalar contribution along the reference movement in CCA1/CCA2.
contribution_project = function(x,y,ref_x,ref_y,epsilon=CCA_CONTRIBUTION_EPSILON) {
  if(length(x)!=length(y) || length(x)!=length(ref_x) || length(x)!=length(ref_y) ||
     any(!is.finite(x)) || any(!is.finite(y))) stop('Invalid contribution vectors')
  length_ref=sqrt(ref_x^2+ref_y^2)
  valid=is.finite(length_ref) & length_ref>epsilon
  parallel=rep(NA_real_,length(x))
  parallel[valid]=(x[valid]*ref_x[valid]+y[valid]*ref_y[valid])/length_ref[valid]
  list(parallel=parallel,valid=valid)
}

contribution_species = function(context,first,last,positions,endpoints) {
  if(!identical(dim(first),dim(last)) || !identical(colnames(first),rownames(positions)) ||
     nrow(first)!=nrow(context) || any(!is.finite(first)) || any(!is.finite(last)))
    stop('Incompatible species endpoint weights')
  change=last-first
  n_species=ncol(first)
  index=rep(seq_len(nrow(context)),each=n_species)
  species_index=rep(seq_len(n_species),times=nrow(context))
  delta=as.vector(t(change))
  x=delta*positions[species_index,1];y=delta*positions[species_index,2]
  projection=contribution_project(x,y,
    endpoints$delta_predicted_CCA1[index],endpoints$delta_predicted_CCA2[index])
  dplyr::bind_cols(context[index,],tibble::tibble(species=rownames(positions)[species_index],
    weight_t1=as.vector(t(first)),weight_t2=as.vector(t(last)),weight_change=delta,
    contribution_CCA1=x,contribution_CCA2=y,
    parallel_contribution=projection$parallel,
    reference_direction_valid=projection$valid))
}

contribution_climate = function(context,endpoints,reference) {
  vars=reference$climate_variables
  first=as.data.frame(endpoints[vars]);last=as.data.frame(endpoints[paste0(vars,'_2')])
  names(last)=vars
  predict_lc=function(data) stats::predict(reference$model,newdata=data,type='lc',
    scaling='sites',hill=FALSE)[,1:2,drop=FALSE]
  initial=predict_lc(first);final=predict_lc(last)
  contribution_close(initial,as.matrix(endpoints[c('p1','p2')]),'Stored initial LC endpoints')
  contribution_close(final,as.matrix(endpoints[c('p1_2','p2_2')]),'Stored final LC endpoints')
  pieces=lapply(vars,function(variable) {
    changed=first;changed[[variable]]=last[[variable]]
    value_first=first[[variable]];value_last=last[[variable]]
    vector=predict_lc(changed)-initial
    projection=contribution_project(vector[,1],vector[,2],
      endpoints$delta_observed_CCA1,endpoints$delta_observed_CCA2)
    dplyr::bind_cols(context,tibble::tibble(variable,
      value_t1=value_first,value_t2=value_last,value_change=value_last-value_first,
      physical_unit=unname(reference$climate_units[variable]),
      contribution_CCA1=vector[,1],contribution_CCA2=vector[,2],
      parallel_contribution=projection$parallel,
      reference_direction_valid=projection$valid))
  })
  dplyr::bind_rows(pieces)
}

contribution_key = function(x) {
  ifelse(x$era=='Holocene',paste('H',x$site,x$lake,x$draw,x$offset,x$age_hi,x$age_lo,sep='|'),
    paste('A',x$site,x$plot_id,sep='|'))
}

contribution_validate = function(species,climate,context,endpoints,positions,first,last) {
  key=contribution_key(context)
  if(anyDuplicated(key) || anyDuplicated(paste(contribution_key(species),species$species)) ||
     anyDuplicated(paste(contribution_key(climate),climate$variable)) ||
     nrow(species)!=nrow(context)*nrow(positions) || nrow(climate)!=nrow(context)*4L ||
     any(!is.finite(context$vegetation_dt_years) | context$vegetation_dt_years<=0) ||
     any(!is.finite(context$climate_dt_years) | context$climate_dt_years<=0))
    stop('Invalid contribution keys, row counts or elapsed times')
  raw_sum=function(data,fields) {
    x=rowsum(as.matrix(data[fields]),match(contribution_key(data),key),reorder=FALSE)
    x[match(seq_along(key),as.integer(rownames(x))),,drop=FALSE]
  }
  observed=as.matrix(endpoints[c('delta_observed_CCA1','delta_observed_CCA2')])
  predicted=as.matrix(endpoints[c('delta_predicted_CCA1','delta_predicted_CCA2')])
  fields=c('contribution_CCA1','contribution_CCA2')
  sum_species=raw_sum(species,fields);sum_climate=raw_sum(climate,fields)
  contribution_close(sum_species,observed,'Species vectors sum to Delta WA')
  contribution_close(sum_climate,predicted,'Climate-variable vectors sum to Delta LC')
  contribution_close((last-first)%*%positions,observed,'Independent weight-matrix displacement')
  # Independent direct-coefficient LC identity is checked by the caller/test.
  contribution_close(rowSums(first),rep(1,nrow(first)),'Initial relative-weight sums')
  contribution_close(rowSums(last),rep(1,nrow(last)),'Final relative-weight sums')
  project_check=function(data,total,reference_vector) {
    valid=sqrt(rowSums(reference_vector^2))>CCA_CONTRIBUTION_EPSILON
    summed=raw_sum(dplyr::mutate(data,
      parallel_contribution=dplyr::coalesce(parallel_contribution,0)),
      'parallel_contribution')[,1]
    target=contribution_project(total[,1],total[,2],reference_vector[,1],reference_vector[,2])
    contribution_close(summed[valid],target$parallel[valid],'Parallel contribution additivity')
    group=match(contribution_key(data),key)
    if(any(data$reference_direction_valid!=valid[group]) ||
       any(!is.na(data$parallel_contribution[!valid[group]])))
      stop('Undefined reference directions were assigned contributions')
    list(valid=valid,error=ifelse(valid,abs(summed-target$parallel),NA_real_))
  }
  s=project_check(species,sum_species,predicted);c=project_check(climate,sum_climate,observed)
  dplyr::bind_cols(context,tibble::tibble(
    species_sum_abs_error=apply(abs(sum_species-observed),1,max),
    climate_sum_abs_error=apply(abs(sum_climate-predicted),1,max),
    species_projection_abs_error=s$error,climate_projection_abs_error=c$error,
    climate_direction_valid=s$valid,observed_direction_valid=c$valid))
}

contribution_measure_names = function(type) {
  measures=c('contribution_CCA1','contribution_CCA2','parallel_contribution')
  if(type=='species') c(measures,'weight_change') else if(type=='climate') measures else
    stop('Unknown contribution type')
}
contribution_component_name = function(type) if(type=='species') 'species' else 'variable'
contribution_stat = function(x,fun,...) {
  x=x[is.finite(x)]
  if(!length(x) || (identical(fun,stats::sd) && length(x)<2L)) NA_real_ else fun(x,...)
}
contribution_distribution = function(values,keys,n_expected) {
  values |> dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::summarize(mean=contribution_stat(value,mean),sd=contribution_stat(value,stats::sd),
      median=contribution_stat(value,stats::median),
      q025=contribution_stat(value,stats::quantile,probs=.025,names=FALSE),
      q975=contribution_stat(value,stats::quantile,probs=.975,names=FALSE),
      n_expected_draws=n_expected,n_present_draws=dplyr::n_distinct(draw),
      n_eligible_draws=sum(eligible),n_valid_draws=sum(eligible & is.finite(value)),
      .groups='drop') |>
    dplyr::mutate(n_missing_draws=n_expected_draws-n_present_draws,
      n_undefined_draws=n_eligible_draws-n_valid_draws)
}

contribution_summaries = function(data,type,n_expected=100L) {
  component=contribution_component_name(type)
  keys=c('site','lake','offset','age_hi','age_lo',component,'measure','sampling_rule')
  values=data |> dplyr::filter(era=='Holocene') |>
    dplyr::select(site,lake,draw,offset,age_hi,age_lo,n_samples_t1,n_samples_t2,
      dplyr::all_of(c(component,contribution_measure_names(type)))) |>
    tidyr::pivot_longer(dplyr::all_of(contribution_measure_names(type)),names_to='measure',values_to='value')
  rules=dplyr::bind_rows(dplyr::mutate(values,sampling_rule='all',eligible=TRUE),
    dplyr::mutate(values,sampling_rule='nmin2',eligible=n_samples_t1>=2 & n_samples_t2>=2)) |>
    dplyr::mutate(value=dplyr::if_else(eligible,value,NA_real_))
  uncertainty=contribution_distribution(rules,keys,n_expected)
  # Whole draws stay together when summarizing the trajectory. Each offset
  # contains non-overlapping transitions; offsets are never pooled as replicates.
  draw_lake=rules |> dplyr::group_by(dplyr::across(dplyr::all_of(
    c('site','lake','draw','offset',component,'measure','sampling_rule')))) |>
    dplyr::summarize(n_present_transitions=dplyr::n(),n_eligible_transitions=sum(eligible),
      n_valid_transitions=sum(is.finite(value)),value=contribution_stat(value,mean),
      eligible=any(eligible),.groups='drop')
  offset_keys=c('site','lake','offset',component,'measure','sampling_rule')
  support=draw_lake |> dplyr::group_by(dplyr::across(dplyr::all_of(offset_keys))) |>
    dplyr::summarize(min_present_transitions=min(n_present_transitions),
      max_present_transitions=max(n_present_transitions),
      min_valid_transitions=min(n_valid_transitions),max_valid_transitions=max(n_valid_transitions),.groups='drop')
  offset_summary=contribution_distribution(draw_lake,offset_keys,n_expected) |>
    dplyr::left_join(support,by=offset_keys,relationship='one-to-one')
  # Park summaries give equal weight to available lake trajectory means within
  # each whole draw; lake support is explicit. Modern plots enter once each.
  site_draw=draw_lake |> dplyr::group_by(dplyr::across(dplyr::all_of(
    c('site','draw','offset',component,'measure','sampling_rule')))) |>
    dplyr::summarize(n_lakes_present=dplyr::n_distinct(lake),n_lakes_valid=sum(is.finite(value)),
      value=contribution_stat(value,mean),eligible=any(eligible),.groups='drop')
  site_keys=c('site','offset',component,'measure','sampling_rule')
  site_support=site_draw |> dplyr::group_by(dplyr::across(dplyr::all_of(site_keys))) |>
    dplyr::summarize(n_lakes_present=max(n_lakes_present),
      min_valid_lakes=min(n_lakes_valid),max_valid_lakes=max(n_lakes_valid),.groups='drop')
  holocene_site=contribution_distribution(site_draw,site_keys,n_expected) |>
    dplyr::left_join(site_support,by=site_keys,relationship='one-to-one') |>
    dplyr::mutate(era='Holocene',estimate=median,n_plots=NA_integer_,n_valid_plots=NA_integer_,
      uncertainty='Bacon-draw percentiles of equal-lake trajectory means; conditional on available transitions')
  modern=data |> dplyr::filter(era=='Anthropocene') |>
    dplyr::select(site,plot_id,dplyr::all_of(c(component,contribution_measure_names(type)))) |>
    tidyr::pivot_longer(dplyr::all_of(contribution_measure_names(type)),names_to='measure',values_to='value') |>
    dplyr::group_by(site,dplyr::across(dplyr::all_of(component)),measure) |>
    dplyr::summarize(estimate=contribution_stat(value,mean),n_plots=dplyr::n_distinct(plot_id),
      n_valid_plots=sum(is.finite(value)),sd=contribution_stat(value,stats::sd),.groups='drop') |>
    dplyr::mutate(era='Anthropocene',offset=NA_real_,sampling_rule='all',
      uncertainty='Descriptive plot mean; no model confidence interval')
  list(uncertainty=uncertainty,offset_summary=offset_summary,
    era_site=dplyr::bind_rows(holocene_site,modern))
}

# Each Holocene boxplot observation is one actual transition's draw median.
# Draws are summarized response by response; modern plots enter once each.
# Offsets remain separate sensitivity pages, never a pooled boxplot sample.
contribution_boxplot_values = function(data,uncertainty,type) {
  component=contribution_component_name(type)
  measures='parallel_contribution'
  holocene=uncertainty |> dplyr::filter(sampling_rule=='all',measure %in% measures) |>
    dplyr::transmute(era='Holocene',site,lake,plot_id=NA_character_,offset,age_hi,age_lo,
      dplyr::across(dplyr::all_of(component)),measure,value=median,
      n_expected_draws,n_present_draws,n_valid_draws,n_undefined_draws)
  modern=data |> dplyr::filter(era=='Anthropocene') |>
    dplyr::select(site,plot_id,dplyr::all_of(c(component,measures))) |>
    tidyr::pivot_longer(dplyr::all_of(measures),names_to='measure',values_to='value') |>
    dplyr::mutate(era='Anthropocene',lake=NA_character_,offset=NA_real_,
      age_hi=NA_real_,age_lo=NA_real_,n_expected_draws=NA_integer_,
      n_present_draws=NA_integer_,n_valid_draws=NA_integer_,n_undefined_draws=NA_integer_)
  values=dplyr::bind_rows(holocene,modern)
  keys=ifelse(values$era=='Holocene',
    paste('H',values$site,values$lake,values$offset,values$age_hi,values$age_lo),
    paste('A',values$site,values$plot_id))
  if(anyDuplicated(paste(keys,values[[component]],values$measure)))
    stop('Duplicate transition or plot in boxplot values')
  values
}

contribution_boxplot = function(values,type,offset,reference) {
  component=contribution_component_name(type)
  data=values |> dplyr::filter(era=='Anthropocene' | .data$offset==.env$offset,
    is.finite(value)) |>
    dplyr::mutate(era=factor(era,levels=c('Holocene','Anthropocene')),
      site=factor(site,levels=c('MORA','NOCA')))
  labels=if(type=='species') stats::setNames(reference$retained_species,reference$retained_species) else
    reference$climate_labels[reference$climate_variables]
  data$component=factor(data[[component]],levels=rev(names(labels)),labels=rev(unname(labels)))
  # The same raw-contribution limits on every page permit offset comparisons.
  limits=range(values$value[is.finite(values$value)],0)
  if(diff(limits)==0) limits=c(-1,1)
  reference_label=if(type=='species') 'Species contributions along climate-predicted movement' else
    'Climate-variable contributions along observed community movement'
  ggplot2::ggplot(data,ggplot2::aes(x=value,y=component,fill=era,color=era))+
    ggplot2::geom_vline(xintercept=0,color='grey55',linetype='dashed',linewidth=.5)+
    ggplot2::geom_boxplot(orientation='y',position=ggplot2::position_dodge2(width=.8,preserve='single'),
      width=.7,linewidth=.7,alpha=.3,outlier.alpha=.25,outlier.size=.8)+
    ggplot2::facet_wrap(~site,nrow=1)+
    ggplot2::scale_fill_manual(values=c(Holocene='#36998c',Anthropocene='#d87934'))+
    ggplot2::scale_color_manual(values=c(Holocene='#36998c',Anthropocene='#d87934'))+
    ggplot2::coord_cartesian(xlim=limits)+
    ggplot2::labs(title=reference_label,
      subtitle=paste('Offset',offset,'• Holocene: transition medians across valid Bacon draws; Anthropocene: individual plots'),
      x='Parallel contribution (CCA units)',y=NULL,fill=NULL,color=NULL,
      caption='Boxes: median and quartiles; whiskers: 1.5 × IQR. Undefined projections omitted; zero contributions retained. Descriptive distributions.')+
    ggplot2::theme_minimal(base_size=20)+ggplot2::theme(panel.grid.minor=ggplot2::element_blank(),
      panel.grid.major.y=ggplot2::element_blank(),axis.text=ggplot2::element_text(size=17),
      axis.text.y=ggplot2::element_text(face=if(type=='species') 'italic' else 'plain'),
      strip.text=ggplot2::element_text(size=20,face='bold'),legend.position='bottom',
      plot.title=ggplot2::element_text(size=23,face='bold'),
      plot.subtitle=ggplot2::element_text(size=14),plot.caption=ggplot2::element_text(size=12,hjust=0))
}
