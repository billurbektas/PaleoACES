# Fig. S6 (Appendix S2, Bills, 11 Nov 2026): the two steps of the bias
# correction of the paleoclimate per park and month on the 5 km discs, from the
# outputs of R/pipeline/07_climate_products.R: step 1 TraCE21k to CHELSAcruts
# over 1900 to 1990, step 2 CHELSAcruts to V2.1 over 1979 to 2016 (with the
# spread of the yearly values), and both together, the correction of the main
# run. The monthly cycles of the four products and the yearly linker series were
# drawn as Figs. S6 and S7 until Bills removed them on 11 Nov 2026; the README
# quotes the product levels from climate_products_monthly.csv.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

values = read_csv(out('climate_products_values.csv'), show_col_types = FALSE)
factors = read_csv(out('climate_bias_correction_factors.csv'), show_col_types = FALSE)

# Not the park colours, which mean MORA and NOCA everywhere else.
PRODUCT_COLORS = c(trace = '#7B3294', cruts = '#B8860B', v12 = '#1B9E77', v21 = 'black')
theme_products = theme_paleoaces(base_size = 15) +
  theme(strip.placement = 'outside', strip.text = element_text(face = 'bold'), panel.grid.minor = element_blank(),
    legend.position = 'bottom', legend.text = element_text(size = 14), legend.key.width = unit(1.4, 'cm'),
    plot.tag = element_text(size = 18, face = 'bold'))

# Fig. S6 -------------------------------------------------------------------------------
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
lab6 = function(x) mutate(x, variable = factor(var_factor[variable], var_factor), site = factor(site, c('MORA', 'NOCA')),
  what = factor(what, names(what_labels)))
reference = tibble(variable = names(var_factor), y = c(0, 0, 1))
s6 = ggplot(lab6(steps), aes(month, value, color = what)) +
  geom_hline(data = lab6(reference |> crossing(site = c('MORA', 'NOCA'), what = 'step1')), aes(yintercept = y),
    color = 'grey55', linetype = 'dashed') +
  geom_ribbon(data = lab6(filter(steps, what == 'step2')), aes(ymin = low, ymax = high), fill = 'grey85', color = NA,
    alpha = .8) +
  geom_line(aes(linewidth = what)) + geom_point(size = 2.2) +
  facet_grid(variable ~ site, scales = 'free_y', switch = 'y') +
  scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1), expand = expansion(.02)) +
  scale_color_manual(values = what_colors, labels = what_labels, name = NULL) +
  scale_linewidth_manual(values = c(step1 = .9, step2 = .9, two_step = 1.6), labels = what_labels, name = NULL) +
  guides(color = guide_legend(nrow = 3), linewidth = guide_legend(nrow = 3)) +
  labs(x = 'Month', y = NULL) + theme_products

if (render_figures) {
  ggsave(fig('supplementary', 'figS06_climate_bias_correction.pdf'), s6, width = 12, height = 11, device = cairo_pdf)
}
cat('Fig. S6: the two steps of the bias correction drawn.\n')
