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

Set a Gemini API key in your environment, for example via
`usethis::edit_r_environ()`, then restart R:

```sh
GEMINI_API_KEY={YOUR_API_KEY}
```

Generate a report for a repository:

```r
library(pkgreviewr)
build_report("https://github.com/dvdscripter/ini")
```

Collect structured review data without generating a report:

```r
library(pkgreviewr)
review_data <- collect_review_data("https://github.com/dvdscripter/ini")
```

- [Example report generated for `ini`](./test_review.md)
