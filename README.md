# ScanSplit

A personal, local macOS app for splitting a bulk PDF scan. Open one or more scans, review their original pages, mark document ends and skip blank backs, then export the documents together.

## Use

Open `dist/ScanSplit.app`, or move a copy into Applications. Choose **Open PDFs**, use **File → Open PDFs**, or drop PDFs into the window. Select multiple PDFs in the chooser to review them as one session. The app keeps the chooser-returned or supplied file order through review and export.

| Key | Action |
| --- | --- |
| Left / Right | Previous / next original page |
| Space | Toggle document end, then advance |
| Delete / Forward Delete | Exclude or restore this page, then advance |
| Command-Z | Undo the last marking and return to its page |
| Command-O | Open one or more PDFs |
| Command-E | Export documents |

Click a thumbnail to revisit a page. Excluded pages remain visible and selectable. Press Delete again on an excluded page to restore it. Space removes an existing end marker. Held Space/Delete keys do not repeatedly change pages; arrows can repeat. Use Fit and the magnifying-glass buttons to adjust the preview.

Each imported file ends automatically, so output documents never merge across files. Space at an automatic file boundary moves to the next file without removing that boundary. Navigation and Undo work across the whole session. The header shows the current file, local page and batch page position.

The final document ends automatically. A boundary stays at its original scan position even if that page is excluded. Empty document intervals are omitted. Export is always an explicit action.

Choose a destination folder. ScanSplit creates a new folder such as `scan-split` containing `scan-001.pdf`, `scan-002.pdf`, and so on. Another export creates `scan-split-2` without overwriting earlier files. **Show in Finder** reveals the completed folder.

Version 0.1.1 also supports mounted shares that reject exclusive folder renames. On those shares, the verified PDFs are published together inside `scan-split/Documents`. Existing files and even empty batch folders are preserved. **Show in Finder** opens the folder containing the PDFs.

For multiple PDFs, one folder such as `scansplit-batch` contains sequence-first names such as `001-first-scan.pdf`, `002-first-scan.pdf`, `003-second-scan.pdf`. These sort in review order; empty groups and fully excluded files do not leave numbering gaps. Single-PDF names remain unchanged.

Your original PDFs stay untouched. Outputs copy retained original PDF pages, preserving embedded scan resolution and page geometry. ScanSplit checks that every original has not changed and reopens every output before publishing the batch. You can cancel an export and retry with the current review.

A new import replaces the entire session only after all chosen PDFs validate. If any file is invalid or encrypted, the current session stays intact.

Review decisions are held in memory. Closing, quitting, or replacing a scan warns about unexported decisions. Export before quitting; this version does not save a resumable review session. Encrypted PDFs are not supported. There is no OCR, automatic blank detection, remote processing, or upload.

## Build and test

Requires macOS 14 or later and Apple command-line developer tools with Swift 6. The source uses SwiftUI, AppKit, PDFKit, CoreGraphics and CryptoKit, with no external package dependencies.

```sh
./script/build_and_run.sh
./script/test.sh
SCANSPLIT_CONFIGURATION=release ./script/build_and_run.sh --build-only
```

The build script packages and locally signs `dist/ScanSplit.app`. The default Run action stops any existing development instance before rebuilding: export your decisions first. `--build-only` packages without stopping it. Codex's project Run action uses this same script.

`script/test.sh` loads the Swift Testing macro plugin explicitly when bundled with the command-line toolchain. This accommodates the Swift 6.4 toolchain on this Mac, which includes Swift Testing but not XCTest or SwiftUI's newer State macro plugin.

Optional development modes: `--verify`, `--debug`, `--logs`, `--telemetry`. A packaged app uses only macOS system libraries and does not need the build tools at runtime. Release builds are locally signed, not notarized.

See [CHANGELOG.md](CHANGELOG.md) for release history. Local verification records are kept separately from the repository.
