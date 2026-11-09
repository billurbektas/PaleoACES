# Figure 7 (PLAN.md section 6): species contributions in both eras. Species as
# rows ordered by their score on rotated axis 1 (spring temperature), the
# cold-associated species at the top. One column per park, with its own x
# scale. Upper row contrib_climate, lower row contrib_gap. Per species a
# triangle (Holocene-S), a circle (Holocene-C) and a diamond (Anthropocene), each
# with its 95% t-interval. A symbol is faded where its interval spans zero.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/cca_display_rotation.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

reference = readRDS(out('cca_calibration_reference.rds'))
bp = scores(reference$model, display = 'bp', choices = 1:2, scaling = 'sites', hill = FALSE)
species_scores = scores(reference$model, display = 'species', choices = 1:2, scaling = 'sites', hill = FALSE) %*%
  cca_display_rotation(bp)$matrix
order_species = rownames(species_scores)[order(species_scores[, 1])]  # coldest first, drawn at the top
means = read_csv(out('species_contribution_models/species_means.csv'), show_col_types = FALSE) |>
  mutate(species = factor(species, levels = order_species),
    period_type = factor(period_type, levels = c('Holocene-S', 'Holocene-C', 'Anthropocene')),
    spans_zero = !interval_defined | (conf_low <= 0 & conf_high >= 0),
    measure_label = factor(c(contrib_climate = 'Contribution along the predicted movement\n(CCA distance per century)',
      contrib_gap = 'Contribution along the starting gap\n(CCA distance per century)')[measure],
      levels = c('Contribution along the predicted movement\n(CCA distance per century)',
        'Contribution along the starting gap\n(CCA distance per century)')))
# Species absent from a park's Holocene record (no share at either end of any
# lake-period) are marked instead of drawn as Holocene symbols.
absent = means |> filter(period_type != 'Anthropocene') |> group_by(measure_label, species, site) |>
  summarise(absent = !any(present), .groups = 'drop') |> filter(absent)
drawn = means |> anti_join(absent |> mutate(period_type = list(c('Holocene-S', 'Holocene-C'))) |> unnest(period_type) |>
  mutate(period_type = factor(period_type, levels = levels(means$period_type))), by = c('measure_label', 'species', 'site', 'period_type')) |>
  filter(!(period_type == 'Anthropocene' & !present))
nudge = c(`Holocene-S` = .22, `Holocene-C` = 0, Anthropocene = -.22)
drawn = drawn |> mutate(y = as.integer(species) + nudge[as.character(period_type)])
figure = ggplot(drawn, aes(estimate, y)) +
  geom_vline(xintercept = 0, color = 'grey60', linetype = 'dashed') +
  geom_errorbar(aes(xmin = conf_low, xmax = conf_high, color = site, alpha = spans_zero), orientation = 'y', width = .15, na.rm = TRUE) +
  geom_point(aes(shape = period_type, fill = site, alpha = spans_zero), size = 3.4, color = 'grey15') +
  geom_text(data = absent, aes(x = 0, y = as.integer(species) + .11, label = 'absent from Holocene record'),
    size = 4, color = 'grey45', hjust = .5) +
  facet_grid(measure_label ~ site, scales = 'free_x', switch = 'y') +
  scale_y_reverse(breaks = seq_along(order_species), labels = order_species, expand = expansion(add = .6)) +
  scale_shape_manual(values = PERIOD_TYPE_SHAPES[c('Holocene-S', 'Holocene-C', 'Anthropocene')], name = NULL,
    labels = c('Holocene stability periods', 'Holocene climate-change periods', 'Anthropocene')) +
  scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') + scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
  scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = .3), guide = 'none') +
  guides(shape = guide_legend(override.aes = list(fill = 'grey60', size = 5))) +
  labs(x = 'Contribution (CCA distance per century)', y = NULL) +
  theme_paleoaces(base_size = 18) +
  theme(axis.text.y = element_text(face = 'italic'), strip.placement = 'outside', legend.position = 'bottom',
    strip.text.y.left = element_text(angle = 90))
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_species_contributions.', ext)), figure, width = 15, height = 16, dpi = 300)
write_csv(tibble(rank = seq_along(order_species), species = order_species, rotated_axis_1 = species_scores[order_species, 1]),
  out('figures/species_order_rotated_axis_1.csv'))
cat('Figure 7: species contributions drawn.\n')
