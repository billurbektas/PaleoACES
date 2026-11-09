# Display-only varimax rotation of the CCA plane (Kaiser 1958).
#
# The two CCA axes are rotated rigidly so that each climate constraint's biplot
# arrow lies as close as possible to one axis. A rigid rotation (plus an optional
# reflection) preserves every distance and angle in the plane, so lags,
# displacements, tracking ratios and angles are unchanged: they are computed on
# the unrotated axes in R/pipeline/ and never read these display coordinates.
# The rotated axes are not ordered by eigenvalue and are slightly correlated, so
# figures label them "rotated axis" rather than CCA1/CCA2.

# Kaiser's closed-form varimax angle for two axes, on row-normalized loadings.
kaiser_varimax_angle = function(loadings) {
  L = loadings[, 1:2, drop = FALSE] / sqrt(rowSums(loadings[, 1:2, drop = FALSE]^2))
  u = L[, 1]^2 - L[, 2]^2; v = 2 * L[, 1] * L[, 2]
  A = sum(u); B = sum(v); C = sum(u^2 - v^2); D = 2 * sum(u * v); p = nrow(L)
  atan2(D - 2 * A * B / p, C - (A^2 - B^2) / p) / 4
}

# The display transform: rotation by the Kaiser angle, then a reflection of each
# axis so that the first constraint points along +axis 1 and the second along +axis 2.
cca_display_rotation = function(biplot_scores) {
  phi = kaiser_varimax_angle(biplot_scores)
  R = matrix(c(cos(phi), sin(phi), -sin(phi), cos(phi)), 2)
  rotated = biplot_scores[, 1:2, drop = FALSE] %*% R
  # Assign each constraint to the axis it loads on most, then orient that axis.
  first = which.max(abs(rotated[1, ]))
  if (first == 2L) { R = R[, 2:1]; rotated = rotated[, 2:1, drop = FALSE] }
  flip = c(sign(rotated[1, 1]), if (nrow(rotated) > 1L) sign(rotated[2, 2]) else 1)
  flip[flip == 0] = 1
  R = R %*% diag(flip)
  structure(list(matrix = R, angle_degrees = phi * 180 / pi,
    axis_variables = rownames(biplot_scores)[1:min(2L, nrow(biplot_scores))]), class = 'cca_display_rotation')
}

# Apply the display transform to coordinate columns (x, y) of a data frame.
rotate_columns = function(data, rotation, x, y) {
  xy = as.matrix(data[, c(x, y)]) %*% rotation$matrix
  data[[x]] = xy[, 1]; data[[y]] = xy[, 2]
  data
}
