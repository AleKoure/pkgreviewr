# Collect deterministic review data for a package repository.

`collect_review_data()` clones a package repository, installs its
dependencies in an isolated library, runs local QA tooling in a
subprocess, and returns the structured signals used by the section-based
review pipeline. This is useful when you want to inspect the
deterministic evidence before running any LLM-backed report generation.

## Usage

``` r
collect_review_data(package_url)
```

## Arguments

- package_url:

  Repository URL to review.

## Value

A `pkgreviewr_review_data` object containing the package reference,
local source path, collected signals, and metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
review_data <- collect_review_data("https://github.com/dvdscripter/ini")
} # }
```
