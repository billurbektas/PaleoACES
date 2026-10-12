# Native-century reconstruction and support audit. Sourcing defines functions
# only. The audit reads original samples and a frozen CCA, and never refits it.

reconstruction_read_original_samples = function() {
  mora = readxl::read_excel(here::here('data/PALEO/DunwiddieMacrofossils.xlsx'),
                           sheet = 'MacrofossilData')
  mora_ids = mora |> dplyr::distinct(lake = Location, depth_cm = Depth) |>
    dplyr::mutate(site = 'MORA', source_sample_id = as.character(depth_cm),
      sample_id = paste0(lake, ':depth:', source_sample_id),
      source = 'DunwiddieMacrofossils.xlsx:MacrofossilData')
  # Same within-sample harmonization as 000_PALEO_b_vegetation.R. No merging
  # across depths or averaging raw percentages across botanical categories.
  aliases = c('Abies Amabilis' = 'Abies amabilis',
    'Abies Lasiocarpa' = 'Abies lasiocarpa', 'Abies Procera' = 'Abies procera',
    'Pinus Contorta Fascilcles' = 'Pinus contorta',
    'Pinus Contorta Fascicles' = 'Pinus contorta',
    'Pinus Contorta Needle Fragments' = 'Pinus contorta',
    'Pinus Monticola Fascicles' = 'Pinus monticola',
    'Pinus Monticola Needle Fragments' = 'Pinus monticola',
    'Pinus Montocola Needle Fragments' = 'Pinus monticola',
    'Picea Engelmannii' = 'Picea engelmannii',
    'Pseudotsuga Menziesii' = 'Pseudotsuga menziesii',
    'Tsuga Heterophylla' = 'Tsuga heterophylla',
    'Tsuga Mertensiana' = 'Tsuga mertensiana',
    'Tsuga Mertinsiana' = 'Tsuga mertensiana',
    'Chamaecyparis' = 'Callitropsis nootkatensis',
    'Chamaecyparis Seeds' = 'Callitropsis nootkatensis')
  nonvegetation = c('Carex Achenes Lenticular', 'Carex Achenes Trigonous',
    'Isoetes Megaspores', 'Nuphar Polysepalum Seeds', 'Potamogeton Species Achenes',
    'Ranunculus CF Aquatilis Achenes', 'Juncus Seeds', 'Sparganium Seeds',
    'Phyllodoce Leaves', 'Abies-Type Seeds', 'Tsuga-Type Seeds',
    'Needle Concentration (per CC)', 'Needle Concentration (Per CC)',
    'Charcoal Fragments', 'Charred Needles')
  mora_occ = mora |> dplyr::transmute(lake = Location, depth_cm = Depth,
      original_species = stringr::str_squish(Species), value = Percentage) |>
    dplyr::filter(!original_species %in% nonvegetation) |>
    dplyr::mutate(species = dplyr::coalesce(unname(aliases[original_species]), original_species),
      occurrence = as.integer(value > 0)) |>
    dplyr::left_join(mora_ids |> dplyr::select(lake, depth_cm, sample_id),
                    by = c('lake', 'depth_cm'), relationship = 'many-to-one')

  noca = readr::read_csv(here::here('data/NOCA/NOCA_paleo/dataset52207_site13042.csv'),
                         show_col_types = FALSE)
  source_ids = setdiff(names(noca), c('name', 'group', 'element', 'units', 'context'))
  depth = noca[noca$name == 'Depth', source_ids, drop = FALSE]
  if (nrow(depth) != 1L) stop('Expected one original NOCA depth record')
  noca_ids = tibble::tibble(site = 'NOCA', lake = 'PantherPotholes',
    source_sample_id = source_ids, depth_cm = as.numeric(depth[1, ]),
    sample_id = paste0('PantherPotholes:', source_ids),
    source = 'Neotoma dataset52207_site13042.csv')
  noca_aliases = c('Abies lasiocarpa' = 'Abies lasiocarpa',
    'Cupressus nootkatensis' = 'Callitropsis nootkatensis',
    'Picea engelmannii' = 'Picea engelmannii', 'Pinus contorta' = 'Pinus contorta',
    'Pinus monticola' = 'Pinus monticola', 'Pseudotsuga menziesii' = 'Pseudotsuga menziesii',
    'Thuja plicata' = 'Thuja plicata', 'Tsuga heterophylla' = 'Tsuga heterophylla',
    'Tsuga mertensiana' = 'Tsuga mertensiana', 'Juniperus communis' = 'Juniperus communis')
  noca_occ = noca |> dplyr::filter(group == 'TRSH', name %in% names(noca_aliases)) |>
    dplyr::mutate(species = unname(noca_aliases[name])) |>
    dplyr::select(species, dplyr::all_of(source_ids)) |>
    tidyr::pivot_longer(-species, names_to = 'source_sample_id', values_to = 'count') |>
    dplyr::mutate(count = tidyr::replace_na(as.numeric(count), 0)) |>
    dplyr::group_by(source_sample_id, species) |>
    dplyr::summarise(occurrence = as.integer(sum(count) > 0), .groups = 'drop') |>
    dplyr::left_join(noca_ids |> dplyr::select(source_sample_id, sample_id),
                    by = 'source_sample_id', relationship = 'many-to-one')
  samples = dplyr::bind_rows(mora_ids, noca_ids) |>
    dplyr::arrange(site, lake, depth_cm, sample_id)
  occurrence = dplyr::bind_rows(mora_occ |> dplyr::select(sample_id, species, occurrence),
                              noca_occ |> dplyr::select(sample_id, species, occurrence)) |>
    dplyr::group_by(sample_id, species) |>
    dplyr::summarise(occurrence = as.integer(any(occurrence == 1)), .groups = 'drop')
  if (anyDuplicated(samples$sample_id) || anyNA(samples) || anyNA(occurrence) ||
      any(!is.finite(samples$depth_cm)) || any(!occurrence$occurrence %in% 0:1))
    stop('Invalid original sample identities, depths or botanical records')
  # Preserve a lookup to the old merged identifiers solely for regression audit.
  historical = readr::read_csv(here::here('output/paleo_sample_depths.csv'),
                               show_col_types = FALSE) |>
    dplyr::select(lake, depth_cm = depth, historical_plot_id = plot_id, historical_median_age = median_age)
  if (anyDuplicated(historical[c('lake', 'depth_cm')])) stop('Ambiguous historical depth register')
  samples = samples |> dplyr::left_join(historical, by = c('lake', 'depth_cm'), relationship = 'many-to-one')
  if (anyNA(samples$historical_plot_id)) stop('Original sample missing from historical depth register')
  list(samples = samples, occurrence = occurrence)
}

reconstruction_project_samples = function(original, reference) {
  if (!identical(reference$scaling, 'sites') || !identical(reference$hill, FALSE) ||
      !identical(reference$axes, 1:2) || nrow(reference$legacy_species) != 607L ||
      length(reference$retained_species) != 14L)
    stop('Expected the fixed 607-plot, 14-taxon CCA1–CCA2 calibration')
  samples = original$samples
  taxa = reference$retained_species
  x = matrix(0, nrow(samples), length(taxa), dimnames = list(samples$sample_id, taxa))
  occurrence = original$occurrence |> dplyr::filter(species %in% taxa)
  x[cbind(match(occurrence$sample_id, samples$sample_id), match(occurrence$species, taxa))] = occurrence$occurrence
  samples$n_retained_taxa = as.integer(rowSums(x))
  samples$eligible = samples$n_retained_taxa > 0L
  samples$exclusion = ifelse(samples$eligible, NA_character_, 'no_retained_calibration_taxa')
  samples$observed_CCA1 = samples$observed_CCA2 = NA_real_
  use = which(samples$eligible)
  wa = stats::predict(reference$model, newdata = x[use, , drop = FALSE],
                       type = 'wa', scaling = 'sites', hill = FALSE)[, 1:2, drop = FALSE]
  basis = vegan::scores(reference$model, display = 'species', choices = 1:2,
                         scaling = 'sites', hill = FALSE)[taxa, , drop = FALSE]
  weights = x[use, , drop = FALSE] / rowSums(x[use, , drop = FALSE])
  independently_projected = sweep(weights, 2, reference$model$colsum, '-') %*% basis
  error = max(abs(wa - independently_projected))
  if (!is.finite(error) || error > 1e-10) stop('Independent sample-level WA scaling check failed')
  samples$observed_CCA1[use] = wa[, 1]
  samples$observed_CCA2[use] = wa[, 2]
  list(samples = samples, species_matrix = x, max_wa_error = error)
}

reconstruction_original_age_draws = function(samples, cache_path, n_draws = 1000L, seed = 42L) {
  source(here::here('R/helpers/bacon_settings.R'), local = TRUE)
  cores = unique(samples$lake)
  source_files = unlist(lapply(cores, function(core) list.files(here::here('Cores', core),
    pattern = '[.](out|bacon|csv)$', full.names = TRUE)), use.names = FALSE)
  signature = object_fingerprint(list(samples = samples[c('site', 'lake', 'sample_id', 'depth_cm')],
    md5 = tools::md5sum(source_files), settings = CORE_ARGS[cores],
    reader_md5 = tools::md5sum(here::here('R/helpers/bacon_settings.R')),
    reader_code = paste(deparse(body(reconstruction_original_age_draws)), collapse = '\n'),
    n_draws = n_draws, seed = seed,
    rbacon_version = as.character(utils::packageVersion('rbacon'))))
  if (file.exists(cache_path)) {
    cached = readRDS(cache_path)
    if (identical(cached$signature, signature)) return(cached)
  }
  scratch = tempfile('paleoaces-core-read-')
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  had_info = exists('info', envir = .GlobalEnv, inherits = FALSE)
  previous_info = if (had_info) get('info', envir = .GlobalEnv) else NULL
  on.exit(if (had_info) assign('info', previous_info, envir = .GlobalEnv) else
    if (exists('info', envir = .GlobalEnv, inherits = FALSE)) rm('info', envir = .GlobalEnv), add = TRUE)
  has_seed = exists('.Random.seed', envir = .GlobalEnv, inherits = FALSE)
  old_seed = if (has_seed) get('.Random.seed', envir = .GlobalEnv) else NULL
  on.exit(if (has_seed) assign('.Random.seed', old_seed, envir = .GlobalEnv) else
    if (exists('.Random.seed', envir = .GlobalEnv, inherits = FALSE)) rm('.Random.seed', envir = .GlobalEnv), add = TRUE)
  draws = rows = evaluators = list()
  for (core in cores) {
    message('Reading stored whole chronologies: ', core)
    destination = file.path(scratch, core)
    dir.create(destination)
    files = list.files(here::here('Cores', core), full.names = TRUE, all.files = TRUE, no.. = TRUE)
    if (!all(file.copy(files, destination, recursive = TRUE, copy.date = TRUE)))
      stop('Cannot copy core for read-only evaluation')
    # Bacon's setup is restricted to the temporary core copy. Read every stored
    # row without MCMC resampling/thinning, preserving exact row identities.
    do.call(rbacon::Bacon, c(list(core = core, coredir = scratch, run = FALSE,
      suggest = FALSE, ask = FALSE, remember = FALSE, plot.pdf = FALSE, verbose = FALSE), CORE_ARGS[[core]]))
    model = get('info', envir = .GlobalEnv)
    posterior = file.path(destination, paste0(core, '_', model$K, '.out'))
    model = rbacon:::Bacon.AnaOut(posterior, model, MCMC.resample = FALSE)
    if (nrow(model$output) < n_draws) stop(core, ': fewer than ', n_draws, ' stored whole posterior rows')
    if (isTRUE(model$BCAD) || any(!is.na(model$hiatus.depths)))
      stop('Audit independent reconstruction requires the current cal-BP, no-hiatus core settings')
    set.seed(seed)
    selected = sample.int(nrow(model$output), n_draws, replace = FALSE)
    metadata = samples[samples$lake == core, ] |> dplyr::arrange(depth_cm, sample_id)
    ages = vapply(metadata$depth_cm, function(depth)
      rbacon::Bacon.Age.d(depth, set = model, its = model$output[selected, , drop = FALSE]), numeric(n_draws))
    if (any(!is.finite(ages)) || any(apply(ages, 1, function(x) any(diff(x) < -1e-8))))
      stop('Incomplete/nonmonotone whole chronologies: ', core)
    draws[[core]] = tibble::tibble(site = metadata$site[rep(seq_len(nrow(metadata)), each = n_draws)],
      lake = core, sample_id = rep(metadata$sample_id, each = n_draws),
      draw = rep(seq_len(n_draws), nrow(metadata)), age_cal_bp = as.vector(ages))
    rows[[core]] = tibble::tibble(lake = core, draw = seq_len(n_draws),
      posterior_row = selected, n_stored_rows = nrow(model$output),
      source = file.path('Cores', core, basename(posterior)), seed = seed)
    adjusted = if (length(model$slump)) rbacon:::toslump(metadata$depth_cm, model$slump, remove = FALSE) else metadata$depth_cm
    section = vapply(adjusted, function(x) max(which(model$elbows <= x)), integer(1))
    evaluators[[core]] = tibble::tibble(lake = core, sample_id = metadata$sample_id,
      depth_cm = metadata$depth_cm, slump_adjusted_depth_cm = adjusted,
      section_index = section, section_start_cm = model$elbows[section], thickness_cm = model$thick)
  }
  result = list(draws = dplyr::bind_rows(draws), posterior_rows = dplyr::bind_rows(rows),
    depth_evaluation = dplyr::bind_rows(evaluators), n_draws = n_draws, seed = seed,
    signature = signature, source_md5 = tools::md5sum(source_files))
  if (nrow(result$draws) != nrow(samples) * n_draws ||
      anyDuplicated(result$draws[c('sample_id', 'draw')])) stop('Incomplete original-sample draw cache')
  saveRDS(result, cache_path)
  result
}

reconstruction_native_grid = function(ponds) {
  grid = ponds |> dplyr::distinct(site, lake, century_cal_bp = cal_BP) |>
    dplyr::mutate(lower_cal_bp = century_cal_bp - 50, upper_cal_bp = century_cal_bp + 50) |>
    dplyr::arrange(site, lake, century_cal_bp)
  if (!nrow(grid) || anyNA(grid) || anyDuplicated(grid[c('lake', 'century_cal_bp')]) ||
      any(!is.finite(grid$century_cal_bp)) || any(grid$century_cal_bp %% 100 != 50))
    stop('Invalid native CHELSA century grid')
  regular = grid |> dplyr::group_by(lake) |>
    dplyr::summarise(ok = all(diff(century_cal_bp) == 100), .groups = 'drop')
  if (!all(regular$ok)) stop('Native climate grid contains missing or overlapping cells')
  grid
}

reconstruction_century_assignments = function(draws, samples, grid) {
  eligible = samples |> dplyr::filter(eligible) |>
    dplyr::select(sample_id, observed_CCA1, observed_CCA2)
  assignments = draws |> dplyr::inner_join(eligible, by = 'sample_id', relationship = 'many-to-one')
  assignments$century_cal_bp = NA_real_
  for (core in unique(assignments$lake)) {
    cell = grid[grid$lake == core, ]
    use = which(assignments$lake == core)
    index = findInterval(assignments$age_cal_bp[use], cell$lower_cal_bp)
    inside = index > 0L
    inside[inside] = assignments$age_cal_bp[use][inside] < cell$upper_cal_bp[index[inside]]
    assignments$century_cal_bp[use[inside]] = cell$century_cal_bp[index[inside]]
  }
  assignments$exclusion = ifelse(is.na(assignments$century_cal_bp), 'outside_native_climate_grid', NA_character_)
  assignments
}

reconstruction_century_products = function(assignments, grid, n_draws) {
  centroids = assignments |> dplyr::filter(!is.na(century_cal_bp)) |>
    dplyr::group_by(site, lake, draw, century_cal_bp) |>
    dplyr::summarise(observed_CCA1 = mean(observed_CCA1), observed_CCA2 = mean(observed_CCA2),
      n_samples = dplyr::n(), .groups = 'drop')
  positions = centroids |> dplyr::group_by(site, lake, century_cal_bp) |>
    # Quantiles precede names that replace source coordinates in summarise().
    dplyr::summarise(CCA1_q025 = quantile(observed_CCA1, .025, names = FALSE),
      CCA1_q975 = quantile(observed_CCA1, .975, names = FALSE),
      CCA2_q025 = quantile(observed_CCA2, .025, names = FALSE),
      CCA2_q975 = quantile(observed_CCA2, .975, names = FALSE),
      observed_CCA1 = median(observed_CCA1), observed_CCA2 = median(observed_CCA2),
      n_occupied_draws = dplyr::n_distinct(draw), n_draws_nmin2 = sum(n_samples >= 2),
      n_samples_median = median(n_samples), .groups = 'drop')
  positions = grid |> dplyr::left_join(positions, by = c('site', 'lake', 'century_cal_bp'),
                                      relationship = 'one-to-one') |>
    dplyr::mutate(n_expected_draws = n_draws,
      n_occupied_draws = tidyr::replace_na(n_occupied_draws, 0L),
      n_draws_nmin2 = tidyr::replace_na(n_draws_nmin2, 0L),
      occupancy_proportion = n_occupied_draws / n_draws,
      occupied = n_occupied_draws > 0L)
  list(centroids = centroids, positions = positions)
}

reconstruction_transition_scenarios = function(positions, centroids, thresholds) {
  if (!length(thresholds) || any(!is.finite(thresholds) | thresholds < 0 | thresholds > 1))
    stop('Diagnostic thresholds must be proportions between zero and one')
  presence = split(centroids$draw, paste(centroids$lake, centroids$century_cal_bp, sep = '|'))
  dplyr::bind_rows(lapply(thresholds, function(threshold) {
    selected = positions |> dplyr::filter(occupied, occupancy_proportion >= threshold) |>
      dplyr::arrange(site, lake, dplyr::desc(century_cal_bp)) |>
      dplyr::group_by(site, lake) |>
      dplyr::mutate(age_lo = dplyr::lead(century_cal_bp),
        n_occupied_draws_t2 = dplyr::lead(n_occupied_draws),
        occupancy_t2 = dplyr::lead(occupancy_proportion)) |>
      dplyr::ungroup() |> dplyr::filter(!is.na(age_lo)) |>
      dplyr::transmute(scenario_threshold = threshold, site, lake, age_hi = century_cal_bp, age_lo,
        interval_mid_cal_bp = (age_hi + age_lo) / 2, duration_years = age_hi - age_lo,
        n_expected_draws, n_occupied_draws_t1 = n_occupied_draws, n_occupied_draws_t2,
        occupancy_t1 = occupancy_proportion, occupancy_t2)
    selected$n_joint_draws = vapply(seq_len(nrow(selected)), function(i)
      length(intersect(presence[[paste(selected$lake[i], selected$age_hi[i], sep = '|')]],
                       presence[[paste(selected$lake[i], selected$age_lo[i], sep = '|')]])), integer(1))
    selected$joint_occupancy_proportion = selected$n_joint_draws / selected$n_expected_draws
    selected$n_native_centuries_between = as.integer(selected$duration_years / 100 - 1)
    selected$n_unoccupied_centuries_between = vapply(seq_len(nrow(selected)), function(i)
      sum(positions$lake == selected$lake[i] & positions$century_cal_bp > selected$age_lo[i] &
          positions$century_cal_bp < selected$age_hi[i] & !positions$occupied), integer(1))
    selected$n_occupied_centuries_skipped = selected$n_native_centuries_between - selected$n_unoccupied_centuries_between
    selected
  }))
}

reconstruction_transition_fire = function(intervals, events, series) {
  keys = c('site', 'age_hi', 'age_lo')
  # NOCA exposure is explicitly its Panther Potholes record, even if another
  # source core is added to the input catalog later.
  series = series |> dplyr::filter(site != 'NOCA' | lake == 'PantherPotholes')
  events = events |> dplyr::filter(site != 'NOCA' | lake == 'PantherPotholes')
  intervals = intervals |> dplyr::select(dplyr::all_of(keys)) |> dplyr::distinct()
  if (any(intervals$age_hi <= intervals$age_lo) ||
      anyNA(events[c('site', 'lake', 'age_cal_yr_BP')]) ||
      anyNA(series[c('site', 'lake', 'age_cal_yr_BP', 'char_interpolated')]) ||
      anyDuplicated(events[c('site', 'lake', 'age_cal_yr_BP')])) stop('Invalid fire inputs')
  # Coverage is based on each complete, regularly sampled accepted-event source
  # series, never on the first/last detected event. Reject internal gaps.
  coverage = series |> dplyr::arrange(site, lake, age_cal_yr_BP) |>
    dplyr::group_by(site, lake) |>
    dplyr::summarise(younger_cal_bp = min(age_cal_yr_BP), older_cal_bp = max(age_cal_yr_BP),
      regular = dplyr::n() >= 2L && all(is.finite(char_interpolated)) &&
        max(abs(diff(age_cal_yr_BP) - median(diff(age_cal_yr_BP)))) < 1e-6,
      .groups = 'drop') |> dplyr::rename(fire_core = lake)
  if (!all(coverage$regular)) stop('Fire source series contains nonfinite values or internal coverage gaps')
  exposure = intervals |> dplyr::left_join(coverage, by = 'site', relationship = 'many-to-many') |>
    dplyr::mutate(duration_years = age_hi - age_lo,
      coverage_fraction = pmax(0, pmin(age_hi, older_cal_bp) - pmax(age_lo, younger_cal_bp)) / duration_years,
      fully_covered = age_lo >= younger_cal_bp & age_hi <= older_cal_bp)
  if (anyNA(exposure$fire_core)) stop('Missing charcoal source for a site')
  exposure$accepted_event_count = vapply(seq_len(nrow(exposure)), function(i) {
    if (!exposure$fully_covered[i]) return(NA_integer_)
    as.integer(sum(events$site == exposure$site[i] & events$lake == exposure$fire_core[i] &
      events$age_cal_yr_BP >= exposure$age_lo[i] & events$age_cal_yr_BP < exposure$age_hi[i]))
  }, integer(1))
  exposure$frequency_per_century = exposure$accepted_event_count * 100 / exposure$duration_years
  regional = exposure |> dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::summarise(fire_covered_cores = sum(fully_covered),
      fire_required_cores = ifelse(dplyr::first(site) == 'MORA', 2L, 1L),
      fire_coverage_valid = fire_covered_cores >= fire_required_cores,
      fire_activity = if (fire_coverage_valid) mean(frequency_per_century[fully_covered]) else NA_real_,
      fire_source_ids = paste(sort(fire_core[fully_covered]), collapse = ';'),
      fire_shared_regional_history = dplyr::first(site) == 'MORA', .groups = 'drop')
  list(core = exposure, regional = regional)
}

reconstruction_stat = function(x, fun, ...) {
  x = x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  fun(x, ...)
}

reconstruction_scenario_summary = function(positions, pairs, thresholds) {
  counts = dplyr::bind_rows(lapply(thresholds, function(threshold)
    positions |> dplyr::group_by(site, lake) |>
      dplyr::summarise(scenario_threshold = threshold, n_native_centuries = dplyr::n(),
        n_occupied_centuries = sum(occupied),
        n_scenario_centuries = sum(occupied & occupancy_proportion >= threshold), .groups = 'drop')))
  support = pairs |> dplyr::group_by(scenario_threshold, site, lake) |>
    dplyr::summarise(n_candidate_transitions = dplyr::n(),
      n_gaps_over_100yr = sum(duration_years > 100),
      n_transitions_with_unoccupied_centuries = sum(n_unoccupied_centuries_between > 0),
      n_transitions_with_skipped_occupied_centuries = sum(n_occupied_centuries_skipped > 0),
      duration_min = min(duration_years), duration_median = median(duration_years),
      duration_max = max(duration_years), n_joint_support_zero = sum(n_joint_draws == 0),
      joint_support_q025 = reconstruction_stat(joint_occupancy_proportion, quantile, probs = .025, names = FALSE),
      joint_support_median = median(joint_occupancy_proportion),
      joint_support_q975 = reconstruction_stat(joint_occupancy_proportion, quantile, probs = .975, names = FALSE),
      n_joint_support_under_10pct = sum(joint_occupancy_proportion < .10),
      n_joint_support_under_25pct = sum(joint_occupancy_proportion < .25),
      n_joint_support_under_50pct = sum(joint_occupancy_proportion < .50),
      n_fire_missing_transitions = sum(!fire_coverage_valid),
      n_fire_valid_transitions = sum(fire_coverage_valid), .groups = 'drop')
  result = counts |> dplyr::left_join(support, by = c('scenario_threshold', 'site', 'lake'),
                                     relationship = 'one-to-one')
  count_cols = setdiff(grep('^n_', names(result), value = TRUE), names(counts))
  result |> dplyr::mutate(dplyr::across(dplyr::all_of(count_cols), ~tidyr::replace_na(.x, 0L))) |>
    dplyr::arrange(site, lake, scenario_threshold)
}

reconstruction_support_plots = function(positions, pairs, summary) {
  lakes = c('JayBath', 'LogWallow', 'ReflectionPond', 'PantherPotholes')
  labels = c('Jay Bath · MORA', 'Log Wallow · MORA', 'Reflection Pond · MORA', 'Panther Potholes · NOCA')
  counts = summary[summary$scenario_threshold == 0, ]
  facet_names = setNames(vapply(lakes, function(lake) {
    x = counts[counts$lake == lake, ]
    paste0(labels[match(lake, lakes)], '\n', x$n_occupied_centuries, ' centuries · ',
      x$n_candidate_transitions, ' transitions')
  }, character(1)), lakes)
  factor_lake = function(x) {x$lake = factor(x$lake, levels = lakes); x}
  positions = factor_lake(positions)
  pairs = factor_lake(pairs[pairs$scenario_threshold == 0, ])
  colors = c(MORA = '#648FFF', NOCA = '#FE6100')
  common = ggplot2::theme_bw(base_size = 17) + ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    strip.background = ggplot2::element_rect(fill = 'grey95', color = NA),
    strip.text = ggplot2::element_text(size = 16, face = 'bold'),
    axis.text = ggplot2::element_text(size = 14),
    plot.title = ggplot2::element_text(size = 19, face = 'bold'),
    legend.position = 'none', plot.margin = ggplot2::margin(8, 10, 8, 8))
  facets = ggplot2::facet_wrap(~lake, nrow = 1, labeller = ggplot2::as_labeller(facet_names))
  site_scale = ggplot2::scale_color_manual(values = colors, guide = 'none')
  site_fill = ggplot2::scale_fill_manual(values = colors, guide = 'none')
  occupancy = ggplot2::ggplot(positions, ggplot2::aes(century_cal_bp, occupancy_proportion * 100, color = site)) +
    ggplot2::geom_hline(yintercept = c(25, 50, 75), color = 'grey75', linetype = 'dotted') +
    ggplot2::geom_line(linewidth = .55) + ggplot2::geom_point(size = 1.4, alpha = .75) +
    facets + site_scale + ggplot2::scale_x_reverse(labels = scales::label_comma(), breaks = seq(0, 12000, 2500)) +
    ggplot2::scale_y_continuous(limits = c(0, 100), breaks = c(0, 25, 50, 75, 100)) +
    ggplot2::labs(title = 'Century occupancy through time', x = 'Native century (cal BP)', y = 'Bacon draws (%)') + common
  occupancy_distribution = ggplot2::ggplot(positions[positions$occupied, ],
      ggplot2::aes(occupancy_proportion * 100, fill = site)) +
    ggplot2::geom_histogram(binwidth = 5, boundary = 0, color = 'white', alpha = .8) +
    facets + site_fill + ggplot2::scale_x_continuous(breaks = c(0, 25, 50, 75, 100), limits = c(0, 100)) +
    ggplot2::labs(title = 'Occupancy distribution among occupied centuries', x = 'Occupied draws (%)', y = 'Centuries') + common
  joint = ggplot2::ggplot(pairs, ggplot2::aes(joint_occupancy_proportion * 100, fill = site)) +
    ggplot2::geom_histogram(binwidth = 5, boundary = 0, color = 'white', alpha = .8) +
    facets + site_fill + ggplot2::scale_x_continuous(breaks = c(0, 25, 50, 75, 100), limits = c(0, 100)) +
    ggplot2::labs(title = 'Joint occupancy of candidate transition endpoints', x = 'Draws with both endpoints (%)', y = 'Transitions') + common
  durations = ggplot2::ggplot(pairs, ggplot2::aes(factor(duration_years), fill = site)) +
    ggplot2::geom_bar(width = .65, color = 'white', alpha = .8) +
    facets + site_fill +
    ggplot2::labs(title = 'Candidate transition durations without a cutoff', x = 'Elapsed time (years)', y = 'Transitions') + common
  first = patchwork::wrap_plots(occupancy, occupancy_distribution, joint, durations, ncol = 1) +
    patchwork::plot_annotation(title = 'Holocene reconstruction support · 1,000 whole Bacon draws',
      subtitle = 'All occupied centuries are retained here. Dotted reference lines are not inclusion rules.',
      theme = ggplot2::theme(plot.title = ggplot2::element_text(size = 24, face = 'bold'),
        plot.subtitle = ggplot2::element_text(size = 18)))
  long = factor_lake(summary) |>
    dplyr::select(site, lake, scenario_threshold, n_scenario_centuries,
      n_candidate_transitions, n_gaps_over_100yr, n_fire_missing_transitions) |>
    tidyr::pivot_longer(dplyr::starts_with('n_'), names_to = 'quantity', values_to = 'count') |>
    dplyr::mutate(quantity = factor(quantity, levels = c('n_scenario_centuries', 'n_candidate_transitions',
      'n_gaps_over_100yr', 'n_fire_missing_transitions'),
      labels = c('Centuries meeting scenario', 'Candidate transitions', 'Gaps exceeding 100 years', 'Transitions lacking fire coverage')))
  second = ggplot2::ggplot(long, ggplot2::aes(scenario_threshold * 100, count, color = site)) +
    ggplot2::geom_line(linewidth = .8) + ggplot2::geom_point(size = 2.4) +
    ggplot2::facet_grid(quantity ~ lake, scales = 'free_y', labeller = ggplot2::labeller(lake = setNames(labels, lakes))) +
    site_scale + ggplot2::scale_x_continuous(breaks = c(0, 10, 25, 50, 75, 90, 100)) +
    ggplot2::labs(title = 'Support scenarios · no primary cutoff selected',
      subtitle = 'Transition pairs are rebuilt for every scenario; no model is fitted.',
      x = 'Diagnostic minimum century occupancy (%)', y = 'Count') + common +
    ggplot2::theme(plot.title = ggplot2::element_text(size = 24), plot.subtitle = ggplot2::element_text(size = 18))
  list(support = first, scenarios = second, occupancy_histogram = occupancy_distribution,
       joint_histogram = joint, duration_histogram = durations)
}

reconstruction_protected_files = function() {
  trees = c('Cores', 'output/exploratory', 'output/cca_transition_contributions', 'plot', 'docs/assets/analysis')
  files = c(unlist(lapply(trees, function(x) list.files(here::here(x), recursive = TRUE,
    full.names = TRUE, all.files = TRUE)), use.names = FALSE),
    list.files(here::here('output'), full.names = TRUE, all.files = TRUE),
    here::here(c('docs/ANALYSIS_REVIEW.md', 'docs/ANALYSIS_REVIEW.html',
      'docs/review/00_main_analysis_review.R')))
  files = sort(unique(files[file.exists(files) & !dir.exists(files)]))
  files[!grepl('fig_holocene_reconstruction_support([._]|$)', basename(files))]
}

reconstruction_report = function(tables, checks, output_dir, figure_stem) {
  summary = tables$scenario_support
  format_table = function(x) {
    x[] = lapply(x, function(v) if (is.numeric(v)) format(round(v, 3), trim = TRUE, scientific = FALSE) else as.character(v))
    c(paste0('| ', paste(names(x), collapse = ' | '), ' |'),
      paste0('| ', paste(rep('---', ncol(x)), collapse = ' | '), ' |'),
      apply(x, 1, function(v) paste0('| ', paste(v, collapse = ' | '), ' |')))
  }
  source = tables$sample_summary |> dplyr::select(lake, n_original_samples, n_eligible_samples,
    n_historical_ids, n_restored_sample_identities)
  all = summary |> dplyr::filter(scenario_threshold == 0) |>
    dplyr::transmute(lake, occupied_centuries = n_occupied_centuries,
      candidate_transitions = n_candidate_transitions, gaps_over_100yr = n_gaps_over_100yr,
      joint_support_median = joint_support_median,
      zero_joint_support = n_joint_support_zero, missing_fire = n_fire_missing_transitions)
  occupancy = tables$occupancy_summary |> dplyr::transmute(lake,
    empty_native_centuries = n_empty_centuries,
    occupancy_q025_pct = occupancy_q025 * 100,
    occupancy_median_pct = occupancy_median * 100,
    occupancy_q975_pct = occupancy_q975 * 100)
  calculation = readLines(here::here('R/helpers/holocene_reconstruction.R'))
  first = grep('^  centroids = assignments', calculation)
  last = grep('^  positions = grid', calculation)
  calculation = calculation[seq(first, last - 1L)]
  scenarios = summary |> dplyr::select(lake, scenario_threshold, n_scenario_centuries,
    n_candidate_transitions, n_gaps_over_100yr, duration_max, joint_support_median,
    n_joint_support_zero, n_fire_missing_transitions)
  lines = c('# Holocene century reconstruction: support audit', '',
    '**Decision pending.** This is a diagnostic reconstruction, not a replacement model input. ',
    'No occupancy or joint-support inclusion cutoff has been applied to a primary analysis.', '',
    'Run: `Rscript R/stages/08_tracking_metrics.R --reconstruction-audit`.', '',
    '## Reconstruction', '',
    'Original macrofossil samples are identified by core depth (MORA) or Neotoma sample ID (NOCA). ',
    'Taxonomic categories are harmonized within each original sample; samples sharing a median age remain separate. ',
    'The fixed 607-plot, 14-taxon CCA projects sample WA positions before averaging. ',
    'The audit uses 1,000 complete chronology rows per core from the existing stored Bacon posteriors, without MCMC or sampling with replacement. ',
    'Bacon evaluates temporary core copies; the source posteriors and configurations are unchanged.', '',
    'Samples are assigned to each lake\'s native CHELSA intervals `[lower, upper)`. ',
    'Centroids average sample WA positions within each draw and century. Reconstructed coordinates are medians of the centroids across occupied draws. ',
    'Occupancy is the number of draws containing at least one eligible sample, divided by 1,000. ',
    'Empty centuries have zero occupancy and undefined coordinates. Coordinate quantiles are conditional on occupied draws, not model confidence intervals.', '',
    'The calculation excerpt below is taken directly from the maintained helper:', '',
    '```r', calculation, '```', '',
    '## Original sample identities', '', format_table(source), '',
    '## Occupancy distributions', '', format_table(occupancy), '',
    'Occupancy quantiles here describe occupied centuries only; empty native centuries are counted separately.', '',
    '## Reconstruction without a cutoff', '', format_table(all), '',
    'Candidate transitions connect successive occupied centuries in older-to-younger order. ',
    'Joint support counts draws in which both exact endpoints contain samples. Zero joint support cannot supply a species contribution, even though independently reconstructed endpoint medians exist. ',
    'Low support does not mean the samples were observed independently every century. ',
    'No vegetation interpolation, extrapolation, equal-lake coverage requirement or ecological bin offset is used.', '',
    '## Diagnostic support scenarios', '', format_table(scenarios), '',
    'These scenarios do not select a cutoff. Each scenario reconstructs its own endpoint pairs; ',
    'a transition joining two retained centuries can span unoccupied centuries or occupied centuries skipped by that scenario. ',
    'Those two causes are counted separately. Empty scenarios contain zero counts and unavailable distribution statistics.', '',
    'A stronger occupancy cutoff can also create long bridges by excluding occupied intermediate centuries. ',
    'Inspect `duration_max` alongside the support distributions before choosing a rule; no maximum-gap exclusion is imposed here.', '',
    '## Fire coverage', '',
    'Fire activity counts accepted events over the entire `[age_lo, age_hi)` transition. ',
    'A fully covered core contributes `event_count * 100 / duration_years` events per century. ',
    'MORA requires at least two fully covered regional cores and averages them equally; NOCA requires Panther Potholes coverage. ',
    'The unit is events per century per eligible core. Covered zero-event windows are zero; missing coverage is NA. ',
    'The three MORA vegetation lakes share the regional charcoal history. Counts of distinct shared exposures are exported separately. ',
    'This audit does not change the normalized 1,000-year fire predictor or CC/S descriptive classification.', '',
    '## Figures', '',
    paste0('![Occupancy, joint support and durations](../../plot/test_figures/', basename(figure_stem), '.png)'), '',
    paste0('![Support scenario counts](../../plot/test_figures/', basename(figure_stem), '_scenarios.png)'), '',
    paste0('[Two-page PDF](../../plot/test_figures/', basename(figure_stem), '.pdf)'), '',
    '## Files and validation', '',
    paste0('Tables and the independent audit draw cache: `', sub(paste0(here::here(), '/'), '', output_dir, fixed = TRUE), '/`.'), '',
    '- `original_samples.csv`: original identities, eligibility, WA, depths and historical-ID lookup.',
    '- `century_draws.csv`: occupied draw/century centroids and sample counts.',
    '- `century_positions.csv`: every native century, coordinates, occupancy and conditional quantiles.',
    '- `occupancy_summary.csv`: per-lake occupancy distributions and empty-century counts.',
    '- `joint_occupancy_by_transition.csv`: no-cutoff endpoint pairs and joint support.',
    '- `all_transition_scenarios.csv` and `scenario_support.csv`: candidate pairs and scenario summaries.',
    '- `fire_core_exposure.csv`, `fire_interval_exposure.csv`, `shared_fire_support.csv`: event counts, frequencies, coverage and distinct shared exposures.',
    '- `posterior_rows.csv`, `depth_evaluation.csv`, `age_draws.rds`: exact whole-row chronology provenance.',
    '- `sample_draw_exclusions.csv`: eligible sample draws outside the native climate grid.',
    '- `preservation.csv`, `validation.csv`, `schema.csv`, `provenance.rds`: preservation and checks.', '',
    format_table(checks), '',
    '## Required decisions before primary production', '',
    'Choose century occupancy and species joint occupancy separately after inspecting these distributions. ',
    'Both policy values remain unset in `R/helpers/holocene_reconstruction_settings.R`; the primary century mode refuses to proceed. ',
    'The subsequent migration includes species GLS models in stage 17: Holocene `site + climate_rate + fire_activity`; Anthropocene `site + burned` only. ',
    'The current 1,000-year model inputs, fitted models, manuscript figures and full Analysis Review have not been replaced.', '')
  markdown = here::here('docs/review/HOLOCENE_RECONSTRUCTION_SUPPORT.md')
  writeLines(lines, markdown)
  if (!rmarkdown::pandoc_available()) stop('Pandoc is required to publish the support review HTML')
  rmarkdown::pandoc_convert(markdown, to = 'html', output = sub('[.]md$', '.html', markdown),
    options = c('--standalone', '--embed-resources', '--metadata',
      'title=Holocene century reconstruction support audit'))
}

run_holocene_reconstruction_audit = function() {
  # Some plotting/setup libraries request a graphics device even in read mode.
  # Discard incidental graphics instead of allowing a root Rplots.pdf artifact.
  grDevices::pdf(file = NULL)
  discard_device = grDevices::dev.cur()
  on.exit(if (discard_device %in% grDevices::dev.list()) grDevices::dev.off(discard_device), add = TRUE)
  output_dir = here::here('output/reconstruction_audit')
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  protected = reconstruction_protected_files()
  before = tools::md5sum(protected)
  verify_preserved = function() {
    current = reconstruction_protected_files()
    if (!identical(current, protected) || anyNA(tools::md5sum(protected)) ||
        !identical(unname(before), unname(tools::md5sum(protected))))
      stop('Support audit changed a protected primary output, chronology input or figure')
    invisible(TRUE)
  }
  on.exit(verify_preserved(), add = TRUE)
  reference_path = here::here('output/cca_calibration_reference.rds')
  reference = readRDS(reference_path)
  if (any(tools::md5sum(names(reference$provenance$input_md5)) != reference$provenance$input_md5) ||
      any(tools::md5sum(names(reference$provenance$model_source_md5)) != reference$provenance$model_source_md5))
    stop('Frozen CCA reference inputs or sources no longer match; do not refit automatically')
  if (as.character(utils::packageVersion('vegan')) != reference$provenance$vegan_version)
    stop('Installed vegan differs from frozen calibration')
  original = reconstruction_read_original_samples()
  projected = reconstruction_project_samples(original, reference)
  # Verify that collapsing the restored identities under their historical IDs
  # recovers the old retained-taxon occurrences. This checks harmonization only,
  # not agreement of new century metrics with the historical pooled analysis.
  pooled = rowsum(projected$species_matrix, projected$samples$historical_plot_id, reorder = FALSE) > 0
  old = readr::read_csv(here::here('output/occ_consolidated.csv'), show_col_types = FALSE) |>
    dplyr::filter(period == 'paleo', species %in% reference$retained_species)
  expected = matrix(FALSE, nrow(pooled), ncol(pooled), dimnames = dimnames(pooled))
  expected[cbind(match(old$plot_id, rownames(expected)), match(old$species, colnames(expected)))] = old$occurrence > 0
  if (!identical(pooled, expected)) stop('Original-sample taxon harmonization does not recover historical retained occurrences')
  age_cache = reconstruction_original_age_draws(projected$samples, file.path(output_dir, 'age_draws.rds'),
    HOLOCENE_RECONSTRUCTION_DRAWS, HOLOCENE_RECONSTRUCTION_SEED)
  ponds = readr::read_csv(here::here('output/chelsa_paleo_ponds.csv'), show_col_types = FALSE)
  grid = reconstruction_native_grid(ponds)
  assignments = reconstruction_century_assignments(age_cache$draws, projected$samples, grid)
  products = reconstruction_century_products(assignments, grid, HOLOCENE_RECONSTRUCTION_DRAWS)
  pairs = reconstruction_transition_scenarios(products$positions, products$centroids, HOLOCENE_SUPPORT_SCENARIOS)
  fire = reconstruction_transition_fire(pairs,
    readr::read_csv(here::here('output/holocene_fire_source_events.csv'), show_col_types = FALSE),
    readr::read_csv(here::here('output/holocene_fire_source_series.csv'), show_col_types = FALSE))
  pairs = pairs |> dplyr::left_join(fire$regional, by = c('site', 'age_hi', 'age_lo'), relationship = 'many-to-one')
  summary = reconstruction_scenario_summary(products$positions, pairs, HOLOCENE_SUPPORT_SCENARIOS)
  sample_summary = projected$samples |> dplyr::group_by(site, lake) |>
    dplyr::summarise(n_original_samples = dplyr::n(), n_eligible_samples = sum(eligible),
      n_excluded_samples = sum(!eligible), n_historical_ids = dplyr::n_distinct(historical_plot_id),
      n_restored_sample_identities = n_original_samples - n_historical_ids, .groups = 'drop')
  occupancy_summary = products$positions |> dplyr::group_by(site, lake) |>
    dplyr::summarise(n_native_centuries = dplyr::n(), n_occupied_centuries = sum(occupied),
      n_empty_centuries = sum(!occupied),
      occupancy_min = reconstruction_stat(occupancy_proportion[occupied], min),
      occupancy_q025 = reconstruction_stat(occupancy_proportion[occupied], quantile, probs = .025, names = FALSE),
      occupancy_q25 = reconstruction_stat(occupancy_proportion[occupied], quantile, probs = .25, names = FALSE),
      occupancy_median = reconstruction_stat(occupancy_proportion[occupied], median),
      occupancy_q75 = reconstruction_stat(occupancy_proportion[occupied], quantile, probs = .75, names = FALSE),
      occupancy_q975 = reconstruction_stat(occupancy_proportion[occupied], quantile, probs = .975, names = FALSE),
      occupancy_max = reconstruction_stat(occupancy_proportion[occupied], max), .groups = 'drop')
  shared = pairs |> dplyr::distinct(scenario_threshold, site, age_hi, age_lo, fire_coverage_valid, fire_covered_cores) |>
    dplyr::group_by(scenario_threshold, site) |>
    dplyr::summarise(n_distinct_exposure_intervals = dplyr::n(),
      n_missing_fire_exposures = sum(!fire_coverage_valid), .groups = 'drop')
  tables = list(original_samples = projected$samples,
    original_sample_occurrences = original$occurrence, sample_summary = sample_summary,
    occupancy_summary = occupancy_summary,
    native_grid = grid, posterior_rows = age_cache$posterior_rows, depth_evaluation = age_cache$depth_evaluation,
    century_draws = products$centroids, century_positions = products$positions,
    joint_occupancy_by_transition = pairs |> dplyr::filter(scenario_threshold == 0),
    all_transition_scenarios = pairs, scenario_support = summary,
    sample_draw_exclusions = assignments |> dplyr::filter(!is.na(exclusion)) |>
      dplyr::select(site, lake, sample_id, draw, age_cal_bp, exclusion),
    fire_core_exposure = fire$core, fire_interval_exposure = fire$regional, shared_fire_support = shared)
  checks = tibble::tibble(check = c('fixed_CCA_sample_WA_identity', 'historical_retained_occurrences',
    'complete_original_sample_draws', 'unique_centroid_keys', 'bounded_occupancy_counts',
    'bounded_joint_counts', 'positive_native_duration', 'zero_fire_missingness_distinction'),
    passed = c(projected$max_wa_error <= 1e-10, identical(pooled, expected),
      nrow(age_cache$draws) == nrow(projected$samples) * HOLOCENE_RECONSTRUCTION_DRAWS,
      !anyDuplicated(products$centroids[c('lake', 'draw', 'century_cal_bp')]),
      all(products$positions$n_occupied_draws >= 0 & products$positions$n_occupied_draws <= HOLOCENE_RECONSTRUCTION_DRAWS),
      all(pairs$n_joint_draws <= pmin(pairs$n_occupied_draws_t1, pairs$n_occupied_draws_t2)),
      all(pairs$duration_years > 0 & pairs$duration_years %% 100 == 0),
      all(is.na(pairs$fire_activity[!pairs$fire_coverage_valid])) &&
        all(is.finite(pairs$fire_activity[pairs$fire_coverage_valid]))))
  if (!all(checks$passed)) stop('Support audit validation failed')
  for (name in names(tables)) readr::write_csv(tables[[name]], file.path(output_dir, paste0(name, '.csv')))
  schema = dplyr::bind_rows(lapply(names(tables), function(name) tibble::tibble(
    dataset = name, column = names(tables[[name]]),
    type = vapply(tables[[name]], function(x) class(x)[1], character(1)),
    unit = vapply(names(tables[[name]]), function(x) {
      if (grepl('CCA', x)) 'CCA_distance' else if (grepl('proportion|occupancy_t|coverage_fraction|threshold', x)) 'proportion' else
      if (grepl('cal_bp$', x)) 'cal_years_BP' else if (grepl('duration', x)) 'years' else
      if (grepl('frequency_per_century|^fire_activity$', x)) 'events_per_century_per_core' else
      if (grepl('cm$', x)) 'cm' else if (grepl('^n_|count|draw$|posterior_row', x)) 'count' else NA_character_
    }, character(1)))))
  readr::write_csv(schema, file.path(output_dir, 'schema.csv'))
  readr::write_csv(checks, file.path(output_dir, 'validation.csv'))
  figure_stem = here::here('plot/test_figures/fig_holocene_reconstruction_support')
  if (isTRUE(getOption('paleoaces.render_figures', TRUE))) {
    figures = reconstruction_support_plots(products$positions, pairs, summary)
    grDevices::cairo_pdf(paste0(figure_stem, '.pdf'), width = 19, height = 19)
    tryCatch({print(figures$support); print(figures$scenarios)}, finally = grDevices::dev.off())
    ggplot2::ggsave(paste0(figure_stem, '.png'), figures$support, width = 19, height = 19, dpi = 160, bg = 'white')
    ggplot2::ggsave(paste0(figure_stem, '_scenarios.png'), figures$scenarios, width = 19, height = 19, dpi = 160, bg = 'white')
    reconstruction_report(tables, checks, output_dir, figure_stem)
  }
  verify_preserved()
  preservation = tibble::tibble(path = sub(paste0(here::here(), '/'), '', protected, fixed = TRUE),
    md5_before = unname(before), md5_after = unname(tools::md5sum(protected)), unchanged = TRUE)
  readr::write_csv(preservation, file.path(output_dir, 'preservation.csv'))
  saveRDS(list(n_draws = HOLOCENE_RECONSTRUCTION_DRAWS, seed = HOLOCENE_RECONSTRUCTION_SEED,
    support_policy = HOLOCENE_SUPPORT_POLICY, diagnostic_thresholds = HOLOCENE_SUPPORT_SCENARIOS,
    age_signature = age_cache$signature, max_independent_WA_error = projected$max_wa_error,
    source_md5 = tools::md5sum(here::here(c('data/PALEO/DunwiddieMacrofossils.xlsx',
      'data/NOCA/NOCA_paleo/dataset52207_site13042.csv', 'output/cca_calibration_reference.rds',
      'output/chelsa_paleo_ponds.csv', 'output/holocene_fire_source_events.csv',
      'output/holocene_fire_source_series.csv', 'R/helpers/holocene_reconstruction_settings.R',
      'R/helpers/holocene_reconstruction.R', 'R/stages/08_tracking_metrics.R'))),
    session = utils::sessionInfo()), file.path(output_dir, 'provenance.rds'))
  print(sample_summary)
  print(summary, n = nrow(summary))
  message('Support audit completed. Primary outputs unchanged; occupancy and species joint-support decisions remain pending.')
  invisible(tables)
}
