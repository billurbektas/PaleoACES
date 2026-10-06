# Geometry gate for the implemented species/climate direction stage.
suppressPackageStartupMessages({library(here); library(tidyverse); library(vegan)})
source(here("R/stages/05_cca_model.R"))

TOL = 1e-8
cosine = function(a, b, tol = TOL) {
  la = sqrt(sum(a^2)); lb = sqrt(sum(b^2))
  if (!is.finite(la) || !is.finite(lb) || la <= tol || lb <= tol)
    return(NA_real_)
  pmin(1, pmax(-1, sum(a * b) / (la * lb)))
}
stopifnot(identical(cca_scaling, "sites"), identical(cca_hill, FALSE))

anth = read_csv(here("output/cca_tracking_anthropocene_plot.csv"),
                show_col_types = FALSE)
row = anth |> filter(!small_observed_movement, !small_predicted_movement) |>
  slice(1)
d_lc = unlist(row[c("delta_predicted_CCA1", "delta_predicted_CCA2")])
d_wa = unlist(row[c("delta_observed_CCA1", "delta_observed_CCA2")])
lc_t1 = unlist(row[c("p1", "p2")])
wa_t1 = unlist(row[c("o1", "o2")])

sp = scores(cca_model, display = "species", choices = 1:2,
            scaling = cca_scaling, hill = cca_hill)
bp = scores(cca_model, display = "bp", choices = 1:2,
            scaling = cca_scaling, hill = cca_hill)
stopifnot(isTRUE(all.equal(unname(sp), unname(species_scores[, 1:2]),
                           tolerance = 1e-12)),
          isTRUE(all.equal(unname(bp), unname(env_scores[, 1:2]),
                           tolerance = 1e-12)))

# The implemented quantities are computed from vectors formed in one score system.
pred_taxon = apply(sp, 1, function(s) cosine(d_lc, s - lc_t1))
obs_taxon = apply(sp, 1, function(s) cosine(d_wa, s - wa_t1))
pred_climate = apply(bp, 1, function(b) cosine(d_lc, b))
obs_climate = apply(bp, 1, function(b) cosine(d_wa, b))
stopifnot(all(is.finite(pred_taxon)), all(is.finite(obs_taxon)),
          all(is.finite(pred_climate)), all(is.finite(obs_climate)),
          setequal(names(pred_climate), c("MSpT", "MWT", "SP", "WP")))

# Translation, rotation/reflection, and a common arrow multiplier preserve
# cosines. Unequal axis scaling generally does not and is therefore forbidden.
shift = c(2.4, -1.7)
theta = .73
rotation = matrix(c(cos(theta), -sin(theta), sin(theta), cos(theta)), 2)
reflection = matrix(c(-1, 0, 0, 1), 2)
transform_cos = function(Q) cosine(drop(d_lc %*% Q),
                                  drop((sp[1, ] - lc_t1) %*% Q))
base = pred_taxon[1]
translated = cosine(d_lc, (sp[1, ] + shift) - (lc_t1 + shift))
stopifnot(abs(base - translated) < 1e-12,
          abs(base - transform_cos(rotation)) < 1e-12,
          abs(base - transform_cos(reflection)) < 1e-12,
          abs(pred_climate[1] - cosine(d_lc, 4.7 * bp[1, ])) < 1e-12,
          is.na(cosine(c(0, 0), bp[1, ])))
unequal = diag(c(2, .5))
stopifnot(abs(base - transform_cos(unequal)) > 1e-6)
cat("PASS: taxon/climate directions use one scaling-1 CCA geometry.\n")
