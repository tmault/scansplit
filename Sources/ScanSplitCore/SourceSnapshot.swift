import Foundation
import CryptoKit
@preconcurrency import PDFKit

public struct ScanError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

private struct SourceIdentity: Equatable {
    let size: UInt64
    let inode: UInt64
    let modified: Date
    init(_ url: URL) throws {
        let values = try FileManager.default.attributesOfItem(atPath: url.path)
        size = (values[.size] as? NSNumber)?.uint64Value ?? 0
        inode = (values[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        modified = values[.modificationDate] as? Date ?? .distantPast
    }
}

/// Immutable paths/digest only. Each worker opens its own PDFDocument; none is shared.
public final class SourceSnapshot: @unchecked Sendable {
    public let originalURL: URL
    public let snapshotURL: URL
    public let pageCount: Int
    public let digest: Data
    private let folderURL: URL
    private let identity: SourceIdentity

    private init(original: URL, snapshot: URL, folder: URL, count: Int, digest: Data, identity: SourceIdentity) {
        originalURL = original; snapshotURL = snapshot; folderURL = folder
        pageCount = count; self.digest = digest; self.identity = identity
    }
    deinit { try? FileManager.default.removeItem(at: folderURL) }

    public static func open(_ url: URL) throws -> SourceSnapshot {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ScanSplit-\(UUID().uuidString)", isDirectory: true)
        do {
            let before = try SourceIdentity(url)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let copy = folder.appendingPathComponent("source.pdf")
            try FileManager.default.copyItem(at: url, to: copy)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: copy.path)
            guard before == (try SourceIdentity(url)) else { throw ScanError("The PDF changed while opening. Please open it again.") }
            guard let document = PDFDocument(url: copy) else { throw ScanError("This file is not a readable PDF.") }
            guard !document.isEncrypted else { throw ScanError("Encrypted PDFs are not supported yet. Choose an unencrypted copy.") }
            guard document.pageCount > 0 else { throw ScanError("This PDF has no pages.") }
            return SourceSnapshot(original: url, snapshot: copy, folder: folder, count: document.pageCount, digest: try hash(copy), identity: before)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            if let known = error as? ScanError { throw known }
            throw ScanError("Cannot open this PDF: \(error.localizedDescription)")
        }
    }

    public func verifyOriginal() throws {
        do {
            guard identity == (try SourceIdentity(originalURL)), digest == (try Self.hash(originalURL)), identity == (try SourceIdentity(originalURL)) else {
                throw ScanError("The source PDF changed after review started. Open it again before exporting.")
            }
        } catch let error as ScanError { throw error }
        catch { throw ScanError("The source PDF is unavailable. Open it again before exporting.") }
    }

    public static func hash(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hasher.update(data: chunk) }
        return Data(hasher.finalize())
    }
}
