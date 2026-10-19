# Welcome to Individual Guide {#reading-this-book}

You can use Individual Guide without knowing R. The app helps you bring in data, clean it, make charts, and share results. You choose settings in forms. The app does the calculations for you.

Think of a project as a recipe. Your data are the ingredients. Each **task** is one step, such as sorting rows or drawing a chart. A **flow**, also called a pipeline, puts those steps together. You can save the recipe and use it again.

This guide covers **Individual Guide 0.4.0**, with **58 task types** and **22 example projects**. Start with installation and the first project. After that, read the task pages you need. You do not need to read the book from start to finish.

## Find your starting point

| What you want to do | Where to go |
| --- | --- |
| Install the Windows app | [Installation and first launch](#installation) |
| Try the app with ready-made data | [Your first project](#first-project) |
| Bring in your own spreadsheet or CSV | [Importing your data](#importing) |
| Find a task and a matching example | [Task finder](#task-finder) |
| Make a report with a log | [Reports and files](#reports-and-exports) |
| Fix a problem | [Troubleshooting](#troubleshooting) |
| Run the app through R instead | [Optional: install with R](#install-with-r) |

## Six words you will see often

| Word | Meaning in the app |
| --- | --- |
| Project | Your saved work: data, tasks, results, and notes |
| Table | Data arranged in rows and columns, like a spreadsheet |
| Task | One step that does a job |
| Flow | A group of connected tasks |
| Output | A result from a task, such as a table or chart |
| Log | A record of what happened when tasks ran |

For example, a flower project can start with measurements, calculate a mean, draw a chart, and make a report. The arrows show which steps need results from earlier steps.

![A flow takes data through tasks to results, reports, and a saved log.](assets/workflow.png){#fig-flow}

## How to follow this guide

Bold words, such as **Run**, name buttons or choices. **File > Save project as...** means open the File menu, then choose Save project as. The dots mean that another window will open. Text such as `flowers` is a name to type exactly.

The Windows app has menus across the top. If you open the app through R in a web browser, use the buttons inside the app for opening and saving projects. Some desktop features, such as restarting the R server from a menu, are only in the Windows app.

Some browser controls are icons. Point to an icon to see its name, such as **Save project** or **Help**.

The HTML book works offline after you download it. Use **Find a chapter or task** in its contents, or press Ctrl+F to search the page. The PDF is useful for printing. EPUB works in an e-reader, and Word lets you add your own notes.

# Installation and first launch {#installation}

For most Windows users, the Setup installer is the easiest choice. It includes R and the extra software the app needs. **You do not need to install R or RStudio separately.**

## Download the public Windows release

You need a 64-bit Windows 10 or Windows 11 computer. Allow about 1.5 GB for the program, plus space for your projects. You need an internet connection to download Setup. The installed app and its examples can then work offline. Tasks that use an online database still need that connection.

1. Open the [public releases page](https://github.com/woodtho/IndividualGuide/releases/latest).
2. Under **Assets**, download **IndividualGuide-0.4.0-Setup-Windows-x64.exe** for this edition. If a newer release is shown, read its notes before choosing it. Find this book's matching installer on the [0.4.0 release page](https://github.com/woodtho/IndividualGuide/releases/tag/v0.4.0).
3. Close any running copy of Individual Guide. You do not need the files called **Source code** to use the desktop app.
4. Double-click the downloaded Setup file and follow its instructions. The usual installation is for your own Windows account.
5. Open **Individual Guide** from the Start menu or desktop shortcut.

The installer is unsigned. Windows may show an unknown-publisher warning. Check that you downloaded it from **woodtho/IndividualGuide** before deciding whether to continue. If your work or school computer blocks it, ask your support team for help.

## Open the app each day

Use the Start menu or desktop shortcut. Setup installs or updates the program; you do not need to run Setup each time.

The first launch may take longer than later launches. Wait while the startup screen shows its progress. The welcome screen then offers three choices. For the first exercise, choose **Start with a blank canvas**. This opens the workspace and makes the Help menu available.

![At the welcome screen, choose Start with a blank canvas to reach the workspace and its Help menu.](assets/ui-welcome.png){#fig-welcome width=12cm}

If startup stops with an error, choose **Open startup log**. See [Troubleshooting](#troubleshooting) for the next step. Repeatedly opening more copies usually does not help.

## Update the app

1. Save your project and close the app.
2. Visit the [public releases page](https://github.com/woodtho/IndividualGuide/releases/latest).
3. Download and run the newer Setup installer.
4. Open the app from its shortcut. Check **Help > About Individual Guide...** to see the installed version.

The app does not update itself. Updating keeps saved projects and settings, but keep your own backup of important project files. Uninstalling through Windows removes the program and keeps separately stored user data.

## Before your first project

Create a folder you can find again, such as **Documents > Individual Guide Projects**. Use it for saved projects and files you export. Give each project a clear name, such as `flower-practice.igpx`.

The file ending **.igpx** means an Individual Guide project. Open it through **File > Open project...**, or double-click it in Windows after installing the app.

You are ready to try [your first project](#first-project). The optional R installation steps are near the end of this guide; the Windows app does not need them.
