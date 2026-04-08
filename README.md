# pkgreviewr

`pkgreviewr` reviews R packages by collecting deterministic QA signals and using
an LLM to draft a package review report.

The current implementation does this in two stages:

- `collect_review_data()` acquires a repository and gathers local review
  signals.
- `build_report()` formats those signals into the current prompt workflow and
  writes the generated report to disk.

Collected signals currently include:

- `devtools::check()` output
- `lintr::lint_package()` output
- `covr::package_coverage()` output
- package source extracted with `rdocdump`

The package is being refactored toward a section-based review architecture.
Today, `build_report()` remains the stable end-to-end entry point, while lower
level helpers stay internal.

## Installation

```r
pak::pak("AleKoure/pkgreviewr")
```

## Usage

`build_report()` now generates independent review sections, each with a body and summary. This usually means more LLM calls, but each call is smaller and more focused. You can also opt into parallel section generation with `parallel = TRUE` on Unix-like systems.

`build_report()` no longer hardcodes a remote provider. You can either:

- pass `chat_fn`, a function with signature `(system_prompt, user_prompt)`
- pass `chat`, an `ellmer` chat object inheriting from `Chat`
- configure a local Ollama model via `PKGREVIEWR_OLLAMA_MODEL` or `OLLAMA_MODEL`

Generate a report with a custom chat function:

```r
library(pkgreviewr)

my_chat_fn <- function(system_prompt, user_prompt) {
  stop("Connect your preferred chat backend here")
}

build_report(
  "https://github.com/dvdscripter/ini",
  chat_fn = my_chat_fn
)
```

Generate a report with an `ellmer` chat object:

```r
library(ellmer)
library(pkgreviewr)

chat <- chat_openai(model = "gpt-4.1-mini")

build_report(
  "https://github.com/dvdscripter/ini",
  chat = chat
)
```

Use a local Ollama backend by configuring a model name:

```sh
export PKGREVIEWR_OLLAMA_MODEL=llama3.2
```

Collect structured review data without generating a report:

```r
library(pkgreviewr)
review_data <- collect_review_data("https://github.com/dvdscripter/ini")
```

- [Example report generated for `ini`](./test_review.md)
