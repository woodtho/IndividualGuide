# Your first project {#first-project}

Start with an example that already works. You will open flower data, find a chart, check a report, and save your own copy. No typing of R code is needed for this first part.

## Open the flower example

1. Open **Help** in the app and find **Example projects**. In the desktop app, **Help > Application help** opens app help.
2. Search for **Iris exploration**.
3. Choose **Open example**. If you already have unsaved work, save it before replacing the current project.
4. Choose **File > Save As**. Save the project as `flower-practice.igpx` in your projects folder. In a browser, use the app's Save As button and file picker.

Iris is a kind of flower. The example has measurements from **150 flowers** in **three species**, with **50 flowers per species**. Each row is one flower. The four measurement columns use centimetres. `Species` names the flower's group.

Opening an example gives you a separate working copy. You can change it without changing the example that ships with the app. Save your copy if you want to keep those changes.

## Look around before running anything

The left side lists the project's tasks and data. The **Process Flow** view shows connected steps. Select the source task and read its notes. Open its flower table and look at the column names.

Find **Summary Statistics**, **Summary Tables**, and **Scatter Plot** in the flow. Open each task's Results. The example already contains results, so you can explore before running it again.

For the species summary, the mean petal lengths should be about:

| Species | Mean petal length, in centimetres |
| --- | ---: |
| setosa | 1.462 |
| versicolor | 4.260 |
| virginica | 5.552 |

You do not need to memorize these values. They give you a way to check that you are viewing the right table and settings.

![The flower example compares sepal length and petal length. Colour shows the species.](assets/iris-chart.png)

## Make one small change

1. Open the **Scatter Plot** task.
2. Find the Y column setting. Change it from `Petal.Length` to `Petal.Width`.
3. Update the chart title so it describes petal width.
4. Click **Run** in the task header. Open Results and check the new chart.
5. Run the **Report** task again so its chart matches your change.
6. Save your project.

Changing a setting does not update a saved report by itself. Run the changed task, then the later tasks that use its result. If you want to run everything again, use the flow's play button. Before doing that, check the Export tasks' folders and Overwrite settings.

## Find the report and log

Open **Report**, then open or download the finished document. Check its headings, tables, and chart. In a Report task, **Appearance > Include pipeline log in the report** adds a section called **Pipeline execution log**. Turn it on and run the report again if needed.

Open **Export Log** to see how the example writes its log to a file. Before running this task, choose a destination you can find. Logs can include earlier runs as well as the latest one. Dates and times help you tell them apart.

## Build a small flow yourself

This optional exercise builds the same kinds of results from a new project. It includes one short piece of R code that you can copy exactly. You do not need to understand the code to finish the exercise. Stay with the ready-made examples if you prefer.

Choose **File > New project** and save it as `first-iris.igpx`. Use **Add Task** to find each task below. Task labels help you recognize a step. Output names tell later steps which result to use, so type those names carefully.

### Step 1: load the practice data

Add **Script** from General. In its outputs, add a **table** named `flowers`. Paste this into the Script editor, not the R Console:

```r
flowers <- datasets::iris
log_event(sprintf("Loaded %d flowers", nrow(flowers)), "INFO")
```

Click **Run**. Open `flowers` in the project and check for 150 rows and five columns. If it is missing, make sure you added the table output named `flowers`. The name in the output list must match the name in the copied code.

### Step 2: summarize the measurements

Add **Summary Statistics** from Describe. Select `flowers` as the input. Choose `Sepal.Length`, `Sepal.Width`, `Petal.Length`, and `Petal.Width`. Name the output `measurement_summary`, then run it.

Check the mean for `Sepal.Length`. It should be about **5.8433**. A mean is the total divided by the number of values. The app may show fewer decimal places.

### Step 3: compare the three species

Add **Summary Tables**. Choose these settings:

| Setting | Choice |
| --- | --- |
| Input table | `flowers` |
| Row variable | `Species` |
| Value variable | `Petal.Length` |
| Statistic | Mean |
| Output name | `species_summary` |

Run it and compare the three results with the table earlier in this chapter.

### Step 4: draw the chart

Add **Scatter Plot**. Select `flowers`, set X to `Sepal.Length`, Y to `Petal.Length`, and the colour or group to `Species`. Set the title to **Iris measurements by species**.

In the output controls, enable a **static image** and name it `iris_scatter_image`. Run the task. A static image is a still chart that you can put in a report or export as PNG.

### Step 5: save a table and chart as files

Add **Export**. Select `species_summary`, choose CSV, choose your projects folder, and enter `species-summary.csv`. Run the task and check that the file appears in that folder.

Add another Export task for `iris_scatter_image`. Choose PNG, set a filename of `iris-scatter.png`, and use the same folder. Set DPI to 150 for this exercise. DPI controls how many dots are used per inch. Run it and open the image.

If a file already exists, the task may ask you to allow Overwrite. Turn that on only when you want to replace that file. An exported file is separate from your saved project.

### Step 6: make a report

Add **Report**. Under Content, add `measurement_summary`, `species_summary`, and `iris_scatter_image`. Give the items clear headings. Under Appearance, choose HTML and set the title to **First Iris report**.

Turn on **Include pipeline log in the report** and leave its minimum level at INFO. Run the task. Open the report and check for the two tables, the chart, and the Pipeline execution log section.

### Step 7: save the log

Add **Export Log**. Select the preceding tasks, including Report, so it waits for them. Choose CSV and a full destination such as `iris-log.csv` inside your projects folder. Use the folder picker or enter the full path shown for your chosen folder.

Run the flow. Check the log file for **Loaded 150 flowers** and the Report completion entry. The report's own log section is made before the report finishes. The final Export Log can record that later completion.

### Step 8: close and reopen your work

Save `first-iris.igpx`, close the project, and open it again. Check that its table, chart, and report are still there. You have made a reusable flow with data, results, a report, and a log.

# Find your way around {#workspace}

The project list, flow diagram, and task panels show the same work in different ways. Use whichever makes the next step easiest to find.

## Open a task or result

Select a task in the project list or flow to open its panel. Its settings control what it does. Results show what happened when it last ran. The Log explains messages and errors. Code shows the R instructions behind the task; reading it is optional.

Closing a task tab hides that panel. It does not delete the task. Use the task's delete action only when you want to remove the step itself.

If the diagram becomes crowded, open **Project tools > Task list**. Search for the step you need and open it from the list. Use **Fit view** to bring the whole flow back into view.

## Understand the arrows

A later task needs the right input name. For example, a summary that uses `flowers` must wait for the task that creates `flowers`. The app draws the connection from those choices.

Dragging a task to a new place changes the layout. It does not change which tasks run first. To change that, edit its inputs or its branch and loop settings.

## Choose useful names

Use a task label that explains the job, such as **Remove repeated customer rows**. Use a short, unique output name, such as `customers_clean`. Avoid giving two outputs the same name.

Changing an output name can affect tasks that use it. Check those tasks' inputs and run the flow again after a rename.

# Save, reopen, and share projects {#projects}

## Save your project

Use **File > Save** or Ctrl+S in the desktop app. The first save asks for a name and folder. Use **Save As** to keep a separate copy before a large change.

In a web browser, use the app's Save controls. Follow its file picker or download prompt and check where the file was saved.

A saved project keeps tasks, settings, available results, notes, and retained task logs. It does not automatically copy every outside file used by your tasks. Keep important input files in a stable folder.

## Move work to another computer

Use the project's files and portability tools to make a **portable project** when you need to bundle supported input files. Check the listed files before exporting. Open the copy on the other computer and check its inputs before running it.

Database connections still need access to the database. A Script may refer to a file that the portable export cannot find on its own. If so, include that file separately and update the path. A path is the address of a file or folder on your computer.

Reports and files that you already exported are separate copies. Saving the project again does not update those copies. Run the relevant Report or Export task when results change.

## Recover interrupted work

The app keeps recovery information for unsaved work. After a crash or restart, it may offer a recovery copy. Read the prompt, recover the work you need, then save it with a clear filename.

Recovery helps after a problem. Keep using Save during normal work. If you need an earlier saved copy, open **Saved versions** from the project tools or File menu. Check the version date before restoring it.

## Share a project with care

A project can contain data, paths, logs, and R code. Share only information you mean to share. Open projects from people or sources you trust, because running tasks can run code and write files.

Before sending a project, save it, check its report, and try opening your saved copy. If the recipient only needs the results, send a report or CSV instead of the full project.
