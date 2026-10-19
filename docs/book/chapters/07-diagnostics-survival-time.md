# Check patterns and work with time {#diagnostics-and-time}

These tasks answer more specific questions. Read the matching example first, and keep the meaning and order of your data clear.

## CDF Plots {#task-cdf_plots}

Use **CDF Plots** to see what share of observations is at or below a value. CDF stands for cumulative distribution function.

Choose a numeric measurement and run the task. Pick a value on the horizontal axis and read the share on the vertical axis. For example, a share of 0.75 means about 75% of the observations are at or below that value.

This view can help you compare thresholds without choosing histogram bins. Check the units and missing-value count. It describes the data you supplied, not a guarantee about future measurements. **Nile flow - distribution and stability** includes this plot alongside a probability plot and control chart, so you can compare different views of the same 100 annual observations.

## Probability Plots {#task-probability_plots}

Use **Probability Plots** to compare the pattern of a numeric column with a reference distribution, such as a normal distribution.

Choose the measurement and available reference settings, then run the task. Points that follow the reference line suggest a similar pattern. Curves and distant points suggest differences, especially in the tails where extreme values lie.

The plot is a check, not a pass-or-fail certificate for every later analysis. Read it with a histogram and the study context. Do not remove observations just to make the points straighter. **Nile flow - distribution and stability** gives you a worked normal probability plot. Use it to learn how the line and points relate before interpreting your own data.

## Control Charts {#task-control_charts}

Use **Control Charts** to inspect measurements in their recorded order and flag unusual patterns.

Choose the measurement and check the row order. Time order matters here. Review the selected chart and rule settings, then run the task. Inspect any flagged points or runs.

The app estimates limits from the data. Those limits are different from an outside target or an allowed tolerance set by a customer. A point inside a limit is not proof that it meets a product requirement. **Nile flow - distribution and stability** uses an individuals chart for practice. River observations are a teaching dataset, not a controlled factory process. Read the example's notes before borrowing its settings for another purpose.

## ARIMA / Basic Forecasting {#task-arima_forecast}

Use **ARIMA / Basic Forecasting** to estimate future values from an ordered numeric series.

Choose the value column and set the forecast horizon, the number of future steps. Make sure each step means the same interval, such as one month. Sort and check the series before fitting. Run the task and inspect the fitted model summary, forecasts, and intervals.

**Air passengers - forecast a monthly series** starts with 144 monthly values and forecasts 12 more steps. The task does not automatically turn every dated table into a tuned seasonal model. Check the settings and model used. The intervals show model uncertainty; they do not promise that future events will stay within them. Keep the time labels clear when reporting the result.

# Time until an event {#survival-analysis}

Survival tasks use a time column and an event indicator. An event might be a failure, a repair, or another outcome. A censored observation means the event had not been seen by the end of that observation's follow-up.

For these tasks, check that **1 means the event occurred** and **0 means it was not observed during follow-up**. Other coding systems must be converted first. The example does this for you and explains the change in its preparation task.

## Life Tables {#task-life_tables}

Use **Life Tables** to estimate how the chance of remaining event-free changes over time.

Choose the time column and event column. Add a grouping column if you want separate curves, then run the task. Check the number of usable rows and events. Confirm that time uses one unit and does not contain unexplained negative values.

**Lung cancer - survival analysis** keeps the 228-row original data and prepares a separate input for analysis. Its original event code of 2 is converted to 1. Open the preparation task before reading the curve. The example teaches app controls and coding checks. It is not a guide for making care decisions. Use suitable analysis advice before applying these methods to important decisions.

## Proportional Hazards {#task-proportional_hazards}

Use **Proportional Hazards** to model the relationship between predictors and the rate at which an event occurs over time. This is often called a Cox model.

Choose time, event, and predictor columns. Check event coding and missing values, then run the task. Read the coefficients, intervals, warnings, and number of included observations.

The **Lung cancer - survival analysis** example shows the prepared input and an illustrative model. A hazard ratio compares event rates in the fitted model. It is not an absolute probability that a person will remain event-free until a chosen date. The method also has assumptions about how relationships behave over time. Use the example to learn the app's settings, and get method advice when those assumptions affect your work.
