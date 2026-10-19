# Branches, loops and conditional pipelines {#control-flow}

Data arrows say which values a task needs. Control paths say whether a task should run and, for a loop, in which iteration context. A path token is not an ordinary dataset to inspect as rows and columns. It is a declared control output selected by downstream tasks.

Start with a small working flow before adding controls. Make the ordinary calculation succeed on one input, then add the branch or loop, its path token and the correct downstream wiring. Test both the intended path and the alternative. Preserve external destinations carefully: repeating an export to the same filename with Overwrite on can deliberately leave only the last iteration's file.

## Branch reference {#task-branch}

Configure the input dependencies the branch reads and define named paths. Each path has a label, unique token and condition. At most one path can be Else. Ordinary paths are evaluated independently: **more than one path can match**. Else activates only when no ordinary path matches, not simply because the preceding path was false.

Conditions can test row count, whether a column contains a matching value, another task's status/validation result, a saved task parameter or a custom R expression. Structured conditions combine rules/groups with AND/OR. Custom conditions must evaluate to a single nonmissing TRUE/FALSE, not an uncollapsed logical vector.

Wire a consumer through its **Run after branch/loop path** selector. Keep its normal data inputs as well. Selecting only the data table means the task is a data consumer, not necessarily part of a conditional branch. Nonmatching paths are marked skipped with explanations; they should not pretend to be failed calculations.

The flower quality-gate example checks for at least 100 rows before its summary path. With Iris's 150 observations, that path activates. Change the threshold in a saved copy to explore the alternative and inspect its log/state. The branch decision itself is not a data-cleaning operation and does not remove rows from `flowers`.

## Branch conditions in detail

| Condition kind | What it tests | Practical check |
| --- | --- | --- |
| Row count | A table's `nrow` against a value | Confirm the table is the intended pre/post-filter dataset |
| Column value | Whether any row satisfies a comparison | “Any” does not mean every observation passes |
| Task status | A task's current status | Use the task ID and ensure the dependency is meaningful |
| Validation result | The configured task-state comparison | This is not an automatic execution of every possible quality test |
| Parameter value | A saved field on a referenced task | A parameter is configuration, not necessarily a computed statistic |
| Custom R | One logical result from the supplied expression | Collapse vectors with `all`, `any` or another deliberate rule |

For a custom condition such as `all(!is.na(sales$amount))`, consider the empty-table case: `all(logical(0))` is true in R. If emptiness must fail, include an explicit row-count condition. For a threshold expression, quote character literals and use the correct column types.

The branch environment contains declared project values and supported helpers, but it is still evaluating R code. Do not assume a custom expression is a harmless spreadsheet condition. Keep conditions focused on decisions, with ordinary transformations in their own tasks.

Multiple control prerequisites can create subtle designs. Inspect the generated pipeline and test the actual dependency selection rather than assuming token names joined in a selector imply a particular natural-language OR. For a clear mutually exclusive design, make your branch conditions mutually exclusive and keep the path wiring simple.

## Loop reference {#task-loop}

Loop defines an iteration source, a loop-variable name, a path token and an output naming rule. Supported iteration types are files, datasets, groups, parameter lists, date ranges and database-query results. Preview loop validates/materializes the iteration description; the full flow executes the dependent body for each iteration.

Attach body tasks to the loop token and their required data. The loop repeats its dependent subgraph, including supported nested controls. It retains named iteration results and makes the last successful template values available under ordinary output names for previews/compatibility.

Naming placeholders are `{task}`, `{item}`, `{index}` and `{output}`. Repeated or sanitized labels can collide. Include `{index}` or `{output}` when necessary; the loop checks planned output names against one another and reserved project values. A valid preview does not excuse a later output collision.

The species example groups Iris by Species, sets the variable `species`, and repeats a Script returning one summary row. It retains `species_summary_1`, `_2` and `_3`, each with 50 observations summarized. Logs carry iteration context. Its report outside the loop summarizes the full input and execution history rather than accidentally becoming a per-species report body.

## Six iteration sources

**Parameter list.** Enter nonblank values one per line. The loop variable receives the value as represented by the iteration source, commonly a string. Convert deliberately in Script if it represents a number or another type. For a simulation threshold, `as.numeric(item)` is clearer than relying on implicit conversion in a comparison.

**Files.** Enter paths or file patterns, one per line. Matching files become iteration values. A missing pattern is an error rather than a silent successful empty run. Use the loop variable in Script or supported `{item}` substitution for a downstream Import path. Preview the matches to avoid accidentally processing an archive, output directory or the same data twice.

**Datasets.** Available source tables define the iterations. Applicable data are available as `.loop_data`; the iteration value identifies the table. The loop excludes its own prior body results from the source selection so a rerun does not recursively expand over its previous outputs. Check source membership when several unrelated tables are present.

**Groups.** Choose a source table and group column. Each unique value defines a record and subset, including supported missing-group handling. Scripts receive the configured variable and `.loop_data`; the source-table alias can be replaced with the current subset inside the body. This is why the species Script can calculate `nrow(flowers)` and obtain 50 rather than 150.

**Date ranges.** Enter one ISO date or `YYYY-MM-DD/YYYY-MM-DD` range per line. The parser validates actual dates and range order. A single date becomes a Date value; a range supplies start/end values in the iteration record. The task does not invent a monthly calendar from an unspecified interval string; enumerate the intended ranges and preview them.

**Database query results.** This iterates rows of an available query-result/source dataset, optionally taking a selected value column; row data are also supplied as context. Materialize/prepare that source with a database Import/Query task as required. A list of strings in the fallback configuration is not proof that the loop has executed arbitrary SQL against a server. The dataset/query source establishes the actual rows.

## Substitution and context

Supported scalar settings can use `{item}` and `{index}` substitutions, such as per-iteration filenames. The raw Script code/expression fields are not blindly text-rewritten with those placeholders. Use the loop variable in R code instead:

```r
threshold <- as.numeric(item)
selected <- subset(observations, value >= threshold)
log_event(sprintf("Threshold %s retained %d rows", item, nrow(selected)))
```

For a group loop, use `.loop_data` or the subset source alias. A loop variable name must be a valid R variable name. Choose something meaningful (`species`, `month`, `input_file`) rather than reusing a project output name that would obscure the context.

An output naming rule concerns retained project objects. An external Export path needs its own per-iteration destination strategy. For example, a filename containing `{index}` avoids overwriting all prior iteration files. Inspect both the planned object names and the resolved file paths before a long run.

## Failures, logs and nested work

The loop records iteration outcomes and log events. A failed body task may stop further work according to the configured failure policy. Retained successful iteration outputs and completed external writes are not rolled back simply because a later iteration fails.

A final Export Log task that waits for the loop/body can collect iteration-aware events without itself becoming part of every iteration. Explicitly wiring a log export onto the loop token instead gives a per-iteration log-export design. Choose based on the artifact you want, and use distinct paths for distinct files.

Nested loops can create a large amount of work. Estimate outer × inner iteration counts and the size of retained results. Test two or three small iterations, inspect names and logs, then expand. Use the generated full pipeline to understand repeated bodies; the Loop task's standalone preview snippet describes its iteration source, while full-flow export supplies the actual body execution.
