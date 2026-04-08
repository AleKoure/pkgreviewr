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
  package_review_prompt <- readLines(path_to_promt) |> paste(collapse = "\n")
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
    paste(readLines(get_package_review_prompt_path()), collapse = "
"),
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
    sep = "

"
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
#
# @return Invisibly returns the generated report text.
# @export
build_report <- function(package_url,
                         output_path = "test_review.md",
                         chat_fn = NULL,
                         chat = NULL,
                         parallel = FALSE,
                         workers = 1L) {
  chat_backend <- resolve_chat_backend(chat_fn = chat_fn, chat = chat)
  review_data <- collect_review_data(package_url)
  section_results <- generate_review_sections(
    review_data = review_data,
    chat_fn = chat_backend,
    parallel = parallel,
    workers = workers
  )
  synthesis_result <- synthesize_review_diagnostics(section_results, chat_backend)
  all_results <- c(list(synthesis_result), section_results)
  draft_report <- render_review_report(review_data, all_results)
  report <- refine_review_report(draft_report, chat_backend)
  report <- structure(
    report,
    class = c("pkgreviewr_report", "character"),
    draft_report = draft_report,
    section_results = all_results,
    section_traces = collect_section_traces(all_results)
  )

  writeLines(as.character(report), output_path)
  message("Review report written to: ", output_path)
  invisible(report)
}
