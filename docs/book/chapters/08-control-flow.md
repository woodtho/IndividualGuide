# Run steps conditionally or repeatedly {#control-flow}

Most first projects can use a straight sequence of tasks. Add a Branch when a decision should choose a path. Add a Loop when the same steps should repeat. Try the supplied example before building a large version.

Before starting, save a copy of your project and run its input tasks. Both tasks are under **Add Task > Control Flow**. A **path token** is a name that tells later tasks which route they belong to. Selecting a table supplies data; selecting a path token controls whether or how often a task runs.

## Branch {#task-branch}

Use **Branch** to run tasks only when a condition is met. For example, you could make a summary only when a table has enough rows.

1. Add **Branch**. Under **Setup**, select the source table in **Inputs / dependencies**.
2. Set **Number of outgoing paths**, then expand the first path's settings. Enter a **Path label** and a unique **Path token**.
3. For a row-count check, choose **Dataset row count** in **Condition**. Choose **Dataset**, **Operator**, and **Row count**. In the flower example, `>=` and `100` mean at least 100 rows.
4. Set another path's **Condition** to **Fallback / else path** if you need a route when no ordinary condition matches. Select **Validate**, then **Evaluate**, and read the decision.
5. Open each task that should follow that decision. In **Run after branch/loop path**, select the intended path token.
6. Run the active flow. Expand **Logging** to check the chosen route and any skipped tasks.

![Branch settings name each path and its condition. The following task must also select that path in Run after branch/loop path.](assets/ui-branch.png){#fig-branch}

Choosing an input table alone does not attach a task to a branch path. That separate path choice is needed. **Flowers - conditional quality gate** checks for at least 100 flowers. Change the threshold in a saved copy and run again to see which path is taken.

## Loop {#task-loop}

Use **Loop** to repeat tasks for several values, files, tables, or groups.

Start with **Flowers - repeat by species**. Its group loop runs one summary for each species. Follow the connection from the Loop path to the repeated Script. Inspect the three saved summaries and the iteration entries in the log.

To practise without writing code, save a copy of **Flowers - repeat by species** and use its prepared tasks. An **iteration** is one trip through the repeated steps.

1. Open the example's **Loop** task. Under **Setup**, check that **Iteration type** is **Groups**.
2. Choose **Source dataset / input alias** and **Group / value column**.
3. Keep the **Loop variable** name used by the prepared Script. This name lets that code use the current group. Do not change it in only one place.
4. Keep the example's **Path token** and **Output naming rule** while learning. The rule's `{index}` part keeps a separate result for each iteration.
5. Select **Preview loop**, then inspect **Preview**. Check that the listed groups are the ones you expect.
6. Open the repeated task and select the loop token in **Run after branch/loop path**, alongside its normal inputs. Run the active flow and check the per-group results and log entries.

When building your own loop, add it from **Add Task > Control Flow > Loop**. Use a unique path token and an output rule such as `{task}_{index}_{output}`. Check later Report and Export inputs after changing output names.

![Loop settings choose the source of repeated work. Preview loop lets you check the planned groups before running the flow.](assets/ui-loop.png){#fig-loop}

For exported files, give each iteration a different filename. A supported `{index}` placeholder can add the iteration number. If every iteration writes the same file with Overwrite on, only the last file may remain.

## Choose a loop source

| Source | What you provide |
| --- | --- |
| Parameter list | One value per line in Iteration values |
| Files | File paths or matching file patterns |
| Datasets | All loaded tables; Source dataset names the input alias used by repeated visual tasks |
| Groups | A source table and grouping column |
| Date ranges | One date or range per line, such as `2026-01-01` or `2026-01-01/2026-01-31` |
| Database query results | A prepared result table whose rows supply the items |

Check the preview before running. A missing file or a mistaken group can otherwise repeat the wrong work many times. If the repeated step uses code, begin with the working example and keep the loop variable name consistent with that code.

## Start small

Try two or three iterations first. Check output names, file paths, row counts, and logs. Once those are right, expand the loop.

Place a final Report or Export Log outside the repeated path if it should run once at the end. Attach it inside the path only when you want one per iteration. A stopped or failed loop does not remove files that earlier iterations already wrote.
