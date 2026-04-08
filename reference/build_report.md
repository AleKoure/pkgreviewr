# Build a package review report.

`build_report()` is the main end-user entry point. It collects
deterministic package diagnostics, generates report sections
independently, synthesizes an overall assessment from section summaries,
optionally persists intermediate artifacts, and writes the final
markdown report to disk.

## Usage

``` r
build_report(
  package_url,
  output_path = "test_review.md",
  chat_fn = NULL,
  chat = NULL,
  parallel = FALSE,
  workers = 1L,
  artifact_dir = NULL
)
```

## Arguments

- package_url:

  Repository URL to review.

- output_path:

  Output path for the generated markdown report.

- chat_fn:

  Optional chat function with signature `(system_prompt, user_prompt)`.

- chat:

  Optional `ellmer` chat object inheriting from `Chat`.

- parallel:

  Whether to generate independent review sections in parallel when
  possible.

- workers:

  Number of workers to use when `parallel = TRUE`.

- artifact_dir:

  Optional directory for persisted prompts, traces, section context, and
  intermediate reports.

## Value

Invisibly returns a `pkgreviewr_report` character vector with attached
draft report, section results, section traces, artifact path, and
provenance metadata.

## Details

Supply exactly one backend source with `chat_fn` or `chat`, or configure
a local Ollama model via `PKGREVIEWR_OLLAMA_MODEL` or `OLLAMA_MODEL`.
See the `ellmer` package documentation for provider-specific chat object
constructors such as
[`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html).

## Examples

``` r
if (FALSE) { # \dontrun{
my_chat_fn <- function(system_prompt, user_prompt) {
  stop("Connect your preferred chat backend here")
}

report <- build_report(
  "https://github.com/dvdscripter/ini",
  chat_fn = my_chat_fn,
  artifact_dir = tempfile("pkgreviewr-artifacts-")
)

chat <- ellmer::chat_openai(model = "gpt-4.1-mini")

build_report(
  "https://github.com/dvdscripter/ini",
  chat = chat,
  parallel = TRUE,
  workers = 2L
)
} # }
```
