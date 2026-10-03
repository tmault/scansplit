import Foundation
@preconcurrency import PDFKit

/// Passive, opt-in local measurements of real review events; never drives the interface.
@MainActor
enum VerificationRecorder {
    static func percentile(_ samples: [Double]) -> Double {
        let sorted = samples.sorted()
        return sorted.isEmpty ? -1 : sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
    }
    static func write(model: AppModel) {
        guard let url = model.verificationReportURL, let batch = model.batch, let result = model.success else { return }
        let navigation = Array(model.displayTimings.dropFirst(model.verificationWarmup))
        let files = ((try? FileManager.default.contentsOfDirectory(at: result.folder, includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
        let counts = files.map { PDFDocument(url: $0)?.pageCount ?? -1 }
        let details: [String: Any] = [
            "source_pages": batch.pageCount, "source_files": batch.sources.map { $0.originalURL.lastPathComponent }, "source_page_counts": batch.sources.map { $0.pageCount }, "excluded_pages": model.review?.excludedCount ?? -1,
            "output_documents": result.documentCount, "output_pages": result.pageCount,
            "output_folder": result.folder.path, "reopened_page_counts": counts,
            "first_open_to_display_ms": model.openingVisibleMilliseconds ?? -1,
            "navigation_samples": navigation.count, "page_display_p95_ms": percentile(navigation),
            "marking_samples": model.markingTimings.count, "visible_marking_p95_ms": percentile(model.markingTimings),
            "visible_marking_max_ms": model.markingTimings.max() ?? -1,
            "warmup_events_excluded": model.verificationWarmup,
            "method": "Real review key/control events. Timing starts at action handling and ends after the next SwiftUI/AppKit layout/display and CATransaction flush. This is not physical screen refresh timing.",
            "source_bytes": batch.sources.map { (try? FileManager.default.attributesOfItem(atPath: $0.originalURL.path)[.size]) ?? 0 },
            "macos": ProcessInfo.processInfo.operatingSystemVersionString, "user_speed_confirmation": "pending"
        ]
        do { try JSONSerialization.data(withJSONObject: details, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic) }
        catch { model.issue = "The PDFs exported, but the local measurement report could not be saved." }
    }
}
