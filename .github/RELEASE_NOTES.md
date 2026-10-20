Install **IndividualGuide-0.6.0-Setup-Windows-x64.exe** on Windows 10/11 x64. Choose English or Français (Canada), then open Individual Guide from the Start menu or desktop shortcut. R, packages, Pandoc and the browser are included.

You can now open another Shiny app from an **app.R** file or a folder with **ui.R** and **server.R**. The app runs in its own R process inside Individual Guide, with a persistent toolbar for your workspace, another app, logs and closing. Switch back to your project at any time; the other app keeps its inputs and stays running until you close or replace it. Startup failures leave the main workspace available. Use trusted apps and follow their authors' instructions for extra packages or external software.

The [English handbook](https://woodtho.github.io/IndividualGuide/#other-shiny-apps) and [French handbook](https://woodtho.github.io/IndividualGuide/fr-CA/#other-shiny-apps) include matching illustrated instructions and HTML, PDF, EPUB and Word downloads.

Installez **IndividualGuide-0.6.0-Setup-Windows-x64.exe** sous Windows 10/11 64 bits. Vous pouvez maintenant ouvrir une application Shiny à partir d’**app.R** ou d’un dossier contenant **ui.R** et **server.R**. La barre Individual Guide garde votre projet, le choix d’application, le journal et la fermeture à portée de main. Revenez à votre projet sans arrêter l’autre application ni perdre sa saisie. Utilisez seulement des applications provenant d’une source fiable.

R users can install `IndividualGuide_0.6.0.zip` with R 4.6, or `IndividualGuide_0.6.0.tar.gz` from source, with dependencies from public CRAN sources. Then run `IndividualGuide::run_app()`.

`SHA256SUMS.txt` records download hashes. `release-manifest.json` identifies the exact committed source and locked dependencies. The Windows installer is unsigned. Updating preserves projects and settings.
