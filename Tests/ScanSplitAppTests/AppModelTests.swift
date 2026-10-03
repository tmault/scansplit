import Testing
import Foundation
import CoreGraphics
@preconcurrency import PDFKit
@testable import ScanSplit
import ScanSplitCore

@Suite(.serialized) @MainActor
struct AppModelTests {
    func fixture(_ url: URL, width: CGFloat) throws {
        var box = CGRect(x: 0, y: 0, width: width, height: 400)
        let ctx = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        ctx.beginPDFPage(nil); ctx.setFillColor(CGColor(gray: 0.4, alpha: 1)); ctx.fill(CGRect(x: 10, y: 10, width: 30, height: 40)); ctx.endPDFPage(); ctx.closePDF()
    }
    func waitForLoad(_ model: AppModel) async {
        while model.loading { await Task.yield() }
    }
    @Test func transactionalImportAndSameLocalPageTransitions() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ScanSplit-model-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let z = folder.appendingPathComponent("z.pdf"), a = folder.appendingPathComponent("a.pdf")
        try fixture(z, width: 300); try fixture(a, width: 600)
        let model = AppModel()
        model.openFiles([z, a]); await waitForLoad(model)
        #expect(model.batch?.sources.map { $0.originalURL } == [z, a])
        #expect(model.document?.page(at: 0)?.bounds(for: .mediaBox).width == 300)
        model.perform(.next)
        #expect(model.localPage == 0)
        #expect(model.filename == "a.pdf")
        #expect(model.document?.page(at: 0)?.bounds(for: .mediaBox).width == 600)
        model.perform(.previous)
        #expect(model.document?.page(at: 0)?.bounds(for: .mediaBox).width == 300)
        await model.thumbnail(0); await model.thumbnail(1)
        #expect(model.thumbnails[0] != nil); #expect(model.thumbnails[1] != nil)
        let id = model.batch?.id
        let bad = folder.appendingPathComponent("bad.pdf"); try Data("bad".utf8).write(to: bad)
        model.openFiles([z, bad]); await waitForLoad(model)
        #expect(model.batch?.id == id)
        #expect(model.issue?.contains("bad.pdf") == true)
        #expect(model.document?.page(at: 0)?.bounds(for: .mediaBox).width == 300)
        model.openFiles([])
        #expect(model.batch?.id == id)
        model.perform(.exclude); model.perform(.exclude)
        #expect(!model.canExport)
        model.perform(.undo)
        #expect(model.canExport)
        model.clear()
        #expect(model.batch == nil); #expect(model.document == nil)
    }
}
