# Figs. S22 to S27 (Appendix S5, Bills, 24 Nov 2026): the analysis with three
# Anthropocene climate products in the same panels, CHELSA V2.1 (the main run),
# PRISM LT81m and nClimGrid, each with the Holocene climate corrected onto it in
# two steps. One colour and symbol per product in every figure; MORA and NOCA
# in separate facets where the result is per park. All read the comparison
# written by R/sensitivity_climate_products.R. Figs. S25 and S26 are drawn by
# R/helpers/sensitivity_figures.R, which Appendix S4 shares.
#   S22  climate of the plot pairs at the two surveys and its change
#   S23  Holocene climate at the lakes and the climate periods (Figure 3)
#   S24  the climate-community space: species scores and climate arrows (Figure 4)
#   S25  rates, lag and contributions by period type (Figure 5)
#   S26  associations with climate and fire: model slopes (Figure 6)
#   S27  species contributions in the climate-predicted direction (Figure 7)
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork); library(ggrepel)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/sensitivity_figures.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

comparison_dir = here('output_climate_sensitivity', 'comparison')
if (!file.exists(file.path(comparison_dir, 'species_means.csv'))) {
  cat('Figs. S22 to S27 skipped: run Rscript R/sensitivity_climate_products.R first.\n')
} else {
  read = function(f) read_csv(file.path(comparison_dir, f), show_col_types = FALSE)
  # Colours checked for colour-blind separation and contrast (dataviz validator, 24 Nov 2026),
  # away from the park blue and red; a symbol per product as a second cue.
  PRODUCT_LABELS = c(v21 = 'CHELSA V2.1 (main analysis)', prism = 'PRISM LT81m', nclimgrid = 'nClimGrid')
  PRODUCT_COLORS = c(v21 = '#7B3FA0', prism = '#138D75', nclimgrid = '#C77C02')
  PRODUCT_SHAPES = c(v21 = 21, prism = 23, nclimgrid = 22)
  products = intersect(names(PRODUCT_LABELS), unique(read('plot_climate_medians.csv')$product))
  as_product = function(x) factor(x, levels = products)
  product_scales = function(labels = PRODUCT_LABELS, aesthetics = c('colour', 'fill', 'shape'))
    sensitivity_scales(labels[products], PRODUCT_COLORS, PRODUCT_SHAPES, aesthetics)
  variable_labels = c(MSpT = 'Spring temperature (°C)', SP = 'Summer precipitation (mm)')
  type_labels = c(`Holocene-S` = 'Holocene stability', `Holocene-C` = 'Holocene climate change', Anthropocene = 'Anthropocene')
  type_ticks = c(`Holocene-S` = 'Holocene\nstability', `Holocene-C` = 'Holocene\nclimate change', Anthropocene = 'Anthropocene')
  signed = function(x, digits) sub('^-', '−', formatC(x, format = 'f', digits = digits))
  save_figure = function(plot, name, width, height) if (render_figures)
    ggsave(fig('supplementary', name), plot, width = width, height = height, device = cairo_pdf)
  theme_s5 = sensitivity_theme
  dodge = position_dodge(width = .55)

  # Fig. S22 -------------------------------------------------------------------------
  # Left, the median over the plot pairs of each survey with the interquartile range;
  # right, the median of the plots' own change. Precipitation change in percent.
  medians = read('plot_climate_medians.csv') |>
    mutate(product = as_product(product), variable = factor(variable_labels[variable], variable_labels))
  levels_long = medians |> select(product, site, variable, starts_with('legacy'), starts_with('resurvey')) |>
    pivot_longer(-c(product, site, variable), names_to = c('survey', '.value'), names_pattern = '(legacy|resurvey)_(.*)') |>
    mutate(survey = factor(c(legacy = 'Legacy\n1979–1989', resurvey = 'Resurvey')[survey], c('Legacy\n1979–1989', 'Resurvey')))
  a = ggplot(levels_long, aes(survey, median, color = product, fill = product, shape = product, group = product)) +
    geom_line(position = dodge, linewidth = 1) +
    geom_errorbar(aes(ymin = q25, ymax = q75), position = dodge, width = .25, linewidth = .9) +
    geom_point(position = dodge, size = 4, color = 'grey15', stroke = .5) +
    facet_grid(variable ~ site, scales = 'free_y', switch = 'y') + product_scales() +
    labs(x = NULL, y = NULL, tag = 'A', title = 'Climate at the two surveys') + theme_s5() +
    theme(strip.placement = 'outside', strip.background.y = element_blank())
  change = read('plot_climate.csv') |> mutate(value = if_else(variable == 'SP', change_percent, change),
    product = as_product(product),
    variable = factor(c(MSpT = 'Spring temperature change (°C)', SP = 'Summer precipitation change (%)')[variable],
      c('Spring temperature change (°C)', 'Summer precipitation change (%)'))) |>
    group_by(product, site, variable) |>
    summarise(median = median(value), q25 = quantile(value, .25), q75 = quantile(value, .75), .groups = 'drop') |>
    mutate(label = if_else(grepl('°C', variable), signed(median, 2), signed(median, 1)))
  b = ggplot(change, aes(product, median, color = product, fill = product, shape = product)) +
    geom_hline(yintercept = 0, color = 'grey55', linetype = 'dashed') +
    geom_errorbar(aes(ymin = q25, ymax = q75), width = .2, linewidth = .9) +
    geom_point(size = 4, color = 'grey15', stroke = .5) +
    geom_text(aes(label = label, y = q75), vjust = -.6, size = 5,
      color = 'grey20', show.legend = FALSE) +
    scale_y_continuous(expand = expansion(mult = c(.06, .14))) +
    facet_grid(variable ~ site, scales = 'free_y', switch = 'y') + product_scales() +
    guides(colour = 'none', fill = 'none', shape = 'none') +
    labs(x = NULL, y = NULL, tag = 'B', title = 'Change at each plot pair') + theme_s5() +
    theme(strip.placement = 'outside', strip.background.y = element_blank(), axis.text.x = element_blank(),
      axis.ticks.x = element_blank())
  save_figure((a | b) + plot_layout(guides = 'collect') & theme(legend.position = 'bottom'),
    'figS22_climate_products_plot_climate.pdf', 17, 10)

  # Fig. S23 -------------------------------------------------------------------------
  # The corrected Holocene climate at the lakes of each park (the mean of the MORA
  # lakes), as the centred 1,000-year running mean of Figure 3 (11 slices), and the
  # climate periods each product gives (drawn from the regional series of Figure 3).
  levels = read('holocene_levels.csv') |> filter(in_view, variable %in% names(variable_labels)) |>
    select(product, variable, t, MORA = raw_MORA, NOCA = raw_NOCA) |>
    pivot_longer(c(MORA, NOCA), names_to = 'site') |> arrange(product, variable, site, desc(t)) |>
    group_by(product, variable, site) |> mutate(value_1000yr = as.numeric(stats::filter(value, rep(1 / 11, 11), sides = 2))) |>
    ungroup() |> filter(is.finite(value_1000yr)) |>
    mutate(product = as_product(product), variable = factor(two_line_title(variable_labels[variable]), two_line_title(variable_labels)))
  time_limits = c(max(levels$t), min(levels$t))
  # A product whose run keeps the Holocene climate of the main analysis (corrected onto
  # V2.1) has the V2.1 lines: drawn dashed on top of them.
  onto = read('products.csv')
  kept = onto$product[onto$holocene_corrected_onto != onto$product]
  lines = ggplot(levels, aes(t, value_1000yr, color = product)) +
    geom_line(data = filter(levels, !product %in% kept), linewidth = 1.3) +
    geom_line(data = filter(levels, product %in% kept), linewidth = 1.3, linetype = '22') +
    facet_grid(variable ~ site, scales = 'free_y', switch = 'y') + product_scales(aesthetics = 'colour') +
    scale_x_reverse(limits = time_limits, labels = scales::label_comma()) +
    labs(x = NULL, y = NULL, tag = 'A') + theme_s5() +
    theme(strip.placement = 'outside', strip.background.y = element_blank(), axis.text.x = element_blank(),
      axis.ticks.x = element_blank())
  periods = read('climate_periods.csv') |> mutate(product = as_product(product),
    row = as.integer(product), kind = if_else(period_type == 'Holocene-C', 'Climate change', 'Stability')) |>
    expand_grid(site = c('MORA', 'NOCA'))
  strip = ggplot(periods) +
    geom_rect(aes(xmin = older_cal_bp, xmax = younger_cal_bp, ymin = row - .4, ymax = row + .4, fill = product,
      alpha = kind), color = 'white', linewidth = .6) +
    geom_text(aes(x = (older_cal_bp + younger_cal_bp) / 2, y = row, label = period), size = 4.2,
      color = if_else(periods$kind == 'Climate change', 'white', 'grey15')) +
    facet_grid(. ~ site) + product_scales(aesthetics = 'fill') + guides(fill = 'none') +
    scale_alpha_manual(values = c(`Climate change` = 1, Stability = .3), name = NULL,
      guide = guide_legend(override.aes = list(fill = 'grey35'))) +
    scale_x_reverse(limits = time_limits, labels = scales::label_comma()) +
    scale_y_reverse(breaks = seq_along(products), labels = unname(c(v21 = 'V2.1', prism = 'PRISM',
      nclimgrid = 'nClimGrid')[products]), expand = expansion(add = .1)) +
    labs(x = 'Age (cal BP)', y = NULL, tag = 'B') + theme_s5() +
    theme(panel.grid = element_blank(), strip.text = element_blank(), strip.background = element_blank())
  save_figure((lines / strip) + plot_layout(heights = c(4, 1.1), guides = 'collect') & theme(legend.position = 'bottom'),
    'figS23_climate_products_holocene_periods.pdf', 16, 12)

  # Fig. S24 -------------------------------------------------------------------------
  # The CCA of each product in its own display rotation (axis 1 along spring
  # temperature, axis 2 along summer precipitation), so that the three spaces are
  # oriented alike. Grey lines join the positions of each species in the three CCAs.
  cca = read('cca.csv') |> mutate(product = as_product(product))
  inertia = cca |> distinct(product, constrained_percent_total) |>
    mutate(label = sprintf('%s: %s%% of inertia constrained', PRODUCT_LABELS[as.character(product)],
      formatC(constrained_percent_total, format = 'f', digits = 1)))
  species = cca |> filter(kind == 'species') |> arrange(name, product)
  climate = cca |> filter(kind == 'climate')
  arrow_scale = .85 * max(sqrt(species$axis1^2 + species$axis2^2)) / max(sqrt(climate$axis1^2 + climate$axis2^2))
  climate = climate |> mutate(x = axis1 * arrow_scale, y = axis2 * arrow_scale,
    label = c(MSpT = 'Spring temperature', SP = 'Summer precipitation')[name])
  s24 = ggplot() + geom_hline(yintercept = 0, color = 'grey80') + geom_vline(xintercept = 0, color = 'grey80') +
    geom_path(data = species, aes(axis1, axis2, group = name), color = 'grey65', linewidth = .5) +
    geom_segment(data = climate, aes(0, 0, xend = x, yend = y, color = product), linewidth = 1.2,
      arrow = arrow(length = unit(.3, 'cm'))) +
    geom_point(data = species, aes(axis1, axis2, fill = product, shape = product), size = 3.6, color = 'grey15', stroke = .5) +
    geom_text_repel(data = filter(species, product == 'v21'), aes(axis1, axis2, label = name), size = 5.2,
      fontface = 'italic', color = 'grey20', seed = 1, min.segment.length = .2, box.padding = .5) +
    geom_label(data = filter(climate, product == 'v21'), aes(x * 1.12, y * 1.12, label = label), size = 5.6,
      label.size = 0, fill = alpha('white', .8)) +
    product_scales(setNames(inertia$label, as.character(inertia$product))) +
    guides(color = 'none', fill = guide_legend(ncol = 1, override.aes = list(size = 4.5)), shape = guide_legend(ncol = 1)) +
    expand_limits(x = range(c(species$axis1, climate$x * 1.35)), y = range(c(species$axis2, climate$y * 1.2))) +
    coord_equal() + labs(x = 'CCA axis 1 (rotated, along spring temperature)', y = 'CCA axis 2 (rotated, along summer precipitation)') +
    theme_s5()
  save_figure(s24, 'figS24_climate_products_cca.pdf', 13, 13)

  # Fig. S25 -------------------------------------------------------------------------
  # Figure 5's responses by period type, park and product.
  save_figure(sensitivity_era_means_figure(read('era_means.csv') |> mutate(version = as_product(product)),
    PRODUCT_LABELS[products], PRODUCT_COLORS, PRODUCT_SHAPES), 'figS25_climate_products_era_means.pdf', 14, 24)

  # Fig. S26 -------------------------------------------------------------------------
  # Figure 6's slopes per product.
  save_figure(sensitivity_slopes_figure(read('model_coefficients.csv') |> mutate(version = as_product(product)),
    PRODUCT_LABELS[products], PRODUCT_COLORS, PRODUCT_SHAPES), 'figS26_climate_products_slopes.pdf', 16, 13)

  # Fig. S27 -------------------------------------------------------------------------
  # Species contributions in the climate-predicted direction (per century), means and
  # 95% intervals; faded where the interval includes zero. Species in the order of
  # Figure 7 (highest elevation first); species absent from a park and period type left out.
  order_file = out('figures/species_order_elevation.csv')
  sp = read('species_means.csv')
  order_species = if (file.exists(order_file)) read_csv(order_file, show_col_types = FALSE) |>
    arrange(desc(max_elevation), desc(mean_elevation)) |> pull(species) else sort(unique(sp$species))
  sp = sp |> filter(present, interval_defined | n == 1) |>
    mutate(product = as_product(product), species = factor(species, rev(order_species)),
      period_type = factor(type_labels[period_type], type_labels),
      faded = !interval_defined | (conf_low <= 0 & conf_high >= 0))
  dodge_y = position_dodge(width = .7)
  s27 = ggplot(sp, aes(estimate, species, color = product, fill = product, shape = product, group = fct_rev(product))) +
    geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed') +
    geom_errorbar(aes(xmin = conf_low, xmax = conf_high, alpha = faded), orientation = 'y', position = dodge_y,
      width = .5, linewidth = .8) +
    geom_point(aes(alpha = faded), position = dodge_y, size = 3, color = 'grey15', stroke = .4) +
    facet_grid(period_type ~ site, scales = 'free', space = 'free_y') + product_scales() +
    scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = .3), guide = 'none') +
    labs(x = 'Species contribution in the climate-predicted direction (per century)', y = NULL) + theme_s5(16) +
    theme(axis.text.y = element_text(face = 'italic'))
  save_figure(s27, 'figS27_climate_products_species.pdf', 16, 22)
  cat('Figs. S22 to S27: the analysis with', paste(PRODUCT_LABELS[products], collapse = ', '), 'drawn.\n')
}
