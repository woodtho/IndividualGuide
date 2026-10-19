# Clean and reshape your data {#preparing-data}

Keep an unchanged input table, then give each cleaned result a new name. This makes it easier to check what changed. After each task, compare row counts, column names, and a few values.

Before you start, run the tasks that supply your input tables. Choose **Add Task**, then **Data**, to find the tasks in this chapter. The [task controls guide](#task-controls) explains where to run a task and name its output.

## Append Table {#task-append_table}

Use **Append Table** to put rows from one table below rows from another. For example, you could combine January sales with February sales.

1. In **Tables to append**, select at least two tables.
2. Check that matching columns use the same units and compatible types. Use **Fill missing columns with NA** only if you want blanks where an input lacks a column.
3. Leave **Source ID column (.id)** blank, or enter a name if you want to identify which table supplied each row.
4. Enter an output table name and click **Run**.

The result contains the combined rows. Check its row count and any missing entries introduced by the fill option.

Appending adds rows. It does not match customer details across tables; use Query Builder for that. Open **Iris - reshape and compare** to see two species subsets combined into 100 rows.

## Compare Data {#task-compare_data}

Use **Compare Data** to check two tables for differences. It is useful after cleaning, importing a new extract, or reshaping data and changing it back.

1. Select **Table A (baseline)** and **Table B (comparison)**.
2. If the tables should be sorted before comparison, select their shared **Key columns**. Leave this blank to compare their current order.
3. Enter an output name and click **Run**.
4. Open **Results** and read the reported differences.

Selecting keys sorts the tables for comparison; it does not join their rows. Column types and attributes can differ even when the displayed values look similar.

If the tables have different row counts, first find why. A filter may have removed rows on purpose. The **Iris - reshape and compare** example compares a table before and after a reshape. Use its notes to see which differences are expected.

## Stack Columns {#task-stack_columns}

Use **Stack Columns** to turn several measurement columns into rows. This is often called making data long.

1. Select the **Input table**.
2. In **Columns to pivot (stack)**, select the measurement columns. Leave identifiers, such as `flower_id`, unselected so they remain beside the stacked values.
3. Enter the **New names column** and **New values column** names.
4. Name the output, click **Run**, and check the long table in **Results**.

In **Iris - reshape and compare**, four measurements for each of 150 flowers become 600 rows. A flower identifier shows which rows belong together. Keep that identifier if you may want to turn the table back into columns later. Extra rows are expected here; they do not mean you have more flowers.

![Stack Columns keeps unselected identifier columns and puts the selected measurements into two new columns: their names and values.](assets/ui-reshape.png){#fig-reshape}

## Split Columns {#task-split_columns}

Use **Split Columns** to turn long-form values back into separate columns. This is often called making data wide. Here, Split Columns means reshaping a table; check its settings rather than assuming it splits words at commas.

1. Select the **Input table** and its **ID columns (keep as rows)**.
2. In **Names from**, choose the column whose values should become headings.
3. In **Values from**, choose the measurement column.
4. Name the output and click **Run**. Check the new headings and row count in **Results**.

Each identifier and new-column pair should describe one value. If several rows claim the same place, inspect those rows before continuing. They may need a summary first. The **Iris - reshape and compare** example shows a full long-to-wide round trip using a flower identifier.

## Transpose {#task-transpose}

Use **Transpose** to turn rows into columns and columns into rows. It is most useful for a small table that needs a different display shape.

1. Prepare a small input first. Use **Keep / Drop Columns** and **First / Last N Rows** if you need a subset.
2. In Transpose, select the **Input table**.
3. Optionally select a **Row ID column** to supply the new headings.
4. Name the output and click **Run**. Inspect the new table and its headings.

Transpose uses the selected input table; it does not offer a separate measurement-column picker. Prepare that selection in an earlier task.

Start with a few rows. Transposing a large table can create a very wide result that is hard to view or export. Mixing text and numeric values may also change how values are stored. The **Iris - reshape and compare** example deliberately transposes a small numeric subset.

## Rank {#task-rank}

Use **Rank** to add positions such as first, second, and third based on a column's values.

1. Select the **Input table** and **Column to rank**.
2. For simple positions, choose **Minimum rank** or **Dense rank** in **Method**. Ties occur when rows have equal values. Other methods can return fractions or break ties by row order.
3. Set the **New column name**. Use **Group by** only if ranks should restart within each group.
4. Name the output and click **Run**.

The form ranks values in ascending order; it has no separate descending-order control. Minimum rank leaves gaps after a tie; Dense rank does not.

Check the highest and lowest values and at least one tie. A rank is a position, not the original measurement. Keep the original column if later work needs its values. The **Cars - rank, scale and sample** example shows ranked fuel economy.

## Standardize Data {#task-standardize}

Use **Standardize Data** when numeric columns need a common scale before a later analysis. For example, weight and length can have very different ranges.

1. Select the **Input table** and **Numeric columns to standardize**.
2. Choose **Z-score** or **Min-Max** under **Method**.
3. Leave **Group by** blank for the whole table, or select groups to scale separately.
4. Name the output and click **Run**.

Z-score subtracts the mean and divides by the standard deviation, a measure of spread. Min-Max puts the observed range on a scale from zero to one. Both change the units of the selected columns.

Check the output and keep the original table for reference. A constant column has no spread, so it needs attention before some scaling methods work. Open **Cars - rank, scale and sample** for an example. Scaling is a choice for a later analysis, not a routine fix for every dataset.

## Random Sample {#task-random_sample}

Use **Random Sample** to choose part of a table without simply taking the first rows. It can help you try a flow on less data.

1. Select the **Input table**.
2. Under **Sample by**, choose a row count or proportion, then enter the amount. A proportion of 0.1 means 10%.
3. Enter a **Seed** for a repeatable choice with the same data and order.
4. Choose whether to **Sample with replacement**, name the output, and click **Run**.

With replacement means the same source row may be picked more than once. Without replacement, choose an amount that fits the available rows.

Check the sample count. Do not treat a small practice sample as if it were the full dataset. The **Cars - rank, scale and sample** example picks ten rows with seed 2026. Try a different seed in a saved copy and compare which rows were chosen.

## Remove Duplicates {#task-remove_dups}

Use **Remove Duplicates** to remove repeated rows based on selected columns.

1. Select the **Input table**.
2. Under **Scope**, choose **All columns (exact row duplicates)** or **Key columns only (keep first by key)**.
3. If you chose keys, select the **Key columns** that define a duplicate.
4. Name the output and click **Run**.

The key option keeps the first matching row in the current order. Sort first if that choice matters. Rows with the same customer number can still describe different real events.

![Remove Duplicates can compare complete rows or selected keys. Choose the scope before checking how many rows were removed.](assets/ui-cleaning.png){#fig-cleaning}

Compare the row counts before and after. Inspect a few repeated cases if you are unsure. Two rows can look similar and still describe separate events, so do not remove them just to make the table smaller. **Cars - prepare an analysis table** adds one duplicate on purpose: its 33 source rows become 32 after this task.

## Keep / Drop Columns {#task-keep_drop_cols}

Use **Keep / Drop Columns** to choose which columns remain in a table.

1. Select the **Input table**.
2. Under **Action**, choose Keep or Drop.
3. Select the **Columns**. Keep retains only this selection; Drop removes it.
4. Give the output a new name and click **Run**.

Open the result and check its column names. Keep an ID column if later joins or checks need it. Removing a column from this output does not remove it from the unchanged source table. If a later task says a column is missing, check whether this step removed it. The **Cars - prepare an analysis table** example shows a smaller analysis table.

## Rename Columns {#task-rename_cols}

Use **Rename Columns** to make headings easier to understand.

1. Select the **Input table**.
2. Under **Rename pairs**, click **Add**.
3. Select the column to rename and enter its new name. Add another pair for each additional change.
4. Name the output, click **Run**, and check the headings in **Results**.

Use unique names. Short names with letters, numbers, and underscores are easy to use in later formulas.

Renaming changes the label, not the values or their units. A weight column does not become kilograms because you call it `weight_kg`. Add a calculation when you need a real conversion. Check later tasks after renaming because their selected columns may need to change too. **Cars - prepare an analysis table** includes a rename you can follow.

## First / Last N Rows {#task-first_last_n}

Use **First / Last N Rows** to keep a set number of rows from one end of a table.

1. Select the **Input table**.
2. Under **Rows to keep**, choose First or Last.
3. Enter the number of rows in **N**.
4. Name the output, click **Run**, and check the row count.

The table's current order decides which rows come first or last. Sort first if you want, for example, the ten largest sales.

This task is useful for a quick check or a short display. It is not a random sample. If the first rows all come from one date or group, they may give a poor picture of the whole table. See **Cars - prepare an analysis table** for a small selection.

## Replace Missing Values {#task-replace_missing}

Use **Replace Missing Values** when you have chosen a reason to fill unknown entries.

1. Select the **Input table**.
2. Select **Columns to fill**. A blank selection means all columns, so choose columns explicitly while learning.
3. Under **Fill with**, choose the method. Enter a **Replacement value** if you choose a fixed value.
4. Name the output and click **Run**. Check both the changed values and the number of missing entries left.

Keep the raw data and note the method you chose. Filling a gap does not recover the unknown original value. It can change summaries and models. **Air quality - clean and compare** uses mean replacement to teach the controls. That example is a practice choice, not a recommendation to fill every dataset that way. You can inspect the missing-value audit before changing anything.

## Recode Values {#task-recode_values}

Use **Recode Values** to replace selected values with new values or labels. For example, you might change 0 and 1 to **Automatic** and **Manual** in a display column.

1. Select the **Input table** and **Column to recode**.
2. Enter an **Output column name** if you want a separate labelled column.
3. Add the old-to-new value mappings. Check the Else setting for values you did not list.
4. Name the output table and click **Run**. Count the categories to check the changes.

Keep the original codes when you may need them for a later model. A model may expect numbers even when a chart is easier to read with words. **Cars - prepare an analysis table** shows labelled transmission values and how they relate to the original codes.

## Change Column Types {#task-change_types}

Use **Change Column Types** when values are stored in the wrong kind of column. Common types are text, number, date, and factor. A factor stores a set of categories.

1. Select the **Input table**.
2. Under **Type conversions**, click **Add**.
3. Select a **Column to convert** and its **Target type**. Repeat for other columns.
4. Name the output and click **Run**. Check types, values, and any new missing entries.

The form has no custom date-format field. Standard date text such as `2026-10-19` is the simplest input. If dates use another format, prepare them before converting or use a trusted Script for that conversion.

Keep identifiers as text when leading zeros matter. Use numeric types for real measurements and categories for group labels. **Cars - prepare an analysis table** changes a category's type. If a column is absent from a chart or model list, its current type is one of the first things to check.
