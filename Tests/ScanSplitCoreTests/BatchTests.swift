import Testing
import Foundation
@preconcurrency import PDFKit
@testable import ScanSplitCore

@Suite(.serialized) @MainActor
struct BatchTests {
    @Test func mappingAndTransactionalLoading() throws {
        try PDFTests().withFolder { root in
            let z = root.appendingPathComponent("z.pdf"), a = root.appendingPathComponent("a.pdf")
            try PDFFixtures.create(at: z, count: 3); try PDFFixtures.create(at: a, count: 2)
            var current = try SourceBatch.open([z, a, z])
            let originalID = current.id
            #expect(current.offsets == [0, 3, 5]); #expect(current.pageCount == 8)
            #expect(current.mandatoryEnds == [2, 4, 7])
            #expect(current.location(3) == PageLocation(source: 1, page: 0))
            #expect(current.location(7) == PageLocation(source: 2, page: 2))
            #expect(current.location(-1) == nil); #expect(current.location(8) == nil)
            let single = try SourceBatch.open([a])
            #expect(single.location(1) == PageLocation(source: 0, page: 1))
            let invalid = root.appendingPathComponent("broken.pdf")
            try Data("invalid".utf8).write(to: invalid)
            let temp = FileManager.default.temporaryDirectory
            let before = Set(try FileManager.default.contentsOfDirectory(atPath: temp.path).filter { $0.hasPrefix("ScanSplit-") })
            do { current = try SourceBatch.open([z, invalid]); Issue.record("Expected import failure") }
            catch { #expect(error.localizedDescription.contains("broken.pdf")) }
            #expect(current.id == originalID)
            let after = Set(try FileManager.default.contentsOfDirectory(atPath: temp.path).filter { $0.hasPrefix("ScanSplit-") })
            #expect(before == after)
        }
    }
    @Test func immutableBoundariesAndGlobalUndo() {
        var review = Review(pageCount: 8, mandatoryEnds: [2, 4, 7])
        #expect(review.groups == [[0, 1, 2], [3, 4], [5, 6, 7]])
        review.select(2); review.toggleEnd()
        #expect(review.selected == 3); #expect(!review.canUndo)
        review.select(2); review.toggleExcluded()
        #expect(review.selected == 3); review.undo()
        #expect(review.selected == 2); #expect(review.excludedCount == 0)
        for page in [2, 3, 4] { review.select(page); review.toggleExcluded() }
        #expect(review.groups == [[0, 1], [5, 6, 7]])
        review.select(0); review.toggleEnd()
        #expect(review.groups == [[0], [1], [5, 6, 7]])
        for page in [0, 1, 5, 6, 7] { review.select(page); review.toggleExcluded() }
        #expect(review.groups.isEmpty); #expect(review.mandatoryEnds == [2, 4, 7])
    }
    @Test func dropCompletionOrderDoesNotChangeIntake() {
        let z = URL(fileURLWithPath: "/z.pdf"), a = URL(fileURLWithPath: "/a.pdf")
        var intake = OrderedFileIntake(count: 2)
        intake.receive(a, at: 1); #expect(!intake.complete)
        intake.receive(z, at: 0); #expect(intake.urls == [z, a])
        var bad = OrderedFileIntake(count: 2)
        bad.receive(nil, at: 0); bad.receive(a, at: 1)
        #expect(bad.complete); #expect(bad.urls == nil)
    }
    @Test func multiSourceExportPreservesPagesAndNaming() throws {
        try PDFTests().withFolder { root in
            let z = root.appendingPathComponent("z.pdf"), a = root.appendingPathComponent("a.pdf")
            try PDFFixtures.create(at: z, count: 6, scanned: true)
            try PDFFixtures.create(at: a, count: 6)
            let batch = try SourceBatch.open([z, a, z])
            let hashes = try [z, a].map { try SourceSnapshot.hash($0) }
            let groups = [[0, 1], [3, 5], [6, 9, 11], [12]]
            let result = try PDFExporter.export(batch: batch, groups: groups, parent: root)
            #expect(result.documentCount == 4); #expect(result.pageCount == 8)
            #expect(result.folder.lastPathComponent == "scansplit-batch")
            let names = ["001-z.pdf", "002-z.pdf", "003-a.pdf", "004-z.pdf"]
            #expect(try FileManager.default.contentsOfDirectory(atPath: result.folder.path).sorted() == names)
            for (index, group) in groups.enumerated() {
                let output = try #require(PDFDocument(url: result.folder.appendingPathComponent(names[index])))
                for (position, global) in group.enumerated() {
                    let loc = try #require(batch.location(global))
                    let input = try #require(PDFDocument(url: batch.sources[loc.source].originalURL))
                    let left = try #require(input.page(at: loc.page)), right = try #require(output.page(at: position))
                    #expect(left.string == right.string)
                    #expect(PDFFixtures.pixels(left) == PDFFixtures.pixels(right))
                    #expect(PDFFixtures.imageSizes(left) == PDFFixtures.imageSizes(right))
                    #expect(left.rotation == right.rotation)
                    for box in [PDFDisplayBox.mediaBox, .cropBox, .bleedBox, .trimBox, .artBox] { #expect(left.bounds(for: box) == right.bounds(for: box)) }
                }
            }
            #expect(try [z, a].map { try SourceSnapshot.hash($0) } == hashes)
            let again = try PDFExporter.export(batch: batch, groups: [[0], [6]], parent: root)
            #expect(again.folder.lastPathComponent == "scansplit-batch-2")
            #expect(throws: ScanError.self) { _ = try PDFExporter.export(batch: batch, groups: [[5, 6]], parent: root) }
            #expect(throws: ScanError.self) { _ = try PDFExporter.export(batch: batch, groups: [], parent: root) }
        }
    }
    @Test func lateBatchFailureCancellationAndChangedOriginal() throws {
        try PDFTests().withFolder { root in
            let z = root.appendingPathComponent("z.pdf"), a = root.appendingPathComponent("a.pdf")
            try PDFFixtures.create(at: z, count: 2); try PDFFixtures.create(at: a, count: 2)
            let batch = try SourceBatch.open([z, a])
            for mode in 0..<3 {
                let flag = CancellationFlag()
                let hooks = ExportHooks(beforeWrite: { index, _ in
                    if mode == 0 && index == 1 { throw ScanError("late write") }
                }, afterWrite: { index, file in
                    if index == 1 && mode == 1 { try Data("invalid".utf8).write(to: file) }
                    if index == 1 && mode == 2 { flag.cancel() }
                })
                #expect(throws: (any Error).self) { _ = try PDFExporter.export(batch: batch, groups: [[0], [2]], parent: root, cancellation: flag, hooks: hooks) }
                #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["a.pdf", "z.pdf"])
            }
            try PDFFixtures.create(at: a, count: 1)
            do { _ = try PDFExporter.export(batch: batch, groups: [[0], [2]], parent: root); Issue.record("Expected changed source") }
            catch { #expect(error.localizedDescription.contains("a.pdf")) }
            try FileManager.default.removeItem(at: a)
            #expect(throws: ScanError.self) { _ = try PDFExporter.export(batch: batch, groups: [[0]], parent: root) }
        }
    }
}
