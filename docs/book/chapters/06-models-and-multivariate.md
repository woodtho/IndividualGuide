# Models, comparisons and multivariate analysis {#models}

The statistical tasks provide reproducible interfaces to specific R calculations. They are not an automatic model-selection service. Choose a method that matches the question, observational unit, outcome type, sampling design and assumptions. The configured predictor selector builds the supported additive formula; use Script when you require interactions, transformations or a different model specification not exposed by the task.

## Shared analytical settings and outputs

Select the input, response and predictors/group as required by the task. Give the primary result a meaningful name. Model tasks expose additional named outputs independently: coefficients or another primary table, model-fit information, fitted values/residuals, optional predictions and the raw model object. PCA/clustering/ANOVA have their own corresponding outputs.

Primary tables and compact fit summaries are commonly enabled by default. Large row-level augment/scores outputs and raw model objects are generally opt-in. If a downstream Script needs the fitted model, enable that object explicitly rather than assuming the displayed coefficient table is the model. If a Report needs fitted values, enable and run that output first.

Prediction-capable tasks take a separate new-data table. It must contain the required predictors with compatible types and factor levels. Enabling the Predictions output without choosing a new-data table is not a valid specification. Confidence intervals for an estimated mean/probability are not automatically individual prediction intervals. Check what the selected task actually returns.

Missing-data handling follows the underlying calculation and current R options unless the task prepares complete cases explicitly. Different models can use different subsets. Inspect the number of observations in the fit, not only the source table's row count. Keep an explicit missing-data audit if this affects interpretation.

## One-Way ANOVA {#task-one_way_anova}

Select a numeric response and a grouping variable. The task treats the group as a factor and fits `aov(response ~ group)`. It returns a tidy ANOVA table, fit information and Tukey HSD comparisons where available, with optional model and new-data predictions.

The PlantGrowth project compares weight across control, treatment 1 and treatment 2. Check that all 30 observations are in the intended groups before interpreting the ANOVA. The omnibus test asks whether the group means are all equal under its model, not which individual pair must differ. Tukey results supply the configured post-hoc comparisons.

Independence, residual behavior and variance assumptions belong to the analysis design. A balanced table does not prove them. Repeated measurements or clustered observations need an appropriate model rather than being treated as unrelated rows. If a group column is a continuous measurement that should have a slope, ANOVA's factor treatment is a different question.

Use the retained model in a Script/console copy for diagnostics when needed. Report the groups, observation counts, comparison method and uncertainty, not only a p-value. Additional covariates or interactions require a different supported model or an explicit Script specification.

## t Test {#task-t_test}

Choose a numeric response. With no group and Paired off, the task runs R's default one-sample `t.test`, whose null mean is **zero**. The UI does not expose a general null-mean or alternative-hypothesis selector; use Script for those custom specifications.

With a group selected, the task uses the ordinary two-sample formula interface. The grouping must have two usable levels; the default R test is Welch's two-sample test rather than an assumed equal-variance pooled test. In paired mode, choose a second numeric measurement from the same row; the implementation compares the two columns as pairs and requires different columns.

The ANOVA example creates a two-group table containing control and treatment 2 before its t Test. That is a deliberate comparison, not an instruction to repeatedly test all pairs and select whichever looks most significant.

Check pairing and missingness. Two columns measured on different people do not become paired merely because they occupy the same row count. The output is a tidy test table plus an optional test object. It does not automatically adjust a collection of separately configured t Tests for multiple comparisons.

## Linear Models {#task-linear_models}

Linear Models fits an additive `lm` using the response and selected predictors. It shares the least-squares engine with Linear Regression. The task's placement in the ANOVA family does not give it a hidden arbitrary-formula editor or automatically introduce interaction terms.

Use categorical predictors as factors when categories are intended. A numeric dose and a factor dose describe different models. Coefficients, confidence intervals, fit statistics, row-level fitted information, predictions and a model object are available according to enabled outputs.

The PlantGrowth example fits weight on group. Compare its model terms and fitted group means with the ANOVA representation. A differently formatted result can describe the same underlying least-squares comparison. The reference category and contrasts determine coefficient interpretation, so record them when handing a model to someone else.

If you need a transformed response, create it explicitly or use Script. If you require `response ~ x * group`, splines, offsets or specialized error structures, configure that model in Script rather than typing an operator into a selector that expects a column name. Keep the fitted object and diagnostics when the work will be reviewed.

## Linear Regression {#task-linear_regression}

Choose a numeric response and at least one predictor. The task builds an additive least-squares model with `lm`. It returns tidy coefficients with confidence intervals and a compact fit summary; fitted/residual rows, new-data predictions and the raw model can be retained separately.

The fuel-economy project fits `mpg ~ wt + hp` on 32 Motor Trend cars. Weight is in thousands of pounds in this dataset. The fitted coefficient on weight is therefore a change per 1,000 pounds at fixed horsepower, not per pound. The model illustrates an observational association, not an intervention effect.

For predictions, choose a new-data table with the required predictor fields. Confidence bounds are for the model's estimated response where implemented, not a claim that future individual cars must fall within those bounds. Extrapolating outside the observed range adds a modelling assumption that the task cannot validate for you.

Inspect residual patterns, influential observations, rank-deficient terms and the observation count. A green task status and a high R-squared are not substitutes for those checks. Save the model object when a downstream Script or diagnostic workflow needs methods such as `predict()` or residual analysis.

## Logistic Regression {#task-logistic_regression}

Logistic Regression fits a binomial GLM using the selected response and additive predictors. For a straightforward binary specification, prepare a 0/1 response and document what **1** means. Factor response behavior follows the underlying R binomial model, so do not leave event interpretation implicit.

Coefficients are on the log-odds scale. They are not probability differences. The result provides tidy coefficients/intervals, fit information and optional fitted values, model and new-data predictions. Prediction helpers return response-scale values for GLMs; optional confidence bounds are formed on the link scale and transformed back.

The binary car example models manual transmission from mpg. It is intentionally small and educational. Adding predictors can produce separation, unstable estimates or convergence warnings. A successful return with a warning still requires review. The app does not automatically fit a penalized logistic model when ordinary maximum likelihood is unstable.

Check the outcome coding, number of events/non-events, fitted probabilities and residual/fit information. If your response is a count of successes with trial totals, or if you need offsets, weights or interaction terms, use an explicitly appropriate model specification rather than assuming the binary form supplies them.

## Generalized Linear Models {#task-glm}

Choose a response, additive predictors and one of the exposed families: **gaussian**, **binomial**, **poisson** or **Gamma**. The task passes that family to `glm`, using its usual default link. It exposes the same main broom-style result families as the other regression tasks.

Family choice is about the response distribution and mean/variance structure, not a cosmetic alternative to a linear-model label. Poisson expects a count response under its model; Gamma is for suitable positive continuous responses. The interface does not automatically estimate an overdispersion parameter, add an exposure offset or change to a negative-binomial model.

The loom-break example fits a Poisson model of break counts using wool and tension. It retains diagnostic information and explicitly notes that overdispersion should be checked before using Poisson inference. Category coding and the study's grouping/design remain part of that review.

For new-data predictions, supply the same predictor schema and inspect whether response-scale output matches your intended quantity. A predicted count is not automatically a rate per exposure unless the model includes that exposure appropriately. More specialized links, offsets and model families can be expressed in Script and retained as model/table outputs.

## Nonlinear Regression {#task-nonlinear_regression}

Choose a numeric response, a numeric predictor and a curve preset. The task uses the first selected predictor for its one-dimensional curve. Presets are logistic, exponential, power and asymptotic. Logistic/asymptotic use self-starting functions; exponential/power use log-regression starting estimates where applicable.

The supported forms are:

| Preset | Form |
| --- | --- |
| Logistic | `Asym / (1 + exp((xmid - x) / scal))` |
| Exponential | `a * exp(b * x)` |
| Power | `a * x^b` |
| Asymptotic | `Asym + (R0 - Asym) * exp(-exp(lrc) * x)` |

The power curve requires strictly positive X and Y. At least five complete X/Y pairs are required. A poor range, unsuitable curve or inadequate starting behavior can prevent convergence; selecting another preset is a modelling decision rather than a guaranteed numerical repair.

The Puromycin example filters treated observations and fits a power curve. Its note explains that the preset is a fitting demonstration, not a biochemical mechanism. Outputs include coefficients, fit/fitted information, a fitted-curve plot/static image and an optional `nls` model. The displayed curve is evaluated on a grid over the observed predictor range; it is not a validated extrapolation beyond those data.

## Correlations {#task-correlations}

Select at least two numeric variables, or leave the variable choice blank to use eligible numeric columns. The task computes correlations with **pairwise complete observations** and returns a tidy pairs representation plus an optional raw matrix. It is a Pearson correlation calculation, not a UI selector for every possible association measure.

Pairwise completion can use different rows for different pairs. This is useful descriptively but means a matrix is not necessarily based on one common complete-case sample. Constant columns can yield undefined values. Numeric identifiers should not be included merely because they pass a type check.

The multivariate Iris example selects the four measurements explicitly and excludes the species label. Inspect scatter plots alongside correlations: a coefficient can conceal nonlinear shape, outliers or differences between groups. A high association does not establish direction of causation.

If a downstream method needs a mathematically suitable covariance/correlation matrix, verify that requirement rather than assuming every pairwise-complete matrix satisfies it. Use a Script for alternative methods, pairwise observation counts or a deliberately common analysis subset.

## Principal Components {#task-pca}

PCA selects at least two numeric fields, omits incomplete rows across those fields and calls `prcomp(..., scale. = TRUE)`. It returns explained-variance/scree information and loadings, with optional row scores, new-data scores and the fitted `prcomp` object.

Scaling is internal to this task. A constant variable can make scaling fail. Blank predictor selection can include every eligible numeric field, including an unwanted row identifier; explicit selection is safer for a documented analysis. Retain an identifier separately if you need to relate scores back to original observations after complete-case omission.

The Iris multivariate example uses its four measurements. Species is available for interpretation but is not a PCA predictor. Principal components summarize variation under the chosen scaling; they do not automatically identify causal biological dimensions or guarantee a useful predictive model.

For new-data scores, supply the required variables with compatible types. The fitted PCA object's centering/scaling is used rather than independently standardizing each new dataset. Inspect loadings and explained variation together. A component's sign can be arbitrary; interpret relationships and subspaces rather than treating a sign flip as a different scientific finding.

## Cluster Analysis {#task-cluster_analysis}

Choose at least two numeric fields, the number of clusters and **k-means** or **hierarchical** clustering. Incomplete rows across selected fields are omitted. K-means uses its configured nonnegative integer seed; hierarchical clustering uses Euclidean distances and a selected linkage: complete, single, average or Ward.D2.

The task does **not** automatically standardize all inputs. Variables in larger numerical units can dominate distances. Use Standardize Data beforehand when that is appropriate, and document why scaling is or is not desired. PCA and clustering therefore have different default scaling behavior in this app.

Outputs include a cluster-summary table, per-row assignments, fit information and an optional model (`kmeans` or `hclust`). Cluster labels are arbitrary identifiers, not ordered quality scores. Changing K, seed, method, scaling or input rows can change assignments.

The Iris example asks for three clusters using measurements, with species held aside. Three clusters need not reproduce the three species perfectly. Evaluate stability and usefulness rather than selecting K solely because you already know the label count. A hierarchical task's cluster summary is not automatically a dendrogram output; use the retained `hclust` model in Script/console for that custom visualization if needed.

## Reviewing a model as part of a project

Retain the input definition and observation count, meaningful model outputs, task configuration and relevant diagnostics. Include uncertainty and assumptions in a report. Use comments/review items to record unresolved analytical questions rather than presenting every generated table as approved.

When comparing runs, distinguish a changed model specification from changed data or package versions. A fresh fit with identical formulas can differ because a file refreshed or factor levels changed. Run records and a saved source table help identify that difference. Generated R carries the configured calculation, but it cannot reconstruct unavailable database contents or unrecorded external preprocessing.
