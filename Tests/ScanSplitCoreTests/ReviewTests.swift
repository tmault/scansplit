import Testing
@testable import ScanSplitCore

struct ReviewTests {
    @Test func testStableCutsExclusionsAndImplicitTail() {
        var review = Review(pageCount: 8)
        for page in [2, 5] { review.select(page); review.toggleEnd() }
        for page in [1, 5, 7] { review.select(page); review.toggleExcluded() }
        #expect(review.groups == [[0, 2], [3, 4], [6]])
        #expect(review.decisions.ends.contains(5))
        review.select(5); review.toggleEnd()
        #expect(review.groups == [[0, 2], [3, 4, 6]])
    }
    @Test func testBoundsRestorationAndUndoAfterNavigation() {
        var review = Review(pageCount: 4)
        review.move(-1); #expect(review.selected == 0)
        review.select(1); review.toggleExcluded(); #expect(review.selected == 2)
        review.select(3); review.move(1); #expect(review.selected == 3)
        review.undo(); #expect(review.selected == 1)
        #expect(review.decisions.excluded.isEmpty)
        review.toggleEnd(); review.select(3); review.undo()
        #expect(review.selected == 1); #expect(review.decisions.ends.isEmpty)
        review.toggleExcluded(); review.select(1); review.toggleExcluded()
        #expect(review.decisions.excluded.isEmpty)
    }
    @Test func testEmptyGroupsAdjacentEndsAndSinglePage() {
        var review = Review(pageCount: 4)
        #expect(review.groups == [[0, 1, 2, 3]])
        for page in 0..<4 { review.select(page); review.toggleEnd() }
        #expect(review.groups == [[0], [1], [2], [3]])
        for page in 0..<4 { review.select(page); review.toggleExcluded() }
        #expect(review.groups == [])
        review.select(2); review.toggleExcluded(); #expect(review.groups == [[2]])
        var single = Review(pageCount: 1); single.toggleEnd()
        #expect(single.selected == 0); #expect(single.groups == [[0]])
        #expect(Review(pageCount: 0).groups == [])
    }
    @Test func testExportedStateAndUndo() {
        var review = Review(pageCount: 2)
        #expect(!(review.hasUnexportedChanges))
        review.toggleEnd(); #expect(review.hasUnexportedChanges)
        review.markExported(review.decisions); #expect(!(review.hasUnexportedChanges))
        review.toggleExcluded(); #expect(review.hasUnexportedChanges)
        review.undo(); #expect(!(review.hasUnexportedChanges))
    }
    @Test func testMarkingRepeatAndBothDeleteKeys() {
        #expect(ReviewKeys.action(keyCode: 49, isRepeat: true) == nil)
        #expect(ReviewKeys.action(keyCode: 51, isRepeat: true) == nil)
        #expect(ReviewKeys.action(keyCode: 117, isRepeat: true) == nil)
        #expect(ReviewKeys.action(keyCode: 124, isRepeat: true) != nil)
        if case .exclude? = ReviewKeys.action(keyCode: 117, isRepeat: false) {} else { Issue.record("Forward Delete") }
    }
    @Test func testPartitionInvariantAcrossDecisionCombinations() {
        // Exhaust all exclusion/boundary combinations for a small scan, rather than mirror grouping.
        for excludedMask in 0..<32 {
            for endMask in 0..<32 {
                var review = Review(pageCount: 5)
                for page in 0..<5 {
                    if excludedMask & (1 << page) != 0 { review.select(page); review.toggleExcluded() }
                    if endMask & (1 << page) != 0 { review.select(page); review.toggleEnd() }
                }
                let pages = review.groups.flatMap { $0 }
                #expect(pages == (0..<5).filter { excludedMask & (1 << $0) == 0 })
                #expect(Set(pages).count == pages.count)
                #expect(!(review.groups.contains(where: { $0.isEmpty })))
            }
        }
    }
}
