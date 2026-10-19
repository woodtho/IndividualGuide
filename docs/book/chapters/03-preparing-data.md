# Preparing and reshaping data {#preparing-data}

Data preparation should make a table's meaning clearer. A useful sequence is to inspect the original schema, identify the observational unit, preserve identifiers, handle duplicates/missing values deliberately, derive fields, and check the result. The app gives these operations separate tasks so each decision can be inspected and rerun.

Do not chain tasks only to make every row look complete. A complete-looking table can hide an invalid join, a recoding mistake or imputation that changes the distribution. Keep the raw source and an audit table; give transformed tables new names. The car-cleaning, reshaping and air-quality projects demonstrate this pattern.

## Append Table {#task-append_table}

Append stacks two or more tables **row-wise** using `dplyr::bind_rows()`. It is appropriate for combining the same kind of observations from several extracts or groups, not attaching columns by matching a key. Choose the input tables, an output name and, optionally, a source-ID column with readable labels for the contributing tables.

Columns are aligned by name. Missing columns in a contributing table are filled with missing values; compatible types are combined according to dplyr's rules. Incompatible column types can fail. A saved `fill` field is retained in the parameter schema, but the execution uses `bind_rows` semantics: do not rely on it as a strict schema-rejection switch.

Check that the resulting row count matches the sum you intended and that identifiers remain meaningful. If two extracts overlap, appending them preserves those overlapping rows; it does not deduplicate them. The Iris reshape example appends setosa and versicolor subsets to produce 100 observations. For monthly extracts, a source-ID column such as `extract_month` makes later investigation much easier.

## Compare Data {#task-compare_data}

Compare Data uses `waldo::compare()` to produce readable differences between two tables. Select table A and table B, and optionally choose key columns to sort both before comparison. The output is a comparison object, not a reconciled table or a database join.

Sorting by keys can remove uninteresting row-order differences, but it does not establish record matching when keys are duplicated. Class, column-order, attribute and value differences can remain relevant. Decide which differences matter for your contract before treating an empty comparison as sufficient validation.

Use it when replacing a transformation, checking a refreshed extract or round-tripping wide/long data. In the reshape project, compare the original and reconstructed flower measurements. The values may be equivalent while column order or representation differs; inspect the comparison instead of suppressing the evidence.

If you need a row-level exception dataset for downstream reporting, create one with an explicit join or Script. The comparison object is designed for inspection and can be included as printed report content or saved as an R object. It is not a tolerance-based numeric testing framework with a hidden configurable tolerance.

## Stack Columns {#task-stack_columns}

Stack Columns converts selected columns from **wide to long** with `tidyr::pivot_longer()`. Choose the input, the columns to stack and names for the new key/value fields. Other columns identify observations and remain available beside the stacked measurements.

For Iris, stack the four measurement columns into `measurement` and `length_cm`. With 150 flowers and four measurements per flower, the result has 600 rows. Add or preserve a flower identifier before pivoting when you will need to reconstruct the original rows. Species alone is not a unique flower identifier.

Selected values need compatible types. Pivoting a numeric measurement together with an unrelated character note can fail or create an unsuitable common representation. Keep semantically different fields separate. Missing measurements generally become rows with missing values rather than disappearing without a decision.

Long data is useful for grouped summaries, faceting and comparing distributions across measurement names. Verify both row count and identifiers. A 600-row table is not 600 independent flowers: each original flower contributes multiple measurements, which matters if you later fit a model.

## Split Columns {#task-split_columns}

Split Columns converts **long to wide** with `tidyr::pivot_wider()`. Choose the input, optional ID columns, the field supplying new column names and the field supplying their values. The ID fields define what one output row represents.

To reverse the Iris stack, identify rows with `Species` and `flower_id`, take names from `measurement` and values from `length_cm`. The intended result has one row per flower again. If you omit the individual identifier, different flowers can compete for the same species/measurement cell.

A single ID/name combination should normally identify one value. Duplicate combinations can create list-valued cells or warnings instead of the numeric scalar columns a later model expects. Aggregate explicitly before widening when multiple observations legitimately belong in one cell; do not assume Split Columns silently chooses a statistically appropriate summary.

Missing combinations can become missing cells. Compare the reconstructed table with the intended original, including classes and column order, before claiming a lossless round trip. Keep a long-form version when it is the natural analytical representation rather than widening solely for appearance.

## Transpose {#task-transpose}

Transpose swaps rows and columns using `t()`. Choose an input and, optionally, an ID column to provide the new column headers. The result is useful for small inspection tables or a matrix-oriented export; it is usually not the correct way to normalize a relational dataset.

A transposed matrix has one underlying type. Mixing numeric and character fields can coerce the whole result to character. Select only the intended numeric fields first if later calculations require numbers. Also examine the generated names when IDs are missing or duplicated; a label is not automatically a valid unique analytical key.

The reshape example deliberately transposes a small numeric subset rather than the full mixed Iris table. It lets you see the orientation change without obscuring the effect of Species or a string identifier on coercion.

Before running a large transpose, consider output width. A table with millions of rows would become an impractically wide result. Stack/Split Columns are generally better for moving between well-defined wide and long observational layouts.

## Rank {#task-rank}

Rank adds a named ranking field based on one selected column. Available methods are **minimum rank**, **dense rank**, **row number**, **percent rank** and **cumulative distribution**. Optional grouping calculates the ranking within each selected group.

Minimum rank leaves gaps after ties: values 10, 10, 20 receive ranks 1, 1, 3. Dense rank gives 1, 1, 2. Row number gives each row a position and therefore depends on tie order. Percent rank and cumulative distribution are related but different proportions; do not interchange them merely because both lie on a 0–1 scale in ordinary cases.

The configured column is ranked in its ordinary ascending value order. If “best” means largest, derive an appropriate ranking score or use an explicit expression/task design rather than assuming a Sort task changes the mathematical ranking direction. Sorting affects row presentation; ranking evaluates the column values.

The sampling project adds a dense fuel-economy rank. Check ties and missing values, and name the result field meaningfully, such as `mpg_rank`. Keep the original measure beside it so reviewers can see what the rank represents.

## Standardize Data {#task-standardize}

Standardize rescales selected numeric columns by **z-score** or **min-max** transformation. Optional group columns apply the transformation within each group. The selected columns are replaced with transformed values in the output table; preserve the raw input under its original name.

Z-scores use centering/scaling behavior from R's `scale()`. Min-max uses the observed range and maps an ordinary nonconstant column to 0–1; a constant column becomes zero under this implementation. Constant/all-missing columns require inspection, and z-score scaling of a constant column can produce nonfinite values. Standardization does not fill missing data or remove outliers automatically.

Use the sampling example to inspect the transformation of mpg, weight and horsepower. For a train/test modelling workflow, do not standardize the two partitions independently and call that the same transformation. Learn the transformation on the training data and apply those stored parameters deliberately, usually through a Script when that design is required.

Scaling can materially change clustering or PCA interpretation. Check whether the downstream method already scales internally; applying an additional transformation without a reason can obscure the units and intended analysis.

## Random Sample {#task-random_sample}

Random Sample draws rows by a requested **count** or **proportion**, with optional replacement and seed. Choose one input table and an output name. A fixed nonnegative integer seed makes a given sampling operation reproducible under the same relevant conditions.

Without replacement, requesting more rows than available follows the underlying row-sampling behavior rather than creating new observations. Proportions and replacement can produce results that differ from an intuitive “exactly this percentage rounded up” expectation; inspect the actual row count. A random sample is not automatically stratified, balanced or suitable for every study design.

The sampling project requests ten rows with seed 2026 after ranking and scaling the car data. Rerun it and compare retained rows. Changing data order, seed or input content can change which rows are drawn even when the requested count stays ten.

Use a persistent identifier to track selected records. Row position alone becomes ambiguous after filtering and sorting. If your design requires group-stratified sampling or independent simulation streams, implement that design explicitly rather than inferring it from the presence of a generic seed box.

## Remove Duplicates {#task-remove_dups}

Remove Duplicates uses distinct-row logic. Choose **all columns** for whole-row duplicates, or selected key columns when duplicates mean repeated keys. For a key-based choice, the first retained row supplies the other columns.

That “first row wins” rule is a data decision. If the same customer ID has two addresses, removing one does not prove which address is correct. Sort deliberately if the first row is meant to be the latest or preferred record, and keep an exception/audit table when conflicting duplicates need investigation.

In the car-cleaning project, the source adds a deliberate duplicate of the first car, giving 33 input rows. Whole-row deduplication restores 32 rows without choosing between conflicting measurements. This is a clear teaching case; a production key conflict may require more work.

Compare counts before/after, inspect which key combinations were repeated and preserve the original source. Deduplicating after a many-to-many join can hide row multiplication rather than repair its cause. Check the join's key relationship first.

## Keep / Drop Columns {#task-keep_drop_cols}

This task selects a set of columns to keep or drop. Choose the input, the action and the column names, then retain the result under a new table name. Keeping a known analysis schema makes dependencies easier to understand and can reduce the amount of data passed to models or reports.

Dropping an identifier too early can make later joins, comparisons and audit checks difficult. Retain fields that explain the unit of observation and source lineage even if they are not predictors. Conversely, do not pass irrelevant text or sensitive fields to a public report just because they are present in the raw input.

The car-cleaning project keeps car name, mpg, weight, horsepower and transmission before renaming and deriving fields. Inspect the resulting column order as well as membership; downstream scripts that use position-based indexing can be fragile when order changes.

An empty selection and missing column references are not a useful schema specification. Choose the intended action explicitly and inspect Preview/Results. For dynamically evolving files, a Script may express a deliberate tolerant selection, but that tolerance should be visible rather than assumed in this task.

## Rename Columns {#task-rename_cols}

Rename Columns takes old-to-new pairs. Select each existing field and enter its replacement name. The output preserves values while changing the schema, so downstream configuration must use the new names.

Prefer names that preserve meaning and units: `weight_1000lb` is clearer than an unexplained `weight` when the source `wt` is measured in thousands of pounds. Avoid duplicate replacement names. Keep original names in a task note when they are needed to relate back to a source specification.

The car-cleaning project renames `wt` before deriving horsepower per 1,000 pounds. That sequence demonstrates a schema contract: the next task refers to `weight_1000lb`, not the old `wt`. A task label change would not perform this column rename.

Renaming is not type conversion, recoding or unit conversion. Changing `temperature_f` to `temperature_c` without calculating the conversion would mislabel the data. Use Derive Columns for the calculation and name the resulting field accordingly.

## First / Last N Rows {#task-first_last_n}

Choose first or last and a row count to retain a short subset. This task uses row order, so establish the ordering with Filter and Sort when order has analytical meaning. “First five” is not a random sample or “five best” unless you deliberately made it so.

Use it for a visible spot check, a small export or an ordered tail of a chronological dataset. In the car-cleaning example it produces a five-row inspection table while retaining the complete analysis table separately.

A table imported from a database may not have an inherent stable order. Even if a preview appears sorted today, use an explicit sort before selecting a head/tail subset that must be reproducible. Include a secondary tie-break key when several rows share the primary ordering field.

Do not confuse this retained subset with the result preview's page length. A page-length setting changes how many rows appear on a page, not how many rows a task analyses. First/Last N actually changes the output dataset.

## Replace Missing Values {#task-replace_missing}

Select columns, a replacement method and an output name. Methods are a **fixed value**, **mean**, **median** or **mode**. Leaving columns blank selects all columns under the saved configuration, but only type-compatible operations make sense.

Mean/median apply to numeric columns and leave unsuitable or entirely unobserved columns unchanged in this implementation. Fixed replacements are converted according to the target class, including numeric, logical, Date and factor handling; an invalid replacement is an error. A factor can gain the replacement as a new level. Mode ties follow the implementation's deterministic sorted-value choice rather than a statistical model of missingness.

The air-quality example audits missing values first, preserves the raw table, and demonstrates mean imputation on Ozone and Solar.R. This is an illustration, not a default analytical recommendation. Filling values changes distributions and can distort uncertainty and relationships.

Check the missing count afterwards. “The task ran” does not mean every column became complete, particularly an all-missing numeric field. Record which columns were changed and why. For a defensible analysis, choose a missing-data strategy appropriate to the data-generating process and the intended inference.

## Recode Values {#task-recode_values}

Choose a source column, a new output-column name and explicit from/to rules. An optional else value handles unmatched entries. A rule whose source is the supported missing-value sentinel can map missing observations. The recoded column is **character**, including when the original column was numeric.

This character-space behavior avoids pretending that strings such as “Manual” belong in a numeric vector. If a model needs a factor or a numeric 0/1 response, follow with Change Column Types or a deliberate Derive/Script operation. Retain the original field to check the mapping.

The car-cleaning project maps transmission code 0 to Automatic and 1 to Manual, then converts the label field to factor. Check a cross-tabulation of original and recoded values. Unexpected categories should be investigated rather than silently folded into an overly broad else label.

Keep rule sources unambiguous. A literal category that looks like a missing sentinel needs special care because the task treats its documented sentinel as missingness. For extensive versioned code lists, a validated lookup join is often easier to maintain than a very long manual rule table.

## Change Column Types {#task-change_types}

Add conversion rows specifying a column and one of numeric, integer, character, logical, factor or Date. Conversions change representation; they do not decide what a category ought to mean. Inspect values and missing counts after converting.

Numeric conversion of character text can produce missing values for nonnumeric entries. Factor-to-numeric handling uses the represented values rather than blindly treating internal level codes as measurements. Logical conversion uses logical text handling; a business code such as Y/N may require recoding first.

Date conversion recognizes several common ISO, slash, dash, dotted and compact patterns. Its parser infers a usable format from observed text rather than negotiating every ambiguous date independently. A mixed-format column or ambiguous `03/04/2026` can therefore need an explicit Script/reader format. Validate known dates near month/day boundaries.

The cleaning project converts transmission labels to factor after recoding. That prepares an explanatory category for models and summaries. It does not establish the correct reference level for every intended model; inspect factor levels and model terms when interpretation depends on them.

## Quality checks after preparation

Use Characterize Data to inspect classes, missingness and distinct values. Use Summary Statistics for numerical ranges. Use One-Way Frequencies or Table Analysis to check recodes and categories. Use Compare Data when refactoring a workflow. Log important exclusions or thresholds with a Script so a report can explain what happened.

Finally, check the unit of observation. After stacking columns, repeated measurements from one person are not independent people. After an append, overlapping extracts may contain repeated records. After a join, key multiplicity can multiply contributions. Task success cannot resolve those conceptual questions for you.
