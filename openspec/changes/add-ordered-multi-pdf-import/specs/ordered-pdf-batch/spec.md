# Spec Delta

## Purpose

Let users import several local PDFs in the intake order, review their pages consecutively, and export ordered split documents while preserving source-file boundaries.

## ADDED Requirements

### Requirement: Ordered atomic multiple-PDF intake
The app SHALL accept one or more local readable, unencrypted, nonempty PDFs through its import chooser. Chooser intake SHALL preserve the sequence returned by the chooser without further sorting. Other ordered intake paths SHALL preserve the supplied file sequence. Import SHALL replace the session only after every source validates; cancellation or any invalid source SHALL retain the existing session and identify the failed source. Processing SHALL remain local.

#### Scenario: Intake sequence differs from alphabetical order
- **WHEN** the intake supplies z.pdf, a.pdf, m.pdf in that sequence
- **THEN** review begins with z.pdf, followed by a.pdf and m.pdf

#### Scenario: Invalid middle source
- **WHEN** the selected batch contains a readable PDF followed by an encrypted or unreadable PDF
- **THEN** import reports the failed filename and preserves the previous review without installing a partial batch

#### Scenario: Cancel replacement
- **WHEN** the user cancels intake or cancels discarding unexported decisions
- **THEN** every source and decision in the current session remains unchanged

### Requirement: Continuous source-aware review
The app SHALL present pages in source-selection order and original page order within each source. Arrow navigation and marking auto-advance SHALL cross file boundaries and stop only at the batch bounds. Excluded pages SHALL remain navigable. The UI SHALL identify the current source filename, source position within the batch, local page number and total batch page position; thumbnails SHALL distinguish source transitions. Undo SHALL restore the affected decision and select its source page even after crossing a file boundary.

#### Scenario: Advance across sources
- **WHEN** the user advances from the final page of the first of two PDFs
- **THEN** the preview selects page 1 of the second PDF and shows the new source and batch position

#### Scenario: Undo across sources
- **WHEN** Delete excludes the first PDF's final page and advances into the next PDF, then the user invokes Undo
- **THEN** the original page is restored and selected in the first PDF

### Requirement: Mandatory source boundaries
Every source's final original position SHALL automatically close its last output interval. These boundaries SHALL remain effective when the final page is excluded, and SHALL not be removable by Space or Undo. Space at a source's final page SHALL advance without recording a removable boundary. User-created cuts inside a source SHALL retain existing reversible source-position behavior. No output document SHALL contain pages from different source files.

#### Scenario: Excluded source ending
- **WHEN** the last page of source A is excluded and source B contains retained pages
- **THEN** source A's retained tail and source B's retained pages form separate outputs

#### Scenario: Attempt to remove automatic boundary
- **WHEN** the user presses Space on source A's final page and subsequently invokes Undo
- **THEN** the source boundary remains mandatory and Space adds no marking history entry

#### Scenario: Entire source excluded
- **WHEN** all pages of a source between two other sources are excluded
- **THEN** that source emits no PDF and the surrounding sources remain separate

### Requirement: Globally ordered exports
Export SHALL emit all nonempty intervals in source-selection order and original order within each source, with each retained page appearing exactly once. Multi-source output names SHALL begin with a globally consecutive sequence padded to at least three digits and sufficient for the output count, followed by a sanitized source stem, such as 001-z.pdf and 002-a.pdf. Numbering SHALL have no gaps for empty intervals or fully excluded sources. Same-named source files SHALL not collide. A single-source session SHALL retain existing source-stem-first naming. Export SHALL be disabled when no retained page exists across the batch.

#### Scenario: Ordered split outputs
- **WHEN** z.pdf is imported before a.pdf and has two nonempty groups while a.pdf has one
- **THEN** outputs are 001-z.pdf, 002-z.pdf and 003-a.pdf containing their corresponding source groups

#### Scenario: Repeated source stems and empty groups
- **WHEN** two sources share a filename stem and some intervals contain only excluded pages
- **THEN** nonempty outputs have unique, consecutive global numbers in review order

### Requirement: Preserve and verify the complete batch
Export SHALL use a frozen review revision and consistent snapshots for all imported sources, detect changes or missing originals before publishing, preserve retained page content, image resolution, boxes and rotation, and leave all originals byte-for-byte unchanged. It SHALL stage one batch, verify every output before publishing, never overwrite existing data, support cancellation, and retain review state on failure. Success SHALL mark the entire exported revision and report total documents and retained pages. No source failure SHALL publish a partial completed batch.

#### Scenario: Later source changed
- **WHEN** any imported original changes or becomes unavailable before export
- **THEN** export identifies that source, requests reopening, retains the review and publishes no completed batch

#### Scenario: Failure in later output
- **WHEN** writing or verification fails after earlier source outputs have been staged
- **THEN** no completed batch is published and app-owned incomplete files are removed or their remaining path is reported

#### Scenario: Successful mixed-source batch
- **WHEN** all planned outputs pass verification
- **THEN** the completed folder contains the expected ordered pages and geometry, original hashes remain unchanged, and the whole revision is marked exported
