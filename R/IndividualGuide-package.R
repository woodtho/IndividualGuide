# Package-level documentation and namespace imports.
#
# The UI/server code uses unqualified shiny functions throughout, so the whole
# shiny namespace is imported. Everything else is called with `::`, except the
# handful of stats/utils/graphics functions listed below.

#' @keywords internal
#' @import shiny
#' @importFrom stats median quantile sd var setNames chisq.test qqnorm
#' @importFrom utils head tail capture.output stack
#' @importFrom lubridate ymd
"_PACKAGE"

# Columns evaluated by ggplot2/dplyr data masks, rather than package globals.
utils::globalVariables(c(".data", ".fitted", "conf.high", "conf.low", "count",
  "density", "estimate", "forecast", "hi80", "hi95", "index", "lo80", "lo95",
  "strata", "theoretical", "time", "value", "values", "violation", "x_value",
  "x_variable", "y_value", "y_variable"))
