# Internal section specifications for the current review flow.
#
# @return A named list of section specifications.
# @keywords internal
# @noRd
get_review_section_specs <- function() {
  list(
    strengths = list(
      section_id = "strengths",
      title = "✅ Strengths",
      focus = paste(
        "Identify the package's clearest strengths in structure, design,",
        "documentation, testing, and usability. Prefer concrete positives over vague praise."
      ),
      signal_names = c("package_code", "rcmd_check_report", "lint_report", "coverage_report"),
      max_chars = 10000L
    ),
    improvements = list(
      section_id = "improvements",
      title = "⚠️ Improvements",
      focus = paste(
        "List the most important quality gaps and missing pieces.",
        "Emphasize concrete improvements based on the package review guides."
      ),
      signal_names = c("rcmd_check_report", "lint_report", "coverage_report", "package_code"),
      max_chars = 10000L
    ),
    refactor_suggestions = list(
      section_id = "refactor_suggestions",
      title = "🔧 Suggestions",
      focus = paste(
        "Suggest practical refactors or cleanup steps that would improve maintainability,",
        "clarity, and package design without overengineering the solution."
      ),
      signal_names = c("package_code", "lint_report", "rcmd_check_report"),
      max_chars = 10000L
    ),
    red_flags = list(
      section_id = "red_flags",
      title = "🚫 Red Flags",
      focus = paste(
        "Identify blockers, correctness risks, release risks, or serious weaknesses.",
        "If there are no major blockers, say so explicitly."
      ),
      signal_names = c("rcmd_check_report", "lint_report", "coverage_report", "package_code"),
      max_chars = 10000L
    ),
    technical_details = list(
      section_id = "technical_details",
      title = "Technical Details",
      focus = paste(
        "Summarize technical diagnostics from session info, lints, R CMD check,",
        "and code coverage using careful markdown list formatting."
      ),
      signal_names = c("session_info", "lint_report", "rcmd_check_report", "coverage_report"),
      max_chars = 12000L
    )
  )
}

# Internal text truncation helper.
#
# @param text Character vector to collapse and truncate.
# @param max_chars Maximum number of characters to keep.
#
# @return A single string.
# @keywords internal
# @noRd
truncate_text <- function(text, max_chars) {
  collapsed <- paste(text, collapse = "\n")

  if (nchar(collapsed, type = "chars") <= max_chars) {
    return(collapsed)
  }

  paste0(substr(collapsed, 1, max_chars), "\n...[truncated]")
}

# Internal section-context builder.
#
# @param review_data A validated `review_data` object.
# @param section_spec A section specification.
#
# @return A named list containing section context.
# @keywords internal
# @noRd
build_section_context <- function(review_data, section_spec) {
  review_data <- validate_review_data(review_data)

  evidence <- list()
  evidence_used <- character()

  for (signal_name in section_spec$signal_names) {
    signal_value <- review_data$signals[[signal_name]]

    if (is.null(signal_value)) {
      next
    }

    rendered_signal <- truncate_text(signal_value, max_chars = section_spec$max_chars)

    if (!nzchar(rendered_signal)) {
      next
    }

    evidence[[signal_name]] <- rendered_signal
    evidence_used <- c(evidence_used, signal_name)
  }

  list(
    section_id = section_spec$section_id,
    title = section_spec$title,
    focus = section_spec$focus,
    evidence = evidence,
    evidence_used = evidence_used
  )
}

# Internal section-context formatter.
#
# @param section_context A section-context list.
#
# @return A single prompt string for the section.
# @keywords internal
# @noRd
format_section_context <- function(section_context) {
  evidence_blocks <- vapply(names(section_context$evidence), function(signal_name) {
    paste(
      "##",
      signal_name,
      section_context$evidence[[signal_name]],
      sep = "\n"
    )
  }, character(1))

  paste(
    paste("Section ID:", section_context$section_id),
    paste("Section Title:", section_context$title),
    paste("Focus:", section_context$focus),
    paste(evidence_blocks, collapse = "\n\n"),
    sep = "\n\n"
  )
}

# Internal review-guide reader.
#
# @return A single string containing the package review guide prompt.
# @keywords internal
# @noRd
read_review_guide_prompt <- function() {
  prompt_path <- file.path("inst", "package_review_prompt.md")

  if (exists("get_package_review_prompt_path", mode = "function")) {
    prompt_path <- get_package_review_prompt_path()
  }

  paste(readLines(prompt_path), collapse = "\n")
}

# Internal section prompt builder.
#
# @param section_context A section-context list.
#
# @return A system prompt for the section.
# @keywords internal
# @noRd
build_section_system_prompt <- function(section_context) {
  paste(
    "You are reviewing an R package using the package review guide below.",
    "Anchor your judgment in the Mozilla, rOpenSci, tidyverse, and r-pkgs principles described there.",
    "Preserve the guide's structure, priorities, and tone.",
    read_review_guide_prompt(),
    "Generate only the requested section.",
    "Keep the output tight, concrete, and stylistically close to the guide's example report.",
    "Do not repeat the section heading inside the body.",
    "Use short numbered lists when they improve readability.",
    "Avoid meta commentary, confidence language, or process notes.",
    "Return exactly this format:",
    "SUMMARY:",
    "<one concise preview sentence or short paragraph>",
    "BODY:",
    "<markdown body for the section only>",
    "The summary must be concise and suitable for a preview and later synthesis.",
    paste("Focus only on the section named:", section_context$title),
    sep = "\n\n"
  )
}

# Internal parser for section responses.
#
# @param response Raw LLM response.
#
# @return A list with `summary`, `body`, and `parse_warning`.
# @keywords internal
# @noRd
parse_section_response <- function(response) {
  lines <- strsplit(response, "\n", fixed = TRUE)[[1]]
  summary_start <- match("SUMMARY:", lines)
  body_start <- match("BODY:", lines)

  if (is.na(summary_start) || is.na(body_start) || body_start <= summary_start) {
    return(list(
      summary = substr(response, 1, min(nchar(response), 220L)),
      body = response,
      parse_warning = "Response did not match the expected SUMMARY/BODY format."
    ))
  }

  summary_lines <- lines[(summary_start + 1):(body_start - 1)]
  body_lines <- lines[(body_start + 1):length(lines)]
  summary <- paste(summary_lines, collapse = "\n")
  body <- paste(body_lines, collapse = "\n")

  if (!nzchar(summary) || !nzchar(body)) {
    return(list(
      summary = substr(response, 1, min(nchar(response), 220L)),
      body = response,
      parse_warning = "Response contained an empty summary or body."
    ))
  }

  list(
    summary = summary,
    body = body,
    parse_warning = NULL
  )
}

# Internal single-section generator.
#
# @param review_data A validated `review_data` object.
# @param section_spec A section specification.
# @param chat_fn Chat backend with signature `(system_prompt, user_prompt)`.
#
# @return A validated `section_result` object.
# @keywords internal
# @noRd
generate_review_section <- function(review_data, section_spec, chat_fn) {
  section_context <- build_section_context(review_data, section_spec)
  user_prompt <- format_section_context(section_context)
  system_prompt <- build_section_system_prompt(section_context)
  warnings <- character()

  response <- tryCatch(
    chat_fn(system_prompt = system_prompt, user_prompt = user_prompt),
    error = function(error) {
      warnings <<- c(
        warnings,
        sprintf("LLM backend failed for section '%s': %s", section_spec$section_id, conditionMessage(error))
      )
      NULL
    }
  )

  if (is.null(response)) {
    return(new_section_result(
      section_id = section_spec$section_id,
      title = section_spec$title,
      body = "This section could not be generated from the available diagnostics.",
      summary = paste("Section unavailable:", section_spec$title),
      evidence_used = section_context$evidence_used,
      warnings = warnings
    ))
  }

  parsed_response <- parse_section_response(response)

  if (!is.null(parsed_response$parse_warning)) {
    warnings <- c(warnings, parsed_response$parse_warning)
  }

  new_section_result(
    section_id = section_spec$section_id,
    title = section_spec$title,
    body = parsed_response$body,
    summary = parsed_response$summary,
    evidence_used = section_context$evidence_used,
    warnings = warnings
  )
}

# Internal multi-section generator.
#
# @param review_data A validated `review_data` object.
# @param chat_fn Chat backend with signature `(system_prompt, user_prompt)`.
# @param parallel Whether to generate sections in parallel when possible.
# @param workers Number of workers to use when `parallel = TRUE`.
#
# @return A list of validated `section_result` objects.
# @keywords internal
# @noRd
generate_review_sections <- function(review_data,
                                     chat_fn,
                                     parallel = FALSE,
                                     workers = 1L) {
  review_data <- validate_review_data(review_data)
  section_specs <- get_review_section_specs()

  generate_one <- function(section_spec) {
    generate_review_section(
      review_data = review_data,
      section_spec = section_spec,
      chat_fn = chat_fn
    )
  }

  if (isTRUE(parallel) && length(section_specs) > 1L && .Platform$OS.type == "unix") {
    workers <- max(1L, min(as.integer(workers), length(section_specs)))

    if (workers > 1L) {
      return(parallel::mclapply(section_specs, generate_one, mc.cores = workers))
    }
  }

  lapply(section_specs, generate_one)
}

# Internal section renderer.
#
# @param section_result A validated `section_result` object.
#
# @return A markdown string for a single section.
# @keywords internal
# @noRd
render_review_section <- function(section_result) {
  section_result <- validate_section_result(section_result)

  blocks <- c(
    paste("##", section_result$title),
    paste("> Preview:", section_result$summary),
    section_result$body
  )

  paste(blocks[nzchar(blocks)], collapse = "\n\n")
}


# Internal synthesis prompt builder.
#
# @param section_results A list of validated `section_result` objects.
#
# @return A list with `system_prompt`, `user_prompt`, and `evidence_used`.
# @keywords internal
# @noRd
build_synthesis_prompt <- function(section_results) {
  validated_results <- lapply(section_results, validate_section_result)
  summary_lines <- vapply(validated_results, function(section_result) {
    paste0(section_result$section_id, ": ", section_result$summary)
  }, character(1))

  list(
    system_prompt = paste(
      "You are refining an R package review into a single overall assessment.",
      "Anchor your judgment in the Mozilla, rOpenSci, tidyverse, and r-pkgs principles from the guide below.",
      "Use the package review guide below as the governing format and criteria.",
      read_review_guide_prompt(),
      "Use only the supplied section summaries.",
      "Keep the assessment tight, concrete, and stylistically close to the guide's example report.",
      "Avoid meta commentary, confidence language, or process notes.",
      "Return exactly this format:",
      "SUMMARY:",
      "<one concise top-level preview sentence or short paragraph>",
      "BODY:",
      "<markdown body with a short overall assessment and top priorities>",
      sep = "\n\n"
    ),
    user_prompt = paste(
      paste("Section summaries (", length(summary_lines), " total):", sep = ""),
      paste(summary_lines, collapse = "\n"),
      sep = "\n\n"
    ),
    evidence_used = vapply(validated_results, function(section_result) section_result$section_id, character(1))
  )
}

# Internal synthesis generator.
#
# @param section_results A list of validated `section_result` objects.
# @param chat_fn Chat backend with signature `(system_prompt, user_prompt)`.
#
# @return A validated `section_result` object.
# @keywords internal
# @noRd
synthesize_review_diagnostics <- function(section_results, chat_fn) {
  synthesis_prompt <- build_synthesis_prompt(section_results)
  warnings <- character()

  response <- tryCatch(
    chat_fn(
      system_prompt = synthesis_prompt$system_prompt,
      user_prompt = synthesis_prompt$user_prompt
    ),
    error = function(error) {
      warnings <<- c(
        warnings,
        sprintf("LLM backend failed for synthesis: %s", conditionMessage(error))
      )
      NULL
    }
  )

  if (is.null(response)) {
    return(new_section_result(
      section_id = "overall_assessment",
      title = "Overall Assessment",
      body = "Overall synthesis could not be generated. Review the section summaries directly.",
      summary = "Overall assessment unavailable.",
      evidence_used = synthesis_prompt$evidence_used,
      warnings = warnings
    ))
  }

  parsed_response <- parse_section_response(response)

  if (!is.null(parsed_response$parse_warning)) {
    warnings <- c(warnings, parsed_response$parse_warning)
  }

  new_section_result(
    section_id = "overall_assessment",
    title = "Overall Assessment",
    body = parsed_response$body,
    summary = parsed_response$summary,
    evidence_used = synthesis_prompt$evidence_used,
    warnings = warnings
  )
}

# Internal report renderer for section results.
#
# @param review_data A validated `review_data` object.
# @param section_results A list of validated `section_result` objects.
#
# @return A markdown report string.
# @keywords internal
# @noRd
render_review_report <- function(review_data, section_results) {
  review_data <- validate_review_data(review_data)
  validated_results <- lapply(section_results, validate_section_result)

  synthesis_index <- which(vapply(validated_results, function(section_result) {
    identical(section_result$section_id, "overall_assessment")
  }, logical(1)))

  top_blocks <- c(
    paste("# Audit report -", basename(review_data$package_ref)),
    paste("Reviewed source:", review_data$package_ref)
  )

  if (length(synthesis_index) > 0) {
    synthesis_result <- validated_results[[synthesis_index[[1]]]]

    top_blocks <- c(
      top_blocks,
      paste("> Preview:", synthesis_result$summary),
      synthesis_result$body
    )

    validated_results <- validated_results[-synthesis_index[[1]]]
  }

  rendered_sections <- vapply(validated_results, render_review_section, character(1))
  blocks <- c(top_blocks, rendered_sections)

  paste(blocks[nzchar(blocks)], collapse = "\n\n")
}
