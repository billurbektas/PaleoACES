# Monthly climate of the four CHELSA products at the plots and the lakes (Bills,
# 11 Nov 2026). Reads what download_products.R wrote and writes only to
# output_product_comparison/. Outside the pipeline and the README.
#
# One column per place (the mean over the plots of each park, then each lake),
# one row per variable. Lines: TraCE21k timeID 20, the mean of 1900 to 1990;
# CHELSAcruts over the same window (1901 to 1990) and over 1979 to 1990;
# CHELSA V1.2 and V2.1 over 1979 to 1990, the period all four products share.
# Grey lines: each V2.1 year, 1979 to 1990, for the year-to-year spread.
# Comparing TraCE21k with CHELSAcruts 1901 to 1990 matches the years; comparing
# CHELSAcruts 1901 to 1990 with CHELSAcruts 1979 to 1990 shows what the choice
# of years alone does; the three 1979 to 1990 lines show what the product alone does.
#
# Also writes product_summary.csv: the annual values and the two CCA variables
# (spring temperature MSpT, March to May mean of (tasmin + tasmax) / 2; summer
# precipitation SP, June to August sum) of each line at each place.
suppressPackageStartupMessages({library(here); library(tidyverse)})
source(here('R/helpers/figure_style.R'), local = TRUE)
root = here('output_product_comparison')
dir.create(file.path(root, 'figures'), showWarnings = FALSE)

climatology = read_csv(file.path(root, 'climatology_by_point.csv'), show_col_types = FALSE)
yearly = read_csv(file.path(root, 'yearly_by_place.csv'), show_col_types = FALSE)
places = c(`MORA plots` = 'MORA plots', `NOCA plots` = 'NOCA plots', JayBath = 'Jay Bath (MORA)',
  LogWallow = 'Log Wallow (MORA)', ReflectionPond = 'Reflection Pond (MORA)', PantherPotholes = 'Panther Potholes (NOCA)')
series = c(trace_1900 = 'TraCE21k timeID 20 (1900 to 1990)', cruts_1901 = 'CHELSAcruts 1901 to 1990',
  cruts_1979 = 'CHELSAcruts 1979 to 1990', v12_1979 = 'CHELSA V1.2 1979 to 1990', v21_1979 = 'CHELSA V2.1 1979 to 1990')
# Not the park colours, which mean MORA and NOCA everywhere else.
series_colors = c(trace_1900 = '#7B3294', cruts_1901 = '#B8860B', cruts_1979 = '#B8860B', v12_1979 = '#1B9E77',
  v21_1979 = 'black')
series_lines = c(trace_1900 = 'solid', cruts_1901 = '22', cruts_1979 = 'solid', v12_1979 = 'solid', v21_1979 = 'solid')
var_names = c(tasmin = 'Minimum temperature\n(°C)', tasmax = 'Maximum temperature\n(°C)',
  pr = 'Precipitation\n(mm per month)')

# The plots of a park are averaged after each point's climatology is formed.
lines = climatology |>
  mutate(place = ifelse(kind == 'plot', paste(site, 'plots'), id),
    series = paste0(product, '_', substr(window, 1, 4))) |>
  group_by(series, place, variable, month) |> summarise(value = mean(value), .groups = 'drop')
stopifnot(setequal(unique(lines$series), names(series)), setequal(unique(lines$place), names(places)))
lab = function(x) mutate(x, place = factor(places[place], places), variable = factor(var_names[variable], var_names))

figure = ggplot(lab(lines), aes(month, value)) +
  geom_line(data = lab(filter(yearly, product == 'v21')), aes(group = year), color = 'grey78', linewidth = .35) +
  geom_line(aes(color = series, linetype = series), linewidth = 1.1) +
  geom_point(data = lab(filter(lines, series == 'trace_1900')), aes(color = series), size = 1.9, show.legend = FALSE) +
  facet_grid(variable ~ place, scales = 'free_y', switch = 'y') +
  scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1), expand = expansion(.02)) +
  scale_color_manual(values = series_colors, labels = series, breaks = names(series), name = NULL) +
  scale_linetype_manual(values = series_lines, labels = series, breaks = names(series), name = NULL) +
  guides(color = guide_legend(nrow = 2, byrow = TRUE, override.aes = list(linewidth = 1.3)),
    linetype = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(x = 'Month', y = NULL, caption = 'Grey lines: each CHELSA V2.1 year, 1979 to 1990.') +
  theme_paleoaces(base_size = 15) +
  theme(strip.placement = 'outside', strip.text = element_text(face = 'bold'), panel.grid.minor = element_blank(),
    legend.position = 'top', legend.text = element_text(size = 14), legend.key.width = unit(1.4, 'cm'))
ggsave(file.path(root, 'figures', 'products_monthly.pdf'), figure, width = 22, height = 10.5, device = cairo_pdf)
ggsave(file.path(root, 'figures', 'products_monthly.png'), figure, width = 22, height = 10.5, dpi = 110, bg = 'white')

# Annual values and the two CCA variables of each line at each place.
wide = lines |> pivot_wider(names_from = variable, values_from = value)
summary = wide |> group_by(series, place) |>
  summarise(annual_tasmin = mean(tasmin), annual_tasmax = mean(tasmax), annual_pr = sum(pr),
    MSpT = mean(((tasmin + tasmax) / 2)[month %in% 3:5]), SP = sum(pr[month %in% 6:8]), .groups = 'drop') |>
  mutate(series = factor(series, names(.env$series)), place = factor(place, names(places))) |> arrange(place, series)
write_csv(summary, file.path(root, 'product_summary.csv'))
print(as.data.frame(summary |> mutate(across(where(is.numeric), ~ round(.x, 2)))))
cat('Figure: output_product_comparison/figures/products_monthly.pdf (and .png)\n')
