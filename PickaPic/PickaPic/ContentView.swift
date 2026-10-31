import SwiftUI

struct EditorRoute: Identifiable { let id = UUID(); var day: Day; var entry: JournalEntry? }
enum JournalTab: Int, CaseIterable { case today, calendar, book, memories
    var symbol: String { ["sun.max", "square.grid.3x3", "book.closed", "shuffle"][rawValue] }
    var title: String { [L("今日", "Today"), L("日历", "Calendar"), L("我的书", "My book"), L("回忆", "Memories")][rawValue] }
}
struct ContentView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarding.complete") private var onboarded = false
    @AppStorage("language") private var language = "system"
    @State private var tab = JournalTab.today
    @State private var showSettings = false
    @State private var editor: EditorRoute?
    var body: some View {
        NavigationStack {
            Group {
                if store.loading { ProgressView(L("打开日记…", "Opening your journal…")) }
                else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            HStack {
                                HStack(spacing: 7) { Circle().fill(Paper.ink).frame(width: 8, height: 8); Text("pickapic").font(.system(size: 22, weight: .bold, design: .rounded)).tracking(-0.8) }
                                Spacer()
                                Button { showSettings = true } label: { RoundIcon(symbol: "slider.horizontal.3") }.accessibilityLabel(L("设置", "Settings"))
                            }
                            switch tab {
                            case .today: TodayScreen { editor = EditorRoute(day: Day(Date()), entry: store.today) }
                            case .calendar: CalendarScreen { day in editor = EditorRoute(day: day, entry: store.entry(on: day)) }
                            case .book: BookScreen()
                            case .memories: MemoriesScreen()
                            }
                        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 24)
                        .frame(maxWidth: 680)
                        .frame(maxWidth: .infinity)
                    }
                }
            }.paperScreen().toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom) { dock }
                .sheet(isPresented: $showSettings) { SettingsScreen() }
                .sheet(item: $editor) { EditorScreen(day: $0.day, entry: $0.entry) }
                .fullScreenCover(isPresented: Binding(get: { !onboarded && !store.loading }, set: { if !$0 { onboarded = true } })) { OnboardingScreen { onboarded = true } }
                .alert(L("请检查", "Please check"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button(L("知道了", "OK")) { store.error = nil } } message: { Text(store.error ?? "") }
                .alert(L("数据恢复提示", "Recovery notice"), isPresented: Binding(get: { store.recoveryNotice != nil }, set: { if !$0 { store.recoveryNotice = nil } })) { Button(L("知道了", "OK")) { store.recoveryNotice = nil } } message: { Text(store.recoveryNotice ?? "") }
        }
        .id(language)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in store.refreshClock() }
        .onOpenURL { url in
            guard url.scheme == "pickapic" else { return }
            tab = url.host == "book" ? .book : (url.host == "calendar" ? .calendar : (url.host == "memories" ? .memories : .today))
            if url.host == "today" { editor = EditorRoute(day: Day(Date()), entry: store.today) }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.refreshClock() }
        }
    }
    private var dock: some View {
        HStack(spacing: 4) {
            ForEach(JournalTab.allCases, id: \.rawValue) { item in
                Button { withAnimation(.easeInOut(duration: 0.18)) { tab = item } } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.symbol).font(.system(size: 18, weight: .medium))
                        if tab == item { Text(item.title).font(.system(size: 12, weight: .bold)) }
                    }.frame(maxWidth: .infinity).frame(minHeight: 48)
                        .background(tab == item ? Paper.lime : .clear, in: Capsule())
                        .foregroundStyle(tab == item ? Paper.ink : .white.opacity(0.65))
                }.buttonStyle(.plain).accessibilityLabel(item.title).accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }.padding(7).background(Paper.ink, in: Capsule()).padding(.horizontal, 24).padding(.bottom, 8)
            .frame(maxWidth: 600).frame(maxWidth: .infinity).background(Paper.background.opacity(0.96))
    }
}
struct TodayScreen: View {
    @EnvironmentObject private var store: JournalStore
    let compose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { Eyebrow(text: Date().formatted(.dateTime.month(.wide).day().year())); Spacer(); Text(L("仅在本机", "ON THIS DEVICE")).font(.system(size: 9, weight: .medium, design: .monospaced)).padding(8).overlay(Capsule().stroke(Paper.line)) }
            HStack(alignment: .top) {
                Text(L("普通的一天，\n也值得一页。", "A little life.\nA lovely page.")).font(.system(size: 42, weight: .bold, design: .rounded)).tracking(-1.8).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Flower().fill(Paper.lime).frame(width: 76, height: 76).rotationEffect(.degrees(9)).overlay(Text(String(format: "%03d", store.live.count)).font(.system(size: 18, weight: .bold, design: .monospaced)))
            }
            if let today = store.today {
                NavigationLink { EntryDetailScreen(entryID: today.id) } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        PhotoTile(url: store.url(for: today)).aspectRatio(0.95, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 25))
                        HStack { VStack(alignment: .leading, spacing: 6) { Eyebrow(text: L("今天的一页", "TODAY'S PAGE")); Text(today.caption.isEmpty ? L("留住了这一天。", "A day, kept.") : today.caption).font(.title3.weight(.medium)).multilineTextAlignment(.leading) }; Spacer(); RoundIcon(symbol: "arrow.up.right", fill: Paper.lime) }
                    }.foregroundStyle(Paper.ink)
                }.buttonStyle(.plain)
                PrimaryButton(title: L("编辑今天", "Edit today's page"), symbol: "pencil", action: compose)
            } else {
                Button(action: compose) {
                    VStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5).fill(.white).frame(width: 148, height: 183).rotationEffect(.degrees(-9))
                            RoundedRectangle(cornerRadius: 5).fill(Paper.sage).frame(width: 148, height: 183).rotationEffect(.degrees(8))
                            Image(systemName: "camera").font(.system(size: 36, weight: .light)).foregroundStyle(Paper.ink)
                        }.padding(.top, 24)
                        Text(L("给今天，留一个位置。", "Make room for today.")).font(.headline).foregroundStyle(Paper.ink)
                        Text(L("一张照片，几句想说的话。", "One photo. A few words. Yours to keep.")).font(.subheadline).foregroundStyle(Paper.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 30).background(Paper.sage.opacity(0.27), in: RoundedRectangle(cornerRadius: 30))
                }.buttonStyle(.plain)
                PrimaryButton(title: L("留住今天", "Keep a moment"), symbol: "plus", action: compose)
            }
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "book.closed").font(.title2)
                VStack(alignment: .leading, spacing: 5) { Text(L("你的生活书，正在长大。", "Your book is growing.")).font(.headline); Text(L("已经留下 \(store.live.count) 个日子。没记录的日子，也不必着急。", "\(store.live.count) days kept. No streaks. No catching up required.")).font(.subheadline).foregroundStyle(Paper.muted) }
            }.padding(.vertical, 8)
        }
    }
}
struct OnboardingScreen: View {
    let done: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack { Eyebrow(text: "PICKAPIC / A PERSONAL JOURNAL"); Spacer(); Button(L("跳过", "Skip"), action: done).foregroundStyle(Paper.ink) }
            Spacer()
            BookArtwork(year: Calendar.current.component(.year, from: Date())).frame(maxHeight: 310).rotationEffect(.degrees(-7)).frame(maxWidth: .infinity)
            Spacer()
            Text(L("把生活，\n慢慢写成书。", "Your days.\nBound together.")).font(.system(size: 44, weight: .bold, design: .rounded)).tracking(-1.6)
            Text(L("每天选一张照片。想到什么就写几句。\n不需要账号，照片与文字保存在本机。", "Pick a photo. Leave a few words.\nNo account. Your journal stays on your device.")).font(.body).foregroundStyle(Paper.muted)
            PrimaryButton(title: L("从今天开始", "Start with today"), action: done)
        }.padding(28).paperScreen()
    }
}
