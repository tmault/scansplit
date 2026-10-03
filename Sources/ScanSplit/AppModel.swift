import AppKit
import Combine
import UniformTypeIdentifiers
@preconcurrency import PDFKit
import ScanSplitCore

actor ThumbnailWorker {
    private var url: URL?
    private var document: PDFDocument?
    func image(url: URL, page: Int) -> Data? {
        if self.url != url { document = PDFDocument(url: url); self.url = url }
        return autoreleasepool { document?.page(at: page)?.thumbnail(of: NSSize(width: 104, height: 140), for: .cropBox).tiffRepresentation }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var review: Review?
    @Published var document: PDFDocument?
    @Published var thumbnails: [Int: NSImage] = [:]
    @Published var loading = false
    @Published var exporting = false
    @Published var progress = 0.0
    @Published var issue: String?
    @Published var success: ExportResult?
    @Published var focusToken = 0
    @Published var notice = ""
    @Published var dropTarget = false
    @Published private var choosingFiles = false
    // Keep one panel per review window and fully reconfigure it for each use.
    private lazy var filePanel = NSOpenPanel()
    weak var window: NSWindow?
    weak var viewer: ReviewPDFView?
    private(set) var batch: SourceBatch?
    private var displayedSource: Int?
    var selectedLocation: PageLocation? { batch?.location(review?.selected ?? 0) }
    var source: SourceSnapshot? {
        guard let batch, let loc = selectedLocation else { return nil }
        return batch.sources[loc.source]
    }
    var localPage: Int { selectedLocation?.page ?? 0 }
    var pageLabel: String {
        guard let batch, let loc = selectedLocation else { return "" }
        return "File \(loc.source + 1) of \(batch.sources.count) · Page \(loc.page + 1) of \(batch.sources[loc.source].pageCount) · Batch \((review?.selected ?? 0) + 1) of \(batch.pageCount)"
    }
    func pageName(_ page: Int) -> String {
        guard let batch, let loc = batch.location(page) else { return "Page \(page + 1)" }
        return "\(batch.sources[loc.source].originalURL.lastPathComponent), page \(loc.page + 1)"
    }
    private var thumbnailWorker: ThumbnailWorker?
    private var pendingThumbnails: Set<Int> = []
    private var cancellation: CancellationFlag?
    var navigationStarted: Double?
    var displayTimings: [Double] = []
    var markingTimings: [Double] = []
    var pendingMarking = false
    var verificationReportURL: URL?
    var verificationWarmup = 0
    var openingDisplayStarted: Double?
    var openingVisibleMilliseconds: Double?
    var busy: Bool { loading || exporting || choosingFiles }
    var canReview: Bool { review != nil && !busy }
    var canExport: Bool { canReview && !(review?.groups.isEmpty ?? true) }
    var filename: String { source?.originalURL.lastPathComponent ?? "" }

    func choosePDF() {
        guard !busy else { return }
        let panel = filePanel
        panel.title = "Open PDFs"; panel.prompt = "Open"
        panel.canChooseDirectories = false; panel.canChooseFiles = true
        panel.canCreateDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf]
        present(panel) { [weak self] panel in self?.openFiles(panel.urls) }
    }
    private func present(_ panel: NSOpenPanel, selection: @escaping @MainActor (NSOpenPanel) -> Void) {
        guard let window, !choosingFiles else { return }
        choosingFiles = true
        panel.beginSheetModal(for: window) { [weak self] response in
            // Defer follow-up alerts and focus until the sheet has fully detached.
            DispatchQueue.main.async {
                guard let self else { return }
                self.choosingFiles = false
                if response == .OK { selection(panel) } else { self.refocus() }
            }
        }
    }
    func openFiles(_ urls: [URL]) {
        guard !busy else { return }
        guard !urls.isEmpty else { issue = "Choose at least one PDF."; return }
        guard mayDiscard() else { refocus(); return }
        loading = true
        let started = CFAbsoluteTimeGetCurrent()
        Task {
            do {
                let candidate = try await Task.detached(priority: .userInitiated) { try SourceBatch.open(urls) }.value
                let snapshot = candidate.sources[0]
                guard let pdf = PDFDocument(url: snapshot.snapshotURL) else { throw ScanError("Cannot display this PDF.") }
                batch = candidate; displayedSource = 0; document = pdf
                review = Review(pageCount: candidate.pageCount, mandatoryEnds: candidate.sources.count > 1 ? candidate.mandatoryEnds : [])
                openingDisplayStarted = started; openingVisibleMilliseconds = nil
                displayTimings = []; markingTimings = []
                thumbnailWorker = ThumbnailWorker()
                thumbnails = [:]; pendingThumbnails = []; success = nil; notice = ""
                loading = false
                window?.makeKeyAndOrderFront(nil)
                refocus()
                if ProcessInfo.processInfo.environment["SCANSPLIT_BENCHMARK"] != nil { notice = String(format: "Opened in %.1f ms", (CFAbsoluteTimeGetCurrent() - started) * 1000) }
            } catch { loading = false; issue = error.localizedDescription; refocus() }
        }
    }
    func perform(_ action: ReviewAction) {
        guard canReview else { return }
        let previous = review?.decisions
        navigationStarted = CFAbsoluteTimeGetCurrent()
        switch action {
        case .next: review?.move(1)
        case .previous: review?.move(-1)
        case .end: review?.toggleEnd()
        case .exclude: review?.toggleExcluded()
        case .undo: review?.undo()
        }
        switch action { case .end, .exclude, .undo: pendingMarking = true; default: pendingMarking = false }
        updateDocument()
        if previous != review?.decisions { success = nil; notice = "" }
        refocus()
    }
    func select(_ page: Int) {
        guard canReview else { return }
        pendingMarking = false
        navigationStarted = CFAbsoluteTimeGetCurrent(); review?.select(page); updateDocument(); refocus()
    }
    func refocus() { focusToken += 1 }
    private func updateDocument() {
        guard let batch, let loc = selectedLocation, displayedSource != loc.source else { return }
        document = PDFDocument(url: batch.sources[loc.source].snapshotURL)
        displayedSource = loc.source
    }
    func thumbnail(_ page: Int) async {
        guard let worker = thumbnailWorker, let batch, let loc = batch.location(page), thumbnails[page] == nil, !pendingThumbnails.contains(page) else { return }
        pendingThumbnails.insert(page)
        let data = await worker.image(url: batch.sources[loc.source].snapshotURL, page: loc.page)
        guard self.batch === batch else { return }
        pendingThumbnails.remove(page)
        guard !Task.isCancelled, let data, let image = NSImage(data: data) else { return }
        thumbnails[page] = image
        if thumbnails.count > 100 {
            let current = review?.selected ?? 0
            if let farthest = thumbnails.keys.max(by: { abs($0 - current) < abs($1 - current) }) { thumbnails.removeValue(forKey: farthest) }
        }
    }
    func openDroppedFiles(_ providers: [NSItemProvider]) {
        guard !busy, !providers.isEmpty else { return }
        // Resolve all providers before replacing the current review.
        loading = true
        Task {
            var intake = OrderedFileIntake(count: providers.count)
            for (index, provider) in providers.enumerated() {
                let url: URL? = await withCheckedContinuation { continuation in
                    _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        continuation.resume(returning: data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) })
                    }
                }
                intake.receive(url, at: index)
            }
            loading = false
            guard let urls = intake.urls else { issue = "Cannot read one of the dropped files."; refocus(); return }
            openFiles(urls)
        }
    }
    func mayDiscard() -> Bool {
        if busy { issue = "Finish or cancel the current operation before closing."; return false }
        guard review?.hasUnexportedChanges == true else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unexported decisions?"
        alert.informativeText = "Your scan stays untouched. Cuts and exclusions from this review will be lost."
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard Decisions")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func clear() {
        document = nil; review = nil; thumbnailWorker = nil; thumbnails = [:]; pendingThumbnails = []
        batch = nil; displayedSource = nil; success = nil
    }
    func chooseDestination() {
        guard canExport else { return }
        let panel = filePanel
        panel.title = "Choose where to save your documents"; panel.prompt = "Export Here"
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder]
        present(panel) { [weak self] panel in
            if let parent = panel.url { self?.export(to: parent) }
        }
    }
    func export(to parent: URL) {
        guard canExport, let batch, let state = review else { return }
        let flag = CancellationFlag(); cancellation = flag
        exporting = true; progress = 0; success = nil; notice = ""
        let owner = self
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try PDFExporter.export(batch: batch, groups: state.groups, parent: parent, cancellation: flag, progress: { value in
                        Task { @MainActor in if owner.cancellation === flag { owner.progress = value } }
                    })
                }.value
                review?.markExported(state.decisions); success = result
                notice = "\(result.documentCount) documents exported · \(result.pageCount) pages kept"
                VerificationRecorder.write(model: self)
            } catch is CancellationError { notice = "Export cancelled. Your review is ready to try again." }
            catch { issue = error.localizedDescription }
            exporting = false; cancellation = nil; refocus()
        }
    }
    func cancelExport() { cancellation?.cancel() }
    func revealExport() { if let success { NSWorkspace.shared.activateFileViewerSelecting([success.folder]) } }
}
