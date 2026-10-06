# Portable report integrity gate; does not require local data or result tables.
suppressPackageStartupMessages(library(here))
source(here("R/helpers/analysis_report.R"))
report_python("--validate")
