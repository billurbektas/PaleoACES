# Figs. S6 to S8 (Appendix S2, Bills, 11 Nov 2026): the four CHELSA climate
# products and the bias correction of the paleoclimate, from the outputs of
# R/pipeline/07_climate_products.R.
# Fig. S6: the monthly climate of each product at the plots of each park and on
# the 5 km disc around its lakes. TraCE21k timeID 20 is the mean of 1900 to
# 1990, so CHELSAcruts is shown over the same years and over 1979 to 1990, the
# years all four products share. Grey lines: each V2.1 year, 1979 to 1990.
# Fig. S7: the linker. Yearly values on each park's disc: CHELSAcruts from 1901,
# V1.2 from 1979 to 2013, V2.1 from 1979, and the TraCE21k century means as
# steps. The correction window, 1979 to 2016, is shaded.
# Fig. S8: the correction per park and month (V2.1 against CHELSAcruts, 1979 to
# 2016, with the spread of the yearly values) next to the remaining difference
# between TraCE21k timeID 20 and CHELSAcruts over the same years and cells.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

monthly = read_csv(out('climate_products_monthly.csv'), show_col_types = FALSE)
values = read_csv(out('climate_products_values.csv'), show_col_types = FALSE)
factors = read_csv(out('climate_bias_correction_factors.csv'), show_col_types = FALSE)
check = read_csv(out('climate_trace_cruts_check.csv'), show_col_types = FALSE)

# Not the park colours, which mean MORA and NOCA everywhere else.
PRODUCT_COLORS = c(trace = '#7B3294', cruts = '#B8860B', v12 = '#1B9E77', v21 = 'black')
var_labels = c(tasmin = 'Minimum temperature\n(°C)', tasmax = 'Maximum temperature\n(°C)',
  pr = 'Precipitation\n(mm per month)')
place_labels = c(`MORA plots` = 'MORA plots', `NOCA plots` = 'NOCA plots', `MORA disc` = 'MORA, 5 km around the lakes',
  `NOCA disc` = 'NOCA, 5 km around the lake')
theme_products = theme_paleoaces(base_size = 15) +
  theme(strip.placement = 'outside', strip.text = element_text(face = 'bold'), panel.grid.minor = element_blank(),
    legend.position = 'bottom', legend.text = element_text(size = 14), legend.key.width = unit(1.4, 'cm'),
    plot.tag = element_text(size = 18, face = 'bold'))

# Fig. S6 -------------------------------------------------------------------------------
series_labels = c(`trace timeID 20 (1900-1990)` = 'TraCE21k timeID 20 (1900 to 1990)', `cruts 1901-1990` = 'CHELSAcruts 1901 to 1990',
  `cruts 1979-1990` = 'CHELSAcruts 1979 to 1990', `v12 1979-1990` = 'CHELSA V1.2 1979 to 1990',
  `v21 1979-1990` = 'CHELSA V2.1 1979 to 1990')
series_colors = setNames(PRODUCT_COLORS[c('trace', 'cruts', 'cruts', 'v12', 'v21')], names(series_labels))
series_lines = setNames(c('solid', '22', 'solid', 'solid', 'solid'), names(series_labels))
lab = function(x) x |> filter(place %in% names(place_labels)) |>
  mutate(place = factor(place_labels[place], place_labels), variable = factor(var_labels[variable], var_labels))
lines = monthly |> mutate(series = paste(product, window)) |> filter(series %in% names(series_labels))
years = values |> filter(product == 'v21', year <= 1990)
s6 = ggplot(lab(lines), aes(month, value)) +
  geom_line(data = lab(years), aes(group = year), color = 'grey80', linewidth = .35) +
  geom_line(aes(color = series, linetype = series), linewidth = 1.1) +
  geom_point(data = lab(filter(lines, product == 'trace')), aes(color = series), size = 1.9, show.legend = FALSE) +
  facet_grid(variable ~ place, scales = 'free_y', switch = 'y') +
  scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1), expand = expansion(.02)) +
  scale_color_manual(values = series_colors, labels = series_labels, breaks = names(series_labels), name = NULL) +
  scale_linetype_manual(values = series_lines, labels = series_labels, breaks = names(series_labels), name = NULL) +
  guides(color = guide_legend(nrow = 2, byrow = TRUE, override.aes = list(linewidth = 1.3))) +
  labs(x = 'Month', y = NULL) + theme_products

# Fig. S7 -------------------------------------------------------------------------------
# Yearly means of the monthly temperatures and yearly totals of precipitation, for
# years with all twelve months.
yearly = values |> filter(place %in% c('MORA disc', 'NOCA disc'), product != 'trace') |>
  group_by(product, site, variable, year) |> filter(n() == 12) |>
  summarise(value = if (first(variable) == 'pr') sum(value) else mean(value), .groups = 'drop')
centuries = values |> filter(place %in% c('MORA disc', 'NOCA disc'), product == 'trace', year >= 19) |>
  group_by(site, variable, year) |>
  summarise(value = if (first(variable) == 'pr') sum(value) else mean(value), .groups = 'drop') |>
  mutate(start = 100 * (year - 1), end = if_else(year == 20, 1990, 100 * year - 1))
var_year = c(tasmin = 'Minimum temperature\n(°C, yearly mean)', tasmax = 'Maximum temperature\n(°C, yearly mean)',
  pr = 'Precipitation\n(mm per year)')
product_labels = c(trace = 'TraCE21k (century means)', cruts = 'CHELSAcruts', v12 = 'CHELSA V1.2', v21 = 'CHELSA V2.1')
lab7 = function(x) mutate(x, variable = factor(var_year[variable], var_year), site = factor(site, c('MORA', 'NOCA')))
s7 = ggplot(lab7(yearly), aes(year, value, color = product)) +
  annotate('rect', xmin = 1979, xmax = 2016, ymin = -Inf, ymax = Inf, fill = 'grey92') +
  geom_line(linewidth = .6) +
  geom_segment(data = lab7(centuries), aes(x = start, xend = end, y = value, yend = value, color = 'trace'),
    linewidth = 1.6) +
  facet_grid(variable ~ site, scales = 'free_y', switch = 'y') +
  scale_color_manual(values = PRODUCT_COLORS, labels = product_labels, breaks = names(product_labels), name = NULL) +
  scale_x_continuous(breaks = seq(1800, 2020, 40), expand = expansion(.01)) +
  labs(x = 'Year CE', y = NULL) + theme_products

# Fig. S8 -------------------------------------------------------------------------------
# The yearly V2.1 against CHELSAcruts values give the spread around each factor.
spread = values |> filter(place %in% c('MORA disc', 'NOCA disc'), product %in% c('cruts', 'v21'), year %in% 1979:2016) |>
  select(product, site, variable, year, month, value) |> pivot_wider(names_from = product, values_from = value) |>
  filter(!is.na(cruts), !is.na(v21)) |>
  mutate(yearly = if_else(variable == 'pr', v21 / cruts, v21 - cruts)) |>
  group_by(site, variable, month) |>
  summarise(low = quantile(yearly, .1), high = quantile(yearly, .9), .groups = 'drop')
correction = factors |> select(site, variable, month, value = factor) |> mutate(what = 'v21') |>
  left_join(spread, by = c('site', 'variable', 'month'))
residual = check |> filter(place %in% c('MORA disc', 'NOCA disc'), variable %in% names(var_labels)) |>
  transmute(site, variable, month, value = if_else(variable == 'pr', ratio, difference), what = 'trace')
var_factor = c(tasmin = 'Minimum temperature\n(°C difference)', tasmax = 'Maximum temperature\n(°C difference)',
  pr = 'Precipitation\n(ratio)')
what_labels = c(v21 = 'CHELSA V2.1 against CHELSAcruts, 1979 to 2016 (the correction)',
  trace = 'TraCE21k timeID 20 against CHELSAcruts 1901 to 1990')
lab8 = function(x) mutate(x, variable = factor(var_factor[variable], var_factor), site = factor(site, c('MORA', 'NOCA')))
reference = tibble(variable = names(var_factor), y = c(0, 0, 1))
s8 = ggplot(lab8(bind_rows(correction, residual)), aes(month, value, color = what)) +
  geom_hline(data = lab8(reference |> crossing(site = c('MORA', 'NOCA'))), aes(yintercept = y), color = 'grey55',
    linetype = 'dashed') +
  geom_ribbon(data = lab8(correction), aes(ymin = low, ymax = high), fill = 'grey80', color = NA, alpha = .7) +
  geom_line(linewidth = 1.1) + geom_point(size = 2.2) +
  facet_grid(variable ~ site, scales = 'free_y', switch = 'y') +
  scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1), expand = expansion(.02)) +
  scale_color_manual(values = c(v21 = 'black', trace = PRODUCT_COLORS[['trace']]), labels = what_labels, name = NULL) +
  guides(color = guide_legend(nrow = 2)) +
  labs(x = 'Month', y = NULL) + theme_products

if (render_figures) {
  ggsave(fig('supplementary', 'figS06_climate_products_monthly.pdf'), s6, width = 16, height = 11, device = cairo_pdf)
  ggsave(fig('supplementary', 'figS07_climate_products_linker.pdf'), s7, width = 14, height = 11, device = cairo_pdf)
  ggsave(fig('supplementary', 'figS08_climate_bias_correction.pdf'), s8, width = 12, height = 11, device = cairo_pdf)
}
cat('Figs. S6 to S8: climate products, the linker and the bias correction drawn.\n')
