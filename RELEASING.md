# Releases

The public repository is https://github.com/woodtho/IndividualGuide.
Application downloads live on its Releases page. The handbook editions are
committed under `docs/handbook` and published at
https://woodtho.github.io/IndividualGuide/ by the Publish handbook workflow.

## Release a version

1. Update `DESCRIPTION`, `tools/desktop/package.json` and both root version fields in `tools/desktop/package-lock.json` together. Update `NEWS.md`, `.github/RELEASE_NOTES.md` and the handbook edition. Do not change the archive-format version solely for an app release.
2. Commit the release changes to `main`. The Build and release workflow restores `renv.lock`, runs R and desktop tests, builds both R archives and the installer, and exercises installation, workflows and uninstall in an isolated Windows runner. Check the workflow result and its evidence before tagging.
3. Create and push a matching version tag:

   ```powershell
   git tag -a v0.4.0 -m "Individual Guide 0.4.0"
   git push origin v0.4.0
   ```

4. The tag workflow repeats verification, then publishes the source `.tar.gz`, Windows R binary `.zip`, Windows Setup `.exe`, SHA256 checksums, manifest and desktop README. The tag must match the package version. Pull requests and ordinary branch pushes upload build artifacts but cannot publish a release. A manual workflow run builds artifacts without publishing.

Publication uses the workflow's repository token with `contents: write` only in the publish job. No personal token or signing key is stored in this repository. A failed test/build prevents publication. Existing releases are not overwritten; fix the problem and choose a new version for an already published release.

## Build locally

Use R 4.6.1, Node 24 and Pandoc 3.12.1. Restore `renv.lock` into a dedicated release R library using `renv::restore(library = "<release-library>", prompt = FALSE)`, then set `R_LIBS_USER` to that library. Install `pkgload` and `testthat` for verification; they are build tools. Keep locked runtime packages unchanged.

From a clean committed checkout:

```powershell
./tools/build-standalone.ps1 -RHome 'C:/Program Files/R/R-4.6.1' -Pandoc '<path>/pandoc.exe' -OutputDirectory build/release
Rscript --vanilla tools/build-r-package.R build/release
Rscript --vanilla tools/verify-release.R build/release v0.4.0
./tools/test-installed.ps1 -Executable build/release/win-unpacked/IndividualGuide.exe
```

Each fresh runtime build uses a new directory under `build/staging`; previous staging folders are preserved. `-SkipRuntime -RuntimeDirectory <path>` reuses an existing runtime only when its installed app, all bundled examples/assets, versions and metadata pass current-source verification. It does not update stale installed R code.

Desktop icons are regenerated from `tools/desktop/assets/icon.svg` using the
pinned CPU-only resvg renderer. No Electron window or graphics compositor is
needed for icon generation on a headless build runner. Commit the regenerated
PNG/ICO assets when changing the SVG so a clean build remains clean.

Do not run `test-clean-machine.ps1` in your normal account. Installation, file-association and uninstall checks require Windows Sandbox or an isolated CI account. Unpacked acceptance uses separate test profiles and does not replace your installed application.

The package builder stages package inputs before calling R so ignored multi-gigabyte local runtimes are never copied into the R source package. Local logs, audit notes, profiles, credentials, build outputs and earlier private history stay outside the published tree. `build/` and `artifacts/` are ignored; retain them locally as needed.

Code signing and an in-app automatic updater are not configured. GitHub Releases provides download hosting; upgrading uses the new Setup installer.
