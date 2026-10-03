# Tasks

## 1. Native project and launch path

- [x] 1.1 Create a macOS 14+ SwiftPM executable app target and focused test target using only Apple frameworks; verify `swift build` and `swift test` run with the installed command-line toolchain without requiring full Xcode.
- [x] 1.2 Create the single-window app shell, Open/Export controls, app menus, and an initial local `.app` packaging path; verify the bundled executable launches with the expected window and standard Quit/Open actions on this Mac.

## 2. Deterministic review decisions

- [x] 2.1 Implement stable original page indexing, exclusions, end-marker toggling, bounded original-page navigation, and mark-then-advance actions; verify focused tests for first/last bounds, revisited excluded pages, restoring exclusions, and removing markers.
- [x] 2.2 Implement source-position grouping with implicit terminal closure and empty-interval omission; verify the eight-page example exports groups [1, 3], [4, 5], [7], plus no-markers, adjacent-markers, all-excluded, leading/trailing exclusions, and excluded-boundary cases.
- [x] 2.3 Add marking-command undo, selection return, and unexported/exported revision tracking; verify undo after navigation returns to the affected page, restores its exact prior decision, and does not undo arrow/thumbnail navigation.

## 3. Local intake, preview, and keyboard review

- [ ] 3.1 Implement file chooser/single-PDF drop, private session source snapshots/content digests, snapshot cleanup, input validation, and safe replacement/discard handling; verify image-only PDF opening, cancellation, encrypted/corrupt/zero-page inputs, multiple-file rejection, and session preservation on failure.
- [x] 3.2 Add a stable single-page PDFKit viewer with fit/zoom and original-page selection; verify mixed page sizes/recorded rotations display correctly and source file hashes stay unchanged during review.
- [x] 3.3 Add a lazy bounded thumbnail strip, selected-page highlight, crossed-out exclusions, visible boundary indicators, and current-page/document/exclusion counters; verify all states match model decisions and excluded pages remain selectable while background thumbnails load.
- [x] 3.4 Add review-scoped first-responder shortcuts for arrows, Space, both Delete keys, and Command-Z; ignore Space/Delete repeat and provide menu/control equivalents; verify mark/exclude auto-advance, immediate focus after opening, held-key behavior, and ordinary keys inside panels/text fields.
- [ ] 3.5 Add in-memory session close/quit/replace warnings, cancel/discard handling, and clear all-excluded status; verify cancellation preserves review, a successful export marks its revision, later edits warn again, and reaching the last page does not export automatically.

## 4. Original-page batch export

- [x] 4.1 Implement an export-plan snapshot, source identity/content recheck, progress/cancellation, and review mutation/source-replacement lockout during export; verify a changed original fails with a reopen message and the exported plan cannot change mid-batch.
- [x] 4.2 Copy retained original pages into new PDFs using an independently opened serial worker document and no rasterization/downsampling options; verify integration fixtures preserve expected page order/counts, boxes/rotation, embedded scan image dimensions, text/vector content, and the unchanged source hash.
- [x] 4.3 Add destination-folder choice, sanitized source base names, padded output numbers, unique batch-folder naming, app-owned staging, and publish-after-verify behavior; verify the expected names, empty-interval numbering, filename edge cases, repeated-export collisions, and preservation of preexisting files.
- [x] 4.4 Verify every output reopens with nonzero size and its expected page count before reporting completion; inject write/reopen/count failures and cancellation to verify no completed batch is claimed, only owned incomplete files are cleaned up, remaining paths are reported if cleanup fails, and review remains available for retry.
- [x] 4.5 Add successful batch feedback with output count and Show in Finder; verify a full successful export reports the exact count, opens the completed folder, and records only the exported review revision.

## 5. Full app verification and personal packaging

- [x] 5.1 Exercise the packaged app through an open-review-correct-export flow on a representative 60-page image-backed fixture containing about 20 documents and blank backs; verify source/retained/excluded page accounting, document counts, keyboard focus, undo, final implicit closure, and the actual exported PDFs in a standard viewer.
- [ ] 5.2 Measure first-open responsiveness, repeated page-display latency, and marking updates while thumbnails load on this Mac; verify the review spec's 150 ms page-display p95 and 50 ms marking targets after the initial pass, document fixture size/timing method/results, and obtain user functional confirmation of fast review before calling usability complete.
- [ ] 5.3 Finalize a repeatable local release build and `.app` bundle with Info.plist and local signing as needed; verify it launches through Finder, opens PDFs, completes export, and works offline, and document build/location/shortcut instructions without publishing or importing anything remotely.
- [x] 5.4 Run the focused model and PDF integration suite, a release build, and strict OpenSpec validation; record the final end-to-end evidence, toolchain used, and any unresolved limitations in the project handoff and Plane before marking implementation complete.
