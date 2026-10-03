import Foundation
import CoreGraphics
import CoreText
import AppKit
@preconcurrency import PDFKit
import ScanSplitCore

enum PDFFixtures {
    static func createEmpty(at url: URL) throws {
        var pdf = "%PDF-1.4\n"
        let catalog = pdf.utf8.count
        pdf += "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
        let pages = pdf.utf8.count
        pdf += "2 0 obj\n<< /Type /Pages /Kids [] /Count 0 >>\nendobj\n"
        let xref = pdf.utf8.count
        pdf += "xref\n0 3\n0000000000 65535 f \n"
        pdf += String(format: "%010d 00000 n \n%010d 00000 n \n", catalog, pages)
        pdf += "trailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        try Data(pdf.utf8).write(to: url)
    }

    static func create(at url: URL, count: Int = 8, scanned: Bool = false) throws {
        var media = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &media, nil) else { throw ScanError("Cannot create fixture") }
        for index in 0..<count {
            var pageBox = index % 7 == 3 ? CGRect(x: 0, y: 0, width: 500, height: 700) : media
            let boxData = NSData(bytes: &pageBox, length: MemoryLayout<CGRect>.size)
            context.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
            if scanned {
                let width = 1275, height = 1650
                let space = CGColorSpaceCreateDeviceRGB()
                guard let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ScanError("Fixture image") }
                bitmap.setFillColor(CGColor(gray: 1, alpha: 1)); bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
                if index % 3 != 2 {
                    bitmap.setFillColor(CGColor(red: 0.05, green: 0.4, blue: 0.38, alpha: 1))
                    bitmap.fill(CGRect(x: 90, y: 1410, width: 1090, height: 5))
                    drawText("EXAMPLE DOCUMENT \(index / 3 + 1)", at: CGPoint(x: 90, y: 1490), size: 42, in: bitmap)
                    drawText("Page \(index % 3 + 1) · Source page \(index + 1)", at: CGPoint(x: 90, y: 1430), size: 24, in: bitmap)
                    for row in 0..<18 { drawText("Sample scan row \(row + 1)    Reference \(1000 + index)    123.45 CHF", at: CGPoint(x: 90, y: 1310 - row * 48), size: 22, in: bitmap) }
                }
                guard let image = bitmap.makeImage() else { throw ScanError("Fixture bitmap") }
                context.draw(image, in: pageBox)
            } else {
                context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(pageBox)
                context.setStrokeColor(CGColor(red: Double(index) / Double(max(1, count)), green: 0.4, blue: 0.2, alpha: 1))
                context.stroke(CGRect(x: 45, y: 45, width: pageBox.width - 90, height: pageBox.height - 90), width: 4)
                drawText("Source page \(index + 1)", at: CGPoint(x: 70, y: pageBox.height - 100), size: 28, in: context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        if let document = PDFDocument(url: url), count > 5 {
            document.page(at: 5)?.rotation = 90
            guard document.write(to: url) else { throw ScanError("Fixture rotation write") }
        }
    }
    static func drawText(_ text: String, at point: CGPoint, size: CGFloat, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let string = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.12, alpha: 1)])
        context.textPosition = point
        CTLineDraw(CTLineCreateWithAttributedString(string), context)
    }
    static func pixels(_ page: PDFPage) -> Data {
        let image = page.thumbnail(of: NSSize(width: 360, height: 480), for: .mediaBox)
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return Data() }
        let bitmap = NSBitmapImageRep(cgImage: cg)
        guard let data = bitmap.bitmapData else { return Data() }
        return Data(bytes: data, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }
    private final class ImageSizes { var values: [String] = [] }
    static func imageSizes(_ page: PDFPage) -> [String] {
        guard let pageRef = page.pageRef, let pageDictionary = pageRef.dictionary else { return [] }
        var resources: CGPDFDictionaryRef?, objects: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resources), let resources,
              CGPDFDictionaryGetDictionary(resources, "XObject", &objects), let objects else { return [] }
        let sizes = ImageSizes()
        CGPDFDictionaryApplyFunction(objects, { _, object, info in
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(object, .stream, &stream), let stream, let info else { return }
            guard let dictionary = CGPDFStreamGetDictionary(stream) else { return }
            var width: CGPDFInteger = 0, height: CGPDFInteger = 0
            if CGPDFDictionaryGetInteger(dictionary, "Width", &width), CGPDFDictionaryGetInteger(dictionary, "Height", &height) {
                Unmanaged<ImageSizes>.fromOpaque(info).takeUnretainedValue().values.append("\(width)x\(height)")
            }
        }, Unmanaged.passUnretained(sizes).toOpaque())
        return sizes.values.sorted()
    }
}
