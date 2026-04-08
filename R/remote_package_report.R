# Generate the legacy single-prompt review input.
#
# This helper preserves the current end-to-end flow by collecting deterministic
# review signals and flattening them into one string for the report generator.
#
# @param package_url Repository URL to review.
#
# @return A single character string containing the collected review input.
# @keywords internal
# @noRd
remote_package_report <- function(package_url) {
  review_data <- collect_review_data(package_url)
  format_review_data(review_data)
}

# Collect deterministic review data for a package repository.
#
# This is the current structured collection entry point. It acquires the
# package source, runs local QA tooling, and returns a validated internal data
# object that later report steps can consume.
#
# @param package_url Repository URL to review.
#
# @return A `pkgreviewr_review_data` object.
# @export
collect_review_data <- function(package_url) {
  local_path <- withr::local_tempdir()
  git2r::clone(package_url, local_path = local_path)
  rcmd_check <- get_rcmd_check(local_path)

  build_review_data(
    package_ref = package_url,
    source_path = local_path,
    package_code = rdocdump::rdd_extract_code(
      local_path,
      include_roxygen = TRUE,
      include_tests = TRUE,
      force_fetch = FALSE,
      repos = c("CRAN" = "https://cran.r-project.org")
    ),
    coverage_report = get_coverage_report(local_path),
    lint_report = get_lint_report(local_path),
    rcmd_check_report = rcmd_check$stdout,
    session_info = as.character(rcmd_check$session_info)
  )
}

# Internal coverage collector.
#
# @param path_to_package Path to the package source.
#
# @return Coverage output formatted for downstream review steps.
# @keywords internal
# @noRd
get_coverage_report <- function(path_to_package) {
  coverage_results <- covr::package_coverage(path = path_to_package, quiet = TRUE)
  covr::coverage_to_list(coverage_results) |> dput()
}

# Internal lint collector.
#
# @param path_to_package Path to the package source.
#
# @return Character vector of lints.
# @keywords internal
# @noRd
get_lint_report <- function(path_to_package) {
  lints <- lintr::lint_package(path_to_package)
  as.character(lints)
}

# Internal `R CMD check` runner.
#
# @param path_to_package Path to the package source.
#
# @return `devtools::check()` result.
# @keywords internal
# @noRd
get_rcmd_check <- function(path_to_package) {
  result <- devtools::check(pkg = path_to_package)
  result
}
