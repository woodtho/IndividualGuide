# Handbook review, 19 October 2026

This review covers the complete beginner handbook for the public 0.4.0 app.
Application behaviour and example archives were not changed.

## What changed

Every authored chapter, generated reference section, and example lesson was
reviewed. The guide assumes no R knowledge. It starts with the public Windows
installer and a ready-made project. R setup, the console, and code exports remain
optional. The R route uses CRAN, the public GitHub release tag, and the official
Pandoc installer. Developer setup stays in the separate build guide.

All 58 task types now have numbered steps, with the actual control names,
expected results, and relevant cautions. Corrections include declaring Script
outputs, finding report downloads, keeping leading zeroes in imported IDs,
choosing model settings, and saving versions without losing the original history.
The 22 example lessons link to their task instructions and explain what to check
and try. Desktop menus and ordinary browser controls are distinguished.

The book includes 36 numbered figures, including 34 real application views.
Captures use public practice data in an isolated desktop profile. Captions,
alternative text, consistent sizing, and three explained workspace callouts help
readers find controls. Figure numbers and cross-references are generated for all
editions. Capture provenance and a live 58-task form inventory are recorded in
`data/screenshots.json`.

| Chapters reviewed | Main focus |
| --- | --- |
| Welcome and installation | Public downloads, first launch, basic terms and navigation |
| First project | Explore Iris, build a small flow, check outputs, save and recover |
| Running and importing | Run versus preview, files, database copies, queries and scripts |
| Preparing data | All cleaning, sorting, reshaping and sampling tasks |
| Describing data | Counts, summaries, distributions and checking results |
| Charts | Actual inputs, labels, saved images and display limits |
| Models and multivariate tasks | Available controls, interpretation and required data |
| Diagnostics, survival and time | Time order, event coding, control charts and forecasts |
| Control flow | Dependencies, branch paths and working loop examples |
| Logging | Rules, severity, message fields, previews and Export Log |
| Reports and exports | Contents, appearance, file formats, destinations and downloads |
| Console and code | Optional trials, saved scripts and complete-flow handoffs |
| Review and settings | Notes, comments, task search, saved versions and defaults |
| Help and optional R | Recovery, troubleshooting and public installation commands |
| Generated example atlas, task finder and reference | All 22 projects, task links and menus |

## Verification

- Checked source implementation and reviewed all 58 live task forms against the
  instructions. Screenshot capture used the matching public 0.4.0 R runtime.
- Verified the integrity, coverage, and saved success records of all 22 example
  archives, containing 165 saved task steps. This does not mean every saved step
  was rerun through the graphical interface during this editorial review.
- Parsed all 10 printed R blocks. Passed 35 worked-example checks, including the
  eight-task Iris flow, CSV and PNG exports, custom logging, report log appendix,
  project reopening, and running generated code without the app installed.
- Tested text IDs through CSV import and conversion, and a fixed SQLite copy
  through the documented Form connection route.
- Verified public GitHub-tag installation and an app HTTP response in a temporary
  R library; required dependencies were reused from the host library.
- Built HTML, PDF, EPUB and Word editions. Checked offline resources, captions,
  internal links, Word bookmarks, EPUB XML, embedded PDF fonts and navigation.
- Checked HTML at desktop, tablet and phone widths. Reviewed the actual captures,
  rendered PDF pages, and sample EPUB chapters. The PDF has 99 pages.
- Passed 672 publication checks. Estimated prose reading grade is 6.23 using a
  simple Flesch-Kincaid syllable estimate. Manual review, rather than that score
  alone, informed the final wording and introduction of new terms.

## Known issues and verification limits

- In app release 0.4.0, opening the saved **Filter and Sort** task in **US states -
  import, join and filter** can disconnect Shiny. The guide documents inspecting
  the saved output or adding a fresh task, plus saving and restarting. A fresh
  filter was exercised successfully. The application defect remains unresolved.
- Some bundled projects retain environment records from an earlier app version.
  The guide explains the resulting version notice and checking a fresh run.
- External database services, credentials, vendor drivers and every possible
  model or data combination were not exercised. The local SQLite route and the
  published controls were checked. macOS and Linux installation instructions
  were checked against public sources, but not run on those operating systems.
- Word package structure, media, text and internal links passed. Native Microsoft
  Word automation could not produce a reliable render on this review machine;
  Word-specific pagination remains unverified. The published PDF is rendered
  separately and was visually checked. EPUB chapters were rendered in a browser;
  pagination in individual e-reader products may vary.

The editable chapters and visual assets are in `docs/book`. Verified reader
editions are in `docs/handbook` and published at
<https://woodtho.github.io/IndividualGuide/>. Build and capture instructions are
in [BUILDING.md](BUILDING.md).
