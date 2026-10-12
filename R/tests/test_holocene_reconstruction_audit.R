# Offline support-audit checks. Independent numerical reconstruction from raw
# posterior rows, sample WA positions and accepted-event catalogs; no file writes.
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan)})
source(here('R/helpers/config.R'))
source(here('R/helpers/holocene_reconstruction_settings.R'))
source(here('R/helpers/holocene_reconstruction.R'))
close = function(actual, expected, label, tolerance = 1e-8) {
  if (length(actual) != length(expected) || any(!is.finite(actual)) ||
      any(!is.finite(expected)) || any(abs(actual - expected) > tolerance)) stop(label)
}
fail = function(call, text) {
  x = tryCatch(call, error = identity)
  stopifnot(inherits(x, 'error'), grepl(text, conditionMessage(x), fixed = TRUE))
}
fail(require_holocene_support_policy(), 'awaiting separate occupancy')
require_holocene_support_policy(list(century_occupancy = 0, species_joint_occupancy = .5))
fail(require_holocene_support_policy(list(century_occupancy = 1.1, species_joint_occupancy = .5)), 'awaiting')

# Missing centuries, mathematical summaries and boundary assignments.
grid = tibble(site = 'MORA', lake = 'toy', century_cal_bp = seq(50, 450, 100),
              lower_cal_bp = seq(0, 400, 100), upper_cal_bp = seq(100, 500, 100))
samples = tibble(sample_id = c('a', 'b', 'c'), eligible = TRUE,
                observed_CCA1 = c(0, 2, 4), observed_CCA2 = c(0, 8, 3))
draws = tibble(site = 'MORA', lake = 'toy', draw = rep(1:3, each = 3),
              sample_id = rep(c('a', 'b', 'c'), 3),
              age_cal_bp = c(300, 350, 100, 200, 200, 100, 300, 100, 0))
assigned = reconstruction_century_assignments(draws, samples, grid)
products = reconstruction_century_products(assigned, grid, 3)
p350 = products$positions[products$positions$century_cal_bp == 350, ]
close(c(p350$observed_CCA1, p350$observed_CCA2), c(.5, 2), 'Median of within-draw WA centroids')
close(c(p350$CCA1_q025, p350$CCA1_q975, p350$CCA2_q025, p350$CCA2_q975),
      c(.025, .975, .1, 3.9), 'Quantiles use full draw distributions, not summarized coordinates')
stopifnot(p350$n_occupied_draws == 2, p350$n_draws_nmin2 == 1,
          products$positions$n_occupied_draws[products$positions$century_cal_bp == 450] == 0,
          is.na(products$positions$observed_CCA1[products$positions$century_cal_bp == 450]))
boundary = draws[rep(1, 5), ]; boundary$age_cal_bp = c(-.1, 0, 100, 499.999, 500)
boundary$draw = 1:5
b = reconstruction_century_assignments(boundary, samples, grid)
stopifnot(identical(b$century_cal_bp, c(NA_real_, 50, 150, 450, NA_real_)))
pairs = reconstruction_transition_scenarios(products$positions, products$centroids, c(0, 2/3, 1))
zero = pairs[pairs$scenario_threshold == 0 & pairs$age_hi == 350, ]
stopifnot(zero$n_joint_draws == 0, zero$n_occupied_draws_t1 == 2,
          zero$n_occupied_draws_t2 == 1)
gap = pairs[pairs$scenario_threshold == 2/3, ]
stopifnot(nrow(gap) == 1, gap$age_hi == 350, gap$age_lo == 150,
          gap$duration_years == 200, gap$n_joint_draws == 2,
          gap$n_unoccupied_centuries_between == 0, gap$n_occupied_centuries_skipped == 1)
pairs$fire_coverage_valid = TRUE
scenario = reconstruction_scenario_summary(products$positions, pairs, c(0, 2/3, 1))
empty = scenario[scenario$scenario_threshold == 1, ]
stopifnot(empty$n_scenario_centuries == 1, empty$n_candidate_transitions == 0,
          is.na(empty$joint_support_median), is.na(empty$duration_median))

# Mean of sample WA is not the WA of pooled/averaged raw composition.
composition = rbind(c(1, 0), c(1, 1))
basis = rbind(c(-1, 0), c(1, 4))
sample_wa = (composition / rowSums(composition)) %*% basis
pooled_wa = (colMeans(composition) / sum(colMeans(composition))) %*% basis
stopifnot(max(abs(colMeans(sample_wa) - pooled_wa)) > .1)

# Variable-duration fire, coverage and half-open boundary events.
series = bind_rows(tibble(site = 'MORA', lake = 'A', age_cal_yr_BP = seq(0, 500, 10)),
                   tibble(site = 'MORA', lake = 'B', age_cal_yr_BP = seq(0, 500, 10)),
                   tibble(site = 'MORA', lake = 'C', age_cal_yr_BP = seq(0, 200, 10)),
                   tibble(site = 'NOCA', lake = 'PantherPotholes', age_cal_yr_BP = seq(0, 500, 10)))
series$char_interpolated = 0
events = bind_rows(tibble(site = 'MORA', lake = 'A', age_cal_yr_BP = c(50, 150, 250)),
                  tibble(site = 'MORA', lake = 'B', age_cal_yr_BP = 75),
                  tibble(site = 'NOCA', lake = 'PantherPotholes', age_cal_yr_BP = c(0, 99.999, 100, 200)))
intervals = tibble(site = c('MORA', 'MORA', 'MORA', 'NOCA', 'NOCA'),
                  age_lo = c(0, 300, 400, 0, 100), age_hi = c(300, 400, 600, 100, 200))
fire = reconstruction_transition_fire(intervals, events, series)$regional
fire_row = function(site, lo) fire[fire$site == site & fire$age_lo == lo, ]
close(fire_row('MORA', 0)$fire_activity, 2/3, 'Mean per-core events per century over 300 years')
stopifnot(fire_row('MORA', 0)$fire_covered_cores == 2, fire_row('MORA', 300)$fire_activity == 0,
          is.na(fire_row('MORA', 400)$fire_activity), !fire_row('MORA', 400)$fire_coverage_valid,
          fire_row('NOCA', 0)$fire_activity == 2, fire_row('NOCA', 100)$fire_activity == 1)
stopifnot(nrow(reconstruction_transition_fire(bind_rows(intervals, intervals), events, series)$regional) == nrow(fire))
other = tibble(site = 'NOCA', lake = 'Other core', age_cal_yr_BP = seq(0, 500, 10), char_interpolated = 0)
extra = reconstruction_transition_fire(intervals, events, bind_rows(series, other))$regional
stopifnot(all(extra$fire_covered_cores[extra$site == 'NOCA'] == 1))
fail(reconstruction_transition_fire(intervals, events, series[-2, ]), 'internal coverage gaps')
cat('Synthetic boundary, centroid, sparse/empty support and fire checks passed.\n')

audit = here('output/reconstruction_audit')
read = function(name) read_csv(file.path(audit, paste0(name, '.csv')), show_col_types = FALSE)
samples = read('original_samples'); centroids = read('century_draws'); positions = read('century_positions')
grid = read('native_grid'); scenarios = read('scenario_support'); pairs = read('all_transition_scenarios')
cache = readRDS(file.path(audit, 'age_draws.rds'))
stopifnot(cache$n_draws == 1000L, cache$seed == 42L,
          nrow(cache$draws) == nrow(samples) * 1000L,
          !anyDuplicated(cache$draws[c('sample_id', 'draw')]),
          all(table(cache$draws$sample_id) == 1000L),
          !anyDuplicated(samples$sample_id), !anyDuplicated(centroids[c('lake', 'draw', 'century_cal_bp')]),
          !anyDuplicated(positions[c('lake', 'century_cal_bp')]),
          !anyDuplicated(pairs[c('scenario_threshold', 'lake', 'age_hi', 'age_lo')]),
          setequal(unique(scenarios$scenario_threshold), HOLOCENE_SUPPORT_SCENARIOS))
raw_mora = readxl::read_excel(here('data/PALEO/DunwiddieMacrofossils.xlsx'), sheet = 'MacrofossilData')
stopifnot(nrow(distinct(raw_mora, Location, Depth)) == sum(samples$site == 'MORA'))
noca_header = names(read_csv(here('data/NOCA/NOCA_paleo/dataset52207_site13042.csv'), n_max = 0, show_col_types = FALSE))
stopifnot(length(setdiff(noca_header, c('name', 'group', 'element', 'units', 'context'))) == sum(samples$site == 'NOCA'))

# Independently rebuild every sample age from the actual selected posterior rows
# and accumulation sections. No Bacon draw/evaluation helper is called here.
for (core in unique(samples$lake)) {
  rows = cache$posterior_rows[cache$posterior_rows$lake == core, ]
  stopifnot(!anyDuplicated(rows$posterior_row), identical(rows$draw, 1:1000))
  raw = as.matrix(read.table(here(unique(rows$source))))
  raw = raw[rows$posterior_row, -ncol(raw), drop = FALSE]
  evaluator = cache$depth_evaluation[cache$depth_evaluation$lake == core, ]
  for (i in seq_len(nrow(evaluator))) {
    v = evaluator[i, ]; section = v$section_index
    prior = if (section == 1) rep(0, nrow(raw)) else rowSums(raw[, 2:section, drop = FALSE])
    expected = raw[, 1] + v$thickness_cm * prior +
      (v$slump_adjusted_depth_cm - v$section_start_cm) * raw[, section + 1]
    stored = cache$draws$age_cal_bp[cache$draws$sample_id == v$sample_id]
    close(stored, expected, paste('Raw-posterior age reconstruction:', v$sample_id))
  }
}
cat('Every original-sample age reconstructed from its selected raw posterior row.\n')

# Independently assign ages and sum original sample WA by draw/century.
ids = match(cache$draws$sample_id, samples$sample_id)
use = samples$eligible[ids]
d = cache$draws[use, ]; ids = ids[use]
age = floor(d$age_cal_bp / 100) * 100 + 50
within = paste(d$lake, age) %in% paste(grid$lake, grid$century_cal_bp)
d = d[within, ]; ids = ids[within]; age = age[within]
keys = paste(d$lake, d$draw, age)
groups = unique(keys)
counts = tabulate(match(keys, groups))
sums = rowsum(as.matrix(samples[ids, c('observed_CCA1', 'observed_CCA2')]), keys, reorder = FALSE)
means = sums / counts
index = match(paste(centroids$lake, centroids$draw, centroids$century_cal_bp), groups)
stopifnot(!anyNA(index), length(groups) == nrow(centroids), all(centroids$n_samples == counts[index]))
close(as.matrix(centroids[c('observed_CCA1', 'observed_CCA2')]), means[index, ], 'Independent sample-WA centroids')
stopifnot(sum(centroids$n_samples) == nrow(d),
          nrow(cache$draws[use, ]) - nrow(d) == nrow(read('sample_draw_exclusions')))
for (i in seq_len(nrow(positions))) {
  p = positions[i, ]; z = centroids[centroids$lake == p$lake & centroids$century_cal_bp == p$century_cal_bp, ]
  stopifnot(nrow(z) == p$n_occupied_draws, p$occupancy_proportion == nrow(z)/1000,
            sum(z$n_samples >= 2) == p$n_draws_nmin2)
  if (nrow(z)) {
    close(c(p$observed_CCA1, p$observed_CCA2),
          c(median(z$observed_CCA1), median(z$observed_CCA2)), 'Reconstructed coordinate medians')
    close(c(p$CCA1_q025, p$CCA1_q975, p$CCA2_q025, p$CCA2_q975),
      c(quantile(z$observed_CCA1, c(.025, .975)), quantile(z$observed_CCA2, c(.025, .975))), 'Coordinate quantiles')
  } else stopifnot(is.na(p$observed_CCA1), is.na(p$observed_CCA2))
}
occupancy = read('occupancy_summary')
for (i in seq_len(nrow(occupancy))) {
  o = occupancy[i, ]; p = positions[positions$lake == o$lake, ]
  stopifnot(nrow(p) == o$n_native_centuries, sum(p$occupied) == o$n_occupied_centuries,
            sum(!p$occupied) == o$n_empty_centuries)
  x = p$occupancy_proportion[p$occupied]
  close(c(o$occupancy_q025, o$occupancy_q25, o$occupancy_median, o$occupancy_q75, o$occupancy_q975),
        quantile(x, c(.025, .25, .5, .75, .975)), 'Occupancy distribution')
}
cat('Every occupied centroid, reconstructed coordinate and support count checked.\n')

presence = table(centroids$draw, paste(centroids$lake, centroids$century_cal_bp)) > 0
for (i in seq_len(nrow(pairs))) {
  p = pairs[i, ]; first = presence[, paste(p$lake, p$age_hi)]; last = presence[, paste(p$lake, p$age_lo)]
  stopifnot(sum(first & last) == p$n_joint_draws,
            p$joint_occupancy_proportion == sum(first & last)/1000,
            p$duration_years == p$age_hi - p$age_lo,
            p$n_unoccupied_centuries_between + p$n_occupied_centuries_skipped == p$duration_years/100 - 1)
}
for (i in seq_len(nrow(scenarios))) {
  s = scenarios[i, ]; p = positions[positions$lake == s$lake & positions$occupied &
    positions$occupancy_proportion >= s$scenario_threshold, ]; ages = sort(p$century_cal_bp, decreasing = TRUE)
  z = pairs[pairs$lake == s$lake & pairs$scenario_threshold == s$scenario_threshold, ]
  stopifnot(nrow(p) == s$n_scenario_centuries, nrow(z) == max(0, nrow(p)-1),
            nrow(z) == s$n_candidate_transitions)
  if (nrow(z)) {
    stopifnot(setequal(paste(z$age_hi, z$age_lo), paste(head(ages, -1), tail(ages, -1))),
              s$n_gaps_over_100yr == sum(abs(diff(ages)) > 100))
    close(s$joint_support_median, median(z$joint_occupancy_proportion), 'Scenario joint median')
  } else stopifnot(is.na(s$joint_support_median), is.na(s$duration_median))
}
cat('All scenario pairs and joint-support distributions reconstructed independently.\n')

events = read_csv(here('output/holocene_fire_source_events.csv'), show_col_types = FALSE)
series = read_csv(here('output/holocene_fire_source_series.csv'), show_col_types = FALSE)
cores = read('fire_core_exposure'); regional = read('fire_interval_exposure')
for (i in seq_len(nrow(cores))) {
  c = cores[i, ]; z = series[series$site == c$site & series$lake == c$fire_core, ]
  covered = c$age_lo >= min(z$age_cal_yr_BP) && c$age_hi <= max(z$age_cal_yr_BP)
  stopifnot(covered == c$fully_covered)
  if (covered) {
    e = sort(events$age_cal_yr_BP[events$site == c$site & events$lake == c$fire_core])
    count = diff(findInterval(c(c$age_lo, c$age_hi), e, left.open = TRUE))
    stopifnot(count == c$accepted_event_count)
    close(c$frequency_per_century, count * 100/(c$age_hi-c$age_lo), 'Fire frequency')
  } else stopifnot(is.na(c$accepted_event_count), is.na(c$frequency_per_century))
}
for (i in seq_len(nrow(regional))) {
  r = regional[i, ]; c = cores[cores$site == r$site & cores$age_hi == r$age_hi & cores$age_lo == r$age_lo, ]
  n = sum(c$fully_covered); required = if (r$site == 'MORA') 2 else 1
  stopifnot(r$fire_covered_cores == n, r$fire_coverage_valid == (n >= required))
  if (n >= required) close(r$fire_activity, mean(c$frequency_per_century[c$fully_covered]), 'Equal-core regional fire activity')
  else stopifnot(is.na(r$fire_activity))
}
cat('Full-window accepted-event frequencies and coverage verified.\n')

figures = reconstruction_support_plots(positions, pairs, scenarios)
for (item in c('occupancy_histogram', 'joint_histogram', 'duration_histogram')) {
  z = ggplot_build(figures[[item]])$data[[1]]
  plotted = as.numeric(tapply(z$count, z$PANEL, sum))
  expected = if (item == 'occupancy_histogram') table(factor(positions$lake[positions$occupied],
    levels = c('JayBath', 'LogWallow', 'ReflectionPond', 'PantherPotholes'))) else
    table(factor(pairs$lake[pairs$scenario_threshold == 0],
      levels = c('JayBath', 'LogWallow', 'ReflectionPond', 'PantherPotholes')))
  close(plotted, as.numeric(expected), paste('Histogram observation counts:', item))
}
preservation = read('preservation')
stopifnot(all(preservation$unchanged),
          all(unname(tools::md5sum(here(preservation$path))) == preservation$md5_before),
          all(read('validation')$passed))
cat(nrow(preservation), 'protected files unchanged. Support audit checks passed.\n')
