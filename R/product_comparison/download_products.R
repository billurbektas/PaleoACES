# Four CHELSA climate products at the plots and the lakes (Bills, 11 Nov 2026).
# A side analysis, outside the pipeline: it reads only the plot and lake
# coordinates from output/ and writes only to output_product_comparison/.
#
# Why: the Holocene positions come from CHELSA-TraCE21k and the CCA is
# calibrated on CHELSA V2.1. Before correcting one towards the other we need to
# see how the products differ where we use them, and over which years.
#
# Products and years:
#   TraCE21k  CHELSA-TraCE21k v1.0, timeID 20. This is the mean of 1900 to 1990
#             (technical specification, Table 4), not a snapshot of the present.
#   V2.1      CHELSA V2.1 monthly, 1979 to 2021 online; used 1979 to 1990.
#   V1.2      CHELSA V1.2 monthly time series, 1979 to 2013 online; used 1979 to 1990.
#   cruts     CHELSAcruts monthly (historical, 1901 to 2016 online); used 1901 to
#             1990, which covers the TraCE21k window, and so also 1979 to 1990.
# 1979 to 1990 is the period all four share. CHELSAcruts alone reaches back over
# the whole TraCE21k window, so it can tell the effect of the years apart from
# the effect of the product.
#
# Points: the 605 analysed plots (328 MORA, 277 NOCA) and the four cored lakes.
# Every file is read once for all points (a streamed read of a cloud GeoTIFF over
# a window around each park) and cached as one small CSV, so the script resumes
# where it stopped.
#
# Units are made common: temperature in degrees C, precipitation in mm per month.
#   TraCE21k, V2.1  tasmin/tasmax in K (terra applies the 0.1 scale), pr in mm
#   V1.2            tmin/tmax in K x 10, prec in mm
#   cruts           tmin/tmax in degrees C x 10, prec in mm
#
# Run: Rscript R/product_comparison/download_products.R   (then figure_products.R)
suppressPackageStartupMessages({library(here); library(tidyverse); library(terra); library(parallel)})
source(here('R/helpers/config.R'), local = TRUE)
root = here('output_product_comparison')
cache = file.path(root, 'cache')
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
WORKERS = 6

# Points --------------------------------------------------------------------------
pairs = read_csv(out('cca_tracking_both_eras.csv'), show_col_types = FALSE) |>
  filter(period_type == 'Anthropocene') |> distinct(site, plot_id)
# Rule: 605 Anthropocene pairs, 328 MORA and 277 NOCA (Bills, 11 Nov 2026).
stopifnot(identical(as.integer(table(pairs$site)[c('MORA', 'NOCA')]), c(328L, 277L)))
coords = bind_rows(
  read_csv(out('MORA_plot_info.csv'), show_col_types = FALSE) |> transmute(plot_id, lon = longitude, lat = latitude),
  read_csv(out('NOCA_plot_info.csv'), show_col_types = FALSE) |> transmute(plot_id, lon = Longitude, lat = Latitude)) |>
  filter(!is.na(lon), !is.na(lat)) |> distinct(plot_id, .keep_all = TRUE)
plots = pairs |> inner_join(coords, by = 'plot_id') |> transmute(id = plot_id, site, kind = 'plot', lon, lat)
stopifnot(nrow(plots) == 605)
lakes = read_csv(out('chelsa_paleo_ponds.csv'), show_col_types = FALSE) |> distinct(lake, site, lon, lat) |>
  transmute(id = lake, site, kind = 'lake', lon, lat)
stopifnot(nrow(lakes) == 4)
points = bind_rows(plots, lakes)
write_csv(points, file.path(root, 'points.csv'))
xy = data.frame(lon = points$lon, lat = points$lat)
# One window around the points of each park. Cropping the window and extracting
# from it gives the same values as extracting each point from the cloud file,
# checked at all 609 points, in a tenth of the time.
boxes = lapply(split(seq_len(nrow(points)), points$site), function(i)
  list(rows = i, box = c(min(points$lon[i]) - .01, max(points$lon[i]) + .01, min(points$lat[i]) - .01,
    max(points$lat[i]) + .01)))

# Files ---------------------------------------------------------------------------
VARS = c('tasmin', 'tasmax', 'pr')
names_v1 = c(tasmin = 'tmin', tasmax = 'tmax', pr = 'prec')
url = function(product, variable, year, month) switch(product,
  trace = sprintf(paste0('https://os.zhdk.cloud.switch.ch/chelsa01/chelsa_trace21k/global/centennial/%s/',
    'CHELSA_TraCE21k_%s_%02d_%04d_V.1.0.tif'), variable, variable, month, 20L),
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
# TraCE21k has one value per month for the whole 1900 to 1990 window; year = NA.
jobs = bind_rows(
  expand_grid(product = 'trace', variable = VARS, year = NA_integer_, month = 1:12),
  expand_grid(product = 'v21', variable = VARS, year = 1979:1990, month = 1:12),
  expand_grid(product = 'v12', variable = VARS, year = 1979:1990, month = 1:12),
  expand_grid(product = 'cruts', variable = VARS, year = 1901:1990, month = 1:12)) |>
  mutate(file = file.path(cache, product, sprintf('%s_%s_%02d.csv', variable, ifelse(is.na(year), 'tid20', year), month)))
for (p in unique(jobs$product)) dir.create(file.path(cache, p), showWarnings = FALSE)
cached = function(f) file.exists(f) && nrow(read_csv(f, show_col_types = FALSE, progress = FALSE)) == nrow(points)
todo = jobs[!vapply(jobs$file, cached, logical(1)), ]
cat(sprintf('%d points (%d plots, %d lakes) | %d files, %d to read\n', nrow(points), nrow(plots), nrow(lakes),
  nrow(jobs), nrow(todo)))

read_one = function(i) {
  j = todo[i, ]
  u = url(j$product, j$variable, j$year, j$month)
  value = tryCatch({
    r = terra::rast(paste0('/vsicurl/', u))
    v = rep(NA_real_, nrow(points))
    for (k in boxes) v[k$rows] = terra::extract(terra::crop(r, terra::ext(k$box)), xy[k$rows, ])[, 2]
    v
  }, error = function(e) NULL)
  if (is.null(value)) return(u)  # unavailable on the server: reported, not cached
  readr::write_csv(data.frame(id = points$id, value = convert(j$product, j$variable, value)), j$file)
  NA_character_
}
t0 = Sys.time()
missing = character(0)
# Separate worker processes, not forks: a forked process crashes on macOS once
# the network library has started.
cluster = makeCluster(WORKERS)
clusterEvalQ(cluster, suppressPackageStartupMessages(library(terra)))
clusterExport(cluster, c('todo', 'url', 'convert', 'names_v1', 'xy', 'points', 'boxes'))
# In batches, so the console shows progress and an interruption loses little.
batches = split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / 240))
for (b in seq_along(batches)) {
  res = unlist(parLapply(cluster, batches[[b]], read_one))
  missing = c(missing, res[!is.na(res)])
  cat(sprintf('.. batch %d of %d read (%.1f min)\n', b, length(batches),
    as.numeric(difftime(Sys.time(), t0, units = 'mins'))))
}
stopCluster(cluster)
if (length(missing)) cat('Unavailable on the server (left out of the means):\n', paste(' ', missing, collapse = '\n'), '\n')
writeLines(missing, file.path(root, 'unavailable_files.txt'))

# Assemble ------------------------------------------------------------------------
present = jobs[vapply(jobs$file, file.exists, logical(1)), ]
values = bind_rows(lapply(seq_len(nrow(present)), function(i)
  read_csv(present$file[i], show_col_types = FALSE, progress = FALSE) |>
    mutate(product = present$product[i], variable = present$variable[i], year = present$year[i],
      month = present$month[i]))) |>
  left_join(points |> select(id, site, kind), by = 'id')
stopifnot(!anyNA(values$value))
# Monthly climatology of each product at each point, over each window compared.
windows = tribble(~product, ~window, ~first, ~last,
  'trace', '1900-1990', NA, NA,
  'cruts', '1901-1990', 1901, 1990,
  'cruts', '1979-1990', 1979, 1990,
  'v12', '1979-1990', 1979, 1990,
  'v21', '1979-1990', 1979, 1990)
climatology = bind_rows(lapply(seq_len(nrow(windows)), function(w) {
  x = windows[w, ]
  values |> filter(product == x$product, is.na(year) | (year >= x$first & year <= x$last)) |>
    group_by(product, id, site, kind, variable, month) |>
    summarise(value = mean(value), years = n(), .groups = 'drop') |> mutate(window = x$window)
}))
write_csv(climatology, file.path(root, 'climatology_by_point.csv'))
# Every year of every product as the mean over the plots of a park, and at each lake.
yearly = values |> filter(!is.na(year)) |>
  mutate(place = ifelse(kind == 'plot', paste(site, 'plots'), id)) |>
  group_by(product, place, site, variable, year, month) |> summarise(value = mean(value), .groups = 'drop')
write_csv(yearly, file.path(root, 'yearly_by_place.csv'))
cat(sprintf('Done: %d values, climatologies and yearly means in %s\n', nrow(values), root))
