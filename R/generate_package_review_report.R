generate_package_review_report <- function(code, path_to_report) {
  path_to_promt <- system.file(package = "pkgreviewr", "package_review_prompt.md")
  package_review_prompt <- readLines(path_to_promt) |> paste(collapse = "\n")

  chat <- ellmer::chat_google_gemini(
    system_prompt = package_review_prompt
  )

  response <- chat$chat(code)

  writeLines(response, path_to_report)
  message("📄 Review report written to: ", path_to_report)
  invisible(response)
}

build_report <- function(package_url, output_path = "test_review.md") {
  code <- remote_package_report(package_url)
  generate_package_review_report(code = code, path_to_report = output_path)
}
