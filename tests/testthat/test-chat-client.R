new_mock_chat <- function() {
  chat <- new.env(parent = emptyenv())
  chat$system_prompt <- NULL
  chat$clone <- function(deep = TRUE) {
    clone <- new_mock_chat()
    clone$system_prompt <- chat$system_prompt
    clone
  }
  chat$set_system_prompt <- function(system_prompt) {
    chat$system_prompt <- system_prompt
    invisible(chat)
  }
  chat$chat <- function(user_prompt) {
    paste(chat$system_prompt, user_prompt, sep = "\n---\n")
  }
  class(chat) <- c("Chat", "R6")
  chat
}

test_that("validate_chat_object rejects non-chat objects", {
  expect_error(
    pkgreviewr:::validate_chat_object(list()),
    "`chat` must inherit from 'Chat'.",
    fixed = TRUE
  )
})

test_that("chat_fn_from_chat adapts ellmer-style chat objects", {
  chat_fn <- pkgreviewr:::chat_fn_from_chat(new_mock_chat())
  response <- chat_fn("system", "user")

  expect_identical(response, "system\n---\nuser")
})

test_that("resolve_chat_backend rejects conflicting chat inputs", {
  expect_error(
    pkgreviewr:::resolve_chat_backend(chat_fn = identity, chat = new_mock_chat()),
    "Supply only one of `chat_fn` or `chat`.",
    fixed = TRUE
  )
})

test_that("resolve_chat_backend rejects invalid chat_fn values", {
  expect_error(
    pkgreviewr:::resolve_chat_backend(chat_fn = "nope"),
    "`chat_fn` must be a function.",
    fixed = TRUE
  )
})

test_that("resolve_chat_backend requires explicit input when no local backend exists", {
  original_ollama_model <- Sys.getenv("PKGREVIEWR_OLLAMA_MODEL", unset = NA_character_)
  original_model <- Sys.getenv("OLLAMA_MODEL", unset = NA_character_)
  Sys.unsetenv("PKGREVIEWR_OLLAMA_MODEL")
  Sys.unsetenv("OLLAMA_MODEL")
  on.exit({
    if (is.na(original_ollama_model)) Sys.unsetenv("PKGREVIEWR_OLLAMA_MODEL") else Sys.setenv(PKGREVIEWR_OLLAMA_MODEL = original_ollama_model)
    if (is.na(original_model)) Sys.unsetenv("OLLAMA_MODEL") else Sys.setenv(OLLAMA_MODEL = original_model)
  }, add = TRUE)

  expect_error(
    pkgreviewr:::resolve_chat_backend(),
    "Provide `chat_fn` or `chat`",
    fixed = TRUE
  )
})

test_that("generate_package_review_report uses a supplied chat function", {
  path <- tempfile(fileext = ".md")
  on.exit(unlink(path), add = TRUE)

  chat_fn <- function(system_prompt, user_prompt) {
    expect_true(is.character(system_prompt))
    expect_length(system_prompt, 1)
    expect_identical(user_prompt, "input payload")
    "custom response"
  }

  response <- pkgreviewr:::generate_package_review_report(
    code = "input payload",
    path_to_report = path,
    chat_fn = chat_fn
  )

  expect_identical(response, "custom response")
  expect_identical(readLines(path), "custom response")
})

test_that("generate_package_review_report uses a supplied chat object", {
  path <- tempfile(fileext = ".md")
  on.exit(unlink(path), add = TRUE)

  response <- pkgreviewr:::generate_package_review_report(
    code = "input payload",
    path_to_report = path,
    chat = new_mock_chat()
  )

  expect_match(response, "input payload", fixed = TRUE)
  expect_identical(paste(readLines(path), collapse = "\n"), response)
})


test_that("refine_review_report uses the package review prompt and returns refined output", {
  refined <- pkgreviewr:::refine_review_report(
    report = "# Audit report - pkg\n\n## ✅ Strengths\n1. Strong API.",
    chat_fn = function(system_prompt, user_prompt) {
      expect_match(system_prompt, "AI Review Prompt for R Packages", fixed = TRUE)
      expect_match(system_prompt, "Return only the final markdown report.", fixed = TRUE)
      expect_match(system_prompt, "## ✅ Strengths", fixed = TRUE)
      expect_match(system_prompt, "Beautify the report in the gluing layer", fixed = TRUE)
      expect_match(user_prompt, "# Audit report - pkg", fixed = TRUE)
      "# Audit report - pkg\n\n## ✅ Strengths\n1. Refined strength."
    }
  )

  expect_match(refined, "Refined strength.", fixed = TRUE)
})

test_that("refine_review_report falls back to the draft report on backend failure", {
  draft_report <- "# Audit report - pkg\n\n## ✅ Strengths\n1. Strong API."

  refined <- pkgreviewr:::refine_review_report(
    report = draft_report,
    chat_fn = function(system_prompt, user_prompt) stop("refinement backend unavailable")
  )

  expect_identical(refined, draft_report)
})


test_that("normalize_final_report removes repeated top metadata and duplicate sections", {
  report <- paste(
    "# Audit report - ini",
    "",
    "Reviewed source: https://github.com/dvdscripter/ini",
    "",
    "> Preview: Top preview.",
    "",
    "# Audit report - ini",
    "",
    "## ✅ Strengths",
    "- Short strength.",
    "",
    "## ✅ Strengths",
    "",
    "> Preview: Better strength.",
    "",
    "1. Detailed strength.",
    "",
    "## ⚠️ Improvements",
    "",
    "> Preview: Improvement preview.",
    "",
    "1. Detailed improvement.",
    sep = "\n"
  )

  cleaned <- pkgreviewr:::normalize_final_report(report)
  cleaned_lines <- strsplit(cleaned, "\n", fixed = TRUE)[[1]]

  expect_identical(length(grep("^# Audit report - ", cleaned_lines)), 1L)
  expect_identical(length(grep("^Reviewed source:", cleaned_lines)), 1L)
  expect_identical(length(grep("^## ✅ Strengths$", cleaned_lines)), 1L)
  expect_match(cleaned, "Better strength.", fixed = TRUE)
  expect_match(cleaned, "Detailed strength.", fixed = TRUE)
  expect_false(grepl("Short strength.", cleaned, fixed = TRUE))
})

test_that("normalize_final_report keeps fuller earlier sections when later duplicates are partial", {
  report <- paste(
    "# Audit report - ini",
    "",
    "Reviewed source: https://github.com/dvdscripter/ini",
    "",
    "> Preview: Top preview.",
    "",
    "## 🚫 Red Flags",
    "",
    "> Preview: No blockers.",
    "",
    "1. No major blockers identified.",
    "",
    "## Technical Details",
    "",
    "> Preview: Technical details preview.",
    "",
    "1. Coverage is high.",
    "",
    "# Audit report - ini",
    "",
    "## 🚫 Red Flags",
    "No red flags identified.",
    sep = "\n"
  )

  cleaned <- pkgreviewr:::normalize_final_report(report)

  expect_match(cleaned, "1. No major blockers identified.", fixed = TRUE)
  expect_match(cleaned, "## Technical Details", fixed = TRUE)
  expect_match(cleaned, "1. Coverage is high.", fixed = TRUE)
})
