# Stop before invalid cache removal or network access in explicitly offline runs.
require_offline_cache = function(paths, valid, label) {
  if (!isTRUE(getOption("paleoaces.offline", FALSE))) return(invisible(NULL))
  invalid = paths[is.na(valid) | !valid]
  if (length(invalid)) stop("Offline ", label, ": ", length(invalid),
    " missing or invalid native cache chunk(s). Restore or refresh these in an online run: ",
    paste(head(basename(invalid), 12L), collapse = ", "), call. = FALSE)
  invisible(NULL)
}
