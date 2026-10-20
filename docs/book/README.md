# Individual Guide: A Friendly Guide

You do not need to know R to use Individual Guide. This book starts with the
public Windows download and an example you can explore without writing code.
It uses short steps, explains new terms, and helps you find the task you need.

The guide covers release **0.5.0**, all **58 task types**, and all **22 example
projects**. It includes saving and recovery, cleaning data, charts, models,
reports, custom logs, exporting files, and troubleshooting. R installation,
the console, and code exports are optional sections.

- [Read the guide online](https://woodtho.github.io/IndividualGuide/).
- [Download PDF](../handbook/Individual-Guide-Handbook.pdf), [EPUB](../handbook/Individual-Guide-Handbook.epub), or [Word](../handbook/Individual-Guide-Handbook.docx).
- [Lire le même guide en français canadien](https://woodtho.github.io/IndividualGuide/fr-CA/).
- [Télécharger le PDF](../handbook/fr-CA/Individual-Guide-Handbook.pdf), [EPUB](../handbook/fr-CA/Individual-Guide-Handbook.epub) ou [Word](../handbook/fr-CA/Individual-Guide-Handbook.docx).
- [Download offline HTML](https://woodtho.github.io/IndividualGuide/Individual-Guide-Handbook.html) / [HTML français hors ligne](https://woodtho.github.io/IndividualGuide/fr-CA/Individual-Guide-Handbook.html).
- [Download the app](https://github.com/woodtho/IndividualGuide/releases/latest).

Both editions contain the same chapters, procedures, code, examples and figure
numbers. French screenshots show the actual French interface. Project data,
column names, file names and copied code keep their original spelling.

Les deux éditions contiennent les mêmes chapitres, étapes, exemples et numéros
de figures. Les images françaises montrent la vraie interface en français.
Les noms de données, de colonnes et de fichiers, ainsi que le code à copier,
gardent leur orthographe d’origine.

For maintainers: refresh `tools/book-metadata.R`, capture both languages with
`tools/capture-book-screenshots.ps1 -Language en-CA|fr-CA`, and annotate each
workspace image with `tools/annotate-book-screenshots.cjs`. Render the shared
illustrations with `tools/build-book-illustrations.R` and
`tools/render-book-diagrams.cjs`. Build English first using
`node tools/build-book.cjs`, then set `BOOK_LANGUAGE=fr-CA` and build again.
Run `tools/test-book.R`, `tools/render-book.R`, and `tools/verify-book.cjs` with
the corresponding language and `BOOK_OUTPUT_DIR` for each edition. Finally,
clear those overrides and run `node tools/publish-book.cjs`. Publication checks
require both reviewed editions. `node tools/publish-book.cjs --check` checks
the committed site without rebuilding.

Download the handbook as PDF for printing, HTML for offline reading, EPUB for
an e-reader, or Word for your own notes. The verified editions are committed in
`docs/handbook` and served through GitHub Pages. Older release attachments may
contain an earlier handbook edition. Editable text is in `chapters/`;
cross-chapter links work in the assembled book.

When building this edition locally, the finished books are saved in `build/book/`
as `Individual-Guide-Handbook.pdf`, `.html`, `.epub`, and `.docx`. You do not need
to build the book to use the app. [Book build instructions](BUILDING.md) are
separate for people maintaining the documentation.

The [review notes](REVIEW.md) describe the editorial changes, verification, and
known limitations of this edition.
