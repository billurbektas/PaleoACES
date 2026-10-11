# =============================================================================
# test_cca_scaling_comparison.R - one CCA drawn at scaling 1 and scaling 2
# =============================================================================
# A diagnostic figure, not a paper figure. Climate constraint arrows and species
# arrows only - no samples - so the effect of the scaling choice on the biplot is
# visible on its own.
#
#   scaling 1 ("sites")   site scores x eigenvalues, species left unscaled.
#                         A SAMPLE sits at the weighted centroid of its SPECIES
#                         (verified exactly: ratio 1.000 on both axes). This is
#                         the scaling used everywhere else in the analysis.
#   scaling 2 ("species") species scores x eigenvalues, sites left unscaled.
#                         A SPECIES sits at the centroid of the SAMPLES holding
#                         it. Species and sites are no longer commensurable -
#                         species would need x3.47 (CCA1) and x7.38 (CCA2) to
#                         land on the sample positions.
#
# Arrows are drawn at their RAW score values, with no display multiplier, so the
# relative lengths of the climate and species blocks are shown as they are.
# Species order and sign along each axis are identical in both panels - only the
# lengths differ.
# =============================================================================

library(here)
if (!exists("extra_exclude")) extra_exclude = character(0)
if (!exists("cca_suffix"))    cca_suffix    = ""
source(here("R/stages/04_cca_model.R"), local = TRUE)
library(ggrepel)
library(patchwork)

imp    = summary(cca_model)$cont$importance[2, ] * 100
ax_lab = paste0(c("CCA1", "CCA2"), " ", round(imp[1:2], 1), "%")

clim_full = CLIMATE_VARIABLE_LABELS[CCA_VARIABLES]

panel_for = function(scaling, subtitle) {
  env_s = as_tibble(scores(cca_model, display = "bp", choices = 1:2,
                           scaling = scaling), rownames = "variable") %>%
    mutate(label = unname(clim_full[variable]))
  sp_s  = as_tibble(scores(cca_model, display = "species", choices = 1:2,
                           scaling = scaling), rownames = "species")

  labs_all = bind_rows(
    env_s %>% transmute(CCA1, CCA2, label, col = "black",  fface = "bold",   sz = 3.0),
    sp_s  %>% transmute(CCA1, CCA2, label = species, col = "grey30", fface = "italic", sz = 2.8)
  )
  lim = max(abs(c(env_s$CCA1, env_s$CCA2, sp_s$CCA1, sp_s$CCA2))) * 1.45

  ggplot() +
    geom_hline(yintercept = 0, color = "grey88", linewidth = 0.3) +
    geom_vline(xintercept = 0, color = "grey88", linewidth = 0.3) +
    geom_segment(data = sp_s, aes(0, 0, xend = CCA1, yend = CCA2),
                 arrow = arrow(length = unit(0.14, "cm")),
                 color = "grey60", linewidth = 0.45) +
    geom_segment(data = env_s, aes(0, 0, xend = CCA1, yend = CCA2),
                 arrow = arrow(length = unit(0.20, "cm")),
                 color = "black", linewidth = 0.9) +
    geom_text_repel(data = labs_all,
                    aes(CCA1, CCA2, label = label, color = col,
                        fontface = fface, size = sz),
                    segment.size = 0.2, segment.color = "grey65",
                    box.padding = 0.45, point.padding = 0.15,
                    force = 10, min.segment.length = 0,
                    max.overlaps = Inf, max.iter = 100000, seed = 5) +
    scale_color_identity() + scale_size_identity() +
    scale_discrete_identity(aesthetics = "fontface") +
    coord_fixed(xlim = c(-lim, lim), ylim = c(-lim, lim)) +
    labs(x = ax_lab[1], y = ax_lab[2],
         title = paste0('scaling = "', scaling, '"  (vegan scaling ',
                        if (scaling == "sites") 1 else 2, ')'),
         subtitle = subtitle) +
    theme_minimal(base_size = 13) +
    theme(plot.title    = element_text(face = "bold"),
          plot.subtitle = element_text(size = 10, color = "grey30", lineheight = 1.1),
          panel.grid.minor = element_blank())
}

p1 = panel_for("sites",
               "site scores x sqrt(eigenvalues); species unscaled\na SAMPLE sits at the weighted centroid of its SPECIES")
p2 = panel_for("species",
               "species scores x sqrt(eigenvalues); sites unscaled\na SPECIES sits at the centroid of the SAMPLES holding it")

fig = p1 + p2 +
  plot_annotation(
    title = "The same CCA under the two scalings",
    caption = paste0(
      "Black = climate constraints, grey = species. Raw scores, no display multiplier, so relative lengths are as computed. ",
      "Axes are drawn to each panel's own range;\nnote the x/y tick values differ. Species order and sign on each axis are preserved; two-axis angles can change with unequal axis scaling ",
      "(species are\nx", round(sqrt(cca_model$CCA$eig[1]), 3), " on CCA1 and x",
      round(sqrt(cca_model$CCA$eig[2]), 3), " on CCA2 in the right panel relative to the left). ",
      "Under scaling 1 the climate arrows shrink by the same factors instead.")) &
  theme(plot.title   = element_text(face = "bold", size = 15),
        plot.caption = element_text(hjust = 0, size = 9, color = "grey30"))

pdf(here(paste0("plot/test_figures/fig_cca_scaling_comparison", cca_suffix, ".pdf")), height = 7.5, width = 14)
print(fig)
dev.off()

cat("\nMax |score| per block and scaling:\n")
for (s in c("sites", "species")) {
  b = scores(cca_model, display = "bp",      choices = 1:2, scaling = s)
  p = scores(cca_model, display = "species", choices = 1:2, scaling = s)
  cat(sprintf("  %-8s climate %.2f / %.2f   species %.2f / %.2f\n", s,
              max(abs(b[,1])), max(abs(b[,2])), max(abs(p[,1])), max(abs(p[,2]))))
}
cat("\nWritten: plot/test_figures/fig_cca_scaling_comparison", cca_suffix,
    ".pdf\n", sep = "")
