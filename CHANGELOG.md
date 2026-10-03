# Changelog

## 0.2.0 — 3 October 2026

### Multiple PDFs in one review

- Open or drop multiple PDFs and review all their pages in one continuous session.
- Keep the supplied file order through review and export. Each file ends automatically, so documents never combine pages from different source files.
- See the current filename, page within that file and position in the whole batch. Navigate and undo across file boundaries.
- Export documents with numbered filenames that sort in review order, including when source filenames repeat or entire files are excluded.
- Keep your current review if any PDF in a new import cannot be opened.

### Fixes

- Repeatedly open the import and export choosers without leaving destination controls disabled.
- Show the correct preview and thumbnail when moving between files with the same page number.

This release also includes the network-share export fix from 0.1.1.

## 0.1.1 — 3 October 2026

### Network-share exports

- Export to mounted network shares that previously failed with “Operation not supported”.
- Publish the verified documents together in a new batch folder. Shares requiring the compatible publication method place PDFs in a `Documents` subfolder.
- Preserve existing exports, including empty folders, and remove temporary export folders after cancellation or failure.

## 0.1.0 — 3 October 2026

### Initial local macOS app

- Review a bulk PDF scan, mark document ends with Space and skip blank backs with Delete.
- Revisit any page through thumbnails and undo marking decisions with Command-Z.
- Adjust the preview with Fit and zoom controls.
- Export retained original PDF pages without reducing scan resolution or changing page geometry. Originals remain untouched.
- Check outputs before publishing, cancel exports and repeat them without overwriting earlier batches.
- Warn before closing or replacing a review with unexported decisions.

ScanSplit processes PDFs locally. Review decisions are held in memory; resumable sessions, encrypted PDFs, OCR and automatic blank-page detection are not supported.
