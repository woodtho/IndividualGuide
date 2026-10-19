# Check patterns and work with time {#diagnostics-and-time}

These tasks answer more specific questions. Read the matching example first, and keep the meaning and order of your data clear.

Run the input task first. Find each analysis task's category in the [Task finder](#task-finder), add it, then choose **Input table** under **Setup**. Keep the output controls enabled for results you want to use later.

## CDF Plots {#task-cdf_plots}

Use **CDF Plots** to see what share of observations is at or below a value. CDF stands for cumulative distribution function.

1. Choose **Input table** and the measurement in **Numeric variable**.
2. Add **Group / colour (optional)** only when you need separate group curves.
3. Select **Run**, then open **Results** and inspect the plot. Pick a value on the horizontal axis and read the share on the vertical axis. A share of 0.75 means about 75% of observations are at or below that value.

This view can help you compare thresholds without choosing histogram bins. Check the units and missing-value count. It describes the data you supplied, not a guarantee about future measurements. **Nile flow - distribution and stability** includes this plot alongside a probability plot and control chart, so you can compare different views of the same 100 annual observations.

## Probability Plots {#task-probability_plots}

Use **Probability Plots** to compare a numeric column with a normal distribution, a common bell-shaped pattern.

1. Choose **Input table**, then choose the measurement in **Numeric variable**.
2. Keep the plot output enabled. This task uses a normal reference; there is no reference-distribution picker.
3. Select **Run**, then open **Results** and inspect the plot. Points near the line suggest a similar pattern. Curves and distant points suggest differences, especially near the extremes.

The plot is a check, not a pass-or-fail certificate for every later analysis. Read it with a histogram and the study context. Do not remove observations just to make the points straighter. **Nile flow - distribution and stability** gives you a worked normal probability plot. Use it to learn how the line and points relate before interpreting your own data.

## Control Charts {#task-control_charts}

Use **Control Charts** to inspect measurements in their recorded order and flag unusual patterns.

1. Sort the input into observation order before adding the task. Choose **Input table** and **Measurement**.
2. Leave **Subgroup** blank for an individuals chart. Select a subgroup column only when the rows form meaningful subgroups for an Xbar chart of subgroup means.
3. Check **Western Electric run rules** if those extra pattern checks suit your use. These rules flag certain sequences, not just single extreme points.
4. Select **Run**, then open **Results**. Inspect the plot and the table of points with control limits and flags.

![Control Charts uses the row order of the input. A blank Subgroup setting selects an individuals chart; run rules add pattern checks.](assets/ui-control-chart.png){#fig-control-chart}

The app estimates limits from the data. Those limits are different from an outside target or an allowed tolerance set by a customer. A point inside a limit is not proof that it meets a product requirement. **Nile flow - distribution and stability** uses an individuals chart for practice. River observations are a teaching dataset, not a controlled factory process. Read the example's notes before borrowing its settings for another purpose.

## ARIMA / Basic Forecasting {#task-arima_forecast}

Use **ARIMA / Basic Forecasting** to estimate future values from an ordered numeric series.

1. Prepare one numeric value per equal time interval, such as one month. Sort the table into time order. The task needs at least eight values and no missing series values.
2. Choose **Input table**, then select **Series value (rows in time order)**.
3. Set **Forecast horizon (steps ahead)**. Enter 12 for twelve future intervals.
4. Select **Run**, then open **Results**. Inspect the fitted model, forecast values, and intervals.

![The forecasting form uses an ordered value column and a horizon measured in steps. It does not infer the calendar interval from a date column.](assets/ui-forecast.png){#fig-forecast}

**Air passengers - forecast a monthly series** starts with 144 monthly values and forecasts 12 more steps. The task does not automatically turn every dated table into a tuned seasonal model. Check the settings and model used. The intervals show model uncertainty; they do not promise that future events will stay within them. Keep the time labels clear when reporting the result.

# Time until an event {#survival-analysis}

Survival tasks use a time column and an event indicator. An event might be a failure, a repair, or another outcome. A censored observation means the event had not been seen by the end of that observation's follow-up.

For numeric event columns, check that **1 means the event occurred** and **0 means it was not observed during follow-up**. Convert other numeric codes first. For text or category columns, use **Event level** to name the value that means an event. The example prepares 0/1 codes and explains the change in its preparation task.

## Life Tables {#task-life_tables}

Use **Life Tables** to estimate how the chance of remaining event-free changes over time.

1. Choose the prepared **Input table**. Select **Time to event** and **Event indicator (1 = event, 0 = censored)**.
2. If the event column contains text or categories, set **Event level** explicitly. For a numeric 0/1 column, keep that coding.
3. Add one **Strata** column if you want separate curves. Only the first selected column is used.
4. Select **Run**, then open **Results**. Check the number of usable rows and events. Confirm that time uses one unit and has no unexplained negative values.

![Life Tables separates follow-up time, event coding, and optional strata. Check the prepared event column before reading the curves.](assets/ui-survival.png){#fig-survival width=14.5cm}

**Lung cancer - survival analysis** keeps the 228-row original data and prepares a separate input for analysis. Its original event code of 2 is converted to 1. Open the preparation task before reading the curve. The example teaches app controls and coding checks. It is not a guide for making care decisions. Use suitable analysis advice before applying these methods to important decisions.

## Proportional Hazards {#task-proportional_hazards}

Use **Proportional Hazards** to model the relationship between predictors and the rate at which an event occurs over time. This is often called a Cox model.

1. Choose the prepared **Input table**, **Time to event**, and **Event indicator (1 = event, 0 = censored)**.
2. Select the predictors in **Covariates**. Set **Event level** if the event column uses text or categories.
3. Check missing values and event coding, then select **Run**.
4. Open **Results**. Read the coefficients, intervals, warnings, and number of included observations together.

**Lung cancer - survival analysis** includes an illustrative model. A hazard ratio compares fitted event rates; it is not a person's absolute event probability. Use the example to learn the controls. Ask for method advice before relying on the model's assumptions.
