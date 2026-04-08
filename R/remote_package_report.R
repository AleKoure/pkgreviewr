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
  sandbox <- create_diagnostic_sandbox()

  install_package_dependencies(local_path, sandbox$library_path)
  diagnostics <- collect_package_diagnostics(local_path, sandbox$library_path)

  build_review_data(
    package_ref = package_url,
    source_path = local_path,
    package_code = diagnostics$package_code,
    coverage_report = diagnostics$coverage_report,
    lint_report = diagnostics$lint_report,
    rcmd_check_report = diagnostics$rcmd_check_report,
    session_info = diagnostics$session_info
  )
}

# Internal sandbox descriptor for package diagnostics.
#
# @return A list containing sandbox paths.
# @keywords internal
# @noRd
create_diagnostic_sandbox <- function() {
  root_path <- tempfile("pkgreviewr-sandbox-")
  dir.create(root_path, recursive = TRUE, showWarnings = FALSE)
  library_path <- file.path(root_path, "library")
  dir.create(library_path, recursive = TRUE, showWarnings = FALSE)

  list(
    root_path = root_path,
    library_path = library_path
  )
}

# Internal sandboxed subprocess runner.
#
# @param path_to_package Path to the package source.
# @param library_path Sandbox library path.
# @param callback Serializable callback run inside the subprocess.
#
# @return Result returned by `callback`.
# @keywords internal
# @noRd
run_in_callr_sandbox <- function(path_to_package, library_path, callback) {
  if (!is.function(callback)) {
    stop("`callback` must be a function.", call. = FALSE)
  }

  callr::r(
    func = function(path_to_package, library_path, callback) {
      withr::with_options(list(repos = c(CRAN = "https://cran.r-project.org")), {
        withr::with_dir(path_to_package, {
          withr::with_libpaths(new = library_path, action = "prefix", {
            callback(path_to_package, library_path)
          })
        })
      })
    },
    args = list(
      path_to_package = path_to_package,
      library_path = library_path,
      callback = callback
    )
  )
}

# Internal dependency installer for downloaded packages.
#
# @param path_to_package Path to the package source.
# @param library_path Sandbox library path.
#
# @return Invisibly returns `TRUE` on success.
# @keywords internal
# @noRd
install_package_dependencies <- function(path_to_package, library_path) {
  run_in_callr_sandbox(
    path_to_package = path_to_package,
    library_path = library_path,
    callback = function(path_to_package, library_path) {
      devtools::install_deps(
        pkg = path_to_package,
        dependencies = TRUE,
        upgrade = "never",
        quiet = TRUE
      )

      invisible(TRUE)
    }
  )
}

# Internal sandboxed diagnostic collector.
#
# @param path_to_package Path to the package source.
# @param library_path Sandbox library path.
#
# @return A named list of collected diagnostic signals.
# @keywords internal
# @noRd
collect_package_diagnostics <- function(path_to_package, library_path) {
  run_in_callr_sandbox(
    path_to_package = path_to_package,
    library_path = library_path,
    callback = function(path_to_package, library_path) {
      coverage_results <- covr::package_coverage(path = path_to_package, quiet = TRUE)
      rcmd_check <- devtools::check(pkg = path_to_package, error_on = "never")

      list(
        package_code = rdocdump::rdd_extract_code(
          path_to_package,
          include_roxygen = TRUE,
          include_tests = TRUE,
          force_fetch = FALSE,
          repos = c("CRAN" = "https://cran.r-project.org")
        ),
        coverage_report = paste(capture.output(dput(covr::coverage_to_list(coverage_results))), collapse = "\n"),
        lint_report = as.character(lintr::lint_package(path_to_package)),
        rcmd_check_report = rcmd_check$stdout,
        session_info = as.character(rcmd_check$session_info)
      )
    }
  )
}
