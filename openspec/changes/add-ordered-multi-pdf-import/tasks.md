# Tasks

## 1. Ordered intake and batch identity

- [x] 1.1 Record the user clarification that chooser-returned order is sufficient and update requirements/design consistently; verify strict OpenSpec validation.
- [x] 1.2 Introduce ordered source records and global-to-local page mapping; verify source transitions, duplicate stems and single-source mappings in focused core tests.
- [x] 1.3 Implement transactional multiple-source snapshot loading and source-specific errors; verify invalid middle sources and discard/cancel retain the previous session and candidate snapshots are released.
- [x] 1.4 Wire multi-selection chooser, ordered multi-file drop accumulation and app-open sequences to batch intake; verify callback completion order cannot reorder drops and chooser-returned order is retained without filename sorting.

## 2. Continuous review

- [x] 2.1 Extend Review grouping with immutable mandatory source ends; test no cross-source group, excluded final pages, fully excluded middle sources, internal cuts and all-excluded batches.
- [x] 2.2 Preserve global navigation and undo while Space at mandatory ends only advances; test marking/undo across source transitions and ensure automatic boundaries never enter mutable decisions.
- [x] 2.3 Translate preview and thumbnail requests by source identity/local index with bounded caches and stale-result guards; verify transitions between same local page numbers show the correct source and mixed geometry.
- [x] 2.4 Update source labels, source separators, mandatory-end feedback, menus and accessibility; verify filename/file index/local page/batch position and review keyboard focus through a native UI pass.

## 3. Ordered atomic export

- [x] 3.1 Build a frozen source-aware export plan and validate every original before publication; test altered/missing later sources, invalid mappings and disabled empty export.
- [x] 3.2 Extend staged export to all sources with globally numbered sequence-first multi-source names and one exclusive publication; test ordering, duplicate stems, skipped empty intervals, padding, folder collisions and compatible single-source names.
- [x] 3.3 Keep whole-batch verification, aggregate progress and exported revision tracking; inject late write/verification failures and cancellation to prove no partial completed batch and preserved retry state.

## 4. Integration and documentation

- [x] 4.1 Run mixed-source image/text/rotation fixtures end to end; compare expected output source/page order, rendered pixels, image resolution, page geometry and every original hash, and record native multiple-import evidence in docs/verification.md.
- [x] 4.2 Update verification reporting and README for multiple-source use; reconcile the pending original change's single-file restriction with this capability without marking its unrelated acceptance work complete, then verify OpenSpec strict validation passes.
- [x] 4.3 Run the existing test script and release packaging build; verify the local app imports selected PDFs in chooser-returned order, crosses boundaries with keyboard navigation, and exports a verified ordered folder while remaining responsive during thumbnails.
