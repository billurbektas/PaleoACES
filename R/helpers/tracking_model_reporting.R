# Labels shared by primary model figures.
source(here::here('R/helpers/tracking_result_paths.R'),local=TRUE)
# Labels for model diagnostics, keyed by the PLAN.md response names.
tracking_model_response_label=function(metric) unname(c(lag_rate='Lag rate',lag='Lag',turnover_rate='Turnover rate',
  climate_rate='Climate change rate',pace_effect='Pace effect',direction_effect='Direction effect',
  Pace='Pace effect',Direction='Direction effect')[metric])
# Period types of the era models (PLAN.md section 2), in model order.
ERA_PERIOD_TYPES=c('Holocene-S','Holocene-C','Anthropocene')
# The era-model responses (PLAN.md Step 5a), with their axis labels and units.
ERA_RESPONSES=c(climate_rate='Standardized climate change rate per century',
  turnover_rate='Turnover rate (CCA distance per century)',lag_rate='Lag rate (CCA distance per century)',
  lag='Lag (CCA distance)',
  pace_effect='Pace effect (CCA distance per century)',direction_effect='Direction effect (CCA distance per century)')

# Paired outcomes on each unit need their own covariance: stacking the two
# corrections as independent observations would give incorrect contrasts. The
# separable correlation is AR(1) on the unit order within a series (PLAN.md row
# 7) times a two-outcome correlation, estimated separately for each era x park
# (Holocene or Anthropocene): a lake's series mixes C and S lake-periods, and
# one series needs one outcome correlation for the matrix to stay positive
# definite. An Anthropocene plot is a series of one unit with two outcomes.
corPairedAR1=function(groups,value=c(.05,rep(0,length(groups))),form=~unit_index | series,fixed=FALSE) {
  if(length(value)!=length(groups)+1L || any(!is.finite(value)) || any(abs(value)>=1))
    stop('Paired AR(1) requires one finite AR parameter and one correlation per group, all strictly between -1 and 1')
  structure(atanh(value),class=c('corPairedAR1','corStruct'),formula=form,fixed=fixed,
    parameter_names=c('AR1',groups))
}
coef.corPairedAR1=function(object,unconstrained=TRUE,...) {
  if(unconstrained) {
    if(isTRUE(attr(object,'fixed'))) numeric(0) else as.vector(object)
  } else setNames(tanh(as.vector(object)),attr(object,'parameter_names'))
}
Initialize.corPairedAR1=function(object,data,...) {
  object=NextMethod()
  groups=as.character(nlme::getGroups(object))
  attr(object,'blocks')=lapply(unique(groups),function(g) {
    d=data[groups==g,]
    # gls passes only model variables here, so the era is read from period_type.
    group=unique(paste(ifelse(as.character(d$period_type)=='Anthropocene','Anthropocene','Holocene'),d$site))
    if(length(group)!=1L || anyDuplicated(d[c('unit_index','correction')]))
      stop('Paired covariance needs unique correction x unit rows within one era x park series')
    if(!group %in% attr(object,'parameter_names')) stop('Unknown paired-correlation group: ',group)
    list(time=d$unit_index,correction=as.integer(d$correction),group=group)
  })
  attr(object,'factor')=nlme::corFactor(object)
  attr(object,'logDet')=nlme::logDet(object)
  object
}
corMatrix.corPairedAR1=function(object,covariate=nlme::getCovariate(object),corr=TRUE,...) {
  if(!corr) return(nlme::corFactor(object))
  pars=coef(object,unconstrained=FALSE)
  lapply(attr(object,'blocks'),function(b) {
    temporal=pars[1]^abs(outer(b$time,b$time,'-'))
    same=outer(b$correction,b$correction,'==')
    temporal*ifelse(same,1,pars[[b$group]])
  })
}
registerS3method('coef','corPairedAR1',coef.corPairedAR1,envir=asNamespace('stats'))
registerS3method('Initialize','corPairedAR1',Initialize.corPairedAR1,envir=asNamespace('nlme'))
registerS3method('corMatrix','corPairedAR1',corMatrix.corPairedAR1,envir=asNamespace('nlme'))

# Pace and direction on the same units, stacked, for the joint model. Units
# where either correction is undefined leave it (epsilon rule).
tracking_joint_correction_input=function(both) {
  x=both |> dplyr::filter(is.finite(pace_effect),is.finite(direction_effect)) |>
    tidyr::pivot_longer(c(pace_effect,direction_effect),names_to='metric',values_to='estimate') |>
    dplyr::mutate(period_type=factor(period_type,levels=ERA_PERIOD_TYPES),
      site=factor(site,levels=c('MORA','NOCA')),
      correction=factor(dplyr::if_else(metric=='pace_effect','Pace','Direction'),levels=c('Pace','Direction')),
      period_type_site=interaction(period_type,site,drop=TRUE,sep=' '),
      pair_group=paste(ifelse(period_type=='Anthropocene','Anthropocene','Holocene'),site),
      period_type_site_correction=interaction(period_type,site,correction,drop=TRUE,sep=' ')) |>
    dplyr::arrange(series,unit_index,correction)
  if(nlevels(droplevels(x$period_type_site_correction))!=12L)
    stop('Joint correction model requires both corrections in all six period type x park groups')
  x
}
