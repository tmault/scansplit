# Design

## Context

See proposal.md for motivation. Live code uses one SourceSnapshot and PDFDocument in AppModel, a flat Review with integer page positions, one ThumbnailWorker, and a single-source PDFExporter. The chooser, drop handler and openFiles reject multiple URLs. The exporter already stages, verifies and exclusively publishes one batch. The original change remains unarchived; the canonical spec inventory is empty. Its single-source intake contract conflicts with this addition and needs explicit reconciliation when applied.

## Goals / Non-Goals

**Goals:** Preserve the existing marking model and export safeguards while adding source identity and deterministic batch order. Keep PDF objects confined to their current worker/main-actor contexts.

**Non-Goals:** Persistent sessions, append-to-session, reordering, cross-source merging, OCR and remote processing. Avoid materializing a merged PDF merely to obtain global page indices.

## Decisions

### Ordered source records and global page mapping

Introduce an immutable batch of source records in intake order, each with a stable session identity, snapshot and cumulative page offset. Map a global review index to source identity and local page index. Extend Review with immutable mandatory end positions distinct from user decisions. Grouping closes intervals at either kind of end; user commands cannot mutate mandatory ends. Space at a mandatory end only navigates, without a no-op undo record. An alternative of separate review objects would complicate global undo, summary counts and discard protection.

### Preserve intake order

The user clarified that chronological click order is unnecessary. Preserve NSOpenPanel.urls order without sorting. Drop callbacks accumulate URLs by provider position, never completion order; application-open events use their supplied sequence. This recorded session order drives review and export.

### Native chooser lifetime

Own one reusable NSOpenPanel per AppModel and present it as a window-attached sheet. Fully configure file/directory selection, content types, multiple selection and directory creation each time, block review mutations while it is open, and defer callbacks until the sheet detaches. Native testing reproduced disabled destination controls with short-lived panels; reuse restored repeated exports and subsequent import/cancel. This is a verified workaround, not a claim about the platform's underlying cause.

### Transactional session replacement

Validate and snapshot all selected sources in a candidate batch off the main actor. Install it only when complete, releasing candidate snapshots on failure and retaining the old session. Obtain discard consent before work as the current app does, but do not clear the old session until installation succeeds. Clear preview/thumbnail state by session identity to prevent stale results from an earlier batch.

### Source-aware display without a merged container

Keep one active source document in the preview, swapping it at file transitions and translating the selected global index to its local page. Make preview cache identity include both source and local index. Thumbnail workers use source identities and a shared bounded cache; do not open an unbounded PDFDocument for every source. Show source filename, file index, local page and batch position, plus labeled automatic boundaries. Adapt accessibility and verification reporting to the same mapping. Preserving a single giant merged PDF would add memory/copying cost and hide source identity.

### One ordered export plan and publication

Freeze ordered groups as source identity plus local page indices. Check all originals, validate no cross-source group, and copy from the corresponding snapshots using worker-local PDFDocuments. Reuse one staging directory, verification pipeline and exclusive final rename for the entire batch; repeated calls to the current single-source exporter would publish partial batches. Preserve single-source names and folder convention. For multiple sources use `scansplit-batch` with collision suffixes and sequence-first names `001-source.pdf`, padding to the total output count. Sanitize stems with the current helper. Number only nonempty groups, so duplicate stems remain safe. Overall progress and success counts cover all groups.

## Risks / Trade-offs

- [More snapshots increase disk usage and initial validation time] → Sequential background validation, visible loading, candidate cleanup and bounded document/thumbnail caches.
- [File switches may expose stale previews or thumbnails] → Source/session identities in cache keys and completion guards; exercise same-local-page transitions.
- [Original change is still active] → Reconcile the single-file restriction explicitly; do not prematurely archive its remaining acceptance work.
- [Regression in preservation or atomic publication] → Mixed-source fixtures, late failure/cancellation injection and original-hash verification.

## Migration Plan

No persisted state migration is needed because sessions are memory-only. Implement and verify locally after a separate apply request. Build a local app package using the existing scripts. Rollback is restoration of the previous app build; original PDFs and previous exports are unaffected. Keep the original change's outstanding acceptance checks separate from this feature's evidence.
