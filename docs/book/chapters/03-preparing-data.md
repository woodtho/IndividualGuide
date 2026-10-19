# Clean and reshape your data {#preparing-data}

Keep an unchanged input table, then give each cleaned result a new name. This makes it easier to check what changed. After each task, compare row counts, column names, and a few values.

## Append Table {#task-append_table}

Use **Append Table** to put rows from one table below rows from another. For example, you could combine January sales with February sales.

Choose the tables and check that matching columns mean the same thing. A column called `amount` should use the same units in both. Choose the output name and run the task. Check the final row count and any blank values caused by columns that were only present in one input.

Appending adds rows. It does not match customer details across tables; use Query Builder for that. Open **Iris - reshape and compare** to see two species subsets combined into 100 rows.

## Compare Data {#task-compare_data}

Use **Compare Data** to check two tables for differences. It is useful after cleaning, importing a new extract, or reshaping data and changing it back.

Select the two tables. Review the comparison settings, including any key or row-matching choices offered. Run the task and read the differences rather than only checking whether it finished. A changed row order or column type can matter even when the displayed values look similar.

If the tables have different row counts, first find why. A filter may have removed rows on purpose. The **Iris - reshape and compare** example compares a table before and after a reshape. Use its notes to see which differences are expected.

## Stack Columns {#task-stack_columns}

Use **Stack Columns** to turn several measurement columns into rows. This is often called making data long.

Choose the input, the columns to stack, and the columns to keep as identifiers. Set names for the new measurement-name and measurement-value columns. Run the task and check that each original observation can still be identified.

In **Iris - reshape and compare**, four measurements for each of 150 flowers become 600 rows. A flower identifier shows which rows belong together. Keep that identifier if you may want to turn the table back into columns later. Extra rows are expected here; they do not mean you have more flowers.

## Split Columns {#task-split_columns}

Use **Split Columns** to turn long-form values back into separate columns. This is often called making data wide. Here, Split Columns means reshaping a table; check its settings rather than assuming it splits words at commas.

Choose the identifier columns, the column whose values will become column names, and the column containing the measurements. Run it and check the output names and row count.

Each identifier and new-column pair should describe one value. If several rows claim the same place, inspect those rows before continuing. They may need a summary first. The **Iris - reshape and compare** example shows a full long-to-wide round trip using a flower identifier.

## Transpose {#task-transpose}

Use **Transpose** to turn rows into columns and columns into rows. It is most useful for a small table that needs a different display shape.

Select the input and the columns you want to transpose. Check naming choices, run the task, and inspect the new table. Make sure the new column headings still tell the reader what each value means.

Start with a few rows. Transposing a large table can create a very wide result that is hard to view or export. Mixing text and numeric values may also change how values are stored. The **Iris - reshape and compare** example deliberately transposes a small numeric subset.

## Rank {#task-rank}

Use **Rank** to add positions such as first, second, and third based on a column's values.

Choose the input and ranking column. Select the order and the method for ties. Ties occur when two rows have equal values. Different methods can give those rows the same rank or leave gaps after them.

Run the task with a new output name. Check the highest and lowest values and at least one tie. A rank is a position, not the original measurement. Keep the original column if later work needs its values. The **Cars - rank, scale and sample** example shows ranked fuel economy.

## Standardize Data {#task-standardize}

Use **Standardize Data** when numeric columns need a common scale before a later analysis. For example, weight and length can have very different ranges.

Choose the numeric columns and the scaling method. Read the method's label before running it. A common method subtracts the mean and divides by the standard deviation, which measures spread. The result then uses a new scale instead of the original units.

Run the task and check the output. Keep the original table for reference. A constant column has no spread, so it needs attention before some scaling methods work. Open **Cars - rank, scale and sample** for an example. Scaling is a choice for a later analysis, not a routine fix for every dataset.

## Random Sample {#task-random_sample}

Use **Random Sample** to choose part of a table without simply taking the first rows. It can help you try a flow on less data.

Choose the input, sample size, and any replacement setting. With replacement means the same row may be picked more than once. Set a **seed** if you want to repeat the same random choice with the same data and order.

Run the task and check the sample count. Do not treat a small practice sample as if it were the full dataset. The **Cars - rank, scale and sample** example picks ten rows with seed 2026. Try a different seed in a saved copy and compare which rows were chosen.

## Remove Duplicates {#task-remove_dups}

Use **Remove Duplicates** to remove repeated rows based on selected columns.

Choose the columns that define a duplicate. All columns means only fully repeated rows match. A smaller key, such as customer number, can also match rows whose other values differ. Check which row will be kept before running.

Run the task, then compare the row counts before and after. Inspect a few removed cases if you are unsure. Two rows can look similar and still describe separate events, so do not remove them just to make the table smaller. **Cars - prepare an analysis table** adds one duplicate on purpose: its 33 source rows become 32 after this task.

## Keep / Drop Columns {#task-keep_drop_cols}

Use **Keep / Drop Columns** to choose which columns remain in a table.

Select the input, choose Keep or Drop, then select the columns. Keep retains only those selected. Drop removes the selected columns. Give the result a new name and run it.

Open the result and check its column names. Keep an ID column if later joins or checks need it. Removing a column from this output does not remove it from the unchanged source table. If a later task says a column is missing, check whether this step removed it. The **Cars - prepare an analysis table** example shows a smaller analysis table.

## Rename Columns {#task-rename_cols}

Use **Rename Columns** to make headings easier to understand.

Choose the input and add each old name with its new name. Use unique names. Short names with letters, numbers, and underscores are easy to use in later formulas. Run the task and check the result's headings.

Renaming changes the label, not the values or their units. A weight column does not become kilograms because you call it `weight_kg`. Add a calculation when you need a real conversion. Check later tasks after renaming because their selected columns may need to change too. **Cars - prepare an analysis table** includes a rename you can follow.

## First / Last N Rows {#task-first_last_n}

Use **First / Last N Rows** to keep a set number of rows from one end of a table.

Choose the input, First or Last, and the number of rows. Run it and check the result. The table's current order decides which rows count as first or last. Sort first if you want, for example, the ten largest sales.

This task is useful for a quick check or a short display. It is not a random sample. If the first rows all come from one date or group, they may give a poor picture of the whole table. See **Cars - prepare an analysis table** for a small selection.

## Replace Missing Values {#task-replace_missing}

Use **Replace Missing Values** when you have chosen a reason to fill unknown entries.

Select the input, the columns, and a replacement method. Depending on the column and method, you may enter a value or choose a calculated value such as a mean. Run it and count how many missing entries remain.

Keep the raw data and note the method you chose. Filling a gap does not recover the unknown original value. It can change summaries and models. **Air quality - clean and compare** uses mean replacement to teach the controls. That example is a practice choice, not a recommendation to fill every dataset that way. You can inspect the missing-value audit before changing anything.

## Recode Values {#task-recode_values}

Use **Recode Values** to replace selected values with new values or labels. For example, you might change 0 and 1 to **Automatic** and **Manual** in a display column.

Choose the column and add the old-to-new mappings. Check what should happen to values you did not list. Run the task and count each category to make sure no group was lost or changed by accident.

Keep the original codes when you may need them for a later model. A model may expect numbers even when a chart is easier to read with words. **Cars - prepare an analysis table** shows labelled transmission values and how they relate to the original codes.

## Change Column Types {#task-change_types}

Use **Change Column Types** when values are stored in the wrong kind of column. Common types are text, number, date, and factor. A factor stores a set of categories.

Select the column and its intended type. For dates, check the date format. Run the task, then inspect both the type and the values. Check for new missing values, which can mean some entries could not be converted.

Keep identifiers as text when leading zeros matter. Use numeric types for real measurements and categories for group labels. **Cars - prepare an analysis table** changes a category's type. If a column is absent from a chart or model list, its current type is one of the first things to check.
