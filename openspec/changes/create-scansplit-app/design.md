# Design

## Context

See `proposal.md` for the motivation and planned capabilities. This is a greenfield project: OpenSpec has been initialized, but no app code, package, tests, or build configuration exists. There are no existing specifications to modify.

Observed on the development Mac on 2026-10-03: macOS 27.0.1, arm64, Swift 6.4 command-line tools; `xcodebuild -version` reports that the active developer directory is CommandLineTools rather than full Xcode. The build must therefore start from Swift Package Manager and produce a local app bundle without requiring a new Xcode installation.

The central constraint is rapid, reliable page review. Navigation, exclusions, and document boundaries must not lose their relationship to the original scan when a user makes corrections.

## Goals / Non-Goals

**Goals:**

- Separate a small deterministic review model from the native viewer and file export so grouping and undo are easy to verify.
- Keep the keyboard loop responsive while thumbnails and large scans load.
- Treat source pages as immutable and keep file output separate from in-memory review decisions.
- Package a double-clickable personal macOS app, using the installed tools and Apple frameworks.

**Non-Goals:**

- A general PDF editor, text recognition, blank-page classification, automatic document separation, or remote services.
- Persisting review state across app restarts, scanning hardware control, or importing results into Paperless.
- Preserving document-level bookmarks, signatures, inter-document links, or metadata as a general archival transformation. This release targets scanned documents; copying original page content is the preservation target.
- App Store distribution, remote publishing, an installer service, or a second platform.

## Decisions

### 1. Native Swift app with a small AppKit bridge

Use a SwiftPM executable app target with SwiftUI for the window and status controls, an `NSViewRepresentable` bridge to PDFKit's `PDFView`, and AppKit file/folder panels and first-responder keyboard handling. Use Foundation for local file work. The proposed deployment baseline is macOS 14, with no third-party runtime dependencies.

A later packaging task creates `ScanSplit.app` with an Info.plist and bundled executable, then signs it locally as needed for this Mac. The executable and packaged app must both be verified during implementation; the planning phase does not build either.

Alternatives considered: a web wrapper would add a second rendering/build stack to a single-purpose Mac tool; a full Xcode project would require an additional active toolchain. SwiftPM keeps the initial build compatible with the tools that are already present. Toolchain compatibility must be demonstrated during apply, not assumed from a successful version command.

### 2. Review model uses stable original page positions

Keep a zero-based source page index, an exclusion flag for each source page, and a set of boundaries AFTER source page positions. In the UI show the original one-based page number; do not renumber pages when excluding them. Load one source PDF per review session.

Navigation visits every original page, including excluded pages. This makes a mistaken deletion easy to find. An exclusion changes the review model only: the source PDF document and source file are never edited.

Partition original positions at explicit boundaries and an implicit final boundary after the last source page. Filter excluded positions from each partition, omit empty partitions, and assign consecutive output numbers to nonempty partitions. Each retained source page appears exactly once and stays in source order.

A boundary belongs to a source position even if that page is later excluded. Excluding a marked last page therefore keeps the document cut; it does not silently merge the two documents. Space can explicitly remove that boundary while viewing the excluded page.

Example: eight source pages, cuts after 3 and 6, exclusions 2, 6, and 8:

```text
Source intervals:    [1 2 3*] [4 5 6*] [7 8]
Excluded pages:         x         x      x
Exported documents: [1   3 ] [4 5   ] [7  ]
```

Deleting source pages in place was rejected because indexes shift and an existing cut can move or disappear. A retained-pages-only index also makes correction and original page references harder.

### 3. Keyboard actions are explicit and reversible

The review surface owns unmodified Left/Right Arrow, Space, Backspace/Delete, and Forward Delete. Space toggles a boundary after the current source page. Delete toggles exclusion, so revisiting an excluded page and pressing Delete restores it. Each marking action advances one original page; at the final source page the selection stays there.

Use a single marking command history integrated with standard Command-Z handling. Undo restores the prior flags/boundary state and selects the page affected by that command. Arrow navigation and thumbnail clicks do not enter this history. Ignore auto-repeat for Space/Delete, while allowing ordinary arrow repeat. A single held action must not mark or discard several pages accidentally.

Scope shortcut capture to the active review surface, not a global event tap. Text fields, file panels, alerts, and export dialogs retain standard keyboard behavior. Return focus to review after opening a file or completing a dialog. Provide visible menu/control equivalents for navigation, end marking, exclusion/restoration, and undo, plus a concise shortcut legend.

An alternative requiring Space then Right Arrow for every document ending adds a keystroke to the frequent path. Auto-advance is the chosen default, paired with undo and visible marks.

### 4. Preview first, bounded background work

Show one large PDF page fitted to the available area; allow fit/zoom controls and respect the source page's recorded rotation and page box. A thumbnail strip highlights the current page, crosses out excluded pages, and labels cuts without relying only on color.

Keep the source document installed in the viewer while navigating instead of rebuilding it for each page. Render thumbnails lazily around visible pages with a bounded cache; do not decode all scan images up front. Navigation and marking operate immediately on the small review model.

Use main-actor ownership for the UI/PDFView. Any thumbnail/export worker owns a separately opened PDFDocument and performs PDFKit operations serially. Do not share a mutable PDFDocument across concurrent workers or assume PDFKit has undocumented thread-safety guarantees. Export freezes a value snapshot of the review plan and source identity; disable review mutations/opening another source while it runs, with cancellation available.

During apply, measure a representative 60-page scanned fixture after loading: visible page changes under normal repeated navigation should be within 150 ms at the 95th percentile on this Mac after the initial viewing pass; model marking/selection updates should respond within 50 ms. Measure end-to-visible timing, not only model updates. Use timing results and user confirmation to assess the fast-review goal; don't call a build or health check proof of usability.

### 5. Export original pages into a staged, verified batch

The user chooses a parent output folder. Use the source filename stem as the base (sanitize unsafe path characters, fallback `scan`), and create a new batch directory named `<base>-split`, adding a numeric suffix if necessary. Reserve it without replacing any existing directory. Output files are `<base>-001.pdf`, `<base>-002.pdf`, etc., with at least three digits and the source order preserved.

Create a private, session-only local source snapshot when opening, compute its content digest, and use that snapshot for viewing and independently opened worker documents. Check source identity (resource identifier where available, size, modification timestamp) around snapshot creation and reject an unstable read. Before export compare the original source contents against the captured digest; if the source changed, require reopening instead of applying markers to different pages. The worker always reads the frozen snapshot, so changes during a batch cannot mix source versions. Dispose of the private snapshot when the session closes or is replaced; it is not a persistent review copy.

Build each group as a new PDFDocument containing copies of the selected original PDFPage objects. Do not render pages to bitmaps for export, change page dimensions/rotation, or enable image optimization/recompression options. Image-backed thumbnails are preview assets only. PDFKit may rewrite PDF containers, so neither byte-identical output nor retention of all document-level features is promised. Scan image resolution, visible content, page order, page boxes, and rotation are acceptance criteria to verify with PDF fixtures.

Write the batch into an app-owned staging directory on the selected destination volume. Check every write result, reopen every generated PDF, and verify planned page counts and nonzero output sizes. During integration tests also compare per-page content rendering/boxes/rotation and source-file hashes. Publish a final uniquely reserved batch directory only after the entire batch verifies. Ensure every retained page appears in exactly one planned group and every excluded page is absent.

Prefer an exclusive same-volume folder rename for publication. If the filesystem returns ENOTSUP for RENAME_EXCL (reproduced on Tower SMB), reserve the unique batch container using POSIX mkdir, which rejects existing files and even empty directories. Move the entire verified staging folder into that owned container as Documents, and return that folder to Show in Finder. Do not fall back to a replacing rename or a check-then-rename at the shared parent. Permission, capacity and I/O errors remain failures. Cancellation/publication failure cleans up both owned staging and reservation folders; report every remaining path if cleanup fails.

Cancellation/failure must leave the review session available for retry and must not report success or alter existing files. Remove only app-owned incomplete output; if cleanup fails, report the incomplete path clearly. After verified completion, display the output count and a Show in Finder action.

Writing directly into the chosen folder was rejected because it scatters partial batches and risks name collisions. Exporting rendered previews was rejected because it loses source image resolution and text/vector content.

### 6. Session lifetime and input limits stay small

Support ordinary readable, unencrypted PDFs, including image-only scans and mixed page sizes. Reject malformed, zero-page, or encrypted PDFs with a clear explanation and retain any already open review. Password handling is outside v1. Choose one PDF at a time; reject a multi-file drop without replacing the existing source.

Opening another PDF or closing the window/app with unexported review decisions requires a discard/cancel confirmation. The review session is in memory only; no automatic restoration is implied. Successful export sets the session's exported revision; further marking creates unexported changes again. If all pages are excluded, show zero documents and disable export with an explanation. Reaching the last page alone never starts file writes.

## Risks / Trade-offs

- PDFKit page copying may change container structure or discard document-level links/metadata. Mitigation: clearly scope this to scan page content, avoid rasterization, and verify preservation on representative image/vector/text fixtures before declaring export complete.
- Large scan images can stall PDF rendering. Mitigation: stable viewer, lazy bounded thumbnails, serial worker ownership, measured page-switch latency, and testing an actual 60-page scan rather than a tiny text-only PDF.
- Fast keys can make accidental exclusions/cuts. Mitigation: ignore marking-key repeat, label current state, keep every source page reachable, and undo back to the affected page.
- A file can change externally after review starts. Mitigation: source identity checks and a controlled export snapshot; fail with a reopen message if changes are detected.
- Without persistent review sessions, quitting loses decisions. Mitigation: confirmation for unexported edits; keep session persistence explicitly outside this release.
- A local SwiftPM app may need bundle/launch adjustments despite a successful compile. Mitigation: launch and exercise the packaged app through Finder and verify the entire open-review-export flow.

## Migration Plan

There is no existing app or data schema to migrate. During apply, create the app package, implement the two capabilities, run the focused tests, build a local app bundle, and verify it on the current Mac. Distribution remains local. Rollback is removal of the generated app/build outputs; originals and existing exported batches are never rewritten. Do not automatically import outputs into another service.

## Documentation checked

Apple PDFKit documentation was queried through Context7 on 2026-10-03. The documented primitives support existing-page insertion and PDF writing; they do not establish a blanket lossless-image or concurrency guarantee. The preservation/performance checks above remain implementation acceptance work.

- [PDFDocument](https://developer.apple.com/documentation/pdfkit/pdfdocument)
- [PDFDocument.insert(_:at:)](https://developer.apple.com/documentation/pdfkit/pdfdocument/insert(_:at:))
- [PDFDocument.write(toFile:withOptions:)](https://developer.apple.com/documentation/pdfkit/pdfdocument/write(tofile:withoptions:))
- [PDFView](https://developer.apple.com/documentation/pdfkit/pdfview)
- [PDFPage.dataRepresentation](https://developer.apple.com/documentation/pdfkit/pdfpage/datarepresentation)
