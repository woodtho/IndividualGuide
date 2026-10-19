# Optional: try the R Console {#console}

You can use the app without the console. It is there for quick questions and small trials when you want more control.

R is the calculation language behind the app. A **command** is an instruction you ask R to carry out. The console shows the command and its result. Start with this calculation:

```r
2 + 3
```

The result is 5. You do not need to install anything to try this inside the desktop app.

## Open the console and run a command

1. Choose the **R Console** tab. In the desktop app, you can also use **View > R console**.
2. Select the command area, type `2 + 3`, and press Enter. Check that the transcript shows 5.
3. Use Shift+Enter to add a line without running it. Use Ctrl+Enter to run a block of lines.

![The R Console has a command area and transcript. Project-data controls supply working copies for trials; they do not add a step to the flow.](assets/ui-console.png){#fig-console}

The console loads copies of available project data when you first run a command. Select **Refresh data** after changing data in the flow. This replaces the imported copies while keeping other console values. Changing a console value does not automatically change the project's table or flow.

## Read a command before running it

Commands can calculate, change values, read files, or write files. Use code you understand or trust. For a simple practice with R's built-in flower data, try:

```r
mean(datasets::iris$Sepal.Length)
```

The result is about 5.8433. Here, `mean` asks for an average. The rest identifies the sepal-length column in the built-in flower data. You do not need to memorize that punctuation to use the task forms.

## Find and reuse a command

Use the history controls to find earlier commands. Up and Down move through history when the cursor is at the command boundary; Alt+Up and Alt+Down also help. Ctrl+R searches command history.

Tab or Ctrl+Space offers completions when available. A completion helps type a name; it does not check that the finished command answers your question. Read errors and edit the command before trying again.

## Clear, Stop, and Reset

| Action | When to use it | What to expect |
| --- | --- | --- |
| Clear output or Ctrl+L | You want a cleaner display | Clears the transcript and plots; working values remain |
| Stop | A command is taking too long | Stops console work and clears its working values; the transcript and history remain |
| Reset R | You want a fresh console | Clears its working values, transcript, history, draft, and plots |
| Restart R server | The app's calculation service has stopped | Restarts the app session; save first if possible |

After Stop, the next command loads fresh project-data copies. Values created only in the console are gone. These actions do not turn a trial command into a saved task.

## Keep useful code in a task

1. Select the useful code in the console, or leave it as the current draft or last command.
2. Select **Create Script**. Open the new Script task and check the copied code.
3. Check **Input tables / special outputs** and **Outputs**. An inferred name still needs to match the result the code creates.
4. Run the Script and check its saved results. See the [Script task guide](#task-script) for the output-line format.

# Optional: export the flow as R code {#generated-code}

The **Code** tab can export the active flow as a complete R script or a code bundle. This is useful when someone needs to rerun the analysis without opening Individual Guide.

A script is a text file of R commands. A bundle includes the script and supporting files with instructions. Choose a complete-flow export for a handoff; an individual task's code may depend on earlier steps.

You can skip code export for everyday app use. A saved project is usually the easiest way to return to your work.

## Share code that someone can run

1. Run the flow and check its results. Select the flow you mean to share.
2. Open **Code**, or **View > Generated R code** in the desktop app. Choose **Complete script** in **Code view** if you want to read all the exported instructions together.
3. Select **Download .R** for one complete script, or **Download bundle** for a ZIP containing the pipeline, its supporting functions, and a README.
4. Save the download. Include any needed input files separately and tell the recipient which outputs to expect. The code bundle does not collect your outside data files or database credentials.

![The Code tab separates the pipeline from supporting functions. Download .R includes both in one file; Download bundle keeps them together in a ZIP.](assets/ui-code.png){#fig-code}

The recipient needs R, the packages requested by the script, and access to its inputs. The complete generated pipeline does not need the Individual Guide package itself. Database access and file locations still need to be set up on the receiving computer.

Open the bundle's README and follow its instructions in a separate working folder. Check output destinations before running. Running a saved script can replace files just as running Export inside the app can.
