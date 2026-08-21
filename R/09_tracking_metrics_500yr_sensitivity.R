# =============================================================================
# 09_tracking_metrics_500yr_sensitivity.R
# =============================================================================
# Explicit sensitivity companion to the authoritative 1,000-year tracking run.
# It writes only names carrying `_500yr`; Anthropocene tables are regenerated
# identically and are overwritten by the primary stage when run in workflow
# order. No model, score scaling, climate cache, or Bacon output is changed.

TRACKING_OUTPUT_SUFFIX = "_500yr"
sys.source(here::here("R/09_tracking_metrics.R"), envir = environment())
