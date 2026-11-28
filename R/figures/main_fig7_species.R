# Figure 7 (PLAN.md section 6): species contributions in the Anthropocene, and
# Fig. S19 with the Holocene ones. Species as rows ordered by the maximum
# elevation of the plots where they occur, the highest at the top (Bills). One
# column per park, with its own x scale. Only contrib_climate is drawn (Bills,
# 24 Nov 2026): how far the species moved the community in the climate-predicted
# direction, negative where it moved it against that direction. From 23 to 24
# Nov 2026 only contrib_lag was drawn, and before that both. The contrib_lag row
# stays in the code and is drawn again by adding it to SHOWN_MEASURES. Per
# species a square (Holocene-S), a diamond (Holocene-C) and a circle
# (Anthropocene), each with its 95% t-interval; means whose interval includes
# zero are small and faded, with faded intervals. Figure 7 holds the circles
# only since 28 Nov 2026 (Bills): the Holocene means are all close to zero, and
# they moved to Fig. S19A, next to the means not divided by time (Fig. S19B), so
# no appendix figure is renumbered.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
source(here('R/helpers/cca_display_rotation.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

# Species order (Bills, 11 Nov 2026; by the mean until then): the maximum
# elevation of the plots where each species occurs, over the 605 paired plots,
# both surveys and both parks; the highest at the top, ties by the mean.
source(here('R/helpers/tracking_predictor_models.R'), local = TRUE)
plots = read_csv(out('cca_tracking_anthropocene_plot_calculations.csv'), show_col_types = FALSE) |>
  distinct(site, plot_id) |> mutate(plot_id = toupper(plot_id))
# 605 Anthropocene pairs (328 MORA, 277 NOCA; the two burned MORA plots left out, Bills 11 Nov 2026).
stopifnot(nrow(plots) == 605, sum(plots$site == 'MORA') == 328, sum(plots$site == 'NOCA') == 277)
cca_species = read_csv(out('cca_species_contributions.csv'), show_col_types = FALSE)$species
occurrences = read_csv(out('occ_consolidated.csv'), show_col_types = FALSE) |>
  filter(era == 'anthropocene', occurrence > 0, species %in% cca_species) |>
  mutate(plot_id = toupper(plot_id))
mora_env = new.env(); load(here('data/MORA_plots.rda'), envir = mora_env)
elevations = tracking_modern_elevations(mora_env$plot_info,
  read_csv(here('data/NOCA/NOCA_plots_fromWilson.csv'), show_col_types = FALSE), plots)
species_elevation = occurrences |>
  inner_join(elevations |> transmute(site, plot_id = toupper(plot_id), elevation), by = c('site', 'plot_id')) |>
  group_by(species) |> summarise(max_elevation = max(elevation), mean_elevation = mean(elevation),
    occurrences = n(), .groups = 'drop')
order_species = species_elevation |> arrange(desc(max_elevation), desc(mean_elevation)) |> pull(species)

# Plots each species was lost from and gained in between the legacy survey and
# the resurvey, over the 605 plot pairs. In Figure 7 the names are coloured by
# the total gain or loss of their park (Bills, 28 Nov 2026): the plots occupied
# at the resurvey minus those occupied at the legacy survey, which is the plots
# gained minus the plots lost.
net_change = occurrences |> semi_join(plots, by = c('site', 'plot_id')) |>
  distinct(site, plot_id, species, period) |> mutate(found = TRUE) |>
  pivot_wider(names_from = period, values_from = found, values_fill = FALSE) |>
  group_by(site, species) |>
  summarise(legacy_plots = sum(past), resurvey_plots = sum(present), lost = sum(past & !present),
    gained = sum(present & !past), .groups = 'drop') |>
  mutate(net_change = gained - lost)
# The net change is the change in the number of plots occupied.
stopifnot(with(net_change, all(net_change == resurvey_plots - legacy_plots)))

# The four elevation steps of the species names in Fig. S19, from below 1,500 m to above 1,900 m.
ELEVATION_REDS = c('#FC9272', '#EF3B2C', '#A50F15', '#67000D')
# The five net-change steps of the species names in Figure 7: purple where a
# species was lost from more plots than it was gained in, green where the
# opposite, grey within 5 plots of no change. Purple and green stay clear of the
# park blue and red, and all five steps are dark enough to read as text.
NET_CHANGE_BREAKS = c(-20, -5, 5, 20)
NET_CHANGE_LIMITS = c(-40, 40)
NET_CHANGE_COLOURS = c('#4D1B66', '#9467B0', '#8A8A8A', '#4E9A57', '#1B5E20')
stopifnot(max(abs(net_change$net_change)) < max(NET_CHANGE_LIMITS))

SHOWN_MEASURES = c('contrib_climate')
PERIOD_TYPES = c('Holocene-S', 'Holocene-C', 'Anthropocene')
PERIOD_TYPE_LABELS = c('Holocene stability periods', 'Holocene climate-change periods', 'Anthropocene')
read_species_means = function(file) {
  read_csv(out(file.path('species_contribution_models', file)), show_col_types = FALSE) |>
    mutate(species = factor(species, levels = order_species),
      period_type = factor(period_type, levels = PERIOD_TYPES),
      spans_zero = !interval_defined | (conf_low <= 0 & conf_high >= 0),
      measure_label = factor(c(contrib_climate = 'Following climate-predicted direction',
        contrib_lag = 'Changing the climate-community lag')[measure],
        levels = c('Following climate-predicted direction',
          'Changing the climate-community lag'))) |>
    filter(measure %in% SHOWN_MEASURES) |> mutate(measure_label = droplevels(measure_label))
}
bands = tibble(species_index = seq(1, length(order_species), by = 2))

# The panels of one table of species means (per century or not divided by time)
# for the period types asked for, one column per park. shape_key = FALSE leaves
# out the key of the period types, which a single period type does not need and
# which Fig. S19 draws once, under its part B.
species_panels = function(means, x_label, period_types, shape_key = length(intersect(PERIOD_TYPES, period_types)) > 1) {
  means = means |> filter(period_type %in% period_types)
  # Species absent from a park's Holocene record (no share at either end of any
  # lake-period) are not drawn as Holocene symbols, and a species absent from a
  # park's plot pairs not as an Anthropocene symbol.
  absent = means |> filter(period_type != 'Anthropocene') |> group_by(measure_label, species, site) |>
    summarise(absent = !any(present), .groups = 'drop') |> filter(absent)
  drawn = means |> anti_join(absent |> mutate(period_type = list(c('Holocene-S', 'Holocene-C'))) |> unnest(period_type) |>
    mutate(period_type = factor(period_type, levels = PERIOD_TYPES)), by = c('measure_label', 'species', 'site', 'period_type')) |>
    filter(!(period_type == 'Anthropocene' & !present))
  # The symbols of one species side by side within its row, in the order of PERIOD_TYPES.
  shown = intersect(PERIOD_TYPES, period_types)
  nudge = setNames(if (length(shown) == 1) 0 else seq(.22, -.22, length.out = length(shown)), shown)
  drawn = drawn |> mutate(y = as.integer(species) + nudge[as.character(period_type)])
  x_extent = drawn |> group_by(site) |> summarise(m = max(abs(c(estimate, conf_low, conf_high)), na.rm = TRUE)) |>
    reframe(site = rep(site, 2), x = c(-m, m)) |>
    expand_grid(measure_label = factor(levels(means$measure_label), levels = levels(means$measure_label)))
  side_labels = expand_grid(measure_label = factor(levels(means$measure_label), levels = levels(means$measure_label)),
    site = c('MORA', 'NOCA'), side = c('negative', 'positive')) |>
    # Each label starts at the zero line and runs away from it, so it never crosses it.
    mutate(x = 0, hjust = if_else(side == 'negative', 1.04, -.04),
      label = case_when(
        # The labels continue the row title (Bills).
        measure_label == 'Following climate-predicted direction' & side == 'negative' ~ '← against',
        measure_label == 'Following climate-predicted direction' ~ 'following →',
        # contrib_lag is the species' part of the lag rate: negative narrows the lag.
        side == 'negative' ~ '← narrowing',
        TRUE ~ 'widening →'))
  ggplot(drawn, aes(estimate, y)) +
    geom_rect(data = bands, aes(xmin = -Inf, xmax = Inf, ymin = species_index - .5, ymax = species_index + .5),
      inherit.aes = FALSE, fill = 'grey95') +
    geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed') +
    geom_errorbar(data = filter(drawn, spans_zero, interval_defined), aes(xmin = conf_low, xmax = conf_high, color = site),
      orientation = 'y', width = .2, linewidth = .7, alpha = .4, na.rm = TRUE) +
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
    # Extra room above the first species for the side labels (y = -0.25). The
    # species names are drawn in their own columns, so the panels carry no y labels.
    scale_y_reverse(breaks = seq_along(order_species), limits = Y_LIMITS, expand = c(0, 0)) +
    scale_shape_manual(values = PERIOD_TYPE_SHAPES[PERIOD_TYPES], limits = PERIOD_TYPES, labels = PERIOD_TYPE_LABELS,
      name = NULL) +
    # No tick labels at the very edges of a panel, where the two parks' labels would meet.
    scale_x_continuous(breaks = function(l) { b = scales::extended_breaks()(l); b[abs(b) < .9 * max(abs(l))] }) +
    scale_fill_manual(values = PAPER_SITE_COLORS, guide = 'none') + scale_color_manual(values = PAPER_SITE_COLORS, guide = 'none') +
    guides(shape = if (!shape_key) 'none' else guide_legend(override.aes = list(fill = 'grey60', size = 5))) +
    labs(x = x_label, y = NULL) +
    theme_paleoaces(base_size = 24) +
    theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.text.x = element_text(size = 21),
      legend.position = 'bottom', legend.text = element_text(size = 22),
      panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
      strip.text.x = element_text(size = 26, face = 'bold'), strip.text.y = element_blank(),
      strip.background.y = element_blank(),
      # Room between the parks, so their end tick labels do not collide.
      panel.spacing.x = unit(2.2, 'lines'))
}
# One y range for the panels and the species-name columns, so their rows line up:
# room above the first species for the side labels.
Y_LIMITS = c(length(order_species) + .6, -1.75)

# A column of species names aligned with the panel rows. side = 'left' puts the
# names flush against the panel on their right, 'right' against the panel on
# their left. A blank strip on top keeps the rows level with the panels.
name_column = function(names, colour_scale, side = 'left') {
  ggplot(names |> mutate(y = match(species, order_species), column = ' '), aes(x = if (side == 'left') 1 else 0, y = y)) +
    geom_rect(data = bands, aes(xmin = -Inf, xmax = Inf, ymin = species_index - .5, ymax = species_index + .5),
      inherit.aes = FALSE, fill = 'grey95') +
    geom_text(aes(label = species, color = colour), fontface = 'italic', hjust = if (side == 'left') 1 else 0, size = 8) +
    facet_grid(. ~ column) +
    scale_y_reverse(limits = Y_LIMITS, expand = c(0, 0)) +
    scale_x_continuous(limits = if (side == 'left') c(0, 1.02) else c(-.02, 1), expand = c(0, 0)) +
    colour_scale +
    theme_paleoaces(base_size = 24) +
    theme(axis.text = element_blank(), axis.ticks = element_blank(), axis.title = element_blank(),
      panel.border = element_blank(), panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
      panel.background = element_blank(),
      strip.text.x = element_text(size = 26, face = 'bold'), strip.background.x = element_blank(),
      legend.position = 'bottom', legend.title = element_text(size = 22), legend.text = element_text(size = 19))
}
signed_label = function(x) sub('^-', '−', scales::comma(x))
# Four clear steps (Bills, 11 Nov 2026): a continuous ramp made neighbouring
# species hard to tell apart. Reds since 27 Nov 2026 (Bills; grey until then),
# a crimson ramp kept away from the orange-red of NOCA, lightest below 1,500 m and
# darkest above 1,900 m. Each colour sits at the middle of its 200 m bin, so
# every step shows exactly its colour.
elevation_scale = scale_color_stepsn(colours = ELEVATION_REDS, values = c(.125, .375, .625, .875),
  breaks = c(1500, 1700, 1900), limits = c(1300, 2100),
  labels = scales::comma, name = 'Maximum elevation (m)',
  guide = guide_coloursteps(even.steps = TRUE, show.limits = TRUE, barwidth = unit(11, 'cm'),
    barheight = unit(.7, 'cm'), title.position = 'top'))
# Each colour at the middle of its bin on the scale from -40 to 40 plots.
net_change_scale = scale_color_stepsn(colours = NET_CHANGE_COLOURS,
  values = scales::rescale(c(-30, -12.5, 0, 12.5, 30), from = NET_CHANGE_LIMITS),
  breaks = NET_CHANGE_BREAKS, limits = NET_CHANGE_LIMITS, labels = signed_label,
  name = 'Total gain or loss (plots)', oob = scales::squish,
  guide = guide_coloursteps(even.steps = TRUE, show.limits = FALSE, barwidth = unit(13, 'cm'),
    barheight = unit(.7, 'cm'), title.position = 'top'))

per_century = read_species_means('species_means.csv')
total = read_species_means('species_means_total.csv')
# Species absent from the Holocene record of both parks (kept in the species-order table).
holocene_absent_species = per_century |> filter(period_type != 'Anthropocene') |> group_by(species) |>
  summarise(any_present = any(present)) |> filter(!any_present) |> pull(species) |> as.character()

# Figure 7: the Anthropocene circles, the MORA names on the left, the NOCA names
# on the right, each coloured by the net change of its park (Bills, 28 Nov 2026).
figure_7 = (name_column(net_change |> filter(site == 'MORA') |> mutate(colour = net_change), net_change_scale, 'left') |
    species_panels(per_century, 'Species contribution in the climate-predicted direction', 'Anthropocene') |
    name_column(net_change |> filter(site == 'NOCA') |> mutate(colour = net_change), net_change_scale, 'right')) +
  plot_layout(widths = c(.3, 1, .3), guides = 'collect') & theme(legend.position = 'bottom')

# Fig. S19: (A) the Holocene means per century, the part of Figure 7 until
# 28 Nov 2026, and (B) the means of all period types not divided by time. The
# names stay coloured by the maximum elevation, which sets their order.
elevation_names = species_elevation |> mutate(colour = max_elevation)
s19_part = function(means, x_label, period_types, tag, shape_key)
  (name_column(elevation_names, elevation_scale, 'left') + labs(tag = tag) |
    species_panels(means, x_label, period_types, shape_key)) + plot_layout(widths = c(.3, 1))
figure_s19 = (s19_part(per_century, 'Species contribution in the climate-predicted direction per century',
    c('Holocene-S', 'Holocene-C'), 'A', shape_key = FALSE) /
  s19_part(total, 'Species contribution in the climate-predicted direction, not divided by time', PERIOD_TYPES, 'B',
    shape_key = TRUE)) +
  plot_layout(guides = 'collect') & theme(legend.position = 'bottom', plot.tag = element_text(size = 30, face = 'bold'))

FIG7_HEIGHT = 10
FIGS19_HEIGHT = 21
if (render_figures) {
  # cairo_pdf draws the arrows of the side labels.
  ggsave(fig('main', 'fig_species_contributions.pdf'), figure_7, width = 20, height = FIG7_HEIGHT, device = cairo_pdf)
  ggsave(fig('main', 'fig_species_contributions.png'), figure_7, width = 20, height = FIG7_HEIGHT, dpi = 300)
  ggsave(fig('supplementary', 'figS19_species_contributions_total.pdf'), figure_s19, width = 20, height = FIGS19_HEIGHT,
    device = cairo_pdf)
}
write_csv(species_elevation |> mutate(holocene_absent = species %in% holocene_absent_species) |>
    arrange(match(species, order_species)) |> mutate(rank = row_number(), .before = 1),
  out('figures/species_order_elevation.csv'))
write_csv(net_change |> arrange(site, match(species, order_species)), out('figures/species_net_change.csv'))
cat('Figure 7 (Anthropocene) and Fig. S19 (Holocene per century, all period types not divided by time) drawn.\n')
