# Run steps conditionally or repeatedly {#control-flow}

Most first projects can use a straight sequence of tasks. Add a Branch when a decision should choose a path. Add a Loop when the same steps should repeat. Try the supplied example before building a large version.

## Branch {#task-branch}

Use **Branch** to run tasks only when a condition is met. For example, you could make a summary only when a table has enough rows.

1. Add Branch and choose a condition. A row-count condition is a simple place to start.
2. Give the matching path a clear label. Add an Else path if you need an alternative when no ordinary path matches.
3. Open the task that should follow that decision. In **Run after branch/loop path**, select the intended path.
4. Run the flow and inspect the decision and skipped tasks in the log.

Choosing an input table alone does not attach a task to a branch path. That separate path choice is needed. **Flowers - conditional quality gate** checks for at least 100 flowers. Change the threshold in a saved copy and run again to see which path is taken.

## Loop {#task-loop}

Use **Loop** to repeat tasks for several values, files, tables, or groups.

Start with **Flowers - repeat by species**. Its group loop runs one summary for each species. Follow the connection from the Loop path to the repeated Script. Inspect the three saved summaries and the iteration entries in the log.

To build your own, choose the loop source, enter or select its items, and preview the planned iterations. An iteration is one trip through the repeated steps. Attach those steps through **Run after branch/loop path**. Choose output naming that keeps each result separate.

For exported files, give each iteration a different filename. A supported `{index}` placeholder can add the iteration number. If every iteration writes the same file with Overwrite on, only the last file may remain.

## Choose a loop source

| Source | What you provide |
| --- | --- |
| Parameter list | Values to use one at a time |
| Files | File paths or matching file patterns |
| Datasets | Available tables to process |
| Groups | A source table and grouping column |
| Date ranges | Dates or start/end ranges requested by the form |
| Database query results | A prepared result table whose rows supply the items |

Check the preview before running. A missing file or a mistaken group can otherwise repeat the wrong work many times. If the repeated step uses code, begin with the working example and keep the loop variable name consistent with that code.

## Start small

Try two or three iterations first. Check output names, file paths, row counts, and logs. Once those are right, expand the loop.

Place a final Report or Export Log outside the repeated path if it should run once at the end. Attach it inside the path only when you want one per iteration. A stopped or failed loop does not remove files that earlier iterations already wrote.
