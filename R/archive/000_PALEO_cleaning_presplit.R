# Re-calibration of the age-depth model ----
# Documentation for rbacon package: https://cran.r-project.org/web/packages/rbacon/vignettes/rbacon.html
# Install (once): install.packages(c("rbacon","readr","tidyverse","here"))
# ================================
# Bacon: JayBath, LogWallow, ReflectionPond (Option C + lahar)
# ================================
# install.packages(c("rbacon","readr","tidyverse","here"))
library(rbacon)
library(readr)
library(tidyverse)
library(here)
library(readxl)   # DunwiddieMacrofossils.xlsx
library(sf)       # st_as_sf for the pond coordinates

# ------------------------
# Paths
# ------------------------
coredir <- file.path(here(), "Cores")
dir.create(coredir, showWarnings = FALSE, recursive = TRUE)

# ------------------------
# Helpers
# ------------------------
read_bacon_ages <- function(core, coredir = file.path(getwd(), "Cores")) {
  # Prefer unsuffixed; else most recent suffixed <core>_*_ages.txt
  f1 <- file.path(coredir, core, paste0(core, "_ages.txt"))
  if (file.exists(f1)) {
    df <- read.table(f1, header = TRUE)
    names(df) <- tolower(names(df))
    return(df)
  }
  cand <- Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))
  if (length(cand) == 0) stop("No *_ages.txt found for core '", core, "' in ", file.path(coredir, core))
  latest <- cand[which.max(file.info(cand)$mtime)]
  df <- read.table(latest, header = TRUE)
  names(df) <- tolower(names(df))
  df
}

# Posterior age draws for a finished Bacon run: an (iterations x depths) matrix,
# one ROW per complete down-core chronology. This is the object age-uncertainty
# randomisation needs - RRatepol::estimate_roc(age_uncertainty=) is documented as
# "one row per age sequence drawn from a posterior age-depth model", and one row
# is drawn per randomisation run. Published quantiles cannot substitute: rebuilding
# draws by sampling each level independently from its own quantiles gives 0.000
# monotone chronologies against 1.000 here, and destroys the down-core error
# correlation (r ~ 0.74) that keeps interval lengths stable.
#
# Pass the SAME arguments the core was run with (thick, slump, d.max, ...) so the
# settings are rebuilt identically; the MCMC is not re-run. Without an explicit
# ssize the read subsamples the stored chain to rbacon's default 4000 draws, which
# is ample; pass ssize to get all of them.
bacon_draws <- function(core, depths, coredir = file.path(here(), "Cores"), ...) {
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

  Bacon(core = core, coredir = coredir, run = FALSE, suggest = FALSE, ask = FALSE,
        remember = FALSE, plot.pdf = FALSE, verbose = FALSE, ...)
  set  = get("info", envir = .GlobalEnv)
  set  = rbacon:::Bacon.AnaOut(
           file.path(set$coredir, core, paste0(core, "_", set$K, ".out")), set)
  assign("info", set, envir = .GlobalEnv)
  m = sapply(depths, function(d) rbacon::Bacon.Age.d(d, set = set))
  stopifnot(all(apply(m, 1, function(r) all(diff(r) >= 0))))   # monotone by construction
  m
}

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
  # Paradise lahar - the mudflow all three ponds sit ON, so a MAXIMUM age for the
  # basal sediment. Crandell 1971 (USGS Prof. Paper 677) p.63: "The Paradise lahar
  # is between 5,800 and 6,600 years old" -> midpoint 6200, half-range 400.
  #
  # TWO CONVERSIONS, both easy to get wrong:
  # 1. Crandell's ages are ALREADY CALIBRATED, so cc = 0 is correct. p.11: ages
  #    under 6,000 yr "have been corrected ... take into account past variations in
  #    atmospheric C14", and his Table 4 calls them "true dates". Re-calibrating
  #    them (which would give ~6845 cal BP) DOUBLE-COUNTS the correction.
  # 2. He reports "Years ago in 1970", NOT cal BP. Verified on his own row: W-1120,
  #    290 14C -> "1525 A.D." -> "450 years ago in 1970" (1970-1525 = 445). So
  #    cal BP = years_ago_in_1970 - 20, giving 5780-6580 cal BP -> 6180 +- 400.
  #
  # Was 6000 +- 600 (Dunwiddie p.59's rounded "6000-yr-old Paradise lahar"). That
  # spans 5400-6600 and so covered the truth, but sat ~180 yr low with a wider error
  # than the source needs. This matters most for ReflectionPond, which has NO
  # radiocarbon at all - it is dated entirely by tephra plus this lahar.
  "Basal_lahar",    90,   6180,    400,   0
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
slumps = list(JayBath = c(87, 105), LogWallow = c(40, 98), ReflectionPond = c(45, 64))

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
  args = list(core = core, coredir = coredir, thick = 5,
              slump = slumps[[core]], remove = FALSE,
              acc.mean = 50, acc.shape = 1.5, mem.mean = 0.5, mem.strength = 10,
              suggest = FALSE, ask = FALSE, remember = FALSE,
              plot.pdf = TRUE, seed = 42, verbose = TRUE)
  if (!is.null(d_max[[core]])) args$d.max = d_max[[core]]
  do.call(Bacon, args)
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
Bacon(core = "PantherPotholes", coredir = coredir, thick = 5,
      d.min = 0, d.max = 870, d.by = 0.5,
      slump = pp_slump, remove = FALSE,
      acc.mean = 10, acc.shape = 1.5, mem.mean = 0.7, mem.strength = 10,
      cc = 1, cc1 = "IntCal20", normal = FALSE, t.a = 15, t.b = 16, ssize = 10000,
      suggest = FALSE, ask = FALSE, remember = FALSE,
      plot.pdf = TRUE, seed = 42, verbose = TRUE)

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
PB210_ASSUMED_ERROR = 10
PB210_ROBUSTNESS    = c()   # set to c(15, 20) to rebuild the table above

pp_dates_pb = pp_dates %>%
  mutate(Error = ifelse(grepl("^Pb210_", ID), PB210_ASSUMED_ERROR, Error))
cat("\n210Pb errors - published (DPM/g activity, mis-entered as years) vs ASSUMED:\n")
print(pp_dates %>% filter(grepl("^Pb210_", ID)) %>%
        transmute(ID, Depth, Age, published_error = Error,
                  assumed_error = PB210_ASSUMED_ERROR))
write_core_files("PantherPotholes_pb210err", pp_dates_pb)

Bacon(core = "PantherPotholes_pb210err", coredir = coredir, thick = 5,
      d.min = 0, d.max = 870, d.by = 0.5,
      slump = pp_slump, remove = FALSE,
      acc.mean = 10, acc.shape = 1.5, mem.mean = 0.7, mem.strength = 10,
      cc = 1, cc1 = "IntCal20", normal = FALSE, t.a = 15, t.b = 16, ssize = 10000,
      suggest = FALSE, ask = FALSE, remember = FALSE,
      plot.pdf = TRUE, seed = 42, verbose = TRUE)

# Optional: rebuild the robustness table in the comment above. Off by default -
# each run is a full MCMC and adds several minutes to sourcing this script.
for (E in PB210_ROBUSTNESS) {
  nm = paste0("PantherPotholes_pbconst", E)
  write_core_files(nm, pp_dates %>%
    mutate(Error = ifelse(grepl("^Pb210_", ID), E, Error)))
  Bacon(core = nm, coredir = coredir, thick = 5,
        d.min = 0, d.max = 870, d.by = 0.5,
        slump = pp_slump, remove = FALSE,
        acc.mean = 10, acc.shape = 1.5, mem.mean = 0.7, mem.strength = 10,
        cc = 1, cc1 = "IntCal20", normal = FALSE, t.a = 15, t.b = 16, ssize = 10000,
        suggest = FALSE, ask = FALSE, remember = FALSE,
        plot.pdf = FALSE, seed = 42, verbose = FALSE)
}

# -------------------------
# 5) Pool Y & F ages from the dated cores
# -------------------------
JB <- read_bacon_ages("JayBath", coredir) %>% mutate(site = "JayBath")
LW <- read_bacon_ages("LogWallow", coredir) %>% mutate(site = "LogWallow")
RP <- read_bacon_ages("ReflectionPond", coredir) %>% mutate(site = "ReflectionPond")

age_depth = rbind(JB, LW, RP) %>%
  rename(year = median)%>%
  select(site, depth, year)

# Get paleo data ----
paleo_plots = data.frame(Location = c("JayBath", "LogWallow", "ReflectionPond")) %>%
  mutate(latitude = case_when(Location == "JayBath" ~ 46.7667,
                              Location == "LogWallow" ~ 46.7667,
                              Location == "ReflectionPond" ~ 46.7667)) %>%
  mutate(longitude = case_when(Location == "JayBath" ~ -121.7667,
                               Location == "LogWallow" ~ -121.75,
                               Location == "ReflectionPond" ~ -121.7167))

paleo_coords = paleo_plots %>%
  select(longitude, latitude, Location) %>%
  distinct() %>%
  rename(id = Location)

paleo_coords_sf = paleo_coords %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Get MORA/NOCA data for species matching ----
NOCA_occ = read_csv(here("output/NOCA_occ.csv"))
MORA_occ = read_csv(here("output/MORA_occ.csv"))

occ = bind_rows(NOCA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "NOCA"),
                MORA_occ %>% select(period, plot_id, species, occurrence) %>% mutate(site = "MORA")) %>%
  mutate(era = "anthropocene") %>%
  filter(!species %in% c("unknown", "Abies sp.", "Salix sp."))

# Harmonize species ----
takeoutpaleosp = c("Carex Achenes Lenticular", "Carex Achenes Trigonous", 
                   "Isoetes Megaspores", "Nuphar Polysepalum Seeds",
                   "Potamogeton Species Achenes", "Ranunculus CF Aquatilis Achenes",
                   "Juncus Seeds", "Sparganium Seeds", "Phyllodoce Leaves",
                   "Abies-Type Seeds", "Tsuga-Type Seeds")
paleo_occ = read_excel(here("data/PALEO/DunwiddieMacrofossils.xlsx"), sheet = "MacrofossilData")
paleo_occ = paleo_occ %>%
  rename(species = Species) %>%
  filter(!species %in% takeoutpaleosp)%>%
  mutate(
    species = str_squish(species),
    species = case_when(
      species == "Abies Amabilis" ~ "Abies amabilis",
      species == "Abies Lasiocarpa" ~ "Abies lasiocarpa",
      species == "Abies Procera" ~ "Abies procera",
      species %in% c("Pinus Contorta Fascilcles", "Pinus Contorta Fascicles",
                     "Pinus Contorta Needle Fragments") ~ "Pinus contorta",
      species %in% c("Pinus Monticola Fascicles", "Pinus Monticola Needle Fragments",
                     "Pinus Montocola Needle Fragments") ~ "Pinus monticola",
      species == "Picea Engelmannii" ~ "Picea engelmannii",
      species == "Pseudotsuga Menziesii" ~ "Pseudotsuga menziesii",
      species == "Tsuga Heterophylla" ~ "Tsuga heterophylla",
      species %in% c("Tsuga Mertensiana", "Tsuga Mertinsiana") ~ "Tsuga mertensiana",
      species %in% c("Chamaecyparis", "Chamaecyparis Seeds") ~ "Callitropsis nootkatensis",
      species %in% c("Needle Concentration (per CC)", "Needle Concentration (Per CC)") ~ "needle_concentration",
      species == "Charcoal Fragments" ~ "charcoal_fragments",
      species == "Charred Needles" ~ "charred_needles",
      TRUE ~ species
    )
  )


paleo_occ = 
  paleo_occ %>%
  rename(site = Location, depth = Depth)%>%
  select(site, species, depth, Percentage)%>%
  left_join(age_depth)
  
#Get fire info
fire_walsh = read_csv(here("output", "fire_walsh.csv"))

paleo_fire = 
  paleo_occ %>%
  filter(species %in% c("charred_needles", "needle_concentration", "charcoal_fragments"))%>%
  pivot_wider(names_from = species, values_from = Percentage)

dim(paleo_fire) #119

paleo_prev_fire = paleo_fire %>%
  # join any fire that is BEFORE the paleo year (older in cal yr BP)
  left_join(fire_walsh, by = join_by(year <= age_cal_yr_BP),
            relationship = "many-to-many") %>%
  # filter to fires within 50 years and keep the nearest earlier event
  filter(is.na(age_cal_yr_BP) | (age_cal_yr_BP - year <= 50)) %>%
  group_by(site, depth, year) %>%
  slice_min(age_cal_yr_BP, with_ties = FALSE) %>%
  ungroup() %>%
  # tidy names and calculate years before
  rename(
    fire_event_year_BP  = age_cal_yr_BP,
    fire_lake           = lake,
    fire_peak_magnitude = peak_magnitude,
    fire_is_significant = is_significant
  ) %>%
  mutate(
    years_before_fire = fire_event_year_BP - year,
    has_fire_within_50yr = !is.na(fire_event_year_BP)
  ) %>%
  filter(!is.na(year))%>%
  filter(fire_is_significant)

paleo_fire = 
  paleo_prev_fire %>%
  select(site, depth, year, charcoal_fragments, needle_concentration, charred_needles, fire_lake, fire_peak_magnitude, years_before_fire)%>%
  right_join(paleo_fire)%>%
  mutate(plot_id = paste0(site, "_", year, "_BP"))%>%
  mutate(period = "paleo")%>%
  rename(lake = site)

paleo_fire = 
  paleo_fire %>%
  mutate(charred_needles = ifelse(is.na(charred_needles), 0, charred_needles),
         fire_peak_magnitude = ifelse(is.na(fire_peak_magnitude), 0, fire_peak_magnitude),
         years_before_fire = ifelse(is.na(years_before_fire), 0, years_before_fire),
         fire_lake = ifelse(is.na(fire_lake), "no_fire_record", fire_lake)
         )

paleo_occ = 
  paleo_occ %>%
  filter(!species %in% c("charred_needles", "needle_concentration", "charcoal_fragments"))%>%
  mutate(occurrence = ifelse(Percentage>0, 1, 0))%>%
  mutate(plot_id = paste0(site, "_", year, "_BP"),
         lake = site,
         era = "holocene",
         period = "paleo",
         site = "MORA")%>%
  select(period, plot_id, species, occurrence, site, era, lake)%>%
  distinct()

paleo_env = read_csv(here("output", "climate_paleo_ponds_summary.csv"))

# Interpolate climate data to match paleo occurrence years ----

# Get climate data range
max_climate_year = abs(min(paleo_env$period))  # Convert -6000 to 6000
print(paste("Climate data available from 0 to", max_climate_year, "years BP"))

# Create fine-resolution years for interpolation (every year)
fine_years = 0:max_climate_year

# Climate variables to interpolate
climate_vars = c("MAT", "MSpT", "MST", "MWT", "AP", "SpP", "SP", "WP")

paleo_env = 
  paleo_env %>% 
  rename(lake = plot_id)

# Interpolate climate for each site
interpolated_list = map(unique(paleo_env$lake), function(lake_name) {

  # Get climate data for this site and convert to positive years
  site_data = paleo_env %>%
    filter(lake == lake_name) %>%
    mutate(year_positive = abs(period)) %>%
    arrange(year_positive)

  # Interpolate each climate variable
  interpolated_site = tibble(
    lake = lake_name,
    year = fine_years,
    plot_id = paste0(fine_years, "_BP")
  )

  for (var in climate_vars) {
    spline_fit = smooth.spline(site_data$year_positive, site_data[[var]], spar = 0.3)
    interpolated_site[[var]] = predict(spline_fit, fine_years)$y
  }

  return(interpolated_site)
})

# Combine all sites
interpolated_climate = bind_rows(interpolated_list) %>%
  mutate(site = "MORA", era = "holocene", period = "paleo") %>%
  select(site, lake, era, period, plot_id, everything(), -year)%>%
  mutate(plot_id = paste0(lake, "_", plot_id))

# Join with paleo occurrence data
paleo_env = paleo_occ %>%
  left_join(interpolated_climate)%>%
  select(-species, -occurrence)%>%
  distinct()
  
  

# NOCA paleo: Panther Potholes core ----
# Macrofossil counts: Neotoma dataset 52207, site 13042 (Prichard et al. 2009).
# Ages: OUR Bacon run from section 4b, NOT the "Gavin 2021" column in this file.
# Both describe the same chronology - our medians reproduce Gavin's to a median
# of 14 yr over a 10,600 yr record - but Neotoma publishes only three quantiles
# per level, and the interval metrics need the full posterior (see SOURCES.md and
# the note at section 3b). Taking ages from our own run keeps the point estimates
# and the draws from one and the same model.
# Mirrors the MORA paleo_occ structure (one plot_id per dated sample). Charcoal is
# NOT in this file, so NOCA paleo enters paleo_occ and paleo_env (via the
# CHELSA-TraCE21k lake climate below) but not paleo_fire.
noca_raw = read_csv(here("data/NOCA/NOCA_paleo/dataset52207_site13042.csv"),
                    show_col_types = FALSE)
noca_desc = c("name", "group", "element", "units", "context")
noca_samples = setdiff(names(noca_raw), noca_desc)

# Per-sample depth, and the age our Bacon model gives at that depth.
# Sample depths are 0.5, 1.5, ... 869.5; Bacon was run with d.by = 0.5, so every
# sample depth is on the output grid and approx() is an exact lookup, not a
# smoothing step. The Gavin column is retained alongside purely as a check.
noca_bacon = read_bacon_ages("PantherPotholes", coredir)

noca_meta = noca_raw %>%
  filter(name %in% c("Depth", "Gavin 2021")) %>%
  select(name, all_of(noca_samples)) %>%
  pivot_longer(-name, names_to = "sample", values_to = "value") %>%
  pivot_wider(names_from = name, values_from = value) %>%
  transmute(
    sample,
    depth      = as.numeric(Depth),
    year       = round(approx(noca_bacon$depth, noca_bacon$median, depth)$y),
    year_gavin = as.numeric(str_split_i(`Gavin 2021`, "/", 2))
  )

# Report the agreement rather than assume it.
cat("\nPantherPotholes ages, ours vs Gavin 2021 (cal yr BP):\n")
print(summary(noca_meta$year - noca_meta$year_gavin))
stopifnot(!any(is.na(noca_meta$year)))
noca_meta = noca_meta %>% select(sample, depth, year)

# Tree/shrub macrofossils -> harmonized species (drop genus/family "undiff.")
noca_paleo_occ = noca_raw %>%
  filter(group == "TRSH") %>%
  mutate(species = case_when(
    name == "Abies lasiocarpa"       ~ "Abies lasiocarpa",
    name == "Cupressus nootkatensis" ~ "Callitropsis nootkatensis",
    name == "Picea engelmannii"      ~ "Picea engelmannii",
    name == "Pinus contorta"         ~ "Pinus contorta",
    name == "Pinus monticola"        ~ "Pinus monticola",
    name == "Pseudotsuga menziesii"  ~ "Pseudotsuga menziesii",
    name == "Thuja plicata"          ~ "Thuja plicata",
    name == "Tsuga heterophylla"     ~ "Tsuga heterophylla",
    name == "Tsuga mertensiana"      ~ "Tsuga mertensiana",
    name == "Juniperus communis"     ~ "Juniperus communis",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(species)) %>%
  select(species, all_of(noca_samples)) %>%
  pivot_longer(-species, names_to = "sample", values_to = "count") %>%
  mutate(count = replace_na(as.numeric(count), 0)) %>%
  group_by(species, sample) %>%
  summarize(count = sum(count), .groups = "drop") %>%
  left_join(noca_meta, by = "sample") %>%
  mutate(
    occurrence = ifelse(count > 0, 1, 0),
    lake = "PantherPotholes",
    site = "NOCA",
    era  = "holocene",
    period = "paleo",
    plot_id = paste0(lake, "_", year, "_BP")
  ) %>%
  select(period, plot_id, species, occurrence, site, era, lake) %>%
  distinct()

paleo_occ = bind_rows(paleo_occ, noca_paleo_occ)

# -----------------------------------------------------------------------------
# Collapse to ONE row per (plot_id, species)
# -----------------------------------------------------------------------------
# distinct() above left 71 (plot_id, species) pairs with TWO rows - one saying
# occurrence 0 and the other 1 - from two unrelated causes:
#
# MORA (59 pairs). Several raw categories map to one species, and they are
# recorded on DIFFERENT bases:
#   Pinus contorta   <- "Pinus Contorta Fascicles" / "...Fascilcles" (typo)
#                       / "Pinus Contorta Needle Fragments"
#   Pinus monticola  <- "Pinus Monticola Fascicles"
#                       / "Pinus Monticola Needle Fragments" / "...Montocola..." (typo)
#   Callitropsis nootkatensis <- "Chamaecyparis" / "Chamaecyparis Seeds"
#   Dunwiddie 1986 counted Pinus fascicles as needle equivalents but tallied
#   needle FRAGMENTS separately, and Fig. 2's caption states "Pinus fragments
#   ... are excluded from the needle sum". Seeds are likewise on their own basis.
#   So the percentages must NOT be summed - they are not commensurable. For a
#   presence/absence analysis it does not matter: any category above zero means
#   the species is present.
#
# NOCA (12 pairs, at PantherPotholes 2678 / 3785 / 7616 BP). Two different core
# DEPTHS whose ages round to the same year, so they share a plot_id. Same
# situation as macrofossil samples inside a slump: contemporaneous within dating
# resolution, so merging them is the honest reading.
#
# Both are handled by the same rule - present if present in any contributing row.
paleo_occ = paleo_occ %>%
  group_by(period, plot_id, species, site, era, lake) %>%
  summarize(occurrence = as.integer(any(occurrence == 1)), .groups = "drop") %>%
  select(period, plot_id, species, occurrence, site, era, lake)

# NOCA paleo lake climate: Panther Potholes (CHELSA-TraCE21k) ----
# Mirrors the MORA ponds processing in 02_get_climate_data.R (lines 628-748)
# and the interpolation above, so NOCA paleo enters the CCA with MWT/MST/WP/SpP.
panther_plots = data.frame(
  Location  = "PantherPotholes",
  latitude  = 48.65,
  longitude = -121.0333
)

## Precipitation: annual + seasonal sums ----
noca_pre_ponds =
  read_csv(here("output/noca_climate/pre.paleo.ponds.csv"), show_col_types = FALSE)[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "pre") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude  = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year  = as.numeric(str_extract(time, "^-?\\d+")) * 100,
    month = as.numeric(str_match(time, "^-?\\d+-(\\d{1,2})-")[, 2])
  ) %>%
  select(-location) %>%
  left_join(panther_plots, by = c("longitude", "latitude")) %>%
  filter(year < 0) %>%
  rename(plot_id = Location) %>%
  mutate(site = "NOCA", elevation = NA, aspect = NA, slope = NA)

noca_pre_summary = noca_pre_ponds %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
  summarize(annual_sum = sum(pre, na.rm = TRUE), .groups = "drop")

noca_pre_seasonal = noca_pre_ponds %>%
  mutate(
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5)  ~ "spring",
      month %in% c(6, 7, 8)  ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(season)) %>%
  group_by(site, plot_id, elevation, aspect, slope, season,
           year = if_else(season == "winter", winter_year, year)) %>%
  summarize(sum_pre = sum(pre, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = season, values_from = sum_pre, names_prefix = "sum_")

noca_pre_summary = noca_pre_summary %>%
  left_join(noca_pre_seasonal, by = c("site", "plot_id", "year", "elevation", "aspect", "slope"))

## Temperature: annual + seasonal means (K -> C) ----
noca_tasmin_ponds =
  read_csv(here("output/noca_climate/tasmin.paleo.ponds.csv"), show_col_types = FALSE)[, -1] %>%
  pivot_longer(cols = -time, names_to = "location", values_to = "tasmin") %>%
  mutate(
    longitude = as.numeric(str_extract(location, "(?<=lon:)[^_]+")),
    latitude  = as.numeric(str_extract(location, "(?<=lat:)[^_]+")),
    year  = as.numeric(str_extract(time, "^-?\\d+")) * 100,
    month = as.numeric(str_match(time, "^-?\\d+-(\\d{1,2})-")[, 2])
  ) %>%
  select(-location) %>%
  left_join(panther_plots, by = c("longitude", "latitude")) %>%
  filter(year < 0) %>%
  rename(plot_id = Location) %>%
  mutate(site = "NOCA", elevation = NA, aspect = NA, slope = NA)

noca_tasmin_summary = noca_tasmin_ponds %>%
  group_by(site, plot_id, elevation, aspect, slope, year) %>%
  summarize(annual_mean = mean(tasmin, na.rm = TRUE), .groups = "drop")

noca_tasmin_seasonal = noca_tasmin_ponds %>%
  mutate(
    winter_year = if_else(month == 12, year + 1, year),
    season = case_when(
      month %in% c(12, 1, 2) ~ "winter",
      month %in% c(3, 4, 5)  ~ "spring",
      month %in% c(6, 7, 8)  ~ "summer",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(season)) %>%
  group_by(site, plot_id, elevation, aspect, slope, season,
           year = if_else(season == "winter", winter_year, year)) %>%
  summarize(mean_temp = mean(tasmin, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = season, values_from = mean_temp, names_prefix = "mean_") %>%
  rename(winter_mean = mean_winter)

noca_tasmin_summary = noca_tasmin_summary %>%
  left_join(noca_tasmin_seasonal, by = c("site", "plot_id", "year", "elevation", "aspect", "slope")) %>%
  mutate(annual_mean = annual_mean - 273.15,
         mean_spring = mean_spring - 273.15,
         mean_summer = mean_summer - 273.15,
         winter_mean = winter_mean - 273.15)

## Combine and interpolate to fine years (mirror of the MORA block above) ----
noca_ponds_summary = left_join(noca_tasmin_summary, noca_pre_summary) %>%
  rename(MAT = annual_mean, MSpT = mean_spring, MST = mean_summer, MWT = winter_mean,
         AP = annual_sum, SpP = sum_spring, SP = sum_summer, WP = sum_winter) %>%
  mutate(era = "holocene") %>%
  rename(lake = plot_id) %>%
  mutate(period = year)

noca_max_year = abs(min(noca_ponds_summary$period))
noca_fine_years = 0:noca_max_year

noca_interp_list = map(unique(noca_ponds_summary$lake), function(lake_name) {
  site_data = noca_ponds_summary %>%
    filter(lake == lake_name) %>%
    mutate(year_positive = abs(period)) %>%
    arrange(year_positive)

  interpolated_site = tibble(
    lake = lake_name,
    year = noca_fine_years,
    plot_id = paste0(noca_fine_years, "_BP")
  )

  for (var in climate_vars) {
    spline_fit = smooth.spline(site_data$year_positive, site_data[[var]], spar = 0.3)
    interpolated_site[[var]] = predict(spline_fit, noca_fine_years)$y
  }

  interpolated_site
})

noca_interpolated_climate = bind_rows(noca_interp_list) %>%
  mutate(site = "NOCA", era = "holocene", period = "paleo") %>%
  select(site, lake, era, period, plot_id, everything(), -year) %>%
  mutate(plot_id = paste0(lake, "_", plot_id))

noca_paleo_env = noca_paleo_occ %>%
  left_join(noca_interpolated_climate) %>%
  select(-species, -occurrence) %>%
  distinct()

paleo_env = bind_rows(paleo_env, noca_paleo_env)

# Save results
write_csv(paleo_env, here("output", "paleo_env.csv"))
write_csv(paleo_occ, here("output", "paleo_occ.csv"))
write_csv(paleo_fire, here("output", "paleo_fire.csv"))


