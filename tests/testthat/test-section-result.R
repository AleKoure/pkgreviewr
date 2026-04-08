test_that("new_section_result returns a validated section_result object", {
  section_result <- pkgreviewr:::new_section_result(
    section_id = "package_summary",
    title = "Package Summary",
    body = "Detailed section body.",
    summary = "Short summary.",
    evidence_used = c("description", "readme"),
    warnings = "none"
  )

  expect_s3_class(section_result, "pkgreviewr_section_result")
  expect_identical(section_result$section_id, "package_summary")
  expect_identical(section_result$summary, "Short summary.")
})

test_that("validate_section_result requires a non-empty summary", {
  section_result <- list(
    section_id = "package_summary",
    title = "Package Summary",
    body = "Detailed section body.",
    summary = "",
    evidence_used = character(),
    warnings = character()
  )
  class(section_result) <- c("pkgreviewr_section_result", "list")

  expect_error(
    pkgreviewr:::validate_section_result(section_result),
    "`section_result$summary` must be a single non-empty string.",
    fixed = TRUE
  )
})

test_that("validate_section_result requires character evidence and warnings", {
  section_result <- list(
    section_id = "package_summary",
    title = "Package Summary",
    body = "Detailed section body.",
    summary = "Short summary.",
    evidence_used = list("description"),
    warnings = character()
  )
  class(section_result) <- c("pkgreviewr_section_result", "list")

  expect_error(
    pkgreviewr:::validate_section_result(section_result),
    "`section_result$evidence_used` must be a character vector.",
    fixed = TRUE
  )
})
