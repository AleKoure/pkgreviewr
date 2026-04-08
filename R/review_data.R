# Internal constructor for collected review data.
#
# A `review_data` object carries deterministic signals gathered from a package
# review run. It is an internal contract used to separate collection from later
# rendering and section generation.
#
# @param package_ref Single package or repository reference.
# @param source_path Single path to the acquired source tree.
# @param signals Named list of collected review signals.
# @param metadata List of auxiliary metadata.
#
# @return A validated `pkgreviewr_review_data` object.
# @keywords internal
# @noRd
new_review_data <- function(package_ref,
                            source_path,
                            signals,
                            metadata = list()) {
  review_data <- list(
    package_ref = package_ref,
    source_path = source_path,
    signals = signals,
    metadata = metadata
  )

  class(review_data) <- c("pkgreviewr_review_data", "list")
  validate_review_data(review_data)
}

# Internal validator for `review_data` objects.
#
# @param review_data Object to validate.
#
# @return The validated `review_data` object.
# @keywords internal
# @noRd
validate_review_data <- function(review_data) {
  if (!inherits(review_data, "pkgreviewr_review_data")) {
    stop("`review_data` must inherit from 'pkgreviewr_review_data'.", call. = FALSE)
  }

  required_fields <- c("package_ref", "source_path", "signals", "metadata")
  missing_fields <- setdiff(required_fields, names(review_data))

  if (length(missing_fields) > 0) {
    stop(
      sprintf(
        "`review_data` is missing required field(s): %s.",
        paste(missing_fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!is.character(review_data$package_ref) || length(review_data$package_ref) != 1) {
    stop("`review_data$package_ref` must be a single string.", call. = FALSE)
  }

  if (!is.character(review_data$source_path) || length(review_data$source_path) != 1) {
    stop("`review_data$source_path` must be a single string.", call. = FALSE)
  }

  if (!is.list(review_data$signals) || is.null(names(review_data$signals))) {
    stop("`review_data$signals` must be a named list.", call. = FALSE)
  }

  if (!is.list(review_data$metadata)) {
    stop("`review_data$metadata` must be a list.", call. = FALSE)
  }

  review_data
}

# Internal builder for `review_data` objects.
#
# @param package_ref Single package or repository reference.
# @param source_path Single path to the acquired source tree.
# @param package_code Extracted package code.
# @param coverage_report Coverage output.
# @param lint_report Lint output.
# @param rcmd_check_report `R CMD check` output.
# @param session_info Session information from the check step.
#
# @return A validated `pkgreviewr_review_data` object.
# @keywords internal
# @noRd
build_review_data <- function(package_ref,
                              source_path,
                              package_code,
                              coverage_report,
                              lint_report,
                              rcmd_check_report,
                              session_info) {
  signals <- list(
    package_code = package_code,
    coverage_report = coverage_report,
    lint_report = lint_report,
    rcmd_check_report = rcmd_check_report,
    session_info = session_info
  )

  metadata <- list(
    signal_names = names(signals)
  )

  new_review_data(
    package_ref = package_ref,
    source_path = source_path,
    signals = signals,
    metadata = metadata
  )
}

# Internal formatter for legacy single-prompt report generation.
#
# @param review_data A validated `review_data` object.
#
# @return A single character string containing all collected signals.
# @keywords internal
# @noRd
format_review_data <- function(review_data) {
  review_data <- validate_review_data(review_data)

  sections <- lapply(names(review_data$signals), function(signal_name) {
    signal_value <- review_data$signals[[signal_name]]

    paste(
      "-------------------------",
      "-------------------------",
      signal_name,
      "-------------------------",
      "-------------------------",
      paste(signal_value, collapse = "\n"),
      sep = "\n"
    )
  })

  paste(unlist(sections, use.names = FALSE), collapse = "\n")
}
