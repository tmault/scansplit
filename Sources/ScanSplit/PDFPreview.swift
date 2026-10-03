import AppKit
import SwiftUI
import QuartzCore
@preconcurrency import PDFKit
import ScanSplitCore

@MainActor
final class ReviewPDFView: PDFView, NSUserInterfaceValidations {
    weak var model: AppModel?
    var lastFocus = -1
    var lastPage = -1
    // Review presents a page image. Avoid PDFKit's text-analysis accessibility tree
    // for image-only scans; page navigation and decisions have separate controls.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .image }
    override func accessibilityLabel() -> String? { "PDF preview, \(model?.pageLabel ?? "")" }
    override func accessibilityChildren() -> [Any]? { [] }
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        guard window?.attachedSheet == nil, NSApp.modalWindow == nil, NSApp.keyWindow === window else { super.keyDown(with: event); return }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty {
            if let action = ReviewKeys.action(keyCode: event.keyCode, isRepeat: event.isARepeat) { model?.perform(action); return }
            if [49, 51, 117].contains(event.keyCode) { return }
        }
        super.keyDown(with: event)
    }
    @objc func undo(_ sender: Any?) { model?.perform(.undo) }
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(undo(_:)) { return model?.canReview == true && model?.review?.canUndo == true }
        return true
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); super.mouseDown(with: event) }
}

struct PDFPreview: NSViewRepresentable {
    @ObservedObject var model: AppModel
    func makeNSView(context: Context) -> ReviewPDFView {
        let view = ReviewPDFView()
        view.model = model; model.viewer = view
        view.displayMode = .singlePage; view.autoScales = true; view.displayBox = .cropBox
        view.backgroundColor = .windowBackgroundColor
        return view
    }
    func updateNSView(_ view: ReviewPDFView, context: Context) {
        if view.document !== model.document { view.document = model.document; view.lastPage = -1; view.autoScales = true }
        if let selected = model.review == nil ? nil : model.localPage, selected != view.lastPage, let page = model.document?.page(at: selected) {
            view.lastPage = selected; view.go(to: page)
            if view.autoScales { view.autoScales = true }
        }
        if let started = model.navigationStarted {
            let marking = model.pendingMarking
            model.navigationStarted = nil
            DispatchQueue.main.async { [weak view, weak model] in
                guard let view, let model else { return }
                view.window?.contentView?.layoutSubtreeIfNeeded()
                view.window?.contentView?.displayIfNeeded()
                CATransaction.flush()
                let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1000
                model.displayTimings.append(elapsed)
                if marking { model.markingTimings.append(elapsed) }
                if model.displayTimings.count > 240 { model.displayTimings.removeFirst() }
                if model.markingTimings.count > 240 { model.markingTimings.removeFirst() }
            }
        }
        if let started = model.openingDisplayStarted {
            model.openingDisplayStarted = nil
            DispatchQueue.main.async { [weak view, weak model] in
                view?.window?.contentView?.layoutSubtreeIfNeeded(); view?.window?.contentView?.displayIfNeeded(); CATransaction.flush()
                model?.openingVisibleMilliseconds = (CFAbsoluteTimeGetCurrent() - started) * 1000
            }
        }
        if view.lastFocus != model.focusToken {
            view.lastFocus = model.focusToken
            DispatchQueue.main.async { [weak view] in
                guard let view, let window = view.window, window.attachedSheet == nil, NSApp.modalWindow == nil, NSApp.keyWindow === window else { return }
                window.makeFirstResponder(view)
            }
        }
    }
}
