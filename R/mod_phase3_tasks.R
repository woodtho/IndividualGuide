# mod_phase3_tasks.R -- Phase 3 graph, model, multivariate, capability,
# control-chart, time-series, and survival task modules.

PHASE3_GRAPH_TYPES <- c(
  "bar_chart", "bar_line_chart", "box_plot", "bubble_plot", "contour_plot",
  "histogram_graph", "line_plot", "pie_chart", "scatter_plot", "scatter_matrix"
)

PHASE3_STAT_TYPES <- c(
  "one_way_anova", "t_test", "linear_models", "cdf_plots",
  "probability_plots", "control_charts", "linear_regression",
  "logistic_regression", "glm", "nonlinear_regression", "correlations",
  "pca", "cluster_analysis", "life_tables", "proportional_hazards",
  "arima_forecast"
)

PHASE3_TYPES <- c(PHASE3_GRAPH_TYPES, PHASE3_STAT_TYPES)

phase3_return_defs <- function(type_id) {
  defs <- list(list(key = "table", kind = "table", label = "Summary / data table"))
  if (type_id %in% PHASE3_GRAPH_TYPES) {
    return(c(defs, list(
      list(key = "plot",  kind = "plot",  label = "Interactive ggiraph plot"),
      list(key = "image", kind = "image", label = "Static ggplot image")
    )))
  }
  # Regression/GLM: broom tidy + glance + augment + predictions
  if (type_id %in% c("linear_regression", "linear_models", "glm", "logistic_regression")) {
    return(list(
      list(key = "table",       kind = "table",  label = "Coefficients (tidy)"),
      list(key = "glance",      kind = "table",  label = "Model fit (glance)"),
      list(key = "augment",     kind = "table",  label = "Fitted values (augment)"),
      list(key = "predictions", kind = "table",  label = "Predictions on new data"),
      list(key = "model",       kind = "model",  label = "Model object")
    ))
  }
  # ANOVA: broom tidy + glance + TukeyHSD + predictions
  if (identical(type_id, "one_way_anova")) {
    return(list(
      list(key = "table",       kind = "table",  label = "ANOVA table (tidy)"),
      list(key = "glance",      kind = "table",  label = "ANOVA fit (glance)"),
      list(key = "tukey",       kind = "table",  label = "Tukey HSD pairs"),
      list(key = "predictions", kind = "table",  label = "Predictions on new data"),
      list(key = "model",       kind = "model",  label = "Model object")
    ))
  }
  # t-test: broom tidy (no predictions — one-sample / two-sample; no newdata concept)
  if (identical(type_id, "t_test")) {
    return(list(
      list(key = "table", kind = "table",  label = "Test statistics (tidy)"),
      list(key = "test",  kind = "object", label = "t-test object")
    ))
  }
  # PCA: scree + loadings + scores + predictions on new data
  if (identical(type_id, "pca")) {
    return(list(
      list(key = "table",       kind = "table",  label = "Scree / variance (tidy)"),
      list(key = "loadings",    kind = "table",  label = "Variable loadings"),
      list(key = "scores",      kind = "table",  label = "Component scores (augment)"),
      list(key = "predictions", kind = "table",  label = "Component scores on new data"),
      list(key = "model",       kind = "model",  label = "prcomp object")
    ))
  }
  # Cluster: centres + assignments + fit
  if (identical(type_id, "cluster_analysis")) {
    return(list(
      list(key = "table",    kind = "table",  label = "Cluster summaries"),
      list(key = "clusters", kind = "table",  label = "Row assignments (augment)"),
      list(key = "glance",   kind = "table",  label = "Cluster fit (glance)"),
      list(key = "model",    kind = "model",  label = "Clustering model")
    ))
  }
  if (identical(type_id, "correlations")) {
    return(c(defs, list(list(key = "matrix", kind = "object", label = "Correlation matrix"))))
  }
  # Proportional hazards — Cox regression (survival::coxph) with broom outputs
  if (identical(type_id, "proportional_hazards")) {
    return(list(
      list(key = "table",       kind = "table",  label = "Coefficients (tidy)"),
      list(key = "glance",      kind = "table",  label = "Model fit (glance)"),
      list(key = "augment",     kind = "table",  label = "Fitted values (augment)"),
      list(key = "predictions", kind = "table",  label = "Risk predictions on new data"),
      list(key = "model",       kind = "model",  label = "coxph model object")
    ))
  }
  if (identical(type_id, "nonlinear_regression")) {
    return(list(
      list(key = "table",   kind = "table", label = "Coefficients (tidy)"),
      list(key = "glance",  kind = "table", label = "Model fit (glance)"),
      list(key = "augment", kind = "table", label = "Fitted values (augment)"),
      list(key = "plot",    kind = "plot",  label = "Fitted curve plot"),
      list(key = "image",   kind = "image", label = "Static ggplot image"),
      list(key = "model",   kind = "model", label = "nls model object")
    ))
  }
  if (identical(type_id, "arima_forecast")) {
    return(list(
      list(key = "table",   kind = "table",  label = "Point forecasts with intervals"),
      list(key = "plot",    kind = "plot",   label = "Forecast plot"),
      list(key = "image",   kind = "image",  label = "Static ggplot image"),
      list(key = "model",   kind = "model",  label = "ARIMA model object"),
      list(key = "summary", kind = "object", label = "Selected order / AIC")
    ))
  }
  if (identical(type_id, "life_tables")) {
    return(list(
      list(key = "table",  kind = "table", label = "Kaplan\u2013Meier estimates"),
      list(key = "glance", kind = "table", label = "Median survival summary"),
      list(key = "plot",   kind = "plot",  label = "Survival curve plot"),
      list(key = "image",  kind = "image", label = "Static ggplot image"),
      list(key = "model",  kind = "model", label = "survfit object")
    ))
  }
  if (identical(type_id, "control_charts")) {
    return(list(
      list(key = "table",   kind = "table",  label = "Points with control limits"),
      list(key = "plot",    kind = "plot",   label = "Control chart plot"),
      list(key = "image",   kind = "image",  label = "Static ggplot image"),
      list(key = "summary", kind = "object", label = "Limits / violations summary")
    ))
  }
  if (type_id %in% c("cdf_plots", "probability_plots")) {
    return(c(defs, list(
      list(key = "plot",  kind = "plot",  label = "Interactive ggiraph plot"),
      list(key = "image", kind = "image", label = "Static ggplot image")
    )))
  }
  defs
}

phase3_default_output_names <- function(type_id, output_name) {
  defs <- phase3_return_defs(type_id)
  names <- lapply(defs, function(d) {
    nm <- if (identical(d$key, "table")) output_name else paste0(output_name, "_", d$key)
    setNames(list(nm), d$key)
  })
  do.call(c, names)
}

# Which outputs are saved by default (FALSE = off, TRUE = on)
output_key_default_enabled <- function(key, kind = "table") {
  if (identical(key, "table"))  return(TRUE)   # primary output — always on
  switch(key,
    glance      = TRUE,    # model fit summary — small and useful
    tukey       = TRUE,    # pairwise comparisons — useful in ANOVA
    loadings    = TRUE,    # PCA loadings — useful
    clusters    = TRUE,    # cluster assignments — useful
    plot        = TRUE,    # interactive plot — always useful
    augment     = FALSE,   # row-level fitted values — large, seldom needed
    scores      = FALSE,   # PCA scores — large, seldom needed
    model       = FALSE,   # raw R object — advanced use
    image       = FALSE,   # static image — mostly for export
    predictions = FALSE,   # new-data predictions — only when pred_table set
    summary     = FALSE,   # summary object — internal
    matrix      = FALSE,   # correlation matrix — advanced
    test        = FALSE,   # test object — advanced
    # fallback by kind
    switch(kind,
      table  = TRUE,
      plot   = TRUE,
      model  = FALSE,
      image  = FALSE,
      object = FALSE,
      TRUE
    )
  )
}

default_phase3_params <- function(type_id, output_name = paste0(type_id, "_out")) {
  list(
    type_id = type_id,
    input_table = NULL,
    x = NULL,
    y = NULL,
    y2 = NULL,
    y2_label = "",
    density_overlay = FALSE,
    donut = FALSE,
    matrix_view = "pairs",
    group = NULL,
    facet = NULL,
    size = NULL,
    cols = character(0),
    response = NULL,
    predictors = character(0),
    family = "gaussian",
    k = 3L,
    cluster_method = "kmeans",
    cluster_linkage = "complete",
    cluster_seed = 1L,
    paired = FALSE,
    paired_column = "",
    horizon = 12L,
    curve = "logistic",
    run_rules = TRUE,
    event_level = "",
    title = "",
    subtitle = "",
    x_label = "",
    y_label = "",
    caption = "",
    plot_theme = "clean",
    palette = "ig",
    legend_position = "right",
    show_grid = TRUE,
    flip = FALSE,
    bins = 30L,
    point_alpha = 0.78,
    bar_alpha = 0.86,
    line_width = 1.05,
    plot_width    = 8,
    plot_height   = 4,
    pred_table    = NULL,
    pred_conf_int = FALSE,
    output_name = output_name,
    output_names = phase3_default_output_names(type_id, output_name),
    output_enabled = {
      defs <- phase3_return_defs(type_id)
      setNames(
        lapply(defs, function(d) output_key_default_enabled(d$key, d$kind)),
        vapply(defs, `[[`, character(1), "key")
      )
    }
  )
}

phase3_graph_fields <- function(type_id) {
  switch(type_id,
    bar_chart = list(x = TRUE, y = TRUE, group = TRUE, size = FALSE,
      facet = TRUE, cols = FALSE, flip = TRUE, bins = FALSE, point = FALSE,
      line = FALSE, bar = TRUE),
    bar_line_chart = list(x = TRUE, y = TRUE, group = TRUE, size = FALSE,
      facet = TRUE, cols = FALSE, flip = FALSE, bins = FALSE, point = FALSE,
      line = TRUE, bar = TRUE),
    box_plot = list(x = TRUE, y = TRUE, group = TRUE, size = FALSE,
      facet = TRUE, cols = FALSE, flip = TRUE, bins = FALSE, point = FALSE,
      line = FALSE, bar = FALSE),
    bubble_plot = list(x = TRUE, y = TRUE, group = TRUE, size = TRUE,
      facet = TRUE, cols = FALSE, flip = FALSE, bins = FALSE, point = TRUE,
      line = FALSE, bar = FALSE),
    contour_plot = list(x = TRUE, y = TRUE, group = FALSE, size = FALSE,
      facet = TRUE, cols = FALSE, flip = FALSE, bins = FALSE, point = FALSE,
      line = FALSE, bar = FALSE),
    histogram_graph = list(x = TRUE, y = FALSE, group = TRUE, size = FALSE,
      facet = TRUE, cols = FALSE, flip = FALSE, bins = TRUE, point = FALSE,
      line = FALSE, bar = TRUE),
    line_plot = list(x = TRUE, y = TRUE, group = TRUE, size = FALSE,
      facet = TRUE, cols = FALSE, flip = FALSE, bins = FALSE, point = FALSE,
      line = TRUE, bar = FALSE),
    pie_chart = list(x = TRUE, y = FALSE, group = FALSE, size = FALSE,
      facet = FALSE, cols = FALSE, flip = FALSE, bins = FALSE, point = FALSE,
      line = FALSE, bar = TRUE),
    scatter_plot = list(x = TRUE, y = TRUE, group = TRUE, size = TRUE,
      facet = TRUE, cols = FALSE, flip = FALSE, bins = FALSE, point = TRUE,
      line = FALSE, bar = FALSE),
    scatter_matrix = list(x = FALSE, y = FALSE, group = FALSE, size = FALSE,
      facet = FALSE, cols = TRUE, flip = FALSE, bins = TRUE, point = TRUE,
      line = FALSE, bar = TRUE),
    list(x = TRUE, y = TRUE, group = TRUE, size = FALSE, facet = TRUE,
      point = type_id %in% c("probability_plots", "nonlinear_regression"),
      line = type_id %in% PHASE3_PLOTTING_STATS, bins = FALSE, bar = FALSE, flip = FALSE,
      cols = FALSE)
  )
}

phase3_graph_mapping_ui <- function(ns, type_id) {
  f <- phase3_graph_fields(type_id)
  controls <- list()
  if (isTRUE(f$x)) {
    x_label <- switch(type_id,
      histogram_graph = "Numeric column",
      pie_chart = "Slice category",
      bar_chart = "Category / X",
      "X / category / date")
    controls <- c(controls, list(selectInput(ns("x"), x_label,
      choices = character(0))))
  }
  if (isTRUE(f$y)) {
    y_label <- switch(type_id,
      box_plot = "Numeric value",
      bar_chart = "Value (optional)",
      "Y / value")
    controls <- c(controls, list(selectInput(ns("y"), y_label,
      choices = character(0))))
  }
  if (type_id %in% c("bar_line_chart", "line_plot")) {
    controls <- c(controls, list(selectInput(ns("y2"), "Secondary Y (optional)", choices = character(0)),
      textInput(ns("y2_label"), "Secondary Y label", value = "")))
  }
  if (type_id == "histogram_graph") controls <- c(controls,
    list(checkboxInput(ns("density_overlay"), "Overlay density (density scale)", value = FALSE)))
  if (type_id == "pie_chart") controls <- c(controls,
    list(checkboxInput(ns("donut"), "Donut chart", value = FALSE)))
  if (type_id == "scatter_matrix") controls <- c(controls,
    list(selectInput(ns("matrix_view"), "Matrix view", choices = c("Pairwise scatterplots" = "pairs", "Distributions" = "distributions"))))
  if (isTRUE(f$group)) {
    group_label <- switch(type_id,
      histogram_graph = "Fill group",
      box_plot = "Fill group",
      "Group / colour")
    controls <- c(controls, list(selectInput(ns("group"), group_label,
      choices = character(0))))
  }
  if (isTRUE(f$size)) {
    controls <- c(controls, list(selectInput(ns("size"), "Size / weight",
      choices = character(0))))
  }
  if (isTRUE(f$facet)) {
    controls <- c(controls, list(selectInput(ns("facet"), "Facet",
      choices = character(0))))
  }
  if (isTRUE(f$cols)) {
    controls <- c(controls, list(selectInput(ns("cols"), "Numeric columns",
      choices = character(0), multiple = TRUE)))
  }
  do.call(bslib::layout_columns, c(list(col_widths = 4), controls))
}

phase3_graph_style_ui <- function(ns, type_id) {
  f <- phase3_graph_fields(type_id)
  matrix_only <- function(control, view) {
    if (type_id != "scatter_matrix") return(control)
    conditionalPanel(sprintf("input['%s'] === '%s'", ns("matrix_view"), view), control)
  }
  tagList(
    bslib::accordion(
      open = FALSE,
      bslib::accordion_panel(
        "Plot styling",
        bslib::layout_columns(
          col_widths = c(4, 4, 4),
          selectInput(ns("plot_theme"), "Theme",
            choices = c(
              "Clean" = "clean",
              "Publication" = "publication",
              "Minimal" = "minimal",
              "Classic" = "classic",
              "Light" = "light",
              "Dark" = "dark"
            )),
          selectInput(ns("palette"), "Palette",
            choices = c(
              "Individual Guide" = "ig",
              "Okabe-Ito" = "okabe_ito",
              "Tableau" = "tableau",
              "Viridis" = "viridis",
              "Grey" = "grey"
            )),
          selectInput(ns("legend_position"), "Legend",
            choices = c("Right" = "right", "Bottom" = "bottom",
              "Top" = "top", "Left" = "left", "Hidden" = "none"))
        ),
        bslib::layout_columns(
          col_widths = 3,
          if (isTRUE(f$bins)) matrix_only(numericInput(ns("bins"), "Bins",
            value = 30, min = 2, step = 1), "distributions"),
          if (isTRUE(f$point)) matrix_only(sliderInput(ns("point_alpha"),
            "Point opacity", min = 0.1, max = 1, value = 0.78, step = 0.05), "pairs"),
          if (isTRUE(f$bar)) matrix_only(sliderInput(ns("bar_alpha"),
            "Bar opacity", min = 0.1, max = 1, value = 0.86, step = 0.05), "distributions"),
          if (isTRUE(f$line)) sliderInput(ns("line_width"),
            "Line width", min = 0.2, max = 3, value = 1.05, step = 0.05),
          checkboxInput(ns("show_grid"), "Grid lines", value = TRUE),
          if (isTRUE(f$flip)) checkboxInput(ns("flip"),
            "Horizontal layout", value = FALSE)
        ),
        bslib::layout_columns(
          col_widths = c(6, 6),
          textInput(ns("title"), "Title", width = "100%"),
          textInput(ns("subtitle"), "Subtitle", width = "100%"),
          textInput(ns("x_label"), "X label", width = "100%"),
          textInput(ns("y_label"), "Y label", width = "100%"),
          textInput(ns("caption"), "Caption", width = "100%")
        ),
        bslib::layout_columns(
          col_widths = c(6, 6),
          numericInput(ns("plot_width"),  "Width (inches)",  value = 8,
            min = 3, max = 24, step = 0.5),
          numericInput(ns("plot_height"), "Height (inches)", value = 4,
            min = 2, max = 16, step = 0.5)
        )
      )
    )
  )
}

phase3_supports_prediction <- function(type_id) {
  type_id %in% c("linear_regression", "linear_models", "glm",
                 "logistic_regression", "proportional_hazards",
                 "one_way_anova", "pca")
}

# Field configuration for the analysis (non-graph) task types: which of the
# generic selectors are shown and what they are labelled. Hiding irrelevant
# fields (e.g. "GLM family" on a t-test) keeps the panels self-explanatory.
phase3_stat_fields <- function(type_id) {
  cfg <- list(
    response   = "Response / value / time",
    predictors = "Predictors / variables",
    group      = "Group / class / event",
    family = FALSE, k = FALSE, horizon = FALSE, curve = FALSE,
    rules = FALSE, event_level = FALSE
  )
  override <- switch(type_id,
    t_test = list(response = "Response (numeric)",
                  group = "Group (optional \u2014 two levels)", predictors = FALSE),
    one_way_anova = list(response = "Response (numeric)",
                         group = "Group variable", predictors = FALSE),
    linear_regression = ,
    linear_models = list(response = "Response", predictors = "Predictors",
                         group = FALSE),
    logistic_regression = list(response = "Response (0/1)",
                               predictors = "Predictors", group = FALSE),
    glm = list(response = "Response", predictors = "Predictors",
               group = FALSE, family = TRUE),
    correlations = ,
    pca = list(response = FALSE, group = FALSE,
               predictors = "Numeric variables (blank = all numeric)"),
    cluster_analysis = list(response = FALSE, group = FALSE,
                            predictors = "Numeric variables (blank = all numeric)",
                            k = TRUE),
    cdf_plots = list(response = "Numeric variable",
                     group = "Group / colour (optional)", predictors = FALSE),
    probability_plots = list(response = "Numeric variable",
                             group = FALSE, predictors = FALSE),
    control_charts = list(response = "Measurement",
                          group = "Subgroup (optional \u2014 Xbar chart when set)",
                          predictors = FALSE, rules = TRUE),
    arima_forecast = list(response = "Series value (rows in time order)",
                          group = FALSE, predictors = FALSE, horizon = TRUE),
    life_tables = list(response = "Time to event",
                       group = "Event indicator (1 = event, 0 = censored)",
                       predictors = "Strata (optional \u2014 first selected used)",
                       event_level = TRUE),
    proportional_hazards = list(response = "Time to event",
                                group = "Event indicator (1 = event, 0 = censored)",
                                predictors = "Covariates",
                                event_level = TRUE),
    nonlinear_regression = list(response = "Response (y)",
                                predictors = "Predictor (x \u2014 first selected used)",
                                group = FALSE, curve = TRUE),
    list()
  )
  for (nm in names(override)) cfg[[nm]] <- override[[nm]]
  cfg
}

phase3_task_ui <- function(id, type_id) {
  ns <- NS(id)
  info <- task_type_info(type_id)
  is_graph <- type_id %in% PHASE3_GRAPH_TYPES
  results_navset <- if (is_graph) {
    bslib::navset_tab(
      id = ns("result_tabs"),
      bslib::nav_panel(tagList(icon("image"), " Plot"), value = "Plot",
        div(class = "ig-result-panel",
          ggiraph::girafeOutput(ns("plot"), width = "100%", height = "380px"))),
      bslib::nav_panel(tagList(icon("table"), " Data"), value = "Data",
        div(class = "ig-result-panel", DT::DTOutput(ns("result_dt")))),
      bslib::nav_panel(tagList(icon("code"), " Code"), value = "Code",
        div(class = "ig-result-panel ig-code-panel",
          verbatimTextOutput(ns("task_code_view"))))
    )
  } else {
    tabs <- Filter(Negate(is.null), list(
      # Stat tasks that draw something get a Plot tab too
      if (type_id %in% PHASE3_PLOTTING_STATS)
        bslib::nav_panel(tagList(icon("image"), " Plot"), value = "Plot",
          div(class = "ig-result-panel",
            ggiraph::girafeOutput(ns("plot"), width = "100%",
              height = "380px"))),
      bslib::nav_panel(tagList(icon("chart-bar"), " Results"), value = "Results",
        div(class = "ig-result-panel ig-formatted-results",
          ig_gt_output(ns("result_gt")))),
      bslib::nav_panel(tagList(icon("table"), " Data"), value = "Data",
        div(class = "ig-result-panel", DT::DTOutput(ns("result_dt")))),
      bslib::nav_panel(tagList(icon("code"), " Code"), value = "Code",
        div(class = "ig-result-panel ig-code-panel",
          verbatimTextOutput(ns("task_code_view"))))
    ))
    do.call(bslib::navset_tab, c(list(id = ns("result_tabs")), tabs))
  }
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    bslib::card_header(
      class = "d-flex align-items-center gap-2",
      icon(info$icon %||% "chart-line"), " ", info$label %||% type_id,
      div(class = "ms-auto d-flex align-items-center gap-2",
        span("Primary table:", class = "text-muted small"),
        textInput(ns("output_name"), sr_label("Primary output table name"),
          width = "180px", placeholder = paste0(type_id, "_out")))
    ),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(
          tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane",
      p(class = "text-muted small mb-3", info$desc %||% ""),
      div(class = "ig-function-palette mb-3",
        tags$strong("Returns: "),
        tagList(lapply(phase3_return_defs(type_id), function(d) {
          span(class = "ig-type-badge me-1", paste0(d$kind, ": ", d$label))
        }))
      ),
      div(class = "mb-3",
        tags$strong("Output names"),
        uiOutput(ns("output_names_ui"))
      ),
      selectInput(ns("input_table"), "Input table",
        choices = character(0), width = "100%"),
      if (is_graph) tagList(
        phase3_graph_mapping_ui(ns, type_id),
        phase3_graph_style_ui(ns, type_id)
      ),
      if (!is_graph) tagList(
        local({
          f <- phase3_stat_fields(type_id)
          mapping <- Filter(Negate(is.null), list(
            if (!isFALSE(f$response))
              selectInput(ns("response"), f$response, choices = character(0)),
            if (!isFALSE(f$predictors))
              selectInput(ns("predictors"), f$predictors,
                choices = character(0), multiple = TRUE),
            if (!isFALSE(f$group))
              selectInput(ns("group"), f$group, choices = character(0))
          ))
          extras <- Filter(Negate(is.null), list(
            if (identical(type_id, "t_test")) tagList(
              checkboxInput(ns("paired"), "Paired measurements", value = FALSE),
              conditionalPanel(sprintf("input['%s']", ns("paired")),
                selectInput(ns("paired_column"), "Second measurement (same row)", choices = character(0)))),
            if (identical(type_id, "cluster_analysis")) tagList(
              selectInput(ns("cluster_method"), "Method", choices = c("k-means" = "kmeans", "Hierarchical" = "hierarchical")),
              conditionalPanel(sprintf("input['%s'] === 'hierarchical'", ns("cluster_method")),
                selectInput(ns("cluster_linkage"), "Linkage", choices = c("complete", "single", "average", "ward.D2"))),
              conditionalPanel(sprintf("input['%s'] === 'kmeans'", ns("cluster_method")),
                numericInput(ns("cluster_seed"), "Random seed", value = 1, min = 0, step = 1))),
            if (isTRUE(f$family))
              selectInput(ns("family"), "GLM family",
                choices = c("gaussian", "binomial", "poisson", "Gamma")),
            if (isTRUE(f$k))
              numericInput(ns("k"), "Clusters", value = 3, min = 1, step = 1),
            if (isTRUE(f$horizon))
              numericInput(ns("horizon"), "Forecast horizon (steps ahead)",
                value = 12, min = 1, step = 1),
            if (isTRUE(f$curve))
              selectInput(ns("curve"), "Curve preset", choices = NLS_CURVES),
            if (isTRUE(f$rules))
              checkboxInput(ns("run_rules"),
                "Western Electric run rules (2-of-3, 4-of-5, 8-in-a-row)",
                value = TRUE),
            if (isTRUE(f$event_level))
              selectInput(ns("event_level"),
                "Event level (for factor/character event columns)",
                choices = c("(auto: 1 / TRUE / second level)" = ""))
          ))
          tagList(
            do.call(bslib::layout_columns,
              c(list(col_widths = rep(12 %/% max(1L, length(mapping)),
                                      length(mapping))), mapping)),
            if (length(extras))
              do.call(bslib::layout_columns,
                c(list(col_widths = rep(12 %/% max(1L, length(extras)),
                                        length(extras))), extras))
          )
        }),
        if (phase3_supports_prediction(type_id)) {
          bslib::accordion(
            open = FALSE,
            bslib::accordion_panel(
              "Predictions on new data",
              p(class = "text-muted small mb-2",
                "Optionally select a table of new observations. The fitted model will ",
                "generate predictions and store them as a separate output table."),
              bslib::layout_columns(
                col_widths = c(8, 4),
                selectInput(ns("pred_table"), "New data table",
                  choices = character(0), width = "100%"),
                if (type_id %in% c("linear_regression", "linear_models",
                                    "glm", "logistic_regression", "one_way_anova")) {
                  checkboxInput(ns("pred_conf_int"),
                    "Include 95% confidence intervals", value = FALSE)
                } else {
                  div()   # PCA — CI not applicable
                }
              )
            )
          )
        }
      ),
      if (!is_graph && type_id %in% PHASE3_PLOTTING_STATS) phase3_graph_style_ui(ns, type_id),
      div(style = "display:none;",
        checkboxInput(ns("is_graph"), NULL, value = is_graph))
          )),
        bslib::nav_panel(
          tagList(icon("chart-bar"), " Results"), value = "results",
          div(class = "ig-results-pane",
            conditionalPanel(
              condition = sprintf("!output['%s']", ns("result_visible")),
              .dt_results_placeholder()),
            conditionalPanel(
              condition = sprintf("output['%s']", ns("result_visible")),
              results_navset)))
      )
    ),
    bslib::card_footer(
      class = "d-flex align-items-center gap-2",
      actionButton(ns("btn_preview"), "Preview", icon = icon("eye"),
        class = "btn btn-sm btn-outline-secondary"),
      actionButton(ns("btn_run"), "Run & Save", icon = icon("play"),
        class = "btn btn-sm btn-primary"),
      if (is_graph || type_id %in% PHASE3_PLOTTING_STATS) tagList(
        downloadButton(ns("download_plot_png"), "Download PNG",
          class = "btn btn-sm btn-outline-secondary"),
        downloadButton(ns("download_plot_html"), "Download HTML",
          class = "btn btn-sm btn-outline-secondary")),
      span(class = "ms-auto text-muted small",
        role = "status", `aria-live` = "polite", `aria-atomic` = "true",
        textOutput(ns("run_status"), inline = TRUE))
    )
  )
}

phase3_task_server <- function(id, store, task_id = NULL, type_id) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_phase3_params(type_id)
      else default_phase3_params(type_id, paste0(task_id %||% type_id, "_out"))
    })
    result_df      <- reactiveVal(NULL)
    result_plot    <- reactiveVal(NULL)
    result_image   <- reactiveVal(NULL)
    result_objects <- reactiveVal(list())
    run_status_msg <- reactiveVal("")

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      updateTextInput(session, "title", value = init_p$title %||% "")
      updateTextInput(session, "subtitle", value = init_p$subtitle %||% "")
      updateTextInput(session, "x_label", value = init_p$x_label %||% "")
      updateTextInput(session, "y_label", value = init_p$y_label %||% "")
      updateTextInput(session, "caption", value = init_p$caption %||% "")
      updateTextInput(session, "y2_label", value = init_p$y2_label %||% "")
      updateCheckboxInput(session, "density_overlay", value = isTRUE(init_p$density_overlay))
      updateCheckboxInput(session, "donut", value = isTRUE(init_p$donut))
      updateSelectInput(session, "matrix_view", selected = init_p$matrix_view %||% "distributions")
      updateSelectInput(session, "plot_theme", selected = init_p$plot_theme %||% "clean")
      updateSelectInput(session, "palette", selected = init_p$palette %||% "ig")
      updateSelectInput(session, "legend_position", selected = init_p$legend_position %||% "right")
      updateCheckboxInput(session, "show_grid", value = isTRUE(init_p$show_grid %||% TRUE))
      updateCheckboxInput(session, "flip", value = isTRUE(init_p$flip %||% FALSE))
      updateNumericInput(session, "bins", value = init_p$bins %||% 30L)
      updateSliderInput(session, "point_alpha", value = init_p$point_alpha %||% 0.78)
      updateSliderInput(session, "bar_alpha", value = init_p$bar_alpha %||% 0.86)
      updateSliderInput(session, "line_width",  value = init_p$line_width  %||% 1.05)
      updateNumericInput(session, "plot_width",  value = init_p$plot_width  %||% 8)
      updateNumericInput(session, "plot_height", value = init_p$plot_height %||% 4)
      updateSelectInput(session, "family", selected = init_p$family %||% "gaussian")
      updateNumericInput(session, "k", value = init_p$k %||% 3L)
      updateSelectInput(session, "cluster_method", selected = init_p$cluster_method %||% "kmeans")
      updateSelectInput(session, "cluster_linkage", selected = init_p$cluster_linkage %||% "complete")
      updateNumericInput(session, "cluster_seed", value = init_p$cluster_seed %||% 1L)
      updateCheckboxInput(session, "paired", value = isTRUE(init_p$paired))
      updateNumericInput(session, "horizon", value = init_p$horizon %||% 12L)
      updateSelectInput(session, "curve", selected = init_p$curve %||% "logistic")
      updateCheckboxInput(session, "run_rules",
        value = !identical(init_p$run_rules, FALSE))
      if (phase3_supports_prediction(type_id)) {
        updateSelectInput(session, "pred_table", selected = init_p$pred_table %||% "")
        updateCheckboxInput(session, "pred_conf_int",
          value = isTRUE(init_p$pred_conf_int %||% FALSE))
      }
      # Restore output_enabled toggles (fire after renderUI has inserted inputs)
      defs <- phase3_return_defs(type_id)
      saved_en <- init_p$output_enabled %||% list()
      for (d in defs) {
        if (identical(d$key, "table")) next
        val <- isTRUE(saved_en[[d$key]] %||% output_key_default_enabled(d$key, d$kind))
        updateCheckboxInput(session, paste0("output_enabled_", d$key), value = val)
      }
    }, once = TRUE)

    output$output_names_ui <- renderUI({
      defs        <- phase3_return_defs(type_id)
      base_name   <- init_p$output_name %||% paste0(task_id %||% type_id, "_out")
      saved_names <- init_p$output_names %||% phase3_default_output_names(type_id, base_name)
      saved_en    <- init_p$output_enabled %||% list()

      KIND_COLOURS <- c(table = "success", model = "secondary",
                        plot = "primary", image = "info", object = "secondary")

      rows <- lapply(defs, function(d) {
        def_en   <- output_key_default_enabled(d$key, d$kind)
        is_en    <- isTRUE(saved_en[[d$key]] %||% def_en)
        is_main  <- identical(d$key, "table")
        badge_cl <- paste0("badge rounded-pill me-2 bg-", KIND_COLOURS[[d$kind]] %||% "secondary")
        name_val <- saved_names[[d$key]] %||%
          if (is_main) base_name else paste0(base_name, "_", d$key)

        # Toggle switch — main table is always enabled (no toggle shown)
        toggle_ui <- if (!is_main) {
          cb <- checkboxInput(session$ns(paste0("output_enabled_", d$key)),
            sr_label(paste("Save", d$label)), value = is_en)
          tagAppendAttributes(cb, class = "form-switch mb-0 ms-1 flex-shrink-0")
        } else {
          tags$small(class = "text-muted ms-1 flex-shrink-0", "primary")
        }

        div(class = "ig-output-def-row d-flex align-items-center gap-2 py-1",
          span(class = badge_cl, d$kind),
          div(class = "flex-grow-1",
            textInput(session$ns(paste0("output_", d$key)),
              sr_label(paste("Output name for", d$label)),
              value = name_val, width = "100%",
              placeholder = if (is_main) base_name else paste0(base_name, "_", d$key))),
          toggle_ui
        )
      })

      tagList(
        tags$small(class = "text-muted d-block mb-1",
          "Toggle the switch to enable/disable saving each output."),
        tagList(rows)
      )
    })

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% tbls) cur else "")
      if (phase3_supports_prediction(type_id)) {
        pred_cur <- isolate(input$pred_table) %||% init_p$pred_table %||% ""
        updateSelectInput(session, "pred_table", choices = tbls,
          selected = if (!is.null(pred_cur) && pred_cur %in% tbls) pred_cur else "")
      }
    })

    last_column_schema <- NULL
    observe({
      tbl <- input$input_table %||% ""
      # A recreated panel briefly binds its blank table selector before the
      # saved selection arrives. Do not clear restored columns in that gap.
      if (!nzchar(tbl) && nzchar(init_p$input_table %||% "") &&
          !store_inputs_ready(store, task_id)) return()
      ci <- store_col_schema(store, tbl)
      schema <- list(table = tbl, columns = ci$column, classes = ci$class)
      if (identical(schema, last_column_schema)) return()
      last_column_schema <<- schema
      cols <- ci$column %||% character(0)
      choices <- c(setNames("", ""), cols)
      updateSelectInput(session, "x", choices = choices,
        selected = store_preserve_choice(isolate(input$x), init_p$x, choices, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "y", choices = choices,
        selected = store_preserve_choice(isolate(input$y), init_p$y, choices, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "y2", choices = choices,
        selected = store_preserve_choice(isolate(input$y2), init_p$y2, choices, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "group", choices = choices,
        selected = store_preserve_choice(isolate(input$group), init_p$group, choices, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "size", choices = choices,
        selected = store_preserve_choice(isolate(input$size), init_p$size, choices, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "facet", choices = choices,
        selected = store_preserve_choice(isolate(input$facet), init_p$facet, choices, initialized = store_inputs_ready(store, task_id)))
      nums <- ci$column[ci$class %in% c("numeric", "integer", "double")]
      updateSelectInput(session, "cols", choices = nums,
        selected = store_preserve_choices(isolate(input$cols),
          init_p$cols %||% character(0), nums, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "response", choices = choices,
        selected = store_preserve_choice(isolate(input$response),
          init_p$response, choices, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "paired_column", choices = c("", nums),
        selected = store_preserve_choice(isolate(input$paired_column), init_p$paired_column, c("", nums), initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "predictors", choices = cols,
        selected = store_preserve_choices(isolate(input$predictors),
          init_p$predictors %||% character(0), cols, initialized = store_inputs_ready(store, task_id)))
    })

    # Event-level choices for survival tasks: when the event column is a
    # factor / character, let the user pick which level counts as the event.
    if (type_id %in% c("life_tables", "proportional_hazards")) {
      observeEvent(list(input$group, input$input_table), {
        ev_col <- input$group %||% ""
        df <- isolate(store$tables[[input$input_table %||% ""]])
        auto <- c("(auto: 1 / TRUE / second level)" = "")
        choices <- if (is.data.frame(df) && nzchar(ev_col) &&
                       ev_col %in% names(df) &&
                       !is.numeric(df[[ev_col]]) && !is.logical(df[[ev_col]])) {
          lv <- sort(unique(as.character(df[[ev_col]][!is.na(df[[ev_col]])])))
          c(auto, setNames(lv, lv))
        } else {
          auto
        }
        cur <- isolate(input$event_level) %||% init_p$event_level %||% ""
        updateSelectInput(session, "event_level", choices = choices,
          selected = if (cur %in% choices) cur else "")
      }, ignoreInit = FALSE)
    }

    collect_p <- reactive({
      defs     <- phase3_return_defs(type_id)
      base_out <- trimws(input$output_name %||% paste0(task_id %||% type_id, "_out"))
      if (!nzchar(base_out)) base_out <- paste0(task_id %||% type_id, "_out")

      output_names   <- list()
      output_enabled <- list()
      for (d in defs) {
        is_main  <- identical(d$key, "table")
        enabled  <- if (is_main) TRUE else
          isTRUE(input[[paste0("output_enabled_", d$key)]] %||%
                   output_key_default_enabled(d$key, d$kind))
        output_enabled[[d$key]] <- enabled
        if (!enabled) {
          output_names[[d$key]] <- ""
        } else {
          raw_val <- trimws(input[[paste0("output_", d$key)]] %||% "")
          val <- if (nzchar(raw_val)) raw_val else
            if (is_main) base_out else paste0(base_out, "_", d$key)
          output_names[[d$key]] <- val
        }
      }
      output_names <- output_names
      list(
        type_id = type_id,
        input_table = input$input_table %||% "",
        x = input$x %||% "",
        y = input$y %||% "",
        y2 = input$y2 %||% "",
        y2_label = input$y2_label %||% "",
        density_overlay = isTRUE(input$density_overlay),
        donut = isTRUE(input$donut),
        matrix_view = input$matrix_view %||% init_p$matrix_view %||% "distributions",
        group = input$group %||% "",
        size = input$size %||% "",
        facet = input$facet %||% "",
        cols = input$cols %||% character(0),
        response = input$response %||% "",
        predictors = input$predictors %||% character(0),
        family = input$family %||% "gaussian",
        k = input$k %||% 3L,
        cluster_method = input$cluster_method %||% "kmeans",
        cluster_linkage = input$cluster_linkage %||% "complete",
        cluster_seed = input$cluster_seed %||% 1L,
        paired = isTRUE(input$paired),
        paired_column = input$paired_column %||% "",
        horizon = input$horizon %||% 12L,
        curve = input$curve %||% "logistic",
        run_rules = !identical(input$run_rules, FALSE),
        event_level = input$event_level %||% "",
        title = input$title %||% "",
        subtitle = input$subtitle %||% "",
        x_label = input$x_label %||% "",
        y_label = input$y_label %||% "",
        caption = input$caption %||% "",
        plot_theme = input$plot_theme %||% "clean",
        palette = input$palette %||% "ig",
        legend_position = input$legend_position %||% "right",
        show_grid = isTRUE(input$show_grid %||% init_p$show_grid %||% TRUE),
        flip = isTRUE(input$flip),
        bins = input$bins %||% 30L,
        point_alpha = input$point_alpha %||% 0.78,
        bar_alpha = input$bar_alpha %||% 0.86,
        line_width   = input$line_width   %||% 1.05,
        plot_width    = input$plot_width   %||% 8,
        plot_height   = input$plot_height  %||% 4,
        pred_table    = if (phase3_supports_prediction(type_id)) (input$pred_table %||% "") else "",
        pred_conf_int = if (phase3_supports_prediction(type_id)) isTRUE(input$pred_conf_int) else FALSE,
        output_name    = output_names$table %||% base_out,
        output_names   = output_names,
        output_enabled = output_enabled
      )
    })

    finish_phase3 <- function(result, p, register) {
      if (!is.null(result$error)) {
        run_status_msg(paste("Error:", result$error))
        showNotification(result$error, type = "error", duration = 8)
        if (register) return(store_task_failed(store, task_id, result$error))
        return(invisible(FALSE))
      }
      result_df(result$data)
      result_plot(result$plot)
      result_image((result$objects %||% list())$image)
      result_objects(result$objects %||% list())
      # Auto-switch preview to the most informative tab
      target <- if (type_id %in% PHASE3_GRAPH_TYPES ||
                    (type_id %in% PHASE3_PLOTTING_STATS && !is.null(result$plot))) {
        "Plot"
      } else {
        "Results"
      }
      bslib::nav_select("result_tabs", target, session = session)
      .desc_goto_results(session)
      if (isTRUE(register)) {
        out <- p$output_name %||% ""
        store_phase3_outputs(store, p, result)
        if (!is.null(task_id)) {
          task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, type_id)
          task <- store_task_from_params(task, p)
          task$output  <- out
          task$outputs <- phase3_output_specs(p, result)
          task$params  <- p   # includes output_enabled
          task$r_code  <- build_phase3_code(type_id, p)
          task$run_time  <- Sys.time()
          task$error_msg <- NULL
          store_set_task(store, task)
        }
      }
      nr <- if (is.data.frame(result$data)) nrow(result$data) else 0L
      nc <- if (is.data.frame(result$data)) ncol(result$data) else 0L
      run_status_msg(sprintf("%s complete: %d x %d", type_id, nr, nc))
      invisible(TRUE)
    }

    run_phase3 <- function(register = FALSE) {
      p <- collect_p()
      if (!register && ig_background_eligible(store, task_id, p, register = FALSE)) {
        run_status_msg("Calculating in the background...")
        return(ig_background_start(store, task_id, params = p, register = FALSE,
          complete = function(result) finish_phase3(result, p, FALSE), module_session = session))
      }
      finish_phase3(execute_phase3_task(type_id, p, isolate(store$tables)), p, register)
    }

    observeEvent(input$btn_preview, { run_phase3(register = FALSE) })
    do_run <- function() run_phase3(register = TRUE)
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })

    output$run_status <- renderText(run_status_msg())
    register_preview_visible(output, run_status_msg)
    output$result_dt <- DT::renderDT({
      req(result_df())
      DT::datatable(head(result_df(), 1000L),
        options = list(scrollX = TRUE, pageLength = ig_page_len(store),
          dom = "Bfrtip", buttons = c("copy", "csv")),
        extensions = "Buttons",
        rownames = FALSE)
    })
    output$plot <- ggiraph::renderGirafe({
      req(result_plot())
      result_plot()
    })

    output$result_gt <- ig_render_gt({
      req(result_df())
      format_phase3_result(type_id, result_df(), result_objects())
    })

    output$task_code_view <- renderText({
      tryCatch(
        build_phase3_code(type_id, collect_p()),
        error = function(e) paste("# Error generating code:", conditionMessage(e))
      )
    })

    output$download_plot_png <- downloadHandler(
      filename = function() paste0((collect_p()$output_names$image %||% collect_p()$output_name %||% "plot"), ".png"),
      content = function(file) {
        req(result_image())
        p <- collect_p()
        ggplot2::ggsave(file, result_image(), width = p$plot_width, height = p$plot_height, units = "in", dpi = 150)
      }
    )
    output$download_plot_html <- downloadHandler(
      filename = function() paste0((collect_p()$output_names$plot %||% collect_p()$output_name %||% "plot"), ".html"),
      content = function(file) {
        req(result_plot())
        writeLines(ig_report_widget_html(result_plot()), file, useBytes = TRUE)
      }
    )
    store_register_result_fn(store, task_id, function(result) {
      result_df(result$data); result_plot(result$plot); result_image(result$objects$image); result_objects(result$objects %||% list()); run_status_msg(ig_preview_status(result))
      if (isTRUE(result$background_run) && is.null(result$error)) {
        target <- if (type_id %in% PHASE3_GRAPH_TYPES ||
          (type_id %in% PHASE3_PLOTTING_STATS && !is.null(result$plot))) "Plot" else "Results"
        bslib::nav_select("result_tabs", target, session = session)
        .desc_goto_results(session)
      }
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
    store_register_code_fn(store, task_id,
      function() build_phase3_code(type_id, collect_p()))
  })
}

execute_phase3_task <- function(type_id, p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, plot = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  tryCatch({
    if (inherits(df, "tbl_sql")) df <- as.data.frame(dplyr::collect(df))
    if (!is.data.frame(df)) stop("Table not found: ", tbl)
    if (!type_id %in% PHASE3_TYPES) stop("Unknown analytical task: ", type_id)
    if (!nrow(df)) stop("The input table has no observations.")
    if (isTRUE(p$output_enabled$predictions) && !nzchar(p$pred_table %||% ""))
      stop("Select a new data table to save predictions.")
    if (type_id %in% PHASE3_GRAPH_TYPES) return(execute_phase3_graph(type_id, p, df,
      default_title = task_type_info(type_id)$label %||% type_id))
    execute_phase3_analysis(type_id, p, df, tables)
  }, error = function(e) list(data = NULL, plot = NULL, error = conditionMessage(e)))
}

phase3_plot_palette <- function(name) {
  switch(name %||% "ig",
    okabe_ito = c("#0072B2", "#E69F00", "#009E73", "#D55E00",
      "#CC79A7", "#56B4E9", "#F0E442", "#000000"),
    tableau = c("#4E79A7", "#F28E2B", "#E15759", "#76B7B2",
      "#59A14F", "#EDC948", "#B07AA1", "#FF9DA7", "#9C755F", "#BAB0AC"),
    viridis = c("#440154", "#31688E", "#35B779", "#FDE725"),
    grey = c("#1f2937", "#4b5563", "#9ca3af", "#d1d5db"),
    c("#4361ee", "#2d6a4f", "#c77b3b", "#8b1a4a",
      "#3a8a3a", "#7b5ea7", "#0f766e", "#b45309")
  )
}

phase3_apply_plot_style <- function(gp, p, type_id, uses_discrete_scale = TRUE) {
  theme_name <- p$plot_theme %||% "clean"
  base_theme <- switch(theme_name,
    publication = ggplot2::theme_classic(base_size = 12),
    minimal = ggplot2::theme_minimal(base_size = 12),
    classic = ggplot2::theme_classic(base_size = 12),
    light = ggplot2::theme_light(base_size = 12),
    dark = ggplot2::theme_dark(base_size = 12),
    ggplot2::theme_minimal(base_size = 12)
  )
  legend_pos <- p$legend_position %||% "right"
  gp <- gp + base_theme +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(size = 10),
      legend.position = legend_pos,
      panel.grid.major = if (isTRUE(p$show_grid)) ggplot2::element_line(linewidth = 0.25) else ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank()
    )
  if (identical(theme_name, "clean")) {
    gp <- gp + ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "#ffffff", colour = NA),
      plot.background = ggplot2::element_rect(fill = "#ffffff", colour = NA),
      axis.title = ggplot2::element_text(face = "bold", colour = "#1f2937"),
      axis.text = ggplot2::element_text(colour = "#374151"),
      panel.grid.major = if (isTRUE(p$show_grid)) ggplot2::element_line(colour = "#e5e7eb", linewidth = 0.25) else ggplot2::element_blank()
    )
  }
  if (identical(theme_name, "dark")) {
    gp <- gp + ggplot2::theme(
      plot.title = ggplot2::element_text(colour = "#f8fafc", face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "#cbd5e1"),
      axis.title = ggplot2::element_text(colour = "#e5e7eb"),
      axis.text = ggplot2::element_text(colour = "#cbd5e1"),
      legend.text = ggplot2::element_text(colour = "#e5e7eb"),
      legend.title = ggplot2::element_text(colour = "#f8fafc")
    )
  }
  if (isTRUE(uses_discrete_scale)) {
    pal <- phase3_plot_palette(p$palette)
    # Recycle the palette when the grouping has more levels than colours —
    # scale_*_manual() errors outright on insufficient values.
    n_levels <- attr(uses_discrete_scale, "n_levels") %||% length(pal)
    if (n_levels > length(pal)) pal <- rep(pal, length.out = n_levels)
    gp <- gp +
      ggplot2::scale_colour_manual(values = pal) +
      ggplot2::scale_fill_manual(values = pal)
  }
  if (isTRUE(p$flip) && type_id %in% c("bar_chart", "box_plot")) {
    gp <- gp + ggplot2::coord_flip()
  }
  gp
}

execute_phase3_graph <- function(type_id, p, df, default_title = type_id) {
  x <- p$x %||% ""; y <- p$y %||% ""; group <- p$group %||% ""
  y2 <- if (type_id %in% c("bar_line_chart", "line_plot")) p$y2 %||% "" else ""
  size_col <- p$size %||% ""
  if (!nzchar(x) && !identical(type_id, "scatter_matrix"))
    return(list(data = NULL, plot = NULL, error = "Select an X/category column."))
  required_y <- c("bar_line_chart", "box_plot", "bubble_plot", "contour_plot",
                  "line_plot", "scatter_plot")
  if (type_id %in% required_y && !nzchar(y))
    return(list(data = NULL, plot = NULL, error = "Select a Y/value column."))
  needed <- unique(Filter(nzchar, c(x, y, y2, group, size_col, p$facet %||% "")))
  missing <- setdiff(needed, names(df))
  if (length(missing))
    return(list(data = NULL, plot = NULL,
      error = paste("Column not found:", paste(missing, collapse = ", "))))
  numeric_y <- c("bar_line_chart", "box_plot", "bubble_plot", "contour_plot",
                 "line_plot", "scatter_plot")
  if (type_id %in% numeric_y && !is.numeric(df[[y]]))
    return(list(data = NULL, plot = NULL, error = "Y/value column must be numeric."))
  if (identical(type_id, "histogram_graph") && !is.numeric(df[[x]]))
    return(list(data = NULL, plot = NULL, error = "Histogram X column must be numeric."))
  if (nzchar(y2)) .p3_require_numeric(df, y2, "secondary Y")
  if (type_id == "bar_chart" && nzchar(y) && !is.numeric(df[[y]])) stop("Y/value column must be numeric.")
  if (nzchar(size_col) && !is.numeric(df[[size_col]])) stop("Size column must be numeric.")
  title <- p$title %||% ""
  if (!nzchar(title)) title <- default_title
  bins <- max(2L, as.integer(p$bins %||% 30L))
  point_alpha <- max(0.1, min(1, as.numeric(p$point_alpha %||% 0.78)))
  bar_alpha <- max(0.1, min(1, as.numeric(p$bar_alpha %||% 0.86)))
  line_width <- max(0.2, as.numeric(p$line_width %||% 1.05))
  # Build aes() from column-name strings using the .data pronoun.
  # (aes_string() is deprecated; passing language objects through do.call()
  # lets aes() capture them as if typed literally.)
  dd <- function(col) str2lang(sprintf('.data[[%s]]', deparse(col)))
  # Tooltip aes for ggiraph interactive geoms: one "col: value" line per
  # mapped column. This is what makes the girafe widgets actually
  # interactive — plain geoms wrapped in girafe() show nothing on hover.
  tip_aes <- function(...) {
    cols <- Filter(nzchar, unique(unlist(list(...))))
    if (!length(cols)) return(ggplot2::aes())
    parts <- vapply(cols, function(cl)
      sprintf('%s, .data[[%s]]', code_literal(paste0(cl, ": ")), code_literal(cl)), character(1))
    expr <- str2lang(paste0("paste0(", paste(parts, collapse = ', "\\n", '), ")"))
    do.call(ggplot2::aes, list(tooltip = expr))
  }
  # Tooltip for count-based geoms (bar/histogram): computed stat value.
  # Must be namespace-qualified: the constructed quosure's environment is the
  # package namespace, which does not import after_stat.
  tip_count <- do.call(ggplot2::aes,
    list(tooltip = str2lang('ggplot2::after_stat(paste0("count: ", count))')))
  aes_xy <- function(include_y = FALSE, colour = FALSE, fill = FALSE,
                     size = FALSE, group_map = FALSE) {
    mapping <- list(x = dd(x))
    if (include_y) mapping$y <- dd(y)
    if (colour && nzchar(group)) mapping$colour <- dd(group)
    if (fill && nzchar(group)) mapping$fill <- dd(group)
    if (size && nzchar(size_col)) mapping$size <- dd(size_col)
    if (group_map && nzchar(group)) mapping$group <- dd(group)
    do.call(ggplot2::aes, mapping)
  }
  # Box plots over a numeric X draw one meaningless box; treat distinct values
  # as categories instead (matches how SEG-style tools handle class variables).
  if (identical(type_id, "box_plot") && nzchar(x) && is.numeric(df[[x]])) {
    df[[x]] <- factor(df[[x]])
  }
  gp <- switch(type_id,
    bar_chart = {
      if (nzchar(y) && y %in% names(df) && is.numeric(df[[y]])) {
        layer <- if (nzchar(group)) {
          ggiraph::geom_col_interactive(mapping = tip_aes(x, y, group),
            alpha = bar_alpha)
        } else {
          ggiraph::geom_col_interactive(mapping = tip_aes(x, y),
            alpha = bar_alpha, fill = "#4361ee")
        }
        ggplot2::ggplot(df, aes_xy(include_y = TRUE, fill = TRUE)) +
          layer
      } else {
        layer <- if (nzchar(group)) {
          ggiraph::geom_bar_interactive(mapping = tip_count, alpha = bar_alpha)
        } else {
          ggiraph::geom_bar_interactive(mapping = tip_count, alpha = bar_alpha,
            fill = "#4361ee")
        }
        ggplot2::ggplot(df, aes_xy(fill = TRUE)) +
          layer
      }
    },
    bar_line_chart = ggplot2::ggplot(df, aes_xy(include_y = TRUE, colour = TRUE, group_map = TRUE)) +
      ggplot2::geom_col(alpha = min(bar_alpha, 0.55), fill = "#94a3b8") +
      ggplot2::geom_line(linewidth = line_width),
    box_plot = ggplot2::ggplot(df, aes_xy(include_y = TRUE, fill = TRUE)) +
      if (nzchar(group)) ggplot2::geom_boxplot() else ggplot2::geom_boxplot(fill = "#4361ee", alpha = bar_alpha),
    bubble_plot = ggplot2::ggplot(df, aes_xy(include_y = TRUE, colour = TRUE, size = TRUE)) +
      if (nzchar(group)) {
        ggiraph::geom_point_interactive(
          mapping = tip_aes(x, y, group, size_col), alpha = point_alpha)
      } else {
        ggiraph::geom_point_interactive(
          mapping = tip_aes(x, y, size_col), alpha = point_alpha,
          color = "#4361ee")
      },
    contour_plot = ggplot2::ggplot(df, aes_xy(include_y = TRUE)) +
      ggplot2::geom_density_2d_filled(alpha = 0.75),
    histogram_graph = ggplot2::ggplot(df, aes_xy(fill = TRUE)) +
      if (nzchar(group)) {
        ggiraph::geom_histogram_interactive(mapping = tip_count, bins = bins,
          color = "white", alpha = bar_alpha)
      } else {
        ggiraph::geom_histogram_interactive(mapping = tip_count, bins = bins,
          fill = "#4361ee", color = "white", alpha = bar_alpha)
      },
    line_plot = ggplot2::ggplot(df, aes_xy(include_y = TRUE, colour = TRUE, group_map = TRUE)) +
      if (nzchar(group)) ggplot2::geom_line(linewidth = line_width) else ggplot2::geom_line(linewidth = line_width, color = "#4361ee"),
    pie_chart = {
      d <- as.data.frame(table(df[[x]], useNA = "ifany"), stringsAsFactors = FALSE)
      count_col <- if (x == "n") "count" else "n"
      names(d) <- c(x, count_col)
      ggplot2::ggplot(d, ggplot2::aes(x = "", y = .data[[count_col]], fill = .data[[x]])) +
        ggiraph::geom_col_interactive(mapping = tip_aes(x, count_col),
          width = 1, alpha = bar_alpha, color = "white") +
        ggplot2::coord_polar(theta = "y")
    },
    scatter_plot = ggplot2::ggplot(df, aes_xy(include_y = TRUE, colour = TRUE)) +
      if (nzchar(group)) {
        ggiraph::geom_point_interactive(mapping = tip_aes(x, y, group),
          alpha = point_alpha)
      } else {
        ggiraph::geom_point_interactive(mapping = tip_aes(x, y),
          alpha = point_alpha, color = "#4361ee")
      },
    scatter_matrix = {
      nums <- .p3_numeric_columns(df, p$cols, "Scatter matrix")
      if (identical(p$matrix_view %||% "distributions", "pairs")) {
        pairs_df <- .p3_scatter_pairs(df, nums)
        ggplot2::ggplot(pairs_df, ggplot2::aes(x = x_value, y = y_value)) +
          ggiraph::geom_point_interactive(ggplot2::aes(tooltip = paste0(x_variable, ": ", x_value,
            "\n", y_variable, ": ", y_value, "\nRow: ", row)), alpha = point_alpha, colour = "#4361ee") +
          ggplot2::facet_grid(y_variable ~ x_variable, scales = "free")
      } else {
        ggplot2::ggplot(stack(utils::head(df[nums], 1000L)), ggplot2::aes(x = values)) +
          ggiraph::geom_histogram_interactive(mapping = tip_count, bins = bins,
            alpha = bar_alpha, fill = "#4361ee", colour = "white") +
          ggplot2::facet_wrap(~ ind, scales = "free")
      }
    },
    ggplot2::ggplot(df, aes_xy()) + ggplot2::geom_bar()
  )
  if (nzchar(y2)) {
    transform <- .p3_secondary_scale(df[[y]], df[[y2]], include_zero = type_id == "bar_line_chart")
    # Keep raw secondary values in tooltips while transforming the drawn line.
    secondary_mapping <- aes_xy(include_y = FALSE, colour = TRUE, group_map = TRUE)
    secondary_mapping$y <- do.call(ggplot2::aes, list(y =
      str2lang(paste0('(', code_literal(transform$slope), ' * .data[[', code_literal(y2), ']] + ', code_literal(transform$intercept), ')'))))$y
    if (type_id == "bar_line_chart") {
      gp <- ggplot2::ggplot(df, aes_xy(include_y = TRUE, colour = TRUE, group_map = TRUE)) +
        ggiraph::geom_col_interactive(mapping = tip_aes(x, y, group),
          alpha = min(bar_alpha, 0.55), fill = "#94a3b8")
    }
    gp <- gp + ggiraph::geom_line_interactive(mapping = secondary_mapping,
      linewidth = line_width, linetype = "dashed") +
      ggiraph::geom_point_interactive(mapping = secondary_mapping,
        tooltip = paste0(y2, ": ", df[[y2]]), size = 1.5) +
      ggplot2::scale_y_continuous(sec.axis = ggplot2::sec_axis(
        transform = function(value) (value - transform$intercept) / transform$slope,
        name = if (nzchar(p$y2_label %||% "")) p$y2_label else y2))
  }
  if (type_id == "histogram_graph" && isTRUE(p$density_overlay)) {
    if (sum(is.finite(df[[x]])) < 2L) stop("Density overlay requires at least two finite values.")
    gp$layers[[1]]$mapping$y <- ggplot2::aes(y = ggplot2::after_stat(density))$y
    gp <- gp + ggplot2::geom_density(linewidth = line_width, colour = "#8b1a4a")
  }
  if (type_id == "pie_chart" && isTRUE(p$donut)) {
    gp$mapping$x <- ggplot2::aes(x = 2)$x
    gp <- gp + ggplot2::xlim(0.5, 2.5)
  }
  if (nzchar(p$facet %||% "") && p$facet %in% names(df)) {
    gp <- gp + ggplot2::facet_wrap(stats::as.formula(paste("~", r_ident(p$facet))))
  }
  gp <- gp + ggplot2::labs(
    title = title,
    subtitle = p$subtitle %||% NULL,
    x = if (nzchar(p$x_label %||% "")) p$x_label else NULL,
    y = if (nzchar(p$y_label %||% "")) p$y_label else NULL,
    caption = p$caption %||% NULL
  )
  # Manual discrete palettes only apply when the grouping column is actually
  # discrete — a numeric group maps to a continuous scale, and forcing a
  # manual discrete scale onto it errors when the plot is rendered.
  group_is_discrete <- nzchar(group) && group %in% names(df) &&
    !is.numeric(df[[group]])
  uses_discrete_scale <- !identical(type_id, "contour_plot") &&
    (group_is_discrete || identical(type_id, "pie_chart"))
  if (uses_discrete_scale) {
    n_levels <- if (group_is_discrete) {
      length(unique(df[[group]]))
    } else if (identical(type_id, "pie_chart") && x %in% names(df)) {
      length(unique(df[[x]]))
    } else {
      0L
    }
    attr(uses_discrete_scale, "n_levels") <- n_levels
  }
  gp <- phase3_apply_plot_style(gp, p, type_id,
    uses_discrete_scale = uses_discrete_scale)
  w    <- max(3, as.numeric(p$plot_width  %||% 8))
  h    <- max(2, as.numeric(p$plot_height %||% 4.2))
  plot <- ggiraph::girafe(ggobj = gp, width_svg = w, height_svg = h)
  # Return computed/summarised data rather than raw rows wherever possible
  plot_data <- switch(type_id,
    pie_chart = {
      d <- as.data.frame(table(df[[x]], useNA = "ifany"), stringsAsFactors = FALSE)
      names(d) <- c(x, if (x == "n") "count" else "n")
      d
    },
    histogram_graph = {
      binned <- ggplot2::ggplot_build(gp)$data[[1L]]
      output <- data.frame(bin_start = binned$xmin, bin_end = binned$xmax,
        midpoint = binned$x, count = binned$count, density = binned$density)
      if (nzchar(group)) output$group <- binned$group
      if (nzchar(p$facet %||% "")) output$panel <- as.integer(binned$PANEL)
      output
    },
    bar_chart = if (!nzchar(y) || !y %in% names(df)) {
      if (nzchar(group) && group %in% names(df)) {
        d2 <- as.data.frame(table(df[[x]], df[[group]], useNA = "ifany"),
          stringsAsFactors = FALSE)
        names(d2) <- c(x, group, "n")
        d2
      } else {
        d2 <- as.data.frame(table(df[[x]], useNA = "ifany"), stringsAsFactors = FALSE)
        names(d2) <- c(x, "n")
        d2
      }
    } else {
      as.data.frame(utils::head(df, 1000L))
    },
    as.data.frame(utils::head(df, 1000L))
  )
  list(
    data = plot_data,
    plot = plot,
    objects = list(plot = plot, image = gp),
    error = NULL
  )
}

execute_phase3_analysis <- function(type_id, p, df, tables = list()) {
  if (type_id %in% c("cdf_plots", "probability_plots", "control_charts", "arima_forecast") && !nzchar(p$response %||% "")) {
    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    p$response <- if (length(numeric_cols)) numeric_cols[[1L]] else ""
  }
  switch(type_id,
    correlations = .p3_correlations(p, df, tables),
    pca = .p3_pca(p, df, tables),
    cluster_analysis = .p3_cluster(p, df),
    linear_regression = , linear_models = , glm = , logistic_regression = .p3_regression(type_id, p, df, tables),
    one_way_anova = .p3_anova(p, df, tables),
    t_test = .p3_t_test_result(p, df),
    cdf_plots = execute_cdf_plot(p, df),
    probability_plots = execute_probability_plot(p, df),
    control_charts = execute_control_chart(p, df),
    arima_forecast = execute_arima_forecast(p, df),
    life_tables = execute_life_tables(p, df),
    proportional_hazards = execute_cox(p, df, tables),
    nonlinear_regression = execute_nonlinear_regression(p, df),
    stop("Unknown analytical task: ", type_id))
}

phase3_output_specs <- function(p, result) {
  out_names <- p$output_names %||% phase3_default_output_names(p$type_id %||% "phase3", p$output_name %||% "")
  out <- out_names$table %||% p$output_name %||% ""
  specs <- list()
  if (!identical(p$output_enabled$table, FALSE) && nzchar(out) && is.data.frame(result$data)) {
    specs <- c(specs, list(list(name = out, kind = "table", label = "Summary table")))
  }
  # Broom data-frame outputs that are stored as queryable tables
  TABLE_KEYS <- c("glance", "augment", "tukey", "loadings",
                  "scores", "clusters", "predictions")

  objs <- result$objects %||% list()
  objs <- objs[vapply(names(objs), function(key) !identical(p$output_enabled[[key]], FALSE) && !is.null(objs[[key]]), logical(1))]
  if (length(objs)) {
    specs <- c(specs, lapply(names(objs), function(nm) {
      kind <- if (nm %in% TABLE_KEYS) "table" else switch(nm,
        plot = "plot",
        image = "image",
        model = "model",
        matrix = "object",
        test = "object",
        summary = "object",
        "object")
      list(name = out_names[[nm]] %||% paste0(out, "_", nm), kind = kind,
        label = paste("Special output:", nm))
    }))
  }
  specs
}

store_phase3_outputs <- function(store, p, result) {
  out_names <- p$output_names %||% phase3_default_output_names(p$type_id %||% "phase3", p$output_name %||% "")
  out <- out_names$table %||% p$output_name %||% ""
  if (!identical(p$output_enabled$table, FALSE) && nzchar(out) && is.data.frame(result$data)) {
    store_add_table(store, out, result$data)
  }
  # broom data-frame outputs go to the table store (queryable downstream);
  # raw model/test/matrix objects go to the object store.
  TABLE_KEYS <- c("glance", "augment", "tukey", "loadings", "scores", "clusters", "predictions")
  objs <- result$objects %||% list()
  for (nm in names(objs)) {
    if (identical(p$output_enabled[[nm]], FALSE)) next
    nm_out <- out_names[[nm]] %||% paste0(out, "_", nm)
    if (!nzchar(nm_out %||% "")) next
    obj <- objs[[nm]]
    if (is.null(obj)) next
    if (nm %in% TABLE_KEYS && is.data.frame(obj)) {
      store_add_table(store, nm_out, obj)
    } else {
      store_add_object(store, nm_out, obj,
        meta = list(kind = nm, source_output = out, task_type = p$type_id %||% "phase3"))
    }
  }
  invisible(NULL)
}

build_phase3_code <- function(type_id, p) {
  build_phase3_shared_code(type_id, p)
}
