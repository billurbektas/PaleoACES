# 07 Climate products: four CHELSA climate products at the plots and around the
# lakes, and the correction that moves the Holocene paleoclimate onto CHELSA V2.1
# (Appendix S2; Bills, 11 Nov 2026).
#
# The CCA is calibrated on CHELSA V2.1, the best product for the Anthropocene,
# while the Holocene positions come from CHELSA-TraCE21k. TraCE21k is downscaled
# with the CHELSA V1 method, as are CHELSAcruts and CHELSA V1.2, and the four
# products differ in level. CHELSAcruts runs from 1901 to 2016, so it overlaps
# both TraCE21k (timeID 20 is the mean of 1900 to 1990) and V2.1 (from 1979): it
# links the two. The correction has two steps, each computed per park, calendar
# month and variable on the monthly tasmin, tasmax and precipitation (not on the
# seasonal variables), on the mean over every 30-arcsec cell within 5 km of the
# park's lakes (MORA: the midpoint of its three lakes; NOCA: Panther Potholes):
#   step 1, TraCE21k to CHELSAcruts over the years TraCE21k timeID 20 stands for
#           (1900 to 1990; CHELSAcruts from 1901), because the two products do not
#           agree around the lakes although both come from the CHELSA V1 method;
#   step 2, CHELSAcruts to V2.1 over the whole overlap of the two, 1979 to 2016.
# Temperature gets offsets (added), precipitation ratios (multiplied). The main
# run applies both steps (Bills, 11 Nov 2026); the sensitivity runs apply step 2
# alone (the one-step correction) or none (R/sensitivity_paleoclimate.R).
# R/pipeline/08_paleo_climate.R applies the factors to every lake of the park.
#
# Products read, all on the same 30-arcsec grid (checked on their file headers):
#   trace  CHELSA-TraCE21k v1.0, timeIDs 16 to 20 (the centuries 1500 to 1990)
#   cruts  CHELSAcruts monthly, 1901 to 2016
#   v12    CHELSA V1.2 monthly time series, 1979 to 2013
#   v21    CHELSA V2.1 monthly, 1979 to 2021
# Units are made common: temperature in degrees C, precipitation in mm per month
# (TraCE21k and V2.1 temperature in K after terra's scale, V1.2 in K x 10,
# CHELSAcruts in degrees C x 10).
#
# Points: every plot of stage 04, the four lake pixels and the cells of the two
# 5 km discs. Each file is read once, cropped to one window per park (cropping
# and extracting gives the same values as reading each point, checked at 609
# points), and cached in output/cache/climate_products/. An --offline run reads
# only the cache. Files the server does not have (V2.1 January 1979
# temperatures) are listed in the cache and left out.
# terra is loaded only in the worker processes: attached here it would mask base::union
# for the stages that run after this one in the same session.
suppressPackageStartupMessages({library(here); library(tidyverse); library(parallel)})
source(here('R/helpers/config.R'), local = TRUE)
source(here('R/helpers/offline_cache.R'), local = TRUE)

CACHE = out('climate_products')
dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)
WORKERS = 6L
RADIUS_KM = 5
CORRECTION_YEARS = 1979:2016
VARS = c('tasmin', 'tasmax', 'pr')
# The CHELSA 30-arcsec grid of all four products.
GRID_RES = 1 / 120; GRID_XMIN = -180 - GRID_RES / 60; GRID_YMAX = 84 - GRID_RES / 60

# Points ------------------------------------------------------------------------------
# The plots of stage 04 (the plots with modern climate).
plot_points = function(site, info, occ, lon, lat) {
  read_csv(out(info), show_col_types = FALSE) |>
    transmute(id = plot_id, site = site, kind = 'plot', lon = .data[[lon]], lat = .data[[lat]]) |>
    filter(id %in% read_csv(out(occ), show_col_types = FALSE)$plot_id, !is.na(lon), !is.na(lat)) |>
    distinct(id, .keep_all = TRUE)
}
plots = bind_rows(plot_points('MORA', 'MORA_plot_info.csv', 'MORA_occ.csv', 'longitude', 'latitude'),
  plot_points('NOCA', 'NOCA_plot_info.csv', 'NOCA_occ.csv', 'Longitude', 'Latitude'))
lakes = PALEO_LAKES |> transmute(id = ID, site, kind = 'lake', lon, lat)
haversine_km = function(lon1, lat1, lon2, lat2) {
  r = pi / 180
  a = sin((lat2 - lat1) * r / 2)^2 + cos(lat1 * r) * cos(lat2 * r) * sin((lon2 - lon1) * r / 2)^2
  2 * 6371 * asin(sqrt(a))
}
# Disc centres: MORA the midpoint of its three lakes, NOCA Panther Potholes.
centres = lakes |> group_by(site) |> summarise(lon = mean(lon), lat = mean(lat), .groups = 'drop')
disc = bind_rows(lapply(seq_len(nrow(centres)), function(i) {
  c0 = centres[i, ]
  half = RADIUS_KM / 111 + 2 * GRID_RES
  cols = floor((c0$lon - half / cos(c0$lat * pi / 180) - GRID_XMIN) / GRID_RES):
    ceiling((c0$lon + half / cos(c0$lat * pi / 180) - GRID_XMIN) / GRID_RES)
  rows = floor((GRID_YMAX - c0$lat - half) / GRID_RES):ceiling((GRID_YMAX - c0$lat + half) / GRID_RES)
  expand_grid(col = cols, row = rows) |>
    mutate(lon = GRID_XMIN + (col + .5) * GRID_RES, lat = GRID_YMAX - (row + .5) * GRID_RES,
      distance_km = haversine_km(lon, lat, c0$lon, c0$lat)) |>
    filter(distance_km <= RADIUS_KM) |>
    transmute(id = sprintf('%s_cell_%d_%d', c0$site, row, col), site = c0$site, kind = 'disc', lon, lat, distance_km)
}))
points = bind_rows(plots, lakes, disc)
stopifnot(!anyDuplicated(points$id), !anyNA(points[c('lon', 'lat')]))
write_csv(points, out('climate_products_points.csv'))
cat(sprintf('points: %s plots, %d lake pixels, %s disc cells (%s within %g km)\n',
  paste(sprintf('%d %s', table(plots$site), names(table(plots$site))), collapse = ' + '), nrow(lakes),
  paste(sprintf('%d %s', table(disc$site), names(table(disc$site))), collapse = ' + '), 'cell centres', RADIUS_KM))
# Plain coordinates for the workers, which do not load tibble (terra::extract
# cannot dispatch on a tibble there).
xy = data.frame(lon = points$lon, lat = points$lat)
# One crop window per park around all of its points.
windows = lapply(split(seq_len(nrow(points)), points$site), function(i)
  list(rows = i, box = c(min(points$lon[i]) - .02, max(points$lon[i]) + .02, min(points$lat[i]) - .02,
    max(points$lat[i]) + .02)))

# Files ---------------------------------------------------------------------------------
names_v1 = c(tasmin = 'tmin', tasmax = 'tmax', pr = 'prec')
url = function(product, variable, year, month) switch(product,
  trace = sprintf(paste0('https://os.zhdk.cloud.switch.ch/chelsa01/chelsa_trace21k/global/centennial/%s/',
    'CHELSA_TraCE21k_%s_%02d_%04d_V.1.0.tif'), variable, variable, month, year),
  v21 = sprintf('https://os.unil.cloud.switch.ch/chelsa02/chelsa/global/monthly/%s/%d/CHELSA_%s_%02d_%d_V.2.1.tif',
    variable, year, variable, month, year),
  v12 = sprintf('https://os.zhdk.cloud.switch.ch/chelsav1/timeseries/%s/CHELSA_%s_%d_%02d_V1.2.1.tif',
    names_v1[[variable]], names_v1[[variable]], year, month),
  cruts = sprintf('https://os.zhdk.cloud.switch.ch/chelsav1/chelsa_cruts/%s/CHELSAcruts_%s_%d_%d_V.1.0.tif',
    names_v1[[variable]], names_v1[[variable]], month, year))
convert = function(product, variable, x) {
  if (variable == 'pr') return(x)
  switch(product, trace = x - 273.15, v21 = x - 273.15, v12 = x / 10 - 273.15, cruts = x / 10)
}
# For TraCE21k the "year" is the timeID.
jobs = bind_rows(
  expand_grid(product = 'trace', variable = VARS, year = 16:20, month = 1:12),
  expand_grid(product = 'cruts', variable = VARS, year = 1901:2016, month = 1:12),
  expand_grid(product = 'v12', variable = VARS, year = 1979:2013, month = 1:12),
  expand_grid(product = 'v21', variable = VARS, year = 1979:2021, month = 1:12)) |>
  mutate(key = sprintf('%s_%s_%d_%02d', product, variable, year, month),
    file = file.path(CACHE, product, paste0(key, '.csv')),
    url = pmap_chr(list(product, variable, year, month), url))
for (p in unique(jobs$product)) dir.create(file.path(CACHE, p), showWarnings = FALSE)
# The cached values are in the order of `points`; a changed point set empties the cache.
signature = object_fingerprint(points[c('id', 'lon', 'lat')])
signature_file = file.path(CACHE, 'points_signature.txt')
if (!file.exists(signature_file) || !identical(readLines(signature_file), signature)) {
  require_offline_cache(signature_file, FALSE, 'climate products (point set changed)')
  unlink(jobs$file[file.exists(jobs$file)])
  writeLines(signature, signature_file)
}
unavailable_file = file.path(CACHE, 'unavailable_files.txt')
unavailable = if (file.exists(unavailable_file)) readLines(unavailable_file) else character(0)
needed = !jobs$key %in% unavailable
require_offline_cache(jobs$file[needed], file.exists(jobs$file[needed]), 'climate products')
todo = jobs[needed & !file.exists(jobs$file), ]
cat(sprintf('climate product files: %d, %d to read, %d unavailable on the server\n', nrow(jobs), nrow(todo),
  length(unavailable)))

read_one = function(i) {
  j = todo[i, ]
  value = tryCatch({
    r = terra::rast(paste0('/vsicurl/', j$url))
    v = rep(NA_real_, nrow(xy))
    for (w in windows) v[w$rows] = terra::extract(terra::crop(r, terra::ext(w$box)), xy[w$rows, ])[, 2]
    v
  }, error = function(e) NULL)
  if (is.null(value) || anyNA(value)) return(j$key)
  tmp = paste0(j$file, '.tmp')
  writeLines(c('value', format(convert(j$product, j$variable, value), digits = 10)), tmp)
  file.rename(tmp, j$file)
  NA_character_
}
if (nrow(todo)) {
  # Separate worker processes, not forks: a forked process crashes on macOS once
  # the network library has started.
  cluster = makeCluster(WORKERS)
  invisible(clusterEvalQ(cluster, suppressPackageStartupMessages(library(terra))))
  clusterExport(cluster, c('todo', 'url', 'convert', 'names_v1', 'xy', 'windows'), envir = environment())
  failed = character(0)
  batches = split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / 300))
  t0 = Sys.time()
  for (b in seq_along(batches)) {
    res = unlist(parLapply(cluster, batches[[b]], read_one))
    failed = c(failed, res[!is.na(res)])
    cat(sprintf('.. climate products: batch %d of %d read (%.1f min)\n', b, length(batches),
      as.numeric(difftime(Sys.time(), t0, units = 'mins'))))
  }
  # A second attempt before a file counts as unavailable.
  if (length(failed)) {
    todo = jobs[jobs$key %in% failed, ]
    clusterExport(cluster, 'todo', envir = environment())
    res = unlist(parLapply(cluster, seq_len(nrow(todo)), read_one))
    failed = res[!is.na(res)]
  }
  stopCluster(cluster)
  unavailable = sort(union(unavailable, failed))
  writeLines(unavailable, unavailable_file)
}
if (length(unavailable)) cat('Unavailable on the server, left out:', paste(unavailable, collapse = ', '), '\n')

# Values at each place ------------------------------------------------------------------
# Places: the plots of each park (mean), each lake pixel, each park's 5 km disc (mean).
place = case_when(points$kind == 'plot' ~ paste(points$site, 'plots'), points$kind == 'lake' ~ points$id,
  TRUE ~ paste(points$site, 'disc'))
present = jobs[file.exists(jobs$file), ]
values = bind_rows(lapply(seq_len(nrow(present)), function(i) {
  v = scan(present$file[i], skip = 1, quiet = TRUE)
  stopifnot(length(v) == nrow(points))
  m = tapply(v, place, mean)
  tibble(product = present$product[i], variable = present$variable[i], year = present$year[i],
    month = present$month[i], place = names(m), value = as.numeric(m))
})) |>
  left_join(distinct(tibble(place, site = points$site)), by = 'place')
stopifnot(!anyNA(values$value))
write_csv(values, out('climate_products_values.csv'))

# Monthly climatology of each product over each window compared.
windows_compared = tribble(~product, ~window, ~first, ~last,
  'trace', 'timeID 20 (1900-1990)', 20, 20,
  'cruts', '1901-1990', 1901, 1990,
  'cruts', '1979-1990', 1979, 1990,
  'cruts', '1979-2016', 1979, 2016,
  'v12', '1979-1990', 1979, 1990,
  'v21', '1979-1990', 1979, 1990,
  'v21', '1979-2016', 1979, 2016)
monthly = bind_rows(lapply(seq_len(nrow(windows_compared)), function(w) {
  x = windows_compared[w, ]
  values |> filter(product == x$product, year >= x$first, year <= x$last) |>
    group_by(product, place, site, variable, month) |>
    summarise(value = mean(value), years = n(), .groups = 'drop') |> mutate(window = x$window, .after = product)
}))
write_csv(monthly, out('climate_products_monthly.csv'))

# Correction --------------------------------------------------------------------------
disc_values = values |> filter(place %in% paste(c('MORA', 'NOCA'), 'disc')) |>
  select(product, site, variable, year, month, value)
# Step 2: CHELSAcruts to V2.1, per park, month and variable over the years both have.
step2 = disc_values |> filter(product %in% c('cruts', 'v21'), year %in% CORRECTION_YEARS) |>
  pivot_wider(names_from = product, values_from = value) |> filter(!is.na(cruts), !is.na(v21)) |>
  group_by(site, variable, month) |>
  summarise(step2_years = n(), step2_first = min(year), step2_last = max(year), cruts_1979_2016 = mean(cruts),
    v21_1979_2016 = mean(v21), .groups = 'drop')
# Step 1: TraCE21k to CHELSAcruts over the years TraCE21k timeID 20 averages.
step1 = disc_values |> filter((product == 'trace' & year == 20) | (product == 'cruts' & year <= 1990)) |>
  group_by(site, variable, month) |>
  summarise(step1_years = sum(product == 'cruts'), trace_timeid20 = mean(value[product == 'trace']),
    cruts_1901_1990 = mean(value[product == 'cruts']), .groups = 'drop')
factors = inner_join(step1, step2, by = c('site', 'variable', 'month'), relationship = 'one-to-one') |>
  mutate(kind = if_else(variable == 'pr', 'ratio', 'offset'),
    step1 = if_else(kind == 'ratio', cruts_1901_1990 / trace_timeid20, cruts_1901_1990 - trace_timeid20),
    step2 = if_else(kind == 'ratio', v21_1979_2016 / cruts_1979_2016, v21_1979_2016 - cruts_1979_2016),
    one_step = step2,
    two_step = if_else(kind == 'ratio', step1 * step2, step1 + step2))
apply_factor = function(x, f, kind) if_else(kind == 'ratio', x * f, x + f)
# Rules: step 1 takes the TraCE21k means to the CHELSAcruts means of the same years,
# step 2 the CHELSAcruts means to the V2.1 means, so both steps take TraCE21k
# timeID 20 to the CHELSAcruts 1901-1990 level shifted by the V2.1 - CHELSAcruts
# difference of 1979-2016.
stopifnot(nrow(factors) == 2 * length(VARS) * 12, all(is.finite(c(factors$step1, factors$step2))),
  all(factors$step1_years == 90),
  isTRUE(all.equal(with(factors, apply_factor(trace_timeid20, step1, kind)), factors$cruts_1901_1990)),
  isTRUE(all.equal(with(factors, apply_factor(cruts_1979_2016, step2, kind)), factors$v21_1979_2016)),
  isTRUE(all.equal(with(factors, apply_factor(trace_timeid20, two_step, kind)),
    with(factors, apply_factor(cruts_1901_1990, step2, kind)))))
write_csv(factors, out('climate_bias_correction_factors.csv'))
cat('\ncorrection factors over the 5 km discs (offset in degC, ratio for pr): step 1 TraCE21k to CHELSAcruts,\n',
  'step 2 CHELSAcruts to V2.1, two-step both (main run)\n', sep = '')
print(as.data.frame(factors |> pivot_longer(c(step1, step2, two_step), names_to = 'factor') |>
  group_by(site, variable, factor) |> summarise(min = min(value), mean = mean(value), max = max(value), .groups = 'drop')),
  digits = 3)

# Check: TraCE21k against CHELSAcruts over the same years ------------------------------
seasonal = function(x) x |> group_by(product, place, site) |>
  summarise(MSpT = mean(((value[variable == 'tasmin'] + value[variable == 'tasmax']) / 2)[month[variable == 'tasmin'] %in% 3:5]),
    SP = sum(value[variable == 'pr' & month %in% 6:8]), .groups = 'drop') |>
  pivot_longer(c(MSpT, SP), names_to = 'variable') |> mutate(month = NA_integer_)
lake_mean = function(x) x |> filter(place %in% lakes$id) |> group_by(product, site, variable, month) |>
  summarise(value = mean(value), .groups = 'drop') |> mutate(place = paste(site, 'lakes'))
both = monthly |> filter((product == 'trace') | (product == 'cruts' & window == '1901-1990')) |>
  select(product, place, site, variable, month, value) |> arrange(product, place, variable, month)
both = bind_rows(both, lake_mean(both))
check = bind_rows(both, seasonal(both)) |>
  filter(place %in% c(paste(c('MORA', 'NOCA'), 'disc'), paste(c('MORA', 'NOCA'), 'plots'), paste(c('MORA', 'NOCA'), 'lakes'))) |>
  pivot_wider(names_from = product, values_from = value) |>
  mutate(difference = trace - cruts, ratio = trace / cruts)
write_csv(check, out('climate_trace_cruts_check.csv'))
cat('\nTraCE21k timeID 20 against CHELSAcruts 1901-1990 (spring temperature degC, summer precipitation mm):\n')
print(as.data.frame(check |> filter(variable %in% c('MSpT', 'SP')) |> select(site, place, variable, trace, cruts, difference, ratio)), digits = 3)
cat('\nwritten: climate product points, values, monthly climatologies, correction factors and the TraCE21k check\n')
