import WidgetKit
import SwiftUI

struct PageEntry: TimelineEntry { let date: Date; let count: Int; let completed: Bool }
struct PageProvider: TimelineProvider {
    func placeholder(in context: Context) -> PageEntry { PageEntry(date: Date(), count: 0, completed: false) }
    func getSnapshot(in context: Context, completion: @escaping (PageEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PageEntry>) -> Void) {
        let now = Date(); let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        completion(Timeline(entries: [read()], policy: .after(min(tomorrow, now.addingTimeInterval(1800)))))
    }
    private func read() -> PageEntry {
        let defaults = UserDefaults(suiteName: "group.ffantta.PickaPic")
        let c = Calendar.current; let today = String(format: "%04d-%02d-%02d", c.component(.year, from: Date()), c.component(.month, from: Date()), c.component(.day, from: Date()))
        return PageEntry(date: Date(), count: defaults?.integer(forKey: "pageCount") ?? 0, completed: defaults?.string(forKey: "updatedDay") == today && (defaults?.bool(forKey: "todayComplete") ?? false))
    }
}
struct PageWidgetView: View {
    var entry: PageEntry
    var zh: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("pickapic").font(.system(size: 14, weight: .bold, design: .rounded)); Spacer(); Image(systemName: entry.completed ? "checkmark.circle.fill" : "plus.circle.fill").foregroundStyle(Color.black) }
            Spacer(minLength: 0)
            Text(String(format: "%03d", entry.count)).font(.system(size: 42, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
            Text(entry.completed ? (zh ? "今天，已留住。" : "Today, kept.") : (zh ? "给今天留一页。" : "A page for today.")).font(.system(size: 12, weight: .medium))
        }.padding(4).foregroundStyle(Color(red: 0.09, green: 0.10, blue: 0.09)).widgetURL(URL(string: "pickapic://today"))
            .modifier(WidgetBackground())
    }
}
struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) { content.containerBackground(Color(red: 0.86, green: 0.96, blue: 0.29), for: .widget) }
        else { content.padding().background(Color(red: 0.86, green: 0.96, blue: 0.29)) }
    }
}
@main
struct PickaPicWidget: Widget {
    let kind = "PickaPicToday"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PageProvider()) { entry in PageWidgetView(entry: entry) }
            .configurationDisplayName("PickaPic").description("Your page count and a shortcut to today's page. No private photos.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
