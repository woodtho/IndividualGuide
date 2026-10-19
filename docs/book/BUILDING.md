# Maintaining the book

These instructions are for documentation contributors. They are not app setup
steps and are not included in the reader's book.

Authored chapters are in `chapters/`. The builder adds short example cards, a
task finder, and shortcuts. `data/example-lessons.json` contains the teaching
notes for each example. `data/app-reference.json` records the actual catalogue,
example archives, and source identities used to verify coverage. Raw task defaults
and internal settings are verification data, not reader-facing appendices.

Use R with the package development dependencies, Node, Pandoc, and a compatible
Chromium browser. The tested documentation environment uses R 4.6.1, Node 24,
Pandoc 3.12.1, and Edge. Rendering checks also need `chromote`, `pdftools`, and
`xml2` in the documentation environment.

From the repository root:

```powershell
Rscript --vanilla tools/book-metadata.R
Rscript --vanilla tools/render-book.R --assets-only
node tools/build-book.cjs
Rscript --vanilla tools/render-book.R
Rscript --vanilla tools/test-book.R
node tools/verify-book.cjs
node tools/publish-book.cjs
```

Set `PANDOC` or pass `--pandoc <path>` to the Node builder if needed.
`CHROMOTE_CHROME` can select a Chromium executable. `BOOK_OUTPUT_DIR` overrides
the output directory. The build creates PDF, offline HTML, EPUB, Word, assembled
Markdown, screenshots, and verification reports under `build/book/` by default.

The final publish command copies only verified reader editions into
`docs/handbook` and records their checksums and source identities. Commit that
folder together with the changed sources. Run `node tools/publish-book.cjs --check`
to check the committed site without R, Pandoc, or a browser. The Publish handbook
workflow runs this check on Linux, then deploys the folder to GitHub Pages for
main-branch pushes. A stale source or changed download fails before deployment.
Pull requests validate without deploying. GitHub Pages must use GitHub Actions
as its publishing source.

Verification checks all 58 task guides and 22 real examples, source hashes,
public installation instructions, approximate prose readability, internal links,
offline resources, XML packages, mobile and desktop layout, PDF text and outline,
and the first-project calculations including save/reopen and exported files.
Installation commands are parsed but are not run by the offline tutorial test.
Test public installation separately in a disposable package library when changing
those instructions. Do not download or install packages during ordinary book
verification.

Readability uses the Flesch-Kincaid formula with a simple syllable estimate over
prose paragraphs, excluding code, headings, tables, links, and inline identifiers.
It is an editing aid, not proof that every technical term is easy to understand.
Review the language and rendered pages as well as the reported score.

Keep the reader's workflow first. Define a new term before using it. Prefer the
public release and CRAN/GitHub installation paths. Do not put developer checkouts,
staged runtimes, build commands, raw constructor defaults, or profiling internals
back into the beginner book. Keep a complete task guide and a useful example
route instead of enforcing a minimum book length.
