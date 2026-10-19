Install **IndividualGuide-0.4.0-Setup-Windows-x64.exe** on Windows 10/11 x64. It includes the application, R, required packages, Pandoc and the desktop browser. Run Setup once, then launch the Start menu shortcut. No separate R installation is needed.

For R users, install the Windows binary `IndividualGuide_0.4.0.zip` with R 4.6, or the source package `IndividualGuide_0.4.0.tar.gz`. Install dependencies from DESCRIPTION first, then run `IndividualGuide::run_app()`.

This release includes 22 complete example projects covering all 58 task types, task/category filters in Help, optional report logging, responsiveness improvements, and the complete handbook sources. See NEWS.md and the project README for details.

`SHA256SUMS.txt` records download hashes. `release-manifest.json` identifies the exact source commit and locked dependencies. The Windows installer is unsigned. Projects and settings are preserved when updating.
