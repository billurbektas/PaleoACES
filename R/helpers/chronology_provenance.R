# Resolve historical chronology hashes only for the exact recorded substitutions
# (relocated paths and authorized figure-caption and typography changes).
# Any other source edit uses the physical file identity and invalidates old caches.
chronology_source_identity = function(path, actual_path = here::here(path)) {
  physical_md5 = unname(tools::md5sum(actual_path))
  result = list(path = normalizePath(actual_path, mustWork = TRUE),
                md5 = physical_md5, historical_path = NULL,
                historical_md5 = NULL, historical_source = NULL)
  bridge = jsonlite::fromJSON(
    here::here("Cores/provenance/chronology_relocation.json"),
    simplifyVector = FALSE)
  entries = Filter(function(x) identical(x$current_path, path), bridge$files)
  if (length(entries) != 1L) stop("Missing chronology relocation record: ", path)
  entry = entries[[1L]]
  snapshot = here::here(entry$snapshot)
  if (!file.exists(snapshot) ||
      !identical(digest::digest(file = snapshot, algo = "sha256"), entry$original_sha256) ||
      !identical(unname(tools::md5sum(snapshot)), entry$original_md5))
    stop("Invalid historical chronology source snapshot: ", entry$snapshot)
  read_bytes = function(file) readBin(file, "raw", n = file.info(file)$size)
  expected = rawToChar(read_bytes(snapshot))
  for (replacement in entry$replacements)
    expected = gsub(replacement$old, replacement$new, expected, fixed = TRUE)
  if (identical(read_bytes(actual_path), charToRaw(expected))) {
    result$historical_path = here::here(entry$original_path)
    result$historical_md5 = entry$original_md5
    result$historical_source = snapshot
  }
  result
}

chronology_md5_candidates = function(identity)
  unique(c(identity$md5, identity$historical_md5))
