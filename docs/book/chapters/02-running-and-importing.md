# Running work and understanding state {#running}

A project stores a definition of work and, when work has run, its retained results. Configuring a task, previewing it, committing its outputs, saving the project and writing an external file are separate operations. Understanding these boundaries prevents many apparently mysterious “old result” problems.

## Single tasks, previews and flows

The common header Run action executes a task with its current synchronized settings. Transformation tasks may also expose Preview and Run & Save. Preview is useful for inspecting a proposed transformation without replacing its retained output. It still performs the calculation; it is not a free estimate or a guarantee that arbitrary user code cannot have external side effects.

Run Flow schedules the active flow's tasks in dependency order. Producers run before consumers even if they were added later. Tasks with unopened panels use saved parameters. The queue reports the current task, completed/total count, elapsed time and final outcome.

A selected partial run must have the inputs it needs. Run to here includes prerequisites; Run from here includes descendants. Running only a consumer does not promise to refresh every external data source automatically. If it uses a successful cached input produced yesterday, decide whether that input is still appropriate before interpreting a fresh output as “today's analysis.”

Cross-flow dependencies mean a table can be visible outside the flow that creates it. They do not mean that starting one active flow automatically becomes a project-wide scheduler that refreshes every other flow. Run prerequisite producers or use the relevant dependency-oriented action when freshness requires them.

## Validation before execution

The Validate active flow command examines configuration without running Script code or contacting databases. It can detect missing files, missing/duplicate output names, invalid dependency structure, unparseable R, some missing columns and unwritable/existing export destinations. Its messages identify the task and field and can link back to the task panel.

Validation has deliberate limits. An upstream task that will rerun may produce a new schema, so checks against its old cached columns would be misleading; those cases are checked during execution. A database's permissions, live schema and connectivity require a real connection. A syntactically valid R expression can still fail at runtime or calculate the wrong thing. “No configuration problems found” is not proof that a model is suitable or that a future external write will succeed.

Use validation when preparing a handoff, before a long run and after changing input paths or output names. Treat warnings as information to resolve deliberately. For example, a file path containing a Loop placeholder can be valid even though the final per-iteration path does not yet exist at validation time.

## Statuses and stale results

| State or indication | Meaning and next action |
| --- | --- |
| Not run/pending | A configured task has no current committed execution; run it after its inputs are ready |
| Running | The task or its worker is computing; avoid replacing its project/inputs |
| Waiting | Work is queued or waiting for required runtime state; inspect the current run rather than launching duplicates |
| Success | The most recent execution completed; inspect its output and any warnings |
| Error | Execution failed; read the stored message and task log, then correct the cause |
| Skipped | A control path or unavailable prerequisite prevented execution; this is not necessarily an error |
| Stale/invalidated | Settings or upstream results changed, so retained downstream results need recomputation |

Staleness propagates through dependencies. Changing an upstream value should make the consequences visible rather than leave an apparently current downstream report. The canvas and header explain what is outdated. Repeatedly opening a result panel is not a recalculation; rerun the appropriate tasks.

A warning can coexist with success. For example, a model may converge with a warning, or a Report task may skip an item that has no computed value. Inspect warnings and retained log events before accepting the result. Success means execution met its implementation's success conditions, not that every analytical assumption has been established.

## Failure policy and Stop

Settings includes **Stop Run Flow at first failing task**. Its default is false. With fail-fast disabled, the queue can continue where dependencies permit and mark unavailable paths appropriately. With fail-fast enabled, a failure stops the remaining queue. The final log export may then need to be run manually.

Export Log has special handling so selected failed tasks do not inherently prevent collecting their logs. That does not override a flow-level decision that has already stopped scheduling all remaining tasks. It is useful precisely because you can run it after a failure to preserve evidence.

Stop ends background analysis workers and abandons queued work. A synchronous operation running inside the Shiny R process must reach a point where the server can handle Stop; a long native call may keep the interface busy until that call returns. Completed work and already performed external writes remain. Stop is not a transaction rollback for a folder full of exported files or a database mutation.

Restart R server belongs to the standalone desktop shell and is a stronger intervention. It stops the backend process and starts a fresh one, including when the old server cannot respond. Save first when possible. Reopen a saved project or recover the latest available snapshot afterwards. The R Console's Stop/Reset controls affect its separate console process, not the same thing as restarting the app server.

## Background execution

Supported tasks run in isolated child R processes when background execution is enabled. The app can remain responsive while the worker calculates, then applies the returned result to the project. Worker reuse avoids repeatedly loading the same runtime for ordinary subsequent tasks.

Not everything can cross a process boundary. Live database connections, process-local handles and environments may require a compatible synchronous route or materialization. A Script that returns an environment or connection cannot be treated like a plain data frame. Loop execution also checks whether results can be transferred. The purpose is to preserve correct state, not to promise every arbitrary R program can run in a worker.

Background execution is a project setting. If a task needs a process-local object, inspect its inputs/results and the reported limitation. Materialize a table, return an ordinary serialized object or disable background tasks for that workflow when the supported synchronous route is appropriate. Do not disable it globally as a first response to every model warning.

## Randomness and reproducibility

Random Sample has its own explicit seed. Clustering has a seed for k-means initialization. Settings also provides an optional project random seed. Configured seeds are recorded and preserved in generated pipeline exports, along with the RNG kind, model contrasts and missing-value option.

A fixed seed helps reproduce stochastic operations given the same data, ordering, code, packages and relevant options. It does not freeze an external database or guarantee identical results across every version of a numerical library. A Script can explicitly set its own seed. Record that choice near the code rather than relying on an accidental prior console command.

The project seed is applied for task execution and loop bodies, not presented as one continuous, unmanaged stream that silently depends on every earlier interactive action. For independent simulation replications, choose a deliberate per-iteration seed strategy in the Script and document it. The run-record chapter explains which settings and fingerprints you can compare afterwards.

# Importing files and database data {#importing}

Import is a normal pipeline task. It can be configured, rerun, saved, logged and used as the producer of downstream data. A source table with a clear name makes refresh behavior visible. If you instead read a file inside an unrelated Script without declaring its relationships, the app cannot infer every hidden dependency from arbitrary code.

## Import Data reference {#task-import_data}

Choose Import Data from Data. Set an output name, choose **File** or **Database** as the source kind and configure the reader/connection. Run the task and inspect both its dimensions and column classes before building analyses on top of it.

Supported local readers include CSV, Excel `.xlsx`/`.xls`, RDS, RData `.rda`, SAS `.sas7bdat`, Stata `.dta` and SPSS `.sav`. Reader-specific settings matter: a file extension does not tell the application whether a comma is a decimal separator, which Excel sheet contains observations or how a missing-value marker was encoded. The parameter appendix records every saved reader field.

Use the **US states - import, join and filter** example for a real CSV import with a regional lookup. Its CSV is bundled in the portable example archive. For a missing-file problem, use Project files/relinking rather than changing a random downstream filter.

## Delimited text: establish the schema

CSV options include delimiter, column names, skipped lines, missing-value markers, quote/escape behavior, comments, whitespace trimming, locale, column types/selection, identifier, name repair, guessing limits, threading, lazy reading and maximum rows where the reader exposes them. Blank/automatic choices delegate to the reader's behavior; they are not all literal empty strings passed blindly to every underlying function.

Start with a small inspection. Check that a header row became names rather than data, that rows did not collapse into one long string column, and that identifiers such as postal codes retained leading zeroes. Check dates and decimal marks explicitly. If only the first few rows were used to guess types, a later exceptional value can reveal a bad guess.

`NA` is a missing value; the text `"NA"` can be either a literal category or a marker configured as missing. Empty strings may also have domain meaning. Choose reader missing markers according to the data contract rather than treating all visually empty cells as equivalent.

If a file has metadata lines before its header, use Skip deliberately. If it has a nonstandard delimiter, select that delimiter. If its encoding/locale differs, set the appropriate reader option. Reimport after changing the reader and inspect the resulting table; a column conversion downstream cannot repair rows that were parsed into the wrong columns in the first place.

For a reproducible schema, use explicit column types and document them. This is especially useful when a field sometimes contains only numeric-looking values but is conceptually an identifier. Record the original file's provenance in a task note or project comment.

## Excel and serialized R data

For Excel, select the sheet or range containing the intended table. Options include names, types, skipped rows, missing markers, trimming, name repair, guessing limits and row limits. A worksheet used for human presentation may contain merged headings, notes and totals that do not form a rectangular analysis table. Restrict the range or clean a deliberately imported region before analysis.

RDS stores one R value. RData can hold named values, so choose the object to import when needed. These formats preserve R structures better than plain text, but they also depend on the classes and namespaces needed to use the stored value. For tabular interchange with non-R tools, choose an appropriate exported table format instead.

SAS, Stata and SPSS readers may retain labelled values and special missing-value semantics. Inspect classes and labels. Converting a labelled variable directly to numeric or factor can change its analytical meaning; document the decision. The app preserves R classes in its project storage where supported rather than deliberately flattening every value into a string.

## Database connections

The Database route supports ODBC/DSN-style configuration and custom DBI connection code, with SQLite/DuckDB available in the packaged runtime. Typical connection fields include a driver/DSN, host, port, database, user, schema and table. Different drivers interpret these fields differently; supply the connection information required by your database.

Passwords supplied through the supported password workflow are session-only and requested again when necessary. Reusable connection settings can be kept in the connection catalogue. The catalogue saves configuration, not a portable authenticated session. Custom connection code is arbitrary R code; use session/environment credential retrieval rather than embedding secret literals in a saved project or exported script.

Import can retain a **lazy** database table or collect the table into memory immediately. A lazy value lets supported dplyr/dbplyr operations become SQL and execute in the database. Collecting creates a local materialized table. The right choice depends on data size, available memory, server capabilities and which downstream tasks you need.

Query Builder and Script can receive a lazy table where appropriate. Many analysis tasks need in-memory values and collect required inputs before computing. Plan for the transfer: selecting/filtering in Query Builder before a local model can be much cheaper than importing a full remote table first.

On reopening a project, re-establish live imports. Materialized results may be retained, but their existence does not prove the remote source has not changed. A fingerprint of a lazy query can describe its query text without snapshotting every row in the database. The run-record chapter makes that distinction explicit.

## Refreshing without losing the original story

Re-running an Import task refreshes its output and can invalidate consumers. If a source changes column names or types, inspect the new schema before running the rest of the flow. If the refresh represents a different extract period or data definition, add a note rather than silently reusing a title that implies the old period.

Keep unmodified imports under names such as `orders_raw`. Use new names for cleaned/filtered outputs. That design makes comparison and recovery easier, and helps reviewers identify which step introduced a change. It also avoids the ambiguity of several tasks all trying to produce a table named `data`.

# Queries, filters and expressions {#queries}

Query Builder combines column selection, computed fields, joins, filters, aggregation and sorting. Filter and Sort is a smaller operation when you only need rows in a different order. Derive Columns adds expressions without the other query stages. Choosing the smallest task that clearly communicates your intent makes a pipeline easier to review.

## Query Builder reference {#task-query_builder}

Choose a primary table and a unique output name. Add joined tables if required, then configure computed columns, row filters, selected output columns/aliases, aggregate functions, HAVING conditions and sorting. Distinct removes duplicate output rows according to the configured query result.

The selected-column list supports aliases and aggregate functions. Available aggregations include COUNT, COUNT DISTINCT, SUM, AVG, MIN, MAX, MEDIAN, standard deviation, variance and a custom expression. Selecting an aggregate makes the remaining appropriate nonaggregate selections grouping fields. An alias names a result column; it is not a replacement for establishing the correct grouping level.

The result is a table. Generated R expresses the operation as a dplyr pipeline. For lazy database inputs, supported expressions can translate into SQL; operations a database backend cannot translate may need a different expression or explicit materialization. Inspect generated code and the actual result, not just whether the UI accepted a field.

Use the **US states - import, join and filter** example to inspect an actual left join on state name. Use a scratch copy to change its income threshold and sorting. Before trusting a joined analysis, check row counts and missing lookup values.

## Filter and Sort reference {#task-filter_sort}

Choose one input table, build row conditions and add sort keys in priority order. Conditions offer type-aware comparisons, ranges, membership, pattern matching and missing-value checks. Adjacent conditions have AND/OR connectors. Choose ascending or descending for each sort column and name the output.

The task does not join tables, select a new grouped summary or invent a stable ordering for tied rows. If your next step takes First N, define enough sort keys to make the subset meaningful. If mixed AND/OR logic becomes difficult to read, inspect the generated expression: the conjunctions are rendered in sequence, and R's ordinary operator precedence matters. Use separate filtering steps or a deliberate expression when you need unmistakable grouping.

The states example keeps high-income observations and sorts Income descending. The Puromycin example filters the treated group before fitting its curve. These demonstrate two different uses: business thresholds and selecting the population for an analysis.

## Type-aware comparisons and missing values

`=` in the filter interface means equality; generated R uses `==`. Use numeric thresholds for numeric columns and literal text values for character categories. The reader/class establishes which operators and quoting are appropriate.

BETWEEN supplies lower and upper endpoints; IN compares against a list of values. LIKE follows the app's pattern translation, where SQL-style wildcards are converted for matching. IS NULL and IS NOT NULL explicitly test missingness. An ordinary comparison to a missing value does not behave like comparing two known numbers; use missing-value operators when missingness is the question.

For several rules, write down the intended logic in words first. “North or South, and positive quantity” needs grouping; it should not accidentally mean “North, or South with positive quantity.” A quick count by region before and after filtering helps expose such errors.

## Joins and row multiplication

The join types include left, inner, right, full and cross. Choose left/right key columns that represent the same concept and have compatible types. A left join retains the left table's rows and attaches matching right-side values. An inner join retains matched combinations. A full join retains unmatched rows from both sides. A cross join deliberately forms combinations and can expand row counts dramatically.

Keys need not be unique, but duplicate keys can multiply rows. If one order matches two customer records, joining can double that order's contribution to a later sum. Count rows and inspect key uniqueness before/after joining. Remove Duplicates is not automatically a valid repair: selecting the first conflicting lookup record may conceal a data-quality issue.

Use an explicit lookup table when recoding many values through a data contract. Use Recode Values for a short visible mapping. Use Compare Data to inspect whether a refactored query changed the retained dataset. These are complementary tools, not interchangeable substitutes for a validated join.

## Aggregation and HAVING

Row filters act before aggregation. HAVING acts on the aggregated query. For example, filtering sales rows to a date range, grouping by region and retaining regions whose total exceeds a threshold is different from retaining individual rows above that threshold and then summing them.

Always state the output's unit of observation: one row per transaction, per customer, per region-month or per category. Select only grouping fields that belong at that level. Adding an otherwise harmless-looking detail column can split a group and change every total.

Null/missing handling can differ between a database and in-memory R. Review results for groups containing missing measurements. COUNT rows and COUNT nonmissing values answer different questions. The selected aggregate's generated code and backend behavior determine what is actually counted.

## Computed expressions

Query computed fields and Derive Columns accept R expressions, not spreadsheet formulas with an implied current cell. A column name is a vector. `hp / wt` calculates one value per row. `mean(hp)` calculates a summary and may be recycled across rows in a mutate-style expression. Those are different intentions.

For a name containing spaces, use R backticks when writing an expression: `` `Total cost` / units ``. Quote character literals: `if_else(region == "North", 1, 0)`. Use explicit package qualification when a function is not among the helpers available in the task environment. A database-backed query also needs an expression the backend can translate, or a deliberate local calculation after collection.

Query Builder also exposes **Libraries for computed columns**, a comma-separated list of installed R packages made available to its expression workflow and carried into generated code. Listing a package does not install it or make all its functions translatable to database SQL. Record required libraries and test the query in the environment where it will run.

The interface cannot turn arbitrary R expressions into safe, reversible arithmetic. Expressions can call functions with external effects. Use them as small transformations, and move complex multi-stage logic into a Script task with declared inputs and outputs.

## Derive Columns reference {#task-derive_cols}

Choose an input table and add named expression rows. Each row supplies the output column name and its R expression. The task uses mutate-style evaluation with existing columns and exposed dplyr, tidyr, lubridate, stats and utility helpers. Expressions can create or replace columns, so prefer new names when preserving the original matters.

Examples include `hp / weight_1000lb`, a date-derived year, a conditional flag or a lagged measurement. Results must have compatible lengths and types. Division by zero can produce infinite values; an apparently successful derivation may still need a data-quality check before a model consumes it.

In the car-cleaning example, `hp_per_1000lb` is derived after renaming weight. Follow that sequence: using a column's old name after it has been renamed is a configuration error. Run Characterize/Summary Statistics on the derived table to check missing and nonfinite values, and add a task note explaining the units.

# Script tasks and analytical code {#scripts}

The Script task is the bridge from configured forms to general R. It belongs in the pipeline when a calculation must be retained, rerun, logged and consumed by another task. The R Console is better for temporary exploration. You can promote suitable console code into a Script, then review the declarations before relying on it.

## Script reference {#task-script}

Declare input tables/objects that the task reads. They establish scheduling dependencies and become named values available to the script. Enter R code and declare each output with a name and kind. Supported declarations cover table, model, plot, image, object and automatic detection. Multiple outputs let one script produce both an audit table and a transformed dataset.

For example, use a task with input `orders_raw` and two declared table outputs:

```r
missing_audit <- data.frame(
  column = names(orders_raw),
  missing = vapply(orders_raw, function(x) sum(is.na(x)), integer(1))
)
orders_valid <- subset(orders_raw, !is.na(order_id))
log_event(sprintf("Kept %d of %d orders",
                  nrow(orders_valid), nrow(orders_raw)), "INFO")
```

The output declarations must include `missing_audit` and `orders_valid`. A local temporary variable is not automatically a retained project output. Conversely, a declared name that the script never creates is an error to fix, not a reason to trust a previous cached result.

## Explicit dependencies

All available flow values can be accessible to Script execution, but undeclared reads make the dependency diagram incomplete. If the code uses `sales_monthly`, declare it as an input rather than relying on a value that happens to be left in the project. Declaration makes run ordering and invalidation understandable to both the application and a reviewer.

Avoid creating the same retained output name from more than one task. If you need several versions, use names such as `scores_raw`, `scores_centered` and `scores_final`. Use the task label and note to explain why each version exists.

Scripts in a Loop receive the configured loop variable and, for applicable iteration types, `.loop_data`. Those values come from control context, so wire the task to the loop's path token as well as its ordinary data inputs. Merely mentioning `item` in code does not put a task inside a loop.

## Messages and logging

Use `log_event("message", "INFO")` for an explicit retained task event. Levels are DEBUG, INFO, WARN and ERROR. Logging an ERROR-level message is a severity choice; it is not automatically the same as calling `stop()` to fail the calculation. Use `stop()` when execution must fail.

Printed console output, messages and warnings can be captured according to task logging configuration. Printing a huge table may create unnecessary text and makes an audit harder to read. Log useful counts and decisions instead: rows read, rows excluded, selected period, imputation method or a failed quality threshold.

`warning()` and a logged WARN event serve different purposes. A real R warning can indicate a numerical or data issue raised during computation. A custom logged warning can record a deliberate caution without pretending a calculation failed. Inspect both when reviewing success.

## Working directory, packages and side effects

A Script is real R code. Filesystem calls access the machine's files; database writes can change an external database. Preview/recovery/project rollback cannot reverse every side effect. For reproducible work, separate input reads, calculations and external export operations when practical.

Use explicit or carefully managed relative paths. Record the expected working directory in a task note or generated-code handoff. Package names and versions matter; an arbitrary `library()` call can require a package absent from the reduced desktop runtime. A source R installation can manage additional packages, while a packaged runtime must have the required dependency available.

Return materialized data frames and serializable values when using background workers. A connection, external pointer or environment may not be transferable. If a specialized package returns a process-local object, inspect the supported execution route and decide whether a plain summary table would be a better retained output.

## Turning a script into maintainable work

Keep a script focused enough that its label describes its purpose. Use intermediate variables within a task when they belong to one logical calculation, and split tasks where results need inspection, reuse or independent rerunning. Add comments explaining decisions and units rather than narrating every assignment.

After editing, run the Script, inspect declared outputs and rerun downstream consumers. Save the project to retain the code even if the script is temporarily unrun. Export the full pipeline when you need a standalone execution artifact; copying one Script does not automatically carry every upstream table or dependency with it.
