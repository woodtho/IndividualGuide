# Published handbook

[Read the guide online](https://woodtho.github.io/IndividualGuide/).

This folder contains the verified HTML, PDF, EPUB, and Word editions. Open
`index.html` to read offline, or select a download from the online guide.
`manifest.json` records download checksums and the source files used for this
edition. It contains no local build paths or private diagnostic logs.

Edit the sources under `docs/book`, then follow `docs/book/BUILDING.md` to
rebuild, verify, and stage the books. Commit the sources and this folder together.
The Publish handbook workflow checks that they match before deploying GitHub
Pages. Pull requests validate the books without publishing.
