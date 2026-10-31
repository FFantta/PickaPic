import SwiftUI
import ImageIO
import Photos
import WidgetKit
import UserNotifications

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published var error: String?
    @Published var recoveryNotice: String?
    @Published var loading = true
    @Published var busy = false
    @Published var storageBytes: Int64 = 0
    let repository: JournalRepository
    let root: URL
    init(root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.root = root; repository = JournalRepository(root: root)
        ExportService.cleanup()
        Task { await reload() }
    }
    var live: [JournalEntry] { entries.filter { !$0.isDeleted }.sorted { $0.day > $1.day } }
    var trash: [JournalEntry] { entries.filter(\.isDeleted).sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) } }
    var today: JournalEntry? { entry(on: Day(Date())) }
    func entry(on day: Day) -> JournalEntry? { live.first { $0.day == day } }
    func url(for entry: JournalEntry, thumbnail: Bool = false) -> URL {
        root.appendingPathComponent("Images/" + (thumbnail ? entry.thumbnailName : entry.imageName))
    }
    func reload() async {
        do {
            let (snapshot, notice) = try await repository.open()
            apply(snapshot); recoveryNotice = notice
            let expired = try await repository.expireTrash(); apply(expired)
            storageBytes = await repository.usage()
        } catch { self.error = error.localizedDescription }
        loading = false
    }
    func apply(_ snapshot: JournalSnapshot) {
        entries = snapshot.entries
        WidgetBridge.update(count: live.count, today: today != nil)
        Task { await ReminderService.reschedule(completedToday: today != nil) }
    }
    func save(day: Day, caption: String, image: UIImage?, editing: JournalEntry?, replace: Bool, saveToPhotos: Bool, crop: PhotoCrop?) async throws {
        busy = true; defer { busy = false }
        let encoded: (Data, Data)?
        if let image {
            encoded = try await Task.detached(priority: .userInitiated) {
                let normalized = ImageProcessor.normalized(image)
                guard let full = normalized.jpegData(compressionQuality: 0.95),
                      let thumb = ImageProcessor.thumbnail(normalized, maxPixel: 480).jpegData(compressionQuality: 0.8) else { throw JournalError.missingImage }
                return (full, thumb)
            }.value
        } else { encoded = nil }
        let snapshot = try await repository.save(day: day, caption: caption, image: encoded?.0, thumbnail: encoded?.1, editingID: editing?.id, replace: replace, crop: crop)
        apply(snapshot); storageBytes = await repository.usage()
        if saveToPhotos, let image {
            do { try await PhotoLibraryService.save(image) }
            catch { recoveryNotice = L("日记已保存，但系统相册副本失败。可稍后从详情页重试。", "Journal saved, but the Photos copy failed. Retry from the page later.") }
        }
    }
    func delete(_ entry: JournalEntry) async { await perform { try await self.repository.setDeleted(entry.id, deleted: true) } }
    func restore(_ entry: JournalEntry, replace: Bool = false) async throws { apply(try await repository.setDeleted(entry.id, deleted: false, replace: replace)) }
    func purge(_ entry: JournalEntry) async { await perform { try await self.repository.purge(ids: [entry.id]) } }
    func exclude(_ entry: JournalEntry) async { await perform { try await self.repository.exclude(entry.id, value: !entry.excludedFromBook) } }
    func cleanCache() async {
        await perform { try await self.repository.cleanOrphans() }
        storageBytes = await repository.usage()
    }
    func perform(_ action: () async throws -> JournalSnapshot) async {
        busy = true; defer { busy = false }
        do { apply(try await action()) } catch { self.error = error.localizedDescription }
    }
}

enum ImageProcessor {
    static func normalized(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
    static func thumbnail(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let ratio = min(1, maxPixel / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
    static func load(_ url: URL, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel] as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum PhotoLibraryService {
    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw CocoaError(.userCancelled) }
        try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) }
    }
}
enum ReminderService {
    static let prefix = "pickapic-daily-"
    static func reschedule(completedToday: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
        guard UserDefaults.standard.bool(forKey: "reminder.enabled") else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let hour = UserDefaults.standard.object(forKey: "reminder.hour") as? Int ?? 21
        let minute = UserDefaults.standard.integer(forKey: "reminder.minute")
        let calendar = Calendar.current
        for offset in 0..<14 {
            if offset == 0 && completedToday { continue }
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()),
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), date > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "PickaPic"
            content.body = L("今天有什么瞬间想留下？", "What would you like to remember about today?")
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(identifier: prefix + Day(date).rawValue, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }
}
enum WidgetBridge {
    // This identifier must match both targets' signed App Group entitlement.
    static let group = "group.ffantta.PickaPic"
    static func update(count: Int, today: Bool) {
        guard let defaults = UserDefaults(suiteName: group) else { return }
        defaults.set(count, forKey: "pageCount"); defaults.set(today, forKey: "todayComplete")
        defaults.set(Day(Date()).rawValue, forKey: "updatedDay")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
