import AppKit
import SwiftUI
import ScanSplitCore

@main
@MainActor
enum ScanSplitMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = AppModel()
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenus()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 850), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ScanSplit"
        window.minSize = NSSize(width: 780, height: 560)
        window.isReleasedWhenClosed = false
        window.delegate = self
        let hosting = NSHostingView(rootView: ContentView(model: model))
        // AppKit owns the window size; a newly rotated PDF must not resize it.
        hosting.sizingOptions = []
        window.contentView = hosting
        model.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        let args = ProcessInfo.processInfo.arguments
        if let position = args.firstIndex(of: "--verification-report"), args.count > position + 1 { model.verificationReportURL = URL(fileURLWithPath: args[position + 1]) }
        if let position = args.firstIndex(of: "--verification-warmup"), args.count > position + 1 { model.verificationWarmup = Int(args[position + 1]) ?? 0 }
    }
    func application(_ application: NSApplication, open urls: [URL]) { model.openFiles(urls) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.mayDiscard() else { return .terminateCancel }
        model.clear()
        return .terminateNow
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { model.mayDiscard() }
    func windowWillClose(_ notification: Notification) { model.clear() }
    @objc func openPDF(_ sender: Any?) { model.choosePDF() }
    @objc func exportPDFs(_ sender: Any?) { model.chooseDestination() }
    @objc func undo(_ sender: Any?) { model.perform(.undo) }
    @objc func endPage(_ sender: Any?) { model.perform(.end) }
    @objc func excludePage(_ sender: Any?) { model.perform(.exclude) }
    @objc func nextPage(_ sender: Any?) { model.perform(.next) }
    @objc func previousPage(_ sender: Any?) { model.perform(.previous) }
    @objc func fitPage(_ sender: Any?) { model.viewer?.autoScales = true; model.refocus() }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(openPDF(_:)) { return !model.busy }
        if item.action == #selector(exportPDFs(_:)) { return model.canExport }
        if item.action == #selector(undo(_:)) { return model.canReview && model.review?.canUndo == true }
        return model.canReview
    }
    private func makeMenus() {
        let bar = NSMenu()
        let appMenu = NSMenu(title: "ScanSplit")
        appMenu.addItem(withTitle: "About ScanSplit", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ScanSplit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appRoot = NSMenuItem(); appRoot.submenu = appMenu; bar.addItem(appRoot)
        let file = NSMenu(title: "File")
        add(file, "Open PDFs…", #selector(openPDF(_:)), key: "o")
        add(file, "Export Documents…", #selector(exportPDFs(_:)), key: "e")
        file.addItem(.separator())
        file.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        let fileRoot = NSMenuItem(title: "File", action: nil, keyEquivalent: ""); fileRoot.submenu = file; bar.addItem(fileRoot)
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: #selector(undo(_:)), keyEquivalent: "z"))
        let editRoot = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editRoot.submenu = edit; bar.addItem(editRoot)
        let review = NSMenu(title: "Review")
        add(review, "Previous Page", #selector(previousPage(_:)))
        add(review, "Next Page", #selector(nextPage(_:)))
        review.addItem(.separator())
        add(review, "Toggle Document End and Advance", #selector(endPage(_:)))
        add(review, "Exclude / Restore and Advance", #selector(excludePage(_:)))
        review.addItem(.separator())
        add(review, "Fit Page", #selector(fitPage(_:)))
        let reviewRoot = NSMenuItem(title: "Review", action: nil, keyEquivalent: ""); reviewRoot.submenu = review; bar.addItem(reviewRoot)
        NSApp.mainMenu = bar
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self; menu.addItem(item)
    }
}
