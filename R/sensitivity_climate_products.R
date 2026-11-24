# Sensitivity of the analysis to the Anthropocene climate product (Appendix S5; Bills, 24 Nov 2026).
#
#   Rscript R/sensitivity_climate_products.R [--products prism,nclimgrid] [--offline] [--fetch-only]
#
# The main run takes the Anthropocene climate from CHELSA V2.1 and corrects the
# CHELSA-TraCE21k Holocene climate onto it in two steps (Appendix S2). Against the
# weather stations, V2.1 drifts after about 2004: too warm in spring at MORA and
# west of 121 degrees W at NOCA, far too wet in summer east of it. This script
# reruns the whole analysis (stages 08 to 16) with each of two station-based
# products as the Anthropocene climate instead:
#   prism      PRISM LT81m 800 m (the long-term, temporally consistent dataset)
#   nclimgrid  NOAA nClimGrid monthly, 1/24 degree
# Everything else is the main run's: the same plots, windows and months (the V2.1
# rows of 04_modern_climate with the product's value put in), the same variables,
# and the same two-step correction, with step 2 now CHELSAcruts to the product over
# the same 5 km discs and years (1979 to 2016). Step 1 (TraCE21k to CHELSAcruts)
# does not depend on the product. No raw or one-step runs are made (Bills).
#
# PRISM is read as tmean, which PRISM defines as (tmin + tmax) / 2, and put in both
# tasmin and tasmax. The analysis uses only that midpoint (TEMP_SOURCE = "mean" in
# R/helpers/climate_variables.R; the _min and _max variants are not read after
# stage 08), so MAT, MSpT, MST and MWT and the correction of their midpoint are
# exact (the offsets are additive). nClimGrid is read as tmin and tmax.
#
# Folders, in output_climate_sensitivity/:
#   cache/       the product values (kept between runs, never deleted here)
#   prism/, nclimgrid/   one output root per product (regenerated)
#   comparison/  long tables with a product column, V2.1 from output/ (Appendix S5)
# The main output/ and report/ are never written: their md5 sums are checked at the end.
# The two products run in parallel, one worker process each.
suppressPackageStartupMessages({library(here); library(tidyverse); library(parallel)})
args = commandArgs(trailingOnly = TRUE)
products_arg = sub('^--products=', '', grep('^--products=', args, value = TRUE))
PRODUCTS = if (length(products_arg)) strsplit(products_arg, ',')[[1]] else c('prism', 'nclimgrid')
stopifnot(length(PRODUCTS) > 0, all(PRODUCTS %in% c('prism', 'nclimgrid')))
bad = setdiff(args[!startsWith(args, '--products=')], c('--offline', '--fetch-only'))
if (length(bad)) stop('Unknown option(s): ', paste(bad, collapse = ', '))
options(paleoaces.offline = '--offline' %in% args)
source(here('R/helpers/offline_cache.R'), local = TRUE)

main = here('output')
base = here('output_climate_sensitivity')
CACHE = file.path(base, 'cache')
PRISM_WORKERS = 8L
CORRECTION_YEARS = 1979:2016
# The Holocene climate of a product's run is corrected onto that product in two steps,
# which needs the product at the cells within 5 km of the lakes. PRISM is read only
# at the plots for now (Bills, 24 Nov 2026: avoid the PRISM correction for now, with a
# note), so the PRISM run keeps the Holocene climate of the main analysis, corrected
# onto V2.1. The disc files are still downloaded (they are needed for the correction):
# set prism = 'product' once they are all cached.
HOLOCENE_ONTO = c(prism = 'v21', nclimgrid = 'product')
for (d in file.path(CACHE, c('prism', 'nclimgrid'))) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Points: the plots, lake pixels and 5 km disc cells of stage 07.
points = read_csv(file.path(main, '07_climate_products', 'climate_products_points.csv'), show_col_types = FALSE)
stopifnot(!anyDuplicated(points$id), !anyNA(points[c('lon', 'lat')]))
xy = data.frame(lon = points$lon, lat = points$lat)
windows = lapply(split(seq_len(nrow(points)), points$site), function(i)
  list(rows = i, box = c(min(points$lon[i]) - .05, max(points$lon[i]) + .05, min(points$lat[i]) - .05,
    max(points$lat[i]) + .05)))
# The V2.1 survey-window climate of the main run: its rows are the rows every product fills.
v21_climate = lapply(c(MORA = 'MORA', NOCA = 'NOCA'), function(s)
  read_csv(file.path(main, '04_modern_climate', paste0(s, '_climate.csv')), show_col_types = FALSE))
plot_months = bind_rows(v21_climate) |> distinct(year, month)

# Read a cropped grid at the points of each park; a point on an empty cell takes the
# nearest filled cell of the same crop (counted and printed).
extract_points = function(r) {
  v = matrix(NA_real_, nrow(xy), terra::nlyr(r))
  filled = 0L
  for (w in windows) {
    rc = terra::crop(r, terra::ext(w$box))
    cells = terra::cellFromXY(rc, as.matrix(xy[w$rows, ]))
    empty = is.na(terra::values(rc[[1]], mat = FALSE))
    bad = is.na(cells) | empty[cells]
    if (any(bad)) {
      ok = which(!empty)
      cxy = terra::xyFromCell(rc, ok)
      k = cos(mean(xy$lat[w$rows]) * pi / 180)
      cells[bad] = ok[vapply(which(bad), function(i)
        which.min((cxy[, 1] - xy$lon[w$rows][i])^2 * k^2 + (cxy[, 2] - xy$lat[w$rows][i])^2), integer(1))]
      filled = filled + sum(bad)
    }
    v[w$rows, ] = as.matrix(terra::values(rc, mat = TRUE)[cells, , drop = FALSE])
  }
  attr(v, 'filled') = filled
  v
}

# nClimGrid -----------------------------------------------------------------------------
# Subsets of the NCEI THREDDS files (the same files as the archive at
# https://www.ncei.noaa.gov/data/nclimgrid-monthly/access/), one per variable.
nclimgrid_vars = c(tasmin = 'tmin', tasmax = 'tmax', pr = 'prcp')
nclimgrid_file = function(v) file.path(CACHE, 'nclimgrid', sprintf('nclimgrid_%s_subset.nc', v))
nclimgrid_url = function(v) sprintf(paste0('https://www.ncei.noaa.gov/thredds/ncss/grid/data-in-development/nclimgrid/',
  'nclimgrid_%s.nc?var=%s&north=49.2&south=46.3&west=-122.5&east=-119.9&horizStride=1',
  '&time_start=1978-12-01T00:00:00Z&time_end=2020-12-31T00:00:00Z&accept=netcdf'), v, v)
nc_dates = function(f) {
  head = system2('ncdump', c('-h', shQuote(f)), stdout = TRUE)
  origin = as.Date(sub('.*since ([0-9]{4}-[0-9]{2}-[0-9]{2}).*', '\\1', grep('time:units', head, value = TRUE)[1]))
  raw = system2('ncdump', c('-v', 'time', shQuote(f)), stdout = TRUE)
  vals = sub(';.*', '', sub('.*time =', '', paste(raw[grep('^ time =', raw):length(raw)], collapse = ' ')))
  origin + as.numeric(strsplit(trimws(vals), '[ ,]+')[[1]])
}
nclimgrid_monthly = function() {
  files = nclimgrid_file(nclimgrid_vars)
  require_offline_cache(files, file.exists(files), 'nClimGrid')
  for (v in nclimgrid_vars[!file.exists(files)]) {
    tmp = paste0(nclimgrid_file(v), '.tmp')
    if (system2('curl', c('-sS', '--fail', '--max-time', '1800', '-o', shQuote(tmp), shQuote(nclimgrid_url(v)))) != 0)
      stop('nClimGrid download failed: ', v)
    file.rename(tmp, nclimgrid_file(v))
  }
  bind_rows(lapply(names(nclimgrid_vars), function(variable) {
    f = nclimgrid_file(nclimgrid_vars[[variable]])
    r = terra::rast(f)
    dates = nc_dates(f)
    stopifnot(terra::nlyr(r) == length(dates))
    modified = sub('.*date_modified = "([^"]*)".*', '\\1',
      grep('date_modified', system2('ncdump', c('-h', shQuote(f)), stdout = TRUE), value = TRUE)[1])
    v = extract_points(r)
    cat(sprintf('nClimGrid %s: %d months %s to %s, file modified %s, %d points on an empty cell took the nearest\n',
      nclimgrid_vars[[variable]], length(dates), format(min(dates), '%Y-%m'), format(max(dates), '%Y-%m'),
      modified, attr(v, 'filled')))
    tibble(id = rep(points$id, length(dates)), variable = variable,
      year = rep(as.integer(format(dates, '%Y')), each = nrow(points)),
      month = rep(as.integer(format(dates, '%m')), each = nrow(points)), value = as.vector(v))
  }))
}

# PRISM ---------------------------------------------------------------------------------
# One file per variable and month from the PRISM web service, read at the points and
# deleted. Cached values: cache/prism/<var>_<yyyymm>.csv (id, value). The months of
# the survey windows are needed at the plots, 1979 to 2016 also at the lakes and discs.
# PRISM allows two downloads of a file per day (Pacific local time): attempts are
# logged with their time, and a file is tried at most once per Pacific day here. A
# file that was already downloaded elsewhere that day is logged by hand as
# 'downloaded elsewhere today' so that it waits for the next day.
prism_vars = c(tmean = 'tmean', pr = 'ppt')
prism_file = function(key) file.path(CACHE, 'prism', paste0(key, '.csv'))
plot_ids = points$id[points$kind == 'plot']
prism_jobs = bind_rows(
  expand_grid(var = prism_vars, ym = sprintf('%d%02d', plot_months$year, plot_months$month)) |> mutate(need = 'plots'),
  expand_grid(var = prism_vars, year = CORRECTION_YEARS, month = 1:12) |>
    transmute(var, ym = sprintf('%d%02d', year, month), need = 'all')) |>
  group_by(var, ym) |> summarise(need = if (any(need == 'all')) 'all' else 'plots', .groups = 'drop') |>
  mutate(key = paste(var, ym, sep = '_'), file = prism_file(key),
    url = sprintf('https://services.nacse.org/prism/data/get/us/800m/%s/%s/lt', var, ym))
prism_valid = function(file, need) {
  if (!file.exists(file)) return(FALSE)
  x = read_csv(file, show_col_types = FALSE, progress = FALSE)
  ids = if (need == 'all') points$id else plot_ids
  all(ids %in% x$id) && all(is.finite(x$value[x$id %in% ids]))
}
prism_fetch = function() {
  prism_jobs$valid = mapply(prism_valid, prism_jobs$file, prism_jobs$need)
  require_offline_cache(prism_jobs$file, prism_jobs$valid, 'PRISM')
  log_file = file.path(CACHE, 'prism', 'attempts.csv')
  attempts = if (file.exists(log_file)) read_csv(log_file, show_col_types = FALSE, col_types = cols(.default = 'c')) else
    tibble(key = character(), time = character(), status = character(), release = character(), filled = character(),
      plot_max_difference = character())
  pacific_day = function(t) format(t, '%Y-%m-%d', tz = 'America/Los_Angeles')
  recent = attempts$key[pacific_day(as.POSIXct(attempts$time, tz = 'UTC')) == pacific_day(Sys.time())]
  todo = prism_jobs |> filter(!valid, !key %in% recent | file.exists(paste0(file, '.zip')))
  cat(sprintf('PRISM: %d files needed, %d valid in the cache, %d to download, %d waiting (tried today, Pacific time)\n',
    nrow(prism_jobs), sum(prism_jobs$valid), nrow(todo), sum(!prism_jobs$valid & prism_jobs$key %in% recent)))
  if (!nrow(todo)) return(invisible(NULL))
  # A zip is deleted only after its values are written, so a file whose reading failed
  # is read again from the zip without a second download.
  work = function(j) {
    zip = paste0(prism_file(j$key), '.zip')
    stamp = format(Sys.time(), '%Y-%m-%d %H:%M:%S', tz = 'UTC')
    row = function(status, release = NA, filled = NA, diff = NA)
      data.frame(key = j$key, time = stamp, status = status, release = release, filled = filled, plot_max_difference = diff)
    if (!file.exists(zip)) {
      Sys.sleep(2)  # PRISM asks for a pause between requests
      rc = system2('curl', c('-sS', '-L', '--max-time', '900', '-o', shQuote(zip), shQuote(j$url)), stdout = FALSE, stderr = FALSE)
      if (rc != 0 || !file.exists(zip)) { unlink(zip); return(row(paste('curl failed', rc))) }
      if (!identical(readBin(zip, 'raw', 2), charToRaw('PK'))) {
        msg = readLines(zip, warn = FALSE)[1]; unlink(zip); return(row(paste('refused:', msg)))
      }
    }
    tryCatch({
      ex = file.path(tempdir(), j$key); dir.create(ex, showWarnings = FALSE)
      files = utils::unzip(zip, exdir = ex)
      r = terra::rast(files[grepl('\\.(tif|bil)$', files)][1])
      v = extract_points(r)
      info = readLines(files[grepl('info\\.txt$', files)][1], warn = FALSE)
      release = sub('PRISM_DATASET_TYPE: ', '', grep('DATASET_TYPE', info, value = TRUE)[1])
      new = data.frame(id = points$id, value = as.vector(v))
      diff = NA_real_
      if (file.exists(prism_file(j$key))) {
        m = merge(utils::read.csv(prism_file(j$key)), new, by = 'id')
        diff = max(abs(m$value.x - m$value.y))
      }
      utils::write.csv(new, paste0(prism_file(j$key), '.tmp'), row.names = FALSE)
      file.rename(paste0(prism_file(j$key), '.tmp'), prism_file(j$key))
      unlink(c(zip, ex), recursive = TRUE)
      row('ok', release, attr(v, 'filled'), diff)
    }, error = function(e) row(paste('read failed:', conditionMessage(e))))
  }
  cluster = makePSOCKcluster(PRISM_WORKERS)
  on.exit(stopCluster(cluster), add = TRUE)
  clusterCall(cluster, function(p) .libPaths(p), .libPaths())
  clusterExport(cluster, c('points', 'xy', 'windows', 'extract_points', 'prism_file', 'CACHE'), envir = environment())
  batches = split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / (4 * PRISM_WORKERS)))
  t0 = Sys.time()
  for (b in seq_along(batches)) {
    res = bind_rows(parLapply(cluster, lapply(batches[[b]], \(i) as.list(todo[i, ])), work))
    attempts = bind_rows(attempts, mutate(res, across(everything(), as.character)))
    write_csv(attempts, log_file)
    cat(sprintf('.. PRISM batch %d of %d: %d ok, %d failed (%.1f min)\n', b, length(batches), sum(res$status == 'ok'),
      sum(res$status != 'ok'), as.numeric(difftime(Sys.time(), t0, units = 'mins'))))
    # A refusal from the server stops the downloads: the rest wait for another day.
    if (any(startsWith(res$status, 'refused'))) { cat('PRISM refused a request; stopping:', res$status[startsWith(res$status, 'refused')][1], '\n'); break }
  }
  # Rule: a file read again gives the cached plot values (the release did not change).
  d = suppressWarnings(as.numeric(attempts$plot_max_difference))
  if (any(d > 1e-4, na.rm = TRUE)) stop('PRISM values changed at the plots in ', sum(d > 1e-4, na.rm = TRUE), ' file(s); see ', log_file)
  invisible(NULL)
}
prism_monthly = function() {
  prism_jobs$valid = mapply(prism_valid, prism_jobs$file, prism_jobs$need)
  prism_jobs$plots_valid = mapply(prism_valid, prism_jobs$file, 'plots')
  if (!all(prism_jobs$plots_valid)) stop('PRISM: ', sum(!prism_jobs$plots_valid), ' cache file(s) missing at the plots, e.g. ',
    paste(head(prism_jobs$key[!prism_jobs$plots_valid], 5), collapse = ', '), '. Rerun online on another day.')
  # A month still missing at the lakes and discs leaves that year out of its step 2 (printed).
  if (!all(prism_jobs$valid)) cat(sprintf('PRISM: %d of %d monthly files not yet at the lakes and discs (%s ...)\n',
    sum(!prism_jobs$valid), sum(prism_jobs$need == 'all'), paste(head(prism_jobs$key[!prism_jobs$valid], 3), collapse = ', ')))
  x = bind_rows(lapply(seq_len(nrow(prism_jobs)), function(i)
    read_csv(prism_jobs$file[i], show_col_types = FALSE, progress = FALSE) |>
      mutate(var = prism_jobs$var[i], year = as.integer(substr(prism_jobs$ym[i], 1, 4)),
        month = as.integer(substr(prism_jobs$ym[i], 5, 6)))))
  # tmean is the midpoint (tmin + tmax) / 2 and stands for both (see the header).
  bind_rows(x |> filter(var == 'tmean') |> mutate(variable = 'tasmin'), x |> filter(var == 'tmean') |> mutate(variable = 'tasmax'),
    x |> filter(var == 'ppt') |> mutate(variable = 'pr')) |> select(id, variable, year, month, value)
}

if ('prism' %in% PRODUCTS && !getOption('paleoaces.offline')) prism_fetch()
if ('--fetch-only' %in% args) quit(save = 'no')

# Inputs of each product's run ----------------------------------------------------------
monthly_of = list(prism = prism_monthly, nclimgrid = nclimgrid_monthly)
main_factors = read_csv(file.path(main, '07_climate_products', 'climate_bias_correction_factors.csv'), show_col_types = FALSE)
# The disc means and years of the main step 2 (V2.1 and CHELSAcruts both present, 1979-2016).
main_step2 = read_csv(file.path(main, '07_climate_products', 'climate_products_values.csv'), show_col_types = FALSE) |>
  filter(place %in% paste(c('MORA', 'NOCA'), 'disc'), product %in% c('cruts', 'v21'), year %in% CORRECTION_YEARS) |>
  select(product, site, variable, year, month, value) |> pivot_wider(names_from = product, values_from = value) |>
  filter(!is.na(cruts), !is.na(v21))
apply_factor = function(x, f, kind) if_else(kind == 'ratio', x * f, x + f)

build_inputs = function(product) {
  root = file.path(base, product)
  stopifnot(normalizePath(root, mustWork = FALSE) != normalizePath(main))
  unlink(root, recursive = TRUE)
  dir.create(file.path(root, 'cache'), recursive = TRUE)
  # The results of steps 01 to 07, the TraCE21k chunks and the Bacon age draws of the main run.
  for (step in list.files(main, pattern = '^0[1-7]_')) file.copy(file.path(main, step), root, recursive = TRUE)
  file.copy(file.path(main, 'cache', c('chelsa_paleo', 'age_draws.rds')), file.path(root, 'cache'), recursive = TRUE)
  monthly = monthly_of[[product]]()
  stopifnot(!anyDuplicated(monthly[c('id', 'variable', 'year', 'month')]))
  # The V2.1 rows with the product's value: the same plots, windows and months.
  for (s in names(v21_climate)) {
    x = v21_climate[[s]] |> left_join(rename(monthly, plot_id = id, product_value = value),
      by = c('plot_id', 'variable', 'year', 'month'), relationship = 'many-to-one')
    # Rule: every row of the V2.1 survey-window climate has a finite product value.
    stopifnot(nrow(x) == nrow(v21_climate[[s]]), all(is.finite(x$product_value)))
    write_csv(x |> mutate(value = product_value) |> select(-product_value), file.path(root, '04_modern_climate', paste0(s, '_climate.csv')))
  }
  if (HOLOCENE_ONTO[[product]] == 'v21') {
    cat(sprintf('%s: inputs written (%s plot-months replaced); the Holocene climate stays corrected onto V2.1 (main analysis)\n',
      product, format(sum(vapply(v21_climate, nrow, integer(1))), big.mark = ',')))
    return(invisible(root))
  }
  # Step 2 against the product over the same discs, months and years as the main step 2.
  disc = monthly |> inner_join(points |> filter(kind == 'disc') |> select(id, site), by = 'id') |>
    group_by(site, variable, year, month) |> summarise(product_value = mean(value), .groups = 'drop')
  step2 = main_step2 |> inner_join(disc, by = c('site', 'variable', 'year', 'month')) |>
    group_by(site, variable, month) |>
    summarise(step2_years = n(), step2_first = min(year), step2_last = max(year), cruts_1979_2016 = mean(cruts),
      product_1979_2016 = mean(product_value), .groups = 'drop')
  factors = main_factors |> select(site, variable, month, step1_years, trace_timeid20, cruts_1901_1990, kind, step1,
    main_step2_years = step2_years, main_cruts_1979_2016 = cruts_1979_2016) |>
    inner_join(step2, by = c('site', 'variable', 'month'), relationship = 'one-to-one') |>
    mutate(product = product, .before = 1,
      step2 = if_else(kind == 'ratio', product_1979_2016 / cruts_1979_2016, product_1979_2016 - cruts_1979_2016),
      one_step = step2, two_step = if_else(kind == 'ratio', step1 * step2, step1 + step2))
  # Rules: the years of the main step 2 (fewer only where a product month is not yet
  # downloaded, printed), CHELSAcruts and the product averaged over the same years; step
  # 2 takes the CHELSAcruts means to the product means; both steps take TraCE21k timeID
  # 20 to the CHELSAcruts 1901-1990 level shifted by the product - CHELSAcruts difference.
  short = factors |> filter(step2_years < main_step2_years)
  if (nrow(short)) cat(sprintf('%s: step 2 over %d of %d years for %s\n', product, short$step2_years, short$main_step2_years,
    paste(short$site, short$variable, month.abb[short$month])), sep = '')
  stopifnot(nrow(factors) == nrow(main_factors), all(is.finite(c(factors$step2, factors$two_step))),
    all(factors$step2_years <= factors$main_step2_years), all(factors$step2_years >= factors$main_step2_years - 1),
    isTRUE(all.equal(factors$cruts_1979_2016[factors$step2_years == factors$main_step2_years],
      factors$main_cruts_1979_2016[factors$step2_years == factors$main_step2_years])),
    isTRUE(all.equal(with(factors, apply_factor(cruts_1979_2016, step2, kind)), factors$product_1979_2016)),
    isTRUE(all.equal(with(factors, apply_factor(trace_timeid20, two_step, kind)),
      with(factors, apply_factor(cruts_1901_1990, step2, kind)))))
  write_csv(factors |> select(-main_step2_years, -main_cruts_1979_2016),
    file.path(root, '07_climate_products', 'climate_bias_correction_factors.csv'))
  cat(sprintf('%s: inputs written (%s plot-months replaced, step 2 over %d-%d)\n', product,
    format(sum(vapply(v21_climate, nrow, integer(1))), big.mark = ','), min(factors$step2_first), max(factors$step2_last)))
  invisible(root)
}

# Runs ----------------------------------------------------------------------------------
# Stages 08 to 16, then the data of Figures 3 to 7 (their out('figures/...') tables,
# no drawing), in a worker process of its own, so the options of the two runs never mix.
run_product = function(product, root) {
  suppressPackageStartupMessages(library(here))
  options(paleoaces.offline = TRUE, paleoaces.run_age_models = FALSE, paleoaces.presentation = FALSE,
    paleoaces.render_figures = FALSE, paleoaces.paleo_correction = 'two_step', paleoaces.output_root = root,
    device = function(...) grDevices::pdf(file = tempfile(fileext = '.pdf'), ...))
  log = file(file.path(root, 'run.log'), open = 'wt')
  sink(log); sink(log, type = 'message')
  on.exit({ sink(type = 'message'); sink(); close(log) })
  t0 = Sys.time()
  scripts = c(file.path('R/pipeline', list.files(here('R/pipeline'), pattern = '^(0[8-9]|1[0-6])_.*[.]R$')),
    file.path('R/figures', list.files(here('R/figures'), pattern = '^main_fig[3-7]_.*[.]R$')))
  status = tryCatch({
    for (s in scripts) {
      cat('\n', strrep('=', 78), '\n', s, ' (', product, ')\n', strrep('=', 78), '\n', sep = '')
      sys.source(here(s), envir = new.env(parent = globalenv()))
    }
    writeLines(format(Sys.time()), file.path(root, 'run_ok.txt'))
    'ok'
  }, error = function(e) paste('error:', conditionMessage(e)))
  sprintf('%s: %s (%.1f min; log %s)', product, status, as.numeric(difftime(Sys.time(), t0, units = 'mins')),
    file.path(root, 'run.log'))
}

fingerprint = function() {
  files = c(list.files(main, recursive = TRUE, full.names = TRUE),
    list.files(here('report', c('figures', 'tables')), recursive = TRUE, full.names = TRUE))
  tools::md5sum(files)
}
before = fingerprint()
roots = vapply(PRODUCTS, build_inputs, character(1))
cluster = makePSOCKcluster(length(PRODUCTS))
clusterCall(cluster, function(dir, lib) { setwd(dir); .libPaths(lib); invisible(NULL) }, here(), .libPaths())
status = unlist(clusterMap(cluster, run_product, PRODUCTS, roots))
stopCluster(cluster)
cat(status, sep = '\n')
if (!all(grepl(': ok ', status))) stop('A product run failed; see its run.log.')
# Each run's own climate must have reached the samples and the plot pairs.
paleo_main = read_csv(file.path(main, '08_paleo_climate', 'paleo_env.csv'), show_col_types = FALSE)
pairs_main = read_csv(file.path(main, '13_tracking', 'cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE)
for (r in roots) {
  paleo = read_csv(file.path(r, '08_paleo_climate', 'paleo_env.csv'), show_col_types = FALSE)
  pairs = read_csv(file.path(r, '13_tracking', 'cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE)
  # Rules: the same samples, with another Holocene climate where it is corrected onto the
  # product and the main one otherwise; the 605 plot pairs (328 MORA, 277 NOCA).
  onto_product = HOLOCENE_ONTO[[basename(r)]] == 'product'
  stopifnot(identical(paleo$plot_id, paleo_main$plot_id), onto_product != isTRUE(all.equal(paleo$MSpT, paleo_main$MSpT)),
    nrow(pairs) == 605, identical(sort(pairs$plot_id), sort(pairs_main$plot_id)), !isTRUE(all.equal(pairs$SP, pairs_main$SP)))
}

# Comparison ----------------------------------------------------------------------------
# V2.1 (the main run) and every product whose run finished, earlier calls included.
done = c('prism', 'nclimgrid')[file.exists(file.path(base, c('prism', 'nclimgrid'), 'run_ok.txt'))]
paths = c(v21 = main, setNames(file.path(base, done), done))
comparison = file.path(base, 'comparison')
unlink(comparison, recursive = TRUE); dir.create(comparison)
read_all = function(file, ...) imap_dfr(paths, \(p, product) read_csv(file.path(p, file), show_col_types = FALSE, ...) |>
  mutate(product = product, .before = 1))
save = function(x, name) write_csv(x, file.path(comparison, name))
# Which climate each run's Holocene is corrected onto.
products = tibble(product = names(paths), holocene_corrected_onto = c(v21 = 'v21', ifelse(HOLOCENE_ONTO[done] == 'product', done, 'v21')))
save(products, 'products.csv')

# Climate of the 605 plot pairs at the two surveys, and its change.
plots = read_all('13_tracking/cca_tracking_anthropocene_plot_calculations.csv') |>
  select(product, plot_id, site, MSpT, SP, MSpT_2, SP_2) |>
  pivot_longer(c(MSpT, SP, MSpT_2, SP_2), names_to = c('variable', 'survey'), names_pattern = '([A-Za-z]+)(_2)?') |>
  mutate(survey = if_else(survey == '_2', 'resurvey', 'legacy')) |> pivot_wider(names_from = survey, values_from = value) |>
  mutate(change = resurvey - legacy, change_percent = if_else(variable == 'SP', 100 * (resurvey / legacy - 1), NA_real_))
save(plots, 'plot_climate.csv')
q = function(x, p) unname(quantile(x, p))
save(plots |> group_by(product, site, variable) |> summarise(plots = n(),
  legacy_median = median(legacy), legacy_q25 = q(legacy, .25), legacy_q75 = q(legacy, .75),
  resurvey_median = median(resurvey), resurvey_q25 = q(resurvey, .25), resurvey_q75 = q(resurvey, .75),
  change_median = median(change), change_q25 = q(change, .25), change_q75 = q(change, .75),
  change_percent_median = median(change_percent), .groups = 'drop'), 'plot_climate_medians.csv')

# Step 2 of each product, by month and for the two CCA seasons (the spring offset of
# the temperature midpoint and the summer ratio of the precipitation sums, on the
# CHELSAcruts means of 1979-2016).
step2 = read_all('07_climate_products/climate_bias_correction_factors.csv') |>
  filter(product %in% products$product[products$holocene_corrected_onto == products$product]) |>
  mutate(product_1979_2016 = coalesce(if ('product_1979_2016' %in% names(pick(everything()))) product_1979_2016 else NA_real_, v21_1979_2016)) |>
  select(product, site, variable, month, kind, cruts_1979_2016, product_1979_2016, step1, step2, two_step)
save(step2, 'step2_factors.csv')
save(step2 |> group_by(product, site) |> summarise(
  spring_temperature_offset = mean(step2[variable %in% c('tasmin', 'tasmax') & month %in% 3:5]),
  summer_precipitation_ratio = sum(product_1979_2016[variable == 'pr' & month %in% 6:8]) /
    sum(cruts_1979_2016[variable == 'pr' & month %in% 6:8]), .groups = 'drop'), 'step2_seasonal.csv')

# Figure 3: the Holocene levels and the climate periods.
save(read_all('figures/holocene_standardized_climate_levels.csv'), 'holocene_levels.csv')
periods = read_all('12_climate_eras/holocene_periods.csv')
save(periods, 'climate_periods.csv')
keys = c('site', 'lake', 'period_type', 'age_start', 'age_end', 'duration_yr')
lake_periods = read_all('13_tracking/cca_tracking_both_eras.csv') |> filter(period_type != 'Anthropocene')
shared = lake_periods |> distinct(product, across(all_of(keys))) |> count(across(all_of(keys))) |> filter(n == length(paths))
save(lake_periods |> count(product, site, period_type, name = 'lake_periods') |>
  left_join(shared |> count(site, period_type, name = 'shared_by_all'), by = c('site', 'period_type')), 'lake_period_matching.csv')

# Figure 4: the CCA, species scores and climate arrows in each run's display rotation.
rotation = read_all('11_cca/cca_display_rotation.csv')
species = read_all('11_cca/cca_species_contributions.csv') |> left_join(rotation, by = 'product') |>
  transmute(product, kind = 'species', name = species, axis1 = CCA1 * m11 + CCA2 * m21, axis2 = CCA1 * m12 + CCA2 * m22,
    percent_constrained_inertia)
arrows = rotation |> transmute(product, MSpT_axis1, MSpT_axis2, SP_axis1, SP_axis2) |>
  pivot_longer(-product, names_to = c('name', '.value'), names_pattern = '(.*)_(axis[12])') |> mutate(kind = 'climate')
axes = read_all('11_cca/cca_axes.csv') |> group_by(product) |>
  summarise(constrained_percent_total = sum(percent_total_inertia), axis1_percent_constrained = percent_constrained_inertia[axis == 'CCA1'],
    .groups = 'drop')
save(bind_rows(species, arrows) |> left_join(axes, by = 'product') |> left_join(select(rotation, product, angle_degrees), by = 'product'),
  'cca.csv')

# Figures 5 to 7: era means and contrasts, model slopes, species contributions.
save(read_all('14_era_models/era_comparison/era_means.csv'), 'era_means.csv')
contrasts = read_all('14_era_models/era_comparison/era_contrasts.csv')
save(contrasts, 'era_contrasts.csv')
save(read_all('15_predictor_models/community_predictor_models/model_coefficients.csv'), 'model_coefficients.csv')
save(read_all('16_contributions/species_contribution_models/species_means.csv') |> filter(measure == 'contrib_climate'),
  'species_means.csv')
# Rule: every run fits the same 60 era contrasts.
stopifnot(all(count(contrasts, product)$n == 60))
print(contrasts |> group_by(product) |> summarise(significant = sum(p_adjusted < .05)))

# Rule: the runs leave the main outputs, figures and report tables untouched.
after = fingerprint()
stopifnot(identical(names(before), names(after)), identical(unname(before), unname(after)))
cat('\nClimate-product sensitivity done:', paste(names(paths), collapse = ', '),
  'in output_climate_sensitivity/comparison/; main output/ and report/ unchanged.\n')
