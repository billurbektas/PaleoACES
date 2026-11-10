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


century_contribution_context = function(x,era) {
  x$era=era
  if(era=='Holocene') x$plot_id=NA_character_ else x$lake=NA_character_
  x |>
    dplyr::select(era,site,lake,plot_id,dplyr::any_of(c('transition_id','transition_index','draw',
      'age_hi','age_lo','interval_mid_cal_bp','vegetation_dt_years','climate_dt_years',
      'standardized_climate_change_rate','fire_activity','fire_coverage_valid','burned')))
}
century_species_contributions = function(reconstruction,bundle) {
  basis=contribution_reference(bundle$reference)
  use=bundle$samples$eligible
  sample_weights=contribution_weights(bundle$species_matrix[use,,drop=FALSE])
  a=reconstruction$assignments |> dplyr::filter(is.finite(century_cal_bp))
  keys=paste(a$lake,a$century_cal_bp)
  groups=unique(keys)
  means=rowsum(sample_weights[match(a$sample_id,rownames(sample_weights)),,drop=FALSE],
    keys,reorder=FALSE)/as.numeric(table(factor(keys,levels=groups)))
  x=reconstruction$calculations
  first=means[match(paste(x$lake,x$age_hi),groups),,drop=FALSE]
  last=means[match(paste(x$lake,x$age_lo),groups),,drop=FALSE]
  contribution_close((last-first)%*%basis$positions,
    as.matrix(x[c('delta_observed_CCA1','delta_observed_CCA2')]),'Every transition species-vector conservation')
  context=century_contribution_context(x,'Holocene')
  result=contribution_species(context,first,last,basis$positions,x)
  result$contribution_rate=result$parallel_contribution*100/result$vegetation_dt_years
  result
}
century_climate_contributions = function(context,x,reference) {
  result=contribution_climate(context,x,reference)
  sum_vectors=rowsum(as.matrix(result[c('contribution_CCA1','contribution_CCA2')]),
    rep(seq_len(nrow(x)),times=length(reference$climate_variables)),reorder=FALSE)
  contribution_close(sum_vectors,as.matrix(x[c('delta_predicted_CCA1','delta_predicted_CCA2')]),
    'Every transition seasonal-climate vector conservation')
  result
}

# Mean relative species weights of each lake and sampled century: each sample's
# weights are normalized first, then averaged, as the WA centroid is.
century_species_weights = function(reconstruction, bundle) {
  use = bundle$samples$eligible
  sample_weights = contribution_weights(bundle$species_matrix[use, , drop = FALSE])
  a = reconstruction$assignments |> dplyr::filter(is.finite(century_cal_bp))
  keys = paste(a$lake, a$century_cal_bp)
  groups = unique(keys)
  means = rowsum(sample_weights[match(a$sample_id, rownames(sample_weights)), , drop = FALSE],
    keys, reorder = FALSE) / as.numeric(table(factor(keys, levels = groups)))
  rownames(means) = groups
  means
}

# Step 6 (PLAN.md): each species' vector is its change in share between t1 and
# t2 times its fixed CCA position. The vectors add up to the observed movement.
# Two measures, per century: the projection on the direction the prediction
# moved (contrib_climate) and on the initial mismatch, LC_t1 - WA_t1
# (contrib_gap). Undefined where the reference vector has no length, and, by
# the epsilon rule, where the observed or predicted position did not move.
step6_species_contributions = function(context, first, last, positions, endpoints, dt) {
  rows = contribution_species(context, first, last, positions, endpoints)
  contribution_close((last - first) %*% positions,
    as.matrix(endpoints[c('delta_observed_CCA1', 'delta_observed_CCA2')]), 'Species vectors sum to dWA')
  index = rep(seq_len(nrow(context)), each = ncol(first))
  gap = contribution_project(rows$contribution_CCA1, rows$contribution_CCA2,
    (endpoints$p1 - endpoints$o1)[index], (endpoints$p2 - endpoints$o2)[index])
  defined = endpoints$direction_defined[index]
  rows$gap_contribution = gap$parallel
  rows$gap_direction_valid = gap$valid
  rows$contrib_climate = ifelse(defined, rows$parallel_contribution * 100 / dt[index], NA_real_)
  rows$contrib_gap = ifelse(defined, rows$gap_contribution * 100 / dt[index], NA_real_)
  rows
}
