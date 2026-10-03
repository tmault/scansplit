import Foundation

public struct PageLocation: Equatable, Sendable {
    public let source: Int
    public let page: Int
}

/// Ordered immutable snapshots. Global positions never change when pages are excluded.
public final class SourceBatch: Sendable {
    public let id = UUID()
    public let sources: [SourceSnapshot]
    public let offsets: [Int]
    public let pageCount: Int
    public let mandatoryEnds: Set<Int>

    public init(sources: [SourceSnapshot]) {
        self.sources = sources
        var offsets: [Int] = [], total = 0, ends: Set<Int> = []
        for source in sources {
            offsets.append(total); total += source.pageCount
            ends.insert(total - 1)
        }
        self.offsets = offsets; pageCount = total; mandatoryEnds = ends
    }
    public static func open(_ urls: [URL]) throws -> SourceBatch {
        guard !urls.isEmpty else { throw ScanError("Choose at least one PDF.") }
        var snapshots: [SourceSnapshot] = []
        for url in urls {
            do { snapshots.append(try SourceSnapshot.open(url)) }
            catch { throw ScanError("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        return SourceBatch(sources: snapshots)
    }
    public func location(_ globalPage: Int) -> PageLocation? {
        guard (0..<pageCount).contains(globalPage) else { return nil }
        // Binary search keeps thumbnail/navigation mapping inexpensive for many files.
        var low = 0, high = offsets.count
        while low < high {
            let mid = (low + high) / 2
            if offsets[mid] <= globalPage { low = mid + 1 } else { high = mid }
        }
        let source = low - 1
        return PageLocation(source: source, page: globalPage - offsets[source])
    }
    public func verifyOriginals() throws {
        for source in sources {
            do { try source.verifyOriginal() }
            catch { throw ScanError("\(source.originalURL.lastPathComponent): \(error.localizedDescription)") }
        }
    }
}

/// Resolve asynchronous drop loads by provider position, never callback completion order.
public struct OrderedFileIntake: Sendable {
    private var slots: [URL?]
    private var received: Set<Int> = []
    public init(count: Int) { slots = Array(repeating: nil, count: count) }
    public mutating func receive(_ url: URL?, at index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index] = url; received.insert(index)
    }
    public var complete: Bool { received.count == slots.count }
    public var urls: [URL]? {
        guard complete, slots.allSatisfy({ $0 != nil }) else { return nil }
        return slots.compactMap { $0 }
    }
}
