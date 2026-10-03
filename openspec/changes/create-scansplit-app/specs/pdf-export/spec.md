# PDF Export Spec Delta

> Compatibility update: `add-ordered-multi-pdf-import` extends these guarantees to all imported sources in one batch, adds mandatory file boundaries and sequence-first multi-source filenames. Single-source export naming remains compatible.

## Purpose

Turn a reviewed bulk scan into ordered individual local PDFs while preserving original page content, avoiding overwritten files, and reporting batch completion accurately.

## ADDED Requirements

### Requirement: Group by source-position boundaries
The app SHALL form source intervals ending after each explicit boundary and the final source page, remove excluded pages from each interval, and emit one output PDF per nonempty interval. Retained pages SHALL appear exactly once in original order. Excluded pages SHALL appear in no output. Output numbering SHALL be consecutive even when an interval contains no retained pages.

#### Scenario: Boundaries mixed with exclusions
- **WHEN** an eight-page source has boundaries after pages 3 and 6 and excludes pages 2, 6, and 8
- **THEN** the output page groups are exactly [1, 3], [4, 5], and [7], in that order

#### Scenario: Consecutive boundaries
- **WHEN** every source page is retained and adjacent source positions are marked as boundaries
- **THEN** each corresponding one-page interval produces a one-page PDF without an empty output between them

#### Scenario: Empty interval
- **WHEN** an interval between two boundaries contains only excluded pages
- **THEN** no PDF is created for that interval and the next nonempty output keeps consecutive numbering

#### Scenario: No explicit markers
- **WHEN** the source has retained pages but no explicit end marker
- **THEN** one PDF contains all retained pages in source order

### Requirement: Prevent an empty export
The app SHALL disable Export when no retained pages exist or no PDF is open, explain the reason, and create no output files or batch directory.

#### Scenario: All pages excluded
- **WHEN** the user excludes every page
- **THEN** the overview reports zero documents, Export is disabled, and no file writes occur

### Requirement: Preserve original scan page content
The app SHALL export the selected original page content without rendering preview images into output pages or intentionally downsampling/recompressing scan images. It SHALL preserve retained page order, visible content, source image resolution, page boxes, and recorded rotation. The app SHALL leave the original source file byte-for-byte unchanged. It SHALL not promise byte-identical output containers or preservation of document-level signatures, bookmarks, or external links.

#### Scenario: Export a rotated mixed-size scan
- **WHEN** retained pages include different dimensions and recorded rotations
- **THEN** each output page retains its original dimensions, boxes, rotation, and visible content

#### Scenario: Preserve image detail and text
- **WHEN** retained fixture pages include a high-resolution scanned image and a page with text/vector content
- **THEN** output keeps the scan's image resolution and text/vector page content rather than flattening them to thumbnail images

#### Scenario: Preserve source bytes
- **WHEN** the user marks, excludes, restores, and exports pages
- **THEN** the original source-file hash remains the same as before review

### Requirement: Detect a changed source before export
The app SHALL detect a replaced or modified source before export and SHALL require the user to reopen it instead of silently applying review decisions to changed pages. A batch SHALL use one consistent source snapshot.

#### Scenario: Source replaced during review
- **WHEN** the source file is changed or replaced after it is opened and the user requests export
- **THEN** export stops with a reopen message, review decisions remain available for inspection, and no completed batch is published

### Requirement: Choose local destination and safe ordered names
Export SHALL ask the user to choose a local parent folder and create a new batch subfolder based on the source filename stem. Files SHALL use that base plus consecutive numbers padded to at least three digits, such as `scan-001.pdf`. Unsafe filename characters SHALL be sanitized, with `scan` as an empty-name fallback. Existing files and directories SHALL never be overwritten; a numeric batch-folder suffix SHALL resolve collisions.

#### Scenario: First export
- **WHEN** the source is `scan.pdf` and the chosen parent has no `scan-split` directory
- **THEN** the app creates a completed `scan-split` batch containing `scan-001.pdf`, `scan-002.pdf`, and further numbered outputs as required

#### Scenario: Export again into the same parent
- **WHEN** `scan-split` already exists
- **THEN** the app selects a new suffixed batch directory and leaves all existing directory contents unchanged

#### Scenario: Cancel destination choice
- **WHEN** the user cancels the destination chooser
- **THEN** no output files are created and the review session remains unchanged

### Requirement: Export a frozen review revision
The app SHALL export one frozen set of page decisions. While exporting it SHALL disable review mutations and source replacement, show progress, and allow cancellation. It SHALL keep the review session available after completion, cancellation, or failure.

#### Scenario: Prevent a plan changing mid-batch
- **WHEN** export is running and the user presses a marking key or tries to open another PDF
- **THEN** the frozen exported plan stays unchanged and the source is not replaced

#### Scenario: Cancel a batch
- **WHEN** the user cancels before the batch is fully verified
- **THEN** no completed batch is reported, the review decisions remain available, and app-owned incomplete files are cleaned up or their remaining path is clearly reported

### Requirement: Verify the whole batch before success
The app SHALL report successful export only after every planned PDF is written, reopens successfully, has a nonzero size, and contains the expected page count. A final batch directory SHALL become available as a completed batch only after all outputs verify. The completion message SHALL give the output count and a Show in Finder action.

#### Scenario: Verified complete export
- **WHEN** all 20 planned output PDFs write and reopen with their expected page counts
- **THEN** the app reports 20 documents exported, records that review revision as exported, and offers Show in Finder for the completed batch

#### Scenario: Mounted share does not support exclusive folder rename
- **WHEN** a writable mounted destination rejects the exclusive batch rename as unsupported
- **THEN** the app reserves a new batch container without replacing existing files or empty folders, publishes all verified PDFs together inside its Documents folder, and opens that completed folder through Show in Finder

#### Scenario: Write or verification failure
- **WHEN** any output cannot be written, reopened, or verified
- **THEN** the app reports the export failure without claiming partial success, retains the review decisions for retry, and does not publish an apparently completed batch

#### Scenario: Incomplete-file cleanup fails
- **WHEN** export fails or is cancelled and an app-owned incomplete file cannot be removed
- **THEN** the app reports the incomplete path and its failure state without deleting unrelated files or claiming the batch succeeded
