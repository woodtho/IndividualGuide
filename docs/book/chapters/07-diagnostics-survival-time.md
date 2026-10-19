# Distribution diagnostics, process charts and time {#diagnostics-and-time}

These tasks expose specific diagnostic and forecasting calculations. Their category names are guides to use, not claims that the application implements every method in a discipline. For example, Life Tables is Kaplan–Meier estimation in this app, and the forecasting task is a basic univariate ARIMA workflow rather than an all-purpose time-series workbench.

## CDF Plots {#task-cdf_plots}

Select a numeric response and optional grouping variable. The task draws an empirical cumulative distribution and returns quantiles at five-percentage-point steps from 0 to 100 percent. Retain the table and desired static/interactive output.

A CDF answers what fraction of observed values are at or below a threshold. It is useful when percentiles or group distribution comparisons are more informative than a bin-dependent histogram. Grouped curves still reflect their own observed samples; matching a percentile does not mean sample sizes or uncertainties are equal.

Missing values are handled by the calculation, while nonfinite values and unsuitable types require correction. A flat stretch means no observed values in that range, not evidence that future values cannot occur there. The curve is empirical and does not fit a parametric tail model.

The Nile diagnostic project combines CDF, probability plot and control chart. Compare what each reveals: distribution position, shape relative to normality and behavior in observation order. They are complementary perspectives rather than three independent approvals of a process.

## Probability Plots {#task-probability_plots}

Choose one numeric variable. The task draws a normal Q–Q plot with a reference line through the sample quartiles, and returns a table containing count, mean, standard deviation, skewness, excess kurtosis and Shapiro–Wilk information where available.

At least three nonmissing observations are required. The Shapiro test is attempted for the supported sample-size range, 3–5,000; beyond it the related fields can be missing rather than a fabricated p-value. Constant or otherwise unsuitable samples can also make a formal statistic unavailable. Inspect the plot and result fields together.

The reference line is not an estimated regression model for the original data. Departures in the tails, curvature or outlying observations help describe shape. A small p-value and a large sample are not a complete judgement of a model's practical adequacy, and raw-variable normality is not the same as residual assumptions.

Use the retained normality table in a report with a heading that identifies the variable and analysis subset. If you use transformed values, say so explicitly. Do not silently replace the original observations simply to make a diagnostic line look straighter.

## Control Charts {#task-control_charts}

Choose a numeric measurement and, optionally, a subgroup field. With no subgroup, the task creates an **Individuals** chart using sigma estimated from average moving range divided by 1.128. It requires at least three nonmissing values. Row order matters because moving ranges and run rules depend on adjacency.

With a subgroup, it creates an Xbar-style chart. Balanced groups of size 2–10 use A2 × average-range limits. Other group sizes/unequal sizes use the implementation's fallback, three standard deviations of subgroup means. The result identifies the method; do not describe that fallback as the same calculation as a balanced Xbar-R chart.

Optional run rules extend simple limit breaches:

| Rule | Trigger |
| --- | --- |
| 1 | A point beyond three sigma |
| 2 | Two of three consecutive points beyond two sigma on the same side |
| 3 | Four of five beyond one sigma on the same side |
| 4 | Eight consecutive points on one side of the centre |

Pattern rules flag the point completing the pattern. Outputs include points/limits and rule flags, plot/static image and an optional summary. Limits are estimated from the supplied observations; they are not externally specified engineering tolerances or Cp/Cpk calculations.

The Nile series illustrates historical stability diagnostics, not a controlled manufacturing process. Time dependence, changing regimes, subgroup design and distributional context affect interpretation. Sort the input chronologically and preserve the original sequence before using order-sensitive diagnostics.

## ARIMA / Basic Forecasting {#task-arima_forecast}

Choose a numeric series-value field, keep rows in their intended time order and select a positive integer horizon. The task requires at least eight observations and rejects missing series values rather than dropping them and silently changing time spacing.

When `forecast` is installed, the engine uses `forecast::auto.arima`; otherwise it searches a small AIC-selected grid with `stats::arima`. The selected engine/order is available in the optional summary. Package availability can therefore change model selection. Record the engine and environment if results need to be reproduced elsewhere.

The input is treated as an ordered numeric series, not an automatically inferred irregular-date forecasting problem. Do not assume a separate date column supplies seasonal frequency or missing-period information. The AirPassengers example forecasts twelve steps from 144 monthly observations and explains that this is the task's basic workflow, not a tuned seasonal model for airline demand.

Outputs include point forecasts and 80/95 percent intervals, a forecast display, an optional ARIMA model and selection summary. The horizon means steps at the series' intended spacing. Forecast intervals reflect the fitted model and assumptions, not every possible structural change. Compare predictions with held-out observations and a sensible benchmark when assessing practical forecasting value.

# Survival analysis with explicit event coding {#survival-analysis}

Survival data combine a duration with information about whether the event was observed or the observation was censored. A duration alone is not enough. Event coding must be established before either task runs; interpreting the wrong code as an event changes the analysis fundamentally.

The lung-cancer example preserves `lung_raw`, selects complete cases for its stated fields, converts original status **2** into event **1**, and labels sex. Read that preparation. It is an educational workflow using historical data, not clinical guidance or a complete adjusted clinical model.

## Event indicators and missingness

Numeric indicators must contain 0/1; logical values map to false/true. For character/factor indicators, explicitly choose the event level when possible. With a blank event level and exactly two observed character levels, the helper uses the second sorted level. Do not rely on lexical order to encode a domain decision.

The shared survival preparation omits rows with missing duration/event indicator, and the fitted method can omit additional rows with missing predictors. Track both stages if observation counts matter. Infinite numeric values are rejected. Check units of time and the meaning of zero/negative/otherwise questionable values according to your study design rather than assuming the UI has established the design for you.

These panels expose ordinary right-censored survival workflows. Delayed entry, competing risks, time-varying effects, complex survey weights and specialized censoring structures are not implied by the category name. Use an explicit supported R specification in Script for those requirements.

## Life Tables {#task-life_tables}

In this application, Life Tables fits **Kaplan–Meier** survival with `survival::survfit`. Select time as the response, event indicator as the group/event field and, optionally, a stratifying predictor. The implementation uses the first selected stratifying field for its grouping formula.

The primary table contains survival-step estimates with confidence information. A compact median-survival summary is also available, along with static/interactive survival curves and the `survfit` model. A median can be undefined if the estimated curve does not reach the relevant probability; a missing median is not automatically a software error.

The lung example compares survival curves by labelled sex. Censoring and follow-up affect how much information remains in later portions of a curve. Read confidence bounds and sample/event counts rather than comparing the last visible points as though each had equal support.

This task does not automatically add a log-rank comparison or fit a covariate-adjusted hazard model. Its name should not be used to imply an actuarial interval life-table implementation. Choose Proportional Hazards for the supported Cox model, or write a separate Script for another defined analysis.

## Proportional Hazards {#task-proportional_hazards}

Select time, event indicator and at least one covariate. The task fits an additive `survival::coxph` model. Its coefficient table includes hazard ratios `exp(coef)` beside log-hazard estimates, with confidence/fit information and optional fitted values, risk predictions and the model object.

The lung example uses age and labelled sex after explicit event conversion. A hazard ratio describes the fitted relative hazard under the model and its coding; it is not a direct probability or an automatic causal effect. Check reference categories, time units, missing-data exclusions and the proportional-hazards assumption.

New-data predictions in this task are **relative risk** values from the Cox model. They are not automatically absolute survival probabilities at a chosen time. If a report needs a time-specific survival estimate or a diagnostic such as proportional-hazards testing, retain the model and implement the appropriate additional calculation in Script.

Do not force an unsuitable model through by recoding every unusual status as censored. Establish the original code meanings, retain the raw status and log the conversion. The project should make that decision inspectable long after the person who configured the task has forgotten it.
