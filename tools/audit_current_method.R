# Reproduce the current method independently; no new models or sensitivities.
# Run in the isolated audit checkout, after its cached workflow:
#   Rscript tools/audit_current_method.R
suppressPackageStartupMessages({library(here); library(readr); library(readxl)})
options(paleoaces.render_figures = FALSE)
destination = here("output/review_audit")
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
e = new.env(parent = globalenv())
sys.source(here("R/stages/05_cca_model.R"), e)
stopifnot(exists("CCA_VARIABLES", e, inherits = FALSE),
          !exists("cca_model", globalenv(), inherits = FALSE))
checks = list()
record = function(name, rows, error = 0, detail = "") {
  checks[[length(checks) + 1L]] <<- data.frame(check = name, rows = rows,
    maximum_absolute_error = error, status = "passed", detail = detail)
}
same = function(actual, expected, label, tolerance = 1e-8) {
  actual = unname(actual); expected = unname(expected)
  stopifnot(identical(is.na(actual), is.na(expected)))
  stopifnot(identical(is.finite(actual), is.finite(expected)))
  valid = is.finite(actual) & is.finite(expected)
  error = if (any(valid)) max(abs(actual[valid] - expected[valid])) else 0
  if (any(abs(actual[valid] - expected[valid]) >
          tolerance * pmax(1, abs(expected[valid])))) stop(label, ": error ", error)
  record(label, length(actual), error)
}
read = function(name) read_csv(here("output", paste0(name, ".csv")),
                              show_col_types = FALSE)

# Correspondence analysis residual matrix, then weighted least-squares
# projection onto the four constraints. This does not call vegan's CCA solver.
y = as.matrix(e$species_past_final)
p = y / sum(y); rw = rowSums(p); cw = colSums(p)
z = (p - outer(rw, cw)) / sqrt(outer(rw, cw))
xx = as.matrix(e$env_past_final)
xc = sweep(xx, 2, colSums(xx * rw)) * sqrt(rw)
q = qr.Q(qr(xc))
fit = q %*% crossprod(q, z)
eig = svd(fit, nu = 0, nv = 0)$d[1:4]^2
same(sum(z^2), e$cca_model$tot.chi, "independent CCA total inertia")
same(eig, as.numeric(e$cca_model$CCA$eig), "independent weighted CCA eigenvalues")

# Independent species selection and keys, based on sets rather than row counts.
occ = read("occ_consolidated")
stopifnot(!anyDuplicated(occ[c("site", "era", "period", "plot_id", "species")]),
          all(occ$occurrence %in% 0:1))
present = occ[occ$occurrence == 1, ]
sets = split(present$plot_id, interaction(present$species, present$site,
                                          present$period, drop = TRUE))
counts = lengths(lapply(sets, unique))
independent = tapply(counts, sub("\\.(MORA|NOCA)\\..*$", "", names(counts)), max)
selected = names(independent)[independent >= 20]
stopifnot(setequal(selected, e$keep_species), nrow(y) == 618L, ncol(y) == 13L)
record("binary occurrence keys and independent threshold selection", nrow(occ))

# Original metadata provides an independent check of the stratum distinction.
wb = here("data/raw/MORA_Cascade Legacy Data_Original1978.xlsx")
veg = read_excel(wb, sheet = "Rainier Veg")
size = read_excel(wb, sheet = "rawsizedata")
cover_only = c("ACCI", "ACGL", "ALSI", "TABR", "SOOC", "PREM", "SASC", "CONU")
stopifnot(all(cover_only %in% names(veg)),
          !any(paste0(rep(cover_only, each = 4), 1:4) %in% names(veg)))
stems = rowSums(as.matrix(size[, match("DBH0", names(size)):match(">DBH120", names(size))]), na.rm = TRUE)
stopifnot(sum(stems[size$Species == "TABR"], na.rm = TRUE) == 0)
record("MORA workbook stratum evidence", length(cover_only))

# Reconcile the received correction layer with raw stem multisets without
# sourcing the cleaner or its count/join routines.
corrected = read_excel(here("data/NOCA/OriginalDataFiles_NOCA/2026_corrected_trees_for_Billur.xlsx"),
                        sheet = "Trees")
original = read_excel(here("data/NOCA/NOCA_vegetation_fromJHRL.xlsx"), sheet = "Tree Data")
stopifnot(nrow(corrected) == 2366L, length(unique(corrected$Plot)) == 54L,
          !anyNA(corrected[c("Plot", "Species", "DBH")]))
normalize = function(x) toupper(trimws(as.character(x)))
stem_key = function(species, dbh) sort(paste(normalize(species), as.numeric(dbh), sep = "::"))
mapping = list(BBCR6065 = "BBCR6075", HB5134 = "HB5144", STE2022 = "STE2020",
  STE2077 = "STE2072", PYRA1015 = c("PYRA1013", "PYRA1015"),
  ROSS3048 = c("ROSS3044", "ROSS3048"))
for (old in names(mapping)) {
  a = original[normalize(original$`Plot ID`) == old, ]
  b = corrected[normalize(corrected$Plot) %in% mapping[[old]], ]
  stopifnot(identical(stem_key(a$species_abv, a$DBH), stem_key(b$Species, b$DBH)))
}
audit = read("NOCA_tree_correction_audit")
counts = table(normalize(corrected$Plot))
same(audit$corrected_rows_added, as.numeric(counts[normalize(audit$plot_id)]),
     "independent NOCA corrected-workbook plot stem counts")
record("independent raw NOCA erroneous-group stem reconciliation", length(mapping))

# Base-R monthly aggregation independently checks variable alignment, DJF year
# assignment, seasonal sums, and means on every current modern climate row.
monthly = rbind(read("MORA_climate"), read("NOCA_climate"))
monthly$key = paste(monthly$plot_id, monthly$site, monthly$period,
                    monthly$year, monthly$month, sep = "::")
parts = split(monthly, monthly$variable)
keys = Reduce(intersect, lapply(parts, function(x) x$key))
aligned = parts$tasmin[match(keys, parts$tasmin$key), ]
aligned$temperature = (aligned$value + parts$tasmax$value[match(keys, parts$tasmax$key)]) / 2
aligned$precipitation = parts$pr$value[match(keys, parts$pr$key)]
annual = e$climate_annual
annual_key = paste(annual$unit, annual$period, annual$time, sep = "::")
for (v in c("MSpT", "MWT", "SP", "WP")) {
  winter = v %in% c("MWT", "WP")
  months = if (winter) c(12, 1, 2) else if (v == "MSpT") 3:5 else 6:8
  x = aligned[aligned$month %in% months, ]
  year = x$year + as.integer(winter & x$month == 12)
  group = paste(x$plot_id, paste(x$site, x$period, sep = "."), year, sep = "::")
  values = if (v %in% c("MSpT", "MWT")) x$temperature else x$precipitation
  aggregate = tapply(values, group, if (v %in% c("MSpT", "MWT")) mean else sum)
  n = table(group); aggregate[n[names(aggregate)] != 3L] = NA_real_
  expected = as.numeric(aggregate[annual_key])
  same(annual[[v]], expected, paste("independent modern monthly aggregation", v))
}

# Native slice matching: choose the first minimum in stored input order,
# consistent with the explicit tie rule, with no synthetic climate values.
pe = read("paleo_env"); ponds = read("chelsa_paleo_ponds")
for (lake in unique(pe$lake)) {
  ages = unique(1950 - 100 * ponds$slice[ponds$lake == lake])
  x = pe[pe$lake == lake, ]
  expected = vapply(x$age, function(a) ages[which.min(abs(ages - a))], numeric(1))
  same(x$slice_age_calBP, expected, paste(lake, "nearest native climate slice"))
}

# Independently recalculate every displacement/rate and every signed climate
# change, for all modern rows and both already-existing Holocene resolutions.
for (name in c("cca_tracking_anthropocene_plot", "cca_tracking_holocene_realizations",
               "cca_tracking_holocene_realizations_500yr")) {
  x = read(name)
  o = cbind(x$o1_2 - x$o1, x$o2_2 - x$o2)
  p = cbind(x$p1_2 - x$p1, x$p2_2 - x$p2)
  no = sqrt(rowSums(o^2)); np = sqrt(rowSums(p^2)); dot = rowSums(o * p)
  valid = is.finite(no) & is.finite(np) & no > 1e-8 & np > 1e-8
  cosine = parallel = perpendicular = rep(NA_real_, nrow(x))
  cosine[valid] = pmax(-1, pmin(1, dot[valid] / no[valid] / np[valid]))
  parallel[valid] = dot[valid] / np[valid]
  # Cross-product expression is independent of subtraction of squared lengths.
  perpendicular[valid] = abs(o[valid, 1] * p[valid, 2] -
    o[valid, 2] * p[valid, 1]) / np[valid]
  expected = list(observed_vegetation_displacement = no,
    predicted_vegetation_displacement = np,
    observed_turnover_rate = no * 100 / x$vegetation_dt_years,
    predicted_vegetation_change_rate = np * 100 / x$climate_dt_years,
    magnitude_tracking_ratio = ifelse(np > 1e-8, no / np, NA_real_),
    rate_tracking_ratio = ifelse(np > 1e-8,
      no / np * x$climate_dt_years / x$vegetation_dt_years, NA_real_),
    cosine_similarity = cosine, angle_degrees = acos(cosine) * 180 / pi,
    climate_aligned_displacement = parallel,
    climate_aligned_tracking = parallel / np,
    perpendicular_movement = perpendicular,
    normalized_perpendicular_movement = perpendicular / np,
    tracking_error = sqrt(rowSums((o - p)^2)),
    normalized_tracking_error = ifelse(np > 1e-8,
      sqrt(rowSums((o - p)^2)) / np, NA_real_),
    lag_t1 = sqrt((x$p1 - x$o1)^2 + (x$p2 - x$o2)^2),
    lag_t2 = sqrt((x$p1_2 - x$o1_2)^2 + (x$p2_2 - x$o2_2)^2))
  expected$lag = expected$lag_t2 - expected$lag_t1
  expected$change_in_lag = expected$lag
  expected$lag_rate_per_century = expected$lag * 100 / x$climate_dt_years
  for (metric in names(expected)) same(x[[metric]], expected[[metric]],
                                       paste(name, metric))
  for (v in e$CCA_VARIABLES) {
    delta = x[[paste0(v, "_2")]] - x[[v]]
    same(x[[paste0(v, "_change")]], delta, paste(name, v, "signed change"))
    same(x[[paste0(v, "_rate_per_century")]], delta * 100 / x$climate_dt_years,
         paste(name, v, "physical rate"))
    reference_sd = sqrt(sum((e$env_past_final[[v]] -
      mean(e$env_past_final[[v]]))^2) / (nrow(e$env_past_final) - 1))
    same(x[[paste0(v, "_z_change")]], delta / reference_sd,
         paste(name, v, "independent standardization"))
    same(x[[paste0(v, "_z_rate_per_century")]],
         delta / reference_sd * 100 / x$climate_dt_years,
         paste(name, v, "standardized physical rate"))
  }
  z = sapply(e$CCA_VARIABLES, function(v) x[[paste0(v, "_z_change")]])
  same(x$standardized_climate_displacement, sqrt(rowSums(z^2)),
       paste(name, "multivariate standardized displacement"))
  same(x$standardized_climate_change_rate,
       sqrt(rowSums(z^2)) * 100 / x$climate_dt_years,
       paste(name, "multivariate standardized rate"))
  if ("age_hi" %in% names(x)) stopifnot(all(x$age_hi > x$age_lo),
    all(x$age_hi - x$age_lo == x$vegetation_dt_years))
}

# Base-R grouping reconstructs the posterior -> offset -> date hierarchy.
# It does not call the implementation's summarization or interval-join helpers.
key_for = function(x, columns) do.call(paste, c(x[columns], sep = "::"))
finite_stat = function(values, fun, ...) {
  values = values[is.finite(values)]
  if (length(values)) fun(values, ...) else NA_real_
}
summary_functions = list(mean = mean, sd = sd, median = median,
  q025 = function(x) quantile(x, .025, names = FALSE),
  q25 = function(x) quantile(x, .25, names = FALSE),
  q75 = function(x) quantile(x, .75, names = FALSE),
  q975 = function(x) quantile(x, .975, names = FALSE))
for (suffix in c("", "_500yr")) {
  x = read(paste0("cca_tracking_holocene_realizations", suffix))
  b = read(paste0("cca_tracking_holocene_by_offset", suffix))
  columns = c("site", "offset", "age_hi", "age_lo")
  groups = split(seq_len(nrow(x)), key_for(x, columns))
  indices = groups[key_for(b, columns)]
  stopifnot(!anyDuplicated(key_for(b, c(columns, "metric"))))
  values = lapply(seq_len(nrow(b)), function(i) x[[b$metric[i]]][indices[[i]]])
  same(b$n_total, lengths(values), paste(suffix, "independent draw counts"))
  same(b$n_valid, vapply(values, function(v) sum(is.finite(v)), integer(1)),
       paste(suffix, "independent finite draw counts"))
  for (field in names(summary_functions)) {
    expected = vapply(values, finite_stat, numeric(1), fun = summary_functions[[field]])
    same(b[[field]], expected, paste(suffix, "draw-within-offset", field))
  }
  dates = read(paste0("cca_tracking_holocene_timeseries", suffix))
  indices = lapply(seq_len(nrow(dates)), function(i) which(
    b$site == dates$site[i] & b$metric == dates$metric[i] &
    b$age_lo <= dates$t[i] & dates$t[i] < b$age_hi))
  stopifnot(all(vapply(indices, function(i) length(unique(b$offset[i])), integer(1)) ==
                  if (suffix == "") 10L else 5L))
  same(dates$estimate, vapply(indices, function(i) median(b$median[i]), numeric(1)),
       paste(suffix, "half-open interval mapping and median across offsets"))
  same(dates$age_q025, vapply(indices, function(i) median(b$q025[i]), numeric(1)),
       paste(suffix, "date draw lower bounds"))
  same(dates$age_q975, vapply(indices, function(i) median(b$q975[i]), numeric(1)),
       paste(suffix, "date draw upper bounds"))
}

# CCA extrapolation is assessed against the unchanged calibration bounds,
# without refitting or replacing predictors.
extrapolation = do.call(rbind, lapply(c("present", "paleo"), function(period) {
  x = e$env[e$env$period == period, ]; outside = matrix(FALSE, nrow(x), 4)
  rows = lapply(seq_along(e$CCA_VARIABLES), function(i) {
    v = e$CCA_VARIABLES[i]; bounds = range(e$env_past_final[[v]])
    outside[, i] <<- x[[v]] < bounds[1] | x[[v]] > bounds[2]
    data.frame(period = period, variable = v, n = nrow(x),
      outside_calibration_range = sum(outside[, i]),
      calibration_min = bounds[1], calibration_max = bounds[2])
  })
  rbind(do.call(rbind, rows), data.frame(period = period, variable = "any",
    n = nrow(x), outside_calibration_range = sum(rowSums(outside) > 0),
    calibration_min = NA_real_, calibration_max = NA_real_))
}))
write_csv(extrapolation, file.path(destination, "extrapolation.csv"))

# Every own-origin direction cosine, including its NA validity mask.
targets = rbind(data.frame(target_type = "taxon", target = rownames(e$species_scores),
  tx = e$species_scores[, 1], ty = e$species_scores[, 2]),
  data.frame(target_type = "climate", target = rownames(e$env_scores),
  tx = e$env_scores[, 1], ty = e$env_scores[, 2]))
cosine = function(a, b) {
  na = sqrt(rowSums(a^2)); nb = sqrt(rowSums(b^2))
  valid = is.finite(na) & is.finite(nb) & na > 1e-8 & nb > 1e-8
  out = rep(NA_real_, nrow(a))
  out[valid] = pmax(-1, pmin(1, rowSums(a[valid, , drop = FALSE] *
    b[valid, , drop = FALSE]) / na[valid] / nb[valid]))
  out
}
for (era in c("anthropocene", "holocene")) {
  x = read(paste0("cca_tracking_", if (era == "anthropocene") "anthropocene_plot" else
                  "holocene_realizations"))
  path = here("output", paste0("cca_direction_", era, "_realizations.csv",
                              if (era == "holocene") ".gz" else ""))
  d = read_csv(path, show_col_types = FALSE)
  keys = if (era == "anthropocene") c("site", "plot_id") else
    c("site", "draw", "offset", "age_hi", "age_lo")
  key = function(x) {
    if ("plot_id" %in% names(x)) x$plot_id = toupper(x$plot_id)
    do.call(paste, c(x[keys], sep = "::"))
  }
  stopifnot(!anyDuplicated(key(x)))
  x = x[match(key(d), key(x)), ]; stopifnot(!anyNA(x$site))
  target = targets[match(paste(d$target_type, d$target),
                         paste(targets$target_type, targets$target)), ]
  tp = to = as.matrix(target[c("tx", "ty")])
  species = d$target_type == "taxon"
  tp[species, ] = tp[species, ] - as.matrix(x[species, c("p1", "p2")])
  to[species, ] = to[species, ] - as.matrix(x[species, c("o1", "o2")])
  a = cbind(x$p1_2 - x$p1, x$p2_2 - x$p2)
  b = cbind(x$o1_2 - x$o1, x$o2_2 - x$o2)
  cp = cosine(a, tp); co = cosine(b, to)
  same(d$predicted_association, cp, paste(era, "predicted own-origin cosine"))
  same(d$observed_association, co, paste(era, "observed own-origin cosine"))
  same(d$directional_difference, cp - co, paste(era, "direction discrepancy"))
  same(d$direct_movement_cosine, cosine(a, b), paste(era, "direct movement cosine"))
}

# Descriptive direction groups use ecological units/site-dates, not all draws.
raw_direction = read_csv(here("output/cca_direction_holocene_realizations.csv.gz"),
                          show_col_types = FALSE)
by_offset = read_csv(here("output/cca_direction_holocene_by_offset.csv.gz"),
                     show_col_types = FALSE)
columns = c("site", "offset", "age_hi", "age_lo", "target_type", "target")
groups = split(seq_len(nrow(raw_direction)), key_for(raw_direction, columns))
indices = groups[key_for(by_offset, columns)]
values = lapply(indices, function(i) raw_direction$directional_difference[i])
same(by_offset$n_total, lengths(values), "direction posterior-within-offset counts")
for (field in c("median", "q025", "q25", "q75", "q975"))
  same(by_offset[[paste0("difference_", field)]], vapply(values, finite_stat,
    numeric(1), fun = summary_functions[[field]]),
    paste("independent direction draw-within-offset", field))
dates = read("cca_direction_holocene_timeseries")
indices = lapply(seq_len(nrow(dates)), function(i) which(
  by_offset$site == dates$site[i] & by_offset$target == dates$target[i] &
  by_offset$target_type == dates$target_type[i] &
  by_offset$age_lo <= dates$t[i] & dates$t[i] < by_offset$age_hi))
stopifnot(all(vapply(indices, function(i) length(unique(by_offset$offset[i])), integer(1)) == 10L))
same(dates$difference_estimate, vapply(indices, function(i)
  finite_stat(by_offset$difference_median[i], median), numeric(1)),
  "independent direction half-open mapping and median across offsets")

summaries = read("cca_direction_group_summaries")
for (period in c("Anthropocene", "Holocene")) {
  modern = period == "Anthropocene"
  input = if (modern) read("cca_direction_anthropocene_realizations") else
    read("cca_direction_holocene_timeseries")
  s = summaries[summaries$period == period, ]
  columns = c("site", if (modern) "burned" else c("climate_state", "high_fire"),
              "target_type", "target")
  groups = split(seq_len(nrow(input)), key_for(input, columns))
  indices = groups[key_for(s, columns)]
  stopifnot(!anyDuplicated(key_for(s, columns)))
  values = lapply(indices, function(i) input[[if (modern)
    "directional_difference" else "difference_estimate"]][i])
  same(s$n_total, lengths(values), paste(period, "direction group counts"))
  same(s$n_valid, vapply(values, function(v) sum(is.finite(v)), integer(1)),
       paste(period, "direction group finite counts"))
  for (field in c("median", "q025", "q25", "q75", "q975"))
    same(s[[paste0("difference_", field)]], vapply(values, finite_stat,
      numeric(1), fun = summary_functions[[field]]),
      paste(period, "independent direction group", field))
}

# Source event ages -> exact half-open windows -> core normalization -> site MAD.
events = read("holocene_fire_source_events")
core = read("holocene_era_fire_core_frequency")
for (i in seq_len(nrow(core))) {
  x = core[i, ]; ages = events$age_cal_yr_BP[events$lake == x$lake]
  n = sum(ages >= x$cal_bp - 500 & ages < x$cal_bp + 500)
  stopifnot(n == x$accepted_event_count, n == x$peak_frequency_per_1000yr)
}
record("accepted events in half-open 1000-year fire windows", nrow(core))
for (lake in unique(core$lake)) {
  x = core[core$lake == lake, ]
  same(x$normalized_frequency, x$accepted_event_count / max(x$accepted_event_count),
       paste(lake, "core fire normalization"))
}
fire = read("holocene_era_fire_site_frequency")
for (site in unique(fire$site)) {
  x = fire[fire$site == site, ]; v = x$normalized_frequency[is.finite(x$normalized_frequency)]
  cutoff = median(v) + 1.4826 * median(abs(v - median(v)))
  same(x$high_fire_threshold, rep(cutoff, nrow(x)), paste(site, "fire MAD cutoff"))
  stopifnot(identical(x$high_fire, is.finite(x$normalized_frequency) &
                       x$normalized_frequency > cutoff))
}

# Regional signed changes and phase support; recompute medians and thresholds
# using base-R grouping, then reconstruct the any-variable union cell by cell.
phases = read("holocene_era_climate_regional_phase_changes")
variables = read("holocene_era_climate_directional_cells")
thresholds = read("holocene_era_climate_variable_thresholds")
grid = read("holocene_era_grid")
groups = split(phases, paste(phases$variable, phases$t, sep = "::"))
for (i in seq_len(nrow(variables))) {
  x = variables[i, ]; rows = groups[[paste(x$variable, x$t, sep = "::")]]
  score = (rows$standardized_signed_change_MORA + rows$standardized_signed_change_NOCA) / 2
  same(x$regional_score, median(score), paste("regional median", x$variable, x$t))
  stopifnot(x$phase_direction_support == sum(sign(score) == sign(median(score)) & score != 0))
}
for (v in unique(variables$variable)) {
  x = variables[variables$variable == v & variables$complete_phase_coverage, ]
  threshold = thresholds$threshold_standardized_change[thresholds$variable == v]
  same(threshold, max(abs(x$regional_score)) / 2, paste(v, "50-percent threshold"))
}
for (i in seq_len(nrow(grid))) {
  x = variables[variables$t == grid$t[i], ]
  qualifies = x$complete_phase_coverage & abs(x$regional_score) >=
    x$threshold_standardized_change & x$phase_direction_support >= 8L
  stopifnot(grid$era_class[i] == if (any(qualifies)) "climate change" else "relative stability")
}
record("independent climate-era union", nrow(grid))

write_csv(do.call(rbind, checks), file.path(destination, "independent_checks.csv"))
writeLines(capture.output(sessionInfo()), file.path(destination, "session_info.txt"))
cat(length(checks), "independent current-method checks passed. Evidence:", destination, "\n")
