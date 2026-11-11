# =============================================================================
# climate_variables.R - THE definition of the climate variables. Used by BOTH arms.
# =============================================================================
# Sourced by 08_paleo_climate.R (Holocene) and 11_cca.R (Anthropocene).
# If the two arms ever define a season differently - DJF vs JF, tasmin vs the
# tasmin/tasmax mean - then MWT means two different things, the CCA is calibrated
# on one and projected with the other, and the resulting displacement is
# indistinguishable from a real lag. So the definitions live here and nowhere else.
#
# Input: long monthly table with columns
#   unit (lake or plot_id), period, variable in {tasmin,tasmax,pr}, time, month, value
# where `time` is a calendar year (Anthropocene) or a TraCE21k slice (Holocene).
#
# Output: one row per unit x period x time with
#   MAT_min  MSpT_min  MST_min  MWT_min     from tasmin  (what the old pipeline used)
#   MAT_max  MSpT_max  MST_max  MWT_max     from tasmax  (newly available)
#   MAT      MSpT      MST      MWT         from the midpoint (tasmin+tasmax)/2
#   AP       SpP       SP       WP          precipitation sums
#
# ⚠ THE OLD PIPELINE'S MWT/MST WERE MINIMUM TEMPERATURES, not means - only tasmin
# was ever downloaded. Both are produced here so variable sensitivities can choose without a
# re-download. Set TEMP_SOURCE below to pick which one the unsuffixed names map to.
#
# WINTER YEAR. For calendar years, December belongs to the FOLLOWING winter, so it
# is shifted (winter 1980 = Dec 1979 + Jan/Feb 1980). For TraCE21k slices that shift
# is meaningless - slices are ~100 yr apart, so shifting December moves it a century
# and strands it in a group of its own. Pass winter_shift = FALSE for paleo.
# (The archived pipeline shifted paleo Decembers by +1 on a year = slice*100 scale,
# which did exactly that. Fixed here.)
# =============================================================================

suppressMessages({library(dplyr); library(tidyr)})

# "mean" = (tasmin + tasmax)/2, a mean-extrema proxy - decided 2026-08-12, now
# that tasmax is downloaded. "min" reproduces the old pipeline, whose MWT/MST were
# really mean winter/summer MINIMUM temperature because only tasmin was ever fetched.
# Keep "min" available for the old-vs-new comparison, but "mean" is the analysis.
TEMP_SOURCE = "mean"

WINTER = c(12, 1, 2)
SPRING = c(3, 4, 5)
SUMMER = c(6, 7, 8)

derive_climate_vars <- function(x, winter_shift = TRUE, temp_source = TEMP_SOURCE) {

  need <- c("unit", "period", "variable", "time", "month", "value")
  miss <- setdiff(need, names(x))
  if (length(miss)) stop("derive_climate_vars(): missing column(s): ",
                         paste(miss, collapse = ", "))
  keys <- c("unit", "period", "variable", "time", "month")
  if (anyNA(x[keys]) || anyDuplicated(x[keys]))
    stop("derive_climate_vars(): monthly keys must be nonmissing and unique")
  if (!is.numeric(x$value) || any(!is.finite(x$value)))
    stop("derive_climate_vars(): monthly values must be finite; omit unavailable months")
  if (!is.numeric(x$month) || any(!x$month %in% 1:12) ||
      !is.numeric(x$time) || any(!is.finite(x$time)))
    stop("derive_climate_vars(): invalid month or time")
  if (!all(c("tasmin", "tasmax") %in% x$variable) ||
      any(!x$variable %in% c("tasmin", "tasmax", "pr")))
    stop("derive_climate_vars(): expected tasmin/tasmax and optional pr")
  if (length(temp_source) != 1L || !temp_source %in% c("mean", "min", "max"))
    stop("derive_climate_vars(): invalid temperature source")

  # --- ALIGN THE VARIABLES: keep only months present for ALL of them ----------
  # Done HERE, not in the callers, so it cannot be forgotten. Without it a month
  # that exists for pr but not for tasmin/tasmax (CHELSA is missing tasmin/tasmax
  # for JANUARY 1979) gives AP a year that MAT does not have, and the two describe
  # different periods. Idempotent - callers that already aligned lose nothing.
  vars_present <- unique(x$variable)
  keep <- x %>% distinct(unit, period, time, month, variable) %>%
    count(unit, period, time, month, name = "n_var") %>%
    filter(n_var == length(vars_present)) %>%
    select(unit, period, time, month)
  n_before <- nrow(x)
  x <- x %>% semi_join(keep, by = c("unit", "period", "time", "month"))
  if (nrow(x) < n_before)
    message("derive_climate_vars(): dropped ", n_before - nrow(x),
            " row(s) in months not shared by all ", length(vars_present),
            " variables, so every variable covers the same months")

  x <- x %>%
    mutate(season = case_when(month %in% WINTER ~ "W",
                              month %in% SPRING ~ "Sp",
                              month %in% SUMMER ~ "S",
                              TRUE ~ NA_character_),
           # December belongs to the following winter - calendar years only
           time_s = if (winter_shift) if_else(month == 12, time + 1, time) else time)

  # --- temperature: seasonal and annual MEANS ---------------------------------
  tmean <- x %>%
    filter(variable %in% c("tasmin", "tasmax")) %>%
    pivot_wider(names_from = variable, values_from = value) %>%
    mutate(mean = (tasmin + tasmax) / 2) %>%
    pivot_longer(c(tasmin, tasmax, mean), names_to = "src", values_to = "value") %>%
    mutate(src = recode(src, tasmin = "min", tasmax = "max", mean = "mean"))

  t_ann <- tmean %>% group_by(unit, period, time, src) %>%
    summarise(MAT = mean(value, na.rm = TRUE), .groups = "drop")

  # A season must have all THREE of its months, and the annual mean all twelve.
  # Otherwise "winter" silently means Feb-only in one year and DJF in another, and the
  # two are not comparable. Incomplete -> NA, so it is visible rather than averaged.
  t_ann <- t_ann %>%
    left_join(tmean %>% count(unit, period, time, src, name = "n_mo"),
              by = c("unit", "period", "time", "src")) %>%
    mutate(MAT = if_else(n_mo == 12, MAT, NA_real_)) %>% select(-n_mo)

  t_sea <- tmean %>% filter(!is.na(season)) %>%
    group_by(unit, period, src, season,
             time = if_else(season == "W", time_s, time)) %>%
    summarise(v = mean(value, na.rm = TRUE), n_mo = n(), .groups = "drop") %>%
    mutate(v = if_else(n_mo == 3, v, NA_real_)) %>% select(-n_mo) %>%
    mutate(name = recode(season, W = "MWT", Sp = "MSpT", S = "MST")) %>%
    select(-season) %>% pivot_wider(names_from = name, values_from = v)

  temp <- full_join(t_ann, t_sea, by = c("unit", "period", "time", "src")) %>%
    pivot_wider(names_from = src, values_from = c(MAT, MSpT, MST, MWT),
                names_glue = "{.value}_{src}")

  # --- precipitation: seasonal and annual SUMS --------------------------------
  # Same completeness rule, and it matters MORE for precipitation: a sum over two
  # months is not a smaller estimate of a three-month total, it is a wrong one.
  #
  # Guarded, because a variable sensitivity may drop precipitation entirely: called on a table
  # with no `pr` rows this used to fail in the final relocate(). It must be
  # possible to run the whole pipeline on temperature alone - that is exactly the
  # comparison the variable diagnostic needs (dropping pr frees MORA legacy temperature from
  # precipitation's 1979 start; see R/figures/supp_climate_correlations.R).
  out <- temp
  if ("pr" %in% vars_present) {
    p <- x %>% filter(variable == "pr")
    p_ann <- p %>% group_by(unit, period, time) %>%
      summarise(AP = sum(value, na.rm = TRUE), n_mo = n(), .groups = "drop") %>%
      mutate(AP = if_else(n_mo == 12, AP, NA_real_)) %>% select(-n_mo)
    p_sea <- p %>% filter(!is.na(season)) %>%
      group_by(unit, period, season, time = if_else(season == "W", time_s, time)) %>%
      summarise(v = sum(value, na.rm = TRUE), n_mo = n(), .groups = "drop") %>%
      mutate(v = if_else(n_mo == 3, v, NA_real_)) %>% select(-n_mo) %>%
      mutate(name = recode(season, W = "WP", Sp = "SpP", S = "SP")) %>%
      select(-season) %>% pivot_wider(names_from = name, values_from = v)
    prec <- full_join(p_ann, p_sea, by = c("unit", "period", "time"))
    out <- full_join(temp, prec, by = c("unit", "period", "time"))
  } else {
    message("derive_climate_vars(): no `pr` rows - returning temperature variables only")
  }

  # the unsuffixed names are what the CCA uses - point them at the chosen source
  sfx <- paste0("_", temp_source)
  for (v in c("MAT", "MSpT", "MST", "MWT")) out[[v]] <- out[[paste0(v, sfx)]]

  out %>% relocate(any_of(c("unit", "period", "time",
                            "MAT", "MSpT", "MST", "MWT", "AP", "SpP", "SP", "WP")))
}
