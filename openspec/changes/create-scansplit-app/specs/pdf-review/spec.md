# PDF Review Spec Delta

> Compatibility update: `add-ordered-multi-pdf-import` supersedes the single-file restriction below with ordered multiple-PDF intake and mandatory source boundaries. The original change's unrelated acceptance tasks remain tracked separately.

## Purpose

Let a person rapidly review a local bulk-scan PDF and make reversible page exclusions and document end markers using a native Mac interface and keyboard.

## ADDED Requirements

### Requirement: Local single PDF intake
The app SHALL open one local PDF at a time through a file chooser or a single-file drag and drop. It SHALL process pages on the Mac without uploading the PDF or its page content.

#### Scenario: Open an image-only scan
- **WHEN** the user chooses a readable, unencrypted, nonempty PDF containing only scanned page images
- **THEN** the app shows its first page and original page count without requiring text extraction, OCR, or a network connection

#### Scenario: Cancel intake
- **WHEN** the user cancels the file chooser
- **THEN** the app retains the current review session or its initial empty state

#### Scenario: Invalid or unsupported source
- **WHEN** a selected file is unreadable, malformed, encrypted, or has no pages
- **THEN** the app explains that it cannot review that file and retains any existing review session

#### Scenario: Drop multiple files
- **WHEN** the user drops more than one file
- **THEN** the app explains that one PDF is supported at a time and does not replace the current source

### Requirement: Large single-page preview and review overview
The app SHALL display one large page preview, fit/zoom controls, and a thumbnail strip. It SHALL preserve the original page numbering in its UI and show current page position, nonempty output document count, excluded page count, and visible end markers. It SHALL make exclusion and boundary states distinguishable without relying only on color.

#### Scenario: Review progress
- **WHEN** the user is viewing source page 34 of a 60-page scan with 11 nonempty output groups and 8 exclusions
- **THEN** the overview reports page 34 of 60, 11 documents, and 8 excluded pages

#### Scenario: Preview different page dimensions
- **WHEN** the current page has a different recorded rotation or page size from the preceding page
- **THEN** the app displays that page using its own size and recorded rotation rather than cropping it to the preceding page

#### Scenario: See decisions in thumbnails
- **WHEN** a page is excluded and has an end marker
- **THEN** its thumbnail shows both states and remains selectable

### Requirement: Navigate original pages
The review surface SHALL use Right Arrow for the next original page and Left Arrow for the previous original page. Clicking a thumbnail SHALL select its original page. Navigation SHALL include excluded pages, stop at document bounds, and not change exclusions or end markers.

#### Scenario: Navigate to an excluded page
- **WHEN** the user advances from source page 4 and source page 5 is excluded
- **THEN** the app selects source page 5 and shows its excluded state

#### Scenario: First and last bounds
- **WHEN** the user presses Left Arrow on the first page or Right Arrow on the last page
- **THEN** the selected page stays at that bound without an error

#### Scenario: Select a thumbnail
- **WHEN** the user clicks the thumbnail for source page 12
- **THEN** the large preview and current-page indicator select source page 12 without altering its decisions

### Requirement: Space toggles a document end and advances
The review surface SHALL use an unmodified Space press to toggle a boundary immediately after the selected original page, then advance by one original page. At the final source page it SHALL keep the selection there. A marker SHALL stay attached to its original source position even if that page is excluded. The final source position SHALL implicitly end the remaining document, whether or not it has an explicit marker.

#### Scenario: Mark an ending
- **WHEN** the user presses Space on unmarked source page 3 of a longer scan
- **THEN** the app marks a boundary after source page 3 and selects source page 4

#### Scenario: Remove a mistaken ending
- **WHEN** the user returns to a page with an explicit end marker and presses Space
- **THEN** the app removes that explicit boundary and advances one original page

#### Scenario: Final document needs no marker
- **WHEN** the scan has a retained tail after its last explicit boundary
- **THEN** that tail is included as the final output document without requiring Space on the final page

#### Scenario: Mark the final page
- **WHEN** the user presses Space on the last source page
- **THEN** the explicit marker toggles, the selection stays on that page, and no additional empty output document is created

### Requirement: Delete reversibly toggles page exclusion
The review surface SHALL use either Backspace/Delete or Forward Delete to toggle the selected original page's exclusion and advance by one original page, staying on the final page at the end. Exclusion SHALL affect export participation only, leave source content untouched, and preserve any boundary after the excluded page.

#### Scenario: Exclude a blank back
- **WHEN** the user presses Delete on a retained blank source page 4
- **THEN** source page 4 is excluded, its thumbnail is crossed out, and source page 5 becomes selected

#### Scenario: Restore a mistaken exclusion
- **WHEN** the user selects excluded source page 4 and presses Delete
- **THEN** source page 4 is retained again and source page 5 becomes selected

#### Scenario: Exclude a marked ending
- **WHEN** source page 3 has an end marker and the user excludes it
- **THEN** the boundary after source page 3 remains in place and the following retained pages do not merge into the preceding document

#### Scenario: Correct a boundary on an excluded page
- **WHEN** the user selects an excluded page with an end marker and presses Space
- **THEN** that boundary is removed without restoring the page

### Requirement: Undo returns to the corrected page
The app SHALL use Command-Z and a standard Undo menu action to reverse the most recent marking command, restore its prior state, and select the affected source page. Navigation SHALL not create undo entries. Undo with no marking command SHALL leave the session unchanged.

#### Scenario: Undo immediately after auto-advance
- **WHEN** the user excludes source page 4, auto-advances to page 5, and presses Command-Z
- **THEN** page 4 is restored and selected

#### Scenario: Undo after navigation
- **WHEN** the user marks page 3 as an ending, navigates to page 9, and presses Command-Z
- **THEN** the marker after page 3 is removed and page 3 is selected

#### Scenario: Undo restores prior boundary independently
- **WHEN** the user excludes a marked ending and then undoes that exclusion
- **THEN** the page is retained again with its preexisting boundary still present

### Requirement: Review shortcuts respect focus and key repeat
The app SHALL handle review keys only when the review surface is active. It SHALL ignore held-key repeat events for Space and Delete, while allowing ordinary repeated arrow navigation. It SHALL provide visible control or menu equivalents for review actions and return focus to review after a completed file dialog.

#### Scenario: Hold a marking key
- **WHEN** the user holds Space or Delete and the operating system emits key-repeat events
- **THEN** only the initial key press changes a page decision and auto-advances

#### Scenario: Use keys inside a file panel
- **WHEN** a file chooser, text field, or modal dialog has keyboard focus
- **THEN** Space, Delete, and arrow keys keep their ordinary control behavior without modifying review decisions

#### Scenario: Begin keyboard review after opening
- **WHEN** the file chooser finishes opening a valid PDF
- **THEN** the review surface accepts Right Arrow, Space, and Delete without an extra focus click

### Requirement: Fast page review
After the initial viewing pass on a representative 60-page scanned fixture, the app SHALL show selected pages within 150 ms at the 95th percentile during normal sequential navigation on the development Mac. It SHALL visibly update marking state and selection within 50 ms for normal marking actions, independent of thumbnail completion. Large scans SHALL not require pre-rendering every page before review starts.

#### Scenario: Navigate while thumbnails load
- **WHEN** thumbnails are still loading and the user navigates or marks the current page
- **THEN** the page decision and selected-page state update without waiting for thumbnail completion

#### Scenario: Measure the normal scan-review loop
- **WHEN** a representative 60-page scan is opened, viewed once, and reviewed through sequential arrow/Space/Delete actions on the development Mac
- **THEN** measured page display and marking response meet the stated timing targets and the split/exclusion results match the actions taken

### Requirement: Protect unexported decisions at session boundaries
Review decisions SHALL remain in memory for the current session. Opening another PDF, closing the review window, or quitting with unexported decisions SHALL offer discard or cancel. A verified export SHALL record the exported review revision; subsequent marking SHALL create unexported decisions again. Reaching the final page SHALL not automatically export or close the session.

#### Scenario: Cancel replacing a reviewed scan
- **WHEN** the user attempts to open another PDF with unexported decisions and cancels the discard prompt
- **THEN** the current PDF and all review decisions remain open

#### Scenario: Close after a successful export
- **WHEN** the user closes a session whose current decisions were successfully exported and have not changed since
- **THEN** the app closes without an unexported-decision warning

#### Scenario: Change decisions after export
- **WHEN** the user changes a marker or exclusion after a successful export and then quits
- **THEN** the app offers discard or cancel because the current revision has not been exported

#### Scenario: Reach the end
- **WHEN** the user marks or excludes the last source page
- **THEN** the review remains available for corrections and export requires an explicit Export action
