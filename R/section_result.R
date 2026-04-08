# Internal constructor for review section results.
#
# A `section_result` object captures the output of a single review section,
# including the long-form body and the concise summary used for later
# diagnostics and synthesis.
#
# @param section_id Single section identifier.
# @param title Single section title.
# @param body Single section body.
# @param summary Single concise section summary.
# @param evidence_used Character vector of evidence identifiers used.
# @param warnings Character vector of section warnings.
# @param trace Named list containing section generation trace metadata.
#
# @return A validated `pkgreviewr_section_result` object.
# @keywords internal
# @noRd
new_section_result <- function(section_id,
                               title,
                               body,
                               summary,
                               evidence_used = character(),
                               warnings = character(),
                               trace = list(status = "success", attempts = list(), final_error = NULL)) {
  section_result <- list(
    section_id = section_id,
    title = title,
    body = body,
    summary = summary,
    evidence_used = evidence_used,
    warnings = warnings,
    trace = trace
  )

  class(section_result) <- c("pkgreviewr_section_result", "list")
  validate_section_result(section_result)
}

# Internal validator for `section_result` objects.
#
# @param section_result Object to validate.
#
# @return The validated `section_result` object.
# @keywords internal
# @noRd
validate_section_result <- function(section_result) {
  if (!inherits(section_result, "pkgreviewr_section_result")) {
    stop("`section_result` must inherit from 'pkgreviewr_section_result'.", call. = FALSE)
  }

  required_fields <- c(
    "section_id",
    "title",
    "body",
    "summary",
    "evidence_used",
    "warnings",
    "trace"
  )
  missing_fields <- setdiff(required_fields, names(section_result))

  if (length(missing_fields) > 0) {
    stop(
      sprintf(
        "`section_result` is missing required field(s): %s.",
        paste(missing_fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  scalar_fields <- c("section_id", "title", "body", "summary")

  for (field in scalar_fields) {
    value <- section_result[[field]]

    if (!is.character(value) || length(value) != 1 || !nzchar(value)) {
      stop(
        sprintf("`section_result$%s` must be a single non-empty string.", field),
        call. = FALSE
      )
    }
  }

  vector_fields <- c("evidence_used", "warnings")

  for (field in vector_fields) {
    value <- section_result[[field]]

    if (!is.character(value)) {
      stop(
        sprintf("`section_result$%s` must be a character vector.", field),
        call. = FALSE
      )
    }
  }

  if (!is.list(section_result$trace)) {
    stop("`section_result$trace` must be a list.", call. = FALSE)
  }

  section_result
}
