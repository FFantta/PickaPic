import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var store: JournalStore
    @State private var month = Date()
    let compose: (Day) -> Void
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.firstWeekday = 1; return c }
    private var days: [Day?] {
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let padding = calendar.component(.weekday, from: first) - 1
        let range = calendar.range(of: .day, in: .month, for: first)!
        return Array(repeating: nil, count: padding) + range.map { Day(calendar.date(byAdding: .day, value: $0 - 1, to: first)!) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(kicker: "THE DAYS ADD UP", title: L("日子有迹可循。", "Days, collected."))
            HStack {
                Button { changeMonth(-1) } label: { RoundIcon(symbol: "chevron.left") }.accessibilityLabel(L("上个月", "Previous month"))
                Spacer(); Text(month.formatted(.dateTime.year().month(.wide))).font(.title3.weight(.semibold)); Spacer()
                Button { changeMonth(1) } label: { RoundIcon(symbol: "chevron.right") }.accessibilityLabel(L("下个月", "Next month"))
            }
            HStack { ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, day in Text(day).font(.caption).foregroundStyle(Paper.muted).frame(maxWidth: .infinity) } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        if let entry = store.entry(on: day) {
                            NavigationLink { EntryDetailScreen(entryID: entry.id) } label: {
                                PhotoTile(url: store.url(for: entry, thumbnail: true), maxPixel: 250)
                                    .aspectRatio(0.82, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(alignment: .bottomLeading) { Text(String(calendar.component(.day, from: day.date))).font(.system(size: 10, weight: .bold)).padding(4).background(Paper.ink.opacity(0.65), in: Capsule()).foregroundStyle(.white).padding(3) }
                            }.accessibilityLabel(day.rawValue + " " + entry.caption)
                        } else {
                            Button { compose(day) } label: {
                                Text(String(calendar.component(.day, from: day.date))).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).aspectRatio(0.82, contentMode: .fit)
                                    .background(day == Day(Date()) ? Paper.lime : .white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(day > Day(Date()) ? Paper.muted.opacity(0.4) : Paper.ink)
                            }.disabled(day > Day(Date())).accessibilityLabel(day.rawValue + L(" 添加记录", " Add a page"))
                        }
                    } else { Color.clear.aspectRatio(0.82, contentMode: .fit) }
                }
            }
            HStack { Text(L("\(monthCount) 个日子，留在这个月。", "\(monthCount) days kept this month.")).font(.subheadline).foregroundStyle(Paper.muted); Spacer(); Button(L("回到今天", "Today")) { month = Date() }.font(.caption.weight(.bold)) }
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: L("这个月的片段", "THIS MONTH"))
                ForEach(store.live.filter { calendar.isDate($0.day.date, equalTo: month, toGranularity: .month) }) { entry in
                    NavigationLink { EntryDetailScreen(entryID: entry.id) } label: {
                        HStack(spacing: 16) { PhotoTile(url: store.url(for: entry, thumbnail: true), maxPixel: 250).frame(width: 70, height: 78).clipShape(RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 5) { Text(entry.day.date.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(Paper.muted); Text(entry.caption.isEmpty ? L("无题的一天", "An untitled day") : entry.caption).font(.body).lineLimit(2) }; Spacer(); Image(systemName: "arrow.up.right") }.foregroundStyle(Paper.ink)
                    }.buttonStyle(.plain)
                }
                if monthCount == 0 { Text(L("空白也没关系。点一个过去的日子，就可以补记。", "Nothing here yet. Tap an earlier day to add a memory.")).foregroundStyle(Paper.muted).font(.subheadline) }
            }
        }
    }
    private var monthCount: Int { store.live.filter { calendar.isDate($0.day.date, equalTo: month, toGranularity: .month) }.count }
    private func changeMonth(_ offset: Int) { if let next = calendar.date(byAdding: .month, value: offset, to: month) { month = next } }
}
struct EntryDetailScreen: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var edit = false
    @State private var confirmDelete = false
    @State private var share: SharePayload?
    @State private var message: String?
    private var entry: JournalEntry? { store.live.first { $0.id == entryID } }
    var body: some View {
        Group {
            if let e = entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Eyebrow(text: e.day.rawValue)
                        PhotoTile(url: store.url(for: e), maxPixel: 2400, fit: true).frame(height: 390).clipShape(RoundedRectangle(cornerRadius: 24))
                        Text(e.caption.isEmpty ? L("无题的一天。", "An untitled day.") : e.caption).font(.title2).textSelection(.enabled)
                        Text(e.day.date.formatted(date: .complete, time: .omitted)).font(.caption).foregroundStyle(Paper.muted)
                        PrimaryButton(title: L("编辑这一页", "Edit this page"), symbol: "pencil") { edit = true }
                        Button { Task { await store.exclude(e) } } label: { Label(e.excludedFromBook ? L("收录进生活书", "Include in book") : L("暂不收录进书", "Leave out of book"), systemImage: e.excludedFromBook ? "book.closed" : "book.closed.fill") }
                        Button { Task { do { let url = try await ExportService.singleCard(entry: e, root: store.root); share = SharePayload(urls: [url]) } catch { message = error.localizedDescription } } } label: { Label(L("分享图文卡片", "Share photo card"), systemImage: "square.and.arrow.up") }
                        Button { Task { do { guard let image = ImageProcessor.load(store.url(for: e), maxPixel: 6000) else { throw JournalError.missingImage }; try await PhotoLibraryService.save(image); message = L("已保存到系统相册。", "Saved to Photos.") } catch { message = error.localizedDescription } } } label: { Label(L("保存照片到相册", "Save photo to Photos"), systemImage: "square.and.arrow.down") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label(L("移到回收站", "Move to Recently Deleted"), systemImage: "trash") }
                    }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }.sheet(isPresented: $edit) { EditorScreen(day: e.day, entry: e) }
            } else { Text(L("这一页已移到回收站。", "This page is in Recently Deleted.")) }
        }.paperScreen().navigationTitle(L("这一页", "A page")).navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(L("删除后可在 30 天内恢复。", "You can restore this page for 30 days."), isPresented: $confirmDelete, titleVisibility: .visible) { Button(L("移到回收站", "Move to Recently Deleted"), role: .destructive) { if let e = entry { Task { await store.delete(e); if store.error == nil { dismiss() } } } } }
            .sheet(item: $share) { ShareSheet(urls: $0.urls) }
            .alert(L("提示", "Notice"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("好", "OK")) { message = nil } } message: { Text(message ?? "") }
    }
}
struct MemoriesScreen: View {
    @EnvironmentObject private var store: JournalStore
    @State private var selection: UUID?
    private var memories: [JournalEntry] { store.live.filter { $0.day < Day(Date()) } }
    private var chosen: JournalEntry? { memories.first { $0.id == selection } ?? memories.first }
    private var onThisDay: [JournalEntry] { memories.filter { String($0.day.rawValue.suffix(5)) == String(Day(Date()).rawValue.suffix(5)) && $0.day.year < Day(Date()).year } }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(kicker: "HELLO AGAIN", title: L("和过去的自己，\n见一面。", "A familiar\nkind of hello."))
            if let e = chosen {
                NavigationLink { EntryDetailScreen(entryID: e.id) } label: {
                    VStack(alignment: .leading, spacing: 16) { PhotoTile(url: store.url(for: e)).aspectRatio(0.9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20)); Eyebrow(text: e.day.rawValue); Text(e.caption.isEmpty ? L("那时的一天。", "A day from before.") : e.caption).font(.title3).foregroundStyle(Paper.ink) }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 26)).rotationEffect(.degrees(-1.5))
                }.buttonStyle(.plain)
                PrimaryButton(title: L("再翻一页回忆", "Another little memory"), symbol: "shuffle") { selection = memories.filter { $0.id != chosen?.id }.randomElement()?.id ?? chosen?.id }
                if !onThisDay.isEmpty { Eyebrow(text: L("往年今日", "ON THIS DAY")); ForEach(onThisDay) { e in NavigationLink(e.day.rawValue) { EntryDetailScreen(entryID: e.id) }.font(.title3) } }
            } else {
                Flower().fill(Paper.lilac).frame(width: 140, height: 140).frame(maxWidth: .infinity).padding(30)
                Text(L("回忆还在来的路上。\n记录今天，未来再来看看。", "Memories take a little time.\nKeep today. Come back tomorrow.")).font(.title3).foregroundStyle(Paper.muted)
            }
        }
    }
}
