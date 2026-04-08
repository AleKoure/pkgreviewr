test_that("new_section_context returns a validated section_context object", {
  section_context <- pkgreviewr:::new_section_context(
    section_id = "strengths",
    title = "Strengths",
    focus = "Focus text.",
    evidence_blocks = list(package_code = "## Package Code
code"),
    evidence_used = c("package_code")
  )

  expect_s3_class(section_context, "pkgreviewr_section_context")
  expect_identical(section_context$section_id, "strengths")
  expect_identical(section_context$evidence_used, c("package_code"))
})

test_that("validate_section_context requires character evidence identifiers", {
  section_context <- list(
    section_id = "strengths",
    title = "Strengths",
    focus = "Focus text.",
    evidence_blocks = list(package_code = "## Package Code
code"),
    evidence_used = list("package_code")
  )
  class(section_context) <- c("pkgreviewr_section_context", "list")

  expect_error(
    pkgreviewr:::validate_section_context(section_context),
    "`section_context$evidence_used` must be a character vector.",
    fixed = TRUE
  )
})

test_that("build_section_context uses explicit section evidence specs", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    signals = list(
      package_code = paste(rep("code", 3000), collapse = ""),
      coverage_report = "95%",
      lint_report = "lint summary",
      rcmd_check_report = "0 errors, 0 warnings",
      session_info = "R 4.4"
    ),
    metadata = list()
  )

  section_spec <- pkgreviewr:::get_review_section_specs()$technical_details
  section_context <- pkgreviewr:::build_section_context(review_data, section_spec)

  expect_s3_class(section_context, "pkgreviewr_section_context")
  expect_identical(
    section_context$evidence_used,
    c("session_info", "lint_report", "rcmd_check_report", "coverage_report")
  )
  expect_false("package_code" %in% section_context$evidence_used)
  expect_true(grepl("Session Info", section_context$evidence_blocks$session_info, fixed = TRUE))
})
