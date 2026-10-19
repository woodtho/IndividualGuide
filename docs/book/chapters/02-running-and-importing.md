# Run tasks and check results {#running}

Start with one task while you are learning. Once each step works, run the whole flow.

## Run, Preview, and Save do different jobs

| Action | What it does |
| --- | --- |
| Preview | Lets you inspect a trial result where the task supports it |
| Run or Run & Save | Runs the task and keeps its result in the project |
| Run flow | Runs connected tasks in the active flow |
| Save project | Writes your project to its .igpx file |

After a Preview, use Run to keep the result. After running, use Save to keep the project on disk. A Script can write outside files even during a preview, so preview only code you trust.

## Check the task status

A successful status means the task finished. Open its result to make sure it answered your question. An error means it needs attention. Open its Log and read the first useful error message.

A stale result means an input or setting has changed since that result was made. Run the affected task and the later tasks that use it. An old report may still open while it waits to be rebuilt.

A skipped task may belong to a branch that was not chosen. A waiting task may need an earlier task to finish. Check inputs and branch settings before treating either state as a failure.

## Run the right part of a project

Use the flow's play button to run the active flow. Check which flow is selected if your project has more than one. Right-click a task for **Run to here** or **Run from here** when those actions are available. These follow task connections, rather than the positions of shapes on the screen.

Use **Validate active flow** to check for missing inputs and other setup problems before a long run. Validation checks the setup. It cannot prove that your data or conclusions are correct.

## Stop a run

Use **Stop** or **Task > Stop run** in the desktop app. Some work may need to finish its current step before it can stop. Wait for the status to change before starting another run.

Stopping does not undo files that tasks already wrote. Check export folders before running again. If you want to avoid replacing files, use new filenames or turn off Overwrite.

# Importing your data {#importing}

For a first import, use a small CSV or Excel sheet with one header row. Give every column a name. Keep titles, footnotes, and totals outside the data area.

## Import Data {#task-import_data}

Use **Import Data** to bring a file or database table into the project.

1. Add the task from Data. Choose the file type and select your file.
2. For CSV or other text files, check the separator, header, and text encoding. A separator is the character between columns, often a comma or tab.
3. For Excel, choose the sheet and any row or range settings you need.
4. Check the preview. Each field should be in its own column, with the right names and values.
5. Choose a clear output name, such as `sales_raw`, and run the task.

Open the new table and check its row count. Check dates, missing values, and identifiers such as postal codes. If an ID starts with zero, keep it as text so the zero is not lost.

If all values land in one column, check the separator. If the names become the first data row, check the header setting. If letters look wrong, try the file's text encoding. The **US states - import, join and filter** example uses a real bundled CSV that you can inspect without finding your own file.

## Work with a database

Choose the database source in Import Data and select or set up its connection. You may need an address, database name, account, and a driver from your database provider. Ask the person who manages the database for these details.

Start with a small table or query. A live database result may still need its connection when later tasks run. If you need a fixed copy for a report, make sure the data have been loaded into the project and record when you took the copy.

The Windows app includes its normal app packages. An R-only installation may need a database package and a separate system driver. The [optional R setup](#install-with-r) explains where to get packages. Do not put passwords in a report, log message, or shared Script.

# Select, join, and calculate data {#queries}

These tasks help you choose the rows and columns you need. Run the input task first so column lists can show its results.

## Query Builder {#task-query_builder}

Use **Query Builder** when you need to choose columns, join tables, filter rows, or make grouped totals in one task.

Select the input tables, then choose the columns to keep. Add a join only when you need columns from another table. A join matches rows using a shared key, such as a customer number. Pick the key on both sides and choose the join type. A left join keeps the rows from the first table and adds matches from the second.

Preview the result and check its row count. When it looks right, run the task to keep the result. If a key appears several times in both tables, a join can produce more rows than you expected. Check keys before calculating totals.

For grouped results, choose the group columns and a calculation such as sum or mean. Filters before grouping choose input rows. A filter on the finished group result chooses which totals remain. Start with the **US states** example to see a join and a filter together.

## Filter and Sort {#task-filter_sort}

Use **Filter and Sort** to keep matching rows and put them in order.

Choose the input table. Add a rule by selecting a column, a comparison, and a value. For example, a numeric amount greater than 100 keeps rows above that amount. Check whether several rules should all match or whether any one may match.

Choose one or more sort columns and their order. Ascending goes from smaller to larger, or A to Z. Descending reverses that order. Run the task with a new output name and check a few rows at the top and bottom.

Missing values need their own rule. A missing value is an unknown entry, not the same as zero or an empty word. Use the missing-value choice when you mean to select those rows. The **US states** example shows how filtering changes the final table.

## Derive Columns {#task-derive_cols}

Use **Derive Columns** to add a calculated column, such as a total or a value converted to new units.

Choose the input, enter a new column name, and enter its formula. A simple formula can use existing column names and arithmetic. For example, if the input has columns named `price` and `quantity`, `price * quantity` calculates their product for each row.

Start with one new column. Run the task and check a few values by hand. Then add other calculations if needed. Keep units clear: changing the column name alone does not convert centimetres to metres.

Formulas use R expressions, so names and punctuation matter. Copy a working formula from a matching example when you are unsure. The **Cars - prepare an analysis table** example shows a calculated field. You can skip this task until you need a calculation that simpler tasks do not provide.

# Optional: saved code steps {#scripts}

## Script {#task-script}

Use **Script** when you have trusted R code to run as part of a flow. You can complete many projects using the other task forms instead.

Select the input tables the code needs. Paste code into the Script editor. In the output list, declare each result you want to keep, using exactly the name used by the code. For a data table, choose a table output. A model or other non-table result needs an object output.

Run the task and check Results and Log. If a result is missing, first compare its declared name with the code. Names are case-sensitive: `Flowers` and `flowers` are different.

The first-project exercise includes a two-line Script you can copy. The examples also contain prepared Scripts with notes. Read those notes before changing their code. Use the [R Console](#console) for a quick trial, then keep repeatable code in a Script task. A console command on its own does not become a saved step in the flow.
