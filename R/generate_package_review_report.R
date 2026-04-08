# Internal validator for ellmer chat objects.
#
# @param chat Object to validate.
#
# @return The validated chat object.
# @keywords internal
# @noRd
validate_chat_object <- function(chat) {
  if (!inherits(chat, "Chat")) {
    stop("`chat` must inherit from 'Chat'.", call. = FALSE)
  }

  required_methods <- c("clone", "set_system_prompt", "chat")
  missing_methods <- required_methods[!vapply(required_methods, function(method) {
    is.function(chat[[method]])
  }, logical(1))]

  if (length(missing_methods) > 0) {
    stop(
      sprintf(
        "`chat` is missing required method(s): %s.",
        paste(missing_methods, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  chat
}

# Internal adapter from chat objects to chat functions.
#
# @param chat An ellmer chat object.
#
# @return A chat function with signature `(system_prompt, user_prompt)`.
# @keywords internal
# @noRd
chat_fn_from_chat <- function(chat) {
  chat <- validate_chat_object(chat)

  function(system_prompt, user_prompt) {
    active_chat <- chat$clone(deep = TRUE)
    active_chat$set_system_prompt(system_prompt)
    active_chat$chat(user_prompt)
  }
}

# Internal local-model resolver.
#
# Uses Ollama only when a local model is explicitly configured.
#
# @return An ellmer chat object, or `NULL` when no local backend is available.
# @keywords internal
# @noRd
resolve_local_chat <- function() {
  model <- Sys.getenv("PKGREVIEWR_OLLAMA_MODEL", unset = "")

  if (!nzchar(model)) {
    model <- Sys.getenv("OLLAMA_MODEL", unset = "")
  }

  if (!nzchar(model) || !nzchar(Sys.which("ollama"))) {
    return(NULL)
  }

  ellmer::chat_ollama(model = model)
}

# Internal chat backend resolver.
#
# @param chat_fn Optional user-supplied chat function.
# @param chat Optional user-supplied ellmer chat object.
#
# @return A chat function with signature `(system_prompt, user_prompt)`.
# @keywords internal
# @noRd
resolve_chat_backend <- function(chat_fn = NULL, chat = NULL) {
  if (!is.null(chat_fn) && !is.null(chat)) {
    stop("Supply only one of `chat_fn` or `chat`.", call. = FALSE)
  }

  if (!is.null(chat_fn)) {
    if (!is.function(chat_fn)) {
      stop("`chat_fn` must be a function.", call. = FALSE)
    }

    return(chat_fn)
  }

  if (!is.null(chat)) {
    return(chat_fn_from_chat(chat))
  }

  local_chat <- resolve_local_chat()

  if (!is.null(local_chat)) {
    return(chat_fn_from_chat(local_chat))
  }

  stop(
    paste(
      "Provide `chat_fn` or `chat`, or configure a local Ollama backend via",
      "`PKGREVIEWR_OLLAMA_MODEL` (or `OLLAMA_MODEL`) and ensure `ollama` is installed."
    ),
    call. = FALSE
  )
}

# Internal prompt path resolver.
#
# Falls back to the source-tree path when the package is not installed.
#
# @return Path to the package review prompt file.
# @keywords internal
# @noRd
get_package_review_prompt_path <- function() {
  installed_path <- system.file("package_review_prompt.md", package = "pkgreviewr")

  if (nzchar(installed_path)) {
    return(installed_path)
  }

  source_path <- file.path("inst", "package_review_prompt.md")

  if (file.exists(source_path)) {
    return(source_path)
  }

  stop("Could not find `package_review_prompt.md`.", call. = FALSE)
}

# Internal review artifact directory validator.
#
# @param artifact_dir Optional artifact directory.
#
# @return `NULL` or a validated artifact directory path.
# @keywords internal
# @noRd
normalize_artifact_dir <- function(artifact_dir = NULL) {
  if (is.null(artifact_dir)) {
    return(NULL)
  }

  if (!is.character(artifact_dir) || length(artifact_dir) != 1L || !nzchar(artifact_dir)) {
    stop("`artifact_dir` must be `NULL` or a single non-empty string.", call. = FALSE)
  }

  artifact_dir
}

# Internal text artifact writer.
#
# @param path Output path.
# @param text Character content to write.
#
# @return Invisibly returns `path`.
# @keywords internal
# @noRd
write_text_artifact <- function(path, text) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(as.character(text), path)
  invisible(path)
}

# Internal structured artifact writer.
#
# @param path Output path.
# @param object R object to serialize with `dput()`.
#
# @return Invisibly returns `path`.
# @keywords internal
# @noRd
write_dput_artifact <- function(path, object) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  dput(object, file = path)
  invisible(path)
}

# Internal artifact provenance builder.
#
# @param section_specs Section specification list.
# @param refinement_ran Whether final refinement ran.
#
# @return A provenance list.
# @keywords internal
# @noRd
build_artifact_provenance <- function(section_specs, refinement_ran = TRUE) {
  template_map <- lapply(section_specs, function(section_spec) {
    list(
      template_name = section_spec$template_name,
      template_path = normalizePath(
        get_section_prompt_template_path(section_spec$template_name),
        winslash = "/",
        mustWork = FALSE
      )
    )
  })

  list(
    review_guide_path = normalizePath(get_package_review_prompt_path(), winslash = "/", mustWork = FALSE),
    section_templates = template_map,
    refinement_ran = isTRUE(refinement_ran)
  )
}

# Persist optional review artifacts for debugging and reproducibility.
#
# @param artifact_dir Target artifact directory.
# @param review_data A validated `review_data` object.
# @param section_results Generated section results excluding synthesis.
# @param synthesis_result Generated synthesis section result.
# @param draft_report Draft assembled report.
# @param final_report Final refined report.
# @param section_specs Section specifications used to build prompts.
# @param refinement_ran Whether refinement ran.
#
# @return Invisibly returns the normalized artifact directory path.
# @keywords internal
# @noRd
persist_review_artifacts <- function(artifact_dir,
                                     review_data,
                                     section_results,
                                     synthesis_result,
                                     draft_report,
                                     final_report,
                                     section_specs = get_review_section_specs(),
                                     refinement_ran = TRUE) {
  artifact_dir <- normalize_artifact_dir(artifact_dir)

  if (is.null(artifact_dir)) {
    return(invisible(NULL))
  }

  review_data <- validate_review_data(review_data)
  validated_sections <- lapply(section_results, validate_section_result)
  synthesis_result <- validate_section_result(synthesis_result)
  provenance <- build_artifact_provenance(section_specs, refinement_ran = refinement_ran)
  artifact_dir <- normalizePath(artifact_dir, winslash = "/", mustWork = FALSE)

  dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
  write_text_artifact(file.path(artifact_dir, "review-data.txt"), format_review_data(review_data))
  write_dput_artifact(file.path(artifact_dir, "review-data-metadata.dput"), review_data$metadata)
  write_dput_artifact(file.path(artifact_dir, "provenance.dput"), provenance)
  write_text_artifact(file.path(artifact_dir, "draft-report.md"), draft_report)
  write_text_artifact(file.path(artifact_dir, "final-report.md"), final_report)

  section_results_by_id <- setNames(
    validated_sections,
    vapply(validated_sections, function(section_result) section_result$section_id, character(1))
  )

  for (section_spec in section_specs) {
    section_context <- build_section_context(review_data, section_spec)
    section_id <- section_spec$section_id
    section_dir <- file.path(artifact_dir, "sections", section_id)
    section_result <- section_results_by_id[[section_id]]

    write_text_artifact(file.path(section_dir, "context.txt"), format_section_context(section_context))
    write_text_artifact(file.path(section_dir, "system-prompt.txt"), build_section_system_prompt(section_context, section_spec))

    if (!is.null(section_result)) {
      write_text_artifact(file.path(section_dir, "summary.txt"), section_result$summary)
      write_text_artifact(file.path(section_dir, "body.md"), section_result$body)
      write_dput_artifact(file.path(section_dir, "trace.dput"), section_result$trace)
    }
  }

  synthesis_prompt <- build_synthesis_prompt(validated_sections)
  synthesis_dir <- file.path(artifact_dir, "synthesis")
  write_text_artifact(file.path(synthesis_dir, "system-prompt.txt"), synthesis_prompt$system_prompt)
  write_text_artifact(file.path(synthesis_dir, "user-prompt.txt"), synthesis_prompt$user_prompt)
  write_text_artifact(file.path(synthesis_dir, "summary.txt"), synthesis_result$summary)
  write_text_artifact(file.path(synthesis_dir, "body.md"), synthesis_result$body)
  write_dput_artifact(file.path(synthesis_dir, "trace.dput"), synthesis_result$trace)

  invisible(artifact_dir)
}

# Internal report generator for the legacy single-prompt workflow.
#
# @param code Single prompt input generated from collected review data.
# @param path_to_report Output path for the generated report.
# @param chat_fn Optional chat function with signature
#   `(system_prompt, user_prompt)`.
# @param chat Optional ellmer chat object inheriting from `Chat`.
#
# @return Invisibly returns the generated report text.
# @keywords internal
# @noRd
generate_package_review_report <- function(code,
                                           path_to_report,
                                           chat_fn = NULL,
                                           chat = NULL) {
  path_to_promt <- get_package_review_prompt_path()
  package_review_prompt <- paste(readLines(path_to_promt), collapse = "\n")
  chat_backend <- resolve_chat_backend(chat_fn = chat_fn, chat = chat)

  response <- chat_backend(
    system_prompt = package_review_prompt,
    user_prompt = code
  )

  writeLines(response, path_to_report)
  message("Review report written to: ", path_to_report)
  invisible(response)
}

# Internal final-refinement prompt builder.
#
# @return A single system prompt for final report refinement.
# @keywords internal
# @noRd
build_final_refinement_prompt <- function() {
  paste(
    "You are refining a draft R package audit report.",
    "Use the package review guide below as the governing style and criteria.",
    paste(readLines(get_package_review_prompt_path()), collapse = "\n"),
    "Treat the section content as fixed evidence-backed draft material and improve only wording, structure, and formatting.",
    "Preserve the report's facts, section meanings, and omissions.",
    "The final report must remain aligned with open-source review expectations reflected in Mozilla, rOpenSci, tidyverse, and r-pkgs guidance.",
    "Beautify the report in the gluing layer, not by inventing new diagnostics.",
    "Keep the final report tidy, concise, and aligned with this format:",
    "# Audit report - <package>",
    "Reviewed source: <source>",
    "Optional single-line omission note when sections were skipped.",
    "> Preview: <overall assessment preview>",
    "<overall assessment body>",
    "## ✅ Strengths",
    "## ⚠️ Improvements",
    "## 🔧 Suggestions",
    "## 🚫 Red Flags",
    "## Technical Details",
    "Preserve existing section order when present and do not add new sections.",
    "Do not invent evidence, add policy commentary, or mention hidden processing steps.",
    "Return only the final markdown report.",
    sep = "\n\n"
  )
}

# Internal final-refinement runner for assembled reports.
#
# @param report Draft markdown report.
# @param chat_fn Chat backend with signature `(system_prompt, user_prompt)`.
#
# @return A refined markdown report, or the draft report on failure.
# @keywords internal
# @noRd
refine_review_report <- function(report, chat_fn) {
  refined_report <- tryCatch(
    chat_fn(
      system_prompt = build_final_refinement_prompt(),
      user_prompt = report
    ),
    error = function(error) NULL
  )

  if (is.null(refined_report) || !is.character(refined_report) || length(refined_report) != 1 || !nzchar(refined_report)) {
    return(report)
  }

  refined_report
}

# Internal scoring helper for duplicate report sections.
#
# @param section_block Character vector representing one section block.
#
# @return A numeric completeness score.
# @keywords internal
# @noRd
score_report_section_block <- function(section_block) {
  if (length(section_block) == 0L) {
    return(-Inf)
  }

  non_empty_lines <- section_block[nzchar(section_block)]
  has_preview <- any(grepl("^> Preview:", non_empty_lines))
  numbered_lines <- sum(grepl("^[0-9]+\\. ", non_empty_lines))
  bullet_lines <- sum(grepl("^[-*] ", non_empty_lines))
  paragraph_lines <- max(0L, length(non_empty_lines) - 1L)

  length(non_empty_lines) + (3L * has_preview) + numbered_lines + bullet_lines + paragraph_lines
}

# Internal final report cleanup for repeated metadata and sections.
#
# @param report_text Report markdown to normalize.
#
# @return A cleaned markdown report.
# @keywords internal
# @noRd
normalize_final_report <- function(report_text) {
  if (!is.character(report_text) || length(report_text) != 1L || !nzchar(report_text)) {
    return(report_text)
  }

  lines <- strsplit(report_text, "\n", fixed = TRUE)[[1]]
  header_line <- grep("^# Audit report - ", lines)
  source_line <- grep("^Reviewed source:", lines)
  section_titles <- c(
    "## ✅ Strengths",
    "## ⚠️ Improvements",
    "## 🔧 Suggestions",
    "## 🚫 Red Flags",
    "## Technical Details"
  )
  section_start <- which(lines %in% section_titles)

  if (length(header_line) > 1L) {
    lines <- lines[-header_line[-1L]]
  }

  if (length(source_line) > 1L) {
    lines <- lines[-source_line[-1L]]
  }

  section_start <- which(lines %in% section_titles)

  if (length(section_start) == 0L) {
    return(paste(lines, collapse = "\n"))
  }

  preamble <- lines[seq_len(section_start[[1]] - 1L)]
  section_blocks <- setNames(vector("list", length(section_titles)), section_titles)
  section_scores <- setNames(rep(-Inf, length(section_titles)), section_titles)

  for (index in seq_along(section_start)) {
    start_line <- section_start[[index]]
    end_line <- if (index < length(section_start)) section_start[[index + 1L]] - 1L else length(lines)
    title <- lines[[start_line]]
    candidate_block <- lines[start_line:end_line]
    candidate_score <- score_report_section_block(candidate_block)

    if (candidate_score >= section_scores[[title]]) {
      section_blocks[[title]] <- candidate_block
      section_scores[[title]] <- candidate_score
    }
  }

  rendered_sections <- unlist(Filter(length, section_blocks), use.names = FALSE)
  blocks <- c(preamble, rendered_sections)

  while (length(blocks) > 0L && blocks[[length(blocks)]] == "") {
    blocks <- blocks[-length(blocks)]
  }

  paste(blocks, collapse = "\n")
}

# Retrieve attached section traces from a built report.
#
# @param report Report value returned by `build_report()`.
# @param section_id Optional section identifier.
#
# @return A named list of traces, or a single section trace.
# @keywords internal
# @noRd
report_section_traces <- function(report, section_id = NULL) {
  traces <- attr(report, "section_traces", exact = TRUE)

  if (is.null(traces)) {
    stop("`report` does not contain attached section traces.", call. = FALSE)
  }

  if (is.null(section_id)) {
    return(traces)
  }

  if (!section_id %in% names(traces)) {
    stop(sprintf("No trace found for section '%s'.", section_id), call. = FALSE)
  }

  traces[[section_id]]
}

# Build a package review report.
#
# `build_report()` is the current end-user entry point. It collects package
# review data, generates a review with the configured LLM prompt, and writes
# the report to disk.
#
# @param package_url Repository URL to review.
# @param output_path Output path for the generated review report.
# @param chat_fn Optional chat function with signature
#   `(system_prompt, user_prompt)`.
# @param chat Optional ellmer chat object inheriting from `Chat`.
# @param parallel Whether to generate independent review sections in parallel
#   when possible.
# @param workers Number of workers to use when `parallel = TRUE`.
# @param artifact_dir Optional directory for persisted prompts, traces, and
#   intermediate report artifacts.
#
# @return Invisibly returns the generated report text.
# @export
build_report <- function(package_url,
                         output_path = "test_review.md",
                         chat_fn = NULL,
                         chat = NULL,
                         parallel = FALSE,
                         workers = 1L,
                         artifact_dir = NULL) {
  chat_backend <- resolve_chat_backend(chat_fn = chat_fn, chat = chat)
  artifact_dir <- normalize_artifact_dir(artifact_dir)
  review_data <- collect_review_data(package_url)
  section_specs <- get_review_section_specs()
  section_results <- generate_review_sections(
    review_data = review_data,
    chat_fn = chat_backend,
    parallel = parallel,
    workers = workers
  )
  synthesis_result <- synthesize_review_diagnostics(section_results, chat_backend)
  all_results <- c(list(synthesis_result), section_results)
  draft_report <- render_review_report(review_data, all_results)
  report_text <- normalize_final_report(refine_review_report(draft_report, chat_backend))
  provenance <- build_artifact_provenance(section_specs, refinement_ran = TRUE)

  persisted_dir <- persist_review_artifacts(
    artifact_dir = artifact_dir,
    review_data = review_data,
    section_results = section_results,
    synthesis_result = synthesis_result,
    draft_report = draft_report,
    final_report = report_text,
    section_specs = section_specs,
    refinement_ran = TRUE
  )

  report <- structure(
    report_text,
    class = c("pkgreviewr_report", "character"),
    draft_report = draft_report,
    section_results = all_results,
    section_traces = collect_section_traces(all_results),
    artifact_dir = persisted_dir,
    provenance = provenance
  )

  writeLines(as.character(report), output_path)
  message("Review report written to: ", output_path)
  invisible(report)
}
