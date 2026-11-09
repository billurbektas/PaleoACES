# =============================================================================
# bacon_settings.R - each core's Bacon settings, and the posterior-draw reader
# =============================================================================
# PURE DEFINITIONS. Sourcing this reads nothing, writes nothing and runs no MCMC,
# so it can be sourced from anywhere in the chain regardless of what has been run.
#
# That is why it is a separate file from R/helpers/paleo_ages.R. paleo_ages.R reads
# Cores/*_ages.txt AT SOURCE TIME, and R/pipeline/05_age_depth_models.R is the script
# that CREATES those files - so 05_age_depth_models.R cannot source it, and anything the
# two need in common has to live somewhere neither of them produces.
#
#   sourced by  R/pipeline/05_age_depth_models.R   (to run and redraw the models)
#               R/helpers/holocene_reconstruction.R             (to read the age posteriors)
#
# Defines:
#   slumps       the slumped depth intervals, per MORA core
#   CORE_ARGS    every core's Bacon settings - THE single definition
#   bacon_draws  posterior age draws at given depths, from a finished run
# =============================================================================

# -----------------------------------------------------------------------------
# ONE definition of every core's Bacon settings, used to run the models, to
# redraw them, and to read their posteriors. Keeping them in one place means a
# figure or a draw cannot drift from what was actually run - Bacon(run = FALSE)
# has to rebuild `info` from the same arguments or it describes a different model
# than the one on disk.
# -----------------------------------------------------------------------------
slumps = list(JayBath = c(87, 105), LogWallow = c(40, 98), ReflectionPond = c(45, 64))

# Age error assigned to each 210Pb control in the Panther Potholes sensitivity run
# (the primary run keeps the archived Gavin values; see 05_age_depth_models.R).
PB210_ASSUMED_ERROR = 10

CORE_ARGS = list(
  JayBath         = list(thick = 5, slump = c(87, 105), d.max = 153, remove = FALSE,
                         acc.mean = 50, acc.shape = 1.5, mem.mean = 0.5, mem.strength = 10),
  LogWallow       = list(thick = 5, slump = c(40, 98), remove = FALSE,
                         acc.mean = 50, acc.shape = 1.5, mem.mean = 0.5, mem.strength = 10),
  ReflectionPond  = list(thick = 5, slump = c(45, 64), remove = FALSE,
                         acc.mean = 50, acc.shape = 1.5, mem.mean = 0.5, mem.strength = 10),
  PantherPotholes = list(thick = 5, d.min = 0, d.max = 870, d.by = 0.5,
                         slump = c(303, 308, 396, 406, 623, 635), remove = FALSE,
                         acc.mean = 10, acc.shape = 1.5, mem.mean = 0.7, mem.strength = 10,
                         cc = 1, cc1 = "IntCal20", normal = FALSE, t.a = 15, t.b = 16,
                         ssize = 10000)
)
CORE_ARGS$PantherPotholes_pb210err = CORE_ARGS$PantherPotholes

# -----------------------------------------------------------------------------
# Posterior age draws for a finished Bacon run: an (iterations x depths) matrix,
# one ROW per complete down-core chronology. This is the object age-uncertainty
# randomisation needs - one row is one internally consistent chronology, drawn
# whole. Published quantiles cannot substitute: rebuilding draws by sampling each
# level independently from its own quantiles gives 0.000 monotone chronologies
# against 1.000 here, and destroys the down-core error correlation (r ~ 0.74)
# that keeps interval lengths stable.
#
# Pass the SAME arguments the core was run with (thick, slump, d.max, ...) so the
# settings are rebuilt identically; the MCMC is not re-run. Callers should use
# CORE_ARGS above rather than retyping them.
bacon_draws <- function(core, depths, coredir = file.path(here::here(), "Cores"), ...) {
  # TWO TRAPS, both found the hard way:
  #
  # 1. Bacon(run = FALSE) rebuilds the settings but does NOT read the stored
  #    iterations back - info$output stays empty and everything downstream
  #    silently sees the PRIORS only. They must be loaded from the .out
  #    explicitly with Bacon.AnaOut.
  # 2. Bacon(run = FALSE) can THIN THE STORED .out DOWN TO ITS OWN ssize. Calling
  #    this helper without repeating the run's ssize silently destroys iterations
  #    (10000 -> 4000 the first time this was written). The .out is therefore
  #    snapshotted and restored, so reading draws can never damage the run.
  outdir = file.path(coredir, core)
  before = Sys.glob(file.path(outdir, paste0(core, "_*.out")))
  bak    = file.path(tempdir(), basename(before))
  file.copy(before, bak, overwrite = TRUE)
  on.exit(file.copy(bak, before, overwrite = TRUE), add = TRUE)

  rbacon::Bacon(core = core, coredir = coredir, run = FALSE, suggest = FALSE,
                ask = FALSE, remember = FALSE, plot.pdf = FALSE, verbose = FALSE, ...)
  set  = get("info", envir = .GlobalEnv)
  set  = rbacon:::Bacon.AnaOut(
           file.path(set$coredir, core, paste0(core, "_", set$K, ".out")), set)
  assign("info", set, envir = .GlobalEnv)
  m = sapply(depths, function(d) rbacon::Bacon.Age.d(d, set = set))
  stopifnot(all(apply(m, 1, function(r) all(diff(r) >= 0))))   # monotone by construction
  m
}
