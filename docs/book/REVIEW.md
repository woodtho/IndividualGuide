# English and Canadian French handbook review

This review covers the matching beginner handbooks for Individual Guide 0.5.0.
The guide assumes no R knowledge and starts with the public Windows installer.
Optional R instructions use CRAN and the public GitHub release tag. Development
instructions remain in [BUILDING.md](BUILDING.md).

## Matching content and images

Both editions contain the same 14 authored chapters, 58 task guides, 22 example
lessons, task finder, shortcuts and troubleshooting procedures. Structural
comparison checks headings, stable anchors, paragraphs, lists, tables, code,
links and figures. The French edition is a complete translation, with Canadian
French wording and the same practical steps.

Each edition has 36 numbered figures: 34 real application views, a workflow
 diagram and an Iris chart. French views were captured from the French
interface, including native desktop menus. Diagram and chart labels were
translated while preserving geometry and plotted data. Captions and alternative
text are translated too. Workspace callouts use the same numbers. Embedded
images are checked against reviewed source PNG files. Figure order and
identities match between languages.

Project-authored names, sample data, R code, raw console output and saved log
messages retain their original text. The guide explains this distinction.
Captures use isolated profiles and public practice data. Records include hashes
and a live inventory of all 58 task forms. Focused recaptures corrected affected
views after text and validation-contrast fixes; unchanged captures retain their
original provenance. See BUILDING.md for that workflow.

## Verification

- English: 24,693 words, 102 PDF pages and 694 publication checks passed.
- Canadian French: 26,683 words, 108 PDF pages and 696 checks passed, including
  matching English structure and translated figures.
- All 22 example archives were checked for integrity and coverage, including
  165 saved successful task steps. This does not mean every saved step was
  rerun through the graphical interface during this review.
- Both editions passed 35 worked-example checks. All 10 printed R blocks were
  parsed. Checks cover the Iris flow, CSV and PNG exports, logging, a report log
  appendix, reopening projects and running exported code without the app.
- HTML was checked at widths of 1440, 1024 and 390 pixels, with offline resources,
  working navigation, internal links and no horizontal overflow.
- All PDF pages were rasterized and inspected in contact sheets. Actual EPUB
  chapters were rendered in a browser in both languages. PDF fonts, text,
  navigation and captions, EPUB resources, and Word media and bookmarks passed.
- English prose has an estimated Flesch-Kincaid grade of 6.23. French prose
  averages 11.08 words per sentence; the English grade formula is not applied to
  French. Editorial review informed the wording in both languages.
- The latest real-browser language verification passed 23 checks, including
  retained input/caret, preserved user data, French search, reversible canvas
  labels, an uninterrupted R connection and readable validation controls.
- Native first-run and reopening checks passed language selection, persistence,
  a real R task, stopped-server language changes and server recovery. The actual
  Setup language chooser was exercised. Release CI separately requires clean
  installation and update acceptance on the committed source.
- Publication checks reject altered English or French downloads and stale
  source inputs. Release checks require matching source, versions and hashes for
  the R packages, Windows installer and eight handbook downloads.

## Known issues and verification limits

- Opening the saved **Filter and Sort** task in **US states - import, join and
  filter** can disconnect Shiny. Both guides explain inspecting its saved output
  or adding a fresh task, and saving before restarting. A fresh filter was
  exercised successfully and its single-row result verified. The saved-task
  defect remains unresolved.
- Some bundled projects retain environment records from earlier app versions.
  Both guides explain the version notice and checking a fresh run.
- External database services, credentials, vendor drivers and every possible
  model or data combination were not exercised. The local SQLite route and
  published controls were checked. macOS and Linux installation was not run on
  those operating systems.
- Word package structure, media, text and links passed. Native Microsoft Word
  pagination remains unverified. PDF rendering is checked separately. EPUB
  chapters were rendered in a browser; individual e-reader pagination may vary.

Editable sources are in `docs/book` and `docs/book/fr-CA`. Verified reader files
are in `docs/handbook` and `docs/handbook/fr-CA`. Public editions are linked from
<https://woodtho.github.io/IndividualGuide/>.
