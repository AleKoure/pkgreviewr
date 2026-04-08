# Internal report generator for the legacy single-prompt workflow.
#
# @param code Single prompt input generated from collected review data.
# @param path_to_report Output path for the generated report.
#
# @return Invisibly returns the generated report text.
# @keywords internal
# @noRd
generate_package_review_report <- function(code, path_to_report) {
  path_to_promt <- system.file(package = "pkgreviewr", "package_review_prompt.md")
  package_review_prompt <- readLines(path_to_promt) |> paste(collapse = "\n")

  chat <- ellmer::chat_google_gemini(
    system_prompt = package_review_prompt
  )

  response <- chat$chat(code)

  writeLines(response, path_to_report)
  message("Review report written to: ", path_to_report)
  invisible(response)
}

# Build a package review report.
#
# `build_report()` is the current end-user entry point. It collects package
# review data, generates a review with the configured LLM prompt, and writes
# the report to disk.
#
# @param package_url Repository URL to review.
# @param output_path Output path for the generated review report.
#
# @return Invisibly returns the generated report text.
# @export
build_report <- function(package_url, output_path = "test_review.md") {
  code <- remote_package_report(package_url)
  generate_package_review_report(code = code, path_to_report = output_path)
}
