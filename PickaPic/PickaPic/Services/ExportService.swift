import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct SharePayload: Identifiable { let id = UUID(); let urls: [URL] }
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: urls, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
extension UTType {
    static let pickapicBackup = UTType(exportedAs: "com.pickapic.journal-backup", conformingTo: .package)
}
// Immutable wrapper handed to the system exporter; never mutated after initialization.
struct BackupDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.pickapicBackup] }
    let wrapper: FileWrapper
    init(url: URL) throws { wrapper = try FileWrapper(url: url, options: []) }
    init(configuration: ReadConfiguration) throws { wrapper = configuration.file }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { wrapper }
}
struct PDFReader: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView(); v.autoScales = true; v.displayMode = .singlePage; v.displayDirection = .horizontal; v.usePageViewController(true); v.backgroundColor = UIColor(Paper.background); return v
    }
    func updateUIView(_ view: PDFView, context: Context) { if view.document?.documentURL != url { view.document = PDFDocument(url: url) } }
}
struct BookExportOptions: Sendable {
    var title: String
    var year: Int
    var coverID: UUID?
    var chinese: Bool
}
enum ExportService {
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PickaPicExports", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func cleanup() {
        guard let root = try? folder(), let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for f in files where ((try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantFuture) < Date().addingTimeInterval(-86400) { try? FileManager.default.removeItem(at: f) }
    }
    static func book(entries: [JournalEntry], root: URL, options: BookExportOptions, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let worker = Task.detached(priority: .userInitiated) { () throws -> URL in
            let pages = entries.filter { !$0.isDeleted && !$0.excludedFromBook && $0.day.year == options.year }.sorted { $0.day < $1.day }
            guard !pages.isEmpty else { throw JournalError.noEntries }
            // Fail before creating a misleading partial book.
            for e in pages { guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Images/" + e.imageName).path) else { throw JournalError.missingImage } }
            let size = CGSize(width: 504, height: 648) // 7 x 9 inches at 72 points per inch.
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
            let output = try folder().appendingPathComponent("PickaPic-\(options.year)-\(UUID().uuidString.prefix(6)).pdf")
            var failure: Error?
            let data = renderer.pdfData { context in
                context.beginPage()
                UIColor(Paper.lilac).setFill(); context.cgContext.fill(CGRect(origin: .zero, size: size))
                drawText("PICKAPIC / A PERSONAL JOURNAL", rect: CGRect(x: 42, y: 42, width: 420, height: 30), font: .monospacedSystemFont(ofSize: 10, weight: .semibold))
                drawText(options.title, rect: CGRect(x: 42, y: 110, width: 420, height: 145), font: .systemFont(ofSize: 44, weight: .heavy), lines: 4)
                if let cover = pages.first(where: { $0.id == options.coverID }), let image = load(cover, root: root, pixels: 2000) { drawImage(image, in: CGRect(x: 42, y: 284, width: 420, height: 235), fill: false) }
                else {
                    UIColor(Paper.lime).setFill(); UIBezierPath(ovalIn: CGRect(x: 42, y: 300, width: 160, height: 160)).fill()
                    drawText("\(pages.count)", rect: CGRect(x: 66, y: 346, width: 120, height: 65), font: .monospacedSystemFont(ofSize: 44, weight: .bold))
                }
                drawText("\(options.year)", rect: CGRect(x: 42, y: 554, width: 200, height: 60), font: .systemFont(ofSize: 42, weight: .light))
                drawText(options.chinese ? "\(pages.count) 个日子，一本生活。" : "\(pages.count) days. A little life.", rect: CGRect(x: 260, y: 578, width: 210, height: 30), font: .systemFont(ofSize: 12))
                var previousMonth = ""
                var pageNumber = 1
                for (i, entry) in pages.enumerated() {
                    if Task.isCancelled { failure = CancellationError(); break }
                    autoreleasepool {
                        let month = String(entry.day.rawValue.prefix(7))
                        if month != previousMonth {
                            previousMonth = month; context.beginPage(); pageNumber += 1
                            UIColor(Paper.sage).setFill(); context.cgContext.fill(CGRect(origin: .zero, size: size))
                            drawText("PICKAPIC / CHAPTER", rect: CGRect(x: 42, y: 42, width: 420, height: 25), font: .monospacedSystemFont(ofSize: 10, weight: .semibold))
                            drawText(String(entry.day.rawValue.dropFirst(5).prefix(2)), rect: CGRect(x: 36, y: 210, width: 430, height: 190), font: .systemFont(ofSize: 150, weight: .ultraLight))
                            drawText(month, rect: CGRect(x: 42, y: 528, width: 420, height: 50), font: .systemFont(ofSize: 28, weight: .medium))
                        }
                        context.beginPage(); pageNumber += 1
                        UIColor(Paper.background).setFill(); context.cgContext.fill(CGRect(origin: .zero, size: size))
                        drawText(entry.day.rawValue, rect: CGRect(x: 36, y: 30, width: 430, height: 25), font: .monospacedSystemFont(ofSize: 11, weight: .medium))
                        if let image = load(entry, root: root, pixels: 3200) { drawImage(image, in: CGRect(x: 36, y: 76, width: 432, height: 400), fill: false) }
                        else { failure = JournalError.missingImage }
                        drawText(entry.caption, rect: CGRect(x: 36, y: 502, width: 432, height: 108), font: .systemFont(ofSize: 16), lines: 5)
                        drawText(String(pageNumber), rect: CGRect(x: 430, y: 620, width: 40, height: 18), font: .monospacedSystemFont(ofSize: 9, weight: .regular))
                    }
                    progress(Double(i + 1) / Double(pages.count))
                    if failure != nil { break }
                }
            }
            if let failure { throw failure }
            try Task.checkCancellation()
            try data.write(to: output, options: .atomic)
            return output
        }
        return try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }
    static func load(_ entry: JournalEntry, root: URL, pixels: Int) -> UIImage? {
        guard let image = ImageProcessor.load(root.appendingPathComponent("Images/" + entry.imageName), maxPixel: pixels) else { return nil }
        return entry.crop.map { ImageProcessor.crop(image, using: $0) } ?? image
    }
    static func singleCard(entry: JournalEntry, root: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            guard let image = load(entry, root: root, pixels: 2200) else { throw JournalError.missingImage }
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let card = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1440), format: format).image { c in
                UIColor(Paper.background).setFill(); c.cgContext.fill(CGRect(x: 0, y: 0, width: 1080, height: 1440))
                drawText("PICKAPIC", rect: CGRect(x: 70, y: 62, width: 500, height: 40), font: .monospacedSystemFont(ofSize: 24, weight: .bold))
                drawImage(image, in: CGRect(x: 60, y: 150, width: 960, height: 930), fill: false)
                drawText(entry.caption, rect: CGRect(x: 70, y: 1130, width: 940, height: 180), font: .systemFont(ofSize: 30), lines: 4)
                drawText(entry.day.rawValue, rect: CGRect(x: 70, y: 1350, width: 940, height: 40), font: .monospacedSystemFont(ofSize: 22, weight: .regular))
            }
            let url = try folder().appendingPathComponent("PickaPic-card-\(UUID().uuidString).jpg")
            guard let data = card.jpegData(compressionQuality: 0.95) else { throw JournalError.missingImage }; try data.write(to: url, options: .atomic); return url
        }.value
    }
    static func collage(entries: [JournalEntry], root: URL, start: Day, end: Day, monthly: Bool, showCaption: Bool, showDates: Bool) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let chosen = entries.filter { !$0.isDeleted && !$0.excludedFromBook && $0.day >= start && $0.day <= end }.sorted { $0.day < $1.day }
            guard !chosen.isEmpty else { throw JournalError.noEntries }
            let columns = monthly ? 7 : 2
            let calendar = Calendar(identifier: .gregorian)
            let padding = monthly ? calendar.component(.weekday, from: start.date) - 1 : 0
            let total = monthly ? (calendar.dateComponents([.day], from: start.date, to: end.date).day ?? 0) + 1 + padding : chosen.count
            let rows = (total + columns - 1) / columns
            let width: CGFloat = 1400, margin: CGFloat = 60, gap: CGFloat = 12
            let cell = (width - margin * 2 - CGFloat(columns - 1) * gap) / CGFloat(columns)
            let captionHeight: CGFloat = !monthly && showCaption ? 100 : 0
            let cellHeight = cell + captionHeight + (showDates ? 32 : 0)
            let height = 230 + CGFloat(rows) * (cellHeight + gap) + 90
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let rendered = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { c in
                UIColor(Paper.background).setFill(); c.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
                drawText("PICKAPIC / LITTLE MOMENTS", rect: CGRect(x: margin, y: 46, width: 1280, height: 40), font: .monospacedSystemFont(ofSize: 20, weight: .bold))
                drawText(monthly ? String(start.rawValue.prefix(7)) : "\(start.rawValue) — \(end.rawValue)", rect: CGRect(x: margin, y: 102, width: 1280, height: 80), font: .systemFont(ofSize: 46, weight: .bold))
                for (i, entry) in chosen.enumerated() {
                    let slot = monthly ? padding + calendar.component(.day, from: entry.day.date) - 1 : i
                    let x = margin + CGFloat(slot % columns) * (cell + gap), y = 230 + CGFloat(slot / columns) * (cellHeight + gap)
                    if let image = load(entry, root: root, pixels: monthly ? 500 : 1200) { drawImage(image, in: CGRect(x: x, y: y, width: cell, height: cell), fill: true) }
                    if showDates { drawText(String(entry.day.rawValue.suffix(5)), rect: CGRect(x: x, y: y + cell + 5, width: cell, height: 28), font: .monospacedSystemFont(ofSize: 18, weight: .medium)) }
                    if !monthly && showCaption { drawText(entry.caption, rect: CGRect(x: x, y: y + cell + (showDates ? 38 : 6), width: cell, height: 90), font: .systemFont(ofSize: 20), lines: 3) }
                }
            }
            // Rendering produces fresh pixels and intentionally does not copy EXIF/location metadata.
            let url = try folder().appendingPathComponent("PickaPic-\(monthly ? "month" : "week")-\(UUID().uuidString).jpg")
            guard let data = rendered.jpegData(compressionQuality: 0.95) else { throw JournalError.missingImage }; try data.write(to: url, options: .atomic); return url
        }.value
    }
    private static func drawText(_ text: String, rect: CGRect, font: UIFont, lines: Int = 1) {
        var font = font
        while font.pointSize > 9 {
            let measured = (text as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
            if measured.height + CGFloat(max(0, lines - 1)) * 4 <= rect.height { break }
            font = font.withSize(font.pointSize - 1)
        }
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping; style.lineSpacing = 4
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font, .foregroundColor: UIColor(Paper.ink), .paragraphStyle: style], context: nil)
    }
    private static func drawImage(_ image: UIImage, in rect: CGRect, fill: Bool) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let r = fill ? max(rect.width / image.size.width, rect.height / image.size.height) : min(rect.width / image.size.width, rect.height / image.size.height)
        let s = CGSize(width: image.size.width * r, height: image.size.height * r)
        UIGraphicsGetCurrentContext()?.saveGState(); UIBezierPath(rect: rect).addClip()
        image.draw(in: CGRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height))
        UIGraphicsGetCurrentContext()?.restoreGState()
    }
}
