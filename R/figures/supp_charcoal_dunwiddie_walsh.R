# Appendix figure A4 (Bills, 11 Nov 2026): do the charcoal peaks of the Walsh
# et al. (2017) Sunrise Ridge cores, the source of the MORA fire values, line up
# with the charcoal in the Dunwiddie cores of the MORA vegetation lakes? A
# descriptive comparison: the Walsh charcoal accumulation rates with their tapas
# fire events, and the Dunwiddie charcoal fragments per sample (a concentration,
# equal sample volume within a core), on one time axis from 7,000 cal BP. Every
# Walsh event is carried as a faint line through all rows. The figure script
# also writes the numbers quoted with the figure: Spearman correlations of
# 500-year bin means, tested against circular shifts of the Walsh series (which
# keep each record's autocorrelation), and the share of Walsh events with a
# Dunwiddie peak within 200 years against the share expected by chance.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(tidyverse)})
source(here('R/helpers/figure_style.R'), local = TRUE)
render_figures = isTRUE(getOption('paleoaces.render_figures', TRUE))

TOP = 7000; BIN = 500; WINDOW = 200
EVENT_COLOR = '#8B1A1A'  # not a park colour: Walsh's cores are MORA too
lake_names = c(JayBath = 'Jay Bath', LogWallow = 'Log Wallow', ReflectionPond = 'Reflection Pond')
walsh = read_csv(out('fire_mora_tapas_series.csv'), show_col_types = FALSE) |>
  filter(age_cal_yr_BP >= 0, age_cal_yr_BP <= TOP) |>
  transmute(core = lake, age = age_cal_yr_BP, char = char_interpolated, background = background_char)
events = read_csv(out('fire_mora_tapas_events.csv'), show_col_types = FALSE) |>
  filter(age_cal_yr_BP >= 0, age_cal_yr_BP <= TOP) |> transmute(core = lake, age = age_cal_yr_BP)
# Ages slightly below 0 cal BP (the coring years) sit at the top of the axis.
dunwiddie = read_csv(out('paleo_fire.csv'), show_col_types = FALSE) |>
  filter(lake %in% names(lake_names), year <= TOP) |>
  transmute(lake, age = pmax(year, 0), fragments = charcoal_fragments) |>
  group_by(lake) |> mutate(peak = fragments > quantile(fragments, .75)) |> ungroup()

# Numbers quoted with the figure ------------------------------------------------
bin_mid = function(a) floor(a / BIN) * BIN + BIN / 2
z = function(x) (x - mean(x)) / sd(x)
walsh_bins = walsh |> group_by(core, t = bin_mid(age)) |> summarise(v = mean(char), .groups = 'drop')
walsh_composite = walsh_bins |> group_by(core) |> mutate(v = z(v)) |> group_by(t) |>
  summarise(walsh_char = mean(v), .groups = 'drop') |>
  left_join(events |> count(core, t = bin_mid(age)) |>
    complete(core = unique(walsh$core), t = seq(BIN / 2, TOP - BIN / 2, BIN), fill = list(n = 0)) |>
    group_by(t) |> summarise(walsh_fires = mean(n) * 1000 / BIN), by = 't')
shift_test = function(x, y) {
  n = length(x); rho = cor(x, y, method = 'spearman')
  null = vapply(seq_len(n - 1), function(k) cor(x, y[c((k + 1):n, seq_len(k))], method = 'spearman'), numeric(1))
  # The observed alignment counts as one of the n possible shifts, so the
  # smallest attainable p is 1 / n (0.07 with 14 bins).
  tibble(rho, p_shift = (sum(abs(null) >= abs(rho)) + 1) / n, bins = n)
}
correlations = bind_rows(lapply(names(lake_names), function(L) {
  x = dunwiddie |> filter(lake == L) |> group_by(t = bin_mid(age)) |> summarise(v = mean(fragments), .groups = 'drop') |>
    inner_join(walsh_composite, by = 't') |> arrange(t)
  bind_rows(shift_test(x$v, x$walsh_char) |> mutate(against = 'Walsh charcoal accumulation (mean of three cores)'),
    shift_test(x$v, x$walsh_fires) |> mutate(against = 'Walsh fire frequency (mean of three cores)')) |>
    mutate(record = lake_names[[L]], .before = 1)
}))
cores = unique(walsh$core)
benchmarks = bind_rows(lapply(combn(cores, 2, simplify = FALSE), function(p) {
  x = walsh_bins |> filter(core == p[1]) |> select(t, a = v) |>
    inner_join(walsh_bins |> filter(core == p[2]) |> select(t, b = v), by = 't') |> arrange(t)
  shift_test(x$a, x$b) |> mutate(record = paste(p, collapse = ' and '), against = 'Walsh core against core', .before = 1)
}))
set.seed(42)  # chance level of the event matching by simulation
matching = bind_rows(lapply(names(lake_names), function(L) {
  d = dunwiddie |> filter(lake == L); peaks = d$age[d$peak]
  hit = function(ages) mean(vapply(ages, function(a) any(abs(peaks - a) <= WINDOW), logical(1)))
  span = range(d$age)
  tibble(record = lake_names[[L]], walsh_events = nrow(events), matched = hit(events$age),
    chance = mean(replicate(2000, hit(runif(nrow(events), span[1], span[2])))))
}))
write_csv(bind_rows(correlations, benchmarks), out('figures/charcoal_dunwiddie_walsh_correlations.csv'))
write_csv(matching, out('figures/charcoal_dunwiddie_walsh_event_matching.csv'))

# Figure ---------------------------------------------------------------------------
rows = c(paste0(cores, '\n(Walsh)'), paste0(lake_names, '\n(Dunwiddie)'))
walsh_rows = walsh |> mutate(row = factor(paste0(core, '\n(Walsh)'), rows))
event_rows = events |> mutate(row = factor(paste0(core, '\n(Walsh)'), rows))
dun_rows = dunwiddie |> mutate(row = factor(paste0(lake_names[lake], '\n(Dunwiddie)'), rows))
figure = ggplot() +
  # Every Walsh event, from any core, as a faint line through all rows.
  geom_vline(data = distinct(events, age), aes(xintercept = age), color = EVENT_COLOR, alpha = .25, linewidth = .5) +
  geom_area(data = walsh_rows, aes(age, char), fill = 'grey72', color = 'grey35', linewidth = .3) +
  geom_line(data = walsh_rows, aes(age, background), color = 'black', linewidth = .6, linetype = 'dashed') +
  geom_point(data = event_rows, aes(age, Inf), shape = 25, size = 3.4, fill = EVENT_COLOR, color = EVENT_COLOR) +
  geom_segment(data = dun_rows, aes(x = age, xend = age, y = 0, yend = fragments), color = PAPER_SITE_COLORS[['MORA']],
    linewidth = .7) +
  geom_point(data = dun_rows, aes(age, fragments, fill = peak), shape = 21, size = 2.8, color = PAPER_SITE_COLORS[['MORA']]) +
  scale_fill_manual(values = c(`FALSE` = 'white', `TRUE` = PAPER_SITE_COLORS[['MORA']]), name = NULL,
    labels = c(`FALSE` = 'Dunwiddie sample', `TRUE` = 'Dunwiddie sample above the lake\'s 75th percentile')) +
  facet_grid(row ~ ., scales = 'free_y', switch = 'y') +
  scale_x_reverse(limits = c(TOP, 0), breaks = seq(TOP, 0, -1000), labels = scales::comma, expand = c(.01, 0)) +
  labs(x = 'cal BP', y = NULL) +
  theme_paleoaces(base_size = 17) +
  theme(strip.placement = 'outside', strip.text.y.left = element_text(angle = 0, hjust = 1, size = 15, face = 'bold'),
    panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(), legend.position = 'bottom',
    legend.text = element_text(size = 15))
if (render_figures) {
  ggsave(fig('supplementary', 'fig_charcoal_dunwiddie_walsh.pdf'), figure, width = 16, height = 11, device = cairo_pdf)
  ggsave(fig('supplementary', 'fig_charcoal_dunwiddie_walsh.png'), figure, width = 16, height = 11, dpi = 300)
}
cat('Appendix A4: Dunwiddie and Walsh charcoal drawn.\n')
