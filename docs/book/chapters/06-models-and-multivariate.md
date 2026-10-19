# Compare groups and fit models {#models}

A model describes a pattern in data. You do not need to write R to use these forms, but you do need to choose a method that fits your question. Start with an example whose question is close to yours.

A **response** is the result you want to explain or predict. **Predictors** are the columns you use to explain it. A **coefficient** describes part of the fitted relationship. A **fitted value** is the model's estimate for a row it used.

Run the input first. Check missing values and column types before selecting a model. After fitting, read warnings and the number of rows used. Use summaries and charts to check the data as well as the model output.

## One-Way ANOVA {#task-one_way_anova}

Use **One-Way ANOVA** to compare the means of a numeric response across groups.

Choose the response and one grouping column, then run the task. Check the group summaries before reading the test table. The p-value helps assess evidence that the group means are not all equal. It does not say which pairs differ or how large those differences are.

The method assumes a suitable study design and data pattern. Repeated measurements on the same person, for example, need more care than unrelated observations. **Plant growth - compare experimental groups** uses 30 plant weights in three groups. Open it to see the response, group choice, summary, and report together before trying your own comparison.

## t Test {#task-t_test}

Use **t Test** to compare a mean with a chosen value or compare two groups, depending on the mode you select.

Choose the input and numeric response. For a two-group test, choose the group column and check that it contains the intended two groups. Leaving the group blank gives a one-sample test against zero. The form does not offer a different comparison value, so use that choice only when zero answers your question.

Check the paired setting carefully. For paired data, choose the second measurement column; each row must contain a matched pair, such as before and after values from the same person. Two unrelated groups are not paired. Run the task and read the mean difference and interval alongside the p-value. **Plant growth - compare experimental groups** includes a two-group example using a prepared subset.

## Linear Models {#task-linear_models}

Use **Linear Models** to explain a numeric response using one or more predictors, including groups.

Choose the response, then the predictors or model terms the form requests. A group column should be stored as a category when its values name groups. Run the task and check the model terms and number of observations.

Read the coefficient and fit tables together. A coefficient for a group is usually a comparison with a reference group; it is not that group's raw mean in every model. The **Plant growth** example shows a model beside its group comparisons. Keep the model description in your report so a reader knows which predictors you included. A completed fit alone does not show that the model is useful.

## Linear Regression {#task-linear_regression}

Use **Linear Regression** to model a numeric response from selected predictors.

Choose the response and predictors, then enable the result tables you need. Run the task. Look at the coefficients, overall fit, fitted values, and residuals where offered. A residual is the observed value minus the fitted value.

The **Fuel economy model** example uses 32 cars and predicts fuel economy from weight and horsepower. In that dataset, weight is in thousands of pounds. Check those units before explaining a coefficient. A fit to these observations is not proof that changing one car feature will cause the predicted change. Try removing one predictor in a saved copy and compare both the model and its warnings.

## Logistic Regression {#task-logistic_regression}

Use **Logistic Regression** for a response with two possible outcomes, such as 0 and 1.

Choose the response and predictors. Check which outcome is coded as 1 before fitting. Run the task and inspect the fitted probabilities as well as coefficients. Probabilities range from zero to one. The coefficients use a different scale, so they are not direct percentage-point changes.

**Cars - binary outcome model** treats 1 as manual transmission and 0 as automatic. It is a useful way to check what a probability refers to. Read warnings about convergence or separation. These can mean the model cannot estimate the relationship reliably. A green task status does not make extreme estimates safe to use without checking them.

## Generalized Linear Models {#task-glm}

Use **Generalized Linear Models** when the response needs a model family other than ordinary numeric regression.

Choose the response, predictors, and **GLM family**. The family describes the kind of outcome. The form uses that family's standard link, which controls how predictors connect to the expected outcome. You do not choose a separate link here. Use a worked example or an analysis plan to guide the family choice.

**Loom breaks - a count model** uses a Poisson model for 54 counts of loom breaks. Counts are whole numbers of events, not percentages or rates. If exposure time differs between rows, the simple count example may not suit your question. Run the task and read warnings and fit information. A successful fit does not by itself show that the chosen family matches the data.

## Nonlinear Regression {#task-nonlinear_regression}

Use **Nonlinear Regression** to fit one of the supported curve forms to numeric measurements.

Choose the response, the predictor, and **Curve preset**. The task uses the first selected predictor and prepares its own starting values. Some curves require positive values, so inspect zeros and negative entries before running. Run the task, then compare the curve with the actual points.

**Puromycin - fit a nonlinear curve** uses positive concentration and reaction-rate values from a prepared subset. It shows a power curve as a teaching example. A different preset changes the model; it is not simply a repair button for a failed fit. If fitting fails, check valid input values and the selected form first. Be cautious about predictions beyond the observed range.

## Correlations {#task-correlations}

Use **Correlations** to measure how pairs of numeric columns vary together.

Choose the numeric columns and run the task. It calculates Pearson correlations, which describe straight-line relationships. It uses available pairs when values are missing. Compare the table with scatter plots. Values near 1 or -1 show a strong straight-line relationship. Values near zero do not rule out a curved pattern.

A correlation does not show that one value causes another. Groups and unusual points can also change the result. **Flowers - multivariate structure** compares the four Iris measurements. Inspect the species groups as well as the combined result. Check the number of usable observations when missing values mean different pairs use different rows.

## Principal Components {#task-pca}

Use **Principal Components** to combine several numeric columns into fewer summary directions. The task is often called PCA.

Choose only the numeric measurements you want to combine. The task scales them before fitting, so you do not need to select a scaling option. Run the task. Check the variance explained, which shows how much of the data's spread each component represents. Loadings show how the original columns contribute.

**Flowers - multivariate structure** uses the four flower measurements and keeps species labels out of that input set. It uses scaling inside PCA. A component is a calculated direction, not a new measurement with a simple original unit. Use its scores to explore patterns, then return to the original columns to explain them.

## Cluster Analysis {#task-cluster_analysis}

Use **Cluster Analysis** to group rows with similar numeric measurements.

Choose the measurement columns, the method, and the requested number of groups where needed. Set a seed for a repeatable random start. Check whether you need to standardize the inputs first: this task does not automatically put all columns on a common scale.

Run the task and inspect group sizes and assignments. Very small groups or results driven by one large-scale column need attention. **Flowers - multivariate structure** creates three clusters. Three requested clusters do not prove that the data contain three natural groups, and clusters need not match the known species. Compare the result with the source measurements and charts before giving the groups names.
