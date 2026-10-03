import Foundation
import Darwin
@preconcurrency import PDFKit

public final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    public init() {}
    public func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    public func check() throws { if isCancelled { throw CancellationError() } }
}

public struct ExportResult: Sendable {
    public let folder: URL
    public let documentCount: Int
    public let pageCount: Int
}

/// Narrow fault checkpoints exercise failed writes, unsupported filesystem operations and cleanup.
public struct ExportHooks: Sendable {
    public var beforeWrite: @Sendable (Int, URL) throws -> Void
    public var afterWrite: @Sendable (Int, URL) throws -> Void
    public var beforeCleanup: @Sendable (URL) throws -> Void
    public var exclusiveRename: @Sendable (URL, URL) -> Int32
    public var beforePortablePublish: @Sendable (URL, URL) throws -> Void
    public init(beforeWrite: @escaping @Sendable (Int, URL) throws -> Void = { _, _ in }, afterWrite: @escaping @Sendable (Int, URL) throws -> Void = { _, _ in }, beforeCleanup: @escaping @Sendable (URL) throws -> Void = { _ in }, exclusiveRename: @escaping @Sendable (URL, URL) -> Int32 = { from, to in
        let result = from.path.withCString { a in to.path.withCString { b in renamex_np(a, b, UInt32(RENAME_EXCL)) } }
        return result == 0 ? 0 : errno
    }, beforePortablePublish: @escaping @Sendable (URL, URL) throws -> Void = { _, _ in }) {
        self.beforeWrite = beforeWrite; self.afterWrite = afterWrite; self.beforeCleanup = beforeCleanup
        self.exclusiveRename = exclusiveRename; self.beforePortablePublish = beforePortablePublish
    }
}

public enum PDFExporter {
    public static func safeBase(_ name: String) -> String {
        let unsafe = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:\\"))
        let clean = name.components(separatedBy: unsafe).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = String(clean.prefix(100)).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return trimmed.isEmpty ? "scan" : trimmed
    }

    public static func export(source: SourceSnapshot, groups: [[Int]], parent: URL, cancellation: CancellationFlag = CancellationFlag(), progress: @Sendable (Double) -> Void = { _ in }, hooks: ExportHooks = ExportHooks()) throws -> ExportResult {
        try export(batch: SourceBatch(sources: [source]), groups: groups, parent: parent, cancellation: cancellation, progress: progress, hooks: hooks)
    }

    public static func export(batch: SourceBatch, groups: [[Int]], parent: URL, cancellation: CancellationFlag = CancellationFlag(), progress: @Sendable (Double) -> Void = { _ in }, hooks: ExportHooks = ExportHooks()) throws -> ExportResult {
        let pages = groups.flatMap { $0 }
        guard !groups.isEmpty, !groups.contains(where: { $0.isEmpty }), pages == pages.sorted(), Set(pages).count == pages.count, pages.allSatisfy({ (0..<batch.pageCount).contains($0) }) else {
            throw ScanError("There are no valid pages to export.")
        }
        try cancellation.check()
        guard groups.allSatisfy({ group in
            let first = batch.location(group[0])?.source
            return group.allSatisfy { batch.location($0)?.source == first }
        }) else { throw ScanError("An output document cannot cross a source-file boundary.") }
        try batch.verifyOriginals()
        let multiple = batch.sources.count > 1
        let base = multiple ? "scansplit-batch" : safeBase(batch.sources[0].originalURL.deletingPathExtension().lastPathComponent)
        var activeSource: Int?
        var activeDocument: PDFDocument?
        let staging = parent.appendingPathComponent(".scansplit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var reservedFolder: URL?
        do {
            let width = max(3, String(groups.count).count)
            for (index, group) in groups.enumerated() {
                try cancellation.check()
                try autoreleasepool {
                    guard let location = batch.location(group[0]) else { throw ScanError("Invalid source page.") }
                    let source = batch.sources[location.source]
                    if activeSource != location.source {
                        activeDocument = PDFDocument(url: source.snapshotURL)
                        activeSource = location.source
                    }
                    guard let document = activeDocument, document.pageCount == source.pageCount else {
                        throw ScanError("Cannot read snapshot for \(source.originalURL.lastPathComponent). Open the PDFs again.")
                    }
                    let offset = batch.offsets[location.source]
                    let output = PDFDocument()
                    for sourcePage in group {
                        try cancellation.check()
                        guard let copy = document.page(at: sourcePage - offset)?.copy() as? PDFPage else { throw ScanError("Cannot copy source page \(sourcePage + 1).") }
                        output.insert(copy, at: output.pageCount)
                    }
                    let number = String(format: "%0*d", width, index + 1)
                    let stem = safeBase(source.originalURL.deletingPathExtension().lastPathComponent)
                    let filename = multiple ? "\(number)-\(stem).pdf" : "\(base)-\(number).pdf"
                    let url = staging.appendingPathComponent(filename)
                    try hooks.beforeWrite(index, url)
                    guard output.write(to: url) else { throw ScanError("Could not write document \(index + 1). Check the destination folder.") }
                    try hooks.afterWrite(index, url)
                    try cancellation.check()
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    guard (attributes[.size] as? NSNumber)?.intValue ?? 0 > 0, let verified = PDFDocument(url: url), verified.pageCount == group.count else {
                        throw ScanError("Document \(index + 1) did not pass verification. No completed batch was created.")
                    }
                    for (position, sourcePage) in group.enumerated() {
                        guard let before = document.page(at: sourcePage - offset), let after = verified.page(at: position), before.rotation == after.rotation,
                              [PDFDisplayBox.mediaBox, .cropBox, .bleedBox, .trimBox, .artBox].allSatisfy({ before.bounds(for: $0) == after.bounds(for: $0) }) else {
                            throw ScanError("Document \(index + 1) changed page geometry. No completed batch was created.")
                        }
                    }
                }
                progress(Double(index + 1) / Double(groups.count))
            }
            try cancellation.check()
            try batch.verifyOriginals()
            // Prefer a single exclusive rename. Some mounted shares reject RENAME_EXCL.
            // There, mkdir reserves a new container; moving the entire verified directory
            // into its absent Documents child exposes no partly written PDF or existing batch.
            var suffix = 1
            var usePortablePublish = false
            while true {
                try cancellation.check()
                let folderBase = multiple ? base : "\(base)-split"
                let name = suffix == 1 ? folderBase : "\(folderBase)-\(suffix)"
                let destination = parent.appendingPathComponent(name, isDirectory: true)
                if !usePortablePublish {
                    let status = hooks.exclusiveRename(staging, destination)
                    if status == 0 { return ExportResult(folder: destination, documentCount: groups.count, pageCount: pages.count) }
                    if status == EEXIST { suffix += 1; continue }
                    guard status == ENOTSUP else { throw ScanError("Cannot publish the export batch: \(String(cString: strerror(status))).") }
                    usePortablePublish = true
                }
                // Foundation's createDirectory accepts an existing directory. POSIX mkdir
                // is required here so even empty directories and concurrent exports collide.
                let code = destination.path.withCString { mkdir($0, 0o700) }
                let status = code == 0 ? 0 : errno
                if status == EEXIST { suffix += 1; continue }
                guard status == 0 else { throw ScanError("Cannot create the export folder: \(String(cString: strerror(status))).") }
                reservedFolder = destination
                let completed = destination.appendingPathComponent("Documents", isDirectory: true)
                try hooks.beforePortablePublish(staging, completed)
                try cancellation.check()
                try FileManager.default.moveItem(at: staging, to: completed)
                return ExportResult(folder: completed, documentCount: groups.count, pageCount: pages.count)
            }
        } catch {
            var remaining: [String] = []
            for folder in [reservedFolder, staging].compactMap({ $0 }) {
                guard FileManager.default.fileExists(atPath: folder.path) else { continue }
                do { try hooks.beforeCleanup(folder); try FileManager.default.removeItem(at: folder) }
                catch { remaining.append(folder.path) }
            }
            if !remaining.isEmpty {
                throw ScanError("Export did not complete. Incomplete files remain at \(remaining.joined(separator: "; ")). Remove those folders after checking them; your source and existing files were not changed.")
            }
            throw error
        }
    }
}
