# Compare groups and fit models {#models}

A model describes a pattern in data. You do not need to write R to use these forms, but you do need to choose a method that fits your question. Start with an example whose question is close to yours.

A **response** is the result you want to explain or predict. **Predictors** are the columns you use to explain it. A **coefficient** describes part of the fitted relationship. A **fitted value** is the model's estimate for a row it used.

Run the input first. Check missing values and column types before selecting a model. After fitting, read warnings and the number of rows used. Use summaries and charts to check the data as well as the model output.

Use the [Task finder](#task-finder) to find each task's Add Task category. In its **Setup** tab, choose **Input table** before choosing columns. Near the top of the panel, keep the **Save** controls checked for the result tables you need. See [Task controls](#task-controls) if you are adding your first analysis task.

## One-Way ANOVA {#task-one_way_anova}

Use **One-Way ANOVA** to compare the means of a numeric response across groups.

1. Choose **Input table**, then select the measurement in **Response (numeric)**.
2. Select one **Group variable**. Check the group names and counts in the input table.
3. Select **Run** and open **Results**. Read the ANOVA table and the saved pairwise comparisons, if enabled.

The p-value in the ANOVA table helps assess evidence that the group means are not all equal. That overall test does not identify which pairs differ; the Tukey comparisons address pairs. Read the size of differences as well as their p-values.

The method assumes a suitable study design and data pattern. Repeated measurements on the same person, for example, need more care than unrelated observations. **Plant growth - compare experimental groups** uses 30 plant weights in three groups. Open it to see the response, group choice, summary, and report together before trying your own comparison.

## t Test {#task-t_test}

Use **t Test** to compare two groups, paired measurements, or a single mean against zero.

1. Choose **Input table** and **Response (numeric)**.
2. For two unrelated groups, choose **Group (optional — two levels)** and leave **Paired measurements** off. The input must contain exactly the two groups you mean to compare.
3. For matched pairs, select **Paired measurements** and **Second measurement (same row)**. Each row must contain one matched pair. Leave the group blank.
4. For a one-sample test against zero, leave the group blank and paired setting off. There is no control for a different comparison value.
5. Select **Run**, then open **Results**. Read the mean difference and interval alongside the p-value.

Check the paired setting carefully. For paired data, choose the second measurement column; each row must contain a matched pair, such as before and after values from the same person. Two unrelated groups are not paired. Run the task and read the mean difference and interval alongside the p-value. **Plant growth - compare experimental groups** includes a two-group example using a prepared subset.

## Linear Models {#task-linear_models}

Use **Linear Models** to explain a numeric response using one or more predictors, including groups.

1. Choose **Input table** and select the numeric **Response**.
2. Select **Predictors**. A group column should use a category type when its values name groups; check it with Characterize or Change Column Types first.
3. Select **Run**, then open **Results**. Check the coefficients, model fit, and number of observations used.

Read the coefficient and fit tables together. A coefficient for a group is usually a comparison with a reference group; it is not that group's raw mean in every model. The **Plant growth** example shows a model beside its group comparisons. Keep the model description in your report so a reader knows which predictors you included. A completed fit alone does not show that the model is useful.

## Linear Regression {#task-linear_regression}

Use **Linear Regression** to model a numeric response from selected predictors.

1. Choose **Input table**, then select **Response** and **Predictors**.
2. Keep the coefficient and model-fit outputs. Select **Save Fitted values (augment)** if you also want row-level fitted values and residuals. A residual is the observed value minus the fitted value.
3. Select **Run**, then open **Results**. Check the coefficients, fit, warnings, and the saved result tables.

![Linear Regression uses a response and selected predictors. Optional saved outputs include fitted values and a model object.](assets/ui-regression.png){#fig-regression}

The **Fuel economy model** example uses 32 cars and predicts fuel economy from weight and horsepower. In that dataset, weight is in thousands of pounds. Check those units before explaining a coefficient. A fit to these observations is not proof that changing one car feature will cause the predicted change. Try removing one predictor in a saved copy and compare both the model and its warnings.

## Logistic Regression {#task-logistic_regression}

Use **Logistic Regression** for a response with two possible outcomes, such as 0 and 1.

1. Choose **Input table**. In **Response (0/1)**, select a column coded with 0 and 1. Confirm what 1 means.
2. Choose **Predictors** and keep the output tables you need. Enable fitted values if you want row-level fitted results.
3. Select **Run**, then open **Results**. Inspect the coefficients and fit information; read warnings before interpreting the result.

Fitted probabilities range from zero to one. The coefficients use a different scale, so they are not direct percentage-point changes.

**Cars - binary outcome model** treats 1 as manual transmission and 0 as automatic. It is a useful way to check what a probability refers to. Read warnings about convergence or separation. These can mean the model cannot estimate the relationship reliably. A green task status does not make extreme estimates safe to use without checking them.

## Generalized Linear Models {#task-glm}

Use **Generalized Linear Models** when the response needs a model family other than ordinary numeric regression.

1. Choose **Input table**, **Response**, and **Predictors**.
2. Choose **GLM family** using a matching example or analysis plan. For example, **poisson** is used for counts in the Loom breaks example.
3. Select **Run**, then open **Results** and inspect warnings, coefficients, and fit information.

The family describes the kind of outcome. The form uses that family's standard link, which controls how predictors connect to the expected outcome. You do not choose a separate link here.

**Loom breaks - a count model** uses a Poisson model for 54 counts of loom breaks. Counts are whole numbers of events, not percentages or rates. If exposure time differs between rows, the simple count example may not suit your question. Run the task and read warnings and fit information. A successful fit does not by itself show that the chosen family matches the data.

## Nonlinear Regression {#task-nonlinear_regression}

Use **Nonlinear Regression** to fit one of the supported curve forms to numeric measurements.

1. Choose **Input table** and the numeric **Response (y)**.
2. Choose one numeric column in **Predictor (x — first selected used)**, then choose **Curve preset**. Start with the matching example's preset.
3. Check for zeros and negative entries; some curve forms require positive values. The task prepares its own starting values.
4. Select **Run**, then open **Results** and compare the fitted curve with the observed points.

**Puromycin - fit a nonlinear curve** uses positive concentration and reaction-rate values from a prepared subset. It shows a power curve as a teaching example. A different preset changes the model; it is not simply a repair button for a failed fit. If fitting fails, check valid input values and the selected form first. Be cautious about predictions beyond the observed range.

## Correlations {#task-correlations}

Use **Correlations** to measure how pairs of numeric columns vary together.

1. Choose **Input table** and select the wanted **Numeric variables**. Blank means all numeric columns, including any numeric IDs, so an explicit selection is often safer.
2. Select **Run** and open **Results**. The task calculates Pearson correlations using available pairs when values are missing.
3. Compare the table with Scatter Plots of interesting pairs. Values near 1 or -1 show a strong straight-line relationship. Values near zero do not rule out a curved pattern.

A correlation does not show that one value causes another. Groups and unusual points can also change the result. **Flowers - multivariate structure** compares the four Iris measurements. Inspect the species groups as well as the combined result. Check the number of usable observations when missing values mean different pairs use different rows.

## Principal Components {#task-pca}

Use **Principal Components** to combine several numeric columns into fewer summary directions. The task is often called PCA.

1. Choose **Input table**. In **Numeric variables**, select only the measurements you want to combine. Leave IDs and group codes out.
2. Keep the wanted outputs near the top of the panel. Enable **Save Component scores (augment)** if you need a component value for each row.
3. Select **Run**, then open **Results**. Check variance explained and loadings. The task scales the measurements automatically.

Variance explained shows how much of the data's spread each component represents. Loadings show how the original columns contribute.

**Flowers - multivariate structure** uses the four flower measurements and keeps species labels out of that input set. It uses scaling inside PCA. A component is a calculated direction, not a new measurement with a simple original unit. Use its scores to explore patterns, then return to the original columns to explain them.

## Cluster Analysis {#task-cluster_analysis}

Use **Cluster Analysis** to group rows with similar numeric measurements.

1. Choose **Input table** and the wanted **Numeric variables**. Standardize them first if a common scale is needed; this task does not do that automatically.
2. Choose **Method** and set **Clusters** to the requested number of groups.
3. For **k-means**, set **Random seed** so a rerun with the same data can repeat its random start. For **Hierarchical**, choose **Linkage** using your analysis plan or example.
4. Select **Run** and open **Results**. Inspect group sizes and the saved cluster assignments.

Run the task and inspect group sizes and assignments. Very small groups or results driven by one large-scale column need attention. **Flowers - multivariate structure** creates three clusters. Three requested clusters do not prove that the data contain three natural groups, and clusters need not match the known species. Compare the result with the source measurements and charts before giving the groups names.
