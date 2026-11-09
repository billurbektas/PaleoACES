# Figure conventions (PLAN.md section 6, Bills 9 Nov 2026). Where observed and
# predicted are not distinguished, a park takes its observed colour.
PARK_COLORS = c(MORA_observed = "#294EFF", MORA_predicted = "#97A9FF",
  NOCA_observed = "#D94000", NOCA_predicted = "#FF9163")
PAPER_SITE_COLORS = c(MORA = "#294EFF", NOCA = "#D94000")
# Holocene-C circle, Holocene-S triangle, Anthropocene diamond (filled shapes).
PERIOD_TYPE_SHAPES = c(`Holocene-C` = 21, `Holocene-S` = 24, Anthropocene = 23)
RESPONSE_AXIS_LABELS = c(climate_rate = "Standardized climate change rate per century",
  turnover_rate = "Turnover rate (CCA distance per century)",
  lag_rate = "Lag rate (CCA distance per century)",
  pace_effect = "Pace effect (CCA distance per century)",
  direction_effect = "Direction effect (CCA distance per century)",
  fire_activity = "Fire activity (events per century per covered core)")

# Shared publication styling for the four main PaleoACES figures.

PAPER_BASE_SIZE = 16
PAPER_AXIS_TITLE_SIZE = 14
PAPER_PANEL_TAG_SIZE = 15
PAPER_LEGEND_TEXT_SIZE = 12
PAPER_LEGEND_TITLE_SIZE = 13

PAPER_FIRE_RED = "#9D2946"
PAPER_NO_FIRE = "grey35"
PAPER_SITE_SHAPES = c(MORA = 21, NOCA = 24)
PAPER_SIGNED_COLORS = c(low = "#3B78A8", mid = "#F5F1E6",
                        high = "#C75B47")

# Axis titles break before the unit in brackets, so the unit is never split.
two_line_title = function(x, width = 34) ifelse(grepl(' [(]', x), sub(' [(]', '\n(', x), stringr::str_wrap(x, width))

theme_paleoaces = function(base_size = PAPER_BASE_SIZE) {
  ggplot2::theme_bw(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = "grey90", linewidth = .35),
      # Every text element scales with base_size, so one setting enlarges a figure.
      axis.title = ggplot2::element_text(size = base_size + 1),
      axis.text = ggplot2::element_text(size = base_size - 1),
      strip.background = ggplot2::element_rect(fill = "grey95", color = "grey65"),
      strip.text = ggplot2::element_text(face = "bold", size = base_size),
      plot.tag = ggplot2::element_text(face = "bold", size = base_size + 3),
      plot.tag.position = "topleft",
      legend.title = ggplot2::element_text(size = base_size),
      legend.text = ggplot2::element_text(size = base_size - 1),
      legend.key.height = grid::unit(.55, "cm"),
      legend.spacing.x = grid::unit(.25, "cm"),
      plot.margin = ggplot2::margin(7, 7, 7, 7)
    )
}

