# Explain and review your work {#review}

A useful project tells another person what you did and why. A few clear notes can save much more time than a long trail of unexplained task names.

## Add notes at decision points

Use task notes or project comments to explain choices. Record why you removed rows, filled missing values, chose a model, or set a threshold. Write for someone who sees the project for the first time.

1. Right-click a task in the flow. Enter **Note (shown as node tooltip)**, then select **Save note**. Point to the task later to read it.
2. For a longer discussion, choose **View > Comments...** in the desktop app, or the browser app's **Comments** button.
3. Choose **Attach to**, enter an optional title, and type your comment. Select **Comment** to keep it, or **Raise issue** when it needs review.
4. Save the project so the notes travel with it.

For example: **We kept orders from January through March and excluded cancelled orders.** That tells a reader more than **Filter updated**.

## Check before sharing

1. Choose **View > Review dashboard...** in the desktop app, or the browser app's review control. Check outstanding issues before marking work ready for review.
2. Choose **View > Change history...** to inspect saved project changes. Use its filters to find the task or time you need.
3. Choose **Task > Run records...** to inspect previous executions. In a browser, these records are under **Project tools > Run records**.
4. Compare records for the task you are checking. A run record helps identify changes in settings, inputs, and software versions; it does not replace reading the result.

![The review dashboard collects review status and issues. Notes and comments help another reader understand the choices behind the results.](assets/ui-review.png){#fig-review}

Check the current results too. Old success messages do not prove that a changed task has run again. Update stale results and the report, then save.

## Find something quickly

1. In the desktop app, press Ctrl+Shift+F to open **Global Search**. In a browser, select the **Global search** button in the app header.
2. Type part of a task name, column name, or comment. Select a result to open it.
3. For a task-only view, choose **View > Task list** in the desktop app, or **Project tools > Task list** in a browser. Enter part of its name in **Find a task**, then open the matching row.

![Task list provides a searchable alternative to the flow diagram. Find a task by its name, type, status, or output.](assets/ui-task-list.png){#fig-task-list}

Undo can restore supported project changes, but it does not rewind every action. In particular, it cannot bring back the old contents of an outside file that Export overwrote. Save a separate copy before a large change.

## A simple review checklist

- Can you name the data source and the date of the copy you used?
- Do row counts and missing values make sense after cleaning?
- Do charts show the correct columns, labels, and units?
- Have you checked model warnings and the number of rows used?
- Does the latest report match the latest results?
- Are logs and exported files in the folder you expect?
- Have you saved the project and checked the copy you will share?

# Make the app comfortable to use {#settings}

1. Open a project, then choose **File > Settings...** in the desktop app. In a browser, select **Settings** in the app header.
2. Change one setting at a time. Start with **Appearance** or **Preview rows per page** if the workspace is hard to read.
3. Select **Apply**. Check the workspace, then save the project to keep its settings.

![Settings controls appearance, preview size, saved versions, and run behaviour. Apply a change, check it, and save the project.](assets/ui-settings.png){#fig-settings}

## Display and navigation

Use **Appearance** to choose Dark or Light. **Default plot theme (new graphs)** and **Default palette (new graphs)** affect newly added charts; they do not restyle every existing chart. Use the desktop View menu's zoom controls if text is too small. For a large flow, combine **Fit view** with **Task list**.

Keyboard navigation can help when a diagram is difficult to use. Tab moves focus through controls. The [shortcut guide](#working-reference) lists common desktop keys.

## Saving and confirmation choices

**Previous saved versions to keep** sets the number of earlier explicit saves retained for a project. The default is 20; zero turns these versions off. Crash recovery is separate. Keep your own backups for important projects.

Leave **Stop Run Flow at the first failing task** on while learning, so an error does not pass unnoticed. **Run supported tasks in the background** helps keep the interface available during supported work; it does not make every task run at once.

Leave useful confirmations on while learning. Read any warning about unsaved work before opening another project or example. Saving takes a moment and is easier than rebuilding changes later.

## Trust and private information

Opening a project can make its saved tasks and code available to run. Accept projects from sources you trust. Review input paths, export destinations, and Script tasks before running someone else's flow.

Treat a project as a file that may contain private information. A report or log can contain it too. Check the actual files before putting them in a public folder or attaching them to an issue.
