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

A successful status means the task finished. Open its result to make sure it answered your question. An error means it needs attention. Expand **Logging** and read its recorded error entries.

A stale result means an input or setting has changed since that result was made. Run the affected task and the later tasks that use it. An old report may still open while it waits to be rebuilt.

A skipped task may belong to a branch that was not chosen. A waiting task may need an earlier task to finish. Check inputs and branch settings before treating either state as a failure.

## Run the right part of a project

Use the flow's play button to run the active flow. Check which flow is selected if your project has more than one. Right-click a task for **Run to here** or **Run from here** when those actions are available. These follow task connections, rather than the positions of shapes on the screen.

1. In the desktop app, choose **Task > Validate active flow...** before a long run. In a browser, select **Validate active flow** in the app header.
2. Read the listed problems. Close the dialog and correct any missing inputs or invalid settings.
3. Validate again. Once the setup is ready, choose **Task > Run active flow** or use the flow's play button.

Validation checks the setup. It cannot prove that your data or conclusions are correct.

![Validation lists problems or information about checks that will run later. Read each message and resolve blocking items before continuing.](assets/ui-validation.png){#fig-validation}

## Stop a run

Use **Stop** or **Task > Stop run** in the desktop app. Some work may need to finish its current step before it can stop. Wait for the status to change before starting another run.

Stopping does not undo files that tasks already wrote. Check export folders before running again. If you want to avoid replacing files, use new filenames or turn off Overwrite.

# Importing your data {#importing}

For a first import, use a small CSV or Excel sheet with one header row. Give every column a name. Keep titles, footnotes, and totals outside the data area.

## Import Data {#task-import_data}

Use **Import Data** to bring a file or database table into the project.

1. Select **Add Task > Data > Import Data**. Under **Setup**, choose **File** in **Source**.
2. Select **Browse...** and choose your file. The app detects its type from the selected file.
3. For CSV or other text files, check **Delimiter** and **First row is header**. A delimiter separates columns, often with a comma or tab. Open **More file settings** only if you need to change options such as text encoding.
4. For Excel, choose the sheet and any row or range settings shown after selecting the file.
5. Select **Preview**. Each field should be in its own column, with the right names and values.
6. Enter a clear **Output table name**, such as `sales_raw`, then select **Run import**.

![Import Data detects the selected CSV and offers delimiter and header settings. Preview it before running the import.](assets/ui-import.png){#fig-import}

Open the new table and check its row count. Check dates, missing values, and identifiers such as postal codes. If an ID starts with zero, keep it as text so the zero is not lost.

Selecting a different file suggests a new output name based on that filename. Check **Output table name** again before rerunning an existing import. Later tasks still need the name they were set up to use.

If all values land in one column, check the separator. If the names become the first data row, check the header setting. If letters look wrong, try the file's text encoding. The **US states - import, join and filter** example uses a real bundled CSV that you can inspect without finding your own file.

### Keep zeros at the start of an ID

Use this when a CSV contains IDs such as `001` and you need to preserve their exact text.

1. Select the CSV, then open **More file settings**.
2. In **col_types**, type one lowercase `c` for each column, without spaces or quotes. Use `cc` for a two-column file or `cccc` for four columns. Each `c` tells the app to read that column as text.
3. Preview the file and check that `001` still has its zeros. Confirm the output name, then select **Run import**.
4. Use **Change Column Types** afterwards to convert measurement columns to numeric. Leave the ID column as text.

Use this option only when you need it. Reading every column as text means measurements need conversion before numeric charts or models can use them.

## Work with a database

Ask the person who manages the database for its connection details and a small table to practise with. A **driver** lets the app connect to that kind of database. A **DSN** is a named connection set up on your computer.

1. In **Import Data > Setup**, choose **Database** in **Source**.
2. If a suitable **Saved connection** exists, select it and choose **Load**. Otherwise, choose **Form** under **Connection** and enter a clear **Connection name**.
3. Choose **Driver** using your database contact's advice. For a SQLite file, choose **RSQLite::SQLite()** and enter its full path in **Database / file**. For ODBC, choose **odbc::odbc()** and use the supplied **DSN** or connection details.
4. Open **More connection settings** if you need **Host**, **Port**, or **User**. Enter a password only when the app requests it during connection.
5. Enter **Table** and **Schema**, if required. Use **Use SQL query** only when you have a suitable query to paste into **SQL**.
6. For a small, fixed practice copy, check **Collect into memory immediately**. This loads the result and closes the connection. Leave it off only when you intend to keep a live database reference.
7. Set **Output table name**, select **Preview**, and check the columns. Select **Run import**, then check the saved table and row count.

Start with a small table or query. A live database result still needs its connection when later tasks use it. Record the date of a fixed copy when that matters to your report. A failed connection may mean an incorrect address, missing driver, or account restriction; use the exact error when asking your database contact for help.

The Windows app includes its normal app packages. An R-only installation may need a database package and a separate system driver. The [optional R setup](#install-with-r) explains where to get packages. Do not put passwords in a report, log message, or shared Script.

# Select, join, and calculate data {#queries}

These tasks help you choose the rows and columns you need. Run the input task first so column lists can show its results.

## Query Builder {#task-query_builder}

Use **Query Builder** when you need to choose columns, join tables, filter rows, or make grouped totals in one task.

1. Select **Add Task > Data > Query Builder**. In **Select Data**, choose the **Primary input table**.
2. Use the plus buttons under **Available columns** to add columns to **Selected columns**. Use **All** if you need every column.
3. If you need another table, open **Join Tables > Add join**. Choose the **Right table**, **Join type**, and matching key columns, then select **Add join** in the dialog.
4. Use **Filter Data > Add condition** to keep matching rows. Use **Sort Data > Add sort** to choose their order.
5. Enter an **Output table name**. Select **Preview (1 000 rows)** and inspect **Results**, then select **Run & save** to keep the full result.

A join matches rows using a shared key, such as a customer number. A left join keeps the rows from the first table and adds matches from the second.

![Query Builder separates column selection, filters, sorting, and joins into tabs. Add wanted columns to Selected columns before previewing.](assets/ui-query.png){#fig-query}

Preview the result and check its row count. When it looks right, run the task to keep the result. If a key appears several times in both tables, a join can produce more rows than you expected. Check keys before calculating totals.

For grouped results, set a selected value column's calculation to **SUM** or **AVG**. AVG means mean. The other selected columns without a calculation define the groups. **Filter Data** chooses input rows; **Having** filters the calculated group results. Start with the **US states** example to inspect a saved join result.

## Filter and Sort {#task-filter_sort}

Use **Filter and Sort** to keep matching rows and put them in order.

1. Select **Add Task > Data > Filter and Sort**, then choose **Input table** in the task header.
2. Under **Filter Data**, select **Add condition**. Choose the column, operator, and value. For example, an amount greater than 100 keeps rows above that amount.
3. If you add more conditions, check their **AND** or **OR** choice. AND needs both rules to match; OR needs at least one.
4. Under **Sort Data**, select **Add sort**. Choose the sort column and direction. Ascending goes from smaller to larger, or A to Z; descending reverses that order.
5. Enter an **Output table name**, select **Run & Save**, and open **Results**. Check a few rows at the top and bottom.

Missing values need their own rule. A missing value is an unknown entry, not the same as zero or an empty word. Use **IS NULL** to select missing values, or **IS NOT NULL** to keep known values.

**Release 0.4.0 note:** opening the saved Filter and Sort step in **US states - import, join and filter** can disconnect the workspace. Inspect its saved output instead, or add a fresh Filter and Sort task using the steps above. Save first. If needed, use the [restart steps](#troubleshooting).

## Derive Columns {#task-derive_cols}

Use **Derive Columns** to add a calculated column, such as a total or a value converted to new units.

1. Select **Add Task > Data > Derive Columns** and choose **Input table**.
2. Select **Add**. Enter **New column name** and **R expression for new column**. For example, if your table has `price` and `quantity`, enter `total` and `price * quantity`.
3. Enter an **Output table name** and select **Run & Save**.
4. Open **Results** and check the new column against a few values you calculate yourself.

Start with one new column. Run the task and check a few values by hand. Then add other calculations if needed. Keep units clear: changing the column name alone does not convert centimetres to metres.

Formulas use R expressions, so names and punctuation matter. Copy a working formula from a matching example when you are unsure. The **Cars - prepare an analysis table** example shows a calculated field. You can skip this task until you need a calculation that simpler tasks do not provide.

# Optional: saved code steps {#scripts}

## Script {#task-script}

Use **Script** when you have trusted R code to run as part of a flow. You can complete many projects using the other task forms instead.

1. Select **Add Task > General > Script**. Under **Setup**, choose any **Input tables / special outputs** the code needs. These choices tell the flow which earlier results to wait for.
2. Paste trusted code into **R code**. The [first-project exercise](#first-project) supplies a complete two-line example.
3. In **Outputs**, put each result on a separate line as `name: kind`. For a table called flowers, type `flowers: table`. For a model called fit, type `fit: model`.
4. Select **Run**, then check the saved results and recorded entries under **Logging**.

Run the task and check Results and Log. If a result is missing, first compare its declared name with the code. Names are case-sensitive: `Flowers` and `flowers` are different.

The first-project exercise includes a two-line Script you can copy. The examples also contain prepared Scripts with notes. Read those notes before changing their code. Use the [R Console](#console) for a quick trial, then keep repeatable code in a Script task. A console command on its own does not become a saved step in the flow.
