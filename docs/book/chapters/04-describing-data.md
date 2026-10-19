# Get to know your data {#describing-data}

Look at your data before fitting a model. Check how many rows you have, which values are missing, and how each column is stored. These tasks help you spot surprises early.

Run the input task first. Find these tasks under **Add Task > Describe**. Their analysis controls and results appear in the same task panel; [task controls](#task-controls) explains the shared layout.

## Characterize Data {#task-characterize}

Use **Characterize Data** for an overview of a table's columns.

1. Select the **Input table**.
2. Set the **Output table** name if you want to retain its summary.
3. Click **Analyze**, or use the task header's **Run** button.
4. Read **Results** for column types, counts, and missing-value information.

This task describes all columns in its input; it has no column-selection control. Check that measurements are numeric, group labels are categories or text, and date columns contain dates.

This is a good first step after Import Data. If a number column is stored as text, look for entries such as currency symbols or words before trying to convert it. Use Change Column Types once you know the intended meaning. The **Tooth growth - descriptive analysis** example starts with checks that help you understand the data before summarizing it.

## List Data {#task-list_data}

Use **List Data** to page through a table in a readable view.

1. Select the **Input table**.
2. Set **Rows per page** to a comfortable display size.
3. Enable and name the output table if you need a retained copy.
4. Click **Load** or the task header's **Run** button. Page through the result.

Rows per page changes the view, not the number of source rows. This form has no column picker. Use Keep / Drop Columns first when you want a smaller set of columns.

A short listing helps you spot misspelled categories, unexpected dates, and values in the wrong units. Check the displayed row count or limit before assuming the listing shows every record. Keep your full input table for calculations. See **Tooth growth - descriptive analysis** for a listing alongside summary tasks. Use Export when you need to deliver a data file rather than a view inside the project.

## One-Way Frequencies {#task-one_way_freq}

Use **One-Way Frequencies** to count how often each category appears in one column.

1. Select the **Input table** and the category under **Variable**.
2. Choose **Sort by frequency** if the most common values should appear first.
3. Name the output and click **Analyze** or the task header's **Run** button.
4. Check the counts, percentages, and their total in **Results**.

The form does not offer separate percentage or missing-value switches. If a category seems to be missing, inspect blank values and spelling in the input.

![One-Way Frequencies counts the selected Variable. Sort by frequency changes the order, while Results lets you check the counts.](assets/ui-frequencies.png){#fig-frequencies}

A count tells you how many records are in a group. A percentage also needs a denominator, such as all rows or only rows with known values. Check which rows the task includes before reporting percentages. **Tooth growth - descriptive analysis** counts supplement groups. You can also count the Iris species to check that each has 50 flowers.

## Summary Statistics {#task-summary_stats}

Use **Summary Statistics** for numbers such as mean, median, minimum, maximum, and spread.

1. Select the **Input table**.
2. Under **Numeric columns**, select the measurements to summarize. Blank means all numeric columns.
3. Enable and name the **Output table** if you want to retain it.
4. Click **Analyze** or the task header's **Run** button, then read **Results**.

Read the usable and missing counts as well as the mean. Ten known values and forty missing entries do not describe fifty complete observations.

In **Data**, `n` is the number of known values and `n_miss` is the missing count. `sd` means standard deviation, a measure of spread. These checks help you judge how much information supports a mean.

The mean is the average. The median is the middle value after sorting. A few very large values can pull the mean away from the median, so comparing both can help you spot an uneven pattern. **Iris exploration** gives you a simple check: mean sepal length is about 5.8433 centimetres. Keep units in the headings when you put the results in a report.

## Summary Tables {#task-summary_tables}

Use **Summary Tables** to calculate a value for each group, such as mean sales by region.

1. Select the **Input table** and **Row variable** for grouping.
2. Leave **Column variable (optional)** blank, or choose a second grouping column.
3. Choose the numeric **Value variable** and **Summary statistic**.
4. Name the output and click **Analyze** or the task header's **Run** button.

For the flower example, choose `Species`, `Petal.Length`, and Mean. The result has one mean for each species.

![Summary Tables groups a Value variable by the Row variable. Leave Column variable blank for one grouping column.](assets/ui-group-summary.png){#fig-group-summary}

Check how many groups appear and whether their labels match the source. Groups with missing measurements may have different numbers of usable values. Check the input and use a separate count summary when needed; a table of means does not also supply those counts. **Iris exploration** shows three species means, and **Tooth growth - descriptive analysis** shows another grouped summary. A grouped table is also a useful input for a report or bar chart.

## Table Analysis {#task-table_analysis}

Use **Table Analysis** to compare two category columns in a cross-table. Each cell counts rows that match one category from each column.

1. Select the **Input table**, **Row variable**, and **Column variable**.
2. Set **Show percentages** to the view you need: none, row, column, or total.
3. Check the output-table and chi-square output switches and names.
4. Click **Analyze** or the task header's **Run** button. Read the counts before the test results.

If you enable a chi-square test, it checks for evidence of a relationship between the categories. Small or empty cells can make that test unsuitable. A **p-value** helps judge evidence against the idea that the categories are unrelated. A small value does not tell you how large or useful the relationship is. **Tooth growth - descriptive analysis** cross-tabulates supplement and dose. It helps you see how the observations are divided among the study groups.

## Distribution Analysis {#task-distribution}

Use **Distribution Analysis** to examine how a numeric column's values are spread out.

1. Select the **Input table** and numeric **Variable**.
2. Set **Bins**, the number of ranges used in the histogram.
3. Choose **Density** or **Q-Q plot** if you need those displays, and check the plot dimensions.
4. Click **Analyze** or the task header's **Run** button. Inspect **Results**, **Plot**, and **Data**.

Look for a long tail, several peaks, extreme values, and missing entries. A long tail means a few values extend far beyond most of the data. The Q-Q view compares the observed pattern with a normal, or bell-shaped, reference pattern.

Use what you see to guide your next question. Do not delete a large value just because it looks unusual; check whether it is a mistake or a real observation. **Tooth growth - descriptive analysis** includes this task beside counts and grouped summaries. Together, those views help you understand both the measurements and the groups that produced them.
