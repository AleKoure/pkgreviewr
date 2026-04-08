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
      evidence_specs = list(
        list(id = "package_code", label = "Package Code", max_chars = 9000L),
        list(id = "rcmd_check_report", label = "R CMD Check", max_chars = 2500L),
        list(id = "coverage_report", label = "Code Coverage", max_chars = 1500L)
      )
    ),
    improvements = list(
      section_id = "improvements",
      title = "⚠️ Improvements",
      focus = paste(
        "List the most important quality gaps and missing pieces.",
        "Emphasize concrete improvements based on the package review guides."
      ),
      evidence_specs = list(
        list(id = "rcmd_check_report", label = "R CMD Check", max_chars = 3500L),
        list(id = "lint_report", label = "Lint Summary", max_chars = 2500L),
        list(id = "coverage_report", label = "Code Coverage", max_chars = 1500L),
        list(id = "package_code", label = "Relevant Package Code", max_chars = 5000L)
      )
    ),
    refactor_suggestions = list(
      section_id = "refactor_suggestions",
      title = "🔧 Suggestions",
      focus = paste(
        "Suggest practical refactors or cleanup steps that would improve maintainability,",
        "clarity, and package design without overengineering the solution."
      ),
      evidence_specs = list(
        list(id = "package_code", label = "Package Code", max_chars = 7000L),
        list(id = "lint_report", label = "Lint Summary", max_chars = 2000L),
        list(id = "rcmd_check_report", label = "R CMD Check", max_chars = 2000L)
      )
    ),
    red_flags = list(
      section_id = "red_flags",
      title = "🚫 Red Flags",
      focus = paste(
        "Identify blockers, correctness risks, release risks, or serious weaknesses.",
        "If there are no major blockers, say so explicitly."
      ),
      evidence_specs = list(
        list(id = "rcmd_check_report", label = "R CMD Check", max_chars = 3500L),
        list(id = "lint_report", label = "Lint Summary", max_chars = 2000L),
        list(id = "coverage_report", label = "Code Coverage", max_chars = 1500L),
        list(id = "package_code", label = "Relevant Package Code", max_chars = 4000L)
      )
    ),
    technical_details = list(
      section_id = "technical_details",
      title = "Technical Details",
      focus = paste(
        "Summarize technical diagnostics from session info, lints, R CMD check,",
        "and code coverage using careful markdown list formatting."
      ),
      evidence_specs = list(
        list(id = "session_info", label = "Session Info", max_chars = 2500L),
        list(id = "lint_report", label = "Lint Summary", max_chars = 2500L),
        list(id = "rcmd_check_report", label = "R CMD Check", max_chars = 3500L),
        list(id = "coverage_report", label = "Code Coverage", max_chars = 2000L)
      )
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

  evidence_blocks <- list()
  evidence_used <- character()

  for (evidence_spec in section_spec$evidence_specs) {
    signal_value <- review_data$signals[[evidence_spec$id]]

    if (is.null(signal_value)) {
      next
    }

    rendered_signal <- truncate_text(signal_value, max_chars = evidence_spec$max_chars)

    if (!nzchar(rendered_signal)) {
      next
    }

    evidence_blocks[[evidence_spec$id]] <- paste(
      "##",
      evidence_spec$label,
      rendered_signal,
      sep = "\n"
    )
    evidence_used <- c(evidence_used, evidence_spec$id)
  }

  new_section_context(
    section_id = section_spec$section_id,
    title = section_spec$title,
    focus = section_spec$focus,
    evidence_blocks = evidence_blocks,
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
  section_context <- validate_section_context(section_context)
  evidence_blocks <- unlist(section_context$evidence_blocks, use.names = FALSE)

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

# Internal trace builder for section and synthesis generation.
#
# @param section_id Single section identifier.
# @param title Single section title.
# @param status Single trace status.
# @param attempts List of attempt records.
# @param final_error Optional final error string.
#
# @return A named trace list.
# @keywords internal
# @noRd
new_section_trace <- function(section_id,
                              title,
                              status,
                              attempts = list(),
                              final_error = NULL) {
  list(
    section_id = section_id,
    title = title,
    status = status,
    attempts = attempts,
    final_error = final_error
  )
}

# Internal chat runner with retries for section-shaped responses.
#
# @param chat_fn Chat backend with signature `(system_prompt, user_prompt)`.
# @param system_prompt System prompt for the call.
# @param user_prompt User prompt for the call.
# @param max_attempts Maximum number of attempts.
#
# @return A list containing parsed response data and attempt traces.
# @keywords internal
# @noRd
run_chat_attempts <- function(chat_fn,
                              system_prompt,
                              user_prompt,
                              max_attempts = 3L) {
  max_attempts <- max(1L, as.integer(max_attempts))
  attempts <- vector("list", length = 0L)
  parsed_response <- NULL
  final_error <- NULL

  for (attempt_index in seq_len(max_attempts)) {
    response <- tryCatch(
      chat_fn(system_prompt = system_prompt, user_prompt = user_prompt),
      error = function(error) {
        final_error <<- conditionMessage(error)
        attempts[[length(attempts) + 1L]] <<- list(
          attempt = attempt_index,
          status = "backend_error",
          error = final_error
        )
        NULL
      }
    )

    if (is.null(response)) {
      next
    }

    current_parsed <- parse_section_response(response)

    if (is.null(current_parsed$parse_warning)) {
      parsed_response <- current_parsed
      attempts[[length(attempts) + 1L]] <- list(
        attempt = attempt_index,
        status = "success",
        error = NULL
      )
      break
    }

    final_error <- current_parsed$parse_warning
    attempts[[length(attempts) + 1L]] <- list(
      attempt = attempt_index,
      status = "parse_error",
      error = final_error
    )
  }

  list(
    parsed_response = parsed_response,
    attempts = attempts,
    final_error = final_error
  )
}

# Internal section success predicate.
#
# @param section_result A validated `section_result` object.
#
# @return `TRUE` when the section generated successfully.
# @keywords internal
# @noRd
is_successful_section_result <- function(section_result) {
  section_result <- validate_section_result(section_result)
  is.null(section_result$trace$status) || identical(section_result$trace$status, "success")
}

# Internal trace collector for generated sections.
#
# @param section_results A list of validated `section_result` objects.
#
# @return A named list of trace records.
# @keywords internal
# @noRd
collect_section_traces <- function(section_results) {
  validated_results <- lapply(section_results, validate_section_result)
  traces <- lapply(validated_results, function(section_result) section_result$trace)
  names(traces) <- vapply(validated_results, function(section_result) section_result$section_id, character(1))
  traces
}

# Internal omitted-section note builder.
#
# @param section_results A list of validated `section_result` objects.
#
# @return A single note string, or `""` when nothing was omitted.
# @keywords internal
# @noRd
build_omitted_sections_note <- function(section_results) {
  validated_results <- lapply(section_results, validate_section_result)
  omitted_titles <- vapply(validated_results, function(section_result) {
    if (!is_successful_section_result(section_result)) {
      return(section_result$title)
    }

    NA_character_
  }, character(1))
  omitted_titles <- unique(stats::na.omit(omitted_titles))

  if (length(omitted_titles) == 0L) {
    return("")
  }

  paste(
    "Note: Omitted sections due to generation failures:",
    paste(omitted_titles, collapse = ", ")
  )
}

# Internal single-section generator.
#
# @param review_data A validated `review_data` object.
# @param section_spec A section specification.
# @param chat_fn Chat backend with signature `(system_prompt, user_prompt)`.
# @param max_attempts Maximum number of attempts for the section call.
#
# @return A validated `section_result` object.
# @keywords internal
# @noRd
generate_review_section <- function(review_data,
                                    section_spec,
                                    chat_fn,
                                    max_attempts = 3L) {
  section_context <- build_section_context(review_data, section_spec)
  user_prompt <- format_section_context(section_context)
  system_prompt <- build_section_system_prompt(section_context)
  chat_result <- run_chat_attempts(
    chat_fn = chat_fn,
    system_prompt = system_prompt,
    user_prompt = user_prompt,
    max_attempts = max_attempts
  )

  if (is.null(chat_result$parsed_response)) {
    warning_messages <- unique(vapply(chat_result$attempts, function(attempt) {
      if (is.null(attempt$error)) {
        return(NA_character_)
      }

      attempt$error
    }, character(1)))
    warning_messages <- stats::na.omit(warning_messages)

    return(new_section_result(
      section_id = section_spec$section_id,
      title = section_spec$title,
      body = "This section could not be generated from the available diagnostics.",
      summary = paste("Section unavailable:", section_spec$title),
      evidence_used = section_context$evidence_used,
      warnings = warning_messages,
      trace = new_section_trace(
        section_id = section_spec$section_id,
        title = section_spec$title,
        status = "failed",
        attempts = chat_result$attempts,
        final_error = chat_result$final_error
      )
    ))
  }

  new_section_result(
    section_id = section_spec$section_id,
    title = section_spec$title,
    body = chat_result$parsed_response$body,
    summary = chat_result$parsed_response$summary,
    evidence_used = section_context$evidence_used,
    warnings = character(),
    trace = new_section_trace(
      section_id = section_spec$section_id,
      title = section_spec$title,
      status = "success",
      attempts = chat_result$attempts,
      final_error = NULL
    )
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
                                     workers = 1L,
                                     max_attempts = 3L) {
  review_data <- validate_review_data(review_data)
  section_specs <- get_review_section_specs()

  generate_one <- function(section_spec) {
    generate_review_section(
      review_data = review_data,
      section_spec = section_spec,
      chat_fn = chat_fn,
      max_attempts = max_attempts
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

  if (!is_successful_section_result(section_result)) {
    return("")
  }

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
  validated_results <- Filter(is_successful_section_result, lapply(section_results, validate_section_result))
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
synthesize_review_diagnostics <- function(section_results, chat_fn, max_attempts = 3L) {
  synthesis_prompt <- build_synthesis_prompt(section_results)

  if (length(synthesis_prompt$evidence_used) == 0L) {
    return(new_section_result(
      section_id = "overall_assessment",
      title = "Overall Assessment",
      body = "Overall synthesis could not be generated because no sections completed successfully.",
      summary = "Overall assessment unavailable.",
      evidence_used = character(),
      warnings = "No successful sections were available for synthesis.",
      trace = new_section_trace(
        section_id = "overall_assessment",
        title = "Overall Assessment",
        status = "failed",
        attempts = list(),
        final_error = "No successful sections were available for synthesis."
      )
    ))
  }

  chat_result <- run_chat_attempts(
    chat_fn = chat_fn,
    system_prompt = synthesis_prompt$system_prompt,
    user_prompt = synthesis_prompt$user_prompt,
    max_attempts = max_attempts
  )

  if (is.null(chat_result$parsed_response)) {
    warning_messages <- unique(vapply(chat_result$attempts, function(attempt) {
      if (is.null(attempt$error)) {
        return(NA_character_)
      }

      attempt$error
    }, character(1)))
    warning_messages <- stats::na.omit(warning_messages)

    return(new_section_result(
      section_id = "overall_assessment",
      title = "Overall Assessment",
      body = "Overall synthesis could not be generated. Review the completed section summaries directly.",
      summary = "Overall assessment unavailable.",
      evidence_used = synthesis_prompt$evidence_used,
      warnings = warning_messages,
      trace = new_section_trace(
        section_id = "overall_assessment",
        title = "Overall Assessment",
        status = "failed",
        attempts = chat_result$attempts,
        final_error = chat_result$final_error
      )
    ))
  }

  new_section_result(
    section_id = "overall_assessment",
    title = "Overall Assessment",
    body = chat_result$parsed_response$body,
    summary = chat_result$parsed_response$summary,
    evidence_used = synthesis_prompt$evidence_used,
    warnings = character(),
    trace = new_section_trace(
      section_id = "overall_assessment",
      title = "Overall Assessment",
      status = "success",
      attempts = chat_result$attempts,
      final_error = NULL
    )
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

  omitted_note <- build_omitted_sections_note(validated_results)

  if (nzchar(omitted_note)) {
    top_blocks <- c(top_blocks, omitted_note)
  }

  if (length(synthesis_index) > 0) {
    synthesis_result <- validated_results[[synthesis_index[[1]]]]

    if (is_successful_section_result(synthesis_result)) {
      top_blocks <- c(
        top_blocks,
        paste("> Preview:", synthesis_result$summary),
        synthesis_result$body
      )
    }

    validated_results <- validated_results[-synthesis_index[[1]]]
  }

  rendered_sections <- vapply(validated_results, render_review_section, character(1))
  blocks <- c(top_blocks, rendered_sections)

  paste(blocks[nzchar(blocks)], collapse = "\n\n")
}
