# Internal constructor for section context objects.
#
# A `section_context` object captures the deterministic inputs passed into a
# single review section prompt.
#
# @param section_id Single section identifier.
# @param title Single section title.
# @param focus Single section focus string.
# @param evidence_blocks Named list of rendered evidence blocks.
# @param evidence_used Character vector of evidence identifiers used.
#
# @return A validated `pkgreviewr_section_context` object.
# @keywords internal
# @noRd
new_section_context <- function(section_id,
                                title,
                                focus,
                                evidence_blocks = list(),
                                evidence_used = character()) {
  section_context <- list(
    section_id = section_id,
    title = title,
    focus = focus,
    evidence_blocks = evidence_blocks,
    evidence_used = evidence_used
  )

  class(section_context) <- c("pkgreviewr_section_context", "list")
  validate_section_context(section_context)
}

# Internal validator for `section_context` objects.
#
# @param section_context Object to validate.
#
# @return The validated `section_context` object.
# @keywords internal
# @noRd
validate_section_context <- function(section_context) {
  if (!inherits(section_context, "pkgreviewr_section_context")) {
    stop("`section_context` must inherit from 'pkgreviewr_section_context'.", call. = FALSE)
  }

  required_fields <- c(
    "section_id",
    "title",
    "focus",
    "evidence_blocks",
    "evidence_used"
  )
  missing_fields <- setdiff(required_fields, names(section_context))

  if (length(missing_fields) > 0) {
    stop(
      sprintf(
        "`section_context` is missing required field(s): %s.",
        paste(missing_fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  scalar_fields <- c("section_id", "title", "focus")

  for (field in scalar_fields) {
    value <- section_context[[field]]

    if (!is.character(value) || length(value) != 1 || !nzchar(value)) {
      stop(
        sprintf("`section_context$%s` must be a single non-empty string.", field),
        call. = FALSE
      )
    }
  }

  if (!is.list(section_context$evidence_blocks)) {
    stop("`section_context$evidence_blocks` must be a list.", call. = FALSE)
  }

  if (!is.character(section_context$evidence_used)) {
    stop("`section_context$evidence_used` must be a character vector.", call. = FALSE)
  }

  block_values <- unname(section_context$evidence_blocks)

  if (length(block_values) > 0 && any(!vapply(block_values, is.character, logical(1)))) {
    stop("`section_context$evidence_blocks` values must be character vectors.", call. = FALSE)
  }

  section_context
}
