# Your first project {#first-project}

Start with an example that already works. You will open flower data, find a chart, check a report, and save your own copy. No typing of R code is needed for this first part.

## Open the flower example

1. If the welcome screen is still open, choose **Start with a blank canvas**.
2. In the desktop app, choose **Help > Application help**. In a browser, select the **Help** button in the app header.
3. Open **Example projects** and search for **Iris exploration**.
4. Choose **Open example**. If an unsaved-work prompt appears, choose **Cancel** and save your current work before trying again. In the desktop prompt, **Discard** replaces the current work; the browser app calls this **Discard and open example**.
5. Choose **File > Save project as...**. Save the project as `flower-practice.igpx` in your projects folder. In a browser, select **Save project** and choose the name and folder in the file picker that opens for this unsaved example.

Iris is a kind of flower. The example has measurements from **150 flowers** in **three species**, with **50 flowers per species**. Each row is one flower. The four measurement columns use centimetres. `Species` names the flower's group.

Opening an example gives you a separate working copy. You can change it without changing the example that ships with the app. Save your copy if you want to keep those changes.

An example may show a software-version notice because its saved run came from another setup. You can inspect the saved results first. Before rerunning, check the export folders, then use the new task logs to check how the work runs on your computer. The [review tools](#review) explain run records if you need to compare versions.

## Look around before running anything

The left side lists the project's tasks and data. The **Flow** tab shows connected steps. Select the source task and read its notes. Open its flower table and look at the column names.

The example uses labels that describe each step's job. Select **Summarize measurements**, **Compare mean petal length by species**, and **Explore relationships** to open the Summary Statistics, Summary Tables, and Scatter Plot tasks. The task type appears in each panel. Open **Results** to inspect the saved result before running anything again. Names given to steps within a project stay in their original language.

![Callout 1 marks the project tree; 2 marks the connected flow; 3 marks the Flow, Code, and R Console tabs. Select a task to open its settings.](assets/ui-workspace.png){#fig-workspace}

For the species summary, the mean petal lengths should be about:

| Species | Mean petal length, in centimetres |
| --- | ---: |
| setosa | 1.462 |
| versicolor | 4.260 |
| virginica | 5.552 |

You do not need to memorize these values. They give you a way to check that you are viewing the right table and settings.

![The flower example compares sepal length and petal length. Colour shows the species.](assets/iris-chart.png){#fig-iris-chart}

## Make one small change

1. Open the **Scatter Plot** task.
2. Under **Setup**, change **Y / value** from `Petal.Length` to `Petal.Width`.
3. Scroll down within **Setup**. Change **Title** to **Petal width by sepal length**. Set **Y label** to **Petal width (cm)**.
4. Click **Run** in the task header. Open Results and check the new chart.
5. Open the **Report** task and select **Generate Report** so its chart matches your change.
6. Choose **File > Save project** or press Ctrl+S.

Check that the vertical axis is labelled **Petal width (cm)**. The source petal widths range from 0.1 to 2.5 centimetres.

![Start from these Scatter Plot settings and change Y / value to Petal.Width. Save Static ggplot image keeps a picture for the report.](assets/ui-chart-settings.png){#fig-chart-settings}

Changing a setting does not update a saved report by itself. Run the changed task, then the later tasks that use its result. If you want to run everything again, use the flow's play button. Before doing that, check the Export tasks' folders and Overwrite settings.

## Find the report and log

1. Open the **Report** task. Under **Appearance**, select **Include pipeline log in the report**.
2. Select **Generate Report**, then **Download HTML**. Save the file in your projects folder and open it in a browser.
3. Check its headings, tables, chart, and **Pipeline execution log** section. The downloaded report is a separate file from the project.

Open **Export Log** to see how the example writes its log to a file. Before running this task, choose a destination you can find. Logs can include earlier runs as well as the latest one. Dates and times help you tell them apart.

## Build a small flow yourself

This optional exercise builds the same kinds of results from a new project. It includes one short piece of R code that you can copy exactly. You do not need to understand the code to finish the exercise. Stay with the ready-made examples if you prefer.

Start with an empty project. In the Windows app, choose **File > New project** and save it as `first-iris.igpx`. In a browser, save your current work, refresh the page, and choose **Start with a blank canvas**. Then use **Save project** to create `first-iris.igpx`.

Use **Add Task** to find each task below. Task labels help you recognize a step. Output names tell later steps which result to use, so type those names carefully.

### Step 1: load the practice data

1. Select **Add Task**, open **General**, and choose **Script**.
2. In the task header, set **Primary table** to `flowers`.
3. Under **Setup**, leave **Input tables / special outputs** blank. This step supplies its own data.
4. In **Outputs**, type `flowers: table` on one line. This tells the app to keep a table named `flowers`.
5. Paste the following into **R code**, not the R Console:

```r
flowers <- datasets::iris
log_event(sprintf("Loaded %d flowers", nrow(flowers)), "INFO")
```

![In Outputs, flowers: table declares the table to keep. Its name matches flowers in the copied code.](assets/ui-script-outputs.png){#fig-script-outputs}

Click **Run**. Select `flowers` under **DATASETS** in the project tree and check for 150 rows and five columns. If it is missing, make sure Outputs contains `flowers: table`. The name must match the name in the copied code.

### Step 2: summarize the measurements

1. Select **Add Task > Describe > Summary Statistics**.
2. Under **Setup**, select `flowers` in **Input table**.
3. In **Numeric columns**, choose `Sepal.Length`, `Sepal.Width`, `Petal.Length`, and `Petal.Width`.
4. Leave **Save** checked and enter `measurement_summary` in **Output table**.
5. Select **Analyze**, then open **Results**.

![Summary Statistics needs an input table and numeric columns. The Save checkbox keeps its Output table for later tasks.](assets/ui-summary-settings.png){#fig-summary-settings}

Under **Results**, select **Data** to read the saved table. Check the mean for `Sepal.Length`. It should be about **5.8433**. A mean is the total divided by the number of values. The app may show fewer decimal places.

### Step 3: compare the three species

1. Select **Add Task > Describe > Summary Tables**.
2. Under **Setup**, choose these settings:

| Setting | Choice |
| --- | --- |
| Input table | `flowers` |
| Row variable | `Species` |
| Value variable | `Petal.Length` |
| Summary statistic | Mean |
| Output table | `species_summary` |

3. Leave **Save** checked and select **Analyze**.
4. Open **Results > Data** and compare the three means with the table earlier in this chapter.

### Step 4: draw the chart

1. Select **Add Task > Graph > Scatter Plot** and choose `flowers` in **Input table**.
2. Set **X / category / date** to `Sepal.Length`, **Y / value** to `Petal.Length`, and **Group / colour** to `Species`.
3. Set **Title** to **Iris measurements by species**.
4. Near the top of the panel, check **Save Static ggplot image**. Set **Output name for Static ggplot image** to `iris_scatter_image`.
5. Select **Run** and open **Results**. Check for a chart like [Figure](#fig-iris-chart).

A static image is a still chart that you can put in a report or export as PNG. The word ggplot names the chart tool; you do not need to learn it.

### Step 5: save a table and chart as files

1. Select **Add Task > Output > Export**. Choose `species_summary` in **Output to export** and CSV in **Format**.
2. Select **Choose folder…** and choose your projects folder. In **File name (without extension)**, type `species-summary`.
3. Select **Export** and check for `species-summary.csv` in that folder.
4. Add another Export task. Select `iris_scatter_image`, choose PNG, and use the same folder.
5. Enter `iris-scatter` without the file ending. Set **DPI** to 150, select **Export**, and open `iris-scatter.png`.

DPI controls how many dots are used per inch. Check the text in the finished image before sharing it.

An existing file can block an export. Choose a new name, or enable **Overwrite if the file already exists** when you mean to replace it. An exported file is separate from your saved project.

### Step 6: make a report

1. Select **Add Task > Output > Report**. Under **Content**, add `measurement_summary`, `species_summary`, and `iris_scatter_image`. Give the items clear section headings.
2. Under **Appearance**, choose HTML in **Output format** and set **Report title** to **First Iris report**.
3. Select **Include pipeline log in the report** and leave **Minimum log level** at INFO.
4. Select **Generate Report**, then **Download HTML**. Open the downloaded file and check for the two tables, the chart, and **Pipeline execution log**.

### Step 7: save the log

A full path includes the folder address and filename together. Use your own projects folder; the practice folder shown in screenshots is only an example.

1. Select **Add Task > Output > Export Log**.
2. In **Run after and include these tasks**, select the preceding tasks, including Report, so it waits for them.
3. Choose CSV. In **Destination file path**, enter the full path to `iris-log.csv` inside your projects folder. For example, use the folder's address from Windows File Explorer, followed by `/iris-log.csv`.
4. Run the active flow. Open the CSV and check for **Loaded 150 flowers** and the Report completion entry.

The report's own log section is made before the report finishes. The final Export Log can record that later completion.

### Step 8: close and reopen your work

1. Choose **File > Save project** to save `first-iris.igpx`.
2. Choose **File > Close project**, then **File > Open project...** and select that file. In a browser, use **Open project** in the app header after saving.
3. Check that its table, chart, and report are still there. You have made a reusable flow with data, results, a report, and a log.

# Find your way around {#workspace}

The project list, flow diagram, and task panels show the same work in different ways. Use whichever makes the next step easiest to find.

## Open a task or result

Select a task in the project list or flow to open its panel. Its settings control what it does. Results show what happened when it last ran. Expand **Logging** to read recorded entries and set messages. **Code**, where offered, shows the R instructions; reading it is optional.

Closing a task tab hides that panel. It does not delete the task. Use the task's delete action only when you want to remove the step itself.

If the diagram becomes crowded, choose **View > Task list** in the desktop app. In a browser, select **Project tools**, then **Task list**. Search for the step you need and open it from the list. Use **Fit view** to bring the whole flow back into view.

## Set up and keep a task result {#task-controls}

Most task pages in this guide start after you have opened a project and run the step that supplies the input table. To add a task, select **Add Task**, choose its category, then select its name. The [Task finder](#task-finder) lists those categories.

1. Open **Setup** when the task has that tab. Choose the input table before choosing columns. A column list can stay empty until its input has run.
2. Enter a unique output name. Keep any **Save** checkbox beside a wanted result checked. A result that is only displayed may not be available to a later task.
3. Select **Run** in the task header. Some forms also have a more specific button, such as **Analyze**, **Load**, **Export**, or **Generate Report**. This guide uses that button name when helpful.
4. Open **Results**, **Data**, or **Preview**, as directed. Check values and messages before moving on.
5. Save the project to keep your work on disk. A task's **Save** checkbox and **Save project** do different jobs.

![Under Results, the Data tab shows one row per numeric measurement. Check the mean and missing count before using the table in a report.](assets/ui-summary-result.png){#fig-summary-result}

A form may scroll. If you cannot find an output control, look near the top of the task panel. If you cannot find its action button, look near the bottom. Screenshot colours may differ from your chosen theme; the labels and steps are the same.

Screenshots use a separate practice folder. Choose the folder you created during installation when your file address differs from the picture.

## Understand the arrows

A later task needs the right input name. For example, a summary that uses `flowers` must wait for the task that creates `flowers`. The app draws the connection from those choices.

Dragging a task to a new place changes the layout. It does not change which tasks run first. To change that, edit its inputs or its branch and loop settings.

## Choose useful names

Give tasks clear labels, such as **Remove repeated customer rows**. Use short, unique output names, such as `customers_clean`. After changing an output name, check later tasks' inputs and rerun the flow.

# Save, reopen, and share projects {#projects}

## Save your project

Use **File > Save project** or Ctrl+S in the desktop app. The first save asks for a name and folder. Use **File > Save project as...** to keep a separate copy before a large change.

![The File menu groups project saving, saved versions, portability, and settings. Use Save project as to make a separate copy.](assets/ui-file-menu.png){#fig-file-menu width=10cm}

In a web browser, use the app's Save controls. Follow its file picker or download prompt and check where the file was saved.

A saved project keeps tasks, settings, available results, notes, and retained task logs. It does not automatically copy every outside file used by your tasks. Keep important input files in a stable folder.

## Move work to another computer

1. Save the project, then choose **File > Project files and portability...** in the desktop app. In a browser, open **Project tools**, then its project-files option.
2. Check the list of outside files. Resolve missing files before making a portable copy.
3. Select **Save portable project** to bundle supported inputs with the project.
4. Open the copy on the other computer and check its inputs before running it.

Database connections still need access to the database. A Script may refer to a file that the portable export cannot find on its own. If so, include that file separately and update the path. A path is the address of a file or folder on your computer.

Reports and files that you already exported are separate copies. Saving the project again does not update those copies. Run the relevant Report or Export task when results change.

## Recover interrupted work

The app keeps recovery information for unsaved work. After a crash or restart, it may offer a recovery copy. Read the prompt, recover the work you need, then save it with a clear filename.

Recovery helps after a problem. Keep using Save during normal work. If you need an earlier saved copy, choose **File > Saved project versions...** in the desktop app, or **Saved versions** from the browser app's Project tools. Check the version date before restoring it.

1. Save your current project before opening its saved versions.
2. Open **Saved project versions...** for the project you mean to restore. Select **Previous saved version** by its date and time.
3. Select **Restore selected version**. This opens the earlier work as an unsaved copy.
4. Check its results, then use **Save project as...** to keep it under a separate name. **Save project** writes the restored work back to the current project file.

## Share a project with care

A project can contain data, paths, logs, and R code. Share only information you mean to share. Open projects from people or sources you trust, because running tasks can run code and write files.

Before sending a project, save it, check its report, and try opening your saved copy. If the recipient only needs the results, send a report or CSV instead of the full project.
