# Advanced Usage

`pkgreviewr` keeps the public API small, but the main entry point
supports a few useful advanced workflows:

- selecting your own LLM backend
- using an `ellmer` chat object
- generating sections in parallel
- persisting prompts, traces, and intermediate reports

## Backend Options

[`build_report()`](https://alekoure.github.io/pkgreviewr/reference/build_report.md)
accepts exactly one of:

- `chat_fn`, a function with signature `(system_prompt, user_prompt)`
- `chat`, an `ellmer` chat object inheriting from `Chat`

If neither is supplied, `pkgreviewr` will look for a local Ollama model
in `PKGREVIEWR_OLLAMA_MODEL` or `OLLAMA_MODEL`.

### Using `chat_fn`

Use `chat_fn` when you already have a provider SDK or want full control
over retry logic, authentication, or logging.

``` r
library(pkgreviewr)

my_chat_fn <- function(system_prompt, user_prompt) {
  stop("Connect your provider here")
}

report <- build_report(
  "https://github.com/dvdscripter/ini",
  chat_fn = my_chat_fn
)
```

### Using `ellmer`

Use `chat` when you want to hand `pkgreviewr` a preconfigured chat
object. The `ellmer` package documentation covers how to construct
provider-specific chat objects such as
[`chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html),
[`chat_anthropic()`](https://ellmer.tidyverse.org/reference/chat_anthropic.html),
and
[`chat_ollama()`](https://ellmer.tidyverse.org/reference/chat_ollama.html):
<https://ellmer.tidyverse.org>.

``` r
library(ellmer)
library(pkgreviewr)

chat <- chat_openai(model = "gpt-4.1-mini")

report <- build_report(
  "https://github.com/dvdscripter/ini",
  chat = chat
)
```

## Persisting Artifacts

Set `artifact_dir` when you want to inspect or keep intermediate files.
`pkgreviewr` writes:

- formatted review data and metadata
- section context and section system prompts
- section summaries, bodies, and traces
- synthesis prompts and trace
- draft and final reports
- provenance describing the prompt templates used

``` r
artifacts <- tempfile("pkgreviewr-artifacts-")

report <- build_report(
  "https://github.com/dvdscripter/ini",
  chat = chat,
  artifact_dir = artifacts
)

attr(report, "artifact_dir")
```

## Parallel Section Generation

Independent review sections can be generated in parallel. This is mainly
useful when the selected backend can tolerate concurrent requests and
the host system has spare cores.

``` r
report <- build_report(
  "https://github.com/dvdscripter/ini",
  chat = chat,
  parallel = TRUE,
  workers = 2L
)
```

## Inspecting Deterministic Signals First

You can inspect the collected local evidence before generating a report.

``` r
review_data <- collect_review_data("https://github.com/dvdscripter/ini")
str(review_data$signals, max.level = 1)
```

This is useful when you want to debug a collector, tailor prompts, or
compare local evidence with the final section output.
