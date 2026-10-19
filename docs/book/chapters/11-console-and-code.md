# Optional: try the R Console {#console}

You can use the app without the console. It is there for quick questions and small trials when you want more control.

R is the calculation language behind the app. A **command** is an instruction you ask R to carry out. The console shows the command and its result. You can start with a harmless calculation:

```r
2 + 3
```

The result is 5. You do not need to install anything to try this inside the desktop app.

## Open the console and run a command

Choose the **R Console** tab. In the desktop app, you can also use **View > R console**. Type in the command area, then press Enter for a one-line command. Use Shift+Enter to add a line and Ctrl+Enter to run a block.

![The R Console has a command area, results, and controls for working with project data.](assets/r-console.png)

If you want to inspect a project table, use the console's project-data controls to add it. Use its exact table name in commands. These are working copies; changing a console value does not automatically change the project's table or flow.

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
| Clear or Ctrl+L | You want a cleaner display | Clears visible output; working values remain |
| Stop | A command is taking too long | Stops console work and clears its working values; the transcript and history remain |
| Reset | You want a fresh console | Clears its working values, transcript, history, draft, and plots |
| Restart R server | The app's calculation service has stopped | Restarts the app session; save first if possible |

Stopping console work can mean you need to load your project-table copies again. These actions do not turn a trial command into a saved task.

## Keep useful code in a task

If a command should be part of the analysis every time, use **Create Script** or copy it into a Script task. Declare the input tables and named outputs there. Run the task and check its results.

Use task logging for the saved analysis. The console transcript records your trials, which may include commands you later changed or abandoned.

# Optional: export the flow as R code {#generated-code}

The **Code** tab can export the active flow as a complete R script or a code bundle. This is useful when someone needs to rerun the analysis without opening Individual Guide.

A script is a text file of R commands. A bundle includes the script and supporting files with instructions. Choose a complete-flow export for a handoff; an individual task's code may depend on earlier steps.

You can skip code export for everyday app use. A saved project is usually the easiest way to return to your work.

## Share code that someone can run

Before exporting, run the flow and check its results. Choose the flow you mean to share, then export its full script or bundle from Code. Include needed input files and tell the recipient which outputs to expect.

The recipient needs R, the packages requested by the script, and access to its inputs. The complete generated pipeline does not need the Individual Guide package itself. Database access and file locations still need to be set up on the receiving computer.

Open the bundle's README and follow its instructions in a separate working folder. Check output destinations before running. Running a saved script can replace files just as running Export inside the app can.
