# Figs. S6 and S7 (Appendix S2), from the outputs of R/pipeline/07_climate_products.R.
# Fig. S6 (Bills, 12 Nov 2026): the three products of the correction without
# correction, over the years they share: TraCE21k timeID 20 (the mean of 1900 to
# 1990) and CHELSAcruts and V2.1 over 1979 to 1990, by month, as the median over
# the plots of each park and over the cells within 5 km of its lakes.
# Fig. S7 (Bills, 11 Nov 2026): the two steps of the bias correction of the
# paleoclimate per park and month on the 5 km discs: step 1 TraCE21k to
# CHELSAcruts over 1900 to 1990, step 2 CHELSAcruts to V2.1 over 1979 to 2016
# (with the spread of the yearly values), and both together, the correction of
# the main run. The monthly cycles of the four products and the yearly linker
# series were drawn as Figs. S6 and S7 on 11 Nov 2026 until Bills removed them.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

values = read_csv(out('climate_products_values.csv'), show_col_types = FALSE)
medians = read_csv(out('climate_products_point_medians.csv'), show_col_types = FALSE)
factors = read_csv(out('climate_bias_correction_factors.csv'), show_col_types = FALSE)

# Not the park colours, which mean MORA and NOCA everywhere else.
PRODUCT_COLORS = c(trace = '#7B3294', cruts = '#B8860B', v12 = '#1B9E77', v21 = 'black')
theme_products = theme_paleoaces(base_size = 15) +
  theme(strip.placement = 'outside', strip.text = element_text(face = 'bold'), panel.grid.minor = element_blank(),
    legend.position = 'bottom', legend.text = element_text(size = 14), legend.key.width = unit(1.4, 'cm'),
    plot.tag = element_text(size = 18, face = 'bold'))

# Fig. S6 -------------------------------------------------------------------------------
product_labels = c(trace = 'CHELSA-TraCE21k, timeID 20 (1900 to 1990)', cruts = 'CHELSAcruts, 1979 to 1990',
  v21 = 'CHELSA V2.1, 1979 to 1990')
var_labels = c(tasmin = 'Minimum temperature\n(°C)', tasmax = 'Maximum temperature\n(°C)',
  pr = 'Precipitation\n(mm per month)')
place_labels = c(`MORA plots` = 'MORA, forest plots', `MORA disc` = 'MORA, 5 km around the lakes',
  `NOCA plots` = 'NOCA, forest plots', `NOCA disc` = 'NOCA, 5 km around the lake')
lab_s6 = function(x) mutate(x, place = factor(place_labels[place], place_labels),
  variable = factor(var_labels[variable], var_labels), product = factor(product, names(product_labels)))
s6_raw = ggplot(lab_s6(medians), aes(month, median, color = product)) +
  geom_line(linewidth = 1.1) + geom_point(size = 2) +
  facet_grid(variable ~ place, scales = 'free_y', switch = 'y') +
  scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1), expand = expansion(.02)) +
  scale_color_manual(values = PRODUCT_COLORS[names(product_labels)], labels = product_labels, name = NULL) +
  labs(x = 'Month', y = NULL) + theme_products

# Fig. S7 -------------------------------------------------------------------------------
# The yearly V2.1 against CHELSAcruts values give the spread around step 2.
spread = values |> filter(place %in% c('MORA disc', 'NOCA disc'), product %in% c('cruts', 'v21'), year %in% 1979:2016) |>
  select(product, site, variable, year, month, value) |> pivot_wider(names_from = product, values_from = value) |>
  filter(!is.na(cruts), !is.na(v21)) |>
  mutate(yearly = if_else(variable == 'pr', v21 / cruts, v21 - cruts)) |>
  group_by(site, variable, month) |>
  summarise(low = quantile(yearly, .1), high = quantile(yearly, .9), .groups = 'drop')
steps = factors |> select(site, variable, month, step1, step2, two_step) |>
  pivot_longer(c(step1, step2, two_step), names_to = 'what') |>
  left_join(spread |> mutate(what = 'step2'), by = c('site', 'variable', 'month', 'what'))
var_factor = c(tasmin = 'Minimum temperature\n(°C added)', tasmax = 'Maximum temperature\n(°C added)',
  pr = 'Precipitation\n(ratio)')
what_labels = c(step1 = 'Step 1: TraCE21k to CHELSAcruts, 1900 to 1990', step2 = 'Step 2: CHELSAcruts to V2.1, 1979 to 2016',
  two_step = 'Both steps: the correction of the main run')
what_colors = c(step1 = PRODUCT_COLORS[['trace']], step2 = 'grey35', two_step = '#C0392B')
lab7 = function(x) mutate(x, variable = factor(var_factor[variable], var_factor), site = factor(site, c('MORA', 'NOCA')),
  what = factor(what, names(what_labels)))
reference = tibble(variable = names(var_factor), y = c(0, 0, 1))
s7 = ggplot(lab7(steps), aes(month, value, color = what)) +
  geom_hline(data = lab7(reference |> crossing(site = c('MORA', 'NOCA'), what = 'step1')), aes(yintercept = y),
    color = 'grey55', linetype = 'dashed') +
  geom_ribbon(data = lab7(filter(steps, what == 'step2')), aes(ymin = low, ymax = high), fill = 'grey85', color = NA,
    alpha = .8) +
  geom_line(aes(linewidth = what)) + geom_point(size = 2.2) +
  facet_grid(variable ~ site, scales = 'free_y', switch = 'y') +
  scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1), expand = expansion(.02)) +
  scale_color_manual(values = what_colors, labels = what_labels, name = NULL) +
  scale_linewidth_manual(values = c(step1 = .9, step2 = .9, two_step = 1.6), labels = what_labels, name = NULL) +
  guides(color = guide_legend(nrow = 3), linewidth = guide_legend(nrow = 3)) +
  labs(x = 'Month', y = NULL) + theme_products

if (render_figures) {
  ggsave(fig('supplementary', 'figS06_climate_products_raw.pdf'), s6_raw, width = 15, height = 10, device = cairo_pdf)
  ggsave(fig('supplementary', 'figS07_climate_bias_correction.pdf'), s7, width = 12, height = 11, device = cairo_pdf)
}
cat('Figs. S6 and S7: the three products without correction and the two steps of the bias correction drawn.\n')
