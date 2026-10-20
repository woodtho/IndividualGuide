# Open other Shiny apps {#other-shiny-apps}

A Shiny app is an interactive page that uses R behind the scenes. It may show a dashboard, a chart, or a form. You can open an app someone has shared with you inside Individual Guide. You do not need to copy its code into a pipeline.

Your Individual Guide project stays open. The other app runs in a separate copy of R. Its view fills most of the window, with an Individual Guide bar across the top.

## What you need

Ask the app's author for its complete folder and any setup instructions. A supported folder has either:

- One **app.R** file, plus any data and helper files it uses.
- Both **ui.R** and **server.R**, plus any other files it uses.

Keep the folder together. If it came in a ZIP file, extract it first. Selecting a file does not upload it or install packages. The app runs on this computer and can read or change files with your permissions. Use apps only from a source you trust.

## Try the practice apps

1. Download the [Shiny practice apps for this release](https://github.com/woodtho/IndividualGuide/releases/download/v0.6.0/IndividualGuide-Shiny-Examples-0.6.0.zip).
2. Right-click the ZIP in Windows and choose **Extract All**. Choose a folder you can find again.
3. Follow the steps below. Select **iris-explorer/app.R** for the flower app. Select the **local-sales** folder for the two-file app, which reads a CSV and can download a filtered copy. Both use packages included with Individual Guide.

The flower app has its own **Language / Langue** list. Choose **Français (Canada)** there to see French labels inside that app. That list changes the practice app only.

## Open and run an app

![Choose a single app.R file or a folder containing both ui.R and server.R. Your Individual Guide project stays open behind this view.](assets/ui-shiny-app-picker.png){#fig-shiny-app-picker width=16cm}

1. On the welcome screen, choose **Open Shiny app**. From your workspace, use the window icon beside the app name. In the desktop menu, **File > Open Shiny app...** opens the same view.
2. Choose **Choose app.R...** for a single-file app, or **Choose app folder...** for a folder. For the two-file format, choose the folder that contains both files.
3. Check the selected path. Keep any data, helper scripts, and **www** folder in their original places.
4. If you trust the source, select **I trust this app**, then **Run app**.
5. Wait for the app to appear. Use its own controls to work with its data. The Individual Guide bar stays above it.

## Return to your project

![The loaded app fills most of the window. The Individual Guide bar keeps the workspace, app switcher, log and close controls within reach.](assets/ui-shiny-app-running.png){#fig-shiny-app-running width=16cm}

Choose **Individual Guide** at the left of the top bar. Your project is still there, with its inputs and results. The other app keeps running in the background.

Use the window icon again to return to the other app. Its inputs stay as you left them. In the desktop app, **View > Individual Guide workspace** also brings you back to your project.

Switching views does not restart either R process. If you are finished with the other app, close it to free its resources.

## Close an app or open another

To stop an app, choose **Close app** in its top bar. Save any work using that app's own controls first. Read the confirmation, then choose **Close app** again. **Cancel** keeps it running. Closing it leaves Individual Guide and your project open.

To switch apps, choose **Open app...**, then select another file or folder. Picking a file alone does not close the running app. You can choose **Back to running app** if you change your mind. When you select **Run app**, the previous app closes and the new one starts. Save work in the previous app before that step.

Closing Individual Guide stops the loaded app too. Its temporary session is not saved inside your **.igpx** project. Each app decides how to save its own data and settings.

Restarting the main R server also closes the loaded app. Save work in both apps before restarting.

## If an app will not start

Choose **App log** to read its messages. The same control works while an app is running. Logs keep the app's original language. Copy the exact error when asking its author for help.

- If a file is missing, check that you extracted and kept the complete folder.
- If a package is missing, follow the author's public package instructions. Individual Guide includes its own packages, but it cannot include every package another app might need. Individual Guide does not install extra packages for that app.
- If the app stops or takes too long to start, the top bar stays available. You can run it again, choose another app, or return to your project.

The language choice in Individual Guide changes its own top bar and controls. The loaded app keeps the language and appearance supplied by its author. Its R code runs separately, with the package libraries available to Individual Guide. Apps that need another R version, external software, or a database still need their own setup.

This feature opens local apps. In the ordinary browser version, use a browser on the same computer that runs Individual Guide.
