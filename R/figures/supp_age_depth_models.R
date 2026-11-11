# Figures S5 (four Bacon age-depth models) and S6 (Panther Potholes 210Pb
# sensitivity), redrawn from the stored runs in Cores/ without re-running MCMC.
source(here::here('R/helpers/config.R'), local = TRUE)
suppressPackageStartupMessages({library(here); library(rbacon); library(tidyverse)})
source(here('R/helpers/bacon_settings.R'), local = TRUE)
coredir <- file.path(here(), "Cores")

# =============================================================================
# 5) FIGURES - redraw the stored models
# =============================================================================
# Nothing here re-runs an MCMC. Each panel is redrawn from the .out on disk using
# the SAME settings the model was run with, taken from CORE_ARGS above so the two
# cannot diverge.
#
# TWO TRAPS, both hit in practice:
#  1. Bacon(run = FALSE) rebuilds `info` but does NOT read the iterations back, so
#     agedepth() would draw the PRIORS only (green curves, no grey posterior).
#     They must be loaded with rbacon:::Bacon.AnaOut.
#  2. Bacon(run = FALSE) can THIN the stored .out to its own ssize - drawing a
#     figure would silently destroy iterations. The .out is snapshotted and
#     restored, so redrawing can never damage a run.
library(magick); library(ggplot2); library(patchwork)

render_panel = function(core, outdir) {
  out = Sys.glob(file.path(coredir, core, paste0(core, "_*.out")))
  if (!length(out)) return(NA_character_)
  bak = file.path(tempdir(), paste0("bak_", basename(out)))
  file.copy(out, bak, overwrite = TRUE)
  on.exit(file.copy(bak, out, overwrite = TRUE), add = TRUE)

  do.call(Bacon, c(list(core = core, coredir = coredir, run = FALSE,
                        suggest = FALSE, ask = FALSE, remember = FALSE,
                        plot.pdf = FALSE, verbose = FALSE), CORE_ARGS[[core]]))
  set = get("info", envir = .GlobalEnv)
  set = rbacon:::Bacon.AnaOut(
          file.path(set$coredir, core, paste0(core, "_", set$K, ".out")), set)
  assign("info", set, envir = .GlobalEnv)
  f = file.path(outdir, paste0(core, ".png"))
  # Larger text remains readable when the four panels are shown together.
  png(f, width = 1500, height = 1750, res = 190)
  par(cex.lab = 1.6)
  agedepth(set = set, BCAD = FALSE,
           mainpanel.tickfontsize = 1.8, mainpanel.labelfontsize = 2,
           toppanel.fontsize = 1.5, prior.fontsize = 1.6, title.size = 2.6,
           mar.main = c(4.8, 5, 1, 1), mar.left = c(4.5, 5, 1, 0.8),
           mar.middle = c(4.5, 1.1, 1, 1.8), mar.right = c(4.5, 1.8, 1, 1.1),
           mgp = c(2.8, 0.9, 0))
  dev.off()
  cat("rendered", core, " (K =", set$K, ",", nrow(set$output), "iterations)\n")
  f
}

tmpdir = file.path(tempdir(), "bacon_panels"); dir.create(tmpdir, showWarnings = FALSE)
panels = na.omit(vapply(c("JayBath","LogWallow","ReflectionPond","PantherPotholes"),
                        render_panel, character(1), outdir = tmpdir))

# compose 2 x 2
pp   = image_border(image_read(panels), color = "grey80", geometry = "6x6")
rows = split(seq_along(panels), ceiling(seq_along(panels)/2))
composite  = image_border(image_append(image_join(lapply(rows, function(i) image_append(pp[i]))),
                                 stack = TRUE), color = "white", geometry = "20x20")
image_write(composite, fig("supplementary", "figS05_age_depth_models.pdf"),
            format = "pdf")
cat("\nWritten report/figures/supplementary/figS05_age_depth_models.pdf\n")

# -----------------------------------------------------------------------------
# 210Pb sensitivity. NOT two agedepth() panels side by side: the difference is
# ~28 yr inside the top 35 cm of an 870 cm core, invisible on a 10,600 yr axis.
# Two panels instead - whole core (effect does NOT propagate) and a top-40 cm zoom.
# -----------------------------------------------------------------------------
if (dir.exists(file.path(coredir, "PantherPotholes_pb210err"))) {
  lab_pub = "published: DPM/g activity errors (0.7-3.5 yr)"
  lab_var = "assumed: flat +-10 yr age error"
  rd = function(core) {
    f = Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))[1]
    setNames(read.table(f, header = TRUE), c("depth","lo","hi","median","mean"))
  }
  env = bind_rows(rd("PantherPotholes")          %>% mutate(run = lab_pub),
                  rd("PantherPotholes_pb210err") %>% mutate(run = lab_var)) %>%
        mutate(run = factor(run, levels = c(lab_var, lab_pub)))   # level order = DRAW order
  pb = tibble(depth = c(7,14,21,28,35), age = c(-36.7,-9,12,21,36),
              e_pub = c(3.47,1.15,0.72,0.74,0.77), e_age = rep(PB210_ASSUMED_ERROR, 5))
  cols = setNames(c("#d1670a","#1b6ca8"), c(lab_var, lab_pub))
  base = function(d) ggplot(d, aes(depth)) +
    geom_ribbon(aes(ymin = lo, ymax = hi, fill = run), alpha = .45) +
    geom_line(aes(y = median, colour = run), linewidth = .45) +
    scale_fill_manual(values = cols, name = NULL, breaks = c(lab_pub, lab_var)) +
    scale_colour_manual(values = cols, name = NULL, breaks = c(lab_pub, lab_var)) +
    labs(x = "Depth (cm)", y = "cal yr BP") + theme_bw(base_size = 10) +
    theme(panel.grid.minor = element_blank(), plot.subtitle = element_text(size = 8.5))
  w = env %>% filter(depth <= 35) %>% group_by(run) %>% summarise(w = median(hi - lo))
  sens = (base(env) +
      annotate("rect", xmin = 0, xmax = 35, ymin = -Inf, ymax = Inf,
               fill = NA, colour = "grey35", linewidth = .3, linetype = "22") +
      labs(subtitle = "Whole core: similar below 35 cm")) +
    (base(env %>% filter(depth <= 40)) +
      geom_linerange(data = pb, inherit.aes = FALSE,
        aes(x = depth - .45, ymin = age - e_pub, ymax = age + e_pub),
        colour = cols[[lab_pub]], linewidth = 1.1) +
      geom_linerange(data = pb, inherit.aes = FALSE,
        aes(x = depth + .45, ymin = age - e_age, ymax = age + e_age),
        colour = cols[[lab_var]], linewidth = 1.1) +
      geom_point(data = pb, inherit.aes = FALSE, aes(depth, age), size = 1.2, colour = "grey15") +
      labs(subtitle = sprintf("Top 40 cm: 95%% width %g -> %g yr. Bars = error given to each control",
                              round(w$w[w$run == lab_pub]), round(w$w[w$run == lab_var])))) +
    plot_layout(guides = "collect") & theme(legend.position = "top")
  ggsave(fig("supplementary", "figS06_panther_potholes_pb210_sensitivity.pdf"), sens, width = 9.5, height = 4.2, device = cairo_pdf)
  cat("Written report/figures/supplementary/figS06_panther_potholes_pb210_sensitivity.pdf\n")
}
