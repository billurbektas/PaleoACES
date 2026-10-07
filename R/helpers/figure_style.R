PAPER_SITE_COLORS = c(MORA = "#648FFF", NOCA = "#FE6100")

# Shared publication styling for the four main PaleoACES figures.

PAPER_BASE_SIZE = 13
PAPER_AXIS_TITLE_SIZE = 14
PAPER_PANEL_TAG_SIZE = 15
PAPER_LEGEND_TEXT_SIZE = 12
PAPER_LEGEND_TITLE_SIZE = 13

PAPER_FIRE_RED = "#9D2946"
PAPER_NO_FIRE = "grey35"
PAPER_SITE_SHAPES = c(MORA = 21, NOCA = 24)
PAPER_SIGNED_COLORS = c(low = "#3B78A8", mid = "#F5F1E6",
                        high = "#C75B47")

theme_paleoaces = function(base_size = PAPER_BASE_SIZE) {
  ggplot2::theme_bw(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = "grey90", linewidth = .35),
      axis.title = ggplot2::element_text(size = PAPER_AXIS_TITLE_SIZE),
      axis.text = ggplot2::element_text(size = base_size - 1),
      strip.background = ggplot2::element_rect(fill = "grey95", color = "grey65"),
      strip.text = ggplot2::element_text(face = "bold", size = base_size),
      plot.tag = ggplot2::element_text(face = "bold", size = PAPER_PANEL_TAG_SIZE),
      plot.tag.position = "topleft",
      legend.title = ggplot2::element_text(size = PAPER_LEGEND_TITLE_SIZE),
      legend.text = ggplot2::element_text(size = PAPER_LEGEND_TEXT_SIZE),
      legend.key.height = grid::unit(.55, "cm"),
      legend.spacing.x = grid::unit(.25, "cm"),
      plot.margin = ggplot2::margin(7, 7, 7, 7)
    )
}

