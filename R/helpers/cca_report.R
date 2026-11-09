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
