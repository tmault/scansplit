import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ScanSplitCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    private let accent = Color(nsColor: .systemBlue)
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let review = model.review {
                HStack(spacing: 0) {
                    thumbnails(review)
                    Divider()
                    VStack(spacing: 0) {
                        pageStatus(review)
                        PDFPreview(model: model).frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("PDF preview, \(model.pageLabel)")
                        actions(review)
                    }
                }
            } else { emptyState }
            Divider()
            footer
        }
        .tint(accent).background(Color(nsColor: .windowBackgroundColor))
        .overlay { if model.dropTarget { RoundedRectangle(cornerRadius: 8).stroke(accent, lineWidth: 3).padding(6).allowsHitTesting(false) } }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $model.dropTarget) { providers in
            guard !model.busy else { return false }
            model.openDroppedFiles(providers)
            return true
        }
        .alert("ScanSplit", isPresented: Binding(get: { model.issue != nil }, set: { if !$0 { model.issue = nil; model.refocus() } })) {
            Button("OK") { model.issue = nil; model.refocus() }
        } message: { Text(model.issue ?? "") }
    }
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "scissors").font(.title2).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.filename.isEmpty ? "ScanSplit" : model.filename).font(.headline).lineLimit(1).truncationMode(.middle)
                Text(model.review == nil ? "Scans in order. Individual documents." : "Original scan stays untouched").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.loading { ProgressView().controlSize(.small); Text("Opening…").foregroundStyle(.secondary) }
            Button { model.choosePDF() } label: { Label("Open PDFs", systemImage: "folder") }.disabled(model.busy)
            Button { model.chooseDestination() } label: { Label("Export Documents", systemImage: "square.and.arrow.up") }
                .buttonStyle(.borderedProminent).disabled(!model.canExport)
        }.padding(.horizontal, 20).padding(.vertical, 13)
    }
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(accent.opacity(0.09)).frame(width: 110, height: 110)
                Image(systemName: "doc.on.doc").font(.system(size: 44, weight: .light)).foregroundStyle(accent)
            }
            VStack(spacing: 8) {
                Text("Split a scan in one quick pass").font(.system(size: 27, weight: .semibold))
                Text("Drop PDFs here, or select one or more to get started.").foregroundStyle(.secondary)
            }
            Button("Choose PDFs…") { model.choosePDF() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
            HStack(spacing: 26) { shortcut("← →", "Browse"); shortcut("Space", "End document"); shortcut("Delete", "Skip blank") }.padding(.top, 10)
            Text("Private by design · Everything stays on this Mac").font(.caption).foregroundStyle(.tertiary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func shortcut(_ key: String, _ label: String) -> some View {
        VStack(spacing: 7) {
            Text(key).font(.system(.caption, design: .monospaced)).padding(.horizontal, 10).padding(.vertical, 5).background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func thumbnails(_ review: Review) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<review.pageCount, id: \.self) { page in
                        let excluded = review.decisions.excluded.contains(page)
                        let end = review.decisions.ends.contains(page)
                        let automatic = review.mandatoryEnds.contains(page)
                        Button { model.select(page) } label: {
                            VStack(spacing: 5) {
                                if let loc = model.batch?.location(page), loc.page == 0, let batch = model.batch {
                                    Text("\(loc.source + 1). \(batch.sources[loc.source].originalURL.lastPathComponent)")
                                        .font(.caption2).lineLimit(2)
                                }
                                ZStack {
                                    RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 92, height: 122)
                                    if let image = model.thumbnails[page] { Image(nsImage: image).resizable().scaledToFit().frame(width: 92, height: 122).opacity(excluded ? 0.4 : 1) }
                                    else { Image(systemName: "doc").foregroundStyle(.gray).frame(width: 92, height: 122) }
                                    if excluded { Image(systemName: "xmark").font(.system(size: 37, weight: .light)).foregroundStyle(.red).shadow(color: .white, radius: 2) }
                                }.overlay { RoundedRectangle(cornerRadius: 4).stroke(page == review.selected ? accent : Color.gray.opacity(0.2), lineWidth: page == review.selected ? 3 : 1) }
                                HStack(spacing: 4) {
                                    Text("\(page + 1)").font(.system(.caption, design: .monospaced))
                                    if excluded { Text("Skipped").font(.system(size: 9)).foregroundStyle(.red) }
                                    if end { Image(systemName: "scissors").foregroundStyle(accent) }
                                }
                                if automatic { Text("FILE END").font(.system(size: 9, weight: .bold)).foregroundStyle(accent) }
                                if end { Text("END").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(accent) }
                            }.frame(width: 118).padding(.vertical, 4)
                        }.buttonStyle(.plain)
                        .help("\(model.pageName(page))\(automatic ? ", automatic file end" : "")\(excluded ? ", excluded" : "")\(end ? ", document end" : "")")
                        .accessibilityLabel("\(model.pageName(page))\(automatic ? ", automatic file end" : "")\(excluded ? ", excluded" : "")\(end ? ", document end" : "")")
                        .id(page).task(id: "\(model.batch?.id.uuidString ?? "")-\(page)") { await model.thumbnail(page) }
                    }
                }.padding(.vertical, 15)
            }.onChange(of: review.selected) { _, page in proxy.scrollTo(page, anchor: .center) }
        }.frame(width: 144).background(Color(nsColor: .controlBackgroundColor))
    }
    private func pageStatus(_ review: Review) -> some View {
        HStack(spacing: 12) {
            Text(model.pageLabel).font(.system(.subheadline, design: .monospaced)).monospacedDigit()
            Spacer()
            if review.decisions.excluded.contains(review.selected) { Label("Excluded from export", systemImage: "xmark.circle").foregroundStyle(.red) }
            if review.mandatoryEnds.contains(review.selected) { Text("File ends automatically").foregroundStyle(.secondary) }
            else if review.decisions.ends.contains(review.selected) { Label("Document ends here", systemImage: "scissors").foregroundStyle(accent) }
            else if review.selected == review.pageCount - 1 { Text("Final document ends automatically").foregroundStyle(.secondary) }
        }.font(.caption).padding(.horizontal, 20).padding(.vertical, 9)
    }
    private func actions(_ review: Review) -> some View {
        HStack(spacing: 10) {
            Button { model.perform(.previous) } label: { Image(systemName: "chevron.left") }.help("Previous page (Left Arrow)")
            Button { model.perform(.next) } label: { Image(systemName: "chevron.right") }.help("Next page (Right Arrow)")
            Divider().frame(height: 18)
            Button { model.viewer?.zoomOut(nil); model.refocus() } label: { Image(systemName: "minus.magnifyingglass") }.help("Zoom out")
            Button("Fit") { model.viewer?.autoScales = true; model.refocus() }
            Button { model.viewer?.zoomIn(nil); model.refocus() } label: { Image(systemName: "plus.magnifyingglass") }.help("Zoom in")
            Spacer()
            Button { model.perform(.undo) } label: { Label("Undo", systemImage: "arrow.uturn.backward") }.disabled(!review.canUndo).help("Undo (Command-Z)")
            Button { model.perform(.exclude) } label: { Label(review.decisions.excluded.contains(review.selected) ? "Restore Page" : "Exclude Page", systemImage: "trash") }.help("Toggle exclusion and advance (Delete)")
            Button { model.perform(.end) } label: { Label(review.mandatoryEnds.contains(review.selected) ? "Next File" : (review.decisions.ends.contains(review.selected) ? "Remove End" : "End Document"), systemImage: "scissors") }.help("Toggle document end and advance (Space)")
        }.disabled(!model.canReview).padding(.horizontal, 18).padding(.vertical, 12)
    }
    private var footer: some View {
        HStack(spacing: 16) {
            if model.exporting {
                ProgressView(value: model.progress).frame(width: 150)
                Text("Exporting… \(Int(model.progress * 100))%").monospacedDigit()
                Button("Cancel") { model.cancelExport() }
            } else if let review = model.review {
                Label("\(review.groups.count) \(review.groups.count == 1 ? "document" : "documents")", systemImage: "doc.on.doc")
                Text("\(review.excludedCount) excluded").foregroundStyle(.secondary)
                if review.groups.isEmpty { Text("Restore a page to export").foregroundStyle(.secondary) }
                else if !model.notice.isEmpty { Text(model.notice).foregroundStyle(accent).lineLimit(1) }
                Spacer()
                if model.success != nil { Button("Show in Finder") { model.revealExport() } }
                else { Text("← → Browse   ·   Space End   ·   Delete Skip   ·   ⌘Z Undo").foregroundStyle(.secondary) }
            } else { Text("Your original PDF is always preserved.").foregroundStyle(.secondary); Spacer() }
        }.font(.caption).padding(.horizontal, 20).padding(.vertical, 10).frame(minHeight: 40)
    }
}
