# Figure 6: climate and fire associations as model slopes (Bills, 9 Nov 2026).
# A, Holocene lake-periods: response ~ site + climate_rate + fire_activity.
# B, Anthropocene plot pairs: response ~ site + burned. One group per response
# (lag rate, pace effect, direction effect), each term with its conditional 95%
# interval. Estimates whose interval includes zero are faded.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse); library(patchwork)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

dir = 'community_predictor_models'
coefficients = read_csv(out(file.path(dir, 'model_coefficients.csv')), show_col_types = FALSE)
performance = read_csv(out(file.path(dir, 'model_performance.csv')), show_col_types = FALSE)
responses = c(lag_rate = 'Lag rate', pace_effect = 'Pace effect', direction_effect = 'Direction effect')
response_colors = c(lag_rate = '#40AB9D', pace_effect = '#DE85F0', direction_effect = '#8B85F1')
term_labels = c(siteNOCA = 'Site\nNOCA − MORA', climate_rate = 'Climate change rate\n+1 standardized unit per century',
  fire_activity = 'Fire activity\n+1 event per century per core', burnedBurned = 'Fire\nburned − unburned')

panel = function(era_name, terms, tag) {
  d = coefficients |> filter(era == era_name, term %in% terms) |>
    mutate(response = factor(metric, levels = names(responses)), term = factor(term, levels = rev(terms)),
      faded = conf_low <= 0 & conf_high >= 0)
  r2 = performance |> filter(era == era_name) |> arrange(match(response, names(responses)))
  ggplot(d, aes(estimate, term, color = response)) +
    geom_vline(xintercept = 0, color = 'grey55', linetype = 'dashed', linewidth = .6) +
    geom_errorbar(aes(xmin = conf_low, xmax = conf_high, alpha = faded), orientation = 'y', width = .22, linewidth = 1.2) +
    geom_point(aes(alpha = faded), size = 3.6) +
    facet_wrap(~ response, ncol = 1, labeller = as_labeller(responses), strip.position = 'top') +
    scale_y_discrete(labels = term_labels) +
    scale_color_manual(values = response_colors, guide = 'none') +
    scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = .35), guide = 'none') +
    scale_x_continuous(n.breaks = 5, expand = expansion(mult = .08)) +
    labs(tag = tag, title = era_name, x = 'Effect on response\n(CCA distance per century)', y = NULL,
      caption = paste0('Descriptive R²: ', paste(sprintf('%s %.3f', tolower(responses[r2$response]), r2$R2), collapse = ', '), '.')) +
    theme_paleoaces(base_size = 19) +
    theme(plot.title = element_text(size = 24, face = 'bold'), plot.tag = element_text(size = 26, face = 'bold'),
      strip.text = element_text(size = 19, face = 'bold'), axis.text.y = element_text(size = 17, color = 'grey15', lineheight = .9),
      axis.text.x = element_text(size = 17), panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
      plot.caption = element_text(size = 15, hjust = 0), plot.caption.position = 'plot')
}
figure = panel('Holocene', c('siteNOCA', 'climate_rate', 'fire_activity'), 'A.') |
  panel('Anthropocene', c('siteNOCA', 'burnedBurned'), 'B.')
if (render_figures) for (ext in c('pdf', 'png'))
  ggsave(fig('main', paste0('fig_climate_fire_associations.', ext)), figure, width = 20, height = 14, dpi = 300, bg = 'white')
cat('Figure 6: model slopes by response drawn.\n')
