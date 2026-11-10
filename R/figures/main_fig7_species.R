# Figure 7 (PLAN.md section 6): species contributions in both eras. Species as
# rows ordered by the mean elevation of the plots where they occur, the highest
# at the top (Bills). One column per park, with its own x
# scale. Upper row contrib_climate, lower row contrib_gap. Per species a
# triangle (Holocene-S), a circle (Holocene-C) and a diamond (Anthropocene), each
# with its 95% t-interval where the interval excludes zero; other means are
# small faded symbols.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/cca_display_rotation.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Species order (Bills, 9 Nov 2026): the mean elevation of the plots where each
# species actually occurs, over the 607 paired plots, both surveys and both
# parks; the highest at the top.
source(here('R/helpers/tracking_predictor_models.R'), local = TRUE)
plots = read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE) |> distinct(site, plot_id)
mora_env = new.env(); load(here('data/MORA_plots.rda'), envir = mora_env)
elevations = tracking_modern_elevations(mora_env$plot_info,
  read_csv(here('data/NOCA/NOCA_plots_fromWilson.csv'), show_col_types = FALSE), plots)
species_elevation = read_csv(out('occ_consolidated.csv'), show_col_types = FALSE) |>
  filter(era == 'anthropocene', occurrence > 0) |>
  mutate(plot_id = toupper(plot_id)) |>
  inner_join(elevations |> transmute(site, plot_id = toupper(plot_id), elevation), by = c('site', 'plot_id')) |>
  filter(species %in% read_csv(out('cca_species_contributions.csv'), show_col_types = FALSE)$species) |>
  group_by(species) |> summarise(mean_elevation = mean(elevation), occurrences = n(), .groups = 'drop')
order_species = species_elevation |> arrange(desc(mean_elevation)) |> pull(species)
means = read_csv(out('species_contribution_models/species_means.csv'), show_col_types = FALSE) |>
  mutate(species = factor(species, levels = order_species),
    period_type = factor(period_type, levels = c('Holocene-S', 'Holocene-C', 'Anthropocene')),
    spans_zero = !interval_defined | (conf_low <= 0 & conf_high >= 0),
    measure_label = factor(c(contrib_climate = 'Following climate-predicted direction',
      contrib_gap = 'Shrinking the initial mismatch')[measure],
      levels = c('Following climate-predicted direction',
        'Shrinking the initial mismatch')))
# Species absent from a park's Holocene record (no share at either end of any
# lake-period) are marked instead of drawn as Holocene symbols.
absent = means |> filter(period_type != 'Anthropocene') |> group_by(measure_label, species, site) |>
  summarise(absent = !any(present), .groups = 'drop') |> filter(absent)
drawn = means |> anti_join(absent |> mutate(period_type = list(c('Holocene-S', 'Holocene-C'))) |> unnest(period_type) |>
  mutate(period_type = factor(period_type, levels = levels(means$period_type))), by = c('measure_label', 'species', 'site', 'period_type')) |>
  filter(!(period_type == 'Anthropocene' & !present))
nudge = c(`Holocene-S` = .22, `Holocene-C` = 0, Anthropocene = -.22)
drawn = drawn |> mutate(y = as.integer(species) + nudge[as.character(period_type)])
# Decluttered (Bills): intervals only where they exclude zero, the other means
# as small faded symbols; light bands alternate between species rows; species
# absent from a park's Holocene record simply have no Holocene symbols.
bands = tibble(species_index = seq(1, length(order_species), by = 2))
x_extent = drawn |> group_by(site) |> summarise(m = max(abs(c(estimate, conf_low, conf_high)), na.rm = TRUE)) |>
  reframe(site = rep(site, 2), x = c(-m, m)) |>
  expand_grid(measure_label = factor(levels(means$measure_label), levels = levels(means$measure_label)))
side_labels = expand_grid(measure_label = factor(levels(means$measure_label), levels = levels(means$measure_label)),
  site = c('MORA', 'NOCA'), side = c('negative', 'positive')) |>
  # Each label starts at the zero line and runs away from it, so it never crosses it.
  mutate(x = 0, hjust = if_else(side == 'negative', 1.04, -.04),
    label = case_when(
      # The labels continue the row title (Bills).
      as.integer(measure_label) == 1 & side == 'negative' ~ '\u2190 against',
      as.integer(measure_label) == 1 ~ 'following \u2192',
      side == 'negative' ~ '\u2190 enlarging',
      TRUE ~ 'shrinking \u2192'))
figure = ggplot(drawn, aes(estimate, y)) +
  geom_rect(data = bands, aes(xmin = -Inf, xmax = Inf, ymin = species_index - .5, ymax = species_index + .5),
    inherit.aes = FALSE, fill = 'grey95') +
  geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed') +
  geom_errorbar(data = filter(drawn, !spans_zero), aes(xmin = conf_low, xmax = conf_high, color = site),
    orientation = 'y', width = .2, linewidth = 1, na.rm = TRUE) +
  geom_point(data = filter(drawn, spans_zero), aes(shape = period_type, fill = site), size = 3, color = 'grey45', alpha = .35) +
  geom_point(data = filter(drawn, !spans_zero), aes(shape = period_type, fill = site), size = 4.6, color = 'grey10') +
  # What each side of zero means, written at the top of every panel (Bills).
  # Symmetric x range per park, so both sides have room for their label.
  geom_blank(data = x_extent, aes(x = x, y = 1), inherit.aes = FALSE) +
  geom_label(data = side_labels, aes(x = x, y = -.25, label = label, hjust = hjust), size = 8.6,
    fontface = 'italic', color = 'grey25', fill = 'white', linewidth = 0, label.padding = unit(.1, 'lines'),
    inherit.aes = FALSE) +
  facet_grid(measure_label ~ site, scales = 'free_x', switch = 'y') +
  # Extra room above the first species for the side labels.
  scale_y_reverse(breaks = seq_along(order_species), labels = order_species, expand = expansion(add = c(1.5, .6))) +
  scale_shape_manual(values = PERIOD_TYPE_SHAPES[c('Holocene-S', 'Holocene-C', 'Anthropocene')], name = NULL,
    labels = c('Holocene stability periods', 'Holocene climate-change periods', 'Anthropocene')) +
  scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') + scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60', size = 5))) +
  labs(x = 'Species contribution', y = NULL) +
  theme_paleoaces(base_size = 24) +
  theme(axis.text.y = element_text(face = 'italic', size = 23), axis.text.x = element_text(size = 21),
    strip.placement = 'outside', legend.position = 'bottom', legend.text = element_text(size = 22),
    panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
    strip.text.x = element_text(size = 26, face = 'bold'), strip.text.y.left = element_text(angle = 90, size = 22, face = 'bold'))
if (render_figures) {
  # cairo_pdf draws the arrows of the side labels.
  ggsave(fig('main', 'fig_species_contributions.pdf'), figure, width = 18, height = 20, device = cairo_pdf)
  ggsave(fig('main', 'fig_species_contributions.png'), figure, width = 18, height = 20, dpi = 300)
}
write_csv(species_elevation |> arrange(desc(mean_elevation)) |> mutate(rank = row_number(), .before = 1),
  out('figures/species_order_elevation.csv'))
cat('Figure 7: species contributions drawn.\n')
