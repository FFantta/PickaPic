import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsScreen: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("language") private var language = "system"
    @AppStorage("reminder.enabled") private var reminders = false
    @AppStorage("reminder.hour") private var hour = 21
    @AppStorage("reminder.minute") private var minute = 0
    @State private var reminderTime = Date()
    @State private var backup: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImport: URL?
    @State private var importSummary: ImportSummary?
    @State private var importConfirm = false
    @State private var working = false
    @State private var message: String?
    @State private var privacy = false
    @State private var preparingBackupURL: URL?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { VStack(alignment: .leading, spacing: 8) { Text("pickapic").font(.title.bold()); Text(L("一本只属于你的生活书。", "A little book of your life.")).font(.subheadline).foregroundStyle(Paper.muted) }; Spacer(); Flower().fill(Paper.lime).frame(width: 54, height: 54) }.padding(.vertical, 10)
                    Picker(L("语言", "Language"), selection: $language) { Text(L("跟随系统", "System")).tag("system"); Text("简体中文").tag("zh"); Text("English").tag("en") }
                }
                Section(L("数据与安全", "Your journal")) {
                    LabeledContent(L("已记录", "Pages"), value: String(store.live.count))
                    LabeledContent(L("照片存储", "Photo storage"), value: ByteCountFormatter.string(fromByteCount: store.storageBytes, countStyle: .file))
                    Button { Task { await createBackup() } } label: { Label(L("导出完整备份", "Export full backup"), systemImage: "externaldrive.badge.plus") }.disabled(working)
                    Button { importing = true } label: { Label(L("从备份恢复", "Restore from backup"), systemImage: "arrow.counterclockwise") }.disabled(working)
                    NavigationLink { TrashScreen() } label: { Label(L("回收站", "Recently Deleted") + " (\(store.trash.count))", systemImage: "trash") }
                    Button { Task { await store.cleanCache(); message = L("已清理未引用的图片。用于恢复上一版本的文件会保留。", "Removed unused images. Files needed for index recovery are kept.") } } label: { Label(L("清理无用文件", "Clean unused files"), systemImage: "sparkle") }
                } footer: { Text(L("卸载 App 可能删除本机日记。请定期将完整备份存到你选择的位置。备份包含私人内容，PDF 不能用于完整恢复。", "Deleting this app may delete local journals. Save a full backup somewhere safe. Backups contain private content; PDFs cannot fully restore a journal.")) }
                Section(L("温柔的提醒", "A gentle reminder")) {
                    Toggle(L("每日提醒", "Daily reminder"), isOn: Binding(get: { reminders }, set: { value in Task { await setReminders(value) } }))
                    if reminders { DatePicker(L("提醒时间", "Time"), selection: $reminderTime, displayedComponents: .hourAndMinute).onChange(of: reminderTime) { value in hour = Calendar.current.component(.hour, from: value); minute = Calendar.current.component(.minute, from: value); Task { await ReminderService.reschedule(completedToday: store.today != nil) } } }
                    Text(L("按设备当前时区提醒。系统可能延迟通知；每次打开会补充未来 14 天的提醒。", "Uses your device's current time zone. Delivery is controlled by iOS; opening the app renews the next 14 days.")).font(.caption).foregroundStyle(Paper.muted)
                }
                Section(L("桌面入口", "On your Home Screen")) {
                    Label(L("今日快捷小组件", "Today's page widget"), systemImage: "square.grid.2x2")
                    Text(L("长按主屏幕，添加 PickaPic 小组件。默认只展示记录数量，不显示私人照片。", "Long-press your Home Screen and add PickaPic. The widget shows your page count, never private photos.")).font(.caption).foregroundStyle(Paper.muted)
                }
                Section(L("关于与支持", "About & support")) {
                    Button(L("隐私与数据说明", "Privacy & data")) { privacy = true }
                    Link(destination: URL(string: "mailto:junrun.chen@outlook.com?subject=PickaPic%20feedback")!) { Label(L("联系开发者", "Contact the developer"), systemImage: "envelope") }
                    LabeledContent(L("版本", "Version"), value: (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0") + " · Local")
                }
                if working { ProgressView(L("正在处理，请稍候…", "Working…")) }
            }.scrollContentBackground(.hidden).paperScreen().navigationTitle(L("留给自己的空间", "A space of your own")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("完成", "Done")) { dismiss() } } }
                .onAppear { reminderTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() }
                .fileExporter(isPresented: $exporting, document: backup, contentType: .pickapicBackup, defaultFilename: "PickaPic-\(Day(Date()).rawValue)") { result in
                    switch result { case .success: message = L("备份已导出。请妥善保存。", "Backup exported. Keep it somewhere safe."); case .failure(let e): if (e as NSError).code != NSUserCancelledError { message = e.localizedDescription } }
                    backup = nil
                    if let preparingBackupURL { try? FileManager.default.removeItem(at: preparingBackupURL); self.preparingBackupURL = nil }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.pickapicBackup], allowsMultipleSelection: false) { result in
                    do { if let url = try result.get().first { Task { await inspect(url) } } } catch { if (error as NSError).code != NSUserCancelledError { message = error.localizedDescription } }
                }
                .confirmationDialog(importTitle, isPresented: $importConfirm, titleVisibility: .visible) {
                    Button(L("保留现有日期的记录", "Keep existing pages on conflicts")) { Task { await restore(.keepExisting) } }
                    Button(L("使用备份的记录替换冲突日期", "Replace conflicting days with backup"), role: .destructive) { Task { await restore(.replaceExisting) } }
                    Button(L("取消", "Cancel"), role: .cancel) { clearImport() }
                }
                .sheet(isPresented: $privacy) { PrivacyScreen() }
                .alert(L("提示", "Notice"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("好", "OK")) { message = nil } } message: { Text(message ?? "") }
        }
    }
    private var importTitle: String {
        guard let summary = importSummary else { return "" }
        return L("将新增 \(summary.added) 个日期，\(summary.conflicts) 个日期冲突，另有 \(summary.deleted) 条回收站记录。导入前会保留恢复副本。", "\(summary.added) new days, \(summary.conflicts) conflicts and \(summary.deleted) deleted pages. A recovery copy is kept before import.")
    }
    private func createBackup() async {
        working = true; defer { working = false }
        do { let url = try await store.repository.makeBackup(); preparingBackupURL = url; backup = try BackupDocument(url: url); exporting = true }
        catch { message = error.localizedDescription }
    }
    private func inspect(_ source: URL) async {
        working = true; defer { working = false }
        let access = source.startAccessingSecurityScopedResource(); defer { if access { source.stopAccessingSecurityScopedResource() } }
        do {
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("Import-\(UUID().uuidString).pickapic")
            try FileManager.default.copyItem(at: source, to: copy)
            do { importSummary = try await store.repository.inspectBackup(copy) } catch { try? FileManager.default.removeItem(at: copy); throw error }
            clearImport(); pendingImport = copy; importConfirm = true
        } catch { message = error.localizedDescription }
    }
    private func restore(_ policy: ImportPolicy) async {
        guard let pendingImport else { return }
        working = true; defer { working = false; clearImport() }
        do { let snapshot = try await store.repository.restore(pendingImport, policy: policy); store.apply(snapshot); store.storageBytes = await store.repository.usage(); message = L("恢复完成，现有记录已保留恢复副本。", "Restore complete. A recovery copy of your previous journal is retained.") }
        catch { message = error.localizedDescription }
    }
    private func clearImport() { if let pendingImport { try? FileManager.default.removeItem(at: pendingImport) }; pendingImport = nil }
    private func setReminders(_ value: Bool) async {
        if value {
            do { let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]); reminders = allowed; if !allowed { message = L("通知权限未开启，可在系统设置中允许。", "Notifications are off. Enable them in Settings.") } }
            catch { message = error.localizedDescription; reminders = false }
        } else { reminders = false }
        await ReminderService.reschedule(completedToday: store.today != nil)
    }
}
struct TrashScreen: View {
    @EnvironmentObject private var store: JournalStore
    @State private var permanent: JournalEntry?
    @State private var conflict: JournalEntry?
    @State private var error: String?
    var body: some View {
        List {
            Section { Text(L("删除的记录保留 30 天。永久删除后，已导出的外部备份和系统相册副本不会自动删除。", "Deleted pages are kept for 30 days. External backups and Photos copies are not erased when a page is permanently deleted.")).font(.caption) }
            ForEach(store.trash) { e in
                HStack { PhotoTile(url: store.url(for: e, thumbnail: true), maxPixel: 200).frame(width: 58, height: 64).clipShape(RoundedRectangle(cornerRadius: 8)); VStack(alignment: .leading) { Text(e.day.rawValue).font(.headline); Text(e.caption).font(.caption).lineLimit(1); Text(L("剩余 \(remaining(e)) 天", "\(remaining(e)) days left")).font(.caption2).foregroundStyle(Paper.muted) }; Spacer(); Menu { Button(L("恢复", "Restore")) { Task { await restore(e) } }; Button(L("永久删除", "Delete permanently"), role: .destructive) { permanent = e } } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel(L("记录操作", "Page actions")) }
            }
            if store.trash.isEmpty { Text(L("回收站是空的。", "Nothing in Recently Deleted.")).foregroundStyle(Paper.muted) }
        }.scrollContentBackground(.hidden).paperScreen().navigationTitle(L("回收站", "Recently Deleted")).navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(L("永久删除这条记录？无法撤销。", "Permanently delete this page? This cannot be undone."), isPresented: Binding(get: { permanent != nil }, set: { if !$0 { permanent = nil } }), titleVisibility: .visible) { Button(L("永久删除", "Delete permanently"), role: .destructive) { if let e = permanent { Task { await store.purge(e) } }; permanent = nil } }
            .confirmationDialog(L("同日已有记录。替换后现有记录会进入回收站。", "A page already exists on this day. Replacing moves it to Recently Deleted."), isPresented: Binding(get: { conflict != nil }, set: { if !$0 { conflict = nil } }), titleVisibility: .visible) { Button(L("替换并恢复", "Replace and restore"), role: .destructive) { if let e = conflict { Task { await restore(e, replace: true) } }; conflict = nil } }
            .alert(L("无法恢复", "Unable to restore"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button(L("好", "OK")) { error = nil } } message: { Text(error ?? "") }
    }
    private func remaining(_ e: JournalEntry) -> Int { max(0, Int(ceil(((e.deletedAt ?? Date()).addingTimeInterval(30 * 86400).timeIntervalSinceNow) / 86400))) }
    private func restore(_ e: JournalEntry, replace: Bool = false) async { do { try await store.restore(e, replace: replace) } catch JournalError.dayConflict { conflict = e } catch { self.error = error.localizedDescription } }
}
struct PrivacyScreen: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 20) {
                Text(L("你的日子，\n留在你这里。", "Your days.\nYour device.")).font(.largeTitle.bold())
                Text(L("此版本没有账号、服务器、广告 SDK 或远程分析。日记照片、文字、日期与裁切信息保存在 App 的本地空间。", "This version has no accounts, servers, advertising SDKs or remote analytics. Photos, words, dates and crop settings live in the app's local storage."))
                Text(L("相机只在你选择拍照时请求权限；系统照片选择器仅提供你选中的图片。保存相册副本时会单独请求写入权限。", "Camera permission is requested when you take a photo. The system photo picker supplies only images you select. Saving a Photos copy requests separate add-only permission."))
                Text(L("系统可能按你的设备设置备份 App 数据。导出的备份包含私人内容，保存到 iCloud Drive 或第三方服务由你自行选择。删除 App 可能删除本地数据。", "iOS may back up app data according to your device settings. Full exports contain private content. Saving to iCloud Drive or another provider is your choice. Removing the app may remove local data."))
                Text(L("PDF 与分享图只在本机生成。仅在你确认分享时把选定文件交给系统分享服务。图片导出不复制原图位置元数据。", "PDFs and collages are created locally. Selected files leave the app only through your explicit use of system sharing. Image exports omit original location metadata."))
                Text(L("桌面小组件仅共享页数与今日是否完成，不共享日记照片或文字。提醒不包含私人内容。", "The widget shares only page counts and today's completion state, never journal photos or text. Reminders contain no private content."))
                Text(L("发送反馈邮件会使用你的邮件服务。请勿附上不希望分享的照片、正文或完整备份。", "Feedback uses your mail provider. Do not attach photos, journal text or full backups you do not want to share."))
            }.padding(24) }.paperScreen().navigationTitle(L("隐私与数据", "Privacy & data")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("完成", "Done")) { dismiss() } } }
        }
    }
}
