# Audit report - ini

Reviewed source: <https://github.com/dvdscripter/ini>

> Preview: The package demonstrates strong documentation and test
> coverage but requires critical correctness fixes for an opaque crash
> in `read.ini` and structural improvements to meet rOpenSci standards.

Overall, the package is reliable and well-documented but needs immediate
attention to a critical crash bug and performance refactoring before it
fully meets rOpenSci and tidyverse standards.

## ✅ Strengths

1.  Excellent test coverage (97.73%) for `R/ini.R`, indicating thorough
    validation of the parsing and writing logic.
2.  Proper resource management using `on.exit(close(con))` in both
    `read.ini` and `write.ini` to prevent connection leaks.
3.  Comprehensive roxygen2 documentation with executable `@examples` for
    both exported functions.
4.  Passes `R CMD check --as-cran` with zero errors and zero warnings.
5.  Focused, intuitive API consisting of two complementary functions
    with explicit encoding support.

## ⚠️ Improvements

1.  Add at least one HTML vignette and package-level documentation
    (`?ini-package`) to meet rOpenSci structural compliance.
2.  Handle key-value pairs that appear before the first section header;
    currently, `lastSection` is undefined in this scenario, leading to
    dropped data or errors.
3.  Replace the custom `index()` character-by-character loop with
    vectorized base R functions like
    [`regexpr()`](https://rdrr.io/r/base/grep.html) or
    `strsplit(..., fixed = TRUE)` to find the `=` delimiter; the current
    implementation is inefficient and over-engineered.
4.  Fix documentation typos in `read.ini` and `write.ini` (e.g.,
    “specifield” should be “specified”).
5.  Address tidyverse style linter warnings: rename functions to
    `read_ini`/`write_ini` (or provide snake_case aliases), use `<-`
    instead of `=` for assignment, use double quotes consistently, and
    remove the explicit
    [`return()`](https://rdrr.io/r/base/function.html).
6.  Remove the legacy `.travis.yml` file and migrate continuous
    integration to GitHub Actions.

## 🔧 Suggestions

1.  In `read.ini()`, replace the custom `index()` helper and manual
    string splicing with `strsplit(line, "=", fixed = TRUE)` or
    [`regmatches()`](https://rdrr.io/r/base/regmatches.html) on the
    existing `keyValueREGEXP` match for vectorized key-value extraction.
2.  Remove the internal `trim()` function and use the base R
    [`trimws()`](https://rdrr.io/r/base/trimws.html).
3.  Simplify `read.ini()` file reading by calling `readLines(con)` once,
    then iterating over the character vector instead of using a
    `while(TRUE)` loop with single-line reads.
4.  Replace the awkward list-append-and-rename pattern in `read.ini()`
    with direct named assignment: `ini[[last_section]][[key]] <- value`.
5.  Refactor `write.ini()` iteration by looping over
    `names(x[[section]])` and accessing values via
    `x[[section]][[key_name]]`, removing the need to subset the list and
    extract names inside the loop.
6.  Adopt snake_case for internal variables (e.g., `section_regexp`) and
    function names.

## 🚫 Red Flags

1.  **Crash on global key-value pairs**: If `read.ini()` encounters a
    key-value line before any `[section]` header, it fails with
    `Error: object 'lastSection' not found` instead of handling the line
    gracefully or providing a clear user-facing message. This is a
    common INI file pattern and poses a significant usability and
    correctness risk.
2.  **Fragile internal parsing logic**: The custom `index()` helper and
    manual string splicing bypass R’s robust string matching tools,
    creating potential edge-case errors.

## Technical Details

1.  **Session Info**: R 4.4.0 running on Ubuntu 22.04.4 LTS (x86_64).
2.  **Lints**: `R/ini.R` generated multiple style violations:
    - **Naming**: `read.ini`, `equalPosition`, `sectionREGEXP`, and
      `keyValueREGEXP` do not conform to snake_case
      (`object_name_linter`).
    - **Syntax**: Used `=` instead of `<-` for assignment
      (`assignment_linter`), missing space before `(` in `for` loop
      (`spaces_left_parentheses_linter`), single quotes instead of
      double quotes (`quotes_linter`), and an explicit
      [`return()`](https://rdrr.io/r/base/function.html) call
      (`return_linter`).
3.  **R CMD check**: Completed with 2 NOTEs:
    - Hidden file `.travis.yml` included in package root.
    - Unable to verify current time for future file timestamps.
4.  **Code Coverage**: 97.73% for `R/ini.R`.
