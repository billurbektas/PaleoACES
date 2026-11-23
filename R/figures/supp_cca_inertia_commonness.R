# Fig. S15 (Bills, 23 Nov 2026): each taxon's share of the constrained inertia
# of the CCA against its commonness, the share of the legacy plots in which it
# occurs. Figure 4A draws the species above half an equal share of the inertia
# and shades them by commonness, so this shows whether the two say the same.
# Also written: the correlations and the linear fit quoted in the caption.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(ggrepel)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

x = read_csv(out('cca_species_contributions.csv'), show_col_types = FALSE) |>
  transmute(species, commonness = prevalence_percent, inertia = percent_constrained_inertia)
pearson = cor.test(x$commonness, x$inertia)
spearman = cor.test(x$commonness, x$inertia, method = 'spearman', exact = FALSE)
fit = lm(inertia ~ commonness, x)
stats = tibble(taxa = nrow(x), pearson_r = unname(pearson$estimate), pearson_p = pearson$p.value,
  spearman_rho = unname(spearman$estimate), spearman_p = spearman$p.value,
  intercept = coef(fit)[[1]], slope = coef(fit)[[2]], slope_p = summary(fit)$coefficients[2, 4],
  r_squared = summary(fit)$r.squared, equal_share = 100 / nrow(x),
  above_one_to_one = paste(x$species[x$inertia > x$commonness], collapse = '; '))
write_csv(stats, out('figures/cca_inertia_commonness.csv'))

top = max(c(x$commonness, x$inertia)) * 1.05
# Empty labels along the 1:1 and fitted lines keep the species names off them.
grid = seq(0, top, length.out = 60)
anchors = bind_rows(tibble(commonness = grid, inertia = grid),
  tibble(commonness = grid, inertia = predict(fit, tibble(commonness = grid)))) |>
  filter(inertia >= 0, inertia <= top) |> mutate(species = '')
figure = ggplot(x, aes(commonness, inertia)) +
  geom_abline(slope = 1, intercept = 0, linetype = 'dashed', color = 'grey50') +
  geom_hline(yintercept = c(100, 50) / nrow(x), color = 'grey70', linetype = 'dotted') +
  geom_smooth(method = 'lm', formula = y ~ x, color = 'black', fill = 'grey85', linewidth = .8) +
  geom_point(size = 3) +
  geom_text_repel(data = bind_rows(x, anchors), aes(label = species), fontface = 'italic', size = 4.2, seed = 1,
    max.overlaps = Inf, box.padding = .3, segment.color = 'grey60', segment.size = .3) +
  annotate('text', x = top * .03, y = top * .97, hjust = 0, vjust = 1, size = 4.6,
    label = sprintf('Pearson r = %.2f (p = %.2f)\nSpearman rho = %.2f (p = %.2f)\nSlope = %.3f, R² = %.2f',
      stats$pearson_r, stats$pearson_p, stats$spearman_rho, stats$spearman_p, stats$slope, stats$r_squared)) +
  coord_equal(xlim = c(0, top), ylim = c(0, top), expand = FALSE) +
  labs(x = 'Legacy plots where the species occurs (%)', y = 'Share of the constrained inertia (%)') +
  theme_paleoaces(base_size = 15) + theme(panel.grid.minor = element_blank())
if (render_figures) ggsave(fig('supplementary', 'figS15_cca_inertia_commonness.pdf'), figure, width = 8.5, height = 8.5,
  device = cairo_pdf)
cat(sprintf('Fig. S15: inertia share against commonness of %d taxa, Pearson r = %.2f.\n', stats$taxa, stats$pearson_r))
