# Sourced by build-examples.R into the current package namespace's child scope.
# All recipe steps use the same task parameter constructors as the app.
build_extended_example <- function(info, add, script, work) {
  items <- list(); result <- NULL
  remember <- function(name, heading = name) {
    items[[length(items) + 1L]] <<- list(name = name, heading = heading)
    invisible(name)
  }
  source <- function(code, name, rows_note = info$source) {
    script("example_source", paste(code,
      sprintf("log_event('Loaded bundled data for %s')", info$id), sep = "\n"),
      name, "Load original observations", note = rows_note)
    remember(name, "Original observations")
  }
  dt <- function(type, input, out, ...) {
    constructor <- switch(type, keep_drop_cols = default_keep_drop_params,
      first_last_n = default_first_last_params, default = NULL)
    if (is.null(constructor)) constructor <- get(paste0("default_", type, "_params"))
    p <- alter(constructor(out), input_table = input, ...)
    if (type == "list_data") p$output_enabled <- TRUE
    add(paste0("example_", type), type, p, task_type_info(type)$label)
    remember(out, task_type_info(type)$label); result <<- out
    invisible(out)
  }
  phase <- function(type, input, out = type, ...) {
    p <- alter(default_phase3_params(type, out), input_table = input, ...)
    if ("plot" %in% names(p$output_enabled)) p$output_enabled$plot <- FALSE
    for (key in intersect(c("image", "model", "augment", "scores", "summary"), names(p$output_enabled)))
      p$output_enabled[[key]] <- TRUE
    add(paste0("example_", type), type, p, task_type_info(type)$label,
      "Static images are retained for portability. Enable the interactive plot output for a local preview.")
    remember(out, task_type_info(type)$label)
    for (key in intersect(c("glance", "loadings", "tukey", "image"), names(p$output_enabled)))
      if (isTRUE(p$output_enabled[[key]])) remember(p$output_names[[key]], paste(task_type_info(type)$label, key))
    result <<- out
    invisible(out)
  }
  cars <- "cars <- datasets::mtcars\ncars$car <- rownames(cars)\nrownames(cars) <- NULL"
  flowers <- "flowers <- datasets::iris"
  filter <- function(col, op, value, type = "numeric") list(col = col, op = if (op == "==") "=" else op, val = value, col_class = type)
  switch(info$id,
    `data-cleaning` = {
      source(paste(cars, "cars <- rbind(cars, cars[1, , drop=FALSE]) # Deliberate duplicate for this exercise", sep = "\n"), "cars")
      dt("remove_dups", "cars", "unique_cars")
      dt("keep_drop_cols", "unique_cars", "selected", cols = c("car", "mpg", "wt", "hp", "am"))
      dt("rename_cols", "selected", "renamed", renames = list(list(old = "wt", new = "weight_1000lb")))
      dt("derive_cols", "renamed", "derived", derives = list(list(name = "hp_per_1000lb", expr = "hp / weight_1000lb")))
      dt("recode_values", "derived", "labelled", col = "am", new_col_name = "transmission",
        rules = list(list(from = "0", to = "Automatic"), list(from = "1", to = "Manual")))
      dt("change_types", "labelled", "analysis_cars", type_changes = list(list(col = "transmission", type = "factor")))
      dt("first_last_n", "analysis_cars", "first_cars", n = 5L)
      dt("characterize", "analysis_cars", "column_audit")
      result <- "analysis_cars"
    },
    `query-joins` = {
      states <- as.data.frame(datasets::state.x77); states$state <- rownames(states); rownames(states) <- NULL
      utils::write.csv(states, file.path(work, "state-statistics.csv"), row.names = FALSE)
      source("regions <- data.frame(state=datasets::state.name, region=as.character(datasets::state.region))", "regions")
      add("example_import", "import_data", alter(default_import_params("states"),
        path = file.path(work, "state-statistics.csv"), type = "csv"), "Import bundled state-statistics.csv")
      remember("states", "Imported state statistics")
      add("example_query", "query_builder", alter(default_qb_params("state_regions"), primary_table = "states",
        joins = list(list(right_table = "regions", type = "left", keys_left = "state", keys_right = "state"))), "Join the regional lookup")
      remember("state_regions", "Joined states and regions")
      dt("filter_sort", "state_regions", "high_income", filters = list(filter("Income", ">=", "4500")), sorts = list(list(col = "Income", dir = "DESC")))
    },
    reshape = {
      source(paste(flowers, "flowers$flower_id <- seq_len(nrow(flowers))", sep = "\n"), "flowers")
      dt("stack_columns", "flowers", "long_measurements", cols = names(datasets::iris)[1:4], names_to = "measurement", values_to = "length_cm")
      dt("split_columns", "long_measurements", "wide_measurements", id_cols = c("Species", "flower_id"), names_from = "measurement", values_from = "length_cm")
      add("example_compare", "compare_data", alter(default_compare_data_params("round_trip_differences"), table_a = "flowers", table_b = "wide_measurements", by_cols = "flower_id"), "Compare the pivot round trip", "Column order may differ; inspect the comparison output as well as values.")
      remember("round_trip_differences", "Round-trip comparison")
      script("example_subsets", "setosa <- flowers[flowers$Species == 'setosa', ]\nversicolor <- flowers[flowers$Species == 'versicolor', ]\nsmall_numeric <- flowers[1:5, 1:4]",
        "setosa", "Prepare subsets and a small numeric table", "flowers",
        defs = lapply(c("setosa", "versicolor", "small_numeric"), function(nm) list(name = nm, kind = "table")))
      add("example_append", "append_table", alter(default_append_table_params("two_species"), input_tables = c("setosa", "versicolor")), "Append two species subsets")
      remember("two_species", "Appended observations")
      dt("transpose", "small_numeric", "transposed")
      result <- "long_measurements"
    },
    sampling = {
      source(cars, "cars")
      dt("rank", "cars", "ranked_cars", rank_col = "mpg", method = "dense_rank", new_col_name = "mpg_rank")
      dt("standardize", "ranked_cars", "scaled_cars", cols = c("mpg", "wt", "hp"))
      dt("random_sample", "scaled_cars", "sampled_cars", n = 10L, seed = 2026L)
    },
    descriptive = {
      source("teeth <- datasets::ToothGrowth\nteeth$dose <- factor(teeth$dose)", "teeth")
      dt("characterize", "teeth", "column_audit")
      dt("list_data", "teeth", "observation_listing")
      dt("one_way_freq", "teeth", "supplement_counts", col = "supp")
      dt("summary_stats", "teeth", "length_summary", cols = "len")
      dt("summary_tables", "teeth", "dose_summary", row_var = "dose", col_var = "supp", value_var = "len", stat_fn = "mean")
      dt("table_analysis", "teeth", "design_counts", row_col = "dose", col_col = "supp")
      dt("distribution", "teeth", "length_distribution", col = "len", bins = 12L, show_qq = TRUE)
      result <- "dose_summary"
    },
    `category-charts` = {
      source(flowers, "flowers")
      phase("bar_chart", "flowers", x = "Species")
      phase("pie_chart", "flowers", x = "Species", donut = TRUE)
      phase("box_plot", "flowers", x = "Species", y = "Petal.Length", group = "Species")
    },
    `numeric-charts` = {
      source(flowers, "flowers")
      phase("bubble_plot", "flowers", x = "Sepal.Length", y = "Petal.Length", size = "Petal.Width", group = "Species")
      phase("contour_plot", "flowers", x = "Sepal.Length", y = "Petal.Length")
      phase("histogram_graph", "flowers", x = "Sepal.Length", bins = 15L)
      phase("scatter_plot", "flowers", x = "Sepal.Length", y = "Petal.Length", group = "Species")
      phase("scatter_matrix", "flowers", cols = names(datasets::iris)[1:4])
    },
    `time-charts` = {
      source("temperatures <- data.frame(year=as.integer(floor(time(datasets::nottem) + 1e-6)), month=rep(1:12,20), temperature=as.numeric(datasets::nottem))\ntemperatures$date <- as.Date(sprintf('%d-%02d-01',temperatures$year,temperatures$month))", "temperatures")
      phase("line_plot", "temperatures", x = "date", y = "temperature")
      script("example_annual", "annual <- aggregate(temperature ~ year, temperatures, function(x) c(mean=mean(x), range=diff(range(x))))\nannual <- data.frame(year=annual$year, mean=annual$temperature[, 'mean'], range=annual$temperature[, 'range'])", "annual", "Summarize annual temperatures", "temperatures")
      phase("bar_line_chart", "annual", x = "year", y = "mean", y2 = "range", y2_label = "Annual range (degrees F)")
    },
    anova = {
      source("plants <- datasets::PlantGrowth", "plants")
      phase("one_way_anova", "plants", response = "weight", group = "group")
      script("example_two_groups", "two_groups <- droplevels(subset(plants, group %in% c('ctrl','trt2')))", "two_groups", "Select control and treatment 2", "plants")
      phase("t_test", "two_groups", response = "weight", group = "group")
      phase("linear_models", "plants", response = "weight", predictors = "group")
    },
    `binary-model` = { source(cars, "cars"); phase("logistic_regression", "cars", response = "am", predictors = "mpg") },
    `count-model` = { source("breaks <- datasets::warpbreaks", "breaks"); phase("glm", "breaks", response = "breaks", predictors = c("wool", "tension"), family = "poisson") },
    nonlinear = {
      source("enzyme <- datasets::Puromycin", "enzyme")
      dt("filter_sort", "enzyme", "treated", filters = list(filter("state", "==", "treated", "character")))
      phase("nonlinear_regression", "treated", response = "rate", predictors = "conc", curve = "power")
    },
    multivariate = {
      source(flowers, "flowers")
      for (type in c("correlations", "pca", "cluster_analysis")) phase(type, "flowers", predictors = names(datasets::iris)[1:4], cluster_seed = 2026L)
    },
    survival = {
      source("lung_raw <- survival::lung", "lung_raw")
      script("example_complete", "lung <- lung_raw[complete.cases(lung_raw[, c('time','status','age','sex')]), ]\nlung$event <- as.integer(lung$status == 2) # Original status: 1=censored, 2=dead\nlung$sex <- factor(lung$sex, levels=c(1,2), labels=c('Male','Female'))\nlog_event(sprintf('Retained %d of %d records; status 2 maps to event 1', nrow(lung), nrow(lung_raw)))",
        "lung", "Prepare complete cases and event indicator", "lung_raw")
      phase("life_tables", "lung", response = "time", group = "event", predictors = "sex", event_level = "1")
      phase("proportional_hazards", "lung", response = "time", group = "event", predictors = c("age", "sex"), event_level = "1")
    },
    forecast = {
      source("passengers <- data.frame(month=as.numeric(time(datasets::AirPassengers)), passengers=as.numeric(datasets::AirPassengers))", "passengers")
      phase("arima_forecast", "passengers", response = "passengers", horizon = 12L)
    },
    `quality-control` = {
      source("river <- data.frame(year=as.integer(time(datasets::Nile)), flow=as.numeric(datasets::Nile))\nlog_event('Historical river data are not a controlled process; inspect shifts and dependence', 'WARN')", "river")
      for (type in c("control_charts", "cdf_plots", "probability_plots")) phase(type, "river", response = "flow")
    },
    branching = {
      source(flowers, "flowers")
      p <- alter(default_branch_params("quality_gate"), dependencies = "flowers")
      p$paths[[1]]$condition <- list(op = "and", rules = list(list(kind = "row_count", table = "flowers", op = ">=", value = "100")))
      add("example_branch", "branch", p, "Require at least 100 flowers")
      dt("summary_stats", "flowers", "gated_summary", cols = names(datasets::iris)[1:4])
      # Return control dependencies separately so the builder can set them.
      result <- "gated_summary"
    },
    looping = {
      source(flowers, "flowers")
      add("example_loop", "loop", alter(default_loop_params("species_loop"), iteration_type = "groups", source = "flowers", group_col = "Species", variable = "species", naming_rule = "{output}_{index}"), "Repeat a summary for each species")
      script("example_iteration", "species_summary <- data.frame(species=as.character(species), n=nrow(flowers), mean_petal_length=mean(flowers$Petal.Length))\nlog_event(sprintf('Species %s: %d flowers', species, nrow(flowers)))", "species_summary", "Summarize the current species", "flowers")
      result <- "flowers" # report/export outside the loop retain the complete input
    },
    `report-audit` = {
      source(paste(cars, "log_event('Observational teaching data: association does not establish causation', 'WARN')", sep = "\n"), "cars")
      dt("summary_stats", "cars", "audit_summary", cols = c("mpg", "wt", "hp"))
    }, stop("Missing example recipe: ", info$id))
  list(source = result, items = items)
}
