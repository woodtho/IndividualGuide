# Individual Guide: The Complete Handbook

The release-edition book covers installation, workspace/projects, all 58 task
types, all 22 real example projects, execution, logging/reporting, R console,
standalone code, review, reproducibility, performance, troubleshooting and desktop
development. The 0.4.0 edition covers the matching source and rebuilt installer.

Rendered deliverables are in `build/book/`:

- `Individual-Guide-Handbook.html`: self-contained offline book with searchable contents.
- `Individual-Guide-Handbook.pdf`: printable book with an outline and page numbers.
- `Individual-Guide-Handbook.epub`: reflowable e-reader edition.
- `Individual-Guide-Handbook.docx`: editable Word edition.
- `Individual-Guide-Handbook.md`: assembled Markdown source.
- `verification.json`: coverage, source identity, links and rendering checks.

The Word edition is editable; refresh its contents field in Word after editing
or repaginating. PDF pagination and hyperlinks are already fixed in the rendered
PDF. The HTML/EPUB editions reflow to the reader's display.

The authored source is in `chapters/`. `data/app-reference.json` contains the
source-derived catalogue/defaults and actual archived example settings. Generated
references are assembled during the build. Assets include verified app screenshots
and an Iris plot; they contain tutorial data, not a user's private project.

From the repository root, with R/package development dependencies, Node and Pandoc:

```powershell
Rscript --vanilla tools/book-metadata.R
Rscript --vanilla tools/render-book.R --assets-only
node tools/build-book.cjs
Rscript --vanilla tools/render-book.R
Rscript --vanilla tools/test-book.R
node tools/verify-book.cjs
```

Set `PANDOC` or pass `--pandoc <path>` to the Node builder if needed. The Windows
renderer uses the installed Edge browser and `chromote`; `CHROMOTE_CHROME` can
point to another compatible Chromium executable. `BOOK_OUTPUT_DIR` overrides the
output directory. No deployment or application installer rebuild is performed.
The verified documentation toolchain uses R 4.6.1, Node 24 and Pandoc 3.12.1;
PDF verification also uses the development packages `pdftools` and `xml2`.

The verification checks source hashes, 58 task entries, 22 complete example
recipes, exact default snapshots, internal links, local assets, offline HTML,
rendered desktop/mobile layout, PDF text/outline and example calculations. Read `build/book/verification.json` for the build verification.
