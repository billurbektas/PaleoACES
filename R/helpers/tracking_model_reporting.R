# Labels shared by primary model figures.
source(here::here('R/helpers/tracking_result_paths.R'),local=TRUE)
tracking_model_response_names=function() c('lag_rate_per_century','observed_turnover_rate',
  'standardized_climate_change_rate','pace_effect_on_lag_per_century','direction_effect_on_lag_per_century')
tracking_model_response_label=function(metric) unname(c(lag_rate_per_century='Observed lag change',
  observed_turnover_rate='Community turnover rate',standardized_climate_change_rate='Standardized climate change per century',
  pace_effect_on_lag_per_century='Pace correction effect',direction_effect_on_lag_per_century='Direction correction effect')[metric])
tracking_model_response_unit=function(metric) if(metric=='standardized_climate_change_rate')
  'Standardized climate change per century' else 'CCA distance per century'

# Paired outcomes on each transition need their own covariance: stacking the
# two corrections as independent observations would give incorrect contrasts.
# The separable correlation is MA(1) on the original transition indices times
# a two-outcome correlation, estimated separately in each era × park group.
# A modern plot is a singleton temporal series with two paired outcomes.
corPairedMA1=function(value=c(.05,0,0,0,0),form=~time_index | series,fixed=FALSE) {
  if(length(value)!=5L || any(!is.finite(value)) || any(abs(value)>=1))
    stop('Paired MA(1) requires five finite parameters strictly between -1 and 1')
  structure(atanh(value),class=c('corPairedMA1','corStruct'),formula=form,fixed=fixed,
    parameter_names=c('MA1','Holocene.MORA','Anthropocene.MORA','Holocene.NOCA','Anthropocene.NOCA'))
}
coef.corPairedMA1=function(object,unconstrained=TRUE,...) {
  if(unconstrained) {
    if(isTRUE(attr(object,'fixed'))) numeric(0) else as.vector(object)
  } else setNames(tanh(as.vector(object)),attr(object,'parameter_names'))
}
Initialize.corPairedMA1=function(object,data,...) {
  object=NextMethod()
  groups=as.character(nlme::getGroups(object))
  attr(object,'blocks')=lapply(unique(groups),function(g) {
    d=data[groups==g,]
    group=unique(as.character(interaction(d$era,d$site,drop=TRUE)))
    if(length(group)!=1L || anyDuplicated(d[c('time_index','correction')]))
      stop('Paired covariance needs unique correction × time rows within one era × park series')
    list(time=d$time_index,correction=as.integer(d$correction),era_site=group)
  })
  attr(object,'factor')=nlme::corFactor(object)
  attr(object,'logDet')=nlme::logDet(object)
  object
}
corMatrix.corPairedMA1=function(object,covariate=nlme::getCovariate(object),corr=TRUE,...) {
  if(!corr) return(nlme::corFactor(object))
  pars=coef(object,unconstrained=FALSE)
  adjacent=pars[1]/(1+pars[1]^2)
  lapply(attr(object,'blocks'),function(b) {
    lag=abs(outer(b$time,b$time,'-'))
    temporal=ifelse(lag==0,1,ifelse(lag==1,adjacent,0))
    same=outer(b$correction,b$correction,'==')
    temporal*ifelse(same,1,pars[[b$era_site]])
  })
}
registerS3method('coef','corPairedMA1',coef.corPairedMA1,envir=asNamespace('stats'))
registerS3method('Initialize','corPairedMA1',Initialize.corPairedMA1,envir=asNamespace('nlme'))
registerS3method('corMatrix','corPairedMA1',corMatrix.corPairedMA1,envir=asNamespace('nlme'))

tracking_joint_correction_input=function(combined) {
  x=dplyr::filter(combined,metric %in% c('pace_effect_on_lag_per_century',
    'direction_effect_on_lag_per_century'))
  keys=c('era','site','transition_id')
  if(anyDuplicated(x[c(keys,'metric')])) stop('Duplicate correction response on a transition')
  pairs=x |> dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::summarise(paired=dplyr::n()==2L && all(is.finite(estimate)),.groups='drop')
  x=x |> dplyr::left_join(pairs,by=keys,relationship='many-to-one') |>
    dplyr::mutate(era=factor(era,levels=c('Holocene','Anthropocene')),
      site=factor(site,levels=c('MORA','NOCA')),
      correction=factor(dplyr::if_else(metric=='pace_effect_on_lag_per_century',
        'Pace','Direction'),levels=c('Pace','Direction')),
      era_site=interaction(era,site,drop=TRUE),
      era_site_correction=interaction(era,site,correction,drop=TRUE))
  d=dplyr::filter(x,paired) |> dplyr::arrange(series,time_index,correction)
  if(nlevels(droplevels(d$era_site_correction))!=8L)
    stop('Joint correction model requires both corrections in all four era × park groups')
  list(data=d,excluded=dplyr::filter(x,!paired) |>
    dplyr::mutate(exclusion='one_or_both_corrections_undefined'))
}
