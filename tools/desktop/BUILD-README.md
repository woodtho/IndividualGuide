# Individual Guide for Windows

Download `IndividualGuide-0.6.0-Setup-Windows-x64.exe` from
https://github.com/woodtho/IndividualGuide/releases/latest.
Run Setup once, then use the Start menu or desktop shortcut. Windows 10/11 x64
is required; allow approximately 1.5 GB for the program, plus your project data.
The installer is unsigned. No administrator access, separate R installation,
browser installation or dependency download is needed for normal startup.

## Installation and data

The per-user installation is normally at
`%LOCALAPPDATA%\Programs\individual-guide-desktop`. It contains the Shiny app,
reduced R runtime, required R packages, Pandoc and the Electron/Chromium shell.
Subsequent launches reuse these files. Running Setup again updates the program;
use the application shortcut for normal launches.

Setup offers English and Français (Canada). Change language later with the
Language menu. Normal browser sessions retain their language selectors in the
header, welcome screen and Settings. The choice is remembered on this
computer. Switching language keeps the R session and typed values in place;
data, project names, formulas and code retain their original spelling.
The [English handbook](https://woodtho.github.io/IndividualGuide/) and its
[matching French edition](https://woodtho.github.io/IndividualGuide/fr-CA/)
include the same task guides, examples and figures in HTML, PDF, EPUB and Word.

Settings, recovery files, connection settings and startup diagnostics live under
`%APPDATA%\Individual Guide`. Save project files wherever you choose. Updating
and uninstalling preserve user data. Use `--data-dir=<directory>` for a separate
profile. Closing the application stops its R processes.

## R packages

Session > R packages opens the package manager. Packages install into a writable
IG-specific library under the app's user-data directory, separated by R
major/minor version, with bundled packages as a fallback. Exact versions are
pinned automatically; unpin before updating. Export and restore an IG package
lockfile to reproduce the selected versions on the same R version.

Changes are staged and checked in a separate process. Save your project and use
Session > Restart R server to apply them. Running workspaces, consoles, task
workers and guest apps keep their current environment until that restart. Undo
last package change and Use bundled packages provide recovery without deleting
libraries still in use. Base R and Individual Guide are managed by the installer.
Older CRAN versions may require Rtools; it is not bundled with the application.

## Other Shiny apps

Choose Apps > Open Shiny app, then select app.R or a folder with ui.R and
server.R. Keep data and helper files together. The loaded app uses its own R
process inside a nearly full-window Individual Guide view. Apps provides Open,
Return to running app (Ctrl+Alt+A), App log and Close. View > Individual Guide
workspace (Ctrl+Alt+I) returns to the main project. Returning to the workspace
keeps the other app running and preserves its inputs. Closing or replacing it
stops it. Use trusted apps; their extra packages or external tools remain the app
author's setup requirements. Opening an app does not install packages.

File provides native Open, Save, Save As, New, Close, recent/pinned projects,
previous saved versions and portability tools. Unsaved changes prompt before
replacement or closing; failed or cancelled saves keep the workspace open.
The title and Save menu indicate unsaved changes. The app remembers window size
and position. Normal Shiny/browser launches retain their in-app controls.

## Recovery and diagnostics

Choose **Session > Restart R server** or **Ctrl+Shift+R** if R disconnects.
The window remains available after a backend failure. Restarting stops running
work and can lose unsaved changes; reopen a saved project or restore recovery
when offered. Repeated requests are guarded and failed starts can be retried.

Use **File > Settings...** for categorized application and R options. Global
defaults apply across projects; explicit project overrides travel with `.igpx`
files. Search the R reference and registered options, or add package options by
name with typed values. **Session > Restart with default R options...** pauses
saved R overrides so a setting that prevents startup can be repaired.

Session can open or export diagnostic logs. These record timestamped startup
stages, runtime versions, connection events, conditions and shutdown/restart.
Rotation keeps five previous files, each capped at 5 MiB. Review diagnostics for
private paths or project details before sharing them. **Help > About** shows the
release, exact source commit and runtime versions even when R is unavailable.

## Working in the desktop app

Task includes Run active flow (**Ctrl+Alt+R**), Stop (**Ctrl+Shift+F5**), validation
and run records. The status strip shows task, progress and elapsed time. Stop can
terminate transferable tasks running in reusable background workers; synchronous
compatibility calls must finish before R can process Stop. Completed external
writes remain in place.

Use **View > R console** (**Ctrl+Alt+C**) for the persistent console worker.
Enter runs a command; Shift+Enter inserts a newline and Ctrl+Enter runs multiline
code. Recall history with Up/Down at editor boundaries or Alt+Up/Down anywhere.
Ctrl+Space/Tab completes names and columns; Ctrl+R searches history; Ctrl+L clears
output. Stop clears the worker workspace and retains transcript/history/draft;
Reset R also clears those and plots. Console data copies stay separate from task
outputs; create a Script task to keep reproducible work.

**Help > Example projects** opens 22 complete offline projects covering all 58
enabled task types. Search or filter by task/category. Each opens a separate
writable copy with real data, executed results, reports, customizable logging and
exports. Save As to keep edits. Report > Appearance can include a pipeline-log
appendix and filter its minimum severity; Export Log includes later completion
events. Bundled tutorials have build-machine identity removed.

Saved project versions default to 20, configurable up to 100. Portability tools
bundle file inputs and exports; Script literals and live database dependencies
still require their resources. Project run records retain bounded configuration,
fingerprints, environment and seed information. Only trust projects from known
sources: archives can contain executable R and native serialized objects.

The full handbook sources and build instructions are in `docs/book/` in the
repository. The app and executable share the same share-nodes logo; attribution
and third-party licenses are retained in the packaged runtime. `packages.csv`
lists bundled R packages and licenses. Vendor ODBC drivers are separate when
needed; SQLite and DuckDB are included.

## Builds and verification

See `RELEASING.md` in the repository for locked dependencies, source/binary R
packages, tag releases, checksums and the CI pipeline. Build with R 4.6.1,
Node 24 and Pandoc 3.12.1:

```powershell
./tools/build-standalone.ps1 -RHome 'C:/Program Files/R/R-4.6.1' -Pandoc '<path>/pandoc.exe' -OutputDirectory build/release
```

The default target is the Setup installer. `-Target portable` optionally builds
a single EXE that extracts its runtime into temporary storage on each launch.
Each EXE is a complete distributable; staging and win-unpacked folders are build
intermediates. Normal release downloads use Setup for faster repeat startup.
The build preserves previous staging folders and rejects stale installed app
code, assets, examples, metadata or dependency versions before packaging.

Use an unpacked test copy and an isolated profile for acceptance:

```powershell
./tools/test-installed.ps1 -Executable build/release/win-unpacked/IndividualGuide.exe
```

The harness disables host R/Pandoc, blocks network access, exercises workflows,
menus, console, examples, project lifecycle, security and R restart, and verifies
that the bundled runtime remains unchanged. It writes local results under
`build/tests/`. Clean install/association/uninstall tests require Windows Sandbox
or an isolated CI account; do not run them against your normal desktop account.
No code-signing identity or automatic in-app update service is configured.
