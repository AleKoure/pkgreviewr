test_that("normalize_artifact_dir validates optional artifact paths", {
  expect_null(pkgreviewr:::normalize_artifact_dir(NULL))
  expect_error(
    pkgreviewr:::normalize_artifact_dir(character()),
    "`artifact_dir` must be `NULL` or a single non-empty string.",
    fixed = TRUE
  )
})

test_that("persist_review_artifacts writes prompts, traces, and reports when requested", {
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
    metadata = list(signal_names = c(
      "package_code",
      "coverage_report",
      "lint_report",
      "rcmd_check_report",
      "session_info"
    ))
  )

  strengths_result <- pkgreviewr:::new_section_result(
    section_id = "strengths",
    title = "✅ Strengths",
    body = "1. Clear API surface.",
    summary = "Clear API surface.",
    evidence_used = c("package_code"),
    warnings = character(),
    trace = list(
      section_id = "strengths",
      title = "✅ Strengths",
      status = "success",
      attempts = list(list(attempt = 1L, status = "success", error = NULL)),
      final_error = NULL
    )
  )

  synthesis_result <- pkgreviewr:::new_section_result(
    section_id = "overall_assessment",
    title = "Overall Assessment",
    body = "Overall body.",
    summary = "Overall preview.",
    evidence_used = c("strengths"),
    warnings = character(),
    trace = list(
      section_id = "overall_assessment",
      title = "Overall Assessment",
      status = "success",
      attempts = list(list(attempt = 1L, status = "success", error = NULL)),
      final_error = NULL
    )
  )

  artifact_dir <- tempfile("pkgreviewr-artifacts-")
  on.exit(unlink(artifact_dir, recursive = TRUE), add = TRUE)

  persisted_dir <- pkgreviewr:::persist_review_artifacts(
    artifact_dir = artifact_dir,
    review_data = review_data,
    section_results = list(strengths_result),
    synthesis_result = synthesis_result,
    draft_report = "# Audit report - pkg\n\nDraft body.",
    final_report = "# Audit report - pkg\n\nFinal body.",
    section_specs = pkgreviewr:::get_review_section_specs(),
    refinement_ran = TRUE
  )

  expect_identical(
    persisted_dir,
    normalizePath(artifact_dir, winslash = "/", mustWork = FALSE)
  )
  expect_true(file.exists(file.path(artifact_dir, "review-data.txt")))
  expect_true(file.exists(file.path(artifact_dir, "draft-report.md")))
  expect_true(file.exists(file.path(artifact_dir, "final-report.md")))
  expect_true(file.exists(file.path(artifact_dir, "provenance.dput")))
  expect_true(file.exists(file.path(artifact_dir, "sections", "strengths", "context.txt")))
  expect_true(file.exists(file.path(artifact_dir, "sections", "strengths", "system-prompt.txt")))
  expect_true(file.exists(file.path(artifact_dir, "sections", "strengths", "summary.txt")))
  expect_true(file.exists(file.path(artifact_dir, "sections", "strengths", "body.md")))
  expect_true(file.exists(file.path(artifact_dir, "sections", "strengths", "trace.dput")))
  expect_true(file.exists(file.path(artifact_dir, "synthesis", "system-prompt.txt")))
  expect_true(file.exists(file.path(artifact_dir, "synthesis", "user-prompt.txt")))
  expect_true(file.exists(file.path(artifact_dir, "synthesis", "trace.dput")))

  expect_match(
    paste(readLines(file.path(artifact_dir, "sections", "strengths", "context.txt")), collapse = "\n"),
    "Section ID: strengths",
    fixed = TRUE
  )
  expect_match(
    paste(readLines(file.path(artifact_dir, "sections", "strengths", "system-prompt.txt")), collapse = "\n"),
    "Section directive: ✅ Strengths",
    fixed = TRUE
  )
  expect_match(
    paste(readLines(file.path(artifact_dir, "synthesis", "user-prompt.txt")), collapse = "\n"),
    "strengths: Clear API surface.",
    fixed = TRUE
  )

  provenance <- dget(file.path(artifact_dir, "provenance.dput"))
  expect_true(isTRUE(provenance$refinement_ran))
  expect_match(provenance$review_guide_path, "package_review_prompt.md", fixed = TRUE)
  expect_match(
    provenance$section_templates$strengths$template_path,
    "strengths.md",
    fixed = TRUE
  )
})
