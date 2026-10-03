# Proposal

## Why

A bulk scanner produces one PDF containing many unrelated documents and blank duplex backs. ScanSplit will let one person rapidly review each page, mark document endings, discard blanks, and export the resulting documents using the keyboard.

## What Changes

- Create a personal native macOS app called ScanSplit in `/Users/tmault/dev/scansplit`.
- Open one local PDF through a file chooser or drag and drop, with a large single-page preview and a thumbnail strip.
- Use Left/Right Arrow to navigate original pages; Space toggles an end-of-document marker and advances; Delete/Forward Delete excludes the current page and advances; Command-Z undoes a marking action and returns to its page.
- Keep excluded pages available for inspection and restoration. Preserve source page numbering and all original source bytes.
- Show the current page, output document count, excluded page count, and visible split markers. Close the final document automatically.
- Export retained original PDF pages into sequentially named files in a new subfolder of a user-selected output folder, with no scan re-rendering or intentional recompression.
- Handle invalid inputs, all-pages-excluded sessions, cancellation, and export failures without silent data loss or overwriting existing files.
- Keep all document processing on the Mac. This first release has no OCR, automatic blank detection, AI, cloud service, Paperless integration, editing, or persistent/resumable review sessions.

## Capabilities

### New Capabilities

- `pdf-review`: Local PDF intake, single-page viewing, fast keyboard navigation, reversible exclusion and end markers, and review status.
- `pdf-export`: Deterministic document grouping, original-page export, safe local output naming, and verified completion/failure reporting.

### Modified Capabilities

None. This is a new project with no existing capabilities.

## Impact

- New Swift app, review model, PDFKit viewer integration, export component, and focused model/PDF integration tests during the later apply phase.
- Use Apple SwiftUI, AppKit, PDFKit, and Foundation with a Swift Package Manager build and local `.app` packaging; no third-party runtime service or framework is needed.
- Proposed compatibility baseline: macOS 14 or newer; the current Mac has macOS 27.0.1 and Swift 6.4 command-line tools. Full Xcode is not the active developer directory, so the first build path must work with the installed command-line tools.
- Original PDFs, existing Paperless records, and scanner configuration are outside the change and remain untouched.
- This change contains planning artifacts only. App code and packaging are created only after a separate apply request.
