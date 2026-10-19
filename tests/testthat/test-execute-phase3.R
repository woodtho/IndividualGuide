# Phase-3 graph and analysis tasks via execute_phase3_task / build_phase3_code.

tabs <- tables_fixture()
cars <- tabs$cars

p3 <- function(type_id, ...) {
  set_params(default_phase3_params(type_id, output_name = "p3_out"), ...)
}

# ── Graph tasks — all ten types must produce a girafe plot + data ──────────────

graph_specs <- list(
  bar_chart       = list(input_table = "sales", x = "region"),
  bar_line_chart  = list(input_table = "sales", x = "region", y = "qty"),
  box_plot        = list(input_table = "cars",  x = "cyl",  y = "mpg"),
  bubble_plot     = list(input_table = "cars",  x = "wt",   y = "mpg", size = "hp"),
  contour_plot    = list(input_table = "cars",  x = "wt",   y = "mpg"),
  histogram_graph = list(input_table = "cars",  x = "mpg"),
  line_plot       = list(input_table = "sales", x = "date", y = "qty"),
  pie_chart       = list(input_table = "sales", x = "region"),
  scatter_plot    = list(input_table = "cars",  x = "wt",   y = "mpg",
                         group = "car"),
  scatter_matrix  = list(input_table = "cars",  cols = c("mpg", "wt", "hp"))
)

for (type in names(graph_specs)) {
  local({
    type_id <- type
    spec    <- graph_specs[[type]]
    test_that(paste0("graph task '", type_id, "' renders"), {
      p <- do.call(p3, c(list(type_id), spec))
      res <- execute_phase3_task(type_id, p, tabs)
      expect_null(res$error)
      expect_s3_class(res$plot, "girafe")
      expect_s3_class(res$objects$image, "ggplot")
      expect_true(is.data.frame(res$data))
      code <- build_phase3_code(type_id, p)
      expect_no_error(parse(text = code))
    })
  })
}

test_that("graph tooltips are wired into the interactive layers", {
  # scatter: per-point tooltip listing the mapped columns
  p <- p3("scatter_plot", input_table = "cars", x = "wt", y = "mpg")
  res <- execute_phase3_task("scatter_plot", p, tabs)
  tip <- res$objects$image$layers[[1]]$mapping$tooltip
  expect_false(is.null(tip))
  expect_match(rlang::as_label(tip), "wt")
  # count bar: tooltip from the computed stat
  pb <- p3("bar_chart", input_table = "sales", x = "region")
  resb <- execute_phase3_task("bar_chart", pb, tabs)
  tipb <- resb$objects$image$layers[[1]]$mapping$tooltip
  expect_match(rlang::as_label(tipb), "count")
})

test_that("bar_chart aggregates counts in its result data", {
  p <- p3("bar_chart", input_table = "sales", x = "region")
  res <- execute_phase3_task("bar_chart", p, tabs)
  expect_setequal(names(res$data), c("region", "n"))
  expect_equal(sum(res$data$n), nrow(tabs$sales))
})

test_that("histogram result data is binned, not raw rows", {
  p <- p3("histogram_graph", input_table = "cars", x = "mpg", bins = 10L)
  res <- execute_phase3_task("histogram_graph", p, tabs)
  expect_true(all(c("bin_start", "bin_end", "count") %in% names(res$data)))
  expect_equal(sum(res$data$count), nrow(cars))
})

test_that("graph tasks validate their column mappings", {
  expect_match(
    execute_phase3_task("scatter_plot",
      p3("scatter_plot", input_table = "cars", x = "wt"), tabs)$error,
    "Y/value")
  expect_match(
    execute_phase3_task("histogram_graph",
      p3("histogram_graph", input_table = "sales", x = "region"), tabs)$error,
    "numeric")
  expect_match(
    execute_phase3_task("bar_chart",
      p3("bar_chart", input_table = "cars", x = "nope"), tabs)$error,
    "not found")
})

# ── Analysis tasks ─────────────────────────────────────────────────────────────

test_that("correlations return matrix + tidy pairs", {
  p <- p3("correlations", input_table = "cars",
          predictors = c("mpg", "wt", "hp"))
  res <- execute_phase3_task("correlations", p, tabs)
  expect_null(res$error)
  expect_true(is.matrix(res$objects$matrix))
  expect_equal(dim(res$objects$matrix), c(3, 3))
  expect_equal(nrow(res$data), 9L)
})

test_that("pca returns scree, loadings, scores and predictions", {
  p <- p3("pca", input_table = "cars", predictors = c("mpg", "wt", "hp"),
          pred_table = "cars")
  res <- execute_phase3_task("pca", p, tabs)
  expect_null(res$error)
  expect_s3_class(res$objects$model, "prcomp")
  expect_true(is.data.frame(res$objects$loadings))
  expect_true(is.data.frame(res$objects$scores))
  expect_true(is.data.frame(res$objects$predictions))
  expect_equal(nrow(res$objects$predictions), nrow(cars))
})

test_that("cluster_analysis returns centres, assignments and fit", {
  p <- p3("cluster_analysis", input_table = "cars",
          predictors = c("mpg", "wt"), k = 3L)
  res <- execute_phase3_task("cluster_analysis", p, tabs)
  expect_null(res$error)
  expect_s3_class(res$objects$model, "kmeans")
  expect_equal(nrow(res$data), 3L)                      # 3 centres
  expect_equal(nrow(res$objects$clusters), nrow(cars))  # row assignments
})

test_that("linear regression returns broom outputs + predictions", {
  p <- p3("linear_regression", input_table = "cars",
          response = "mpg", predictors = c("wt", "hp"),
          pred_table = "cars", pred_conf_int = TRUE)
  res <- execute_phase3_task("linear_regression", p, tabs)
  expect_null(res$error)
  expect_s3_class(res$objects$model, "lm")
  expect_true(all(c("term", "estimate", "p.value") %in% names(res$data)))
  expect_equal(nrow(res$data), 3L)   # intercept + 2 predictors
  expect_true(is.data.frame(res$objects$glance))
  expect_true(is.data.frame(res$objects$augment))
  expect_true(is.data.frame(res$objects$predictions))
})

test_that("logistic regression and glm fit", {
  p <- p3("logistic_regression", input_table = "cars",
          response = "am", predictors = c("wt", "hp"))
  # mtcars am ~ wt + hp is near-separable; the fit converges with warnings
  res <- suppressWarnings(execute_phase3_task("logistic_regression", p, tabs))
  expect_null(res$error)
  expect_s3_class(res$objects$model, "glm")
  expect_equal(stats::family(res$objects$model)$family, "binomial")

  pg <- p3("glm", input_table = "cars", response = "carb",
           predictors = "hp", family = "poisson")
  resg <- execute_phase3_task("glm", pg, tabs)
  expect_null(resg$error)
  expect_equal(stats::family(resg$objects$model)$family, "poisson")
})

test_that("one-way anova returns tidy, glance and tukey tables", {
  df <- data.frame(g = rep(c("a", "b", "c"), each = 10),
                   y = c(rnorm(10, 0), rnorm(10, 3), rnorm(10, 6)))
  p <- p3("one_way_anova", input_table = "d", response = "y", group = "g")
  res <- execute_phase3_task("one_way_anova", p, list(d = df))
  expect_null(res$error)
  expect_s3_class(res$objects$model, "aov")
  expect_true(is.data.frame(res$objects$tukey))
  expect_equal(nrow(res$objects$tukey), 3L)   # 3 pairwise comparisons
})

test_that("t-test runs one-sample and two-sample", {
  one <- execute_phase3_task("t_test",
    p3("t_test", input_table = "cars", response = "mpg"), tabs)
  expect_null(one$error)
  expect_s3_class(one$objects$test, "htest")

  two <- execute_phase3_task("t_test",
    p3("t_test", input_table = "cars", response = "mpg", group = "am"), tabs)
  expect_null(two$error)
  expect_match(two$data$method, "t-test")
})

# ── Capability / control chart / forecasting / survival / nls tasks ───────────

test_that("cdf_plots returns a quantile table and an ECDF plot", {
  p <- p3("cdf_plots", input_table = "cars", response = "mpg")
  res <- execute_phase3_task("cdf_plots", p, tabs)
  expect_null(res$error)
  expect_s3_class(res$plot, "girafe")
  expect_equal(nrow(res$data), 21L)                  # probs 0..1 by 0.05
  expect_equal(res$data$value[res$data$prob == 0], min(cars$mpg))
  expect_equal(res$data$value[res$data$prob == 1], max(cars$mpg))
  expect_no_error(parse(text = build_phase3_code("cdf_plots", p)))

  grp <- p3("cdf_plots", input_table = "cars", response = "mpg", group = "am")
  res2 <- execute_phase3_task("cdf_plots", grp, tabs)
  expect_null(res2$error)
  expect_equal(nrow(res2$data), 42L)                 # 21 quantiles × 2 groups
  expect_true("am" %in% names(res2$data))

  # grouped generated code must reproduce the grouped quantile table
  code <- build_phase3_code("cdf_plots", grp)
  expect_no_error(parse(text = code))
  env <- new.env(parent = globalenv())
  env$cars <- tabs$cars
  suppressWarnings(eval(parse(text = code), envir = env))
  gen <- get("p3_out", envir = env)
  expect_equal(nrow(gen), 42L)
  expect_true("am" %in% names(gen))
})

test_that("probability_plots returns a Q-Q plot with normality stats", {
  p <- p3("probability_plots", input_table = "cars", response = "mpg")
  res <- execute_phase3_task("probability_plots", p, tabs)
  expect_null(res$error)
  expect_s3_class(res$plot, "girafe")
  expect_equal(res$data$n, nrow(cars))
  expect_true(res$data$shapiro_w > 0 && res$data$shapiro_w <= 1)
  expect_true(res$data$shapiro_p >= 0 && res$data$shapiro_p <= 1)
  # moments round out the normality assessment
  expect_true(all(c("skewness", "excess_kurtosis") %in% names(res$data)))
  expect_true(is.finite(res$data$skewness))
  expect_no_error(parse(text = build_phase3_code("probability_plots", p)))
})

test_that("control_charts flags out-of-control individuals (rule 1)", {
  set.seed(7)
  df <- data.frame(meas = c(rnorm(30, mean = 10, sd = 0.5), 25))
  p <- p3("control_charts", input_table = "d", response = "meas",
          run_rules = FALSE)   # rule 1 only — deterministic for random data
  res <- execute_phase3_task("control_charts", p, list(d = df))
  expect_null(res$error)
  expect_s3_class(res$plot, "girafe")
  expect_true(all(c("center", "lcl", "ucl", "violation", "rule") %in%
                    names(res$data)))
  expect_true(res$data$violation[31])                 # the spike at 25
  expect_equal(res$data$rule[31], "1")
  expect_false(any(res$data$violation[1:30]))
  expect_equal(res$objects$summary$n_violations, 1L)
  expect_true(is.finite(res$objects$summary$sigma) && res$objects$summary$sigma > 0)
  expect_no_error(parse(text = build_phase3_code("control_charts", p)))
})

test_that("Western Electric run rules detect each pattern", {
  # rule 1: single point beyond 3 sigma
  r <- .p3_we_rules(c(0, 0, 4), center = 0, sigma = 1)
  expect_equal(r[3], "1")
  # rule 2: 2 of 3 consecutive beyond 2 sigma, same side
  r <- .p3_we_rules(c(0, 2.5, 2.5), center = 0, sigma = 1)
  expect_match(r[3], "2")
  # rule 3: 4 of 5 beyond 1 sigma, same side
  r <- .p3_we_rules(c(1.5, 1.5, 0, 1.5, 1.5), center = 0, sigma = 1)
  expect_match(r[5], "3")
  # rule 4: 8 consecutive points on the same side of centre
  r <- .p3_we_rules(rep(0.5, 8), center = 0, sigma = 1)
  expect_match(r[8], "4")
  expect_equal(r[7], "")
  # quiet data triggers nothing
  r <- .p3_we_rules(c(0.5, -0.5, 0.4, -0.4), center = 0, sigma = 1)
  expect_true(all(r == ""))
})

test_that("control_charts applies run rules by default", {
  # a sustained shift inside the 3-sigma limits — only rule 4 catches it
  x <- c(2, -2, 2, -2, 2, -2, 2, -2, rep(1.6, 8))
  df <- data.frame(meas = x)
  p <- p3("control_charts", input_table = "d", response = "meas")
  res <- execute_phase3_task("control_charts", p, list(d = df))
  expect_null(res$error)
  expect_match(res$data$rule[16], "4")
  expect_true(res$data$violation[16])
  # generated code reproduces the run-rule verdicts
  code <- build_phase3_code("control_charts", p)
  expect_no_error(parse(text = code))
  env <- new.env(parent = globalenv())
  env$d <- df
  suppressWarnings(eval(parse(text = code), envir = env))
  expect_equal(get("p3_out", envir = env)$violation, res$data$violation)
})

test_that("control_charts builds Xbar charts from subgroups", {
  set.seed(8)
  df <- data.frame(meas = rnorm(40, 50, 2), batch = rep(1:8, each = 5))
  p <- p3("control_charts", input_table = "d", response = "meas",
          group = "batch")
  res <- execute_phase3_task("control_charts", p, list(d = df))
  expect_null(res$error)
  expect_equal(nrow(res$data), 8L)                    # one row per subgroup
  expect_true(all(res$data$n == 5L))
  expect_match(res$objects$summary$method, "Xbar-R")

  # The generated code must reproduce the app's A2-based limits, not an
  # approximation — run it and compare against the in-app result.
  code <- build_phase3_code("control_charts", p)
  expect_no_error(parse(text = code))
  env <- new.env(parent = globalenv())
  env$d <- df
  suppressWarnings(eval(parse(text = code), envir = env))
  gen <- get("p3_out", envir = env)
  expect_equal(gen$lcl[1], res$data$lcl[1], tolerance = 1e-10)
  expect_equal(gen$ucl[1], res$data$ucl[1], tolerance = 1e-10)
})

test_that("arima_forecast produces horizon-length forecasts with intervals", {
  set.seed(9)
  df <- data.frame(y = cumsum(rnorm(48)) + 100)
  p <- p3("arima_forecast", input_table = "d", response = "y", horizon = 6L)
  res <- execute_phase3_task("arima_forecast", p, list(d = df))
  expect_null(res$error)
  expect_s3_class(res$plot, "girafe")
  expect_equal(nrow(res$data), 6L)
  expect_true(all(res$data$hi95 > res$data$lo95))
  expect_true(all(res$data$hi80 <= res$data$hi95))
  expect_s3_class(res$objects$model, "Arima")
  expect_length(res$objects$summary$order, 3L)
  # auto.arima engine is used when the forecast package is installed
  if (requireNamespace("forecast", quietly = TRUE)) {
    expect_equal(res$objects$summary$engine, "forecast::auto.arima")
  }
  expect_no_error(parse(text = build_phase3_code("arima_forecast", p)))
})

test_that("life_tables computes Kaplan-Meier estimates", {
  skip_if_not_installed("survival")
  set.seed(10)
  df <- data.frame(time = rexp(60, rate = 0.1),
                   status = rbinom(60, 1, 0.7),
                   arm = sample(c("a", "b"), 60, replace = TRUE))
  p <- p3("life_tables", input_table = "d", response = "time",
          group = "status")
  res <- execute_phase3_task("life_tables", p, list(d = df))
  expect_null(res$error)
  expect_s3_class(res$plot, "girafe")
  expect_s3_class(res$objects$model, "survfit")
  expect_true(all(res$data$estimate >= 0 & res$data$estimate <= 1))
  expect_false(is.unsorted(rev(res$data$estimate)))   # non-increasing survival

  # headline summary: records, events, median survival + CI
  expect_true(is.data.frame(res$objects$glance))
  expect_equal(res$objects$glance$records, 60)
  expect_true("median_survival" %in% names(res$objects$glance))

  strat <- p3("life_tables", input_table = "d", response = "time",
              group = "status", predictors = "arm")
  res2 <- execute_phase3_task("life_tables", strat, list(d = df))
  expect_null(res2$error)
  expect_setequal(unique(res2$data$strata), c("a", "b"))
  expect_equal(nrow(res2$objects$glance), 2L)         # one row per stratum
  expect_setequal(res2$objects$glance$strata, c("a", "b"))
  expect_no_error(parse(text = build_phase3_code("life_tables", strat)))
})

test_that("life_tables validates the event column", {
  skip_if_not_installed("survival")
  df <- data.frame(time = c(1, 2, 3), status = c(0, 1, 2))
  p <- p3("life_tables", input_table = "d", response = "time",
          group = "status")
  res <- execute_phase3_task("life_tables", p, list(d = df))
  expect_match(res$error, "0/1")
})

test_that("survival tasks honour an explicit event level", {
  skip_if_not_installed("survival")
  set.seed(13)
  df <- data.frame(
    time   = rexp(40, 0.1),
    status = sample(c("censored", "died", "withdrawn"), 40, replace = TRUE),
    stringsAsFactors = FALSE
  )
  # three levels with no explicit pick → must ask the user
  p <- p3("life_tables", input_table = "d", response = "time",
          group = "status")
  res <- execute_phase3_task("life_tables", p, list(d = df))
  expect_match(res$error, "Event level")

  # explicit level works and matches a manual 0/1 recode
  p$event_level <- "died"
  res2 <- execute_phase3_task("life_tables", p, list(d = df))
  expect_null(res2$error)
  expect_equal(sum(res2$data$n.event), sum(df$status == "died"))
  # the generated code carries the chosen level
  code <- build_phase3_code("life_tables", p)
  env <- new.env(parent = globalenv()); env$d <- df
  eval(parse(text = code), envir = env)
  expect_equal(sum(env$p3_out$n.event), sum(df$status == "died"))

  # unknown level errors clearly
  p$event_level <- "nope"
  res3 <- execute_phase3_task("life_tables", p, list(d = df))
  expect_match(res3$error, "not found")
})

test_that("proportional_hazards fits a Cox model", {
  skip_if_not_installed("survival")
  set.seed(11)
  n <- 100
  age <- rnorm(n, 60, 8)
  df <- data.frame(
    age    = age,
    time   = rexp(n, rate = exp(0.04 * (age - 60)) / 20),
    status = rbinom(n, 1, 0.8)
  )
  p <- p3("proportional_hazards", input_table = "d", response = "time",
          group = "status", predictors = "age", pred_table = "d")
  res <- execute_phase3_task("proportional_hazards", p, list(d = df))
  expect_null(res$error)
  expect_s3_class(res$objects$model, "coxph")
  expect_equal(res$data$term, "age")
  expect_true(all(c("estimate", "p.value", "conf.low") %in% names(res$data)))
  # hazard ratios are the headline Cox numbers — exp(coef), next to estimate
  expect_equal(res$data$hazard_ratio, exp(res$data$estimate))
  expect_equal(match("hazard_ratio", names(res$data)),
               match("estimate", names(res$data)) + 1L)
  expect_true(is.data.frame(res$objects$glance))
  expect_true(".risk" %in% names(res$objects$predictions))
  code <- build_phase3_code("proportional_hazards", p)
  expect_no_error(parse(text = code))
  expect_match(code, "hazard_ratio")
})

test_that("Cox results format with hazard ratio and z statistic", {
  skip_if_not_installed("survival")
  tidy_df <- data.frame(term = "age", estimate = 0.05, hazard_ratio = exp(0.05),
                        std.error = 0.01, statistic = 5, p.value = 0.001,
                        conf.low = 0.03, conf.high = 0.07)
  gt_tbl <- format_phase3_result("proportional_hazards", tidy_df, list())
  expect_s3_class(gt_tbl, "gt_tbl")
  expect_true("hazard_ratio" %in% gt_tbl$`_boxhead`$var)
})

test_that("nonlinear_regression fits preset curves", {
  set.seed(12)
  x <- seq(-5, 5, length.out = 80)
  dlog <- data.frame(x = x, y = 10 / (1 + exp(-x)) + rnorm(80, 0, 0.2))
  p <- p3("nonlinear_regression", input_table = "d", response = "y",
          predictors = "x", curve = "logistic")
  res <- execute_phase3_task("nonlinear_regression", p, list(d = dlog))
  expect_null(res$error)
  expect_s3_class(res$plot, "girafe")
  expect_s3_class(res$objects$model, "nls")
  asym <- res$data$estimate[res$data$term == "Asym"]
  expect_equal(asym, 10, tolerance = 0.5)
  expect_no_error(parse(text = build_phase3_code("nonlinear_regression", p)))

  xe <- seq(0, 5, length.out = 60)
  dexp <- data.frame(x = xe, y = 2 * exp(0.3 * xe) * exp(rnorm(60, 0, 0.02)))
  pe <- p3("nonlinear_regression", input_table = "d", response = "y",
           predictors = "x", curve = "exponential")
  rese <- execute_phase3_task("nonlinear_regression", pe, list(d = dexp))
  expect_null(rese$error)
  expect_equal(rese$data$estimate[rese$data$term == "b"], 0.3, tolerance = 0.05)

  dp <- data.frame(x = xe[-1], y = 2 * xe[-1]^1.5 * exp(rnorm(59, 0, 0.02)))
  pp <- p3("nonlinear_regression", input_table = "d", response = "y",
           predictors = "x", curve = "power")
  resp <- execute_phase3_task("nonlinear_regression", pp, list(d = dp))
  expect_null(resp$error)
  expect_equal(resp$data$estimate[resp$data$term == "b"], 1.5, tolerance = 0.05)
})

test_that("plot-centric stat tasks expose plot/image output defs", {
  for (type in PHASE3_PLOTTING_STATS) {
    keys <- vapply(phase3_return_defs(type), `[[`, character(1), "key")
    expect_true(all(c("table", "plot", "image") %in% keys), info = type)
  }
})

test_that("analysis tasks validate inputs", {
  expect_match(
    execute_phase3_task("linear_regression",
      p3("linear_regression", input_table = "cars"), tabs)$error,
    "response")
  expect_match(
    execute_phase3_task("correlations",
      p3("correlations", input_table = "sales", predictors = "region"),
      tabs)$error,
    "two numeric")
  expect_match(
    execute_phase3_task("bar_chart",
      p3("bar_chart", input_table = "missing_tbl", x = "x"), tabs)$error,
    "not found")
})

# ── Output name plumbing ───────────────────────────────────────────────────────

test_that("phase3 default output names derive from the base name", {
  nm <- phase3_default_output_names("linear_regression", "fit1")
  expect_equal(nm$table, "fit1")
  expect_equal(nm$glance, "fit1_glance")
  expect_equal(nm$model, "fit1_model")
})

test_that("output_key_default_enabled keeps primary on and heavy outputs off", {
  expect_true(output_key_default_enabled("table"))
  expect_true(output_key_default_enabled("glance"))
  expect_false(output_key_default_enabled("augment"))
  expect_false(output_key_default_enabled("model"))
})

test_that("build_phase3_code omits disabled outputs", {
  p <- p3("linear_regression", input_table = "cars", response = "mpg",
          predictors = "wt")
  p$output_enabled$glance  <- FALSE
  p$output_enabled$augment <- FALSE
  code <- build_phase3_code("linear_regression", p)
  env <- new.env(parent = globalenv()); env$cars <- tabs$cars
  eval(parse(text = code), envir = env)
  expect_false(exists("p3_out_glance", env, inherits = FALSE))
  expect_false(exists("p3_out_augment", env, inherits = FALSE))
  expect_match(code, "broom::tidy")
})

test_that("store_phase3_outputs writes tables and objects to the store", {
  store <- new_test_store(tabs)
  p <- p3("linear_regression", input_table = "cars", response = "mpg",
          predictors = "wt")
  p$output_enabled$model <- TRUE
  res <- execute_phase3_task("linear_regression", p, tabs)
  shiny::isolate(store_phase3_outputs(store, p, res))
  tbls <- shiny::isolate(store$tables)
  objs <- shiny::isolate(store$objects)
  expect_true("p3_out" %in% names(tbls))            # tidy table
  expect_true("p3_out_glance" %in% names(tbls))     # broom table output
  expect_true("p3_out_model" %in% names(objs))      # model object
})
