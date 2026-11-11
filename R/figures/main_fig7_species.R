# Figure 7 (PLAN.md section 6): species contributions in both eras. Species as
# rows ordered by the mean elevation of the plots where they occur, the highest
# at the top (Bills). One column per park, with its own x
# scale. Upper row contrib_climate, lower row contrib_lag (Bills, 11 Nov 2026,
# in place of contrib_gap): the species' part of the lag rate, negative where
# the species narrowed the climate-community lag. Per species a
# triangle (Holocene-S), a circle (Holocene-C) and a diamond (Anthropocene), each
# with its 95% t-interval where the interval excludes zero; other means are
# small faded symbols.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/cca_display_rotation.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Species order (Bills, 11 Nov 2026; by the mean until then): the maximum
# elevation of the plots where each species occurs, over the 607 paired plots,
# both surveys and both parks; the highest at the top, ties by the mean. The
# species names are shaded by that maximum.
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
  group_by(species) |> summarise(max_elevation = max(elevation), mean_elevation = mean(elevation),
    occurrences = n(), .groups = 'drop')
order_species = species_elevation |> arrange(desc(max_elevation), desc(mean_elevation)) |> pull(species)
means = read_csv(out('species_contribution_models/species_means.csv'), show_col_types = FALSE) |>
  mutate(species = factor(species, levels = order_species),
    period_type = factor(period_type, levels = c('Holocene-S', 'Holocene-C', 'Anthropocene')),
    spans_zero = !interval_defined | (conf_low <= 0 & conf_high >= 0),
    measure_label = factor(c(contrib_climate = 'Following climate-predicted direction',
      contrib_lag = 'Changing the climate-community lag')[measure],
      levels = c('Following climate-predicted direction',
        'Changing the climate-community lag')))
# Species absent from a park's Holocene record (no share at either end of any
# lake-period) are marked instead of drawn as Holocene symbols.
absent = means |> filter(period_type != 'Anthropocene') |> group_by(measure_label, species, site) |>
  summarise(absent = !any(present), .groups = 'drop') |> filter(absent)
drawn = means |> anti_join(absent |> mutate(period_type = list(c('Holocene-S', 'Holocene-C'))) |> unnest(period_type) |>
  mutate(period_type = factor(period_type, levels = levels(means$period_type))), by = c('measure_label', 'species', 'site', 'period_type')) |>
  filter(!(period_type == 'Anthropocene' & !present))
nudge = c(`Holocene-S` = .22, `Holocene-C` = 0, Anthropocene = -.22)
drawn = drawn |> mutate(y = as.integer(species) + nudge[as.character(period_type)])
# One y range for the panels and the species-name column, so their rows line up:
# room above the first species for the side labels (y = -0.25).
y_limits = c(max(drawn$y) + .6, -1.75)
# Species absent from the Holocene record of both parks.
holocene_absent_species = means |> filter(period_type != 'Anthropocene') |> group_by(species) |>
  summarise(any_present = any(present)) |> filter(!any_present) |> pull(species) |> as.character()
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
      # contrib_lag is the species' part of the lag rate: negative narrows the lag.
      side == 'negative' ~ '\u2190 narrowing',
      TRUE ~ 'widening \u2192'))
figure = ggplot(drawn, aes(estimate, y)) +
  geom_rect(data = bands, aes(xmin = -Inf, xmax = Inf, ymin = species_index - .5, ymax = species_index + .5),
    inherit.aes = FALSE, fill = 'grey95') +
  geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed') +
  geom_errorbar(data = filter(drawn, !spans_zero), aes(xmin = conf_low, xmax = conf_high, color = site),
    orientation = 'y', width = .2, linewidth = 1, na.rm = TRUE) +
  # Symbols kept small so the intervals stay visible (Bills, 11 Nov 2026).
  geom_point(data = filter(drawn, spans_zero), aes(shape = period_type, fill = site), size = 2.4, color = 'grey45', alpha = .35) +
  geom_point(data = filter(drawn, !spans_zero), aes(shape = period_type, fill = site), size = 3.4, color = 'grey10') +
  # What each side of zero means, written at the top of every panel (Bills).
  # Symmetric x range per park, so both sides have room for their label.
  geom_blank(data = x_extent, aes(x = x, y = 1), inherit.aes = FALSE) +
  geom_label(data = side_labels, aes(x = x, y = -.25, label = label, hjust = hjust), size = 8.6,
    fontface = 'italic', color = 'grey25', fill = 'white', linewidth = 0, label.padding = unit(.1, 'lines'),
    inherit.aes = FALSE) +
  facet_grid(measure_label ~ site, scales = 'free_x') +
  # Extra room above the first species for the side labels. The species names
  # are drawn in their own column (below), so the panels carry no y labels.
  scale_y_reverse(breaks = seq_along(order_species), limits = y_limits, expand = c(0, 0)) +
  scale_shape_manual(values = PERIOD_TYPE_SHAPES[c('Holocene-S', 'Holocene-C', 'Anthropocene')], name = NULL,
    labels = c('Holocene stability periods', 'Holocene climate-change periods', 'Anthropocene')) +
  # No tick labels at the very edges of a panel, where the two parks' labels would meet.
  scale_x_continuous(breaks = function(l) { b = scales::extended_breaks()(l); b[abs(b) < .9 * max(abs(l))] }) +
  scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') + scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    guides(shape = guide_legend(override.aes = list(fill = 'grey60', size = 5))) +
  labs(x = 'Species contribution', y = NULL) +
  theme_paleoaces(base_size = 24) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.text.x = element_text(size = 21),
    legend.position = 'bottom', legend.text = element_text(size = 22),
    panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
    strip.text.x = element_text(size = 26, face = 'bold'), strip.text.y = element_blank(),
    strip.background.y = element_blank(),
    # Room between the parks, so their end tick labels do not collide.
    panel.spacing.x = unit(2.2, 'lines'))
# The species names in their own column, aligned with the panel rows: coloured
# by the maximum elevation of the plots where the species occurs, and in bold
# where the species is absent from the Holocene
# record of both parks (Bills, 11 Nov 2026). The row titles sit on its left.
# The names are coloured in greyscale by that maximum.
names = species_elevation |> mutate(y = match(species, order_species),
    holocene_absent = species %in% holocene_absent_species,
    # The elevation is shown by the shade only, not written (Bills, 11 Nov 2026).
    label = species) |>
  expand_grid(measure_label = factor(levels(means$measure_label), levels = levels(means$measure_label))) |>
  mutate(column = ' ')
name_column = ggplot(names, aes(x = 1, y = y)) +
  geom_rect(data = bands, aes(xmin = -Inf, xmax = Inf, ymin = species_index - .5, ymax = species_index + .5),
    inherit.aes = FALSE, fill = 'grey95') +
  geom_text(aes(label = label, color = max_elevation, fontface = if_else(holocene_absent, 'bold.italic', 'italic')),
    hjust = 1, size = 8) +
  facet_grid(measure_label ~ column, switch = 'y') +
  scale_y_reverse(limits = y_limits, expand = c(0, 0)) +
  scale_x_continuous(limits = c(0, 1.02), expand = c(0, 0)) +
  # Greyscale in four clear steps (Bills, 11 Nov 2026): a continuous ramp made
  # neighbouring species hard to tell apart. Lightest below 1,500 m, black above 1,900 m.
  scale_color_steps(low = 'grey68', high = 'black', breaks = c(1500, 1700, 1900), limits = c(1300, 2100),
    labels = scales::comma, name = 'Maximum elevation (m)',
    guide = guide_coloursteps(even.steps = TRUE, show.limits = TRUE, barwidth = unit(11, 'cm'),
      barheight = unit(.7, 'cm'), title.position = 'top')) +
  theme_paleoaces(base_size = 24) +
  theme(axis.text = element_blank(), axis.ticks = element_blank(), axis.title = element_blank(),
    panel.border = element_blank(), panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
    panel.background = element_blank(),
    strip.placement = 'outside', strip.text.y.left = element_text(angle = 90, size = 22, face = 'bold'),
    strip.text.x = element_text(size = 26, face = 'bold'), strip.background.x = element_blank(),
    legend.position = 'bottom', legend.title = element_text(size = 22), legend.text = element_text(size = 19))
# The name column only as wide as the longest name, so the row titles sit close to the names.
figure = (name_column | figure) + plot_layout(widths = c(.3, 1), guides = 'collect') &
  theme(legend.position = 'bottom')
if (render_figures) {
  # cairo_pdf draws the arrows of the side labels.
  ggsave(fig('main', 'fig_species_contributions.pdf'), figure, width = 20, height = 20, device = cairo_pdf)
  ggsave(fig('main', 'fig_species_contributions.png'), figure, width = 20, height = 20, dpi = 300)
}
write_csv(species_elevation |> mutate(holocene_absent = species %in% holocene_absent_species) |>
    arrange(match(species, order_species)) |> mutate(rank = row_number(), .before = 1),
  out('figures/species_order_elevation.csv'))
cat('Figure 7: species contributions drawn.\n')
