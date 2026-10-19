# A working guide to Individual Guide {#reading-this-book}

Individual Guide is a desktop-style workspace for building analytical pipelines in R. A project connects data, transformations, analyses, charts and documents. You configure tasks through forms, inspect their results, and retain the R code behind the workflow. You can begin without writing R and move into scripts when a problem needs more control.

This book follows that progression. Its first chapters get the application running and build a small project. The middle chapters explain data management and every task in the catalogue. The later chapters cover control flow, logging, reporting, the console, code exports, project review, maintenance and development. The worked-example atlas reconstructs every bundled example from its actual saved task settings.

The book is also a reference. Use the table of contents to find a task, the task index to find its example projects, and the parameter appendix when you need the exact saved field names. The HTML edition has a contents search and normal browser text search. The PDF is intended for printing and annotation; the EPUB supports an e-reader's own navigation and search.

## Edition and feature boundaries

This is the **19 October 2026 release edition**. The R package identifies itself as `IndividualGuide` version **0.4.0**. The project archive format is **0.5.0**. These version numbers describe different things: changing an analysis does not require a new archive format, and a source checkout can contain improvements made after a released installer.

The `IndividualGuide-0.4.0-Setup-Windows-x64.exe` is rebuilt from the 0.4.0 source. It includes the expanded library of **22 example projects**, task/category filters, optional report-log appendices and the latest responsiveness changes. Older 0.3.0 installations may show only three examples; use the new Setup installer to update. Download it from the project's GitHub Releases page.

| Your starting point | What to expect |
| --- | --- |
| 0.4.0 Setup installer | Self-contained Windows desktop application built from the matching release source |
| Current source checkout | The full source-edition feature set documented here, including 22 examples and report log appendices |
| Older 0.2.0 portable executable | An older snapshot with extraction on each launch; some later desktop controls are absent |
| Generated pipeline `.R` or bundle | An executable analysis script; it requires R, packages and inputs, but not the Individual Guide application |

The book calls out source-edition additions where this distinction matters. It does not assume an installer has silently updated itself. Code signing and a public automatic-update service have not been configured for the delivered release.

## What a project contains

A project is more than a drawing. It holds named process flows, task definitions and their settings, materialized datasets, retained R objects, report artifacts, layout, preferences, task logs and review information. The `.igpx` file is an archive containing metadata and payloads; complex or larger R values use native R serialization inside that archive. It is not a folder of CSV files with a picture attached.

An ordinary project does not automatically copy every external input file. A portable project export can bundle supported local imports and exported files. A live database connection is neither a frozen copy of a database nor a portable credential. The project chapters explain these differences before you move work between computers.

## A vocabulary for the rest of the book

A **task** is a configured operation. A **table** is a named dataset available to tasks. An **object** is a retained non-table value, such as a model or static plot. An **output** is something a task declares and produces. A **flow** groups tasks into a workflow. A **dependency** means one task requires an output or control decision from another. A **path token** belongs to Branch or Loop and controls whether or how often a downstream task executes.

The visible task label helps people recognize a step; its internal task ID identifies the saved task. Output names identify data and objects. Renaming a task label and changing an output name are different operations. A label such as “Clean customer ages” can be descriptive, while its output might be the concise name `customers_clean`.

**Run** commits results to the project. A supported **Preview** calculates a result without replacing the project's retained result. Neither word means that arbitrary code is prevented from touching the filesystem: a Script or custom database expression can still have external effects. **Save** writes the project archive. **Export** writes a selected result to an external file. **Autosave recovery** writes a recovery snapshot and does not turn an untitled project into your chosen saved file.

## How to learn from the examples

The bundled projects use observations distributed with R, including the `survival` package's lung-cancer dataset. Their scripts sometimes add identifiers, convert types, select complete cases or deliberately duplicate a row to demonstrate cleaning. Those preparations are documented. They are teaching workflows, not claims that a particular statistical model is the best analysis of those data.

Start by opening an example and inspecting its original table. Follow its task inputs and outputs. Read the source task, inspect the custom log events, and open the completed report. Save a separate copy before experimenting. Then change one choice—an input column, filter threshold or model predictor—and run the affected steps again. Compare the changed result with the retained run information rather than assuming a green status proves the new analysis is appropriate.

## What was checked

The task catalogue and parameter appendix are generated from the current R constructors. The example atlas is extracted from the actual bundled `.igpx` archives, including task inputs, settings, output declarations and table dimensions. The documentation build checks that all 58 enabled task types and all 22 example IDs have coverage. Commands and worked calculations have dedicated checks described in the development chapter. The documentation's source map identifies the implementation files used to resolve behavior.

These checks establish that the book describes the inspected application. They do not certify an analysis for a scientific, clinical or commercial decision. Inspect data quality, model assumptions and the meaning of each variable before using results outside a tutorial.

# Installation and first launch {#installation}

There are two main ways to use Individual Guide: install the Windows desktop distribution, or run the R application from an installed package or source checkout. Choose based on what you need to maintain. The desktop package supplies the runtime. The R route gives you direct control over the package library and access to the newest source changes.

## Windows desktop installation

The packaged desktop target is **64-bit Windows 10 or 11**. The standalone build includes the Shiny app, a reduced R runtime, its selected package dependencies, Pandoc and an Electron/Chromium browser shell. A normal user does not need a separate R installation, RStudio, Node.js or a web browser to run that package.

For the inspected release, the installer is named `IndividualGuide-0.4.0-Setup-Windows-x64.exe`. In this repository it is under `build/`. Prefer that Setup build to the older executable carrying the `0.2.0` portable filename. Allow roughly **1.5 GB** for the desktop installation, with additional room for project data, exported results, recovery files and backups. Large analyses can require considerably more working disk space and memory than the program itself.

1. Finish or save any work in a currently running copy of the app, then close it.
2. Run the Setup executable for the release you intend to install.
3. Complete the per-user installation. Administrator access and a dependency download are not required for the supplied complete installer.
4. Start **Individual Guide** from the Start menu or its desktop shortcut. The installer does not automatically launch the application.
5. Wait for the startup stages to finish and the workspace to connect. If a recovery choice appears, deal with it before starting a new project.

Normal launches should use the installed application shortcut. Running Setup again performs installation or updating; it is not the usual way to open the workspace. The application files normally live at:

```text
%LOCALAPPDATA%\Programs\individual-guide-desktop
```

The installed executable is `IndividualGuide.exe`. Opening another copy of the installed app normally focuses its existing workspace rather than creating a second independent project session. To open a saved project, use File > Open project, a recent-project entry or the installed `.igpx` association in Explorer.

### First-launch speed

Preparation and first-use costs can make an initial launch feel slower than later ones. The installed distribution extracts its program files during installation and reuses them for later launches. The older portable executable instead extracts a runtime for each launch, so repeated portable startup remains slower. Startup time also depends on disk activity, security scanning, available memory and other work on the machine.

The startup display and log distinguish preparation, R initialization and connection. A quiet window is not enough evidence that the process has failed. If a stage stops progressing or the app reports failure, use **Open startup log** and follow the troubleshooting chapter. Do not infer a universal startup-time guarantee from the local timing measurements recorded in the repository.

### Updating, uninstalling and user data

Re-running a newer installer replaces the program snapshot while retaining separately stored user data. The app does not fetch a public update feed in this delivery. Compare the About dialog's build information with the release you were given.

Windows Settings > Apps can uninstall the program. Uninstalling preserves its user data. Projects saved in your chosen folders are separate from the installed program. Desktop preferences, recovery information, saved connection settings and diagnostic logs normally live under:

```text
%APPDATA%\Individual Guide
```

Do not delete that profile as a routine repair. It can contain the recovery snapshot you need. Back up important project files independently of the application profile. If you want a separate desktop profile for testing, the desktop executable accepts a data-directory argument:

```powershell
& "$env:LOCALAPPDATA\Programs\individual-guide-desktop\IndividualGuide.exe" `
  --data-dir="C:\IG-Test-Profile"
```

That option changes application state storage, not where all arbitrary R filesystem operations can act. The developer chapter explains the equivalent state-directory environment variable.

## Running from R

The package declares **R 4.1 or newer**. That is a declared minimum, not evidence that every combination of current optional packages has been tested on every historical R release. The inspected Windows development/runtime environment uses a later R version. Use a working R installation compatible with the dependencies you install.

Obtain the source directory, then run the following from that directory in R:

```r
install.packages("devtools")
devtools::install_deps(dependencies = TRUE)
devtools::install()
IndividualGuide::run_app()
```

Package installation may need internet access and, for dependencies that must compile, platform build tools. The standalone desktop app avoids that setup for ordinary use by shipping a prepared runtime. Do not confuse installing the R package with rebuilding the desktop installer.

To run the source checkout directly:

```r
install.packages("pkgload")
pkgload::load_all()
IndividualGuide::run_app()
```

The repository's `app.R` also supports `shiny::runApp()` from the repository root. Calling `run_app()` constructs a Shiny application; printing it in an interactive R session starts it. For a script that must start and keep serving explicitly, use Shiny's runner:

```r
pkgload::load_all()
shiny::runApp(IndividualGuide::run_app(), launch.browser = TRUE)
```

Keep that R process alive while using the browser. Closing its R session stops the server. The standalone shell's Restart R server command is not present in a normal browser launch; restart the R application from the R session instead.

### Which dependencies matter

The package's `DESCRIPTION` is the authoritative dependency list. Core work uses Shiny/bslib, data manipulation and readers, plotting, serialization, process management and reporting support. Optional capabilities include ODBC/DBI drivers, SQLite/DuckDB, survival analysis and the optional `forecast` implementation. A source installation should include the suggested packages needed by the tasks you intend to use. A missing optional package can affect a particular task without preventing every other task from working.

**HTML reporting** can use the application's built-in fallback renderer when Pandoc is unavailable. **Word reporting** requires Pandoc and the reporting packages. For a source installation, make sure R can find Pandoc. The app checks standard locations and `RSTUDIO_PANDOC`; RStudio may already provide a Pandoc path. The bundled desktop runtime supplies its own Pandoc.

ODBC connectivity additionally depends on the database vendor's system driver, network access and permissions. An R package alone does not install every vendor's driver or grant access to a server. A saved database connection in a project cannot substitute for those prerequisites.

## Desktop and normal-browser controls

In the standalone desktop shell, native menus provide the global File, Edit, View, Task, Session and Help actions. The app hides duplicate global Shiny header controls there. In a normal browser, including a launch from R or RStudio, the in-app controls remain visible. Task panels still contain their own settings and task actions in either mode.

If a screenshot shows a File menu that your browser does not have, use the corresponding visible Shiny Save/Open/Settings control. If a screenshot shows header icons that the desktop shell hides, use its native menus. The workflow and `.igpx` format remain the same.

## A first-launch checklist

Open the app, create a fresh project, add one Script task that returns a small table, run it, and save a `.igpx` file in a writable folder. Close and reopen that file, then verify the table is still present. This checks more than seeing the welcome screen: it exercises R execution, result retention, serialization and file access. The next chapter gives the complete exercise.

If the workspace cannot connect, start with diagnostics rather than reinstalling packages at random. If a single Import or model task fails, inspect that task's error and required reader/driver/package. Keep installation problems, project-file problems and analysis problems separate; they have different remedies.
