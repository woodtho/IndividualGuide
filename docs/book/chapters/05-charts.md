# Make charts people can read {#charts}

Choose a chart based on the question you want to answer. Start with simple settings, then add a clear title, axis labels, and units.

The **X** setting usually controls the horizontal axis. **Y** controls the vertical axis. Group or colour separates categories. After running, check both the chart and the number of rows it uses.

## Keep the output you need

Chart tasks can offer plotting data, an interactive chart, and a static image. An interactive chart may show details when you hover. A static image is a still chart that works well in Word reports and image exports.

Enable the static image output if you want to export PNG. Then use an **Export** task to write the file. Making a chart in the project does not by itself write a picture into your chosen folder.

Some chart views and chart data outputs show only the first 1,000 rows. Check the task's row limit before using a chart output as if it were the complete source table. Use a summary or sample on purpose when there are too many points to read.

## Bar Chart {#task-bar_chart}

Use **Bar Chart** to compare category counts or a selected numeric summary.

Choose the category for X. If the chart mode asks for a value or summary, choose those too. Add a group only if it helps the comparison. Run the task and check that the axis describes what the bar height means: a count, sum, and mean answer different questions.

Keep category names readable. If the labels overlap, reduce the number of categories or change the layout. **Flowers - categorical chart gallery** counts the three species. Each bar should represent 50 flowers. Compare it with the frequency table if you are unsure what the chart is counting.

## Bar-Line Chart {#task-bar_line_chart}

Use **Bar-Line Chart** to show bars and a line on the same category or time axis.

Choose the shared X column, then the values for the bars and line. Check axis labels and any second-axis settings. Run the chart and make sure the legend clearly identifies each part.

If the two values use different units or scales, explain both. Similar-looking heights on two axes do not mean equal values. Avoid using the chart to imply a relationship just because the shapes line up. **Nottingham temperatures - time charts** compares annual averages with observed ranges. The range is a difference between observed values, not a measure of uncertainty around the average.

## Box Plot {#task-box_plot}

Use **Box Plot** to compare the spread of a numeric measurement across groups.

Choose the group for X and the measurement for Y. Run the task. The line inside the box marks the median, the middle value. The box covers the middle half of the data. Points beyond the whiskers highlight values that may deserve a closer look.

Read the plot alongside group counts. A small group gives less information than a large one, even if their boxes look similar. Check unusual points before deciding they are errors. **Flowers - categorical chart gallery** compares flower measurements by species. Use Summary Tables if you also need exact group values in a report.

## Bubble Plot {#task-bubble_plot}

Use **Bubble Plot** to show two numeric measurements, with bubble size showing a third.

Choose X, Y, and a numeric size column. Add colour or group if useful, then run the task. Check that the size legend explains what larger bubbles mean. Keep the units clear for all three measurements.

Overlapping bubbles can hide smaller ones. Try less data or a simpler Scatter Plot if the picture is hard to read. Use this task when size needs to change visibly; a Size field shared with other chart forms may not have that effect in Scatter Plot. **Flowers - numeric chart gallery** lets you compare both charts using the same observations.

## Contour Plot {#task-contour_plot}

Use **Contour Plot** to see where pairs of numeric values are concentrated.

Choose the two numeric columns for X and Y, then run the chart. Read the contour lines or regions as a guide to where more observations lie. Compare the result with a scatter plot of the same columns.

The smooth shape depends on the data and chart settings. It does not show a measured boundary around a real group. A small sample can give a pattern that looks more certain than it is. **Flowers - numeric chart gallery** includes contours beside the individual flower points, which makes it easier to see what the smoothing adds and what it leaves out.

## Histogram {#task-histogram_graph}

Use **Histogram** to show how one numeric measurement is distributed.

Choose the numeric column and a bin setting. A bin is a range of values counted together. Run the task and check the horizontal axis, the counts, and the number of missing values.

Try a few sensible bin choices. Very wide bins can hide patterns, while very narrow bins can make random variation look important. A histogram's bars represent numeric ranges; a Bar Chart usually represents separate categories. **Flowers - numeric chart gallery** includes a histogram you can compare with its Summary Statistics. Use both when you want a picture of the spread and exact values.

## Line Plot {#task-line_plot}

Use **Line Plot** to show change across an ordered column, often time.

Choose the date or ordered value for X and a measurement for Y. Add a group if you need separate lines. When several rows share the same time, decide whether you need to summarize them first. Check the order, then run the task.

A line joins observations. It does not prove what happened between them, and it is not a forecast. Check gaps and the time range so readers can see where data are missing. **Nottingham temperatures - time charts** shows 240 monthly observations. Read the date column and units before comparing years or describing a seasonal pattern.

## Pie Chart {#task-pie_chart}

Use **Pie Chart** for a simple view of category shares when there are only a few groups.

Choose the category column and run the task. Check each category's count and share. In this task, the slices count observations by category; do not assume a numeric amount column supplies slice weights.

Use a frequency table to confirm the totals. Many small slices are hard to compare, so a Bar Chart may be easier to read when you have many groups. **Flowers - categorical chart gallery** uses the three Iris species. Its slices should be equal because each species has 50 observations. Changing colour affects the display, not the counts behind it.

## Scatter Plot {#task-scatter_plot}

Use **Scatter Plot** to look at the relationship between two numeric columns.

Choose X and Y, then add colour or group if it helps. Run the chart and check the labels and units. Each visible point represents an observation, although points can overlap.

Look for a trend, curved pattern, separate groups, and unusual points. A visible trend does not prove that one measurement causes the other. Use Bubble Plot if you need a third measurement to control point size. **Iris exploration** compares sepal length with petal length by species. Try changing Y to petal width in a saved copy, then rerun the report so it shows your new chart.

## Scatter Plot Matrix {#task-scatter_matrix}

Use **Scatter Plot Matrix** to compare several numeric columns in one grid.

Choose a small set of numeric columns and any grouping setting, then run it. Each panel compares a pair of columns. Read its row and column labels to know which measurements are shown.

Start with three or four columns. A large grid becomes hard to read, and display limits may show only part of a large dataset. If one pair is interesting, open a separate Scatter Plot for a clearer view. **Flowers - numeric chart gallery** compares the four Iris measurements. Use its matrix to choose a relationship to inspect, rather than trying to explain every panel at once.
