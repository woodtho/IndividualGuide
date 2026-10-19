# Get to know your data {#describing-data}

Look at your data before fitting a model. Check how many rows you have, which values are missing, and how each column is stored. These tasks help you spot surprises early.

## Characterize Data {#task-characterize}

Use **Characterize Data** for an overview of a table's columns.

Choose the input table and the columns to inspect, then run the task. Review the column types, counts, and missing-value information. Check that measurements are numeric, group labels are categories or text, and date columns contain dates.

This is a good first step after Import Data. If a number column is stored as text, look for entries such as currency symbols or words before trying to convert it. Use Change Column Types once you know the intended meaning. The **Tooth growth - descriptive analysis** example starts with checks that help you understand the data before summarizing it.

## List Data {#task-list_data}

Use **List Data** to make a readable view of selected rows and columns.

Choose the input, the columns, and any row limit or display settings. Run the task and read a few records. Include a useful identifier so you can trace an unusual value back to its source row.

A short listing helps you spot misspelled categories, unexpected dates, and values in the wrong units. Check the displayed row count or limit before assuming the listing shows every record. Keep your full input table for calculations. See **Tooth growth - descriptive analysis** for a listing alongside summary tasks. Use Export when you need to deliver a data file rather than a view inside the project.

## One-Way Frequencies {#task-one_way_freq}

Use **One-Way Frequencies** to count how often each category appears in one column.

Choose the input and category column. Set any missing-value and percentage options, then run it. Check the counts and their total. If a category seems to be missing, inspect blank values and spelling in the source table.

A count tells you how many records are in a group. A percentage also needs a denominator, such as all rows or only rows with known values. Check which rows the task includes before reporting percentages. **Tooth growth - descriptive analysis** counts supplement groups. You can also count the Iris species to check that each has 50 flowers.

## Summary Statistics {#task-summary_stats}

Use **Summary Statistics** for numbers such as mean, median, minimum, maximum, and spread.

Choose the input and numeric columns, then run it. Read the number of usable values as well as the summary. A mean based on ten known values does not describe fifty complete observations when forty entries are missing.

The mean is the average. The median is the middle value after sorting. A few very large values can pull the mean away from the median, so comparing both can help you spot an uneven pattern. **Iris exploration** gives you a simple check: mean sepal length is about 5.8433 centimetres. Keep units in the headings when you put the results in a report.

## Summary Tables {#task-summary_tables}

Use **Summary Tables** to calculate a value for each group, such as mean sales by region.

Choose the input, a row or group variable, a value variable, and a statistic. For example, use `Species` for groups, `Petal.Length` for values, and mean for the statistic. Choose an output name and run the task.

Check how many groups appear and whether their labels match the source. Groups with missing measurements may have different numbers of usable rows. Read those counts before comparing means. **Iris exploration** shows three species means, and **Tooth growth - descriptive analysis** shows a grouped summary for another dataset. A grouped table is also a useful input for a report or bar chart.

## Table Analysis {#task-table_analysis}

Use **Table Analysis** to compare two category columns in a cross-table. Each cell counts rows that match one category from each column.

Choose the row category and column category. Run the task and check the counts before reading any test results. Review whether displayed percentages are based on rows, columns, or the whole table.

If you enable a chi-square test, it checks for evidence of a relationship between the categories. Small or empty cells can make that test unsuitable. A small p-value does not tell you how large or useful the relationship is. **Tooth growth - descriptive analysis** cross-tabulates supplement and dose. It helps you see how the observations are divided among the study groups.

## Distribution Analysis {#task-distribution}

Use **Distribution Analysis** to examine how a numeric column's values are spread out.

Choose the input and measurement column. Select the summaries or displays you need, then run it. Look for a long tail, several peaks, extreme values, and missing entries. A long tail means a few values extend far beyond most of the data.

Use what you see to guide your next question. Do not delete a large value just because it looks unusual; check whether it is a mistake or a real observation. **Tooth growth - descriptive analysis** includes this task beside counts and grouped summaries. Together, those views help you understand both the measurements and the groups that produced them.
