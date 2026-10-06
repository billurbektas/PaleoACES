# =============================================================================
# test_paleo_surface_years.R - which product can serve the top of the cores?
# =============================================================================
# Reassesses the paleo surface-coverage decision recorded in docs/SCIENTIFIC_DECISIONS.md:
# climate from TraCE21k, core tops included.
#
# The core tops reach 1999 CE, well inside the instrumental era, so it is natural
# to ask whether they should come from an observational product instead. This
# script counts how many samples each product could actually serve. Verified
# 2026-08-12:
#
#   cruts        1901-2016   ->  41 of 41
#   V2.1 daily temperature   ->  22 of 41   (1941+)
#   V2.1 pr / monthly        ->   9 of 41   (1979+)
#
# The answer is nevertheless TraCE21k for all of them, because:
#
#   The Holocene arm bins at 500 yr, so it was never going to resolve
#   within-century change anyway; those samples all land in the youngest bin
#   regardless, which averages slices 16-20. Detecting 20th-century climate
#   change is the Anthropocene arm's job, from the survey plots.
#
# Reads output/paleo_occ.csv only - no downloads.
# =============================================================================

library(here)
suppressMessages({library(dplyr); library(readr)})

a = read_csv(here("output/paleo_occ.csv"), show_col_types = FALSE) %>%
  distinct(lake, plot_id) %>%
  mutate(age     = as.numeric(regmatches(plot_id,
                     regexpr("-?[0-9.]+(?=_BP$)", plot_id, perl = TRUE))),
         year_CE = 1950 - age)

stopifnot(!any(is.na(a$age)))

cat("all paleo samples: ", nrow(a), "\n", sep = "")
print(as.data.frame(
  a %>% group_by(lake) %>%
    summarise(n = n(), youngest_CE = max(year_CE), oldest_calBP = max(age),
              .groups = "drop")))

# --- the post-1900 samples ---------------------------------------------------
young = a %>% filter(age < 50) %>% arrange(age)
cat("\nsamples younger than 50 cal BP (after 1900 CE): ", nrow(young),
    "  spanning ", min(young$year_CE), "-", max(young$year_CE), " CE\n", sep = "")
print(as.data.frame(young %>% count(lake, name = "n")))

# --- product coverage, bounds from test_chelsa_coverage.R --------------------
cov = tibble::tribble(
  ~product,                     ~from, ~to,
  "CHELSAcruts",                 1901,  2016,
  "V2.1 daily tasmin/tasmax",    1941,  2025,
  "V2.1 daily pr",               1979,  2019,
  "V2.1 monthly (all vars)",     1979,  2021
) %>%
  rowwise() %>%
  mutate(n_of_post1900 = sum(young$year_CE >= from & young$year_CE <= to),
         n_of_all = sum(a$year_CE >= from & a$year_CE <= to)) %>%
  ungroup()

cat("\n--- how many of the ", nrow(young),
    " post-1900 samples each product could serve ---\n", sep = "")
print(as.data.frame(cov))

# --- the decisive point ------------------------------------------------------
cat("\n--- why it does not matter: TraCE21k resolution vs sample spread ---\n")
span = max(young$year_CE) - min(young$year_CE)
cat("the ", nrow(young), " samples span ", span,
    " yr; TraCE21k slices are ~100 yr apart,\n",
    "so they fall in ", length(unique(round(young$year_CE / 100))),
    " slice(s) and receive at most that many distinct climate values.\n", sep = "")
cat("Delta climate between them is therefore ~0 by construction - which is fine,\n",
    "within either the primary 1,000-year bins or the 500-year sensitivity.\n", sep = "")

cat("\nfull list:\n")
print(as.data.frame(young %>% select(lake, year_CE, cal_BP = age)), row.names = FALSE)
