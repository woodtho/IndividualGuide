# IndividualGuide 0.7.0

- Replace the compact Settings dialog with categorized, searchable global and
  project options. Add editor, console, plotting and recovery preferences;
  inherit global defaults unless a project explicitly overrides a value.
- Present the documented R options and dynamically registered application and
  console options. Support arbitrary package option names and typed values,
  including functions, with consistent task/console/guest execution and code export.
- Save typed project overrides in project format 0.6; retain migration support
  for older project archives and their existing appearance/settings values.

- Add an IG-specific R package library and a package manager for installing,
  pinning and restoring exact CRAN package versions. Validate changes in a
  separate library, apply them after restarting R, and retain rollback profiles.

# Individual Guide 0.6.0

- Open other local Shiny apps from app.R or a ui.R/server.R folder, with a
  persistent Individual Guide toolbar and a separate supervised R process.
- Keep the main workspace available while an app runs. Switch views without
  reloading either app, or close/replace the loaded app with clear save reminders.
- Show startup/runtime logs and recover from failed apps without losing the
  pipeline session. Clean up app processes on close and desktop shutdown.
- Add English and Canadian French controls and matching illustrated handbook
  instructions for the new app browser. Include two working practice apps.
- Keep shinyFiles dialogs visible with Bootstrap 5, readable in the dark theme,
  and preserve file/folder names during translation.

# Individual Guide 0.5.0

- Choose English or Canadian French during Windows installation or in the app.
- Remember the language on this computer independently of saved projects.
- Change interface language without restarting R or losing input values.
- Provide matching English and Canadian French handbooks with localized screenshots.
- Search task types in English or French in the picker, Help, task list and project search.
- Ignore duplicate recovery actions so a restarted session opens one welcome screen.

# Individual Guide 0.4.0

- Expand the offline library to 22 complete projects covering all 58 enabled task types.
- Search and filter Help examples by task type and category without server reloads.
- Include configurable pipeline log appendices in HTML/Word reports and exported R pipelines.
- Remove build-machine paths and author identity from bundled tutorial snapshots.
- Add the complete handbook, covering all tasks and worked examples.
- Publish R source and Windows binary packages plus a rebuilt Windows installer through GitHub Releases, with checksums and source manifests.
- Package exactly one selected desktop runtime, preventing old staging folders from being merged into a new release.
- Preserve local audit notes and original private history outside the public repository.

# Responsiveness improvements

- Retain graph/tree UI for value-only changes and derived autosave snapshots.
- Load logging previews when opened; batch downstream preview invalidation.
- Use faster recovery compression and existing layout without rebuilding canvas cards.
- Retain console highlight tokens and capped heights; observe size after layout.
- Keep console drafts/history search local and preserve keyboard tab focus on repeated activation messages.
- Add ten performance hypotheses, R CPU/allocation and browser profiles, repeatable before/after comparisons and responsiveness regressions.

# Individual Guide 0.3.0

- Retain configurable previous project versions and restore an unsaved working copy.
- Bundle file inputs and existing exports in portable projects; locate missing files.
- Validate a flow before running and open affected tasks from one problem list.
- Reuse isolated workers for transferable tasks, with cancellation and stale-result guards.
- Persist and compare bounded run records, file/data fingerprints, RNG state and environment versions.
- Add optional fixed project seeds and lock release dependencies.
- Highlight console code; complete names/functions/columns; search history; run selections; create Script tasks.
- Add a keyboard task list, accessible controls, improved contrast and scrollable scaled dialogs.
- Show matching release/build information in the app and desktop Help menu.
- Require trust for unfamiliar project contents and authenticate desktop Shiny sessions.
- Provide isolated Windows CI and offline Sandbox installation/upgrade/uninstall checks.

Code signing and public update delivery are excluded from this release.
