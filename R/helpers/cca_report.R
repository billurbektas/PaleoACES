# CCA summary tables for the report, computed from the fitted model in the CCA
# step's environment. The permutation tests are seeded and cached on the fit, so
# they rerun only when the model changes.
cca_report_tables = function(e, permutations = 9999L, seed = 20261008L) {
  fit = e$cca_model
  write = function(x, name) readr::write_csv(x, out(paste0(name, '.csv')))

  write(data.frame(field = c('calibration_plots', 'retained_species', 'count_threshold', 'scaling',
      'hill', 'constraints', 'total_inertia', 'constrained_inertia', 'constrained_percent',
      'projection_candidates', 'positioned_samples'),
    value = c(nrow(e$species_past_final), length(e$keep_species), e$count.thr,
      e$cca_scaling, e$cca_hill, paste(e$CCA_VARIABLES, collapse = ';'),
      fit$tot.chi, fit$CCA$tot.chi, 100 * fit$CCA$tot.chi / fit$tot.chi,
      sum(e$cca_eligibility_counts$input_units[e$cca_eligibility_counts$use != 'Legacy calibration']),
      nrow(e$comparison_df))), 'cca_summary')
  eig = fit$CCA$eig
  write(data.frame(axis = names(eig), eigenvalue = as.numeric(eig),
    percent_total_inertia = 100 * eig / fit$tot.chi,
    percent_constrained_inertia = 100 * eig / sum(eig)), 'cca_axes')
  write(as.data.frame(e$occ_summary) |> dplyr::mutate(retained = species %in% e$keep_species), 'cca_taxa')
  counts = e$env |> dplyr::distinct(site, period, plot_id) |> dplyr::count(site, period, name = 'input_samples')
  calibrated = e$env |> dplyr::filter(period == 'past', plot_id %in% rownames(e$species_past_final)) |>
    dplyr::count(site, period, name = 'calibration_samples')
  positioned = e$comparison_df |> dplyr::mutate(period = ifelse(era == 'anthropocene', 'present', 'paleo')) |>
    dplyr::count(site, period, name = 'positioned_samples')
  write(counts |> dplyr::left_join(calibrated, by = c('site', 'period')) |>
    dplyr::left_join(positioned, by = c('site', 'period')), 'cca_counts')
  writeLines(capture.output(print(fit)), out('cca_model_output.txt'))

  # Permutation tests: unrestricted and within parks; overall, by axis, by term.
  stopifnot(identical(rownames(e$species_past_final), rownames(e$env_past_final)))
  legacy = e$cca_sample_eligibility |> dplyr::filter(period == 'past', calibration_included)
  sites = factor(legacy$site[match(rownames(e$species_past_final), legacy$plot_id)])
  stopifnot(!anyNA(sites), !anyDuplicated(legacy$plot_id), length(sites) == nrow(e$species_past_final))
  signature = object_fingerprint(list(fit$CCA$v, fit$CCA$eig, as.character(sites), permutations, seed,
    as.character(utils::packageVersion('vegan'))))
  cache = out('cca_anova_cache.rds')
  cached = if (file.exists(cache)) readRDS(cache) else NULL
  if (!identical(cached$signature, signature)) {
    rng_kind = RNGkind()
    had_seed = exists('.Random.seed', envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) rng_seed = get('.Random.seed', envir = .GlobalEnv, inherits = FALSE)
    on.exit({
      do.call(RNGkind, as.list(rng_kind))
      if (had_seed) assign('.Random.seed', rng_seed, envir = .GlobalEnv) else
        if (exists('.Random.seed', envir = .GlobalEnv, inherits = FALSE)) rm('.Random.seed', envir = .GlobalEnv)
    }, add = TRUE)
    RNGkind('Mersenne-Twister', 'Inversion', 'Rejection')
    set.seed(seed)
    designs = list(
      Unrestricted = permute::shuffleSet(length(sites), nset = permutations,
        control = permute::how(nperm = permutations)),
      `Within parks` = permute::shuffleSet(length(sites), nset = permutations,
        control = permute::how(nperm = permutations, blocks = sites)))
    tests = list()
    for (design in names(designs)) {
      if (design == 'Within parks') stopifnot(all(vapply(seq_len(permutations),
        function(i) identical(sites[designs[[design]][i, ]], sites), logical(1))))
      for (test in c('Overall', 'Axis', 'Climate variable')) {
        cat('CCA permutation test: ', design, ', ', test, ' (', permutations, ').\n', sep = '')
        by = switch(test, Overall = NULL, Axis = 'axis', `Climate variable` = 'margin')
        a = stats::anova(fit, by = by, permutations = designs[[design]],
          model = 'reduced', cutoff = 1, parallel = 1)
        tests[[length(tests) + 1L]] = data.frame(design, test, component = rownames(a),
          df = a$Df, inertia = a$ChiSquare, pseudo_F = a$F, p_value = a$`Pr(>F)`,
          permutations, seed, vegan_version = as.character(utils::packageVersion('vegan')))
      }
    }
    cached = list(signature = signature, anova = dplyr::bind_rows(tests))
    saveRDS(cached, cache)
  }
  valid = cached$anova |> dplyr::filter(!is.na(p_value))
  write(valid |> dplyr::filter(design == 'Unrestricted', test != 'Climate variable') |>
    dplyr::select(test, component, df, inertia, pseudo_F, p_unrestricted = p_value) |>
    dplyr::left_join(valid |> dplyr::filter(design == 'Within parks') |>
      dplyr::select(test, component, p_within_parks = p_value), by = c('test', 'component')), 'cca_anova')

  total = fit$CCA$tot.chi
  sp = vegan::inertcomp(fit, display = 'species')
  species_scores = vegan::scores(fit, display = 'species', choices = 1:2, scaling = e$cca_scaling, hill = e$cca_hill)
  species = data.frame(species = rownames(sp),
    legacy_plots = as.numeric(colSums(e$species_past_final)[rownames(sp)]),
    constrained_inertia = sp[, 'CCA'], percent_constrained_inertia = 100 * sp[, 'CCA'] / total,
    CCA1 = species_scores[rownames(sp), 1], CCA2 = species_scores[rownames(sp), 2]) |>
    dplyr::mutate(prevalence_percent = 100 * legacy_plots / nrow(e$species_past_final)) |>
    dplyr::arrange(dplyr::desc(percent_constrained_inertia))
  stopifnot(abs(sum(species$constrained_inertia) - total) < 1e-12)
  write(species, 'cca_species_contributions')
  bp = vegan::scores(fit, display = 'bp', choices = 1:2, scaling = e$cca_scaling, hill = e$cca_hill)
  vif = vegan::vif.cca(fit)
  climate = valid |> dplyr::filter(design == 'Unrestricted', test == 'Climate variable') |>
    dplyr::transmute(variable = component, variable_label = unname(e$CLIMATE_VARIABLE_LABELS[variable]), df,
      marginal_inertia = inertia, unique_percent_constrained = 100 * inertia / total,
      pseudo_F, p_unrestricted = p_value) |>
    dplyr::left_join(valid |> dplyr::filter(design == 'Within parks', test == 'Climate variable') |>
      dplyr::select(variable = component, p_within_parks = p_value), by = 'variable') |>
    dplyr::mutate(VIF = unname(vif[variable]), CCA1 = bp[variable, 1], CCA2 = bp[variable, 2])
  stopifnot(nrow(climate) == length(e$CCA_VARIABLES), !anyNA(climate))
  write(climate, 'cca_climate_contributions')
  invisible(NULL)
}

# Step 0.1 screening of the climate constraints (PLAN.md section 5, Step 0).
# The same 605 calibration plots and retained taxa are refitted with three
# constraint sets, so the sets differ only in their climate variables.
# Extrapolation: a Holocene lake-century lies outside the calibration climate
# cloud when its Mahalanobis distance from the calibration plots (their mean and
# covariance for that set) exceeds the 99th percentile of the plots' own
# distances. This measure sees combinations of seasons the calibration lacks,
# such as a warm spring with a cold winter, which no single variable reveals.
cca_screening_tables = function(e, permutations = 9999L, seed = 20261109L) {
  sets = list(`All four` = c('MSpT', 'MWT', 'SP', 'WP'), `MWT + SP` = c('MWT', 'SP'),
    `MSpT + SP` = c('MSpT', 'SP'))
  ids = rownames(e$species_past_final)
  climate = e$climate_summary |> dplyr::filter(period == 'past') |>
    dplyr::distinct(plot_id, dplyr::across(dplyr::all_of(sets[[1]]))) |>
    tibble::column_to_rownames('plot_id')
  climate = climate[ids, sets[[1]], drop = FALSE]
  # Rule: the legacy calibration plots of config.R, complete in all four seasonal variables.
  stopifnot(nrow(climate) == sum(ANTHROPOCENE_PAIRS), !anyNA(climate))
  source(here::here('R/helpers/climate_variables.R'), local = TRUE)
  holocene = readr::read_csv(out('chelsa_paleo_ponds.csv'), show_col_types = FALSE) |>
    dplyr::transmute(unit = lake, period = site, variable, time = slice, month,
      value = if (PALEO_USE_BIAS_CORRECTED) value_corrected else value_raw) |>
    derive_climate_vars(winter_shift = FALSE) |>
    dplyr::transmute(site = period, lake = unit, cal_bp = trace_slice_cal_bp(time),
      dplyr::across(dplyr::all_of(sets[[1]])))
  stopifnot(!anyNA(holocene[sets[[1]]]))
  fits = lapply(sets, function(v) vegan::cca(e$species_past_final ~ ., data = climate[, v, drop = FALSE]))
  # The adjusted R2 of a CCA is estimated by permutation in vegan; seed it.
  set.seed(seed)
  rows = purrr::imap_dfr(sets, function(v, set) {
    fit = fits[[set]]
    X = as.matrix(climate[v]); centre = colMeans(X); covariance = stats::cov(X)
    edge = stats::quantile(stats::mahalanobis(X, centre, covariance), 0.99)
    outside = stats::mahalanobis(as.matrix(holocene[v]), centre, covariance) > edge
    r = stats::cor(X); r = r[upper.tri(r)]
    tibble::tibble(set, variables = paste(v, collapse = ';'), n_plots = nrow(X),
      variable = v, VIF = unname(vegan::vif.cca(fit)[v]),
      max_abs_correlation = if (length(r)) max(abs(r)) else NA_real_,
      constrained_axes = length(fit$CCA$eig),
      R2 = vegan::RsquareAdj(fit)$r.squared,
      adjusted_R2 = vegan::RsquareAdj(fit, permutations = 1000L)$adj.r.squared,
      holocene_lake_centuries_MORA = sum(holocene$site == 'MORA'),
      extrapolated_share_MORA = mean(outside[holocene$site == 'MORA']),
      holocene_lake_centuries_NOCA = sum(holocene$site == 'NOCA'),
      extrapolated_share_NOCA = mean(outside[holocene$site == 'NOCA']))
  })
  readr::write_csv(rows, out('cca_screening.csv'))
  r = stats::cor(as.matrix(climate))
  readr::write_csv(tibble::as_tibble(r, rownames = 'variable'), out('cca_screening_correlations.csv'))
  # Does adding winter temperature and winter precipitation back improve the fit?
  sites = factor(e$cca_sample_eligibility$site[match(ids, e$cca_sample_eligibility$plot_id)])
  stopifnot(!anyNA(sites))
  set.seed(seed)
  designs = list(Unrestricted = permute::how(nperm = permutations),
    `Within parks` = permute::how(nperm = permutations, blocks = sites))
  addback = purrr::imap_dfr(designs, function(control, design) {
    a = stats::anova(fits[['MSpT + SP']], fits[['All four']], permutations = control)
    tibble::tibble(design, reduced = 'MSpT + SP', full = 'All four (adds MWT and WP)',
      residual_df_reduced = a$ResDf[1], residual_df_full = a$ResDf[2],
      residual_inertia_reduced = a$ResChiSquare[1], residual_inertia_full = a$ResChiSquare[2],
      added_inertia = a$ChiSquare[2], pseudo_F = a$F[2], p_value = a$`Pr(>F)`[2],
      permutations, seed)
  })
  readr::write_csv(addback, out('cca_screening_addback.csv'))
  invisible(list(screening = rows, addback = addback))
}

# The display rotation of the fitted model, for figures and the report. Tables
# stay in unrotated coordinates.
cca_rotation_table = function(e) {
  source(here::here('R/helpers/cca_display_rotation.R'), local = TRUE)
  bp = vegan::scores(e$cca_model, display = 'bp', choices = 1:2, scaling = e$cca_scaling, hill = e$cca_hill)
  rotation = cca_display_rotation(bp)
  rotated = bp %*% rotation$matrix
  # Rule (PLAN.md Step 0.4): axis 1 is spring temperature increasing to the
  # right, axis 2 summer precipitation increasing upward.
  stopifnot(identical(rotation$axis_variables, c('MSpT', 'SP')), rotated['MSpT', 1] > 0, rotated['SP', 2] > 0)
  readr::write_csv(tibble::tibble(angle_degrees = rotation$angle_degrees,
    axis_1 = rotation$axis_variables[1], axis_2 = rotation$axis_variables[2],
    m11 = rotation$matrix[1, 1], m21 = rotation$matrix[2, 1], m12 = rotation$matrix[1, 2], m22 = rotation$matrix[2, 2],
    MSpT_axis1 = rotated['MSpT', 1], MSpT_axis2 = rotated['MSpT', 2],
    SP_axis1 = rotated['SP', 1], SP_axis2 = rotated['SP', 2]), out('cca_display_rotation.csv'))
  invisible(rotation)
}
