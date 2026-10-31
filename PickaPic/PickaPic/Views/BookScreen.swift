import SwiftUI
import PDFKit

struct BookScreen: View {
    @EnvironmentObject private var store: JournalStore
    @AppStorage("book.title") private var title = "THE LITTLE\nTHINGS"
    @AppStorage("book.cover") private var cover = ""
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var start = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!
    @State private var end = Date()
    @State private var useRange = false
    @State private var exportTask: Task<Void, Never>?
    @State private var progress: Double?
    @State private var preview: SharePayload?
    @State private var showSharing = false
    @State private var error: String?
    private var pages: [JournalEntry] { store.live.filter { !$0.excludedFromBook && $0.day.year == year && (!useRange || ($0.day >= Day(start) && $0.day <= Day(end))) }.sorted { $0.day < $1.day } }
    private var years: [Int] { Array(Set(store.live.map { $0.day.year } + [Calendar.current.component(.year, from: Date())])).sorted(by: >) }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(kicker: "A LIFE IN PAGES", title: L("这是你的，\n生活作品集。", "A life,\nwell collected."))
            HStack { Text(L("年度", "Year")).font(.headline); Spacer(); Picker(L("年度", "Year"), selection: $year) { ForEach(years, id: \.self) { Text(String($0)).tag($0) } }.pickerStyle(.menu) }
            ZStack(alignment: .bottomTrailing) {
                BookArtwork(year: year, title: title, count: pages.count).frame(maxWidth: 280).rotationEffect(.degrees(-5)).padding(.vertical, 24).frame(maxWidth: .infinity)
                Flower().fill(Paper.lime).frame(width: 86, height: 86).overlay(Text(L("慢慢\n成书", "IN THE\nMAKING")).font(.system(size: 11, weight: .bold, design: .monospaced)).multilineTextAlignment(.center)).rotationEffect(.degrees(12))
            }
            TextField(L("书名", "Book title"), text: $title, axis: .vertical).font(.title2.weight(.bold)).lineLimit(2...3).onChange(of: title) { value in title = String(value.prefix(50)) }
            Picker(L("封面照片", "Cover photo"), selection: $cover) { Text(L("使用文字封面", "Typography cover")).tag(""); ForEach(pages) { Text($0.day.rawValue).tag($0.id.uuidString) } }
            Toggle(L("自选日期范围", "Choose a date range"), isOn: $useRange)
            if useRange { DatePicker(L("从", "From"), selection: $start, in: ...end, displayedComponents: .date); DatePicker(L("到", "To"), selection: $end, in: start...Date(), displayedComponents: .date) }
            if let progress {
                ProgressView(value: progress)
                Button(L("取消生成", "Cancel export")) { exportTask?.cancel(); exportTask = nil; self.progress = nil }
            } else {
                PrimaryButton(title: L("翻开我的书", "Open my book"), symbol: "book") { generate() }.disabled(pages.isEmpty)
            }
            Text(L("\(pages.count) 张照片会收录。每个日子独占一页，月份自成章节。", "\(pages.count) photos included. A page for each day, a chapter for each month.")).font(.subheadline).foregroundStyle(Paper.muted)
            Button { showSharing = true } label: { Label(L("制作每周或月历分享图", "Make a week or month collage"), systemImage: "square.and.arrow.up") }.font(.headline)
            if !pages.isEmpty {
                Divider(); Eyebrow(text: L("收录预览", "IN THIS BOOK"))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(pages) { e in NavigationLink { EntryDetailScreen(entryID: e.id) } label: { PhotoTile(url: store.url(for: e, thumbnail: true), maxPixel: 300).aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10)) }.accessibilityLabel(e.day.rawValue) }
                }
            }
            Text(L("在记录详情中可选择不收录；这不会删除日记。PDF 是阅读版，请以印刷商规范进一步预检后再印刷。", "Leave out a page from its details without deleting it. The PDF is a reading edition; check a printer's specifications before printing.")).font(.caption).foregroundStyle(Paper.muted)
        }
        .sheet(item: $preview) { payload in BookPreviewScreen(url: payload.urls[0]) }
        .sheet(isPresented: $showSharing) { CollageScreen() }
        .alert(L("导出未完成", "Export not completed"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button(L("好", "OK")) { error = nil } } message: { Text(error ?? "") }
        .onDisappear { exportTask?.cancel() }
    }
    private func generate() {
        progress = 0
        let selected = pages; let root = store.root
        let options = BookExportOptions(title: title.isEmpty ? "THE LITTLE THINGS" : title, year: year, coverID: UUID(uuidString: cover), chinese: L("是", "no") == "是")
        exportTask = Task {
            do {
                let url = try await ExportService.book(entries: selected, root: root, options: options) { value in Task { @MainActor in progress = value } }
                try Task.checkCancellation(); preview = SharePayload(urls: [url])
            } catch is CancellationError { } catch { self.error = error.localizedDescription }
            progress = nil
        }
    }
}
struct BookPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var share: SharePayload?
    var body: some View {
        NavigationStack {
            PDFReader(url: url).ignoresSafeArea(edges: .bottom).navigationTitle(L("逐页预览", "Page by page")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("完成", "Done")) { dismiss() } }; ToolbarItem(placement: .primaryAction) { Button { share = SharePayload(urls: [url]) } label: { Label(L("导出 PDF", "Export PDF"), systemImage: "square.and.arrow.up") } } }
                .sheet(item: $share) { ShareSheet(urls: $0.urls) }
        }
    }
}
struct CollageScreen: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var monthly = true
    @State private var showCaption = true
    @State private var showDates = true
    @State private var working = false
    @State private var result: URL?
    @State private var error: String?
    @State private var share: SharePayload?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Picker(L("样式", "Layout"), selection: $monthly) { Text(L("月历", "Month")).tag(true); Text(L("一周碎片", "Week")).tag(false) }.pickerStyle(.segmented)
                    DatePicker(L("选择日期", "Choose a date"), selection: $date, in: ...Date(), displayedComponents: .date)
                    Toggle(L("显示日期", "Show dates"), isOn: $showDates)
                    if !monthly { Toggle(L("显示文字", "Show captions"), isOn: $showCaption) }
                    if let result { PhotoTile(url: result, maxPixel: 1800, fit: true).frame(height: 400); PrimaryButton(title: L("保存或分享", "Save or share"), symbol: "square.and.arrow.up") { share = SharePayload(urls: [result]) } }
                    PrimaryButton(title: working ? L("正在排版…", "Making your collage…") : L("生成预览", "Create preview"), symbol: "rectangle.3.group") { Task { await generate() } }.disabled(working)
                    Text(L("仅在你确认后打开系统分享。不附带照片位置数据。", "Sharing starts only when you choose. Photo location metadata is omitted.")).font(.caption).foregroundStyle(Paper.muted)
                }.padding(24)
            }.paperScreen().navigationTitle(L("把片段带走", "Keep the collection")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("完成", "Done")) { dismiss() } } }
                .onChange(of: date) { _ in result = nil }.onChange(of: monthly) { _ in result = nil }.onChange(of: showCaption) { _ in result = nil }.onChange(of: showDates) { _ in result = nil }
                .sheet(item: $share) { ShareSheet(urls: $0.urls) }
                .alert(L("无法生成", "Unable to export"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button(L("好", "OK")) { error = nil } } message: { Text(error ?? "") }
        }
    }
    private func generate() async {
        working = true; defer { working = false }
        var c = Calendar(identifier: .gregorian); c.firstWeekday = 2
        let interval = c.dateInterval(of: monthly ? .month : .weekOfYear, for: date)!
        let last = c.date(byAdding: .day, value: -1, to: interval.end)!
        do { result = try await ExportService.collage(entries: store.live, root: store.root, start: Day(interval.start), end: Day(last), monthly: monthly, showCaption: showCaption, showDates: showDates) }
        catch { self.error = error.localizedDescription }
    }
}
