# Proposal

## Why

ScanSplit currently accepts one PDF per review. Users need to review several selected scans consecutively and export their split documents as one ordered batch without accidentally merging across source files.

## What Changes

- Accept multiple PDFs in chooser-returned order, with no filename sorting or reorder screen.
- Review all original pages as one sequential session, retaining source filename, source-local page number and batch position.
- Automatically close each source's final interval with a mandatory boundary that exclusions, Space and Undo cannot remove.
- Export all nonempty groups in source-selection order and page order, with globally numbered filenames that sort in the same order.
- Preserve snapshot checks, page content, whole-batch verification, cancellation and discard protection across all sources.
- Keep single-PDF behavior compatible. Import replaces the session; appending and manual reordering are out of scope.

## Capabilities

### New Capabilities

- `ordered-pdf-batch`: Ordered multiple-source intake, continuous review, mandatory source boundaries and safe batch export.

### Modified Capabilities

None in the canonical inventory: `openspec list --specs` reports no specs. The pending `create-scansplit-app` change defines `pdf-review` and `pdf-export`; this capability explicitly supersedes its single-file intake restriction for the new workflow and extends its review/export guarantees. Reconcile those requirements during implementation without archiving or rewriting the original change as part of this proposal.

## Impact

`AppModel`, chooser/drop/app-open intake, `ContentView`, `PDFPreview`, thumbnails, `Review`, `SourceSnapshot`, `PDFExporter`, verification reporting, core tests and README. No external dependencies or remote PDF processing.
