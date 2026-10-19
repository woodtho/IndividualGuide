# Keep work running smoothly {#performance}

Try a small version of a flow before using a large dataset. Check its settings, then run the full version once you know what it will do.

## When editing feels slow

Wait for an active run to finish, or use Stop if you do not need it. Close task panels you are not using and use the Task list to move around a large project. A smaller chart or sample can make exploration easier, but keep full data for calculations that need it.

If the app remains slow, save, close it, and open it again from its shortcut. Record which task and action cause the delay if you need help. A report such as **Typing the output name is slow in a 40-task project** is easier to investigate than **The app is slow**.

# Troubleshooting {#troubleshooting}

Start with the symptom below. Keep the exact error text when asking for help. It often points to a missing file, column, or package.

## The app seems not to open

Use the installed Start menu or desktop shortcut. Wait for the startup stages, especially on the first launch. If you opened Setup, finish installation and then use the app shortcut.

If startup shows a failure, open its startup log. Save the error text. Check that the installer came from the [public release page](https://github.com/woodtho/IndividualGuide/releases/latest) and that it matches your 64-bit Windows computer.

## The app disconnects or the R server stops

1. If the workspace still responds, save the project and wait for saving to finish.
2. In the desktop app, choose **Session > Restart R server...**. If a reconnect screen is shown, its **Restart R server** button provides the same recovery route.
3. Read the confirmation and restart. This stops active work and can lose unsaved changes.
4. Wait for reconnection. Reopen your saved project, or select **Restore** if a **Recover unsaved work?** prompt offers the work you need. Save a recovered copy before continuing.
5. Check the input paths and results before running the flow again.

![The desktop Session menu provides server restart and startup diagnostics. Use task logs instead when investigating an analysis result.](assets/ui-session-menu.png){#fig-session-menu width=11cm}

When running through R in a web browser, go to the R window that launched the app. Stop that session if needed and run the launch command again. See [Optional: install with R](#install-with-r). The browser version has no independent desktop Session menu.

## A button or menu item is disabled

Finish any open dialog and check whether a flow is running. Open or create a project if you are still on the welcome screen. If the app is disconnected, reconnect or restart the R server first.

## A file will not import

Check that the file still exists and that you can open its folder. For text files, check the separator and header. For Excel, check the selected sheet and range. Confirm the file type matches the import choice.

If the error names a missing package and you run through R, follow the [public package instructions](#install-with-r). If you use Setup, keep the full error and app version when reporting the issue.

## A table or column is missing from a choice list

Run the task that creates the table. Check its output name and Results. Then check whether a cleaning step renamed or removed the column. A numeric-only list may hide a column stored as text; inspect its type before converting it.

## A result is old, empty, or different from the preview

Check the selected input and filters. Use Run, rather than only Preview, to keep the result. Run later tasks again when their inputs change. Check branch decisions for skipped work and logs for failed earlier tasks.

Some views show only the first part of a large table. Read the row-count and limit information before assuming the full data are missing.

## A model fails or looks strange

Read its first warning or error. Check response and predictor types, missing values, group counts, and the number of usable rows. Start with a matching example to check the setup. A model may need method advice even when all app settings are valid.

## A report is missing a chart

Run the chart task and enable its static image output. Select that image in Report, then run Report again. Open the downloaded file to check the result.

If Word generation says Pandoc is missing, use the reporting setup in the optional R section. The Windows Setup already includes Pandoc. HTML is a useful first format to try.

## An exported file is missing or will not update

Open its Export or Export Log task. Check the full destination, folder permissions, filename, and format. Run the task again. If the file already exists, decide whether to allow Overwrite or use a new name. Close the file in another program if it is locked.

## A log seems empty

Check that task logging is enabled and that its rules are enabled. INFO messages will not appear with a minimum of WARN. Run a selected task again and check its own log before checking an export or report appendix.

The report's log section contains earlier recorded events, not its own later completion. Put Export Log after Report when you need that entry.

## Ask for help

Use the [public issue tracker](https://github.com/woodtho/IndividualGuide/issues) for app problems. A GitHub account is needed to create an issue. Include the app version, how you opened it, the last action, the exact error, and what you expected.

For startup or connection problems, use **Session > Save diagnostic log...** in the desktop app. For an analysis problem, export the relevant task log. Check attachments for private data and passwords before posting them. A small example using public data is often the easiest way to explain a problem.

# Optional: install with R {#install-with-r}

Skip this chapter if you use the Windows Setup. These steps are for people who want to launch the app from R instead. You do not need to learn general R programming first.

**R** is the software that performs calculations. An R **package** is an add-on. IndividualGuide is the app's package name. You install it once, then use a short command to open the app on later days.

## Step 1: install R from its public website

1. Go to the [R download site, CRAN](https://cran.r-project.org/). Choose your operating system.
2. On Windows, choose **Download R for Windows**, then **base**, then the current R installer. Download it and follow its instructions.
3. Open **R** from the Start menu. Check for a console with a `>` prompt before continuing.

That R console is where you paste the installation commands below. Do not type the `>` itself. Use the separate R application for installation, rather than a Script task or the R Console inside Individual Guide.

On macOS, use the CRAN macOS download and open the R application. Linux users should follow CRAN's instructions for their Linux version; extra system software may be needed for some packages.

## Step 2: install the app from GitHub

You need internet access for installation. In the R console, paste these commands and press Enter. Installation can take several minutes and print many progress lines. Keep R open and wait for a new `>` prompt before moving on.

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages("remotes")
remotes::install_github(
  "woodtho/IndividualGuide",
  ref = "v0.4.0",
  dependencies = NA,
  upgrade = "never"
)
```

This gets the app from its public GitHub release tag and its required add-ons from the public CRAN package service. It does not require you to download the source repository or find a local build folder. You normally do not need a GitHub account for this public download.

If R asks to create a personal package library, choose Yes. This means a folder for your installed add-ons. If Windows asks whether to compile packages from source when a ready-made version is available, choose No to use the ready-made version. If installation ends in an error, read it before trying to launch the app.

## Step 3: add the features you need

The basic app installation includes its required packages. These extra public packages support reports and some analysis tasks. Install them once if you want to use those features or explore all the examples:

```r
install.packages(
  c("rmarkdown", "knitr", "survival", "forecast"),
  repos = "https://cloud.r-project.org"
)
```

For Word reports, also install Pandoc using its [official installer](https://pandoc.org/installing.html). Close and reopen R after installing it. You can check that R can find it with:

```r
rmarkdown::pandoc_available()
```

`TRUE` means it was found. HTML reports have a simpler fallback, so you can start with HTML while sorting out Word support.

Only add database support if you need it. For a SQLite file, run:

```r
install.packages("RSQLite", repos = "https://cloud.r-project.org")
```

For an ODBC connection, run:

```r
install.packages("odbc", repos = "https://cloud.r-project.org")
```

ODBC may also need a driver from the database provider. Ask your database support contact which one to use. If you have trusted custom connection code, ask its author which extra packages it needs. These commands belong in the separate R application, with the app closed.

## Step 4: open the app

In the R console, run:

```r
IndividualGuide::run_app()
```

The app opens in a web browser. Keep the R window open while using it. That R session is running the app, so it is normal for its console to be busy.

Use the app's own open and save buttons. The desktop File and Session menus belong to the Windows Setup version and are not present here.

When you finish, save the project first. Close the app's browser tab, then stop the app in R with the Stop control or Esc as appropriate for your R window. Quit R when you no longer need it.

## Open it next time

Open R and run only `IndividualGuide::run_app()`. You do not need to reinstall packages each day. If the browser does not open automatically, use the local address printed in the R console.

To update later, save and close the app, start a fresh R session, and follow the instructions for the release you want. The tag `v0.4.0` deliberately selects the version used in this guide.

## If package installation fails

If an optional task names a missing package, close the app and return to R. Use one of the single-package installation commands above, replacing its first quoted name with the package named in the error. Keep the CRAN address as shown.

Check your internet connection and copy the first useful error. A message about a missing system library or compiler needs the setup for that package and operating system; repeating the same command will not fix it. On Windows, the public Setup is the easier route if you do not need an R-managed installation.

The commands above follow the [official remotes installation reference](https://remotes.r-lib.org/reference/install_github.html). Keep using the project's public release notes for version-specific instructions.
