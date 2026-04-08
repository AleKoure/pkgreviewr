test_that("build_review_data returns a validated review_data object", {
  review_data <- pkgreviewr:::build_review_data(
    package_ref = "https://example.com/pkg.git",
    source_path = "/tmp/pkg",
    package_code = c("line1", "line2"),
    coverage_report = "coverage",
    lint_report = "lint",
    rcmd_check_report = "check",
    session_info = "session"
  )

  expect_s3_class(review_data, "pkgreviewr_review_data")
  expect_named(
    review_data$signals,
    c(
      "package_code",
      "coverage_report",
      "lint_report",
      "rcmd_check_report",
      "session_info"
    )
  )
})

test_that("format_review_data renders all collected signals", {
  review_data <- pkgreviewr:::new_review_data(
    package_ref = "pkg",
    source_path = "/tmp/pkg",
    signals = list(
      package_code = c("a <- 1", "b <- 2"),
      lint_report = "no lints"
    ),
    metadata = list()
  )

  rendered <- pkgreviewr:::format_review_data(review_data)

  expect_match(rendered, "package_code")
  expect_match(rendered, "a <- 1")
  expect_match(rendered, "lint_report")
  expect_match(rendered, "no lints")
})
