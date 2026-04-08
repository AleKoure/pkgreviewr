test_that("create_diagnostic_sandbox returns a writable library path", {
  sandbox <- pkgreviewr:::create_diagnostic_sandbox()

  expect_true(dir.exists(sandbox$library_path))
  expect_true(dir.exists(sandbox$root_path))
})

test_that("run_in_callr_sandbox executes inside the target directory and library path", {
  pkg_dir <- withr::local_tempdir()
  sandbox <- pkgreviewr:::create_diagnostic_sandbox()

  result <- pkgreviewr:::run_in_callr_sandbox(
    path_to_package = pkg_dir,
    library_path = sandbox$library_path,
    callback = function(path_to_package, library_path) {
      list(
        working_directory = getwd(),
        library_paths = .libPaths()
      )
    }
  )

  expect_identical(normalizePath(result$working_directory), normalizePath(pkg_dir))
  expect_identical(normalizePath(result$library_paths[[1]]), normalizePath(sandbox$library_path))
})

test_that("run_in_callr_sandbox rejects non-function callbacks", {
  sandbox <- pkgreviewr:::create_diagnostic_sandbox()

  expect_error(
    pkgreviewr:::run_in_callr_sandbox(tempdir(), sandbox$library_path, "nope"),
    "`callback` must be a function.",
    fixed = TRUE
  )
})
