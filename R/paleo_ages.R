# =============================================================================
# paleo_ages.R - read the Bacon chronologies written by 000_PALEO_a_agedepth.R
# =============================================================================
# Shared by 000_PALEO_b_vegetation.R, 000_PALEO_c_fire.R and
# 000_PALEO_e_climate.R so the age lookup is defined once. Contains NO side
# effects: sourcing it reads Cores/ and defines objects, and writes nothing.
#
# Run 000_PALEO_a_agedepth.R first (four MCMC runs, ~25 min). Everything here is
# fast and can be re-run on its own.
# =============================================================================

# Reads <core>_<K>_ages.txt written by 000_PALEO_a. Prefers the unsuffixed file,
# else the most recent suffixed one - so a stale file from a different K would be
# a problem; 000_PALEO_a's reset_core() deletes them before every run.
read_bacon_ages <- function(core, coredir = file.path(here::here(), "Cores")) {
  f1 <- file.path(coredir, core, paste0(core, "_ages.txt"))
  if (file.exists(f1)) {
    df <- read.table(f1, header = TRUE)
    names(df) <- tolower(names(df))
    return(df)
  }
  cand <- Sys.glob(file.path(coredir, core, paste0(core, "_*_ages.txt")))
  if (length(cand) == 0)
    stop("No *_ages.txt found for core '", core, "' in ", file.path(coredir, core),
         " - run R/000_PALEO_a_agedepth.R first.")
  latest <- cand[which.max(file.info(cand)$mtime)]
  df <- read.table(latest, header = TRUE)
  names(df) <- tolower(names(df))
  df
}

coredir <- file.path(here::here(), "Cores")

# Pooled depth -> median age for the three MORA cores. PantherPotholes is read
# separately where it is needed, because its ages are matched to sample depths by
# approx() rather than joined on depth.
age_depth <- rbind(
  read_bacon_ages("JayBath",        coredir) |> transform(site = "JayBath"),
  read_bacon_ages("LogWallow",      coredir) |> transform(site = "LogWallow"),
  read_bacon_ages("ReflectionPond", coredir) |> transform(site = "ReflectionPond")
)
names(age_depth)[names(age_depth) == "median"] <- "year"
age_depth <- age_depth[, c("site", "depth", "year")]
