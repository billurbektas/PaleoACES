# Lake-period construction (PLAN.md sections 4 and 5, Steps 1 to 4) on a
# synthetic lake whose answers are known by hand.
suppressPackageStartupMessages({library(here); library(dplyr)})
source(here('R/helpers/config.R'), local = TRUE)
source(here('R/helpers/lake_periods.R'), local = TRUE)

periods = tibble(period = c('C1', 'S1', 'C2'), period_type = c('Holocene-C', 'Holocene-S', 'Holocene-C'),
  older_cal_bp = c(1000, 700, 400), younger_cal_bp = c(700, 400, 0))
# C1: three centuries; S1: one century (fails the two-century rule); C2: two
# centuries with an observed position that does not move (epsilon rule).
positions = tibble(site = 'MORA', lake = 'Test', century_cal_bp = c(950, 850, 750, 550, 350, 150),
  o1 = c(0, 5, 3, 9, 1, 1), o2 = c(0, 5, 4, 9, 2, 2), p1 = c(1, 0, 1, 0, 0, 2), p2 = c(0, 0, 0, 0, 0, 0),
  n_samples = c(2L, 1L, 4L, 1L, 3L, 1L))
for (v in CCA_VARIABLES) positions[[v]] = c(10, 11, 12, 13, 14, 15)
scaling = tibble(variable = CCA_VARIABLES, mean = 0, sd = 2, n_calibration = 607L, unit = 'x')
no_fire = function(intervals) list(regional = intervals |> distinct(site, age_hi, age_lo) |>
  mutate(fire_covered_cores = 1L, fire_coverage_valid = TRUE, fire_activity = 0, fire_source_ids = 'x'))

candidates = lake_period_candidates(positions, periods)
stopifnot(identical(candidates$period, c('C1', 'S1', 'C2')),
  identical(candidates$two_century_rule, c(TRUE, FALSE, TRUE)))
u = build_lake_periods(positions, periods, scaling, no_fire)
stopifnot(nrow(u) == 2L, identical(u$period, c('C1', 'C2')), identical(u$unit_index, 1:2),
  identical(u$age_start, c(950, 350)), identical(u$age_end, c(750, 150)),
  identical(u$duration_yr, c(200, 200)), all.equal(u$endpoint_var, c(1/2 + 1/4, 1/3 + 1)))
# C1 by hand: WA (0,0) -> (3,4), LC (1,0) -> (1,0).
stopifnot(all.equal(u$M_start[1], 1), all.equal(u$M_end[1], sqrt(4 + 16)),
  all.equal(u$lag_rate[1], (sqrt(20) - 1) * 100 / 200), all.equal(u$turnover_rate[1], 5 * 100 / 200),
  all.equal(u$climate_rate[1], sqrt(length(CCA_VARIABLES) * (2 / 2)^2) * 100 / 200))
# C1: the predicted position did not move, so pace and direction are undefined.
# C2: the observed position did not move, so pace and direction are undefined.
stopifnot(!u$direction_defined[1], is.na(u$pace_effect[1]), is.na(u$direction_effect[1]),
  !u$direction_defined[2], is.na(u$pace_effect[2]), is.na(u$direction_effect[2]),
  u$turnover_rate[2] == 0)
cat('Lake-period periods, two-century rule, endpoints, rates and the epsilon rule checks passed.\n')
