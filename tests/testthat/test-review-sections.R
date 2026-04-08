test_that("generate_review_section returns a section_result with summary and warnings", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(
      package_code = c("f <- function() TRUE"),
      coverage_report = "95%",
      lint_report = "No lints",
      rcmd_check_report = "0 errors, 0 warnings",
      session_info = "R 4.4"
    ),
    metadata = list()
  )

  section_spec <- pkgreviewr:::get_review_section_specs()[[1]]
  chat_fn <- function(system_prompt, user_prompt) {
    expect_match(system_prompt, "SUMMARY:", fixed = TRUE)
    expect_match(user_prompt, section_spec$section_id, fixed = TRUE)
    paste(
      "SUMMARY:",
      "Concise section summary.",
      "BODY:",
      "Detailed markdown body.",
      sep = "\n"
    )
  }

  section_result <- pkgreviewr:::generate_review_section(review_data, section_spec, chat_fn)

  expect_s3_class(section_result, "pkgreviewr_section_result")
  expect_identical(section_result$summary, "Concise section summary.")
  expect_length(section_result$warnings, 0L)
})

test_that("generate_review_section degrades gracefully on backend failure", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(
      package_code = c("f <- function() TRUE"),
      coverage_report = "95%",
      lint_report = "No lints",
      rcmd_check_report = "0 errors, 0 warnings",
      session_info = "R 4.4"
    ),
    metadata = list()
  )

  section_spec <- pkgreviewr:::get_review_section_specs()[[1]]
  chat_fn <- function(system_prompt, user_prompt) {
    stop("backend unavailable")
  }

  section_result <- pkgreviewr:::generate_review_section(review_data, section_spec, chat_fn)

  expect_match(section_result$summary, "Section unavailable", fixed = TRUE)
  expect_true(any(grepl("backend unavailable", section_result$warnings, fixed = TRUE)))
})

test_that("generate_review_sections returns one result per section spec", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(
      package_code = c("f <- function() TRUE"),
      coverage_report = "95%",
      lint_report = "No lints",
      rcmd_check_report = "0 errors, 0 warnings",
      session_info = "R 4.4"
    ),
    metadata = list()
  )

  chat_fn <- function(system_prompt, user_prompt) {
    paste(
      "SUMMARY:",
      "Concise section summary.",
      "BODY:",
      "Detailed markdown body.",
      sep = "\n"
    )
  }

  section_results <- pkgreviewr:::generate_review_sections(review_data, chat_fn, parallel = FALSE, workers = 1L)

  expect_length(section_results, length(pkgreviewr:::get_review_section_specs()))
  expect_true(all(vapply(section_results, inherits, logical(1), what = "pkgreviewr_section_result")))
})

test_that("render_review_report renders section summaries and warnings", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(package_code = "code"),
    metadata = list()
  )

  section_results <- list(
    pkgreviewr:::new_section_result(
      section_id = "strengths",
      title = "✅ Strengths",
      body = "Detailed markdown body.",
      summary = "Concise section summary.",
      evidence_used = c("package_code"),
      warnings = character()
    )
  )

  rendered <- pkgreviewr:::render_review_report(review_data, section_results)

  expect_match(rendered, "# Audit report", fixed = TRUE)
  expect_match(rendered, "> Preview: Concise section summary.", fixed = TRUE)
  expect_match(rendered, "## ✅ Strengths", fixed = TRUE)
})


test_that("generate_review_sections can use parallel workers on unix", {
  skip_if(.Platform$OS.type != "unix")

  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(
      package_code = c("f <- function() TRUE"),
      coverage_report = "95%",
      lint_report = "No lints",
      rcmd_check_report = "0 errors, 0 warnings",
      session_info = "R 4.4"
    ),
    metadata = list()
  )

  chat_fn <- function(system_prompt, user_prompt) {
    paste(
      "SUMMARY:",
      "Parallel summary.",
      "BODY:",
      "Parallel body.",
      sep = "\n"
    )
  }

  section_results <- pkgreviewr:::generate_review_sections(
    review_data,
    chat_fn,
    parallel = TRUE,
    workers = 2L
  )

  expect_length(section_results, length(pkgreviewr:::get_review_section_specs()))
  expect_true(all(vapply(section_results, inherits, logical(1), what = "pkgreviewr_section_result")))
})


test_that("build_synthesis_prompt uses only section summaries", {
  section_results <- list(
    pkgreviewr:::new_section_result(
      section_id = "strengths",
      title = "✅ Strengths",
      body = "Detailed package body.",
      summary = "Package summary text.",
      evidence_used = c("package_code"),
      warnings = character()
    ),
    pkgreviewr:::new_section_result(
      section_id = "improvements",
      title = "⚠️ Improvements",
      body = "Detailed actions body.",
      summary = "Action summary text.",
      evidence_used = c("lint_report"),
      warnings = character()
    )
  )

  synthesis_prompt <- pkgreviewr:::build_synthesis_prompt(section_results)

  expect_match(synthesis_prompt$user_prompt, "Package summary text.", fixed = TRUE)
  expect_match(synthesis_prompt$user_prompt, "Action summary text.", fixed = TRUE)
  expect_false(grepl("Detailed package body.", synthesis_prompt$user_prompt, fixed = TRUE))
})

test_that("synthesize_review_diagnostics returns a synthesis section", {
  section_results <- list(
    pkgreviewr:::new_section_result(
      section_id = "strengths",
      title = "✅ Strengths",
      body = "Detailed package body.",
      summary = "Package summary text.",
      evidence_used = c("package_code"),
      warnings = character()
    )
  )

  synthesis_result <- pkgreviewr:::synthesize_review_diagnostics(
    section_results,
    function(system_prompt, user_prompt) {
      expect_match(user_prompt, "Package summary text.", fixed = TRUE)
      paste(
        "SUMMARY:",
        "Overall diagnostic summary.",
        "BODY:",
        "Overall diagnostic body.",
        sep = "\n"
      )
    }
  )

  expect_identical(synthesis_result$section_id, "overall_assessment")
  expect_identical(synthesis_result$summary, "Overall diagnostic summary.")
})

test_that("synthesize_review_diagnostics degrades gracefully on backend failure", {
  section_results <- list(
    pkgreviewr:::new_section_result(
      section_id = "strengths",
      title = "✅ Strengths",
      body = "Detailed package body.",
      summary = "Package summary text.",
      evidence_used = c("package_code"),
      warnings = character()
    )
  )

  synthesis_result <- pkgreviewr:::synthesize_review_diagnostics(
    section_results,
    function(system_prompt, user_prompt) stop("synthesis backend unavailable")
  )

  expect_identical(synthesis_result$section_id, "overall_assessment")
  expect_true(any(grepl("synthesis backend unavailable", synthesis_result$warnings, fixed = TRUE)))
})


test_that("render_review_report places synthesis as top preview", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(package_code = "code"),
    metadata = list()
  )

  section_results <- list(
    pkgreviewr:::new_section_result(
      section_id = "overall_assessment",
      title = "Overall Assessment",
      body = "Short overview body.",
      summary = "Short overview summary.",
      evidence_used = c("strengths", "improvements"),
      warnings = character()
    ),
    pkgreviewr:::new_section_result(
      section_id = "strengths",
      title = "✅ Strengths",
      body = "1. Strong API design.",
      summary = "Strong API design.",
      evidence_used = c("package_code"),
      warnings = character()
    )
  )

  rendered <- pkgreviewr:::render_review_report(review_data, section_results)

  expect_match(rendered, "> Preview: Short overview summary.", fixed = TRUE)
  expect_match(rendered, "## ✅ Strengths", fixed = TRUE)
})


test_that("build_section_system_prompt includes review guide context and section template", {
  section_context <- pkgreviewr:::new_section_context(
    section_id = "strengths",
    title = "✅ Strengths",
    focus = "Focus text.",
    evidence_blocks = list(package_code = "## Package Code\nf <- function() TRUE"),
    evidence_used = c("package_code")
  )
  section_spec <- pkgreviewr:::get_review_section_specs()$strengths

  system_prompt <- pkgreviewr:::build_section_system_prompt(section_context, section_spec)

  expect_match(system_prompt, "AI Review Prompt for R Packages", fixed = TRUE)
  expect_match(system_prompt, "Section directive: ✅ Strengths", fixed = TRUE)
  expect_match(system_prompt, "Mozilla review principles", fixed = TRUE)
  expect_match(system_prompt, "rOpenSci package expectations", fixed = TRUE)
  expect_match(system_prompt, "Focus only on the section named: ✅ Strengths", fixed = TRUE)
})

test_that("render_review_section uses preview format without internal scaffolding", {
  section_result <- pkgreviewr:::new_section_result(
    section_id = "strengths",
    title = "✅ Strengths",
    body = "1. Clear API surface.",
    summary = "Clear API surface.",
    evidence_used = c("package_code"),
    warnings = character()
  )

  rendered <- pkgreviewr:::render_review_section(section_result)

  expect_match(rendered, "> Preview: Clear API surface.", fixed = TRUE)
  expect_false(grepl("Evidence used:", rendered, fixed = TRUE))
  expect_false(grepl("Warnings:", rendered, fixed = TRUE))
})


test_that("generate_review_section retries before succeeding", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(
      package_code = c("f <- function() TRUE"),
      coverage_report = "95%",
      lint_report = "No lints",
      rcmd_check_report = "0 errors, 0 warnings",
      session_info = "R 4.4"
    ),
    metadata = list()
  )

  section_spec <- pkgreviewr:::get_review_section_specs()[[1]]
  attempts <- 0L
  chat_fn <- function(system_prompt, user_prompt) {
    attempts <<- attempts + 1L

    if (attempts == 1L) {
      stop("transient backend failure")
    }

    paste(
      "SUMMARY:",
      "Recovered section summary.",
      "BODY:",
      "Recovered section body.",
      sep = "
"
    )
  }

  section_result <- pkgreviewr:::generate_review_section(review_data, section_spec, chat_fn)

  expect_identical(section_result$summary, "Recovered section summary.")
  expect_identical(section_result$trace$status, "success")
  expect_length(section_result$trace$attempts, 2L)
  expect_identical(section_result$trace$attempts[[1]]$status, "backend_error")
  expect_identical(section_result$trace$attempts[[2]]$status, "success")
})

test_that("render_review_report omits failed sections and shows one note", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(package_code = "code"),
    metadata = list()
  )

  section_results <- list(
    pkgreviewr:::new_section_result(
      section_id = "overall_assessment",
      title = "Overall Assessment",
      body = "Overall body.",
      summary = "Overall summary.",
      evidence_used = c("strengths"),
      warnings = character(),
      trace = list(status = "success", attempts = list(), final_error = NULL)
    ),
    pkgreviewr:::new_section_result(
      section_id = "strengths",
      title = "✅ Strengths",
      body = "1. Strong API design.",
      summary = "Strong API design.",
      evidence_used = c("package_code"),
      warnings = character(),
      trace = list(status = "success", attempts = list(), final_error = NULL)
    ),
    pkgreviewr:::new_section_result(
      section_id = "improvements",
      title = "⚠️ Improvements",
      body = "This section could not be generated from the available diagnostics.",
      summary = "Section unavailable: ⚠️ Improvements",
      evidence_used = c("lint_report"),
      warnings = "backend unavailable",
      trace = list(status = "failed", attempts = list(list(attempt = 1L, status = "backend_error", error = "backend unavailable")), final_error = "backend unavailable")
    )
  )

  rendered <- pkgreviewr:::render_review_report(review_data, section_results)

  expect_match(rendered, "Note: Omitted sections due to generation failures: ⚠️ Improvements", fixed = TRUE)
  expect_false(grepl("## ⚠️ Improvements", rendered, fixed = TRUE))
  expect_match(rendered, "## ✅ Strengths", fixed = TRUE)
})

test_that("report_section_traces exposes failed section errors", {
  report <- structure(
    "report body",
    class = c("pkgreviewr_report", "character"),
    section_traces = list(
      improvements = list(
        section_id = "improvements",
        title = "⚠️ Improvements",
        status = "failed",
        attempts = list(list(attempt = 1L, status = "backend_error", error = "backend unavailable")),
        final_error = "backend unavailable"
      )
    )
  )

  trace <- pkgreviewr:::report_section_traces(report, "improvements")

  expect_identical(trace$final_error, "backend unavailable")
  expect_identical(trace$status, "failed")
})
