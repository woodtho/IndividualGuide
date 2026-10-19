# Contributing

File reproducible bugs and feature requests in GitHub Issues. Include your app version, operating system, steps and a small public-data example. Review logs and project archives before sharing them: they may contain data, file paths, R scripts and connection settings.

Develop with R and the dependencies in DESCRIPTION, `pkgload` and `testthat`:

```r
pkgload::load_all()
IndividualGuide::run_app()
testthat::test_local()
```

Use `tools/test-focused.R <filter>` for a relevant R test group. Desktop builds require Node/npm and Pandoc; see [release instructions](RELEASING.md). Keep user data and generated files outside the source tree. Add a regression test for behavior changes and describe the trigger, result and validation in your pull request.
