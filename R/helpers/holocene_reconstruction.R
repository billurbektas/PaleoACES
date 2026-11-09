# Native-century reconstruction from original samples and a fixed CCA.
# Shared by the posterior-median primary analysis and whole-chronology sensitivity.

reconstruction_read_original_samples = function() {
  mora = readxl::read_excel(here::here('data/PALEO/DunwiddieMacrofossils.xlsx'),
                           sheet = 'MacrofossilData')
  mora_ids = mora |> dplyr::distinct(lake = Location, depth_cm = Depth) |>
    dplyr::mutate(site = 'MORA', source_sample_id = as.character(depth_cm),
      sample_id = paste0(lake, ':depth:', source_sample_id),
      source = 'DunwiddieMacrofossils.xlsx:MacrofossilData')
  # Same within-sample harmonization as 06_paleo_samples.R. No merging
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
