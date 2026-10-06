# =============================================================================
# paleo_runs.R - the moving-window run machinery: age draws x bin offsets
# =============================================================================
# ONE definition of what a "run" is, shared by the CCA figure and the tracking
# metrics, so a bin cannot mean one thing in a figure and another
# in the numbers underneath it.
#
#   reads   output/paleo_sample_depths.csv   (written by 000_PALEO_b_vegetation.R)
#           Cores/<core>/<core>_<K>.out      (the Bacon posterior, via bacon_draws)
#   caches  output/paleo_age_draws.rds
#   writes  nothing else - this file is sourced, not run for its outputs
#
# Sourcing it defines functions and constants only. Nothing is computed until
# paleo_age_draws() is called, and that call is cached.
#
# WHY A RUN IS (ONE AGE DRAW x ONE BIN OFFSET) - both, nested, not either alone:
#
#   Age draw.   The 95% age uncertainty is 370-692 yr, a substantial fraction
#               of a primary bin. Draws can move samples between bins, and many
#               samples are genuinely ambiguous, so a single median chronology
#               reports a precision the cores do not have.
#   Bin offset. Where the first bin edge falls is arbitrary, and it decides which
#               samples group together. Running all 10 primary offsets and taking the
#               median removes that arbitrariness; the spread across offsets is a
#               free, honest error band, and it is widest exactly where samples
#               are sparse.
#
# The two are NESTED rather than crossed-and-averaged-separately: each run draws
# one complete chronology AND one bin phase, so the run spread carries both
# sources at once. The primary bin width is 1,000 yr, matching the operational
# climate-change support, with 10 native 100-yr CHELSA steps. The former
# 500-year configuration is invoked explicitly by its sensitivity stage.
#
# ⚠ THE RUN SPREAD IS NOT A CONFIDENCE INTERVAL ON THE RESULT. It covers age
# uncertainty and bin phase, and NOTHING else - not CCA uncertainty, not CHELSA
# uncertainty, not the TraCE21k bias. Say so wherever it is drawn.
# =============================================================================

library(here)
library(tidyverse)
source(here("R/helpers/bacon_settings.R"))     # CORE_ARGS, bacon_draws()
source(here("R/helpers/config.R"))
source(here("R/helpers/chronology_provenance.R"))

# -----------------------------------------------------------------------------
# Run configuration - all `if (!exists())`, so a caller can sweep any of them
# -----------------------------------------------------------------------------
# Primary interval configuration; callers may override it before sourcing.
if (!exists("HOLO_BIN"))  HOLO_BIN  = 1000
if (!exists("OFFSETS"))   OFFSETS   = seq(0, HOLO_BIN - 100, by = 100)
# N_DRAWS is the documented primary setting. Reassess it explicitly if chronology
# or sample support changes; use draw_convergence() below rather than raising the
# number until a result looks calm.
if (!exists("N_DRAWS"))   N_DRAWS   = 100
if (!exists("DRAW_SEED")) DRAW_SEED = 42

CORES = c("JayBath", "LogWallow", "ReflectionPond", "PantherPotholes")

# -----------------------------------------------------------------------------
# paleo_age_draws() - one complete chronology per draw, per sample
# -----------------------------------------------------------------------------
# Returns a long tibble: lake, plot_id, draw, age.
#
# Draws are taken WHOLE. Row i of the Bacon output is one internally consistent
# down-core chronology; every sample in draw i is dated by that same chronology.
# Sampling each sample independently from its own posterior would destroy the
# down-core error correlation (r ~ 0.74) that keeps interval lengths stable, and
# would produce non-monotone chronologies - a younger sample below an older one.
# bacon_draws() asserts monotonicity, so that failure mode cannot pass silently.
#
# COLLAPSED SAMPLES. 30 depths share a plot_id with another depth, because their
# MEDIAN ages round to the same year (three ReflectionPond depths at 3641 cal BP,
# plus three PantherPotholes pairs). Their ages are averaged WITHIN each draw -
# not across draws, and not by picking one depth. Within a draw the contributing
# depths are dated by the same chronology, so their mean is still a position on
# that chronology; picking one depth would let an accident of the median decide
# which posterior a sample carries. This mirrors how the vegetation collapses
# them (present if present at any contributing depth) and how the fire table does
# (max magnitude, mean percentage).
paleo_age_draws = function(n_draws = N_DRAWS, seed = DRAW_SEED, cache = TRUE) {

  cache_file = here("output", "paleo_age_draws.rds")
  dependency_files = c(
    here("output/paleo_sample_depths.csv"),
    here("R/helpers/bacon_settings.R"),
    list.files(here("Cores"), pattern = "\\.out$", recursive = TRUE,
               full.names = TRUE)
  )
  if (!all(file.exists(dependency_files)))
    stop("Missing paleo age-draw dependency: ",
         paste(dependency_files[!file.exists(dependency_files)], collapse = ", "))
  dependency_paths = normalizePath(dependency_files)
  dependency_md5 = unname(tools::md5sum(dependency_files))
  settings_identity = chronology_source_identity("R/helpers/bacon_settings.R")
  # Preserve the existing draws only when every byte matches the recorded move.
  # Genuine edits retain their current identity and trigger the existing rebuild.
  if (!is.null(settings_identity$historical_md5)) {
    dependency_paths[2L] = settings_identity$historical_path
    dependency_md5[2L] = settings_identity$historical_md5
  }
  dependency_signature = object_fingerprint(list(
    files = dependency_paths,
    md5 = dependency_md5,
    core_args = CORE_ARGS
  ))
  if (cache && file.exists(cache_file)) {
    cached = readRDS(cache_file)
    if (identical(cached$n_draws, n_draws) && identical(cached$seed, seed) &&
        identical(cached$dependency_signature, dependency_signature))
      return(cached$draws)
    message("paleo_age_draws.rds dependencies changed; rebuilding cached draws.")
  }

  sd_tbl = read_csv(here("output/paleo_sample_depths.csv"), show_col_types = FALSE)
  stopifnot(setequal(sd_tbl$lake, CORES))

  out = map_dfr(CORES, function(core) {
    d = sd_tbl %>% filter(lake == core) %>% arrange(depth)
    # ssize is part of CORE_ARGS where it matters (PantherPotholes, 10000) - it
    # MUST be passed through, or Bacon(run = FALSE) thins the stored chain.
    m = do.call(bacon_draws, c(list(core = core, depths = d$depth), CORE_ARGS[[core]]))
    # m is (iterations x depths). Subsample ROWS - whole chronologies.
    set.seed(seed)
    idx = sample.int(nrow(m), n_draws, replace = nrow(m) < n_draws)
    if (nrow(m) < n_draws)
      warning("core ", core, " has only ", nrow(m), " stored iterations for ",
              n_draws, " draws - sampling WITH replacement")

    as_tibble(m[idx, , drop = FALSE], .name_repair = "minimal") %>%
      setNames(as.character(d$depth)) %>%
      mutate(draw = row_number()) %>%
      pivot_longer(-draw, names_to = "depth", values_to = "age") %>%
      mutate(depth = as.numeric(depth), lake = core) %>%
      left_join(d %>% select(depth, plot_id), by = "depth") %>%
      # collapse the shared-plot_id depths, within the draw
      group_by(lake, plot_id, draw) %>%
      summarize(age = mean(age), .groups = "drop")
  })

  # Every sample must get every draw, or a sample would silently thin out of the
  # binned figures while still looking present in paleo_occ.
  stopifnot(nrow(out) == n_distinct(sd_tbl$plot_id) * n_draws,
            !any(is.na(out$age)))

  if (cache) saveRDS(list(draws = out, n_draws = n_draws, seed = seed,
                          dependency_signature = dependency_signature), cache_file)
  out
}

# -----------------------------------------------------------------------------
# make_runs() - cross the draws with the bin offsets and assign bins
# -----------------------------------------------------------------------------
# Returns lake, plot_id, draw, offset, run_id, age, bin, bin_mid.
#
# run_id identifies one age draw x one bin offset, so n_runs = n_draws x
# length(offsets). Downstream: compute the metric per run, then take the MEDIAN
# across runs and the 2.5-97.5 percentile as the band.
#
# The bin a sample lands in is `floor((age - offset)/w)*w + offset`, so bin is
# the bin's LOWER edge in cal BP and bin_mid its centre. Ages run backwards, so a
# smaller bin is younger; sort by descending bin to walk time forwards.
make_runs = function(draws = paleo_age_draws(), bin_width = HOLO_BIN,
                     offsets = OFFSETS) {
  expand_grid(offset = offsets, draws) %>%
    mutate(bin     = floor((age - offset) / bin_width) * bin_width + offset,
           bin_mid = bin + bin_width / 2,
           run_id  = paste0("d", draw, "_o", offset))
}

# -----------------------------------------------------------------------------
# draw_convergence() - is n_draws enough? Do not assume; show it.
# -----------------------------------------------------------------------------
# Recomputes a summary statistic on the first k draws for increasing k and
# returns the sequence, so the caller can see the median flatten out (or not).
# `stat_fun` takes the runs tibble and returns one number.
draw_convergence = function(stat_fun, draws = paleo_age_draws(),
                            ks = c(10, 25, 50, 100, 200), ...) {
  ks = ks[ks <= max(draws$draw)]
  map_dfr(ks, function(k)
    tibble(n_draws = k,
           value   = stat_fun(make_runs(draws %>% filter(draw <= k), ...))))
}
