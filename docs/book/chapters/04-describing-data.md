# Describing a dataset before modelling {#describing-data}

Description establishes what was actually imported and transformed. Start with structure and counts, then examine distributions and relationships. A model output can look precise even when an identifier was read as a number or a missing-value code was treated as an observation.

The **Tooth growth - descriptive analysis** example exercises every Describe task. It has 60 observations, supplement categories and dose groups, and preserves the variables used in its summaries. The source converts dose to factor for categorical comparisons. Read that preparation before interpreting an analysis that treats the same numeric-looking dose as continuous.

## Characterize Data {#task-characterize}

Choose an input table and an output name. Characterize produces a structured profile of its columns: type, row count, missing count and proportion, distinct values and examples. It is a useful first task after an unfamiliar import or schema-changing transformation.

Read the profile as a schema audit. A field expected to be an identifier should not have lost leading zeroes. A factor with unexpected levels can reveal a recoding/import issue. A numeric variable with only one distinct observed value will not be useful for ordinary standardization or regression in the same way as a varying predictor.

The profile summarizes columns; it does not validate every domain rule or detect every impossible combination of fields. An age range may look plausible while two date fields contradict each other. Add explicit quality checks in Derive/Script tasks when those rules matter.

Retain a characterization of both raw and cleaned data when changes are substantial. Put the relevant profile or an audit subset in a report, and use meaningful headings such as “Post-import schema” rather than leaving readers to infer when it was calculated.

## List Data {#task-list_data}

List Data opens a searchable, sortable table view with per-column filters. It is an inspection task, not a transformation. It can optionally retain a copy under an output name; persistent output is off by default in its constructor.

The page length controls presentation. Searching, sorting and paging in a viewer should not be confused with defining a new pipeline table. If the next task needs the subset you inspected, configure Filter and Sort or Query Builder and commit that result explicitly.

Use the descriptive example to inspect tooth-growth observations and the categories behind its summaries. Check a few rows from each group, not just the first page. If a variable looks truncated by formatting, inspect its underlying type/value before treating a display convention as data loss.

A copy made by List Data has the same analytical content unless another operation changes it. Giving it a new name can be useful for demonstration, but it should not imply that validation or cleaning has occurred. For a large table, the view may still require data retrieval/materialization; ten visible rows is not proof that only ten rows were accessed.

## One-Way Frequencies {#task-one_way_freq}

Select one variable and choose whether to sort by descending count. The result includes category counts, percentages and cumulative percentages. Missing observations are counted as a separate level when present.

The denominator includes the counted missing level, so compare the percentage definition with your reporting convention. A report that wants percentages among observed values must explicitly implement that alternative rather than relabel the default output. Cumulative percentages follow the displayed order, which may be frequency order rather than an ordinal scale.

Use it for transmission labels after recoding, supplement groups or a data-quality flag. In a balanced ToothGrowth design, the supplement categories have equal counts. That balance is a property of the design, not evidence of an estimated population prevalence.

High-cardinality numeric values and identifiers can generate long frequency tables that obscure the question. Use bins, summaries or a histogram when the purpose is a numeric distribution. If categories that should match appear separately, inspect whitespace, case and import/recoding choices before manually combining them.

## Summary Statistics {#task-summary_stats}

Choose numeric columns, or leave the selection blank to summarize available numeric columns. The output has one row per summarized variable with nonmissing/missing counts, mean, sample standard deviation, minimum, quartiles, median, maximum and a skewness calculation. Numeric results are rounded for the summary output as implemented.

Read missing counts beside means. Two variables summarized over different nonmissing subsets are not necessarily comparable as if they came from the same complete cases. A constant variable can have undefined skewness. If there are no eligible numeric columns, the task returns an explanatory result rather than magically converting strings to measurements.

Use Summary Statistics before and after missing-value handling, scaling or filtering. The Iris exercise's sepal-length mean provides a simple known-value check. The air-quality project compares raw and mean-imputed summaries so the teaching transformation is visible.

This task is descriptive; it does not provide confidence intervals or a formal normality test by default. A small standard deviation can be real, a unit error or a rounded import. Interpret values using the source's units and provenance.

## Summary Tables {#task-summary_tables}

Choose a row grouping variable, optionally a column grouping variable, and a value variable/statistic. Available summaries include mean, sum, median, count, minimum, maximum and standard deviation. With no value field, the task can produce group counts.

This is useful for a report-ready comparison such as mean petal length by species or tooth length by dose and supplement. Establish whether the statistic is a count of records, a count of observed values or a summary of a numeric measurement. Those questions are not interchangeable when missingness differs among groups.

Treat empty or small cells carefully. A mean for one observation has a different evidential basis from a mean for a large group, even when the table displays them with the same precision. Include counts alongside values when the intended audience needs that context, using another summary or a deliberate Script if needed.

A table grouped by a factor uses its categories; a continuous-looking field can create many small groups. In the ToothGrowth example, dose is intentionally categorical. If you want a continuous dose-response model instead, choose a model whose specification matches that question.

## Table Analysis {#task-table_analysis}

Select row and column category variables. The task creates a contingency table, optional row/column/total percentage display, and a chi-square test where possible. The chi-square result can be retained as its own named table.

The retained primary table is the count table. Percentage settings affect the displayed contingency summary; they are not a declaration that exported counts have become percentages. Name any separately derived percentage table explicitly if downstream work needs it.

The implementation uses ordinary contingency-table handling, which omits missing categories unless you explicitly prepare them as values. That differs from One-Way Frequencies' explicit missing level. Check denominators when comparing the two outputs.

Sparse/empty cells can make the chi-square approximation inappropriate or unavailable. The task records warnings and can retain useful counts even when the test cannot be produced. Inspect expected-count warnings, study design and dependence among observations before interpreting a p-value. The balanced ToothGrowth dose/supplement table illustrates a design cross-tabulation, not a surprising observational association discovered by a significance test.

## Distribution Analysis {#task-distribution}

Select one numeric variable, a histogram bin count, optional density overlay and optional normal Q–Q plot. The task reports a numeric distribution summary, and its interactive Results supplies distribution graphics with export/download options.

The retained named analytical output is the summary table. Do not assume every on-screen preview is an independently declared plot object available to all downstream tasks. If you need a configurable named histogram/static image for Report or Export, the Histogram graph task exposes that graph-output workflow clearly.

Check missing and infinite values. Missing observations are excluded from numeric distribution calculations; infinite values are rejected by the summary helper. A few extreme finite values can still dominate a histogram or density estimate. Changing bins changes the visual impression, not the underlying observations.

A roughly straight Q–Q pattern is not proof that every modelling assumption is satisfied. Distribution of a raw response and distribution of a model's residuals are different questions. The descriptive example uses tooth length for exploration; the capability/diagnostic tasks provide additional distribution tools when you need a retained CDF or normal-probability result.

## Reporting descriptive results honestly

Include the observation count, missingness and grouping definition with a summary. State whether a dataset is raw, filtered, imputed or complete-case. Preserve units in headings and derived-field names. When several tasks summarize different subsets, a tidy report layout cannot make their denominators identical.

Use task notes for analytical decisions and custom logging for runtime facts: how many rows were retained, which columns had missing values, or which threshold was applied. A report can then combine the result tables with an execution-log appendix instead of presenting numbers without a trace of their preparation.
