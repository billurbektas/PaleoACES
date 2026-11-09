# 05 Age-depth models: the four Bacon chronologies (Appendix S1).
#
# SLOW: four seeded MCMC runs plus the +-10-year 210Pb sensitivity. They run only
# with `Rscript R/run_all.R --age-models` (or when no run manifest exists). Every
# run also rebuilds Tables S1.1 and S1.2 from the Bacon inputs and settings.
# Provenance of every control: report/details/03_chronology_control_points.md.
# Figures S5 and S6 are drawn from the stored runs by R/figures/supp_age_depth_models.R.
#
# rbacon vignette: https://cran.r-project.org/web/packages/rbacon/vignettes/rbacon.html

library(rbacon)
library(readr)
library(tidyverse)
library(here)

# CORE_ARGS, slumps and bacon_draws(). Pure definitions - sourcing it reads and
# writes nothing, which is why it is safe here, before any core has been run.
source(here("R/helpers/bacon_settings.R"))
source(here("R/helpers/config.R"))

# ------------------------
# Paths
# ------------------------
coredir <- file.path(here(), "Cores")
dir.create(coredir, showWarnings = FALSE, recursive = TRUE)


manifest_path = out('bacon_run_manifest.csv')
if (isTRUE(getOption('paleoaces.run_age_models', FALSE)) || !file.exists(manifest_path)) {
  # -----------------------------------------------------------------------------
  # CLEAN SLATE - run before every Bacon call
  # -----------------------------------------------------------------------------
  # rbacon caches aggressively, and three separate mechanisms can silently make a
  # "re-run" reuse the OLD model:
  #
  #   1. An existing <core>_<K>.out makes Bacon offer to LOAD rather than re-run.
  #      With ask = FALSE that choice is made for you, and the only hint is the
  #      warning "The file with the dates seems newer than the run you are
  #      loading ... please run Bacon.cleanup()".
  #   2. `info` persists in .GlobalEnv between calls within one R session, so a
  #      later core can inherit an earlier core's settings.
  #   3. Stale <core>_<K>_ages.txt from a DIFFERENT K survives a re-run at a new
  #      thick, and read_bacon_ages() picks by modification time - so downstream
  #      can silently read the wrong model. (This bit us once already, with a
  #      leftover PantherPotholes_43_ages.txt beside the real _169 one.)
  #
  # reset_core() removes everything Bacon generated for a core, keeping only the
  # input <core>.csv, and clears `info`. remember = FALSE on every call stops
  # rbacon writing settings back for reuse.
  reset_core <- function(core, coredir = file.path(here(), "Cores")) {
    d <- file.path(coredir, core)
    if (dir.exists(d)) {
      keep <- paste0(core, ".csv")
      gone <- setdiff(list.files(d), keep)
      if (length(gone)) unlink(file.path(d, gone), recursive = TRUE)
    }
    if (exists("info", envir = .GlobalEnv)) rm("info", envir = .GlobalEnv)
    invisible(NULL)
  }

  # Every Bacon call in this script goes through here, so no run can inherit
  # state from a previous one. Args are passed straight to Bacon().
  run_bacon <- function(core, ...) {
    reset_core(core, coredir)
    Bacon(core = core, coredir = coredir,
          suggest = FALSE, ask = FALSE, remember = FALSE, seed = 42, ...)
    # confirm exactly one age file was produced, and that it is new
    f <- Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))
    stopifnot(length(f) == 1)
    cat("  -> ", basename(f), "\n", sep = "")
    invisible(f)
  }

  # ------------------------
  # Helpers
  # ------------------------
  # read_bacon_ages() lives in R/helpers/paleo_ages.R, the shared downstream reader that
  # consumes the ages. Kept there rather than duplicated here so the two copies
  # cannot drift apart.

  # bacon_draws() - posterior age draws for a finished run - now lives in
  # R/helpers/bacon_settings.R, sourced above, because R/helpers/holocene_reconstruction.R needs it too. It
  # could not move into R/helpers/paleo_ages.R: that file reads Cores/*_ages.txt at source
  # time, and THIS script is what creates them.

  write_core_files <- function(core, dates_tbl, ties_tbl) {
    # Enforce Bacon-documented order and headers:
    # Dates CSV MUST be: ID,Age,Error,Depth,cc  (in that order)
    # Ties CSV.TI MUST be: Depth,Age,Error
    dir.create(file.path(coredir, core), showWarnings = FALSE, recursive = TRUE)
  
    dates_tbl <- dates_tbl %>%
      transmute(
        ID    = as.character(ID),
        Age   = as.numeric(Age),
        Error = as.numeric(Error),
        Depth = as.numeric(Depth),
        cc    = as.integer(cc)
      ) %>%
      arrange(Depth)
    stopifnot(all(diff(dates_tbl$Depth) > 0))
    write_csv(dates_tbl, file.path(coredir, core, paste0(core, ".csv")))
  }

  # -------------------------
  # 1) JAY BATH
  # -------------------------
  # Radiocarbon (uncalibrated); ORDER: ID,Age,Error,Depth,cc
  jay_dates <- tribble(
    ~ID,          ~Age, ~Error, ~Depth,  ~cc,
    "QL-1729",     1320,   30,     39.5,   1,
    "QL-1730",     2920,   60,     70.0,   1,
    "Beta-6332",   3740,   80,    124.5,   1,
    "QL-1704",     6050,  110,    152.25,  1
  )

  # NOTE the column name must be ~ID, not ~id. With ~id, bind_rows() below creates
  # a SECOND column and write_core_files() (which reads ID) writes NA for every
  # tephra and surface tie into the Bacon .csv.
  #
  # Tephra_Y and Tephra_Y_alt are the TOP and BOTTOM of one instantaneous deposit,
  # not two alternative picks - see the slump note at the Bacon call below.
  jay_ties <- tribble(
    ~ID,            ~Depth, ~Age, ~Error, ~cc,
    "Surface",         0,    -31.5,   10,    0,   # see SURFACE note at the Bacon call
    "Tephra_W",       22,    470,    10,    0,
    "Tephra_C",       62,   2250,   100,    0,
    "Tephra_Y",       87,   3650,   100,    0,
    "Tephra_Y_alt",  105,   3650,   100,    0,
    "Tephra_F",      142,   5740,   100,    0
  )

  jay_dates = bind_rows(jay_dates, jay_ties)

  write_core_files("JayBath", jay_dates)

  # -------------------------
  # 2) LOG WALLOW
  # -------------------------
  lw_dates <- tribble(
    ~ID,        ~Age, ~Error, ~Depth, ~cc,
    "QL-1726",   1650,   80,     29.0,  1,
    "QL-1727",   4900,   80,    117.0,  1,
    "QL-1728",   5980,   60,    140.0,  1
  )

  lw_ties <- tribble(
    ~ID,           ~Depth, ~Age, ~Error, ~cc,
    "Surface",       0,      -31.5,   10,    0,  # see SURFACE note at the Bacon call
    "Tephra_W",     22,      470,    10,    0, # Wn (AD 1480) dendro # Taken from the Yamaguchi 1983
    "Tephra_Y",     40,     3650,   100,    0,  # Y (broad)
    "Tephra_Y_alt", 98,     3650,   100,    0, # Y (second pick; same age)
    "Tephra_F",     116,    5740,   100,    0 # F (broad)
  )

  lw_dates = bind_rows(lw_dates, lw_ties)

  write_core_files("LogWallow", lw_dates)

  # -------------------------
  # 3) REFLECTION POND
  # -------------------------
  # Radiocarbon (uncalibrated); ORDER: ID,Age,Error,Depth,cc

  rp_dates <- tribble(
    ~ID,            ~Depth, ~Age, ~Error, ~cc,
    "Surface",         0,    -31.5,   10,    0,   # see SURFACE note at the Bacon call
    "Tephra_W",       10,    470,    10,    0,
    "Tephra_C",       26,   2250,   100,    0,
    "Tephra_Y",       45,   3650,    100,   0,
    "Tephra_Y_alt",   64,   3650,    100,   0,
    "Tephra_F",       82,   5740,    100,   0,
    # BASAL DATE (decided 2026-11-09, supersedes the 6180 +- 400 cal BP Crandell
    # lahar control). Reflection Pond has no radiocarbon, so its base borrows the
    # basal dates of the other two ponds on the same surface, as Dunwiddie himself
    # advised (pers. comm.): "This should be the same basal date as the other two
    # sites. I suggest using 6015 (average of my two dates) for all three sites."
    #   6015 = mean of QL-1704 (Jay Bath, 6050 +- 110) and QL-1728 (Log Wallow,
    #   5980 +- 60). The two pass Ward & Wilson (T = 0.31 < 3.84).
    # It is a 14C AGE, so cc = 1: entered as cc = 0 it would sit ~800 yr too young.
    # Error = the LARGER lab error (110), not the error of the mean (63): the mean's
    # error is measurement error only and would make this undated core more precise
    # than Jay Bath's own basal date; it ignores the transfer between ponds.
    # Jay Bath and Log Wallow keep their own measured basal dates.
    # Why the Crandell control was wrong: his 5,800-6,600 bracket tops out at layer
    # O = Mazama "about 6,600 years ago", which is ~7,630 cal BP today, so the
    # bracket is radiocarbon-era, not calendar; and both measured basal dates on the
    # lahar (6910 and 6818 cal BP) were older than its supposed maximum age. It also
    # compressed the core: ~380 yr below tephra F, i.e. ~95 yr per 2-cm sample,
    # against the 300-370 yr per sample Dunwiddie (1986) reports before 4900 BP.
    "Basal_date_mean", 90,  6015,    110,   1
  )

  rp_dates = bind_rows(rp_dates)

  write_core_files("ReflectionPond", rp_dates)


  # -------------------------
  # 3b) PANTHER POTHOLES (NOCA)
  # -------------------------
  # FULL PROVENANCE: data/NOCA/NOCA_paleo/SOURCES.md. Summary of every number below.
  #
  # The site already has a published Bayesian chronology - "Gavin 2021" (Daniel G.
  # Gavin, prepared 2021-11-09), which IS a Bacon run. Its complete settings string
  # and all 15 control points are stored by Neotoma and checked in here:
  #   data/NOCA/NOCA_paleo/neotoma_chronology_52207_gavin2021.json
  #   data/NOCA/NOCA_paleo/neotoma_chroncontrols_52207_gavin2021.csv
  # retrieved 2026-08-07 from
  #   https://api.neotomadb.org/v2.0/data/downloads/52207
  #
  # WHY RE-RUN A MODEL THAT ALREADY EXISTS. Not to re-estimate it - Gavin's
  # chronology is sound. Neotoma publishes only three quantiles per level
  # (older/median/younger), and every metric in this project is measured over an
  # INTERVAL (delta climate / vegetation / offset from t1 to t2, with dt in the
  # denominator). Propagating age uncertainty through those needs whole coherent
  # chronologies, which is also what RRatepol::estimate_roc(age_uncertainty=) takes:
  # "one row per age sequence drawn from a posterior age-depth model". Quantiles
  # cannot be turned back into draws - tested on JayBath, where we have both:
  # sampling each level independently from its own quantiles yields 0.000 monotone
  # chronologies (all 4000 contain an age reversal) vs 1.000 for the true posterior,
  # and collapses the down-core error correlation that keeps dt stable (r = 0.741
  # true, 0.003 rebuilt). Re-running regenerates that ensemble.
  #
  # !! DO NOT USE THE DEPTHS PRINTED IN PRICHARD'S TABLES 1a/1b !!
  # Neotoma sitenotes: "See geochronology notes about errors in sample depths and
  # tephra depths in publication and Neotoma, corrected November 2021." Prichard's
  # own Results text agrees with the corrections and contradicts their own Table 1b
  # ("the basal date ... at 864 cm ... the most recent date ... at 214 cm" vs 972
  # and 219 in the table). Shifts: -5, -15, -15, -25, -78, -108 cm. Two traps this
  # springs if ignored: the model then looks like it rejects Beta-169208 by ~880 yr
  # (it fits to -148 at the right depth), and Beta-169624 appears to sit inside the
  # MSH Y tephra (it is 7 cm above it at 389 cm).
  pp_dates <- tribble(
    ~ID,          ~Age,  ~Error, ~Depth, ~cc,
    # --- Core top. Coring year 1999, derived two ways (SOURCES.md): Gavin's own
    # core-top control is -49 cal BP = 1999 CE, and a 1999 coring year reproduces
    # all five 210Pb controls to RMSE 1.0 yr.
    "CoreTop",      -49,   1,       0.5,  0,
    # --- 210Pb. Prichard Table 1c, CRS model (Flett Research Ltd., Winnipeg).
    # Table 1c is in YEARS BEFORE CORING; cal BP = yr_before_coring - 49.
    # NOTE the errors are Prichard's DPM/g ACTIVITY errors, which Gavin carried into
    # the age-error column (3.47/1.15/0.72/0.74/0.77 in both). A DPM/g s.e. is not a
    # year. Kept here to reproduce Gavin faithfully; see the pb210_err variant below.
    "Pb210_7",    -36.7,   3.47,    7,    0,   # T1c 12.3 yr before coring
    "Pb210_14",      -9,   1.15,   14,    0,   # T1c 40
    "Pb210_21",      12,   0.72,   21,    0,   # T1c 61
    "Pb210_28",      21,   0.74,   28,    0,   # T1c 70
    "Pb210_35",      36,   0.77,   35,    0,   # T1c 85
    # --- AMS 14C, UNCALIBRATED (cc = 1, Bacon calibrates with IntCal20).
    # Ages/errors are Prichard Table 1b verbatim (Beta Analytic); depths corrected.
    "Beta-172005", 1950,  50,     214,    1,   # conifer seed   (Table 1b says 219)
    "Beta-169623", 3260,  40,     363,    1,   # seed                        (378)
    "Beta-169624", 3520,  40,     389,    1,   # pollen cone                 (404)
    "Beta-169207", 4500,  40,     479,    1,   # pollen cone                 (504)
    "Beta-169208", 7330,  40,     678,    1,   # seed                        (756)
    "Beta-169625", 9370,  40,     864,    1,   # Pinus contorta needles      (972)
    # --- Tephra, calendar ages (cc = 0). Layers identified by glass chemistry
    # (F. Foit, WSU); similarity coefficients 0.99 / 0.97 / 0.99. Ages are Gavin's
    # literature values, NOT Prichard's core-derived brackets.
    # MSH P  : 2620 +- 70. Prichard's 2590-3184 is the calibration of the broad
    #          2500-3000 14C literature range for set P; its midpoint (2887) is too old.
    # MSH Y  : 3660 +- 65. SAME ERUPTION as MORA's Tephra_Y, entered above as
    #          3650 +- 100. The two sites agree to 10 yr independently.
    # Mazama : 7633 +- 25. Matches Egan et al. 2015 (7584-7682, 2sd) and Zdanowicz
    #          et al. 1999 (7627 +- 150); Prichard's 7610-7690 agrees too.
    "Tephra_MSH_P",  2620, 70,   305.5,   0,   # 303-308,  5 cm
    "Tephra_MSH_Y",  3660, 65,   401.0,   0,   # 396-406, 10 cm
    "Tephra_Mazama", 7633, 25,   629.0,   0    # 623-635, 12 cm (Table 1a said 623-639)
  )

  # Verify the hand-entered table against the checked-in Neotoma extract, so a typo
  # in the numbers above cannot pass silently.
  pp_neotoma = read_csv(here("data/NOCA/NOCA_paleo/neotoma_chroncontrols_52207_gavin2021.csv"),
                        show_col_types = FALSE) %>% arrange(depth)
  stopifnot(
    nrow(pp_dates) == nrow(pp_neotoma),
    all.equal(sort(pp_dates$Depth), pp_neotoma$depth),
    all.equal((pp_dates %>% arrange(Depth))$Age,   pp_neotoma$age),
    all.equal((pp_dates %>% arrange(Depth))$Error, pp_neotoma$error)
  )

  write_core_files("PantherPotholes", pp_dates)

  # -------------------------
  # 4) RUN BACON: JayBath & LogWallow & ReflectionPond
  # -------------------------
  # SLUMP. The Y tephra is entered at two depths per core, both 3650 cal BP. Those
  # are the TOP and BOTTOM of one instantaneously deposited unit, not alternative
  # picks. Dunwiddie 1986 (Ecology 67:58-68):
  #   p.62  "The Y tephra is overlain by 43 cm of redeposited Y tephra"
  #   Fig.4 "Redeposited Y tephra (86-43 cm) is omitted"
  #   p.59  layer Yn is "the thickest of the set Y tephra, with deposits of 15 cm
  #         common on the south side of the mountain"
  # so JayBath 87-105 (18 cm) and ReflectionPond 45-64 (19 cm) are the airfall,
  # and LogWallow 40-98 (58 cm) is ~15 cm airfall plus 43 cm of redeposited Y.
  # `slump` excises these before age-modelling and re-inserts them afterwards at
  # zero elapsed time. Without it Bacon tried to accumulate 58 cm of LogWallow in
  # no time, blew its 95% CI out to a median of 1513 yr, and REJECTED the 40 cm
  # date (model 2180 vs stated 3650). With it: CI median 397 yr and every date in
  # every core inside the 95% envelope.
  # SURFACE = -31.5 cal BP, NOT 0. The core top is the sediment surface at the moment
  # of coring, and cal BP is measured from A.D. 1950 - so entering 0 asserts the tops
  # are A.D. 1950. **Billur confirmed with Dunwiddie that the lakes were cored in
  # 1981-1982**, so the tops are 1950 - 1981.5 = -31.5 cal BP. Neither Dunwiddie 1986
  # nor 1987 states the coring year (1986 Methods: "Cores were collected with a
  # modified 5 cm diameter Livingstone piston corer from a floating platform" - no
  # date); the published bound is only "manuscript received 17 April 1984".
  #
  # Error 10, not 5. The coring year is now known to ~1 yr, so the residual
  # uncertainty is whether the sediment-water interface survived extrusion. At these
  # cores' accumulation rates (~23-50 yr/cm) even 0.5 cm of lost floc is ~15-25 yr,
  # so +-10 is the honest floor. It spans A.D. 1972-1992.
  #
  # Effect of the fix, measured: core tops move to -32/-33/-32 as intended, and the
  # median absolute change BELOW 40 cm is 3/5/1 yr - i.e. nothing. This matters for
  # consistency with NOCA (whose core top was derived as -49 cal BP = A.D. 1999),
  # not because it moves any result.
  # `slumps` and CORE_ARGS - the single definition of every core's Bacon settings,
  # used to run the models, to redraw them in section 5, and by R/helpers/holocene_reconstruction.R to
  # read their posteriors - are defined in R/helpers/bacon_settings.R, sourced at the top.

  # d.max. JayBath has a macrofossil sample at 153 cm but its deepest date sits at
  # 152.25, so by default Bacon models only to 152 and the basal (oldest) sample
  # joins to no age - it became "JayBath_NA_BP". Extrapolating 1 cm (~40 yr at this
  # core's accumulation rate) recovers it. The other two cores need nothing:
  # LogWallow samples reach 140 and ReflectionPond 90, both within their models.
  d_max = list(JayBath = 153, LogWallow = NULL, ReflectionPond = NULL)

  # acc.mean = 50 MUST be given explicitly. It was previously supplied by accepting
  # Bacon's interactive suggestion; with suggest = FALSE that prompt never appears
  # and Bacon silently falls back to its default of 20 yr/cm. That is far too fast
  # for these cores (ReflectionPond runs ~90 yr/cm below the slump), and the model
  # then ignores the F tephra and basal lahar entirely.
  # suggest/ask = FALSE so the script can be sourced without prompting.
  for (core in names(slumps)) {
    cat("\n=== ", core, " ===\n", sep = "")
    do.call(run_bacon, c(list(core = core, plot.pdf = TRUE, verbose = TRUE),
                         CORE_ARGS[[core]]))
  }

  # -------------------------
  # 4b) RUN BACON: PantherPotholes (NOCA)
  # -------------------------
  # Every setting below is Gavin's, read off the settings string Neotoma stores with
  # the chronology (data/NOCA/NOCA_paleo/neotoma_chronology_52207_gavin2021.json):
  #
  #   0 #d.min | 870 #d.max | 0.5 #d.by | 303308396406623635 #slump
  #   10 #acc.mean | 1.5 #acc.shape | 0.7 #mem.mean | 10 #mem.strength
  #   1 #cc | IntCal20 #cc1 | 0 #normal | 15 #t.a | 16 #t.b | 0.95 #prob
  #
  # acc.mean = 10, NOT the 50 used for the MORA ponds. acc.mean is the mean of a
  # gamma prior on accumulation in yr/cm; the standard way to set it is age span /
  # depth span. Here 10594 yr / 941 slump-free cm ~ 11, and Prichard's stated core
  # mean is 12.8 yr/cm (0.078 cm/yr); Gavin used 10. The MORA ponds run ~50. Passing
  # the MORA value here would be as wrong as the silent fallback to 20 was there.
  #
  # SLUMP: the three tephras are instantaneous deposits with real thickness -
  # 303-308 (5 cm), 396-406 (10 cm), 623-635 (12 cm), 27 cm total. Same treatment as
  # the MORA Y tephra. With remove = FALSE a control that falls inside its own slump
  # is collapsed onto the slump horizon rather than dropped, so all three tephra
  # dates survive (verified against rbacon:::toslump).
  #
  # normal = 0 with t.a = 15, t.b = 16 is Bacon's Student-t outlier model, which
  # tolerates a scattered date instead of being dragged by it. The MORA cores use
  # rbacon's defaults; this is Gavin's choice and is kept.
  pp_slump = c(303, 308, 396, 406, 623, 635)

  # thick = 5 (rbacon's default; K = 169 sections) and ssize = 10000.
  # `thick` is the ONE Gavin setting Neotoma does not store - a Bacon _settings.txt
  # does not record it - so it was recovered by sweeping it against his published
  # quantiles. Our _settings.txt is otherwise byte-identical to the string Neotoma
  # holds for his run, so this is the only free parameter.
  #
  #   thick   K   median |ours - Gavin|   max |diff|   our 95% width   MCMC ESS
  #      50  17          34 yr               167 yr        550            37
  #      30  29          36                  213           618             6
  #      20  43          26                  126           614           106
  #      10  85          13                   52           526           863
  #       5 169           3                   17           418          2621   <-
  #
  # Gavin's published 95% width is 417 yr. At thick = 5 ours is 418 and the medians
  # agree to 3 yr over a 10,600 yr record, so this is a reproduction, not a refit.
  # ssize is raised from the default 4000 because at 4000 this core mixes badly
  # (ESS 37); at 10000 mixing is "excellent" (ESS 2621). Do not lower it.

  # PRIMARY run - reproduces Gavin 2021.
  cat("\n=== PantherPotholes ===\n")
  do.call(run_bacon, c(list(core = "PantherPotholes", plot.pdf = TRUE, verbose = TRUE),
                       CORE_ARGS$PantherPotholes))

  # SENSITIVITY - 210Pb age errors instead of activity errors.
  #
  # THE PROBLEM (sourced). Prichard Table 1c has NO age-error column; its
  # "Error (1sigma)" is on total 210Pb ACTIVITY in DPM/g, per its own footnote, and
  # those five numbers were carried verbatim into the age-error column of the
  # published model (3.47/1.15/0.72/0.74/0.77 in both). So Bacon was told the age at
  # 21 cm is 12 cal BP +- 0.72 YEARS. Consequence: the top 35 cm carries a 95% width
  # of ~7 yr against a core median of 417 yr.
  #
  # THE REPLACEMENT (NOT sourced - ASSUMED BY US).
  # ------------------------------------------------------------------------------
  # There is no way to recover the real CRS age errors from Table 1c: proper
  # propagation needs supported 210Pb, dry bulk density and sample mass, none of
  # which are published. The Flett Research report or Prichard's 2003 thesis would
  # have them; until then this number is OUR ASSUMPTION and nothing else.
  #
  # ONE CONSTANT, +-10 yr, deliberately. An earlier version used an age-proportional
  # rule (25% of the age, floor 5 yr), on the argument that CRS errors grow downcore
  # as unsupported 210Pb decays toward background. That argument is correct - it
  # produces a widening envelope (20/30/37/44/62 yr at 7/14/21/28/35 cm) where a
  # constant produces a flat one (28/32/30/30/36) - but it is IRRELEVANT to the only
  # question this run exists to answer, and it is harder to defend. Tested directly,
  # all four assumptions give the same answer:
  #
  #   assumption      95% width, top 35 cm    35-214 cm    below 214 cm
  #   published                        7            436            417
  #   constant 10                     30            441            422
  #   proportional                    34            437            416
  #   constant 15                     39            439            419
  #   constant 20                     46            438            418
  #
  # So: 7 -> 30-46 yr in the 210Pb section and NOTHING below 35 cm moves, under every
  # assumption tried. That range, not any single value, is the result - which is why
  # a constant is preferred: it makes the weaker, more defensible claim and reaches
  # the same conclusion. Reproduce the other rows with PB210_ROBUSTNESS below.
  #
  # This affects ONLY the sensitivity run. The primary run keeps Gavin's values, so
  # the reproduction claim is untouched.
  # PB210_ASSUMED_ERROR (10 yr) is set in R/helpers/bacon_settings.R.
  PB210_ROBUSTNESS    = c()   # set to c(15, 20) to rebuild the table above

  pp_dates_pb = pp_dates %>%
    mutate(Error = ifelse(grepl("^Pb210_", ID), PB210_ASSUMED_ERROR, Error))
  cat("\n210Pb errors - published (DPM/g activity, mis-entered as years) vs ASSUMED:\n")
  print(pp_dates %>% filter(grepl("^Pb210_", ID)) %>%
          transmute(ID, Depth, Age, published_error = Error,
                    assumed_error = PB210_ASSUMED_ERROR))
  write_core_files("PantherPotholes_pb210err", pp_dates_pb)

  cat("\n=== PantherPotholes_pb210err (210Pb sensitivity) ===\n")
  do.call(run_bacon, c(list(core = "PantherPotholes_pb210err", plot.pdf = TRUE, verbose = TRUE),
                       CORE_ARGS$PantherPotholes_pb210err))

  # Optional: rebuild the robustness table in the comment above. Off by default -
  # each run is a full MCMC and adds several minutes to sourcing this script.
  for (E in PB210_ROBUSTNESS) {
    nm = paste0("PantherPotholes_pbconst", E)
    write_core_files(nm, pp_dates %>%
      mutate(Error = ifelse(grepl("^Pb210_", ID), E, Error)))
    do.call(run_bacon, c(list(core = nm, plot.pdf = FALSE, verbose = FALSE),
                         CORE_ARGS$PantherPotholes))
  }


  # =============================================================================
  # 6) RUN MANIFEST - durable proof of exactly what the seeded rebuild produced
  # =============================================================================
  manifest_models = c("JayBath", "LogWallow", "ReflectionPond",
                      "PantherPotholes", "PantherPotholes_pb210err")
  manifest_file = function(core, suffix) {
    f = Sys.glob(file.path(coredir, core, paste0(core, suffix)))
    if (length(f) != 1L) stop("Expected exactly one ", suffix, " file for ", core)
    f
  }
  project_relative = function(path) {
    sub(paste0(normalizePath(here()), "/"), "", normalizePath(path), fixed = TRUE)
  }
  bacon_manifest = map_dfr(manifest_models, function(core) {
    control = file.path(coredir, core, paste0(core, ".csv"))
    posterior = manifest_file(core, "_*.out")
    ages = manifest_file(core, "_*_ages.txt")
    settings = CORE_ARGS[[core]]
    tibble(
      model = core,
      role = if_else(core == "PantherPotholes_pb210err",
                     "configured +-10-year 210Pb sensitivity", "primary"),
      seed = 42L,
      r_version = paste(R.version$major, R.version$minor, sep = "."),
      rbacon_version = as.character(packageVersion("rbacon")),
      settings_fingerprint = object_fingerprint(settings),
      control_file = project_relative(control),
      control_md5 = unname(tools::md5sum(control)),
      posterior_file = project_relative(posterior),
      posterior_md5 = unname(tools::md5sum(posterior)),
      posterior_bytes = file.info(posterior)$size,
      ages_file = project_relative(ages),
      ages_md5 = unname(tools::md5sum(ages)),
      ages_bytes = file.info(ages)$size,
      age_model_script_md5 = unname(tools::md5sum(here("R/pipeline/05_age_depth_models.R"))),
      bacon_settings_md5 = unname(tools::md5sum(here("R/helpers/bacon_settings.R"))),
      generated_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
  })
  write_csv(bacon_manifest, out("bacon_run_manifest.csv"))
  cat("Written", manifest_path, "for", nrow(bacon_manifest), "seeded runs.\n")
}

# =============================================================================
# Tables S1.1 (chronological controls) and S1.2 (rbacon parameters)
# =============================================================================
source(here('R/helpers/chronology_tables.R'), local = TRUE)
write_chronology_tables()
