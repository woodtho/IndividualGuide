Install **IndividualGuide-0.5.0-Setup-Windows-x64.exe** on Windows 10/11 x64. It includes the application, R, required packages, Pandoc and the desktop browser. Choose English or Français (Canada) during Setup, then launch the Start menu shortcut. No separate R installation is needed.

For R users, install the Windows binary `IndividualGuide_0.5.0.zip` with R 4.6, or the source package `IndividualGuide_0.5.0.tar.gz`. Install dependencies from public CRAN sources, then run `IndividualGuide::run_app()`.

This release adds remembered English and Canadian French language selection throughout the app and desktop menus. Switching languages preserves the R connection and your work. The [English handbook](https://woodtho.github.io/IndividualGuide/) and [French handbook](https://woodtho.github.io/IndividualGuide/fr-CA/) cover the same 58 task types and 22 examples, with translated figures and HTML, PDF, EPUB and Word downloads. See NEWS.md for details.

Installez **IndividualGuide-0.5.0-Setup-Windows-x64.exe** sous Windows 10/11 64 bits. Choisissez **Français (Canada)** ou **English** pendant l’installation. Vous pouvez changer de langue plus tard dans le menu **Language / Langue**, sans redémarrer R ni perdre votre saisie. Le [guide français complet](https://woodtho.github.io/IndividualGuide/fr-CA/) contient les mêmes chapitres, exemples et figures que le guide anglais.

`SHA256SUMS.txt` records download hashes. `release-manifest.json` identifies the exact source commit and locked dependencies. The Windows installer is unsigned. Projects and settings are preserved when updating.
