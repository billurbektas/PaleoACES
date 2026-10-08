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
stopifnot(setequal(selected, e$keep_species), nrow(y) == 607L, ncol(y) == 14L)
record("binary occurrence keys and independent threshold selection", nrow(occ))

# Independently intersect recorded retained-taxon presence and complete climate
# at both dates, without calling the CCA eligibility or pairing functions.
at_date = function(period) {
  ids = unique(present$plot_id[present$period == period & present$species %in% selected])
  climate = e$env[e$env$period == period, ]
  complete = apply(as.matrix(climate[e$CCA_VARIABLES]), 1, function(x) all(is.finite(x)))
  intersect(ids, climate$plot_id[complete])
}
matched_ids = intersect(at_date("past"), at_date("present"))
stopifnot(setequal(rownames(y), matched_ids),
          setequal(rownames(e$cca_model$CCA$u), matched_ids),
          identical(e$species_past_final, e$species_past_paired),
          identical(e$env_past_final, e$env_past_paired))
record("independent matched-pair CCA calibration membership", length(matched_ids))

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
# Independently derive dates/windows from adult raw data, without the shared
# date helper or seedling Year column. Check every plot, endpoint and denominator.
adult_dates = read_csv(here("data/MORA/MORA_TreeData_Resurvey_Cleaned.csv"), show_col_types = FALSE)
library_ids = read_csv(here("data/MORA/MORA_plot_lib.csv"), show_col_types = FALSE)
latest = tapply(adult_dates$Year, adult_dates$Plot_ID, max)
modern = read("cca_tracking_anthropocene_plot_calculations")
mi = modern$site == "MORA"
supplied = library_ids$Plot_ID[match(modern$plot_id[mi], library_ids$plot_id)]
same(modern$vegetation_t2_year[mi], as.numeric(latest[supplied]), "independent latest adult MORA dates")
wilson = read_csv(here("data/NOCA/NOCA_plots_fromWilson.csv"), show_col_types = FALSE)
ni = !mi
same(modern$vegetation_t2_year[ni], wilson$Resurvey.Year[
  match(toupper(modern$plot_id[ni]), toupper(trimws(wilson$`2015.Plot.Name`)))], "independent Wilson NOCA dates")
same(modern$climate_t1_midyear, rep(1984, nrow(modern)), "historical climate midpoint retained")
same(modern$climate_t2_midyear, modern$vegetation_t2_year - 2.5, "independent six-year modern midpoints")
same(modern$climate_dt_years, modern$vegetation_t2_year - 1986.5, "independent plot-specific climate intervals")
for (i in seq_len(nrow(modern))) {
  x = monthly[monthly$plot_id == modern$plot_id[i] & monthly$period == "present", ]
  Y = modern$vegetation_t2_year[i]
  expected = expand.grid(variable = c("tasmin", "tasmax", "pr"), year = (Y-5):Y, month = 1:12)
  expected = rbind(expected, data.frame(variable = c("tasmin", "tasmax", "pr"), year = Y-6, month = 12))
  key = function(z) paste(z$variable, z$year, z$month)
  stopifnot(nrow(x) == 219L, !anyDuplicated(key(x)), setequal(key(x), key(expected)))
}
record("independent full monthly windows including lead-in December", nrow(modern))

# Optional pre-update fitted-object snapshot for the authorized before/after check.
baseline_arg = commandArgs(TRUE)
if (length(baseline_arg)) {
  before = readRDS(baseline_arg[1])
  stopifnot(identical(before$species_past_final, e$species_past_final),
    identical(before$env_past_final, e$env_past_final), identical(before$keep_species, e$keep_species))
  for (component in c("tot.chi", "grand.total", "rowsum", "colsum", "Ybar", "pCCA", "CCA", "CA"))
    stopifnot(isTRUE(all.equal(before$cca_model[[component]], e$cca_model[[component]])))
  stopifnot(identical(before$climate_summary[before$climate_summary$period == "past", ],
    e$climate_summary[e$climate_summary$period == "past", ]),
    identical(before$comparison_df[before$comparison_df$era == "holocene", ],
      e$comparison_df[e$comparison_df$era == "holocene", ]))
  record("pre-update calibration, retained taxa and complete numerical CCA fit unchanged", nrow(e$species_past_final))
}
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
# change, for all modern rows and the canonical lake realizations.
for (name in c("cca_tracking_anthropocene_plot_calculations",
               "cca_tracking_holocene_lake_realizations")) {
  x = read(name)
  o = cbind(x$o1_2 - x$o1, x$o2_2 - x$o2)
  p = cbind(x$p1_2 - x$p1, x$p2_2 - x$p2)
  no = sqrt(rowSums(o^2)); np = sqrt(rowSums(p^2)); dot = rowSums(o * p)
  valid = is.finite(no) & is.finite(np) & no > 1e-8 & np > 1e-8
  cosine = rep(NA_real_, nrow(x))
  cosine[valid] = pmax(-1, pmin(1, dot[valid] / no[valid] / np[valid]))
  expected = list(observed_vegetation_displacement = no,
    predicted_vegetation_displacement = np,
    observed_turnover_rate = no * 100 / x$vegetation_dt_years,
    predicted_vegetation_change_rate = np * 100 / x$climate_dt_years,
    magnitude_tracking_ratio = ifelse(np > 1e-8, no / np, NA_real_),
    rate_tracking_ratio = ifelse(np > 1e-8,
      no / np * x$climate_dt_years / x$vegetation_dt_years, NA_real_),
    angle_degrees = acos(cosine) * 180 / pi,
    lag_t1 = sqrt((x$p1 - x$o1)^2 + (x$p2 - x$o2)^2),
    lag_t2 = sqrt((x$p1_2 - x$o1_2)^2 + (x$p2_2 - x$o2_2)^2))
  expected$change_in_lag = expected$lag_t2 - expected$lag_t1
  expected$lag_rate_per_century = expected$change_in_lag * 100 / x$climate_dt_years
  pace = cbind(x$o1,x$o2) + o * (np / no)
  direction = cbind(x$o1,x$o2) + p * (no / np)
  pace[no <= 1e-8, ] = NA_real_
  direction[np <= 1e-8, ] = NA_real_
  final = cbind(x$p1_2,x$p2_2)
  expected$lag_t2_pace_corrected = sqrt(rowSums((pace-final)^2))
  expected$lag_t2_direction_corrected = sqrt(rowSums((direction-final)^2))
  expected$pace_effect_on_lag = expected$lag_t2-expected$lag_t2_pace_corrected
  expected$direction_effect_on_lag = expected$lag_t2-expected$lag_t2_direction_corrected
  expected$pace_effect_on_lag_per_century = expected$pace_effect_on_lag*100/x$climate_dt_years
  expected$direction_effect_on_lag_per_century = expected$direction_effect_on_lag*100/x$climate_dt_years
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
summary_functions = list(median = median,
  q025 = function(x) quantile(x, .025, names = FALSE),
  q975 = function(x) quantile(x, .975, names = FALSE))
x = read("cca_tracking_holocene_lake_realizations")
b = read("cca_tracking_holocene_lake_by_offset")
u = read("cca_tracking_holocene_lake_uncertainty")
columns = c("site", "lake", "offset", "age_hi", "age_lo")
groups = split(seq_len(nrow(x)), key_for(x, columns))
indices = groups[key_for(b, columns)]
stopifnot(!anyDuplicated(key_for(b, columns)), nrow(b)==273L, nrow(u)==3822L)
metrics = c("lag_rate_per_century", "observed_turnover_rate", "magnitude_tracking_ratio",
  "rate_tracking_ratio", "angle_degrees", "pace_effect_on_lag_per_century",
  "direction_effect_on_lag_per_century")
same(b$n_draws_present, lengths(indices), "transition draw presence")
same(b$n_draws_nmin2, vapply(indices,function(i) sum(x$n_min[i]>=2),integer(1)),
     "transition sampling support")
for (rule in c("all","nmin2")) for (metric in metrics) {
  rows = u[u$sampling_rule==rule & u$metric==metric,]
  idx = groups[key_for(rows,columns)]
  eligible = lapply(idx,function(i) if(rule=="all") i else i[x$n_min[i]>=2])
  values = lapply(eligible, function(i) x[[metric]][i])
  valid = vapply(values, function(v) sum(is.finite(v)), integer(1))
  same(rows$n_present_draws,lengths(idx),paste(rule,metric,"present draws"))
  same(rows$n_eligible_draws,lengths(eligible),paste(rule,metric,"eligible draws"))
  same(rows$n_valid_draws,valid,paste(rule,metric,"finite draw counts"))
  same(rows$n_undefined_draws,lengths(eligible)-valid,paste(rule,metric,"undefined draw counts"))
  same(rows$n_expected_draws,rep(100L,nrow(rows)),paste(rule,metric,"expected draws"))
  for (field in names(summary_functions)) {
    expected = vapply(values, finite_stat, numeric(1), fun=summary_functions[[field]])
    same(rows[[field]],expected,paste(rule,metric,"draw-within-offset",field))
    if(rule=="all" && field=="median") same(b[[metric]],
      expected[match(key_for(b,columns),key_for(rows,columns))],paste(metric,"compact model response"))
  }
}
dates = read("cca_tracking_holocene_lake_timeseries")
all = u[u$sampling_rule=="all",]
indices = lapply(seq_len(nrow(dates)), function(i) which(
  all$site == dates$site[i] & all$lake == dates$lake[i] & all$metric == dates$metric[i] &
  all$age_lo <= dates$t[i] & dates$t[i] < all$age_hi))
stopifnot(all(vapply(indices, function(i) length(unique(all$offset[i])), integer(1)) == 10L),
  all(vapply(indices, function(i) sum(is.finite(all$median[i])), integer(1)) == 10L))
for (actual_field in c("estimate","age_q025","age_q975","phase_min","phase_max")) {
  source_field = c(estimate="median",age_q025="q025",age_q975="q975",phase_min="median",phase_max="median")[[actual_field]]
  fun = switch(actual_field,phase_min=min,phase_max=max,median)
  expected = vapply(indices,function(i) finite_stat(all[[source_field]][i],fun),numeric(1))
  same(dates[[actual_field]],expected,paste("lake reporting grid",actual_field))
}
same(dates$min_present_draws,vapply(indices,function(i) min(all$n_present_draws[i]),numeric(1)),
  "lake reporting grid draw support")
same(dates$n_offsets,rep(10L,nrow(dates)),"lake reporting grid offset support")
same(dates$n_valid_offsets,rep(10L,nrow(dates)),"lake reporting grid finite offset support")

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
