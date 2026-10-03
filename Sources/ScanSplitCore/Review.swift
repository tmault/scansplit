import Foundation

public struct ReviewDecisions: Equatable, Sendable {
    public var excluded: Set<Int> = []
    public var ends: Set<Int> = []
    public init() {}
}

public struct Review: Sendable {
    public let pageCount: Int
    public let mandatoryEnds: Set<Int>
    public private(set) var selected = 0
    public private(set) var decisions = ReviewDecisions()
    private var exported = ReviewDecisions()
    private var history: [(page: Int, before: ReviewDecisions)] = []

    public init(pageCount: Int, mandatoryEnds: Set<Int> = []) {
        self.pageCount = max(0, pageCount)
        self.mandatoryEnds = mandatoryEnds.filter { (0..<max(0, pageCount)).contains($0) }
    }
    public var canUndo: Bool { !history.isEmpty }
    public var hasUnexportedChanges: Bool { decisions != exported }
    public var excludedCount: Int { decisions.excluded.count }
    public var groups: [[Int]] {
        guard pageCount > 0 else { return [] }
        var result: [[Int]] = [], current: [Int] = []
        for page in 0..<pageCount {
            if !decisions.excluded.contains(page) { current.append(page) }
            if decisions.ends.contains(page) || mandatoryEnds.contains(page) || page == pageCount - 1 {
                if !current.isEmpty { result.append(current) }
                current = []
            }
        }
        return result
    }
    public mutating func select(_ page: Int) {
        selected = min(max(0, page), max(0, pageCount - 1))
    }
    public mutating func move(_ delta: Int) { select(selected + delta) }
    public mutating func toggleEnd() {
        guard pageCount > 0 else { return }
        guard !mandatoryEnds.contains(selected) else { move(1); return }
        history.append((selected, decisions))
        if !decisions.ends.insert(selected).inserted { decisions.ends.remove(selected) }
        move(1)
    }
    public mutating func toggleExcluded() {
        guard pageCount > 0 else { return }
        history.append((selected, decisions))
        if !decisions.excluded.insert(selected).inserted { decisions.excluded.remove(selected) }
        move(1)
    }
    public mutating func undo() {
        guard let command = history.popLast() else { return }
        decisions = command.before
        selected = command.page
    }
    public mutating func markExported(_ snapshot: ReviewDecisions) { exported = snapshot }
}

public enum ReviewAction: Sendable { case next, previous, end, exclude, undo }

public enum ReviewKeys {
    /// Only unmodified review events enter here; panels/field editors are filtered by the view.
    public static func action(keyCode: UInt16, isRepeat: Bool) -> ReviewAction? {
        switch keyCode {
        case 124: return .next
        case 123: return .previous
        case 49: return isRepeat ? nil : .end
        case 51, 117: return isRepeat ? nil : .exclude
        default: return nil
        }
    }
}
