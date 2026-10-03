import Testing
import Foundation
import Darwin
@preconcurrency import PDFKit
@testable import ScanSplitCore

@Suite(.serialized) @MainActor
struct PDFTests {
    func withFolder(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ScanSplit-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
    @Test func originalPagesPreserveContentGeometryAndSource() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("scan.pdf")
            try PDFFixtures.create(at: url)
            let beforeHash = try SourceSnapshot.hash(url)
            let source = try SourceSnapshot.open(url)
            let groups = [[0, 2], [3, 4, 5], [6]]
            let result = try PDFExporter.export(source: source, groups: groups, parent: root)
            #expect(result.documentCount == 3); #expect(result.pageCount == 6)
            let original = try #require(PDFDocument(url: url))
            for (index, group) in groups.enumerated() {
                let exported = try #require(PDFDocument(url: result.folder.appendingPathComponent(String(format: "scan-%03d.pdf", index + 1))))
                #expect(exported.pageCount == group.count)
                for (position, sourcePage) in group.enumerated() {
                    let left = try #require(original.page(at: sourcePage)), right = try #require(exported.page(at: position))
                    #expect(right.string == left.string)
                    #expect(right.bounds(for: .mediaBox) == left.bounds(for: .mediaBox))
                    #expect(right.rotation == left.rotation)
                    #expect(PDFFixtures.pixels(left) == PDFFixtures.pixels(right))
                }
            }
            #expect(try SourceSnapshot.hash(url) == beforeHash)
        }
    }
    @Test func scannedImagesKeepResolutionAndSnapshotsCleanUp() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("image-scan.pdf")
            try PDFFixtures.create(at: url, count: 6, scanned: true)
            var source: SourceSnapshot? = try SourceSnapshot.open(url)
            let snapshotURL = try #require(source?.snapshotURL)
            let snapshot = try #require(source)
            let result = try PDFExporter.export(source: snapshot, groups: [[0, 1], [3, 4, 5]], parent: root)
            let original = try #require(PDFDocument(url: url))
            let exported = try #require(PDFDocument(url: result.folder.appendingPathComponent("image-scan-002.pdf")))
            #expect(original.page(at: 0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" == "")
            let left = try #require(original.page(at: 3)), right = try #require(exported.page(at: 0))
            #expect(PDFFixtures.imageSizes(left) == ["1275x1650"])
            #expect(PDFFixtures.imageSizes(left) == PDFFixtures.imageSizes(right))
            #expect(PDFFixtures.pixels(left) == PDFFixtures.pixels(right))
            source = nil
            // The explicit snapshot reference retains it through this scope; test disposal separately below.
            #expect(FileManager.default.fileExists(atPath: snapshotURL.path))
        }
        var source: SourceSnapshot?
        var snapshotURL: URL?
        try withFolder { root in
            let url = root.appendingPathComponent("lifetime.pdf"); try PDFFixtures.create(at: url, count: 1)
            source = try SourceSnapshot.open(url); snapshotURL = source?.snapshotURL
            source = nil
            #expect(!FileManager.default.fileExists(atPath: try #require(snapshotURL).path))
        }
    }
    @Test func collisionsCancellationAndChangedSource() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("scan.pdf"); try PDFFixtures.create(at: url)
            let source = try SourceSnapshot.open(url)
            let first = try PDFExporter.export(source: source, groups: [[0]], parent: root)
            let preserved = try Data(contentsOf: first.folder.appendingPathComponent("scan-001.pdf"))
            let second = try PDFExporter.export(source: source, groups: [[1]], parent: root)
            #expect(second.folder.lastPathComponent == "scan-split-2")
            #expect(try Data(contentsOf: first.folder.appendingPathComponent("scan-001.pdf")) == preserved)
            let flag = CancellationFlag()
            #expect(throws: CancellationError.self) {
                _ = try PDFExporter.export(source: source, groups: [[0], [1]], parent: root, cancellation: flag, hooks: ExportHooks(afterWrite: { _, _ in flag.cancel() }))
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix(".scansplit-") }.isEmpty)
            try PDFFixtures.create(at: url, count: 1)
            #expect(throws: ScanError.self) { _ = try PDFExporter.export(source: source, groups: [[0]], parent: root) }
        }
    }
    @Test func batchFailuresNeverPublishSuccess() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("scan.pdf"); try PDFFixtures.create(at: url)
            let source = try SourceSnapshot.open(url)
            for mode in 0..<3 {
                let hooks = ExportHooks(beforeWrite: { index, _ in if mode == 0 && index == 1 { throw ScanError("Injected write failure") } }, afterWrite: { _, file in
                    if mode == 1 { try Data("invalid".utf8).write(to: file) }
                    if mode == 2 { let wrong = PDFDocument(); wrong.insert(PDFPage(), at: 0); wrong.insert(PDFPage(), at: 1); _ = wrong.write(to: file) }
                })
                #expect(throws: (any Error).self) { _ = try PDFExporter.export(source: source, groups: [[0], [1]], parent: root, hooks: hooks) }
                #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["scan.pdf"])
            }
            let hooks = ExportHooks(beforeWrite: { _, _ in throw ScanError("failure") }, beforeCleanup: { _ in throw ScanError("cleanup failure") })
            do { _ = try PDFExporter.export(source: source, groups: [[0]], parent: root, hooks: hooks); Issue.record("Expected cleanup failure") }
            catch { #expect(error.localizedDescription.contains("Incomplete files remain")) }
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".scansplit-") })
        }
    }
    @Test func unsupportedExclusiveRenameStillPublishesVerifiedBatch() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("scan.pdf"); try PDFFixtures.create(at: url, count: 3)
            let source = try SourceSnapshot.open(url)
            let occupied = root.appendingPathComponent("scan-split")
            try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: false)
            let occupiedFile = root.appendingPathComponent("scan-split-2")
            try Data("keep".utf8).write(to: occupiedFile)
            let hooks = ExportHooks(exclusiveRename: { _, _ in ENOTSUP }, beforePortablePublish: { staged, _ in
                let files = try FileManager.default.contentsOfDirectory(at: staged, includingPropertiesForKeys: nil)
                #expect(files.count == 2)
                #expect(files.allSatisfy { PDFDocument(url: $0)?.pageCount == 1 })
            })
            let result = try PDFExporter.export(source: source, groups: [[0], [2]], parent: root, hooks: hooks)
            #expect(result.folder.deletingLastPathComponent().lastPathComponent == "scan-split-3")
            #expect(result.folder.lastPathComponent == "Documents")
            #expect(result.documentCount == 2); #expect(result.pageCount == 2)
            #expect(PDFDocument(url: result.folder.appendingPathComponent("scan-001.pdf"))?.page(at: 0)?.string == PDFDocument(url: url)?.page(at: 0)?.string)
            #expect(PDFDocument(url: result.folder.appendingPathComponent("scan-002.pdf"))?.page(at: 0)?.string == PDFDocument(url: url)?.page(at: 2)?.string)
            #expect(try FileManager.default.contentsOfDirectory(atPath: occupied.path).isEmpty)
            #expect(try Data(contentsOf: occupiedFile) == Data("keep".utf8))
            try source.verifyOriginal()
        }
    }
    @Test func portablePublicationFailuresAndCancellationCleanUp() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("scan.pdf"); try PDFFixtures.create(at: url, count: 1)
            let source = try SourceSnapshot.open(url)
            let existing = root.appendingPathComponent("scan-split")
            try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: false)
            try Data("keep".utf8).write(to: existing.appendingPathComponent("keep.txt"))
            for mode in 0..<3 {
                let flag = CancellationFlag()
                let hooks = ExportHooks(exclusiveRename: { _, _ in ENOTSUP }, beforePortablePublish: { _, completed in
                    if mode == 0 { throw ScanError("Injected publication failure") }
                    if mode == 1 { flag.cancel() }
                    if mode == 2 { try Data("occupied".utf8).write(to: completed) }
                })
                #expect(throws: (any Error).self) { _ = try PDFExporter.export(source: source, groups: [[0]], parent: root, cancellation: flag, hooks: hooks) }
                #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["scan-split", "scan.pdf"])
                #expect(try Data(contentsOf: existing.appendingPathComponent("keep.txt")) == Data("keep".utf8))
            }
            let hooks = ExportHooks(beforeCleanup: { _ in throw ScanError("Injected cleanup failure") }, exclusiveRename: { _, _ in ENOTSUP }, beforePortablePublish: { _, _ in throw ScanError("Injected publication failure") })
            do { _ = try PDFExporter.export(source: source, groups: [[0]], parent: root, hooks: hooks); Issue.record("Expected cleanup failure") }
            catch {
                #expect(error.localizedDescription.contains("Incomplete files remain"))
                #expect(error.localizedDescription.contains("scan-split-2"))
                #expect(error.localizedDescription.contains(".scansplit-"))
            }
            try source.verifyOriginal()
        }
    }
    @Test func otherPublicationErrorsDoNotUseFallback() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("scan.pdf"); try PDFFixtures.create(at: url, count: 1)
            let source = try SourceSnapshot.open(url)
            for code in [EACCES, ENOSPC, EIO] {
                let hooks = ExportHooks(exclusiveRename: { _, _ in code }, beforePortablePublish: { _, _ in Issue.record("Unexpected fallback") })
                #expect(throws: ScanError.self) { _ = try PDFExporter.export(source: source, groups: [[0]], parent: root, hooks: hooks) }
                #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["scan.pdf"])
            }
        }
    }
    @Test func invalidInputsAndEmptyPlan() throws {
        try withFolder { root in
            let invalid = root.appendingPathComponent("bad.pdf"); try Data("not a PDF".utf8).write(to: invalid)
            #expect(throws: ScanError.self) { _ = try SourceSnapshot.open(invalid) }
            let zero = root.appendingPathComponent("empty.pdf"); try PDFFixtures.createEmpty(at: zero)
            #expect(try Data(contentsOf: zero).count > 0)
            #expect(throws: ScanError.self) { _ = try SourceSnapshot.open(zero) }
            let url = root.appendingPathComponent("scan.pdf"); try PDFFixtures.create(at: url, count: 1)
            let document = try #require(PDFDocument(url: url))
            let encrypted = root.appendingPathComponent("encrypted.pdf")
            #expect(document.write(to: encrypted, withOptions: [.ownerPasswordOption: "fixture-owner", .userPasswordOption: "fixture-user"]))
            #expect(throws: ScanError.self) { _ = try SourceSnapshot.open(encrypted) }
            let source = try SourceSnapshot.open(url)
            let before = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
            #expect(throws: ScanError.self) { _ = try PDFExporter.export(source: source, groups: [], parent: root) }
            #expect(before == (try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()))
            #expect(PDFExporter.safeBase("/:") == "--")
            #expect(PDFExporter.safeBase("...") == "scan")
        }
    }
    @Test func sixtyPageScanProducesTwentyDocuments() throws {
        try withFolder { root in
            let url = root.appendingPathComponent("bulk-60.pdf"); try PDFFixtures.create(at: url, count: 60, scanned: true)
            let source = try SourceSnapshot.open(url)
            var review = Review(pageCount: 60)
            for document in 0..<20 { review.select(document * 3 + 1); review.toggleEnd(); review.toggleExcluded() }
            #expect(review.groups.count == 20); #expect(review.excludedCount == 20)
            let result = try PDFExporter.export(source: source, groups: review.groups, parent: root)
            #expect(result.documentCount == 20); #expect(result.pageCount == 40)
            #expect(try FileManager.default.contentsOfDirectory(atPath: result.folder.path).count == 20)
        }
    }
    @Test func reusableDemoFixture() throws {
        guard let path = ProcessInfo.processInfo.environment["SCANSPLIT_FIXTURE_PATH"] else { return }
        try PDFFixtures.create(at: URL(fileURLWithPath: path), count: 60, scanned: true)
        #expect(PDFDocument(url: URL(fileURLWithPath: path))?.pageCount == 60)
    }
}
