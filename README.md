
# pkgreviewr

The goal of pkgreviewr is to generate QA report using LLMs.

In this initial draft phase, it gathers data using:

- `devtools::check()`
- `lintr::lint_package()`
- `covr::package_coverage()`
- Dump package to a single file

and performs an API call with `ellmer` and this [prompt](./inst/package_review_prompt.md)

## How to use

1. Get Gemini API key: https://aistudio.google.com/app/api-keys

2. Add Gemini API key as the environmental variable (e.g., `usethis::edit_r_environ()`) and restart R:

```
GEMINI_API_KEY={YOUR_API_KEY}
```

3. Install `pkgreviewr` package:

```
pak::pak("AleKoure/pkgreviewr")
```

4. This is a basic example that generates a report for the `ini` package

``` r
library(pkgreviewr)
build_report("https://github.com/dvdscripter/ini")
```

- [Example report generated for `ini`](./test_review.md)
