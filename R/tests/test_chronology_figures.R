# Independent temporal-envelope audit: reconstruct sampled lake/date values
# directly from actual transitions in every chronology, without the plot mapper.
suppressPackageStartupMessages({library(here);library(readr);library(dplyr)})
r=read_csv(here('output/tracking_analysis/sensitivity/bacon_chronologies/community/chronology_temporal_ranges.csv'),show_col_types=FALSE)
stopifnot(!anyDuplicated(r[c('lake','century_cal_bp','metric')]),all(r$n_expected_draws==1000),
 all(r$n_valid_draws<=r$n_draws_with_transition),all(r$n_draws_with_transition<=1000),
 all(r$n_undefined_or_uncovered==r$n_draws_with_transition-r$n_valid_draws),
 all(is.na(r$median)==(r$n_valid_draws==0)))
check=r[r$century_cal_bp %in% c(10550,9050,6050,3050,50),]
expected=matrix(NA_real_,nrow(check),1000);present=matrix(FALSE,nrow(check),1000)
for(draw in 1:1000) {
 saved=readRDS(here('output/tracking_analysis/sensitivity/bacon_chronologies/community/chronology_batches',sprintf('draw_%04d.rds',draw)))
 x=saved$calculations
 for(i in seq_len(nrow(check))) {
  use=which(x$lake==check$lake[i] & x$age_lo<=check$century_cal_bp[i] & x$age_hi>check$century_cal_bp[i])
  stopifnot(length(use)<=1L)
  if(length(use)) {present[i,draw]=TRUE;expected[i,draw]=x[[check$metric[i]]][use]}
 }
}
close=function(x,y) stopifnot(identical(is.na(x),is.na(y)),
 all(abs(x[is.finite(x)]-y[is.finite(y)])<1e-9))
for(i in seq_len(nrow(check))) {
 v=expected[i,is.finite(expected[i,])]
 stopifnot(check$n_valid_draws[i]==length(v),check$n_draws_with_transition[i]==sum(present[i,]))
 q=if(length(v)) quantile(v,c(.025,.25,.5,.75,.975),names=FALSE) else rep(NA_real_,5)
 close(as.numeric(check[i,c('q025','q25','median','q75','q975')]),q)
}
cat('Bacon temporal ranges independently reconstructed from all 1,000 draw-specific transition sequences.\n')
