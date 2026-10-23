Install **IndividualGuide-0.7.0-Setup-Windows-x64.exe** on Windows 10/11 x64. Choose English or Français (Canada), then open Individual Guide from the Start menu or desktop shortcut. R, packages, Pandoc and the browser are included.

**Session > R packages...** now manages an IG-specific package library. Install or update packages, pin exact versions, export and restore a lockfile, or return to a previous package profile. Changes take effect after restarting R. Your other R libraries remain separate.

**File > Settings...** now opens categorized, searchable options for appearance, editing, the console, execution, plots and recovery. Choose global defaults or an explicit project override. Browse the bundled R reference and registered options, or add package options by name with typed values. **Session > Restart with default R options...** lets you repair a saved R setting that prevents startup.

Older projects remain readable. Projects saved by this release use format 0.6 and require Individual Guide 0.7.0 or newer. Save a separate copy when you need to retain compatibility with an older app.

The matching [English handbook](https://woodtho.github.io/IndividualGuide/) and [French handbook](https://woodtho.github.io/IndividualGuide/fr-CA/) include HTML, PDF, EPUB and Word downloads. This release retains hosted Shiny apps, 58 task types and 22 complete offline example projects.

Installez **IndividualGuide-0.7.0-Setup-Windows-x64.exe** sous Windows 10/11 64 bits. **Session > Paquets R...** gère une bibliothèque propre à IG et le verrouillage des versions. **Fichier > Paramètres...** organise les options globales et les remplacements propres au projet, avec les options R et les options de paquets ajoutées manuellement. Redémarrez R pour appliquer les changements de paquets. Les anciens projets restent lisibles; les projets enregistrés avec cette version exigent Individual Guide 0.7.0 ou une version plus récente.

R users can install `IndividualGuide_0.7.0.zip` with R 4.6, or `IndividualGuide_0.7.0.tar.gz` from source, with dependencies from public CRAN sources. Then run `IndividualGuide::run_app()`.

`SHA256SUMS.txt` records download hashes. `release-manifest.json` identifies the exact committed source and locked dependencies. The Windows installer is unsigned. Updating preserves projects and settings.
