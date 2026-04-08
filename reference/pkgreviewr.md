# pkgreviewr: Section-Based QA Reviews for R Packages

`pkgreviewr` combines deterministic local QA signals with section-wise
LLM generation to review R packages. The main public entry points are
[`collect_review_data()`](https://alekoure.github.io/pkgreviewr/reference/collect_review_data.md)
for structured signal collection and
[`build_report()`](https://alekoure.github.io/pkgreviewr/reference/build_report.md)
for end-to-end report generation. For provider-specific chat object
setup, see the `ellmer` documentation at <https://ellmer.tidyverse.org>.
